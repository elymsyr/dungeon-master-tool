-- 020_marketplace_character_and_editable.sql
--
-- (a) marketplace_listings.item_type CHECK constraint'ı 'character' dahil
--     edilecek şekilde güncellenir.
-- (b) enforce_listing_immutability trigger'ı gevşetilir: title/description/
--     language/tags/changelog artık mutate edilebilir. Hash/payload/owner/
--     item_type/id/size/created_at hâlâ immutable.

-- ── (a) item_type CHECK constraint ───────────────────────────────────────
ALTER TABLE public.marketplace_listings
  DROP CONSTRAINT IF EXISTS marketplace_listings_item_type_check;

ALTER TABLE public.marketplace_listings
  ADD CONSTRAINT marketplace_listings_item_type_check
  CHECK (item_type IN ('world','template','package','character'));

-- ── (b) Immutability trigger gevşetmesi ──────────────────────────────────
-- Fonksiyon gövdesi yeniden yazılır; mevcut trigger binding (trg_listings_
-- immutable) korunur — CREATE OR REPLACE FUNCTION otomatik yeni gövdeyi
-- kullandırır.
CREATE OR REPLACE FUNCTION public.enforce_listing_immutability()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.id <> OLD.id
     OR NEW.owner_id <> OLD.owner_id
     OR NEW.item_type <> OLD.item_type
     OR NEW.content_hash <> OLD.content_hash
     OR NEW.payload_path <> OLD.payload_path
     OR NEW.size_bytes <> OLD.size_bytes
     OR NEW.created_at <> OLD.created_at
  THEN
    RAISE EXCEPTION 'marketplace_listings: immutable column modified';
  END IF;
  RETURN NEW;
END $$;
