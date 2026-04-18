-- 024_linter_fixes.sql
--
-- Supabase Database Linter uyarılarını kapatan idempotent migration.
-- Kapsam:
--   1. `profile_counts` + `post_scores` view'larını SECURITY INVOKER'a çevirir
--      (ERROR: security_definer_view).
--   2. `public` şemasındaki 9 fonksiyon için `search_path` değerini
--      `public, pg_temp`'a sabitler (WARN: function_search_path_mutable).
--   3. `avatars` ve `post-images` public bucket'larındaki geniş SELECT
--      policy'lerini kaldırır (WARN: public_bucket_allows_listing).
--      Public URL erişimi Storage CDN üzerinden yapılır; bu policy'ler
--      yalnızca programatik `list()` çağrılarını açıyordu ve istemci
--      tarafında kullanılmıyor.
--
-- Ek DASHBOARD adımı (SQL değil, unutulmasın):
--   Authentication → Providers → Email → "Leaked password protection" aç
--   (WARN: auth_leaked_password_protection).

-- ── 1. View'ları SECURITY INVOKER'a çevir ───────────────────────────────────

ALTER VIEW public.profile_counts SET (security_invoker = true);
ALTER VIEW public.post_scores    SET (security_invoker = true);

-- ── 2. Fonksiyonlar için search_path'i sabitle ──────────────────────────────

ALTER FUNCTION public.beta_slot_cap()                SET search_path = public, pg_temp;
ALTER FUNCTION public.beta_user_quota_bytes()        SET search_path = public, pg_temp;
ALTER FUNCTION public.beta_inactivity_days()         SET search_path = public, pg_temp;
ALTER FUNCTION public.post_rate_per_minute()         SET search_path = public, pg_temp;
ALTER FUNCTION public.post_rate_per_hour()           SET search_path = public, pg_temp;
ALTER FUNCTION public.post_rate_per_day()            SET search_path = public, pg_temp;
ALTER FUNCTION public.get_user_storage_used(uuid)    SET search_path = public, pg_temp;
ALTER FUNCTION public.bug_reports_touch_updated_at() SET search_path = public, pg_temp;
ALTER FUNCTION public.enforce_listing_immutability() SET search_path = public, pg_temp;

-- ── 3. Public bucket'lardaki geniş SELECT policy'lerini kaldır ──────────────

DROP POLICY IF EXISTS "post-images public read" ON storage.objects;
DROP POLICY IF EXISTS "avatars public read"     ON storage.objects;
