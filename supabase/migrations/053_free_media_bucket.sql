-- ============================================================================
-- 053_free_media_bucket.sql — Ücretsiz medya depolama (Supabase Storage)
-- ============================================================================
-- Karakter portreleri ve world/package kapak resimleri Cloudflare R2 yerine
-- Supabase Storage'a gider ve kullanıcının 50MB storage quota'sından
-- DÜŞÜLMEZ. Binary veri `free-media` public bucket'ında; bu migration ek
-- olarak galeri listelemesi için `free_media_assets` metadata tablosunu kurar.
--
-- ⚠ KRİTİK INVARIANT: `free_media_assets` HİÇBİR quota toplamı fonksiyonuna
-- (get_user_total_storage_used — 002 / get_beta_quota_used — 007) EKLENMEZ.
-- Ücretsiz medyanın quota'ya sayılmaması tamamen bu kuralın korunmasına bağlı.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

-- ── 1. free-media bucket ────────────────────────────────────────────────────
-- Public bucket (avatars pattern'i — bkz. 004_likes_and_storage.sql).
-- 2 MB per-file limit: en büyük ücretsiz öğe (portre/kapak) 2MB.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'free-media',
  'free-media',
  true,
  2097152,  -- 2 MB
  ARRAY['image/jpeg','image/png','image/webp','image/gif']
)
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ── 2. free-media RLS (avatars pattern; beta-gate YOK — tüm kullanıcılar) ───
-- Path format: {uploader_id}/{sha256}.{ext}
-- (storage.foldername(name))[1] = ilk klasör = uploader_id.

DROP POLICY IF EXISTS "free-media public read" ON storage.objects;
CREATE POLICY "free-media public read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'free-media');

DROP POLICY IF EXISTS "free-media owner insert" ON storage.objects;
CREATE POLICY "free-media owner insert"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'free-media'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "free-media owner update" ON storage.objects;
CREATE POLICY "free-media owner update"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'free-media'
    AND auth.uid()::text = (storage.foldername(name))[1]
  )
  WITH CHECK (
    bucket_id = 'free-media'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "free-media owner delete" ON storage.objects;
CREATE POLICY "free-media owner delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'free-media'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- ── 3. free_media_assets metadata tablosu ──────────────────────────────────
-- Galeri free + counted asset'leri birlikte listeleyebilsin diye. Her satır
-- `free-media` bucket'ındaki bir object'e (storage_path) karşılık gelir.

CREATE TABLE IF NOT EXISTS public.free_media_assets (
  -- Primary key — client-generated UUID v4.
  id                UUID PRIMARY KEY,

  -- Sahiplik — silinince asset metadata'sı da silinir.
  owner_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Storage object path — {uploader_id}/{sha256}.{ext}
  storage_path      TEXT NOT NULL UNIQUE,

  -- İntegrity — download sonrası client SHA-256 doğrulaması yapar.
  sha256_hash       TEXT NOT NULL,

  -- İçerik bilgileri
  mime_type         TEXT NOT NULL,
  size_bytes        BIGINT NOT NULL,
  kind              TEXT NOT NULL,             -- MediaKind.wireName
  original_filename TEXT,

  -- Kapsam — galeri "this world" filtresi için (campaign/package id).
  scope_id          TEXT,

  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_free_media_assets_owner
  ON public.free_media_assets (owner_id);

CREATE INDEX IF NOT EXISTS idx_free_media_assets_owner_scope
  ON public.free_media_assets (owner_id, scope_id);

-- ── 4. Row Level Security ──────────────────────────────────────────────────

ALTER TABLE public.free_media_assets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owner manages own free media" ON public.free_media_assets;
CREATE POLICY "Owner manages own free media"
  ON public.free_media_assets
  FOR ALL
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

-- ── 5. Quota invariant ─────────────────────────────────────────────────────
-- free_media_assets KASITLI olarak get_user_total_storage_used (002) ve
-- get_beta_quota_used (007) fonksiyonlarının DIŞINDA tutulur. Bu tablo
-- HİÇBİR ZAMAN bir quota SUM'ına eklenmemelidir — ücretsiz medya kuralı
-- doğrudan buna bağlıdır.

NOTIFY pgrst, 'reload schema';
