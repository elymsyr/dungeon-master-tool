import 'package:flutter/foundation.dart';

import '../../core/utils/deep_copy.dart';
import '../../data/network/asset_service.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../../domain/value_objects/media_kind.dart';
import 'asset_ref_resolver.dart';

/// Marketplace yayını öncesi payload'daki TÜM medyayı `pinned` sınıfına
/// (`pub/{sha}{ext}`) taşır ve ref'leri yerinde yeniden yazar.
///
/// Neden gerekli (docs/media-storage-redesign.md → "Marketplace"): yayın bugün
/// payload'ı olduğu gibi gönderiyor, yani ref'ler ya yayıncının local
/// path'lerine (indirende kırık) ya da sayılan `{uid}/` objelerine işaret
/// ediyor — sayılan katman sökülünce ikisi de ölür. `pinned` LRU'ya tabi
/// değildir, indirilebilirliği garantidir.
///
/// Tek gezgin, tüm itemType'lar: payload şekli world/package/character
/// arasında değişiyor, ama medya her zaman bir String yaprağı. Anahtar adına
/// göre değil **değerin kendisine** göre karar verir (bkz. [isMediaRef]).
///
/// Tek tek başarısızlıklar [PublishPinResult.failures]'a düşer ve o ref eski
/// hâliyle (yayıncının local path'i) kalır. Pinner bunu fırlatmaz — hangi
/// ref'lerin düştüğünü toplamak için gezinti sürer — ama **çağıran yayını
/// iptal etmeli**: kırık ref'li bir listing indirende sessizce boş açılır.
/// Bkz. `marketplace_listing_provider.publishSnapshot`. Kota hataları
/// ([PinnedQuotaExceededException]) gezintiyi anında keser.
class PublishMediaPinner {
  PublishMediaPinner(this._assets, this._resolver);

  final AssetService _assets;
  final AssetRefResolver _resolver;

  static const _imageExts = {'.png', '.jpg', '.jpeg', '.bmp', '.webp', '.gif'};

  /// [refKey] refcount sahibi — listing id. [payload] deep-clone edilir.
  Future<PublishPinResult> pin({
    required Map<String, dynamic> payload,
    required String refKey,
    required MediaKind kind,
  }) async {
    final cloned = deepCopyJson(payload) as Map<String, dynamic>;
    // Set: aynı ref payload'da N kez geçebilir, hata da N kez raporlanmasın.
    // Daha önemlisi negatif cache — `pub/{sha}` içerik adresli, başarısız bir
    // upload rollback'te `pub_asset_release` çağırıyor. Aynı ref'i tekrar
    // denemek aynı sha'yı ikinci kez rezerve edip ikinci kez bıraktırır, yani
    // evict kuyruğuna aynı sha için ikinci bayat satır atar (bkz. migration
    // 090). Bir kez patladıysa o ref bu yayında bir daha denenmez.
    final failures = <String>{};
    final pinned = <String, String>{}; // eski ref → yeni ref (aynı payload'da tekrar)

    Future<String?> convert(String raw) async {
      final cached = pinned[raw];
      if (cached != null) return cached;
      final file = await _resolver.resolve(AssetRef(raw));
      if (file == null) {
        failures.add(raw);
        return null;
      }
      final uri = await _assets.uploadPub(file, kind: kind, refKey: refKey);
      final out = uri.toString();
      pinned[raw] = out;
      return out;
    }

    Future<Object?> walk(Object? node) async {
      if (node is Map) {
        for (final key in node.keys.toList()) {
          final replaced = await walk(node[key]);
          if (replaced != null) node[key] = replaced;
        }
        return null;
      }
      if (node is List) {
        for (var i = 0; i < node.length; i++) {
          final replaced = await walk(node[i]);
          if (replaced != null) node[i] = replaced;
        }
        return null;
      }
      if (node is String && isMediaRef(node)) {
        if (failures.contains(node)) return null;
        try {
          return await convert(node);
        } on PinnedQuotaExceededException {
          rethrow;
        } catch (e) {
          debugPrint('publish pin: $node — $e');
          failures.add(node);
          return null;
        }
      }
      return null;
    }

    await walk(cloned);
    return PublishPinResult(cloned, failures.toList(), pinned.length);
  }

  /// Pin edilmesi gereken bir medya ref'i mi? Public: gezgindeki tek dallanma
  /// noktası bu, testi de buradan yapılıyor.
  ///
  /// Dışarıda kalanlar kasıtlı:
  /// - `pub/` zaten pinned — tekrar yüklemek boşa RPC.
  /// - `dmt-art://` first-party katalog; R2 `catalog/` prefix'inde public durur,
  ///   havuza girmez, refcount'u yoktur.
  /// - `dmt-transient://` oturum medyasıdır; yayına giren bir şey transient
  ///   olamaz (LRU onu silebilir) — ama resolver çözebiliyorsa pinleriz.
  static bool isMediaRef(String raw) {
    if (raw.isEmpty || raw.length > 1024) return false;
    final ref = AssetRef(raw);
    if (ref.isArt) return false;
    if (ref.isCloud) return !raw.startsWith('${AssetRef.scheme}pub/');
    if (ref.isPublic || ref.isTransient) return true;
    // Local path: yalnızca görsel uzantılı, ayırıcı içeren mutlak yollar.
    if (!raw.contains('/') && !raw.contains(r'\')) return false;
    final dot = raw.lastIndexOf('.');
    if (dot < 0) return false;
    return _imageExts.contains(raw.substring(dot).toLowerCase());
  }
}

class PublishPinResult {
  PublishPinResult(this.payload, this.failures, this.pinnedCount);

  /// Ref'leri `dmt-asset://pub/...` ile değiştirilmiş kopya.
  final Map<String, dynamic> payload;

  /// Çözülemeyen/yüklenemeyen ref'ler — payload'da eski hâlleriyle duruyorlar.
  final List<String> failures;

  /// Kaç ayrı ref pinlendi (dedup sonrası).
  final int pinnedCount;
}

/// Yayın, pinlenemeyen medya yüzünden iptal edildi. Mesaj presentation
/// katmanında lokalize edilir ([count] tek parametre).
class PublishMediaPinFailure implements Exception {
  PublishMediaPinFailure(this.count);

  final int count;

  @override
  String toString() => 'PublishMediaPinFailure($count)';
}
