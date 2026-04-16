-- ============================================================================
-- DMT Social — Supabase SQL Migration (Sprint 11 / v3.0.0-beta)
-- ============================================================================
-- Sosyal özellikler: profiller, takip, paylaşılan item'lar, oyun ilanları,
-- post feed, mesajlaşma ve admin gate.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

-- ── 1. profiles ─────────────────────────────────────────────────────────────
-- Her auth.users satırı için public profil. İlk sign-in sonrası client elle
-- insert eder (ProfileEditDialog username seçimi).

CREATE TABLE IF NOT EXISTS public.profiles (
  user_id      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username     TEXT UNIQUE NOT NULL CHECK (
    length(username) BETWEEN 3 AND 20
    AND username ~ '^[a-z0-9_]+$'
  ),
  display_name TEXT,
  bio          TEXT CHECK (length(bio) <= 280),
  avatar_url   TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles (username);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Tüm profiller public okunur (plan: "tüm profiller public").
DROP POLICY IF EXISTS "Profiles are public" ON public.profiles;
CREATE POLICY "Profiles are public"
  ON public.profiles FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "User manages own profile" ON public.profiles;
CREATE POLICY "User manages own profile"
  ON public.profiles FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ── 2. follows ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.follows (
  follower_id  UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, following_id),
  CHECK (follower_id <> following_id)
);

