import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/schema/entity_category_schema.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../../domain/services/template_rules/template_rule_resolver.dart'
    show RuleKinds, RuleTriggers;
import 'template_provider.dart';

const _uuid = Uuid();

/// Sentinel distinguishing "argument omitted" from an explicit `null` in the
/// field mutators (so a nullable attribute like `groupId` can be *cleared*).
const Object _unset = Object();

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

/// Lowercase `snake_case` grammar for field keys: starts with a letter, then
/// letters/digits/single underscores (the wire keys cards store values under —
/// e.g. `rage_uses`, `asi_options`, `spell_slots`). Distinct from the category
/// slug grammar (hyphens) because card attribute maps are conventionally
/// snake_case in this codebase.
final RegExp templateFieldKeyPattern = RegExp(r'^[a-z][a-z0-9_]*$');

/// Field keys the editor refuses to mint/rename onto. These collide with the
/// entity envelope's own identity/format keys (`{id, slug, name, format}` ride
/// beside `attributes`), so a field key must never shadow them.
const Set<String> reservedFieldKeys = {'id', 'slug', 'name', 'format'};

/// Normalizes free text into a [templateFieldKeyPattern]-valid key. Non-alnum
/// runs collapse to single underscores; a leading digit is prefixed with `f_`
/// so the result still starts with a letter. Empty when the input has no
/// key-able characters (the validator then flags it).
String fieldKeyNormalize(String input) {
  final lowered = input.trim().toLowerCase();
  var s = lowered
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (s.isNotEmpty && RegExp(r'^[0-9]').hasMatch(s)) s = 'f_$s';
  return s;
}

// --- typeConfig vocabularies (the-template-system §2.3) ----------------------
//
// Exported so the per-type `typeConfig` sub-forms (PR-2.2b) and the validator
// below share one source of truth for the closed value sets.

/// Canonical `combatStatsTable` keys. The structure is **not** creator-editable
/// (fixed widget semantics); only which keys are *visible* is configurable.
const List<String> combatStatsCanonicalKeys = [
  'hp',
  'max_hp',
  'ac',
  'speed',
  'level',
  'initiative',
  'xp',
];

/// Valid `maxSource`/`countSource` kinds shared by every pouch type (intPouch,
/// checkboxPouch, pouchMatrix).
const List<String> pouchSourceKinds = ['manual', 'fixed', 'levelTable', 'formula'];

/// Valid `recordList` column kinds.
const List<String> recordListColumnKinds = [
  'text',
  'int',
  'float',
  'dice',
  'bool',
  'enum',
  'ref',
];

/// Valid `actionButton` actions (the button label is creator-editable; the
/// process each one runs is fixed).
const List<String> actionButtonActions = ['level_up', 'short_rest', 'long_rest'];

/// Valid `levelUpTable` gates.
const List<String> levelUpTableGates = ['class', 'character'];

/// Valid `skillTree` proficiency tiers.
const List<String> skillTreeTiers = ['proficient', 'expertise'];

