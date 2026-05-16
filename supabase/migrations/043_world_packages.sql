-- PR-SYNC-5: world_packages — DM-shared package mirror per world.
-- DM uploads personal package to a world; all members see it via CDC.

CREATE TABLE IF NOT EXISTS public.world_packages (
  package_id    TEXT PRIMARY KEY,
  world_id      TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  package_name  TEXT NOT NULL,
  shared_by     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  state_json    TEXT NOT NULL DEFAULT '{}',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_world_packages_world
  ON public.world_packages (world_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_world_packages_world_name
  ON public.world_packages (world_id, package_name);

ALTER TABLE public.world_packages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "WP: members read" ON public.world_packages;
CREATE POLICY "WP: members read" ON public.world_packages FOR SELECT
  USING (public.is_world_member(world_id));

DROP POLICY IF EXISTS "WP: dm writes" ON public.world_packages;
CREATE POLICY "WP: dm writes" ON public.world_packages FOR ALL
  USING (public.is_world_dm(world_id))
  WITH CHECK (public.is_world_dm(world_id) AND shared_by = auth.uid());

DROP TRIGGER IF EXISTS trg_world_packages_bump ON public.world_packages;
CREATE TRIGGER trg_world_packages_bump BEFORE UPDATE ON public.world_packages
  FOR EACH ROW EXECUTE FUNCTION public.tg_bump_updated_at();

-- Realtime publication add (idempotent).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'world_packages'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.world_packages';
  END IF;
END $$;

-- DM share RPC — upsert by (world_id, package_name).
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

-- DM unshare RPC.
CREATE OR REPLACE FUNCTION public.unshare_world_package(
  p_package_id TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_world TEXT;
BEGIN
  SELECT world_id INTO v_world FROM public.world_packages
   WHERE package_id = p_package_id;
  IF v_world IS NULL THEN RETURN; END IF;
  IF NOT public.is_world_dm(v_world) THEN
    RAISE EXCEPTION 'dm only' USING ERRCODE = '42501';
  END IF;
  DELETE FROM public.world_packages WHERE package_id = p_package_id;
END $$;
GRANT EXECUTE ON FUNCTION public.unshare_world_package(TEXT) TO authenticated;
