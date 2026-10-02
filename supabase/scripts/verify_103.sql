-- ============================================================================
-- verify_103.sql — entity_shares saf izin (103) self-check. Kalıcı değişiklik
-- yapmaz. Kullanım: Supabase Dashboard > SQL Editor > yapıştır > Run.
-- Başarılıysa "103 OK" notice'i döner.
-- ============================================================================

BEGIN;

DO $$
BEGIN
  ASSERT NOT EXISTS (SELECT 1 FROM information_schema.columns
                      WHERE table_schema = 'public' AND table_name = 'entity_shares'
                        AND column_name = 'payload_json'),
    '1 entity_shares.payload_json duruyor';
  ASSERT NOT EXISTS (SELECT 1 FROM pg_constraint
                      WHERE conname = 'chk_entity_shares_payload_size'),
    '2 512 KB CHECK duruyor';
  ASSERT to_regprocedure('public.max_share_payload_bytes()') IS NULL,
    '3 max_share_payload_bytes duruyor';
  ASSERT to_regprocedure('public.max_shares_per_world()') IS NOT NULL,
    '4 4000 satır tavanı kayboldu';
  ASSERT to_regprocedure('public.get_shared_entities(text, bigint, text[])') IS NOT NULL
     AND to_regprocedure('public.get_shared_entity_stamps(text)') IS NOT NULL,
    '5 102''nin kapıları yok';
  RAISE NOTICE '103 OK';
END $$;

ROLLBACK;
