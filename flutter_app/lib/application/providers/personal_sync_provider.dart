import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../core/config/supabase_config.dart';
import '../services/personal_mirror_applier.dart';
import '../services/personal_sync_service.dart';
import 'auth_provider.dart';
import 'world_mirror_provider.dart';

/// Tekil PersonalSyncService — Supabase Realtime kanalını yönetir.
final personalSyncServiceProvider =
    Provider<PersonalSyncService?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  if (ref.watch(authProvider) == null) return null;
  final svc = PersonalSyncService(Supabase.instance.client);
  ref.onDispose(svc.dispose);
  return svc;
});

/// Applier — service.events'i local repository'lere uygular.
final personalMirrorApplierProvider =
    Provider<PersonalMirrorApplier?>((ref) {
  final svc = ref.watch(personalSyncServiceProvider);
  final mirror = ref.watch(worldMirrorServiceProvider);
  if (svc == null || mirror == null) return null;
  final worldApplier = ref.watch(worldMirrorApplierProvider);
  final applier = PersonalMirrorApplier(
    ref: ref,
    service: svc,
    mirror: mirror,
    worldApplier: worldApplier,
  )..start();
  ref.onDispose(applier.stop);
  return applier;
});

/// Auth değişikliğinde personal kanalı otomatik açar/kapatır + ilk
/// bootstrap pull'unu yapar. Root widget `ref.watch(...)` ile tetikler.
final personalSyncAutoSubscribeProvider = Provider<void>((ref) {
  final svc = ref.watch(personalSyncServiceProvider);
  if (svc == null) {
    return;
  }
  final applier = ref.watch(personalMirrorApplierProvider);
  final auth = ref.watch(authProvider);
  if (auth == null) {
    // ignore: discarded_futures
    svc.stop();
    return;
  }
  final uid = auth.uid;
  if (svc.activeUid == uid) return;
  // ignore: discarded_futures
  svc.start(uid).then((_) {
    applier?.bootstrap();
  });
});
