-- ============================================================================
-- 104 — Medya satırı silinince R2 temizliği hemen (pg_net → worker sweep)
-- ============================================================================
-- 099'dan beri `world_media` satırı silinince objenin key'i `r2_evict_queue`'ya
-- düşüyor, ama kuyruğu yalnız worker'ın saatlik cron'u boşaltıyordu: dünyayı/
-- paketi/karakteri yerele alan kullanıcı medyasını bir saate kadar R2'de
-- görüyordu. Artık silmeyi yapan transaction commit olunca Supabase worker'ın
-- `/admin/evict-sweep` ucunu çağırıyor. İstemci değişmedi.
--
-- Ne yapar:
--   A) `pg_net` (Supabase'te hazır; düz Postgres'te yoksa atlanır).
--   B) `world_media` üzerinde AFTER DELETE FOR EACH STATEMENT trigger. Tek
--      trigger her yolu kapsıyor: dünya (`worlds` CASCADE), paket
--      (`user_packages` CASCADE), karakter (`world_characters` CASCADE),
--      hesap silme, sahibin elle silmesi. Bir transaction'da en çok bir
--      istek: 300 görselli dünya ve sahipsiz karakterlerinin cascade'leri
--      tek sweep'e iner.
--
-- `pg_net` isteği commit'ten sonra gönderir; rollback olursa istek de düşer.
-- Yeniden denemez — worker'a ulaşılamazsa satırlar kuyrukta kalır, saatlik
-- cron boşaltır. Sweep çağrı başına 500 satır; fazlası da cron'a kalır.
--
-- Kurulum (bir kez, SQL Editor): worker URL'i ve worker'daki SWEEP_TOKEN
-- secret'ının aynısı Vault'a —
--   SELECT vault.create_secret('https://dmt-assets.<acct>.workers.dev', 'dmt_worker_url');
--   SELECT vault.create_secret('<SWEEP_TOKEN>', 'dmt_sweep_token');
-- Biri yoksa trigger sessizce atlar (davranış 103'teki gibi: yalnız cron).
-- ADMIN_TOKEN bilerek konmuyor: o /admin/purge-all'ı da açıyor.
--
-- Deploy sırası: worker (SWEEP_TOKEN ile) → Vault secret'ları → 104.
-- İdempotent.
-- ============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pg_net') THEN
    CREATE EXTENSION IF NOT EXISTS pg_net;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.kick_r2_evict_sweep()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_url   TEXT;
  v_token TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM gone) THEN
    RETURN NULL;
  END IF;
  IF current_setting('dmt.evict_kicked', true) = '1' THEN
    RETURN NULL;
  END IF;
  IF to_regnamespace('net') IS NULL
     OR to_regclass('vault.decrypted_secrets') IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT decrypted_secret INTO v_url
    FROM vault.decrypted_secrets WHERE name = 'dmt_worker_url';
  SELECT decrypted_secret INTO v_token
    FROM vault.decrypted_secrets WHERE name = 'dmt_sweep_token';
  IF v_url IS NULL OR v_token IS NULL THEN
    RETURN NULL;
  END IF;

  PERFORM set_config('dmt.evict_kicked', '1', true);
  -- Worker istemci koparsa işi kesebilir; 500 R2 silmesi birkaç saniye.
  PERFORM net.http_post(
    url                  := rtrim(v_url, '/') || '/admin/evict-sweep?limit=500',
    headers              := jsonb_build_object(
                              'Authorization', 'Bearer ' || v_token,
                              'Content-Type', 'application/json'),
    timeout_milliseconds := 30000
  );
  RETURN NULL;
END $$;

REVOKE ALL ON FUNCTION public.kick_r2_evict_sweep() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_world_media_kick_sweep ON public.world_media;
CREATE TRIGGER trg_world_media_kick_sweep
  AFTER DELETE ON public.world_media
  REFERENCING OLD TABLE AS gone
  FOR EACH STATEMENT EXECUTE FUNCTION public.kick_r2_evict_sweep();
