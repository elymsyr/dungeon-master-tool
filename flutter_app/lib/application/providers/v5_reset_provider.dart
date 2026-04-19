import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/storage/v5_reset_bootstrap.dart';

/// Latest [V5ResetOutcome] from the boot-time `V5ResetBootstrap.runIfNeeded`
/// call, or `null` before the first launch's purger has run.
///
/// Seeded via `ProviderScope` override at [`DungeonMasterApp`] construction
/// time so listeners can decide whether to show the one-time
/// [V5UpgradeNoticeDialog]. Surfaces the outcome rather than firing the
/// dialog inline so test code can read the value directly without a UI
/// pump.
final v5ResetOutcomeProvider = StateProvider<V5ResetOutcome?>((ref) => null);
