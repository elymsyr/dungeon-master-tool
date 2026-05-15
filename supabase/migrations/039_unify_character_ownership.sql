-- ============================================================================
-- 039_unify_character_ownership.sql — single-source character model
-- ============================================================================
-- Hedef: karakter durumunu `(owner_id, world_id)` iki ortogonal eksene
-- indirgemek ve geçersiz durumu (NULL, NULL) DB-level CHECK ile yasaklamak.
-- Geçişler 5 RPC üzerinden merkezileşir; eski `character_claim_pool` tablosu
-- ve `personal_characters` chars-için kullanımı emekliye ayrılır.
--
-- Geçerli durumlar:
--   1. (owner, NULL)  → orphan-personal      | Char Tab'da görünür, edit owner
--   2. (owner, W)     → world member         | "Your", edit owner + W DM
--   3. (NULL, W)      → unclaimed in world   | "Available", edit W DM only
--   4. (NULL, NULL)   → YASAK (CHECK reddeder)
--
-- Geçişler:
--   create (no/in world) → (me, NULL) | (me, W)
--   claim                (NULL, W) → (me, W)
--   release              (me, W) → (NULL, W); (me, NULL) → DELETE (CHECK)
--   remove_from_world    (owner, W) → (owner, NULL); (NULL, W) → DELETE
--   delete_character     only (owner, NULL) → DELETE
--   assign_character     (NULL, W) → (player, W)
--   leave/kick (trigger) (me, W) → (NULL, W)
--   world delete         (owner, W) → (owner, NULL); (NULL, W) → DELETE
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────
-- FAZ A — Şema
-- ──────────────────────────────────────────────────────────────────────────

-- A.1 world_id nullable yap.
ALTER TABLE public.world_characters
  ALTER COLUMN world_id DROP NOT NULL;

-- A.2 FK'yi ON DELETE CASCADE'den ON DELETE SET NULL'a çevir. World silindiğinde
-- owner'lı row'lar (owner, NULL)'a düşer; owner'sızlar BEFORE-DELETE trigger ile
-- silinir (Faz D.2). Postgres BEFORE-DELETE trigger önce çalışır, sonra FK
-- referential action uygulanır → owner'sız row'lar trigger'la temizlenmiş olur
-- ve CHECK violation olmaz.
ALTER TABLE public.world_characters
  DROP CONSTRAINT IF EXISTS world_characters_world_id_fkey;
ALTER TABLE public.world_characters
  ADD CONSTRAINT world_characters_world_id_fkey
  FOREIGN KEY (world_id) REFERENCES public.worlds(id) ON DELETE SET NULL;

-- A.3 (NULL, NULL) durumunu DB-level yasakla. RPC'ler bu kuralı sezerek
-- "delete-vs-update" branchini server-side karara dönüştürür.
ALTER TABLE public.world_characters
  DROP CONSTRAINT IF EXISTS chk_world_chars_not_both_null;
ALTER TABLE public.world_characters
  ADD CONSTRAINT chk_world_chars_not_both_null
  CHECK (owner_id IS NOT NULL OR world_id IS NOT NULL);

-- A.4 Yeni axis'lere göre partial index'ler.
CREATE INDEX IF NOT EXISTS idx_world_chars_orphan_by_owner
  ON public.world_characters (owner_id) WHERE world_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_world_chars_unclaimed_by_world
  ON public.world_characters (world_id) WHERE owner_id IS NULL;

-- ──────────────────────────────────────────────────────────────────────────
-- FAZ B — `character_claim_pool` emekliye ayır
-- ──────────────────────────────────────────────────────────────────────────
-- 034 zaten pool'u bypass etmişti; bu migration ile pool tamamen gider.
-- RPC'ler artık pool'a yazmıyor, trigger pool'a INSERT yapmıyor.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'character_claim_pool'
  ) THEN
    ALTER PUBLICATION supabase_realtime DROP TABLE public.character_claim_pool;
  END IF;
END $$;

DROP TABLE IF EXISTS public.character_claim_pool CASCADE;

-- ──────────────────────────────────────────────────────────────────────────
-- FAZ C — RPC seti
-- ──────────────────────────────────────────────────────────────────────────
-- CREATE OR REPLACE FUNCTION return-type değişikliğini desteklemez (42P13).
-- 037'de `release_character` `(character_id, world_id)` döndürüyordu; 039'da
-- `(character_id, world_id, deleted)` olarak değişti → önceden DROP zorunlu.
-- Diğer RPC'ler signature uyumlu ama tutarlılık için hepsini DROP ediyoruz.

