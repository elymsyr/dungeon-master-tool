import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/error_format.dart';
import '../../core/utils/format_bytes.dart';
import '../../domain/entities/online/world_role.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../services/cloud_pull_service.dart';
import '../services/cloud_push_service.dart';
import '../services/pending_write_buffer.dart';
import '../services/content_ref_index.dart';
import '../services/world_media_sync.dart';
import 'auth_provider.dart';
import 'campaign_provider.dart';
import 'connectivity_provider.dart';
import '../../data/database/database_provider.dart';
import 'entity_provider.dart';
import 'package_provider.dart' show activePackageProvider, packageListProvider;
import 'role_provider.dart';

/// Faz 4 push servisi. Supabase yapılandırılmamışsa ya da oturum yoksa null —
/// uygulama tamamen yerel çalışır.
final cloudPushServiceProvider = Provider<CloudPushService?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  if (ref.watch(authProvider) == null) return null;
  return CloudPushService(
    db: ref.watch(appDatabaseProvider),
    client: Supabase.instance.client,
    index: ref.read(contentRefIndexProvider),
  );
});

/// Faz 5d — limiti aşıp buluta çıkmayan dosyaların adları, **yeni eklendikleri**
/// turda. `MainScreen` dinleyip "oyunculara gitmeyecek" der; dosya yerelde
/// çalışmaya devam eder.
final worldMediaNoticeProvider = StateProvider<List<String>>((ref) => const []);

/// Faz 5f — arka plan yüklemesi kotaya takıldı: kişi payı (false) ya da R2'nin
/// toplamı (true). Oturumda bir kez dolar; uygulama kökü dinleyip söyler.
/// Yeniden denenmez — beklemek yer açmaz.
final worldMediaQuotaProvider = StateProvider<bool?>((ref) => null);

/// Faz 5a pull servisi. Push ile aynı kapıdan geçer: yapılandırma ve oturum
/// yoksa null.
final cloudPullServiceProvider = Provider<CloudPullService?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  if (ref.watch(authProvider) == null) return null;
  return CloudPullService(
    db: ref.watch(appDatabaseProvider),
    client: Supabase.instance.client,
    index: ref.read(contentRefIndexProvider),
  );
});

/// Faz 5c — bu kullanıcının bulutta olup bu cihazda olmayan dünyaları. Yerel
/// liste değişince (indirme bitti, dünya silindi) yeniden sorulur;
/// çevrimdışıyken boş.
final cloudOnlyWorldsProvider = FutureProvider<List<CloudWorld>>((ref) async {
  final svc = ref.watch(cloudPullServiceProvider);
  ref.watch(campaignInfoListProvider);
  if (svc == null) return const [];
  try {
    return await svc.listCloudOnlyWorlds();
  } catch (e) {
    debugPrint('cloudOnlyWorlds: ${isOfflineError(e) ? 'offline' : e}');
    return const [];
  }
});

/// Faz 5c — paket eşi. Yerel paket listesi değişince yeniden sorulur.
final cloudOnlyPackagesProvider =
    FutureProvider<List<CloudPackage>>((ref) async {
  final svc = ref.watch(cloudPullServiceProvider);
  ref.watch(packageListProvider);
  if (svc == null) return const [];
  try {
    return await svc.listCloudOnlyPackages();
  } catch (e) {
    debugPrint('cloudOnlyPackages: ${isOfflineError(e) ? 'offline' : e}');
    return const [];
  }
});

/// Bulut aynasının istemci tarafındaki tek sürücüsü: yazma tamponu sustuğunda
/// push, bulut revizyonu değiştiğinde pull.
///
/// Tampon zaten 750–2000 ms debounce ediyor; buradaki [_idle] onun üstüne
/// binen ikinci bir sessizlik penceresi — kart düzenlerken her tuş vuruşunda
/// değil, eli çektikten sonra tek tur gider.
///
/// Push ve pull **tek şeritten** geçer ([_rows]): üst üste binmezler. Bu
/// yalnız israf önlemi değil — sinyal geldiğinde kendi push'umuz hâlâ
/// sürüyorsa, pull onun damgayı ilerletmesini bekler ve kendi yankısını
/// çekmez.
///
/// Medya (Faz 5d): artımlı turda satırlardan **önce** yüklenir — öbür cihaz
/// satırı gördüğünde baytlar bulutta olsun. Dünyanın tam uzlaştırması kendi
/// şeridinde ([_media]): büyük bir yükleme satırların senkronunu bekletmesin.
/// Uzlaştırma başarısızsa dünya online kaldıkça geri çekilerek yeniden
/// denenir ([_scheduleMediaRetry]); kullanıcının bir şey düzenlemesi gerekmez.
///
/// Açık olmayan dünyalar (Faz 5f): uygulama açılınca, oturum açılınca ve
/// bağlantı geri gelince [reconcileAll] — dünyayı açmak gerekmez.
class CloudPushPump {
  CloudPushPump(this._ref) {
    _buffer = _ref.read(pendingWriteBufferProvider);
    _buffer.tick.addListener(_onTick);
    _ref.listen<AsyncValue<bool>>(connectivityStreamProvider, _onConnectivity);
  }

