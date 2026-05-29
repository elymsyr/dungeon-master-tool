-- ============================================================================
-- 069_notifications.sql
--   Admin broadcast notifications.
--   • notifications          — admin yayınladığı bildirim (başlık + blok JSONB).
--   • notification_responses — kullanıcının poll/input yanıtları (user başına 1).
--   • notification_reads     — okundu takibi (rozet için).
--   Bloklar: [{id,type:'markdown',text} | {id,type:'poll',question,options[],multiple}
--             | {id,type:'input',prompt,multiline}]
--   Yanıt answers: { "<block_id>": {"choice":[0,..]} | {"text":"..."} }
--   RLS: notifications published → herkes okur; yazma yalnız SECURITY DEFINER RPC.
--   Realtime: notifications + notification_responses publication'a eklenir.
-- ============================================================================

-- ── 1. notifications ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notifications (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  title      TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 200),
  blocks     JSONB NOT NULL DEFAULT '[]'::jsonb,
  published  BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_created_at
  ON public.notifications (created_at DESC);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Yayınlanmış bildirimleri herkes okur; admin hepsini görür.
DROP POLICY IF EXISTS "notifications read" ON public.notifications;
CREATE POLICY "notifications read"
  ON public.notifications FOR SELECT
  USING (published OR public.is_admin());

-- İstemci yazamaz (yalnız RPC).
DROP POLICY IF EXISTS "notifications no client write" ON public.notifications;
CREATE POLICY "notifications no client write"
  ON public.notifications FOR INSERT
  WITH CHECK (false);

