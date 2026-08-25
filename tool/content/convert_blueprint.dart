/// Converts world-blueprint.json + blueprint.json → .pkg.json wire format.
///
/// Usage:
///   dart run tool/content/convert_blueprint.dart \
///     --dir "tool/content/99 Devils of Uzrahs Palace Shadowdark" \
///     --out "tool/content/99-devils-of-uzrahs-palace-shadowdark.pkg.json"
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// ── Minimal UUID v5 (SHA-1 based, no external deps) ─────────────────────
// Namespace UUID for URLs (RFC 4122).
final _nsUrl = Uint8List.fromList([
  0x6b, 0xa7, 0xb8, 0x10, 0x9d, 0xad, 0x11, 0xd1, //
  0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8,
]);

String _uuid5(Uint8List namespace, String name) {
  // SHA-1 of namespace bytes + name UTF-8 bytes.
  final bytes = utf8.encode(name);
  final combined = Uint8List(namespace.length + bytes.length);
  combined.setAll(0, namespace);
  combined.setAll(namespace.length, bytes);

  // Use dart:crypto is not available standalone, so we use a simple hash.
  // For our purposes, a deterministic ID derived from the name is sufficient.
  // We'll use a simpler approach: hash the string and format as UUID-like.
  return _simpleHashId(namespace, name);
}

String _simpleHashId(Uint8List namespace, String name) {
  // Combine namespace + name, hash with DJB2 (simple, fast, deterministic).
  final input = '${String.fromCharCodes(namespace)}:$name';
  var hash = 5381;
  for (var i = 0; i < input.length; i++) {
    hash = ((hash << 5) + hash + input.codeUnitAt(i)) & 0x7FFFFFFF;
  }

  // Generate a UUIDv4-like string from the hash (repeated to fill 16 bytes).
  final h = hash.toRadixString(16).padLeft(8, '0');
  final parts = [
    h.substring(0, 8),
    '${h.substring(6, 8)}${h.substring(4, 6)}',
    '5${h.substring(1, 4)}',
    '8${h.substring(2, 4)}${h.substring(0, 2)}',
    '${h.substring(0, 4)}${h.substring(4, 8)}${h.substring(0, 4)}',
  ];
  return parts.join('-');
}

// ── Tier-0 lookup categories (always resolved at install time) ──────────
const _tier0 = {
  'ability', 'skill', 'damage-type', 'condition', 'creature-type',
  'language', 'weapon-property', 'weapon-mastery', 'spell-school',
  'magic-item-category', 'sense', 'hazard', 'arcane-focus', 'druidic-focus',
  'holy-symbol', 'size', 'rarity', 'coin', 'lifestyle', 'duration-unit',
  'body-slot', 'alignment', 'weapon-category', 'armor-category',
  'tool-category', 'feat-category', 'action', 'area-shape', 'attitude',
  'illumination', 'travel-pace', 'plane', 'casting-component',
  'casting-time-unit', 'speed-type', 'cover', 'tier-of-play',
  'character-state', 'resource-pool',
};

// ── Blueprint category → .pkg.json type slug ────────────────────────────
const _categoryMap = {
  'npc': 'npc',
  'location': 'location',
  'encounter': 'encounter',
  'trap': 'trap',
  'scene': 'scene',
  'quest': 'quest',
  'lore': 'lore',
  'campaign': 'campaign',
  'environmental-effect': 'environmental-effect',
  'monster': 'monster',
  'hireling': 'hireling',
  'service': 'service',
  'poison': 'poison',
  'curse': 'curse',
};