  final Ref _ref;
  late final PendingWriteBuffer _buffer;

  static const Duration _idle = Duration(seconds: 3);

  /// Karşı cihazın bir push turu satır başına bir sinyal üretir (sayaç her
  /// yazmada artıyor); pencere o patlamayı tek pull'a indirir.
  static const Duration _signalIdle = Duration(seconds: 1);

  Timer? _timer;
  Timer? _signalTimer;
  final _rows = _Lane();
  final _media = _Lane();

  /// Bu oturumda medyası tam uzlaştırılmış dünyalar. Uzlaştırılmamış dünyada
  /// her tur tam tarama yapar — yarıda kalan yükleme böyle tamamlanıyor.
  final Set<String> _mediaSynced = {};

  /// Yetim temizliği oturumda bir kez, dünyanın ilk açılışında.
  final Set<String> _pruned = {};

  /// Kullanıcıya "limitin üstünde" denmiş dosyalar — her biri bir kez.
  final Set<String> _noticed = {};

  /// Medyası uzlaştırılamayan dünya → art arda başarısızlık sayısı ve
  /// bekleyen yeniden deneme.
  final Map<String, int> _mediaFails = {};
  final Map<String, Timer> _mediaRetry = {};

  /// Faz 5f — bağlantı geri geldi: çevrimdışıyken çözülen rol `none` diye
  /// önbellekte kalmış olabilir (rol sağlayıcıları ağ hatasını `none`
  /// sayıyor); tazelenmezse push ve kanal hiç kurulmaz. Açık dünyanın rolü
  /// tazelenince kanal kurulur ve `SUBSCRIBED` uzlaştırır; kalanlar
  /// [reconcileAll] ile.
  void _onConnectivity(AsyncValue<bool>? prev, AsyncValue<bool> next) {
    if (prev?.valueOrNull != false || next.valueOrNull != true) return;
    debugPrint('CloudSync: bağlantı geri geldi');
    _ref.invalidate(currentWorldRoleProvider);
    unawaited(reconcileAll());
  }

  void _onTick() {
    _timer?.cancel();
    _timer = Timer(_idle, () => unawaited(_round()));
  }

  /// Açık olan ne varsa bir tur: dünya ve/veya paket. İkisi aynı anda açık
  /// olmuyor ama hangisinin açık olduğunu sormak yerine ikisini de denemek
  /// daha ucuz — kapalı olan satırı bulamayıp atlıyor.
  Future<void> _round() async {
    final id = _ref.read(activeCampaignProvider);
    final res = await push(worldId: id);
    // Uzlaştırılmamış dünya (açılış yarıda kaldı, ağ koptu): tam tarama.
    if (res.ok && id != null && !_mediaSynced.contains(id)) {
      unawaited(_media.run(() => _quiet(id, () => _fullMedia(id))));
    }
    await pushActivePackage();
  }

  /// Aktif dünyanın turunu koşturur. [full] ilk yayın / "yeniden gönder".
  Future<CloudPushResult> push({bool full = false, String? worldId}) async {
    final svc = _ref.read(cloudPushServiceProvider);
    // `activeCampaignProvider` "açık içeriğin anahtarı" — pakette paket adı
    // tutuyor. Dünya değilse servis satırı bulamaz ve tur atlanır; paketin
    // turu `pushActivePackage` ile ayrı gidiyor.
    final id = worldId ?? _ref.read(activeCampaignProvider);
    if (svc == null || id == null || id.isEmpty) {
      return const CloudPushResult(skipped: true);
    }
    // DM olmayan kimse ayna tablolarına yazamaz (RLS).
    final role = await _roleOf(id);
    if (role != WorldRole.dm) {
      debugPrint(
          'CloudSync: push $id atlandı, rol=${role?.name ?? 'çözülmedi'}');
      return const CloudPushResult(skipped: true);
    }
    // Tam tur ("multiplayer aç") medyasını ilerleme overlay'inde ayrıca
    // yüklüyor; burada beklenseydi satırlar bütün medyayı beklerdi.
    return _rows.run(() => _logged(
        'push $id',
        svc.pushWorld(id,
            dmOnlyKeys: _dmOnlyKeys(),
            full: full,
            beforeRows: full ? null : (refs) => _uploadNew(id, refs))));
  }

