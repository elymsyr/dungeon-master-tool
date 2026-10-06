-- ============================================================================
-- verify_105.sql — oyuncu tur kontrolü (105) self-check. Hiçbir kalıcı
-- değişiklik yapmaz.
-- ============================================================================
-- Kullanım: Supabase Dashboard > SQL Editor > yapıştır > Run.
-- Sonunda ROLLBACK var; başarılıysa "105 OK" notice'i döner, aksi halde ilk
-- başarısız assertion exception olarak patlar.
--
-- Kapsam:
--   1. DM izni yazar; üye olmayana izin yazılamaz.
--   2. Sahip satırı görür, RPC ile oynatır; doğrudan UPDATE edemez.
--   3. Başka oyuncu satırı göremez, RPC'si FALSE.
--   4. Geçersiz pozisyon (NaN, sonsuz, aşırı) reddedilir.
--   5. Sıra geçince (DELETE) eski sahibin RPC'si FALSE.
--   6. anon çalıştıramaz.
--
-- 107 imzayı değiştirdi (p_path, p_kind): 107 uygulanmışsa 6.1 eski imzayı
-- bulamaz — onun yerine verify_107.sql çalıştır.
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_dm    UUID := gen_random_uuid();
  v_pl    UUID := gen_random_uuid();
  v_pl2   UUID := gen_random_uuid();
  v_out   UUID := gen_random_uuid();
  v_world TEXT := 'verify105-world';
  v_n     INT;
  v_ok    BOOLEAN;
BEGIN
  INSERT INTO auth.users (id, aud, role, email) VALUES
    (v_dm,  'authenticated', 'authenticated', 'verify105-dm@example.invalid'),
    (v_pl,  'authenticated', 'authenticated', 'verify105-pl@example.invalid'),
    (v_pl2, 'authenticated', 'authenticated', 'verify105-p2@example.invalid'),
    (v_out, 'authenticated', 'authenticated', 'verify105-ou@example.invalid');
  INSERT INTO public.worlds (id, owner_id, world_name)
    VALUES (v_world, v_dm, 'verify105');
  INSERT INTO public.world_members (world_id, user_id, role) VALUES
    (v_world, v_dm, 'dm'),
    (v_world, v_pl, 'player'),
    (v_world, v_pl2, 'player')
  ON CONFLICT (world_id, user_id) DO UPDATE SET role = EXCLUDED.role;

  -- ══ 1 — DM ═════════════════════════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_dm, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);

  v_ok := false;
  BEGIN
    INSERT INTO public.world_turn_control
      (world_id, encounter_id, combatant_id, owner_id, origin_x, origin_y, x, y)
    VALUES (v_world, 'enc', 'c1', v_out, 10, 10, 10, 10);
  EXCEPTION WHEN insufficient_privilege THEN v_ok := true;
  END;
  ASSERT v_ok, '1.1 üye olmayana izin yazıldı';

  INSERT INTO public.world_turn_control
    (world_id, encounter_id, combatant_id, owner_id, origin_x, origin_y, x, y)
  VALUES (v_world, 'enc', 'c1', v_pl, 10, 10, 10, 10);

  -- ══ 2 — Sahip ══════════════════════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_pl, 'role', 'authenticated')::text, true);
  ASSERT auth.uid() = v_pl, '0 rol taklidi çalışmadı';

  SELECT count(*) INTO v_n FROM public.world_turn_control;
  ASSERT v_n = 1, '2.1 sahip kendi iznini göremiyor';

  ASSERT public.move_turn_token(v_world, 'c1', 55, 66), '2.2 sahibin RPC''si FALSE';
  ASSERT NOT public.move_turn_token(v_world, 'c2', 1, 1),
    '2.3 başka combatant oynatılabildi';

  UPDATE public.world_turn_control SET origin_x = 999 WHERE world_id = v_world;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  ASSERT v_n = 0, '2.4 oyuncu satırı doğrudan UPDATE edebildi';

  -- ══ 4 — Geçersiz pozisyon ══════════════════════════════════════════════
  v_ok := false;
  BEGIN PERFORM public.move_turn_token(v_world, 'c1', 'NaN'::float8, 1);
  EXCEPTION WHEN invalid_parameter_value THEN v_ok := true; END;
  ASSERT v_ok, '4.1 NaN kabul edildi';
  v_ok := false;
  BEGIN PERFORM public.move_turn_token(v_world, 'c1', 1, 'Infinity'::float8);
  EXCEPTION WHEN invalid_parameter_value THEN v_ok := true; END;
  ASSERT v_ok, '4.2 Infinity kabul edildi';
  v_ok := false;
  BEGIN PERFORM public.move_turn_token(v_world, 'c1', 2e6, 1);
  EXCEPTION WHEN invalid_parameter_value THEN v_ok := true; END;
  ASSERT v_ok, '4.3 aşırı pozisyon kabul edildi';

  -- ══ 3 — Başka oyuncu ═══════════════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_pl2, 'role', 'authenticated')::text, true);
  SELECT count(*) INTO v_n FROM public.world_turn_control;
  ASSERT v_n = 0, '3.1 başka oyuncu izni görüyor';
  ASSERT NOT public.move_turn_token(v_world, 'c1', 1, 1),
    '3.2 başka oyuncu token''ı oynatabildi';

  -- ══ 5 — Sıra geçti ═════════════════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_dm, 'role', 'authenticated')::text, true);
  SELECT x INTO v_n FROM public.world_turn_control WHERE world_id = v_world;
  ASSERT v_n = 55, '5.1 DM oyuncunun hareketini görmüyor';
  DELETE FROM public.world_turn_control WHERE world_id = v_world;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_pl, 'role', 'authenticated')::text, true);
  ASSERT NOT public.move_turn_token(v_world, 'c1', 1, 1),
    '5.2 sıra geçtikten sonra oynatılabildi';

  -- ══ 6 — anon ═══════════════════════════════════════════════════════════
  PERFORM set_config('role', 'postgres', true);
  ASSERT NOT has_function_privilege('anon',
    'public.move_turn_token(text,text,double precision,double precision)',
    'EXECUTE'), '6.1 anon move_turn_token çalıştırabiliyor';

  RAISE NOTICE '105 OK';
END $$;

ROLLBACK;
