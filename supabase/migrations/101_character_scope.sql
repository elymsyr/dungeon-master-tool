-- ============================================================================
-- 101_character_scope.sql — Faz 5g: karakterin kendi kapsamı
-- ============================================================================
-- Bkz. docs/online-sync-redesign.md §4.8.7 (Faz 5g).
--
-- Neden: karakter bugüne kadar yalnız dünyanın parçası olarak buluta
-- çıkıyordu. Sahibinin öbür cihazına bir şey gelmiyordu, dünyasız karakter
-- buluta hiç yazılamıyordu ve görselleri iki ayrı yoldan (free-media +
-- pinned havuz) gidip push turunda eziliyordu.
--
-- Kullanıcının kararları (2026-10-01):
--   * Sahip kapsamı ayrı bir sayaçla: satırda `owner_revision`, kullanıcı
--     başına `character_revisions` satırı ve tek Realtime sinyali. Online
--     dünyadaki karakter iki kapsamda birden: dünyanınkinde DM'in cihazları,
--     sahibininkinde sahibinin cihazları görür.
--   * Multiplayer kapatılınca sahipli karakter online kalır: bulutta dünyasız
--     satır olarak durur, sahibi isterse yerele alır (039'un kuralı).
--   * Silme yayılır: sahibin öbür cihazı silinen karakteri çöpe atar. "Yerele
--     al" ise yalnız bulut kopyasını kaldırır; öbür cihaz yerel kopyayı tutar.
--
-- Ne yapar:
--   A) Hata: 094'ün revizyon trigger'ı `world_id` NULL satırda patlıyordu
--      (`world_revisions`'a NULL). Sonuçları: sahipli karakteri olan dünyanın
--      multiplayer'ı kapatılamıyordu (FK'nın SET NULL'u trigger'a takılıyor),
--      `remove_from_world` sahipli karakterde ve hesap silme başka oyuncunun
--      karakterini taşıyan dünyada hata veriyordu, dünyasız karakter hiç
--      yazılamıyordu. Karakterin trigger'ı artık iki sayacı ayrı ayrı damgalıyor.
--   B) Sahip sayacı: `character_revisions`, `next_character_revision`,
--      `world_characters.owner_revision` (+ mevcut satırların doldurulması).
--   C) Bulutta olmayan dünya: istemci karakterin yerel dünyasını gönderir;
--      dünya bulutta yoksa (online değilse) `world_id` NULL'a çekilir. Bağ
--      `payload_json`'daki `worldId`'de kalır.
--   D) Sahip tombstone'ları: silme `deleted`, yerele alma ve sahiplik
--      değişimi `gone`. Tombstone'dan eski düzenleme satırı diriltmez.
--   E) Karakter dünyadan ayrılınca dünyaya tombstone: DM'in cihazları onu
--      dünyadan düşürsün.
--   F) `get_character_delta(since, limit)` — `get_world_delta`'nın eşi.
--   G) `get_world_delta`: DM dünyanın bütün tombstone'larını görür (oyuncunun
--      karakterininkiler dahil); önceki hali yalnız sahipsizleri veriyordu.
--   H) `remove_from_world` payload'daki `worldId`'yi de boşaltır; sahibin
--      dünyasız satırını silme izni; `unpublish_character` ("yerele al").
--   I) Medya: `world_media.character_id` üçüncü kapsam, R2'de
--      `characters/{characterId}/`. Rezervasyon karakterin sahibine ya da
--      dünyasının DM'ine; imza (get) sahibine ve dünyasının üyelerine; kota
--      sahibin (sahipsizde dünyanın sahibinin).
--
-- Deploy sırası: 100 → 101 → worker → uygulama. 101 tek başına (worker'sız)
-- deploy edilirse karakter medyası imzalanmaz ama hiçbir şey bozulmaz.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run.
-- Doğrulama: ayrı bir verify betiği yok; istemcinin yazmaları yerelde geri
-- alınan bir işlemde denendi (docs/online-sync-redesign.md §4.8.7).
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM B — Sahip sayacı (A'nın trigger'ı bunu kullanıyor, önce kurulur)
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.character_revisions (
  owner_id   UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  revision   BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.character_revisions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.character_revisions FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.character_revisions FROM authenticated;
DROP POLICY IF EXISTS "CRev: own read" ON public.character_revisions;
CREATE POLICY "CRev: own read" ON public.character_revisions
  FOR SELECT USING (owner_id = (SELECT auth.uid()));

-- Sahibin sayacını bir artırır. İstemciye kapalı: yalnız trigger'lar çağırır.
CREATE OR REPLACE FUNCTION public.next_character_revision(p_owner UUID)
RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE v_rev BIGINT;
BEGIN
  INSERT INTO public.character_revisions AS cr (owner_id, revision, updated_at)
  VALUES (p_owner, 1, now())
  ON CONFLICT (owner_id) DO UPDATE
    SET revision   = cr.revision + 1,
        updated_at = now()
  RETURNING cr.revision INTO v_rev;
  RETURN v_rev;
END $$;

REVOKE ALL ON FUNCTION public.next_character_revision(UUID)
  FROM PUBLIC, anon, authenticated;

ALTER TABLE public.world_characters
  ADD COLUMN IF NOT EXISTS owner_revision BIGINT NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_world_characters_owner_delta
  ON public.world_characters (owner_id, owner_revision);

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM A — Revizyon trigger'ı: iki sayaç, ikisi de NULL'a dayanıklı
-- ──────────────────────────────────────────────────────────────────────────
-- 097 C'nin kuralı korunuyor: upsert'in INSERT dalı satır zaten varsa
-- damgalamaz, kararı UPDATE dalı (WHEN OLD.* IS DISTINCT FROM NEW.*) verir.
CREATE OR REPLACE FUNCTION public.tg_stamp_character_revision()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT'
     AND EXISTS (SELECT 1 FROM public.world_characters WHERE id = NEW.id) THEN
    RETURN NEW;
  END IF;
  IF NEW.world_id IS NOT NULL THEN
    NEW.revision := public.next_world_revision(NEW.world_id);
  END IF;
  IF NEW.owner_id IS NOT NULL THEN
    NEW.owner_revision := public.next_character_revision(NEW.owner_id);
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_world_characters_stamp_rev_ins ON public.world_characters;
DROP TRIGGER IF EXISTS trg_world_characters_stamp_rev_upd ON public.world_characters;
CREATE TRIGGER trg_world_characters_stamp_rev_ins
  BEFORE INSERT ON public.world_characters
  FOR EACH ROW EXECUTE FUNCTION public.tg_stamp_character_revision();
CREATE TRIGGER trg_world_characters_stamp_rev_upd
  BEFORE UPDATE ON public.world_characters
  FOR EACH ROW WHEN (OLD.* IS DISTINCT FROM NEW.*)
  EXECUTE FUNCTION public.tg_stamp_character_revision();

-- Mevcut sahipli satırlar sahip kapsamına girsin: `owner_revision` 0 olan
-- satır `get_character_delta(0)`'da hiç dönmezdi. Trigger'lar kapalıyken —
-- açık olsalar her satır dünya sayacını da yakar, DM'in cihazları boşa
-- uyanırdı. İkinci koşuda doldurulacak satır kalmadığı için atlanır.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.world_characters
              WHERE owner_id IS NOT NULL AND owner_revision = 0) THEN
    ALTER TABLE public.world_characters DISABLE TRIGGER USER;
    WITH n AS (
      SELECT id,
             row_number() OVER (PARTITION BY owner_id
                                ORDER BY updated_at, id) AS rn
        FROM public.world_characters
       WHERE owner_id IS NOT NULL
    )
    UPDATE public.world_characters c
       SET owner_revision = n.rn
      FROM n
     WHERE c.id = n.id;
    ALTER TABLE public.world_characters ENABLE TRIGGER USER;

    INSERT INTO public.character_revisions (owner_id, revision)
      SELECT owner_id, max(owner_revision)
        FROM public.world_characters
       WHERE owner_id IS NOT NULL
       GROUP BY owner_id
    ON CONFLICT (owner_id) DO UPDATE
      SET revision = GREATEST(public.character_revisions.revision,
                              EXCLUDED.revision);
  END IF;
END $$;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM C — Bulutta olmayan dünya
-- ──────────────────────────────────────────────────────────────────────────
-- İstemci karakterin yerel dünyasını olduğu gibi gönderir; dünyanın online
-- olup olmadığını oyuncunun cihazı çevrimdışıyken bilemiyor. Dünya bulutta
-- yoksa satır dünyasız yazılır — FK ve RLS bu trigger'dan SONRA bakar.
-- Ad sırası: aynı zamanlamadaki trigger'lar ada göre koşar; `a_` lww ve
-- stamp'ten önce, ikisi de NULL'lanmış değeri görür.
CREATE OR REPLACE FUNCTION public.tg_character_cloud_world()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF NEW.world_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.worlds WHERE id = NEW.world_id) THEN
    NEW.world_id := NULL;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_world_characters_a_cloud_world ON public.world_characters;
