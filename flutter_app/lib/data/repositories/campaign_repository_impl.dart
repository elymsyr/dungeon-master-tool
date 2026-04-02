import 'dart:convert';

import 'package:path/path.dart' as p;

import '../../core/config/app_paths.dart';
import '../../domain/entities/schema/default_dnd5e_schema.dart';
import '../../domain/entities/schema/world_schema.dart';
import '../datasources/local/campaign_local_ds.dart';

/// Kampanya CRUD operasyonları.
class CampaignRepository {
  final CampaignLocalDataSource _localDs;

  CampaignRepository(this._localDs);

  Future<List<String>> getAvailable() => _localDs.getAvailableCampaigns();

  Future<Map<String, dynamic>> load(String campaignName) async {
    final path = p.join(AppPaths.worldsDir, campaignName);
    final data = await _localDs.load(path);

    // Schema migration: world_schema yoksa default üret
    if (!data.containsKey('world_schema')) {
      final schema = generateDefaultDnd5eSchema();
      // Freezed nesnelerini temiz Map'e çevir (MsgPack uyumlu)
    data['world_schema'] = jsonDecode(jsonEncode(schema.toJson()));
    }

    return data;
  }

  Future<void> save(String campaignName, Map<String, dynamic> data) async {
    final path = p.join(AppPaths.worldsDir, campaignName);
    await _localDs.save(path, data);
  }

  Future<String> create(String worldName, {WorldSchema? template}) async {
    await _localDs.createCampaign(worldName);

    // Seçilen template'i kampanyaya yaz
    final path = p.join(AppPaths.worldsDir, worldName);
    final data = await _localDs.load(path);
    final schema = template ?? generateDefaultDnd5eSchema();
    // Freezed nesnelerini temiz Map'e çevir (MsgPack uyumlu)
    data['world_schema'] = jsonDecode(jsonEncode(schema.toJson()));
    await _localDs.save(path, data);

    return worldName;
  }
}
