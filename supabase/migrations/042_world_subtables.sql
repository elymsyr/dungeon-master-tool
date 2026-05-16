-- ============================================================================
-- 042_world_subtables.sql — worlds.state_json granular split (PR-SYNC-3)
-- ============================================================================
-- The legacy `worlds.state_json` blob carries mapData + sessions + settings
-- + everything else as a single ~MB JSON. Every map drag / session note edit
-- re-uploads the whole blob and re-decodes it on every player device.
--
-- This migration introduces three granular mirror tables:
--   * world_map_data  — 1:1 with world (current battle map state)
--   * world_sessions  — 1:N (session rows with nested encounters/combatants)
--   * world_settings  — 1:1 (settings + remaining top-level state)
--
-- Transition: DM clients dual-write (state_json + granular tables) until
-- PR-SYNC-6 retires the state_json path. The applier prefers granular rows
-- and strips matching keys from incoming `worlds.state_json` events.
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────
-- A — Tables
-- ──────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.world_map_data (
  world_id    TEXT PRIMARY KEY REFERENCES public.worlds(id) ON DELETE CASCADE,
  data_json   TEXT NOT NULL DEFAULT '{}',
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.world_sessions (
  id          TEXT PRIMARY KEY,
  world_id    TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  name        TEXT NOT NULL DEFAULT '',
  data_json   TEXT NOT NULL DEFAULT '{}',
  is_active   BOOLEAN NOT NULL DEFAULT false,
  sort_order  INT NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_world_sessions_world
  ON public.world_sessions (world_id);

CREATE TABLE IF NOT EXISTS public.world_settings (
  world_id      TEXT PRIMARY KEY REFERENCES public.worlds(id) ON DELETE CASCADE,
  settings_json TEXT NOT NULL DEFAULT '{}',
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ──────────────────────────────────────────────────────────────────────────
-- B — RLS
-- ──────────────────────────────────────────────────────────────────────────

ALTER TABLE public.world_map_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "WMD: member read"  ON public.world_map_data;
CREATE POLICY "WMD: member read"
  ON public.world_map_data FOR SELECT
  USING (public.is_world_member(world_id));

DROP POLICY IF EXISTS "WMD: dm writes"    ON public.world_map_data;
CREATE POLICY "WMD: dm writes"
  ON public.world_map_data FOR ALL
  USING (public.is_world_dm(world_id))
  WITH CHECK (public.is_world_dm(world_id));

DROP POLICY IF EXISTS "WSes: member read" ON public.world_sessions;
CREATE POLICY "WSes: member read"
  ON public.world_sessions FOR SELECT
  USING (public.is_world_member(world_id));

DROP POLICY IF EXISTS "WSes: dm writes"   ON public.world_sessions;
CREATE POLICY "WSes: dm writes"
  ON public.world_sessions FOR ALL
  USING (public.is_world_dm(world_id))
  WITH CHECK (public.is_world_dm(world_id));

DROP POLICY IF EXISTS "WSet: member read" ON public.world_settings;
CREATE POLICY "WSet: member read"
  ON public.world_settings FOR SELECT
  USING (public.is_world_member(world_id));

DROP POLICY IF EXISTS "WSet: dm writes"   ON public.world_settings;
CREATE POLICY "WSet: dm writes"
  ON public.world_settings FOR ALL
  USING (public.is_world_dm(world_id))
  WITH CHECK (public.is_world_dm(world_id));

-- ──────────────────────────────────────────────────────────────────────────
-- C — updated_at bump triggers (reuses tg_bump_updated_at from 026)
-- ──────────────────────────────────────────────────────────────────────────

DROP TRIGGER IF EXISTS trg_world_map_data_bump  ON public.world_map_data;
CREATE TRIGGER trg_world_map_data_bump
  BEFORE UPDATE ON public.world_map_data
  FOR EACH ROW EXECUTE FUNCTION public.tg_bump_updated_at();

DROP TRIGGER IF EXISTS trg_world_sessions_bump  ON public.world_sessions;
CREATE TRIGGER trg_world_sessions_bump
  BEFORE UPDATE ON public.world_sessions
  FOR EACH ROW EXECUTE FUNCTION public.tg_bump_updated_at();

DROP TRIGGER IF EXISTS trg_world_settings_bump  ON public.world_settings;
CREATE TRIGGER trg_world_settings_bump
  BEFORE UPDATE ON public.world_settings
  FOR EACH ROW EXECUTE FUNCTION public.tg_bump_updated_at();

-- ──────────────────────────────────────────────────────────────────────────
-- D — Realtime publication add
-- ──────────────────────────────────────────────────────────────────────────

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['world_map_data', 'world_sessions', 'world_settings'] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
