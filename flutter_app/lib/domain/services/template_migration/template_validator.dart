/// Template v3 structural validator — the single source of truth for "is this
/// template well-formed?" (master-roadmap §1.5 "Validation surfacing").
///
/// This is a **pure, Flutter-free** domain library so the SAME rules run in two
/// places, dogfooding each other (content-convert §Tooling / roadmap §3 "JIT
/// dogfoods the editor's validator"):
///
///   1. the responsive Template Editor — `TemplateEditorNotifier` re-exports
///      these symbols and calls [validateTemplateCategories] on every commit so
///      blocking problems surface in the Save error summary; and
///   2. the offline CLI `tool/convert_packs_v3.dart`/`tool/validate_template.dart`,
///      which every JIT wave PR must pass (master-roadmap §3 "Per-wave review
///      gate") — it parses a template JSON asset into a [WorldSchema] and runs
///      this exact validator.
///
/// Keeping it here (domain layer, no `package:flutter`) lets the `dart run`
/// tooling import it directly — the editor provider lives in the application
/// layer and pulls in Riverpod, which `dart run` cannot resolve.
///
/// All checks are **blocking** (they belong in the Save error summary / fail the
/// CLI). Non-blocking amber warnings (e.g. a rule referencing a missing
/// `fieldKey`, master-roadmap §1.5 / Phase 3) are surfaced elsewhere and are not
/// part of this list.
library;

import '../../entities/schema/entity_category_schema.dart';
import '../../entities/schema/field_schema.dart';
import '../template_rules/template_rule_resolver.dart' show RuleKinds, RuleTriggers;

// --- slug / field-key grammar -----------------------------------------------

/// Lowercase slug grammar shared by category and (later) field-key validation:
/// a–z, 0–9 and single hyphens, never leading/trailing a hyphen.
final RegExp templateSlugPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

/// Category slugs the editor refuses to mint/rename onto. The slug is the stable
/// import-matching key (a renamed category must still receive its pack rows —
/// see `package_import_service`); these tokens are reserved so a user slug can
/// never shadow an internal sentinel. Intentionally small — extend as internals
/// grow.
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
// The closed value sets every parametric `typeConfig` sub-form (PR-2.2b) and the
// validator below share one source of truth for.

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
/// rule validator and the rule-attachment editor share one closed set without
/// the domain importing presentation. Scalars/media are aspect sources only and
/// are never rule-capable.
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

// --- validation entry point --------------------------------------------------

/// Combined template validation = category errors ⊕ field errors ⊕ typeConfig
/// errors ⊕ rule errors. The editor's commit paths and the CLI both route
/// through here so the one error list reflects every blocking problem regardless
/// of what was edited. Returns an empty list for a well-formed template.
List<String> validateTemplateCategories(List<EntityCategorySchema> categories) => [
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
/// surfaces it in the Save error summary (and fails the CLI) rather than letting
/// the shadow resolver silently defer it.
List<String> _validateRules(List<EntityCategorySchema> categories) {
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
        if (trigger != null && !RuleTriggers.all.contains(trigger.toString())) {
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
List<String> _validateTypeConfig(List<EntityCategorySchema> categories) {
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
void _validateConfigColumns(
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
void _validatePouchSource(
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
List<String> _validateFields(List<EntityCategorySchema> categories) {
  final errors = <String>[];
  for (final c in categories) {
    final catLabel = c.name.trim().isEmpty ? '(unnamed)' : c.name.trim();
    final keyCounts = <String, int>{};
    for (final f in c.fields) {
      final fieldLabel = f.label.trim().isEmpty ? f.fieldKey : f.label.trim();
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

/// Blocking category validation: empty names, empty/malformed/reserved slugs,
/// and duplicate slugs (the import-matching key must be unique).
List<String> _validateCategories(List<EntityCategorySchema> categories) {
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
