import 'package:uuid/uuid.dart';

import '../../core/utils/deep_copy.dart';

import '../../domain/entities/schema/default_dnd5e_schema.dart';
import 'legacy_maps.dart';

const _uuid = Uuid();

/// Handles migration of legacy Python campaign data to the Flutter schema format.
///
/// When opening campaigns that lack a `world_schema`, this class:
/// 1. Generates the default D&D 5e schema
/// 2. Translates entity type names (TR/EN) to Flutter slugs
/// 3. Translates attribute keys (TR) to Flutter fieldKeys
/// 4. Back-fills missing default fields
/// 5. Translates sessions/encounters/combatants (snake_case → camelCase + legacy wrap)
/// 6. Translates map_data pins and timeline pins
/// 7. Translates mind_maps nodes and connections → edges
class SchemaMigration {
  /// Migrate campaign data in-place.
  /// Returns `true` if any migration was performed.
  static bool migrate(Map<String, dynamic> data) {
    bool changed = false;

    // Legacy schema migration (Python → Flutter)
    if (!data.containsKey('world_schema')) {
      // 1. Generate and inject default schema
      final schema = generateDefaultDnd5eSchema();
      data['world_schema'] = deepCopyJson(schema.toJson());

      // 2. Migrate entities
      final entities = data['entities'];
      if (entities is Map) {
        final migratedEntities = <String, dynamic>{};
        for (final entry in entities.entries) {
          final entity = entry.value;
          if (entity is Map) {
            final dynamicMap = Map<String, dynamic>.from(entity);
            _migrateEntity(dynamicMap);
            migratedEntities[entry.key.toString()] = dynamicMap;
          } else {
            migratedEntities[entry.key.toString()] = entity;
          }
        }
        data['entities'] = migratedEntities;
      } else if (entities is List) {
        final migratedList = <dynamic>[];
        for (final entity in entities) {
          if (entity is Map) {
            final dynamicMap = Map<String, dynamic>.from(entity);
            _migrateEntity(dynamicMap);
            migratedList.add(dynamicMap);
          } else {
            migratedList.add(entity);
          }
        }
        data['entities'] = migratedList;
      }

      // 3. Sessions / encounters / combatants — resilient: bozuk bir
      //    session diğerlerini engellemesin.
      try {
        _migrateSessions(data);
      } catch (e, st) {
        // ignore: avoid_print
        print('SchemaMigration._migrateSessions failed: $e\n$st');
      }

      // 4. Map data (pins, timeline pins)
      try {
        _migrateMapData(data);
      } catch (e, st) {
        // ignore: avoid_print
        print('SchemaMigration._migrateMapData failed: $e\n$st');
      }

      // 5. Mind maps (nodes + connections → edges)
      try {
        _migrateMindMaps(data);
      } catch (e, st) {
        // ignore: avoid_print
        print('SchemaMigration._migrateMindMaps failed: $e\n$st');
      }

      changed = true;
    }

    // UUID backfill for existing campaigns
    if (!data.containsKey('world_id')) {
      data['world_id'] = const Uuid().v4();
      data['created_at'] ??= DateTime.now().toIso8601String();
      changed = true;
    }

    return changed;
  }

  static void _migrateEntity(Map<String, dynamic> entity) {
    // Translate type → slug
    _migrateType(entity);

    // Translate attribute keys
    _migrateAttributes(entity);

    // Back-fill missing default fields
    _backfillDefaults(entity);

    // Fix image_path → images migration
    _migrateImages(entity);
  }

  /// Translate `type` field from Turkish/English name to Flutter slug.
  static void _migrateType(Map<String, dynamic> entity) {
    final type = entity['type'];
    if (type is! String) return;

    // Try direct lookup in schemaMap (covers both TR and EN names)
    final slug = schemaMap[type];
    if (slug != null) {
      entity['type'] = slug;
      return;
    }

    // Fallback: normalize to lowercase-hyphenated
    entity['type'] = type.toLowerCase().replaceAll(' ', '-');
  }

