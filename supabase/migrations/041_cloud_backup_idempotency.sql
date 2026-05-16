-- 041_cloud_backup_idempotency.sql
-- PR-SYNC-2: payload_hash idempotency for cloud_backups.
-- SyncEngine SHA-256s the (uncompressed) backup envelope and skips upload
-- when the same hash is already on the matching (user_id, item_id, type) row.

ALTER TABLE public.cloud_backups
  ADD COLUMN IF NOT EXISTS payload_hash TEXT;

CREATE INDEX IF NOT EXISTS idx_cloud_backups_item_hash
  ON public.cloud_backups (user_id, item_id, type, payload_hash);
