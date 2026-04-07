import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:logger/logger.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;
import 'package:path/path.dart' as p;

import '../../../core/config/app_paths.dart';

final _log = Logger(printer: SimplePrinter());

/// MsgPack / JSON kampanya dosyası I/O.
/// Python DataManager.save_data() + CampaignManager birebir karşılığı.
class CampaignLocalDataSource {
  /// Kampanya verisini yükle. Önce MsgPack, fallback JSON.
  Future<Map<String, dynamic>> load(String campaignPath) async {
    final datFile = File(p.join(campaignPath, 'data.dat'));
    if (await datFile.exists()) {
      final bytes = await datFile.readAsBytes();
      final decoded = await compute(_deserializeInIsolate, bytes);
      return _toStringKeyMap(decoded);
    }

    // JSON fallback (legacy)
    final jsonFile = File(p.join(campaignPath, 'data.json'));
    if (await jsonFile.exists()) {
      final content = await jsonFile.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    }

    throw FileSystemException('Campaign data not found', campaignPath);
  }

  /// Kampanya verisini MsgPack olarak kaydet.
  Future<void> save(String campaignPath, Map<String, dynamic> data) async {
    final datFile = File(p.join(campaignPath, 'data.dat'));
    final bytes = await compute(_serializeInIsolate, data);
    await datFile.writeAsBytes(bytes);
  }

  /// worlds/ altındaki kampanya dizin isimlerini listele.
  Future<List<String>> getAvailableCampaigns() async {
    final worldsDir = Directory(AppPaths.worldsDir);
    if (!await worldsDir.exists()) return [];

    final entries = await worldsDir.list().toList();
    final campaigns = <String>[];
    for (final entry in entries) {
      if (entry is Directory) {
        final name = p.basename(entry.path);
        final hasDat = await File(p.join(entry.path, 'data.dat')).exists();
        final hasJson = await File(p.join(entry.path, 'data.json')).exists();
        if (hasDat || hasJson) {
          campaigns.add(name);
        }
      }
    }
    campaigns.sort();
    return campaigns;
  }

  /// Kampanya verisinden template adını oku (hafif — sadece schema name).
  Future<String> getTemplateName(String campaignPath) async {
    try {
      final data = await load(campaignPath);
      final schema = data['world_schema'];
      if (schema is Map) {
        return (schema['name'] as String?) ?? 'Unknown';
      }
    } catch (_) {}
    return 'D&D 5e (Default)';
  }

  /// Yeni kampanya oluştur.
  Future<String> createCampaign(String worldName) async {
    final campaignPath = p.join(AppPaths.worldsDir, worldName);
    final dir = Directory(campaignPath);
    if (await dir.exists()) {
      throw FileSystemException('Campaign already exists', campaignPath);
    }

    await dir.create(recursive: true);

    final defaultData = <String, dynamic>{
      'world_name': worldName,
      'entities': <String, dynamic>{},
      'map_data': {'image_path': '', 'pins': <dynamic>[], 'timeline': <dynamic>[]},
      'sessions': <dynamic>[],
      'last_active_session_id': null,
      'mind_maps': <String, dynamic>{},
    };

    await save(campaignPath, defaultData);
    _log.i('Campaign created: $worldName');
    return campaignPath;
  }

  /// Kampanyayı .trash/ klasörüne taşı (soft delete, 30 gün sonra otomatik silinir).
  Future<void> deleteCampaign(String campaignName) async {
    final campaignPath = p.join(AppPaths.worldsDir, campaignName);
    final dir = Directory(campaignPath);
    if (!await dir.exists()) return;

    final trashTarget = p.join(AppPaths.trashDir, '${campaignName}_${DateTime.now().millisecondsSinceEpoch}');
    await dir.rename(trashTarget);
    _log.i('Campaign moved to trash: $campaignName');
  }

  /// MsgPack'ten gelen dynamic map'i Map<String, dynamic>'e dönüştür.
  Map<String, dynamic> _toStringKeyMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _convertValue(v)));
    }
    return {};
  }

  dynamic _convertValue(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _convertValue(v)));
    }
    if (value is List) {
      return value.map(_convertValue).toList();
    }
    return value;
  }
}

// Top-level functions for compute() — must not be closures or instance methods.
Uint8List _serializeInIsolate(Map<String, dynamic> data) => msgpack.serialize(data);
dynamic _deserializeInIsolate(Uint8List bytes) => msgpack.deserialize(bytes);
