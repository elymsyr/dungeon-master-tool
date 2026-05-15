import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../domain/entities/online/world_role.dart';
import '../services/world_mirror_applier.dart';
import '../services/world_mirror_service.dart';
import 'auth_provider.dart';
import 'role_provider.dart';
import 'world_sync_provider.dart';

/// Tekil WorldMirrorService. Push + inbound echo-tracking için.
final worldMirrorServiceProvider = Provider<WorldMirrorService?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  if (ref.watch(authProvider) == null) return null;
  return WorldMirrorService(Supabase.instance.client);
});

/// Applier — sync.events stream'ini local state'e bağlar. App startup
/// `ref.watch(worldMirrorApplierProvider)` ile başlatılır.
final worldMirrorApplierProvider = Provider<WorldMirrorApplier?>((ref) {
  final mirror = ref.watch(worldMirrorServiceProvider);
  final sync = ref.watch(worldSyncServiceProvider);
  if (mirror == null || sync == null) return null;
  final applier =
      WorldMirrorApplier(ref: ref, mirror: mirror, sync: sync)..start();
  ref.onDispose(() => applier.stop());
  return applier;
});

/// Aktif campaign + rol değiştikçe sync subscription'ı otomatik açıp kapatır.
/// Subscribe'tan hemen sonra `WorldMirrorApplier.applyInitialState` ile remote
/// snapshot local'a seed edilir. MainScreen
/// `ref.watch(worldSyncAutoSubscribeProvider)` ile tetikler.
final worldSyncAutoSubscribeProvider = Provider<void>((ref) {
  final svc = ref.watch(worldSyncServiceProvider);
  if (svc == null) return;
  final applier = ref.watch(worldMirrorApplierProvider);
  final campaignId = ref.watch(activeCampaignIdProvider).valueOrNull;
  final role =
      ref.watch(currentWorldRoleProvider).valueOrNull ?? WorldRole.none;

  if (campaignId == null || role == WorldRole.none) {
    unawaited(svc.unsubscribeAll());
    return;
  }
  if (!svc.isSubscribed(campaignId)) {
    // Fire-and-forget — UI build no longer blocks on remote snapshot seed.
    // Drift mirror rows will trigger entity_provider notifiers as they
    // arrive; tab content paints immediately.
    unawaited(svc.subscribe(campaignId));
    final a = applier;
    if (a != null) {
      unawaited(a.applyInitialState(campaignId));
    }
  }
});
