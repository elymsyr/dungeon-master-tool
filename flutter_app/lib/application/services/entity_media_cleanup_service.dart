import 'package:drift/drift.dart' show Variable;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/database/database_provider.dart';
import '../../data/network/asset_service.dart';
import '../../data/network/free_media_service.dart';
import '../../data/network/network_providers.dart';
import '../../domain/value_objects/asset_ref.dart';

/// Bir entity (karakter / world / package) silindiğinde o entity'ye ait cloud
/// medya objelerini siler — Cloudflare R2 (`community_assets`) + Supabase
/// `free-media` (`free_media_assets`).
///
/// Politika (kullanıcı kararı 2026-05-21):
/// - Cloud objesi entity silinir silinmez temizlenir.
/// - Local SHA cache KORUNUR (`keepCache: true`) → entity trash'ten restore
///   edilirse resim local'den render olur (cloud'a geri yüklenmez).
///
/// Güvenlik: SHA-dedupe nedeniyle tek cloud objesi birden çok entity'ce
/// paylaşılabilir. Bir ref silinmeden önce [_isReferencedElsewhere] ile
/// hayatta kalan başka bir entity'nin aynı ref'i kullanıp kullanmadığı
/// kontrol edilir — kullanıyorsa silme atlanır.
///
/// Tüm işlem best-effort: hata fırlatmaz, local silmeyi bloklamaz.
class EntityMediaCleanupService {
  EntityMediaCleanupService({
    required AppDatabase db,
    required AssetService assetService,
    required FreeMediaService freeMediaService,
  })  : _db = db,
        _asset = assetService,
        _free = freeMediaService;

  final AppDatabase _db;
  final AssetService _asset;
  final FreeMediaService _free;

  /// Karakter silindiğinde: portre (`dmt-public://`) + ek resimler
  /// (`dmt-asset://`). [characterJson] `Character.toJson()` formatı.
  Future<void> cleanupCharacter(Map<String, dynamic> characterJson) async {
    final refs = <String>{};
    _collectRefs(characterJson, refs);
    await _deleteRefs(refs);
  }

  /// World silindiğinde: dünyaya bağlı tüm counted + free medya. Counted
  /// medya `campaign_id == worldId`; free medya (kapak + world-bound karakter
  /// portreleri) `scope_id` worldId veya kampanya adı olabilir.
  Future<void> cleanupWorld({
    required String worldId,
    required String campaignName,
  }) async {
    final refs = await _scopedRefs(
      countedScopes: {worldId, campaignName},
      freeScopes: {worldId, campaignName},
    );
    await _deleteRefs(refs);
  }

  /// Package silindiğinde: paket scope'una bağlı medya. Counted + free medya
  /// için scope = paket adı.
  Future<void> cleanupPackage({required String packageName}) async {
    final refs = await _scopedRefs(
      countedScopes: {packageName},
      freeScopes: {packageName},
    );
    await _deleteRefs(refs);
  }

  /// Bir kapak/portre DEĞİŞTİRİLDİĞİNDE eski cloud ref'i temizler. Yeni ref
  /// DB'ye commit edildikten SONRA çağrılmalı — aksi halde [_isReferencedElsewhere]
  /// satırın kendi bayat ref'ini görür ve silmeyi yanlışlıkla atlar.
  Future<void> cleanupReplacedRef({
    required String? oldRef,
    required String? newRef,
  }) async {
    final old = oldRef?.trim() ?? '';
    if (old.isEmpty || old == (newRef?.trim() ?? '')) return;
    final r = AssetRef(old);
    if (!r.isCloud && !r.isPublic) return; // local/transient → no-op
    await _deleteRefs({old});
  }

  // ── discovery ─────────────────────────────────────────────────────────

