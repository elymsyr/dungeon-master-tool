-- ============================================================================
-- wipe_all_cloud.sql
--   FULL cloud reset. Wipes every user's published worlds, shared cards,
--   asset metadata, and (optionally) marketplace + social activity. Auth users
--   themselves are NOT deleted — they keep their accounts and can re-publish.
--
--   NOT: bulut sync kaldırıldı (migration 077). Kullanıcıların dünyaları,
--   karakterleri ve paketleri KENDİ CİHAZLARINDA duruyor; burada silinen tek
--   şey online oturumun sunucu tarafı.
--
-- USE ONLY ON DEV/STAGING. Production data is unrecoverable after this.
-- Run as service_role / postgres role. Wrap in BEGIN/ROLLBACK first to dry-run.
-- ============================================================================

BEGIN;

-- ── 1. WORLDS — cascade kills world_members/invites/characters/packages,
--      entity_shares (paylaşılan kart gövdeleri dahil) ve world_projection ──
TRUNCATE TABLE public.worlds CASCADE;

-- ── 2. COMMUNITY ASSETS METADATA ────────────────────────────────────────
TRUNCATE TABLE public.community_assets CASCADE;

-- ── 3. MARKETPLACE + SOCIAL (uncomment as needed) ───────────────────────
-- TRUNCATE TABLE public.marketplace_listings CASCADE;
-- TRUNCATE TABLE public.posts                CASCADE;
-- TRUNCATE TABLE public.messages             CASCADE;
-- TRUNCATE TABLE public.conversations        CASCADE;

-- ── 4. PROFILES (uncomment for full reset) ──────────────────────────────
-- TRUNCATE TABLE public.profiles CASCADE;

-- ── 5. STORAGE OBJECTS ──────────────────────────────────────────────────
-- Supabase blocks direct DELETE on storage.objects (storage.protect_delete
-- trigger). After this SQL commits, empty the buckets via:
--   1) Dashboard → Storage → shared-payloads / free-media → select all → delete
--   2) supabase/scripts/wipe_storage.sh   (Storage REST API, all users)
-- R2 tarafı ayrı: worker'ın /admin/purge-all ucu.

-- Verify counts before commit. If anything looks wrong → ROLLBACK.
SELECT
  (SELECT COUNT(*) FROM public.worlds)            AS worlds,
  (SELECT COUNT(*) FROM public.entity_shares)     AS entity_shares,
  (SELECT COUNT(*) FROM public.community_assets)  AS community_assets;

COMMIT;
-- ROLLBACK;  -- uncomment + comment COMMIT to dry-run
