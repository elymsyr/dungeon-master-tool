-- 051: Set REPLICA IDENTITY FULL on world_members.
--
-- Why:
--   Realtime CDC payloads for UPDATE/DELETE only carry PK columns under
--   the default REPLICA IDENTITY. world_members PK is (world_id, user_id)
--   — so role changes (UPDATE) and member removals (DELETE) reach the
--   DM client with truncated `oldRecord`/`newRecord` payloads, making
--   downstream role/profile reconciliation harder.
--
-- INSERT payloads already carry the full new row, so the current "player
-- join → DM sees member" path works without this. This migration is a
-- forward-looking fix for kick/role-change CDC reliability and matches
-- the pattern used elsewhere in the schema (entity_shares etc.).
--
-- No data change; ALTER TABLE ... REPLICA IDENTITY is metadata-only.

ALTER TABLE public.world_members REPLICA IDENTITY FULL;
