-- ============================================================================
-- verify_099.sql — Faz 5d (099) self-check. Hiçbir kalıcı değişiklik yapmaz.
-- ============================================================================
-- Kullanım: Supabase Dashboard > SQL Editor > yapıştır > Run.
-- Sonunda ROLLBACK var; başarılıysa "099 OK" notice'i döner, aksi halde ilk
-- başarısız assertion exception olarak patlar.
--
-- Kapsam:
--   1. Sabitler; transient'ten iz kalmadı, kuyruk yeniden adlandırıldı.
--   2. Rezervasyon: yalnız sahip; limit aşan atlanır; tekrar rezervasyon
--      onaysızı yeniden döner, onaylıyı atlar.
--   3. İmza RPC'leri: put yalnız sahibe, get yalnız üyeye ve yalnız onaylıya.
--   4. RLS: üye okur, yabancı okumaz; silme yalnız sahibin.
--   5. Kişi başı ve toplam tavan — aşan parti hiç satır yazmaz.
--   6. Silme → kuyruk; yeniden canlanan obje silinmez; dünya CASCADE'i.
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_dm     UUID := gen_random_uuid();
  v_player UUID := gen_random_uuid();
  v_other  UUID := gen_random_uuid();
  v_a      TEXT := repeat('a', 64);
  v_b      TEXT := repeat('b', 64);
  v_c      TEXT := repeat('c', 64);
  v_r      JSONB;
  v_n      INT;
  v_ok     BOOLEAN;
  v_key    TEXT;
