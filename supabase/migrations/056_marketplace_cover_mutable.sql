-- 056_marketplace_cover_mutable.sql
--
-- Makes a published listing's cover image refreshable. When an item's cover
-- (world/package cover, character portrait) changes after publishing, the
-- marketplace banner should follow — without re-publishing. The content
-- snapshot stays frozen: `content_hash` and `payload_path` remain immutable,
-- so the downloadable copy is unchanged. Only `cover_image_b64` becomes
-- mutable, refreshed through the owner-scoped `update_listing_cover` RPC.

-- ── 1. Immutability trigger — drop cover_image_b64 from the locked set ─────
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
  THEN
    RAISE EXCEPTION 'marketplace_listings: immutable column modified';
  END IF;
  RETURN NEW;
END $$;

-- ── 2. update_listing_cover RPC — owner refreshes the banner thumbnail ────
CREATE OR REPLACE FUNCTION public.update_listing_cover(
  p_id              UUID,
  p_cover_image_b64 TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.marketplace_listings
     SET cover_image_b64 = p_cover_image_b64
   WHERE id = p_id
     AND owner_id = auth.uid();
END $$;

GRANT EXECUTE ON FUNCTION public.update_listing_cover(UUID, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
