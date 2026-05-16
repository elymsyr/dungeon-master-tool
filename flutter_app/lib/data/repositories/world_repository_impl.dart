import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../application/services/srd_core_bootstrap.dart';
import '../../application/services/srd_core_package_bootstrap.dart';
import '../../core/utils/deep_copy.dart';
import '../../domain/entities/schema/builtin/builtin_dnd5e_v2_schema.dart';
import '../../domain/entities/schema/world_schema.dart' as domain;
import '../../domain/entities/schema/world_schema_hash.dart';
import '../../domain/repositories/campaign_repository.dart';
import '../database/app_database.dart';

const _uuid = Uuid();

/// PR-D3 minimal substitution rewrite of the legacy `CampaignRepositoryImpl`.
///
/// Interface preserved as-is — still `Map<String, dynamic>` based, still
/// implements [CampaignRepository] (rename to `WorldRepository` deferred to
/// PR-D6). Storage moved to v12 DAOs:
///   * `worlds` row carries id/name/template_*/timestamps.
///   * `world_entities` rows carry entities (was `entities` table).
///   * Schema content + every other dynamic key (combat_state, map_data,
///     sessions, mind_maps, ...) is packed into `world_settings.settings_json`.
///     PR-D5 will split map_data / sessions / mind_maps into their own
///     tables for granular CDC; D3 keeps the blob path so the rewrite stays
///     surgical.
class WorldRepositoryImpl implements CampaignRepository {
  final AppDatabase _db;

  WorldRepositoryImpl(this._db);

  static const _schemaSettingsKey = '_world_schema';
  static const _typedTopKeys = <String>{
    'world_id',
    'world_name',
    'created_at',
    'entities',
    'world_schema',
    'template_id',
    'template_hash',
    'template_original_hash',
  };

  @override
  Future<List<String>> getAvailable() async {
    final worlds = await _db.worldsDao.getAll();
    final names = worlds.map((w) => w.worldName).toSet().toList()..sort();
    return names;
  }

  @override
  Future<Map<String, dynamic>> load(String campaignName) async {
    final existing = await _findByName(campaignName);
    if (existing == null) {
      throw StateError('World not found: $campaignName');
    }
    return _loadFromDb(existing.id);
  }

  @override
  Future<void> save(String campaignName, Map<String, dynamic> data) async {
    final existing = await _findByName(campaignName);
    if (existing != null) {
      await _saveToDb(existing.id, campaignName, data);
      return;
    }
    final worldId = data['world_id'] as String? ?? _uuid.v4();
    data['world_id'] = worldId;
    await _db.worldsDao.upsert(WorldsCompanion.insert(
      id: worldId,
      worldName: campaignName,
    ));
    await _saveToDb(worldId, campaignName, data);
  }

  @override
  Future<void> delete(String campaignName) async {
    final existing = await _findByName(campaignName);
    if (existing == null) return;
    final worldId = existing.id;

    // Snapshot for trash row before cascade wipe.
    final snapshot = await _loadFromDb(worldId);
    await _db.trashDao.upsert(TrashItemsCompanion.insert(
      id: _uuid.v4(),
      kind: 'world',
      sourceId: worldId,
      payloadJson: jsonEncode(snapshot),
    ));

    await _purgeWorld(worldId);
  }

  @override
  Future<void> purge(String campaignName) async {
    final existing = await _findByName(campaignName);
    if (existing == null) return;
    await _purgeWorld(existing.id);
  }

