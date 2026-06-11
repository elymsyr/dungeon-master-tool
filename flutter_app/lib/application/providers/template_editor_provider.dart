import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import 'template_provider.dart';

/// Immutable draft state for the responsive Template Editor (roadmap §1.5).
///
/// PR-1.5 lands the editor **read-only**: this state already carries the draft
/// schema, the active category/field selection (shared across the desktop
/// 3-pane, tablet 2-pane, and phone stacked layouts), a `dirty` flag, and a
/// validation error list — but no field/category mutators are wired yet. The
/// Phase 2 CRUD PRs (2.1 category CRUD, 2.2 field CRUD) plug their mutators into
/// [TemplateEditorNotifier] and flip `dirty`; the Save flow below already exists
/// so they need only mark the draft dirty.
@immutable
class TemplateEditorState {
  /// The working copy of the template. `null` before [TemplateEditorNotifier.load].
  final WorldSchema? schema;

  /// Built-in templates are read-only — all CRUD affordances are hidden and a
  /// "make a copy to edit" banner is shown instead (roadmap §1.5).
  final bool isBuiltin;

  /// Currently inspected category (`categoryId`), or null when none selected
  /// (desktop/tablet then show category-level metadata in the inspector).
  final String? selectedCategoryId;

  /// Currently inspected field (`fieldId`) within [selectedCategoryId], or null.
  final String? selectedFieldId;

  /// True once the draft diverges from its persisted form. Drives the app-bar
  /// dirty dot, the Save button enablement, and the `PopScope` discard prompt.
  /// Always false in read-only mode.
  final bool isDirty;

  /// Blocking validation messages surfaced in the Save error summary. Empty in
  /// PR-1.5 (nothing mutates yet); populated by the Phase 2 CRUD validators.
  final List<String> errors;

  /// True while [TemplateEditorNotifier.save] is in flight.
  final bool isSaving;

  const TemplateEditorState({
    this.schema,
    this.isBuiltin = false,
    this.selectedCategoryId,
    this.selectedFieldId,
    this.isDirty = false,
    this.errors = const [],
    this.isSaving = false,
  });

  /// Empty initial state, before a template is loaded into the editor.
  static const TemplateEditorState empty = TemplateEditorState();

  bool get isLoaded => schema != null;

  /// Editing is permitted only on a loaded, non-built-in template.
  bool get canEdit => isLoaded && !isBuiltin;

  List<EntityCategorySchema> get categories => schema?.categories ?? const [];

  EntityCategorySchema? get selectedCategory {
    final id = selectedCategoryId;
    if (id == null) return null;
    for (final c in categories) {
      if (c.categoryId == id) return c;
    }
    return null;
  }

  FieldSchema? get selectedField {
    final id = selectedFieldId;
    final cat = selectedCategory;
    if (id == null || cat == null) return null;
    for (final f in cat.fields) {
      if (f.fieldId == id) return f;
    }
    return null;
  }

  TemplateEditorState copyWith({
    WorldSchema? schema,
    bool? isBuiltin,
    Object? selectedCategoryId = _sentinel,
    Object? selectedFieldId = _sentinel,
    bool? isDirty,
    List<String>? errors,
    bool? isSaving,
  }) {
    return TemplateEditorState(
      schema: schema ?? this.schema,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      selectedCategoryId: selectedCategoryId == _sentinel
          ? this.selectedCategoryId
          : selectedCategoryId as String?,
      selectedFieldId: selectedFieldId == _sentinel
          ? this.selectedFieldId
          : selectedFieldId as String?,
      isDirty: isDirty ?? this.isDirty,
      errors: errors ?? this.errors,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  static const Object _sentinel = Object();
}

/// Result of a [TemplateEditorNotifier.save] attempt.
enum TemplateSaveResult {
  /// Persisted successfully; the library was invalidated.
  saved,

  /// Nothing to do (read-only built-in, or no pending changes).
  noop,

  /// Blocked by validation errors (see [TemplateEditorState.errors]).
  invalid,

  /// The repository threw while persisting.
  failed,
}

/// Screen-scoped editor controller. One instance per open editor (autoDispose),
/// shared by every responsive layout and the phone's nested-Navigator pages so
/// selection stays in sync regardless of which surface the user drives.
class TemplateEditorNotifier extends StateNotifier<TemplateEditorState> {
  final Ref _ref;

  TemplateEditorNotifier(this._ref) : super(TemplateEditorState.empty);

  /// Loads [schema] into the editor and selects its first category (so the
  /// desktop/tablet field list is never empty on open). Idempotent for the same
  /// schema id — re-loading the same template preserves the current selection.
  void load(WorldSchema schema, {required bool isBuiltin}) {
    if (state.schema?.schemaId == schema.schemaId && state.isLoaded) {
      // Same template re-pushed (e.g. router rebuild) — refresh the blob but
      // keep the user's place.
      state = state.copyWith(schema: schema, isBuiltin: isBuiltin);
      return;
    }
    final firstCategory =
        schema.categories.isNotEmpty ? schema.categories.first.categoryId : null;
    state = TemplateEditorState(
      schema: schema,
      isBuiltin: isBuiltin,
      selectedCategoryId: firstCategory,
      selectedFieldId: null,
      isDirty: false,
      errors: const [],
    );
  }

  /// Selects a category and clears any field selection (the inspector then
  /// shows category metadata). No-op if already selected.
  void selectCategory(String? categoryId) {
    if (state.selectedCategoryId == categoryId && state.selectedFieldId == null) {
      return;
    }
    state = state.copyWith(
      selectedCategoryId: categoryId,
      selectedFieldId: null,
    );
  }

  /// Selects a field within the active category for inspection/editing.
  void selectField(String? fieldId) {
    if (state.selectedFieldId == fieldId) return;
    state = state.copyWith(selectedFieldId: fieldId);
  }

  /// Clears the field selection, returning the inspector to category metadata.
  void clearFieldSelection() {
    if (state.selectedFieldId == null) return;
    state = state.copyWith(selectedFieldId: null);
  }

  /// Persists the draft to the user template library.
  ///
  /// In PR-1.5 this never runs work (read-only built-in, and nothing mutates a
  /// user copy yet) — it returns [TemplateSaveResult.noop]. The full
  /// validate → recompute-hash → repository.save → invalidate-list pipeline is
  /// already wired so the Phase 2 CRUD PRs only need to mark the draft dirty.
  Future<TemplateSaveResult> save() async {
    final schema = state.schema;
    if (schema == null || state.isBuiltin) {
      return TemplateSaveResult.noop;
    }
    if (!state.isDirty) {
      return TemplateSaveResult.noop;
    }
    if (state.errors.isNotEmpty) {
      return TemplateSaveResult.invalid;
    }
    state = state.copyWith(isSaving: true);
    try {
      final repo = _ref.read(templateRepositoryProvider);
      // TemplateRepository.save recomputes computeWorldSchemaContentHash and
      // preserves the originalHash lineage (PR-1.4).
      await repo.save(schema);
      _ref.invalidate(templateLibraryProvider);
      state = state.copyWith(isSaving: false, isDirty: false);
      return TemplateSaveResult.saved;
    } catch (e, st) {
      debugPrint('Template save failed: $e\n$st');
      state = state.copyWith(isSaving: false);
      return TemplateSaveResult.failed;
    }
  }
}

/// AutoDispose so each opened editor starts fresh and is torn down when the
/// editor screen leaves the tree.
final templateEditorProvider = StateNotifierProvider.autoDispose<
    TemplateEditorNotifier, TemplateEditorState>(
  (ref) => TemplateEditorNotifier(ref),
);