DROP FUNCTION IF EXISTS public.claim_character(TEXT);
DROP FUNCTION IF EXISTS public.release_character(TEXT);
DROP FUNCTION IF EXISTS public.remove_from_world(TEXT);
DROP FUNCTION IF EXISTS public.delete_character(TEXT);
DROP FUNCTION IF EXISTS public.assign_character(TEXT, UUID);

-- C.1 claim_character — (NULL, W) → (auth.uid, W).
-- 034 + 037 RPC'sinin pool'suz versiyonu.
CREATE OR REPLACE FUNCTION public.claim_character(p_character_id TEXT)
RETURNS TABLE (character_id TEXT, world_id TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_world_id TEXT;
  v_owner    UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  SELECT wc.world_id, wc.owner_id
    INTO v_world_id, v_owner
    FROM public.world_characters wc
   WHERE wc.id = p_character_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'character not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_world_id IS NULL THEN
    -- Orphan karakter claim edilemez; world dışında zaten "claim" anlamlı değil.
    RAISE EXCEPTION 'character is not in a world' USING ERRCODE = 'P0005';
  END IF;

  IF v_owner IS NOT NULL THEN
    RAISE EXCEPTION 'character already claimed' USING ERRCODE = 'P0003';
  END IF;

  IF NOT public.is_world_member(v_world_id) THEN
    RAISE EXCEPTION 'not a world member' USING ERRCODE = '42501';
  END IF;

  UPDATE public.world_characters
     SET owner_id   = auth.uid(),
         updated_at = now()
   WHERE id = p_character_id;

  RETURN QUERY SELECT p_character_id, v_world_id;
END $$;

ALTER FUNCTION public.claim_character(TEXT) SET row_security = off;
GRANT EXECUTE ON FUNCTION public.claim_character(TEXT) TO authenticated;

-- C.2 release_character — ownership drop.
--   (me, W) → (NULL, W)      UPDATE
--   (me, NULL) → DELETE       (aksi takdirde CHECK violation)
-- DM force-release de bu RPC'den geçer (owner_id update yetkisi RLS UPDATE
-- policy'sinin DM branch'iyle de geçerli, ama burası SECURITY DEFINER'la
-- merkezileşir → setOwner UPDATE'i kaldırılır).
CREATE OR REPLACE FUNCTION public.release_character(p_character_id TEXT)
RETURNS TABLE (character_id TEXT, world_id TEXT, deleted BOOLEAN)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_world_id TEXT;
  v_owner    UUID;
  v_is_dm    BOOLEAN := FALSE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  SELECT wc.world_id, wc.owner_id
    INTO v_world_id, v_owner
    FROM public.world_characters wc
   WHERE wc.id = p_character_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'character not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_world_id IS NOT NULL THEN
    v_is_dm := public.is_world_dm(v_world_id);
  END IF;

  IF v_owner IS NULL THEN
    -- Zaten serbest; idempotent davran.
    RETURN QUERY SELECT p_character_id, v_world_id, FALSE;
    RETURN;
  END IF;

  IF v_owner <> auth.uid() AND NOT v_is_dm THEN
    RAISE EXCEPTION 'not the owner' USING ERRCODE = '42501';
  END IF;

  IF v_world_id IS NULL THEN
    -- Orphan release = delete (CHECK violation olurdu).
    DELETE FROM public.world_characters WHERE id = p_character_id;
    RETURN QUERY SELECT p_character_id, NULL::TEXT, TRUE;
    RETURN;
  END IF;

  UPDATE public.world_characters
     SET owner_id   = NULL,
         updated_at = now()
   WHERE id = p_character_id;

  RETURN QUERY SELECT p_character_id, v_world_id, FALSE;
END $$;

ALTER FUNCTION public.release_character(TEXT) SET row_security = off;
GRANT EXECUTE ON FUNCTION public.release_character(TEXT) TO authenticated;

-- C.3 remove_from_world — karakteri dünyadan çıkar.
--   (owner, W) → (owner, NULL)   UPDATE
--   (NULL, W)  → DELETE           (CHECK violation olurdu)
-- Yetki: owner = auth.uid OR is_world_dm(world_id).
CREATE OR REPLACE FUNCTION public.remove_from_world(p_character_id TEXT)
RETURNS TABLE (character_id TEXT, deleted BOOLEAN)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_world_id TEXT;
  v_owner    UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  SELECT wc.world_id, wc.owner_id
    INTO v_world_id, v_owner
    FROM public.world_characters wc
   WHERE wc.id = p_character_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'character not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_world_id IS NULL THEN
    RAISE EXCEPTION 'character is not in a world' USING ERRCODE = 'P0005';
  END IF;

  IF v_owner IS DISTINCT FROM auth.uid() AND NOT public.is_world_dm(v_world_id) THEN
    RAISE EXCEPTION 'not authorized' USING ERRCODE = '42501';
  END IF;

  IF v_owner IS NULL THEN
    -- Unclaimed → sil.
    DELETE FROM public.world_characters WHERE id = p_character_id;
    RETURN QUERY SELECT p_character_id, TRUE;
    RETURN;
  END IF;

  UPDATE public.world_characters
     SET world_id   = NULL,
         updated_at = now()
   WHERE id = p_character_id;

  RETURN QUERY SELECT p_character_id, FALSE;
END $$;

ALTER FUNCTION public.remove_from_world(TEXT) SET row_security = off;
GRANT EXECUTE ON FUNCTION public.remove_from_world(TEXT) TO authenticated;

-- C.4 delete_character — hard-delete sadece orphan için.
-- World-bound row'lar için remove_from_world veya release_character çağrılmalı.
CREATE OR REPLACE FUNCTION public.delete_character(p_character_id TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_world_id TEXT;
  v_owner    UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  SELECT wc.world_id, wc.owner_id
    INTO v_world_id, v_owner
    FROM public.world_characters wc
   WHERE wc.id = p_character_id
   FOR UPDATE;

  IF NOT FOUND THEN
    -- Idempotent.
    RETURN;
  END IF;

  IF v_world_id IS NOT NULL THEN
    RAISE EXCEPTION 'character is world-bound; use remove_from_world or release_character'
      USING ERRCODE = 'P0005';
  END IF;

  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'not the owner' USING ERRCODE = '42501';
  END IF;

  DELETE FROM public.world_characters WHERE id = p_character_id;
END $$;

ALTER FUNCTION public.delete_character(TEXT) SET row_security = off;
GRANT EXECUTE ON FUNCTION public.delete_character(TEXT) TO authenticated;

-- C.5 assign_character — DM bir karaktere oyuncu atar veya unclaimed yapar.
-- Yetki: DM only. Target user (p_user_id NULL değilse) world member olmalı.
CREATE OR REPLACE FUNCTION public.assign_character(
  p_character_id TEXT,
  p_user_id      UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_world_id TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  SELECT wc.world_id
    INTO v_world_id
    FROM public.world_characters wc
   WHERE wc.id = p_character_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'character not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_world_id IS NULL THEN
    RAISE EXCEPTION 'character is not in a world' USING ERRCODE = 'P0005';
  END IF;

  IF NOT public.is_world_dm(v_world_id) THEN
    RAISE EXCEPTION 'dm role required' USING ERRCODE = '42501';
  END IF;

  IF p_user_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.world_members wm
       WHERE wm.world_id = v_world_id AND wm.user_id = p_user_id
    ) THEN
      RAISE EXCEPTION 'target user is not a world member' USING ERRCODE = 'P0006';
    END IF;
  END IF;

  UPDATE public.world_characters
     SET owner_id   = p_user_id,
         updated_at = now()
   WHERE id = p_character_id;
END $$;

ALTER FUNCTION public.assign_character(TEXT, UUID) SET row_security = off;
GRANT EXECUTE ON FUNCTION public.assign_character(TEXT, UUID) TO authenticated;

-- ──────────────────────────────────────────────────────────────────────────
-- FAZ D — Trigger'lar
-- ──────────────────────────────────────────────────────────────────────────

-- D.1 tg_release_owned_chars_on_leave (032'nin pool'suz versiyonu).
-- Player world'ü terk ettiğinde (self-leave veya kick) ownership düşer.
-- CHECK constraint güvende: world_id hâlâ set, sadece owner_id NULL → (NULL, W).
CREATE OR REPLACE FUNCTION public.tg_release_owned_chars_on_leave()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.world_characters
     SET owner_id   = NULL,
         updated_at = now()
   WHERE world_id = OLD.world_id
     AND owner_id = OLD.user_id;
  RETURN OLD;
END;
$$;

-- Trigger zaten 032'de oluşturuldu; CREATE OR REPLACE FUNCTION ile body
-- güncellendi, trigger yeniden bind etmek gerekmez. Ama temkinli olalım:
DROP TRIGGER IF EXISTS trg_release_chars_on_leave ON public.world_members;
CREATE TRIGGER trg_release_chars_on_leave
  AFTER DELETE ON public.world_members
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_release_owned_chars_on_leave();

-- D.2 tg_world_delete_chars — world silinmeden önce unclaimed (NULL, W)
-- row'larını sil. Geride kalan owner'lı row'ların world_id'sini FK ON DELETE
-- SET NULL halleder → onlar (owner, NULL) orphan'larına dönüşür.
CREATE OR REPLACE FUNCTION public.tg_world_delete_chars()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.world_characters
   WHERE world_id = OLD.id AND owner_id IS NULL;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_world_delete_chars ON public.worlds;
CREATE TRIGGER trg_world_delete_chars
  BEFORE DELETE ON public.worlds
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_world_delete_chars();

-- ──────────────────────────────────────────────────────────────────────────
-- FAZ E — RLS politikaları
-- ──────────────────────────────────────────────────────────────────────────
-- world_characters için yeni model:
--   SELECT: world member tüm world chars + self orphan
--   INSERT: orphan as self OR world create (member + self-owned/DM)
--   UPDATE: owner VEYA world DM
--   DELETE: direkt DELETE kullanılmaz (RPC zorunlu); DM full belt-and-suspenders

-- E.1 SELECT — eski 026 + 034 policy'lerini temizle, yeni unified policy.
DROP POLICY IF EXISTS "Chars: player reads own"   ON public.world_characters;
DROP POLICY IF EXISTS "Chars: members read all"   ON public.world_characters;
DROP POLICY IF EXISTS "Chars: read"               ON public.world_characters;
CREATE POLICY "Chars: read"
  ON public.world_characters FOR SELECT
  USING (
    (world_id IS NOT NULL AND public.is_world_member(world_id))
    OR
    (world_id IS NULL AND owner_id = auth.uid())
  );

-- E.2 INSERT
DROP POLICY IF EXISTS "Chars: player inserts own" ON public.world_characters;
DROP POLICY IF EXISTS "Chars: insert"             ON public.world_characters;
CREATE POLICY "Chars: insert"
  ON public.world_characters FOR INSERT
  WITH CHECK (
    (world_id IS NULL AND owner_id = auth.uid())
    OR
    (world_id IS NOT NULL AND public.is_world_member(world_id)
     AND (owner_id = auth.uid() OR public.is_world_dm(world_id)))
  );

-- E.3 UPDATE
DROP POLICY IF EXISTS "Chars: player writes own"  ON public.world_characters;
DROP POLICY IF EXISTS "Chars: update"             ON public.world_characters;
CREATE POLICY "Chars: update"
  ON public.world_characters FOR UPDATE
  USING (
    owner_id = auth.uid()
    OR (world_id IS NOT NULL AND public.is_world_dm(world_id))
  )
  WITH CHECK (
    owner_id = auth.uid()
    OR (world_id IS NOT NULL AND public.is_world_dm(world_id))
  );

-- E.4 DELETE — direkt DELETE 038'de player'a açıktı, geri al. DM full kalır
-- emergency için; client kod yine RPC üzerinden gider.
DROP POLICY IF EXISTS "Chars: player deletes own" ON public.world_characters;
DROP POLICY IF EXISTS "Chars: dm full"            ON public.world_characters;
CREATE POLICY "Chars: dm full"
  ON public.world_characters FOR ALL
  USING (world_id IS NOT NULL AND public.is_world_dm(world_id))
  WITH CHECK (world_id IS NOT NULL AND public.is_world_dm(world_id));

-- ──────────────────────────────────────────────────────────────────────────
-- FAZ F — `personal_characters` backfill
-- ──────────────────────────────────────────────────────────────────────────
-- Tablo PR4'te DROP edilecek; bu fazda chars-only row'lar world_characters'a
-- taşınır (orphan olarak). Mevcut world_characters row'larıyla id çakışırsa
-- skip (world-bound versiyonu canonical).

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
     WHERE table_schema = 'public' AND table_name = 'personal_characters'
  ) THEN
    INSERT INTO public.world_characters
          (id, owner_id, world_id, template_id, template_name, payload_json,
           created_at, updated_at)
    SELECT pc.id,
           pc.owner_id,
           NULL,
           '',
           '',
           pc.payload_json,
           pc.created_at,
           pc.updated_at
      FROM public.personal_characters pc
     WHERE NOT EXISTS (
       SELECT 1 FROM public.world_characters wc WHERE wc.id = pc.id
     );
  END IF;
END $$;

-- ──────────────────────────────────────────────────────────────────────────
-- FAZ G — PostgREST schema cache reload
-- ──────────────────────────────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
