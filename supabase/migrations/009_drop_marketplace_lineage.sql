-- ============================================================================
-- DMT — Marketplace lineage kaldırımı
-- ============================================================================
-- Lineage/version chaining modelini kaldırır. Her publish bağımsız bir satır
-- üretir; kullanıcılar eski snapshot'ları manuel siler. İlgili RPC'ler ve
-- kolonlar (`lineage_id`, `is_current`, `superseded_by`) drop edilir.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

-- ── 0. Eski RPC'leri düşür ────────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.lineage_current_versions(UUID[]);
DROP FUNCTION IF EXISTS public.publish_listing_snapshot(
  UUID, UUID, TEXT, TEXT, TEXT, TEXT, TEXT[], TEXT, TEXT, TEXT, BIGINT
);
DROP FUNCTION IF EXISTS public.delete_listing(UUID);

-- ── 1. Trigger'ı geçici olarak devre dışı bırak ───────────────────────────
-- Kolon drop sırasında immutability kontrolü bizi engellememeli.

DROP TRIGGER IF EXISTS trg_listings_immutable ON public.marketplace_listings;

-- ── 2. Kolonları drop et ──────────────────────────────────────────────────

DROP INDEX IF EXISTS public.idx_ml_lineage;
DROP INDEX IF EXISTS public.idx_ml_current;

ALTER TABLE public.marketplace_listings DROP COLUMN IF EXISTS lineage_id;
ALTER TABLE public.marketplace_listings DROP COLUMN IF EXISTS is_current;
ALTER TABLE public.marketplace_listings DROP COLUMN IF EXISTS superseded_by;

-- ── 3. Immutability trigger'ı sadeleştir ──────────────────────────────────
-- Sadece download_count ve changelog mutate edilebilir.

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
     OR NEW.created_at <> OLD.created_at
  THEN
    RAISE EXCEPTION 'marketplace_listings: immutable column modified';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER trg_listings_immutable
  BEFORE UPDATE ON public.marketplace_listings
  FOR EACH ROW EXECUTE FUNCTION public.enforce_listing_immutability();

-- ── 4. publish_listing_snapshot RPC (lineage'siz) ─────────────────────────

CREATE OR REPLACE FUNCTION public.publish_listing_snapshot(
  p_listing_id    UUID,
  p_item_type     TEXT,
  p_title         TEXT,
  p_description   TEXT,
  p_language      TEXT,
  p_tags          TEXT[],
  p_changelog     TEXT,
  p_content_hash  TEXT,
  p_payload_path  TEXT,
  p_size_bytes    BIGINT
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_new_id UUID := COALESCE(p_listing_id, gen_random_uuid());
BEGIN
  INSERT INTO public.marketplace_listings (
    id, owner_id, item_type, title, description, language,
    tags, changelog, content_hash, payload_path, size_bytes
  ) VALUES (
    v_new_id, auth.uid(), p_item_type, p_title, p_description, p_language,
    COALESCE(p_tags, '{}'), p_changelog, p_content_hash, p_payload_path, p_size_bytes
  );
  RETURN v_new_id;
END $$;

GRANT EXECUTE ON FUNCTION public.publish_listing_snapshot(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT[], TEXT, TEXT, TEXT, BIGINT
) TO authenticated;

-- ── 5. delete_listing RPC (sade) ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.delete_listing(p_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_owner UUID;
BEGIN
  SELECT owner_id INTO v_owner
    FROM public.marketplace_listings
   WHERE id = p_id;

  IF v_owner IS NULL THEN
    RETURN;  -- already gone
  END IF;
  IF v_owner <> auth.uid() THEN
    RAISE EXCEPTION 'not owner';
  END IF;

  DELETE FROM public.marketplace_listings WHERE id = p_id;
END $$;

GRANT EXECUTE ON FUNCTION public.delete_listing(UUID) TO authenticated;

-- ── 6. PostgREST schema cache reload ──────────────────────────────────────
-- Ensure PostgREST picks up the new function signature immediately so the
-- client stops hitting PGRST202 against the cached 11-parameter signature.
NOTIFY pgrst, 'reload schema';
