-- ============================================================================
-- verify_096.sql — Faz 5a (096) self-check. Hiçbir kalıcı değişiklik yapmaz.
-- ============================================================================
-- Kullanım: Supabase Dashboard > SQL Editor > yapıştır > Run.
-- Sonunda ROLLBACK var; başarılıysa tek satır "096 OK" döner, aksi halde ilk
-- başarısız assertion exception olarak patlar.
--
-- Kapsam:
--   1. Echo guard — aynı gövdenin yeniden yazılması revizyonu ARTIRMAMALI.
--      Bu testin kırmızıya dönmesi iki cihaz arasında sonsuz senkron turu
--      demektir (bkz. 096 başlığı).
--   2. get_world_delta — pencere, tombstone, sayfalama, RLS.
--
-- Rol taklidi 094'teki gibi: tablo sahibi postgres RLS'i bypass ettiği için
-- okuma testleri MUTLAKA `authenticated` rolünde koşar.
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_dm    UUID := gen_random_uuid();
  v_pl    UUID := gen_random_uuid();
  v_world TEXT := 'verify096-world';
  v_rev   BIGINT;
  v_rev2  BIGINT;
  v_d     JSONB;
  v_row   BIGINT;
  v_n     INT;
BEGIN
  -- ══ Kurulum ════════════════════════════════════════════════════════════
  INSERT INTO auth.users (id, aud, role, email) VALUES
    (v_dm, 'authenticated', 'authenticated', 'verify096-dm@example.invalid'),
    (v_pl, 'authenticated', 'authenticated', 'verify096-pl@example.invalid');

  INSERT INTO public.worlds (id, owner_id, world_name)
    VALUES (v_world, v_dm, 'verify096');
  INSERT INTO public.world_members (world_id, user_id, role) VALUES
    (v_world, v_dm, 'dm'),
    (v_world, v_pl, 'player')
  ON CONFLICT (world_id, user_id) DO UPDATE SET role = EXCLUDED.role;

  INSERT INTO public.world_entities
    (id, world_id, category_slug, name, fields_json, updated_at) VALUES
    ('e1', v_world, 'npc', 'Ejder',  '{"hp":12}', '2026-06-01T00:00:00Z'),
    ('e2', v_world, 'npc', 'Goblin', '{"hp":7}',  '2026-06-01T00:00:00Z'),
    ('e3', v_world, 'npc', 'Kobold', '{"hp":5}',  '2026-06-01T00:00:00Z');
  INSERT INTO public.world_settings (world_id) VALUES (v_world);

  -- ══ 1 — Echo guard ═════════════════════════════════════════════════════
  SELECT revision INTO v_rev FROM public.world_revisions WHERE world_id = v_world;
  SELECT revision INTO v_row FROM public.world_entities WHERE id = 'e1';

  -- 1.1 Aynı gövdeyi geri yaz: sayaç KIPIRDAMAMALI.
  UPDATE public.world_entities
     SET name = 'Ejder', fields_json = '{"hp":12}',
         updated_at = '2026-06-01T00:00:00Z'
   WHERE id = 'e1';
  SELECT revision INTO v_rev2 FROM public.world_revisions WHERE world_id = v_world;
  ASSERT v_rev2 = v_rev,
    '1.1 AYNI GOVDE REVIZYONU ARTIRDI — echo dongusu acik';

  -- 1.2 Satırın kendi revizyonu da sabit kalmalı: değişseydi delta onu
  -- karşı cihaza yeniden gönderirdi.
  ASSERT (SELECT revision FROM public.world_entities WHERE id = 'e1') = v_row,
    '1.2 satir revizyonu bos yazmada artti';

  -- 1.3 Gerçek değişiklik hâlâ sayacı artırmalı.
  UPDATE public.world_entities SET name = 'Yasli Ejder' WHERE id = 'e1';
  ASSERT (SELECT revision FROM public.world_revisions WHERE world_id = v_world)
         > v_rev2,
    '1.3 GERCEK DEGISIKLIK REVIZYONU ARTIRMADI — senkron olu';

  -- 1.4 INSERT şartsız artırır.
  SELECT revision INTO v_rev FROM public.world_revisions WHERE world_id = v_world;
  INSERT INTO public.world_map_pins (id, world_id, x, y)
    VALUES ('p1', v_world, 1, 2);
  ASSERT (SELECT revision FROM public.world_revisions WHERE world_id = v_world)
         > v_rev,
    '1.4 INSERT revizyonu artirmadi';

  -- 1.5 Paket sayacında da aynı guard.
  INSERT INTO public.user_packages (id, owner_id, name)
    VALUES ('up1', v_dm, 'DM paketi');
  SELECT revision INTO v_rev FROM public.user_packages WHERE id = 'up1';
  UPDATE public.user_packages SET name = 'DM paketi' WHERE id = 'up1';
  ASSERT (SELECT revision FROM public.user_packages WHERE id = 'up1') = v_rev,
    '1.5 PAKET: ayni govde revizyonu artirdi (her push turu bos yazma)';

  -- ══ 2 — get_world_delta, DM rolüyle ════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_dm, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);

  -- 2.1 since = 0 → her şey.
  v_d := public.get_world_delta(v_world, 0, 500);
  ASSERT jsonb_array_length(v_d -> 'tables' -> 'world_entities') = 3,
    '2.1 tam delta 3 kart dondurmedi';
  ASSERT jsonb_array_length(v_d -> 'tables' -> 'world_settings') = 1,
    '2.2 1:1 tablo delta''da yok';
  ASSERT (v_d ->> 'complete')::boolean, '2.3 tam delta complete degil';

  -- 2.4 Pencere: son revizyondan sonrası boş.
  v_rev := (v_d ->> 'revision')::bigint;
  v_d := public.get_world_delta(v_world, v_rev, 500);
  ASSERT jsonb_array_length(v_d -> 'tables' -> 'world_entities') = 0,
    '2.4 bos pencere satir dondurdu';

  -- 2.5 Tek kart düzenle → yalnız o gelsin.
  UPDATE public.world_entities SET name = 'Kizil Ejder' WHERE id = 'e1';
  v_d := public.get_world_delta(v_world, v_rev, 500);
  ASSERT jsonb_array_length(v_d -> 'tables' -> 'world_entities') = 1,
    '2.5 artimli delta 1 satir dondurmedi';
  ASSERT v_d -> 'tables' -> 'world_entities' -> 0 ->> 'id' = 'e1',
    '2.6 yanlis satir dondu';

  -- 2.7 Silme → tombstone delta'da.
  v_rev := (v_d ->> 'revision')::bigint;
  DELETE FROM public.world_entities WHERE id = 'e2';
  v_d := public.get_world_delta(v_world, v_rev, 500);
  ASSERT jsonb_array_length(v_d -> 'tombstones') = 1, '2.7 tombstone dondurmedi';
  ASSERT v_d -> 'tombstones' -> 0 ->> 'row_id' = 'e2', '2.8 yanlis tombstone';

  -- 2.9 Sayfalama: limit 1 → complete false, kesme noktası ilerlemeli.
  v_d := public.get_world_delta(v_world, 0, 1);
  ASSERT NOT (v_d ->> 'complete')::boolean, '2.9 kirpilmis delta complete dedi';
  ASSERT (v_d ->> 'revision')::bigint > 0, '2.10 kesme noktasi ilerlemedi';
  -- Kırpma tüm tablolara uygulanmalı: dönen hiçbir satır kesme noktasını
  -- aşmamalı, yoksa istemci arada kalan satırı bir daha hiç görmez.
  SELECT count(*) INTO v_n
    FROM jsonb_each(v_d -> 'tables') AS tbl,
         jsonb_array_elements(tbl.value) AS r
   WHERE (r ->> 'revision')::bigint > (v_d ->> 'revision')::bigint;
  ASSERT v_n = 0, '2.11 KESME NOKTASININ OTESI DONDU — satir kaybi riski';

  -- 2.12 Sayfalama ilerliyor: aynı çağrıyı yeni damgayla tekrarla, sonunda
  -- complete olmalı.
  FOR v_n IN 1..20 LOOP
    EXIT WHEN (v_d ->> 'complete')::boolean;
    v_d := public.get_world_delta(v_world, (v_d ->> 'revision')::bigint, 1);
  END LOOP;
  ASSERT (v_d ->> 'complete')::boolean, '2.12 sayfalama sonlanmadi';

  -- ══ 3 — RLS: oyuncu bu kapıdan DM kartı GÖREMEZ ════════════════════════
  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_pl, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);

  v_d := public.get_world_delta(v_world, 0, 500);
  ASSERT jsonb_array_length(v_d -> 'tables' -> 'world_entities') = 0,
    '3.1 OYUNCU DM KARTLARINI GORUYOR — gizlilik hatasi';
  ASSERT jsonb_array_length(v_d -> 'tombstones') = 0,
    '3.2 OYUNCU DM TOMBSTONE''LARINI GORUYOR';

  PERFORM set_config('role', 'postgres', true);
  RAISE NOTICE '096 OK';
END $$;

SELECT '096 OK' AS result;

ROLLBACK;