  @override
  Future<String> create(String worldName,
      {domain.WorldSchema? template}) async {
    final existing = await _findByName(worldName);
    if (existing != null) {
      throw StateError('Campaign already exists: $worldName');
    }
    if (template == null) {
      throw StateError('Cannot create world without a template');
    }
    final worldId = _uuid.v4();
    final schema = template;
    final currentHash = computeWorldSchemaContentHash(schema);
    final originalHash = schema.originalHash ?? currentHash;

    await _db.worldsDao.upsert(WorldsCompanion.insert(
      id: worldId,
      worldName: worldName,
      templateId: Value(schema.schemaId),
      templateHash: Value(currentHash),
      templateOriginalHash: Value(originalHash),
    ));

    // Persist schema content into world_settings so load() can rebuild the
    // full WorldSchema without needing the template registry. Mirrors what
    // v11 wrote to the now-retired `world_schemas` table.
    final schemaJson =
        deepCopyJson(schema.toJson()) as Map<String, dynamic>;
    await _db.worldSettingsDao.upsert(WorldSettingsCompanion.insert(
      worldId: worldId,
      settingsJson: Value(jsonEncode({_schemaSettingsKey: schemaJson})),
    ));

    if (schema.schemaId == builtinDnd5eV2SchemaId) {
      await SrdCorePackageBootstrap(_db).ensureInstalled();
      await SrdCoreBootstrap(_db).ensureImported(
        worldId: worldId,
        build: generateBuiltinDnd5eV2Schema(),
      );
    }

    return worldName;
  }

  // ── Internal helpers ─────────────────────────────────────────────────────

  Future<World?> _findByName(String name) async {
    final all = await _db.worldsDao.getAll();
    for (final w in all) {
      if (w.worldName == name) return w;
    }
    return null;
  }

