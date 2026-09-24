import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../data/network/asset_service.dart';
import '../../data/network/network_providers.dart';
import '../../domain/value_objects/asset_ref.dart';
import '../../domain/value_objects/media_kind.dart';
import '../providers/auth_provider.dart';
import 'content_ref_index.dart';
import 'content_store.dart';

/// Faz 5d — multiplayer dünyanın medyası R2'de, dünya başına ve kalıcı
/// (`worlds/{worldId}/{sha}{ext}`).
///
/// **Kuyruk yok.** Bulutta ne olduğunu `world_media` söylüyor, gönderilmesi
/// gerekeni satırlardaki `dmt-content://` ref'leri; aradaki fark bir sonraki
/// turun işi. Yükleme dört adım: rezervasyon (sahiplik + dosya limiti + kota,
/// tek RPC) → toplu imza (tek worker isteği) → R2'ye doğrudan PUT → onay.
/// Bayt worker'dan geçmez.
///
/// Kaynak dosya iki yerden gelir: bu cihazın özgün dosyası
/// ([ContentRefIndex], DM'in yazdığı cihaz) ya da içerik önbelleği (DM'in
/// ikinci cihazı daha önce indirdiyse). İkisinde de yoksa atlanır — o sha'yı
/// yükleyebilecek olan başka cihaz.
class WorldMediaSync {
  WorldMediaSync({
    required SupabaseClient client,
    required AssetService assets,
    required ContentRefIndex index,
    required ContentStore store,
    Duration Function(int attempt)? backoff,
  })  : _client = client,
        _assets = assets,
        _index = index,
        _store = store,
        _backoff = backoff ?? ((n) => Duration(seconds: 2 * n));

  final SupabaseClient _client;
  final AssetService _assets;
  final ContentRefIndex _index;
  final ContentStore _store;

  /// Geçici hatadan sonra aynı dosyanın yeniden denenmesinden önceki bekleme.
  final Duration Function(int attempt) _backoff;

  /// Tek rezervasyon / imza isteğinde en çok bu kadar sha (worker'ın tavanı).
  static const int _batch = 100;

  /// Aynı anda en çok bu kadar PUT (Faz 5f). Dünya medyası çoğunlukla küçük
  /// dosya (Aegis: medyan 72 KB), yani süreyi bant genişliği değil istek
  /// başına gecikme belirliyor — sırayla 179 dosya 179 gidiş-dönüş demekti.
  static const int _parallel = 6;

  /// Onaylar bu kadar dosyada bir gider. R2'de duran ama `uploaded = false`
  /// kalan obje kimseye imzalanmaz; tur yarıda kesilirse (uygulama kapandı,
  /// ağ koptu) boşa giden PUT bununla sınırlı — onaysız olanı bir sonraki tur
  /// yeniden yükler.
  static const int _confirmEvery = 10;

  /// Geçici hatada (ağ, zaman aşımı, 5xx) aynı dosyanın deneme sayısı.
  static const int _attempts = 3;

  /// Supabase çağrılarının istek başına süresi — dolunca istek iptal edilir.
  static const Duration _rpcTimeout = Duration(seconds: 30);

  /// Yetim temizliği bundan genç satırlara dokunmaz. Öbür cihaz yeni bir
  /// görseli yüklemiş, onu taşıyan satır bu cihaza henüz inmemiş olabilir —
  /// pencere o yarışı kapatıyor.
  static const Duration pruneGrace = Duration(minutes: 10);

  /// Dünya → bulutta yüklü sha'lar. İlk ihtiyaçta `world_media`'dan okunur;
  /// [forget] bir sonraki okumayı tazeletir.
  final Map<String, Set<String>> _inCloud = {};

  /// [worldId]'nin önbelleğini düşürür — uzlaştırma turunda, öbür cihazın
  /// yüklediklerini de görmek için.
  void forget(String worldId) => _inCloud.remove(worldId);

  /// Bu cihazdaki kaynak dosyalar ve limitler — **ağ yok**. "Multiplayer aç"
  /// bunu kotayla karşılaştırıp dünyayı hiç yayınlamadan reddedebilir.
  Future<WorldMediaPlan> plan(Map<String, WorldMediaRef> refs) async {
    final items = <WorldMediaItem>[];
    final tooLarge = <String>[];
    for (final e in refs.entries) {
      final file = await _index.fileForSha(e.key) ??
          await _store.read(e.key, touch: false);
      if (file == null) continue;
      final bytes = await file.length();
      if (bytes > e.value.kind.maxBytes) {
        tooLarge.add(_nameOf(file, e.value.ext));
        continue;
      }
      items.add(WorldMediaItem(e.key, e.value, file, bytes));
    }
    return WorldMediaPlan(items, tooLarge);
  }

