-- ============================================================================
-- 037_fix_claim_release_ambig.sql — qualify column refs in claim/release RPCs
-- ============================================================================
-- `claim_character` (034) ve `release_character` (036) RPC'leri RETURNS TABLE
-- ile (character_id, world_id) OUT param tanımlıyor. Function body içindeki
-- UPDATE ... WHERE character_id = p_character_id ifadelerinde Postgres
-- column ref'i hangisi belirsiz kaldı:
--   * OUT param `character_id`
--   * `character_claim_pool.character_id`
-- → "column reference character_id is ambiguous" (42702).
--
-- Çözüm: pool UPDATE'lerini tablo adıyla nitele. SELECT/UPDATE
-- world_characters tarafları zaten `wc.` alias ile güvende.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.claim_character(p_character_id TEXT)
RETURNS TABLE (character_id TEXT, world_id TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_world_id TEXT;
  v_owner    UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required';
  END IF;

  SELECT wc.world_id, wc.owner_id
    INTO v_world_id, v_owner
    FROM public.world_characters wc
   WHERE wc.id = p_character_id
   FOR UPDATE;

  IF v_world_id IS NULL THEN
    RAISE EXCEPTION 'character not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_owner IS NOT NULL THEN
    RAISE EXCEPTION 'character already claimed' USING ERRCODE = 'P0003';
  END IF;

  IF NOT public.is_world_member(v_world_id) THEN
    RAISE EXCEPTION 'not a world member' USING ERRCODE = '42501';
  END IF;

  UPDATE public.world_characters
     SET owner_id   = auth.uid(),
         updated_at = now()
   WHERE id = p_character_id;

  UPDATE public.character_claim_pool
     SET available  = false,
         claimed_by = auth.uid(),
         claimed_at = now()
   WHERE character_claim_pool.character_id = p_character_id;

  RETURN QUERY SELECT p_character_id, v_world_id;
END $$;

ALTER FUNCTION public.claim_character(TEXT) SET row_security = off;

CREATE OR REPLACE FUNCTION public.release_character(p_character_id TEXT)
RETURNS TABLE (character_id TEXT, world_id TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_world_id TEXT;
  v_owner    UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required';
  END IF;

  SELECT wc.world_id, wc.owner_id
    INTO v_world_id, v_owner
    FROM public.world_characters wc
   WHERE wc.id = p_character_id
   FOR UPDATE;

  IF v_world_id IS NULL THEN
    RAISE EXCEPTION 'character not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_owner IS NULL THEN
    RETURN QUERY SELECT p_character_id, v_world_id;
    RETURN;
  END IF;

  IF v_owner <> auth.uid() THEN
    RAISE EXCEPTION 'not the owner' USING ERRCODE = '42501';
  END IF;

  UPDATE public.world_characters
     SET owner_id   = NULL,
         updated_at = now()
   WHERE id = p_character_id;

  UPDATE public.character_claim_pool
     SET available  = true,
         claimed_by = NULL,
         claimed_at = NULL
   WHERE character_claim_pool.character_id = p_character_id;

  RETURN QUERY SELECT p_character_id, v_world_id;
END $$;

ALTER FUNCTION public.release_character(TEXT) SET row_security = off;

NOTIFY pgrst, 'reload schema';
