-- ============================================================================
-- verify_094.sql — Faz 3 (094) self-check. Hiçbir kalıcı değişiklik yapmaz.
-- ============================================================================
-- Kullanım: Supabase Dashboard > SQL Editor > yapıştır > Run.
-- Sonunda ROLLBACK var; başarılıysa tek satır "094 OK" döner, aksi halde ilk
-- başarısız assertion exception olarak patlar.
--
-- Kapsam — docs/online-sync-redesign.md §3.4'ün "RLS testleri opsiyonel
-- değil" maddesi. Bugün gizliliği `redactDmOnly` sağlıyor ve yanlış yapmak
-- imkansız: sır hiç gönderilmiyor. 094'ten sonra sır SUNUCUDA duruyor ve tek
-- yanlış politika onu oyuncuya açar. Bu yüzden her ayna tablosu için
-- "oyuncu rolüyle oku, boş dönmeli" testi var.
--
-- Rol taklidi: SET LOCAL ROLE + request.jwt.claims. Tablo sahibi postgres
-- RLS'i bypass ettiği için testler MUTLAKA `authenticated` rolünde koşar.
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_dm      UUID := gen_random_uuid();
  v_pl      UUID := gen_random_uuid();
  v_other   UUID := gen_random_uuid();
  v_world   TEXT := 'verify094-world';
  v_world2  TEXT := 'verify094-other';
  v_n       INT;
  v_txt     TEXT;
  v_fields  JSONB;
  v_rev     BIGINT;
  v_rev2    BIGINT;
  v_ok      BOOLEAN;
