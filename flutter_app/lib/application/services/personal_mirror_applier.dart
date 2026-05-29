import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/database/database_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/campaign_provider.dart';
import '../providers/online_worlds_provider.dart';
import '../providers/package_provider.dart';
import '../providers/role_provider.dart';
import 'beta_enter_gate.dart';
import 'beta_loss_gate.dart';
import 'personal_sync_service.dart';
import 'world_mirror_applier.dart';
import 'world_mirror_service.dart';

/// `PersonalSyncService.events` stream'ini local state'e uygular.
///
/// Sorumluluk (PR-3 sonrası):
///   - `world_members` INSERT (self) → `onlineWorldIdsProvider.add` +
///     hub world list refresh. DELETE (self) → karşılığı yoksa local
///     world'ü purge et (DM-kick on başka cihaz senaryosu).
///   - `world_characters` (`owner_id = uid`) → `WorldMirrorApplier`
///     ortak apply'ı; owner'ın karakteri dünya kapalıyken de canlı sync.
///
/// **Package + worldless char realtime KALDIRILDI** (PR-3): `personal_packages`,
/// `personal_package_entities`, `cloud_backups` CDC dinlenmez. Cross-device
/// pull `bootstrap()` üzerinden (auto on applier provider resolve + manual
/// Sync button).
///
/// `personal_characters` retire edildi — world-bound char cross-device sync
/// `world_characters` CDC + RLS üzerinden çalışır
/// (bkz. `world_mirror_applier.dart`).
class PersonalMirrorApplier {
  final Ref ref;
  final PersonalSyncService service;
  final WorldMirrorService mirror;
  final WorldMirrorApplier? worldApplier;

  StreamSubscription<PersonalSyncEvent>? _sub;
  String? _bootstrappedFor;

  PersonalMirrorApplier({
    required this.ref,
    required this.service,
    required this.mirror,
    this.worldApplier,
  });

  void start() {
    _sub ??= service.events.listen(_onEvent);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _bootstrappedFor = null;
  }