CREATE TRIGGER trg_world_characters_a_cloud_world
  BEFORE INSERT OR UPDATE ON public.world_characters
  FOR EACH ROW EXECUTE FUNCTION public.tg_character_cloud_world();

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM D — Sahip tombstone'ları
-- ──────────────────────────────────────────────────────────────────────────
-- `deleted`: karakter silindi — sahibin öbür cihazı onu çöpe atar.
-- `gone`   : bulut kopyası kalktı ama karakter silinmedi (yerele alındı ya
--            da sahipliği el değiştirdi) — öbür cihaz yerel kopyayı tutar,
--            yalnız offline'a düşürür.
CREATE TABLE IF NOT EXISTS public.character_tombstones (
  owner_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  character_id TEXT NOT NULL,
  kind         TEXT NOT NULL CHECK (kind IN ('deleted', 'gone')),
  revision     BIGINT NOT NULL,
  deleted_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (owner_id, character_id)
);

CREATE INDEX IF NOT EXISTS idx_character_tombstones_delta
  ON public.character_tombstones (owner_id, revision);

ALTER TABLE public.character_tombstones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.character_tombstones FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.character_tombstones FROM authenticated;
DROP POLICY IF EXISTS "CTomb: own read" ON public.character_tombstones;
CREATE POLICY "CTomb: own read" ON public.character_tombstones
  FOR SELECT USING (owner_id = (SELECT auth.uid()));

