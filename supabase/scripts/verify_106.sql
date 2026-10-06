-- ============================================================================
-- verify_106.sql — zar günlüğü (106) self-check. Hiçbir kalıcı değişiklik
-- yapmaz.
-- ============================================================================
-- Kullanım: Supabase Dashboard > SQL Editor > yapıştır > Run.
-- Sonunda ROLLBACK var; başarılıysa "106 OK" notice'i döner, aksi halde ilk
-- başarısız assertion exception olarak patlar.
--
-- Kapsam:
--   1. Üye atışını yazar; satırın sahibi auth.uid().
--   2. Oyuncu satırı göremez, doğrudan INSERT edemez.
--   3. Üye olmayanın RPC'si FALSE, hiçbir şey yazmaz.
--   4. Geçersiz tür / aşırı uzun metin reddedilir.
--   5. DM satırı görür; 1 saatten eski satırlar bir sonraki yazmada silinir.
--   6. anon çalıştıramaz.
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_dm    UUID := gen_random_uuid();
  v_pl    UUID := gen_random_uuid();
  v_out   UUID := gen_random_uuid();
  v_world TEXT := 'verify106-world';
  v_n     INT;
  v_ok    BOOLEAN;
BEGIN
  INSERT INTO auth.users (id, aud, role, email) VALUES
    (v_dm,  'authenticated', 'authenticated', 'verify106-dm@example.invalid'),
    (v_pl,  'authenticated', 'authenticated', 'verify106-pl@example.invalid'),
    (v_out, 'authenticated', 'authenticated', 'verify106-ou@example.invalid');
  INSERT INTO public.worlds (id, owner_id, world_name)
    VALUES (v_world, v_dm, 'verify106');
  INSERT INTO public.world_members (world_id, user_id, role) VALUES
    (v_world, v_dm, 'dm'),
    (v_world, v_pl, 'player')
  ON CONFLICT (world_id, user_id) DO UPDATE SET role = EXCLUDED.role;

  -- ══ 1 — Oyuncu ═════════════════════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_pl, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  ASSERT auth.uid() = v_pl, '0 rol taklidi çalışmadı';

  ASSERT public.log_dice_roll(v_world, 'Thorin', 'skill', 'Stealth', 17, 'd20: 12 + 5'),
    '1.1 üyenin RPC''si FALSE';

  -- ══ 2 — Oyuncu okuyamaz / doğrudan yazamaz ═════════════════════════════
  SELECT count(*) INTO v_n FROM public.world_dice_rolls;
  ASSERT v_n = 0, '2.1 oyuncu zar satırlarını görüyor';
  v_ok := false;
  BEGIN
    INSERT INTO public.world_dice_rolls (world_id, user_id, kind, total, detail)
    VALUES (v_world, v_dm, 'roll', 20, 'd20: 20');
  EXCEPTION WHEN insufficient_privilege THEN v_ok := true;
  END;
  ASSERT v_ok, '2.2 oyuncu doğrudan INSERT edebildi';

  -- ══ 4 — Geçersiz girdi ═════════════════════════════════════════════════
  v_ok := false;
  BEGIN PERFORM public.log_dice_roll(v_world, NULL, 'attack', NULL, 1, 'd20: 1');
  EXCEPTION WHEN invalid_parameter_value THEN v_ok := true; END;
  ASSERT v_ok, '4.1 geçersiz tür kabul edildi';
  v_ok := false;
  BEGIN PERFORM public.log_dice_roll(v_world, NULL, 'roll', NULL, 1, repeat('x', 201));
  EXCEPTION WHEN invalid_parameter_value THEN v_ok := true; END;
  ASSERT v_ok, '4.2 aşırı uzun döküm kabul edildi';

  -- ══ 3 — Üye olmayan ════════════════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_out, 'role', 'authenticated')::text, true);
  ASSERT NOT public.log_dice_roll(v_world, NULL, 'roll', NULL, 4, 'd4: 4'),
    '3.1 üye olmayan zar yazabildi';

  -- ══ 5 — DM ═════════════════════════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_dm, 'role', 'authenticated')::text, true);
  SELECT count(*) INTO v_n FROM public.world_dice_rolls WHERE user_id = v_pl;
  ASSERT v_n = 1, '5.1 DM oyuncunun atışını görmüyor';

  PERFORM set_config('role', 'postgres', true);
  UPDATE public.world_dice_rolls SET created_at = now() - interval '2 hours'
   WHERE world_id = v_world;
  PERFORM set_config('role', 'authenticated', true);
  ASSERT public.log_dice_roll(v_world, NULL, 'roll', NULL, 6, 'd6: 6'),
    '5.2 DM''in RPC''si FALSE';
  SELECT count(*) INTO v_n FROM public.world_dice_rolls WHERE world_id = v_world;
  ASSERT v_n = 1, '5.3 eski satırlar silinmedi';

  -- ══ 6 — anon ═══════════════════════════════════════════════════════════
  PERFORM set_config('role', 'postgres', true);
  ASSERT NOT has_function_privilege('anon',
    'public.log_dice_roll(text,text,text,text,integer,text)', 'EXECUTE'),
    '6.1 anon log_dice_roll çalıştırabiliyor';

  RAISE NOTICE '106 OK';
END $$;

ROLLBACK;
