-- 052: entity_shares REPLICA IDENTITY FULL — un-share DELETE CDC fix.
--
-- Why:
--   Realtime CDC DELETE payloads only carry PK columns under the default
--   REPLICA IDENTITY. entity_shares PK is `id` only, but the realtime
--   subscription filters this table by `world_id` (world_sync_service
--   _mirrorTables). On un-share (DELETE) the `oldRecord` lacks `world_id`,
--   so the realtime filter never matches and the DELETE event is silently
--   dropped — the un-share never reaches the player client.
--
--   INSERT payloads carry the full new row, so initial share delivery
--   works without this. This is the same bug migration 051 fixed for
--   world_members.
--
-- No data change; ALTER TABLE ... REPLICA IDENTITY is metadata-only.

ALTER TABLE public.entity_shares REPLICA IDENTITY FULL;
