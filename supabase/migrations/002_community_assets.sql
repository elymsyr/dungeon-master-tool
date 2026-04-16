-- ============================================================================
-- DMT Community Assets — Supabase SQL Migration (Sprint 10)
-- ============================================================================
-- Bu migration Cloudflare R2 asset pipeline'ı için metadata tablosunu kurar.
-- Gerçek binary veri R2'da; bu tablo yalnızca erişim kontrolü + integrity
-- metadata'sını tutar.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

-- ── 1. community_assets tablosu ─────────────────────────────────────────────
-- R2 bucket 'dmt-assets' içindeki her object için bir metadata satırı.
-- R2 object key formatı: {uploader_id}/{campaign_id}/{sha256}.{ext}

CREATE TABLE IF NOT EXISTS public.community_assets (
  -- Primary key — client-generated UUID v4.
  id               UUID PRIMARY KEY,

  -- Sahiplik — Supabase Auth user ID. Silinince asset'ler de silinir.
  uploader_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- R2 object key — Worker tarafından erişim kontrolünde kullanılır.
  r2_object_key    TEXT NOT NULL UNIQUE,

  -- İntegrity — download sonrası client SHA-256 doğrulaması yapar.
  sha256_hash      TEXT NOT NULL,             -- 64 hex karakter

  -- İçerik bilgileri
  mime_type        TEXT NOT NULL,
  size_bytes       BIGINT NOT NULL,
  original_filename TEXT,

  -- Kapsam — hangi kampanyaya / session'a ait?
  campaign_id      TEXT,                      -- local campaign id
  session_id       UUID,                      -- Sprint 9 session bridge için

  -- Zaman damgası
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── 2. İndeksler ────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_community_assets_uploader
  ON public.community_assets (uploader_id);

CREATE INDEX IF NOT EXISTS idx_community_assets_session
  ON public.community_assets (session_id);

CREATE INDEX IF NOT EXISTS idx_community_assets_uploader_campaign
  ON public.community_assets (uploader_id, campaign_id);

-- r2_object_key zaten UNIQUE constraint üzerinden indexlenmiş durumda.

-- ── 3. Row Level Security (RLS) ─────────────────────────────────────────────

ALTER TABLE public.community_assets ENABLE ROW LEVEL SECURITY;

-- INSERT / UPDATE / DELETE: sadece uploader kendi satırını yönetebilir.
DROP POLICY IF EXISTS "Uploader manages own assets" ON public.community_assets;
CREATE POLICY "Uploader manages own assets"
  ON public.community_assets
  FOR ALL
  USING (auth.uid() = uploader_id)
  WITH CHECK (auth.uid() = uploader_id);

-- SELECT: Sprint 10 scope'u yalnızca uploader.
-- TODO (Sprint 9): session_participants tablosu eklenince bu policy
-- genişletilmeli — aynı session'daki diğer katılımcılar da SELECT yapabilmeli.
-- Örnek (Sprint 9):
--   USING (
--     auth.uid() = uploader_id
--     OR session_id IN (
--       SELECT session_id FROM session_participants WHERE user_id = auth.uid()
--     )
--   )

-- ── 4. Erişim kontrolü fonksiyonu (Cloudflare Worker için) ─────────────────
-- Worker, service_role key ile bu fonksiyonu çağırır ve download onayı alır.
-- SECURITY DEFINER — service_role authorized olduğu için RLS bypass yapılır;
-- fonksiyon içindeki koşul asıl yetkilendirmeyi tanımlar.

CREATE OR REPLACE FUNCTION public.get_asset_access(
  p_user_id UUID,
  p_r2_key  TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  -- Sprint 10: yalnızca uploader erişebilir.
  -- TODO (Sprint 9): session_participants join ile genişletilecek.
  SELECT EXISTS (
    SELECT 1
    FROM public.community_assets
    WHERE r2_object_key = p_r2_key
      AND uploader_id = p_user_id
  );
$$;

-- Fonksiyonu yalnızca service_role çağırabilsin — client JWT'leri erişemesin.
REVOKE ALL ON FUNCTION public.get_asset_access(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_asset_access(UUID, TEXT) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_asset_access(UUID, TEXT) TO service_role;

-- ── 5. Combined storage kullanım fonksiyonu ────────────────────────────────
-- cloud_backups + community_assets toplam byte'ını döndürür.
-- Flutter cloudStorageUsedProvider bunu RPC ile çağırır; UI'da birleşik
-- kullanılan/kalan quota gösterilir.

CREATE OR REPLACE FUNCTION public.get_user_total_storage_used(p_user_id UUID)
RETURNS BIGINT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    COALESCE((SELECT SUM(size_bytes) FROM public.cloud_backups
              WHERE user_id = p_user_id), 0)
    +
    COALESCE((SELECT SUM(size_bytes) FROM public.community_assets
              WHERE uploader_id = p_user_id), 0);
$$;

GRANT EXECUTE ON FUNCTION public.get_user_total_storage_used(UUID)
  TO authenticated, service_role;

-- ── 6. Asset quota pre-check (Worker çağırır) ──────────────────────────────
-- Upload öncesi: "mevcut toplam + yeni dosya <= limit mi?"
-- Worker service_role key ile çağırır, client'a açık değildir.

CREATE OR REPLACE FUNCTION public.check_asset_quota(
  p_user_id   UUID,
  p_new_bytes BIGINT,
  p_limit     BIGINT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.get_user_total_storage_used(p_user_id) + p_new_bytes <= p_limit;
$$;

REVOKE ALL ON FUNCTION public.check_asset_quota(UUID, BIGINT, BIGINT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.check_asset_quota(UUID, BIGINT, BIGINT) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_asset_quota(UUID, BIGINT, BIGINT) TO service_role;