/// Field types that may carry rule attachments (master-roadmap §2.1 "Rule
/// capability"). Mirrors the `ruleCapable` flags in `field_type_meta.dart`
/// (the presentation-layer source the badge/picker read) — kept here so the
/// application-layer rule validator and the rule-attachment editor share one
/// closed set without the provider importing presentation. Scalars/media are
/// aspect sources only and are never rule-capable.
const Set<FieldType> ruleCapableTypes = {
  FieldType.relation,
  FieldType.recordList,
  FieldType.intPouch,
  FieldType.checkboxPouch,
  FieldType.pouchMatrix,
  FieldType.abilityScoreTable,
  FieldType.combatStatsTable,
  FieldType.skillTree,
  FieldType.levelMatrix,
  FieldType.levelTable,
  FieldType.levelTextTable,
  FieldType.levelUpTable,
  FieldType.actionButton,
  // Legacy v2 aliases (PR-2.3 swaps their renderers) stay rule-capable so a
  // copied built-in carrying the old type keeps its rules valid.
  FieldType.statBlock,
  FieldType.combatStats,
  FieldType.slot,
  FieldType.proficiencyTable,
  FieldType.spellSlotGrid,
};

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
      errors: _validateAll(categories),
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
  /// every change; the combined validator (`_validateTypeConfig`) then flags any
  /// incompleteness. An empty map clears the config back to `null`.
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
  /// writes it through here on every change; [_validateRules] then flags any
  /// rule with an unknown kind/trigger or attached to a non-rule-capable field.
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
      errors: _validateAll(categories),
      selectedFieldId: selectField ?? (clearSel ? null : state.selectedFieldId),
    );
  }

  /// Combined draft validation = category errors ⊕ field errors ⊕ typeConfig
  /// errors. Both commit paths route through here so the single `errors` list
  /// (and the Save error summary) reflects every blocking problem regardless of
  /// what was edited.
  static List<String> _validateAll(List<EntityCategorySchema> categories) => [
        ..._validateCategories(categories),
        ..._validateFields(categories),
        ..._validateTypeConfig(categories),
        ..._validateRules(categories),
      ];

  /// Blocking rule-attachment validation (PR-3.5a). Each rule must declare a
  /// kind from the closed [RuleKinds] set; an explicit `trigger` (when present)
  /// must be from the closed [RuleTriggers] set; and rules may only be attached
  /// to rule-capable field types (master-roadmap §2.1). The editor only ever
  /// writes valid shapes, but a copied/imported template can carry drift — this
  /// surfaces it in the Save error summary rather than letting the shadow
  /// resolver silently defer it.
  static List<String> _validateRules(List<EntityCategorySchema> categories) {
    final errors = <String>[];
    for (final c in categories) {
      final catLabel = c.name.trim().isEmpty ? '(unnamed)' : c.name.trim();
      for (final f in c.fields) {
        final rules = f.rules;
        if (rules == null || rules.isEmpty) continue;
        final fieldLabel = f.label.trim().isEmpty ? f.fieldKey : f.label.trim();
        final where = '"$fieldLabel" in "$catLabel"';
        if (!ruleCapableTypes.contains(f.fieldType)) {
          errors.add(
              'Field $where is not rule-capable but has ${rules.length} rule(s).');
        }
        for (var i = 0; i < rules.length; i++) {
          final rule = rules[i];
          final kind = (rule['kind'] ?? '').toString();
          if (kind.isEmpty) {
            errors.add('Rule ${i + 1} on $where is missing its kind.');
          } else if (!RuleKinds.all.contains(kind)) {
            errors.add('Rule ${i + 1} on $where has an unknown kind "$kind".');
          }
          final trigger = rule['trigger'];
          if (trigger != null &&
              !RuleTriggers.all.contains(trigger.toString())) {
            errors.add(
                'Rule ${i + 1} on $where has an unknown trigger "$trigger".');
          }
        }
      }
    }
    return errors;
  }

  /// Blocking `typeConfig` completeness validation per parametric field type
  /// (the-template-system §2.3). Non-parametric types contribute nothing.
  static List<String> _validateTypeConfig(
      List<EntityCategorySchema> categories) {
    final errors = <String>[];
    for (final c in categories) {
      final catLabel = c.name.trim().isEmpty ? '(unnamed)' : c.name.trim();
      for (final f in c.fields) {
        final fieldLabel = f.label.trim().isEmpty ? f.fieldKey : f.label.trim();
        final where = '"$fieldLabel" in "$catLabel"';
        final cfg = f.typeConfig;
        // Absent config means a legacy-typed field carried over from a copied
        // built-in (no typeConfig until the PR-2.3 renderer swap) or a
        // non-parametric field — neither is editor-managed, so don't block on
        // it. Every v3 field the editor mints seeds a non-null default config.
        if (cfg == null) continue;
        switch (f.fieldType) {
          case FieldType.abilityScoreTable:
          case FieldType.statBlock:
            _validateConfigColumns(cfg, where, errors, requireKind: false);
            final step = cfg['modifierStep'];
            if (step is num && step == 0) {
              errors.add('Ability scores $where: modifier step cannot be zero.');
            }
            break;
          case FieldType.combatStatsTable:
          case FieldType.combatStats:
            final keys = cfg['visibleKeys'];
            if (keys is! List || keys.isEmpty) {
              errors.add('Combat stats $where needs at least one visible stat.');
            } else {
              for (final k in keys) {
                if (!combatStatsCanonicalKeys.contains(k)) {
                  errors.add('Combat stats $where has an unknown stat key "$k".');
                }
              }
            }
            break;
          case FieldType.intPouch:
            _validatePouchSource(cfg['maxSource'], where, 'max', errors);
            break;
          case FieldType.checkboxPouch:
          case FieldType.slot:
            _validatePouchSource(cfg['countSource'], where, 'count', errors);
            break;
          case FieldType.pouchMatrix:
          case FieldType.spellSlotGrid:
            final rows = cfg['rowKeys'];
            if (rows is! List || rows.isEmpty) {
              errors.add('Pouch matrix $where needs at least one row.');
            }
            _validatePouchSource(cfg['maxSource'], where, 'max', errors);
            break;
          case FieldType.skillTree:
          case FieldType.proficiencyTable:
            final tiers = cfg['tiers'];
            if (tiers is! List || tiers.isEmpty) {
              errors.add('Skill tree $where needs at least one tier.');
            }
            break;
          case FieldType.recordList:
            _validateConfigColumns(cfg, where, errors, requireKind: true);
            break;
          case FieldType.levelUpTable:
            final gate = cfg['gate'];
            if (gate is! String || !levelUpTableGates.contains(gate)) {
              errors.add('Level-up table $where needs a gate (class or character).');
            }
            break;
          case FieldType.actionButton:
            final action = cfg['action'];
            if (action is! String || !actionButtonActions.contains(action)) {
              errors.add(
                  'Action button $where needs an action (level-up / short rest / long rest).');
            }
            break;
          default:
            break;
        }
      }
    }
    return errors;
  }

  /// Shared column-list validation for `abilityScoreTable` and `recordList`:
  /// at least one column, non-empty keys, unique keys, and (records only) a
  /// valid column kind.
  static void _validateConfigColumns(
    Map<String, dynamic>? cfg,
    String where,
    List<String> errors, {
    required bool requireKind,
  }) {
    final cols = cfg?['columns'];
    if (cols is! List || cols.isEmpty) {
      errors.add('$where needs at least one column.');
      return;
    }
    final seen = <String>{};
    for (final col in cols) {
      if (col is! Map) continue;
      final colKey = (col['key'] ?? '').toString().trim();
      if (colKey.isEmpty) {
        errors.add('$where has a column with an empty key.');
      } else if (!seen.add(colKey)) {
        errors.add('$where has a duplicate column key "$colKey".');
      }
      if (requireKind) {
        final kind = (col['kind'] ?? '').toString();
        if (!recordListColumnKinds.contains(kind)) {
          errors.add(
              '$where column "${colKey.isEmpty ? '(unnamed)' : colKey}" has an invalid kind.');
        }
      }
    }
  }

  /// Shared pouch `maxSource`/`countSource` validation across all pouch types.
  static void _validatePouchSource(
    Object? source,
    String where,
    String which,
    List<String> errors,
  ) {
    if (source is! Map) {
      errors.add('$where is missing its $which source.');
      return;
    }
    final kind = (source['kind'] ?? '').toString();
    if (!pouchSourceKinds.contains(kind)) {
      errors.add('$where $which source has an invalid kind "$kind".');
      return;
    }
    switch (kind) {
      case 'fixed':
        if (source['value'] is! num) {
          errors.add('$where $which source (fixed) needs a number.');
        }
        break;
      case 'formula':
        final expr = (source['expr'] ?? '').toString().trim();
        if (expr.isEmpty) {
          errors.add('$where $which source (formula) needs an expression.');
        }
        break;
      case 'levelTable':
        final table = source['table'];
        if (table is! Map || table.isEmpty) {
          errors.add(
              '$where $which source (level table) needs at least one entry.');
        }
        break;
      case 'manual':
        break;
    }
  }

  /// Blocking field validation, scoped per category: empty labels, and
  /// empty/malformed/reserved/duplicate field keys (the per-card value key must
  /// be unique within its category).
  static List<String> _validateFields(List<EntityCategorySchema> categories) {
    final errors = <String>[];
    for (final c in categories) {
      final catLabel = c.name.trim().isEmpty ? '(unnamed)' : c.name.trim();
      final keyCounts = <String, int>{};
      for (final f in c.fields) {
        final fieldLabel =
            f.label.trim().isEmpty ? f.fieldKey : f.label.trim();
        if (f.label.trim().isEmpty) {
          errors.add('Field "${f.fieldKey}" in "$catLabel" has an empty label.');
        }
        final key = f.fieldKey.trim();
        if (key.isEmpty) {
          errors.add('Field "$fieldLabel" in "$catLabel" has an empty key.');
        } else if (!templateFieldKeyPattern.hasMatch(key)) {
          errors.add(
            'Field key "$key" in "$catLabel" must be lowercase snake_case '
            '(letter first, then letters, numbers and single underscores).',
          );
        } else if (reservedFieldKeys.contains(key)) {
          errors.add('Field key "$key" in "$catLabel" is reserved.');
        }
        if (key.isNotEmpty) keyCounts[key] = (keyCounts[key] ?? 0) + 1;
      }
      for (final entry in keyCounts.entries) {
        if (entry.value > 1) {
          errors.add(
            'Duplicate field key "${entry.key}" in "$catLabel" '
            '(used ${entry.value}×).',
          );
        }
      }
    }
    return errors;
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