  /// Satırlardan önce: bu turun satırlarının andığı, bulutta olmayan medya.
  /// Hata atmaz ([_quiet]) — yüklenemese de satırlar gider, uzlaştırma
  /// sonra tamamlar.
  Future<void> _uploadNew(String id, Map<String, WorldMediaRef> refs) async {
    final media = _ref.read(worldMediaSyncProvider);
    if (media == null || refs.isEmpty) return;
    await _quiet(id, () async {
      final rep = await media.upload(id, refs);
      _notice(rep.tooLarge);
      return rep;
    });
  }

  /// Rol, dünya açık olmasa da: hub'dan multiplayer açılan dünya aktif değil.
  Future<WorldRole?> _roleOf(String id) async {
    try {
      return id == _ref.read(activeCampaignProvider)
          ? await _ref.read(currentWorldRoleProvider.future)
          : await _ref.read(worldRoleProvider(id).future);
    } catch (_) {
      return null;
    }
  }

  /// Faz 4b — açık paketin turu. Rol kontrolü yok: paket kullanıcı kapsamlı,
  /// RLS `owner_id`'ye bakıyor.
  ///
  /// [packageName] verilmezse açık paket alınır (`activePackageProvider` adı
  /// tutuyor, id'yi tablodan buluyoruz).
  Future<CloudPushResult> pushPackage({
    bool full = false,
    String? packageName,
    String? packageId,
  }) async {
    final svc = _ref.read(cloudPushServiceProvider);
    if (svc == null) return const CloudPushResult(skipped: true);
    var id = packageId;
    if (id == null) {
      final name = packageName ?? _ref.read(activePackageProvider);
      if (name == null || name.isEmpty) {
        return const CloudPushResult(skipped: true);
      }
      id = (await _ref.read(appDatabaseProvider).packagesDao.getByName(name))?.id;
      if (id == null) return const CloudPushResult(skipped: true);
    }
    final pid = id;
    return _rows.run(
        () => _logged('push paket $pid', svc.pushPackage(pid, full: full)));
  }

  /// Faz 5a — aktif dünyanın bulut aynasını yerele çeker.
  ///
  /// [full] true ise damga yok sayılır: yeni cihazdaki ilk senkron.
  Future<CloudPullResult> pull({bool full = false, String? worldId}) async {
    final svc = _ref.read(cloudPullServiceProvider);
    final id = worldId ?? _ref.read(activeCampaignProvider);
    if (svc == null || id == null || id.isEmpty) {
      return const CloudPullResult(skipped: true);
    }
    // Ayna tabloları DM'e ait; oyuncunun kapısı `get_shared_entities` (Faz 5.5).
    final role = await _roleOf(id);
    if (role != WorldRole.dm) {
      debugPrint(
          'CloudSync: pull $id atlandı, rol=${role?.name ?? 'çözülmedi'}');
      return const CloudPullResult(skipped: true);
    }
    final sw = Stopwatch()..start();
    final res = await _rows.run(() => svc.pullWorld(id, full: full));
    debugPrint('CloudSync: pull $id +${res.applied} -${res.removed} '
        'rev=${res.revision}${res.skipped ? ' atlandı' : ''}'
        '${res.error != null ? ' hata=${res.error}' : ''} '
        '${sw.elapsedMilliseconds} ms');
    // Pull Drift satırlarına yazdı, ama açık dünyanın UI'ı Drift'ten değil
    // `ActiveCampaignNotifier`'ın bellekteki blob'undan okuyor
    // (`EntityNotifier._loadFromCampaign`). `reload()` blob'u depodan
    // tazeleyip `campaignRevisionProvider`'ı bump ediyor — notifier zinciri
    // yeniden kurulmadan inen satırlar görünür oluyor.
    if ((res.applied > 0 || res.removed > 0) &&
        id == _ref.read(activeCampaignProvider)) {
      await _ref.read(activeCampaignProvider.notifier).reload();
    }
    return res;
  }

