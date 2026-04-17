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

  Future<void> delete(String id) async {
    final file = File(p.join(AppPaths.charactersDir, '$id.json'));
    if (await file.exists()) await file.delete();
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
