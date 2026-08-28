-- ============================================================================
-- DMT — Marketplace content rating (18+ mature label)
-- ============================================================================
-- Adds a content_rating column to marketplace_listings so publishers can
-- flag mature/adult content. Default 'all' (safe) keeps every existing row
-- unaffected. The browse query filters on this column when the user opts out
-- of mature content.
--
-- Usage: Supabase Dashboard > SQL Editor > New Query > paste > Run.
-- ============================================================================

-- ── 1. Column ─────────────────────────────────────────────────────────────
ALTER TABLE public.marketplace_listings
  ADD COLUMN IF NOT EXISTS content_rating TEXT NOT NULL DEFAULT 'all';

ALTER TABLE public.marketplace_listings
  ADD CONSTRAINT marketplace_listings_content_rating_check
  CHECK (content_rating IN ('all', 'mature'));

CREATE INDEX IF NOT EXISTS idx_ml_content_rating
  ON public.marketplace_listings (content_rating)
  WHERE content_rating = 'mature';

-- ── 2. Immutability trigger — add content_rating to guarded columns ───────
-- content_rating is set once at publish time and must never change afterward,
-- like item_type / title / content_hash.

CREATE OR REPLACE FUNCTION public.enforce_listing_immutability()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.id <> OLD.id
     OR NEW.owner_id <> OLD.owner_id
     OR NEW.item_type <> OLD.item_type
     OR NEW.title <> OLD.title
     OR NEW.description IS DISTINCT FROM OLD.description
     OR NEW.language IS DISTINCT FROM OLD.language
     OR NEW.tags <> OLD.tags
     OR NEW.content_hash <> OLD.content_hash
     OR NEW.payload_path <> OLD.payload_path
     OR NEW.size_bytes <> OLD.size_bytes
     OR NEW.content_rating <> OLD.content_rating
     OR NEW.created_at <> OLD.created_at
  THEN
    RAISE EXCEPTION 'marketplace_listings: immutable column modified';
  END IF;
  RETURN NEW;
END $$;

-- ── 3. publish_listing_snapshot RPC — add p_content_rating param ──────────
-- Latest definition is the 13-arg version from migration 076. Drop and
-- recreate with p_content_rating appended (14th param, DEFAULT 'all').

DROP FUNCTION IF EXISTS public.publish_listing_snapshot(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT[], TEXT, TEXT, TEXT, BIGINT, TEXT, TEXT, JSONB
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
  p_cover_image_b64 TEXT    DEFAULT NULL,
  p_template_name   TEXT    DEFAULT NULL,
  p_content_summary JSONB   DEFAULT NULL,
  p_content_rating  TEXT    DEFAULT 'all'
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_new_id UUID := COALESCE(p_listing_id, gen_random_uuid());
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required to publish to the marketplace'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.marketplace_listings (
    id, owner_id, item_type, title, description, language,
    tags, changelog, content_hash, payload_path, size_bytes, cover_image_b64,
    template_name, content_summary, content_rating
  ) VALUES (
    v_new_id, auth.uid(), p_item_type, p_title, p_description, p_language,
    COALESCE(p_tags, '{}'), p_changelog, p_content_hash, p_payload_path,
    p_size_bytes, p_cover_image_b64, p_template_name, p_content_summary,
    COALESCE(p_content_rating, 'all')
  );
  RETURN v_new_id;
END $$;

GRANT EXECUTE ON FUNCTION public.publish_listing_snapshot(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT[], TEXT, TEXT, TEXT, BIGINT, TEXT, TEXT, JSONB, TEXT
) TO authenticated;

NOTIFY pgrst, 'reload schema';
