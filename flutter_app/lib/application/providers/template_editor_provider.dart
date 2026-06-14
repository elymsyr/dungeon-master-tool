import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/services/template_migration/template_validator.dart';
import 'template_provider.dart';

// Re-export the shared template-validation vocabulary + entry point so the
// editor UI (and the per-type typeConfig sub-forms) keep importing these from
// the provider, while the single source of truth lives in the Flutter-free
// domain library (`template_validator.dart`) that the offline `dart run`
// tooling — `tool/validate_template.dart` / `tool/convert_packs_v3.dart` —
// also consumes. JIT wave PRs therefore dogfood the editor's exact validator.
export '../../domain/services/template_migration/template_validator.dart'
    show
        templateSlugPattern,
        reservedCategorySlugs,
        categorySlugify,
        templateFieldKeyPattern,
        reservedFieldKeys,
        fieldKeyNormalize,
        combatStatsCanonicalKeys,
        pouchSourceKinds,
        recordListColumnKinds,
        actionButtonActions,
        levelUpTableGates,
        skillTreeTiers,
        ruleCapableTypes,
        validateTemplateCategories;

const _uuid = Uuid();

/// Sentinel distinguishing "argument omitted" from an explicit `null` in the
/// field mutators (so a nullable attribute like `groupId` can be *cleared*).
const Object _unset = Object();

// The template-validation vocabulary (slug/field-key grammar, the closed
// typeConfig value sets, `ruleCapableTypes`) and the `validateTemplateCategories`
// entry point now live in the Flutter-free `template_validator.dart` and are
// re-exported above, so the editor UI keeps its imports while the `dart run`
// tooling shares the exact same rules.

