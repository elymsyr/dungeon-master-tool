import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/error_format.dart';
import '../../domain/entities/online/world_role.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../services/cloud_pull_service.dart';
import '../services/cloud_push_service.dart';
import '../services/pending_write_buffer.dart';
import '../services/content_ref_index.dart';
import '../services/shared_media_courier.dart';
import 'auth_provider.dart';
import 'campaign_provider.dart';
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
    courier: ref.read(sharedMediaCourierProvider),
  );
});

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
/// Push ve pull **tek şeritten** geçer ([_serial]): üst üste binmezler. Bu
/// yalnız israf önlemi değil — sinyal geldiğinde kendi push'umuz hâlâ
/// sürüyorsa, pull onun damgayı ilerletmesini bekler ve kendi yankısını
/// çekmez.
class CloudPushPump {
  CloudPushPump(this._ref) {
    _buffer = _ref.read(pendingWriteBufferProvider);
    _buffer.tick.addListener(_onTick);
  }

  final Ref _ref;
  late final PendingWriteBuffer _buffer;

  static const Duration _idle = Duration(seconds: 3);

  /// Karşı cihazın bir push turu satır başına bir sinyal üretir (sayaç her
  /// yazmada artıyor); pencere o patlamayı tek pull'a indirir.
  static const Duration _signalIdle = Duration(seconds: 1);

  Timer? _timer;
  Timer? _signalTimer;
  Future<void> _lane = Future.value();

  void _onTick() {
    _timer?.cancel();
    _timer = Timer(_idle, () => unawaited(_round()));
  }

  /// İşleri sırayla koşturur; bir işin hatası şeridi tıkamaz.
  Future<T> _serial<T>(Future<T> Function() body) {
    final next = _lane.then((_) => body());
    _lane = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  /// Açık olan ne varsa bir tur: dünya ve/veya paket. İkisi aynı anda açık
  /// olmuyor ama hangisinin açık olduğunu sormak yerine ikisini de denemek
  /// daha ucuz — kapalı olan satırı bulamayıp atlıyor.
  Future<void> _round() async {
    await push();
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
    // DM olmayan kimse ayna tablolarına yazamaz (RLS). Rol çözülmediyse tur
    // atlanır, bir sonraki tick yeniden dener.
    final role = _ref.read(currentWorldRoleProvider).valueOrNull;
    if (role != WorldRole.dm) {
      debugPrint(
          'CloudSync: push $id atlandı, rol=${role?.name ?? 'çözülmedi'}');
      return const CloudPushResult(skipped: true);
    }
    return _serial(() => _logged('push $id',
        svc.pushWorld(id, dmOnlyKeys: _dmOnlyKeys(), full: full)));
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
    return _serial(
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
    final role = _ref.read(currentWorldRoleProvider).valueOrNull;
    if (role != WorldRole.dm) {
      debugPrint(
          'CloudSync: pull $id atlandı, rol=${role?.name ?? 'çözülmedi'}');
      return const CloudPullResult(skipped: true);
    }
    final res = await _serial(() => svc.pullWorld(id, full: full));
    debugPrint('CloudSync: pull $id +${res.applied} -${res.removed} '
        'rev=${res.revision}${res.skipped ? ' atlandı' : ''}'
        '${res.error != null ? ' hata=${res.error}' : ''}');
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
  Future<void> catchUp(String worldId) async {
    debugPrint('CloudSync: catchUp $worldId');
    await _buffer.flush();
    await push(worldId: worldId);
    await pull(worldId: worldId);
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
    await _serial(() async {});
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
      final res = await _serial(() => svc.pullPackage(id));
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
    final res = await run;
    debugPrint('CloudSync: $label ↑${res.pushed} ✕${res.deleted}'
        '${res.skipped ? ' atlandı' : ''}'
        '${res.error != null ? ' hata=${res.error}' : ''}');
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
    _buffer.tick.removeListener(_onTick);
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
