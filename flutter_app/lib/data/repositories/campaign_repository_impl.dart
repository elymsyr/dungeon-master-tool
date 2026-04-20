import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/config/app_paths.dart';
import '../../domain/entities/schema/default_dnd5e_schema.dart';
import '../../domain/entities/schema/world_schema.dart' as domain;
import '../../domain/repositories/campaign_repository.dart';
import '../database/app_database.dart';
import '../datasources/local/campaign_local_ds.dart';
import '../schema/schema_migration.dart';

const _uuid = Uuid();

/// Lazy-initialized serialized form of the built-in D&D 5e schema. The
/// schema itself is static; serializing it fresh on every campaign load
/// produced a new map reference that defeated `worldSchemaProvider`'s
/// identity cache, forcing a deep Freezed re-parse on every world open.
/// Sharing the single JSON map reference across campaigns fixes that.
/// Serialized once at module load and deep-copied per campaign load.
/// Avoids the expensive `generateDefaultDnd5eSchema()` Freezed build +
/// `toJson()` walk on every world open while still handing each campaign
/// an independent map it can freely mutate.
final Map<String, dynamic> _defaultWorldSchemaJsonTemplate =
    generateDefaultDnd5eSchema().toJson();

Map<String, dynamic> _freshDefaultWorldSchemaJson() {
  return jsonDecode(jsonEncode(_defaultWorldSchemaJsonTemplate))
      as Map<String, dynamic>;
}

/// Drift-backed CampaignRepository implementasyonu.
/// MsgPack legacy desteği: migration sırasında eski data.dat dosyalarını okur.
class CampaignRepositoryImpl implements CampaignRepository {
  final AppDatabase _db;
  final CampaignLocalDataSource _localDs;

  CampaignRepositoryImpl(this._db, this._localDs);

  @override
  Future<List<String>> getAvailable() async {
    final dbCampaigns = await _db.campaignDao.getAvailableNames();
    // Legacy dosya bazlı kampanyaları da kontrol et (migration için)
    final fileCampaigns = await _localDs.getAvailableCampaigns();
    final allNames = <String>{...dbCampaigns, ...fileCampaigns};
    return allNames.toList()..sort();
  }

  @override
  Future<Map<String, dynamic>> load(String campaignName) async {
    // Önce SQLite'da var mı kontrol et
    final existing = await _db.campaignDao.getByName(campaignName);
    if (existing != null) {
      return _loadFromDb(existing.id);
    }

    // SQLite'da yoksa → legacy MsgPack dosyasından yükle ve migrate et
    final path = p.join(AppPaths.worldsDir, campaignName);
    final data = await _localDs.load(path);
    SchemaMigration.migrate(data);

    // SQLite'a migrate et
    await _migrateToDb(campaignName, data);

    return data;
  }

  @override
  Future<void> save(String campaignName, Map<String, dynamic> data) async {
    final existing = await _db.campaignDao.getByName(campaignName);
    if (existing != null) {
      await _saveToDb(existing.id, data);
    } else {
      // Yeni kampanya: SQLite'a yaz
      final campaignId = data['world_id'] as String? ?? _uuid.v4();
      data['world_id'] = campaignId;
      await _db.campaignDao.createCampaign(CampaignsCompanion.insert(
        id: campaignId,
        worldName: campaignName,
      ));
      await _saveToDb(campaignId, data);
    }
  }

  @override
  Future<void> delete(String campaignName) async {
    final existing = await _db.campaignDao.getByName(campaignName);

    // Try filesystem-based trash first (legacy MsgPack/JSON campaigns).
    await _localDs.deleteCampaign(campaignName);

    // If no filesystem directory existed (DB-only campaign), create a
    // trash entry with metadata so the item still appears in the trash list.
    final trashDir = Directory(AppPaths.trashDir);
    final trashTarget = p.join(
      trashDir.path,
      '${campaignName}_${DateTime.now().millisecondsSinceEpoch}',
    );
    final trashEntry = Directory(trashTarget);
    if (!await trashEntry.exists()) {
      await trashEntry.create(recursive: true);
      final metaFile = File(p.join(trashTarget, '.meta.json'));
      await metaFile.writeAsString(jsonEncode({
        'originalName': campaignName,
        'type': 'World',
        'deletedAt': DateTime.now().toIso8601String(),
      }));
    }

    // Now remove from database.
    if (existing != null) {
      await _db.campaignDao.deleteCampaign(existing.id);
    }
  }