  Future<Map<String, dynamic>> _loadFromDb(String worldId) async {
    final world = await _db.worldsDao.getById(worldId);
    if (world == null) {
      throw StateError('World not found: $worldId');
    }

    // Settings blob — packed dynamic state + schema snapshot.
    final settingsRow = await _db.worldSettingsDao.get(worldId);
    final settingsBlob = <String, dynamic>{};
    if (settingsRow != null &&
        settingsRow.settingsJson.isNotEmpty &&
        settingsRow.settingsJson != '{}') {
      try {
        final decoded = jsonDecode(settingsRow.settingsJson);
        if (decoded is Map) {
          settingsBlob.addAll(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }

    final schemaSnapshot =
        settingsBlob.remove(_schemaSettingsKey) as Map<String, dynamic>?;

    // Entities — joined from world_entities.
    final entityRows = await _db.worldEntitiesDao.getByWorld(worldId);
    final entitiesMap = <String, dynamic>{};
    for (final e in entityRows) {
      entitiesMap[e.id] = {
        'name': e.name,
        'type': e.categorySlug,
        'source': e.source,
        'description': e.description,
        'image_path': e.imagePath,
        'images': jsonDecode(e.imagesJson),
        'tags': jsonDecode(e.tagsJson),
        'dm_notes': e.dmNotes,
        'pdfs': jsonDecode(e.pdfsJson),
        'location_id': e.locationId,
        'attributes': jsonDecode(e.fieldsJson),
        if (e.packageId != null) 'package_id': e.packageId,
        if (e.packageEntityId != null) 'package_entity_id': e.packageEntityId,
        if (e.linked) 'linked': true,
      };
    }

    // Reconstruct WorldSchema map. Legacy world_schemas table is gone —
    // schema content rides in world_settings.settings_json under
    // `_world_schema`. Falls back to `'builtin-dnd5e-default'` when missing.
    Map<String, dynamic>? worldSchemaMap;
    final templateId = world.templateId ?? 'builtin-dnd5e-default';
    final templateHash = world.templateHash;
    final templateOriginalHash = world.templateOriginalHash;
    if (schemaSnapshot != null) {
      worldSchemaMap = Map<String, dynamic>.from(schemaSnapshot);
    }

    return {
      ...settingsBlob, // combat_state, map_data, mind_maps, sessions, ...
      'world_id': world.id,
      'world_name': world.worldName,
      'created_at': world.createdAt.toIso8601String(),
      'entities': entitiesMap,
      'world_schema': ?worldSchemaMap,
      'template_id': templateId,
      'template_hash': ?templateHash,
      'template_original_hash': ?templateOriginalHash,
    };
  }

  Future<void> _saveToDb(
    String worldId,
    String worldName,
    Map<String, dynamic> data,
  ) async {
    final stateBlob = <String, dynamic>{};
    for (final entry in data.entries) {
      if (_typedTopKeys.contains(entry.key)) continue;
      stateBlob[entry.key] = entry.value;
    }

    // Schema snapshot rides inside settings_json (legacy world_schemas table
    // is gone in v12).
    final schemaData = data['world_schema'] as Map<String, dynamic>?;
    if (schemaData != null) {
      stateBlob[_schemaSettingsKey] = schemaData;
    }

    final templateId = data['template_id'] as String?;
    final templateHash = data['template_hash'] as String?;
    final templateOriginalHash = data['template_original_hash'] as String?;

    await _db.transaction(() async {
      await _db.worldsDao.upsert(WorldsCompanion(
        id: Value(worldId),
        worldName: Value(worldName),
        templateId: Value(templateId),
        templateHash: Value(templateHash),
        templateOriginalHash: Value(templateOriginalHash),
        updatedAt: Value(DateTime.now()),
      ));

      await _db.worldSettingsDao.upsert(WorldSettingsCompanion(
        worldId: Value(worldId),
        settingsJson: Value(jsonEncode(stateBlob)),
        updatedAt: Value(DateTime.now()),
      ));

      // Entities — full replace, mirrors v11 semantics. PR-D5 will switch
      // to per-row diffing once the sync engine is rewritten.
      await _db.worldEntitiesDao.deleteByWorld(worldId);
      final entities = data['entities'] as Map<String, dynamic>? ?? {};
      if (entities.isNotEmpty) {
        final companions = entities.entries.map((e) {
          final m = Map<String, dynamic>.from(e.value as Map);
          return WorldEntitiesCompanion.insert(
            id: e.key,
            worldId: worldId,
            categorySlug: (m['type'] as String? ?? 'npc')
                .toLowerCase()
                .replaceAll(' ', '-'),
            name: m['name'] as String? ?? 'Unknown',
            source: Value(m['source'] as String? ?? ''),
            description: Value(m['description'] as String? ?? ''),
            imagePath: Value(m['image_path'] as String? ?? ''),
            imagesJson: Value(jsonEncode(m['images'] ?? [])),
            tagsJson: Value(jsonEncode(m['tags'] ?? [])),
            dmNotes: Value(m['dm_notes'] as String? ?? ''),
            pdfsJson: Value(jsonEncode(m['pdfs'] ?? [])),
            locationId: Value(m['location_id'] as String?),
            fieldsJson: Value(jsonEncode(m['attributes'] ?? {})),
            packageId: Value(m['package_id'] as String?),
            packageEntityId: Value(m['package_entity_id'] as String?),
            linked: Value((m['linked'] as bool?) ?? false),
          );
        }).toList();
        await _db.worldEntitiesDao.upsertAll(companions);
      }
    });
  }

  Future<void> _purgeWorld(String worldId) async {
    await _db.transaction(() async {
      await _db.worldEntitiesDao.deleteByWorld(worldId);
      await _db.worldSettingsDao.deleteByWorld(worldId);
      await _db.worldMapDataDao.deleteByWorld(worldId);
      await _db.worldSessionsDao.deleteByWorld(worldId);
      await _db.installedPackagesDao.deleteByWorld(worldId);
      await _db.entitySharesDao.deleteByWorld(worldId);
      await _db.worldMembersDao.deleteByWorld(worldId);
      await _db.worldInvitesDao.deleteByWorld(worldId);
      await _db.worldPackagesDao.deleteByWorld(worldId);
      await _db.mapPinsDao.deleteByWorld(worldId);
      await _db.timelinePinsDao.deleteByWorld(worldId);
      await _db.worldsDao.deleteById(worldId);
    });
  }
}
