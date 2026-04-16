-- Profiles can opt out of appearing in discover/suggested results.
ALTER TABLE public.profiles
  ADD COLUMN hidden_from_discover BOOLEAN NOT NULL DEFAULT false;

-- Update suggested_profiles to exclude hidden profiles.
CREATE OR REPLACE FUNCTION public.suggested_profiles(p_limit INT DEFAULT 10)
RETURNS TABLE (
  user_id       UUID,
  username      TEXT,
  display_name  TEXT,
  avatar_url    TEXT,
  followers     BIGINT
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    p.user_id,
    p.username,
    p.display_name,
    p.avatar_url,
    COALESCE((SELECT count(*) FROM public.follows f WHERE f.following_id = p.user_id), 0) AS followers
  FROM public.profiles p
  WHERE p.user_id <> auth.uid()
    AND p.hidden_from_discover = false
    AND NOT EXISTS (
      SELECT 1 FROM public.follows f
      WHERE f.follower_id = auth.uid() AND f.following_id = p.user_id
    )
  ORDER BY followers DESC, p.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 50));
$$;

-- Update search_profiles to exclude hidden profiles.
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
  WHERE (username ILIKE p_query || '%'
     OR display_name ILIKE '%' || p_query || '%')
    AND hidden_from_discover = false
  ORDER BY username
  LIMIT GREATEST(1, LEAST(p_limit, 50));
$$;
