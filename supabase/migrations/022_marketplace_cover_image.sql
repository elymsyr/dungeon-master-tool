-- 022_marketplace_cover_image.sql
--
-- Adds a cover image to marketplace listings. The image is stored inline
-- as base64 (data URL friendly) so the marketplace browse UI can render
-- banner thumbnails without a second fetch. The value is immutable once
-- published — it's part of the snapshot.
--
-- Clients should keep the encoded payload small (<100 KB ideally).

-- ── 1. Add column ─────────────────────────────────────────────────────────
ALTER TABLE public.marketplace_listings
  ADD COLUMN IF NOT EXISTS cover_image_b64 TEXT;

-- ── 2. Immutability trigger — cover_image_b64 joins the locked set ───────
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

-- ── 3. publish_listing_snapshot RPC — new p_cover_image_b64 parameter ─────
DROP FUNCTION IF EXISTS public.publish_listing_snapshot(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT[], TEXT, TEXT, TEXT, BIGINT
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
  p_cover_image_b64 TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_new_id UUID := COALESCE(p_listing_id, gen_random_uuid());
BEGIN
  INSERT INTO public.marketplace_listings (
    id, owner_id, item_type, title, description, language,
    tags, changelog, content_hash, payload_path, size_bytes, cover_image_b64
  ) VALUES (
    v_new_id, auth.uid(), p_item_type, p_title, p_description, p_language,
    COALESCE(p_tags, '{}'), p_changelog, p_content_hash, p_payload_path,
    p_size_bytes, p_cover_image_b64
  );
  RETURN v_new_id;
END $$;

GRANT EXECUTE ON FUNCTION public.publish_listing_snapshot(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT[], TEXT, TEXT, TEXT, BIGINT, TEXT
) TO authenticated;

NOTIFY pgrst, 'reload schema';