BEGIN
  -- ══ 1 — Sabitler ve söküm ══════════════════════════════════════════════
  ASSERT public.media_total_cap_bytes()      = 9663676416::bigint, '1.1 toplam tavan != 9 GB';
  ASSERT public.world_media_user_cap_bytes() = 1073741824::bigint, '1.2 kişi başı != 1 GB';
  ASSERT public.world_media_max_bytes('battle_map')         = 10485760, '1.3 harita != 10 MB';
  ASSERT public.world_media_max_bytes('world_entity_image') = 5242880,  '1.3 görsel != 5 MB';
  ASSERT public.world_media_max_bytes('world_audio')        = 10485760, '1.3 ses != 10 MB';
  ASSERT public.world_media_max_bytes('world_pdf')          = 20971520, '1.3 pdf != 20 MB';
  ASSERT public.world_media_max_bytes('character_portrait') IS NULL,    '1.3 bilinmeyen tür limit aldı';
  ASSERT NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                      WHERE n.nspname = 'public'
                        AND (p.proname ILIKE '%transient%' OR p.prosrc ILIKE '%transient_%'
                             OR p.prosrc ILIKE '%missing_shas%')),
    '1.4 transient / missing_shas taşıyan fonksiyon kaldı';
  ASSERT to_regclass('public.transient_shares') IS NULL,      '1.5 transient_shares duruyor';
  ASSERT to_regclass('public.transient_evict_queue') IS NULL, '1.5 eski kuyruk adı duruyor';
  ASSERT to_regclass('public.r2_evict_queue') IS NOT NULL,    '1.5 r2_evict_queue yok';
  ASSERT NOT EXISTS (SELECT 1 FROM information_schema.columns
                      WHERE table_schema = 'public' AND column_name = 'missing_shas'),
    '1.6 missing_shas kolonu duruyor';

  -- ══ Kurulum ════════════════════════════════════════════════════════════
  INSERT INTO auth.users (id, aud, role, email) VALUES
    (v_dm,     'authenticated', 'authenticated', 'verify099-dm@example.invalid'),
    (v_player, 'authenticated', 'authenticated', 'verify099-pl@example.invalid'),
    (v_other,  'authenticated', 'authenticated', 'verify099-ot@example.invalid');
  INSERT INTO public.worlds (id, owner_id, world_name) VALUES
    ('w099', v_dm, 'Dünya'), ('w099b', v_other, 'Başkası');
  INSERT INTO public.world_members (world_id, user_id, role) VALUES
    ('w099', v_dm, 'dm'), ('w099', v_player, 'player'), ('w099b', v_other, 'dm')
    ON CONFLICT DO NOTHING;   -- worlds trigger'ı sahibin satırını zaten yazıyor

  -- ══ 2 — Rezervasyon ════════════════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_dm, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);

  v_r := public.world_media_reserve('w099', jsonb_build_array(
    jsonb_build_object('sha', v_a, 'ext', '.png', 'bytes', 1000,
                       'kind', 'world_entity_image', 'mime', 'image/png'),
    jsonb_build_object('sha', v_b, 'ext', '.jpg', 'bytes', 9000000,
                       'kind', 'battle_map', 'mime', 'image/jpeg'),
    -- 6 MB "diğer görsel": limit 5 MB → atlanır, hata değil
    jsonb_build_object('sha', v_c, 'ext', '.png', 'bytes', 6291456,
                       'kind', 'world_entity_image', 'mime', 'image/png')));
  ASSERT v_r->'upload' = jsonb_build_array(v_a, v_b), format('2.1 upload listesi yanlış: %s', v_r);
  ASSERT v_r->'too_large' = jsonb_build_array(v_c), format('2.2 too_large yanlış: %s', v_r);

  PERFORM set_config('role', 'postgres', true);
  ASSERT (SELECT count(*) FROM public.world_media WHERE world_id = 'w099') = 2,
    '2.3 limit aşan dosyanın satırı yazıldı';
  ASSERT NOT EXISTS (SELECT 1 FROM public.world_media WHERE uploaded),
    '2.4 satır onaysız doğmadı';
  PERFORM set_config('role', 'authenticated', true);

  -- Onaysız tekrar döner (yarıda kalan tur), onaylı atlanır.
  PERFORM public.world_media_confirm('w099', ARRAY[v_a]);
  v_r := public.world_media_reserve('w099', jsonb_build_array(
    jsonb_build_object('sha', v_a, 'ext', '.png', 'bytes', 1000,
                       'kind', 'world_entity_image', 'mime', 'image/png'),
    jsonb_build_object('sha', v_b, 'ext', '.jpg', 'bytes', 9000000,
                       'kind', 'battle_map', 'mime', 'image/jpeg')));
  ASSERT v_r->'upload' = jsonb_build_array(v_b), format('2.5 tekrar rezervasyon yanlış: %s', v_r);

  v_ok := FALSE;
  BEGIN
    PERFORM public.world_media_reserve('w099', jsonb_build_array(
      jsonb_build_object('sha', v_c, 'ext', '/../x', 'bytes', 10,
                         'kind', 'world_entity_image', 'mime', 'image/png')));
  EXCEPTION WHEN invalid_parameter_value THEN v_ok := TRUE;
  END;
  ASSERT v_ok, '2.6 key''i bozan uzantı kabul edildi';

  v_ok := FALSE;
  BEGIN
    PERFORM public.world_media_reserve('w099', jsonb_build_array(
      jsonb_build_object('sha', v_c, 'ext', '.exe', 'bytes', 10,
                         'kind', 'world_entity_image', 'mime', 'application/x-msdownload')));
  EXCEPTION WHEN invalid_parameter_value THEN v_ok := TRUE;
  END;
  ASSERT v_ok, '2.7 izinsiz MIME kabul edildi';

  -- Oyuncu (üye ama sahip değil) rezerve edemez.
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_player, 'role', 'authenticated')::text, true);
  v_ok := FALSE;
  BEGIN
    PERFORM public.world_media_reserve('w099', '[]'::jsonb);
  EXCEPTION WHEN insufficient_privilege THEN v_ok := TRUE;
  END;
  ASSERT v_ok, '2.8 OYUNCU DÜNYAYA MEDYA REZERVE ETTİ';
  v_ok := FALSE;
  BEGIN
    PERFORM public.world_media_confirm('w099', ARRAY[v_b]);
  EXCEPTION WHEN insufficient_privilege THEN v_ok := TRUE;
  END;
  ASSERT v_ok, '2.9 oyuncu onay verebildi';

  -- ══ 4 — RLS ════════════════════════════════════════════════════════════
  ASSERT (SELECT count(*) FROM public.world_media WHERE world_id = 'w099') = 2,
    '4.1 üye dünyanın medya listesini okuyamıyor';
  DELETE FROM public.world_media WHERE world_id = 'w099';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 0, '4.2 OYUNCU DÜNYANIN MEDYASINI SİLDİ';

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_other, 'role', 'authenticated')::text, true);
  ASSERT (SELECT count(*) FROM public.world_media WHERE world_id = 'w099') = 0,
    '4.3 YABANCI DÜNYANIN MEDYASINI GÖRDÜ';
  v_ok := FALSE;
  BEGIN
    PERFORM public.world_media_reserve('w099', '[]'::jsonb);
  EXCEPTION WHEN insufficient_privilege THEN v_ok := TRUE;
  END;
  ASSERT v_ok, '4.4 yabancı başkasının dünyasına rezerve etti';

  -- ══ 3 — İmza RPC'leri (worker, service_role) ═══════════════════════════
  PERFORM set_config('role', 'postgres', true);
  ASSERT (SELECT count(*) FROM public.world_media_sign_put(v_dm, 'w099', ARRAY[v_a, v_b])) = 2,
    '3.1 sahip PUT imzası alamıyor';
  ASSERT (SELECT bytes FROM public.world_media_sign_put(v_dm, 'w099', ARRAY[v_b])) = 9000000,
    '3.2 imzaya bağlanacak boyut yanlış';
  ASSERT (SELECT count(*) FROM public.world_media_sign_put(v_player, 'w099', ARRAY[v_a])) = 0,
    '3.3 OYUNCUYA PUT İMZASI VERİLDİ';
  ASSERT (SELECT world_id FROM public.world_media_sign_get(v_player, ARRAY[v_a])) = 'w099',
    '3.4 üye onaylı görseli çekemiyor';
  ASSERT (SELECT count(*) FROM public.world_media_sign_get(v_dm, ARRAY[v_b])) = 0,
    '3.5 onaysız (yüklenmemiş) sha imzalandı';
  ASSERT (SELECT count(*) FROM public.world_media_sign_get(v_other, ARRAY[v_a])) = 0,
    '3.6 ÜYE OLMAYANA GET İMZASI VERİLDİ';
  ASSERT has_function_privilege('authenticated',
           'public.world_media_sign_get(uuid, text[])', 'EXECUTE') = FALSE,
    '3.7 imza RPC''si istemciye açık';

  -- ══ 5 — Tavanlar ═══════════════════════════════════════════════════════
  -- Kişi başı: DM'in öbür dünyasında 1 GB'a 500 bayt kala dolu bir satır.
  INSERT INTO public.worlds (id, owner_id, world_name) VALUES ('w099c', v_dm, 'Dolu');
  INSERT INTO public.world_media (world_id, sha256, ext, bytes, kind, mime, uploaded)
    VALUES ('w099c', v_c, '.png',
            public.world_media_user_cap_bytes() - 1000 - 9000000 - 500,
            'world_entity_image', 'image/png', TRUE);
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_dm, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_ok := FALSE;
  BEGIN
    PERFORM public.world_media_reserve('w099', jsonb_build_array(
      jsonb_build_object('sha', repeat('d', 64), 'ext', '.png', 'bytes', 400,
                         'kind', 'world_entity_image', 'mime', 'image/png'),
      jsonb_build_object('sha', repeat('e', 64), 'ext', '.png', 'bytes', 400,
                         'kind', 'world_entity_image', 'mime', 'image/png')));
  EXCEPTION WHEN raise_exception THEN
    v_ok := SQLERRM = 'media_user_full';
  END;
  ASSERT v_ok, '5.1 kişi başı tavan aşıldı';
  ASSERT NOT EXISTS (SELECT 1 FROM public.world_media WHERE sha256 = repeat('d', 64)),
    '5.2 reddedilen partiden satır yazıldı';
  -- Sığan tek dosya geçer; zaten olan (b) tekrar sayılmaz.
  v_r := public.world_media_reserve('w099', jsonb_build_array(
    jsonb_build_object('sha', repeat('d', 64), 'ext', '.png', 'bytes', 400,
                       'kind', 'world_entity_image', 'mime', 'image/png'),
    jsonb_build_object('sha', v_b, 'ext', '.jpg', 'bytes', 9000000,
                       'kind', 'battle_map', 'mime', 'image/jpeg')));
  ASSERT jsonb_array_length(v_r->'upload') = 2, format('5.3 sığan dosya reddedildi: %s', v_r);
  ASSERT (public.get_media_quota()->>'user_used')::bigint
         = public.world_media_user_cap_bytes() - 100,
    format('5.4 get_media_quota yanlış: %s', public.get_media_quota());

  -- Toplam tavan pub/ tarafını da bağlıyor.
  PERFORM set_config('role', 'postgres', true);
  UPDATE public.world_media SET bytes = public.media_total_cap_bytes() - 50
   WHERE world_id = 'w099c';
  PERFORM set_config('role', 'authenticated', true);
  v_ok := FALSE;
  BEGIN
    PERFORM public.pub_asset_reserve(repeat('f', 64), '.png', 1000, 'image/png', 'listing-099');
  EXCEPTION WHEN raise_exception THEN
    v_ok := SQLERRM = 'pool_full';
  END;
  ASSERT v_ok, '5.5 marketplace dünya medyasıyla birlikte tavanı aştı';

  -- ══ 6 — Silme, kuyruk, CASCADE ═════════════════════════════════════════
  PERFORM set_config('role', 'postgres', true);
  DELETE FROM public.r2_evict_queue;
  PERFORM set_config('role', 'authenticated', true);
  DELETE FROM public.world_media WHERE world_id = 'w099' AND sha256 = v_a;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 1, '6.1 sahip kendi medyasını silemedi';

  PERFORM set_config('role', 'postgres', true);
  SELECT r2_key INTO v_key FROM public.r2_evict_queue WHERE sha256 = v_a;
  ASSERT v_key = 'worlds/w099/' || v_a || '.png', format('6.2 kuyruğa yanlış key: %s', v_key);

  -- Pop'tan önce aynı sha yeniden rezerve edildi → obje canlı, silinmemeli.
  INSERT INTO public.world_media (world_id, sha256, ext, bytes, kind, mime)
    VALUES ('w099', v_a, '.png', 1000, 'world_entity_image', 'image/png');
  ASSERT NOT EXISTS (SELECT 1 FROM public.r2_evict_pop(10) WHERE r2_key LIKE '%' || v_a || '%'),
    '6.3 YENİDEN CANLANAN OBJE SİLİNMEK ÜZERE DÖNDÜ';
  ASSERT NOT EXISTS (SELECT 1 FROM public.r2_evict_queue), '6.4 bayat satır kuyrukta kaldı';

  -- Multiplayer kapatma = worlds satırının silinmesi → her obje kuyruğa.
  SELECT count(*) INTO v_n FROM public.world_media WHERE world_id = 'w099';
  DELETE FROM public.worlds WHERE id = 'w099';
  ASSERT NOT EXISTS (SELECT 1 FROM public.world_media WHERE world_id = 'w099'),
    '6.5 dünya silinince medya satırları kaldı';
  ASSERT (SELECT count(*) FROM public.r2_evict_queue WHERE r2_key LIKE 'worlds/w099/%') = v_n,
    '6.6 CASCADE her objeyi kuyruğa atmadı';
  ASSERT (SELECT count(*) FROM public.r2_evict_pop(100) WHERE r2_key LIKE 'worlds/w099/%') = v_n,
    '6.7 silinmiş dünyanın objeleri worker''a dönmedi';

  RAISE NOTICE '099 OK';
END $$;

ROLLBACK;
