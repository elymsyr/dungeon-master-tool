-- ============================================================================
-- DMT — Drop Admin Built-in Marketplace Feature
-- ============================================================================
-- Built-in template/package/world artifacts now ship directly in the app code
-- (bundled assets, code-embedded defaults). Admin-curated built-in marketplace
-- listings are no longer a thing.
--
-- This migration removes every DB surface introduced by 023_admin_moderation_v2
-- that existed only to support that flow:
--   - set_listing_builtin RPC
--   - is_builtin / builtin_marked_by / builtin_marked_at columns on
--     marketplace_listings (+ partial index, + immutability-trigger carve-out)
--   - the builtin-protected DELETE policy (owner can always delete own listing
--     again; admin keeps delete via SECURITY DEFINER admin_delete_marketplace_listing)
--   - admin_list_marketplace_listings `p_builtin_only` filter parameter
--
-- Audit log history (`mark_builtin` / `unmark_builtin` rows) is left in place —
-- those rows are historical records, not active state.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run.
-- ============================================================================

-- ── 1. Drop the set_listing_builtin RPC ────────────────────────────────────

DROP FUNCTION IF EXISTS public.set_listing_builtin(UUID, BOOLEAN);

-- ── 2. Restore the immutability trigger without the is_builtin carve-out ───
-- 023 added is_builtin/builtin_marked_* as intentionally-mutable columns.
-- With the columns gone, the trigger reverts to blocking UPDATEs on all
-- non-download_count columns.

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

-- ── 3. Simplify DELETE policy — owner can always delete own listing ────────

DROP POLICY IF EXISTS "Owner or admin deletes listings" ON public.marketplace_listings;
CREATE POLICY "Owner or admin deletes listings"
  ON public.marketplace_listings FOR DELETE
  USING (public.is_admin() OR auth.uid() = owner_id);

-- ── 4. Drop the partial index + columns ────────────────────────────────────

DROP INDEX IF EXISTS idx_marketplace_listings_builtin;

ALTER TABLE public.marketplace_listings
  DROP COLUMN IF EXISTS is_builtin,
  DROP COLUMN IF EXISTS builtin_marked_by,
  DROP COLUMN IF EXISTS builtin_marked_at;

-- ── 5. Recreate admin_list_marketplace_listings without the builtin filter ─
-- Signature change (dropped p_builtin_only) requires DROP + CREATE.

DROP FUNCTION IF EXISTS public.admin_list_marketplace_listings(BOOLEAN, INT);

CREATE OR REPLACE FUNCTION public.admin_list_marketplace_listings(
  p_limit INT DEFAULT 200
)
RETURNS TABLE (
  id            UUID,
  owner_id      UUID,
  owner_name    TEXT,
  item_type     TEXT,
  title         TEXT,
  language      TEXT,
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
  SELECT m.id, m.owner_id,
         COALESCE(pr.username, pr.display_name, m.owner_id::TEXT),
         m.item_type, m.title, m.language, m.size_bytes,
         m.created_at
  FROM public.marketplace_listings m
  LEFT JOIN public.profiles pr ON pr.user_id = m.owner_id
  ORDER BY m.created_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 500));
END $$;

GRANT EXECUTE ON FUNCTION public.admin_list_marketplace_listings(INT) TO authenticated;

-- ── 6. PostgREST schema cache reload ───────────────────────────────────────
NOTIFY pgrst, 'reload schema';
