import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/config/app_paths.dart';
import '../../domain/entities/schema/default_dnd5e_schema.dart';
import '../../domain/entities/schema/world_schema.dart' as domain;
import '../../domain/repositories/campaign_repository.dart';
import '../database/app_database.dart' hide WorldSchema;
import '../datasources/local/campaign_local_ds.dart';
import '../schema/schema_migration.dart';

const _uuid = Uuid();

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
    if (existing != null) {
      await _db.campaignDao.deleteCampaign(existing.id);
    }
    // Legacy dosyayı da sil (varsa)
    await _localDs.deleteCampaign(campaignName);
  }

  @override
  Future<String> create(String worldName, {domain.WorldSchema? template}) async {
    final campaignId = _uuid.v4();
    final schema = template ?? generateDefaultDnd5eSchema();

    await _db.campaignDao.createCampaign(CampaignsCompanion.insert(
      id: campaignId,
      worldName: worldName,
    ));

    // Schema'yı kaydet
    final schemaJson = jsonDecode(jsonEncode(schema.toJson()));
    await (_db.into(_db.worldSchemas)).insert(WorldSchemasCompanion.insert(
      id: schema.schemaId,
      campaignId: campaignId,
      name: Value(schema.name),
      version: Value(schema.version),
      categoriesJson: Value(jsonEncode(schemaJson['categories'] ?? [])),
      encounterConfigJson:
          Value(jsonEncode(schemaJson['encounter_config'] ?? {})),
      encounterLayoutsJson:
          Value(jsonEncode(schemaJson['encounter_layouts'] ?? [])),
      metadataJson: Value(jsonEncode(schemaJson['metadata'] ?? {})),
    ));

    return worldName;
  }

  // --- Internal helpers ---

  Future<Map<String, dynamic>> _loadFromDb(String campaignId) async {
    final campaign = await _db.campaignDao.getById(campaignId);
    if (campaign == null) throw StateError('Campaign not found: $campaignId');

    // Schema
    final schemaRow = await (_db.select(_db.worldSchemas)
          ..where((t) => t.campaignId.equals(campaignId)))
        .getSingleOrNull();

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

    // WorldSchema reconstruct — camelCase keys (json_serializable default)
    Map<String, dynamic>? worldSchemaMap;
    if (schemaRow != null) {
      worldSchemaMap = {
        'schemaId': schemaRow.id,
        'name': schemaRow.name,
        'version': schemaRow.version,
        'baseSystem': schemaRow.baseSystem,
        'description': schemaRow.description,
        'categories': jsonDecode(schemaRow.categoriesJson),
        'encounterConfig': jsonDecode(schemaRow.encounterConfigJson),
        'encounterLayouts': jsonDecode(schemaRow.encounterLayoutsJson),
        'metadata': jsonDecode(schemaRow.metadataJson),
        'createdAt': schemaRow.createdAt.toIso8601String(),
        'updatedAt': schemaRow.updatedAt.toIso8601String(),
      };
    }

    return {
      ...stateBlob, // combat_state, map_data, mind_maps, vb.
      'world_id': campaign.id,
      'world_name': campaign.worldName,
      'created_at': campaign.createdAt.toIso8601String(),
      'entities': entitiesMap,
      if (worldSchemaMap != null) 'world_schema': worldSchemaMap,
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

      // WorldSchema
      final schemaData = data['world_schema'] as Map<String, dynamic>?;
      if (schemaData != null) {
        await (_db.delete(_db.worldSchemas)
              ..where((t) => t.campaignId.equals(campaignId)))
            .go();
        // camelCase (json_serializable) ve snake_case key'leri ikisini de kabul et.
        String pickStr(String camel, String snake, [String fallback = '']) =>
            (schemaData[camel] ?? schemaData[snake] ?? fallback) as String;
        dynamic pickAny(String camel, String snake) =>
            schemaData[camel] ?? schemaData[snake];
        await (_db.into(_db.worldSchemas)).insert(
          WorldSchemasCompanion.insert(
            id: pickStr('schemaId', 'schema_id', _uuid.v4()),
            campaignId: campaignId,
            name: Value(schemaData['name'] as String? ?? ''),
            version: Value(schemaData['version'] as String? ?? '1.0'),
            description: Value(schemaData['description'] as String? ?? ''),
            categoriesJson:
                Value(jsonEncode(schemaData['categories'] ?? [])),
            encounterConfigJson: Value(jsonEncode(
                pickAny('encounterConfig', 'encounter_config') ?? {})),
            encounterLayoutsJson: Value(jsonEncode(
                pickAny('encounterLayouts', 'encounter_layouts') ?? [])),
            metadataJson: Value(jsonEncode(schemaData['metadata'] ?? {})),
          ),
        );
      }
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