-- Silme türünü çağıran söyler (`dmt.character_gone`, işlem-yerel); söylemezse
-- `deleted`. Sahiplik değişimi her zaman `gone`.
CREATE OR REPLACE FUNCTION public.tg_character_owner_tombstone()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_kind TEXT;
BEGIN
  IF OLD.owner_id IS NULL THEN
    RETURN NULL;
  END IF;
  IF TG_OP = 'DELETE' THEN
    v_kind := COALESCE(NULLIF(current_setting('dmt.character_gone', true), ''),
                       'deleted');
  ELSE
    v_kind := 'gone';
  END IF;
  -- Hesap siliniyor (auth.users CASCADE'i karakteri günceller): sahibin
  -- tombstone'u da gidecekti, yazılmaz.
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = OLD.owner_id) THEN
    RETURN NULL;
  END IF;
  INSERT INTO public.character_tombstones
    (owner_id, character_id, kind, revision, deleted_at)
  VALUES
    (OLD.owner_id, OLD.id, v_kind,
     public.next_character_revision(OLD.owner_id), now())
  ON CONFLICT (owner_id, character_id) DO UPDATE
    SET kind       = EXCLUDED.kind,
        revision   = EXCLUDED.revision,
        deleted_at = EXCLUDED.deleted_at;
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS trg_world_characters_owner_tomb_del ON public.world_characters;
DROP TRIGGER IF EXISTS trg_world_characters_owner_tomb_upd ON public.world_characters;
CREATE TRIGGER trg_world_characters_owner_tomb_del
  AFTER DELETE ON public.world_characters
  FOR EACH ROW EXECUTE FUNCTION public.tg_character_owner_tombstone();
CREATE TRIGGER trg_world_characters_owner_tomb_upd
  AFTER UPDATE OF owner_id ON public.world_characters
  FOR EACH ROW WHEN (OLD.owner_id IS DISTINCT FROM NEW.owner_id)
  EXECUTE FUNCTION public.tg_character_owner_tombstone();

-- 097 B'nin sahip kapsamındaki eşi: tombstone'dan eski düzenleme satırı
-- diriltmez (silinmiş karakteri de, yerele alınmışı da). `lww_ins_owner`
-- `stamp`'ten önce koşar — atlanan satır sayaç yakmaz.
CREATE OR REPLACE FUNCTION public.tg_skip_buried_character()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF NEW.owner_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.character_tombstones t
     WHERE t.owner_id     = NEW.owner_id
       AND t.character_id = NEW.id
       AND t.deleted_at   > NEW.updated_at) THEN
    RETURN NULL;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_world_characters_lww_ins_owner ON public.world_characters;
