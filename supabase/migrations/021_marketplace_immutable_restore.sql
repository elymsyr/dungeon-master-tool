-- 021_marketplace_immutable_restore.sql
--
-- Migration 020'de marketplace_listings metadata (title/description/language/
-- tags/changelog) mutate edilebilir hale getirilmişti. Ürün kararı geri
-- alındı: snapshot immutable olmalı; yalnız `download_count` ve `changelog`
-- mutate edilebilir (009'daki orijinal davranış).

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