  /// Translate Turkish attribute keys to Flutter fieldKeys.
  static void _migrateAttributes(Map<String, dynamic> entity) {
    final attrs = entity['attributes'];
    if (attrs is! Map) return;

    final migrated = <String, dynamic>{};
    for (final entry in attrs.entries) {
      final key = entry.key.toString();
      // Look up in propertyMap; if not found keep original key
      final newKey = propertyMap[key] ?? key;
      migrated[newKey] = entry.value;
    }
    entity['attributes'] = migrated;
  }

  /// Back-fill missing fields from the default entity structure.
  static void _backfillDefaults(Map<String, dynamic> entity) {
    for (final entry in defaultEntityFields.entries) {
      if (!entity.containsKey(entry.key)) {
        final value = entry.value;
        if (value == null) continue; // skip null defaults (e.g. location_id)
        // Deep-copy default value to avoid shared mutable state
        entity[entry.key] = _deepCopy(value);
      }
    }
  }

  /// Migrate `image_path` → `images` list.
  static void _migrateImages(Map<String, dynamic> entity) {
    final images = entity['images'];
    final imagePath = entity['image_path'];

    if ((images == null || (images is List && images.isEmpty)) &&
        imagePath is String &&
        imagePath.isNotEmpty) {
      entity['images'] = [imagePath];
    }
  }

