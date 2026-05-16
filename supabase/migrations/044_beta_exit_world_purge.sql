-- ============================================================================
-- 044_beta_exit_world_purge.sql
--   • leave_beta(): owned worlds + world_packages cascade-delete.
--   • publish_world(): only beta-active users can create/update online worlds.
--   • share_package_to_world(): only beta-active DMs can share packages.
--   • World JOIN (redeem_world_invite, claim_character) stays open — non-beta
--     users can play in someone else's online world.
--   • Characters, posts, conversations, messages, game_listings untouched.
-- ============================================================================

-- ── 1. leave_beta — extend with owned-world + package purge ────────────────
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
  -- world_entities, world_mind_map_nodes/edges, world_characters,
  -- entity_shares, character_claim_pool, world_packages, world_map_data,
  -- world_sessions, world_settings (FK ON DELETE CASCADE).
  DELETE FROM public.worlds WHERE owner_id = v_user;

  -- world_packages where shared_by = user but world owned by someone else:
  -- leave them in place — they belong to the other DM's world.

  -- Storage objects (campaign-backups bucket) are removed client-side via
  -- Storage API (RLS blocks direct DELETE on storage.objects from plpgsql).
  DELETE FROM public.cloud_backups WHERE user_id = v_user;

  DELETE FROM public.community_assets WHERE uploader_id = v_user;

  DELETE FROM public.beta_participants WHERE user_id = v_user;

  RETURN TRUE;
END $$;

GRANT EXECUTE ON FUNCTION public.leave_beta() TO authenticated;

-- ── 2. publish_world — gate creation/update on beta membership ─────────────
CREATE OR REPLACE FUNCTION public.publish_world(
  p_world_id      TEXT,
  p_world_name    TEXT,
  p_template_id   TEXT,
  p_template_hash TEXT,
  p_state_json    TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_existing_owner UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  IF NOT public.is_beta_active(auth.uid()) THEN
    RAISE EXCEPTION 'beta membership required to publish online worlds'
      USING ERRCODE = '42501';
  END IF;

  SELECT owner_id INTO v_existing_owner
  FROM public.worlds WHERE id = p_world_id;

  IF v_existing_owner IS NULL THEN
    INSERT INTO public.worlds (
      id, owner_id, world_name, template_id, template_hash, state_json
    ) VALUES (
      p_world_id, auth.uid(), p_world_name,
      p_template_id, p_template_hash, p_state_json
    );
  ELSIF v_existing_owner = auth.uid() THEN
    UPDATE public.worlds
       SET world_name    = p_world_name,
           template_id   = p_template_id,
           template_hash = p_template_hash,
           state_json    = p_state_json,
           updated_at    = now()
     WHERE id = p_world_id;
  ELSE
    RAISE EXCEPTION 'world % owned by different user (%)',
      p_world_id, v_existing_owner USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.world_members (world_id, user_id, role)
  VALUES (p_world_id, auth.uid(), 'dm')
  ON CONFLICT (world_id, user_id) DO UPDATE SET role = 'dm';
END $$;

GRANT EXECUTE ON FUNCTION
  public.publish_world(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- ── 3. share_package_to_world — gate on beta membership ────────────────────
CREATE OR REPLACE FUNCTION public.share_package_to_world(
  p_world_id     TEXT,
  p_package_name TEXT,
  p_state_json   TEXT
) RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id TEXT;
BEGIN
  IF NOT public.is_world_dm(p_world_id) THEN
    RAISE EXCEPTION 'dm only' USING ERRCODE = '42501';
  END IF;

  IF NOT public.is_beta_active(auth.uid()) THEN
    RAISE EXCEPTION 'beta membership required to share online packages'
      USING ERRCODE = '42501';
  END IF;

  SELECT package_id INTO v_id
    FROM public.world_packages
   WHERE world_id = p_world_id
     AND package_name = p_package_name;

  IF v_id IS NULL THEN
    v_id := gen_random_uuid()::TEXT;
    INSERT INTO public.world_packages
      (package_id, world_id, package_name, shared_by, state_json)
    VALUES
      (v_id, p_world_id, p_package_name, auth.uid(), p_state_json);
  ELSE
    UPDATE public.world_packages
       SET state_json = p_state_json,
           shared_by  = auth.uid(),
           updated_at = now()
     WHERE package_id = v_id;
  END IF;

  RETURN v_id;
END $$;
GRANT EXECUTE ON FUNCTION public.share_package_to_world(TEXT, TEXT, TEXT)
  TO authenticated;

-- ── 4. RLS hardening — direct INSERT/UPDATE on `worlds` must be beta-active
--     Defense-in-depth so non-beta users can't bypass publish_world via
--     PostgREST direct table writes.
DROP POLICY IF EXISTS "Worlds: owner insert" ON public.worlds;
CREATE POLICY "Worlds: owner insert"
  ON public.worlds FOR INSERT
  WITH CHECK (
    auth.uid() = owner_id
    AND public.is_beta_active(auth.uid())
  );

DROP POLICY IF EXISTS "Worlds: dm update" ON public.worlds;
CREATE POLICY "Worlds: dm update"
  ON public.worlds FOR UPDATE
  USING (
    public.is_world_dm(id)
    AND public.is_beta_active(auth.uid())
  );

NOTIFY pgrst, 'reload schema';