  /// [refs]'ten bulutta olmayanları yükler; aynı anda en çok [_parallel] PUT.
  ///
  /// Dosyaya özgü ret (4xx, okunamayan dosya) o dosyayı atlar, tur sürer —
  /// adı [WorldMediaReport.failed]'da. Geçici hata [_attempts] kez denenir,
  /// geçmezse yukarı çıkar: ağ yoksa kalan dosyaları tek tek denemek yalnızca
  /// zaman kaybı. Kota aşımı [WorldMediaQuotaException]. Her durumda o ana dek
  /// yüklenenler (yoldaki PUT'lar dahil) onaylanmış olur; kalanı bir sonraki
  /// tur tamamlar.
  Future<WorldMediaReport> upload(
    String worldId,
    Map<String, WorldMediaRef> refs, {
    void Function(int done, int total)? onProgress,
  }) async {
    final have = await _cloudSet(worldId);
    final plan = await this.plan({
      for (final e in refs.entries)
        if (!have.contains(e.key)) e.key: e.value,
    });
    final total = plan.items.length;
    var done = 0;
    var uploaded = 0;
    final failed = <String>[];
    if (total > 0) onProgress?.call(0, total);

    final pending = <String>[];
    Future<void> confirm() async {
      if (pending.isEmpty) return;
      final shas = List.of(pending);
      pending.clear();
      await _confirm(worldId, shas);
      have.addAll(shas);
      uploaded += shas.length;
    }

    var bytes = 0;
    try {
      for (var i = 0; i < total; i += _batch) {
        final chunk = plan.items.sublist(i, (i + _batch).clamp(0, total));
        final todo = await _reserve(worldId, chunk);
        final put = <WorldMediaItem>[];
        for (final it in chunk) {
          // Rezervasyonun atladığı (zaten yüklü) sha'lar bulutta.
          if (todo.contains(it.sha)) {
            put.add(it);
          } else {
            have.add(it.sha);
          }
        }
        done += chunk.length - put.length;
        final urls = put.isEmpty
            ? <String, String>{}
            : await _sign(worldId, [for (final it in put) it.sha]);

        // [_parallel] işçi aynı listeden sırayla dosya alır. Birinin hatası
        // yenilerin başlamasını durdurur; yoldakiler biter ve onaylanır.
        var next = 0;
        Object? error;
        StackTrace? trace;
        Future<void> worker() async {
          while (error == null && next < put.length) {
            final it = put[next++];
            try {
              if (await _put(worldId, it, urls)) {
                bytes += it.bytes;
                pending.add(it.sha);
                if (pending.length >= _confirmEvery) await confirm();
              } else {
                failed.add(_nameOf(it.file, it.ref.ext));
              }
            } catch (e, s) {
              error ??= e;
              trace ??= s;
              return;
            }
            onProgress?.call(++done, total);
          }
        }

        await Future.wait([
          for (var w = 0; w < _parallel && w < put.length; w++) worker(),
        ]);
        if (error != null) Error.throwWithStackTrace(error!, trace!);
      }
    } finally {
      await confirm();
    }
    return WorldMediaReport(
        uploaded: uploaded,
        bytes: bytes,
        tooLarge: plan.tooLarge,
        failed: failed);
  }

  /// Tek dosyanın PUT'u; true → R2'de. Dosyaya özgü ret false döner, geçici
  /// hata denemeler bitince yukarı çıkar ([upload]).
  Future<bool> _put(
    String worldId,
    WorldMediaItem it,
    Map<String, String> urls,
  ) async {
    var resigned = false;
    for (var attempt = 1;; attempt++) {
      final url = urls[it.sha];
      if (url == null) return false; // rezerve ama imzasız: satır silinmiş
      try {
        await _assets.putSigned(url, it.file,
            bytes: it.bytes, mime: AssetService.mimeOf(it.ref.ext));
        return true;
      } on AssetServiceException catch (e) {
        final status = int.tryParse(e.code.replaceFirst('put_', '')) ?? 0;
        // Uzun turda imzanın saati (1 sa) dolmuş olabilir: bir kez tazele.
        if (status == 403 && !resigned) {
          resigned = true;
          urls.remove(it.sha);
          urls.addAll(await _sign(worldId, [it.sha]));
          continue;
        }
        if (status >= 400 && status < 500) {
          debugPrint('WorldMediaSync: ${it.sha} reddedildi: $e');
          return false;
        }
        if (attempt >= _attempts) rethrow;
      } on FileSystemException catch (e) {
        debugPrint('WorldMediaSync: ${it.file.path} okunamadı: $e');
        return false;
      } catch (_) {
        if (attempt >= _attempts) rethrow;
      }
      await Future<void>.delayed(_backoff(attempt));
    }
  }

