-- ============================================================================
-- 109 — Dünyaya katılma DM onayına bağlanır + iki self-insert açığı kapanır
-- ============================================================================
-- Güvenlik raporu (GuardLayer): iki INSERT politikası, id'yi bilen herkesin
-- kendini bir dünyaya / konuşmaya eklemesine izin veriyordu.
--   • "Members: self player insert" (027, 075) — davet, dünya ya da kovulma
--     kontrolü yoktu; kovulan oyuncu dünya id'siyle geri girebiliyordu.
--   • "Self-add to conversation" (003, 075) — özel DM'ler dahil her
--     konuşmaya girip mesajları okumak mümkündü.
-- İkisinin de meşru yolu zaten SECURITY DEFINER RPC'ler (redeem_world_invite,
-- open_direct_conversation, create_group_conversation, add_conversation_member);
-- client bu tablolara doğrudan INSERT etmiyor.
--
-- Yeni akış:
--   Oyuncu → redeem_world_invite(kod) — artık üye yapmaz, world_join_requests'e
--            bekleyen istek yazar (status='pending'). Zaten üyeyse 'member'.
--            Bir dünyada aynı anda en fazla 10 bekleyen istek; 11. istek hiç
--            kaydedilmez (P0005).
--   DM     → answer_join_request(dünya, kullanıcı, kabul) — istek silinir;
--            kabulde oyuncu world_members'a 'player' olarak eklenir.
--
-- İdempotent.
-- ============================================================================

-- ── A — Açık politikalar ────────────────────────────────────────────────────

DROP POLICY IF EXISTS "Members: self player insert" ON public.world_members;
DROP POLICY IF EXISTS "Self-add to conversation" ON public.conversation_members;

-- ── B — Bekleyen istekler ───────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.world_join_requests (
  world_id     TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (world_id, user_id)
);

-- Yazma politikası yok: tek kapı iki RPC. DM dünyasının isteklerini, oyuncu
-- kendi isteğini görür.
ALTER TABLE public.world_join_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "JoinReq: dm or self read" ON public.world_join_requests;
CREATE POLICY "JoinReq: dm or self read"
  ON public.world_join_requests FOR SELECT
  USING (public.is_world_dm(world_id) OR user_id = (SELECT auth.uid()));

-- ── C — redeem_world_invite: üyelik yerine istek ────────────────────────────
-- Dönüş tipine status eklendiği için CREATE OR REPLACE yetmez.

DROP FUNCTION IF EXISTS public.redeem_world_invite(TEXT);
CREATE FUNCTION public.redeem_world_invite(p_code TEXT)
RETURNS TABLE (world_id TEXT, world_name TEXT, status TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
#variable_conflict use_column
DECLARE
  v_uid        UUID := auth.uid();
  v_world_id   TEXT;
  v_world_name TEXT;
  v_uses_left  INT;
  v_expires_at TIMESTAMPTZ;
  v_status     TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth required';
  END IF;

  SELECT i.world_id, i.uses_left, i.expires_at
    INTO v_world_id, v_uses_left, v_expires_at
  FROM public.world_invites i
  WHERE i.code = upper(p_code)
  FOR UPDATE;

  IF v_world_id IS NULL THEN
    RAISE EXCEPTION 'invite not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_uses_left <= 0 THEN
    RAISE EXCEPTION 'invite exhausted' USING ERRCODE = 'P0003';
  END IF;
  IF v_expires_at IS NOT NULL AND v_expires_at < now() THEN
    RAISE EXCEPTION 'invite expired' USING ERRCODE = 'P0004';
  END IF;

  -- Dünya satırı kilidi: aynı dünyaya farklı kodlarla gelen eşzamanlı
  -- istekler sırayla sayılır, sınır aşılamaz.
  SELECT w.world_name INTO v_world_name
  FROM public.worlds w
  WHERE w.id = v_world_id
  FOR UPDATE;

  IF EXISTS (SELECT 1 FROM public.world_members m
              WHERE m.world_id = v_world_id AND m.user_id = v_uid) THEN
    v_status := 'member';
  ELSIF EXISTS (SELECT 1 FROM public.world_join_requests r
                 WHERE r.world_id = v_world_id AND r.user_id = v_uid) THEN
    v_status := 'pending';
  ELSE
    IF (SELECT count(*) FROM public.world_join_requests r
         WHERE r.world_id = v_world_id) >= 10 THEN
      RAISE EXCEPTION 'join request limit' USING ERRCODE = 'P0005';
    END IF;
    INSERT INTO public.world_join_requests (world_id, user_id)
    VALUES (v_world_id, v_uid);
    UPDATE public.world_invites i
       SET uses_left = i.uses_left - 1
     WHERE i.code = upper(p_code);
    v_status := 'pending';
  END IF;

  RETURN QUERY SELECT v_world_id, v_world_name, v_status;
END $$;

REVOKE ALL ON FUNCTION public.redeem_world_invite(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.redeem_world_invite(TEXT) TO authenticated;

-- ── D — answer_join_request (DM) ────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.answer_join_request(
  p_world_id TEXT,
  p_user_id  UUID,
  p_accept   BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required';
  END IF;
  IF NOT public.is_world_dm(p_world_id) THEN
    RAISE EXCEPTION 'dm only' USING ERRCODE = '42501';
  END IF;

  DELETE FROM public.world_join_requests
   WHERE world_id = p_world_id AND user_id = p_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'join request not found' USING ERRCODE = 'P0002';
  END IF;

  IF p_accept THEN
    INSERT INTO public.world_members (world_id, user_id, role)
    VALUES (p_world_id, p_user_id, 'player')
    ON CONFLICT (world_id, user_id) DO NOTHING;
  END IF;
END $$;

REVOKE ALL ON FUNCTION public.answer_join_request(TEXT, UUID, BOOLEAN)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.answer_join_request(TEXT, UUID, BOOLEAN)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
