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
