-- ============================================================================
-- DMT — conversations RLS fix
-- ============================================================================
-- Yeni bir DM/grup açılırken RLS hatası (42501) alınıyordu. Sorun zincirleme:
--
--   1) `conversations` INSERT policy'si `auth.uid() = created_by` bekliyor →
--      client satırı doğru ekliyor, ama aynı statement'taki `RETURNING *`
--      sırasında SELECT policy'si `is_conversation_member(id)` üyelik ister;
--      satır henüz `conversation_members` içinde olmadığı için dönüş boş kalır
--      ve PostgREST bunu RLS ihlali olarak yüzeye vurur.
--   2) `conversation_members` INSERT policy'si `auth.uid() = user_id OR
--      is_conversation_member(conversation_id)`. Tek batch insert'te karşı
--      tarafı eklerken `is_conversation_member` STABLE olduğundan aynı
--      statement içinde oluşan yeni satırı göremez.
--
-- Çözüm: DM ve grup oluşturmayı SECURITY DEFINER RPC'lerin içine taşıyoruz.
-- RPC içinde RLS devre dışı çalışır; auth.uid() kontrolünü fonksiyon manuel
-- yapar. Client artık tekil `rpc(...)` çağrısı yapar, tablolara doğrudan
-- INSERT etmez.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

-- ── 1. open_direct_conversation ───────────────────────────────────────────
-- İki kullanıcı arasındaki DM'i bulur; yoksa yaratır. Her hâlükârda
-- conversation_id döner.

CREATE OR REPLACE FUNCTION public.open_direct_conversation(p_other_user UUID)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid      UUID := auth.uid();
  v_conv_id  UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF p_other_user IS NULL OR p_other_user = v_uid THEN
    RAISE EXCEPTION 'invalid counterparty';
  END IF;

  -- Mevcut DM var mı? (is_group=false, tam olarak iki üye: v_uid ve p_other_user)
  SELECT c.id INTO v_conv_id
    FROM public.conversations c
    JOIN public.conversation_members m1 ON m1.conversation_id = c.id AND m1.user_id = v_uid
    JOIN public.conversation_members m2 ON m2.conversation_id = c.id AND m2.user_id = p_other_user
   WHERE c.is_group = false
     AND (SELECT COUNT(*) FROM public.conversation_members mm WHERE mm.conversation_id = c.id) = 2
   LIMIT 1;

  IF v_conv_id IS NOT NULL THEN
    RETURN v_conv_id;
  END IF;

  INSERT INTO public.conversations (is_group, created_by)
  VALUES (false, v_uid)
  RETURNING id INTO v_conv_id;

  INSERT INTO public.conversation_members (conversation_id, user_id)
  VALUES (v_conv_id, v_uid), (v_conv_id, p_other_user);

  RETURN v_conv_id;
END $$;

GRANT EXECUTE ON FUNCTION public.open_direct_conversation(UUID) TO authenticated;

-- ── 2. create_group_conversation ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.create_group_conversation(
  p_title   TEXT,
  p_members UUID[]
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid     UUID := auth.uid();
  v_conv_id UUID;
  v_member  UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF p_title IS NULL OR length(btrim(p_title)) = 0 THEN
    RAISE EXCEPTION 'title required';
  END IF;

  INSERT INTO public.conversations (is_group, title, created_by)
  VALUES (true, p_title, v_uid)
  RETURNING id INTO v_conv_id;

  -- Yaratıcıyı her zaman ekle.
  INSERT INTO public.conversation_members (conversation_id, user_id)
  VALUES (v_conv_id, v_uid)
  ON CONFLICT DO NOTHING;

  IF p_members IS NOT NULL THEN
    FOREACH v_member IN ARRAY p_members LOOP
      IF v_member IS NOT NULL AND v_member <> v_uid THEN
        INSERT INTO public.conversation_members (conversation_id, user_id)
        VALUES (v_conv_id, v_member)
        ON CONFLICT DO NOTHING;
      END IF;
    END LOOP;
  END IF;

  RETURN v_conv_id;
END $$;

GRANT EXECUTE ON FUNCTION public.create_group_conversation(TEXT, UUID[]) TO authenticated;

-- ── 3. Conversations SELECT policy — creator da okuyabilsin ───────────────
-- RPC akışı dışında (örn. realtime stream, `select *`) yaratıcının konuşmasını
-- görebilmesi garantiye alınır. Üyelik kontrolü zaten asıl güvenlik katmanı.

DROP POLICY IF EXISTS "Conversations: members read" ON public.conversations;
CREATE POLICY "Conversations: members read"
  ON public.conversations FOR SELECT
  USING (
    public.is_conversation_member(id)
    OR auth.uid() = created_by
  );

-- ── 4. PostgREST schema cache reload ──────────────────────────────────────
NOTIFY pgrst, 'reload schema';
