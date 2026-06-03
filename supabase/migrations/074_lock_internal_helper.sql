-- ============================================================================
-- 074_lock_internal_helper.sql — dahili rate-limit helper'ını client rollerinden kapat
-- ============================================================================
-- `_assert_admin_rate_limit()` SADECE diğer SECURITY DEFINER RPC'lerin içinden
-- çağrılır (set_online_restriction, admin_delete_*, ...). DEFINER fonksiyon içindeki
-- iç çağrıda EXECUTE kontrolü fonksiyon SAHİBİNE göre yapılır — bu yüzden çağıranın
-- (authenticated/anon) grant'ı kaldırılsa bile iç çağrılar çalışmaya devam eder.
-- Flutter hiçbir yerde `.rpc('_assert_admin_rate_limit')` çağırmaz; service_role
-- de doğrudan çağırmaz. Dolayısıyla tüm client-rol EXECUTE'u güvenle kaldırılır.
--
-- Etki: lint 0029 (authenticated_security_definer_function_executable) listesinden
-- bu fonksiyon düşer. Gövde değişmez, davranış aynı. Idempotent.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

REVOKE ALL ON FUNCTION public._assert_admin_rate_limit() FROM PUBLIC;
REVOKE ALL ON FUNCTION public._assert_admin_rate_limit() FROM anon, authenticated;

NOTIFY pgrst, 'reload schema';