CREATE TRIGGER trg_world_characters_lww_ins_owner
  BEFORE INSERT ON public.world_characters
  FOR EACH ROW EXECUTE FUNCTION public.tg_skip_buried_character();

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM E — Dünyadan ayrılan karakter
-- ──────────────────────────────────────────────────────────────────────────
-- `world_id` değişince eski dünyanın DM cihazları satırı artık
-- `get_world_delta`'da görmez; tombstone olmadan yerel kopya dünyada kalırdı.
-- Dünyanın kendisi siliniyorsa (FK'nın SET NULL'u) tombstone yazılmaz — o
-- dünyanın tombstone'ları da CASCADE ile gidiyor.
CREATE OR REPLACE FUNCTION public.tg_character_left_world()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.worlds WHERE id = OLD.world_id) THEN
    INSERT INTO public.world_tombstones
      (world_id, table_name, row_id, owner_id, revision, deleted_at)
    VALUES
      (OLD.world_id, 'world_characters', OLD.id, OLD.owner_id,
       public.next_world_revision(OLD.world_id), now())
    ON CONFLICT (world_id, table_name, row_id) DO UPDATE
      SET revision   = EXCLUDED.revision,
          deleted_at = EXCLUDED.deleted_at,
          owner_id   = EXCLUDED.owner_id;
  END IF;
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS trg_world_characters_left_world ON public.world_characters;
CREATE TRIGGER trg_world_characters_left_world
  AFTER UPDATE OF world_id ON public.world_characters
  FOR EACH ROW
  WHEN (OLD.world_id IS NOT NULL AND OLD.world_id IS DISTINCT FROM NEW.world_id)
  EXECUTE FUNCTION public.tg_character_left_world();

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM F — get_character_delta
-- ──────────────────────────────────────────────────────────────────────────
-- Çağıranın karakterleri (dünyasız ya da bir dünyada) ve tombstone'ları,
-- `p_since`'ten sonra değişenler. Biçim `get_world_delta`'nınki; tombstone
-- ayrıca `kind` taşır. SECURITY INVOKER: RLS çağıranın kendi satırlarını
-- zaten veriyor, sorgu yine de `owner_id`'ye bakıyor.
CREATE OR REPLACE FUNCTION public.get_character_delta(
  p_since BIGINT DEFAULT 0,
  p_limit INT    DEFAULT 500
) RETURNS JSONB
LANGUAGE plpgsql STABLE
SET search_path = public
AS $$
DECLARE
  v_uid  UUID := auth.uid();
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
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object(
      'revision', p_since, 'head', p_since, 'complete', true,
      'tables', '{}'::jsonb, 'tombstones', '[]'::jsonb);
  END IF;

  SELECT COALESCE(revision, 0) INTO v_head
    FROM public.character_revisions WHERE owner_id = v_uid;
  v_head := COALESCE(v_head, 0);
  v_cut  := v_head;

  SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.owner_revision), '[]'::jsonb)
    INTO v_rows
    FROM (SELECT * FROM public.world_characters
           WHERE owner_id = v_uid AND owner_revision > p_since
           ORDER BY owner_revision LIMIT p_limit) x;
  IF jsonb_array_length(v_rows) >= p_limit THEN
    v_max := (v_rows -> (p_limit - 1) ->> 'owner_revision')::bigint;
    IF v_max < v_cut THEN v_cut := v_max; END IF;
  END IF;

  SELECT COALESCE(jsonb_agg(to_jsonb(d) ORDER BY d.revision), '[]'::jsonb)
    INTO v_tomb
    FROM (SELECT 'world_characters'::text AS table_name,
                 character_id AS row_id, kind, deleted_at, revision
            FROM public.character_tombstones
           WHERE owner_id = v_uid AND revision > p_since
           ORDER BY revision LIMIT p_limit) d;
  IF jsonb_array_length(v_tomb) >= p_limit THEN
    v_max := (v_tomb -> (p_limit - 1) ->> 'revision')::bigint;
    IF v_max < v_cut THEN v_cut := v_max; END IF;
  END IF;

  IF v_cut < v_head THEN
    v_rows := COALESCE(
      (SELECT jsonb_agg(e) FROM jsonb_array_elements(v_rows) e
        WHERE (e ->> 'owner_revision')::bigint <= v_cut), '[]'::jsonb);
    v_tomb := COALESCE(
      (SELECT jsonb_agg(e) FROM jsonb_array_elements(v_tomb) e
        WHERE (e ->> 'revision')::bigint <= v_cut), '[]'::jsonb);
  END IF;

  RETURN jsonb_build_object(
    'revision',   v_cut,
    'head',       v_head,
    'complete',   v_cut >= v_head,
    'tables',     jsonb_build_object('world_characters', v_rows),
    'tombstones', v_tomb);
END $$;

