-- ============================================================================
-- 106 — Oyuncuların zar atışları DM'in oturum günlüğüne
-- ============================================================================
-- Oyuncu zar attığında (serbest zar, skill check, saving throw) sonuç DM'in
-- session log'una düşer. DM kendi atışlarını yerelde yazar; buradan geçen
-- yalnız oyuncununki.
--
--   Oyuncu → log_dice_roll(world, karakter, tür, etiket, toplam, döküm) —
--            satırın sahibi sunucuda auth.uid(); başkası adına yazılamaz.
--   DM     ← INSERT CDC → kullanıcı adını üye listesinden çözer, günlüğe
--            yazar.
--
-- Satır yalnız bir taşıma kaydı: DM okur, oyuncu kendi satırını bile
-- görmez. Her yazma o dünyanın 1 saatten eski satırlarını siler.
--
-- İdempotent.
-- ============================================================================

-- ── A — Tablo ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.world_dice_rolls (
  id         BIGSERIAL PRIMARY KEY,
  world_id   TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  character  TEXT,
  kind       TEXT NOT NULL CHECK (kind IN ('roll', 'skill', 'save')),
  label      TEXT,
  total      INT NOT NULL,
  detail     TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS world_dice_rolls_world_created
  ON public.world_dice_rolls (world_id, created_at);

-- ── B — RLS ─────────────────────────────────────────────────────────────────
-- Yazma politikası yok: tek kapı log_dice_roll.

ALTER TABLE public.world_dice_rolls ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "WDice: dm read" ON public.world_dice_rolls;
CREATE POLICY "WDice: dm read"
  ON public.world_dice_rolls FOR SELECT
  USING (public.is_world_dm(world_id));

-- ── C — Oyuncunun tek yazma kapısı ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.log_dice_roll(
  p_world_id  TEXT,
  p_character TEXT,
  p_kind      TEXT,
  p_label     TEXT,
  p_total     INT,
  p_detail    TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_world_member(p_world_id) THEN
    RETURN FALSE;
  END IF;
  IF p_kind IS NULL OR p_kind NOT IN ('roll', 'skill', 'save')
     OR p_total IS NULL OR p_detail IS NULL
     OR length(p_detail) > 200
     OR length(coalesce(p_character, '')) > 80
     OR length(coalesce(p_label, '')) > 80 THEN
    RAISE EXCEPTION 'invalid dice roll' USING ERRCODE = '22023';
  END IF;

  DELETE FROM public.world_dice_rolls
   WHERE world_id = p_world_id
     AND created_at < now() - interval '1 hour';

  INSERT INTO public.world_dice_rolls
    (world_id, user_id, character, kind, label, total, detail)
  VALUES
    (p_world_id, auth.uid(), nullif(p_character, ''), p_kind,
     nullif(p_label, ''), p_total, p_detail);
  RETURN TRUE;
END $$;

REVOKE ALL ON FUNCTION public.log_dice_roll(TEXT, TEXT, TEXT, TEXT, INT, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_dice_roll(TEXT, TEXT, TEXT, TEXT, INT, TEXT)
  TO authenticated;

COMMENT ON FUNCTION public.log_dice_roll(TEXT, TEXT, TEXT, TEXT, INT, TEXT) IS
  'Oyuncunun zar atışını DM''in oturum günlüğüne gönderdiği TEK kapı. '
  'Üye değilse FALSE döner, hiçbir şey yazmaz.';

-- ── D — Realtime ────────────────────────────────────────────────────────────

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'world_dice_rolls'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.world_dice_rolls;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
