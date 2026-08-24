-- 082: 073'ün anon EXECUTE mührünü yeniden bas — ve bir daha bozulmasın.
--
-- Neden:
--   073, `public` şemasındaki tüm SECURITY DEFINER fonksiyonlarından PUBLIC
--   (dolayısıyla anon) EXECUTE'unu geri almıştı. Ama bu tek seferlik bir
--   temizlikti: Postgres yeni yaratılan her fonksiyona EXECUTE'u varsayılan
--   olarak PUBLIC'e verir. 076 (`get_all_users_summary`, `search_users`) ve
--   077 (`publish_world`) bu üç fonksiyonu DROP+CREATE ettiği için üçü de
--   anon'a açık halde geri geldi — advisor taraması yakaladı.
--
--   Gövdelerindeki guard'lar (is_admin() / auth.uid() IS NULL) sömürüyü
--   engelliyor, yani acil bir açık değil. Ama 073'ün kurduğu katman bu; her
--   fonksiyon yeniden yazıldığında sessizce delinmesini istemiyoruz.
--
-- İki parça:
--   1. Mevcut durumu düzelt — 073'ün döngüsü, aynı koruma mantığıyla
--      (authenticated/service_role erişimi REVOKE öncesi yakalanıp geri
--      verilir). 073'ün beta allowlist'i düştü: is_beta_active ve
--      get_beta_status 076'da silindi, whoami zaten SECURITY INVOKER.
--      Idempotent — tekrar çalıştırmak zararsız.
--   2. Tekrarı önle — `postgres` rolünün yarattığı yeni fonksiyonlarda PUBLIC
--      varsayılanı kapatılır. Bundan sonra yazılan her fonksiyonun kendi
--      `GRANT EXECUTE ... TO authenticated` satırını taşıması gerekir; bu
--      zaten repodaki mevcut pratik.

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT p.oid, p.oid::regprocedure::text AS sig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef = true
  LOOP
    IF has_function_privilege('authenticated', r.oid, 'EXECUTE') THEN
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', r.sig);
    END IF;
    IF has_function_privilege('service_role', r.oid, 'EXECUTE') THEN
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', r.sig);
    END IF;
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', r.sig);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon',   r.sig);
  END LOOP;
END $$;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM anon;

NOTIFY pgrst, 'reload schema';
