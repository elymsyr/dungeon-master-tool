import '../encounter_config.dart';
import '../encounter_layout.dart';
import '../entity_category_schema.dart';
import '../world_schema.dart';
import 'content.dart';
import 'dm.dart';
import 'lookups.dart';
import 'rules.dart';

/// Schema id for the v2 built-in D&D 5e template.
/// Lives beside `builtin-dnd5e-default` (v1) per design §9 #6 —
/// old campaigns keep working against v1; new campaigns opt into v2.
const builtinDnd5eV2SchemaId = 'builtin-dnd5e-default-v2';

/// Globally stable lineage identifier for the v2 template.
/// Bump the suffix for a breaking re-shape.
const builtinDnd5eV2OriginalHash = 'builtin-dnd5e-default-v2';

/// Generate the v2 D&D 5e [WorldSchema].
/// Ships Tier 0 lookups (36) + Tier 1 content shapes (18) + Tier 2 DM
/// categories (13) = 67 total.
/// Tier 1 row content (classes, spells, monsters, …) ships via the
/// separate `srd_core.dnd5e-pkg.json` content pack per design §6.
/// Tier 2 DM categories are user-authored at runtime — never seeded.
BuiltinDnd5eV2Build generateBuiltinDnd5eV2Schema() {
  final now = DateTime.now().toUtc().toIso8601String();
  const schemaId = builtinDnd5eV2SchemaId;

  final tier0 = buildTier0Lookups(schemaId: schemaId, now: now);
  final tier1 = buildTier1Content(
    schemaId: schemaId,
    now: now,
    startOrderIndex: tier0.length,
  );
  final tier2 = buildTier2Dm(
    schemaId: schemaId,
    now: now,
    startOrderIndex: tier0.length + tier1.length,
  );

  final categoriesRaw = <EntityCategorySchema>[
    for (final t in tier0) t.category,
    ...tier1,
    ...tier2,
  ];

  final ruleSet = buildBuiltinRules();
  final categories = attachBuiltinRules(categoriesRaw, ruleSet);

  final seedRows = <String, List<Map<String, dynamic>>>{
    for (final t in tier0) t.category.slug: t.seedRows,
    // Tier-1 categories ship shape only; rows come from srd_core content pack.
    for (final c in tier1) c.slug: const <Map<String, dynamic>>[],
    // Tier-2 DM categories are user-authored — never seeded.
    for (final c in tier2) c.slug: const <Map<String, dynamic>>[],
  };

  final schema = WorldSchema(
    schemaId: schemaId,
    name: 'D&D 5e (SRD 5.2.1)',
    version: '2.3.0',
    baseSystem: 'dnd5e',
    description:
        'Built-in D&D 5e template aligned with SRD 5.2.1 (CC-BY-4.0). '
        'Ships Tier 0 lookup catalogs (abilities, skills, damage types, '
        'conditions, etc.). Tier 1 content and Tier 2 DM categories land '
        'in subsequent phases.',
    categories: categories,
    encounterLayouts: [_defaultEncounterLayout(schemaId, now)],
    encounterConfig: _defaultEncounterConfig(),
    createdAt: now,
    updatedAt: now,
    originalHash: builtinDnd5eV2OriginalHash,
  );

  return BuiltinDnd5eV2Build(schema: schema, seedRows: seedRows);
}

/// Generator output: the [WorldSchema] plus the canonical seed rows for
/// every Tier-0 category, keyed by slug. Bootstrap consumes [seedRows] to
/// insert Entity records with `isBuiltin=true` on first launch.
class BuiltinDnd5eV2Build {
  final WorldSchema schema;
  final Map<String, List<Map<String, dynamic>>> seedRows;
  const BuiltinDnd5eV2Build({required this.schema, required this.seedRows});
}

EncounterConfig _defaultEncounterConfig() {
  // v2 encounter config references the condition catalog at runtime —
  // hardcoded names from v1 are replaced by lookups at the UI layer.
  return const EncounterConfig(
    combatStatsFieldKey: 'combat_stats',
    conditionStatsFieldKey: 'condition_stats',
    statBlockFieldKey: 'stat_block',
    initiativeSubField: 'initiative',
    sortBySubField: 'initiative',
    sortDirection: 'desc',
    columns: [
      EncounterColumnConfig(subFieldKey: 'level', label: 'Lvl', editable: true, width: 36),
      EncounterColumnConfig(subFieldKey: 'initiative', label: 'Init', editable: true, width: 48),
      EncounterColumnConfig(subFieldKey: 'ac', label: 'AC', editable: true, width: 36),
      EncounterColumnConfig(subFieldKey: 'hp', label: 'HP', editable: true, showButtons: true, width: 130),
    ],
    // Left empty — runtime reads condition rows from the catalog.
    conditions: [],
  );
}

EncounterLayout _defaultEncounterLayout(String schemaId, String now) {
  // Deterministic layoutId so exports land on the same id across installs.
  return EncounterLayout(
    layoutId: '$schemaId-layout-standard',
    schemaId: schemaId,
    name: 'Standard D&D 5e',
    columns: const [
      EncounterColumn(fieldKey: 'name', displayLabel: 'Name', width: 150),
      EncounterColumn(fieldKey: 'initiative', displayLabel: 'Init', width: 50, isEditable: true),
      EncounterColumn(fieldKey: 'ac', displayLabel: 'AC', width: 50),
      EncounterColumn(fieldKey: 'hp', displayLabel: 'HP', width: 120, isEditable: true, formatTemplate: '{value}/{max_value}'),
      EncounterColumn(fieldKey: 'conditions', displayLabel: 'Conditions', width: 0),
    ],
    sortRules: const [
      SortRule(fieldKey: 'initiative', direction: 'desc', priority: 0),
    ],
  );
}
