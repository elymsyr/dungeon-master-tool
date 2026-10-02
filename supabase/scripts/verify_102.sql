-- ============================================================================
-- verify_102.sql — oyuncunun kart doğrulaması (102) self-check. Hiçbir kalıcı
-- değişiklik yapmaz.
-- ============================================================================
-- Kullanım: Supabase Dashboard > SQL Editor > yapıştır > Run.
-- Sonunda ROLLBACK var; başarılıysa "102 OK" notice'i döner, aksi halde ilk
-- başarısız assertion exception olarak patlar.
--
-- Kapsam:
--   1. İmza: üç parametreli get_shared_entities, iki parametreli yok;
--      dönüşte dm_notes yok.
--   2. Damga listesi: yalnız izinli + dm_only_keys bilinen kartlar, gövdesiz.
--   3. p_ids: yalnız istenen kartlar; izinsiz id istense de dönmez; sır
--      yine kırpılı; eski iki parametreli çağrı çalışıyor.
--   4. Üye olmayan reddedilir.
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_dm     UUID := gen_random_uuid();
  v_pl     UUID := gen_random_uuid();
  v_other  UUID := gen_random_uuid();
  v_world  TEXT := 'verify102-world';
  v_n      INT;
  v_ids    TEXT[];
  v_fields JSONB;
  v_ok     BOOLEAN;
BEGIN
  -- ══ 1 — İmza ═══════════════════════════════════════════════════════════
  ASSERT to_regprocedure('public.get_shared_entities(text, bigint)') IS NULL,
    '1.1 iki parametreli get_shared_entities duruyor (PostgREST belirsiz kalır)';
  ASSERT position('dm_notes' IN pg_get_function_result(
      'public.get_shared_entities(text,bigint,text[])'::regprocedure)) = 0,
    '1.2 get_shared_entities dm_notes döndürüyor';
  ASSERT position('dm_notes' IN pg_get_function_result(
      'public.get_shared_entity_stamps(text)'::regprocedure)) = 0
     AND position('fields_json' IN pg_get_function_result(
      'public.get_shared_entity_stamps(text)'::regprocedure)) = 0,
    '1.3 damga listesi gövde taşıyor';

  -- ══ Kurulum — postgres rolünde ═════════════════════════════════════════
  INSERT INTO auth.users (id, aud, role, email) VALUES
    (v_dm,    'authenticated', 'authenticated', 'verify102-dm@example.invalid'),
    (v_pl,    'authenticated', 'authenticated', 'verify102-pl@example.invalid'),
    (v_other, 'authenticated', 'authenticated', 'verify102-ot@example.invalid');
  INSERT INTO public.worlds (id, owner_id, world_name)
    VALUES (v_world, v_dm, 'verify102');
  INSERT INTO public.world_members (world_id, user_id, role) VALUES
    (v_world, v_dm, 'dm'),
    (v_world, v_pl, 'player')
  ON CONFLICT (world_id, user_id) DO UPDATE SET role = EXCLUDED.role;

  -- e1, e4: paylaşılan.  e2: paylaşılmamış.  e3: paylaşılan, sır listesi NULL.
  -- e5: paylaşılan linked kart.
  INSERT INTO public.world_entities
    (id, world_id, category_slug, name, dm_notes, fields_json, dm_only_keys, linked)
  VALUES
    ('e1', v_world, 'npc', 'A', 'GIZLI', '{"public":"ok","secret":"x"}', ARRAY['secret'], false),
    ('e2', v_world, 'npc', 'B', 'GIZLI', '{"public":"ok"}', ARRAY[]::TEXT[], false),
    ('e3', v_world, 'npc', 'C', '',      '{"public":"ok"}', NULL, false),
    ('e4', v_world, 'npc', 'D', '',      '{"public":"ok"}', ARRAY[]::TEXT[], false),
    ('e5', v_world, 'npc', 'E', '',      '{}', ARRAY[]::TEXT[], true);
  INSERT INTO public.entity_shares (entity_id, world_id, shared_with, shared_by)
  VALUES ('e1', v_world, NULL, v_dm),
         ('e3', v_world, NULL, v_dm),
         ('e4', v_world, NULL, v_dm),
         ('e5', v_world, NULL, v_dm);

  -- ══ OYUNCU ROLÜ ════════════════════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_pl, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  ASSERT auth.uid() = v_pl, '0 rol taklidi çalışmadı';

  -- ══ 2 — Damga listesi ══════════════════════════════════════════════════
  SELECT array_agg(s.id ORDER BY s.id) INTO v_ids
    FROM public.get_shared_entity_stamps(v_world) s;
  ASSERT v_ids = ARRAY['e1', 'e4', 'e5'], format(
    '2.1 damga listesi %s, beklenen {e1,e4,e5} (e2 paylaşılmamış, e3 NULL)', v_ids);
  ASSERT (SELECT bool_and(s.updated_at IS NOT NULL)
            FROM public.get_shared_entity_stamps(v_world) s),
    '2.2 updated_at boş';
  ASSERT (SELECT s.linked FROM public.get_shared_entity_stamps(v_world) s
           WHERE s.id = 'e5'),
    '2.3 linked bayrağı gelmiyor';

  -- ══ 3 — p_ids ══════════════════════════════════════════════════════════
  SELECT count(*) INTO v_n
    FROM public.get_shared_entities(v_world, 0, ARRAY['e1', 'e2', 'e3']);
  ASSERT v_n = 1, format(
    '3.1 %s kart döndü, yalnız e1 bekleniyor (e2/e3 izinsiz istense de dönmez)', v_n);
  SELECT e.fields_json::jsonb INTO v_fields
    FROM public.get_shared_entities(v_world, 0, ARRAY['e1']) e;
  ASSERT v_fields ? 'public' AND NOT (v_fields ? 'secret'),
    '3.2 DM''E ÖZEL ALAN p_ids yolunda SIZDI';
  ASSERT (SELECT count(*) FROM public.get_shared_entities(v_world, 0)) = 3,
    '3.3 eski iki parametreli çağrı bozuldu';
  ASSERT (SELECT count(*) FROM public.get_shared_entities(v_world, 0, ARRAY[]::TEXT[])) = 0,
    '3.4 boş id listesi kart döndürdü';

  -- ══ 4 — Üye olmayan ════════════════════════════════════════════════════
  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_other, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_ok := FALSE;
  BEGIN
    PERFORM public.get_shared_entity_stamps(v_world);
  EXCEPTION WHEN insufficient_privilege THEN v_ok := TRUE;
  END;
  ASSERT v_ok, '4.1 üye olmayan damga listesini okudu';

  PERFORM set_config('role', 'postgres', true);
  RAISE NOTICE '102 OK';
END $$;

ROLLBACK;
