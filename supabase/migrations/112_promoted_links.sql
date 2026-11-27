-- ============================================================================
-- 112_promoted_links.sql
--   Support penceresinin alt kısmındaki "Promoted" bağlantıları (ikon · isim ·
--   link). Admin panelinden eklenir / silinir.
--   • Herkes okur (anon dahil): içerik public, created_by tutulmaz.
--   • INSERT / DELETE yalnız is_admin().
--   • İkon resmi 110'un `notification-images` bucket'ında durur
--     (admin-only yazma, public okuma); image_path silmede temizlik içindir.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.promoted_links (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  label      TEXT NOT NULL CHECK (length(btrim(label)) BETWEEN 1 AND 80),
  url        TEXT NOT NULL CHECK (url ~* '^https?://' AND length(url) <= 500),
  image_url  TEXT,
  image_path TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.promoted_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "promoted_links read" ON public.promoted_links;
CREATE POLICY "promoted_links read"
  ON public.promoted_links FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "promoted_links admin insert" ON public.promoted_links;
CREATE POLICY "promoted_links admin insert"
  ON public.promoted_links FOR INSERT
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "promoted_links admin delete" ON public.promoted_links;
CREATE POLICY "promoted_links admin delete"
  ON public.promoted_links FOR DELETE
  USING (public.is_admin());

GRANT SELECT ON public.promoted_links TO anon, authenticated;
GRANT INSERT, DELETE ON public.promoted_links TO authenticated;

NOTIFY pgrst, 'reload schema';