  Future<Map<String, String>> _sign(String worldId, List<String> shas) async =>
      Map.of(await _assets.signWorldMedia('put', shas, worldId: worldId));

  /// Tek dosyayı dünyanın medyasına çıkarır ve `dmt-content://` ref'ini döner
  /// — projeksiyon yolu için: yansıtılan görsel her zaman bir satırda
  /// durmuyor (paket kartının token'ı, düz görsel). Yüklenemezse null.
  Future<String?> publish(
    String worldId,
    String localPath, {
    MediaKind kind = MediaKind.worldEntityImage,
  }) async {
    final ref = await _index.refFor(localPath);
    final sha = ref == null ? null : AssetRef(ref).contentSha;
    if (ref == null || sha == null) return null;
    final ext = AssetRef(ref).contentExt;
    await upload(worldId, {
      sha: WorldMediaRef(ext, worldMediaKindOf(ext, map: kind == MediaKind.battleMap)),
    });
    return (_inCloud[worldId]?.contains(sha) ?? false) ? ref : null;
  }

  /// Artık hiçbir satırın anmadığı medyayı buluttan siler — kotayı
  /// doldurmasın. [keep] dünyanın bütün satırlarındaki sha'lar. Yanlış silme
  /// kendiliğinden düzelir: hâlâ anılan sha bir sonraki turda yeniden yüklenir.
  Future<int> prune(String worldId, Set<String> keep) async {
    final cutoff = DateTime.now().toUtc().subtract(pruneGrace);
    final victims = <String>[
      for (final r in await _rows(worldId, 'sha256, created_at'))
        if (!keep.contains(r['sha256']) &&
            (DateTime.tryParse('${r['created_at']}')?.isBefore(cutoff) ??
                false))
          r['sha256'] as String,
    ];
    for (var i = 0; i < victims.length; i += _batch) {
      await _client
          .from('world_media')
          .delete()
          .eq('world_id', worldId)
          .inFilter('sha256',
              victims.sublist(i, (i + _batch).clamp(0, victims.length)))
          .retry(requestTimeout: _rpcTimeout);
    }
    _inCloud[worldId]?.removeAll(victims);
    return victims.length;
  }

  /// Kullanıcının dünya medyası payı ve R2'nin toplam doluluğu.
  Future<MediaQuota> quota() async {
    final m = Map<String, dynamic>.from(await _client
        .rpc('get_media_quota')
        .retry(requestTimeout: _rpcTimeout) as Map);
    int n(String k) => (m[k] as num?)?.toInt() ?? 0;
    return MediaQuota(
      userUsed: n('user_used'),
      userCap: n('user_cap'),
      totalUsed: n('total_used'),
      totalCap: n('total_cap'),
    );
  }

  // ── içerisi ──────────────────────────────────────────────────────────────

  Future<Set<String>> _cloudSet(String worldId) async =>
      _inCloud[worldId] ??= {
        for (final r in await _rows(worldId, 'sha256', uploadedOnly: true))
          r['sha256'] as String,
      };

  /// PostgREST bir yanıtta en çok 1000 satır döner; dünya daha büyük olabilir.
  Future<List<Map<String, dynamic>>> _rows(
    String worldId,
    String columns, {
    bool uploadedOnly = false,
  }) async {
    const page = 1000;
    final out = <Map<String, dynamic>>[];
    for (var from = 0;; from += page) {
      var q = _client.from('world_media').select(columns).eq('world_id', worldId);
      if (uploadedOnly) q = q.eq('uploaded', true);
      final rows = await q
          .order('sha256')
          .range(from, from + page - 1)
          .retry(requestTimeout: _rpcTimeout);
      out.addAll(rows);
      if (rows.length < page) return out;
    }
  }

  Future<Set<String>> _reserve(String worldId, List<WorldMediaItem> items) async {
    try {
      final res = Map<String, dynamic>.from(
        await _client.rpc('world_media_reserve', params: {
          '_world': worldId,
          '_items': [
            for (final it in items)
              {
                'sha': it.sha,
                'ext': it.ref.ext,
                'bytes': it.bytes,
                'kind': it.ref.kind.wireName,
                'mime': AssetService.mimeOf(it.ref.ext),
              },
          ],
        }).retry(requestTimeout: _rpcTimeout) as Map,
      );
      return {...(res['upload'] as List? ?? const []).cast<String>()};
    } on PostgrestException catch (e) {
      if (e.message.contains('media_user_full') ||
          e.message.contains('media_pool_full')) {
        throw WorldMediaQuotaException(
            e.message.contains('media_pool_full'), e.hint ?? '');
      }
      rethrow;
    }
  }