  /// Uzlaştırma turu: **önce push, sonra pull.** Kanal her `SUBSCRIBED`
  /// olduğunda (dünya açılışı, yeniden bağlanma, uygulamanın öne gelmesi) ve
  /// karşı cihazın sinyalinde koşar.
  ///
  /// Sıra rastgele değil. Pull satırı bulutun `updated_at`'i ile yazıyor;
  /// push'un damgası tur başında `now()`'a çekildiği için ondan önce
  /// düzenlenmiş uzak satırlar bir sonraki push taramasına düşmez. Ters sırada
  /// her pull, kendi getirdiği satırları buluta geri göndertirdi.
  ///
  /// Önce tampon boşaltılır: yarım kalmış düzenleme Drift'e insin ki pull'un
  /// LWW'si onu bayat satırla karşılaştırmasın ve push onu bu turda götürsün.
  ///
  /// Sonra medya — oturumda bir kez (başarısızsa yeniden): dünyanın bütün
  /// satırları taranır, bulutta olmayan yüklenir, artık anılmayan silinir.
  /// Sinyalle gelen uzlaştırmada tekrarlanmaz; öbür cihazın medyasını o cihaz
  /// yüklüyor. Temizlik pull'dan SONRA: öbür cihazın yeni görselini anan satır
  /// buraya inmeden silinseydi, görsel herkes için kırılırdı.
  Future<void> catchUp(String worldId) async {
    debugPrint('CloudSync: catchUp $worldId');
    await _buffer.flush();
    final res = await push(worldId: worldId);
    if (res.skipped) {
      // Online dünyada atlanma = rol çözülemedi: rol sağlayıcıları ağ
      // hatasını `none` sayıyor (çevrimdışı açılış, internetsiz Wi-Fi).
      // Yeniden denenmezse bu oturumda hiçbir şey gitmezdi.
      final world =
          await _ref.read(appDatabaseProvider).worldsDao.getById(worldId);
      if (_ref.read(cloudPushServiceProvider) != null &&
          (world?.isOnline ?? false)) {
        _scheduleMediaRetry(worldId);
      }
      return;
    }
    final pulled = await pull(worldId: worldId);
    if (_mediaSynced.contains(worldId) && _pruned.contains(worldId)) return;
    // Pull tutmadıysa yerel satırlar bayat olabilir: öbür cihazın yeni
    // görseli "anılmıyor" sanılıp silinirdi. Temizlik sonraki uzlaştırmaya.
    final prune = pulled.ok && !_pruned.contains(worldId);
    unawaited(_media.run(
        () => _quiet(worldId, () => _fullMedia(worldId, prune: prune))));
  }

  /// Faz 5f — bu cihazdaki bütün online dünyaların uzlaştırması, sırayla.
  /// Uygulama açılınca ve oturum açılınca koşar: yarıda kalan yükleme ve
  /// çevrimdışı birikmiş düzenleme dünyayı açmayı beklemesin. Online dünya
  /// yalnız DM'in cihazında online işaretli (oyuncu dünyası değil), rolü
  /// [catchUp] yine doğruluyor.
  ///
  /// Açık dünya atlanır: onu kanalın `SUBSCRIBED`'ı uzlaştırıyor.
  Future<void> reconcileAll() async {
    final worlds = await _ref.read(appDatabaseProvider).worldsDao.getAll();
    for (final w in worlds) {
      if (!w.isOnline || w.id == _ref.read(activeCampaignProvider)) continue;
      _ref.invalidate(worldRoleProvider(w.id));
      try {
        await catchUp(w.id);
      } catch (e) {
        debugPrint('CloudSync: uzlaştırma ${w.id} hata=$e');
      }
    }
  }

  /// Faz 5d — "multiplayer aç": dünyanın bütün medyası, ilerlemeyle. Hata ve
  /// kota aşımı çağırana çıkar (kullanıcının başlattığı iş). Limiti aşanlar
  /// raporda; bildirim olarak ayrıca gösterilmez.
  ///
  /// Yarım kalırsa (hata ya da reddedilen dosya) arka planda yeniden denenir.
  Future<WorldMediaReport?> syncWorldMedia(
    String worldId, {
    void Function(int done, int total)? onProgress,
  }) =>
      _media.run(() async {
        try {
          final rep = await _fullMedia(worldId, onProgress: onProgress);
          _noticed.addAll(rep?.tooLarge ?? const []);
          if (rep != null && rep.failed.isNotEmpty) {
            _scheduleMediaRetry(worldId);
          }
          return rep;
        } catch (e) {
          if (e is! WorldMediaQuotaException) _scheduleMediaRetry(worldId);
          rethrow;
        }
      });

