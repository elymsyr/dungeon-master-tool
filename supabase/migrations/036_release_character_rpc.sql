-- ============================================================================
-- 036_release_character_rpc.sql — symmetric inverse of claim_character
-- ============================================================================
-- Player kendi sahip olduğu karakteri dünyada bırakabilmeli — claim'in tam
-- tersi. Atomic: owner_id'yi NULL'a çeker, updated_at bump'lar, pool
-- tablosunu (deprecated ama hâlâ FK-safe) best-effort senkronlar.
--
-- Auth gate + ownership check zorunlu: yalnız mevcut owner release edebilir.
-- DM zaten `assignToPlayer(owner_id = NULL)` ile aynı sonucu alabilir → bu
-- RPC sadece player flow için.
-- ============================================================================

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
    -- Zaten serbest; idempotent davran.
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

  -- Pool tablosunu best-effort senkronla (eski client'lar). Tablo
  -- drop edildiğinde bu UPDATE no-op olur.
  UPDATE public.character_claim_pool
     SET available  = true,
         claimed_by = NULL,
         claimed_at = NULL
   WHERE character_id = p_character_id;

  RETURN QUERY SELECT p_character_id, v_world_id;
END $$;

ALTER FUNCTION public.release_character(TEXT) SET row_security = off;

NOTIFY pgrst, 'reload schema';
