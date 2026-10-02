-- ============================================================================
-- verify_104.sql — 104 self-check. Hiçbir kalıcı değişiklik yapmaz.
-- ============================================================================
-- Kullanım: Supabase Dashboard > SQL Editor > yapıştır > Run.
-- Sonunda ROLLBACK var; başarılıysa "104 OK" notice'i döner. ROLLBACK
-- `pg_net`'in kuyruğa yazdığı isteği de geri alır — worker'a bir şey gitmez.
--
-- Kapsam:
--   1. Şema: trigger ve fonksiyon var.
--   2. Hiç satır silmeyen DELETE istek kuyruğa yazmaz.
--   3. Dünya ve paket aynı transaction'da silinince (CASCADE) kuyruğa tek
--      istek düşer; key'ler `r2_evict_queue`'da.
-- Vault secret'ları yoksa 3 "istek yok" diye doğrulanır ve notice söyler.
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_owner UUID := gen_random_uuid();
  v_a     TEXT := repeat('a', 64);
  v_b     TEXT := repeat('b', 64);
  v_conf  BOOLEAN;
  v_net0  BIGINT;
BEGIN
  -- ══ 1 — Şema ═══════════════════════════════════════════════════════════
  ASSERT EXISTS (SELECT 1 FROM pg_trigger
                  WHERE tgname = 'trg_world_media_kick_sweep'
                    AND tgrelid = 'public.world_media'::regclass),
    '1.1 trg_world_media_kick_sweep yok';
  ASSERT to_regprocedure('public.kick_r2_evict_sweep()') IS NOT NULL,
    '1.2 kick_r2_evict_sweep yok';
  ASSERT to_regclass('net.http_request_queue') IS NOT NULL,
    '1.3 pg_net kurulu değil';

  v_conf := to_regclass('vault.decrypted_secrets') IS NOT NULL
    AND (SELECT count(*) FROM vault.decrypted_secrets
          WHERE name IN ('dmt_worker_url', 'dmt_sweep_token')) = 2;

  INSERT INTO auth.users (id, aud, role, email) VALUES
    (v_owner, 'authenticated', 'authenticated', 'o104@test.local');
  INSERT INTO public.worlds (id, owner_id, world_name) VALUES ('w104', v_owner, 'Dünya');
  INSERT INTO public.user_packages (id, owner_id, name) VALUES ('p104', v_owner, 'Paket');
  INSERT INTO public.world_media (world_id, sha256, ext, bytes, kind, mime) VALUES
    ('w104', v_a, '.png', 10, 'image', 'image/png'),
    ('w104', v_b, '.png', 10, 'image', 'image/png');
  INSERT INTO public.world_media (package_id, sha256, ext, bytes, kind, mime) VALUES
    ('p104', v_a, '.png', 10, 'image', 'image/png');

  -- ══ 2 — Boş DELETE istek atmaz ═════════════════════════════════════════
  SELECT count(*) INTO v_net0 FROM net.http_request_queue;
  DELETE FROM public.world_media WHERE world_id = 'yok104';
  ASSERT (SELECT count(*) FROM net.http_request_queue) = v_net0,
    '2.1 hiç satır silinmedi ama istek kuyruğa yazıldı';

  -- ══ 3 — Dünya + paket silme → tek istek ════════════════════════════════
  DELETE FROM public.worlds WHERE id = 'w104';
  DELETE FROM public.user_packages WHERE id = 'p104';
  ASSERT NOT EXISTS (SELECT 1 FROM public.world_media
                      WHERE world_id = 'w104' OR package_id = 'p104'),
    '3.1 CASCADE medya satırlarını silmedi';
  ASSERT (SELECT count(*) FROM public.r2_evict_queue
           WHERE r2_key IN ('worlds/w104/' || v_a || '.png',
                            'worlds/w104/' || v_b || '.png',
                            'packages/p104/' || v_a || '.png')) = 3,
    '3.2 key''ler r2_evict_queue''da değil';
  IF v_conf THEN
    ASSERT (SELECT count(*) FROM net.http_request_queue) = v_net0 + 1,
      '3.3 iki CASCADE tek istek olmalıydı';
    ASSERT (SELECT url FROM net.http_request_queue ORDER BY id DESC LIMIT 1)
             LIKE '%/admin/evict-sweep?limit=500',
      '3.4 istek sweep ucuna gitmiyor';
    RAISE NOTICE '104 OK';
  ELSE
    ASSERT (SELECT count(*) FROM net.http_request_queue) = v_net0,
      '3.3 secret yokken istek kuyruğa yazıldı';
    RAISE NOTICE '104 OK (Vault secret''ları yok — yalnız cron boşaltır)';
  END IF;
END $$;

ROLLBACK;
