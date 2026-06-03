-- ============================================================================
-- 072_security_hardening.sql — Supabase linter (Advisors > Security) uyarılarını kapat
-- ============================================================================
-- İki uyarı sınıfı:
--   (A) function_search_path_mutable — 10 fonksiyonda pinlenmiş search_path yok.
--   (B) anon_security_definer_function_executable — public şemadaki SECURITY DEFINER
--       RPC'leri anon rolünden EXECUTE edilebilir (PostgREST varsayılanı).
--
-- Bu migration SADECE izin/öznitelik değiştirir; fonksiyon GÖVDELERİ değişmez,
-- davranış aynı kalır. Admin RPC'leri zaten `IF NOT public.is_admin() THEN RAISE`
-- ile kendini koruyor — bu, derinlemesine savunma (defense-in-depth) içindir.
--
-- Idempotent: ALTER ... SET ve REVOKE tekrar çalıştırılabilir.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

-- ---------------------------------------------------------------------------
-- (A) search_path'i pinle (gövde/SECURITY niteliği korunur, sadece path sabitlenir)
-- ---------------------------------------------------------------------------
ALTER FUNCTION public.beta_slot_cap()                  SET search_path = public, pg_temp;
ALTER FUNCTION public.tg_bump_updated_at()             SET search_path = public, pg_temp;
ALTER FUNCTION public.enforce_listing_immutability()   SET search_path = public, pg_temp;
ALTER FUNCTION public.max_online_characters_per_user() SET search_path = public, pg_temp;
ALTER FUNCTION public.max_online_worlds_per_user()     SET search_path = public, pg_temp;
ALTER FUNCTION public.max_characters_per_world()       SET search_path = public, pg_temp;
ALTER FUNCTION public.max_online_packages_per_user()   SET search_path = public, pg_temp;
ALTER FUNCTION public.compact_battlemap_marks(TEXT, TEXT, BIGINT)
                                                       SET search_path = public, pg_temp;
ALTER FUNCTION public.transient_per_user_cap_bytes()   SET search_path = public, pg_temp;
ALTER FUNCTION public.transient_pool_cap_bytes()       SET search_path = public, pg_temp;

-- ---------------------------------------------------------------------------
-- (B) public şemadaki TÜM SECURITY DEFINER fonksiyonlarından anon EXECUTE'unu kaldır.
--     authenticated/service_role grant'ları korunur (admin kullanıcı authenticated'tir
--     ve hâlâ is_admin() geçer). Sadece oturumsuz (anon) yol kapanır.
--     Liste uzun ve büyüyebilir; bu yüzden imza tek tek yazmak yerine döngü kullanılır.
--
--     NOT: anon için KASITLI çalışması gereken bir SECURITY DEFINER fonksiyon YOK
--     (tüm oyun akışı oturum arkasında; e-posta onayı GoTrue verifyOtp ile, RPC değil).
--     İleride böyle bir fonksiyon eklenirse aşağıdaki WHERE'e allowlist ekle:
--         AND p.proname <> 'kasitli_anon_func'
-- ---------------------------------------------------------------------------
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure::text AS sig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef = true            -- yalnız SECURITY DEFINER
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon', r.sig);
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
