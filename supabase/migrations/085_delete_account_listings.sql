-- ============================================================================
-- 085_delete_account_listings.sql — 083/084'ün iki sessiz noktası
-- ============================================================================
-- Rapor: hesap silindikten sonra kullanıcının marketplace ilanları (world,
-- package, character kartları) listede duruyordu.
--
-- İki olası neden vardı ve ikisi de sessizdi:
--
--   1. `marketplace_listings.owner_id` → `profiles(user_id)` → `auth.users`
--      zinciri (006 + 003) kâğıt üzerinde CASCADE. Dağıtılmış şemada zincirin
--      bir halkası beklendiği gibi değilse ilan sahipsiz kalıyor ve hiçbir
--      hata çıkmıyor. Silmeyi cascade'e bırakmak yerine burada **açıkça**
--      yapıyoruz: cascade zaten çalışıyorsa bu satır no-op, çalışmıyorsa
--      raporlanan hatayı imkânsız kılıyor. (083'ün "tablo listesi tutma"
--      kuralının bilinçli istisnası: liste değil, gözlenmiş tek vaka.)
--
--   2. `auth.uid()` NULL ise fonksiyon hiçbir şey silmeden `FALSE` dönüyordu
--      ve istemci bu dönüşü yutuyordu — kullanıcı hesabını silinmiş sanıyor,
--      bulutta her şey duruyor. Artık NULL uid `RAISE EXCEPTION`, ve
--      `auth.users`'tan 0 satır silinmesi de öyle. İstemci tarafı da dönüş
--      değerini kontrol ediyor (account_deletion_service.dart).
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user    UUID := auth.uid();
  v_deleted INT;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'delete_my_account: not authenticated' USING ERRCODE = '42501';
  END IF;

  -- Cascade'e bırakılmayan, gözlenmiş vaka: hesap gittikten sonra da listede
  -- duran ilanlar. Payload objelerini istemci kendi JWT'siyle önceden siler.
  DELETE FROM public.marketplace_listings WHERE owner_id = v_user;

  -- SET NULL'ın NULL'ı kabul edilmeyen yerlere düştüğü iki tablo (084).
  DELETE FROM public.world_characters WHERE owner_id = v_user;
  DELETE FROM public.admin_audit_log  WHERE admin_id = v_user;

  -- Tek CASCADE'siz (NO ACTION) referans.
  UPDATE public.world_projection SET updated_by = NULL WHERE updated_by = v_user;

  -- Geri kalan her şey auth.users FK'leri üzerinden ON DELETE CASCADE ile.
  DELETE FROM auth.users WHERE id = v_user;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  IF v_deleted = 0 THEN
    -- Sessiz no-op yerine hata: aksi halde istemci hesabı silinmiş sanır.
    RAISE EXCEPTION 'delete_my_account: no auth.users row for %', v_user;
  END IF;

  RETURN TRUE;
END $$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.delete_my_account() FROM anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

NOTIFY pgrst, 'reload schema';
