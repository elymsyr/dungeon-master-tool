import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/config/app_paths.dart';
import '../../../domain/entities/schema/world_schema.dart';
import '../../../domain/entities/schema/world_schema_hash.dart';

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

  /// Schema'yı diske yaz.
  Future<void> save(WorldSchema schema) async {
    await _ensureDir();
    // Lazy-init the frozen lineage hash on first save. Built-in templates
    // already carry [builtinDndOriginalHash]; custom templates created
    // before the originalHash field landed get backfilled here using
    // their CURRENT content as the "original" — best-effort, but stable
    // forever once written. Subsequent saves preserve whatever is on the
    // schema (the editor passes the loaded value through unchanged), so
    // edits never overwrite the lineage identifier.
    final toPersist = schema.originalHash == null
        ? schema.copyWith(originalHash: computeWorldSchemaContentHash(schema))
        : schema;
    final file = File(p.join(_dir, '${toPersist.schemaId}.json'));
    await file.writeAsString(jsonEncode(toPersist.toJson()));
  }

  /// Load a single template by schema id. Returns null if there is no
  /// saved file for that id — used by the built-in template provider to
  /// prefer an admin-edited version over the code-generated default.
  Future<WorldSchema?> loadById(String schemaId) async {
    final file = File(p.join(_dir, '$schemaId.json'));
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return WorldSchema.fromJson(json);
    } catch (_) {
      return null;
    }
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

    // Aynı ID ile zaten varsa yeni ID ile kaydet (mevcut template korunsun)
    if (await targetFile.exists()) {
      final content = await templateFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final schema = WorldSchema.fromJson(json);
      final now = DateTime.now().toUtc().toIso8601String();
      final newId = const Uuid().v4();
      final restored = schema.copyWith(
        schemaId: newId,
        name: '${schema.name} (restored)',
        updatedAt: now,
      );
      final newFile = File(p.join(_dir, '$newId.json'));
      await newFile.writeAsString(jsonEncode(restored.toJson()));
    } else {
      await templateFile.copy(targetFile.path);
    }

    // Trash dizinini sil
    await trashDir.delete(recursive: true);
  }
}
