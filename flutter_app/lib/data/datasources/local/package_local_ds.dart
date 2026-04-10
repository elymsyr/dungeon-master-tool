import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/config/app_paths.dart';

/// Paket trash desteği — soft delete ve restore.
/// Paket verisi Drift DB'de yaşar; bu sınıf yalnızca trash I/O yönetir.
class PackageLocalDataSource {
  /// Paketi .trash/ klasörüne taşı (soft delete, 30 gün sonra otomatik silinir).
  /// [data] verilirse paket verisi de yedeklenir (restore için).
  Future<void> moveToTrash(String packageName, {Map<String, dynamic>? data}) async {
    final trashTarget = p.join(
      AppPaths.trashDir,
      '${packageName}_${DateTime.now().millisecondsSinceEpoch}',
    );
    await Directory(trashTarget).create(recursive: true);

    final metaFile = File(p.join(trashTarget, '.meta.json'));
    await metaFile.writeAsString(jsonEncode({
      'originalName': packageName,
      'type': 'Package',
      'deletedAt': DateTime.now().toIso8601String(),
    }));

    // Paket verisini yedekle
    if (data != null) {
      final dataFile = File(p.join(trashTarget, 'package_data.json'));
      await dataFile.writeAsString(jsonEncode(data));
    }
  }

  /// Trash'ten paket adını oku (restore için).
  Future<String?> readTrashPackageName(String trashDirName) async {
    final trashPath = p.join(AppPaths.trashDir, trashDirName);
    final metaFile = File(p.join(trashPath, '.meta.json'));
    if (!await metaFile.exists()) return null;
    try {
      final meta =
          jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
      return meta['originalName'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Trash'ten paketi geri yükle. Yedeklenmiş veriyi döndürür,
  /// bulunamazsa null döner. Çağıran taraf veriyi DB'ye geri yazar.
  Future<Map<String, dynamic>?> restoreFromTrash(String trashDirName) async {
    final trashPath = p.join(AppPaths.trashDir, trashDirName);
    final trashDir = Directory(trashPath);
    if (!await trashDir.exists()) return null;

    final dataFile = File(p.join(trashPath, 'package_data.json'));
    Map<String, dynamic>? data;
    if (await dataFile.exists()) {
      try {
        data = jsonDecode(await dataFile.readAsString()) as Map<String, dynamic>;
      } catch (_) {}
    }

    // Trash dizinini temizle
    await trashDir.delete(recursive: true);
    return data;
  }

  /// Trash dizinini kalıcı olarak sil.
  Future<void> permanentlyDeleteFromTrash(String trashDirName) async {
    final trashPath = p.join(AppPaths.trashDir, trashDirName);
    final dir = Directory(trashPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