  /// Onay gitmezse hata yukarı çıkar ve sha'lar "bulutta" sayılmaz: bir
  /// sonraki rezervasyon onları yeniden döner, PUT tekrar edilir (aynı bayt,
  /// aynı key). Yutulsaydı bu cihaz onları yüklü sanıp bir daha denemezdi.
  Future<void> _confirm(String worldId, List<String> shas) async {
    await _client.rpc('world_media_confirm',
        params: {'_world': worldId, '_shas': shas}).retry(
        requestTimeout: _rpcTimeout);
  }

  static String _nameOf(File file, String ext) {
    final name = p.basename(file.path);
    // Önbellekteki kopyanın adı `{sha}.bin` — kullanıcıya bir şey anlatmaz.
    return name.endsWith('.bin') ? '${name.substring(0, 12)}…$ext' : name;
  }
}

/// Bir sha'nın buluttaki adı ve sınıfı.
@immutable
class WorldMediaRef {
  const WorldMediaRef(this.ext, this.kind);

  /// Nokta dahil (`.png`), ya da boş.
  final String ext;
  final MediaKind kind;

  @override
  bool operator ==(Object other) =>
      other is WorldMediaRef && other.ext == ext && other.kind == kind;

  @override
  int get hashCode => Object.hash(ext, kind);
}

/// Dünya medyasının dört sınıfı (099 `world_media_max_bytes`): uzantısı PDF ya
/// da ses değilse [map] olan harita (10 MB), olmayan "diğer" (5 MB).
MediaKind worldMediaKindOf(String ext, {required bool map}) {
  switch (ext.toLowerCase()) {
    case '.pdf':
      return MediaKind.worldPdf;
    case '.mp3':
    case '.ogg':
    case '.wav':
    case '.m4a':
    case '.flac':
      return MediaKind.worldAudio;
  }
  return map ? MediaKind.battleMap : MediaKind.worldEntityImage;
}

class WorldMediaItem {
  const WorldMediaItem(this.sha, this.ref, this.file, this.bytes);
  final String sha;
  final WorldMediaRef ref;
  final File file;
  final int bytes;
}

class WorldMediaPlan {
  const WorldMediaPlan(this.items, this.tooLarge);

  /// Bu cihazdan yüklenebilecekler.
  final List<WorldMediaItem> items;

  /// Limiti aşan dosyaların adları — yüklenmez, yerelde çalışmaya devam eder.
  final List<String> tooLarge;

  int get bytes => items.fold(0, (a, it) => a + it.bytes);
}

class WorldMediaReport {
  const WorldMediaReport({
    this.uploaded = 0,
    this.bytes = 0,
    this.tooLarge = const [],
    this.failed = const [],
  });
  final int uploaded;

  /// R2'ye giden bayt — ölçüm log'u için (Faz 5f).
  final int bytes;
  final List<String> tooLarge;

  /// R2'nin reddettiği ya da okunamayan dosyalar — tur onları atlayıp sürdü.
  final List<String> failed;
}

class MediaQuota {
  const MediaQuota({
    required this.userUsed,
    required this.userCap,
    required this.totalUsed,
    required this.totalCap,
  });

  final int userUsed;
  final int userCap;
  final int totalUsed;
  final int totalCap;

  /// Yeni yüklemeye kalan yer: kişi payı ile R2 toplamının darı.
  int get remaining {
    final user = userCap - userUsed;
    final total = totalCap - totalUsed;
    return (user < total ? user : total).clamp(0, 1 << 62);
  }
}

/// Kişi başı (1 GB) ya da R2 toplam (9 GB) tavanı doldu.
class WorldMediaQuotaException implements Exception {
  WorldMediaQuotaException(this.pool, this.detail);

  /// true → R2'nin toplamı doldu (kullanıcının elinde değil); false → kişi payı.
  final bool pool;
  final String detail;

  @override
  String toString() => 'WorldMediaQuotaException(${pool ? 'pool' : 'user'}): $detail';
}

final worldMediaSyncProvider = Provider<WorldMediaSync?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  if (ref.watch(authProvider) == null) return null;
  final assets = ref.watch(assetServiceProvider);
  if (assets == null) return null;
  return WorldMediaSync(
    client: Supabase.instance.client,
    assets: assets,
    index: ref.read(contentRefIndexProvider),
    store: ref.watch(contentStoreProvider),
  );
});
