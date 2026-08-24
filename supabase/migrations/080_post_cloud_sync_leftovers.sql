-- 080: 076/077 sonrası kalan iki artık.
--
-- 1. user_heartbeat(TEXT, TEXT) — 076 yalnızca parametresiz overload'u
--    düzeltti. İstemci parametreyle çağırıyor (heartbeat_service.dart:74),
--    yani bu overload'a düşüyor ve gövdesindeki `UPDATE beta_participants`
--    tablo 076'da düştüğü için her heartbeat'i patlatıyor. İstemci hatayı
--    yutuyor → sessizce bozuk: last_active_at / app_version / platform
--    güncellenmiyor, admin panelindeki "son aktif" donuyor.
--
-- 2. get_user_storage_used(UUID) — 001'den kalma, gövdesi `cloud_backups`
--    okuyor, tablo 077'de düştü. Çağıranı yok (ne DB fonksiyonu ne Dart).
--    Adı get_user_total_storage_used ile karışıyor; o düzgün ve kalıyor.

CREATE OR REPLACE FUNCTION public.user_heartbeat(
  p_app_version TEXT DEFAULT NULL,
  p_platform    TEXT DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RETURN;
  END IF;

  UPDATE public.profiles
     SET last_active_at = now(),
         app_version    = COALESCE(NULLIF(p_app_version, ''), app_version),
         platform       = COALESCE(NULLIF(p_platform,    ''), platform)
   WHERE user_id = v_user;
END $$;

DROP FUNCTION IF EXISTS public.get_user_storage_used(UUID);

NOTIFY pgrst, 'reload schema';
