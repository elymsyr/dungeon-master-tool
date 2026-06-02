-- ============================================================================
-- DMT — Marketplace listing content summary
-- ============================================================================
-- Adds two read-only metadata columns captured at publish time so the
-- marketplace card + preview dialog can show what an item contains WITHOUT
-- downloading the full gzip payload:
--   • template_name    — the world_schema name (shown on the card subtitle).
--   • content_summary  — per-category entity counts + (capped) name lists,
--                        rendered as collapsed sections in the preview dialog.
--
-- Old listings (published before this migration) keep NULL in both columns;
-- the UI degrades gracefully (no breakdown). Re-publishing backfills them.
--
-- Usage: Supabase Dashboard > SQL Editor > New Query > paste > Run.
-- ============================================================================

-- ── 1. Columns ─────────────────────────────────────────────────────────────
ALTER TABLE public.marketplace_listings
  ADD COLUMN IF NOT EXISTS template_name   TEXT;

ALTER TABLE public.marketplace_listings
  ADD COLUMN IF NOT EXISTS content_summary JSONB;

-- The enforce_listing_immutability() trigger (migration 006) only guards an
-- explicit column list; these new columns are not referenced there, so they
-- are free to be written by the publish RPC. No trigger change required.

-- ── 2. publish_listing_snapshot RPC — two new optional params ──────────────
-- Latest definition is the 11-arg beta-gated version from migration 057. Drop
-- it and recreate with p_template_name + p_content_summary appended so PostgREST
-- exposes a single unambiguous overload.
DROP FUNCTION IF EXISTS public.publish_listing_snapshot(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT[], TEXT, TEXT, TEXT, BIGINT, TEXT
);

CREATE OR REPLACE FUNCTION public.publish_listing_snapshot(
  p_listing_id      UUID,
  p_item_type       TEXT,
  p_title           TEXT,
  p_description     TEXT,
  p_language        TEXT,
  p_tags            TEXT[],
  p_changelog       TEXT,
  p_content_hash    TEXT,
  p_payload_path    TEXT,
  p_size_bytes      BIGINT,
  p_cover_image_b64 TEXT  DEFAULT NULL,
  p_template_name   TEXT  DEFAULT NULL,
  p_content_summary JSONB DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_new_id UUID := COALESCE(p_listing_id, gen_random_uuid());
BEGIN
  IF NOT public.is_beta_active(auth.uid()) THEN
    RAISE EXCEPTION 'beta membership required to publish to the marketplace'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.marketplace_listings (
    id, owner_id, item_type, title, description, language,
    tags, changelog, content_hash, payload_path, size_bytes, cover_image_b64,
    template_name, content_summary
  ) VALUES (
    v_new_id, auth.uid(), p_item_type, p_title, p_description, p_language,
    COALESCE(p_tags, '{}'), p_changelog, p_content_hash, p_payload_path,
    p_size_bytes, p_cover_image_b64, p_template_name, p_content_summary
  );
  RETURN v_new_id;
END $$;

GRANT EXECUTE ON FUNCTION public.publish_listing_snapshot(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT[], TEXT, TEXT, TEXT, BIGINT, TEXT, TEXT, JSONB
) TO authenticated;

NOTIFY pgrst, 'reload schema';
