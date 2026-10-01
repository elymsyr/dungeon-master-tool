-- ============================================================================
-- verify_100.sql — Faz 5e (100) self-check. Hiçbir kalıcı değişiklik yapmaz.
-- ============================================================================
-- Kullanım: Supabase Dashboard > SQL Editor > yapıştır > Run.
-- Sonunda ROLLBACK var; başarılıysa "100 OK" notice'i döner, aksi halde ilk
-- başarısız assertion exception olarak patlar. Dünya kapsamının kuralları
-- verify_099.sql'de (100'ün RPC adlarıyla).
--
-- Kapsam:
--   1. Şema: ikinci kapsam kolonu, tek kapsam CHECK'i, 099'un RPC'leri gitti.
--   2. Paket rezervasyonu: yalnız sahip; kapsam karışmaz; key'i bozan id
--      reddedilir; aynı sha dünyada ve pakette iki ayrı satır.
--   3. İmza RPC'leri: put yalnız paketin sahibine; get sahibine, yabancıya
--      ve paketin olmayan bir dünyanın üyesine değil; key `packages/…`.
--   4. RLS: paketin medyasını yalnız sahibi okur ve siler.
--   5. Kota: paket medyası kişi başı sayıya giriyor.
--   6. Silme → `packages/` key'i kuyrukta; yeniden canlanan silinmez;
--      paket buluttan silinince (yerele alma) her obje kuyrukta.
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_owner  UUID := gen_random_uuid();
  v_player UUID := gen_random_uuid();
  v_other  UUID := gen_random_uuid();
  v_a      TEXT := repeat('a', 64);
  v_b      TEXT := repeat('b', 64);
  v_r      JSONB;
  v_n      INT;
  v_ok     BOOLEAN;
  v_key    TEXT;
