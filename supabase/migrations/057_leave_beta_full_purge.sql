-- ============================================================================
-- 057_leave_beta_full_purge.sql
--   • leave_beta(): extend the purge to ALL of the user's online content —
--     orphan online characters, personal packages, marketplace listings,
--     free-media image metadata, transient shares. Worlds / cloud_backups /
--     community_assets / beta_participants were already covered (044).
--   • Lock the now-purged feature surfaces behind beta membership ("kilitle"):
--     publish_listing_snapshot, publish_personal_package(_entity) RPCs gated;
--     RLS INSERT hardened on marketplace_listings, personal_packages,
--     personal_package_entities and the orphan branch of world_characters.
--   • Social layer (posts, game_listings, conversations, messages, profiles,
--     follows) is DELIBERATELY untouched — the user keeps the community.
-- ============================================================================

-- ── 1. leave_beta — full online-data purge ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.leave_beta()
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RETURN FALSE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.beta_participants WHERE user_id = v_user) THEN
    RETURN FALSE;
  END IF;

  -- Owned online worlds: cascade kills world_members, world_invites,
  -- world_entities, world_mind_map_nodes/edges, world_characters (world-bound),
  -- entity_shares, world_packages, world_map_data, world_sessions,
  -- world_settings (FK ON DELETE CASCADE).
  DELETE FROM public.worlds WHERE owner_id = v_user;

  -- Orphan online personal characters (world_id IS NULL). World-bound
  -- characters the user owns inside OTHER DMs' worlds are intentionally left
  -- in place — the user keeps playing there (see migration 044).
  DELETE FROM public.world_characters
   WHERE owner_id = v_user AND world_id IS NULL;

  -- Personal package online sync (row-level entities + the package row).
  DELETE FROM public.personal_package_entities WHERE owner_id = v_user;
  DELETE FROM public.personal_packages         WHERE owner_id = v_user;

  -- Marketplace listings. The cover image is an inline base64 column, so it
  -- goes with the row; the payload objects live in the `shared-payloads`
  -- bucket and are removed client-side (RLS blocks storage.objects DELETE
  -- from plpgsql).
  DELETE FROM public.marketplace_listings WHERE owner_id = v_user;

  -- Cloud image metadata. free_media_assets = `free-media` bucket images
  -- (portraits / covers); community_assets = counted Cloudflare R2 images —
  -- the R2 binary objects are garbage-collected by the asset worker.
  -- Storage objects for the free-media / shared-payloads / campaign-backups
  -- buckets are removed client-side.
  DELETE FROM public.free_media_assets WHERE owner_id    = v_user;
  DELETE FROM public.community_assets  WHERE uploader_id = v_user;
  DELETE FROM public.transient_shares  WHERE uploader_id = v_user;
  DELETE FROM public.cloud_backups     WHERE user_id     = v_user;

  -- NOT deleted (deliberately): posts, post_likes, game_listings,
  -- game_listing_applications, conversations, conversation_members, messages,
  -- profiles, follows. The social layer survives leaving the beta.

  DELETE FROM public.beta_participants WHERE user_id = v_user;

  RETURN TRUE;
END $$;

GRANT EXECUTE ON FUNCTION public.leave_beta() TO authenticated;

