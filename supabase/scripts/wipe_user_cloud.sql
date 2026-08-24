-- ============================================================================
-- wipe_user_cloud.sql
--   Purge ALL cloud records for a single user. Run from Supabase SQL editor.
--   Idempotent. Safe to run repeatedly.
--
-- WARNING: destructive. After this, the user's published worlds (cascaded
-- world_characters/members/invites/packages, entity_shares, world_projection)
-- and community_assets metadata are gone.
-- Local data on the user's devices is NOT touched — bulut sync kaldırıldı
-- (migration 077), dünyalar ve karakterler zaten yerelde yaşıyor.
--
-- R2 objects are NOT deleted here — use the worker's /admin/purge-user
-- endpoint. Supabase Storage (shared-payloads / free-media) see the bottom.
-- ============================================================================

-- ── 1. SET TARGET ─────────────────────────────────────────────────────────
-- Either paste the user_id (uuid) below, OR uncomment the auth.uid() form if
-- running as the user's own session.
DO $$
DECLARE
  v_user UUID := 'PASTE-USER-UUID-HERE'::UUID;
  -- v_user UUID := auth.uid();
  v_world_count INT;
  v_asset_count INT;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'v_user not set';
  END IF;

  -- ── 2. OWNED WORLDS ────────────────────────────────────────────────────
  -- FK ON DELETE CASCADE handles:
  --   world_members, world_invites, world_characters, entity_shares,
  --   character_claim_pool, world_packages, world_projection.
  DELETE FROM public.worlds WHERE owner_id = v_user;
  GET DIAGNOSTICS v_world_count = ROW_COUNT;

  -- ── 3. MEMBERSHIP IN OTHER USERS' WORLDS ──────────────────────────────
  -- The user joined someone else's online world. Drop just their membership
  -- (and any chars they owned in those worlds).
  DELETE FROM public.world_characters WHERE owner_id = v_user;
  DELETE FROM public.world_members    WHERE user_id  = v_user;

  -- ── 4. COMMUNITY ASSET METADATA ───────────────────────────────────────
  DELETE FROM public.community_assets WHERE uploader_id = v_user;
  GET DIAGNOSTICS v_asset_count = ROW_COUNT;

  -- ── 5. MARKETPLACE LISTINGS + SOCIAL ──────────────────────────────────
  -- Leave posts/messages/conversations alone unless you want a full account
  -- wipe — uncomment to nuke them too.
  -- DELETE FROM public.marketplace_listings WHERE seller_id = v_user;
  -- DELETE FROM public.posts                 WHERE author_id = v_user;
  -- DELETE FROM public.messages              WHERE sender_id = v_user;

  RAISE NOTICE 'wipe_user_cloud: worlds=%, community_assets=%',
    v_world_count, v_asset_count;
END $$;

-- ── 6. STORAGE OBJECTS (shared-payloads / free-media) ────────────────────
-- Supabase blocks direct DELETE on storage.objects (storage.protect_delete
-- trigger). Use one of:
--   1) Dashboard → Storage → <bucket> → delete '{user_id}/' folder
--   2) supabase/scripts/wipe_storage.sh <USER_UUID>  (Storage REST API)
--   3) Service-role curl loop on /storage/v1/object/{bucket}/{path}
-- shared-payloads layout: '{user_id}/listings/{listing_id}.json.gz'
-- R2 objects: worker POST /admin/purge-user with Bearer ADMIN_TOKEN.