BEGIN
  -- ══ Kurulum — postgres rolünde ═════════════════════════════════════════
  INSERT INTO auth.users (id, aud, role, email) VALUES
    (v_dm,    'authenticated', 'authenticated', 'verify094-dm@example.invalid'),
    (v_pl,    'authenticated', 'authenticated', 'verify094-pl@example.invalid'),
    (v_other, 'authenticated', 'authenticated', 'verify094-ot@example.invalid');

  INSERT INTO public.worlds (id, owner_id, world_name) VALUES
    (v_world,  v_dm,    'verify094'),
    (v_world2, v_other, 'verify094 other');

  INSERT INTO public.world_members (world_id, user_id, role) VALUES
    (v_world,  v_dm,    'dm'),
    (v_world,  v_pl,    'player'),
    (v_world2, v_other, 'dm')
  ON CONFLICT (world_id, user_id) DO UPDATE SET role = EXCLUDED.role;

  -- e1: paylaşılan, bir sırrı var.  e2: paylaşılmamış.
  -- e3: paylaşılan ama dm_only_keys NULL → "bilinmiyor" → hiç dönmemeli.
  -- e4: paylaşılan, sır listesi boş → fields_json aynen dönmeli.
  INSERT INTO public.world_entities
    (id, world_id, category_slug, name, dm_notes, fields_json, dm_only_keys) VALUES
    ('e1', v_world, 'npc', 'Paylasilan', 'COK GIZLI',
     '{"public":"ok","secret":"hidden"}', ARRAY['secret']),
    ('e2', v_world, 'npc', 'Paylasilmayan', 'COK GIZLI',
     '{"public":"ok"}', ARRAY[]::TEXT[]),
    ('e3', v_world, 'npc', 'Liste bilinmiyor', '', '{"public":"ok"}', NULL),
    ('e4', v_world, 'npc', 'Sirsiz', '', '{"public":"ok"}', ARRAY[]::TEXT[]);

  INSERT INTO public.entity_shares (entity_id, world_id, shared_with, shared_by)
  VALUES ('e1', v_world, NULL, v_dm),
         ('e3', v_world, NULL, v_dm),
         ('e4', v_world, NULL, v_dm);

  INSERT INTO public.world_settings (world_id) VALUES (v_world);
  INSERT INTO public.world_map_data (world_id) VALUES (v_world);
  INSERT INTO public.world_sessions (id, world_id, name) VALUES ('s1', v_world, 'S1');
  INSERT INTO public.world_encounters (id, world_id, session_id, name)
    VALUES ('en1', v_world, 's1', 'Savas');
  INSERT INTO public.world_combatants (id, world_id, encounter_id, name)
    VALUES ('c1', v_world, 'en1', 'Goblin');
  INSERT INTO public.world_map_pins (id, world_id, x, y) VALUES ('p1', v_world, 1, 2);
  INSERT INTO public.world_timeline_pins (id, world_id, x, y) VALUES ('t1', v_world, 1, 2);
  INSERT INTO public.world_installed_packages (world_id, package_id)
    VALUES (v_world, 'pkg1');

  -- Mind map: biri DM'in (owner NULL), biri oyuncunun.
  INSERT INTO public.world_mind_map_nodes (id, world_id, map_id, owner_id, label) VALUES
    ('n-dm', v_world, 'default',  NULL, 'DM notu'),
    ('n-pl', v_world, 'default',  v_pl, 'Oyuncu notu');
  INSERT INTO public.world_mind_map_edges (id, world_id, map_id, owner_id, source_id, target_id)
    VALUES ('ed-dm', v_world, 'default', NULL, 'n-dm', 'n-dm');

  INSERT INTO public.world_member_state (world_id, user_id, state_json) VALUES
    (v_world, v_pl, '{"note":"oyuncunun"}'),
    (v_world, v_dm, '{"note":"dm''in"}');

  INSERT INTO public.user_packages (id, owner_id, name) VALUES ('up1', v_dm, 'DM paketi');
  INSERT INTO public.user_package_entities (id, package_id, owner_id, category_slug, name)
    VALUES ('upe1', 'up1', v_dm, 'spell', 'Ates Topu');
  INSERT INTO public.user_package_schemas (id, package_id, owner_id, name)
    VALUES ('ups1', 'up1', v_dm, 'sema');

  -- ══ 1 — Revizyon sayacı (§2.3) ═════════════════════════════════════════
  SELECT revision INTO v_rev FROM public.world_revisions WHERE world_id = v_world;
  ASSERT v_rev IS NOT NULL AND v_rev > 0, '1.1 world_revisions olusmadi';

  SELECT revision INTO v_rev2 FROM public.world_entities WHERE id = 'e1';
  ASSERT v_rev2 > 0, '1.2 entity revision damgalanmadi';
  ASSERT (SELECT revision FROM public.world_entities WHERE id = 'e2') > v_rev2,
    '1.3 revision monoton artmiyor';

  UPDATE public.world_entities SET name = 'Yeni ad' WHERE id = 'e1';
  ASSERT (SELECT revision FROM public.world_entities WHERE id = 'e1') > v_rev,
    '1.4 UPDATE revision''u artirmadi';

  -- updated_at sunucu tarafindan EZILMEMELI (§2.8)
  UPDATE public.world_entities
     SET updated_at = TIMESTAMPTZ '2020-01-01 00:00:00+00' WHERE id = 'e2';
  ASSERT (SELECT updated_at FROM public.world_entities WHERE id = 'e2')
         = TIMESTAMPTZ '2020-01-01 00:00:00+00',
    '1.5 updated_at sunucu tarafindan ezildi — cevrimdisi kuyruk yeni veriyi eze'
    'r (§2.8)';

  -- Paylasim/geri cekme sinyal uretmeli
  SELECT revision INTO v_rev FROM public.world_revisions WHERE world_id = v_world;
  DELETE FROM public.entity_shares WHERE entity_id = 'e4' AND world_id = v_world;
  ASSERT (SELECT revision FROM public.world_revisions WHERE world_id = v_world) > v_rev,
    '1.6 unshare revision sinyali uretmedi';

  -- ══ 2 — Tombstone (§2.4) ═══════════════════════════════════════════════
  DELETE FROM public.world_entities WHERE id = 'e2';
  SELECT count(*) INTO v_n FROM public.world_tombstones
   WHERE world_id = v_world AND table_name = 'world_entities' AND row_id = 'e2';
  ASSERT v_n = 1, '2.1 silinen entity icin tombstone yazilmadi';

  DELETE FROM public.world_mind_map_nodes WHERE id = 'n-pl';
  SELECT owner_id INTO v_txt FROM public.world_tombstones
   WHERE world_id = v_world AND table_name = 'world_mind_map_nodes' AND row_id = 'n-pl';
  ASSERT v_txt::uuid = v_pl, '2.2 oyuncu satirinin tombstone owner_id''si yanlis';

  -- Dunya CASCADE'i tombstone uretmemeli (050'nin dersi + bos is)
  DELETE FROM public.worlds WHERE id = v_world2;
  SELECT count(*) INTO v_n FROM public.world_tombstones WHERE world_id = v_world2;
  ASSERT v_n = 0, '2.3 dunya CASCADE''inde tombstone uretildi';

  -- ══ 3 — Kota sinirlari (§2.14) ═════════════════════════════════════════
  v_ok := FALSE;
  BEGIN
    INSERT INTO public.world_entities (id, world_id, category_slug, name, fields_json)
    VALUES ('too-big', v_world, 'npc', 'Buyuk',
            '{"x":"' || repeat('a', 300000) || '"}');
  EXCEPTION WHEN check_violation THEN v_ok := TRUE;
  END;
  ASSERT v_ok, '3.1 256 KB ustu kart satiri kabul edildi';

  v_ok := FALSE;
  BEGIN
    INSERT INTO public.world_entities (id, world_id, category_slug, name, fields_json)
    VALUES ('bad-json', v_world, 'npc', 'Bozuk', 'bu json degil');
  EXCEPTION WHEN OTHERS THEN v_ok := TRUE;
  END;
  ASSERT v_ok, '3.2 gecersiz fields_json kabul edildi — redaksiyon sorgusu patlar';

  v_ok := FALSE;
  BEGIN
    INSERT INTO public.world_entities (id, world_id, category_slug, name, fields_json)
    VALUES ('scalar-json', v_world, 'npc', 'Skaler', '[1,2,3]');
  EXCEPTION WHEN OTHERS THEN v_ok := TRUE;
  END;
  ASSERT v_ok, '3.3 nesne olmayan fields_json kabul edildi';

  ASSERT public.max_rows_per_world()           = 20000,     '3.4 satir kotasi';
  ASSERT public.max_entity_row_bytes()         = 262144,    '3.5 satir boyutu';
  ASSERT public.max_online_packages_per_user() = 20,        '3.6 paket kotasi';
  ASSERT public.max_cloud_bytes_per_user()     = 524288000, '3.7 alan kotasi';

  -- ══ 4 — Politika yuzeyi ════════════════════════════════════════════════
  -- Oyuncuya acilan tek bir world_entities policy'si bile olmamali.
  SELECT count(*) INTO v_n FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'world_entities';
  ASSERT v_n = 1, format('4.1 world_entities''te %s policy var, 1 bekleniyor '
    '(oyuncunun yolu yalnizca get_shared_entities olmali)', v_n);

  SELECT count(*) INTO v_n FROM pg_tables t
   WHERE t.schemaname = 'public'
     AND t.tablename IN (
       'world_revisions','world_tombstones','world_member_state','world_entities',
       'world_settings','world_map_data','world_sessions','world_mind_map_nodes',
       'world_mind_map_edges','world_encounters','world_combatants',
       'world_map_pins','world_timeline_pins','world_installed_packages',
       'user_packages','user_package_entities','user_package_schemas')
     AND NOT t.rowsecurity;
  ASSERT v_n = 0, format('4.2 %s yeni tabloda RLS kapali', v_n);

  -- dm_notes RPC'nin donus tipinde HIC olmamali (bosaltmak degil, secmemek).
  ASSERT position('dm_notes' IN pg_get_function_result(
      'public.get_shared_entities(text,bigint)'::regprocedure)) = 0,
    '4.3 get_shared_entities dm_notes donduruyor';

  -- ══ 5 — OYUNCU ROLU ════════════════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_pl, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);

  ASSERT auth.uid() = v_pl, '5.0 rol taklidi calismadi';

  -- 5.1 Ayna tablolarinin hepsi oyuncuya KAPALI
  SELECT count(*) INTO v_n FROM public.world_entities;
  ASSERT v_n = 0, '5.1 OYUNCU world_entities OKUYABILIYOR — gizlilik hatasi';

  ASSERT (SELECT count(*) FROM public.world_settings)           = 0, '5.2 world_settings';
  ASSERT (SELECT count(*) FROM public.world_map_data)           = 0, '5.3 world_map_data';
  ASSERT (SELECT count(*) FROM public.world_sessions)           = 0, '5.4 world_sessions';
  ASSERT (SELECT count(*) FROM public.world_encounters)         = 0, '5.5 world_encounters';
  ASSERT (SELECT count(*) FROM public.world_combatants)         = 0, '5.6 world_combatants';
  ASSERT (SELECT count(*) FROM public.world_map_pins)           = 0, '5.7 world_map_pins';
  ASSERT (SELECT count(*) FROM public.world_timeline_pins)      = 0, '5.8 world_timeline_pins';
  ASSERT (SELECT count(*) FROM public.world_installed_packages) = 0, '5.9 world_installed_packages';
  ASSERT (SELECT count(*) FROM public.user_packages)            = 0, '5.10 user_packages';
  ASSERT (SELECT count(*) FROM public.user_package_entities)    = 0, '5.11 user_package_entities';
  ASSERT (SELECT count(*) FROM public.user_package_schemas)     = 0, '5.12 user_package_schemas';

  -- 5.13 Mind map: yalnizca kendi satiri (n-pl silindi, geriye DM'inki kaldi)
  ASSERT (SELECT count(*) FROM public.world_mind_map_nodes) = 0,
    '5.13 OYUNCU DM''in mind map''ini goruyor';
  ASSERT (SELECT count(*) FROM public.world_mind_map_edges) = 0,
    '5.14 OYUNCU DM''in mind map kenarlarini goruyor';

  -- 5.15 Kendi durumu evet, DM'inki hayir
  ASSERT (SELECT count(*) FROM public.world_member_state) = 1,
    '5.15 world_member_state sizintisi';
  ASSERT (SELECT user_id FROM public.world_member_state) = v_pl,
    '5.16 world_member_state yanlis satiri donuyor';

  -- 5.17 Revizyon sinyalini okuyabilmeli (icerik tasimaz)
  ASSERT (SELECT count(*) FROM public.world_revisions) = 1, '5.17 world_revisions okunamiyor';

  -- 5.18 Tombstone: yalnizca kendi satirlari (DM'in sildigi kart id'leri sizmasin)
  SELECT count(*) INTO v_n FROM public.world_tombstones;
  ASSERT v_n = 1, format('5.18 oyuncu %s tombstone goruyor, 1 bekleniyor', v_n);
  ASSERT (SELECT row_id FROM public.world_tombstones) = 'n-pl', '5.19 yanlis tombstone';

  -- 5.20 Yazma yok
  v_ok := FALSE;
  BEGIN
    INSERT INTO public.world_entities (id, world_id, category_slug, name)
    VALUES ('pl-hack', v_world, 'npc', 'Oyuncunun yazdigi');
  EXCEPTION WHEN insufficient_privilege THEN v_ok := TRUE;
  END;
  ASSERT v_ok, '5.20 OYUNCU world_entities''e YAZABILIYOR';

  UPDATE public.world_entities SET name = 'ele gecirildi' WHERE id = 'e1';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 0, '5.21 OYUNCU paylasilan karti duzenleyebiliyor';

  -- ══ 6 — Tek kapi: get_shared_entities (§2.5, §2.6) ═════════════════════
  SELECT count(*) INTO v_n FROM public.get_shared_entities(v_world, 0);
  ASSERT v_n = 1, format(
    '6.1 RPC %s kart dondu, 1 bekleniyor (e1). e3 dm_only_keys NULL oldugu '
    'icin, e4 paylasimi geri cekildigi icin disarida kalmali', v_n);

  SELECT id INTO v_txt FROM public.get_shared_entities(v_world, 0);
  ASSERT v_txt = 'e1', '6.2 yanlis kart dondu';

  SELECT fields_json::jsonb INTO v_fields FROM public.get_shared_entities(v_world, 0);
  ASSERT v_fields ? 'public',      '6.3 acik alan kayboldu';
  ASSERT NOT (v_fields ? 'secret'),
    '6.4 DM''E OZEL ALAN OYUNCUYA SIZDI — redaksiyon calismiyor';

  -- 6.5 since_revision filtresi
  SELECT revision INTO v_rev FROM public.get_shared_entities(v_world, 0);
  ASSERT (SELECT count(*) FROM public.get_shared_entities(v_world, v_rev)) = 0,
    '6.5 since_revision filtrelemiyor';

  -- 6.6 Izin listesi (gri kart akisi)
  ASSERT public.get_shared_entity_ids(v_world) = ARRAY['e1'],
    '6.6 get_shared_entity_ids yanlis liste donuyor';

  -- 6.7 Gorunurluk view'i istemciye KAPALI (RLS'i atlar, tek okuyucusu RPC'ler)
  v_ok := FALSE;
  BEGIN
    PERFORM count(*) FROM public.v_shared_entities;
  EXCEPTION WHEN insufficient_privilege THEN v_ok := TRUE;
  END;
  ASSERT v_ok, '6.7 v_shared_entities OYUNCUYA ACIK — world_entities RLS''i atlanir';

  -- 6.8 Uye olmadigi dunya reddedilmeli
  v_ok := FALSE;
  BEGIN
    PERFORM public.get_shared_entities('verify094-yok', 0);
  EXCEPTION WHEN insufficient_privilege THEN v_ok := TRUE;
  END;
  ASSERT v_ok, '6.8 uye olmayan dunyada RPC calisti';

  -- ══ 7 — DM ROLU ════════════════════════════════════════════════════════
  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_dm, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);

  ASSERT (SELECT count(*) FROM public.world_entities) = 3,
    '7.1 DM kendi kartlarini goremiyor (e1,e3,e4)';
  ASSERT (SELECT count(*) FROM public.world_settings) = 1, '7.2 DM world_settings';
  ASSERT (SELECT count(*) FROM public.world_encounters) = 1, '7.3 DM world_encounters';
  ASSERT (SELECT count(*) FROM public.world_combatants) = 1, '7.4 DM world_combatants';
  ASSERT (SELECT count(*) FROM public.user_packages) = 1, '7.5 DM paketi';
  ASSERT (SELECT count(*) FROM public.user_package_entities) = 1, '7.6 DM paket kartlari';

  -- DM oyuncunun mind map'ini GORMEZ (owner_id ayrimi)
  ASSERT (SELECT count(*) FROM public.world_mind_map_nodes) = 1,
    '7.7 DM oyuncunun mind map dugumunu goruyor';

  -- DM oyuncunun kisisel durumunu GORMEZ
  ASSERT (SELECT count(*) FROM public.world_member_state) = 1,
    '7.8 DM oyuncunun member_state''ini goruyor';

  -- DM tombstone'larin hepsini gorur
  ASSERT (SELECT count(*) FROM public.world_tombstones) = 2, '7.9 DM tombstone gormuyor';

  -- DM baskasinin paketine dokunamaz
  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_other, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  ASSERT (SELECT count(*) FROM public.user_packages) = 0,
    '7.10 BASKASININ ONLINE PAKETI GORUNUYOR';

  PERFORM set_config('role', 'postgres', true);
  RAISE NOTICE '094 OK';
END $$;

SELECT '094 OK' AS result;

ROLLBACK;
