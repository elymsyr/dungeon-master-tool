-- ============================================================================
-- verify_097.sql — Faz 5b (097) self-check. Hiçbir kalıcı değişiklik yapmaz.
-- ============================================================================
-- Kullanım: Supabase Dashboard > SQL Editor > yapıştır > Run.
-- Sonunda ROLLBACK var; başarılıysa tek satır "097 OK" döner, aksi halde ilk
-- başarısız assertion exception olarak patlar.
--
-- Kapsam (§2.8 — son düzenleyen kazanır, varış sırası değil):
--   1. Eski düzenleme buluttaki yeniyi ezmez; atlanan satır revizyon yakmaz.
--   2. Eşit zaman geçer — `next_package_revision` ve rol RPC'leri buna dayanıyor.
--   3. Tombstone'dan eski düzenleme silinmiş satırı diriltmez; yenisi diriltir.
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_dm    UUID := gen_random_uuid();
  v_world TEXT := 'verify097-world';
  v_rev   BIGINT;
BEGIN
  -- ══ Kurulum ════════════════════════════════════════════════════════════
  INSERT INTO auth.users (id, aud, role, email) VALUES
    (v_dm, 'authenticated', 'authenticated', 'verify097-dm@example.invalid');
  INSERT INTO public.worlds (id, owner_id, world_name)
    VALUES (v_world, v_dm, 'verify097');
  INSERT INTO public.world_entities
    (id, world_id, category_slug, name, fields_json, updated_at) VALUES
    ('e1', v_world, 'npc', 'Laptop 15:00', '{}', '2026-06-01T15:00:00Z'),
    ('e2', v_world, 'npc', 'Silinecek',    '{}', '2026-06-01T15:00:00Z');

  -- ══ 1 — Eski düzenleme ═════════════════════════════════════════════════
  SELECT revision INTO v_rev FROM public.world_revisions WHERE world_id = v_world;

  -- 1.1 Telefonun 14:00 düzenlemesi 16:00'da geliyor — PostgREST'in upsert'i.
  INSERT INTO public.world_entities
    (id, world_id, category_slug, name, fields_json, updated_at)
  VALUES ('e1', v_world, 'npc', 'Telefon 14:00', '{}', '2026-06-01T14:00:00Z')
  ON CONFLICT (id) DO UPDATE
    SET name = EXCLUDED.name, updated_at = EXCLUDED.updated_at;
  ASSERT (SELECT name FROM public.world_entities WHERE id = 'e1') = 'Laptop 15:00',
    '1.1 ESKI DUZENLEME YENIYI EZDI — varis zamani kazaniyor (§2.8)';

  -- 1.2 Atlanan satır sayacı artırmamalı: artsaydı karşı cihaz boşuna uyanırdı.
  ASSERT (SELECT revision FROM public.world_revisions WHERE world_id = v_world)
         = v_rev,
    '1.2 atlanan satir revizyon yakti';

  -- 1.3 Yeni düzenleme hâlâ yazılıyor.
  UPDATE public.world_entities
     SET name = 'Tablet 17:00', updated_at = '2026-06-01T17:00:00Z'
   WHERE id = 'e1';
  ASSERT (SELECT name FROM public.world_entities WHERE id = 'e1') = 'Tablet 17:00',
    '1.3 YENI DUZENLEME YAZILMADI — senkron olu';

  -- ══ 2 — Eşit zaman geçer ═══════════════════════════════════════════════
  UPDATE public.world_entities SET name = 'Ayni saniye' WHERE id = 'e1';
  ASSERT (SELECT name FROM public.world_entities WHERE id = 'e1') = 'Ayni saniye',
    '2.1 updated_at''e dokunmayan guncelleme yutuldu';

  -- 2.2 Paket sayacı: çocuk yazması paketin satırını updated_at'e dokunmadan
  -- günceller. `<=` olsaydı sayaç 0'a düşerdi.
  INSERT INTO public.user_packages (id, owner_id, name)
    VALUES ('up1', v_dm, 'Paket');
  SELECT revision INTO v_rev FROM public.user_packages WHERE id = 'up1';
  INSERT INTO public.user_package_entities
    (id, package_id, owner_id, category_slug, name)
    VALUES ('upe1', 'up1', v_dm, 'npc', 'Kart');
  ASSERT (SELECT revision FROM public.user_packages WHERE id = 'up1') > v_rev,
    '2.2 PAKET SAYACI ILERLEMEDI — lww guard next_package_revision''i yuttu';
  ASSERT (SELECT revision FROM public.user_package_entities WHERE id = 'upe1') > 0,
    '2.3 paket karti revizyonsuz kaldi';

  -- ══ 3 — Tombstone ══════════════════════════════════════════════════════
  DELETE FROM public.world_entities WHERE id = 'e2';
  ASSERT EXISTS (SELECT 1 FROM public.world_tombstones
                  WHERE world_id = v_world AND row_id = 'e2'),
    '3.0 tombstone yazilmadi';

  -- 3.1 Silmeden önceki bir düzenleme geri gelmemeli.
  SELECT revision INTO v_rev FROM public.world_revisions WHERE world_id = v_world;
  INSERT INTO public.world_entities
    (id, world_id, category_slug, name, fields_json, updated_at)
  VALUES ('e2', v_world, 'npc', 'Hortlak', '{}', '2026-06-01T15:30:00Z')
  ON CONFLICT (id) DO UPDATE
    SET name = EXCLUDED.name, updated_at = EXCLUDED.updated_at;
  ASSERT NOT EXISTS (SELECT 1 FROM public.world_entities WHERE id = 'e2'),
    '3.1 SILINMIS KART ESKI DUZENLEMEYLE DIRILDI';
  ASSERT (SELECT revision FROM public.world_revisions WHERE world_id = v_world)
         = v_rev,
    '3.2 reddedilen dirilis revizyon yakti';

  -- 3.3 Silmeden sonraki düzenleme diriltir (§2.8'in öteki yönü).
  INSERT INTO public.world_entities
    (id, world_id, category_slug, name, fields_json, updated_at)
  VALUES ('e2', v_world, 'npc', 'Geri dondu', '{}', now() + interval '1 hour');
  ASSERT EXISTS (SELECT 1 FROM public.world_entities WHERE id = 'e2'),
    '3.3 silmeden SONRAKI duzenleme yazilmadi';

  -- 3.4 Tombstone'u olmayan satır ne kadar eski olursa olsun yazılır.
  INSERT INTO public.world_map_pins (id, world_id, x, y, updated_at)
    VALUES ('e2-pin', v_world, 1, 2, '2020-01-01T00:00:00Z');
  ASSERT EXISTS (SELECT 1 FROM public.world_map_pins WHERE id = 'e2-pin'),
    '3.4 tombstone''u olmayan eski satir reddedildi';

  -- ══ 4 — Upsert sayacı yakmamalı (C, 096'nın deliği) ═══════════════════
  -- PostgREST'in upsert'i INSERT … ON CONFLICT; BEFORE INSERT trigger'ı
  -- çakışmadan önce koşar. verify_096'nın düz UPDATE'i bunu görmüyordu.
  SELECT revision INTO v_rev FROM public.world_revisions WHERE world_id = v_world;

  -- 4.1 Aynı gövdenin upsert'i: sayaç sabit.
  INSERT INTO public.world_entities
    (id, world_id, category_slug, name, fields_json, updated_at)
  SELECT id, world_id, category_slug, name, fields_json, updated_at
    FROM public.world_entities WHERE id = 'e1'
  ON CONFLICT (id) DO UPDATE
    SET name = EXCLUDED.name, fields_json = EXCLUDED.fields_json,
        updated_at = EXCLUDED.updated_at;
  ASSERT (SELECT revision FROM public.world_revisions WHERE world_id = v_world)
         = v_rev,
    '4.1 AYNI GOVDENIN UPSERT''I SAYACI YAKTI — echo guard delik';

  -- 4.2 Değişen gövde: sayaç TAM BİR artar ve satır o revizyonu taşır. İki
  -- artsaydı biri ölü revizyon olurdu ve istemcinin yankı kontrolü
  -- (ownRunEnd: "dönen revizyonlar boşluksuz mu") hiç tutmazdı.
  INSERT INTO public.world_entities
    (id, world_id, category_slug, name, fields_json, updated_at)
  VALUES ('e1', v_world, 'npc', 'Upsert', '{}', now() + interval '2 hours')
  ON CONFLICT (id) DO UPDATE
    SET name = EXCLUDED.name, updated_at = EXCLUDED.updated_at;
  ASSERT (SELECT revision FROM public.world_revisions WHERE world_id = v_world)
         = v_rev + 1,
    '4.2 GUNCELLEME UPSERT''I BIRDEN FAZLA REVIZYON YAKTI — olu revizyon';
  ASSERT (SELECT revision FROM public.world_entities WHERE id = 'e1') = v_rev + 1,
    '4.3 satir sayacin son degerini tasimiyor';

  -- 4.4 Yeni satırın upsert'i hâlâ damgalanıyor.
  INSERT INTO public.world_entities
    (id, world_id, category_slug, name, fields_json, updated_at)
  VALUES ('e3', v_world, 'npc', 'Yeni', '{}', now())
  ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;
  ASSERT (SELECT revision FROM public.world_entities WHERE id = 'e3') = v_rev + 2,
    '4.4 YENI SATIR DAMGALANMADI — delta onu hic getirmez';

  -- 4.5 Bileşik PK'lı tabloda da aynı.
  INSERT INTO public.world_installed_packages (world_id, package_id)
    VALUES (v_world, 'pk1');
  SELECT revision INTO v_rev FROM public.world_revisions WHERE world_id = v_world;
  INSERT INTO public.world_installed_packages (world_id, package_id)
    VALUES (v_world, 'pk1')
  ON CONFLICT (world_id, package_id) DO UPDATE SET package_id = EXCLUDED.package_id;
  ASSERT (SELECT revision FROM public.world_revisions WHERE world_id = v_world)
         = v_rev,
    '4.5 bilesik PK''li tabloda ayni upsert sayaci yakti';

  -- 4.6 Paket çocuğu: aynı gövde paketin sayacını yakmamalı.
  SELECT revision INTO v_rev FROM public.user_packages WHERE id = 'up1';
  INSERT INTO public.user_package_entities
    (id, package_id, owner_id, category_slug, name)
    VALUES ('upe1', 'up1', v_dm, 'npc', 'Kart')
  ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;
  ASSERT (SELECT revision FROM public.user_packages WHERE id = 'up1') = v_rev,
    '4.6 PAKET: ayni govdenin upsert''i sayaci yakti';

  RAISE NOTICE '097 OK';
END $$;

SELECT '097 OK' AS result;

ROLLBACK;
