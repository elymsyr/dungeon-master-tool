import '../entities/entity.dart';
import '../entities/schema/encounter_config.dart';
import '../entities/schema/entity_category_schema.dart';
import '../entities/schema/field_schema.dart';
import '../entities/schema/world_schema.dart';
import 'free_field_styles.dart';
import 'free_template.dart' show isFreeTemplate;
import 'template_edit.dart' show presetById;

/// The free template's encounter and battle map (docs/free-template/DESIGN.md
/// §14): what the session tab reads from the template where the built-in
/// path has fixed keys and slugs. Built-in schemas pass through as they
/// are. Pure.

/// `allowedInSections` value of a category whose cards join the encounter.
const encounterSection = 'encounter';

/// The encounter table's Conditions column (session tab sentinel).
const encounterConditionsColumn = '__conditions__';

/// Where a built-in world picks battle maps from: Location's maps.
const builtinBattlemapFields = {
  'location': ['battlemaps', 'map', 'map_per_era'],
};

/// Image fields a battle map can come from (DESIGN §14.6).
bool isBattlemapFieldType(FieldType t) =>
    t == FieldType.image || t == FieldType.imagePerEra;

/// [cat]'s Combat stats block (DESIGN §8.6), or null.
FieldSchema? combatBlockOf(EntityCategorySchema cat) =>
    cat.fields.where(isCombatBlock).firstOrNull;

/// Categories whose cards join the encounter (DESIGN §14.1); the player
/// card always does.
List<EntityCategorySchema> encounterCategories(WorldSchema s) => [
  for (final c in s.categories)
    if (c.isPlayerCard == true || c.allowedInSections.contains(encounterSection))
      c,
];

/// The Combat stats preset the encounter reads (DESIGN §14.2), or null
/// when none is chosen (or it is gone): then the table has only HP.
FieldSchema? encounterPreset(WorldSchema s) {
  final p = presetById(s, s.encounterConfig.combatPresetId);
  return p != null && p.fieldType == FieldType.combatStats ? p : null;
}

/// The encounter preset's values, in its order: every card's block is
/// bound to it, so a key means the same column in every row.
List<CombatValue> encounterValues(WorldSchema s) => switch (encounterPreset(s)) {
  final p? => CombatStatsSpec.of(p).values,
  null => const [],
};

/// The Number or Dice value the table sorts by and initiative rolls
/// (DESIGN §14.3), or null.
CombatValue? encounterSortValue(WorldSchema s) {
  final key = s.encounterConfig.sortBySubField;
  return encounterValues(
    s,
  ).where((v) => v.key == key && v.type != CombatValueType.cards).firstOrNull;
}

/// The card list behind the Conditions column, when it is shown (§14.5).
CombatValue? encounterConditionsValue(WorldSchema s) => encounterValues(
  s,
).where((v) => v.type == CombatValueType.cards && v.encounter).firstOrNull;

/// The encounter config the session tab reads. A free template's columns
/// come from the blocks (DESIGN §14.2): the sort value, the other shown
/// values in block order, HP (always, with −/+), then Conditions.
EncounterConfig encounterConfigOf(WorldSchema s) {
  if (!isFreeTemplate(s)) return s.encounterConfig;
  final sort = encounterSortValue(s);
  final conditions = encounterConditionsValue(s);
  final preset = encounterPreset(s);
  final hpLabel = preset == null ? null : CombatStatsSpec.of(preset).hpLabel;
  EncounterColumnConfig column(CombatValue v) => EncounterColumnConfig(
    subFieldKey: v.key,
    label: v.label,
    editable: v.editable,
    width: v.width ?? 0,
  );
  return s.encounterConfig.copyWith(
    initiativeSubField: sort?.key ?? '',
    sortBySubField: sort?.key ?? '',
    columns: [
      if (sort != null) column(sort),
      for (final v in encounterValues(s))
        if (v.encounter && v.type != CombatValueType.cards && v.key != sort?.key)
          column(v),
      EncounterColumnConfig(
        subFieldKey: combatHpKey,
        label: hpLabel ?? 'HP',
        editable: true,
        showButtons: true,
        width: 130,
      ),
      if (conditions != null)
        EncounterColumnConfig(
          subFieldKey: encounterConditionsColumn,
          label: conditions.label,
        ),
    ],
  );
}

/// Whether the encounter can roll initiative (V18): a Dice sort value, or a
/// Number one with the template's dice. Built-in worlds always can.
bool canRollEncounter(WorldSchema s) {
  if (!isFreeTemplate(s)) return true;
  final v = encounterSortValue(s);
  if (v == null) return false;
  return v.type == CombatValueType.dice ||
      (s.encounterConfig.sortDice?.trim().isNotEmpty ?? false);
}

/// A card's encounter values (DESIGN §14.4): its block's values as the card
/// shows them (§16.3), HP as text like the built-in snapshot. A blank
/// current HP is the Max HP; a card without a block comes in with empty HP.
({int hp, int maxHp, Map<String, dynamic> stats}) freeCombatantValues(
  WorldSchema s,
  Entity e,
) {
  final cat = s.categories.where((c) => c.slug == e.categorySlug).firstOrNull;
  final block = cat == null ? null : combatBlockOf(cat);
  if (block == null) return (hp: 0, maxHp: 0, stats: <String, dynamic>{});
  final stats = combatStatsValue(e.fields[block.fieldKey], e.fields);
  final current = combatNumber(stats[combatHpKey]);
  final max = combatNumber(stats[combatMaxHpKey]) ?? current ?? 0;
  final hp = (current ?? max).clamp(0, max);
  return (
    hp: hp,
    maxHp: max,
    stats: {...stats, combatHpKey: '$hp', combatMaxHpKey: '$max'},
  );
}

/// The dice spec of [stats]' sort value (V18): a Dice value as it is, a
/// Number one after the template's dice (`1d20+3`). Its flat part is the
/// value a combatant starts with. Null when there is no value.
String? freeSortSpec(WorldSchema s, Map<String, dynamic> stats) {
  final v = encounterSortValue(s);
  if (v == null) return null;
  final raw = stats[v.key];
  if (v.type == CombatValueType.dice) {
    final t = '${raw ?? ''}'.trim();
    return t.isEmpty ? null : t;
  }
  final n = combatNumber(raw);
  final dice = s.encounterConfig.sortDice?.trim() ?? '';
  if (dice.isEmpty) return n?.toString();
  if (n == null) return dice;
  return n < 0 ? '$dice$n' : '$dice+$n';
}

/// The block key of a card in [slug] (where the encounter writes a player's
/// values back, DESIGN §14.4), or null.
String? combatBlockKey(WorldSchema s, String slug) {
  final cat = s.categories.where((c) => c.slug == slug).firstOrNull;
  return cat == null ? null : combatBlockOf(cat)?.fieldKey;
}

/// Category slug → image fields a battle map can be picked from (§14.6).
Map<String, List<String>> battlemapFieldsOf(WorldSchema s) => isFreeTemplate(s)
    ? s.encounterConfig.battlemapFields ?? const {}
    : builtinBattlemapFields;

/// The images [e]'s [keys] hold, in order, once each: a single image, an
/// image list or per-era images.
List<String> battlemapImages(Entity e, List<String> keys) {
  final out = <String>{};
  void add(Object? v) {
    if (v is String && v.isNotEmpty) out.add(v);
  }

  for (final k in keys) {
    final v = e.fields[k];
    if (v is List) v.forEach(add);
    if (v is Map) v.values.forEach(add);
    add(v);
  }
  return out.toList();
}
