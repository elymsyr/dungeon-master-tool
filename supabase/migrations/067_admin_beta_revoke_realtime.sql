-- ============================================================================
-- 067_admin_beta_revoke_realtime.sql
--   • Realtime publication: beta_requests + beta_participants → kullanıcı
--     admin tarafından onay/ret/revoke aldığında istemci tarafı UI otomatik
--     refresh olur (realtime CDC ile).
--   • _purge_beta_user(p_user) helper: leave_beta gövdesi çıkartıldı; admin
--     revoke yolu da aynı tam-temizliği kullanır.
--   • leave_beta() yeni helper'a delege olur (davranış değişmez).
--   • admin_list_beta_participants() — admin paneli için aktif beta liste +
--     storage kullanımı + last_active_at + app_version + platform.
--   • admin_revoke_beta(p_user) — admin gate; _purge_beta_user çağırır,
--     admin_audit_log 'beta_revoke' satırı yazar.
-- ============================================================================

-- ── 1. Realtime publication + REPLICA IDENTITY FULL ────────────────────────
ALTER TABLE public.beta_requests     REPLICA IDENTITY FULL;
ALTER TABLE public.beta_participants REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication
    WHERE pubname = 'supabase_realtime'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'beta_requests'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.beta_requests;
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'beta_participants'
    ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.beta_participants;
    END IF;
  END IF;
END $$;

-- ── 2. _purge_beta_user(p_user) — admin + leave_beta ortak gövdesi ─────────
-- 057 leave_beta gövdesi çıkartıldı. Slot satırı da burada silinir.
CREATE OR REPLACE FUNCTION public._purge_beta_user(p_user UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF p_user IS NULL THEN
    RETURN FALSE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.beta_participants WHERE user_id = p_user) THEN
    RETURN FALSE;
  END IF;

  DELETE FROM public.worlds                    WHERE owner_id    = p_user;
  DELETE FROM public.world_characters
   WHERE owner_id = p_user AND world_id IS NULL;
  DELETE FROM public.personal_package_entities WHERE owner_id    = p_user;
  DELETE FROM public.personal_packages         WHERE owner_id    = p_user;
  DELETE FROM public.marketplace_listings      WHERE owner_id    = p_user;
  DELETE FROM public.free_media_assets         WHERE owner_id    = p_user;
  DELETE FROM public.community_assets          WHERE uploader_id = p_user;
  DELETE FROM public.transient_shares          WHERE uploader_id = p_user;
  DELETE FROM public.cloud_backups             WHERE user_id     = p_user;
  -- Bekleyen istek varsa onu da düşür (admin revoke + tekrar request senaryosu).
  DELETE FROM public.beta_requests             WHERE user_id     = p_user;
  DELETE FROM public.beta_participants         WHERE user_id     = p_user;

  RETURN TRUE;
END $$;

REVOKE ALL ON FUNCTION public._purge_beta_user(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._purge_beta_user(UUID) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public._purge_beta_user(UUID) TO service_role;

-- ── 3. leave_beta() — helper'a delege ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.leave_beta()
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN RETURN FALSE; END IF;
  RETURN public._purge_beta_user(v_user);
END $$;

GRANT EXECUTE ON FUNCTION public.leave_beta() TO authenticated;

-- ── 4. admin_list_beta_participants() ──────────────────────────────────────
-- Aktif beta üyelerini storage + meta ile listeler.
CREATE OR REPLACE FUNCTION public.admin_list_beta_participants()
RETURNS TABLE (
  user_id        UUID,
  email          TEXT,
  username       TEXT,
  slot_number    INT,
  joined_at      TIMESTAMPTZ,
  last_active_at TIMESTAMPTZ,
  used_bytes     BIGINT,
  quota_bytes    BIGINT,
  app_version    TEXT,
  platform       TEXT,
  profile_last_active_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    bp.user_id,
    u.email::TEXT                                       AS email,
    p.username                                          AS username,
    bp.slot_number,
    bp.joined_at,
    bp.last_active_at,
    COALESCE(public.get_beta_quota_used(bp.user_id), 0) AS used_bytes,
    public.beta_user_quota_bytes()                      AS quota_bytes,
    p.app_version                                       AS app_version,
    p.platform                                          AS platform,
    p.last_active_at                                    AS profile_last_active_at
  FROM public.beta_participants bp
  LEFT JOIN auth.users    u ON u.id      = bp.user_id
  LEFT JOIN public.profiles p ON p.user_id = bp.user_id
  ORDER BY bp.slot_number ASC NULLS LAST;
END $$;

GRANT EXECUTE ON FUNCTION public.admin_list_beta_participants() TO authenticated;

-- ── 5. admin_revoke_beta(p_user) ───────────────────────────────────────────
-- Tam temizlik: _purge_beta_user + audit log.
CREATE OR REPLACE FUNCTION public.admin_revoke_beta(p_user UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_ok BOOLEAN;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF p_user IS NULL THEN RETURN FALSE; END IF;

  v_ok := public._purge_beta_user(p_user);

  IF v_ok THEN
    INSERT INTO public.admin_audit_log (admin_id, action, target_user_id)
    VALUES (auth.uid(), 'beta_revoke', p_user);
  END IF;

  RETURN v_ok;
END $$;

GRANT EXECUTE ON FUNCTION public.admin_revoke_beta(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
