-- ============================================================================
-- DMT Cloud Backups — Supabase SQL Migration
-- ============================================================================
-- Bu migration Supabase SQL Editor'da çalıştırılmalıdır.
-- Tablo: cloud_backups (metadata) + Storage bucket: campaign-backups
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

-- ── 1. cloud_backups tablosu ────────────────────────────────────────────────
-- Worlds, templates ve packages için ortak metadata tablosu.
-- Gerçek veri Supabase Storage'da gzip JSON olarak saklanır;
-- bu tablo yalnızca lightweight metadata satırlarını tutar (~200 byte/row).

CREATE TABLE IF NOT EXISTS public.cloud_backups (
  -- Primary key — UUID v4, client tarafından üretilir.
  id          UUID PRIMARY KEY,

  -- Sahiplik — Supabase Auth user ID.
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Item bilgileri
  item_name   TEXT NOT NULL,               -- World/template/package adı
  item_id     TEXT NOT NULL,               -- world_id, schemaId veya package_id
  type        TEXT NOT NULL DEFAULT 'world', -- 'world', 'template', 'package'

  -- Storage referansı
  storage_path TEXT NOT NULL,              -- '{user_id}/{type}s/{item_id}.json.gz'

  -- Boyut ve istatistikler
  size_bytes   BIGINT NOT NULL DEFAULT 0,  -- Compressed (gzip) boyut
  entity_count INT NOT NULL DEFAULT 0,     -- Entity sayısı (world/package için)
  schema_version INT NOT NULL DEFAULT 5,   -- Drift schema version

  -- Metadata
  app_version  TEXT,                       -- Uygulama versiyonu (ör. '2.0.3')
  notes        TEXT,                       -- Kullanıcı notu (isteğe bağlı)

  -- Zaman damgaları
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── 2. İndeksler ────────────────────────────────────────────────────────────

-- Kullanıcının backup'larını hızlı listeleme (en yeni önce)
CREATE INDEX IF NOT EXISTS idx_cloud_backups_user_created
  ON public.cloud_backups (user_id, created_at DESC);

-- Tip bazlı filtreleme
CREATE INDEX IF NOT EXISTS idx_cloud_backups_user_type
  ON public.cloud_backups (user_id, type);

-- Upsert desteği — aynı item için mevcut backup arama
CREATE INDEX IF NOT EXISTS idx_cloud_backups_user_item
  ON public.cloud_backups (user_id, item_id, type);

-- ── 3. Row Level Security (RLS) ─────────────────────────────────────────────

ALTER TABLE public.cloud_backups ENABLE ROW LEVEL SECURITY;

-- Kullanıcılar yalnızca kendi backup'larını yönetebilir (CRUD).
DROP POLICY IF EXISTS "Users manage own backups" ON public.cloud_backups;
CREATE POLICY "Users manage own backups"
  ON public.cloud_backups
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ── 4. Storage Bucket ───────────────────────────────────────────────────────
-- Private bucket: campaign-backups
-- Her kullanıcı yalnızca kendi klasörüne ({user_id}/) erişebilir.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'campaign-backups',
  'campaign-backups',
  false,
  10485760,  -- 10 MB
  ARRAY['application/gzip']
)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: kullanıcı kendi klasöründeki dosyaları yönetebilir.
-- Path format: {user_id}/{type}s/{item_id}.json.gz
-- (storage.foldername(name))[1] = ilk klasör = user_id

DROP POLICY IF EXISTS "Users can upload to own folder" ON storage.objects;
CREATE POLICY "Users can upload to own folder"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'campaign-backups'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "Users can read own files" ON storage.objects;
CREATE POLICY "Users can read own files"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'campaign-backups'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "Users can update own files" ON storage.objects;
CREATE POLICY "Users can update own files"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'campaign-backups'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "Users can delete own files" ON storage.objects;
CREATE POLICY "Users can delete own files"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'campaign-backups'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- ── 5. Yardımcı fonksiyon: Kullanıcı toplam storage hesaplama ──────────────

CREATE OR REPLACE FUNCTION public.get_user_storage_used(p_user_id UUID)
RETURNS BIGINT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE(SUM(size_bytes), 0)
  FROM public.cloud_backups
  WHERE user_id = p_user_id;
$$;
