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
}