  /// Dünyanın bütün satırlarındaki medyayı buluta çıkarır; [prune] ise artık
  /// anılmayanı siler. Limit aşımı burada bildirilmez: açılışta eski dosyalar
  /// için her seferinde uyarmak gürültü olurdu, uyarı eklenme anının.
  Future<WorldMediaReport?> _fullMedia(
    String id, {
    bool prune = false,
    void Function(int done, int total)? onProgress,
  }) async {
    final media = _ref.read(worldMediaSyncProvider);
    final svc = _ref.read(cloudPushServiceProvider);
    if (media == null || svc == null) return null;
    if (await _roleOf(id) != WorldRole.dm) return null;
    final refs = await svc.worldMediaRefs(id);
    media.forget(id);
    final rep = await media.upload(id, refs, onProgress: onProgress);
    if (rep.failed.isEmpty) _mediaSynced.add(id);
    _noticed.addAll(rep.tooLarge);
    if (prune) {
      final n = await media.prune(id, refs.keys.toSet());
      _pruned.add(id);
      if (n > 0) debugPrint('CloudSync: medya $id yetim ✕$n');
    }
    return rep;
  }

  /// Arka plan medya işi: hata log'a, uzlaştırma bayrağı düşer ve yeniden
  /// deneme kurulur. Kota dolduysa kurulmaz — beklemek yer açmaz.
  Future<void> _quiet(
      String id, Future<WorldMediaReport?> Function() body) async {
    final sw = Stopwatch()..start();
    try {
      final rep = await body();
      if (rep == null) return;
      if (rep.uploaded > 0 || rep.tooLarge.isNotEmpty || rep.failed.isNotEmpty) {
        debugPrint('CloudSync: medya $id ↑${rep.uploaded}'
            '${rep.tooLarge.isEmpty ? '' : ' limit üstü ${rep.tooLarge.length}'}'
            '${rep.failed.isEmpty ? '' : ' reddedilen ${rep.failed.length}'}'
            ' ${formatBytes(rep.bytes)} ${sw.elapsedMilliseconds} ms');
      }
      if (rep.failed.isEmpty) {
        _mediaFails.remove(id);
      } else {
        _mediaSynced.remove(id);
        _scheduleMediaRetry(id);
      }
    } catch (e) {
      _mediaSynced.remove(id);
      debugPrint('CloudSync: medya $id hata=${isOfflineError(e) ? 'offline' : e}');
      if (e is WorldMediaQuotaException) {
        _ref.read(worldMediaQuotaProvider.notifier).state ??= e.pool;
      } else {
        _scheduleMediaRetry(id);
      }
    }
  }

  /// Uzlaştırmayı [catchUp] ile yeniden dener: 30 sn, sonra her seferinde iki
  /// katı, en çok 10 dk. Dünya o arada multiplayer'dan çıktıysa ya da
  /// silindiyse bırakılır. Zaten bekleyen deneme varsa yenisi kurulmaz.
  /// Medya hatası da rolün çözülememesi de buraya düşer.
  void _scheduleMediaRetry(String id) {
    if (_mediaRetry[id]?.isActive ?? false) return;
    final n = _mediaFails[id] = (_mediaFails[id] ?? 0) + 1;
    final delay = Duration(seconds: (30 << (n.clamp(1, 6) - 1)).clamp(30, 600));
    debugPrint('CloudSync: medya $id ${delay.inSeconds} sn sonra yeniden');
    _mediaRetry[id] = Timer(delay, () async {
      _mediaRetry.remove(id);
      final world =
          await _ref.read(appDatabaseProvider).worldsDao.getById(id);
      if (world == null || !world.isOnline) {
        _mediaFails.remove(id);
        return;
      }
      // Rol önbelleği tazelensin — ağ hatası `none` olarak kalmış olabilir.
      if (id == _ref.read(activeCampaignProvider)) {
        _ref.invalidate(currentWorldRoleProvider);
      } else {
        _ref.invalidate(worldRoleProvider(id));
      }
      try {
        await catchUp(id);
      } catch (e) {
        debugPrint('CloudSync: medya $id yeniden deneme hata=$e');
        _scheduleMediaRetry(id);
      }
    });
  }

  void _notice(List<String> names) {
    final fresh = names.where(_noticed.add).toList();
    if (fresh.isNotEmpty) {
      _ref.read(worldMediaNoticeProvider.notifier).state = fresh;
    }
  }

