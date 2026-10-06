-- ============================================================================
-- 105 — Oyuncunun kendi turunda token'ını oynatması
-- ============================================================================
-- DM battlemap'i online yayınlarken encounter'da sıra bir oyuncunun
-- karakterine gelince, DM o oyuncuya dünya başına TEK satırlık bir izin
-- yazar: hangi encounter, hangi combatant, kimin, tur başındaki pozisyon.
--
--   DM   → INSERT/DELETE (sıra değişince önce DELETE, sonra INSERT — eski
--          sahip DELETE event'iyle iznini kaybettiğini öğrenir; yeni satırı
--          RLS yüzünden göremez)
--   Oyuncu → move_turn_token(world, combatant, x, y) — yalnız x/y/moved_at
--          yazılır, yalnız satır onunsa. Doğrudan UPDATE yetkisi yok.
--   DM   ← UPDATE CDC → pozisyonu encounter'a uygular, yayın her zamanki
--          gibi world_projection'dan herkese gider.
--
-- Sıra geçince satır silinir/değişir; eski sahibin RPC'si hiçbir satırı
-- bulamaz (FALSE). Kimlik ve sıra sunucuda doğrulanır, istemcide değil.
--
-- Satırda olan her şey (combatant id, pozisyon) zaten yayında; gizli
-- token'a izin yazılmaz (istemci tarafı). Okuma yalnız DM + sahip.
--
-- İdempotent.
-- ============================================================================

-- ── A — Tablo ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.world_turn_control (
  world_id     TEXT PRIMARY KEY REFERENCES public.worlds(id) ON DELETE CASCADE,
  encounter_id TEXT NOT NULL,
  combatant_id TEXT NOT NULL,
  owner_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  origin_x     DOUBLE PRECISION NOT NULL,
  origin_y     DOUBLE PRECISION NOT NULL,
  x            DOUBLE PRECISION NOT NULL,
  y            DOUBLE PRECISION NOT NULL,
  moved_at     TIMESTAMPTZ,
  granted_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── B — RLS ─────────────────────────────────────────────────────────────────
-- Oyuncunun yazma politikası yok: tek kapı move_turn_token.

ALTER TABLE public.world_turn_control ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "WTurn: dm or owner read" ON public.world_turn_control;
CREATE POLICY "WTurn: dm or owner read"
  ON public.world_turn_control FOR SELECT
  USING (
    public.is_world_dm(world_id)
    OR (owner_id = auth.uid() AND public.is_world_member(world_id))
  );

-- İzin yalnız o dünyanın üyesine yazılabilir.
DROP POLICY IF EXISTS "WTurn: dm writes" ON public.world_turn_control;
CREATE POLICY "WTurn: dm writes"
  ON public.world_turn_control FOR ALL
  USING (public.is_world_dm(world_id))
  WITH CHECK (
    public.is_world_dm(world_id)
    AND EXISTS (
      SELECT 1 FROM public.world_members m
      WHERE m.world_id = world_turn_control.world_id
        AND m.user_id = world_turn_control.owner_id
    )
  );

-- ── C — Oyuncunun tek yazma kapısı ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.move_turn_token(
  p_world_id     TEXT,
  p_combatant_id TEXT,
  p_x            DOUBLE PRECISION,
  p_y            DOUBLE PRECISION
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

  UPDATE public.world_turn_control
     SET x = p_x, y = p_y, moved_at = now()
   WHERE world_id = p_world_id
     AND combatant_id = p_combatant_id
     AND owner_id = auth.uid()
     AND public.is_world_member(p_world_id);
  RETURN FOUND;
END $$;

REVOKE ALL ON FUNCTION public.move_turn_token(TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.move_turn_token(TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION)
  TO authenticated;

COMMENT ON FUNCTION public.move_turn_token(TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) IS
  'Oyuncunun kendi turunda token pozisyonu yazdığı TEK kapı. Satır çağıranın '
  'değilse ya da sıra geçmişse FALSE döner, hiçbir şey yazmaz.';

-- ── D — Realtime ────────────────────────────────────────────────────────────
-- FULL identity: DELETE event'inin oldRecord'u world_id taşısın (RLS'li
-- tabloda zaten yalnız PK gelir — PK world_id).

ALTER TABLE public.world_turn_control REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'world_turn_control'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.world_turn_control;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
