-- ============================================================================
-- 070_beta_inactivity_14d.sql — Beta inaktivite eşiğini 7 → 14 güne çıkar
-- ============================================================================
-- 007_beta_program.sql `beta_inactivity_days()` IMMUTABLE `SELECT 7` döndürüyor.
-- Bu fonksiyon hem `sweep_inactive_beta()` (günlük pg_cron purge cutoff) hem de
-- `get_beta_status()` (client'a gösterilen `inactivity_days`) tarafından runtime'da
-- çağrılıyor — bu yüzden tek `CREATE OR REPLACE` yeterli; sweep/cron/RPC değişmiyor.
--
-- Sweep silme kapsamı AYNI kalır (cloud_backups + storage objects + community_assets
-- + beta_participants). Lokal Drift verisi sweep'ten zaten etkilenmez.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

CREATE OR REPLACE FUNCTION public.beta_inactivity_days()
RETURNS INT LANGUAGE sql IMMUTABLE AS $$ SELECT 14 $$;

ALTER FUNCTION public.beta_inactivity_days() SET search_path = public, pg_temp;

NOTIFY pgrst, 'reload schema';
