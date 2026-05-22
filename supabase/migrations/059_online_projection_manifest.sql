-- ============================================================================
-- 059_online_projection_manifest.sql — Online ikinci ekran manifest tablosu
-- ============================================================================
-- DM'in uzak oyunculara projekte ettiği içeriğin ("şu an ne paylaşılıyor")
-- dünya-başına tek satırlık manifesti. `state_json` = ProjectionState.toJson().
--
-- world_settings (042) ile aynı şekil — combat_state blob'una coupling olmasın
-- diye AYRI tablo. DM yazar, tüm dünya üyeleri okur; CDC ile uzak oyunculara
-- replike olur (online ikinci ekran Faz A).
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

-- ── A — Table ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.world_projection (
  world_id    TEXT PRIMARY KEY REFERENCES public.worlds(id) ON DELETE CASCADE,
  state_json  TEXT NOT NULL DEFAULT '{}',
  updated_by  UUID REFERENCES auth.users(id),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── B — RLS ─────────────────────────────────────────────────────────────────
-- SELECT = dünya üyesi (oyuncu manifesti okur); INSERT/UPDATE/DELETE = DM.

ALTER TABLE public.world_projection ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "WProj: member read" ON public.world_projection;
CREATE POLICY "WProj: member read"
  ON public.world_projection FOR SELECT
  USING (public.is_world_member(world_id));

DROP POLICY IF EXISTS "WProj: dm writes" ON public.world_projection;
CREATE POLICY "WProj: dm writes"
  ON public.world_projection FOR ALL
  USING (public.is_world_dm(world_id))
  WITH CHECK (public.is_world_dm(world_id));

-- ── C — updated_at bump trigger (tg_bump_updated_at — 026'dan) ───────────────

DROP TRIGGER IF EXISTS trg_world_projection_bump ON public.world_projection;
CREATE TRIGGER trg_world_projection_bump
  BEFORE UPDATE ON public.world_projection
  FOR EACH ROW EXECUTE FUNCTION public.tg_bump_updated_at();

-- ── D — Realtime publication + REPLICA IDENTITY FULL ────────────────────────
-- FULL identity: DM projeksiyonu kapatınca DELETE event'inin oldRecord'u
-- world_id taşısın → uzak oyuncu manifesti temizleyebilsin.

ALTER TABLE public.world_projection REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'world_projection'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.world_projection;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
