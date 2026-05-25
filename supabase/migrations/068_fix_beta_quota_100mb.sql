-- ============================================================================
-- 068_fix_beta_quota_100mb.sql — Beta quota'yı gerçekten 100 MB'a çıkar
-- ============================================================================
-- 062_double_media_limits.sql YANLIŞ fonksiyonu güncelledi:
-- `get_beta_quota_bytes()` adında bir fonksiyon yarattı ama gerçek caller'lar
-- (007/066/067 view'ları + RPC quota check) `beta_user_quota_bytes()` çağırıyor.
-- O fonksiyon hâlâ 50 MB döndürüyor → admin paneli + tüm storage check'leri
-- yanlış limit gösteriyordu.
--
-- Bu migration:
--   1) `beta_user_quota_bytes()` → 100 MB
--   2) Yetim `get_beta_quota_bytes()` drop
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

CREATE OR REPLACE FUNCTION public.beta_user_quota_bytes()
RETURNS BIGINT LANGUAGE sql IMMUTABLE AS $$ SELECT (100 * 1024 * 1024)::bigint $$;

ALTER FUNCTION public.beta_user_quota_bytes() SET search_path = public, pg_temp;

DROP FUNCTION IF EXISTS public.get_beta_quota_bytes();

NOTIFY pgrst, 'reload schema';
