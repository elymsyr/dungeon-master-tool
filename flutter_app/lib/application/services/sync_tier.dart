/// Sync tier classification.
///
/// `fast`: realtime row-level mirror (world entities, characters in world,
/// world settings/map/sessions, world_packages). Cloud push runs on the next
/// outbox drain (~150ms after tick bump).
///
/// `slow`: cloud-save only, no realtime CDC subscribe (personal packages +
/// entities, worldless characters via cloud_backups). Cloud push delayed
/// by [cloudDelay] so rapid edits batch before hitting the network.
///
/// Local debounce window is determined solely by `WriteKind.window` — tier
/// no longer multiplies the local debounce (previous multiplier was dead
/// code: no caller passed `tier:` to `PendingWriteBuffer.schedule`).
enum SyncTier { fast, slow }

extension SyncTierWindows on SyncTier {
  Duration get cloudDelay => switch (this) {
        SyncTier.fast => Duration.zero,
        SyncTier.slow => const Duration(seconds: 10),
      };
}