  /// `community_assets` / `free_media_assets` tablolarından scope'a bağlı
  /// ref'leri toplar. counted → `dmt-asset://`, free → `dmt-public://`.
  Future<Set<String>> _scopedRefs({
    required Set<String> countedScopes,
    required Set<String> freeScopes,
  }) async {
    final refs = <String>{};
    for (final scope in countedScopes) {
      if (scope.isEmpty) continue;
      try {
        for (final row in await _asset.listAssetsForCampaign(scope)) {
          refs.add(AssetRef.formatCloudUri(row.r2Key));
        }
      } catch (e) {
        debugPrint('media cleanup: counted scope "$scope" list error: $e');
      }
    }
    for (final scope in freeScopes) {
      if (scope.isEmpty) continue;
      try {
        for (final row in await _free.listForScope(scope)) {
          refs.add(row.ref);
        }
      } catch (e) {
        debugPrint('media cleanup: free scope "$scope" list error: $e');
      }
    }
    return refs;
  }

  /// JSON ağacını gezer, `dmt-asset://` ve `dmt-public://` string'lerini toplar.
  void _collectRefs(Object? node, Set<String> out) {
    if (node is String) {
      if (node.startsWith(AssetRef.scheme) ||
          node.startsWith(AssetRef.publicScheme)) {
        out.add(node);
      }
    } else if (node is Map) {
      for (final v in node.values) {
        _collectRefs(v, out);
      }
    } else if (node is List) {
      for (final v in node) {
        _collectRefs(v, out);
      }
    }
  }

  // ── delete ────────────────────────────────────────────────────────────

  Future<void> _deleteRefs(Set<String> refs) async {
    for (final raw in refs) {
      try {
        if (await _isReferencedElsewhere(raw)) continue;
        final ref = AssetRef(raw);
        if (ref.isCloud) {
          final key = ref.r2Key;
          if (key != null) await _asset.deleteAsset(key, keepCache: true);
        } else if (ref.isPublic) {
          final path = ref.publicPath;
          if (path != null) {
            await _free.deleteFreeMedia(path, keepCache: true);
          }
        }
      } catch (e) {
        debugPrint('media cleanup: delete "$raw" error: $e');
      }
    }
  }

  /// Hayatta kalan (silinmemiş) bir entity hâlâ [ref]'i kullanıyor mu?
  /// Kullanıyorsa cloud objesi silinmemeli (paylaşılan SHA-dedupe objesi).
  ///
  /// Tarama hatasında güvenli tarafa düşer (referans VAR sayar → silmez).
  Future<bool> _isReferencedElsewhere(String ref) async {
    const sql = '''
SELECT 1 FROM world_characters WHERE payload_json LIKE ?1
UNION ALL
SELECT 1 FROM world_entities
  WHERE image_path LIKE ?1 OR images_json LIKE ?1 OR fields_json LIKE ?1
UNION ALL
SELECT 1 FROM package_entities
  WHERE image_path LIKE ?1 OR images_json LIKE ?1 OR fields_json LIKE ?1
UNION ALL
SELECT 1 FROM world_map_data WHERE data_json LIKE ?1
UNION ALL
SELECT 1 FROM world_settings WHERE settings_json LIKE ?1
UNION ALL
SELECT 1 FROM packages WHERE state_json LIKE ?1
LIMIT 1
''';
    try {
      final rows = await _db.customSelect(
        sql,
        variables: [Variable<String>('%$ref%')],
      ).get();
      return rows.isNotEmpty;
    } catch (e) {
      debugPrint('media cleanup: ref-scan error for "$ref": $e');
      return true;
    }
  }
}

/// Supabase + Worker konfigüre değilse null döner — çağıranlar no-op yapar.
final entityMediaCleanupServiceProvider =
    Provider<EntityMediaCleanupService?>((ref) {
  final asset = ref.watch(assetServiceProvider);
  final free = ref.watch(freeMediaServiceProvider);
  if (asset == null || free == null) return null;
  return EntityMediaCleanupService(
    db: ref.watch(appDatabaseProvider),
    assetService: asset,
    freeMediaService: free,
  );
});
