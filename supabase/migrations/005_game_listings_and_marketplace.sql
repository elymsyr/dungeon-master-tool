-- ============================================================================
-- DMT — Game listing başvuruları + marketplace genişletme
-- ============================================================================
-- 1) game_listings'e game_language, tags eklenir (filtreleme için).
-- 2) game_listing_applications tablosu: başvuran + mesaj + timestamp.
-- 3) shared_items'a language, tags, download_count eklenir.
-- 4) increment_shared_item_downloads(id) RPC — atomik sayaç.
-- 5) suggested_profiles() RPC — henüz takip edilmeyen ve en çok takipçiye
--    sahip kullanıcıları döner.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

-- ── 1. game_listings kolonları ──────────────────────────────────────────────

ALTER TABLE public.game_listings
  ADD COLUMN IF NOT EXISTS game_language TEXT,
  ADD COLUMN IF NOT EXISTS tags TEXT[] NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_game_listings_language
  ON public.game_listings (game_language) WHERE game_language IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_game_listings_tags
  ON public.game_listings USING GIN (tags);

-- ── 2. game_listing_applications ────────────────────────────────────────────
-- Bir listing'e başvuru. Aynı kullanıcı aynı listing'e birden fazla başvuramaz
-- (UNIQUE). Owner kendi listing'ine başvuramaz (trigger ile kontrol).

CREATE TABLE IF NOT EXISTS public.game_listing_applications (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id     UUID NOT NULL REFERENCES public.game_listings(id) ON DELETE CASCADE,
  applicant_id   UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  message        TEXT NOT NULL CHECK (length(message) BETWEEN 1 AND 1000),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (listing_id, applicant_id)
);

CREATE INDEX IF NOT EXISTS idx_gla_listing ON public.game_listing_applications (listing_id);
CREATE INDEX IF NOT EXISTS idx_gla_applicant ON public.game_listing_applications (applicant_id);

ALTER TABLE public.game_listing_applications ENABLE ROW LEVEL SECURITY;

-- Başvuran kendi başvurularını görür; listing sahibi kendi listing'ine gelen
-- tüm başvuruları görür.
DROP POLICY IF EXISTS "Applications: applicant or owner read" ON public.game_listing_applications;
CREATE POLICY "Applications: applicant or owner read"
  ON public.game_listing_applications FOR SELECT
  USING (
    auth.uid() = applicant_id
    OR EXISTS (
      SELECT 1 FROM public.game_listings gl
      WHERE gl.id = listing_id AND gl.owner_id = auth.uid()
    )
  );

-- Başvuru oluşturma: kimliği doğrulanmış kullanıcı kendi adına başvurabilir;
-- kendi listing'ine başvuramaz.
DROP POLICY IF EXISTS "Applications: apply as self" ON public.game_listing_applications;
CREATE POLICY "Applications: apply as self"
  ON public.game_listing_applications FOR INSERT
  WITH CHECK (
    auth.uid() = applicant_id
    AND NOT EXISTS (
      SELECT 1 FROM public.game_listings gl
      WHERE gl.id = listing_id AND gl.owner_id = auth.uid()
    )
  );

-- Başvuran kendi başvurusunu silebilir (geri çekme); listing sahibi de
-- başvuruyu silebilir (reddetme).
DROP POLICY IF EXISTS "Applications: applicant or owner delete" ON public.game_listing_applications;
CREATE POLICY "Applications: applicant or owner delete"
  ON public.game_listing_applications FOR DELETE
  USING (
    auth.uid() = applicant_id
    OR EXISTS (
      SELECT 1 FROM public.game_listings gl
      WHERE gl.id = listing_id AND gl.owner_id = auth.uid()
    )
  );

-- ── 3. shared_items kolonları ──────────────────────────────────────────────

ALTER TABLE public.shared_items
  ADD COLUMN IF NOT EXISTS language TEXT,
  ADD COLUMN IF NOT EXISTS tags TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS download_count BIGINT NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_shared_items_language
  ON public.shared_items (language) WHERE language IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_shared_items_tags
  ON public.shared_items USING GIN (tags);

-- ── 4. increment_shared_item_downloads RPC ─────────────────────────────────
-- İndirme butonuna basıldığında atomik olarak download_count++.

CREATE OR REPLACE FUNCTION public.increment_shared_item_downloads(p_item_id UUID)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_count BIGINT;
BEGIN
  UPDATE public.shared_items
     SET download_count = download_count + 1
   WHERE id = p_item_id AND is_public = true
  RETURNING download_count INTO v_new_count;
  RETURN COALESCE(v_new_count, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.increment_shared_item_downloads(UUID) TO authenticated;

-- ── 5. suggested_profiles RPC ──────────────────────────────────────────────
-- Auth user'ın henüz takip etmediği, kendisi olmayan ve en çok takipçiye
-- sahip kullanıcıları döner. Basit "popüler öneri" mantığı.

CREATE OR REPLACE FUNCTION public.suggested_profiles(p_limit INT DEFAULT 10)
RETURNS TABLE (
  user_id       UUID,
  username      TEXT,
  display_name  TEXT,
  avatar_url    TEXT,
  followers     BIGINT
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    p.user_id,
    p.username,
    p.display_name,
    p.avatar_url,
    COALESCE((SELECT count(*) FROM public.follows f WHERE f.following_id = p.user_id), 0) AS followers
  FROM public.profiles p
  WHERE p.user_id <> auth.uid()
    AND NOT EXISTS (
      SELECT 1 FROM public.follows f
      WHERE f.follower_id = auth.uid() AND f.following_id = p.user_id
    )
  ORDER BY followers DESC, p.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 50));
$$;

GRANT EXECUTE ON FUNCTION public.suggested_profiles(INT) TO authenticated;
