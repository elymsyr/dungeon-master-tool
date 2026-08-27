-- ============================================================================
-- 086_delete_account_ownership_semantics.sql — 085'in iki sahiplik hatası
-- ============================================================================
-- `delete_my_account()` iki tabloda "kullanıcı gidiyorsa satırı da gitsin"
-- diyordu. İkisinde de satır yalnız kullanıcının değil:
--
--   1. `world_characters` — 039 sahipliği iki ortogonal eksene indirdi ve
--      `(NULL, W)` = "unclaimed in world, edit W DM only" **geçerli bir durum**
--      (039 başlığındaki durum tablosu; `chk_world_chars_not_both_null` bunu
--      kodluyor). 085'in `DELETE ... WHERE owner_id = v_user`'ı bu makineyi
--      atlıyor ve **başka bir DM'in dünyasındaki** satırı da siliyordu: oyuncu
--      hesabını silince DM'in kampanyasından karakter kayboluyordu. Oysa
--      `release_character` (039) ve leave/kick trigger'ı aynı geçiş için
--      zaten `(me,W) → (NULL,W)` diyor; hesap silme bunun en uç hâli, ayrı
--      davranması için sebep yok. (Bulut satırı DM'e mirror'lanıyor zaten —
--      silmek gizlilik kazandırmıyor, yalnız diverjans üretiyordu.)
--
--   2. `admin_audit_log` — satırlar admin'in **başka kullanıcılara** uyguladığı
--      ban / kısıtlama / ilan silme eylemlerinin kaydı (023'te 6, 069'da 2
--      yazıcı). Sahibi admin değil, sistem: RLS client INSERT'i yasaklıyor,
--      okumayı admin'e kapatıyor. 085 bunları siliyordu — kötüye kullanan bir
--      admin hesabını silerek izini süpürebiliyordu.
--
--      084 bu satırları silmeyi seçmişti çünkü `admin_id` **NOT NULL** ve FK
--      **ON DELETE SET NULL** (023:71 — kendi içinde çelişkili tanım). Doğru
--      çözüm kaydı silmek değil, çelişkiyi kaldırmak: `admin_id` nullable olur,
--      korelasyon FK'siz `admin_legacy_id` kolonunda kalır. Kayıt anonimleşir
--      ama durur — 084'ün "admin kaydı anonimleşti" niyetiyle de bu uyumlu.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

-- ── 1. admin_audit_log: NOT NULL + SET NULL çelişkisini çöz ─────────────────

ALTER TABLE public.admin_audit_log
  ADD COLUMN IF NOT EXISTS admin_legacy_id UUID;   -- FK yok: hesap gidince kalır

ALTER TABLE public.admin_audit_log
  ALTER COLUMN admin_id DROP NOT NULL;

-- ── 2. RPC gövdesi ──────────────────────────────────────────────────────────

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

  -- Cascade'e bırakılmayan, gözlenmiş vaka (085): hesap gittikten sonra da
  -- listede duran ilanlar. Payload objelerini istemci kendi JWT'siyle siler.
  DELETE FROM public.marketplace_listings WHERE owner_id = v_user;

  -- 039'un durum makinesi. Sıra önemli: kişisel satırlar önce gider, kalanlar
  -- `(NULL, W)`'ye düşer. Kullanıcının KENDİ dünyasındakiler birazdan
  -- `auth.users` cascade'i `worlds`'ü silerken 039'un BEFORE-DELETE trigger'ı
  -- (`owner_id IS NULL` olanları siler) tarafından toplanır; başka DM'in
  -- dünyasındakiler "unclaimed" olarak hayatta kalır.
  DELETE FROM public.world_characters WHERE owner_id = v_user AND world_id IS NULL;
  UPDATE public.world_characters SET owner_id = NULL WHERE owner_id = v_user;

  -- Denetim kaydı silinmez, anonimleşir.
  UPDATE public.admin_audit_log
     SET admin_legacy_id = COALESCE(admin_legacy_id, admin_id),
         admin_id        = NULL
   WHERE admin_id = v_user;

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

-- ── 3. Audit panel: anonimleşmiş satır boş isimle görünmesin ────────────────
-- 023'ün LEFT JOIN'i `admin_id IS NULL` iken profil bulamıyor ve COALESCE'in
-- üç şıkkı da NULL'a düşüyordu. Dördüncü şık: silinmiş admin'in eski uid'i.

CREATE OR REPLACE FUNCTION public.admin_list_audit_log(
  p_limit  INT     DEFAULT 200,
  p_action TEXT    DEFAULT NULL
)
RETURNS TABLE (
  id               BIGINT,
  admin_id         UUID,
  admin_name       TEXT,
  action           TEXT,
  target_user_id   UUID,
  target_user_name TEXT,
  target_entity_id TEXT,
  reason           TEXT,
  created_at       TIMESTAMPTZ
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  RETURN QUERY
  SELECT a.id, a.admin_id,
         COALESCE(ap.username, ap.display_name, a.admin_id::TEXT,
                  'deleted:' || a.admin_legacy_id::TEXT),
         a.action, a.target_user_id,
         COALESCE(tp.username, tp.display_name, a.target_user_id::TEXT),
         a.target_entity_id, a.reason, a.created_at
  FROM public.admin_audit_log a
  LEFT JOIN public.profiles ap ON ap.user_id = a.admin_id
  LEFT JOIN public.profiles tp ON tp.user_id = a.target_user_id
  WHERE p_action IS NULL OR a.action = p_action
  ORDER BY a.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END $$;

GRANT EXECUTE ON FUNCTION public.admin_list_audit_log(INT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
