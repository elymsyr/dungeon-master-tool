import 'dart:io';

import '../../core/utils/deep_copy.dart';
import '../../data/network/asset_service.dart';
import '../../data/network/free_media_service.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../../domain/value_objects/media_kind.dart';

/// Karakter medyasının bulut kopyasını üretir — `world_characters` satırı
/// yazılmadan hemen önce (`character_provider._pushCharacterToMirror`).
///
/// Dünyanın geri kalanı buluta HİÇ çıkmaz; sayılan katman Phase D'de
/// kaldırıldı. Karakter bunun istisnası: `world_characters` beş abone
/// tablodan biri, yani karakter her zaman sync'tir ve medyası oturum
/// ortasında LRU'ya yem olmamalı. Bu yüzden:
///   - portre → ücretsiz Supabase Storage (`dmt-public://`, kotasız),
///   - ek resimler → **pinned** R2 havuzu (`pub/{sha}{ext}`), refcount sahibi
///     `char:{characterId}`.
///
/// Zaten bulutta olan (local olmayan) ref'lere dokunulmaz; map deep-clone
/// edilir, orijinal değişmez.
class MediaBundler {
  MediaBundler(this._assetService, {this.freeMediaService});

  final AssetService _assetService;

  /// Ücretsiz medya (karakter portresi) için. Null ise portre local kalır.
  final FreeMediaService? freeMediaService;

  /// Bir karakter JSON map'inin (`Character.toJson()` formatı) medyasını
  /// bundle eder. Tek dosya hatası akışı kesmez — ref'siz satır yine de
  /// karakteri taşır.
  Future<Map<String, dynamic>> bundleCharacterMedia({
    required String scopeId,
    required Map<String, dynamic> characterMap,
  }) async {
    final cloned = deepCopyJson(characterMap) as Map<String, dynamic>;
    final entity = cloned['entity'];
    if (entity is! Map<String, dynamic>) return cloned;
    final characterId = cloned['id'] as String? ?? '';

    // Portre → ücretsiz Supabase Storage (quota'ya sayılmaz).
    final portrait = entity['imagePath'];
    if (portrait is String &&
        portrait.isNotEmpty &&
        AssetRef(portrait).isLocal) {
      final ref =
          await _uploadFree(portrait, MediaKind.characterPortrait, scopeId);
      if (ref != null) entity['imagePath'] = ref;
    }

    // Ek resimler → pinned havuz.
    final images = entity['images'];
    if (images is List && characterId.isNotEmpty) {
      for (var i = 0; i < images.length; i++) {
        final raw = images[i];
        if (raw is! String || raw.isEmpty || !AssetRef(raw).isLocal) continue;
        final ref = await _uploadPinned(
          raw,
          MediaKind.characterExtraImage,
          characterPinKey(characterId),
        );
        if (ref != null) images[i] = ref;
      }
    }
    return cloned;
  }

  /// `pub_asset_refs.ref_key` — karakterin pinned medyasının refcount sahibi.
  /// Karakter silinince [AssetService.releasePub] bu key ile çağrılır.
  static String characterPinKey(String characterId) => 'char:$characterId';

  /// Servis yoksa / dosya yoksa / hata olursa null (caller local path'i korur).
  Future<String?> _uploadFree(
    String localPath,
    MediaKind kind,
    String scopeId,
  ) async {
    final svc = freeMediaService;
    if (svc == null) return null;
    final file = File(localPath);
    if (!await file.exists()) return null;
    try {
      final uri = await svc.uploadFreeMedia(file, kind: kind, scopeId: scopeId);
      return uri.toString();
    } catch (_) {
      return null;
    }
  }

  /// Local path'i pinned havuza yükler, `dmt-asset://pub/{sha}{ext}` döner.
  ///
  /// ponytail: aynı [refKey] altında eski sha bırakılmıyor — kullanıcı
  /// resmini değiştirirse eskisi karakter silinene kadar refcount'ta kalır.
  /// Ölçülür bir sızıntı olursa bundle öncesi `releasePub(refKey)` çağrılır.
  Future<String?> _uploadPinned(
    String localPath,
    MediaKind kind,
    String refKey,
  ) async {
    final file = File(localPath);
    if (!await file.exists()) return null;
    try {
      final uri = await _assetService.uploadPub(file, kind: kind, refKey: refKey);
      return uri.toString();
    } catch (_) {
      return null;
    }
  }
}