-- ── 2. publish_listing_snapshot — gate on beta membership ──────────────────
CREATE OR REPLACE FUNCTION public.publish_listing_snapshot(
  p_listing_id      UUID,
  p_item_type       TEXT,
  p_title           TEXT,
  p_description     TEXT,
  p_language        TEXT,
  p_tags            TEXT[],
  p_changelog       TEXT,
  p_content_hash    TEXT,
  p_payload_path    TEXT,
  p_size_bytes      BIGINT,
  p_cover_image_b64 TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_new_id UUID := COALESCE(p_listing_id, gen_random_uuid());
BEGIN
  IF NOT public.is_beta_active(auth.uid()) THEN
    RAISE EXCEPTION 'beta membership required to publish to the marketplace'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.marketplace_listings (
    id, owner_id, item_type, title, description, language,
    tags, changelog, content_hash, payload_path, size_bytes, cover_image_b64
  ) VALUES (
    v_new_id, auth.uid(), p_item_type, p_title, p_description, p_language,
    COALESCE(p_tags, '{}'), p_changelog, p_content_hash, p_payload_path,
    p_size_bytes, p_cover_image_b64
  );
  RETURN v_new_id;
END $$;

GRANT EXECUTE ON FUNCTION public.publish_listing_snapshot(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT[], TEXT, TEXT, TEXT, BIGINT, TEXT
) TO authenticated;

-- ── 3. publish_personal_package — gate on beta membership ──────────────────
CREATE OR REPLACE FUNCTION public.publish_personal_package(
  p_package_name TEXT,
  p_state_json TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;
  IF NOT public.is_beta_active(auth.uid()) THEN
    RAISE EXCEPTION 'beta membership required to sync personal packages online'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.personal_packages (owner_id, package_name, state_json)
  VALUES (auth.uid(), p_package_name, p_state_json)
  ON CONFLICT (owner_id, package_name) DO UPDATE
    SET state_json = EXCLUDED.state_json,
        updated_at = now();
END $$;

GRANT EXECUTE ON FUNCTION
  public.publish_personal_package(TEXT, TEXT) TO authenticated;

-- ── 4. publish_personal_package_entity — gate on beta membership ───────────
CREATE OR REPLACE FUNCTION public.publish_personal_package_entity(
  p_package_name TEXT,
  p_entity_id    TEXT,
  p_payload_json TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;
  IF NOT public.is_beta_active(auth.uid()) THEN
    RAISE EXCEPTION 'beta membership required to sync personal packages online'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.personal_package_entities
    (id, owner_id, package_name, payload_json)
  VALUES (p_entity_id, auth.uid(), p_package_name, p_payload_json)
  ON CONFLICT (owner_id, package_name, id) DO UPDATE
    SET payload_json = EXCLUDED.payload_json,
        updated_at   = now();
END $$;

GRANT EXECUTE ON FUNCTION
  public.publish_personal_package_entity(TEXT, TEXT, TEXT) TO authenticated;

-- ── 5. RLS hardening — INSERT gated on beta (defense-in-depth) ─────────────
-- Mirrors migration 044's hardening of `worlds`. The SECURITY DEFINER RPCs
-- above are the primary gate; these block direct PostgREST table writes too.

-- 5a. marketplace_listings INSERT.
DROP POLICY IF EXISTS "Owner inserts own listings" ON public.marketplace_listings;
CREATE POLICY "Owner inserts own listings"
  ON public.marketplace_listings FOR INSERT
  WITH CHECK (
    auth.uid() = owner_id
    AND public.is_beta_active(auth.uid())
  );

-- 5b. personal_packages — keep USING ownership-only (rows stay readable /
--     updatable / deletable), gate new rows via WITH CHECK.
DROP POLICY IF EXISTS "personal_packages: owner all" ON public.personal_packages;
CREATE POLICY "personal_packages: owner all" ON public.personal_packages
  FOR ALL
  USING (owner_id = auth.uid())
  WITH CHECK (
    owner_id = auth.uid()
    AND public.is_beta_active(auth.uid())
  );

-- 5c. personal_package_entities — same treatment.
DROP POLICY IF EXISTS "ppe: owner all" ON public.personal_package_entities;
CREATE POLICY "ppe: owner all" ON public.personal_package_entities
  FOR ALL
  USING (owner_id = auth.uid())
  WITH CHECK (
    owner_id = auth.uid()
    AND public.is_beta_active(auth.uid())
  );

-- 5d. world_characters INSERT — gate the ORPHAN branch (world_id IS NULL =
--     online personal character) on beta. The world-bound branch stays open
--     so non-beta users can still create / claim characters inside other
--     DMs' worlds.
DROP POLICY IF EXISTS "Chars: insert" ON public.world_characters;
CREATE POLICY "Chars: insert"
  ON public.world_characters FOR INSERT
  WITH CHECK (
    (world_id IS NULL AND owner_id = auth.uid()
     AND public.is_beta_active(auth.uid()))
    OR
    (world_id IS NOT NULL AND public.is_world_member(world_id)
     AND (owner_id = auth.uid() OR public.is_world_dm(world_id)))
  );

NOTIFY pgrst, 'reload schema';