REVOKE ALL ON FUNCTION public.get_character_delta(BIGINT, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_character_delta(BIGINT, INT) TO authenticated;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM G — get_world_delta: DM bütün tombstone'ları görür
-- ──────────────────────────────────────────────────────────────────────────
-- 096'nın gövdesi, tek fark tombstone şartında. Önceki hali DM'e yalnız
-- sahipsiz (kendi) satırlarının tombstone'larını veriyordu: oyuncunun
-- karakteri silindiğinde ya da dünyadan ayrıldığında DM'in yerel kopyası
-- dünyada kalıyordu. Oyuncu yine yalnız kendisininkileri görür (RLS
-- `WTomb: scoped read` aynı kuralı uyguluyor).
CREATE OR REPLACE FUNCTION public.get_world_delta(
  p_world TEXT,
  p_since BIGINT DEFAULT 0,
  p_limit INT    DEFAULT 500
) RETURNS JSONB
LANGUAGE plpgsql STABLE
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

  -- Tombstone'lar: DM dünyanın hepsini, oyuncu DM'in satırlarını (owner_id
  -- NULL) ve kendi satırlarını görür.
  SELECT COALESCE(jsonb_agg(to_jsonb(d) ORDER BY d.revision), '[]'::jsonb)
    INTO v_tomb
    FROM (SELECT table_name, row_id, deleted_at, revision
            FROM public.world_tombstones
           WHERE world_id = p_world
             AND revision > p_since
             AND (owner_id IS NULL
                  OR owner_id = (SELECT auth.uid())
                  OR (SELECT public.is_world_dm(p_world)))
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

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM H — Dünyadan çıkarma, sahibin silmesi, yerele alma
-- ──────────────────────────────────────────────────────────────────────────
-- `remove_from_world`: sahipli karakter dünyasız kalır. Dünya bağı istemcide
-- `payload_json.worldId`'den okunuyor (C); RPC onu da boşaltmasa sahibin
-- cihazı karakteri dünyada tutar ve bir sonraki push'ta geri bağlardı.
-- Bozuk blob'a dokunulmaz.
CREATE OR REPLACE FUNCTION public.remove_from_world(p_character_id TEXT)
RETURNS TABLE (character_id TEXT, deleted BOOLEAN)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_world_id TEXT;
  v_owner    UUID;
  v_payload  TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  SELECT wc.world_id, wc.owner_id, wc.payload_json
    INTO v_world_id, v_owner, v_payload
    FROM public.world_characters wc
   WHERE wc.id = p_character_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'character not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_world_id IS NULL THEN
    RAISE EXCEPTION 'character is not in a world' USING ERRCODE = 'P0005';
  END IF;

  IF v_owner IS DISTINCT FROM auth.uid() AND NOT public.is_world_dm(v_world_id) THEN
    RAISE EXCEPTION 'not authorized' USING ERRCODE = '42501';
  END IF;

  IF v_owner IS NULL THEN
    -- Unclaimed → sil.
    DELETE FROM public.world_characters WHERE id = p_character_id;
    RETURN QUERY SELECT p_character_id, TRUE;
    RETURN;
  END IF;

  BEGIN
    v_payload := (v_payload::jsonb || '{"worldId": null}'::jsonb)::text;
  EXCEPTION WHEN others THEN
    NULL;
  END;

  -- Damga eskisinden büyük olmalı: 097'nin LWW guard'ı daha eski
  -- `updated_at`'li yazmayı sessizce atlıyor, saati ileri giden bir cihazın
  -- son düzenlemesi RPC'yi boşa düşürürdü.
  UPDATE public.world_characters
     SET world_id     = NULL,
         payload_json = v_payload,
         updated_at   = GREATEST(now(), updated_at + interval '1 millisecond')
   WHERE id = p_character_id;

  RETURN QUERY SELECT p_character_id, FALSE;
END $$;

-- Sahip kendi dünyasız satırını silebilir: çevrimdışı yapılan silme,
-- push turunun tombstone'uyla gider (`delete_character` RPC'si de duruyor).
DROP POLICY IF EXISTS "Chars: owner delete worldless" ON public.world_characters;
CREATE POLICY "Chars: owner delete worldless" ON public.world_characters
  FOR DELETE USING (world_id IS NULL AND owner_id = (SELECT auth.uid()));

-- "Yerele al": bulut kopyası kalkar, sahibin öbür cihazları `gone` görür ve
-- yerel kopyalarını tutar. Online dünyadaki karakter yerele alınamaz —
-- dünya online kaldıkça karakteri de online.
CREATE OR REPLACE FUNCTION public.unpublish_character(p_character_id TEXT)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_world_id TEXT;
  v_owner    UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  SELECT wc.world_id, wc.owner_id INTO v_world_id, v_owner
    FROM public.world_characters wc
   WHERE wc.id = p_character_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RETURN;   -- zaten bulutta değil
  END IF;
  IF v_owner IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'not the owner' USING ERRCODE = '42501';
  END IF;
  IF v_world_id IS NOT NULL THEN
    RAISE EXCEPTION 'character is in an online world' USING ERRCODE = 'P0005';
  END IF;

  PERFORM set_config('dmt.character_gone', 'gone', true);
  DELETE FROM public.world_characters WHERE id = p_character_id;
  PERFORM set_config('dmt.character_gone', '', true);
END $$;

REVOKE ALL ON FUNCTION public.unpublish_character(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.unpublish_character(TEXT) TO authenticated;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM I — Karakter medyası: üçüncü kapsam
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE public.world_media
  ADD COLUMN IF NOT EXISTS character_id TEXT
    REFERENCES public.world_characters(id) ON DELETE CASCADE;

ALTER TABLE public.world_media DROP CONSTRAINT IF EXISTS world_media_one_scope;
ALTER TABLE public.world_media ADD CONSTRAINT world_media_one_scope
  CHECK (num_nonnulls(world_id, package_id, character_id) = 1);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conrelid = 'public.world_media'::regclass
                    AND conname = 'world_media_character_sha_key') THEN
    ALTER TABLE public.world_media
      ADD CONSTRAINT world_media_character_sha_key UNIQUE (character_id, sha256);
  END IF;
END $$;

-- Key yerleşiminin tek tanımı. 100'ün dört argümanlı hali ona sarılıyor
-- (verify_100 onu çağırıyor).
CREATE OR REPLACE FUNCTION public.media_r2_key(
  _world     TEXT,
  _package   TEXT,
  _character TEXT,
  _sha       TEXT,
  _ext       TEXT
) RETURNS TEXT
LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT CASE WHEN _world   IS NOT NULL THEN 'worlds/'   || _world
              WHEN _package IS NOT NULL THEN 'packages/' || _package
              ELSE 'characters/' || _character END
         || '/' || _sha || _ext
$$;

CREATE OR REPLACE FUNCTION public.media_r2_key(
  _world   TEXT,
  _package TEXT,
  _sha     TEXT,
  _ext     TEXT
) RETURNS TEXT
LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT public.media_r2_key(_world, _package, NULL, _sha, _ext)
$$;

-- Karakter kapsamının "sahibi": karakterin sahibi ya da dünyasının DM'i
-- (sahipsiz, claim edilecek karakterin görselini DM yükler; oyuncunun
-- karakterine DM'in eklediği görsel de oyuncuya gitmeli).
CREATE OR REPLACE FUNCTION public._media_scope_owner(
  _scope TEXT,
  _id    TEXT,
  _uid   UUID
) RETURNS BOOLEAN
LANGUAGE sql STABLE
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(_id ~ '^[A-Za-z0-9_-]{1,100}$', FALSE) AND CASE _scope
    WHEN 'world'     THEN EXISTS (SELECT 1 FROM public.worlds
                                   WHERE id = _id AND owner_id = _uid)
    WHEN 'package'   THEN EXISTS (SELECT 1 FROM public.user_packages
                                   WHERE id = _id AND owner_id = _uid)
    WHEN 'character' THEN EXISTS (SELECT 1 FROM public.world_characters c
                                    LEFT JOIN public.worlds w ON w.id = c.world_id
                                   WHERE c.id = _id
                                     AND (c.owner_id = _uid OR w.owner_id = _uid))
    ELSE FALSE
  END
$$;

REVOKE ALL ON FUNCTION public._media_scope_owner(TEXT, TEXT, UUID)
  FROM PUBLIC, anon, authenticated;

-- RLS: karakterin medyasını sahibi ve dünyasının üyeleri okur; sahibi ya da
-- dünyasının sahibi siler.
DROP POLICY IF EXISTS "world_media: scope read" ON public.world_media;
CREATE POLICY "world_media: scope read" ON public.world_media
  FOR SELECT USING (
    public.is_world_member(world_id)
    OR EXISTS (SELECT 1 FROM public.user_packages p
                WHERE p.id = world_media.package_id
                  AND p.owner_id = (SELECT auth.uid()))
    OR EXISTS (SELECT 1 FROM public.world_characters c
                WHERE c.id = world_media.character_id
                  AND (c.owner_id = (SELECT auth.uid())
                       OR (c.world_id IS NOT NULL
                           AND public.is_world_member(c.world_id))))
  );

DROP POLICY IF EXISTS "world_media: scope owner delete" ON public.world_media;
CREATE POLICY "world_media: scope owner delete" ON public.world_media
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.worlds w
             WHERE w.id = world_media.world_id
               AND w.owner_id = (SELECT auth.uid()))
    OR EXISTS (SELECT 1 FROM public.user_packages p
                WHERE p.id = world_media.package_id
                  AND p.owner_id = (SELECT auth.uid()))
    OR EXISTS (SELECT 1 FROM public.world_characters c
                LEFT JOIN public.worlds w ON w.id = c.world_id
                WHERE c.id = world_media.character_id
                  AND (c.owner_id = (SELECT auth.uid())
                       OR w.owner_id = (SELECT auth.uid())))
  );

