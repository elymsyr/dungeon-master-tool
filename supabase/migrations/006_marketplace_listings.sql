-- ============================================================================
-- DMT — Marketplace listings (snapshot + lineage modeli)
-- ============================================================================
-- Eski public/private toggle modeli (`shared_items`) yerine immutable snapshot
-- + lineage zinciri. Owner her publish'te yeni bir row insert eder; aynı
-- yerel item'dan üretilen snapshot'lar `lineage_id` ile birbirine bağlanır.
-- Reader indirilen kopyada lineage takibi yaparak owner yeni snapshot
-- yayınladığında bildirim alır.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

-- ── 0. Eski shared_items'i temizle ─────────────────────────────────────────
-- Beta sprint kararı: temiz başlangıç, mevcut public veriler atılır.

DROP TABLE IF EXISTS public.shared_items CASCADE;

-- ── 1. marketplace_listings tablosu ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.marketplace_listings (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id        UUID NOT NULL REFERENCES public.profiles(user_id) ON DELETE CASCADE,
  item_type       TEXT NOT NULL CHECK (item_type IN ('world','template','package')),

  -- Lineage: aynı yerel item'dan üretilen tüm snapshot'lar aynı lineage_id'yi
  -- paylaşır. İlk publish'te yeni UUID; sonrakiler reuse eder.
  lineage_id      UUID NOT NULL,
  is_current      BOOLEAN NOT NULL DEFAULT true,
  superseded_by   UUID REFERENCES public.marketplace_listings(id) ON DELETE SET NULL,

  -- Immutable snapshot metadata
  title           TEXT NOT NULL,
  description     TEXT,
  language        TEXT,
  tags            TEXT[] NOT NULL DEFAULT '{}',
  changelog       TEXT,
  content_hash    TEXT NOT NULL,
  payload_path    TEXT NOT NULL,
  size_bytes      BIGINT NOT NULL DEFAULT 0,

  download_count  BIGINT NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ml_owner    ON public.marketplace_listings (owner_id);
CREATE INDEX IF NOT EXISTS idx_ml_lineage  ON public.marketplace_listings (lineage_id);
CREATE INDEX IF NOT EXISTS idx_ml_current  ON public.marketplace_listings (is_current) WHERE is_current = true;
CREATE INDEX IF NOT EXISTS idx_ml_type     ON public.marketplace_listings (item_type);
CREATE INDEX IF NOT EXISTS idx_ml_language ON public.marketplace_listings (language) WHERE language IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ml_tags     ON public.marketplace_listings USING GIN (tags);

ALTER TABLE public.marketplace_listings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Listings public read" ON public.marketplace_listings;
CREATE POLICY "Listings public read"
  ON public.marketplace_listings FOR SELECT USING (true);

DROP POLICY IF EXISTS "Owner inserts own listings" ON public.marketplace_listings;
CREATE POLICY "Owner inserts own listings"
  ON public.marketplace_listings FOR INSERT
  WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Owner updates own listings" ON public.marketplace_listings;
CREATE POLICY "Owner updates own listings"
  ON public.marketplace_listings FOR UPDATE
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Owner deletes own listings" ON public.marketplace_listings;
CREATE POLICY "Owner deletes own listings"
  ON public.marketplace_listings FOR DELETE
  USING (auth.uid() = owner_id);

-- ── 2. Immutability trigger ────────────────────────────────────────────────
-- Title, description, content_hash, payload_path, lineage_id, tags, language,
-- item_type, owner_id ve created_at UPDATE'ten korunur. Sadece is_current,
-- superseded_by, download_count, changelog mutate edilebilir.

CREATE OR REPLACE FUNCTION public.enforce_listing_immutability()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.id <> OLD.id
     OR NEW.owner_id <> OLD.owner_id
     OR NEW.item_type <> OLD.item_type
     OR NEW.lineage_id <> OLD.lineage_id
     OR NEW.title <> OLD.title
     OR NEW.description IS DISTINCT FROM OLD.description
     OR NEW.language IS DISTINCT FROM OLD.language
     OR NEW.tags <> OLD.tags
     OR NEW.content_hash <> OLD.content_hash
     OR NEW.payload_path <> OLD.payload_path
     OR NEW.size_bytes <> OLD.size_bytes
     OR NEW.created_at <> OLD.created_at
  THEN
    RAISE EXCEPTION 'marketplace_listings: immutable column modified';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_listings_immutable ON public.marketplace_listings;
CREATE TRIGGER trg_listings_immutable
  BEFORE UPDATE ON public.marketplace_listings
  FOR EACH ROW EXECUTE FUNCTION public.enforce_listing_immutability();

-- ── 3. publish_listing_snapshot RPC ────────────────────────────────────────
-- Atomik: aynı lineage'in current'larını supersede et, yeni row insert et,
-- eski current'ların superseded_by alanını yeni id'ye işaretle.
-- p_lineage_id NULL ise yeni lineage UUID üretilir. p_listing_id de
-- NULL olabilir; client-side UUID gönderilirse Storage path'i ile eşleşmesi
-- garanti edilir (payload upload listing_id'yi önceden gerektirir).

CREATE OR REPLACE FUNCTION public.publish_listing_snapshot(
  p_listing_id    UUID,
  p_lineage_id    UUID,
  p_item_type     TEXT,
  p_title         TEXT,
  p_description   TEXT,
  p_language      TEXT,
  p_tags          TEXT[],
  p_changelog     TEXT,
  p_content_hash  TEXT,
  p_payload_path  TEXT,
  p_size_bytes    BIGINT
) RETURNS TABLE(listing_id UUID, lineage_id UUID)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_lineage UUID := COALESCE(p_lineage_id, gen_random_uuid());
  v_new_id  UUID := COALESCE(p_listing_id, gen_random_uuid());
BEGIN
  -- Yetkisiz lineage hijack'ini engelle: var olan lineage'in sahibi auth.uid() olmalı
  IF p_lineage_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.marketplace_listings
    WHERE marketplace_listings.lineage_id = p_lineage_id
      AND owner_id <> auth.uid()
  ) THEN
    RAISE EXCEPTION 'lineage owned by another user';
  END IF;

  -- Eski current'ları supersede et
  UPDATE public.marketplace_listings
     SET is_current = false
   WHERE marketplace_listings.lineage_id = v_lineage
     AND owner_id = auth.uid()
     AND is_current = true;

  -- Yeni snapshot insert
  INSERT INTO public.marketplace_listings (
    id, owner_id, item_type, lineage_id, title, description, language,
    tags, changelog, content_hash, payload_path, size_bytes
  ) VALUES (
    v_new_id, auth.uid(), p_item_type, v_lineage, p_title, p_description, p_language,
    COALESCE(p_tags, '{}'), p_changelog, p_content_hash, p_payload_path, p_size_bytes
  );

  -- Eski current'ların superseded_by'ını yeni id'ye bağla (henüz null olanları)
  UPDATE public.marketplace_listings
     SET superseded_by = v_new_id
   WHERE marketplace_listings.lineage_id = v_lineage
     AND owner_id = auth.uid()
     AND id <> v_new_id
     AND superseded_by IS NULL;

  RETURN QUERY SELECT v_new_id, v_lineage;
END $$;

GRANT EXECUTE ON FUNCTION public.publish_listing_snapshot(UUID,UUID,TEXT,TEXT,TEXT,TEXT,TEXT[],TEXT,TEXT,TEXT,BIGINT) TO authenticated;

-- ── 4. lineage_current_versions RPC ────────────────────────────────────────
-- Reader drift check için lightweight: payload yok, sadece metadata.
-- Verilen lineage id'leri için her birinin current snapshot'ını döner.
-- Lineage tamamen silindiyse o lineage row'u dönmez (caller "removed"
-- olarak yorumlar).

