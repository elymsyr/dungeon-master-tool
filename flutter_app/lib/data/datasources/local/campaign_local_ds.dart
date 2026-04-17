import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:logger/logger.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;
import 'package:path/path.dart' as p;

import 'package:uuid/uuid.dart';

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
      'world_id': const Uuid().v4(),
      'created_at': DateTime.now().toIso8601String(),
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

    // Write metadata for reliable restoration
    final metaFile = File(p.join(trashTarget, '.meta.json'));
    await metaFile.writeAsString(jsonEncode({
      'originalName': campaignName,
      'type': 'World',
      'deletedAt': DateTime.now().toIso8601String(),
    }));

    _log.i('Campaign moved to trash: $campaignName');
  }

  /// .trash/ altındaki öğeleri listele.
  Future<List<TrashItem>> listTrash() async {
    final dir = Directory(AppPaths.trashDir);
    if (!await dir.exists()) return [];

    final items = <TrashItem>[];
    await for (final entry in dir.list()) {
      if (entry is! Directory) continue;
      final dirName = p.basename(entry.path);

      // Try .meta.json first
      final metaFile = File(p.join(entry.path, '.meta.json'));
      if (await metaFile.exists()) {
        try {
          final meta = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
          items.add(TrashItem(
            directoryName: dirName,
            originalName: meta['originalName'] as String? ?? dirName,
            type: meta['type'] as String? ?? 'World',
            deletedAt: DateTime.parse(meta['deletedAt'] as String),
          ));
          continue;
        } catch (_) {}
      }

      // Fallback: parse legacy format {name}_{timestamp}
      final lastUnderscore = dirName.lastIndexOf('_');
      if (lastUnderscore > 0) {
        final namePart = dirName.substring(0, lastUnderscore);
        final tsPart = dirName.substring(lastUnderscore + 1);
        final ts = int.tryParse(tsPart);
        if (ts != null) {
          items.add(TrashItem(
            directoryName: dirName,
            originalName: namePart,
            type: 'World',
            deletedAt: DateTime.fromMillisecondsSinceEpoch(ts),
          ));
          continue;
        }
      }

      // Worst case: use directory name and stat modified time
      final stat = await entry.stat();
      items.add(TrashItem(
        directoryName: dirName,
        originalName: dirName,
        type: 'World',
        deletedAt: stat.modified,
      ));
    }

    items.sort((a, b) => b.deletedAt.compareTo(a.deletedAt)); // newest first
    return items;
  }

  /// Trash'ten geri yükle.
  Future<String> restoreFromTrash(String trashDirName, String restoreName) async {
    final trashPath = p.join(AppPaths.trashDir, trashDirName);
    final restorePath = p.join(AppPaths.worldsDir, restoreName);

    final trashDir = Directory(trashPath);
    if (!await trashDir.exists()) {
      throw FileSystemException('Trash item not found', trashPath);
    }
    if (await Directory(restorePath).exists()) {
      throw FileSystemException('World with this name already exists', restorePath);
    }

    // Remove .meta.json before restoring
    final metaFile = File(p.join(trashPath, '.meta.json'));
    if (await metaFile.exists()) await metaFile.delete();

    // Update world_name in campaign data
    try {
      final data = await load(trashPath);
      data['world_name'] = restoreName;
      await save(trashPath, data);
    } catch (_) {
      // If data can't be loaded, still restore the directory
    }

    await trashDir.rename(restorePath);
    _log.i('Campaign restored from trash: $trashDirName → $restoreName');
    return restoreName;
  }

  /// Benzersiz geri yükleme ismi bul (çakışma varsa suffix ekle).
  Future<String> findUniqueRestoreName(String originalName) async {
    final worldsDir = Directory(AppPaths.worldsDir);
    final existing = <String>{};
    if (await worldsDir.exists()) {
      await for (final entry in worldsDir.list()) {
        if (entry is Directory) existing.add(p.basename(entry.path));
      }
    }

    if (!existing.contains(originalName)) return originalName;

    final restored = '$originalName (restored)';
    if (!existing.contains(restored)) return restored;

    for (int i = 2; ; i++) {
      final candidate = '$originalName ($i)';
      if (!existing.contains(candidate)) return candidate;
    }
  }

  /// Trash'ten kalıcı olarak sil.
  Future<void> permanentlyDeleteFromTrash(String trashDirName) async {
    final trashPath = p.join(AppPaths.trashDir, trashDirName);
    final dir = Directory(trashPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    _log.i('Permanently deleted from trash: $trashDirName');
  }

  /// MsgPack'ten gelen dynamic map'i `Map<String, dynamic>`'e dönüştür.
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

/// Silinen kampanya bilgisi.
class TrashItem {
  final String directoryName;
  final String originalName;
  final String type;
  final DateTime deletedAt;

  const TrashItem({
    required this.directoryName,
    required this.originalName,
    required this.type,
    required this.deletedAt,
  });
}

// Top-level functions for compute() — must not be closures or instance methods.
Uint8List _serializeInIsolate(Map<String, dynamic> data) => msgpack.serialize(data);
dynamic _deserializeInIsolate(Uint8List bytes) => msgpack.deserialize(bytes);
