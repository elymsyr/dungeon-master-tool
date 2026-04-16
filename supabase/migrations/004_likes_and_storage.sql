-- ============================================================================
-- DMT — Likes + Storage RLS bucket fix
-- ============================================================================
-- 1) post-images ve shared-payloads bucket'ları için storage.objects RLS
--    politikaları (003 sonrası elle oluşturulmuş bucket'lara INSERT izni
--    yoktu; "new row violates row-level security policy" hatasının kaynağı).
-- 2) post_likes tablosu — feed beğenileri.
-- 3) post_scores view — beğeni sayısı + zamana göre ağırlıklı sıralama.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

-- ── 1. Bucket tanımları (idempotent) ────────────────────────────────────────
-- 003 README'sinde elle oluşturulması istenen bucket'lar artık migration
-- tarafından da garanti edilir.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'post-images',
  'post-images',
  true,
  5242880,  -- 5 MB
  ARRAY['image/jpeg','image/png','image/webp']
)
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'shared-payloads',
  'shared-payloads',
  false,
  10485760,  -- 10 MB
  ARRAY['application/gzip']
)
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  2097152,  -- 2 MB
  ARRAY['image/jpeg','image/png','image/webp']
)
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ── 2. shared-payloads RLS ──────────────────────────────────────────────────
-- Path format: {user_id}/{itemType}/{localId}.json.gz
-- Sahibi kendi klasörüne yazar; SELECT public.shared_items.is_public ile
-- gating yapıldığı için herhangi bir auth user payload'ı GET edebilir
-- (signed URL gerekli değil — gzip JSON, küçük).

DROP POLICY IF EXISTS "shared-payloads owner insert" ON storage.objects;
CREATE POLICY "shared-payloads owner insert"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'shared-payloads'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "shared-payloads owner update" ON storage.objects;
CREATE POLICY "shared-payloads owner update"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'shared-payloads'
    AND auth.uid()::text = (storage.foldername(name))[1]
  )
  WITH CHECK (
    bucket_id = 'shared-payloads'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "shared-payloads owner delete" ON storage.objects;
CREATE POLICY "shared-payloads owner delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'shared-payloads'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "shared-payloads authenticated read" ON storage.objects;
CREATE POLICY "shared-payloads authenticated read"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'shared-payloads'
    AND auth.role() = 'authenticated'
  );

-- ── 3. post-images RLS ──────────────────────────────────────────────────────
-- Public bucket — okuma anon dahil açık. Yazma yalnızca sahip klasörüne.

DROP POLICY IF EXISTS "post-images public read" ON storage.objects;
CREATE POLICY "post-images public read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'post-images');

DROP POLICY IF EXISTS "post-images owner insert" ON storage.objects;
CREATE POLICY "post-images owner insert"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'post-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "post-images owner update" ON storage.objects;
CREATE POLICY "post-images owner update"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'post-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  )
  WITH CHECK (
    bucket_id = 'post-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "post-images owner delete" ON storage.objects;
CREATE POLICY "post-images owner delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'post-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- ── 4. avatars RLS ──────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "avatars public read" ON storage.objects;
CREATE POLICY "avatars public read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "avatars owner write" ON storage.objects;
CREATE POLICY "avatars owner write"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "avatars owner update" ON storage.objects;
CREATE POLICY "avatars owner update"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  )
  WITH CHECK (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "avatars owner delete" ON storage.objects;
CREATE POLICY "avatars owner delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- ── 5. post_likes tablosu ───────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.post_likes (
  post_id    UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_post_likes_post ON public.post_likes (post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user ON public.post_likes (user_id);

ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Likes are public read" ON public.post_likes;
CREATE POLICY "Likes are public read"
  ON public.post_likes FOR SELECT USING (true);

DROP POLICY IF EXISTS "User manages own likes" ON public.post_likes;
CREATE POLICY "User manages own likes"
  ON public.post_likes FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ── 6. post_scores view ─────────────────────────────────────────────────────
-- Hot/popular sıralama için ham like_count + zamana göre sönümlenmiş skor.
-- Formül: (likes + 1) / pow(hours_since + 2, 1.5) — Hacker News-style decay.

CREATE OR REPLACE VIEW public.post_scores AS
  SELECT
    p.id AS post_id,
    p.created_at,
    COALESCE((SELECT count(*) FROM public.post_likes l WHERE l.post_id = p.id), 0) AS like_count,
    (
      (COALESCE((SELECT count(*) FROM public.post_likes l WHERE l.post_id = p.id), 0)::float + 1.0)
      /
      pow(
        (EXTRACT(EPOCH FROM (now() - p.created_at)) / 3600.0)::float + 2.0,
        1.5
      )
    ) AS hot_score
  FROM public.posts p;

GRANT SELECT ON public.post_scores TO anon, authenticated;
