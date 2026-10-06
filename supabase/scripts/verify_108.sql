-- ============================================================================
-- verify_108.sql — oyuncu hareket yolu + sıra numarası (107/108) self-check. Hiçbir kalıcı
-- değişiklik yapmaz.
-- ============================================================================
-- 107'nin yerine geçer: 108 uygulandıktan sonra verify_107.sql 6 parametreli
-- imzayı bulamaz.
--
-- Kullanım: Supabase Dashboard > SQL Editor > yapıştır > Run.
-- Sonunda ROLLBACK var; başarılıysa "108 OK" notice'i döner, aksi halde ilk
-- başarısız assertion exception olarak patlar.
--
-- Kapsam:
--   1. Eski 4 parametreli çağrı çalışır (yol yok, kind 0).
--   2. Yol + kind satıra yazılır.
--   3. Geçersiz yol (tek sayı, NaN, aşırı uzun) ve kind reddedilir.
--   4. anon çalıştıramaz; eski imzalar kalmadı.
--   5. Sıra numarası yazılır, negatif reddedilir.
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_dm    UUID := gen_random_uuid();
  v_pl    UUID := gen_random_uuid();
  v_world TEXT := 'verify108-world';
  v_row   public.world_turn_control%ROWTYPE;
  v_ok    BOOLEAN;
BEGIN
  INSERT INTO auth.users (id, aud, role, email) VALUES
    (v_dm, 'authenticated', 'authenticated', 'verify108-dm@example.invalid'),
    (v_pl, 'authenticated', 'authenticated', 'verify108-pl@example.invalid');
  INSERT INTO public.worlds (id, owner_id, world_name)
    VALUES (v_world, v_dm, 'verify108');
  INSERT INTO public.world_members (world_id, user_id, role) VALUES
    (v_world, v_dm, 'dm'),
    (v_world, v_pl, 'player')
  ON CONFLICT (world_id, user_id) DO UPDATE SET role = EXCLUDED.role;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_dm, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  INSERT INTO public.world_turn_control
    (world_id, encounter_id, combatant_id, owner_id, origin_x, origin_y, x, y)
  VALUES (v_world, 'enc', 'c1', v_pl, 10, 10, 10, 10);

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_pl, 'role', 'authenticated')::text, true);

  -- ══ 1 — Eski çağrı ═════════════════════════════════════════════════════
  ASSERT public.move_turn_token(v_world, 'c1', 20, 20), '1.1 eski çağrı FALSE';
  SELECT * INTO v_row FROM public.world_turn_control WHERE world_id = v_world;
  ASSERT v_row.path IS NULL AND v_row.kind = 0, '1.2 eski çağrı yol/kind yazdı';

  -- ══ 2 — Yol + kind ═════════════════════════════════════════════════════
  ASSERT public.move_turn_token(v_world, 'c1', 40, 40,
    ARRAY[25, 22, 30, 28]::float8[], 1::smallint), '2.1 yollu çağrı FALSE';
  SELECT * INTO v_row FROM public.world_turn_control WHERE world_id = v_world;
  ASSERT v_row.path = '[25, 22, 30, 28]'::jsonb, '2.2 yol yazılmadı';
  ASSERT v_row.kind = 1, '2.3 kind yazılmadı';
  ASSERT public.move_turn_token(v_world, 'c1', 10, 10, NULL, 2::smallint),
    '2.4 geri al FALSE';
  SELECT * INTO v_row FROM public.world_turn_control WHERE world_id = v_world;
  ASSERT v_row.path IS NULL AND v_row.kind = 2, '2.5 geri al yolu temizlemedi';

  -- ══ 3 — Geçersiz ═══════════════════════════════════════════════════════
  v_ok := false;
  BEGIN PERFORM public.move_turn_token(v_world, 'c1', 1, 1, ARRAY[1, 2, 3]::float8[]);
  EXCEPTION WHEN invalid_parameter_value THEN v_ok := true; END;
  ASSERT v_ok, '3.1 tek sayıda yol kabul edildi';
  v_ok := false;
  BEGIN PERFORM public.move_turn_token(v_world, 'c1', 1, 1, ARRAY[1, 'NaN']::float8[]);
  EXCEPTION WHEN invalid_parameter_value THEN v_ok := true; END;
  ASSERT v_ok, '3.2 NaN yol kabul edildi';
  v_ok := false;
  BEGIN PERFORM public.move_turn_token(v_world, 'c1', 1, 1,
    array_fill(1::float8, ARRAY[802]));
  EXCEPTION WHEN invalid_parameter_value THEN v_ok := true; END;
  ASSERT v_ok, '3.3 aşırı uzun yol kabul edildi';
  v_ok := false;
  BEGIN PERFORM public.move_turn_token(v_world, 'c1', 1, 1, NULL, 5::smallint);
  EXCEPTION WHEN invalid_parameter_value THEN v_ok := true; END;
  ASSERT v_ok, '3.4 geçersiz kind kabul edildi';

  -- ══ 5 — Sıra numarası ═════════════════════════════════════════════════
  ASSERT public.move_turn_token(v_world, 'c1', 12, 12, NULL, 0::smallint, 77),
    '5.1 numaralı çağrı FALSE';
  SELECT * INTO v_row FROM public.world_turn_control WHERE world_id = v_world;
  ASSERT v_row.seq = 77, '5.2 sıra numarası yazılmadı';
  v_ok := false;
  BEGIN PERFORM public.move_turn_token(v_world, 'c1', 1, 1, NULL, 0::smallint, -1);
  EXCEPTION WHEN invalid_parameter_value THEN v_ok := true; END;
  ASSERT v_ok, '5.3 negatif sıra numarası kabul edildi';

  -- ══ 4 — anon / eski imza ═══════════════════════════════════════════════
  PERFORM set_config('role', 'postgres', true);
  ASSERT NOT has_function_privilege('anon',
    'public.move_turn_token(text,text,double precision,double precision,double precision[],smallint,bigint)',
    'EXECUTE'), '4.1 anon move_turn_token çalıştırabiliyor';
  ASSERT to_regprocedure(
    'public.move_turn_token(text,text,double precision,double precision)') IS NULL,
    '4.2 eski 4 parametreli imza duruyor';
  ASSERT to_regprocedure(
    'public.move_turn_token(text,text,double precision,double precision,double precision[],smallint)') IS NULL,
    '4.3 107''nin 6 parametreli imzası duruyor';

  RAISE NOTICE '108 OK';
END $$;

ROLLBACK;
