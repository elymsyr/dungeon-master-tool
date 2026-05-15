-- ============================================================================
-- 040_drop_personal_characters.sql — chars-için personal_characters retire
-- ============================================================================
-- 039 migration `world_characters`'ı orphan + world-bound tek tablo yaptı ve
-- `personal_characters`'tan orphan backfill çekti. Bu migration personal
-- chars katmanını tamamen kaldırır:
--   - publication membership çıkar
--   - publish/unpublish RPC'leri DROP
--   - tablo DROP
--
-- `personal_packages` ayrı kalır — paketler dual-axis problem yaşamıyor.
-- ============================================================================

-- ── A. Publication membership ───────────────────────────────────────────────

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'personal_characters'
  ) THEN
    ALTER PUBLICATION supabase_realtime DROP TABLE public.personal_characters;
  END IF;
END $$;

-- ── B. RPC'ler ──────────────────────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.publish_personal_character(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.unpublish_personal_character(TEXT);

-- ── C. Tablo ────────────────────────────────────────────────────────────────

DROP TABLE IF EXISTS public.personal_characters CASCADE;

-- ── D. Schema cache reload ──────────────────────────────────────────────────

NOTIFY pgrst, 'reload schema';
