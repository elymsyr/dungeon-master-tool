import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/repositories/campaign_repository.dart';

/// Installs / removes bundled worlds from `assets/worlds/`.
///
/// Each world directory contains a `manifest.json`, `world-blueprint.json`,
/// `blueprint.json`, and a `media/` folder.  The installer reads the blueprint
/// files, converts them to world format, and delegates to
/// [CampaignRepository] for persistence — worlds appear in the Worlds tab,
/// not Packages.
///
/// Admin-only utility gated by the dashboard toggle.
class BundledWorldsInstaller {
  BundledWorldsInstaller(this._repo);
  final CampaignRepository _repo;

  static const _manifestAsset = 'assets/worlds/manifest.json';
  static const _assetDir = 'assets/worlds';

  // ── Tier-0 lookup categories (must match convert_blueprint.dart) ──────
  static const _tier0 = {
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

  // ── Blueprint category → entity type slug ────────────────────────────
  static const _categoryMap = {
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

  /// Whether bundled worlds are present in this build.
  Future<bool> isAvailable() async => (await _tryLoad(_manifestAsset)) != null;

  /// Install every bundled world.  Idempotent — upserts by name.
  /// Returns the number of worlds installed.
  Future<int> installAll() async {
    final raw = await _tryLoad(_manifestAsset);
    if (raw == null) return 0;
    final json = jsonDecode(raw);
    final worlds = (json is Map ? json['worlds'] : null);
    if (worlds is! List) return 0;

    var n = 0;
    for (final w in worlds.whereType<Map>()) {
      final dir = w['dir'] as String?;
      if (dir == null) continue;
      try {
        final ok = await _installWorld(dir, w.cast<String, dynamic>());
        if (ok) n++;
      } catch (e) {
        // best-effort — skip worlds that fail to load/convert.
      }
    }
    return n;
  }

  /// Remove every world previously installed from bundled assets (those
  /// stamped with `metadata.installed_from == 'assets'`).  Returns the count
  /// removed.
  Future<int> uninstallAll() async {
    final names = await _repo.getAvailable();
    var n = 0;
    for (final name in names) {
      try {
        final data = await _repo.load(name);
        final meta = data['metadata'];
        if (meta is Map && meta['installed_from'] == 'assets') {
          await _repo.delete(name);
          n++;
        }
      } catch (_) {
        // best-effort
      }
    }
    return n;
  }

  // ── Single world install ─────────────────────────────────────────────

  Future<bool> _installWorld(
    String dir,
    Map<String, dynamic> manifestEntry,
  ) async {
    final base = '$_assetDir/$dir';

    final worldRaw = await _tryLoad('$base/world-blueprint.json');
    final charRaw = await _tryLoad('$base/blueprint.json');
    final manifestRaw = await _tryLoad('$base/manifest.json');
    if (worldRaw == null || manifestRaw == null) return false;

    final worldBp = jsonDecode(worldRaw) as Map<String, dynamic>;
    final charBp = charRaw != null
        ? jsonDecode(charRaw) as Map<String, dynamic>
        : null;
    final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;

    final worldName = manifest['title'] as String;
    final packTitle = '$worldName, ${manifest['system']}';

    // Pass 1: Mint UUIDs and build ref index.
    final entities = <String, dynamic>{};
    final refIndex = <String, Map<String, String>>{};

    String stableId(String typeSlug, String name) =>
        _uuid5('dmt-world:$worldName:$typeSlug:${name.toLowerCase().trim()}');

    void registerEntity(String typeSlug, Map<String, dynamic> mapping) {
      final name = mapping['name'] as String;
      final id = stableId(typeSlug, name);
      (refIndex[typeSlug] ??= {})[name] = id;
    }

    // Register world entities.
    final categories = worldBp['categories'] as Map<String, dynamic>? ?? {};
    for (final entry in categories.entries) {
      final catSlug = _categoryMap[entry.key];
      if (catSlug == null) continue;
      final list = entry.value as List;
      for (final item in list) {
        final mapping =
            (item as Map<String, dynamic>)['mapping'] as Map<String, dynamic>;
        registerEntity(catSlug, mapping);
      }
    }

    // Register PC entities.
    final characters = charBp?['characters'] as List? ?? [];
    for (final char in characters) {
      final mapping =
          (char as Map<String, dynamic>)['mapping'] as Map<String, dynamic>;
      registerEntity('player-character', mapping);
    }

    // Pass 2: Build entity objects.
    for (final entry in categories.entries) {
      final catSlug = _categoryMap[entry.key];
      if (catSlug == null) continue;
      final list = entry.value as List;
      for (final item in list) {
        final mapping =
            (item as Map<String, dynamic>)['mapping'] as Map<String, dynamic>;
        final id = stableId(catSlug, mapping['name'] as String);
        entities[id] = _buildEntity(id, catSlug, packTitle, mapping, refIndex);
      }
    }

    for (final char in characters) {
      final mapping =
          (char as Map<String, dynamic>)['mapping'] as Map<String, dynamic>;
      final id = stableId('player-character', mapping['name'] as String);
      entities[id] =
          _buildEntity(id, 'player-character', packTitle, mapping, refIndex);
    }

    // Resolve _ref placeholders.
    for (final entity in entities.values) {
      final attrs = entity['attributes'] as Map<String, dynamic>;
      entity['attributes'] = _resolveAllRefs(attrs, refIndex);
    }

    // Check if world already exists — if so, overwrite via save.
    final existing = await _repo.getAvailable();
    final alreadyExists = existing.contains(worldName);

    final worldData = <String, dynamic>{
      'entities': entities,
      'metadata': {
        'title': manifest['title'],
        'publisher': manifest['publisher'],
        'license': manifest['license'],
        'attribution': manifest['attribution'],
        'game_system': manifest['system'],
        'source': manifest['title'],
        'pack_version': manifest['version'],
        'installed_from': 'assets',
      },
    };

    if (alreadyExists) {
      // Merge entities into existing world data.
      try {
        final existingData = await _repo.load(worldName);
        final existingEntities =
            existingData['entities'] as Map<String, dynamic>? ?? {};
        worldData['entities'] = {...existingEntities, ...entities};
      } catch (_) {
        // If load fails, just overwrite.
      }
    }

    await _repo.save(worldName, worldData);
    return true;
  }

  // ── UUID v5 (deterministic, same as convert_blueprint.dart) ───────────

  static String _uuid5(String name) {
    var hash = 5381;
    for (var i = 0; i < name.length; i++) {
      hash = ((hash << 5) + hash + name.codeUnitAt(i)) & 0x7FFFFFFF;
    }
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

  // ── Ref resolution (mirrors convert_blueprint.dart) ───────────────────

  static dynamic _resolveAllRefs(
    dynamic value,
    Map<String, Map<String, String>> refIndex,
  ) {
    if (value is Map) {
      if (value.containsKey('_lookup')) return value;
      if (value.containsKey('_ref')) return value;
      if (value.containsKey('slug') && value.containsKey('name')) return value;

      final lookup = value['lookup'];
      final match = value['match'];
      final val = value['value'];
      if (lookup is String && match == 'name' && val is String) {
        if (_tier0.contains(lookup)) {
          return {'_lookup': lookup, 'name': val};
        }
        final packTargets = refIndex[lookup];
        if (packTargets != null && packTargets.containsKey(val)) {
          return {'_ref': lookup, 'name': val};
        }
        return {'slug': lookup, 'name': val};
      }

      return value.map((k, v) => MapEntry(k, _resolveAllRefs(v, refIndex)));
    }
    if (value is List) {
      return value.map((e) => _resolveAllRefs(e, refIndex)).toList();
    }
    return value;
  }

  // ── Entity builder (mirrors convert_blueprint.dart) ───────────────────

  static Map<String, dynamic> _buildEntity(
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
      if (key == 'name') continue;
      attrs[key] = _resolveAllRefs(value, refIndex);
    }

    // Promote base Entity fields from mapping to entity level.
    String str(dynamic v) => v is String ? v : '${v ?? ''}';
    List<String> strList(dynamic v) =>
        v is List ? v.map((e) => '$e').toList() : <String>[];

    final description = str(attrs.remove('description'));
    final imagePath = str(attrs.remove('imagePath'));
    final dmNotes = str(attrs.remove('dmNotes'));
    final tags = strList(attrs.remove('tags'));
    final pdfs = strList(attrs.remove('pdfs'));
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

  // ── Asset loading ────────────────────────────────────────────────────

  Future<String?> _tryLoad(String asset) async {
    try {
      return await rootBundle.loadString(asset);
    } catch (_) {
      if (kDebugMode && !kIsWeb) {
        try {
          final f = File(asset);
          if (await f.exists()) return await f.readAsString();
        } catch (_) {
          // fall through
        }
      }
      return null;
    }
  }
}
