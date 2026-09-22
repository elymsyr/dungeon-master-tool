import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
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
import 'package_provider.dart' show activePackageProvider;
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

/// Yazma tamponu sustuğunda push turunu tetikler; dünya açılışında bir kez de
/// pull koşar.
///
/// Tampon zaten 750–2000 ms debounce ediyor; buradaki [_idle] onun üstüne
/// binen ikinci bir sessizlik penceresi — kart düzenlerken her tuş vuruşunda
/// değil, eli çektikten sonra tek tur gider.
class CloudPushPump {
  CloudPushPump(this._ref) {
    _buffer = _ref.read(pendingWriteBufferProvider);
    _buffer.tick.addListener(_onTick);
  }

  final Ref _ref;
  late final PendingWriteBuffer _buffer;

  static const Duration _idle = Duration(seconds: 3);

  Timer? _timer;
  bool _running = false;
  bool _pendingRound = false;

  void _onTick() {
    _timer?.cancel();
    _timer = Timer(_idle, () => unawaited(_round()));
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
    if (_ref.read(currentWorldRoleProvider).valueOrNull != WorldRole.dm) {
      return const CloudPushResult(skipped: true);
    }
    return _guarded(
        () => svc.pushWorld(id, dmOnlyKeys: _dmOnlyKeys(), full: full));
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
    return _guarded(() => svc.pushPackage(pid, full: full));
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
    if (_ref.read(currentWorldRoleProvider).valueOrNull != WorldRole.dm) {
      return const CloudPullResult(skipped: true);
    }
    return svc.pullWorld(id, full: full);
  }

  /// Dünya açılışındaki tek senkron turu: **önce push, sonra pull.**
  ///
  /// Sıra rastgele değil. Pull satırı bulutun `updated_at`'i ile yazıyor;
  /// push'un damgası tur başında `now()`'a çekildiği için ondan önce
  /// düzenlenmiş uzak satırlar bir sonraki push taramasına düşmez. Ters sırada
  /// her pull, kendi getirdiği satırları buluta geri göndertirdi.
  Future<void> syncOnOpen() async {
    if (_opened) return;
    _opened = true;
    await push();
    await pull();
  }

  bool _opened = false;

  Future<CloudPushResult> pushActivePackage() =>
      _ref.read(activePackageProvider) == null
          ? Future.value(const CloudPushResult(skipped: true))
          : pushPackage();

  /// Tek seferde tek tur. Tur sürerken gelen istekler tek bir ek tura
  /// toplanır — üst üste binen turlar aynı satırları iki kez göndermekten
  /// başka bir şey yapmaz.
  Future<CloudPushResult> _guarded(
      Future<CloudPushResult> Function() body) async {
    if (_running) {
      _pendingRound = true;
      return const CloudPushResult(skipped: true);
    }
    _running = true;
    try {
      final res = await body();
      if (res.rejected.isNotEmpty) {
        debugPrint('CloudPushPump: ${res.rejected.length} satır buluta '
            'yazılamadı: ${res.rejected.take(5).join(", ")}');
      }
      return res;
    } finally {
      _running = false;
      if (_pendingRound) {
        _pendingRound = false;
        unawaited(_round());
      }
    }
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
    _buffer.tick.removeListener(_onTick);
  }
}

/// Dünya açıkken hayatta tutulur (`MainScreen` watch eder).
///
/// Rol DM'e çözülür çözülmez açılış senkronu bir kez koşar; pompa dünya
/// kapanınca dispose olduğu için bayrak da onunla gider.
final cloudPushPumpProvider = Provider<CloudPushPump>((ref) {
  final pump = CloudPushPump(ref);
  ref.listen<AsyncValue<WorldRole?>>(
    currentWorldRoleProvider,
    (_, next) {
      if (next.valueOrNull == WorldRole.dm) unawaited(pump.syncOnOpen());
    },
    fireImmediately: true,
  );
  ref.onDispose(pump.dispose);
  return pump;
});