  /// Faz 5b — [worldId]'nin bulut sayacı [revision]'a çıktı (Realtime).
  void onSignal(String worldId, int revision) {
    _signalTimer?.cancel();
    _signalTimer =
        Timer(_signalIdle, () => unawaited(_onSignal(worldId, revision)));
  }

  Future<void> _onSignal(String worldId, int revision) async {
    // Şeridin boşalmasını bekle: sinyal kendi push'umuzdan geldiyse o tur
    // damgayı ilerletmiş olur ve aşağıdaki karşılaştırma yankıyı eler.
    await _rows.run(() async {});
    final world =
        await _ref.read(appDatabaseProvider).worldsDao.getById(worldId);
    debugPrint('CloudSync: sinyal $worldId rev=$revision '
        'yerel=${world?.cloudRevision}');
    if (world == null || revision <= world.cloudRevision) return;
    await catchUp(worldId);
  }

  /// Faz 5c — paket açılmadan önce: push, sonra pull (sıranın gerekçesi
  /// [catchUp]'ta). Paketin canlı sinyali yok; uzlaştırma anı açılış.
  ///
  /// [wait] kadar beklenir, sonra paket yerel haliyle açılır: yavaş ağ
  /// açılışı kilitlemesin. Geç biten pull satırları yine Drift'e yazar,
  /// bir sonraki açılışta görünür.
  Future<void> syncPackage(String packageName,
      {Duration wait = const Duration(seconds: 8)}) async {
    final svc = _ref.read(cloudPullServiceProvider);
    final id =
        (await _ref.read(appDatabaseProvider).packagesDao.getByName(packageName))
            ?.id;
    if (svc == null || id == null) return;
    Future<void> run() async {
      await pushPackage(packageId: id);
      final res = await _rows.run(() => svc.pullPackage(id));
      debugPrint('CloudSync: pull paket $id +${res.applied} -${res.removed} '
          'rev=${res.revision}${res.error != null ? ' hata=${res.error}' : ''}');
    }

    await run().timeout(wait, onTimeout: () {});
  }

  Future<CloudPushResult> pushActivePackage() =>
      _ref.read(activePackageProvider) == null
          ? Future.value(const CloudPushResult(skipped: true))
          : pushPackage();

  Future<CloudPushResult> _logged(
      String label, Future<CloudPushResult> run) async {
    final sw = Stopwatch()..start();
    final res = await run;
    debugPrint('CloudSync: $label ↑${res.pushed} ✕${res.deleted}'
        '${res.skipped ? ' atlandı' : ''}'
        '${res.error != null ? ' hata=${res.error}' : ''} '
        '${sw.elapsedMilliseconds} ms');
    if (res.rejected.isNotEmpty) {
      debugPrint('CloudPushPump: ${res.rejected.length} satır buluta '
          'yazılamadı: ${res.rejected.take(5).join(", ")}');
    }
    return res;
  }

  /// Kategori slug → oyuncudan gizlenecek alan anahtarları. Şemayı yorumlayan
  /// taraf istemci, uygulayan taraf `get_shared_entities` (§2.6).
  Map<String, List<String>> _dmOnlyKeys() {
    final schema = _ref.read(worldSchemaProvider);
    return {
      for (final c in schema.categories)
        c.slug: [
          for (final f in c.fields)
            if (f.visibility == FieldVisibility.dmOnly ||
                f.visibility == FieldVisibility.private_)
              f.fieldKey,
        ],
    };
  }

  void dispose() {
    _timer?.cancel();
    _signalTimer?.cancel();
    for (final t in _mediaRetry.values) {
      t.cancel();
    }
    _buffer.tick.removeListener(_onTick);
  }
}

/// İşleri sırayla koşturur; bir işin hatası şeridi tıkamaz.
class _Lane {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() body) {
    final next = _tail.then((_) => body());
    _tail = next.then<void>((_) {}, onError: (_) {});
    return next;
  }
}

/// `MainScreen` ve paket ekranı watch eder. Pull'un tetikleri pompada değil
/// dünya kanalında (`worldMirrorApplierProvider`): her `SUBSCRIBED`'da
/// [CloudPushPump.catchUp], her revizyon sinyalinde [CloudPushPump.onSignal].
final cloudPushPumpProvider = Provider<CloudPushPump>((ref) {
  final pump = CloudPushPump(ref);
  ref.onDispose(pump.dispose);
  return pump;
});
