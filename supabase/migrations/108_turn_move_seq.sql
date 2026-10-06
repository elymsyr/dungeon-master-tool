-- ============================================================================
-- 108 — Oyuncu hareketinin sıra numarası (DM onayı)
-- ============================================================================
-- Oyuncu hareketini kendi ekranında hemen gösterir, DM'in yayını gecikmeli
-- gelir. 107'ye kadar oyuncu yerel hâlini yayın "yetişti" gibi görünene ya
-- da 2 sn dolana kadar tutuyordu; bu arada DM'in yaptığı geri al oyuncuda
-- görünmüyor, iki taraf karışabiliyordu.
--
--   p_seq — oyuncunun bu çağrıya verdiği artan numara. DM hareketi
--           uyguladıktan sonra yayında (BattleMapSnapshot.moveAck) son
--           uyguladığı numarayı geri bildirir; oyuncu o numaraya kadar olan
--           her şeyi onaylanmış sayar, yerel hâli bırakıp DM'in durumunu
--           (geri almalar dahil) gösterir.
--
-- DEFAULT'lu: 105/107 istemcilerinin çağrıları aynen çalışır. 107'nin
-- 6 parametreli imzası düşürülür (aşırı yükleme belirsizlik yaratırdı).
-- 107 uygulanmamışsa onun sütunları da burada eklenir.
--
-- İdempotent.
-- ============================================================================

ALTER TABLE public.world_turn_control
  ADD COLUMN IF NOT EXISTS path JSONB,
  ADD COLUMN IF NOT EXISTS kind SMALLINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS seq  BIGINT;

DROP FUNCTION IF EXISTS public.move_turn_token(TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION);
DROP FUNCTION IF EXISTS public.move_turn_token(TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION[], SMALLINT);

CREATE OR REPLACE FUNCTION public.move_turn_token(
  p_world_id     TEXT,
  p_combatant_id TEXT,
  p_x            DOUBLE PRECISION,
  p_y            DOUBLE PRECISION,
  p_path         DOUBLE PRECISION[] DEFAULT NULL,
  p_kind         SMALLINT DEFAULT 0,
  p_seq          BIGINT DEFAULT NULL
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
  IF p_seq IS NOT NULL AND p_seq < 0 THEN
    RAISE EXCEPTION 'invalid move seq' USING ERRCODE = '22023';
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
         seq = p_seq,
         moved_at = now()
   WHERE world_id = p_world_id
     AND combatant_id = p_combatant_id
     AND owner_id = auth.uid()
     AND public.is_world_member(p_world_id);
  RETURN FOUND;
END $$;

REVOKE ALL ON FUNCTION public.move_turn_token(TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION[], SMALLINT, BIGINT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.move_turn_token(TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION[], SMALLINT, BIGINT)
  TO authenticated;

COMMENT ON FUNCTION public.move_turn_token(TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION[], SMALLINT, BIGINT) IS
  'Oyuncunun kendi turunda token pozisyonu yazdığı TEK kapı. p_path: son '
  'çağrıdan beri yürünen ara noktalar (düz x/y), p_kind: 0 devam, 1 yeni '
  'sürükleme, 2 geri al, p_seq: DM''in yayında onayladığı artan numara. '
  'Satır çağıranın değilse ya da sıra geçmişse FALSE döner, hiçbir şey yazmaz.';

NOTIFY pgrst, 'reload schema';
