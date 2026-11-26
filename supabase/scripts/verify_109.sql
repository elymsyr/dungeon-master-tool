-- ============================================================================
-- verify_109.sql — katılma istekleri (109) self-check. Hiçbir kalıcı değişiklik
-- yapmaz.
-- ============================================================================
-- Kullanım: Supabase Dashboard > SQL Editor > yapıştır > Run.
-- Sonunda ROLLBACK var; başarılıysa "109 OK" notice'i döner, aksi halde ilk
-- başarısız assertion exception olarak patlar.
--
-- Kapsam:
--   1. Kullanıcı kendini world_members / conversation_members'a ekleyemez.
--   2. Kod istek yazar, üye yapmaz; tekrar gönderim tek satır kalır.
--   3. İsteği DM ve sahibi görür, başkası görmez.
--   4. 10 bekleyen istekten sonra 11. reddedilir (P0005), satır düşmez.
--   5. DM olmayan yanıtlayamaz; DM kabul → üye, ret → üye değil.
--   6. Üye olanın kodu 'member' döner; open_direct_conversation çalışır.
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_dm    UUID := gen_random_uuid();
  v_pl    UUID := gen_random_uuid();
  v_out   UUID := gen_random_uuid();
  v_world TEXT := 'verify109-world';
  v_code  TEXT := 'VRFY1090';
  v_conv  UUID;
  v_extra UUID[] := ARRAY[]::UUID[];
  v_u     UUID;
  v_n     INT;
  v_ok    BOOLEAN;
  v_st    TEXT;
