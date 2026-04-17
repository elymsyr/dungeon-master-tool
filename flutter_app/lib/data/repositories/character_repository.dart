import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/config/app_paths.dart';
import '../../domain/entities/character.dart';

/// Character JSON file storage.
/// Her karakter `{charactersDir}/{id}.json` altında saklanır.
class CharacterRepository {
  Future<List<Character>> loadAll() async {
    final dir = Directory(AppPaths.charactersDir);
    if (!await dir.exists()) return const [];
    final out = <Character>[];
    await for (final entry in dir.list()) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;
      try {
        final text = await entry.readAsString();
        final map = jsonDecode(text) as Map<String, dynamic>;
        _migrateLegacyWorldLinks(map);
        out.add(Character.fromJson(map));
      } catch (_) {
        // Skip corrupt files.
      }
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  Future<void> save(Character character) async {
    final dir = Directory(AppPaths.charactersDir);
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, '${character.id}.json'));
    await file.writeAsString(jsonEncode(character.toJson()));
  }

  /// Karakteri `.trash/` klasörüne taşı (soft delete, 30 gün sonra temizlenir).
  /// Restore için tüm karakter JSON'u ile birlikte `.meta.json` yazılır.
  Future<void> delete(String id, {String? displayName}) async {
    final file = File(p.join(AppPaths.charactersDir, '$id.json'));
    if (!await file.exists()) return;

    final originalName = (displayName ?? '').trim().isEmpty ? id : displayName!;
    final safeName = originalName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final trashTarget = p.join(
      AppPaths.trashDir,
      '${safeName}_${DateTime.now().millisecondsSinceEpoch}',
    );
    await Directory(trashTarget).create(recursive: true);

    await file.copy(p.join(trashTarget, '$id.json'));

    final metaFile = File(p.join(trashTarget, '.meta.json'));
    await metaFile.writeAsString(jsonEncode({
      'originalName': originalName,
      'type': 'Character',
      'characterId': id,
      'deletedAt': DateTime.now().toIso8601String(),
    }));

    await file.delete();
  }

  /// Trash'ten karakter dosyasını geri yükle. Meta'daki characterId orijinal
  /// konumdaki dosya adını verir; çakışma olursa UUID yenilenir.
  Future<Character?> restoreFromTrash(String trashDirName) async {
    final trashPath = p.join(AppPaths.trashDir, trashDirName);
    final trashDir = Directory(trashPath);
    if (!await trashDir.exists()) return null;

    final metaFile = File(p.join(trashPath, '.meta.json'));
    if (!await metaFile.exists()) return null;
    final meta = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
    final id = meta['characterId'] as String?;
    if (id == null) return null;

    final jsonFile = File(p.join(trashPath, '$id.json'));
    if (!await jsonFile.exists()) return null;

    await Directory(AppPaths.charactersDir).create(recursive: true);
    final targetFile = File(p.join(AppPaths.charactersDir, '$id.json'));
    if (await targetFile.exists()) {
      // Aynı id çakışması — eski veri korunsun, restore edilen düşsün.
      await trashDir.delete(recursive: true);
      return null;
    }
    await jsonFile.copy(targetFile.path);
    await trashDir.delete(recursive: true);

    try {
      final map = jsonDecode(await targetFile.readAsString()) as Map<String, dynamic>;
      _migrateLegacyWorldLinks(map);
      return Character.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Eski karakter JSON'larında `linked_worlds: [...]` + `linked_packages: [...]`
  /// vardı. Yeni model tek bir `world_name` bekliyor — ilk linkedWorld alınıp
  /// worldName'e taşınır, paketler tamamen bırakılır.
  void _migrateLegacyWorldLinks(Map<String, dynamic> map) {
    if (map.containsKey('world_name') && (map['world_name'] as String?) != null) {
      return;
    }
    final linkedWorlds = map['linked_worlds'];
    if (linkedWorlds is List && linkedWorlds.isNotEmpty) {
      final first = linkedWorlds.first;
      if (first is String && first.isNotEmpty) {
        map['world_name'] = first;
      }
    }
    map['world_name'] ??= '';
    map.remove('linked_worlds');
    map.remove('linked_packages');
  }
}
