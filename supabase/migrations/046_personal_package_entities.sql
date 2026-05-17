-- ============================================================================
-- 046_personal_package_entities.sql — Personal package entities (row-level)
-- ============================================================================
-- F5 row-level migration: personal package entity edits no longer re-upload
-- the whole `personal_packages.state_json` blob. Each entity has its own row
-- here, RLS-gated to its owner. `personal_packages.state_json` keeps schema
-- + marketplace metadata only.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.personal_package_entities (
  id             TEXT NOT NULL,
  owner_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  package_name   TEXT NOT NULL,
  payload_json   TEXT NOT NULL DEFAULT '{}',
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (owner_id, package_name, id)
);
CREATE INDEX IF NOT EXISTS idx_personal_pkg_entities_owner_pkg
  ON public.personal_package_entities (owner_id, package_name);

ALTER TABLE public.personal_package_entities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ppe: owner all" ON public.personal_package_entities;
CREATE POLICY "ppe: owner all" ON public.personal_package_entities
  FOR ALL
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE OR REPLACE FUNCTION public.publish_personal_package_entity(
  p_package_name TEXT,
  p_entity_id    TEXT,
  p_payload_json TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.personal_package_entities
    (id, owner_id, package_name, payload_json)
  VALUES (p_entity_id, auth.uid(), p_package_name, p_payload_json)
  ON CONFLICT (owner_id, package_name, id) DO UPDATE
    SET payload_json = EXCLUDED.payload_json,
        updated_at   = now();
END $$;

CREATE OR REPLACE FUNCTION public.delete_personal_package_entity(
  p_package_name TEXT,
  p_entity_id    TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;
  DELETE FROM public.personal_package_entities
   WHERE owner_id     = auth.uid()
     AND package_name = p_package_name
     AND id           = p_entity_id;
END $$;

GRANT EXECUTE ON FUNCTION
  public.publish_personal_package_entity(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION
  public.delete_personal_package_entity(TEXT, TEXT) TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'personal_package_entities'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.personal_package_entities;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
