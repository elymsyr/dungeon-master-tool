import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../providers/campaign_provider.dart';
import 'asset_ref_resolver.dart';
import 'content_store.dart';

/// Oyuncu tarafı: paylaşılan kartlarda çözülemeyen transient SHA'ları DM'e
/// bildirir ve geldiklerinde indirir.
///
/// Akış ([SharedMediaCourier]'ın karşı ucu):
///   1. DM paylaşırken medya YÜKLEMEZ; payload `dmt-transient://{sha}{ext}`
///      taşır.
///   2. [sweep] payload'ları tarar, her SHA için önce yerel [ContentStore]'a,
///      sonra çözücüye bakar. Çözülemeyenler `report_missing_shas` RPC'si ile
///      `world_members.missing_shas`'e yazılır.
///   3. DM CDC ile listeyi görür, yalnızca o baytları transient'e yükler.
///   4. Bir sonraki süpürmede indirilir, liste kendiliğinden boşalır.
///
/// Liste her seferinde **tümüyle** yeniden yazılır: çözülen SHA düşer, ayrı
/// bir temizleme yolu yok. Eksik varken periyodik süpürme sürer, liste
/// boşalınca durur.
///
/// ponytail: 15 sn'lik yeniden deneme timer'ı, DM'in yüklemeyi bitirdiğine
/// dair bir sinyal olmadığı için var — `transient_shares` abone tablolardan
/// biri değil. Gecikme rahatsız ederse doğru yükseltme o tabloya abone olmak
/// değil, DM'in yükleme sonrası oyuncunun zaten dinlediği bir satıra dokunması.
class MissingMediaReporter {
  MissingMediaReporter(this._ref, {required this.onResolved});

  final Ref _ref;

  /// En az bir SHA indirildiğinde çağrılır — UI'ın resmi yeniden çözmesi için.
  final VoidCallback onResolved;

  static const _debounce = Duration(seconds: 2);
  static const _retryEvery = Duration(seconds: 15);

  Timer? _debounceTimer;
  Timer? _retryTimer;
  String? _worldId;
  Set<String> _reported = const {};
  bool _busy = false;
  bool _disposed = false;

  /// Paylaşım uygulandıktan sonra çağrılır — süpürmeyi debounce ile tetikler.
  void schedule(String worldId) {
    if (_disposed) return;
    _worldId = worldId;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => unawaited(_sweep()));
  }

  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _debounceTimer = null;
    _retryTimer = null;
  }

  Future<void> _sweep() async {
    if (_disposed || _busy) return;
    final worldId = _worldId;
    if (worldId == null) return;
    _busy = true;
    try {
      final missing = await _scanAndFetch(worldId);
      if (_disposed) return;

      if (missing.isEmpty) {
        _retryTimer?.cancel();
        _retryTimer = null;
      } else {
        _retryTimer ??=
            Timer.periodic(_retryEvery, (_) => unawaited(_sweep()));
      }

      if (!setEquals(missing, _reported) && await _report(worldId, missing)) {
        _reported = missing;
      }
    } catch (e) {
      debugPrint('MissingMediaReporter sweep error: $e');
    } finally {
      _busy = false;
    }
  }

  /// Aktif dünyanın kart gövdelerindeki transient ref'leri tarar; elde
  /// olmayanları indirmeyi dener ve hâlâ çözülemeyenlerin SHA'larını döner.
  Future<Set<String>> _scanAndFetch(String worldId) async {
    final data = _ref.read(activeCampaignProvider.notifier).data;
    final entities = data?['entities'];
    if (entities is! Map) return const {};

    final refs = collectTransientRefs(entities); // sha → tam ref
    if (refs.isEmpty) return const {};

    final store = _ref.read(contentStoreProvider);
    final resolver = _ref.read(assetRefResolverProvider);
    final missing = <String>{};
    var fetched = false;

    for (final entry in refs.entries) {
      if (_disposed) break;
      if (await store.read(entry.key, touch: false) != null) continue;
      // Baytlar DM tarafından yüklendiyse çözücü indirir ve store'a yazar.
      final file = await resolver.resolve(AssetRef(entry.value));
      if (file != null) {
        fetched = true;
      } else {
        missing.add(entry.key);
      }
    }
    if (fetched && !_disposed) onResolved();
    return missing;
  }

  /// Listeyi DM'e bildirir. Başarısızsa false — `_reported` güncellenmez,
  /// böylece bir sonraki süpürme aynı listeyi yeniden dener.
  Future<bool> _report(String worldId, Set<String> shas) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await Supabase.instance.client.rpc('report_missing_shas', params: {
        '_world': worldId,
        '_shas': shas.toList(),
      });
      return true;
    } catch (e) {
      debugPrint('report_missing_shas failed: $e');
      return false;
    }
  }
}

/// JSON gövdesinde geçen her `dmt-transient://` ref'ini `sha → ref` olarak
/// toplar. Şemadan bağımsız gezilir: portre, galeri, `image` alanı ya da
/// ileride eklenecek herhangi bir medya alanı aynı ref şemasını taşıyor, o
/// yüzden alan listesi tutmak yerine gövde taranır.
Map<String, String> collectTransientRefs(Object? node,
    [Map<String, String>? into]) {
  final out = into ?? <String, String>{};
  if (node is String) {
    final ref = AssetRef(node);
    if (!ref.isTransient) return out;
    final sha = ref.transientSha;
    if (sha != null && sha.length == 64) out[sha.toLowerCase()] = node;
  } else if (node is Map) {
    for (final v in node.values) {
      collectTransientRefs(v, out);
    }
  } else if (node is List) {
    for (final v in node) {
      collectTransientRefs(v, out);
    }
  }
  return out;
}