  static dynamic _deepCopy(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k, _deepCopy(v)));
    }
    if (value is List) {
      return value.map(_deepCopy).toList();
    }
    return value;
  }

  // ==========================================================================
  // Sessions / Encounters / Combatants
  // ==========================================================================

  /// Legacy Python session data'yı Flutter Session/Encounter/Combatant
  /// şekline çevirir.
  ///
  /// İki format desteklenir:
  ///   A) Flat combatants: `session = {id, name, combatants: [...]}` —
  ///      implicit bir encounter'a sarılır.
  ///   B) Encounters dict/list: `session = {id, name, encounters: {...}}`
  ///      veya `encounters: [...]`.
  static void _migrateSessions(Map<String, dynamic> data) {
    final sessionsRaw = data['sessions'];
    if (sessionsRaw is! List) return;

    final migrated = <Map<String, dynamic>>[];
    for (final s in sessionsRaw) {
      if (s is! Map) continue;
      try {
        migrated.add(_migrateSession(Map<String, dynamic>.from(s)));
      } catch (e, st) {
        // Bozuk tekil session — import'u düşürmemek için placeholder ekle.
        // ignore: avoid_print
        print('SchemaMigration._migrateSession failed, inserting stub: $e\n$st');
        migrated.add(<String, dynamic>{
          'id': (s['id'] ?? _uuid.v4()).toString(),
          'name': (s['name'] ?? 'Corrupted Session').toString(),
          'notes': 'Import error: $e',
          'logs': '',
          'encounters': <Map<String, dynamic>>[],
        });
      }
    }
    data['sessions'] = migrated;
  }

  static Map<String, dynamic> _migrateSession(Map<String, dynamic> session) {
    final result = <String, dynamic>{
      'id': session['id'] ?? _uuid.v4(),
      'name': session['name'] ?? '',
      'notes': session['notes'] ?? '',
      'logs': session['logs'] ?? '',
    };

    // Flutter Session'da `date` alanı yok; `notes` başına ekleyerek koru.
    final date = session['date'];
    if (date is String && date.isNotEmpty) {
      final notes = result['notes'] as String;
      if (!notes.contains(date)) {
        result['notes'] = notes.isEmpty ? 'Date: $date' : 'Date: $date\n\n$notes';
      }
    }

    final encountersList = <Map<String, dynamic>>[];
    String? activeEncounterId;

    final encountersRaw = session['encounters'];
    if (encountersRaw is Map) {
      // Newer Python format: encounters is {id: encounter, ...}
      for (final entry in encountersRaw.entries) {
        final enc = entry.value;
        if (enc is! Map) continue;
        final encMap = Map<String, dynamic>.from(enc);
        encMap['id'] ??= entry.key.toString();
        encountersList.add(_migrateEncounter(encMap));
      }
      final currentId =
          session['current_encounter_id'] ?? session['active_encounter_id'];
      if (currentId is String && currentId.isNotEmpty) {
        activeEncounterId = currentId;
      }
    } else if (encountersRaw is List) {
      for (final enc in encountersRaw) {
        if (enc is! Map) continue;
        encountersList
            .add(_migrateEncounter(Map<String, dynamic>.from(enc)));
      }
    } else if (session['combatants'] is List) {
      // Legacy flat format: session'ın doğrudan altında combatants listesi.
      final implicit = _migrateEncounter({
        'id': _uuid.v4(),
        'name': 'Encounter',
        'combatants': session['combatants'],
      });
      encountersList.add(implicit);
      activeEncounterId = implicit['id'] as String;
    }

    result['encounters'] = encountersList;
    if (activeEncounterId != null) {
      result['activeEncounterId'] = activeEncounterId;
    } else if (encountersList.isNotEmpty) {
      result['activeEncounterId'] = encountersList.first['id'];
    }
    return result;
  }

  static Map<String, dynamic> _migrateEncounter(Map<String, dynamic> enc) {
    // snake_case ↔ camelCase tolerant okuyucu.
    dynamic pick(String camel, String snake, [dynamic fallback]) =>
        enc[camel] ?? enc[snake] ?? fallback;

    // Token positions — combatants'ın eski x/y'si buraya taşınacak.
    final tokenPositions = <String, dynamic>{};
    final rawTp = pick('tokenPositions', 'token_positions');
    if (rawTp is Map) {
      for (final entry in rawTp.entries) {
        tokenPositions[entry.key.toString()] = entry.value;
      }
    }

    // Combatants — listeyi migrate et ve x/y varsa tokenPositions'a yaz.
    final combatantsRaw = enc['combatants'];
    final combatants = <Map<String, dynamic>>[];
    if (combatantsRaw is List) {
      for (final c in combatantsRaw) {
        if (c is! Map) continue;
        final cMap = Map<String, dynamic>.from(c);
        final translated = _migrateCombatant(cMap);
        combatants.add(translated);
        final x = cMap['x'];
        final y = cMap['y'];
        if (x is num && y is num) {
          tokenPositions[translated['id'] as String] = {
            'x': x.toDouble(),
            'y': y.toDouble(),
          };
        }
      }
    }

    // token_size_overrides → tokenSizeMultipliers (Map<String, double>).
    final sizeMults = <String, double>{};
    final rawSizeOverrides = pick('tokenSizeMultipliers', 'token_size_overrides');
    if (rawSizeOverrides is Map) {
      for (final entry in rawSizeOverrides.entries) {
        final v = entry.value;
        if (v is num) {
          sizeMults[entry.key.toString()] = v.toDouble();
        }
      }
    }

    return <String, dynamic>{
      'id': enc['id'] ?? _uuid.v4(),
      'name': enc['name'] ?? 'Encounter',
      'combatants': combatants,
      'mapPath': pick('mapPath', 'map_path'),
      'tokenSize': _toInt(pick('tokenSize', 'token_size'), 50),
      'tokenSizeMultipliers': sizeMults,
      'turnIndex': _toInt(pick('turnIndex', 'turn_index'), -1),
      'round': _toInt(enc['round'], 1),
      'tokenPositions': tokenPositions,
      'gridSize': _toInt(pick('gridSize', 'grid_size'), 50),
      'gridVisible': pick('gridVisible', 'grid_visible', false) == true,
      'gridSnap': pick('gridSnap', 'grid_snap', false) == true,
      'feetPerCell': _toInt(pick('feetPerCell', 'feet_per_cell'), 5),
      'fogData': pick('fogData', 'fog_data'),
      'annotationData': pick('annotationData', 'annotation_data'),
    };
  }

  static Map<String, dynamic> _migrateCombatant(Map<String, dynamic> c) {
    final id = (c['id'] ?? c['tid'] ?? _uuid.v4()).toString();
    final hp = _toInt(c['hp'], 10);
    return <String, dynamic>{
      'id': id,
      'name': (c['name'] ?? 'Unknown').toString(),
      'init': _toInt(c['init'], 0),
      'ac': _toInt(c['ac'], 10),
      'hp': hp,
      'maxHp': _toInt(c['maxHp'] ?? c['max_hp'] ?? c['hp'], hp),
      'entityId': c['entityId'] ?? c['eid'],
      'conditions': _migrateConditions(c['conditions']),
      'tokenId': c['tokenId'] ?? c['tid'],
    };
  }

  static List<Map<String, dynamic>> _migrateConditions(dynamic conditions) {
    if (conditions is! List) return const [];
    final result = <Map<String, dynamic>>[];
    for (final c in conditions) {
      if (c is! Map) continue;
      result.add(<String, dynamic>{
        'name': (c['name'] ?? '').toString(),
        'duration': c['duration'] is num ? (c['duration'] as num).toInt() : null,
        'initialDuration': (c['initialDuration'] ?? c['max_duration']) is num
            ? ((c['initialDuration'] ?? c['max_duration']) as num).toInt()
            : null,
        'entityId': c['entityId'] ?? c['entity_id'],
      });
    }
    return result;
  }

  static int _toInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  // ==========================================================================
  // Map Data
  // ==========================================================================

  static void _migrateMapData(Map<String, dynamic> data) {
    final raw = data['map_data'];
    if (raw is! Map) return;
    final md = Map<String, dynamic>.from(raw);

    // image_path → imagePath (Flutter MapData camelCase).
    if (md.containsKey('image_path') && !md.containsKey('imagePath')) {
      md['imagePath'] = md['image_path'];
    }
    md.remove('image_path');

    // Pins — snake_case → camelCase.
    final pinsRaw = md['pins'];
    if (pinsRaw is List) {
      md['pins'] = pinsRaw
          .whereType<Map>()
          .map((p) => _migratePin(Map<String, dynamic>.from(p)))
          .toList();
    }

    // Timeline pins — snake_case → camelCase + parent_id → parentIds.
    final timelineRaw = md['timeline'];
    if (timelineRaw is List) {
      md['timeline'] = timelineRaw
          .whereType<Map>()
          .map((t) => _migrateTimelinePin(Map<String, dynamic>.from(t)))
          .toList();
    }

    data['map_data'] = md;
  }

  static Map<String, dynamic> _migratePin(Map<String, dynamic> p) {
    return <String, dynamic>{
      'id': (p['id'] ?? _uuid.v4()).toString(),
      'x': (p['x'] is num ? (p['x'] as num) : 0).toDouble(),
      'y': (p['y'] is num ? (p['y'] as num) : 0).toDouble(),
      'label': (p['label'] ?? '').toString(),
      'pinType': (p['pinType'] ?? p['pin_type'] ?? 'default').toString(),
      'entityId': p['entityId'] ?? p['entity_id'],
      'note': (p['note'] ?? '').toString(),
      'color': (p['color'] ?? '').toString(),
      'style': p['style'] is Map
          ? Map<String, dynamic>.from(p['style'] as Map)
          : <String, dynamic>{},
    };
  }

  static Map<String, dynamic> _migrateTimelinePin(Map<String, dynamic> t) {
    final parentIds = <String>[];
    final rawParentIds = t['parentIds'];
    if (rawParentIds is List) {
      parentIds.addAll(rawParentIds.map((e) => e.toString()));
    }
    final legacyParent = t['parent_id'];
    if (legacyParent is String && legacyParent.isNotEmpty) {
      parentIds.add(legacyParent);
    }

    final entityIds = <String>[];
    final rawEids = t['entityIds'] ?? t['entity_ids'];
    if (rawEids is List) {
      entityIds.addAll(rawEids.map((e) => e.toString()));
    }

    return <String, dynamic>{
      'id': (t['id'] ?? _uuid.v4()).toString(),
      'x': (t['x'] is num ? (t['x'] as num) : 0).toDouble(),
      'y': (t['y'] is num ? (t['y'] as num) : 0).toDouble(),
      'day': _toInt(t['day'], 1),
      'note': (t['note'] ?? '').toString(),
      'entityIds': entityIds,
      'sessionId': t['sessionId'] ?? t['session_id'],
      'parentIds': parentIds,
      'color': (t['color'] ?? '#42a5f5').toString(),
    };
  }

  // ==========================================================================
  // Mind Maps
  // ==========================================================================

  /// Python mind_maps:
  ///   `{mapId: {nodes: [{id, type, x, y, w, h, extra, content}],
  ///             connections: [{from, to}], workspaces, viewport}}`
  ///
  /// Flutter mind_maps (mind_map_notifier.init beklentisi):
  ///   `{mapId: {nodes: [MindMapNode.toJson()],
  ///             edges: [MindMapEdge.toJson()], pan_x, pan_y, scale}}`
  static void _migrateMindMaps(Map<String, dynamic> data) {
    final raw = data['mind_maps'];
    if (raw is! Map) return;

    final result = <String, dynamic>{};
    for (final entry in raw.entries) {
      final mapData = entry.value;
      if (mapData is! Map) {
        result[entry.key.toString()] = mapData;
        continue;
      }
      final m = Map<String, dynamic>.from(mapData);

      // Nodes
      final nodesRaw = m['nodes'];
      if (nodesRaw is List) {
        m['nodes'] = nodesRaw
            .whereType<Map>()
            .map((n) => _migrateMindMapNode(Map<String, dynamic>.from(n)))
            .toList();
      } else {
        m['nodes'] = <Map<String, dynamic>>[];
      }

      // Connections → edges (sadece edges yoksa çevir)
      if (!m.containsKey('edges')) {
        final connsRaw = m['connections'];
        final edges = <Map<String, dynamic>>[];
        if (connsRaw is List) {
          for (final c in connsRaw) {
            if (c is! Map) continue;
            edges.add(<String, dynamic>{
              'id': (c['id'] ?? _uuid.v4()).toString(),
              'sourceId':
                  (c['sourceId'] ?? c['from'] ?? '').toString(),
              'targetId':
                  (c['targetId'] ?? c['to'] ?? '').toString(),
              'label': (c['label'] ?? '').toString(),
              'style': c['style'] is Map
                  ? Map<String, dynamic>.from(c['style'] as Map)
                  : <String, dynamic>{},
            });
          }
        }
        m['edges'] = edges;
      }
      m.remove('connections');

      // Viewport → pan_x/pan_y/scale (mind_map_notifier.init beklentisi)
      final viewport = m['viewport'];
      if (viewport is Map) {
        m['pan_x'] = (viewport['x'] is num) ? (viewport['x'] as num) : 0;
        m['pan_y'] = (viewport['y'] is num) ? (viewport['y'] as num) : 0;
        m['scale'] = (viewport['zoom'] is num) ? (viewport['zoom'] as num) : 1.0;
      }

      result[entry.key.toString()] = m;
    }
    data['mind_maps'] = result;
  }

  static Map<String, dynamic> _migrateMindMapNode(Map<String, dynamic> n) {
    final extra = n['extra'] is Map
        ? Map<String, dynamic>.from(n['extra'] as Map)
        : <String, dynamic>{};

    final rawType = (n['nodeType'] ?? n['type'] ?? 'note').toString();
    // Python type'ları Flutter nodeType değerleriyle örtüşüyor:
    // note, entity, image, workspace — normalize etmeye gerek yok.

    String? imageUrl = n['imageUrl'] as String?;
    imageUrl ??= extra['path'] as String?;

    String? entityId = n['entityId'] as String?;
    entityId ??= extra['eid'] as String?;

    return <String, dynamic>{
      'id': (n['id'] ?? _uuid.v4()).toString(),
      'label': (n['label'] ?? extra['label'] ?? '').toString(),
      'nodeType': rawType,
      'x': (n['x'] is num ? (n['x'] as num) : 0).toDouble(),
      'y': (n['y'] is num ? (n['y'] as num) : 0).toDouble(),
      'width': (n['width'] ?? n['w'] ?? 200 as num?) is num
          ? ((n['width'] ?? n['w'] ?? 200) as num).toDouble()
          : 200.0,
      'height': (n['height'] ?? n['h'] ?? 100 as num?) is num
          ? ((n['height'] ?? n['h'] ?? 100) as num).toDouble()
          : 100.0,
      'entityId': entityId,
      'imageUrl': imageUrl,
      'content': (n['content'] ?? '').toString(),
      'style': n['style'] is Map
          ? Map<String, dynamic>.from(n['style'] as Map)
          : <String, dynamic>{},
      'color': (n['color'] ?? '#42a5f5').toString(),
    };
  }
}
