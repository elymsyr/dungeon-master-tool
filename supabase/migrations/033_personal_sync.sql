-- ============================================================================
-- 033_personal_sync.sql — Personal multi-device sync for characters & packages
-- ============================================================================
-- Karakter ve package'lar için "Make Online" → kullanıcının kendi cihazları
-- arasında realtime sync. Davet/üyelik yok; tek sahip (owner_id = auth.uid()).
--
-- Tablolar:
--   personal_characters (id, owner_id, payload_json, updated_at)
--   personal_packages   (owner_id, package_name, state_json, updated_at)
--
-- RLS: tek predikat `owner_id = auth.uid()` — owner her şeyi yapabilir,
-- diğer kullanıcılar görmez/yazamaz.
--
-- RPC'ler `publish_world` pattern'ini izler: SECURITY DEFINER, row_security off,
-- auth.uid()'yi sunucudan çeker → client ownership iddiasını client'a güvenmeden
-- doğrular.
-- ============================================================================

-- ── A. Tablolar ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.personal_characters (
  id            TEXT PRIMARY KEY,
  owner_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  payload_json  TEXT NOT NULL DEFAULT '{}',
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_personal_characters_owner
  ON public.personal_characters (owner_id);

CREATE TABLE IF NOT EXISTS public.personal_packages (
  owner_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  package_name  TEXT NOT NULL,
  state_json    TEXT NOT NULL DEFAULT '{}',
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (owner_id, package_name)
);
CREATE INDEX IF NOT EXISTS idx_personal_packages_owner
  ON public.personal_packages (owner_id);

-- ── B. RLS ──────────────────────────────────────────────────────────────────

ALTER TABLE public.personal_characters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personal_packages   ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "personal_chars: owner all" ON public.personal_characters;
CREATE POLICY "personal_chars: owner all" ON public.personal_characters
  FOR ALL
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "personal_packages: owner all" ON public.personal_packages;
CREATE POLICY "personal_packages: owner all" ON public.personal_packages
  FOR ALL
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- ── C. RPC'ler ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.publish_personal_character(
  p_id TEXT,
  p_payload_json TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_existing_owner UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  SELECT owner_id INTO v_existing_owner
  FROM public.personal_characters WHERE id = p_id;

  IF v_existing_owner IS NULL THEN
    INSERT INTO public.personal_characters (id, owner_id, payload_json)
    VALUES (p_id, auth.uid(), p_payload_json);
  ELSIF v_existing_owner = auth.uid() THEN
    UPDATE public.personal_characters
       SET payload_json = p_payload_json,
           updated_at   = now()
     WHERE id = p_id;
  ELSE
    RAISE EXCEPTION 'character % owned by different user', p_id
      USING ERRCODE = '42501';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.unpublish_personal_character(
  p_id TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;
  DELETE FROM public.personal_characters
   WHERE id = p_id AND owner_id = auth.uid();
END $$;

CREATE OR REPLACE FUNCTION public.publish_personal_package(
  p_package_name TEXT,
  p_state_json TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.personal_packages (owner_id, package_name, state_json)
  VALUES (auth.uid(), p_package_name, p_state_json)
  ON CONFLICT (owner_id, package_name) DO UPDATE
    SET state_json = EXCLUDED.state_json,
        updated_at = now();
END $$;

CREATE OR REPLACE FUNCTION public.unpublish_personal_package(
  p_package_name TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;
  DELETE FROM public.personal_packages
   WHERE owner_id = auth.uid() AND package_name = p_package_name;
END $$;

GRANT EXECUTE ON FUNCTION
  public.publish_personal_character(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION
  public.unpublish_personal_character(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION
  public.publish_personal_package(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION
  public.unpublish_personal_package(TEXT) TO authenticated;

-- ── D. Realtime publication ─────────────────────────────────────────────────

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'personal_characters', 'personal_packages'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
    ) THEN
      EXECUTE format(
        'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
