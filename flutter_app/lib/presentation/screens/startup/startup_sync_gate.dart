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

  @override
  void initState() {
    super.initState();
    _run();
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
    if (ref.read(authProvider) == null) return;

    if (ref.read(isBetaActiveProvider)) {
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
