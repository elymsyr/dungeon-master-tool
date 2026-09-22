-- ============================================================================
-- 096_world_delta.sql — Faz 5a: echo guard + delta okuma kapısı
-- ============================================================================
-- Bkz. docs/online-sync-redesign.md §2.3 (CDC değil artımlı çekme), §2.4
-- (tombstone), §4.8 (Faz 5).
--
-- Ne yapar:
--   A) 094'ün `trg_*_stamp_rev` trigger'larını ikiye böler ve UPDATE dalına
--      `WHEN (OLD.* IS DISTINCT FROM NEW.*)` koyar.
--   B) `get_world_delta(world, since, limit)` — istemcinin tek okuma çağrısı.
--
-- Neden A, yani echo guard:
--   094'te trigger `BEFORE INSERT OR UPDATE`, şartsız. Pull gelince kapanmayan
--   bir döngü doğuyordu:
--
--     cihaz A pull eder → satırı yerele yazar (bulut `updated_at`'iyle)
--     → satır A'nın push damgasından yeni görünür → A aynı satırı geri push'lar
--     → trigger revizyonu artırır → B sinyal alır → B pull eder → B push'lar
--     → ... iki cihaz arasında sonsuz tur, her turda Realtime mesajı.
--
--   Aynı hata bugün de para yakıyor: `user_packages` satırı push'ta
--   `sinceAll` (her tur gider, FK hedefi). Hiçbir şey değişmese bile her tur
--   `revision`'ı bir artırıyordu.
--
--   `OLD.* IS DISTINCT FROM NEW.*` bunu kaynağında keser: upsert yalnız
--   gönderilen kolonları yazar, gönderilmeyen kolonlar OLD'da kalır, dolayısıyla
--   içerik aynıysa NEW = OLD ve sayaç kıpırdamaz. Satır yine UPDATE edilir
--   (boşa yazma), ama sinyal çıkmaz ve döngü kapanır.
--
-- Ne YAPMAZ — bilinçli:
--   * `entity_shares` tetikleyicisine (E.4) dokunmaz: o AFTER ve gövdesi
--     aynalanmıyor, echo'su yok.
--   * `get_package_delta` YOK — paket pull'u Faz 5b. Dünya ile birebir aynı
--     iskelet, kapsam kolonu `package_id`.
--   * Realtime publication'a tablo eklenmez/çıkarılmaz. İstemci sinyale Faz
--     5b'de geçiyor; 5a pull'u dünya açılışında elle koşuyor.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run.
-- Doğrulama: scripts/verify_096.sql
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM A — Echo guard
-- ──────────────────────────────────────────────────────────────────────────
-- 094 E.6 + E.7'deki tek trigger yerine iki trigger: INSERT şartsız (yeni
-- satır her zaman sayacı ilerletir), UPDATE yalnızca satır GERÇEKTEN
-- değiştiyse.
DO $$
DECLARE
  t  TEXT;
  fn TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'world_entities', 'world_settings', 'world_map_data', 'world_sessions',
    'world_mind_map_nodes', 'world_mind_map_edges', 'world_encounters',
    'world_combatants', 'world_map_pins', 'world_timeline_pins',
    'world_installed_packages', 'world_member_state', 'world_characters',
    'user_packages', 'user_package_entities', 'user_package_schemas'
  ] LOOP
    fn := CASE WHEN t LIKE 'user_package%'
               THEN 'public.tg_stamp_package_revision'
               ELSE 'public.tg_stamp_world_revision' END;

    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_stamp_rev     ON public.%I', t, t);
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_stamp_rev_ins ON public.%I', t, t);
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_stamp_rev_upd ON public.%I', t, t);

    EXECUTE format(
      'CREATE TRIGGER trg_%s_stamp_rev_ins BEFORE INSERT ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION %s()', t, t, fn);
    EXECUTE format(
      'CREATE TRIGGER trg_%s_stamp_rev_upd BEFORE UPDATE ON public.%I '
      'FOR EACH ROW WHEN (OLD.* IS DISTINCT FROM NEW.*) '
      'EXECUTE FUNCTION %s()', t, t, fn);
  END LOOP;
