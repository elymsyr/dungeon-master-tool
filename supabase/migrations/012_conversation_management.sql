-- ============================================================================
-- DMT — Conversation management RPCs
-- ============================================================================
-- Grup yönetimi: üye ayrılma (admin transfer ile), grup silme, isim değiştirme.
-- Mesaj silme mevcut RLS policy ile destekleniyor (author deletes own).
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

-- ── 1. leave_conversation ─────────────────────────────────────────────────────
-- Kullanıcı konuşmadan ayrılır. Son üyeyse konuşma silinir. Grup admin'i
-- (created_by) ayrılıyorsa yöneticilik en eski üyeye transfer edilir.

CREATE OR REPLACE FUNCTION public.leave_conversation(p_conv_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid          UUID := auth.uid();
  v_is_group     BOOLEAN;
  v_is_creator   BOOLEAN;
  v_next_admin   UUID;
  v_member_count INT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  -- Üyelik kontrolü
  IF NOT EXISTS (
    SELECT 1 FROM conversation_members
    WHERE conversation_id = p_conv_id AND user_id = v_uid
  ) THEN
    RAISE EXCEPTION 'not a member';
  END IF;

  SELECT is_group, (created_by = v_uid)
    INTO v_is_group, v_is_creator
    FROM conversations WHERE id = p_conv_id;

  -- Kalan üye sayısı
  SELECT count(*) INTO v_member_count
    FROM conversation_members WHERE conversation_id = p_conv_id;

  -- Son üyeyse konuşmayı tamamen sil (CASCADE members + messages temizler)
  IF v_member_count <= 1 THEN
    DELETE FROM conversations WHERE id = p_conv_id;
    RETURN;
  END IF;

  -- Grup admin'i ayrılıyorsa yöneticiliği en eski üyeye transfer et
  IF v_is_group AND v_is_creator THEN
    SELECT user_id INTO v_next_admin
      FROM conversation_members
      WHERE conversation_id = p_conv_id AND user_id <> v_uid
      ORDER BY joined_at ASC
      LIMIT 1;

    IF v_next_admin IS NOT NULL THEN
      UPDATE conversations SET created_by = v_next_admin WHERE id = p_conv_id;
    END IF;
  END IF;

  -- Kendini üyelikten çıkar
  DELETE FROM conversation_members
    WHERE conversation_id = p_conv_id AND user_id = v_uid;
END $$;

GRANT EXECUTE ON FUNCTION public.leave_conversation(UUID) TO authenticated;

-- ── 2. delete_conversation ────────────────────────────────────────────────────
-- Yalnızca grup admin'i (created_by) çağırabilir. CASCADE ile tüm üyeler
-- ve mesajlar silinir.

CREATE OR REPLACE FUNCTION public.delete_conversation(p_conv_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  -- Yalnızca oluşturan (admin) silebilir
  IF NOT EXISTS (
    SELECT 1 FROM conversations
    WHERE id = p_conv_id AND created_by = v_uid
  ) THEN
    RAISE EXCEPTION 'only admin can delete group';
  END IF;

  DELETE FROM conversations WHERE id = p_conv_id;
END $$;

GRANT EXECUTE ON FUNCTION public.delete_conversation(UUID) TO authenticated;

-- ── 3. rename_conversation ────────────────────────────────────────────────────
-- Yalnızca grup admin'i grup ismini değiştirebilir.

CREATE OR REPLACE FUNCTION public.rename_conversation(p_conv_id UUID, p_title TEXT)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF p_title IS NULL OR length(btrim(p_title)) = 0 THEN
    RAISE EXCEPTION 'title required';
  END IF;

  -- Yalnızca admin + grup olan konuşma
  IF NOT EXISTS (
    SELECT 1 FROM conversations
    WHERE id = p_conv_id AND created_by = v_uid AND is_group = true
  ) THEN
    RAISE EXCEPTION 'only admin can rename group';
  END IF;

  UPDATE conversations SET title = btrim(p_title) WHERE id = p_conv_id;
END $$;

GRANT EXECUTE ON FUNCTION public.rename_conversation(UUID, TEXT) TO authenticated;

-- ── 4. PostgREST schema cache reload ──────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
