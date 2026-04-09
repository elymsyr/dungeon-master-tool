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

    // Sessions + Encounters + Combatants
    final sessionRows = await _db.sessionDao.getAllForCampaign(campaignId);
    final sessionsList = <Map<String, dynamic>>[];
    for (final s in sessionRows) {
      final encounterRows =
          await _db.sessionDao.getEncountersForSession(s.id);
      final encountersList = <Map<String, dynamic>>[];
      for (final enc in encounterRows) {
        final combatantRows =
            await _db.sessionDao.getCombatantsForEncounter(enc.id);
        final combatantsList = <Map<String, dynamic>>[];
        for (final c in combatantRows) {
          final conditionRows =
              await _db.sessionDao.getConditionsForCombatant(c.id);
          combatantsList.add({
            'id': c.id,
            'name': c.name,
            'init': c.init,
            'ac': c.ac,
            'hp': c.hp,
            'max_hp': c.maxHp,
            'entity_id': c.entityId,
            'token_id': c.tokenId,
            'conditions': conditionRows
                .map((cond) => {
                      'name': cond.name,
                      'duration': cond.duration,
                      'initial_duration': cond.initialDuration,
                      'entity_id': cond.entityId,
                    })
                .toList(),
          });
        }
        encountersList.add({
          'id': enc.id,
          'name': enc.name,
          'combatants': combatantsList,
          'map_path': enc.mapPath,
          'token_size': enc.tokenSize,
          'grid_size': enc.gridSize,
          'grid_visible': enc.gridVisible,
          'grid_snap': enc.gridSnap,
          'feet_per_cell': enc.feetPerCell,
          'fog_data': enc.fogData,
          'annotation_data': enc.annotationData,
          'encounter_layout_id': enc.encounterLayoutId,
          'turn_index': enc.turnIndex,
          'round': enc.round,
          'token_positions': jsonDecode(enc.tokenPositionsJson),
          'token_size_multipliers': jsonDecode(enc.tokenSizeMultipliersJson),
        });
      }
      sessionsList.add({
        'id': s.id,
        'name': s.name,
        'notes': s.notes,
        'logs': s.logs,
        'encounters': encountersList,
        'active_encounter_id': s.isActive ? s.id : null,
      });
    }

    // Map pins
    final pinRows = await _db.mapDao.getPinsForCampaign(campaignId);
    final pins = pinRows
        .map((p) => {
              'id': p.id,
              'x': p.x,
              'y': p.y,
              'label': p.label,
              'pin_type': p.pinType,
              'entity_id': p.entityId,
              'note': p.note,
              'color': p.color,
              'style': jsonDecode(p.styleJson),
            })
        .toList();

    // Timeline pins
    final timelinePinRows =
        await _db.mapDao.getTimelinePinsForCampaign(campaignId);
    final timelinePins = timelinePinRows
        .map((tp) => {
              'id': tp.id,
              'x': tp.x,
              'y': tp.y,
              'day': tp.day,
              'note': tp.note,
              'entity_ids': jsonDecode(tp.entityIdsJson),
              'session_id': tp.sessionId,
              'parent_ids': jsonDecode(tp.parentIdsJson),
              'color': tp.color,
            })
        .toList();

    // Mind maps
    final mindMapIds =
        await _db.mindMapDao.getMapIdsForCampaign(campaignId);
    final mindMaps = <String, dynamic>{};
    for (final mapId in mindMapIds) {
      final nodes =
          await _db.mindMapDao.getNodesForMap(campaignId, mapId);
      final edges =
          await _db.mindMapDao.getEdgesForMap(campaignId, mapId);
      mindMaps[mapId] = {
        'nodes': nodes
            .map((n) => {
                  'id': n.id,
                  'label': n.label,
                  'node_type': n.nodeType,
                  'x': n.x,
                  'y': n.y,
                  'width': n.width,
                  'height': n.height,
                  'entity_id': n.entityId,
                  'image_url': n.imageUrl,
                  'content': n.content,
                  'style': jsonDecode(n.styleJson),
                  'color': n.color,
                })
            .toList(),
        'edges': edges
            .map((e) => {
                  'id': e.id,
                  'source_id': e.sourceId,
                  'target_id': e.targetId,
                  'label': e.label,
                  'style': jsonDecode(e.styleJson),
                })
            .toList(),
      };
    }

    // WorldSchema reconstruct
    Map<String, dynamic>? worldSchemaMap;
    if (schemaRow != null) {
      worldSchemaMap = {
        'schema_id': schemaRow.id,
        'name': schemaRow.name,
        'version': schemaRow.version,
        'base_system': schemaRow.baseSystem,
        'description': schemaRow.description,
        'categories': jsonDecode(schemaRow.categoriesJson),
        'encounter_config': jsonDecode(schemaRow.encounterConfigJson),
        'encounter_layouts': jsonDecode(schemaRow.encounterLayoutsJson),
        'metadata': jsonDecode(schemaRow.metadataJson),
        'created_at': schemaRow.createdAt.toIso8601String(),
        'updated_at': schemaRow.updatedAt.toIso8601String(),
      };
    }

    return {
      'world_id': campaign.id,
      'world_name': campaign.worldName,
      'created_at': campaign.createdAt.toIso8601String(),
      'entities': entitiesMap,
      'sessions': sessionsList,
      'map_data': {
        'pins': pins,
        'timeline': timelinePins,
      },
      'mind_maps': mindMaps,
      if (worldSchemaMap != null) 'world_schema': worldSchemaMap,
    };
  }

  Future<void> _saveToDb(String campaignId, Map<String, dynamic> data) async {
    await _db.transaction(() async {
      // Update campaign timestamp
      await _db.campaignDao.updateCampaign(CampaignsCompanion(
        id: Value(campaignId),
        worldName: Value(data['world_name'] as String? ?? ''),
        updatedAt: Value(DateTime.now()),
      ));

      // Entities — full replace strategy
      await (_db.delete(_db.entities)
            ..where((t) => t.campaignId.equals(campaignId)))
          .go();
      final entities = data['entities'] as Map<String, dynamic>? ?? {};
      if (entities.isNotEmpty) {
        final companions = entities.entries.map((e) {
          final m = e.value as Map<String, dynamic>;
          return EntitiesCompanion.insert(
            id: e.key,
            campaignId: campaignId,
            categorySlug:
                (m['type'] as String? ?? 'npc').toLowerCase().replaceAll(' ', '-'),
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
        await (_db.into(_db.worldSchemas)).insert(
          WorldSchemasCompanion.insert(
            id: schemaData['schema_id'] as String? ?? _uuid.v4(),
            campaignId: campaignId,
            name: Value(schemaData['name'] as String? ?? ''),
            version: Value(schemaData['version'] as String? ?? '1.0'),
            categoriesJson:
                Value(jsonEncode(schemaData['categories'] ?? [])),
            encounterConfigJson:
                Value(jsonEncode(schemaData['encounter_config'] ?? {})),
            encounterLayoutsJson:
                Value(jsonEncode(schemaData['encounter_layouts'] ?? [])),
            metadataJson:
                Value(jsonEncode(schemaData['metadata'] ?? {})),
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