-- Kota: karakterin medyası sahibine, sahipsizse dünyasının sahibine sayılır.
CREATE OR REPLACE FUNCTION public._media_usage(_uid UUID)
RETURNS TABLE (user_used BIGINT, total_used BIGINT)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    (SELECT COALESCE(SUM(m.bytes), 0)::bigint
       FROM public.world_media m
       LEFT JOIN public.worlds w           ON w.id  = m.world_id
       LEFT JOIN public.user_packages p    ON p.id  = m.package_id
       LEFT JOIN public.world_characters c ON c.id  = m.character_id
       LEFT JOIN public.worlds cw          ON cw.id = c.world_id
      WHERE COALESCE(w.owner_id, p.owner_id, c.owner_id, cw.owner_id) = _uid),
    ((SELECT COALESCE(SUM(bytes), 0) FROM public.world_media)
     + (SELECT COALESCE(SUM(bytes), 0) FROM public.pub_assets))::bigint
$$;

-- Tahliye: key beş argümanlı yerleşimden; `characters/` öneki de canlılığa
-- bakılarak kuyruktan düşer.
CREATE OR REPLACE FUNCTION public.enqueue_world_media_evict()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  INSERT INTO public.r2_evict_queue (sha256, ext, r2_key)
    VALUES (OLD.sha256, OLD.ext,
            public.media_r2_key(OLD.world_id, OLD.package_id, OLD.character_id,
                                OLD.sha256, OLD.ext));
  RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION public.r2_evict_pop(_limit INT DEFAULT 20)
