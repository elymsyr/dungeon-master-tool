// Builders + placeholder helpers shared across the hand-authored SRD 5.2.1
// content pack files in this directory.
//
// Tier-0 references → `lookup(slug, name)` placeholder, resolved at import
// time against the campaign's seeded Tier-0 entities.
// Inter-Tier-1 references → `ref(slug, name)` placeholder, resolved during
// pack-build against the freshly minted Tier-1 UUIDs.

import '../../dnd5e_constants.dart';

/// Tier-0 lookup placeholder (resolved at import time).
Map<String, String> lookup(String slug, String name) =>
    {'_lookup': slug, 'name': name};

/// Inter-Tier-1 reference placeholder (resolved during pack-build).
Map<String, String> ref(String slug, String name) =>
    {'_ref': slug, 'name': name};

/// equipmentChoiceGroups option item entry: `{ref, quantity}`.
Map<String, dynamic> eqItem(String slug, String name, {int qty = 1}) =>
    {'ref': ref(slug, name), 'quantity': qty};

/// equipmentChoiceGroups option: `{option_id, label, items, gold_gp?}`.
Map<String, dynamic> eqOption({
  required String optionId,
  required String label,
  List<Map<String, dynamic>> items = const [],
  int? goldGp,
}) => {
  'option_id': optionId,
  'label': label,
  'items': items,
  'gold_gp': ?goldGp,
};

/// equipmentChoiceGroups group: `{group_id, label, prompt, options}`.
Map<String, dynamic> eqGroup({
  required String groupId,
  required String label,
  String prompt = 'Choose one',
  required List<Map<String, dynamic>> options,
}) => {
  'group_id': groupId,
  'label': label,
  'prompt': prompt,
  'options': options,
};

/// Row-level key carrying a class-feature feat's placement on its source
/// card. **Build-time only** — `buildSrdCorePack` consumes and strips it, so
/// it never reaches the entity's `attributes` and is not a schema field. The
/// leading underscore keeps it out of the wire format by convention.
const srdFeatureGrantKey = '_feature_grant';

/// Tag [row] with the Class / Subclass `features` row that grants it. The
/// pack builder reads this and writes `granted_feat_refs` onto that row, so
/// the level a feature arrives at is stored **once**, on the class card.
Map<String, dynamic> withFeatureGrant(
  Map<String, dynamic> row, {
  required String source, // 'class' | 'subclass'
  required String sourceName,
  required int atLevel,
  required String featureName,
}) =>
    {
      ...row,
      srdFeatureGrantKey: <String, dynamic>{
        'source': source,
        'source_name': sourceName,
        'at_level': atLevel,
        'feature_name': featureName,
      },
    };

/// One package entity in the wire format `PackageImportService` consumes.
/// `attributes` keys must match the target category's `FieldSchema.fieldKey`.
Map<String, dynamic> packEntity({
  required String slug,
  required String name,
  String description = '',
  String source = 'SRD 5.2.1',
  List<String> tags = const [],
  required Map<String, dynamic> attributes,
}) {
  return {
    'name': name,
    'type': slug,
    'source': source,
    'description': description,
    'image_path': '',
    'images': const <String>[],
    'tags': tags,
    'dm_notes': '',
    'pdfs': const <String>[],
    'location_id': null,
    'attributes': attributes,
  };
}

/// SRD statblok "SAVE" sütunu → `save_bonuses` tablosu.
///
/// [proficient] yetkin kurtarmaların ability kısaltmaları ('DEX'); [misc]
/// kaynağın bastığı, PB ile açıklanmayan artığı taşır (SRD'de dört kart).
/// Satır sırası ve isimleri `kDnd5eSavingThrows` presetinden gelir, yani
/// widget'ın beklediği tam altı satır her zaman yazılır.
Map<String, dynamic> saves(
  List<String> proficient, {
  Map<String, int> misc = const {},
}) =>
    _profTable(kDnd5eSavingThrows, keyOf: (p) => p.ability,
        flag: {for (final a in proficient) a: 'p'}, misc: misc);

/// SRD statblok "Skills" satırı → `skill_bonuses` tablosu.
///
/// [rows] beceri adı → `'p'` (yetkin) veya `'e'` (uzmanlık); [misc] kalan
/// artık. Bilinmeyen bir ad assert'e takılır — yazım hatası testte patlar.
Map<String, dynamic> skills(
  Map<String, String> rows, {
  Map<String, int> misc = const {},
}) =>
    _profTable(kDnd5eSkills, keyOf: (p) => p.name, flag: rows, misc: misc);

Map<String, dynamic> _profTable(
  List<ProficiencyRowPreset> preset, {
  required String Function(ProficiencyRowPreset) keyOf,
  required Map<String, String> flag,
  required Map<String, int> misc,
}) {
  final keys = preset.map(keyOf).toSet();
  assert(flag.keys.every(keys.contains),
      'unknown row: ${flag.keys.toSet().difference(keys)}');
  assert(misc.keys.every(keys.contains),
      'unknown row: ${misc.keys.toSet().difference(keys)}');
  return {
    'rows': [
      for (final p in preset)
        {
          'name': p.name,
          'ability': p.ability,
          'proficient': flag[keyOf(p)] != null,
          'expertise': flag[keyOf(p)] == 'e',
          'misc': misc[keyOf(p)] ?? 0,
        },
    ],
  };
}
