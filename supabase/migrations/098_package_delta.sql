-- ============================================================================
-- 098_package_delta.sql — Faz 5c: paketin ikinci yönü (pull)
-- ============================================================================
-- Bkz. docs/online-sync-redesign.md §4.8.2 (Faz 5c). Dünyanın 094/096/097'de
-- kurduğu iskeletin paket kapsamlı eşi; kapsam kolonu `package_id`, sayaç
-- paketin kendi satırında (`user_packages.revision`, 094 E.7).
--
-- Ne yapar:
--   A) `user_package_tombstones` + kart/şema silmesinde tombstone trigger'ı.
--      Bugüne kadar paket çocuklarının silmesi bulutta iz bırakmıyordu —
--      push satırı siliyordu ama öbür cihaz bunu öğrenemezdi, kart onda
--      sonsuza kadar kalırdı.
--   B) Tombstone'dan eski bir düzenleme silinmiş kartı diriltmesin (097 B'nin
--      paket eşi).
--   C) `get_package_delta(package, since, limit)` — `get_world_delta`'nın eşi.
--
-- Ne YAPMAZ — bilinçli:
--   * Paketin KENDİSİNİN silinmesi için tombstone yok. Paket buluttan
--     silinince (yerel silme ya da "Yerele al") satırı ve çocukları CASCADE
--     ile gider, tombstone'ları da. Öbür cihaz bunu push'ta öğreniyor:
--     ilk yayından sonra istemci paketin satırını upsert değil UPDATE ile
--     yazıyor, satır yoksa yerel paketi offline'a düşürüyor (diriltmiyor).
--   * Realtime yok: paketin canlı sinyali yok, uzlaştırma anı paketin
--     açılışı.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run.
-- Doğrulama: scripts/verify_098.sql
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM A — Paket tombstone'u
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_package_tombstones (
  package_id  TEXT        NOT NULL REFERENCES public.user_packages(id) ON DELETE CASCADE,
  table_name  TEXT        NOT NULL,
  row_id      TEXT        NOT NULL,
  owner_id    UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  revision    BIGINT      NOT NULL,
  deleted_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (package_id, table_name, row_id)
);
CREATE INDEX IF NOT EXISTS idx_user_package_tombstones_delta
  ON public.user_package_tombstones (package_id, revision);

COMMENT ON TABLE public.user_package_tombstones IS
  'Silinen paket kartları/şemaları. get_package_delta aynı pencereden okur. '
  'Paket silinince CASCADE ile düşer — paketin kendisinin silinmesini istemci '
  'push''ta öğreniyor (098 başlığı).';

ALTER TABLE public.user_package_tombstones ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "UPTomb: owner read" ON public.user_package_tombstones;
CREATE POLICY "UPTomb: owner read"
  ON public.user_package_tombstones FOR SELECT
  USING (owner_id = (SELECT auth.uid()));
-- Yazma policy'si yok: tek yazar aşağıdaki SECURITY DEFINER trigger.
REVOKE ALL ON public.user_package_tombstones FROM anon;
GRANT SELECT ON public.user_package_tombstones TO authenticated;

CREATE OR REPLACE FUNCTION public.tg_package_tombstone()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  -- Paketin kendisi siliniyorsa (CASCADE) tombstone anlamsız ve FK'sı tutmaz.
  IF NOT EXISTS (SELECT 1 FROM public.user_packages WHERE id = OLD.package_id) THEN
    RETURN OLD;
  END IF;
  INSERT INTO public.user_package_tombstones (
    package_id, table_name, row_id, owner_id, revision, deleted_at)
  VALUES (
    OLD.package_id, TG_TABLE_NAME, OLD.id, OLD.owner_id,
    public.next_package_revision(OLD.package_id), now())
  ON CONFLICT (package_id, table_name, row_id) DO UPDATE
    SET revision   = EXCLUDED.revision,
        deleted_at = EXCLUDED.deleted_at;
  RETURN OLD;
END $$;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM B — Silinmiş kart eski düzenlemeyle dirilmesin
-- ──────────────────────────────────────────────────────────────────────────
-- Ad `lww_ins`: 097'deki gibi `stamp_rev_ins`'ten önce koşar, atlanan satır
-- revizyon yakmaz.
CREATE OR REPLACE FUNCTION public.tg_skip_buried_package_insert()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.user_package_tombstones t
     WHERE t.package_id = NEW.package_id
       AND t.table_name = TG_TABLE_NAME
       AND t.row_id     = NEW.id
       AND t.deleted_at > NEW.updated_at) THEN
    RETURN NULL;
  END IF;
  RETURN NEW;