  /// Subscribe sonrası lokal state'i sunucu ile aynı hizaya getirir.
  /// Row-level pull: `personal_packages` her satırı + `personal_package_entities`
  /// her satırı. Yeni cihaza ilk giriş için bootstrap. Aynı uid için idempotent.
  /// World-bound karakterler `world_mirror_applier` üzerinden bootstrap edilir.
  Future<void> bootstrap() async {
    final auth = ref.read(authProvider);
    if (auth == null) return;
    if (_bootstrappedFor == auth.uid) return;
    _bootstrappedFor = auth.uid;
    final client = Supabase.instance.client;
    final repo = ref.read(packageRepositoryProvider);
    // Beta-enter wipe guard: PackageRepositoryImpl._saveToDb full-replaces
    // package entities. Until first-enter merge runs, do NOT overwrite local
    // packages that already exist — stale cloud rows would wipe offline work.
    // Cloud-only packages (no local copy) still pull safely.
    final betaEnterCompleted =
        await ref.read(betaEnterGateProvider).isCompleted(auth.uid);
    Set<String> localPkgNames = const <String>{};
    if (!betaEnterCompleted) {
      try {
        final db = ref.read(appDatabaseProvider);
        final rows = await db.packagesDao.getAll();
        localPkgNames = rows.map((p) => p.name).toSet();
      } catch (_) {/* ignore — fall through with empty set */}
    }
    try {
      final rows = await client
          .from('personal_packages')
          .select('package_name, state_json')
          .eq('owner_id', auth.uid);
      var any = false;
      for (final raw in rows as List) {
        final row = raw as Map;
        final name = row['package_name'] as String?;
        final state = row['state_json'];
        if (name == null || state is! String) continue;
        if (!betaEnterCompleted && localPkgNames.contains(name)) {
          debugPrint(
              'PersonalMirrorApplier: skip package bootstrap "$name" — beta-enter gate unset');
          continue;
        }
        try {
          final decoded = jsonDecode(state);
          if (decoded is! Map<String, dynamic>) continue;
          await repo.save(name, decoded);
          any = true;
        } catch (err) {
          debugPrint('personal_packages bootstrap row error: $err');
        }
      }
      if (any) ref.invalidate(packageListProvider);
    } catch (e) {
      debugPrint('PersonalMirrorApplier bootstrap packages error: $e');
    }
    try {
      final rows = await client
          .from('personal_package_entities')
          .select('package_name, id, payload_json')
          .eq('owner_id', auth.uid);
      for (final raw in rows as List) {
        final row = raw as Map;
        final name = row['package_name'] as String?;
        final id = row['id'] as String?;
        final payload = row['payload_json'];
        if (name == null || id == null || payload is! String) continue;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is! Map<String, dynamic>) continue;
          await repo.saveEntity(name, id, decoded);
        } catch (err) {
          debugPrint('personal_package_entities bootstrap row error: $err');
        }
      }
    } catch (e) {
      debugPrint('PersonalMirrorApplier bootstrap entities error: $e');
    }
  }

  Future<void> _onEvent(PersonalSyncEvent e) async {
    try {
      switch (e.table) {
        case 'world_members':
          await _applyMembersEvent(e);
        case 'world_characters':
          await _applyCharacterEvent(e);
      }
    } catch (err, st) {
      debugPrint('PersonalMirrorApplier error: $err\n$st');
    }
  }

  /// `world_characters` CDC per-user channel'dan `owner_id = uid` filtreli
  /// gelir — owner'ın online-dünya karakteri dünya açık olmasa da (hub char
  /// tab) canlı sync olsun. Apply mantığı world channel ile ortak
  /// (`WorldMirrorApplier.applyCharacterCdc`).
  Future<void> _applyCharacterEvent(PersonalSyncEvent e) async {
    final id = (e.newRecord['id'] ?? e.oldRecord['id']) as String?;
    if (id == null) return;
    // Self-echo: kendi push'umuzun event'i — `WorldMirrorService` ile
    // paylaşılan stamp map'i üzerinden filtrele.
    if (mirror.isEchoOfId(id)) return;
    await worldApplier?.applyCharacterCdc(
      eventType: e.eventType,
      newRecord: e.newRecord,
      oldRecord: e.oldRecord,
      channelWorldId: null,
    );
  }

  /// `world_members` CDC kullanıcının kendi user_id'si üzerinden filtreli
  /// gelir; INSERT → bu cihaz başka cihazda yapılan join'i öğrenir,
  /// DELETE → kick edildi veya başka cihazda leave yapıldı.
  Future<void> _applyMembersEvent(PersonalSyncEvent e) async {
    final worldId =
        (e.newRecord['world_id'] ?? e.oldRecord['world_id']) as String?;
    if (worldId == null) return;
    switch (e.eventType) {
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        ref.read(onlineWorldIdsProvider.notifier).add(worldId);
        ref.invalidate(worldRoleProvider(worldId));
        ref.invalidate(currentWorldRoleProvider);
        ref.invalidate(campaignInfoListProvider);
        ref.invalidate(campaignListProvider);
      case PostgresChangeEvent.delete:
        ref.read(onlineWorldIdsProvider.notifier).remove(worldId);
        ref.invalidate(worldRoleProvider(worldId));
        ref.invalidate(currentWorldRoleProvider);
        ref.invalidate(campaignInfoListProvider);
        ref.invalidate(campaignListProvider);
        // Make Offline: DM lokal dünyayı offline olarak tutmak istiyor —
        // purge'ü atla. Cleanup + guard temizliği world kanalı applier'ına
        // ait (handleExpectedUnpublish); burada çift cleanup yapma.
        if (mirror.isExpectedUnpublish(worldId)) break;
        // Involuntary beta loss: I own this world but lost beta (inactivity
        // sweep / admin revoke) — keep the local copy as offline, don't purge.
        if (await _ownsWorldAndLostBeta(worldId)) break;
        // Local mirror'ı temizle — başka cihazda leave/kick edildikse bu
        // cihazda ölü dünya kalmasın.
        try {
          await worldApplier?.purgeLocalWorld(worldId);
        } catch (err) {
          debugPrint('personal_members purgeLocalWorld error: $err');
        }
      default:
        return;
    }
  }

  /// Involuntary beta loss preserve: while the per-uid sentinel is set, a CDC
  /// membership DELETE for a world the user OWNS must keep the local mirror as
  /// offline instead of purging. Scoped to `ownerId == uid` so normal
  /// non-owner kicks still purge.
  Future<bool> _ownsWorldAndLostBeta(String worldId) async {
    final uid = ref.read(authProvider)?.uid;
    if (uid == null || !ref.read(betaLossGateProvider).isMarkedSync(uid)) {
      return false;
    }
    try {
      final w = await ref.read(appDatabaseProvider).worldsDao.getById(worldId);
      return w != null && w.ownerId == uid;
    } catch (_) {
      return false;
    }
  }
}
