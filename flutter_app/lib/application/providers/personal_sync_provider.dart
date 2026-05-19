import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../core/config/supabase_config.dart';
import '../services/personal_mirror_applier.dart';
import '../services/personal_sync_service.dart';
import 'auth_provider.dart';
import 'character_provider.dart';
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

/// Applier — service.events'i local repository'lere uygular + cold-start'ta
/// otomatik bootstrap çalıştırır (paket + worldless char pull).
final personalMirrorApplierProvider =
    Provider<PersonalMirrorApplier?>((ref) {
  final svc = ref.watch(personalSyncServiceProvider);
  final mirror = ref.watch(worldMirrorServiceProvider);
  if (svc == null || mirror == null) return null;
  final worldApplier = ref.watch(worldMirrorApplierProvider).valueOrNull;
  final applier = PersonalMirrorApplier(
    ref: ref,
    service: svc,
    mirror: mirror,
    worldApplier: worldApplier,
  )..start();
  ref.onDispose(applier.stop);
  // Auto-bootstrap on first resolve. world_members channel realtime için
  // service.start(uid) çağrısı da burada. Bootstrap kendi içinde idempotent.
  final auth = ref.read(authProvider);
  if (auth != null) {
    unawaited(() async {
      try {
        if (svc.activeUid != auth.uid) {
          await svc.start(auth.uid);
        }
        await applier.bootstrap();
        await ref.read(characterListProvider.notifier).pullNewerFromCloud();
      } catch (_) {/* best-effort */}
    }());
  }
  return applier;
});

/// Manuel personal sync giriş noktası — Sync butonu fallback. Auto bootstrap
/// (PR-3 startup gate + PR-3 applier provider) zaten cold-start'ta çalışır;
/// bu fonksiyon kullanıcı manuel "Retry" der ise yeniden tetikler.
Future<void> runManualPersonalSync(WidgetRef ref) async {
  final svc = ref.read(personalSyncServiceProvider);
  if (svc == null) return;
  final auth = ref.read(authProvider);
  if (auth == null) {
    await svc.stop();
    return;
  }
  final applier = ref.read(personalMirrorApplierProvider);
  final uid = auth.uid;
  if (svc.activeUid != uid) {
    await svc.start(uid);
  }
  await applier?.bootstrap();
}
