-- ============================================================================
-- DMT — Admin Moderation v2 & Built-in Content
-- ============================================================================
-- (A) profiles: online_restricted + app_version + platform kolonları.
-- (B) marketplace_listings: is_builtin (+ builtin_marked_by, builtin_marked_at).
-- (C) Yeni admin-only RPC'ler: set_online_restriction, am_i_online_restricted,
--     admin_delete_post / admin_delete_marketplace_listing /
--     admin_delete_game_listing / admin_delete_message, set_listing_builtin.
-- (D) user_heartbeat(p_app_version, p_platform) signature extension.
-- (E) ban_user: tam online veri temizliği (posts, messages, likes, follows,
--     game listings, marketplace listings, bug reports). Profil korunur.
-- (F) admin_audit_log tablosu + her admin aksiyonundan yazılır.
-- (G) RLS: NOT is_online_restricted() guard'ları INSERT policy'lerine eklenir.
-- (H) Built-in listing: owner silemez (admin işareti kaldırmalı önce).
-- (I) Admin moderation rate limit (1 dk'da ≤20 delete).
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run.
-- ============================================================================

-- ── 1. profiles: yeni kolonlar ──────────────────────────────────────────────

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS online_restricted         BOOLEAN     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS online_restricted_reason  TEXT,
  ADD COLUMN IF NOT EXISTS online_restricted_at      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS online_restricted_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS app_version               TEXT,
  ADD COLUMN IF NOT EXISTS platform                  TEXT;

CREATE INDEX IF NOT EXISTS idx_profiles_online_restricted
  ON public.profiles (online_restricted) WHERE online_restricted = true;

-- ── 2. marketplace_listings: is_builtin ─────────────────────────────────────

ALTER TABLE public.marketplace_listings
  ADD COLUMN IF NOT EXISTS is_builtin          BOOLEAN     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS builtin_marked_by   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS builtin_marked_at   TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_marketplace_listings_builtin
  ON public.marketplace_listings (is_builtin) WHERE is_builtin = true;

-- Immutability trigger'ını DROP + yeniden CREATE: is_builtin ve builtin_marked_*
-- kolonları MUTABLE (UPDATE'ten korunmaz) — böylece admin istediği zaman
-- işaretleyip/kaldırabilir. Diğer tüm korumalar migration 022 ile aynı.
CREATE OR REPLACE FUNCTION public.enforce_listing_immutability()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.id <> OLD.id
     OR NEW.owner_id <> OLD.owner_id
     OR NEW.item_type <> OLD.item_type
     OR NEW.title <> OLD.title
     OR NEW.description IS DISTINCT FROM OLD.description
     OR NEW.language IS DISTINCT FROM OLD.language
     OR NEW.tags IS DISTINCT FROM OLD.tags
     OR NEW.content_hash <> OLD.content_hash
     OR NEW.payload_path <> OLD.payload_path
     OR NEW.size_bytes <> OLD.size_bytes
     OR NEW.created_at <> OLD.created_at
     OR NEW.cover_image_b64 IS DISTINCT FROM OLD.cover_image_b64
  THEN
    RAISE EXCEPTION 'marketplace_listings: immutable column modified';
  END IF;
  RETURN NEW;
END $$;

-- ── 3. admin_audit_log ──────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.admin_audit_log (
  id               BIGSERIAL PRIMARY KEY,
  admin_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  action           TEXT NOT NULL,
  target_user_id   UUID,
  target_entity_id TEXT,
  reason           TEXT,
  meta             JSONB,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_log_created_at
  ON public.admin_audit_log (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_log_admin_action
  ON public.admin_audit_log (admin_id, action, created_at DESC);

ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;

-- Yalnızca admin okur; INSERT sadece SECURITY DEFINER fonksiyonlardan.
DROP POLICY IF EXISTS "Audit log: admin read" ON public.admin_audit_log;
CREATE POLICY "Audit log: admin read"
  ON public.admin_audit_log FOR SELECT
  USING (public.is_admin());

-- Client'tan doğrudan insert yasak — tüm admin_* RPC'leri SECURITY DEFINER.
DROP POLICY IF EXISTS "Audit log: no client write" ON public.admin_audit_log;
CREATE POLICY "Audit log: no client write"
  ON public.admin_audit_log FOR INSERT
  WITH CHECK (false);

-- Admin moderation rate limit (1 dk'da ≤20 delete aksiyonu). Admin hesabı
-- çalınırsa kitle silmeyi önler. Ban/restriction aksiyonları RATE'e sayılır.
CREATE OR REPLACE FUNCTION public._assert_admin_rate_limit()
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INT;
BEGIN
  SELECT count(*)
    INTO v_count
    FROM public.admin_audit_log
   WHERE admin_id = auth.uid()
     AND created_at > now() - interval '1 minute'
     AND action IN (
       'ban','delete_post','delete_marketplace_listing',
       'delete_game_listing','delete_message','online_restrict'
     );
  IF v_count >= 20 THEN
    RAISE EXCEPTION 'admin rate limit exceeded (20/min)'
      USING HINT = 'Wait a minute before continuing moderation actions.';
  END IF;
END $$;

-- ── 4. is_online_restricted() helper + RLS guards ───────────────────────────

CREATE OR REPLACE FUNCTION public.is_online_restricted(p_user UUID DEFAULT auth.uid())
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT online_restricted FROM public.profiles WHERE user_id = p_user),
    false
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_online_restricted(UUID) TO authenticated;

-- 4.1 posts: FOR ALL policy'yi ayrıştır. SELECT zaten "Posts are public" ile var.
DROP POLICY IF EXISTS "Author manages posts" ON public.posts;
DROP POLICY IF EXISTS "posts author insert"  ON public.posts;
DROP POLICY IF EXISTS "posts author update"  ON public.posts;
DROP POLICY IF EXISTS "posts author delete"  ON public.posts;

CREATE POLICY "posts author insert"
  ON public.posts FOR INSERT
  WITH CHECK (auth.uid() = author_id AND NOT public.is_online_restricted());

CREATE POLICY "posts author update"
  ON public.posts FOR UPDATE
  USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);

CREATE POLICY "posts author delete"
  ON public.posts FOR DELETE
  USING (auth.uid() = author_id OR public.is_admin());

-- 4.2 post_likes INSERT/DELETE ayrıştır (eski FOR ALL policy'yi ikiye böl).
DROP POLICY IF EXISTS "User manages own likes" ON public.post_likes;
DROP POLICY IF EXISTS "post_likes self insert" ON public.post_likes;
DROP POLICY IF EXISTS "post_likes self delete" ON public.post_likes;

CREATE POLICY "post_likes self insert"
  ON public.post_likes FOR INSERT
  WITH CHECK (auth.uid() = user_id AND NOT public.is_online_restricted());

CREATE POLICY "post_likes self delete"
  ON public.post_likes FOR DELETE
  USING (auth.uid() = user_id);

-- 4.3 messages INSERT guard — 003_social.sql'deki "Messages: members write"
--     policy'sini guard'la genişlet.
DROP POLICY IF EXISTS "Messages: members write" ON public.messages;
CREATE POLICY "Messages: members write"
  ON public.messages FOR INSERT
  WITH CHECK (
    auth.uid() = author_id
    AND public.is_conversation_member(conversation_id)
    AND NOT public.is_online_restricted()
  );

-- Mesaj DELETE: author silebilir veya admin
DROP POLICY IF EXISTS "Messages: author deletes own" ON public.messages;
CREATE POLICY "Messages: author deletes own"
  ON public.messages FOR DELETE
  USING (auth.uid() = author_id OR public.is_admin());

-- 4.4 game_listings: FOR ALL policy'yi ayrıştır. SELECT zaten
--     "Game listings public read" ile var.
DROP POLICY IF EXISTS "Owner manages listings" ON public.game_listings;
DROP POLICY IF EXISTS "game_listings owner insert" ON public.game_listings;
DROP POLICY IF EXISTS "game_listings owner update" ON public.game_listings;
DROP POLICY IF EXISTS "game_listings owner or admin delete" ON public.game_listings;

CREATE POLICY "game_listings owner insert"
  ON public.game_listings FOR INSERT
  WITH CHECK (auth.uid() = owner_id AND NOT public.is_online_restricted());

CREATE POLICY "game_listings owner update"
  ON public.game_listings FOR UPDATE
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "game_listings owner or admin delete"
  ON public.game_listings FOR DELETE
  USING (auth.uid() = owner_id OR public.is_admin());

-- 4.5 game_listing_applications INSERT guard (migration 005'teki
--     "Applications: apply as self" policy'sini restrict guard ile değiştir).
DROP POLICY IF EXISTS "Applications: apply as self" ON public.game_listing_applications;
CREATE POLICY "Applications: apply as self"
  ON public.game_listing_applications FOR INSERT
  WITH CHECK (
    auth.uid() = applicant_id
    AND NOT public.is_online_restricted()
    AND NOT EXISTS (
      SELECT 1 FROM public.game_listings gl
      WHERE gl.id = listing_id AND gl.owner_id = auth.uid()
    )
  );

-- 4.6 marketplace_listings INSERT guard + built-in-protected DELETE
DROP POLICY IF EXISTS "Owner inserts own listings" ON public.marketplace_listings;
CREATE POLICY "Owner inserts own listings"
  ON public.marketplace_listings FOR INSERT
  WITH CHECK (auth.uid() = owner_id AND NOT public.is_online_restricted());

-- DELETE: built-in işaretliyse owner silemez (admin işareti önce kaldırmalı).
-- Admin her durumda silebilir.
DROP POLICY IF EXISTS "Owner deletes own listings" ON public.marketplace_listings;
CREATE POLICY "Owner or admin deletes listings"
  ON public.marketplace_listings FOR DELETE
  USING (
    public.is_admin()
    OR (auth.uid() = owner_id AND is_builtin = false)
  );

-- 4.7 follows: FOR ALL policy'yi ayrıştır. SELECT zaten
--     "Follows are public" ile var.
DROP POLICY IF EXISTS "User manages own follows" ON public.follows;
DROP POLICY IF EXISTS "follows self insert" ON public.follows;
DROP POLICY IF EXISTS "follows self delete" ON public.follows;

CREATE POLICY "follows self insert"
  ON public.follows FOR INSERT
  WITH CHECK (auth.uid() = follower_id AND NOT public.is_online_restricted());

CREATE POLICY "follows self delete"
  ON public.follows FOR DELETE
  USING (auth.uid() = follower_id);

-- ── 5. user_heartbeat: app_version + platform ───────────────────────────────
-- Eski signature'ı override ederken geriye dönük uyumluluk için parametresiz
-- overload kalır (011'de tanımlandı). Yeni signature iki opsiyonel parametre.

CREATE OR REPLACE FUNCTION public.user_heartbeat(
  p_app_version TEXT DEFAULT NULL,
  p_platform    TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RETURN;
  END IF;

  UPDATE public.profiles
     SET last_active_at = now(),
         app_version    = COALESCE(NULLIF(p_app_version, ''), app_version),
         platform       = COALESCE(NULLIF(p_platform,    ''), platform)
   WHERE user_id = v_user;

  UPDATE public.beta_participants
     SET last_active_at = now()
   WHERE user_id = v_user;
END $$;

GRANT EXECUTE ON FUNCTION public.user_heartbeat(TEXT, TEXT) TO authenticated;

-- ── 6. Online restriction RPC'leri ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.set_online_restriction(
  p_target     UUID,
  p_restricted BOOLEAN,
  p_reason     TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  PERFORM public._assert_admin_rate_limit();

  IF EXISTS (SELECT 1 FROM public.app_admins WHERE user_id = p_target) THEN
    RAISE EXCEPTION 'cannot restrict an admin';
  END IF;

  IF p_restricted THEN
    UPDATE public.profiles
       SET online_restricted        = true,
           online_restricted_reason = NULLIF(p_reason, ''),
           online_restricted_at     = now(),
           online_restricted_by     = auth.uid()
     WHERE user_id = p_target;
  ELSE
    UPDATE public.profiles
       SET online_restricted        = false,
           online_restricted_reason = NULL,
           online_restricted_at     = NULL,
           online_restricted_by     = NULL
     WHERE user_id = p_target;
  END IF;

  INSERT INTO public.admin_audit_log (admin_id, action, target_user_id, reason)
  VALUES (
    auth.uid(),
    CASE WHEN p_restricted THEN 'online_restrict' ELSE 'online_unrestrict' END,
    p_target,
    NULLIF(p_reason, '')
  );
END $$;

GRANT EXECUTE ON FUNCTION public.set_online_restriction(UUID, BOOLEAN, TEXT)
  TO authenticated;

-- Kullanıcı kendi restrict durumunu öğrenir (am_i_banned pattern'i).
CREATE OR REPLACE FUNCTION public.am_i_online_restricted()
RETURNS TABLE (
  is_restricted BOOLEAN,
  reason        TEXT,
  restricted_at TIMESTAMPTZ
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.online_restricted,
    p.online_restricted_reason,
    p.online_restricted_at
  FROM public.profiles p
  WHERE p.user_id = auth.uid()
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, NULL::TEXT, NULL::TIMESTAMPTZ;
  END IF;
END $$;

GRANT EXECUTE ON FUNCTION public.am_i_online_restricted() TO authenticated;

-- ── 7. Admin moderation: içerik silme RPC'leri ──────────────────────────────

CREATE OR REPLACE FUNCTION public.admin_delete_post(p_post UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_author UUID;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  PERFORM public._assert_admin_rate_limit();

  SELECT author_id INTO v_author FROM public.posts WHERE id = p_post;
  IF v_author IS NULL THEN
    RETURN;  -- already gone
  END IF;

  DELETE FROM public.posts WHERE id = p_post;

  INSERT INTO public.admin_audit_log (admin_id, action, target_user_id, target_entity_id)
  VALUES (auth.uid(), 'delete_post', v_author, p_post::TEXT);
END $$;

GRANT EXECUTE ON FUNCTION public.admin_delete_post(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_delete_marketplace_listing(p_listing UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_owner UUID;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  PERFORM public._assert_admin_rate_limit();

  SELECT owner_id INTO v_owner FROM public.marketplace_listings WHERE id = p_listing;
  IF v_owner IS NULL THEN
    RETURN;
  END IF;

  DELETE FROM public.marketplace_listings WHERE id = p_listing;

  INSERT INTO public.admin_audit_log (admin_id, action, target_user_id, target_entity_id)
  VALUES (auth.uid(), 'delete_marketplace_listing', v_owner, p_listing::TEXT);
END $$;

GRANT EXECUTE ON FUNCTION public.admin_delete_marketplace_listing(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_delete_game_listing(p_listing UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_owner UUID;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  PERFORM public._assert_admin_rate_limit();

  SELECT owner_id INTO v_owner FROM public.game_listings WHERE id = p_listing;
  IF v_owner IS NULL THEN
    RETURN;
  END IF;

  DELETE FROM public.game_listings WHERE id = p_listing;

  INSERT INTO public.admin_audit_log (admin_id, action, target_user_id, target_entity_id)
  VALUES (auth.uid(), 'delete_game_listing', v_owner, p_listing::TEXT);
END $$;

GRANT EXECUTE ON FUNCTION public.admin_delete_game_listing(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_delete_message(p_message UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_author UUID;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  PERFORM public._assert_admin_rate_limit();

  SELECT author_id INTO v_author FROM public.messages WHERE id = p_message;
  IF v_author IS NULL THEN
    RETURN;
  END IF;

  DELETE FROM public.messages WHERE id = p_message;

  INSERT INTO public.admin_audit_log (admin_id, action, target_user_id, target_entity_id)
  VALUES (auth.uid(), 'delete_message', v_author, p_message::TEXT);
END $$;

GRANT EXECUTE ON FUNCTION public.admin_delete_message(UUID) TO authenticated;

-- ── 8. Built-in işaretleme RPC ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.set_listing_builtin(
  p_listing UUID,
  p_builtin BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_owner UUID;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  SELECT owner_id INTO v_owner FROM public.marketplace_listings WHERE id = p_listing;
  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'listing not found';
  END IF;

  UPDATE public.marketplace_listings
     SET is_builtin        = p_builtin,
         builtin_marked_by = CASE WHEN p_builtin THEN auth.uid() ELSE NULL END,
         builtin_marked_at = CASE WHEN p_builtin THEN now()      ELSE NULL END
   WHERE id = p_listing;

  INSERT INTO public.admin_audit_log (admin_id, action, target_user_id, target_entity_id)
  VALUES (
    auth.uid(),
    CASE WHEN p_builtin THEN 'mark_builtin' ELSE 'unmark_builtin' END,
    v_owner,
    p_listing::TEXT
  );
END $$;

GRANT EXECUTE ON FUNCTION public.set_listing_builtin(UUID, BOOLEAN) TO authenticated;

-- ── 9. Admin listeleme RPC'leri (moderation dashboard için) ─────────────────

-- Tüm postları (admin moderation tab) — created_at DESC, limit 500.
CREATE OR REPLACE FUNCTION public.admin_list_posts(p_limit INT DEFAULT 200)
RETURNS TABLE (
  id            UUID,
  author_id     UUID,
  author_name   TEXT,
  body          TEXT,
  image_url     TEXT,
  size_bytes    BIGINT,
  created_at    TIMESTAMPTZ
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  RETURN QUERY
  SELECT p.id, p.author_id,
         COALESCE(pr.username, pr.display_name, p.author_id::TEXT),
         p.body, p.image_url, p.size_bytes, p.created_at
  FROM public.posts p
  LEFT JOIN public.profiles pr ON pr.user_id = p.author_id
  ORDER BY p.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END $$;

GRANT EXECUTE ON FUNCTION public.admin_list_posts(INT) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_list_game_listings(p_limit INT DEFAULT 200)
RETURNS TABLE (
  id            UUID,
  owner_id      UUID,
  owner_name    TEXT,
  title         TEXT,
  system        TEXT,
  is_open       BOOLEAN,
  created_at    TIMESTAMPTZ
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  RETURN QUERY
  SELECT g.id, g.owner_id,
         COALESCE(pr.username, pr.display_name, g.owner_id::TEXT),
         g.title, g.system, g.is_open, g.created_at
  FROM public.game_listings g
  LEFT JOIN public.profiles pr ON pr.user_id = g.owner_id
  ORDER BY g.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END $$;

GRANT EXECUTE ON FUNCTION public.admin_list_game_listings(INT) TO authenticated;

-- admin_list_marketplace_listings — is_builtin filtresi destekli.
-- p_builtin_only TRUE → yalnız built-in, FALSE → yalnız non-builtin, NULL → hepsi.
CREATE OR REPLACE FUNCTION public.admin_list_marketplace_listings(
  p_builtin_only BOOLEAN DEFAULT NULL,
  p_limit        INT     DEFAULT 200
)
RETURNS TABLE (
  id            UUID,
  owner_id      UUID,
  owner_name    TEXT,
  item_type     TEXT,
  title         TEXT,
  language      TEXT,
  size_bytes    BIGINT,
  is_builtin    BOOLEAN,
  created_at    TIMESTAMPTZ
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  RETURN QUERY
  SELECT m.id, m.owner_id,
         COALESCE(pr.username, pr.display_name, m.owner_id::TEXT),
         m.item_type, m.title, m.language, m.size_bytes,
         m.is_builtin, m.created_at
  FROM public.marketplace_listings m
  LEFT JOIN public.profiles pr ON pr.user_id = m.owner_id
  WHERE p_builtin_only IS NULL OR m.is_builtin = p_builtin_only
  ORDER BY m.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END $$;

GRANT EXECUTE ON FUNCTION public.admin_list_marketplace_listings(BOOLEAN, INT) TO authenticated;

-- Audit log listeleme (admin-only).
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
         COALESCE(ap.username, ap.display_name, a.admin_id::TEXT),
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

-- Restricted users listesi (admin paneli için).
CREATE OR REPLACE FUNCTION public.get_restricted_users()
RETURNS TABLE (
  user_id                  UUID,
  email                    TEXT,
  username                 TEXT,
  reason                   TEXT,
  restricted_at            TIMESTAMPTZ
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  RETURN QUERY
  SELECT p.user_id,
         u.email::TEXT,
         p.username,
         p.online_restricted_reason,
         p.online_restricted_at
  FROM public.profiles p
  JOIN auth.users u ON u.id = p.user_id
  WHERE p.online_restricted = true
  ORDER BY p.online_restricted_at DESC;
END $$;

GRANT EXECUTE ON FUNCTION public.get_restricted_users() TO authenticated;

-- ── 10. get_all_users_summary / search_users — refresh ──────────────────────
-- Kolon sayısı değiştiği için DROP + CREATE zorunlu.

DROP FUNCTION IF EXISTS public.get_all_users_summary();
DROP FUNCTION IF EXISTS public.search_users(TEXT);

CREATE OR REPLACE FUNCTION public.get_all_users_summary()
RETURNS TABLE (
  user_id            UUID,
  email              TEXT,
  username           TEXT,
  provider           TEXT,
  created_at         TIMESTAMPTZ,
  is_beta            BOOLEAN,
  is_banned          BOOLEAN,
  storage_bytes      BIGINT,
  last_active_at     TIMESTAMPTZ,
  app_version        TEXT,
  platform           TEXT,
  online_restricted  BOOLEAN,
  online_restricted_reason TEXT
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
    COALESCE(u.raw_app_meta_data->>'provider', 'email')::TEXT AS provider,
    u.created_at,
    EXISTS (SELECT 1 FROM public.beta_participants b WHERE b.user_id = u.id) AS is_beta,
    EXISTS (SELECT 1 FROM public.banned_users bu WHERE bu.user_id = u.id)    AS is_banned,
    COALESCE(public.get_user_total_storage_used(u.id), 0)::BIGINT            AS storage_bytes,
    p.last_active_at,
    p.app_version,
    p.platform,
    COALESCE(p.online_restricted, false),
    p.online_restricted_reason
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.user_id = u.id
  ORDER BY u.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_all_users_summary() TO authenticated;

CREATE OR REPLACE FUNCTION public.search_users(p_query TEXT)
RETURNS TABLE (
  user_id            UUID,
  email              TEXT,
  username           TEXT,
  provider           TEXT,
  created_at         TIMESTAMPTZ,
  is_beta            BOOLEAN,
  is_banned          BOOLEAN,
  storage_bytes      BIGINT,
  last_active_at     TIMESTAMPTZ,
  app_version        TEXT,
  platform           TEXT,
  online_restricted  BOOLEAN,
  online_restricted_reason TEXT
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
    EXISTS (SELECT 1 FROM public.banned_users bu WHERE bu.user_id = u.id)    AS is_banned,
    COALESCE(public.get_user_total_storage_used(u.id), 0)::BIGINT            AS storage_bytes,
    p.last_active_at,
    p.app_version,
    p.platform,
    COALESCE(p.online_restricted, false),
    p.online_restricted_reason
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.user_id = u.id
  WHERE lower(COALESCE(u.email, '')) LIKE q
     OR lower(COALESCE(p.username, '')) LIKE q
  ORDER BY u.created_at DESC
  LIMIT 200;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_users(TEXT) TO authenticated;

-- ── 11. ban_user: tam online veri temizliği ─────────────────────────────────
-- Profil kaydı korunur (username rezerve, display_name='[banned user]') —
-- böylece diğer kullanıcılardaki referanslar (DM history, post'ta mention)
-- ölü link olmaz ve username banlanan hesaba geri gelmez.

CREATE OR REPLACE FUNCTION public.ban_user(p_target UUID, p_reason TEXT)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  PERFORM public._assert_admin_rate_limit();

  IF EXISTS (SELECT 1 FROM public.app_admins WHERE user_id = p_target) THEN
    RAISE EXCEPTION 'cannot ban an admin';
  END IF;

  INSERT INTO public.banned_users (user_id, reason, banned_by)
  VALUES (p_target, NULLIF(p_reason, ''), auth.uid())
  ON CONFLICT (user_id) DO UPDATE
    SET reason    = EXCLUDED.reason,
        banned_at = now(),
        banned_by = EXCLUDED.banned_by;

  -- ── Cleanup: tüm online veri ──
  DELETE FROM public.cloud_backups             WHERE user_id      = p_target;
  DELETE FROM public.community_assets          WHERE uploader_id  = p_target;
  DELETE FROM public.beta_participants         WHERE user_id      = p_target;
  DELETE FROM public.post_likes                WHERE user_id      = p_target;
  DELETE FROM public.posts                     WHERE author_id    = p_target;
  DELETE FROM public.follows                   WHERE follower_id  = p_target
                                                  OR following_id = p_target;
  DELETE FROM public.game_listing_applications WHERE applicant_id = p_target;
  DELETE FROM public.game_listings             WHERE owner_id     = p_target;
  DELETE FROM public.messages                  WHERE author_id    = p_target;
  DELETE FROM public.conversation_members      WHERE user_id      = p_target;
  DELETE FROM public.marketplace_listings      WHERE owner_id     = p_target;
  DELETE FROM public.bug_reports               WHERE user_id      = p_target;

  -- Profil kaydı korunur ama anonimleştirilir.
  UPDATE public.profiles
     SET display_name         = '[banned user]',
         bio                  = NULL,
         avatar_url           = NULL,
         hidden_from_discover = true,
         online_restricted    = false,
         online_restricted_reason = NULL,
         online_restricted_at = NULL,
         online_restricted_by = NULL
   WHERE user_id = p_target;

  INSERT INTO public.admin_audit_log (admin_id, action, target_user_id, reason)
  VALUES (auth.uid(), 'ban', p_target, NULLIF(p_reason, ''));
END;
$$;

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

  INSERT INTO public.admin_audit_log (admin_id, action, target_user_id)
  VALUES (auth.uid(), 'unban', p_target);
END;
$$;

GRANT EXECUTE ON FUNCTION public.unban_user(UUID) TO authenticated;

-- ── 12. PostgREST schema cache reload ───────────────────────────────────────
NOTIFY pgrst, 'reload schema';