-- ── 2. notification_responses ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notification_responses (
  id              BIGSERIAL PRIMARY KEY,
  notification_id UUID NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  answers         JSONB NOT NULL DEFAULT '{}'::jsonb,
  submitted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT notification_responses_uniq UNIQUE (notification_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_notification_responses_notif
  ON public.notification_responses (notification_id);

ALTER TABLE public.notification_responses ENABLE ROW LEVEL SECURITY;

-- Kullanıcı kendi yanıtını, admin tümünü okur.
DROP POLICY IF EXISTS "notification_responses read" ON public.notification_responses;
CREATE POLICY "notification_responses read"
  ON public.notification_responses FOR SELECT
  USING (auth.uid() = user_id OR public.is_admin());

-- İstemci doğrudan yazamaz (yalnız submit RPC).
DROP POLICY IF EXISTS "notification_responses no client write" ON public.notification_responses;
CREATE POLICY "notification_responses no client write"
  ON public.notification_responses FOR INSERT
  WITH CHECK (false);

-- ── 3. notification_reads ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.notification_reads (
  notification_id UUID NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  read_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (notification_id, user_id)
);

ALTER TABLE public.notification_reads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notification_reads self read" ON public.notification_reads;
CREATE POLICY "notification_reads self read"
  ON public.notification_reads FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "notification_reads self write" ON public.notification_reads;
CREATE POLICY "notification_reads self write"
  ON public.notification_reads FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ── 3b. notification_dismissals ────────────────────────────────────────────
-- Kullanıcının kendi gelen kutusundan kalıcı kaldırdığı bildirimler (per-user).
CREATE TABLE IF NOT EXISTS public.notification_dismissals (
  notification_id UUID NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  dismissed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (notification_id, user_id)
);

ALTER TABLE public.notification_dismissals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notification_dismissals self read" ON public.notification_dismissals;
CREATE POLICY "notification_dismissals self read"
  ON public.notification_dismissals FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "notification_dismissals self write" ON public.notification_dismissals;
CREATE POLICY "notification_dismissals self write"
  ON public.notification_dismissals FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ── 4. admin_create_notification ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_create_notification(
  p_title TEXT,
  p_blocks JSONB
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id UUID;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF p_title IS NULL OR length(btrim(p_title)) = 0 THEN
    RAISE EXCEPTION 'title required';
  END IF;

  INSERT INTO public.notifications (admin_id, title, blocks)
  VALUES (auth.uid(), btrim(p_title), COALESCE(p_blocks, '[]'::jsonb))
  RETURNING id INTO v_id;

  INSERT INTO public.admin_audit_log (admin_id, action, target_entity_id)
  VALUES (auth.uid(), 'notification_create', v_id::TEXT);

  RETURN v_id;
END $$;

GRANT EXECUTE ON FUNCTION public.admin_create_notification(TEXT, JSONB) TO authenticated;

-- ── 5. admin_delete_notification ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_delete_notification(p_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF p_id IS NULL THEN RETURN FALSE; END IF;

  DELETE FROM public.notifications WHERE id = p_id;

  INSERT INTO public.admin_audit_log (admin_id, action, target_entity_id)
  VALUES (auth.uid(), 'notification_delete', p_id::TEXT);

  RETURN TRUE;
END $$;

GRANT EXECUTE ON FUNCTION public.admin_delete_notification(UUID) TO authenticated;

-- ── 6. admin_list_notifications ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_list_notifications()
RETURNS TABLE (
  id             UUID,
  title          TEXT,
  blocks         JSONB,
  created_at     TIMESTAMPTZ,
  response_count BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    n.id,
    n.title,
    n.blocks,
    n.created_at,
    COALESCE(r.cnt, 0) AS response_count
  FROM public.notifications n
  LEFT JOIN (
    SELECT notification_id, COUNT(DISTINCT user_id) AS cnt
    FROM public.notification_responses
    GROUP BY notification_id
  ) r ON r.notification_id = n.id
  ORDER BY n.created_at DESC;
END $$;

GRANT EXECUTE ON FUNCTION public.admin_list_notifications() TO authenticated;

-- ── 7. admin_notification_responses ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_notification_responses(p_id UUID)
RETURNS TABLE (
  user_id      UUID,
  username     TEXT,
  answers      JSONB,
  submitted_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    nr.user_id,
    p.username AS username,
    nr.answers,
    nr.submitted_at
  FROM public.notification_responses nr
  LEFT JOIN public.profiles p ON p.user_id = nr.user_id
  WHERE nr.notification_id = p_id
  ORDER BY nr.submitted_at DESC;
END $$;

GRANT EXECUTE ON FUNCTION public.admin_notification_responses(UUID) TO authenticated;

-- ── 8. list_notifications (user inbox) ─────────────────────────────────────
-- Yayınlanmış bildirimler + caller'ın kendi yanıtı + okundu flag (tek çağrı).
CREATE OR REPLACE FUNCTION public.list_notifications()
RETURNS TABLE (
  id         UUID,
  title      TEXT,
  blocks     JSONB,
  created_at TIMESTAMPTZ,
  my_answers JSONB,
  read       BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN RETURN; END IF;

  RETURN QUERY
  SELECT
    n.id,
    n.title,
    n.blocks,
    n.created_at,
    nr.answers AS my_answers,
    (rd.user_id IS NOT NULL) AS read
  FROM public.notifications n
  LEFT JOIN public.notification_responses nr
    ON nr.notification_id = n.id AND nr.user_id = v_user
  LEFT JOIN public.notification_reads rd
    ON rd.notification_id = n.id AND rd.user_id = v_user
  LEFT JOIN public.notification_dismissals dm
    ON dm.notification_id = n.id AND dm.user_id = v_user
  WHERE n.published AND dm.notification_id IS NULL
  ORDER BY n.created_at DESC;
END $$;

GRANT EXECUTE ON FUNCTION public.list_notifications() TO authenticated;

-- ── 9. submit_notification_response ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.submit_notification_response(
  p_id UUID,
  p_answers JSONB
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN RETURN FALSE; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.notifications WHERE id = p_id AND published
  ) THEN
    RAISE EXCEPTION 'notification not found';
  END IF;

  INSERT INTO public.notification_responses (notification_id, user_id, answers)
  VALUES (p_id, v_user, COALESCE(p_answers, '{}'::jsonb))
  ON CONFLICT (notification_id, user_id)
  DO UPDATE SET answers = EXCLUDED.answers, updated_at = now();

  RETURN TRUE;
END $$;

GRANT EXECUTE ON FUNCTION public.submit_notification_response(UUID, JSONB) TO authenticated;

-- ── 10. mark_notification_read ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.mark_notification_read(p_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN RETURN; END IF;
  INSERT INTO public.notification_reads (notification_id, user_id)
  VALUES (p_id, v_user)
  ON CONFLICT (notification_id, user_id) DO NOTHING;
END $$;

GRANT EXECUTE ON FUNCTION public.mark_notification_read(UUID) TO authenticated;

-- ── 10b. dismiss_read_notifications ────────────────────────────────────────
-- Caller'ın okuduğu tüm bildirimleri kendi gelen kutusundan kalıcı kaldırır.
-- Kaldırılan satır sayısını döner.
CREATE OR REPLACE FUNCTION public.dismiss_read_notifications()
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user  UUID := auth.uid();
  v_count INT;
BEGIN
  IF v_user IS NULL THEN RETURN 0; END IF;

  INSERT INTO public.notification_dismissals (notification_id, user_id)
  SELECT rd.notification_id, v_user
  FROM public.notification_reads rd
  JOIN public.notifications n ON n.id = rd.notification_id AND n.published
  WHERE rd.user_id = v_user
  ON CONFLICT (notification_id, user_id) DO NOTHING;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END $$;

GRANT EXECUTE ON FUNCTION public.dismiss_read_notifications() TO authenticated;

-- ── 11. Realtime publication + REPLICA IDENTITY FULL ───────────────────────
ALTER TABLE public.notifications          REPLICA IDENTITY FULL;
ALTER TABLE public.notification_responses REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public' AND tablename = 'notifications'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public' AND tablename = 'notification_responses'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.notification_responses;
    END IF;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
