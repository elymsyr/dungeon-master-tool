import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/config/app_paths.dart';
import '../../../domain/entities/schema/world_schema.dart';

/// Custom template'leri diske kaydetme/okuma.
/// Konum: cache/templates/{schemaId}.json
class TemplateLocalDataSource {
  String get _dir => p.join(AppPaths.cacheDir, 'templates');

  Future<void> _ensureDir() async {
    await Directory(_dir).create(recursive: true);
  }

  Future<List<WorldSchema>> loadAll() async {
    await _ensureDir();
    final dir = Directory(_dir);
    final templates = <WorldSchema>[];

    await for (final entry in dir.list()) {
      if (entry is File && entry.path.endsWith('.json')) {
        try {
          final content = await entry.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          templates.add(WorldSchema.fromJson(json));
        } catch (_) {
          // Bozuk dosyayı atla
        }
      }
    }

    templates.sort((a, b) => a.name.compareTo(b.name));
    return templates;
  }

  Future<void> save(WorldSchema schema) async {
    await _ensureDir();
    final file = File(p.join(_dir, '${schema.schemaId}.json'));
    await file.writeAsString(jsonEncode(schema.toJson()));
  }

  Future<void> delete(String schemaId) async {
    final file = File(p.join(_dir, '$schemaId.json'));
    if (await file.exists()) await file.delete();
  }

  /// Template'i .trash/ klasörüne taşı (soft delete, 30 gün sonra otomatik silinir).
  Future<void> moveToTrash(String schemaId, String templateName) async {
    final file = File(p.join(_dir, '$schemaId.json'));
    if (!await file.exists()) return;

    final trashTarget = p.join(
      AppPaths.trashDir,
      '${templateName}_${DateTime.now().millisecondsSinceEpoch}',
    );
    await Directory(trashTarget).create(recursive: true);

    // Template JSON'ı trash dizinine kopyala
    await file.copy(p.join(trashTarget, '$schemaId.json'));

    // Metadata yaz
    final metaFile = File(p.join(trashTarget, '.meta.json'));
    await metaFile.writeAsString(jsonEncode({
      'originalName': templateName,
      'type': 'Template',
      'schemaId': schemaId,
      'deletedAt': DateTime.now().toIso8601String(),
    }));

    // Orijinal dosyayı sil
    await file.delete();
  }

  /// Trash'ten template'i geri yükle.
  Future<void> restoreFromTrash(String trashDirName) async {
    final trashPath = p.join(AppPaths.trashDir, trashDirName);
    final trashDir = Directory(trashPath);
    if (!await trashDir.exists()) return;

    // .meta.json'dan schemaId'yi oku
    final metaFile = File(p.join(trashPath, '.meta.json'));
    if (!await metaFile.exists()) return;
    final meta =
        jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
    final schemaId = meta['schemaId'] as String?;
    if (schemaId == null) return;

    // Template JSON'ı bul
    final templateFile = File(p.join(trashPath, '$schemaId.json'));
    if (!await templateFile.exists()) return;

    // Geri yükle
    await _ensureDir();
    final targetFile = File(p.join(_dir, '$schemaId.json'));

    // Aynı ID ile zaten varsa üzerine yazma, yeni ID ile kaydet
    if (await targetFile.exists()) {
      // Mevcut template korunur, trash'ten gelen güncellenmiş isimle kaydedilir
      final content = await templateFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final schema = WorldSchema.fromJson(json);
      final now = DateTime.now().toUtc().toIso8601String();
      final restored = schema.copyWith(
        name: '${schema.name} (restored)',
        updatedAt: now,
      );
      await targetFile.writeAsString(jsonEncode(restored.toJson()));
    } else {
      await templateFile.copy(targetFile.path);
    }

    // Trash dizinini sil
    await trashDir.delete(recursive: true);
  }
}
