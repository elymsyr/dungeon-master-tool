-- ============================================================================
-- 073_revoke_anon_execute.sql — anon EXECUTE'unu SECURITY DEFINER RPC'lerden kaldır
-- ============================================================================
-- 072 Part B `REVOKE ... FROM anon` yaptı ama NO-OP'tu: Postgres EXECUTE'u
-- varsayılan olarak PUBLIC'e verir ve anon bunu PUBLIC üzerinden miras alır.
-- Tek bir rolden PUBLIC grant'ı geri alınamaz → linter hâlâ anon'u görüyordu.
-- Gerçek çözüm: `REVOKE EXECUTE ... FROM PUBLIC`.
--
-- PUBLIC'i geri almak authenticated/service_role'ü de düşürür — bu yüzden REVOKE
-- öncesi mevcut erişim has_function_privilege ile YAKALANIP açıkça yeniden verilir.
-- Böylece authenticated/service_role bugünkü erişimini korur, sadece anon kapanır.
--
-- Korunan iki durum:
--   1) service_role-only funcs (get_asset_access, _purge_beta_user, ...) — 060/065/067
--      zaten PUBLIC'ten revoke etmiş; authenticated privilege'i false → yeniden
--      verilmez, service_role-only kalır.
--   2) KASITLI anon funcs (is_beta_active, get_beta_status) — beta-gate için
--      login öncesi gerekli; allowlist'te, döngü atlar. (whoami INVOKER, lint
--      0028 onu zaten flag'lemez.)
--
-- Gövdeler DEĞİŞMEZ — sadece grant'lar. Idempotent.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT p.oid, p.oid::regprocedure::text AS sig, p.proname
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef = true                                              -- yalnız SECURITY DEFINER
      AND p.proname NOT IN ('is_beta_active', 'get_beta_status', 'whoami') -- kasıtlı anon (allowlist)
  LOOP
    -- mevcut etkin erişimi PUBLIC kaldırılmadan ÖNCE açıkça koru
    IF has_function_privilege('authenticated', r.oid, 'EXECUTE') THEN
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', r.sig);
    END IF;
    IF has_function_privilege('service_role', r.oid, 'EXECUTE') THEN
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', r.sig);
    END IF;
    -- anon'un miras aldığı varsayılan PUBLIC grant'ını + varsa doğrudan anon grant'ını kaldır
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', r.sig);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon',   r.sig);
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
