import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import 'template_provider.dart';

const _uuid = Uuid();

/// Lowercase slug grammar shared by category and (later) field-key validation:
/// a–z, 0–9 and single hyphens, never leading/trailing a hyphen.
final RegExp templateSlugPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

/// Category slugs the editor refuses to mint/rename onto. The slug is the stable
/// import-matching key (a renamed category must still receive its pack rows — see
/// [package_import_service]); these tokens are reserved so a user slug can never
/// shadow an internal sentinel. Intentionally small — extend as internals grow.
const Set<String> reservedCategorySlugs = {'__proto__', 'constructor', 'prototype'};

/// Normalizes free text into a [templateSlugPattern]-valid slug. Empty when the
/// input has no slug-able characters (the validator then flags it).
String categorySlugify(String input) {
  final lowered = input.trim().toLowerCase();
  final hyphenated =
      lowered.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'-+'), '-');
  return hyphenated.replaceAll(RegExp(r'^-+|-+$'), '');
}

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

  // --- Category CRUD (PR-2.1) -------------------------------------------------
  //
  // Every mutator rebuilds the draft `WorldSchema` via `copyWith`, marks the
  // draft dirty, and recomputes the blocking validation errors. The Save flow
  // already refuses to persist while `errors` is non-empty.

  /// Appends a new editable category and selects it. Slug is normalized so the
  /// caller can pass either a hand-typed slug or raw text; validation still runs
  /// (empty/duplicate/reserved/format) and surfaces in [TemplateEditorState.errors].
  void addCategory({
    required String name,
    required String slug,
    String icon = '',
    String color = '#808080',
  }) {
    final schema = state.schema;
    if (schema == null || !state.canEdit) return;
    final now = _now();
    final category = EntityCategorySchema(
      categoryId: 'cat-${_uuid.v4()}',
      schemaId: schema.schemaId,
      name: name.trim(),
      slug: categorySlugify(slug.isEmpty ? name : slug),
      icon: icon.trim(),
      color: color,
      isBuiltin: false,
      orderIndex: schema.categories.length,
      createdAt: now,
      updatedAt: now,
    );
    final next = [...schema.categories, category];
    _commitCategories(
      next,
      selectedCategoryId: category.categoryId,
      clearFieldSelection: true,
    );
  }

  /// Edits a category's metadata (any subset of name/slug/icon/color). Untouched
  /// arguments are left as-is. The slug is re-normalized when provided.
  void updateCategoryMeta(
    String categoryId, {
    String? name,
    String? slug,
    String? icon,
    String? color,
  }) {
    final schema = state.schema;
    if (schema == null || !state.canEdit) return;
    final now = _now();
    var changed = false;
    final next = <EntityCategorySchema>[];
    for (final c in schema.categories) {
      if (c.categoryId != categoryId) {
        next.add(c);
        continue;
      }
      changed = true;
      next.add(c.copyWith(
        name: name?.trim() ?? c.name,
        slug: slug == null ? c.slug : categorySlugify(slug),
        icon: icon?.trim() ?? c.icon,
        color: color ?? c.color,
        updatedAt: now,
      ));
    }
    if (!changed) return;
    _commitCategories(next);
  }

  /// Toggles a category's archived flag (the editor's soft-delete — archived
  /// categories stay in the template but are hidden from authoring surfaces).
  void toggleCategoryArchived(String categoryId) {
    final schema = state.schema;
    if (schema == null || !state.canEdit) return;
    final now = _now();
    final next = [
      for (final c in schema.categories)
        if (c.categoryId == categoryId)
          c.copyWith(isArchived: !c.isArchived, updatedAt: now)
        else
          c,
    ];
    _commitCategories(next);
  }

  /// Reorders the category list (drag-and-drop). [newIndex] follows Flutter's
  /// `ReorderableListView` convention (it is the pre-removal insertion index).
  /// `orderIndex` is renumbered to match the new list order.
  void reorderCategories(int oldIndex, int newIndex) {
    final schema = state.schema;
    if (schema == null || !state.canEdit) return;
    final list = [...schema.categories];
    if (oldIndex < 0 || oldIndex >= list.length) return;
    var insertAt = newIndex;
    if (insertAt > oldIndex) insertAt -= 1;
    if (insertAt < 0) insertAt = 0;
    if (insertAt >= list.length) insertAt = list.length - 1;
    if (insertAt == oldIndex) return;
    final moved = list.removeAt(oldIndex);
    list.insert(insertAt, moved);
    final now = _now();
    final renumbered = [
      for (var i = 0; i < list.length; i++)
        list[i].orderIndex == i ? list[i] : list[i].copyWith(orderIndex: i, updatedAt: now),
    ];
    _commitCategories(renumbered);
  }

  /// Replaces the draft categories, marks dirty, and recomputes validation.
  /// Optionally updates the active selection (used by [addCategory]).
  void _commitCategories(
    List<EntityCategorySchema> categories, {
    String? selectedCategoryId,
    bool clearFieldSelection = false,
  }) {
    final schema = state.schema;
    if (schema == null) return;
    final updated = schema.copyWith(categories: categories);
    state = state.copyWith(
      schema: updated,
      isDirty: true,
      errors: _validateCategories(categories),
      selectedCategoryId: selectedCategoryId ?? state.selectedCategoryId,
      selectedFieldId: clearFieldSelection ? null : state.selectedFieldId,
    );
  }

  /// Blocking category validation: empty names, empty/malformed/reserved slugs,
  /// and duplicate slugs (the import-matching key must be unique).
  static List<String> _validateCategories(List<EntityCategorySchema> categories) {
    final errors = <String>[];
    final slugCounts = <String, int>{};
    for (final c in categories) {
      final label = c.name.trim().isEmpty ? '(unnamed)' : c.name.trim();
      if (c.name.trim().isEmpty) {
        errors.add('A category has an empty name.');
      }
      final slug = c.slug.trim();
      if (slug.isEmpty) {
        errors.add('Category "$label" has an empty slug.');
      } else if (!templateSlugPattern.hasMatch(slug)) {
        errors.add(
          'Category "$label" slug "$slug" must be lowercase letters, '
          'numbers and single hyphens.',
        );
      } else if (reservedCategorySlugs.contains(slug)) {
        errors.add('Category slug "$slug" is reserved.');
      }
      if (slug.isNotEmpty) slugCounts[slug] = (slugCounts[slug] ?? 0) + 1;
    }
    for (final entry in slugCounts.entries) {
      if (entry.value > 1) {
        errors.add('Duplicate category slug "${entry.key}" (used ${entry.value}×).');
      }
    }
    return errors;
  }

  String _now() => DateTime.now().toUtc().toIso8601String();

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