END $$;

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['user_package_entities', 'user_package_schemas'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_tombstone ON public.%I', t, t);
    EXECUTE format(
      'CREATE TRIGGER trg_%s_tombstone AFTER DELETE ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION public.tg_package_tombstone()', t, t);
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_lww_ins ON public.%I', t, t);
    EXECUTE format(
      'CREATE TRIGGER trg_%s_lww_ins BEFORE INSERT ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION public.tg_skip_buried_package_insert()',
      t, t);
  END LOOP;
END $$;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM C — get_package_delta
-- ──────────────────────────────────────────────────────────────────────────
-- `get_world_delta` (096) ile aynı sözleşme ve aynı kırpma. Tek fark paketin
-- kendi satırı: sayacı o taşıyor (her çocuk yazması onu da artırıyor), yani
-- revizyonu hep başa eşit ve yalnız SON sayfada döner. İstemci o satırı en
-- son yazdığı için yarım inen paket hub listesinde hiç görünmez.
--
-- SECURITY INVOKER: RLS sahibi dışında herkese boş döndürüyor.
CREATE OR REPLACE FUNCTION public.get_package_delta(
  p_package TEXT,
  p_since   BIGINT DEFAULT 0,
  p_limit   INT    DEFAULT 500
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_tables CONSTANT TEXT[] := ARRAY['user_package_schemas', 'user_package_entities'];
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

  SELECT revision INTO v_head FROM public.user_packages WHERE id = p_package;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'revision', p_since, 'head', p_since, 'complete', true,
      'tables', '{}'::jsonb, 'tombstones', '[]'::jsonb);
  END IF;
  v_cut := v_head;

  FOREACH t IN ARRAY v_tables LOOP
    EXECUTE format(
      'SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.revision), ''[]''::jsonb) '
      'FROM (SELECT * FROM public.%I '
      '       WHERE package_id = $1 AND revision > $2 '
      '       ORDER BY revision LIMIT $3) x', t)
      INTO v_rows USING p_package, p_since, p_limit;
    v_raw := v_raw || jsonb_build_object(t, v_rows);
    IF jsonb_array_length(v_rows) >= p_limit THEN
      v_max := (v_rows -> (p_limit - 1) ->> 'revision')::bigint;
      IF v_max < v_cut THEN v_cut := v_max; END IF;
    END IF;
  END LOOP;

  SELECT COALESCE(jsonb_agg(to_jsonb(d) ORDER BY d.revision), '[]'::jsonb)
    INTO v_tomb
    FROM (SELECT table_name, row_id, deleted_at, revision
            FROM public.user_package_tombstones
           WHERE package_id = p_package AND revision > p_since
           ORDER BY revision LIMIT p_limit) d;
  IF jsonb_array_length(v_tomb) >= p_limit THEN
    v_max := (v_tomb -> (p_limit - 1) ->> 'revision')::bigint;
    IF v_max < v_cut THEN v_cut := v_max; END IF;
  END IF;

  IF v_cut >= v_head THEN
    v_out := v_raw;
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

  -- Paketin kendi satırı: revizyonu başa eşit, dolayısıyla yalnız tam sayfada.
  v_out := v_out || jsonb_build_object('user_packages', COALESCE(
    (SELECT jsonb_agg(to_jsonb(p)) FROM public.user_packages p
      WHERE p.id = p_package AND p.revision > p_since AND p.revision <= v_cut),
    '[]'::jsonb));

  RETURN jsonb_build_object(
    'revision',   v_cut,
    'head',       v_head,
    'complete',   v_cut >= v_head,
    'tables',     v_out,
    'tombstones', v_tomb);
END $$;

COMMENT ON FUNCTION public.get_package_delta(TEXT, BIGINT, INT) IS
  'Paketin `since` revizyonundan sonraki değişiklikleri tek pakette döner — '
  'get_world_delta''nın eşi. SECURITY INVOKER; RLS sahibinden başkasına boş '
  'döndürür. `complete` false ise istemci dönen `revision` ile tekrar çağırır.';

REVOKE ALL ON FUNCTION public.get_package_delta(TEXT, BIGINT, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_package_delta(TEXT, BIGINT, INT)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
