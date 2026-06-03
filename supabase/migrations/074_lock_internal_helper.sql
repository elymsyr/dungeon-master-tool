-- ============================================================================
-- 074_lock_internal_helper.sql — son anon/internal lockdown
-- ============================================================================
-- (1) `_assert_admin_rate_limit()` SADECE diğer SECURITY DEFINER RPC'lerin içinden
--     çağrılır (set_online_restriction, admin_delete_*, ...). DEFINER fonksiyon
--     içindeki iç çağrıda EXECUTE kontrolü fonksiyon SAHİBİNE göre yapılır — bu
--     yüzden çağıranın (authenticated/anon) grant'ı kaldırılsa bile iç çağrılar
--     çalışmaya devam eder. Flutter hiçbir yerde `.rpc('_assert_admin_rate_limit')`
--     çağırmaz; service_role de doğrudan çağırmaz → tüm client-rol EXECUTE güvenle
--     kaldırılır. Etki: lint 0029 listesinden düşer.
--
-- (2) anon beta oracle'larını kapat. 073 bunları "login öncesi gerekli" gerekçesiyle
--     anon'da bırakmıştı; kod bunu YALANLIYOR (audit, PASS):
--       * `is_beta_active(uuid)` — oturumsuz saldırgan herhangi bilinen user-id için
--         "beta üyesi mi?" sorgulayabiliyordu (id'ler community post/listing'den sızar).
--         Per-uuid bilgi-sızdırma oracle'ı.
--       * `get_beta_status()` — boş slot sayısını herkese sızdırıyordu.
--     Hiçbir anon RLS yolu bunlara ulaşmıyor (tüm `is_beta_active` policy'leri yazma
--     kapısı, authenticated-only, `auth.uid()` predicate'li). Flutter ikisini de
--     yalnız sign-in sonrası çağırıyor (beta_provider.dart authProvider==null erken
--     dönüş). Web confirm sayfası yalnız verifyOtp. authenticated EXECUTE'u KORUNUR
--     → gerçek kullanıcıya etki YOK; lint 0028 (anon) → 0.
--
-- Gövdeler değişmez; yalnız grant'lar. Idempotent.
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

-- (1) internal-only rate-limit helper
REVOKE ALL ON FUNCTION public._assert_admin_rate_limit() FROM PUBLIC;
REVOKE ALL ON FUNCTION public._assert_admin_rate_limit() FROM anon, authenticated;

-- (2) anon beta oracle'ları (authenticated/service_role korunur)
REVOKE EXECUTE ON FUNCTION public.is_beta_active(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_beta_status()    FROM PUBLIC, anon;

NOTIFY pgrst, 'reload schema';
