import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/beta_provider.dart';
import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/character_provider.dart';
import '../../../application/providers/package_provider.dart';
import '../../../application/providers/personal_sync_provider.dart';
import '../../../application/providers/world_mirror_provider.dart';
import '../../../application/services/beta_enter_merge_service.dart';
import '../../../application/services/cloud_catchup_service.dart';
import '../../../application/services/pending_write_buffer.dart';
import '../../../application/services/world_reconciler.dart';
import '../../../core/config/supabase_config.dart';
import '../../widgets/app_icon_image.dart';

/// Cold-start sync gate. Splash card with progress message stays on top until:
///   1. Pending local writes flushed (drain any debounce timers carried over
///      from previous run).
///   2. (Beta + auth ready) row-level cloud catchup — personal packages,
///      worldless characters, all per-row.
///   3. Active world (if any) realtime subscribe + applyInitialState resolved.
///
/// Whole sequence is best-effort with an 8s ceiling — offline / slow networks
/// don't block the user. Once done, `child` (the actual app shell) renders.
class StartupSyncGate extends ConsumerStatefulWidget {
  const StartupSyncGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StartupSyncGate> createState() => _StartupSyncGateState();
}

class _StartupSyncGateState extends ConsumerState<StartupSyncGate> {
  bool _ready = false;
  String _message = 'Syncing local writes...';
  static const Duration _ceiling = Duration(seconds: 8);

  /// Initial `_runSequence` auth-null guard'ında çıktıysa veya kullanıcı
  /// uygulama içinde sign-in yaptıysa, bu listener bir kez catchup+reconcile
  /// tetikler. `null → non-null` geçişinde fire eder; aynı session'da tekrar
  /// fire etmez. Splash kapalıyken UI'a görünür değişiklik yok — sadece
  /// provider invalidate (`worlds` / `packages` / `characters`).
  bool _retryFired = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _runDeferredCatchup() async {
    if (_retryFired) return;
    _retryFired = true;
    if (!SupabaseConfig.isConfigured) return;
    if (ref.read(authProvider) == null) return;
    try {
      if (ref.read(isBetaActiveProvider)) {
        // Same ordering as `_runSequence`: merge local→cloud first so cloud
        // catchup can't wipe local rows via stale-row pulls (PR-B1 gate).
        try {
          await ref.read(betaEnterMergeServiceProvider)?.merge();
        } catch (e) {
          debugPrint('deferred beta-enter merge error: $e');
        }
        await ref.read(cloudCatchupServiceProvider).runAll();
        ref.read(personalMirrorApplierProvider);
        try {
          await ref.read(characterListProvider.notifier).pullNewerFromCloud();
        } catch (e) {
          debugPrint('deferred char pull error: $e');
        }
      }
      try {
        await ref.read(worldReconcilerProvider).reconcile();
      } catch (e) {
        debugPrint('deferred world reconcile error: $e');
      }
    } finally {
      if (mounted) {
        ref.invalidate(campaignInfoListProvider);
        ref.invalidate(campaignListProvider);
        ref.invalidate(packageListProvider);
        try {
          await ref.read(characterListProvider.notifier).refresh();
        } catch (e) {
          debugPrint('deferred char list refresh error: $e');
        }
      }
    }
  }

  void _setMessage(String m) {
    if (mounted) setState(() => _message = m);
  }