/// Seeds a valid default `typeConfig` for a parametric [type] so a freshly
/// added field is immediately save-valid (never flashes a completeness error)
/// and its sub-form opens on sensible values. Returns `null` for types that
/// carry no parametric payload (scalars, media, relation, levelMatrix, …).
///
/// The defaults mirror the built-in D&D template's shapes (the-template-system
/// §2.3) — the creator edits them in the inspector's type-config form.
Map<String, dynamic>? defaultTypeConfig(FieldType type) {
  switch (type) {
    case FieldType.abilityScoreTable:
    case FieldType.statBlock:
      return {
        'columns': [
          {'key': 'str', 'label': 'STR'},
          {'key': 'dex', 'label': 'DEX'},
          {'key': 'con', 'label': 'CON'},
          {'key': 'int', 'label': 'INT'},
          {'key': 'wis', 'label': 'WIS'},
          {'key': 'cha', 'label': 'CHA'},
        ],
        'modifierBase': 10,
        'modifierStep': 2,
        'publishAspects': true,
      };
    case FieldType.combatStatsTable:
    case FieldType.combatStats:
      return {
        'visibleKeys': ['hp', 'max_hp', 'ac', 'initiative', 'level'],
      };
    case FieldType.intPouch:
      return {
        'maxSource': {'kind': 'manual'},
      };
    case FieldType.checkboxPouch:
    case FieldType.slot:
      return {
        'countSource': {'kind': 'fixed', 'value': 3},
        'style': 'pips',
      };
    case FieldType.pouchMatrix:
    case FieldType.spellSlotGrid:
      return {
        'rowKeys': ['1', '2', '3'],
        'rowLabelPrefix': 'Level ',
        'maxSource': {'kind': 'manual'},
      };
    case FieldType.skillTree:
    case FieldType.proficiencyTable:
      return {
        'abilityFieldKey': 'stat_block',
        'proficiencyBonusAspect': 'prof_bonus',
        'rowSeed': 'skill',
        'tiers': ['proficient', 'expertise'],
      };
    case FieldType.recordList:
      return {
        'columns': [
          {'key': 'name', 'label': 'Name', 'kind': 'text'},
        ],
      };
    case FieldType.levelUpTable:
      return {'gate': 'class'};
    case FieldType.actionButton:
      return {'action': 'level_up', 'placement': 'header'};
    default:
      return null;
  }
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
      errors: validateTemplateCategories(categories),
      selectedCategoryId: selectedCategoryId ?? state.selectedCategoryId,
      selectedFieldId: clearFieldSelection ? null : state.selectedFieldId,
    );
  }

  // --- Field CRUD (PR-2.2) ----------------------------------------------------
  //
  // Mirrors the category mutators: each rebuilds the selected category's field
  // list, rebuilds the draft `WorldSchema`, marks dirty, and recomputes the
  // combined category+field validation surfaced in [TemplateEditorState.errors]
  // (field-key uniqueness within the category, reserved keys, empty labels).

  /// Appends a new field of [type] to [categoryId] and selects it. The label and
  /// key are seeded to sensible, in-category-unique defaults the user edits in
  /// the inspector. `orderIndex` is placed after the current last field.
  void addField(String categoryId, FieldType type) {
    final schema = state.schema;
    if (schema == null || !state.canEdit) return;
    final catIndex =
        schema.categories.indexWhere((c) => c.categoryId == categoryId);
    if (catIndex < 0) return;
    final category = schema.categories[catIndex];
    final now = _now();
    final base = _humanizeType(type);
    final key = _uniqueFieldKey(
      fieldKeyNormalize(base),
      {for (final f in category.fields) f.fieldKey},
    );
    final maxOrder = category.fields.fold<int>(
      -1,
      (m, f) => f.orderIndex > m ? f.orderIndex : m,
    );
    final field = FieldSchema(
      fieldId: 'fld-${_uuid.v4()}',
      categoryId: categoryId,
      fieldKey: key,
      label: base,
      fieldType: type,
      orderIndex: maxOrder + 1,
      isBuiltin: false,
      // Parametric types open on a valid default config so the field is
      // immediately save-valid and its sub-form has something to edit.
      typeConfig: defaultTypeConfig(type),
      createdAt: now,
      updatedAt: now,
    );
    final nextFields = [...category.fields, field];
    _commitFields(
      catIndex,
      nextFields,
      selectField: field.fieldId,
    );
  }

  /// Edits a field's core attributes (any subset). Untouched arguments are left
  /// as-is. The key is re-normalized when provided; pass `groupId: null` (via
  /// the sentinel default being overridden with an explicit `null`) to clear the
  /// group assignment.
  void updateFieldMeta(
    String categoryId,
    String fieldId, {
    String? label,
    String? fieldKey,
    bool? isRequired,
    bool? isList,
    bool? hasEquip,
    FieldVisibility? visibility,
    Object? groupId = _unset,
    int? gridColumnSpan,
    String? placeholder,
    String? helpText,
  }) {
    final schema = state.schema;
    if (schema == null || !state.canEdit) return;
    final catIndex =
        schema.categories.indexWhere((c) => c.categoryId == categoryId);
    if (catIndex < 0) return;
    final category = schema.categories[catIndex];
    final now = _now();
    var changed = false;
    final nextFields = <FieldSchema>[];
    for (final f in category.fields) {
      if (f.fieldId != fieldId) {
        nextFields.add(f);
        continue;
      }
      changed = true;
      nextFields.add(f.copyWith(
        label: label ?? f.label,
        fieldKey: fieldKey == null ? f.fieldKey : fieldKeyNormalize(fieldKey),
        isRequired: isRequired ?? f.isRequired,
        isList: isList ?? f.isList,
        hasEquip: hasEquip ?? f.hasEquip,
        visibility: visibility ?? f.visibility,
        groupId: groupId == _unset ? f.groupId : groupId as String?,
        gridColumnSpan: gridColumnSpan ?? f.gridColumnSpan,
        placeholder: placeholder ?? f.placeholder,
        helpText: helpText ?? f.helpText,
        updatedAt: now,
      ));
    }
    if (!changed) return;
    _commitFields(catIndex, nextFields);
  }

  /// Replaces a field's per-type `typeConfig` payload wholesale (PR-2.2b). The
  /// per-type sub-forms build the full config map and write it through here on
  /// every change; the combined validator ([validateTemplateCategories]) then
  /// flags any incompleteness. An empty map clears the config back to `null`.
  void updateFieldTypeConfig(
    String categoryId,
    String fieldId,
    Map<String, dynamic> typeConfig,
  ) {
    final schema = state.schema;
    if (schema == null || !state.canEdit) return;
    final catIndex =
        schema.categories.indexWhere((c) => c.categoryId == categoryId);
    if (catIndex < 0) return;
    final category = schema.categories[catIndex];
    final now = _now();
    var changed = false;
    final nextFields = <FieldSchema>[];
    for (final f in category.fields) {
      if (f.fieldId != fieldId) {
        nextFields.add(f);
        continue;
      }
      changed = true;
      nextFields.add(f.copyWith(
        typeConfig:
            typeConfig.isEmpty ? null : Map<String, dynamic>.from(typeConfig),
        updatedAt: now,
      ));
    }
    if (!changed) return;
    _commitFields(catIndex, nextFields);
  }

  /// Replaces a field's `rules` attachment list wholesale (PR-3.5a). The
  /// rule-attachment editor builds the full list (add/edit/delete/reorder) and
  /// writes it through here on every change; [validateTemplateCategories] then
  /// flags any rule with an unknown kind/trigger or on a non-rule-capable field.
  /// An empty list clears `rules` back to `null` (the "no rules" wire shape).
  void updateFieldRules(
    String categoryId,
    String fieldId,
    List<Map<String, dynamic>> rules,
  ) {
    final schema = state.schema;
    if (schema == null || !state.canEdit) return;
    final catIndex =
        schema.categories.indexWhere((c) => c.categoryId == categoryId);
    if (catIndex < 0) return;
    final category = schema.categories[catIndex];
    final now = _now();
    var changed = false;
    final nextFields = <FieldSchema>[];
    for (final f in category.fields) {
      if (f.fieldId != fieldId) {
        nextFields.add(f);
        continue;
      }
      changed = true;
      nextFields.add(f.copyWith(
        rules: rules.isEmpty
            ? null
            : [for (final r in rules) Map<String, dynamic>.from(r)],
        updatedAt: now,
      ));
    }
    if (!changed) return;
    _commitFields(catIndex, nextFields);
  }

  /// Removes a field from [categoryId] (hard delete — fields have no archive
  /// flag). Clears the field selection if the removed field was selected.
  void removeField(String categoryId, String fieldId) {
    final schema = state.schema;
    if (schema == null || !state.canEdit) return;
    final catIndex =
        schema.categories.indexWhere((c) => c.categoryId == categoryId);
    if (catIndex < 0) return;
    final category = schema.categories[catIndex];
    final nextFields = [
      for (final f in category.fields)
        if (f.fieldId != fieldId) f,
    ];
    if (nextFields.length == category.fields.length) return;
    _commitFields(
      catIndex,
      nextFields,
      clearSelectionIf: fieldId,
    );
  }

  /// Reorders fields within [categoryId]. Indices follow Flutter's
  /// `ReorderableListView` convention against the **orderIndex-sorted** list
  /// (which is what the field list pane renders); `orderIndex` is renumbered.
  void reorderFields(String categoryId, int oldIndex, int newIndex) {
    final schema = state.schema;
    if (schema == null || !state.canEdit) return;
    final catIndex =
        schema.categories.indexWhere((c) => c.categoryId == categoryId);
    if (catIndex < 0) return;
    final category = schema.categories[catIndex];
    final sorted = [...category.fields]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    if (oldIndex < 0 || oldIndex >= sorted.length) return;
    var insertAt = newIndex;
    if (insertAt > oldIndex) insertAt -= 1;
    if (insertAt < 0) insertAt = 0;
    if (insertAt >= sorted.length) insertAt = sorted.length - 1;
    if (insertAt == oldIndex) return;
    final moved = sorted.removeAt(oldIndex);
    sorted.insert(insertAt, moved);
    final now = _now();
    final renumbered = [
      for (var i = 0; i < sorted.length; i++)
        sorted[i].orderIndex == i
            ? sorted[i]
            : sorted[i].copyWith(orderIndex: i, updatedAt: now),
    ];
    _commitFields(catIndex, renumbered);
  }

  /// Replaces [catIndex]'s field list, marks dirty, recomputes validation, and
  /// optionally updates the field selection.
  void _commitFields(
    int catIndex,
    List<FieldSchema> fields, {
    String? selectField,
    String? clearSelectionIf,
  }) {
    final schema = state.schema;
    if (schema == null) return;
    final categories = [...schema.categories];
    categories[catIndex] = categories[catIndex].copyWith(fields: fields);
    final updated = schema.copyWith(categories: categories);
    final clearSel =
        clearSelectionIf != null && state.selectedFieldId == clearSelectionIf;
    state = state.copyWith(
      schema: updated,
      isDirty: true,
      errors: validateTemplateCategories(categories),
      selectedFieldId: selectField ?? (clearSel ? null : state.selectedFieldId),
    );
  }

  /// Seeds a human-readable default label from a [FieldType] (`intPouch` →
  /// "Int Pouch"). The user renames it immediately; this just avoids an empty
  /// label flashing as a validation error on add.
  static String _humanizeType(FieldType type) {
    final name = type.name.replaceAll('_', '');
    final buf = StringBuffer();
    for (var i = 0; i < name.length; i++) {
      final ch = name[i];
      if (i > 0 && ch.toUpperCase() == ch && ch.toLowerCase() != ch) {
        buf.write(' ');
      }
      buf.write(i == 0 ? ch.toUpperCase() : ch);
    }
    return buf.toString();
  }

  /// Returns [base] if free within [existing], else suffixes `_2`, `_3`, … .
  static String _uniqueFieldKey(String base, Set<String> existing) {
    final seed = base.isEmpty ? 'field' : base;
    if (!existing.contains(seed)) return seed;
    var n = 2;
    while (existing.contains('${seed}_$n')) {
      n++;
    }
    return '${seed}_$n';
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
