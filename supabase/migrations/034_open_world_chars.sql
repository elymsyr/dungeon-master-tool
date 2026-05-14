-- ============================================================================
-- 034_open_world_chars.sql — DMT Online Multiplayer
-- ============================================================================
-- Bu migration karakterleri "tüm üyeler okuyabilir, owner_id null olanları
-- claim edilebilir" modeline geçirir.
--
-- Önceki davranış (026):
--   * Player sadece `owner_id = auth.uid()` olan karakterleri görüyordu →
--     DM karakterleri ve diğer oyuncuların karakterleri SELECT ile gizli.
--   * Claim akışı `character_claim_pool` tablosu üzerinden yürüyordu → DM'in
--     "Make available for claim" ile pool satırı oluşturması gerekiyordu.
--
-- Bu migration:
--   1. SELECT policy'sini "members read all" olarak değiştirir.
--   2. `claim_character` RPC'sini pool tablosundan bağımsız hale getirir
--      (kanon: `world_characters.owner_id IS NULL` = claim edilebilir).
--   3. Geri uyumluluk için pool tablosunu, eski clients (henüz update
--      olmamış) için en iyi çabayla senkronize tutar. Tablo bir sonraki
--      release'de drop edilecek.
-- ============================================================================

-- ── BÖLÜM A — RLS: tüm üyeler tüm karakterleri okuyabilir ────────────────

DROP POLICY IF EXISTS "Chars: player reads own" ON public.world_characters;

DROP POLICY IF EXISTS "Chars: members read all" ON public.world_characters;
CREATE POLICY "Chars: members read all"
  ON public.world_characters FOR SELECT
  USING (public.is_world_member(world_id));

-- INSERT/UPDATE policy'leri değişmedi: player sadece kendi owner_id'sini
-- yazabilir, DM her şeyi yazabilir.

-- ── BÖLÜM B — claim_character RPC: pool-free ─────────────────────────────

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

  -- Pool tablosunu best-effort senkronla (eski client'lar pool'a bakıyor
  -- olabilir). Tablo silindiğinde bu satır no-op olur — şu an FK
  -- sebebiyle güvenli.
  UPDATE public.character_claim_pool
     SET available  = false,
         claimed_by = auth.uid(),
         claimed_at = now()
   WHERE character_id = p_character_id;

  RETURN QUERY SELECT p_character_id, v_world_id;
END $$;

ALTER FUNCTION public.claim_character(TEXT) SET row_security = off;

-- ── BÖLÜM C — PostgREST schema cache reload ──────────────────────────────
NOTIFY pgrst, 'reload schema';