  Future<void> _run() async {
    try {
      await _runSequence().timeout(_ceiling, onTimeout: () {
        debugPrint('StartupSyncGate: ceiling reached, opening app');
      });
    } catch (e, st) {
      debugPrint('StartupSyncGate error: $e\n$st');
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _runSequence() async {
    _setMessage('Syncing local writes...');
    await ref.read(pendingWriteBufferProvider).flush();

    // Built-in SRD pack must be present locally before world joins/CDC try
    // to link it; gate idempotent per session.
    try {
      await ref.read(srdCorePackageBootstrapProvider.future);
    } catch (e) {
      debugPrint('startup SRD pack bootstrap error: $e');
    }

    if (!SupabaseConfig.isConfigured) return;
    // Cold-start race: Supabase session restore senkron olsa da provider build
    // sırası bazen authProvider'ı henüz set etmemiş oluyor. `_ceiling` içinde
    // sinyali bekle; gelirse devam, gelmezse offline gibi davran. Reconcile
    // sonraki sign-in event'inde retry edilecek (`_StartupRetryHooks`).
    if (ref.read(authProvider) == null) {
      try {
        await ref
            .read(authProvider.notifier)
            .stream
            .firstWhere((s) => s != null)
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        // timeout veya provider tear-down — sessiz; retry hook devreye girer.
      }
      if (ref.read(authProvider) == null) {
        debugPrint(
            'StartupSyncGate: auth still null after wait — skipping catchup, '
            'will retry on next sign-in event');
        return;
      }
    }

    if (ref.read(isBetaActiveProvider)) {
      // First-time beta enter: push local-owned content to cloud BEFORE any
      // cloud→local applier runs. The PR-B1 wipe guard skips destructive pulls
      // until the sentinel is set, so this must complete before the catchup +
      // reconcile + bootstrap pipeline below to actually transfer the data
      // forward.
      _setMessage('Securing your local data...');
      try {
        await ref.read(betaEnterMergeServiceProvider)?.merge();
      } catch (e) {
        debugPrint('startup beta-enter merge error: $e');
      }
      _setMessage('Syncing packages and characters...');
      try {
        await ref.read(cloudCatchupServiceProvider).runAll();
      } catch (e) {
        debugPrint('startup cloud catchup error: $e');
      }
      // Personal applier provider'ı warm up — service.start(uid) +
      // bootstrap() yan etkisi (paket + worldless char row pull) tetiklenir.
      ref.read(personalMirrorApplierProvider);
      try {
        await ref
            .read(characterListProvider.notifier)
            .pullNewerFromCloud();
      } catch (e) {
        debugPrint('startup char pull error: $e');
      }
      // Worlds list pull — `cloudCatchupService` paket + char çekiyor,
      // worlds için ayrı reconciler var. App startup'ta çağırılmadığı
      // sürece hub Worlds tab'ı yeni cihaz / sign-out+in sonrası boş
      // geliyor ve manuel refresh gerekiyor. Reconcile cloud row'ları
      // yerel Drift'e yazıp `onlineWorldIdsProvider`'ı refresh ediyor.
      _setMessage('Syncing worlds...');
      try {
        await ref.read(worldReconcilerProvider).reconcile();
      } catch (e) {
        debugPrint('startup world reconcile error: $e');
      }
    }

    _setMessage('Connecting to active world...');
    try {
      await ref.read(worldMirrorApplierProvider.future);
    } catch (e) {
      debugPrint('startup world subscribe error: $e');
    }

    // Hub liste provider'ları (worlds / packages / characters) tamamen yerel
    // Drift'i okuyor. Yukarıdaki pull'lar Drift'i populate ettiyse de eğer
    // bu provider'lar startup splash sırasında çözüldüyse stale snapshot
    // tutarlar. Splash kapanmadan invalidate edelim ki hub açılışında
    // taze veri okunsun.
    if (mounted) {
      ref.invalidate(campaignInfoListProvider);
      ref.invalidate(campaignListProvider);
      ref.invalidate(packageListProvider);
      // characterListProvider StateNotifier — refresh() metoduyla _load yenile.
      try {
        await ref.read(characterListProvider.notifier).refresh();
      } catch (e) {
        debugPrint('startup char list refresh error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Auth `null → non-null` transition'unda bir kez catchup+reconcile fire et.
    // Initial `_runSequence` auth henüz null iken çıktıysa veya kullanıcı
    // landing → sign-in → hub akışında geldiyse, manuel "Refresh" gerek
    // kalmadan worlds listesinin dolması için.
    ref.listen<AuthState?>(authProvider, (prev, next) {
      if (prev == null && next != null) {
        unawaited(_runDeferredCatchup());
      }
    });
    if (_ready) return widget.child;

    const bg = Color(0xFF1A1814);
    const gold = Color(0xFFC8A24B);
    return Material(
      color: bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIconImage(size: 160),
            const SizedBox(height: 24),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(gold),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
