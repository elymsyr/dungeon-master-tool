-- ============================================================================
-- wipe_all_cloud.sql
--   FULL cloud reset. Wipes every user's published worlds, cloud backups,
--   asset metadata, marketplace, and social activity. Auth users themselves
--   are NOT deleted — they keep their accounts and can re-publish.
--
-- USE ONLY ON DEV/STAGING. Production data is unrecoverable after this.
-- Run as service_role / postgres role. Wrap in BEGIN/ROLLBACK first to dry-run.
-- ============================================================================

BEGIN;

-- ── 1. WORLDS — cascade kills every world_* subtable + entity_shares ─────
TRUNCATE TABLE public.worlds CASCADE;

-- ── 2. CLOUD BACKUPS METADATA ───────────────────────────────────────────
TRUNCATE TABLE public.cloud_backups;

-- ── 3. COMMUNITY ASSETS METADATA ────────────────────────────────────────
TRUNCATE TABLE public.community_assets CASCADE;

-- ── 4. MARKETPLACE + SOCIAL (uncomment as needed) ───────────────────────
-- TRUNCATE TABLE public.marketplace_listings CASCADE;
-- TRUNCATE TABLE public.posts                CASCADE;
-- TRUNCATE TABLE public.messages             CASCADE;
-- TRUNCATE TABLE public.conversations        CASCADE;

-- ── 5. BETA + PROFILES (uncomment for full reset) ───────────────────────
-- TRUNCATE TABLE public.beta_participants;
-- TRUNCATE TABLE public.profiles CASCADE;

-- ── 6. STORAGE OBJECTS ──────────────────────────────────────────────────
-- Supabase blocks direct DELETE on storage.objects (storage.protect_delete
-- trigger). After this SQL commits, empty the bucket via:
--   1) Dashboard → Storage → campaign-backups → select all → delete
--   2) supabase/scripts/wipe_storage.sh   (Storage REST API, all users)

-- Verify counts before commit. If anything looks wrong → ROLLBACK.
SELECT
  (SELECT COUNT(*) FROM public.worlds)            AS worlds,
  (SELECT COUNT(*) FROM public.cloud_backups)     AS cloud_backups,
  (SELECT COUNT(*) FROM public.community_assets)  AS community_assets,
  (SELECT COUNT(*) FROM storage.objects
    WHERE bucket_id = 'campaign-backups')         AS storage_objects_remaining;

COMMIT;
-- ROLLBACK;  -- uncomment + comment COMMIT to dry-run