  @override
  Future<String> create(String worldName, {domain.WorldSchema? template}) async {
    // Defensive: never insert a second row with the same worldName.
    // The Campaigns table currently has no unique constraint on
    // `worldName`, so without this check a re-create (e.g., after a
    // partially-failed create) silently doubled the row count and
    // poisoned later loads via "Bad state: Too many elements".
    final existing = await _db.campaignDao.getByName(worldName);
    if (existing != null) {
      throw StateError('Campaign already exists: $worldName');
    }

    final campaignId = _uuid.v4();
    // Post-v9: `world_schemas` table is gone. The single hardcoded D&D 5e
    // schema is injected at load time via `generateDefaultDnd5eSchema()`,
    // so the `template` arg is retained for interface compatibility but
    // never persisted.
    await _db.campaignDao.createCampaign(CampaignsCompanion.insert(
      id: campaignId,
      worldName: worldName,
    ));

    return worldName;
  }

  // --- Internal helpers ---

  Future<Map<String, dynamic>> _loadFromDb(String campaignId) async {
    final campaign = await _db.campaignDao.getById(campaignId);
    if (campaign == null) throw StateError('Campaign not found: $campaignId');

    // Entities
    final entityRows = await _db.entityDao.getAllForCampaign(campaignId);
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
      };
    }

    // Dynamic state blob (combat_state, map_data, mind_maps, vb.)
    final stateBlob = <String, dynamic>{};
    final stateRaw = campaign.stateJson;
    if (stateRaw.isNotEmpty && stateRaw != '{}') {
      try {
        final decoded = jsonDecode(stateRaw);
        if (decoded is Map) {
          stateBlob.addAll(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }

    // Post-v9: every campaign uses the single hardcoded D&D 5e schema.
    // The `world_schemas` table is gone; we inject the built-in schema
    // here so downstream UI (EntityCard / SessionScreen / CharacterEditor)
    // keeps rendering exactly as before. Serialized once at module load
    // and shared across every campaign load — the schema is static, so
    // reusing the identical map reference lets `worldSchemaProvider`'s
    // identity cache actually hit between world opens.
    final worldSchemaMap = _freshDefaultWorldSchemaJson();

    return {
      ...stateBlob, // combat_state, map_data, mind_maps, vb.
      'world_id': campaign.id,
      'world_name': campaign.worldName,
      'created_at': campaign.createdAt.toIso8601String(),
      'entities': entitiesMap,
      'world_schema': worldSchemaMap,
      'template_id': builtinDnd5eSchemaId,
      'template_original_hash': builtinDndOriginalHash,
    };
  }

  /// Anahtarları hangi tablolara map ettiğimizi izole eder. Geri kalan
  /// dynamic state (combat_state, map_data, mind_maps, vb.) `state_json`
  /// JSON blob'una yazılır — gelecekte normalize edilebilir.
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

  Future<void> _saveToDb(String campaignId, Map<String, dynamic> data) async {
    // Dynamic state blob — typed kolonlara map'lemediğimiz her şey.
    final stateBlob = <String, dynamic>{};
    for (final entry in data.entries) {
      if (_typedTopKeys.contains(entry.key)) continue;
      stateBlob[entry.key] = entry.value;
    }
    final stateJsonStr = jsonEncode(stateBlob);

    await _db.transaction(() async {
      // Update campaign + state blob
      await _db.campaignDao.updateCampaign(CampaignsCompanion(
        id: Value(campaignId),
        worldName: Value(data['world_name'] as String? ?? ''),
        stateJson: Value(stateJsonStr),
        updatedAt: Value(DateTime.now()),
      ));

      // Entities — full replace strategy
      await (_db.delete(_db.entities)
            ..where((t) => t.campaignId.equals(campaignId)))
          .go();
      final entities = data['entities'] as Map<String, dynamic>? ?? {};
      if (entities.isNotEmpty) {
        final companions = entities.entries.map((e) {
          final m = Map<String, dynamic>.from(e.value as Map);
          return EntitiesCompanion.insert(
            id: e.key,
            campaignId: campaignId,
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
          );
        }).toList();
        await _db.entityDao.insertAll(companions);
      }

      // Post-v9: `world_schemas` table dropped. `world_schema` in the data
      // map is reconstructed on load from the hardcoded built-in schema,
      // so nothing to persist here.
    });
  }

  Future<void> _migrateToDb(
      String campaignName, Map<String, dynamic> data) async {
    final campaignId = data['world_id'] as String? ?? _uuid.v4();
    data['world_id'] = campaignId;

    await _db.campaignDao.createCampaign(CampaignsCompanion.insert(
      id: campaignId,
      worldName: campaignName,
    ));

    await _saveToDb(campaignId, data);
  }
}