BEGIN
  INSERT INTO auth.users (id, aud, role, email) VALUES
    (v_dm,  'authenticated', 'authenticated', 'verify109-dm@example.invalid'),
    (v_pl,  'authenticated', 'authenticated', 'verify109-pl@example.invalid'),
    (v_out, 'authenticated', 'authenticated', 'verify109-ou@example.invalid');
  FOR i IN 1..10 LOOP
    v_u := gen_random_uuid();
    v_extra := v_extra || v_u;
    INSERT INTO auth.users (id, aud, role, email)
      VALUES (v_u, 'authenticated', 'authenticated',
              'verify109-x' || i || '@example.invalid');
  END LOOP;
  INSERT INTO public.profiles (user_id, username) VALUES
    (v_dm, 'verify109dm'), (v_pl, 'verify109pl'), (v_out, 'verify109ou')
  ON CONFLICT (user_id) DO NOTHING;
  INSERT INTO public.worlds (id, owner_id, world_name)
    VALUES (v_world, v_dm, 'verify109');
  INSERT INTO public.world_members (world_id, user_id, role)
    VALUES (v_world, v_dm, 'dm')
  ON CONFLICT (world_id, user_id) DO UPDATE SET role = EXCLUDED.role;
  INSERT INTO public.world_invites (code, world_id, created_by, uses_left)
    VALUES (v_code, v_world, v_dm, 99999);
  INSERT INTO public.conversations (is_group, created_by)
    VALUES (false, v_dm) RETURNING id INTO v_conv;
  INSERT INTO public.conversation_members (conversation_id, user_id)
    VALUES (v_conv, v_dm), (v_conv, v_pl);

  -- ══ 1 — Doğrudan self-insert kapalı ════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_out, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  ASSERT auth.uid() = v_out, '0 rol taklidi çalışmadı';

  v_ok := false;
  BEGIN
    INSERT INTO public.world_members (world_id, user_id, role)
    VALUES (v_world, v_out, 'player');
  EXCEPTION WHEN insufficient_privilege THEN v_ok := true;
  END;
  ASSERT v_ok, '1.1 kullanıcı kendini dünyaya ekleyebildi';

  v_ok := false;
  BEGIN
    INSERT INTO public.conversation_members (conversation_id, user_id)
    VALUES (v_conv, v_out);
  EXCEPTION WHEN insufficient_privilege THEN v_ok := true;
  END;
  ASSERT v_ok, '1.2 kullanıcı kendini özel konuşmaya ekleyebildi';

  v_ok := false;
  BEGIN
    INSERT INTO public.world_join_requests (world_id, user_id)
    VALUES (v_world, v_out);
  EXCEPTION WHEN insufficient_privilege THEN v_ok := true;
  END;
  ASSERT v_ok, '1.3 istek RPC dışından yazılabildi';

  -- ══ 2 — Kod istek yazar ════════════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_pl, 'role', 'authenticated')::text, true);
  SELECT r.status INTO v_st FROM public.redeem_world_invite(lower(v_code)) r;
  ASSERT v_st = 'pending', '2.1 ilk gönderim pending değil: ' || v_st;
  ASSERT NOT public.is_world_member(v_world), '2.2 istek üye yaptı';
  SELECT r.status INTO v_st FROM public.redeem_world_invite(v_code) r;
  ASSERT v_st = 'pending', '2.3 tekrar gönderim pending değil';
  SELECT count(*) INTO v_n FROM public.world_join_requests;
  ASSERT v_n = 1, '2.4 oyuncu kendi isteğini görmüyor / çift satır';

  -- ══ 3 — Başkası göremez ════════════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_out, 'role', 'authenticated')::text, true);
  SELECT count(*) INTO v_n FROM public.world_join_requests;
  ASSERT v_n = 0, '3.1 yabancı başkasının isteğini görüyor';

  -- ══ 4 — Sınır ══════════════════════════════════════════════════════════
  FOR i IN 1..9 LOOP
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_extra[i], 'role', 'authenticated')::text, true);
    PERFORM public.redeem_world_invite(v_code);
  END LOOP;
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_extra[10], 'role', 'authenticated')::text, true);
  v_ok := false;
  BEGIN PERFORM public.redeem_world_invite(v_code);
  EXCEPTION WHEN SQLSTATE 'P0005' THEN v_ok := true; END;
  ASSERT v_ok, '4.1 11. istek kabul edildi';
  SELECT count(*) INTO v_n FROM public.world_join_requests;
  ASSERT v_n = 0, '4.2 reddedilen istek satır bıraktı';

  -- ══ 5 — Yanıt ══════════════════════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_out, 'role', 'authenticated')::text, true);
  v_ok := false;
  BEGIN PERFORM public.answer_join_request(v_world, v_pl, true);
  EXCEPTION WHEN insufficient_privilege THEN v_ok := true; END;
  ASSERT v_ok, '5.1 DM olmayan isteği yanıtlayabildi';

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_dm, 'role', 'authenticated')::text, true);
  SELECT count(*) INTO v_n FROM public.world_join_requests WHERE world_id = v_world;
  ASSERT v_n = 10, '5.2 DM istekleri görmüyor: ' || v_n;
  PERFORM public.answer_join_request(v_world, v_pl, true);
  PERFORM public.answer_join_request(v_world, v_extra[1], false);
  SELECT count(*) INTO v_n FROM public.world_members
   WHERE world_id = v_world AND user_id = v_pl AND role = 'player';
  ASSERT v_n = 1, '5.3 kabul üye yapmadı';
  SELECT count(*) INTO v_n FROM public.world_members
   WHERE world_id = v_world AND user_id = v_extra[1];
  ASSERT v_n = 0, '5.4 ret üye yaptı';
  SELECT count(*) INTO v_n FROM public.world_join_requests WHERE world_id = v_world;
  ASSERT v_n = 8, '5.5 yanıtlanan istekler silinmedi';
  v_ok := false;
  BEGIN PERFORM public.answer_join_request(v_world, v_pl, true);
  EXCEPTION WHEN SQLSTATE 'P0002' THEN v_ok := true; END;
  ASSERT v_ok, '5.6 olmayan istek yanıtlandı';

  -- Yer açıldı: 11. kullanıcı artık gönderebilir.
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_extra[10], 'role', 'authenticated')::text, true);
  SELECT r.status INTO v_st FROM public.redeem_world_invite(v_code) r;
  ASSERT v_st = 'pending', '5.7 yer açılınca istek gönderilemedi';

  -- ══ 6 — Üye ve RPC yolları ═════════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_pl, 'role', 'authenticated')::text, true);
  SELECT r.status INTO v_st FROM public.redeem_world_invite(v_code) r;
  ASSERT v_st = 'member', '6.1 üyenin kodu member dönmedi';
  ASSERT public.is_world_member(v_world), '6.2 kabul edilen oyuncu üye değil';

  v_conv := public.open_direct_conversation(v_out);
  SELECT count(*) INTO v_n FROM public.conversation_members
   WHERE conversation_id = v_conv;
  ASSERT v_n = 2, '6.3 open_direct_conversation iki üye yazmadı';

  RAISE NOTICE '109 OK';
END $$;

ROLLBACK;
