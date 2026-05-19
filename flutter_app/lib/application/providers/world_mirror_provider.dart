import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../domain/entities/online/world_role.dart';
import '../services/world_mirror_applier.dart';
import '../services/world_mirror_service.dart';
import 'auth_provider.dart';
import 'role_provider.dart';
import 'world_membership_provider.dart';
import 'world_sync_provider.dart';

/// Tekil WorldMirrorService. Push + inbound echo-tracking için.
final worldMirrorServiceProvider = Provider<WorldMirrorService?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  if (ref.watch(authProvider) == null) return null;
  return WorldMirrorService(Supabase.instance.client);
});

/// Applier — sync.events stream'ini lokal state'e bağlar + aktif world için
/// otomatik subscribe + applyInitialState çalıştırır.
///
/// Bağlamlar:
///   - `activeCampaignIdProvider` resolve → world açık.
///   - `currentWorldRoleProvider` resolve + `WorldRole != none` → kullanıcı
///     member, RLS subscribe'a izin verir.
/// İki koşul sağlandığında channel açılır + initial state pull edilir.
/// Provider dispose'da (world değiştirme / sign-out / app pause invalidate)
/// kanal kapanır.
final worldMirrorApplierProvider =
    FutureProvider<WorldMirrorApplier?>((ref) async {
  final mirror = ref.watch(worldMirrorServiceProvider);
  final sync = ref.watch(worldSyncServiceProvider);
  if (mirror == null || sync == null) return null;

  final applier =
      WorldMirrorApplier(ref: ref, mirror: mirror, sync: sync)..start();
  ref.onDispose(applier.stop);

  final worldId = await ref.watch(activeCampaignIdProvider.future);
  final role = await ref.watch(currentWorldRoleProvider.future);
  if (worldId == null || role == WorldRole.none) return applier;

  // Race koşulu: subscribe öncesi yapılan join'ler kaybedilir. Channel
  // `SUBSCRIBED` durumuna geçtiğinde roster'ı taze fetch et — listMembers
  // RPC subscribe'tan sonraki INSERT'leri de toplar.
  void refreshRoster() {
    try {
      // ignore: discarded_futures
      ref
          .read(worldMembersProvider(worldId).notifier)
          .bootstrap(force: true);
    } catch (_) {
      // Provider scope tear-down sırasında patlamasın.
    }
  }

  if (!sync.isSubscribed(worldId)) {
    await sync.subscribe(worldId, onSubscribed: refreshRoster);
  } else {
    // Zaten subscribe iken (örn. world reopen aynı oturumda) yine de
    // bootstrap force et — CDC açıklığı olabilir.
    refreshRoster();
  }
  ref.onDispose(() => sync.unsubscribe(worldId));
  await applier.applyInitialState(worldId);
  return applier;
});

/// Manuel sync entry — "Retry now" Sync butonu fallback'i. Auto-subscribe
/// (PR-2) zaten kanal açar; bu fonksiyon kanal hâlâ kapalıysa açar ve
/// `applyInitialState` ile catchup tetikler. Idempotent.
Future<void> runManualWorldSync(WidgetRef ref) async {
  final svc = ref.read(worldSyncServiceProvider);
  if (svc == null) return;
  final campaignId = await ref.read(activeCampaignIdProvider.future);
  final role = await ref.read(currentWorldRoleProvider.future);
  if (campaignId == null || role == WorldRole.none) return;
  final applier = await ref.read(worldMirrorApplierProvider.future);
  if (!svc.isSubscribed(campaignId)) {
    await svc.subscribe(campaignId);
  }
  // Manuel "Retry" sync: roster'ı her durumda taze çek.
  try {
    await ref
        .read(worldMembersProvider(campaignId).notifier)
        .bootstrap(force: true);
  } catch (_) {}
  if (applier != null) {
    await applier.applyInitialState(campaignId);
  }
}
