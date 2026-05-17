-- ============================================================================
-- wipe_user_cloud.sql
--   Purge ALL cloud records for a single user. Run from Supabase SQL editor.
--   Idempotent. Safe to run repeatedly.
--
-- WARNING: destructive. After this, the user's worlds (cascaded
-- world_characters/members/invites/packages/entities/...), cloud_backups
-- metadata, community_assets metadata, beta_participants flag are gone.
-- Local data on the user's devices is NOT touched — it will re-publish on the
-- next online action.
--
-- Storage objects (campaign-backups bucket + R2 assets) are deleted at the
-- bottom via storage.objects. R2 community assets only have metadata cleared
-- here; the object files themselves live in R2 and have to be purged from
-- the R2 console separately.
-- ============================================================================

-- ── 1. SET TARGET ─────────────────────────────────────────────────────────
-- Either paste the user_id (uuid) below, OR uncomment the auth.uid() form if
-- running as the user's own session.
DO $$
DECLARE
  v_user UUID := 'PASTE-USER-UUID-HERE'::UUID;
  -- v_user UUID := auth.uid();
  v_world_count INT;
  v_backup_count INT;
  v_asset_count INT;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'v_user not set';
  END IF;

  -- ── 2. OWNED WORLDS ────────────────────────────────────────────────────
  -- FK ON DELETE CASCADE handles:
  --   world_members, world_invites, world_entities, world_mind_map_nodes,
  --   world_mind_map_edges, world_characters, entity_shares,
  --   character_claim_pool, world_packages, world_map_data, world_sessions,
  --   world_settings.
  DELETE FROM public.worlds WHERE owner_id = v_user;
  GET DIAGNOSTICS v_world_count = ROW_COUNT;

  -- ── 3. MEMBERSHIP IN OTHER USERS' WORLDS ──────────────────────────────
  -- The user joined someone else's online world. Drop just their membership
  -- (and any chars they owned in those worlds).
  DELETE FROM public.world_characters WHERE owner_id = v_user;
  DELETE FROM public.world_members    WHERE user_id  = v_user;

  -- ── 4. CLOUD BACKUPS METADATA ─────────────────────────────────────────
  DELETE FROM public.cloud_backups WHERE user_id = v_user;
  GET DIAGNOSTICS v_backup_count = ROW_COUNT;

  -- ── 5. COMMUNITY ASSET METADATA ───────────────────────────────────────
  DELETE FROM public.community_assets WHERE uploader_id = v_user;
  GET DIAGNOSTICS v_asset_count = ROW_COUNT;

  -- ── 6. MARKETPLACE LISTINGS + SOCIAL ──────────────────────────────────
  -- Leave posts/messages/conversations alone unless you want a full account
  -- wipe — uncomment to nuke them too.
  -- DELETE FROM public.marketplace_listings WHERE seller_id = v_user;
  -- DELETE FROM public.posts                 WHERE author_id = v_user;
  -- DELETE FROM public.messages              WHERE sender_id = v_user;

  -- ── 7. BETA STATUS ────────────────────────────────────────────────────
  -- Keep the user beta-active so they can publish again immediately.
  -- Uncomment to force-eject from beta.
  -- DELETE FROM public.beta_participants WHERE user_id = v_user;

  RAISE NOTICE 'wipe_user_cloud: worlds=%, cloud_backups=%, community_assets=%',
    v_world_count, v_backup_count, v_asset_count;
END $$;

-- ── 8. STORAGE OBJECTS (campaign-backups bucket) ─────────────────────────
-- Supabase blocks direct DELETE on storage.objects (storage.protect_delete
-- trigger). Use one of:
--   1) Dashboard → Storage → campaign-backups → delete '{user_id}/' folder
--   2) supabase/scripts/wipe_storage.sh <USER_UUID>  (Storage REST API)
--   3) Service-role curl loop on /storage/v1/object/{bucket}/{path}
-- Path layout: '{user_id}/{type}s/{item_id}.json.gz'
