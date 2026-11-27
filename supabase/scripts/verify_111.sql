-- ============================================================================
-- verify_111.sql — misafir bildirimleri (111) self-check. Hiçbir kalıcı
-- değişiklik yapmaz.
-- ============================================================================
-- Kullanım: Supabase Dashboard > SQL Editor > yapıştır > Run.
-- Sonunda ROLLBACK var; başarılıysa "111 OK" notice'i döner, aksi halde ilk
-- başarısız assertion exception olarak patlar.
--
-- Kapsam:
--   1. anon list_notifications() çağırabilir.
--   2. anon yalnız yayınlanmış bildirimleri görür; my_answers NULL, read false.
--   3. anon'un submit / mark_read / dismiss çağrıları hiçbir şey yazmaz.
--   4. anon notifications tablosunu doğrudan okuyamaz (081 korunur).
--   5. Giriş yapmış kullanıcının davranışı değişmedi (okundu + dismiss).
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_user UUID := gen_random_uuid();
  v_pub  UUID := gen_random_uuid();
  v_hid  UUID := gen_random_uuid();
  v_n    INT;
  v_ok   BOOLEAN;
BEGIN
  INSERT INTO auth.users (id, aud, role, email)
    VALUES (v_user, 'authenticated', 'authenticated', 'u111@test.local');
  INSERT INTO public.notifications (id, title, blocks, published) VALUES
    (v_pub, 'v111 published', '[]'::jsonb, true),
    (v_hid, 'v111 hidden',    '[]'::jsonb, false);

  -- ══ 1 — anon EXECUTE ═══════════════════════════════════════════════════
  ASSERT has_function_privilege('anon', 'public.list_notifications()', 'EXECUTE'),
    '1.1 anon list_notifications() çağıramıyor';

  -- ══ 2 — anon görünürlüğü ═══════════════════════════════════════════════
  PERFORM set_config('request.jwt.claims', '{"role":"anon"}', true);
  PERFORM set_config('role', 'anon', true);

  ASSERT EXISTS (SELECT 1 FROM public.list_notifications()
                  WHERE id = v_pub AND my_answers IS NULL AND NOT read),
    '2.1 anon yayınlanmış bildirimi görmüyor (ya da read/my_answers dolu)';
  ASSERT NOT EXISTS (SELECT 1 FROM public.list_notifications() WHERE id = v_hid),
    '2.2 anon yayınlanmamış bildirimi görüyor';

  -- ══ 3 — anon yazamaz (yetki hatası ya da no-op; ikisi de kabul) ════════
  BEGIN
    v_ok := public.submit_notification_response(v_pub, '{}'::jsonb);
    ASSERT NOT v_ok, '3.1 anon submit TRUE döndü';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM public.mark_notification_read(v_pub);
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    v_n := public.dismiss_read_notifications();
    ASSERT COALESCE(v_n, 0) = 0, '3.2 anon dismiss bir şey sildi';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  -- ══ 4 — tablo kapalı ═══════════════════════════════════════════════════
  BEGIN
    PERFORM 1 FROM public.notifications LIMIT 1;
    RAISE EXCEPTION '4.1 anon notifications tablosunu doğrudan okuyabiliyor';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  PERFORM set_config('role', 'postgres', true);
  ASSERT NOT EXISTS (SELECT 1 FROM public.notification_responses WHERE notification_id = v_pub),
    '3.3 anon yanıtı yazıldı';
  ASSERT NOT EXISTS (SELECT 1 FROM public.notification_reads WHERE notification_id = v_pub),
    '3.4 anon okundu kaydı yazıldı';

  -- ══ 5 — authenticated değişmedi ════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_user, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);

  ASSERT EXISTS (SELECT 1 FROM public.list_notifications() WHERE id = v_pub AND NOT read),
    '5.1 kullanıcı bildirimi görmüyor';
  PERFORM public.mark_notification_read(v_pub);
  ASSERT EXISTS (SELECT 1 FROM public.list_notifications() WHERE id = v_pub AND read),
    '5.2 okundu işaretlenmedi';
  PERFORM public.dismiss_read_notifications();
  ASSERT NOT EXISTS (SELECT 1 FROM public.list_notifications() WHERE id = v_pub),
    '5.3 dismiss sonrası bildirim hâlâ görünüyor';

  PERFORM set_config('role', 'postgres', true);
  RAISE NOTICE '111 OK';
END $$;

ROLLBACK;
