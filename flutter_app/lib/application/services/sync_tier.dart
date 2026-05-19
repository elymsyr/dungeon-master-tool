/// Sync tier classification.
///
/// `fast`: realtime row-level mirror (world entities, characters in world,
/// world settings/map/sessions, world_packages). Local debounce = base
/// WriteKind window; cloud push runs on the next outbox drain (~150ms).
///
/// `slow`: cloud-save only, no realtime CDC subscribe (personal packages +
/// entities, worldless characters via cloud_backups). Local debounce = 2×
/// WriteKind window; cloud push delayed 30s so rapid edits batch before
/// hitting the network.
enum SyncTier { fast, slow }

extension SyncTierWindows on SyncTier {
  double get debounceMultiplier => switch (this) {
        SyncTier.fast => 1.0,
        SyncTier.slow => 2.0,
      };

  Duration get cloudDelay => switch (this) {
        SyncTier.fast => Duration.zero,
        SyncTier.slow => const Duration(seconds: 30),
      };
}
