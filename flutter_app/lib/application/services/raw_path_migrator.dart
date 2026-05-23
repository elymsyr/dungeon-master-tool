import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';
import '../../data/network/asset_service.dart';
import '../../data/network/free_media_service.dart';
import '../../data/network/network_providers.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../../domain/value_objects/media_kind.dart';

/// F11 — one-time raw filesystem path → AssetRef migrator.
///
/// Mevcut entity'lerin (`world_entities`, `world_characters`, vb.) JSON
/// blob'larında ham `image_path`/`images[]` field'ları kalmış olabilir.
/// Bu servis arka planda bunları tarar, `MediaBundler` benzeri akışla
/// `AssetService`/`FreeMediaService`'e yükler, `dmt-asset://` ya da
/// `dmt-public://` ref'lerine çevirir + row'u günceller.
///
/// UX kararı: **otomatik arka plan, sessiz**. Beta DM bootstrap'tan sonra
/// (campaign_provider.completeLoad → trigger noktası — wiring sonraki PR)
/// tetiklenir. Hata sessizce log'a; `migration_progress` tablosunda
/// resume state tutulur (idempotent).
///
/// Batch: 10 row/sec rate limit (UI yumuşaklığı için), per-table dispatch.
class RawPathMigrator {
  RawPathMigrator({
    required AppDatabase db,
    required AssetService? assetService,
    required FreeMediaService? freeMediaService,
  })  : _db = db,
        _asset = assetService,
        _free = freeMediaService;

  final AppDatabase _db;
  final AssetService? _asset;
  final FreeMediaService? _free;

  static const String migrationName = 'raw_path_to_assetref_v1';
  static const Duration batchPause = Duration(milliseconds: 100);

  bool _running = false;

  /// Dünya bazlı migrate. [campaignId] R2 upload için scope.
  /// İşlem zaten tamamlandıysa no-op.
  Future<MigrateResult> migrateWorld({
    required String worldId,
    required String campaignId,
  }) async {
    if (_running) return MigrateResult.empty();
    if (_asset == null || _free == null) return MigrateResult.empty();

    _running = true;
    final result = MigrateResult();
    try {
      final completed = await _isCompleted(worldId);
      if (completed) return result;

      await _migrateCharacters(
        worldId: worldId,
        campaignId: campaignId,
        result: result,
      );
      await _migrateEntities(
        worldId: worldId,
        campaignId: campaignId,
        result: result,
      );

      await _markCompleted(worldId);
    } catch (e, st) {
      debugPrint('RawPathMigrator error: $e\n$st');
    } finally {
      _running = false;
    }
    return result;
  }

  Future<bool> _isCompleted(String worldId) async {
    final rows = await _db.customSelect(
      'SELECT completed FROM migration_progress '
      'WHERE migration_name = ? AND world_id = ?',
      variables: [
        const Variable<String>(migrationName),
        Variable<String>(worldId),
      ],
    ).get();
    if (rows.isEmpty) return false;
    return rows.first.read<int>('completed') == 1;
  }

  Future<void> _markCompleted(String worldId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customStatement(
      'INSERT INTO migration_progress '
      '(migration_name, world_id, last_id, completed, updated_at) '
      'VALUES (?, ?, NULL, 1, ?) '
      'ON CONFLICT(migration_name, world_id) '
      'DO UPDATE SET completed = 1, updated_at = excluded.updated_at',
      [migrationName, worldId, now],
    );
  }