CREATE INDEX IF NOT EXISTS idx_follows_follower  ON public.follows (follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON public.follows (following_id);

ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Follows are public" ON public.follows;
CREATE POLICY "Follows are public"
  ON public.follows FOR SELECT USING (true);

DROP POLICY IF EXISTS "User manages own follows" ON public.follows;
CREATE POLICY "User manages own follows"
  ON public.follows FOR ALL
  USING (auth.uid() = follower_id)
  WITH CHECK (auth.uid() = follower_id);

-- Takipçi/takip sayıları için lightweight view.
CREATE OR REPLACE VIEW public.profile_counts AS
  SELECT
    p.user_id,
    COALESCE((SELECT count(*) FROM public.follows f WHERE f.following_id = p.user_id), 0) AS followers,
    COALESCE((SELECT count(*) FROM public.follows f WHERE f.follower_id  = p.user_id), 0) AS following
  FROM public.profiles p;

GRANT SELECT ON public.profile_counts TO anon, authenticated;

-- ── 3. shared_items ─────────────────────────────────────────────────────────
-- World / template / package için paylaşılan public item kayıtları. Local DB
-- temiz kalsın diye Drift tablolarına isPublic eklemiyoruz; tek source of
-- truth burası.

CREATE TABLE IF NOT EXISTS public.shared_items (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id     UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  item_type    TEXT NOT NULL CHECK (item_type IN ('world','template','package')),
  local_id     TEXT NOT NULL,                  -- yerel kayıttaki uuid
  title        TEXT NOT NULL,
  description  TEXT,
  is_public    BOOLEAN NOT NULL DEFAULT false,
  payload_path TEXT,                           -- Storage bucket içindeki obje
  size_bytes   BIGINT NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (owner_id, item_type, local_id)
);

CREATE INDEX IF NOT EXISTS idx_shared_items_owner  ON public.shared_items (owner_id);
CREATE INDEX IF NOT EXISTS idx_shared_items_public ON public.shared_items (is_public) WHERE is_public = true;

ALTER TABLE public.shared_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Shared items: public or owner read" ON public.shared_items;
CREATE POLICY "Shared items: public or owner read"
  ON public.shared_items FOR SELECT
  USING (is_public = true OR owner_id = auth.uid());

DROP POLICY IF EXISTS "Owner manages shared items" ON public.shared_items;
CREATE POLICY "Owner manages shared items"
  ON public.shared_items FOR ALL
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

-- ── 4. game_listings ────────────────────────────────────────────────────────
-- Takım arkadaşı bulma — public oyun ilanları.

CREATE TABLE IF NOT EXISTS public.game_listings (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id     UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  title        TEXT NOT NULL CHECK (length(title) BETWEEN 3 AND 100),
  description  TEXT,
  system       TEXT,                            -- 'D&D 5e', 'Pathfinder', vs.
  seats_total  INT,
  seats_filled INT NOT NULL DEFAULT 0,
  schedule     TEXT,
  is_open      BOOLEAN NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_game_listings_open  ON public.game_listings (is_open) WHERE is_open = true;
CREATE INDEX IF NOT EXISTS idx_game_listings_owner ON public.game_listings (owner_id);

ALTER TABLE public.game_listings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Game listings public read" ON public.game_listings;
CREATE POLICY "Game listings public read"
  ON public.game_listings FOR SELECT USING (true);

DROP POLICY IF EXISTS "Owner manages listings" ON public.game_listings;
CREATE POLICY "Owner manages listings"
  ON public.game_listings FOR ALL
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

-- ── 5. posts ────────────────────────────────────────────────────────────────
-- Sosyal feed. Resimli postlar Storage'a yüklenir; size_bytes quota'ya sayılır.

CREATE TABLE IF NOT EXISTS public.posts (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id    UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  body         TEXT CHECK (length(body) <= 2000),
  image_url    TEXT,
  image_path   TEXT,                            -- Storage bucket key (silmek için)
  size_bytes   BIGINT NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_posts_author     ON public.posts (author_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON public.posts (created_at DESC);

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Posts are public" ON public.posts;
CREATE POLICY "Posts are public"
  ON public.posts FOR SELECT USING (true);

DROP POLICY IF EXISTS "Author manages posts" ON public.posts;
CREATE POLICY "Author manages posts"
  ON public.posts FOR ALL
  USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);

-- ── 6. conversations / messages ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.conversations (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  is_group   BOOLEAN NOT NULL DEFAULT false,
  title      TEXT,                              -- Yalnızca grup için
  created_by UUID REFERENCES public.profiles(user_id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.conversation_members (
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  joined_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_conv_members_user ON public.conversation_members (user_id);

CREATE TABLE IF NOT EXISTS public.messages (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  author_id       UUID REFERENCES public.profiles(user_id) ON DELETE SET NULL,
  body            TEXT NOT NULL CHECK (length(body) BETWEEN 1 AND 4000),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation ON public.messages (conversation_id, created_at);

ALTER TABLE public.conversations        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages             ENABLE ROW LEVEL SECURITY;

-- Yardımcı: kullanıcı bu konuşmaya üye mi?
CREATE OR REPLACE FUNCTION public.is_conversation_member(p_conv UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.conversation_members
    WHERE conversation_id = p_conv AND user_id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_conversation_member(UUID) TO authenticated;

DROP POLICY IF EXISTS "Conversations: members read" ON public.conversations;
CREATE POLICY "Conversations: members read"
  ON public.conversations FOR SELECT
  USING (public.is_conversation_member(id));

DROP POLICY IF EXISTS "Conversations: anyone can create" ON public.conversations;
CREATE POLICY "Conversations: anyone can create"
  ON public.conversations FOR INSERT
  WITH CHECK (auth.uid() = created_by);

DROP POLICY IF EXISTS "Members read conv membership" ON public.conversation_members;
CREATE POLICY "Members read conv membership"
  ON public.conversation_members FOR SELECT
  USING (public.is_conversation_member(conversation_id));

DROP POLICY IF EXISTS "Self-add to conversation" ON public.conversation_members;
CREATE POLICY "Self-add to conversation"
  ON public.conversation_members FOR INSERT
  WITH CHECK (auth.uid() = user_id OR public.is_conversation_member(conversation_id));

DROP POLICY IF EXISTS "Self-leave conversation" ON public.conversation_members;
CREATE POLICY "Self-leave conversation"
  ON public.conversation_members FOR DELETE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Messages: members read" ON public.messages;
CREATE POLICY "Messages: members read"
  ON public.messages FOR SELECT
  USING (public.is_conversation_member(conversation_id));

DROP POLICY IF EXISTS "Messages: members write" ON public.messages;
CREATE POLICY "Messages: members write"
  ON public.messages FOR INSERT
  WITH CHECK (
    auth.uid() = author_id
    AND public.is_conversation_member(conversation_id)
  );

DROP POLICY IF EXISTS "Messages: author deletes own" ON public.messages;
CREATE POLICY "Messages: author deletes own"
  ON public.messages FOR DELETE
  USING (auth.uid() = author_id);

-- ── 7. app_admins + is_admin() ──────────────────────────────────────────────
-- Email kaynak kodda DEĞİL — admin user_id'leri burada tutulur. Atama:
--
--   INSERT INTO public.app_admins (user_id)
--     SELECT id FROM auth.users WHERE email = 'orhun868@gmail.com';
--
-- Bu komut Supabase SQL Editor'da elle çalıştırılır. Repoda seed YOK.

CREATE TABLE IF NOT EXISTS public.app_admins (
  user_id    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  granted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.app_admins ENABLE ROW LEVEL SECURITY;
-- Hiçbir client doğrudan select yapamaz; yalnızca is_admin() RPC dolaylı erişim.
DROP POLICY IF EXISTS "Admins table is opaque" ON public.app_admins;
CREATE POLICY "Admins table is opaque"
  ON public.app_admins FOR SELECT USING (false);

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.app_admins WHERE user_id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- ── 8. Storage quota integration ────────────────────────────────────────────
-- 002_community_assets'teki get_user_total_storage_used'a posts + shared_items
-- ekleyen güncelleme. UI'daki cloudStorageUsedProvider tek RPC ile birleşik
-- değer alır.

CREATE OR REPLACE FUNCTION public.get_user_total_storage_used(p_user_id UUID)
RETURNS BIGINT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    COALESCE((SELECT SUM(size_bytes) FROM public.cloud_backups
              WHERE user_id = p_user_id), 0)
    +
    COALESCE((SELECT SUM(size_bytes) FROM public.community_assets
              WHERE uploader_id = p_user_id), 0)
    +
    COALESCE((SELECT SUM(size_bytes) FROM public.posts
              WHERE author_id = p_user_id), 0)
    +
    COALESCE((SELECT SUM(size_bytes) FROM public.shared_items
              WHERE owner_id = p_user_id), 0);
$$;

-- ── 9. Username arama ───────────────────────────────────────────────────────
-- Players tab kullanıcı ararken bu fonksiyon prefix match döner.

CREATE OR REPLACE FUNCTION public.search_profiles(p_query TEXT, p_limit INT DEFAULT 20)
RETURNS TABLE (
  user_id UUID,
  username TEXT,
  display_name TEXT,
  avatar_url TEXT
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT user_id, username, display_name, avatar_url
  FROM public.profiles
  WHERE username ILIKE p_query || '%'
     OR display_name ILIKE '%' || p_query || '%'
  ORDER BY username
  LIMIT GREATEST(1, LEAST(p_limit, 50));
$$;

GRANT EXECUTE ON FUNCTION public.search_profiles(TEXT, INT) TO authenticated;