CREATE OR REPLACE FUNCTION public.lineage_current_versions(p_lineage_ids UUID[])
RETURNS TABLE (
  lineage_id    UUID,
  listing_id    UUID,
  owner_id      UUID,
  item_type     TEXT,
  title         TEXT,
  description   TEXT,
  language      TEXT,
  tags          TEXT[],
  changelog     TEXT,
  content_hash  TEXT,
  payload_path  TEXT,
  size_bytes    BIGINT,
  created_at    TIMESTAMPTZ
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    ml.lineage_id,
    ml.id,
    ml.owner_id,
    ml.item_type,
    ml.title,
    ml.description,
    ml.language,
    ml.tags,
    ml.changelog,
    ml.content_hash,
    ml.payload_path,
    ml.size_bytes,
    ml.created_at
  FROM public.marketplace_listings ml
  WHERE ml.lineage_id = ANY(p_lineage_ids)
    AND ml.is_current = true;
$$;

GRANT EXECUTE ON FUNCTION public.lineage_current_versions(UUID[]) TO authenticated;

-- ── 5. increment_listing_downloads RPC ─────────────────────────────────────

CREATE OR REPLACE FUNCTION public.increment_listing_downloads(p_id UUID)
RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_new_count BIGINT;
BEGIN
  UPDATE public.marketplace_listings
     SET download_count = download_count + 1
   WHERE id = p_id
  RETURNING download_count INTO v_new_count;
  RETURN COALESCE(v_new_count, 0);
END $$;

GRANT EXECUTE ON FUNCTION public.increment_listing_downloads(UUID) TO authenticated;

-- ── 6. delete_listing RPC ──────────────────────────────────────────────────
-- Owner bir snapshot'ı sildiğinde: row delete + (eğer current'sa) aynı
-- lineage'in en yeni non-current snapshot'ı current'a yükseltilir.
-- Storage payload silme client tarafından yapılır (RPC sadece DB).

CREATE OR REPLACE FUNCTION public.delete_listing(p_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_lineage    UUID;
  v_was_current BOOLEAN;
  v_owner      UUID;
BEGIN
  SELECT lineage_id, is_current, owner_id
    INTO v_lineage, v_was_current, v_owner
    FROM public.marketplace_listings
   WHERE id = p_id;

  IF v_owner IS NULL THEN
    RETURN;  -- already gone
  END IF;
  IF v_owner <> auth.uid() THEN
    RAISE EXCEPTION 'not owner';
  END IF;

  DELETE FROM public.marketplace_listings WHERE id = p_id;

  IF v_was_current THEN
    -- En yeni kalan snapshot'ı current'a yükselt (varsa)
    UPDATE public.marketplace_listings
       SET is_current = true,
           superseded_by = NULL
     WHERE id = (
       SELECT id FROM public.marketplace_listings
        WHERE lineage_id = v_lineage AND owner_id = auth.uid()
        ORDER BY created_at DESC
        LIMIT 1
     );
  END IF;
END $$;

GRANT EXECUTE ON FUNCTION public.delete_listing(UUID) TO authenticated;

-- ── 7. Storage quota: shared_items yerine marketplace_listings ─────────────

CREATE OR REPLACE FUNCTION public.get_user_total_storage_used(p_user_id UUID)
RETURNS BIGINT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
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
    COALESCE((SELECT SUM(size_bytes) FROM public.marketplace_listings
              WHERE owner_id = p_user_id), 0);
$$;
