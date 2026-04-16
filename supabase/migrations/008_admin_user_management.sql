-- ============================================================================
-- DMT Admin — User Management & Storage Stats
-- ============================================================================
-- Admin panelinin "Users / Banned / Storage" sekmeleri için gereken tablo ve
-- RPC'ler. Tüm RPC'ler SECURITY DEFINER ile auth.users / storage.objects gibi
-- korumalı şemalara erişir ve ilk satırda is_admin() kontrolü yapar — admin
-- olmayan çağrılar exception atar.
--
-- Kullanım: Supabase Dashboard > SQL Editor > Run.
-- ============================================================================

-- ── 1. banned_users ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.banned_users (
  user_id    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  reason     TEXT,
  banned_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  banned_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

ALTER TABLE public.banned_users ENABLE ROW LEVEL SECURITY;

-- Client doğrudan okuyamaz; yalnızca admin RPC'leri üzerinden erişim.
DROP POLICY IF EXISTS "Banned users opaque" ON public.banned_users;
CREATE POLICY "Banned users opaque"
  ON public.banned_users FOR SELECT USING (false);

-- ── 2. get_all_users_summary() ──────────────────────────────────────────────
-- Admin user listesi: auth.users + profiles + beta_participants + banned_users
-- birleşik görüntüsü. Provider bilgisi auth metadata'dan alınır.

CREATE OR REPLACE FUNCTION public.get_all_users_summary()
RETURNS TABLE (
  user_id     UUID,
  email       TEXT,
  username    TEXT,
  provider    TEXT,
  created_at  TIMESTAMPTZ,
  is_beta     BOOLEAN,
  is_banned   BOOLEAN
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
    EXISTS (SELECT 1 FROM public.banned_users bu WHERE bu.user_id = u.id)  AS is_banned
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.user_id = u.id
  ORDER BY u.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_all_users_summary() TO authenticated;

-- ── 3. search_users(query) ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.search_users(p_query TEXT)
RETURNS TABLE (
  user_id     UUID,
  email       TEXT,
  username    TEXT,
  provider    TEXT,
  created_at  TIMESTAMPTZ,
  is_beta     BOOLEAN,
  is_banned   BOOLEAN
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
    EXISTS (SELECT 1 FROM public.banned_users bu WHERE bu.user_id = u.id)  AS is_banned
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.user_id = u.id
  WHERE lower(COALESCE(u.email, '')) LIKE q
     OR lower(COALESCE(p.username, '')) LIKE q
  ORDER BY u.created_at DESC
  LIMIT 200;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_users(TEXT) TO authenticated;

-- ── 4. ban_user / unban_user ────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.ban_user(p_target UUID, p_reason TEXT)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  IF EXISTS (SELECT 1 FROM public.app_admins WHERE user_id = p_target) THEN
    RAISE EXCEPTION 'cannot ban an admin';
  END IF;

  INSERT INTO public.banned_users (user_id, reason, banned_by)
  VALUES (p_target, NULLIF(p_reason, ''), auth.uid())
  ON CONFLICT (user_id) DO UPDATE
    SET reason    = EXCLUDED.reason,
        banned_at = now(),
        banned_by = EXCLUDED.banned_by;

  -- ── Cleanup ─────────────────────────────────────────────────────────────
  -- Ban ile birlikte kullanıcının cloud metadata'sı silinir ve beta slotu
  -- boşalır. storage.objects doğrudan DELETE'i Supabase yeni trigger ile
  -- bloke ettiğinden, storage temizliği client tarafında Storage API ile
  -- yapılır (bknz. admin RLS policy aşağıda + AdminUsersRemoteDataSource).

  -- (a) cloud_backups metadata
  DELETE FROM public.cloud_backups WHERE user_id = p_target;

  -- (b) community_assets metadata (R2 nesneleri Worker tarafından ayrı temizlenir)
  DELETE FROM public.community_assets WHERE uploader_id = p_target;

  -- (c) beta_participants → slot boşalır
  DELETE FROM public.beta_participants WHERE user_id = p_target;
END;
$$;

-- ── 4b. Admin storage cleanup policy ────────────────────────────────────────
-- Admin kullanıcılar herhangi bir campaign-backups nesnesini silebilmeli ki
-- ban akışında kullanıcının yedek klasörünü Storage API üzerinden temizlesin.

DROP POLICY IF EXISTS "Admins can delete any campaign backup" ON storage.objects;
CREATE POLICY "Admins can delete any campaign backup"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'campaign-backups'
    AND public.is_admin()
  );

GRANT EXECUTE ON FUNCTION public.ban_user(UUID, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.unban_user(p_target UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  DELETE FROM public.banned_users WHERE user_id = p_target;
END;
$$;

GRANT EXECUTE ON FUNCTION public.unban_user(UUID) TO authenticated;

-- ── 5. get_banned_users() ───────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_banned_users()
RETURNS TABLE (
  user_id    UUID,
  email      TEXT,
  username   TEXT,
  reason     TEXT,
  banned_at  TIMESTAMPTZ
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
    bu.user_id,
    u.email::TEXT,
    p.username,
    bu.reason,
    bu.banned_at
  FROM public.banned_users bu
  JOIN auth.users u ON u.id = bu.user_id
  LEFT JOIN public.profiles p ON p.user_id = bu.user_id
  ORDER BY bu.banned_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_banned_users() TO authenticated;

-- ── 6. get_system_storage_stats() ───────────────────────────────────────────
-- Supabase storage.objects üzerinden bucket başına toplam boyut ve nesne
-- sayısı. Quota/limit bilgisi bilinmediği için yalnızca "kullanılan" döner.

CREATE OR REPLACE FUNCTION public.get_system_storage_stats()
RETURNS TABLE (
  bucket_id    TEXT,
  object_count BIGINT,
  used_bytes   BIGINT
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
    o.bucket_id::TEXT,
    COUNT(*)::BIGINT AS object_count,
    COALESCE(SUM((o.metadata->>'size')::BIGINT), 0)::BIGINT AS used_bytes
  FROM storage.objects o
  GROUP BY o.bucket_id
  ORDER BY o.bucket_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_system_storage_stats() TO authenticated;

-- ── 7. am_i_banned() ────────────────────────────────────────────────────────
-- Kullanıcı kendi ban durumunu sorgular. Login sonrası ve session restore'da
-- client tarafı çağırır; banned ise auth.signOut() ve hata mesajı gösterilir.
-- Opaque RLS'ten bağımsız çalışır çünkü SECURITY DEFINER.

CREATE OR REPLACE FUNCTION public.am_i_banned()
RETURNS TABLE (
  is_banned BOOLEAN,
  reason    TEXT,
  banned_at TIMESTAMPTZ
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    TRUE,
    bu.reason,
    bu.banned_at
  FROM public.banned_users bu
  WHERE bu.user_id = auth.uid()
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, NULL::TEXT, NULL::TIMESTAMPTZ;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.am_i_banned() TO authenticated;
