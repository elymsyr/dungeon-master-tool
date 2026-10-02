import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/error_format.dart';
import '../../core/utils/format_bytes.dart';
import '../../data/database/sync_stamp.dart' show characterScope;
import '../../domain/entities/online/world_role.dart';
import '../services/cloud_pull_service.dart';
import '../services/cloud_push_service.dart';
import '../services/pending_write_buffer.dart';
import '../services/content_ref_index.dart';
import '../services/entity_share_prepare.dart' show dmOnlyKeysBySlug;
import '../services/world_media_sync.dart';
import 'auth_provider.dart';
import 'campaign_provider.dart';
import 'character_provider.dart' show characterListProvider;
import 'cloud_sync_status_provider.dart';
import 'connectivity_provider.dart';
import '../../data/database/database_provider.dart';
import 'entity_provider.dart';
import 'online_worlds_provider.dart';
import 'package_provider.dart' show activePackageProvider, packageListProvider;
import 'role_provider.dart';
import 'world_mirror_provider.dart' show worldMirrorServiceProvider;

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

/// Faz 5g — bu kullanıcının bulutta olup bu cihazda olmayan karakterleri.
/// Hub'ın karakter listesi değişince yeniden sorulur.
final cloudOnlyCharactersProvider =
    FutureProvider<List<CloudCharacter>>((ref) async {
  final svc = ref.watch(cloudPullServiceProvider);
  ref.watch(characterListProvider.select((s) => s.valueOrNull?.length));
  if (svc == null) return const [];
  try {
    return await svc.listCloudOnlyCharacters();
  } catch (e) {
    debugPrint('cloudOnlyCharacters: ${isOfflineError(e) ? 'offline' : e}');
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
/// bağlantı geri gelince [reconcileAll] — dünyayı açmak gerekmez. Faz 5e'den
/// beri online paketler de aynı anlarda ve medyalarıyla; paketin canlı
/// sinyali yok, zamanlayıcıyla yeniden denenmez.
///
/// Karakter (Faz 5g) kendi turunda: kapsamı sahibi, sinyali kullanıcı başına
/// `character_revisions` satırı (kanal oturum boyunca açık, dünyadan
/// bağımsız), düzenlemeden sonra 1 sn.
class CloudPushPump {
  CloudPushPump(this._ref) {
    _buffer = _ref.read(pendingWriteBufferProvider);
    _buffer.tick.addListener(_onTick);
    _ref.listen<AsyncValue<bool>>(connectivityStreamProvider, _onConnectivity);
    _ref.listen(authProvider, (_, next) => _bindCharacters(next?.uid),
        fireImmediately: true);
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
    if (!await _worldOnline(id)) return const CloudPushResult(skipped: true);
    // DM olmayan kimse ayna tablolarına yazamaz (RLS). Online dünya yalnız
    // DM'in cihazında işaretli; burada rol yoksa çözülemedi demek.
    final role = await _roleOf(id);
    if (role != WorldRole.dm) {
      debugPrint(
          'CloudSync: push $id atlandı, rol=${role?.name ?? 'çözülmedi'}');
      _status.markOffline(id);
      return const CloudPushResult(skipped: true);
    }
    // Tam tur ("multiplayer aç") medyasını ilerleme overlay'inde ayrıca
    // yüklüyor; burada beklenseydi satırlar bütün medyayı beklerdi.
    return _shown(
        id,
        CloudSyncIssue.push,
        () => _rows.run(() => _logged(
            'push $id',
            svc.pushWorld(id,
                dmOnlyKeys: dmOnlyKeysBySlug(_ref.read(worldSchemaProvider)),
                full: full,
                beforeRows: full ? null : (refs) => _uploadNew(id, refs)))));
  }

  CloudSyncStatusNotifier get _status =>
      _ref.read(cloudSyncStatusProvider.notifier);

  /// Faz 9 — online değilse göstergenin kaydı da kalkar (multiplayer
  /// kapandı): yerel dünyada gösterge yalnız yerel kaydı anlatır.
  Future<bool> _worldOnline(String id) async {
    final world = await _ref.read(appDatabaseProvider).worldsDao.getById(id);
    if (world?.isOnline ?? false) return true;
    _status.remove(id);
    return false;
  }

  /// Turu göstergeye yansıtır: sürerken "eşitleniyor", bitince sonucu.
  Future<T> _shown<T>(
      String key, CloudSyncIssue kind, Future<T> Function() body) async {
    _status.started(key);
    try {
      final res = await body();
      switch (res) {
        // Servisler yalnız öğe online değilse atlıyor.
        case CloudPushResult(skipped: true) || CloudPullResult(skipped: true):
          _status.remove(key);
        case CloudPushResult(:final error, :final rejected):
          _status.report(key, kind, error: error, failed: rejected.length);
        case CloudPullResult(:final error):
          _status.report(key, kind, error: error);
      }
      return res;
    } catch (e) {
      _status.report(key, kind, error: e);
      rethrow;
    } finally {
      _status.ended(key);
    }
  }

  /// Satırlardan önce: bu turun satırlarının andığı, bulutta olmayan medya.
  /// Hata atmaz ([_quiet]) — yüklenemese de satırlar gider, uzlaştırma
  /// sonra tamamlar. Pakette (Faz 5e) [statusKey] paketin adı; "oyunculara
  /// gitmeyecek" uyarısı yalnız dünyanın.
  Future<void> _uploadNew(
    String id,
    Map<String, WorldMediaRef> refs, {
    MediaScope scope = MediaScope.world,
    String? statusKey,
  }) async {
    final media = _ref.read(worldMediaSyncProvider);
    if (media == null || refs.isEmpty) return;
    final world = scope == MediaScope.world;
    await _quiet(id, () async {
      final rep = await media.upload(id, refs, scope: scope);
      if (world) _notice(rep.tooLarge);
      return rep;
    }, statusKey: statusKey, retry: world);
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
    final dao = _ref.read(appDatabaseProvider).packagesDao;
    final name = packageName ?? _ref.read(activePackageProvider);
    final row = packageId != null
        ? await dao.getById(packageId)
        : (name == null || name.isEmpty ? null : await dao.getByName(name));
    if (row == null) return const CloudPushResult(skipped: true);
    // Göstergenin anahtarı paket adı (bkz. [CloudSyncStatusNotifier]).
    if (!row.isOnline) {
      _status.remove(row.name);
      return const CloudPushResult(skipped: true);
    }
    final pid = row.id;
    // Medya satırlardan önce (Faz 5e), dünyadaki gerekçeyle. İlk yayında
    // servis atlıyor: paketin bulut satırı o turda doğuyor.
    return _shown(
        row.name,
        CloudSyncIssue.push,
        () => _rows.run(() => _logged(
            'push paket $pid',
            svc.pushPackage(pid,
                full: full,
                beforeRows: (refs) => _uploadNew(pid, refs,
                    scope: MediaScope.package, statusKey: row.name)))));
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
    final res = await _shown(id, CloudSyncIssue.pull,
        () => _rows.run(() => svc.pullWorld(id, full: full)));
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
  ///
  /// Faz 5e — online paketler de: çevrimdışı düzenlenip kapatılan paket
  /// açılmayı beklemeden çıkar. Açık paket yalnız push edilir: pull Drift'e
  /// yazar ama paket ekranı bellekteki halinden okuyup onu kaydediyor —
  /// inen satırları bir sonraki kayıtta eski halleriyle ezerdi. Öbür
  /// cihazın düzenlemesini bir sonraki açılışta görür.
  Future<void> reconcileAll() async {
    try {
      await catchUpCharacters();
    } catch (e) {
      debugPrint('CloudSync: uzlaştırma karakter hata=$e');
    }
    final db = _ref.read(appDatabaseProvider);
    final worlds = await db.worldsDao.getAll();
    for (final w in worlds) {
      if (!w.isOnline || w.id == _ref.read(activeCampaignProvider)) continue;
      _ref.invalidate(worldRoleProvider(w.id));
      try {
        await catchUp(w.id);
      } catch (e) {
        debugPrint('CloudSync: uzlaştırma ${w.id} hata=$e');
      }
    }
    for (final p in await db.packagesDao.getAll()) {
      if (!p.isOnline) continue;
      try {
        if (p.name == _ref.read(activePackageProvider)) {
          await pushPackage(packageId: p.id, packageName: p.name);
        } else {
          await _catchUpPackage(p.id, p.name);
        }
      } catch (e) {
        debugPrint('CloudSync: uzlaştırma paket ${p.id} hata=$e');
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

  /// Faz 5e — paketi online yapmak: bütün medyası, ilerlemeyle. Hata ve
  /// kota aşımı çağırana çıkar. Yarım kalan, paketin bir sonraki uzlaştırma
  /// anında tamamlanır (zamanlayıcı yok).
  Future<WorldMediaReport?> syncPackageMedia(
    String packageId, {
    void Function(int done, int total)? onProgress,
  }) =>
      _media.run(() => _fullMedia(packageId,
          scope: MediaScope.package, onProgress: onProgress));

  /// Kapsamın bütün satırlarındaki medyayı buluta çıkarır; [prune] ise artık
  /// anılmayanı siler. Limit aşımı burada bildirilmez: açılışta eski dosyalar
  /// için her seferinde uyarmak gürültü olurdu, uyarı eklenme anının.
  Future<WorldMediaReport?> _fullMedia(
    String id, {
    MediaScope scope = MediaScope.world,
    bool prune = false,
    void Function(int done, int total)? onProgress,
  }) async {
    final media = _ref.read(worldMediaSyncProvider);
    final svc = _ref.read(cloudPushServiceProvider);
    if (media == null || svc == null) return null;
    final world = scope == MediaScope.world;
    // Paket kullanıcı kapsamlı: rol yok, RLS sahibe bakıyor.
    if (world && await _roleOf(id) != WorldRole.dm) return null;
    final refs = world
        ? await svc.worldMediaRefs(id)
        : await svc.packageMediaRefs(id);
    media.forget(id, scope: scope);
    final rep = await media.upload(id, refs,
        scope: scope, onProgress: onProgress);
    if (rep.failed.isEmpty) _mediaSynced.add(id);
    _noticed.addAll(rep.tooLarge);
    if (prune) {
      final n = await media.prune(id, refs.keys.toSet(), scope: scope);
      _pruned.add(id);
      if (n > 0) debugPrint('CloudSync: medya $id yetim ✕$n');
    }
    return rep;
  }

  /// Arka plan medya işi: hata log'a, uzlaştırma bayrağı düşer ve yeniden
  /// deneme kurulur. Kota dolduysa kurulmaz — beklemek yer açmaz.
  ///
  /// Paket (Faz 5e) göstergeye adıyla girer ([statusKey]) ve [retry] almaz:
  /// uzlaştırma anları belli (açılış, [reconcileAll]).
  Future<void> _quiet(
    String id,
    Future<WorldMediaReport?> Function() body, {
    String? statusKey,
    bool retry = true,
  }) async {
    final key = statusKey ?? id;
    final sw = Stopwatch()..start();
    _status.started(key);
    try {
      final rep = await body();
      if (rep == null) return;
      _status.report(key, CloudSyncIssue.media, failed: rep.failed.length);
      if (rep.failed.isEmpty) _status.report(key, CloudSyncIssue.quota);
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
        if (retry) _scheduleMediaRetry(id);
      }
    } catch (e) {
      _mediaSynced.remove(id);
      debugPrint('CloudSync: medya $id hata=${isOfflineError(e) ? 'offline' : e}');
      if (e is WorldMediaQuotaException) {
        _ref.read(worldMediaQuotaProvider.notifier).state ??= e.pool;
        _status.report(key, CloudSyncIssue.quota, failed: 1);
      } else {
        _status.report(key, CloudSyncIssue.media, error: e);
        if (retry) _scheduleMediaRetry(id);
      }
    } finally {
      _status.ended(key);
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

  /// Faz 5c — paket açılmadan önce uzlaştırma ([_catchUpPackage]). Paketin
  /// canlı sinyali yok; uzlaştırma anı açılış (ve [reconcileAll]).
  ///
  /// [wait] kadar beklenir, sonra paket yerel haliyle açılır: yavaş ağ
  /// açılışı kilitlemesin. Geç biten pull satırları yine Drift'e yazar,
  /// bir sonraki açılışta görünür.
  ///
  /// false: [wait] doldu, paket bulutla uzlaşmadan açılıyor (Faz 9 — çağıran
  /// kullanıcıya söyler).
  Future<bool> syncPackage(String packageName,
      {Duration wait = const Duration(seconds: 8)}) async {
    final id =
        (await _ref.read(appDatabaseProvider).packagesDao.getByName(packageName))
            ?.id;
    if (_ref.read(cloudPullServiceProvider) == null || id == null) return true;
    Future<bool> run() async {
      await _catchUpPackage(id, packageName);
      return true;
    }

    return run().timeout(wait, onTimeout: () => false);
  }

  /// Paketin uzlaştırması: push, sonra pull (sıranın gerekçesi [catchUp]'ta),
  /// sonra oturumda bir kez bütün medyası (Faz 5e) — kendi şeridinde, açılışı
  /// bekletmeden. Yetim temizliği dünyadaki kuralla: yalnız pull tuttuysa.
  Future<void> _catchUpPackage(String id, String name) async {
    final svc = _ref.read(cloudPullServiceProvider);
    if (svc == null) return;
    final pushed = await pushPackage(packageId: id, packageName: name);
    // Push'la aynı koşul: paket online değil, pull da atlardı.
    if (pushed.skipped) return;
    final res = await _shown(
        name, CloudSyncIssue.pull, () => _rows.run(() => svc.pullPackage(id)));
    debugPrint('CloudSync: pull paket $id +${res.applied} -${res.removed} '
        'rev=${res.revision}${res.error != null ? ' hata=${res.error}' : ''}');
    if (_mediaSynced.contains(id) && _pruned.contains(id)) return;
    final prune = res.ok && !_pruned.contains(id);
    unawaited(_media.run(() => _quiet(
        id,
        () => _fullMedia(id, scope: MediaScope.package, prune: prune),
        statusKey: name,
        retry: false)));
  }

  // ── Faz 5g — karakter ───────────────────────────────────────────────────

  /// Karakter düzenlemesinden sonraki sessizlik (kullanıcının kararı): canlı
  /// oyunda oyuncunun HP'si DM'e dünyanın 3 sn'sini beklemeden gitsin.
  static const Duration _charIdle = Duration(seconds: 1);

  Timer? _charTimer;
  Timer? _charSignalTimer;
  Timer? _charResub;
  RealtimeChannel? _charChannel;
  String? _charUid;

  /// Karakter yerelde değişti (kaydedildi, silindi, anahtarı açıldı). Turun
  /// kapısı sahiplik — karakterin bulutta olup olmadığına tur bakar.
  void characterEdited() {
    _charTimer?.cancel();
    _charTimer = Timer(_charIdle, () => unawaited(pushCharacters()));
  }

  /// Karakter turu. [full] damgayı yok sayar: dünya multiplayer olunca
  /// karakterleri kapsama girdi ama düzenlenmedikleri için damgadan eski.
  Future<CloudPushResult> pushCharacters({bool full = false}) async {
    final svc = _ref.read(cloudPushServiceProvider);
    final uid = _ref.read(authProvider)?.uid;
    if (svc == null || uid == null) return const CloudPushResult(skipped: true);
    return _shown(
        characterScope,
        CloudSyncIssue.push,
        () => _rows.run(() => _logged(
            'push karakter',
            svc.pushCharacters(
                ownerId: uid,
                worlds: _ref.read(onlineWorldIdsProvider),
                full: full,
                media: _characterMedia))));
  }

  /// Satırlardan önce karakter başına medya (`characters/{id}/`). Yükleyemediği
  /// karakterler döner — servis onları satırdan sonra bir kez daha dener.
  /// Yeni bir görsel çıktıysa karakterin artık anılmayan görseli silinir
  /// (öbür cihazın tazesini [WorldMediaSync.pruneGrace] koruyor): portre
  /// değiştikçe eskisi kotada birikmesin. Bulut satırının andıkları da
  /// korunur: temizlik pull'dan önce koşuyor, bu satır LWW'yi kaybedecekse
  /// (öbür cihazda daha yeni portre) o portre silinmesin.
  Future<Set<String>> _characterMedia(
      Map<String, Map<String, WorldMediaRef>> refs) async {
    final media = _ref.read(worldMediaSyncProvider);
    final svc = _ref.read(cloudPushServiceProvider);
    final failed = <String>{};
    for (final MapEntry(key: id, value: shas) in refs.entries) {
      if (media == null || shas.isEmpty) continue;
      try {
        final rep =
            await media.upload(id, shas, scope: MediaScope.character);
        if (rep.failed.isNotEmpty) {
          failed.add(id);
        } else if (rep.uploaded > 0 && svc != null) {
          final keep = {...shas.keys, ...await svc.cloudCharacterShas(id)};
          await media.prune(id, keep, scope: MediaScope.character);
        }
      } on WorldMediaQuotaException catch (e) {
        _ref.read(worldMediaQuotaProvider.notifier).state ??= e.pool;
        break;
      } catch (e) {
        // İlk kez giden karakter: rezervasyon bulut satırını arıyor
        // (`not_scope_owner`), satırdan sonra yeniden.
        debugPrint('CloudSync: medya karakter $id ${isOfflineError(e) ? 'offline' : e}');
        failed.add(id);
      }
    }
    // Paylaşım yayını kendi yazmamızı geri getiriyor; satır yerel yolların
    // yerine ref taşıdığı için uygulanmamalı (eski doğrudan yolun yankı
    // damgası). Satırlardan hemen önce: 3 sn'lik pencere medyayla dolmasın.
    final mirror = _ref.read(worldMirrorServiceProvider);
    for (final id in refs.keys) {
      mirror?.markPushed(id);
    }
    return failed;
  }

  /// Karakter kapsamının uzlaştırması: push, sonra pull (sıranın gerekçesi
  /// [catchUp]'ta). Kanal `SUBSCRIBED` olunca, sahibin sinyalinde ve
  /// [reconcileAll]'da.
  Future<void> catchUpCharacters() async {
    if (_ref.read(cloudPullServiceProvider) == null) return;
    await _buffer.flush();
    // Karakterin dünyası online mı, bu listeye bakılarak karar veriliyor;
    // çevrimdışı açılışta boş kalmış olabilir.
    await _ref.read(onlineWorldIdsProvider.notifier).refresh();
    final pushed = await pushCharacters();
    if (pushed.skipped) return;
    final svc = _ref.read(cloudPullServiceProvider);
    if (svc == null) return;
    final res = await _rows.run(() => svc.pullCharacters());
    final pull = res.pull;
    debugPrint('CloudSync: pull karakter +${pull.applied} '
        '-${res.deleted.length} ~${res.gone.length} rev=${pull.revision}'
        '${pull.error != null ? ' hata=${pull.error}' : ''}');
    _status.report(characterScope, CloudSyncIssue.pull, error: pull.error);
    // Öbür cihazda online yapılan karakter yerelde yok, pull onu uygulamaz:
    // hub'ın "bulutta, bu cihazda yok" listesi buradan tazelenir.
    _ref.invalidate(cloudOnlyCharactersProvider);
    if (pull.applied > 0 || res.deleted.isNotEmpty || res.gone.isNotEmpty) {
      await _ref.read(characterListProvider.notifier).applyCloudRemovals(
          deleted: res.deleted,
          gone: res.gone,
          onlineWorlds: _ref.read(onlineWorldIdsProvider));
    }
  }

  /// Sahibin kanalı: oturum açıkken tek kanal, dünyalardan bağımsız.
  /// `SUBSCRIBED` (ilk bağlanma ve her yeniden bağlanma) uzlaştırır.
  void _bindCharacters(String? uid) {
    if (uid == _charUid) return;
    _charUid = uid;
    _charResub?.cancel();
    final old = _charChannel;
    _charChannel = null;
    if (!SupabaseConfig.isConfigured) return;
    final client = Supabase.instance.client;
    if (old != null) unawaited(client.removeChannel(old));
    if (uid == null) return;
    _charChannel = client.channel('dmt:characters:$uid')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'character_revisions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'owner_id',
          value: uid,
        ),
        callback: (p) {
          final rev = p.newRecord['revision'];
          if (rev is num) _onCharacterSignal(rev.toInt());
        },
      )
      ..subscribe((status, error) {
        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
            unawaited(catchUpCharacters());
          case RealtimeSubscribeStatus.channelError:
          case RealtimeSubscribeStatus.timedOut:
            debugPrint('CloudSync: karakter kanalı $status: $error');
            _charResub?.cancel();
            _charResub = Timer(const Duration(seconds: 30), () {
              if (_ref.read(authProvider)?.uid != uid) return;
              _charUid = null;
              _bindCharacters(uid);
            });
          case RealtimeSubscribeStatus.closed:
            break;
        }
      });
  }

  /// Öbür cihazın turu sayacı satır başına artırıyor: pencere patlamayı tek
  /// uzlaştırmaya indirir; kendi turumuzun yankısını damga eler.
  void _onCharacterSignal(int revision) {
    _charSignalTimer?.cancel();
    _charSignalTimer = Timer(_signalIdle, () async {
      await _rows.run(() async {});
      final mark =
          await _ref.read(appDatabaseProvider).worldCharactersDao.cloudMark();
      debugPrint('CloudSync: karakter sinyali rev=$revision '
          'yerel=${mark.revision}');
      if (revision <= mark.revision) return;
      await catchUpCharacters();
    });
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

  void dispose() {
    _timer?.cancel();
    _signalTimer?.cancel();
    _charTimer?.cancel();
    _charSignalTimer?.cancel();
    _charResub?.cancel();
    final ch = _charChannel;
    if (ch != null) unawaited(Supabase.instance.client.removeChannel(ch));
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
