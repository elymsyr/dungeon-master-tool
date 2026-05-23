-- ============================================================================
-- 066_beta_access_requests.sql — beta access by admin approval
-- ============================================================================
-- Beta artık doğrudan join_beta ile alınmıyor; kullanıcı opsiyonel mesajla
-- istek atar, admin panelinden onaylanır/reddedilir. Slot allocation sadece
-- admin yolunda yapılır.
--
-- Yapılan:
--   1. beta_requests tablosu (PK user_id, mesaj ≤500).
--   2. _grant_beta_slot(uid) helper — join_beta'nın slot-alma gövdesi taşındı.
--   3. join_beta() davranış değişti — slot yerine request oluşturur.
--      Status enum: requested | already | pending | not_signed_in.
--   4. request_beta(p_message) — UPSERT mesaj ile birlikte.
--   5. cancel_beta_request() — kullanıcı kendi isteğini geri çeker.
--   6. admin_list_beta_requests() — admin paneli okuma RPC'si.
--   7. admin_approve_beta_request / admin_reject_beta_request — onay/ret.
--   8. get_beta_status() — request_pending + request_message + requested_at
--      alanları eklendi.
-- ============================================================================

-- ── 1. beta_requests tablosu ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.beta_requests (
  user_id      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  message      TEXT,
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT beta_requests_message_len
    CHECK (message IS NULL OR length(message) <= 500)
);

CREATE INDEX IF NOT EXISTS idx_beta_requests_requested_at
  ON public.beta_requests (requested_at DESC);

ALTER TABLE public.beta_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "beta_requests self read" ON public.beta_requests;
CREATE POLICY "beta_requests self read"
  ON public.beta_requests FOR SELECT
  USING (auth.uid() = user_id);

-- Mutasyon yok — tüm yazma SECURITY DEFINER RPC'lerden.

-- ── 2. _grant_beta_slot(uid) — internal slot allocation ────────────────────
-- 007 join_beta gövdesinden çıkartıldı. Status: granted|already|full|invalid_user
CREATE OR REPLACE FUNCTION public._grant_beta_slot(p_user UUID)
RETURNS TABLE (status TEXT, assigned_slot INT, slots_remaining INT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_cap   INT := public.beta_slot_cap();
  v_count INT;
  v_slot  INT;
BEGIN
  IF p_user IS NULL THEN
    RETURN QUERY SELECT 'invalid_user'::TEXT, NULL::INT, v_cap;
    RETURN;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('beta_join_lock'));

  IF EXISTS (SELECT 1 FROM public.beta_participants bp WHERE bp.user_id = p_user) THEN
    SELECT bp.slot_number INTO v_slot
      FROM public.beta_participants bp WHERE bp.user_id = p_user;
    RETURN QUERY
      SELECT
        'already'::TEXT,
        v_slot,
        GREATEST(0, v_cap - (SELECT count(*)::int FROM public.beta_participants));
    RETURN;
  END IF;

  SELECT count(*)::int INTO v_count FROM public.beta_participants;
  IF v_count >= v_cap THEN
    RETURN QUERY SELECT 'full'::TEXT, NULL::INT, 0;
    RETURN;
  END IF;

  SELECT COALESCE(
    (SELECT MIN(n) FROM generate_series(1, v_cap) n
       WHERE n NOT IN (SELECT bp.slot_number FROM public.beta_participants bp WHERE bp.slot_number IS NOT NULL)),
    v_count + 1
  ) INTO v_slot;

  INSERT INTO public.beta_participants (user_id, slot_number)
    VALUES (p_user, v_slot);

  RETURN QUERY
    SELECT 'granted'::TEXT, v_slot, v_cap - (v_count + 1);
END $$;