  Future<void> _migrateCharacters({
    required String worldId,
    required String campaignId,
    required MigrateResult result,
  }) async {
    final rows = await _db.customSelect(
      'SELECT id, payload_json FROM world_characters WHERE world_id = ?',
      variables: [Variable<String>(worldId)],
    ).get();
    for (final r in rows) {
      final id = r.read<String>('id');
      final raw = r.read<String>('payload_json');
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) continue;
        final updated = await _rewriteTree(
          decoded,
          campaignId: campaignId,
          portraitMode: true,
          result: result,
        );
        if (updated) {
          await _db.customStatement(
            'UPDATE world_characters SET payload_json = ? WHERE id = ?',
            [jsonEncode(decoded), id],
          );
          result.rowsUpdated++;
        }
      } catch (e) {
        debugPrint('RawPathMigrator char $id error: $e');
      }
      await Future<void>.delayed(batchPause);
    }
  }

  Future<void> _migrateEntities({
    required String worldId,
    required String campaignId,
    required MigrateResult result,
  }) async {
    final rows = await _db.customSelect(
      'SELECT id, image_path, images_json, fields_json FROM world_entities '
      'WHERE world_id = ?',
      variables: [Variable<String>(worldId)],
    ).get();
    for (final r in rows) {
      final id = r.read<String>('id');
      final imagePath = r.readNullable<String>('image_path');
      final imagesJson = r.readNullable<String>('images_json');
      final fieldsJson = r.readNullable<String>('fields_json');

      String? newImagePath = imagePath;
      String? newImagesJson = imagesJson;
      String? newFieldsJson = fieldsJson;
      var changed = false;

      // image_path: portre değil — entity card image → counted.
      if (imagePath != null && _needsMigrate(imagePath)) {
        final ref = await _uploadIfFile(
          imagePath,
          MediaKind.worldEntityImage,
          campaignId,
        );
        if (ref != null) {
          newImagePath = ref;
          result.refsCreated++;
          changed = true;
        }
      }

      if (imagesJson != null) {
        try {
          final decoded = jsonDecode(imagesJson);
          if (decoded is List) {
            final out = <dynamic>[];
            var anyChanged = false;
            for (final v in decoded) {
              if (v is String && _needsMigrate(v)) {
                final ref = await _uploadIfFile(
                  v,
                  MediaKind.worldEntityImage,
                  campaignId,
                );
                if (ref != null) {
                  out.add(ref);
                  result.refsCreated++;
                  anyChanged = true;
                } else {
                  out.add(v);
                }
              } else {
                out.add(v);
              }
            }
            if (anyChanged) {
              newImagesJson = jsonEncode(out);
              changed = true;
            }
          }
        } catch (_) {}
      }

      if (fieldsJson != null) {
        try {
          final decoded = jsonDecode(fieldsJson);
          if (decoded is Map<String, dynamic>) {
            final any = await _rewriteTree(
              decoded,
              campaignId: campaignId,
              portraitMode: false,
              result: result,
            );
            if (any) {
              newFieldsJson = jsonEncode(decoded);
              changed = true;
            }
          }
        } catch (_) {}
      }

      if (changed) {
        await _db.customStatement(
          'UPDATE world_entities SET image_path = ?, images_json = ?, '
          'fields_json = ? WHERE id = ?',
          [newImagePath, newImagesJson, newFieldsJson, id],
        );
        result.rowsUpdated++;
      }
      await Future<void>.delayed(batchPause);
    }
  }

  /// JSON tree'sini in-place mutate eder: string field'ları AssetRef-değil
  /// File var ise upload edip ref'le değiştir. [portraitMode] true → portre
  /// = free media; false → entity image = counted.
  Future<bool> _rewriteTree(
    Object? node, {
    required String campaignId,
    required bool portraitMode,
    required MigrateResult result,
  }) async {
    if (node is Map) {
      var any = false;
      for (final key in node.keys.toList()) {
        final v = node[key];
        if (v is String && _needsMigrate(v)) {
          final kind = portraitMode && _looksLikePortraitKey(key.toString())
              ? MediaKind.characterPortrait
              : MediaKind.worldEntityImage;
          final ref = await _uploadIfFile(v, kind, campaignId);
          if (ref != null) {
            node[key] = ref;
            result.refsCreated++;
            any = true;
          }
        } else {
          final child = await _rewriteTree(
            v,
            campaignId: campaignId,
            portraitMode: portraitMode,
            result: result,
          );
          if (child) any = true;
        }
      }
      return any;
    }
    if (node is List) {
      var any = false;
      for (var i = 0; i < node.length; i++) {
        final v = node[i];
        if (v is String && _needsMigrate(v)) {
          final ref = await _uploadIfFile(
            v,
            MediaKind.worldEntityImage,
            campaignId,
          );
          if (ref != null) {
            node[i] = ref;
            result.refsCreated++;
            any = true;
          }
        } else {
          final child = await _rewriteTree(
            v,
            campaignId: campaignId,
            portraitMode: portraitMode,
            result: result,
          );
          if (child) any = true;
        }
      }
      return any;
    }
    return false;
  }

  bool _needsMigrate(String s) {
    if (s.isEmpty) return false;
    if (s.startsWith(AssetRef.scheme) ||
        s.startsWith(AssetRef.publicScheme) ||
        s.startsWith(AssetRef.transientScheme)) {
      return false;
    }
    // Heuristic: path benzeri + bilinen image uzantısı
    if (!s.contains('/')) return false;
    return RegExp(r'\.(png|jpe?g|webp|gif)$', caseSensitive: false)
        .hasMatch(s);
  }

  bool _looksLikePortraitKey(String key) {
    final lower = key.toLowerCase();
    return lower.contains('portrait') ||
        lower == 'image_path' ||
        lower == 'imagepath' ||
        lower == 'cover';
  }

  Future<String?> _uploadIfFile(
    String path,
    MediaKind kind,
    String campaignId,
  ) async {
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      if (kind.counted) {
        final uri = await _asset!.uploadAsset(
          f,
          campaignId: campaignId,
          kind: kind,
        );
        return uri.toString();
      } else {
        final uri = await _free!.uploadFreeMedia(
          f,
          kind: kind,
          scopeId: campaignId,
        );
        return uri.toString();
      }
    } catch (e) {
      debugPrint('RawPathMigrator upload error path=$path: $e');
      return null;
    }
  }
}

class MigrateResult {
  MigrateResult({
    this.rowsScanned = 0,
    this.rowsUpdated = 0,
    this.refsCreated = 0,
  });

  factory MigrateResult.empty() => MigrateResult();

  int rowsScanned;
  int rowsUpdated;
  int refsCreated;
}

final rawPathMigratorProvider = Provider<RawPathMigrator>((ref) {
  return RawPathMigrator(
    db: ref.watch(appDatabaseProvider),
    assetService: ref.watch(assetServiceProvider),
    freeMediaService: ref.watch(freeMediaServiceProvider),
  );
});
