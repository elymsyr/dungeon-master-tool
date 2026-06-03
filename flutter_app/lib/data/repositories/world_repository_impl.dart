import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../application/services/srd_core_bootstrap.dart';
import '../../application/services/srd_core_package_bootstrap.dart';
import '../database/util/builtin_synth.dart';
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
  Future<List<Map<String, String>>> installedPackages(
      String campaignName) async {
    final existing = await _findByName(campaignName);
    if (existing == null) return const [];
    final rows = await _db.installedPackagesDao.getByWorld(existing.id);
    return [
      for (final r in rows)
        if (r.packageName.isNotEmpty)
          {
            'id': r.packageId,
            'name': r.packageName,
            'version': r.packageVersion,
          },
    ];
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

  @override
  Future<void> saveEntity(
    String campaignName,
    String entityId,
    Map<String, dynamic> row,
  ) async {
    final existing = await _findByName(campaignName);
    if (existing == null) {
      throw StateError('World not found: $campaignName');
    }
    final worldId = existing.id;
    await _db.transaction(() async {
      await _db.worldEntitiesDao.upsert(_entityCompanion(worldId, entityId, row));
      await _touchWorld(worldId);
    });
  }

  @override
  Future<void> deleteEntity(String campaignName, String entityId) async {
    final existing = await _findByName(campaignName);
    if (existing == null) return;
    final worldId = existing.id;
    await _db.transaction(() async {
      await _db.worldEntitiesDao.deleteById(entityId);
      await _touchWorld(worldId);
    });
  }

  @override
  Future<void> saveSettingsPatch(
    String campaignName,
    Map<String, dynamic> patch,
  ) async {
    if (patch.isEmpty) return;
    final existing = await _findByName(campaignName);
    if (existing == null) {
      throw StateError('World not found: $campaignName');
    }
    final worldId = existing.id;
    await _db.transaction(() async {
      final row = await _db.worldSettingsDao.get(worldId);
      final merged = <String, dynamic>{};
      if (row != null && row.settingsJson.isNotEmpty &&
          row.settingsJson != '{}') {
        try {
          final decoded = jsonDecode(row.settingsJson);
          if (decoded is Map) {
            merged.addAll(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      }
      merged.addAll(patch);
      await _db.worldSettingsDao.upsert(WorldSettingsCompanion(
        worldId: Value(worldId),
        settingsJson: Value(jsonEncode(merged)),
        updatedAt: Value(DateTime.now()),
      ));
      await _touchWorld(worldId);
    });
  }

  @override
  Future<void> saveMapData(
    String campaignName,
    Map<String, dynamic> mapData,
  ) async {
    final existing = await _findByName(campaignName);
    if (existing == null) {
      throw StateError('World not found: $campaignName');
    }
    final worldId = existing.id;
    await _db.transaction(() async {
      await _db.worldMapDataDao.upsert(WorldMapDataCompanion(
        worldId: Value(worldId),
        dataJson: Value(jsonEncode(mapData)),
        updatedAt: Value(DateTime.now()),
      ));
      await _touchWorld(worldId);
    });
  }

  @override
  Future<void> saveSessions(
    String campaignName,
    List<Map<String, dynamic>> sessions,
  ) async {
    if (sessions.isEmpty) return;
    final existing = await _findByName(campaignName);
    if (existing == null) {
      throw StateError('World not found: $campaignName');
    }
    final worldId = existing.id;
    final companions = <WorldSessionsCompanion>[];
    for (final s in sessions) {
      final id = s['id'];
      if (id is! String) continue;
      // Strip typed columns from inner blob; they ride in their own fields.
      final inner = Map<String, dynamic>.from(s)
        ..remove('id')
        ..remove('name')
        ..remove('is_active')
        ..remove('sort_order');
      companions.add(WorldSessionsCompanion(
        id: Value(id),
        worldId: Value(worldId),
        name: Value((s['name'] as String?) ?? ''),
        dataJson: Value(jsonEncode(inner)),
        isActive: Value((s['is_active'] as bool?) ?? false),
        sortOrder: Value((s['sort_order'] as num?)?.toInt() ?? 0),
        updatedAt: Value(DateTime.now()),
      ));
    }
    if (companions.isEmpty) return;
    await _db.transaction(() async {
      await _db.worldSessionsDao.upsertAll(companions);
      await _touchWorld(worldId);
    });
  }

  @override
  Future<void> saveSession(
    String campaignName,
    Map<String, dynamic> session,
  ) async {
    await saveSessions(campaignName, [session]);
  }

  @override
  Future<void> deleteSession(String campaignName, String sessionId) async {
    final existing = await _findByName(campaignName);
    if (existing == null) return;
    await _db.transaction(() async {
      await _db.worldSessionsDao.deleteById(sessionId);
      await _touchWorld(existing.id);
    });
  }

  Future<void> _touchWorld(String worldId) async {
    // UPDATE only — `insertOnConflictUpdate` worldName gibi NOT NULL
    // alanları ister, ama burada salt timestamp bump amaçlı; INSERT path'i
    // çağrılırsa worldName eksik → InvalidDataException.
    await (_db.update(_db.worlds)..where((t) => t.id.equals(worldId)))
        .write(WorldsCompanion(updatedAt: Value(DateTime.now())));
  }

  WorldEntitiesCompanion _entityCompanion(
    String worldId,
    String entityId,
    Map<String, dynamic> m,
  ) {
    return WorldEntitiesCompanion.insert(
      id: entityId,
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
  }

  @override
  Future<bool> restoreFromTrash(String trashId) async {
    final trash = await _db.trashDao.getById(trashId);
    if (trash == null || trash.kind != 'world') return false;
    try {
      final payload = jsonDecode(trash.payloadJson) as Map<String, dynamic>;
      final restoredName =
          (payload['world_name'] as String?) ?? trash.sourceId;
      // Conflict — skip restore if a world with that name already exists.
      final clash = await _findByName(restoredName);
      if (clash != null) {
        await _db.trashDao.deleteById(trashId);
        return false;
      }
      await save(restoredName, payload);
      await _db.trashDao.deleteById(trashId);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> permanentlyDelete(String trashId) =>
      _db.trashDao.deleteById(trashId);

  // ── Internal helpers ─────────────────────────────────────────────────────

  // SS-1/DB-3: use the indexed name lookup instead of getAll() + linear scan
  // on every debounced row write (12 call sites).
  Future<World?> _findByName(String name) => _db.worldsDao.getByName(name);

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

    // Entities — joined from world_entities + synthesised built-in pack
    // entries (F1: built-in pack rows live in `package_entities`, not
    // duplicated per world).
    final entityRows = await _db.worldEntitiesDao.getByWorld(worldId);
    final entitiesMap = <String, dynamic>{};
    final coveredPackageEntityIds = <String>{};
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
      if (e.packageEntityId != null) {
        coveredPackageEntityIds.add(e.packageEntityId!);
      }
    }
    // Self-heal: ensure the built-in SRD pack link exists before synthesis.
    // A player who joined before the link-based idempotency fix has no
    // installed_packages row — without this, synthesis yields nothing and
    // the built-in catalog is empty. Cheap when already linked (one query).
    if (world.templateId == builtinDnd5eV2SchemaId) {
      await SrdCorePackageBootstrap(_db).ensureInstalled();
      await SrdCoreBootstrap(_db).ensureImported(
        worldId: worldId,
        build: generateBuiltinDnd5eV2Schema(),
      );
    }
    final synth = await synthesizeWorldBuiltins(
      _db,
      worldId,
      existingPackageEntityIds: coveredPackageEntityIds,
    );
    if (synth.entries.isNotEmpty) {
      entitiesMap.addAll(synth.entries);
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
      // Self-heal: a built-in world's stored schema snapshot predates newer
      // built-in categories (e.g. the `subspecies` category added 2026-06).
      // Overlay any built-in category missing from the snapshot so existing
      // worlds surface it without a per-world migration; user/custom (Tier-2)
      // categories in the snapshot are preserved. Snapshot stays untouched on
      // disk — refreshed naturally next time the schema is saved.
      if (templateId == builtinDnd5eV2SchemaId) {
        worldSchemaMap = _overlayMissingBuiltinCategories(worldSchemaMap);
      }
    }

    // Granular `world_map_data` Drift row — source-of-truth for map_data.
    // Settings_json may still carry a legacy `map_data` key (DM dual-write);
    // the typed row wins if present. App reopen path: without this, map
    // image vanishes on close→open when settings_json drift gets out of
    // sync with cloud (force-close before flush, partial sync, etc.).
    Map<String, dynamic>? mapDataOverride;
    final mapDataRow = await _db.worldMapDataDao.get(world.id);
    if (mapDataRow != null &&
        mapDataRow.dataJson.isNotEmpty &&
        mapDataRow.dataJson != '{}') {
      try {
        final decoded = jsonDecode(mapDataRow.dataJson);
        if (decoded is Map) {
          mapDataOverride = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    // Granular `world_sessions` Drift rows — source-of-truth for sessions.
    // Settings_json no longer carries sessions (PR-SYNC-3). Reconstruct from
    // typed rows so session tab persists across app reopens (without this,
    // sessions only live in-memory after a cloud sync apply).
    List<Map<String, dynamic>>? sessionsOverride;
    final sessionRows = await _db.worldSessionsDao.getByWorld(world.id);
    if (sessionRows.isNotEmpty) {
      sessionsOverride = <Map<String, dynamic>>[];
      for (final row in sessionRows) {
        Map<String, dynamic> inner = <String, dynamic>{};
        if (row.dataJson.isNotEmpty && row.dataJson != '{}') {
          try {
            final decoded = jsonDecode(row.dataJson);
            if (decoded is Map) {
              inner = Map<String, dynamic>.from(decoded);
            }
          } catch (_) {}
        }
        sessionsOverride.add(<String, dynamic>{
          ...inner,
          'id': row.id,
          'name': row.name,
          'is_active': row.isActive,
          'sort_order': row.sortOrder,
        });
      }
    }

    return {
      ...settingsBlob, // combat_state, mind_maps, map_view, mind_map_views, …
      'world_id': world.id,
      'world_name': world.worldName,
      'created_at': world.createdAt.toIso8601String(),
      'entities': entitiesMap,
      'world_schema': ?worldSchemaMap,
      'template_id': templateId,
      'template_hash': ?templateHash,
      'template_original_hash': ?templateOriginalHash,
      // Granular tables override anything that may have leaked into
      // settings_json blob — see comments above.
      if (mapDataOverride != null) 'map_data': mapDataOverride,
      if (sessionsOverride != null) 'sessions': sessionsOverride,
    };
  }

  /// Built-in category JSON, keyed by build, cached once (the generator is
  /// deterministic except for timestamps). Used by the load-time overlay.
  static List<Map<String, dynamic>>? _builtinCategoryJsonCache;

  static List<Map<String, dynamic>> _builtinCategoryJson() {
    final cached = _builtinCategoryJsonCache;
    if (cached != null) return cached;
    final schemaMap =
        deepCopyJson(generateBuiltinDnd5eV2Schema().schema.toJson())
            as Map<String, dynamic>;
    final cats = schemaMap['categories'];
    final out = <Map<String, dynamic>>[
      if (cats is List)
        for (final c in cats)
          if (c is Map) Map<String, dynamic>.from(c),
    ];
    return _builtinCategoryJsonCache = out;
  }

  /// Append any built-in category absent (by slug) from [snapshot]'s category
  /// list, preserving existing/custom categories and their order.
  Map<String, dynamic> _overlayMissingBuiltinCategories(
      Map<String, dynamic> snapshot) {
    final cats = snapshot['categories'];
    if (cats is! List) return snapshot;
    final present = <String>{
      for (final c in cats)
        if (c is Map && c['slug'] is String) c['slug'] as String,
    };
    final additions = [
      for (final c in _builtinCategoryJson())
        if (c['slug'] is String && !present.contains(c['slug'])) c,
    ];
    if (additions.isEmpty) return snapshot;
    final merged = Map<String, dynamic>.from(snapshot);
    merged['categories'] = [...cats, ...additions];
    return merged;
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

      // Entities — full replace, mirrors v11 semantics. F2 (row-level
      // migration) drives per-row updates via [saveEntity] / [deleteEntity];
      // this bulk path stays as the import/restore safety net.
      //
      // F1: entries marked `_synth: true` come from the built-in pack
      // synthesiser and never persist. EntityNotifier edits drop the flag
      // (its `_entityToMap` produces a fresh map), so an edited built-in
      // entry naturally writes through and forks at the same synth id.
      //
      // Beta-enter wipe defense (PR-B5): a payload that does NOT contain the
      // `entities` key is treated as "metadata-only save" — DO NOT delete the
      // existing rows. The cloud reconciler / preserve hydrators strip the
      // entities key from world_state because they're carried per-row through
      // granular tables; passing such a payload here used to wipe the world.
      // Trash restore, package import, and explicit re-save call sites still
      // pass the `entities` key (even if empty) and get full-replace semantics.
      if (data.containsKey('entities')) {
        await _db.worldEntitiesDao.deleteByWorld(worldId);
        final entities = data['entities'] as Map<String, dynamic>? ?? {};
        if (entities.isNotEmpty) {
          final companions = <WorldEntitiesCompanion>[];
          for (final e in entities.entries) {
            final m = Map<String, dynamic>.from(e.value as Map);
            if (m[synthFlagKey] == true) continue;
            companions.add(_entityCompanion(worldId, e.key, m));
          }
          if (companions.isNotEmpty) {
            await _db.worldEntitiesDao.upsertAll(companions);
          }
        }
      }
    });
  }

  Future<void> _purgeWorld(String worldId) async {
    await _db.transaction(() async {
      // Capture this world's package links BEFORE removing them so we can
      // purge orphaned materialized package rows (Req 3 lifecycle).
      final pkgLinks = await _db.installedPackagesDao.getByWorld(worldId);
      await _db.worldEntitiesDao.deleteByWorld(worldId);
      await _db.worldSettingsDao.deleteByWorld(worldId);
      await _db.worldMapDataDao.deleteByWorld(worldId);
      await _db.worldSessionsDao.deleteByWorld(worldId);
      await _db.installedPackagesDao.deleteByWorld(worldId);
      // After this world's links are gone, drop any materialized package whose
      // only home was this world. Standalone installs leave NO installed_packages
      // link, so they never appear here; built-in SRD is name-guarded; packages
      // still linked in another world survive (countWorldsForPackage > 0).
      for (final link in pkgLinks) {
        if (link.packageName == srdCorePackageName) continue;
        if (await _db.installedPackagesDao
                .countWorldsForPackage(link.packageId) >
            0) {
          continue;
        }
        await _db.packagesDao.deleteEntitiesByPackage(link.packageId);
        await _db.packagesDao.deleteSchemasByPackage(link.packageId);
        await _db.packagesDao.deletePackage(link.packageId);
      }
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
