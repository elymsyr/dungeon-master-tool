// Builders + placeholder helpers shared across the hand-authored SRD 5.2.1
// content pack files in this directory.
//
// Tier-0 references → `lookup(slug, name)` placeholder, resolved at import
// time against the campaign's seeded Tier-0 entities.
// Inter-Tier-1 references → `ref(slug, name)` placeholder, resolved during
// pack-build against the freshly minted Tier-1 UUIDs.

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

/// `auto_granted_by` entry — declares the feat is auto-applied when the
/// character has the matching class+level / species / background.
Map<String, dynamic> autoGrantBy({
  required String source,
  required String sourceName,
  int? atLevel,
  bool? choiceRequired,
}) {
  final slug = source; // 'class' | 'subclass' | 'species' | 'background'
  return {
    'source': source,
    'source_ref': ref(slug, sourceName),
    'at_level': ?atLevel,
    'choice_required': ?choiceRequired,
  };
}

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
