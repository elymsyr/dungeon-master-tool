import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;

import '../../core/config/app_paths.dart';
import '../../domain/entities/character.dart';
import '../database/app_database.dart';

/// Character persistence — Drift-backed since PR-SYNC-0.
///
/// The old per-file JSON store at `{charactersDir}/{id}.json` is preserved
/// as a recovery snapshot until PR-SYNC-6; new writes only touch Drift.
/// `delete()` continues to write trash sidecar JSON so restore-from-trash
/// keeps working without a Drift-backed trash bin.
class CharacterLoadResult {
  final List<Character> chars;

  /// `worldId` set olmayan ve sadece legacy `world_name` taşıyan karakterlerin
  /// id→name eşlemesi. `_backfillWorldIds` campaign listesi yüklendiğinde bu
  /// haritadan worldId'ye migrate eder.
  final Map<String, String> legacyWorldNames;
  const CharacterLoadResult({
    required this.chars,
    required this.legacyWorldNames,
  });
}

class CharacterRepository {
  CharacterRepository(this._db);

  final AppDatabase _db;

  Future<List<Character>> loadAll() async => (await loadAllWithLegacy()).chars;

  Future<CharacterLoadResult> loadAllWithLegacy() async {
    final rows = await _db.characterDao.getAll();
    final out = <Character>[];
    final legacy = <String, String>{};
    for (final row in rows) {
      try {
        final map = _rowToCharacterJson(row);
        _migrateLegacyWorldLinks(map);
        final id = map['id'] as String?;
        final legacyName = map.remove('world_name');
        if (id != null &&
            legacyName is String &&
            legacyName.isNotEmpty &&
            (map['world_id'] == null ||
                (map['world_id'] as String).isEmpty)) {
          legacy[id] = legacyName;
        }
        out.add(Character.fromJson(map));
      } catch (_) {
        // Skip corrupt rows — rare since payload was written by us.
      }
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return CharacterLoadResult(chars: out, legacyWorldNames: legacy);
  }

  Future<void> save(Character character) async {
    await _db.characterDao.upsert(_characterToCompanion(character));
  }

  /// Karakteri `.trash/` klasörüne taşı (soft delete, 30 gün sonra temizlenir).
  /// Restore için tüm karakter JSON'u ile birlikte `.meta.json` yazılır.
  Future<void> delete(String id, {String? displayName}) async {
    final row = await _db.characterDao.getById(id);
    if (row == null) return;

    final originalName = (displayName ?? '').trim().isEmpty ? id : displayName!;
    final safeName = originalName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final trashTarget = p.join(
      AppPaths.trashDir,
      '${safeName}_${DateTime.now().millisecondsSinceEpoch}',
    );
    await Directory(trashTarget).create(recursive: true);

    final map = _rowToCharacterJson(row);
    await File(p.join(trashTarget, '$id.json'))
        .writeAsString(jsonEncode(map));

    final metaFile = File(p.join(trashTarget, '.meta.json'));
    await metaFile.writeAsString(jsonEncode({
      'originalName': originalName,
      'type': 'Character',
      'characterId': id,
      'deletedAt': DateTime.now().toIso8601String(),
    }));

    await _db.characterDao.deleteById(id);

    // Best-effort cleanup of the legacy JSON snapshot file too — keeps
    // `charactersDir` tidy in the dual-stored window. Failure non-fatal.
    try {
      final legacy = File(p.join(AppPaths.charactersDir, '$id.json'));
      if (await legacy.exists()) await legacy.delete();
    } catch (_) {}
  }

  /// Trash'ten karakter dosyasını geri yükle. Meta'daki characterId orijinal
  /// konumdaki dosya adını verir; çakışma olursa restore düşer.
  Future<Character?> restoreFromTrash(String trashDirName) async {
    final trashPath = p.join(AppPaths.trashDir, trashDirName);
    final trashDir = Directory(trashPath);
    if (!await trashDir.exists()) return null;

    final metaFile = File(p.join(trashPath, '.meta.json'));
    if (!await metaFile.exists()) return null;
    final meta =
        jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
    final id = meta['characterId'] as String?;
    if (id == null) return null;

    final jsonFile = File(p.join(trashPath, '$id.json'));
    if (!await jsonFile.exists()) return null;

    final existing = await _db.characterDao.getById(id);
    if (existing != null) {
      // Aynı id çakışması — Drift'teki kalsın, restore düşsün.
      await trashDir.delete(recursive: true);
      return null;
    }

    try {
      final map =
          jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
      _migrateLegacyWorldLinks(map);
      map.remove('world_name');
      final c = Character.fromJson(map);
      await save(c);
      await trashDir.delete(recursive: true);
      return c;
    } catch (_) {
      return null;
    }
  }

  /// Eski karakter JSON'larında `linked_worlds: [...]` + `linked_packages: [...]`
  /// vardı. Şimdiki kanon link `world_id`; legacy `world_name` field'ı yine
  /// strip edilir (`loadAllWithLegacy` map'e taşır, sonra `_backfillWorldIds`
  /// resolve eder). `linked_*` listeleri silinir.
  void _migrateLegacyWorldLinks(Map<String, dynamic> map) {
    if (!map.containsKey('world_name')) {
      final linkedWorlds = map['linked_worlds'];
      if (linkedWorlds is List && linkedWorlds.isNotEmpty) {
        final first = linkedWorlds.first;
        if (first is String && first.isNotEmpty) {
          map['world_name'] = first;
        }
      }
    }
    map.remove('linked_worlds');
    map.remove('linked_packages');
  }

  /// Reconstructs the Character JSON map from a Drift row. Mirrors the
  /// shape produced by `Character.toJson()` so `Character.fromJson` is
  /// the single decode path.
  Map<String, dynamic> _rowToCharacterJson(CharacterRow row) {
    final entity = jsonDecode(row.entityJson) as Map<String, dynamic>;
    return {
      'id': row.id,
      'template_id': row.templateId,
      'template_name': row.templateName,
      'entity': entity,
      'world_id': row.worldId,
      'owner_id': row.ownerId,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
    };
  }

  CharactersCompanion _characterToCompanion(Character c) {
    final json = c.toJson();
    final entityJson = jsonEncode(json['entity']);
    return CharactersCompanion(
      id: Value(c.id),
      templateId: Value(c.templateId),
      templateName: Value(c.templateName),
      entityJson: Value(entityJson),
      worldId: Value(c.worldId),
      ownerId: Value(c.ownerId),
      createdAt: Value(
        DateTime.tryParse(c.createdAt)?.toUtc() ?? DateTime.now().toUtc(),
      ),
      updatedAt: Value(
        DateTime.tryParse(c.updatedAt)?.toUtc() ?? DateTime.now().toUtc(),
      ),
    );
  }
}