REVOKE ALL ON FUNCTION public._grant_beta_slot(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._grant_beta_slot(UUID) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public._grant_beta_slot(UUID) TO service_role;

-- ── 3. join_beta() — request oluşturma davranışı ──────────────────────────
-- Eski 007 imzası korunur; status enum'ı genişledi:
--   not_signed_in | already | pending | requested
-- (Eski 'joined' / 'full' artık dönmez — slot allocation admin yolunda.)
CREATE OR REPLACE FUNCTION public.join_beta()
RETURNS TABLE (status TEXT, assigned_slot INT, slots_remaining INT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_user   UUID := auth.uid();
  v_cap    INT  := public.beta_slot_cap();
  v_remain INT;
  v_slot   INT;
BEGIN
  IF v_user IS NULL THEN
    RETURN QUERY SELECT 'not_signed_in'::TEXT, NULL::INT, v_cap;
    RETURN;
  END IF;

  v_remain := GREATEST(0, v_cap - (SELECT count(*)::int FROM public.beta_participants));

  IF EXISTS (SELECT 1 FROM public.beta_participants bp WHERE bp.user_id = v_user) THEN
    SELECT bp.slot_number INTO v_slot
      FROM public.beta_participants bp WHERE bp.user_id = v_user;
    RETURN QUERY SELECT 'already'::TEXT, v_slot, v_remain;
    RETURN;
  END IF;

  IF EXISTS (SELECT 1 FROM public.beta_requests WHERE user_id = v_user) THEN
    RETURN QUERY SELECT 'pending'::TEXT, NULL::INT, v_remain;
    RETURN;
  END IF;

  INSERT INTO public.beta_requests (user_id, message)
    VALUES (v_user, NULL);

  RETURN QUERY SELECT 'requested'::TEXT, NULL::INT, v_remain;
END $$;

GRANT EXECUTE ON FUNCTION public.join_beta() TO authenticated;

-- ── 4. request_beta(p_message) — opsiyonel mesajla ─────────────────────────
-- Status: requested | already_active | already_pending | not_signed_in
-- Var olan request'i overwrite eder (kullanıcı mesajı güncelleyebilir).
CREATE OR REPLACE FUNCTION public.request_beta(p_message TEXT)
RETURNS TABLE (status TEXT, slots_remaining INT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_user   UUID := auth.uid();
  v_cap    INT  := public.beta_slot_cap();
  v_remain INT;
  v_msg    TEXT;
BEGIN
  IF v_user IS NULL THEN
    RETURN QUERY SELECT 'not_signed_in'::TEXT, v_cap;
    RETURN;
  END IF;

  v_remain := GREATEST(0, v_cap - (SELECT count(*)::int FROM public.beta_participants));

  IF EXISTS (SELECT 1 FROM public.beta_participants bp WHERE bp.user_id = v_user) THEN
    RETURN QUERY SELECT 'already_active'::TEXT, v_remain;
    RETURN;
  END IF;

  v_msg := NULLIF(btrim(COALESCE(p_message, '')), '');
  IF v_msg IS NOT NULL AND length(v_msg) > 500 THEN
    v_msg := left(v_msg, 500);
  END IF;

  IF EXISTS (SELECT 1 FROM public.beta_requests WHERE user_id = v_user) THEN
    UPDATE public.beta_requests
       SET message = v_msg,
           requested_at = now()
     WHERE user_id = v_user;
    RETURN QUERY SELECT 'already_pending'::TEXT, v_remain;
    RETURN;
  END IF;

  INSERT INTO public.beta_requests (user_id, message) VALUES (v_user, v_msg);
  RETURN QUERY SELECT 'requested'::TEXT, v_remain;
END $$;

GRANT EXECUTE ON FUNCTION public.request_beta(TEXT) TO authenticated;

-- ── 5. cancel_beta_request() ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.cancel_beta_request()
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN RETURN FALSE; END IF;
  DELETE FROM public.beta_requests WHERE user_id = v_user;
  RETURN FOUND;
END $$;

GRANT EXECUTE ON FUNCTION public.cancel_beta_request() TO authenticated;

-- ── 6. admin_list_beta_requests() ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_list_beta_requests()
RETURNS TABLE (
  user_id      UUID,
  email        TEXT,
  username     TEXT,
  message      TEXT,
  requested_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    br.user_id,
    u.email::TEXT,
    p.username,
    br.message,
    br.requested_at
  FROM public.beta_requests br
  LEFT JOIN auth.users u ON u.id = br.user_id
  LEFT JOIN public.profiles p ON p.user_id = br.user_id
  ORDER BY br.requested_at ASC;
END $$;

GRANT EXECUTE ON FUNCTION public.admin_list_beta_requests() TO authenticated;

-- ── 7. admin_approve_beta_request(p_user) ──────────────────────────────────
-- _grant_beta_slot çağırır; başarılı (granted/already) ise request silinir.
CREATE OR REPLACE FUNCTION public.admin_approve_beta_request(p_user UUID)
RETURNS TABLE (status TEXT, assigned_slot INT, slots_remaining INT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_row    RECORD;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  IF p_user IS NULL THEN
    RETURN QUERY SELECT 'invalid_user'::TEXT, NULL::INT, 0;
    RETURN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.beta_requests br WHERE br.user_id = p_user) THEN
    RETURN QUERY SELECT 'not_pending'::TEXT, NULL::INT, 0;
    RETURN;
  END IF;

  SELECT * INTO v_row FROM public._grant_beta_slot(p_user);

  IF v_row.status IN ('granted', 'already') THEN
    DELETE FROM public.beta_requests WHERE user_id = p_user;

    INSERT INTO public.admin_audit_log (admin_id, action, target_user_id, meta)
    VALUES (
      auth.uid(),
      'beta_approve',
      p_user,
      jsonb_build_object('slot', v_row.assigned_slot)
    );
  END IF;

  RETURN QUERY SELECT v_row.status, v_row.assigned_slot, v_row.slots_remaining;
END $$;

GRANT EXECUTE ON FUNCTION public.admin_approve_beta_request(UUID) TO authenticated;

-- ── 8. admin_reject_beta_request(p_user) ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_reject_beta_request(p_user UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_existed BOOLEAN := FALSE;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  IF p_user IS NULL THEN RETURN FALSE; END IF;

  DELETE FROM public.beta_requests WHERE user_id = p_user;
  GET DIAGNOSTICS v_existed = ROW_COUNT;

  IF v_existed THEN
    INSERT INTO public.admin_audit_log (admin_id, action, target_user_id)
    VALUES (auth.uid(), 'beta_reject', p_user);
  END IF;

  RETURN v_existed;
END $$;

GRANT EXECUTE ON FUNCTION public.admin_reject_beta_request(UUID) TO authenticated;

-- ── 9. get_beta_status() — request_* alanları eklendi ──────────────────────
-- DROP gerekli: return TABLE shape değişti (Postgres CREATE OR REPLACE
-- function signature'ı değiştiremez).
DROP FUNCTION IF EXISTS public.get_beta_status();
CREATE OR REPLACE FUNCTION public.get_beta_status()
RETURNS TABLE (
  is_active       BOOLEAN,
  joined_at       TIMESTAMPTZ,
  last_active_at  TIMESTAMPTZ,
  slot_number     INT,
  slots_remaining INT,
  slot_cap        INT,
  quota_bytes     BIGINT,
  used_bytes      BIGINT,
  inactivity_days INT,
  request_pending BOOLEAN,
  request_message TEXT,
  requested_at    TIMESTAMPTZ
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_user UUID := auth.uid();
BEGIN
  RETURN QUERY
  SELECT
    (bp.user_id IS NOT NULL)::boolean AS is_active,
    bp.joined_at,
    bp.last_active_at,
    bp.slot_number,
    GREATEST(0, public.beta_slot_cap()
             - (SELECT count(*)::int FROM public.beta_participants))::int
      AS slots_remaining,
    public.beta_slot_cap() AS slot_cap,
    public.beta_user_quota_bytes() AS quota_bytes,
    CASE WHEN v_user IS NULL THEN 0::bigint
         ELSE COALESCE(public.get_beta_quota_used(v_user), 0)
    END AS used_bytes,
    public.beta_inactivity_days() AS inactivity_days,
    (br.user_id IS NOT NULL)::boolean AS request_pending,
    br.message AS request_message,
    br.requested_at AS requested_at
  FROM (SELECT v_user AS uid) u
  LEFT JOIN public.beta_participants bp ON bp.user_id = u.uid
  LEFT JOIN public.beta_requests br ON br.user_id = u.uid;
END $$;

GRANT EXECUTE ON FUNCTION public.get_beta_status() TO authenticated, anon;

NOTIFY pgrst, 'reload schema';