RETURNS TABLE (id BIGINT, r2_key TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH picked AS (
    SELECT q.id
      FROM public.r2_evict_queue q
     ORDER BY q.enqueued_at ASC
     LIMIT _limit
     FOR UPDATE SKIP LOCKED
  ), popped AS (
    DELETE FROM public.r2_evict_queue q
     USING picked
     WHERE q.id = picked.id
    RETURNING q.id, q.sha256, q.r2_key
  )
  SELECT p.id, p.r2_key
    FROM popped p
   WHERE CASE
           WHEN p.r2_key LIKE 'pub/%'
             THEN NOT EXISTS (SELECT 1 FROM public.pub_assets a
                               WHERE a.sha256 = p.sha256)
           WHEN p.r2_key LIKE 'worlds/%'
             THEN NOT EXISTS (SELECT 1 FROM public.world_media m
                               WHERE m.world_id = split_part(p.r2_key, '/', 2)
                                 AND m.sha256 = p.sha256)
           WHEN p.r2_key LIKE 'packages/%'
             THEN NOT EXISTS (SELECT 1 FROM public.world_media m
                               WHERE m.package_id = split_part(p.r2_key, '/', 2)
                                 AND m.sha256 = p.sha256)
           WHEN p.r2_key LIKE 'characters/%'
             THEN NOT EXISTS (SELECT 1 FROM public.world_media m
                               WHERE m.character_id = split_part(p.r2_key, '/', 2)
                                 AND m.sha256 = p.sha256)
           ELSE TRUE
         END;
END $$;

-- 100'ün rezervasyonu, üç kapsamla. Kurallar aynı.
CREATE OR REPLACE FUNCTION public.media_reserve(
  _scope TEXT,
  _id    TEXT,
  _items JSONB
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid       UUID := auth.uid();
  v_world     TEXT := CASE WHEN _scope = 'world'     THEN _id END;
  v_package   TEXT := CASE WHEN _scope = 'package'   THEN _id END;
  v_character TEXT := CASE WHEN _scope = 'character' THEN _id END;
  v_item      JSONB;
  v_sha       TEXT;
  v_ext       TEXT;
  v_kind      TEXT;
  v_mime      TEXT;
  v_bytes     BIGINT;
  v_max       BIGINT;
  v_uploaded  BOOLEAN;
  v_new       JSONB := '[]'::jsonb;   -- bulutta hiç olmayanlar
  v_new_bytes BIGINT := 0;
  v_upload    TEXT[] := '{}';
  v_too_large TEXT[] := '{}';
  v_u         RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_signed_in' USING ERRCODE = '42501';
  END IF;
  IF NOT public._media_scope_owner(_scope, _id, v_uid) THEN
    RAISE EXCEPTION 'not_scope_owner' USING ERRCODE = '42501';
  END IF;
  IF jsonb_typeof(_items) IS DISTINCT FROM 'array'
     OR jsonb_array_length(_items) > 500 THEN
    RAISE EXCEPTION 'invalid_items' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('media_reserve'));

  FOR v_item IN SELECT * FROM jsonb_array_elements(_items) LOOP
    v_sha   := lower(v_item->>'sha');
    v_ext   := lower(COALESCE(v_item->>'ext', ''));
    v_kind  := v_item->>'kind';
    v_mime  := lower(COALESCE(v_item->>'mime', ''));
    v_bytes := (v_item->>'bytes')::bigint;
    v_max   := public.world_media_max_bytes(v_kind);

    IF v_sha IS NULL OR v_sha !~ '^[0-9a-f]{64}$'
       OR v_ext !~ '^(\.[a-z0-9]{1,10})?$'
       OR v_max IS NULL
       OR v_bytes IS NULL OR v_bytes <= 0
       OR NOT (v_mime ~ '^(image|audio)/[a-z0-9.+-]+$'
               OR v_mime IN ('application/pdf', 'application/octet-stream')) THEN
      RAISE EXCEPTION 'invalid_item' USING ERRCODE = '22023',
        HINT = v_item::text;
    END IF;

    IF v_bytes > v_max THEN
      v_too_large := array_append(v_too_large, v_sha);
      CONTINUE;
    END IF;
    IF v_sha = ANY(v_upload) THEN
      CONTINUE;   -- aynı partide iki kez
    END IF;

    SELECT uploaded INTO v_uploaded FROM public.world_media
     WHERE sha256 = v_sha
       AND (world_id = v_world OR package_id = v_package
            OR character_id = v_character);
    IF FOUND THEN
      IF NOT v_uploaded THEN
        v_upload := array_append(v_upload, v_sha);
      END IF;
      CONTINUE;
    END IF;

    v_upload := array_append(v_upload, v_sha);
    v_new := v_new || jsonb_build_object('sha', v_sha, 'ext', v_ext,
               'bytes', v_bytes, 'kind', v_kind, 'mime', v_mime);
    v_new_bytes := v_new_bytes + v_bytes;
  END LOOP;

  IF v_new_bytes > 0 THEN
    SELECT * INTO v_u FROM public._media_usage(v_uid);
    IF v_u.user_used + v_new_bytes > public.world_media_user_cap_bytes() THEN
      RAISE EXCEPTION 'media_user_full' USING ERRCODE = 'P0001',
        HINT = format('used=%s new=%s cap=%s', v_u.user_used, v_new_bytes,
                      public.world_media_user_cap_bytes());
    END IF;
    IF v_u.total_used + v_new_bytes > public.media_total_cap_bytes() THEN
      RAISE EXCEPTION 'media_pool_full' USING ERRCODE = 'P0001',
        HINT = format('used=%s new=%s cap=%s', v_u.total_used, v_new_bytes,
                      public.media_total_cap_bytes());
    END IF;

    INSERT INTO public.world_media
      (world_id, package_id, character_id, sha256, ext, bytes, kind, mime)
    SELECT v_world, v_package, v_character, n->>'sha', n->>'ext',
           (n->>'bytes')::bigint, n->>'kind', n->>'mime'
      FROM jsonb_array_elements(v_new) n;
  END IF;

  RETURN jsonb_build_object('upload', to_jsonb(v_upload),
                            'too_large', to_jsonb(v_too_large));
END $$;

CREATE OR REPLACE FUNCTION public.media_confirm(
  _scope TEXT,
  _id    TEXT,
  _shas  TEXT[]
) RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_n INT;
BEGIN
  IF NOT public._media_scope_owner(_scope, _id, auth.uid()) THEN
    RAISE EXCEPTION 'not_scope_owner' USING ERRCODE = '42501';
  END IF;
  UPDATE public.world_media
     SET uploaded = TRUE
   WHERE (world_id     = CASE WHEN _scope = 'world'     THEN _id END
       OR package_id   = CASE WHEN _scope = 'package'   THEN _id END
       OR character_id = CASE WHEN _scope = 'character' THEN _id END)
     AND sha256 = ANY(_shas)
     AND NOT uploaded;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END $$;

CREATE OR REPLACE FUNCTION public.media_sign_put(
  p_user  UUID,
  p_scope TEXT,
  p_id    TEXT,
  p_shas  TEXT[]
) RETURNS TABLE (sha256 TEXT, r2_key TEXT, bytes BIGINT, mime TEXT)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT m.sha256,
         public.media_r2_key(m.world_id, m.package_id, m.character_id,
                             m.sha256, m.ext),
         m.bytes, m.mime
    FROM public.world_media m
   WHERE public._media_scope_owner(p_scope, p_id, p_user)
     AND m.sha256 = ANY(p_shas)
     AND (m.world_id     = CASE WHEN p_scope = 'world'     THEN p_id END
       OR m.package_id   = CASE WHEN p_scope = 'package'   THEN p_id END
       OR m.character_id = CASE WHEN p_scope = 'character' THEN p_id END);
$$;

-- GET: üyesi olduğu bir dünyada, sahibi olduğu bir pakette, ya da sahibi
-- olduğu / dünyasının üyesi olduğu bir karakterde yüklenmiş sha.
CREATE OR REPLACE FUNCTION public.media_sign_get(
  p_user UUID,
  p_shas TEXT[]
) RETURNS TABLE (sha256 TEXT, r2_key TEXT)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT DISTINCT ON (m.sha256) m.sha256,
         public.media_r2_key(m.world_id, m.package_id, m.character_id,
                             m.sha256, m.ext)
    FROM public.world_media m
   WHERE m.sha256 = ANY(p_shas)
     AND m.uploaded
     AND (EXISTS (SELECT 1 FROM public.world_members wm
                   WHERE wm.world_id = m.world_id AND wm.user_id = p_user)
          OR EXISTS (SELECT 1 FROM public.user_packages up
                      WHERE up.id = m.package_id AND up.owner_id = p_user)
          OR EXISTS (SELECT 1 FROM public.world_characters c
                      WHERE c.id = m.character_id
                        AND (c.owner_id = p_user
                             OR EXISTS (SELECT 1 FROM public.world_members wm
                                         WHERE wm.world_id = c.world_id
                                           AND wm.user_id = p_user))))
   ORDER BY m.sha256, m.created_at;
$$;

REVOKE ALL ON FUNCTION public.media_sign_put(UUID, TEXT, TEXT, TEXT[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.media_sign_get(UUID, TEXT[])             FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.media_sign_put(UUID, TEXT, TEXT, TEXT[]) TO service_role;
GRANT EXECUTE ON FUNCTION public.media_sign_get(UUID, TEXT[])             TO service_role;

-- ──────────────────────────────────────────────────────────────────────────
-- Realtime: sahibin sinyali
-- ──────────────────────────────────────────────────────────────────────────
-- 094'ün `world_revisions`'ı gibi: CDC değil, kullanıcı başına tek satırlık
-- uyandırma sinyali. RLS satırı yalnız sahibine gösteriyor.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND NOT EXISTS (
       SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'character_revisions') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.character_revisions;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
