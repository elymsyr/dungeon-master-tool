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

/// Applier — sync.events stream'ini local state'e bağlar. Singleton kalır;
/// realtime subscription tamamen manuel olduğundan applier sadece event
/// kanalına bağlı durur, hiç event almazsa no-op.
final worldMirrorApplierProvider = Provider<WorldMirrorApplier?>((ref) {
  final mirror = ref.watch(worldMirrorServiceProvider);
  final sync = ref.watch(worldSyncServiceProvider);
  if (mirror == null || sync == null) return null;
  final applier =
      WorldMirrorApplier(ref: ref, mirror: mirror, sync: sync)..start();
  ref.onDispose(() => applier.stop());
  return applier;
});

/// Manuel sync giriş noktası. Sync butonu çağırır — subscribe + initial
/// snapshot pull. Hiçbir yerde otomatik watch edilmez. WidgetRef veya Ref
/// kabul eder (her ikisi de `.read` + `.read(<future>)` destekler).
Future<void> runManualWorldSync(WidgetRef ref) async {
  final svc = ref.read(worldSyncServiceProvider);
  if (svc == null) return;
  final campaignId = await ref.read(activeCampaignIdProvider.future);
  final role = await ref.read(currentWorldRoleProvider.future);
  if (campaignId == null || role == WorldRole.none) return;
  final applier = ref.read(worldMirrorApplierProvider);
  if (!svc.isSubscribed(campaignId)) {
    await svc.subscribe(campaignId);
  }
  if (applier != null) {
    await applier.applyInitialState(campaignId);
  }
}
