-- ============================================================================
-- 083_delete_account.sql — Kullanıcının kendi hesabını + verisini silmesi
-- ============================================================================
-- Tek RPC: `delete_my_account()`. Client (Settings → Delete Account) çağırır.
-- GERİ DÖNÜŞÜ YOK.
--
-- Silme `auth.users` satırından yürür; public şemadaki her kullanıcı-sahipli
-- tablo zaten `REFERENCES auth.users(id) ON DELETE CASCADE` taşıyor
-- (profiles → posts/messages/follows/likes, worlds → world_* çocukları,
-- marketplace_listings, community_assets, free_media_assets, transient_shares,
-- notifications, bug_reports, banned_users …). Yani burada tablo tablo DELETE
-- listesi tutulmaz — liste bakımı yapılmayan bir yerde bayatlar; FK'ler
-- bayatlamaz.
--
-- İki istisna elle ele alınır:
--   • `world_projection.updated_by` — tek CASCADE'siz referans (NO ACTION),
--     silmeyi FK ihlaliyle patlatır. NULL'lanır.
--   • Storage objeleri (Supabase buckets + Cloudflare R2) SQL'den silinemez
--     (`storage.protect_delete()` trigger'ı direct DELETE'i bloklar; R2 zaten
--     Postgres'in dışında). İkisini de client, hesabı silmeden ÖNCE kendi
--     RLS/JWT yetkisiyle temizler — bkz. account_deletion_service.dart.
--
-- Not: `banned_users` satırı da cascade ile gider; banlı bir kullanıcı hesabını
-- silip yeniden kayıt olabilir. Ban e-posta bazlı olmadığı için bu zaten
-- mevcut durumun devamı, silme özelliğinin açtığı yeni bir delik değil.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RETURN FALSE;
  END IF;

  UPDATE public.world_projection SET updated_by = NULL WHERE updated_by = v_user;

  DELETE FROM auth.users WHERE id = v_user;

  RETURN TRUE;
END $$;

-- 082'nin mührü: yeni fonksiyonlar anon'a kapalı doğar, EXECUTE açıkça verilir.
REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.delete_my_account() FROM anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

NOTIFY pgrst, 'reload schema';
