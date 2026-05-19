import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/auth_provider.dart';
import '../../../application/providers/beta_provider.dart';
import '../../../application/providers/character_provider.dart';
import '../../../application/providers/personal_sync_provider.dart';
import '../../../application/providers/world_mirror_provider.dart';
import '../../../application/services/cloud_catchup_service.dart';
import '../../../application/services/pending_write_buffer.dart';
import '../../../core/config/supabase_config.dart';

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
    }

    _setMessage('Connecting to active world...');
    try {
      await ref.read(worldMirrorApplierProvider.future);
    } catch (e) {
      debugPrint('startup world subscribe error: $e');
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
            Image.asset(
              'assets/app_icon_transparent.png',
              width: 160,
              height: 160,
              filterQuality: FilterQuality.medium,
            ),
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
