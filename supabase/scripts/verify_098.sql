-- ============================================================================
-- verify_098.sql — Faz 5c (098) self-check. Hiçbir kalıcı değişiklik yapmaz.
-- ============================================================================
-- Kullanım: Supabase Dashboard > SQL Editor > yapıştır > Run.
-- Sonunda ROLLBACK var; başarılıysa tek satır "098 OK" döner, aksi halde ilk
-- başarısız assertion exception olarak patlar.
--
-- Kapsam:
--   1. Kart silmesi tombstone bırakır ve paket sayacını artırır; paketin
--      kendisi silinince (CASCADE) hata çıkmaz, iz kalmaz.
--   2. Tombstone'dan eski düzenleme silinmiş kartı diriltmez.
--   3. get_package_delta — pencere, tombstone, paket satırı yalnız son
--      sayfada, sayfalama sonlanıyor, başka kullanıcı hiçbir şey görmüyor.
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_me    UUID := gen_random_uuid();
  v_other UUID := gen_random_uuid();
  v_rev   BIGINT;
  v_d     JSONB;
  v_n     INT;
BEGIN
  -- ══ Kurulum ════════════════════════════════════════════════════════════
  INSERT INTO auth.users (id, aud, role, email) VALUES
    (v_me,    'authenticated', 'authenticated', 'verify098-me@example.invalid'),
    (v_other, 'authenticated', 'authenticated', 'verify098-other@example.invalid');
  INSERT INTO public.user_packages (id, owner_id, name)
    VALUES ('p1', v_me, 'Paket');
  INSERT INTO public.user_package_schemas (id, package_id, owner_id, name)
    VALUES ('s1', 'p1', v_me, 'Şema');
  INSERT INTO public.user_package_entities
    (id, package_id, owner_id, category_slug, name, updated_at) VALUES
    ('k1', 'p1', v_me, 'npc', 'Ejder',  '2026-06-01T00:00:00Z'),
    ('k2', 'p1', v_me, 'npc', 'Goblin', '2026-06-01T00:00:00Z'),
    ('k3', 'p1', v_me, 'npc', 'Kobold', '2026-06-01T00:00:00Z');

  -- ══ 1 — Tombstone ══════════════════════════════════════════════════════
  SELECT revision INTO v_rev FROM public.user_packages WHERE id = 'p1';
  DELETE FROM public.user_package_entities WHERE id = 'k2';
  ASSERT EXISTS (SELECT 1 FROM public.user_package_tombstones
                  WHERE package_id = 'p1' AND row_id = 'k2'
                    AND table_name = 'user_package_entities'),
    '1.1 KART SILMESI TOMBSTONE BIRAKMADI — obur cihaz karti hic silmez';
  ASSERT (SELECT revision FROM public.user_packages WHERE id = 'p1') > v_rev,
    '1.2 silme paket sayacini artirmadi — pull onu gormez';
  ASSERT (SELECT revision FROM public.user_package_tombstones WHERE row_id = 'k2')
         = (SELECT revision FROM public.user_packages WHERE id = 'p1'),
    '1.3 tombstone revizyonu sayacin son degeri degil';

  -- ══ 2 — Diriltme ═══════════════════════════════════════════════════════
  INSERT INTO public.user_package_entities
    (id, package_id, owner_id, category_slug, name, updated_at)
  VALUES ('k2', 'p1', v_me, 'npc', 'Hortlak', '2026-06-01T12:00:00Z')
  ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;
  ASSERT NOT EXISTS (SELECT 1 FROM public.user_package_entities WHERE id = 'k2'),
    '2.1 SILINMIS KART ESKI DUZENLEMEYLE DIRILDI';

  -- ══ 3 — get_package_delta, sahibin rolüyle ═════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_me, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);

  v_d := public.get_package_delta('p1', 0, 500);
  ASSERT (v_d ->> 'complete')::boolean, '3.1 tam delta complete degil';
  ASSERT jsonb_array_length(v_d -> 'tables' -> 'user_package_entities') = 2,
    '3.2 tam delta 2 kart dondurmedi';
  ASSERT jsonb_array_length(v_d -> 'tables' -> 'user_package_schemas') = 1,
    '3.3 sema delta''da yok';
  ASSERT jsonb_array_length(v_d -> 'tables' -> 'user_packages') = 1,
    '3.4 paketin kendi satiri tam delta''da yok';
  ASSERT jsonb_array_length(v_d -> 'tombstones') = 1, '3.5 tombstone yok';
  ASSERT (v_d ->> 'revision')::bigint = (v_d ->> 'head')::bigint,
    '3.6 tam delta basa ulasmadi';

  -- 3.7 Pencere: sonrası boş.
  v_rev := (v_d ->> 'revision')::bigint;
  v_d := public.get_package_delta('p1', v_rev, 500);
  ASSERT jsonb_array_length(v_d -> 'tables' -> 'user_package_entities') = 0
     AND jsonb_array_length(v_d -> 'tables' -> 'user_packages') = 0,
    '3.7 bos pencere satir dondurdu';

  -- 3.8 Sayfalama: limit 1 → paket satırı ilk sayfada GELMEMELİ (istemci onu
  -- en son yazar; erken gelseydi yarım paket hub'da görünürdü).
  v_d := public.get_package_delta('p1', 0, 1);
  ASSERT NOT (v_d ->> 'complete')::boolean, '3.8 kirpilmis delta complete dedi';
  ASSERT jsonb_array_length(v_d -> 'tables' -> 'user_packages') = 0,
    '3.9 PAKET SATIRI SON SAYFADAN ONCE GELDI';
  SELECT count(*) INTO v_n
    FROM jsonb_each(v_d -> 'tables') AS tbl,
         jsonb_array_elements(tbl.value) AS r
   WHERE (r ->> 'revision')::bigint > (v_d ->> 'revision')::bigint;
  ASSERT v_n = 0, '3.10 KESME NOKTASININ OTESI DONDU';
  FOR v_n IN 1..20 LOOP
    EXIT WHEN (v_d ->> 'complete')::boolean;
    v_d := public.get_package_delta('p1', (v_d ->> 'revision')::bigint, 1);
  END LOOP;
  ASSERT (v_d ->> 'complete')::boolean, '3.11 sayfalama sonlanmadi';
  ASSERT jsonb_array_length(v_d -> 'tables' -> 'user_packages') = 1,
    '3.12 paket satiri son sayfada gelmedi';

  -- 3.13 Başka kullanıcı hiçbir şey görmez.
  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_other, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  v_d := public.get_package_delta('p1', 0, 500);
  ASSERT v_d -> 'tables' = '{}'::jsonb
     AND jsonb_array_length(v_d -> 'tombstones') = 0,
    '3.13 BASKASININ PAKETI GORUNUYOR';
  PERFORM set_config('role', 'postgres', true);

  -- ══ 4 — Paketin kendisi silinince ══════════════════════════════════════
  DELETE FROM public.user_packages WHERE id = 'p1';
  ASSERT NOT EXISTS (SELECT 1 FROM public.user_package_tombstones
                      WHERE package_id = 'p1'),
    '4.1 paket silinince tombstone kaldi';
  ASSERT NOT EXISTS (SELECT 1 FROM public.user_package_entities
                      WHERE package_id = 'p1'),
    '4.2 cocuklar CASCADE ile gitmedi';

  RAISE NOTICE '098 OK';
END $$;

SELECT '098 OK' AS result;

ROLLBACK;
