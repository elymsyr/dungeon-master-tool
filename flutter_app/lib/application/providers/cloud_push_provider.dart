import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../domain/entities/online/world_role.dart';
import '../../domain/entities/schema/field_schema.dart';
import '../services/cloud_push_service.dart';
import '../services/pending_write_buffer.dart';
import '../services/shared_media_courier.dart';
import 'auth_provider.dart';
import 'campaign_provider.dart';
import '../../data/database/database_provider.dart';
import 'entity_provider.dart';
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

/// Yazma tamponu sustuğunda push turunu tetikler.
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
    _timer = Timer(_idle, () => unawaited(push()));
  }

  /// Aktif dünyanın turunu koşturur. [full] ilk yayın / "yeniden gönder".
  ///
  /// Tur sürerken gelen istekler tek bir ek tura toplanır — üst üste binen
  /// turlar aynı satırları iki kez göndermekten başka bir şey yapmaz.
  Future<CloudPushResult> push({bool full = false, String? worldId}) async {
    if (_running) {
      _pendingRound = true;
      return const CloudPushResult(skipped: true);
    }
    final svc = _ref.read(cloudPushServiceProvider);
    // `activeCampaignProvider` "açık içeriğin anahtarı" — pakette paket adı
    // tutuyor (§4.7). Dünya değilse servis satırı bulamaz ve tur atlanır.
    final id = worldId ?? _ref.read(activeCampaignProvider);
    if (svc == null || id == null || id.isEmpty) {
      return const CloudPushResult(skipped: true);
    }
    // DM olmayan kimse ayna tablolarına yazamaz (RLS). Rol çözülmediyse tur
    // atlanır, bir sonraki tick yeniden dener.
    if (_ref.read(currentWorldRoleProvider).valueOrNull != WorldRole.dm) {
      return const CloudPushResult(skipped: true);
    }
    _running = true;
    try {
      final res = await svc.pushWorld(id, dmOnlyKeys: _dmOnlyKeys(), full: full);
      if (res.rejected.isNotEmpty) {
        debugPrint('CloudPushPump: ${res.rejected.length} satır buluta '
            'yazılamadı: ${res.rejected.take(5).join(", ")}');
      }
      return res;
    } finally {
      _running = false;
      if (_pendingRound) {
        _pendingRound = false;
        unawaited(push());
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
final cloudPushPumpProvider = Provider<CloudPushPump>((ref) {
  final pump = CloudPushPump(ref);
  ref.onDispose(pump.dispose);
  return pump;
});
