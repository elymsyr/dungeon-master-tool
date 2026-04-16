-- ============================================================================
-- DMT Bug Reports + User Activity Tracking
-- ============================================================================
-- Üç blok:
--   (A) public.bug_reports  — in-app bug raporlama (metin-only, RLS + rate limit)
--   (B) profiles.last_active_at — her kullanıcı için activity tracking
--   (C) get_all_users_summary() / search_users() — storage_bytes + last_active_at
--       sütunları ile refresh edilir.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run.
-- ============================================================================

-- ── 1. bug_reports tablosu ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.bug_reports (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  message      TEXT NOT NULL CHECK (char_length(message) BETWEEN 10 AND 4000),
  logs         TEXT,
  app_version  TEXT,
  platform     TEXT,
  status       TEXT NOT NULL DEFAULT 'open'
               CHECK (status IN ('open', 'read', 'resolved')),
  admin_note   TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bug_reports_user_id
  ON public.bug_reports (user_id);
CREATE INDEX IF NOT EXISTS idx_bug_reports_status_created
  ON public.bug_reports (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bug_reports_created_at
  ON public.bug_reports (created_at DESC);

ALTER TABLE public.bug_reports ENABLE ROW LEVEL SECURITY;

-- Kullanıcı kendi raporlarını okuyabilir (geçmiş gönderimlerini görmek için).
DROP POLICY IF EXISTS "bug_reports self read" ON public.bug_reports;
CREATE POLICY "bug_reports self read"
  ON public.bug_reports FOR SELECT
  USING (auth.uid() = user_id);

-- Kullanıcı kendi user_id ile insert edebilir; status 'open' ve admin_note NULL
-- olmak zorunda (client admin alanlarını set edemez).
DROP POLICY IF EXISTS "bug_reports self insert" ON public.bug_reports;
CREATE POLICY "bug_reports self insert"
  ON public.bug_reports FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND status = 'open'
    AND admin_note IS NULL
  );

-- UPDATE/DELETE client'tan yok; admin erişimi SECURITY DEFINER RPC üzerinden.

-- ── 2. updated_at auto-maintenance ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.bug_reports_touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_bug_reports_updated_at ON public.bug_reports;
CREATE TRIGGER trg_bug_reports_updated_at
  BEFORE UPDATE ON public.bug_reports
  FOR EACH ROW EXECUTE FUNCTION public.bug_reports_touch_updated_at();

-- ── 3. Bug report rate limit trigger ────────────────────────────────────────
-- 1 dakika ≤1, 1 saat ≤5. Spam'i önlemek için. Pattern: 007_beta_program
-- enforce_post_rate_limit ile aynı.

CREATE OR REPLACE FUNCTION public.enforce_bug_report_rate_limit()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_1m INT;
  v_1h INT;
BEGIN
  IF NEW.user_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT count(*) INTO v_1m FROM public.bug_reports
    WHERE user_id = NEW.user_id
      AND created_at > now() - interval '1 minute';
  IF v_1m >= 1 THEN
    RAISE EXCEPTION 'bug_report_rate_limit_exceeded (1m: %)', v_1m
      USING ERRCODE = 'check_violation', HINT = 'window=1m';
  END IF;

  SELECT count(*) INTO v_1h FROM public.bug_reports
    WHERE user_id = NEW.user_id
      AND created_at > now() - interval '1 hour';
  IF v_1h >= 5 THEN
    RAISE EXCEPTION 'bug_report_rate_limit_exceeded (1h: %)', v_1h
      USING ERRCODE = 'check_violation', HINT = 'window=1h';
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_bug_report_rate_limit ON public.bug_reports;
CREATE TRIGGER trg_bug_report_rate_limit
  BEFORE INSERT ON public.bug_reports
  FOR EACH ROW EXECUTE FUNCTION public.enforce_bug_report_rate_limit();

-- ── 4. Admin RPC: get_bug_reports(p_status) ─────────────────────────────────
-- p_status NULL veya 'all' → tüm raporlar. Aksi halde filtre.

DROP FUNCTION IF EXISTS public.get_bug_reports(TEXT);
CREATE OR REPLACE FUNCTION public.get_bug_reports(p_status TEXT DEFAULT NULL)
RETURNS TABLE (
  id           UUID,
  user_id      UUID,
  email        TEXT,
  username     TEXT,
  message      TEXT,
  logs         TEXT,
  app_version  TEXT,
  platform     TEXT,
  status       TEXT,
  admin_note   TEXT,
  created_at   TIMESTAMPTZ,
  updated_at   TIMESTAMPTZ
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  RETURN QUERY
  SELECT
    br.id,
    br.user_id,
    u.email::TEXT,
    p.username,
    br.message,
    br.logs,
    br.app_version,
    br.platform,
    br.status,
    br.admin_note,
    br.created_at,
    br.updated_at
  FROM public.bug_reports br
  LEFT JOIN auth.users u      ON u.id = br.user_id
  LEFT JOIN public.profiles p ON p.user_id = br.user_id
  WHERE p_status IS NULL
     OR p_status = 'all'
     OR br.status = p_status
  ORDER BY br.created_at DESC
  LIMIT 500;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_bug_reports(TEXT) TO authenticated;

-- ── 5. Admin RPC: update_bug_report_status(p_id, p_status, p_note) ──────────

CREATE OR REPLACE FUNCTION public.update_bug_report_status(
  p_id     UUID,
  p_status TEXT,
  p_note   TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  IF p_status NOT IN ('open', 'read', 'resolved') THEN
    RAISE EXCEPTION 'invalid status: %', p_status;
  END IF;

  UPDATE public.bug_reports
     SET status     = p_status,
         admin_note = COALESCE(NULLIF(p_note, ''), admin_note)
   WHERE id = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'bug_report % not found', p_id;
  END IF;
END $$;

GRANT EXECUTE ON FUNCTION public.update_bug_report_status(UUID, TEXT, TEXT)
  TO authenticated;

-- ── 6. profiles.last_active_at ──────────────────────────────────────────────
-- Genel amaçlı activity tracking. beta_participants.last_active_at sadece
-- beta kullanıcılar içindi; profiles kolonu tüm auth kullanıcıları kapsar.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_profiles_last_active_at
  ON public.profiles (last_active_at DESC);

-- ── 7. user_heartbeat() RPC ─────────────────────────────────────────────────
-- App başlangıcında çağrılır. Hem profiles hem beta_participants'ı günceller.
-- Eski beta_heartbeat() geriye uyumluluk için bırakılır.

CREATE OR REPLACE FUNCTION public.user_heartbeat()
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RETURN;
  END IF;

  UPDATE public.profiles
     SET last_active_at = now()
   WHERE user_id = v_user;

  UPDATE public.beta_participants
     SET last_active_at = now()
   WHERE user_id = v_user;
END $$;

GRANT EXECUTE ON FUNCTION public.user_heartbeat() TO authenticated;

-- ── 8. get_all_users_summary() ve search_users() refresh ────────────────────
-- RETURNS TABLE sütun sayısı değişiyor, DROP zorunlu.

DROP FUNCTION IF EXISTS public.get_all_users_summary();
DROP FUNCTION IF EXISTS public.search_users(TEXT);

CREATE OR REPLACE FUNCTION public.get_all_users_summary()
RETURNS TABLE (
  user_id        UUID,
  email          TEXT,
  username       TEXT,
  provider       TEXT,
  created_at     TIMESTAMPTZ,
  is_beta        BOOLEAN,
  is_banned      BOOLEAN,
  storage_bytes  BIGINT,
  last_active_at TIMESTAMPTZ
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  RETURN QUERY
  SELECT
    u.id AS user_id,
    u.email::TEXT,
    p.username,
    COALESCE(
      u.raw_app_meta_data->>'provider',
      'email'
    )::TEXT AS provider,
    u.created_at,
    EXISTS (SELECT 1 FROM public.beta_participants b WHERE b.user_id = u.id) AS is_beta,
    EXISTS (SELECT 1 FROM public.banned_users bu WHERE bu.user_id = u.id)  AS is_banned,
    COALESCE(public.get_user_total_storage_used(u.id), 0)::BIGINT AS storage_bytes,
    p.last_active_at
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.user_id = u.id
  ORDER BY u.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_all_users_summary() TO authenticated;

CREATE OR REPLACE FUNCTION public.search_users(p_query TEXT)
RETURNS TABLE (
  user_id        UUID,
  email          TEXT,
  username       TEXT,
  provider       TEXT,
  created_at     TIMESTAMPTZ,
  is_beta        BOOLEAN,
  is_banned      BOOLEAN,
  storage_bytes  BIGINT,
  last_active_at TIMESTAMPTZ
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  q TEXT := '%' || lower(COALESCE(p_query, '')) || '%';
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  RETURN QUERY
  SELECT
    u.id AS user_id,
    u.email::TEXT,
    p.username,
    COALESCE(u.raw_app_meta_data->>'provider', 'email')::TEXT AS provider,
    u.created_at,
    EXISTS (SELECT 1 FROM public.beta_participants b WHERE b.user_id = u.id) AS is_beta,
    EXISTS (SELECT 1 FROM public.banned_users bu WHERE bu.user_id = u.id)  AS is_banned,
    COALESCE(public.get_user_total_storage_used(u.id), 0)::BIGINT AS storage_bytes,
    p.last_active_at
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.user_id = u.id
  WHERE lower(COALESCE(u.email, '')) LIKE q
     OR lower(COALESCE(p.username, '')) LIKE q
  ORDER BY u.created_at DESC
  LIMIT 200;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_users(TEXT) TO authenticated;
