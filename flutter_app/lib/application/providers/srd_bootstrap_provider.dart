import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database_provider.dart';
import '../dnd5e/bootstrap/srd_bootstrap_service.dart';
import 'custom_effect_registry_provider.dart';

/// User-scoped [SrdBootstrapService] — rebuilds when [appDatabaseProvider]
/// rebuilds (i.e. the active user changes), so each user gets the SRD
/// content imported into *their* DB exactly once. Idempotency inside the
/// service still gates re-runs by version; this provider only ensures the
/// service is bound to the right `AppDatabase` for the right user.
final srdBootstrapServiceProvider = Provider<SrdBootstrapService>((ref) {
  return SrdBootstrapService(
    db: ref.watch(appDatabaseProvider),
    registry: ref.watch(customEffectRegistryProvider),
  );
});

/// Latest [SrdBootstrapOutcome] for the active user, or `null` before the
/// bootstrap has been run for this session.
///
/// Surfacing as a `StateProvider` (rather than firing a one-shot snackbar
/// inline) lets multiple UI surfaces (settings page, debug screen, optional
/// upgrade banner) observe the same outcome without coupling to the
/// trigger site. UI listening is wired in [DungeonMasterApp] via a
/// `ProviderScope` listener; tests can read the value directly.
final srdBootstrapOutcomeProvider =
    StateProvider<SrdBootstrapOutcome?>((ref) => null);

/// Triggers the SRD bootstrap for the currently active user. Stores the
/// outcome in [srdBootstrapOutcomeProvider] and returns the same value so
/// callers can `await` and react.
///
/// Safe to call repeatedly: [SrdBootstrapService.runIfNeeded] short-circuits
/// when the bundled monolith's version matches the version flag stamped in
/// `shared_preferences`. Errors are returned (not thrown) per
/// [SrdBootstrapError]; the caller does not need a try/catch.
Future<SrdBootstrapOutcome> runSrdBootstrap(Ref ref) async {
  final service = ref.read(srdBootstrapServiceProvider);
  final outcome = await service.runIfNeeded();
  ref.read(srdBootstrapOutcomeProvider.notifier).state = outcome;
  return outcome;
}