void main(List<String> args) {
  String? dir;
  String? out;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--dir' && i + 1 < args.length) dir = args[++i];
    if (args[i] == '--out' && i + 1 < args.length) out = args[++i];
  }
  dir ??= 'tool/content/99 Devils of Uzrahs Palace Shadowdark';
  out ??= '$dir.pkg.json';

  final worldBp = _readJson('$dir/world-blueprint.json');
  final charBp = _readJson('$dir/blueprint.json');
  final manifest = _readJson('$dir/manifest.json');

  final packageName = manifest['slug'] as String;
  final packTitle = '${manifest['title']}, ${manifest['system']}';
  final namespace = _nsUrl; // Use URL namespace for deterministic IDs.

  // Pass 1: Mint UUIDs for every entity, build ref index.
  final entities = <String, dynamic>{};
  final refIndex = <String, Map<String, String>>{}; // slug → name → uuid

  String stableId(String slug, String name) =>
      _uuid5(namespace, 'dmt-pack:$packageName:$slug:${name.toLowerCase().trim()}');

  void registerEntity(String typeSlug, Map<String, dynamic> mapping) {
    final name = mapping['name'] as String;
    final id = stableId(typeSlug, name);
    (refIndex[typeSlug] ??= {})[name] = id;
  }

  // Register world entities.
  final categories = worldBp['categories'] as Map<String, dynamic>;
  for (final entry in categories.entries) {
    final catSlug = _categoryMap[entry.key];
    if (catSlug == null) continue;
    final list = entry.value as List;
    for (final item in list) {
      final mapping = (item as Map<String, dynamic>)['mapping'] as Map<String, dynamic>;
      registerEntity(catSlug, mapping);
    }
  }

  // Register PC entities.
  final characters = charBp['characters'] as List;
  for (final char in characters) {
    final mapping = (char as Map<String, dynamic>)['mapping'] as Map<String, dynamic>;
    registerEntity('player-character', mapping);
  }

  // Pass 2: Build entity objects.
  // World entities.
  for (final entry in categories.entries) {
    final catSlug = _categoryMap[entry.key];
    if (catSlug == null) continue;
    final list = entry.value as List;
    for (final item in list) {
      final mapping = (item as Map<String, dynamic>)['mapping'] as Map<String, dynamic>;
      final id = stableId(catSlug, mapping['name'] as String);
      entities[id] = _buildEntity(id, catSlug, packTitle, mapping, refIndex);
    }
  }

  // PC entities.
  for (final char in characters) {
    final mapping = (char as Map<String, dynamic>)['mapping'] as Map<String, dynamic>;
    final id = stableId('player-character', mapping['name'] as String);
    entities[id] = _buildEntity('player-character', 'player-character', packTitle, mapping, refIndex);
  }

  // Resolve _ref placeholders (cross-entity refs within this pack).
  for (final entity in entities.values) {
    final attrs = entity['attributes'] as Map<String, dynamic>;
    entity['attributes'] = _resolveAllRefs(attrs, refIndex);
  }

  // Build counts.
  final counts = <String, int>{};
  for (final e in entities.values) {
    final t = e['type'] as String;
    counts[t] = (counts[t] ?? 0) + 1;
  }

  final pkg = {
    'package_name': packageName,
    'metadata': {
      'title': manifest['title'],
      'publisher': manifest['publisher'],
      'license': manifest['license'],
      'attribution': manifest['attribution'],
      'game_system': manifest['system'],
      'source': manifest['title'],
      'pack_version': manifest['version'],
      'counts': counts,
    },
    'entities': entities,
  };

  final encoder = JsonEncoder.withIndent('  ');
  File(out).writeAsStringSync(encoder.convert(pkg));
  print('✓ Wrote ${entities.length} entities to $out');
  print('  Counts: $counts');
  print('');
  print('To create ZIP for import:');
  print('  cd "${dir.replaceAll('\\', '/')}"');
  print('  Compress-Archive -Path "media\\*","${out.split(Platform.pathSeparator).last}" -DestinationPath "${out.replaceAll('.pkg.json', '.zip').split(Platform.pathSeparator).last}"');
}

Map<String, dynamic> _readJson(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}

/// Recursively resolve all refs in a value.
dynamic _resolveAllRefs(dynamic value, Map<String, Map<String, String>> refIndex) {
  if (value is Map) {
    // Already a _lookup placeholder — leave it.
    if (value.containsKey('_lookup')) return value;
    // Already a _ref — leave it.
    if (value.containsKey('_ref')) return value;
    // Already a {slug, name} soft ref — leave it.
    if (value.containsKey('slug') && value.containsKey('name')) return value;

    // Convert blueprint {lookup, match, value} ref.
    final lookup = value['lookup'];
    final match = value['match'];
    final val = value['value'];
    if (lookup is String && match == 'name' && val is String) {
      if (_tier0.contains(lookup)) {
        return {'_lookup': lookup, 'name': val};
      }
      // Check if the target entity exists in THIS pack.
      final packTargets = refIndex[lookup];
      if (packTargets != null && packTargets.containsKey(val)) {
        // Within-pack ref → _ref (resolved to UUID at build time).
        return {'_ref': lookup, 'name': val};
      }
      // Cross-pack ref (e.g. species from SRD) → soft ref (resolved at runtime).
      return {'slug': lookup, 'name': val};
    }

    // Recurse into map values.
    return value.map((k, v) => MapEntry(k, _resolveAllRefs(v, refIndex)));
  }
  if (value is List) {
    return value.map((e) => _resolveAllRefs(e, refIndex)).toList();
  }
  return value;
}

Map<String, dynamic> _buildEntity(
  String id,
  String typeSlug,
  String sourceTitle,
  Map<String, dynamic> mapping,
  Map<String, Map<String, String>> refIndex,
) {
  final attrs = <String, dynamic>{};
  for (final entry in mapping.entries) {
    final key = entry.key;
    final value = entry.value;

    // Skip top-level identity keys.
    if (key == 'name') continue;

    // Convert blueprint refs.
    attrs[key] = _resolveAllRefs(value, refIndex);
  }

  // ── Promote base Entity fields from mapping to entity level ──────────
  // The blueprint spec defines these as base fields on every entity, but
  // the default loop puts everything into `attributes`.  Extract them so
  // they land at the correct output level.
  String _str(dynamic v) => v is String ? v : '${v ?? ''}';
  List<String> _strList(dynamic v) =>
      v is List ? v.map((e) => '$e').toList() : <String>[];

  final description = _str(attrs.remove('description'));
  final imagePath = _str(attrs.remove('imagePath'));
  final dmNotes = _str(attrs.remove('dmNotes'));
  final tags = _strList(attrs.remove('tags'));
  final pdfs = _strList(attrs.remove('pdfs'));
  final locationId = attrs.remove('locationId');

  return {
    'name': mapping['name'],
    'type': typeSlug,
    'source': sourceTitle,
    'description': description,
    'image_path': imagePath,
    'images': <String>[],
    'tags': tags,
    'dm_notes': dmNotes,
    'pdfs': pdfs,
    'location_id': locationId,
    'attributes': attrs,
  };
}