BEGIN
  -- ══ 1 — Şema ═══════════════════════════════════════════════════════════
  ASSERT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema = 'public' AND table_name = 'world_media'
                    AND column_name = 'package_id'),
    '1.1 world_media.package_id yok';
  ASSERT (SELECT is_nullable FROM information_schema.columns
           WHERE table_schema = 'public' AND table_name = 'world_media'
             AND column_name = 'world_id') = 'YES',
    '1.2 world_id hâlâ NOT NULL';
  ASSERT to_regprocedure('public.world_media_reserve(text, jsonb)') IS NULL
     AND to_regprocedure('public.world_media_confirm(text, text[])') IS NULL
     AND to_regprocedure('public.world_media_sign_put(uuid, text, text[])') IS NULL
     AND to_regprocedure('public.world_media_sign_get(uuid, text[])') IS NULL,
    '1.3 099''un dünyaya bağlı RPC''si duruyor';
  ASSERT has_function_privilege('authenticated',
           'public.media_sign_put(uuid, text, text, text[])', 'EXECUTE') = FALSE
     AND has_function_privilege('authenticated',
           'public.media_sign_get(uuid, text[])', 'EXECUTE') = FALSE,
    '1.4 imza RPC''si istemciye açık';
  ASSERT public.media_r2_key(NULL, 'p1', v_a, '.png') = 'packages/p1/' || v_a || '.png'
     AND public.media_r2_key('w1', NULL, v_a, '') = 'worlds/w1/' || v_a,
    '1.5 key yerleşimi yanlış';

  -- ══ Kurulum ════════════════════════════════════════════════════════════
  INSERT INTO auth.users (id, aud, role, email) VALUES
    (v_owner,  'authenticated', 'authenticated', 'verify100-ow@example.invalid'),
    (v_player, 'authenticated', 'authenticated', 'verify100-pl@example.invalid'),
    (v_other,  'authenticated', 'authenticated', 'verify100-ot@example.invalid');
  INSERT INTO public.user_packages (id, owner_id, name) VALUES
    ('p100', v_owner, 'Canavarlar'), ('p100b', v_other, 'Başkasının');
  -- Sahibin bir de dünyası var; oyuncu o dünyanın üyesi, paketin değil.
  INSERT INTO public.worlds (id, owner_id, world_name) VALUES ('w100', v_owner, 'Dünya');
  INSERT INTO public.world_members (world_id, user_id, role) VALUES
    ('w100', v_owner, 'dm'), ('w100', v_player, 'player')
    ON CONFLICT DO NOTHING;   -- worlds trigger'ı sahibin satırını zaten yazıyor

  -- Tek kapsam: ikisi birden ya da hiçbiri olmaz.
  v_ok := FALSE;
  BEGIN
    INSERT INTO public.world_media (world_id, package_id, sha256, ext, bytes, kind, mime)
      VALUES ('w100', 'p100', v_a, '.png', 1, 'world_entity_image', 'image/png');
  EXCEPTION WHEN check_violation THEN v_ok := TRUE;
  END;
  ASSERT v_ok, '1.6 iki kapsamlı satır yazıldı';
  v_ok := FALSE;
  BEGIN
    INSERT INTO public.world_media (sha256, ext, bytes, kind, mime)
      VALUES (v_a, '.png', 1, 'world_entity_image', 'image/png');
  EXCEPTION WHEN check_violation THEN v_ok := TRUE;
  END;
  ASSERT v_ok, '1.7 kapsamsız satır yazıldı';

  -- ══ 2 — Paket rezervasyonu ═════════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_owner, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);

  v_r := public.media_reserve('package', 'p100', jsonb_build_array(
    jsonb_build_object('sha', v_a, 'ext', '.png', 'bytes', 1000,
                       'kind', 'world_entity_image', 'mime', 'image/png'),
    jsonb_build_object('sha', v_b, 'ext', '.pdf', 'bytes', 25000000,
                       'kind', 'world_pdf', 'mime', 'application/pdf')));
  ASSERT v_r->'upload' = jsonb_build_array(v_a), format('2.1 upload listesi yanlış: %s', v_r);
  ASSERT v_r->'too_large' = jsonb_build_array(v_b), format('2.2 too_large yanlış: %s', v_r);

  -- Aynı sha sahibin dünyasında da: ayrı satır, ayrı obje.
  v_r := public.media_reserve('world', 'w100', jsonb_build_array(
    jsonb_build_object('sha', v_a, 'ext', '.png', 'bytes', 1000,
                       'kind', 'world_entity_image', 'mime', 'image/png')));
  ASSERT v_r->'upload' = jsonb_build_array(v_a), format('2.3 dünya rezervasyonu pakete takıldı: %s', v_r);

  PERFORM set_config('role', 'postgres', true);
  ASSERT (SELECT count(*) FROM public.world_media WHERE sha256 = v_a) = 2,
    '2.4 aynı sha iki kapsamda iki satır değil';
  ASSERT (SELECT world_id IS NULL FROM public.world_media WHERE package_id = 'p100'),
    '2.5 paket satırı dünyaya da bağlandı';
  PERFORM set_config('role', 'authenticated', true);

  -- Onay kapsamına bakar: paketin onayı dünyanınkini açmaz.
  ASSERT public.media_confirm('package', 'p100', ARRAY[v_a]) = 1, '2.6 paket onayı tutmadı';
  PERFORM set_config('role', 'postgres', true);
  ASSERT (SELECT NOT uploaded FROM public.world_media WHERE world_id = 'w100' AND sha256 = v_a),
    '2.7 paketin onayı dünyanın satırını da açtı';
  PERFORM set_config('role', 'authenticated', true);

  -- Paket id'si dünya kapsamında aranmaz; key'i bozan id reddedilir.
  v_ok := FALSE;
  BEGIN
    PERFORM public.media_reserve('world', 'p100', '[]'::jsonb);
  EXCEPTION WHEN insufficient_privilege THEN v_ok := TRUE;
  END;
  ASSERT v_ok, '2.8 paket id''si dünya kapsamında kabul edildi';
  v_ok := FALSE;
  BEGIN
    PERFORM public.media_reserve('package', 'p100/../w100', '[]'::jsonb);
  EXCEPTION WHEN insufficient_privilege THEN v_ok := TRUE;
  END;
  ASSERT v_ok, '2.9 key''i bozan kapsam id''si kabul edildi';

  -- Başkası (dünyanın oyuncusu dahil) pakete rezerve edemez, onay veremez.
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_player, 'role', 'authenticated')::text, true);
  v_ok := FALSE;
  BEGIN
    PERFORM public.media_reserve('package', 'p100', '[]'::jsonb);
  EXCEPTION WHEN insufficient_privilege THEN v_ok := TRUE;
  END;
  ASSERT v_ok, '2.10 BAŞKASI PAKETE MEDYA REZERVE ETTİ';
  v_ok := FALSE;
  BEGIN
    PERFORM public.media_confirm('package', 'p100', ARRAY[v_a]);
  EXCEPTION WHEN insufficient_privilege THEN v_ok := TRUE;
  END;
  ASSERT v_ok, '2.11 başkası paketin onayını verdi';

  -- ══ 4 — RLS ════════════════════════════════════════════════════════════
  -- Oyuncu sahibin dünyasının üyesi: dünyanın satırını görür, paketinkini değil.
  ASSERT (SELECT count(*) FROM public.world_media WHERE package_id = 'p100') = 0,
    '4.1 DÜNYANIN OYUNCUSU SAHİBİN PAKET MEDYASINI GÖRDÜ';
  ASSERT (SELECT count(*) FROM public.world_media WHERE world_id = 'w100') = 1,
    '4.2 üye dünyanın medyasını göremiyor';
  DELETE FROM public.world_media WHERE package_id = 'p100';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 0, '4.3 BAŞKASI PAKETİN MEDYASINI SİLDİ';

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_owner, 'role', 'authenticated')::text, true);
  ASSERT (SELECT count(*) FROM public.world_media WHERE package_id = 'p100') = 1,
    '4.4 sahip paketinin medya listesini okuyamıyor';

  -- ══ 3 — İmza RPC'leri (worker, service_role) ═══════════════════════════
  PERFORM set_config('role', 'postgres', true);
  SELECT r2_key INTO v_key FROM public.media_sign_put(v_owner, 'package', 'p100', ARRAY[v_a]);
  ASSERT v_key = 'packages/p100/' || v_a || '.png', format('3.1 PUT key''i yanlış: %s', v_key);
  ASSERT (SELECT count(*) FROM public.media_sign_put(v_other, 'package', 'p100', ARRAY[v_a])) = 0,
    '3.2 BAŞKASINA PAKET PUT İMZASI VERİLDİ';
  ASSERT (SELECT count(*) FROM public.media_sign_put(v_owner, 'world', 'p100', ARRAY[v_a])) = 0,
    '3.3 kapsam karıştı: paket satırı dünya imzası aldı';
  SELECT r2_key INTO v_key FROM public.media_sign_get(v_owner, ARRAY[v_a]);
  ASSERT v_key = 'packages/p100/' || v_a || '.png', format('3.4 sahip paket görselini çekemiyor: %s', v_key);
  ASSERT (SELECT count(*) FROM public.media_sign_get(v_player, ARRAY[v_a])) = 0,
    '3.5 ONAYSIZ DÜNYA SATIRI YA DA PAKET OYUNCUYA İMZALANDI';
  ASSERT (SELECT count(*) FROM public.media_sign_get(v_other, ARRAY[v_a])) = 0,
    '3.6 YABANCIYA PAKET GET İMZASI VERİLDİ';
  -- Dünyanın satırı onaylanınca üye onu çeker — dünya key'iyle.
  UPDATE public.world_media SET uploaded = TRUE WHERE world_id = 'w100';
  SELECT r2_key INTO v_key FROM public.media_sign_get(v_player, ARRAY[v_a]);
  ASSERT v_key = 'worlds/w100/' || v_a || '.png', format('3.7 üyeye yanlış key: %s', v_key);

  -- ══ 5 — Kota ═══════════════════════════════════════════════════════════
  -- Pakette 1 GB'a 500 bayt kala dolu bir satır: dünyaya 1000 baytlık yeni
  -- dosya sığmamalı — iki kapsam tek sayı.
  INSERT INTO public.world_media (package_id, sha256, ext, bytes, kind, mime, uploaded)
    VALUES ('p100', repeat('c', 64), '.png',
            public.world_media_user_cap_bytes() - 1000 - 1000 - 500,
            'world_entity_image', 'image/png', TRUE);
  PERFORM set_config('role', 'authenticated', true);
  ASSERT (public.get_media_quota()->>'user_used')::bigint
         = public.world_media_user_cap_bytes() - 500,
    format('5.1 paket medyası kotaya sayılmadı: %s', public.get_media_quota());
  v_ok := FALSE;
  BEGIN
    PERFORM public.media_reserve('world', 'w100', jsonb_build_array(
      jsonb_build_object('sha', repeat('d', 64), 'ext', '.png', 'bytes', 1000,
                         'kind', 'world_entity_image', 'mime', 'image/png')));
  EXCEPTION WHEN raise_exception THEN
    v_ok := SQLERRM = 'media_user_full';
  END;
  ASSERT v_ok, '5.2 paket + dünya kişi başı tavanı aştı';

  -- ══ 6 — Silme, kuyruk, CASCADE ═════════════════════════════════════════
  PERFORM set_config('role', 'postgres', true);
  DELETE FROM public.r2_evict_queue;
  PERFORM set_config('role', 'authenticated', true);
  DELETE FROM public.world_media WHERE package_id = 'p100' AND sha256 = v_a;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, '6.1 sahip paketinin medyasını silemedi';

  PERFORM set_config('role', 'postgres', true);
  SELECT r2_key INTO v_key FROM public.r2_evict_queue WHERE sha256 = v_a;
  ASSERT v_key = 'packages/p100/' || v_a || '.png', format('6.2 kuyruğa yanlış key: %s', v_key);

  -- Pop'tan önce aynı sha pakete yeniden rezerve edildi → obje canlı.
  INSERT INTO public.world_media (package_id, sha256, ext, bytes, kind, mime)
    VALUES ('p100', v_a, '.png', 1000, 'world_entity_image', 'image/png');
  ASSERT NOT EXISTS (SELECT 1 FROM public.r2_evict_pop(10) WHERE r2_key LIKE 'packages/%'),
    '6.3 YENİDEN CANLANAN PAKET OBJESİ SİLİNMEK ÜZERE DÖNDÜ';
  ASSERT NOT EXISTS (SELECT 1 FROM public.r2_evict_queue), '6.4 bayat satır kuyrukta kaldı';

  -- Yerele alma = user_packages satırının silinmesi → her obje kuyruğa.
  SELECT count(*) INTO v_n FROM public.world_media WHERE package_id = 'p100';
  DELETE FROM public.user_packages WHERE id = 'p100';
  ASSERT NOT EXISTS (SELECT 1 FROM public.world_media WHERE package_id = 'p100'),
    '6.5 paket silinince medya satırları kaldı';
  ASSERT (SELECT count(*) FROM public.r2_evict_queue WHERE r2_key LIKE 'packages/p100/%') = v_n,
    '6.6 CASCADE her objeyi kuyruğa atmadı';
  ASSERT (SELECT count(*) FROM public.r2_evict_pop(100) WHERE r2_key LIKE 'packages/p100/%') = v_n,
    '6.7 silinmiş paketin objeleri worker''a dönmedi';
  ASSERT EXISTS (SELECT 1 FROM public.world_media WHERE world_id = 'w100'),
    '6.8 paketi silmek dünyanın aynı sha''lı satırını da götürdü';

  RAISE NOTICE '100 OK';
END $$;

ROLLBACK;