END $$;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM B — get_world_delta (§2.3)
-- ──────────────────────────────────────────────────────────────────────────
-- Tek çağrı, tek transaction, tek jsonb. 12 ayna tablosunun `revision >
-- p_since` satırları + aynı pencerenin tombstone'ları.
--
-- SECURITY INVOKER (varsayılan): RLS çağıranın rolüyle işler. DM kendi
-- dünyasının hepsini görür, oyuncu 094 F.4 gereği hiçbirini — oyuncunun
-- kapısı `get_shared_entities`, bu değil.
--
-- Sayfalama: tablo başına `p_limit` satır. Bir tablo dolduysa turun kesme
-- noktası (`revision`) o tablonun son satırına çekilir ve TÜM tablolar o
-- noktadan kırpılır — böylece dönen paket tutarlı bir revizyon aralığı olur
-- ve istemci `complete` false olduğu sürece yeni `revision` ile tekrar çağırır.
-- İlerleme garantili: kesme noktası her zaman `p_since`'ten büyüktür.
CREATE OR REPLACE FUNCTION public.get_world_delta(
  p_world TEXT,
  p_since BIGINT DEFAULT 0,
  p_limit INT     DEFAULT 500
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_tables CONSTANT TEXT[] := ARRAY[
    'world_entities', 'world_settings', 'world_map_data', 'world_sessions',
    'world_mind_map_nodes', 'world_mind_map_edges', 'world_encounters',
    'world_combatants', 'world_map_pins', 'world_timeline_pins',
    'world_characters', 'world_installed_packages'
  ];
  t      TEXT;
  v_raw  JSONB  := '{}'::jsonb;
  v_out  JSONB  := '{}'::jsonb;
  v_rows JSONB;
  v_tomb JSONB;
  v_head BIGINT;
  v_cut  BIGINT;
  v_max  BIGINT;
BEGIN
  IF p_limit IS NULL OR p_limit < 1 OR p_limit > 2000 THEN
    p_limit := 500;
  END IF;
  p_since := COALESCE(p_since, 0);

  -- Dünya görünmüyorsa (RLS) boş delta döner; hata atmıyoruz, istemci
  -- "değişiklik yok" gibi davranır.
  IF NOT EXISTS (SELECT 1 FROM public.worlds WHERE id = p_world) THEN
    RETURN jsonb_build_object(
      'revision', p_since, 'head', p_since, 'complete', true,
      'tables', '{}'::jsonb, 'tombstones', '[]'::jsonb);
  END IF;

  SELECT COALESCE(revision, 0) INTO v_head
    FROM public.world_revisions WHERE world_id = p_world;
  v_head := COALESCE(v_head, 0);
  v_cut  := v_head;

  -- 1. tur: her tablodan pencereyi çek, kesme noktasını daralt.
  FOREACH t IN ARRAY v_tables LOOP
    EXECUTE format(
      'SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.revision), ''[]''::jsonb) '
      'FROM (SELECT * FROM public.%I '
      '       WHERE world_id = $1 AND revision > $2 '
      '       ORDER BY revision LIMIT $3) x', t)
      INTO v_rows USING p_world, p_since, p_limit;

    v_raw := v_raw || jsonb_build_object(t, v_rows);

    IF jsonb_array_length(v_rows) >= p_limit THEN
      v_max := (v_rows -> (p_limit - 1) ->> 'revision')::bigint;
      IF v_max < v_cut THEN v_cut := v_max; END IF;
    END IF;
  END LOOP;

  -- Tombstone'lar: DM'in satırları (owner_id NULL) + çağıranın kendi
  -- satırları. DM'in sildiği kart id'leri başka bir oyuncuya sızmaz — RLS
  -- (F.2) zaten kapatıyor, buradaki şart onu tekrar ediyor.
  SELECT COALESCE(jsonb_agg(to_jsonb(d) ORDER BY d.revision), '[]'::jsonb)
    INTO v_tomb
    FROM (SELECT table_name, row_id, deleted_at, revision
            FROM public.world_tombstones
           WHERE world_id = p_world
             AND revision > p_since
             AND (owner_id IS NULL OR owner_id = (SELECT auth.uid()))
           ORDER BY revision LIMIT p_limit) d;

  IF jsonb_array_length(v_tomb) >= p_limit THEN
    v_max := (v_tomb -> (p_limit - 1) ->> 'revision')::bigint;
    IF v_max < v_cut THEN v_cut := v_max; END IF;
  END IF;

  -- 2. tur: kesme noktasının ötesini at.
  IF v_cut >= v_head THEN
    v_out  := v_raw;
  ELSE
    FOREACH t IN ARRAY v_tables LOOP
      v_out := v_out || jsonb_build_object(t, COALESCE(
        (SELECT jsonb_agg(e) FROM jsonb_array_elements(v_raw -> t) e
          WHERE (e ->> 'revision')::bigint <= v_cut), '[]'::jsonb));
    END LOOP;
    v_tomb := COALESCE(
      (SELECT jsonb_agg(e) FROM jsonb_array_elements(v_tomb) e
        WHERE (e ->> 'revision')::bigint <= v_cut), '[]'::jsonb);
  END IF;

  RETURN jsonb_build_object(
    'revision',   v_cut,
    'head',       v_head,
    'complete',   v_cut >= v_head,
    'tables',     v_out,
    'tombstones', v_tomb);
END $$;

COMMENT ON FUNCTION public.get_world_delta(TEXT, BIGINT, INT) IS
  'Dünyanın `since` revizyonundan sonraki değişiklikleri tek pakette döner '
  '(§2.3). SECURITY INVOKER — RLS çağıranın rolüyle işler; oyuncu bu kapıdan '
  'DM kartı göremez, onun kapısı get_shared_entities. `complete` false ise '
  'istemci dönen `revision` ile tekrar çağırır.';

REVOKE ALL ON FUNCTION public.get_world_delta(TEXT, BIGINT, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_world_delta(TEXT, BIGINT, INT)
  TO authenticated;
