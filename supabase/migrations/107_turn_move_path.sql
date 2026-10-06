-- ============================================================================
-- 107 — Oyuncu hareketinin yolu (iz) ve adım türü
-- ============================================================================
-- 105'te move_turn_token yalnız son pozisyonu yazıyordu. Oyuncunun istemcisi
-- RPC'leri tek uçuşta ve en az 100 ms arayla gönderiyor; hızlı çizilen bir
-- daire DM'e 3-5 köşe olarak varıyor, DM'in izi üçgene dönüyordu. Geri al da
-- sıradan bir hareket gibi gidiyor, iz başlangıca dönen bir çizgi oluyordu.
--
--   p_path — son çağrıdan bu yana yürünen ara noktalar, düz
--            [x0, y0, x1, y1, ...] (x, y'den önce). DM izi bunlarla uzatır.
--   p_kind — 0 = sürükleme devam ediyor, 1 = yeni sürükleme (DM'de yeni geri
--            al durağı), 2 = geri al (DM son durağı siler).
--
-- İkisi de DEFAULT'lu: eski istemcinin 4 parametreli çağrısı aynen çalışır.
-- Eski imza düşürülür; aynı adla 4 ve 6 parametreli iki fonksiyon PostgREST'te
-- 4 argümanlı çağrıyı belirsiz yapardı.
--
-- Satırda yeni olan her şey (yol) zaten yayına giren pozisyonlardan biri;
-- okuma kuralı 105'teki gibi DM + sahip.
--
-- İdempotent.
-- ============================================================================

ALTER TABLE public.world_turn_control
  ADD COLUMN IF NOT EXISTS path JSONB,
  ADD COLUMN IF NOT EXISTS kind SMALLINT NOT NULL DEFAULT 0;

DROP FUNCTION IF EXISTS public.move_turn_token(TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION);

CREATE OR REPLACE FUNCTION public.move_turn_token(
  p_world_id     TEXT,
  p_combatant_id TEXT,
  p_x            DOUBLE PRECISION,
  p_y            DOUBLE PRECISION,
  p_path         DOUBLE PRECISION[] DEFAULT NULL,
  p_kind         SMALLINT DEFAULT 0
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  -- BETWEEN NaN/Infinity'yi de reddeder (Postgres'te NaN her sayıdan büyük).
  IF p_x IS NULL OR p_y IS NULL
     OR NOT (p_x BETWEEN -1e6 AND 1e6)
     OR NOT (p_y BETWEEN -1e6 AND 1e6) THEN
    RAISE EXCEPTION 'invalid token position' USING ERRCODE = '22023';
  END IF;
  IF p_kind IS NULL OR p_kind NOT IN (0, 1, 2) THEN
    RAISE EXCEPTION 'invalid move kind' USING ERRCODE = '22023';
  END IF;
  -- Tek boyutlu, çift sayıda (x/y çiftleri), en fazla 400 nokta, her değer
  -- sonlu ve sınır içinde.
  IF p_path IS NOT NULL AND (
       array_ndims(p_path) > 1
       OR coalesce(array_length(p_path, 1), 0) % 2 <> 0
       OR coalesce(array_length(p_path, 1), 0) > 800
       OR EXISTS (
         SELECT 1 FROM unnest(p_path) v
         WHERE v IS NULL OR NOT (v BETWEEN -1e6 AND 1e6)
       )
     ) THEN
    RAISE EXCEPTION 'invalid token path' USING ERRCODE = '22023';
  END IF;

  UPDATE public.world_turn_control
     SET x = p_x,
         y = p_y,
         path = CASE WHEN coalesce(array_length(p_path, 1), 0) = 0 THEN NULL
                     ELSE to_jsonb(p_path) END,
         kind = p_kind,
         moved_at = now()
   WHERE world_id = p_world_id
     AND combatant_id = p_combatant_id
     AND owner_id = auth.uid()
     AND public.is_world_member(p_world_id);
  RETURN FOUND;
END $$;

REVOKE ALL ON FUNCTION public.move_turn_token(TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION[], SMALLINT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.move_turn_token(TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION[], SMALLINT)
  TO authenticated;

COMMENT ON FUNCTION public.move_turn_token(TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION[], SMALLINT) IS
  'Oyuncunun kendi turunda token pozisyonu yazdığı TEK kapı. p_path: son '
  'çağrıdan beri yürünen ara noktalar (düz x/y), p_kind: 0 devam, 1 yeni '
  'sürükleme, 2 geri al. Satır çağıranın değilse ya da sıra geçmişse FALSE '
  'döner, hiçbir şey yazmaz.';

NOTIFY pgrst, 'reload schema';
