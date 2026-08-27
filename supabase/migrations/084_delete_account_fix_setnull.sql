-- ============================================================================
-- 084_delete_account_fix_setnull.sql — 083'ün cascade varsayımını düzeltir
-- ============================================================================
-- 083 "her şey ON DELETE CASCADE ile gider" diyordu. İki kolon CASCADE değil
-- **SET NULL**, ve ikisi de NULL'ı kabul etmeyen bir kural altında:
--
--   • `world_characters.owner_id` (026) — SET NULL. Kullanıcının dünyasız
--     (kişisel) karakterlerinde `world_id` zaten NULL olduğu için satır
--     `(NULL, NULL)`'a düşüyor ve 039'un `chk_world_chars_not_both_null`
--     CHECK'ini deviriyor:
--       23514: new row for relation "world_characters" violates check
--              constraint "chk_world_chars_not_both_null"
--     Gerçek hesapla test edilirken alınan hata bu; silme hiç başlamıyordu.
--     (Aynı satırlar kullanıcının kendi dünyasındaysa da aynı yere düşer:
--     dünya cascade ile silinirken `world_id` SET NULL oluyor.)
--
--   • `admin_audit_log.admin_id` (023) — kolon **NOT NULL** ve FK yine
--     SET NULL. Bir admin hesabını silmeye kalkarsa `23502` ile patlar.
--     Henüz gözlenmedi çünkü test hesabı admin değildi.
--
-- Çözüm ikisinde de satırı silmek: hesabı silinen kullanıcının karakterleri
-- onun verisi (başkasının dünyasındakiler dahil — kullanıcı gidiyorsa
-- karakteri de gidiyor), audit satırları da yalnız o admin'in kendi
-- eylemlerinin kaydı. Kolon tanımlarına dokunulmuyor: SET NULL davranışı
-- "karakter serbest bırakıldı" / "admin kaydı anonimleşti" anlamıyla başka
-- akışlarda doğru; yanlış olan tek şey 083'ün onları hesaba katmamasıydı.
--
-- 083 idempotent olduğu için bu dosya sadece gövdeyi CREATE OR REPLACE eder.
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

  -- SET NULL'ın NULL'ı kabul edilmeyen yerlere düştüğü iki tablo.
  DELETE FROM public.world_characters WHERE owner_id = v_user;
  DELETE FROM public.admin_audit_log  WHERE admin_id = v_user;

  -- Tek CASCADE'siz (NO ACTION) referans.
  UPDATE public.world_projection SET updated_by = NULL WHERE updated_by = v_user;

  -- Geri kalan her şey auth.users FK'leri üzerinden ON DELETE CASCADE ile.
  DELETE FROM auth.users WHERE id = v_user;

  RETURN TRUE;
END $$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.delete_my_account() FROM anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

NOTIFY pgrst, 'reload schema';
