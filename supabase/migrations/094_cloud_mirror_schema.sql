-- ============================================================================
-- 094_cloud_mirror_schema.sql — Faz 3: bulut şeması + RLS
-- ============================================================================
-- Bkz. docs/online-sync-redesign.md §2.2–§2.6, §4.4 (Faz 3).
--
-- Ne yapar:
--   077'nin düşürdüğü altı ayna tablosunu geri getirir, hiç var olmamış beş
--   tabloyu (savaş, pinler, kurulu paketler) ekler, online paketler için üç
--   tablo açar ve senkronun altyapısını kurar: `world_revisions` (uyandırma
--   sinyali), `world_tombstones` (silme yayılımı), `world_member_state`
--   (oyuncunun kendi durumu).
--
--   Ayrıca oyuncunun tek okuma kapısı olan `get_shared_entities()` RPC'sini
--   ve onun SQL tarafındaki redaksiyonunu tanımlar (§2.6).
--
-- Ne YAPMAZ — bilinçli:
--   * `entity_shares.payload_json` DÜŞMEZ. §2.5 onu kaldırıyor ama yerine
--     geçen şey (istemcinin RPC'den çekmesi) Faz 5.5'te. Şimdi düşürmek
--     bugün çalışan paylaşım akışını iki faz boyunca kırardı (§3.3).
--   * Realtime publication'dan hiçbir tablo ÇIKMAZ, yalnızca
--     `world_revisions` eklenir. Budama da Faz 5.5'te, istemci sinyale
--     geçtiğinde.
--   * `trg_chars_bump_updated` (026) duruyor. §2.8 "updated_at'i sunucu
--     ezmesin" kuralı push yazılırken, Faz 4'te uygulanır; şimdi düşürmek
--     yaşayan istemcinin karakter zaman damgasını dondururdu.
--   * İstemci bu şemayı KULLANMAZ. Faz 3'ün çıkış kriteri "RLS testleri
--     yeşil, istemci hâlâ kullanmıyor".
--
-- Veri göçü yok: 077'nin düşürdüğü tablolar boş geri geliyor, kullanıcı yok
-- (§3.1).
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run.
-- Doğrulama: scripts/verify_094.sql
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM A — Senkron altyapısı
-- ──────────────────────────────────────────────────────────────────────────

-- A.1 world_revisions — senkronun kalbi (§2.3).
-- Realtime'a bağlanan TEK tablo. Dünyadaki her satır yazması bu sayacı
-- artırır; istemci "dünya X revizyon 47'de" sinyalini alır ve tek RPC ile
-- yalnızca 47'den sonrasını çeker. 26 tabloya CDC aboneliğinin alternatifi.
CREATE TABLE IF NOT EXISTS public.world_revisions (
  world_id    TEXT PRIMARY KEY REFERENCES public.worlds(id) ON DELETE CASCADE,
  revision    BIGINT      NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by  UUID        REFERENCES auth.users(id) ON DELETE SET NULL
);

COMMENT ON TABLE public.world_revisions IS
  'Dünya başına monoton revizyon sayacı. Realtime yayınındaki tek senkron '
  'tablosu — istemci bunu dinler, içeriği get_world_delta/get_shared_entities '
  'ile çeker. updated_by echo bastırma içindir.';

-- A.2 world_tombstones — silme yayılımı (§2.4).
-- Tombstone olmazsa bir cihazda silinen satırı delta geri getirir (LAN
-- sync'in kabul edilmiş açığıydı). Sonradan eklemek acı, ilk migration'da.
-- owner_id: oyuncunun kendi satırı (mind map, member_state) silindiğinde
-- dolu; DM'in satırlarında NULL.
CREATE TABLE IF NOT EXISTS public.world_tombstones (
  world_id    TEXT        NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  table_name  TEXT        NOT NULL,
  row_id      TEXT        NOT NULL,
  owner_id    UUID,
  revision    BIGINT      NOT NULL,
  deleted_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (world_id, table_name, row_id)
);
CREATE INDEX IF NOT EXISTS idx_world_tombstones_delta
  ON public.world_tombstones (world_id, revision);

COMMENT ON TABLE public.world_tombstones IS
  'Silinen ayna satırları. Delta çekilirken revision > since olanlar okunur '
  've yerelde silinir. Tombstone zamanı ile düzenleme zamanı karşılaştırılır '
  '(§2.8) — yoksa çevrimdışı cihaz silinmiş kartı diriltir. Dünya silinince '
  'CASCADE ile düşer; kalanlar süpürülür (öneri: 90 gün).';

-- A.3 world_member_state — oyuncunun kendi durumu (§2.9).
-- Notlar, kurulu paketler, arayüz durumu. DM bile göremez.
CREATE TABLE IF NOT EXISTS public.world_member_state (
  world_id    TEXT        NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  state_json  JSONB       NOT NULL DEFAULT '{}'::jsonb,
  revision    BIGINT      NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (world_id, user_id)
);

COMMENT ON TABLE public.world_member_state IS
  'Oyuncunun o dünyadaki kişisel durumu: notlar, kurulu paketler, arayüz. '
  'LAN sync bunları `extras` içinde taşıyordu. RLS tek satır: user_id = '
  'auth.uid(); DM dahil kimse başkasınınkini göremez.';

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM B — 077'den geri gelen altı
-- ──────────────────────────────────────────────────────────────────────────
-- Şekil 026/042'den kopya; üzerine `revision` (delta anahtarı) eklendi.
-- `updated_at` artık İSTEMCİNİN yazdığı düzenleme zamanıdır, sunucu now()'ı
-- değil (§2.8) — bu yüzden bu tablolara tg_bump_updated_at BAĞLANMAZ.

-- B.1 world_entities — DM'in kartları. Oyuncu bu tabloya HİÇ erişmez.
CREATE TABLE IF NOT EXISTS public.world_entities (
  id                TEXT PRIMARY KEY,
  world_id          TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  category_slug     TEXT NOT NULL,
  name              TEXT NOT NULL,
  source            TEXT NOT NULL DEFAULT '',
  description       TEXT NOT NULL DEFAULT '',
  image_path        TEXT NOT NULL DEFAULT '',
  images_json       TEXT NOT NULL DEFAULT '[]',
  tags_json         TEXT NOT NULL DEFAULT '[]',
  dm_notes          TEXT NOT NULL DEFAULT '',
  pdfs_json         TEXT NOT NULL DEFAULT '[]',
  location_id       TEXT,
  fields_json       TEXT NOT NULL DEFAULT '{}',
  package_id        TEXT,
  package_entity_id TEXT,
  linked            BOOLEAN NOT NULL DEFAULT false,
  dm_only_keys      TEXT[],
  revision          BIGINT      NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_world_entities_world ON public.world_entities (world_id);
CREATE INDEX IF NOT EXISTS idx_world_entities_world_category
  ON public.world_entities (world_id, category_slug);
CREATE INDEX IF NOT EXISTS idx_world_entities_delta
  ON public.world_entities (world_id, revision);

COMMENT ON COLUMN public.world_entities.dm_only_keys IS
  'fields_json''dan oyuncuya giderken silinecek anahtarlar. Kararı Dart '
  'verir (şema yorumlayıcısı orada), uygulamayı get_shared_entities''teki '
  'jsonb çıkarma yapar (§2.6). NULL = "bilinmiyor" — kart oyuncuya HİÇ '
  'döndürülmez; "sır yok" anlamına GELMEZ.';

COMMENT ON COLUMN public.world_entities.updated_at IS
  'Düzenlemenin İSTEMCİDEKİ zamanı. Sunucu ezmez (§2.8): çevrimdışı kuyruk '
  'geç geldiğinde varış zamanına bakılırsa yeni veri eziliyor.';

-- B.2 world_settings / B.3 world_map_data — 1:1.
CREATE TABLE IF NOT EXISTS public.world_settings (
  world_id      TEXT PRIMARY KEY REFERENCES public.worlds(id) ON DELETE CASCADE,
  settings_json TEXT        NOT NULL DEFAULT '{}',
  revision      BIGINT      NOT NULL DEFAULT 0,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.world_map_data (
  world_id    TEXT PRIMARY KEY REFERENCES public.worlds(id) ON DELETE CASCADE,
  data_json   TEXT        NOT NULL DEFAULT '{}',
  revision    BIGINT      NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- B.4 world_sessions — 1:N.
CREATE TABLE IF NOT EXISTS public.world_sessions (
  id          TEXT PRIMARY KEY,
  world_id    TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  name        TEXT NOT NULL DEFAULT '',
  data_json   TEXT NOT NULL DEFAULT '{}',
  is_active   BOOLEAN NOT NULL DEFAULT false,
  sort_order  INT NOT NULL DEFAULT 0,
  revision    BIGINT      NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_world_sessions_world ON public.world_sessions (world_id);
CREATE INDEX IF NOT EXISTS idx_world_sessions_delta
  ON public.world_sessions (world_id, revision);

-- B.5/B.6 mind map — tek şema, `owner_id` sahibi ayırır (§2.9).
-- NULL = DM'in haritası, dolu = o oyuncunun. 026'nın `map_id = 'player_<uid>'`
-- konvansiyonu yerine geçer: string'e gömülü kimlik yerine kolon.
CREATE TABLE IF NOT EXISTS public.world_mind_map_nodes (
  id          TEXT PRIMARY KEY,
  world_id    TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  map_id      TEXT NOT NULL,
  owner_id    UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  label       TEXT NOT NULL DEFAULT '',
  node_type   TEXT NOT NULL DEFAULT 'note',
  x           DOUBLE PRECISION NOT NULL DEFAULT 0,
  y           DOUBLE PRECISION NOT NULL DEFAULT 0,
  width       DOUBLE PRECISION NOT NULL DEFAULT 150,
  height      DOUBLE PRECISION NOT NULL DEFAULT 80,
  entity_id   TEXT,
  image_url   TEXT,
  content     TEXT NOT NULL DEFAULT '',
  style_json  TEXT NOT NULL DEFAULT '{}',
  color       TEXT NOT NULL DEFAULT '',
  revision    BIGINT      NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_mind_map_nodes_world_map
  ON public.world_mind_map_nodes (world_id, map_id);
CREATE INDEX IF NOT EXISTS idx_mind_map_nodes_delta
  ON public.world_mind_map_nodes (world_id, revision);

CREATE TABLE IF NOT EXISTS public.world_mind_map_edges (
  id          TEXT PRIMARY KEY,
  world_id    TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  map_id      TEXT NOT NULL,
  owner_id    UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  source_id   TEXT NOT NULL,
  target_id   TEXT NOT NULL,
  label       TEXT NOT NULL DEFAULT '',
  style_json  TEXT NOT NULL DEFAULT '{}',
  revision    BIGINT      NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_mind_map_edges_world_map
  ON public.world_mind_map_edges (world_id, map_id);
CREATE INDEX IF NOT EXISTS idx_mind_map_edges_delta
  ON public.world_mind_map_edges (world_id, revision);

COMMENT ON COLUMN public.world_mind_map_nodes.owner_id IS
  'NULL = DM''in haritası, dolu = o oyuncunun. Tek şema, tek applier; '
  'yalnızca sahibi değişir (§2.9).';

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM C — Hiç var olmamış beş (savaş, pinler, kurulu paketler)
-- ──────────────────────────────────────────────────────────────────────────
-- Eski "tam ayna" bunları içermiyordu. "Savaş yarıda kaldığı yerde başka
-- cihazda devam eder" vaadi (§1.3) bu tablolarla çalışır.
--
-- Hepsinde `world_id` var — yerelde combatant encounter'a asılıdır ama
-- bulutta RLS ve revizyon trigger'ı JOIN'siz bir dünya anahtarı ister.

CREATE TABLE IF NOT EXISTS public.world_encounters (
  id                         TEXT PRIMARY KEY,
  world_id                   TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  session_id                 TEXT NOT NULL,
  name                       TEXT NOT NULL,
  map_path                   TEXT,
  token_size                 INT  NOT NULL DEFAULT 40,
  grid_size                  INT  NOT NULL DEFAULT 50,
  grid_visible               BOOLEAN NOT NULL DEFAULT true,
  grid_snap                  BOOLEAN NOT NULL DEFAULT true,
  feet_per_cell              INT  NOT NULL DEFAULT 5,
  fog_data                   TEXT,
  annotation_data            TEXT,
  encounter_layout_id        TEXT,
  turn_index                 INT  NOT NULL DEFAULT -1,
  round                      INT  NOT NULL DEFAULT 1,
  token_positions_json       TEXT NOT NULL DEFAULT '{}',
  token_size_multipliers_json TEXT NOT NULL DEFAULT '{}',
  sort_order                 INT  NOT NULL DEFAULT 0,
  revision                   BIGINT      NOT NULL DEFAULT 0,
  created_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                 TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_world_encounters_delta
  ON public.world_encounters (world_id, revision);
CREATE INDEX IF NOT EXISTS idx_world_encounters_session
  ON public.world_encounters (world_id, session_id);

COMMENT ON COLUMN public.world_encounters.fog_data IS
  'Fog maskesi (base64). §"Doğrulanmamış tek veri": gerçek boyutu Faz 7''de '
  'ölçülecek — kota sayıları buna göre ayarlanır.';

-- Savaşçı: HP/init tek tek değiştiği için satır bazlı. Durum etkileri
-- (`conditions_json`) SATIR DEĞİL kolon — yerelde autoincrement int PK'lı bir
-- leaf tablo ve o id cihazlar arası taşınamaz. Hiçbir zaman combatant'ından
-- ayrı okunmuyorlar; JSON olarak taşımak bir tabloyu, bir trigger'ı, bir
-- policy'yi ve id üretme problemini birden siliyor.
CREATE TABLE IF NOT EXISTS public.world_combatants (
  id               TEXT PRIMARY KEY,
  world_id         TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  encounter_id     TEXT NOT NULL REFERENCES public.world_encounters(id) ON DELETE CASCADE,
  entity_id        TEXT,
  name             TEXT NOT NULL,
  init             INT  NOT NULL DEFAULT 0,
  ac               INT  NOT NULL DEFAULT 10,
  hp               INT  NOT NULL DEFAULT 10,
  max_hp           INT  NOT NULL DEFAULT 10,
  token_id         TEXT,
  sort_order       INT  NOT NULL DEFAULT 0,
  conditions_json  TEXT NOT NULL DEFAULT '[]',
  revision         BIGINT      NOT NULL DEFAULT 0,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_world_combatants_delta
  ON public.world_combatants (world_id, revision);
CREATE INDEX IF NOT EXISTS idx_world_combatants_encounter
  ON public.world_combatants (encounter_id);

COMMENT ON COLUMN public.world_combatants.conditions_json IS
  'Durum etkileri dizisi: [{name, duration, initial_duration, entity_id}]. '
  'Yerel combat_conditions tablosunun karşılığı — ayrı tablo değil, çünkü '
  'yerel PK autoincrement int ve cihazlar arası taşınamaz (§4.5).';

CREATE TABLE IF NOT EXISTS public.world_map_pins (
  id          TEXT PRIMARY KEY,
  world_id    TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  x           DOUBLE PRECISION NOT NULL,
  y           DOUBLE PRECISION NOT NULL,
  label       TEXT NOT NULL DEFAULT '',
  pin_type    TEXT NOT NULL DEFAULT 'default',
  entity_id   TEXT,
  note        TEXT NOT NULL DEFAULT '',
  color       TEXT NOT NULL DEFAULT '',
  style_json  TEXT NOT NULL DEFAULT '{}',
  revision    BIGINT      NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_world_map_pins_delta
  ON public.world_map_pins (world_id, revision);

CREATE TABLE IF NOT EXISTS public.world_timeline_pins (
  id               TEXT PRIMARY KEY,
  world_id         TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  x                DOUBLE PRECISION NOT NULL,
  y                DOUBLE PRECISION NOT NULL,
  day              INT  NOT NULL DEFAULT 0,
  note             TEXT NOT NULL DEFAULT '',
  entity_ids_json  TEXT NOT NULL DEFAULT '[]',
  session_id       TEXT,
  parent_ids_json  TEXT NOT NULL DEFAULT '[]',
  color            TEXT NOT NULL DEFAULT '',
  revision         BIGINT      NOT NULL DEFAULT 0,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_world_timeline_pins_delta
  ON public.world_timeline_pins (world_id, revision);

CREATE TABLE IF NOT EXISTS public.world_installed_packages (
  world_id         TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  package_id       TEXT NOT NULL,
  package_name     TEXT NOT NULL DEFAULT '',
  package_version  TEXT NOT NULL DEFAULT '',
  installed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_synced_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  revision         BIGINT      NOT NULL DEFAULT 0,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (world_id, package_id)
);
CREATE INDEX IF NOT EXISTS idx_world_installed_packages_delta
  ON public.world_installed_packages (world_id, revision);

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM D — Online paketler (§2.2)
-- ──────────────────────────────────────────────────────────────────────────
-- 077'nin düşürdüğü personal_packages/_entities'in yerine, yereldeki üç
-- tablonun (packages / package_entities / package_schemas) karşılığı.
-- Dünya değil KULLANICI kapsamlı: revizyon sayacı paketin kendi satırında.
-- `owner_id` çocuklarda da tutulur — RLS tek kolon testi olsun (JOIN'siz).

CREATE TABLE IF NOT EXISTS public.user_packages (
  id                TEXT PRIMARY KEY,
  owner_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name              TEXT NOT NULL,
  state_json        TEXT NOT NULL DEFAULT '{}',
  revision          BIGINT      NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_user_packages_owner ON public.user_packages (owner_id);

CREATE TABLE IF NOT EXISTS public.user_package_entities (
  id             TEXT PRIMARY KEY,
  package_id     TEXT NOT NULL REFERENCES public.user_packages(id) ON DELETE CASCADE,
  owner_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category_slug  TEXT NOT NULL,
  name           TEXT NOT NULL,
  source         TEXT NOT NULL DEFAULT '',
  description    TEXT NOT NULL DEFAULT '',
  image_path     TEXT NOT NULL DEFAULT '',
  images_json    TEXT NOT NULL DEFAULT '[]',
  tags_json      TEXT NOT NULL DEFAULT '[]',
  dm_notes       TEXT NOT NULL DEFAULT '',
  pdfs_json      TEXT NOT NULL DEFAULT '[]',
  location_id    TEXT,
  fields_json    TEXT NOT NULL DEFAULT '{}',
  revision       BIGINT      NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_user_package_entities_pkg
  ON public.user_package_entities (package_id, revision);

CREATE TABLE IF NOT EXISTS public.user_package_schemas (
  id                      TEXT PRIMARY KEY,
  package_id              TEXT NOT NULL REFERENCES public.user_packages(id) ON DELETE CASCADE,
  owner_id                UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name                    TEXT NOT NULL DEFAULT '',
  version                 TEXT NOT NULL DEFAULT '1.0',
  base_system             TEXT,
  description             TEXT NOT NULL DEFAULT '',
  categories_json         TEXT NOT NULL DEFAULT '[]',
  encounter_config_json   TEXT NOT NULL DEFAULT '{}',
  encounter_layouts_json  TEXT NOT NULL DEFAULT '[]',
  metadata_json           TEXT NOT NULL DEFAULT '{}',
  template_id             TEXT,
  template_hash           TEXT,
  template_original_hash  TEXT,
  revision                BIGINT      NOT NULL DEFAULT 0,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_user_package_schemas_pkg
  ON public.user_package_schemas (package_id, revision);

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM E — Revizyon + tombstone trigger'ları (§2.3, §2.4)
-- ──────────────────────────────────────────────────────────────────────────

-- E.1 Sayacı bir artırır ve yeni değeri döner. Tek yazar burasıdır.
CREATE OR REPLACE FUNCTION public.next_world_revision(p_world TEXT)
RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE v_rev BIGINT;
BEGIN
  INSERT INTO public.world_revisions AS wr (world_id, revision, updated_at, updated_by)
  VALUES (p_world, 1, now(), auth.uid())
  ON CONFLICT (world_id) DO UPDATE
    SET revision   = wr.revision + 1,
        updated_at = now(),
        updated_by = auth.uid()
  RETURNING wr.revision INTO v_rev;
  RETURN v_rev;
END $$;

-- E.2 Yazmada satırı damgala. `updated_at`'E DOKUNMAZ — o istemcinin
-- düzenleme zamanı (§2.8).
CREATE OR REPLACE FUNCTION public.tg_stamp_world_revision()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.revision := public.next_world_revision(NEW.world_id);
  RETURN NEW;
END $$;

-- E.3 Silmede tombstone yaz + sayacı artır.
-- TG_ARGV[0] = satırın kimlik kolonu (PK'sı world_id olan 1:1 tablolarda
-- 'world_id', bileşik PK'lılarda ikinci kolon).
--
-- 050'nin tuzağı burada YOK: o hata child trigger'ının `worlds` satırının
-- KENDİSİNİ update etmesindendi. Biz ayrı tablolara yazıyoruz. Yine de dünya
-- CASCADE'i sırasında boşuna satır üretmemek için erken çıkış var.
CREATE OR REPLACE FUNCTION public.tg_world_tombstone()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_old JSONB := to_jsonb(OLD);
  v_wid TEXT  := v_old ->> 'world_id';
BEGIN
  IF v_wid IS NULL THEN
    RETURN OLD;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.worlds WHERE id = v_wid) THEN
    RETURN OLD;  -- dünya gitti; tombstone da CASCADE ile düşerdi
  END IF;

  INSERT INTO public.world_tombstones (
    world_id, table_name, row_id, owner_id, revision, deleted_at)
  VALUES (
    v_wid,
    TG_TABLE_NAME,
    v_old ->> TG_ARGV[0],
    COALESCE(v_old ->> 'owner_id', v_old ->> 'user_id')::uuid,
    public.next_world_revision(v_wid),
    now())
  ON CONFLICT (world_id, table_name, row_id) DO UPDATE
    SET revision   = EXCLUDED.revision,
        deleted_at = EXCLUDED.deleted_at,
        owner_id   = EXCLUDED.owner_id;

  RETURN OLD;
END $$;

-- E.4 Gövdesi aynalanmayan ama "değişti" sinyali gereken tablolar için
-- (entity_shares: paylaş/geri çek oyuncunun görebildiğini değiştirir).
CREATE OR REPLACE FUNCTION public.tg_bump_world_revision_only()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_wid TEXT;
BEGIN
  IF TG_OP = 'DELETE' THEN v_wid := OLD.world_id; ELSE v_wid := NEW.world_id; END IF;
  IF v_wid IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.worlds WHERE id = v_wid) THEN
    PERFORM public.next_world_revision(v_wid);
  END IF;
  RETURN NULL;  -- AFTER trigger
END $$;

-- E.5 world_characters — 026'dan beri var, ayna ailesine katılıyor.
-- `trg_chars_bump_updated` BİLEREK duruyor (bkz. başlık).
ALTER TABLE public.world_characters
  ADD COLUMN IF NOT EXISTS revision BIGINT NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_world_characters_delta
  ON public.world_characters (world_id, revision);

-- E.6 Trigger'ları bağla.
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('world_entities',           'id'),
      ('world_settings',           'world_id'),
      ('world_map_data',           'world_id'),
      ('world_sessions',           'id'),
      ('world_mind_map_nodes',     'id'),
      ('world_mind_map_edges',     'id'),
      ('world_encounters',         'id'),
      ('world_combatants',         'id'),
      ('world_map_pins',           'id'),
      ('world_timeline_pins',      'id'),
      ('world_installed_packages', 'package_id'),
      ('world_member_state',       'user_id'),
      ('world_characters',         'id')
    ) AS t(tbl, key_col)
  LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_%s_stamp_rev ON public.%I', r.tbl, r.tbl);
    EXECUTE format(
      'CREATE TRIGGER trg_%s_stamp_rev BEFORE INSERT OR UPDATE ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION public.tg_stamp_world_revision()',
      r.tbl, r.tbl);

    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_%s_tombstone ON public.%I', r.tbl, r.tbl);
    EXECUTE format(
      'CREATE TRIGGER trg_%s_tombstone AFTER DELETE ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION public.tg_world_tombstone(%L)',
      r.tbl, r.tbl, r.key_col);
  END LOOP;
END $$;

DROP TRIGGER IF EXISTS trg_entity_shares_bump_rev ON public.entity_shares;
CREATE TRIGGER trg_entity_shares_bump_rev
  AFTER INSERT OR UPDATE OR DELETE ON public.entity_shares
  FOR EACH ROW EXECUTE FUNCTION public.tg_bump_world_revision_only();

-- E.7 Paket sayacı — dünya değil paket kapsamlı, aynı mantık.
CREATE OR REPLACE FUNCTION public.next_package_revision(p_package TEXT)
RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE v_rev BIGINT;
BEGIN
  UPDATE public.user_packages
     SET revision = revision + 1
   WHERE id = p_package
  RETURNING revision INTO v_rev;
  RETURN COALESCE(v_rev, 0);
END $$;

CREATE OR REPLACE FUNCTION public.tg_stamp_package_revision()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_TABLE_NAME = 'user_packages' THEN
    NEW.revision := COALESCE(OLD.revision, 0) + 1;
  ELSE
    NEW.revision := public.next_package_revision(NEW.package_id);
  END IF;
  RETURN NEW;
END $$;

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'user_packages', 'user_package_entities', 'user_package_schemas'
  ] LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_%s_stamp_rev ON public.%I', t, t);
    EXECUTE format(
      'CREATE TRIGGER trg_%s_stamp_rev BEFORE INSERT OR UPDATE ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION public.tg_stamp_package_revision()', t, t);
  END LOOP;
END $$;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM F — RLS
-- ──────────────────────────────────────────────────────────────────────────
-- Model (§2.5 "tek kapı"):
--   DM       → dünyasının ayna tablolarına tam okuma/yazma
--   Oyuncu   → world_entities dahil ayna tablolarına HİÇ erişim yok;
--              izinli kartlara yalnızca get_shared_entities() üzerinden
--   Oyuncu   → kendi mind map'i (owner_id), kendi member_state'i
--   Herkes   → world_revisions (sadece sayı; içerik taşımaz)
--
-- auth.uid() çağrıları (SELECT ...) içinde — 075'in InitPlan kuralı.

ALTER TABLE public.world_revisions          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_tombstones         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_member_state       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_entities           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_settings           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_map_data           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_sessions           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_mind_map_nodes     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_mind_map_edges     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_encounters         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_combatants         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_map_pins           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_timeline_pins      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_installed_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_packages            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_package_entities    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_package_schemas     ENABLE ROW LEVEL SECURITY;

-- F.1 world_revisions — üye okur, kimse yazmaz (sayacı yalnızca
-- next_world_revision SECURITY DEFINER olarak artırır).
DROP POLICY IF EXISTS "WRev: member read" ON public.world_revisions;
CREATE POLICY "WRev: member read"
  ON public.world_revisions FOR SELECT
  USING (public.is_world_member(world_id));

-- F.2 world_tombstones — DM hepsini, oyuncu yalnızca kendi satırlarınınkini.
-- (DM'in sildiği kart id'leri oyuncuya sızmasın.)
DROP POLICY IF EXISTS "WTomb: scoped read" ON public.world_tombstones;
CREATE POLICY "WTomb: scoped read"
  ON public.world_tombstones FOR SELECT
  USING (
    public.is_world_dm(world_id)
    OR (owner_id IS NOT NULL AND owner_id = (SELECT auth.uid()))
  );

-- F.3 world_member_state — yalnızca sahibi. DM bile göremez.
DROP POLICY IF EXISTS "WMS: self all" ON public.world_member_state;
CREATE POLICY "WMS: self all"
  ON public.world_member_state FOR ALL
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()) AND public.is_world_member(world_id));

-- F.4 DM-only ayna tabloları. Oyuncu politikası YOK = satır görünmez.
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'world_entities', 'world_settings', 'world_map_data', 'world_sessions',
    'world_encounters', 'world_combatants', 'world_map_pins',
    'world_timeline_pins', 'world_installed_packages'
  ] LOOP
    EXECUTE format('DROP POLICY IF EXISTS "%s: dm all" ON public.%I', t, t);
    EXECUTE format(
      'CREATE POLICY "%s: dm all" ON public.%I FOR ALL '
      'USING (public.is_world_dm(world_id)) '
      'WITH CHECK (public.is_world_dm(world_id))', t, t);
  END LOOP;
END $$;

-- F.5 Mind map — DM'in (owner_id NULL) ve oyuncunun (owner_id = kendisi)
-- satırları aynı tabloda (§2.9).
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['world_mind_map_nodes', 'world_mind_map_edges'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS "%s: owner all" ON public.%I', t, t);
    EXECUTE format(
      'CREATE POLICY "%s: owner all" ON public.%I FOR ALL '
      'USING ('
      '  (owner_id IS NULL AND public.is_world_dm(world_id)) '
      '  OR (owner_id = (SELECT auth.uid()) AND public.is_world_member(world_id))) '
      'WITH CHECK ('
      '  (owner_id IS NULL AND public.is_world_dm(world_id)) '
      '  OR (owner_id = (SELECT auth.uid()) AND public.is_world_member(world_id)))',
      t, t);
  END LOOP;
END $$;

-- F.6 Online paketler — sahibinden başkası yok. `owner_id` çocuklarda da
-- tutulduğu için JOIN'siz tek kolon testi.
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'user_packages', 'user_package_entities', 'user_package_schemas'
  ] LOOP
    EXECUTE format('DROP POLICY IF EXISTS "%s: owner all" ON public.%I', t, t);
    EXECUTE format(
      'CREATE POLICY "%s: owner all" ON public.%I FOR ALL '
      'USING (owner_id = (SELECT auth.uid())) '
      'WITH CHECK (owner_id = (SELECT auth.uid()))', t, t);
  END LOOP;
END $$;

-- F.7 Grant katmanı — 081'in kuralı: anon hiçbir yeni tabloyu görmez.
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'world_revisions', 'world_tombstones', 'world_member_state',
    'world_entities', 'world_settings', 'world_map_data', 'world_sessions',
    'world_mind_map_nodes', 'world_mind_map_edges', 'world_encounters',
    'world_combatants', 'world_map_pins', 'world_timeline_pins',
    'world_installed_packages', 'user_packages', 'user_package_entities',
    'user_package_schemas'
  ] LOOP
    EXECUTE format('REVOKE ALL ON public.%I FROM anon', t);
    EXECUTE format(
      'GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO authenticated', t);
  END LOOP;
END $$;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM G — Oyuncunun tek okuma kapısı (§2.5, §2.6)
-- ──────────────────────────────────────────────────────────────────────────
-- Karar (neyin sır olduğu) Dart'ta, uygulama (anahtarı sil) burada. PL/pgSQL'e
-- ikinci bir şema yorumlayıcısı YAZMIYORUZ — iki yorumlayıcının ayrışması tam
-- olarak sır sızdıran senaryo.
--
-- `dm_notes` döndürülen kolonlar arasında hiç YOK: boşaltmak yerine sütunu
-- hiç seçmemek, yanlış yapılması imkansız olan hâli.

-- G.0 Görünürlük predikatı — TEK tanım.
-- §2.6'nın uyarısı ("iki yorumlayıcının ayrışması tam olarak sır sızdıran
-- senaryo") aynı şekilde bu predikat için de geçerli: hangi kartın oyuncuya
-- görünür olduğunu iki ayrı sorguda tekrarlarsak, biri güncellenip öteki
-- unutulduğunda sızıntı olur. Aşağıdaki iki RPC de yalnızca buradan okur.
--
-- Görünüm `postgres`'e ait ve SECURITY INVOKER DEĞİL — yani world_entities
-- RLS'ini atlar. Bu yüzden istemciye ASLA grant edilmez; tek okuyucusu
-- aşağıdaki iki SECURITY DEFINER fonksiyondur.
CREATE OR REPLACE VIEW public.v_shared_entities AS
  SELECT e.*
    FROM public.world_entities e
    JOIN public.entity_shares s
      ON s.world_id  = e.world_id
     AND s.entity_id = e.id
     AND (s.shared_with IS NULL OR s.shared_with = auth.uid())
   -- EMNİYET KURALI (§2.6): NULL = "sır listesi bilinmiyor", "sır yok"
   -- DEĞİL. Kart hiç görünmez.
   WHERE e.dm_only_keys IS NOT NULL;

REVOKE ALL ON public.v_shared_entities FROM anon, authenticated;

DROP FUNCTION IF EXISTS public.get_shared_entities(TEXT, BIGINT);
CREATE FUNCTION public.get_shared_entities(
  p_world_id       TEXT,
  p_since_revision BIGINT DEFAULT 0
)
RETURNS TABLE (
  id                TEXT,
  world_id          TEXT,
  category_slug     TEXT,
  name              TEXT,
  source            TEXT,
  description       TEXT,
  image_path        TEXT,
  images_json       TEXT,
  tags_json         TEXT,
  pdfs_json         TEXT,
  location_id       TEXT,
  fields_json       TEXT,
  package_id        TEXT,
  package_entity_id TEXT,
  linked            BOOLEAN,
  revision          BIGINT,
  updated_at        TIMESTAMPTZ
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF NOT public.is_world_member(p_world_id) THEN
    RAISE EXCEPTION 'not a member of world %', p_world_id USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    e.id, e.world_id, e.category_slug, e.name, e.source, e.description,
    e.image_path, e.images_json, e.tags_json, e.pdfs_json, e.location_id,
    CASE WHEN e.dm_only_keys = '{}'::TEXT[]
         THEN e.fields_json
         ELSE (e.fields_json::jsonb - e.dm_only_keys)::TEXT
    END,
    e.package_id, e.package_entity_id, e.linked, e.revision, e.updated_at
  FROM public.v_shared_entities e
  WHERE e.world_id = p_world_id
    AND e.revision > COALESCE(p_since_revision, 0);
END $$;

GRANT EXECUTE ON FUNCTION public.get_shared_entities(TEXT, BIGINT) TO authenticated;

COMMENT ON FUNCTION public.get_shared_entities(TEXT, BIGINT) IS
  'Oyuncunun kart okumak için TEK kapısı. world_entities''e doğrudan RLS '
  'erişimi yoktur. dm_notes hiç seçilmez, dm_only_keys anahtarları '
  'fields_json''dan çıkarılır, dm_only_keys NULL ise kart döndürülmez.';

-- Paylaşım geri çekildiğinde oyuncunun kartı griye alabilmesi için güncel
-- görünür kart listesi (§2.5). Tombstone yerine liste karşılaştırması:
-- paylaşım sayısı dünya başına 4000 ile sınırlı, tek dizi ucuz.
DROP FUNCTION IF EXISTS public.get_shared_entity_ids(TEXT);
CREATE FUNCTION public.get_shared_entity_ids(p_world_id TEXT)
RETURNS TEXT[]
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE v_ids TEXT[];
BEGIN
  IF NOT public.is_world_member(p_world_id) THEN
    RAISE EXCEPTION 'not a member of world %', p_world_id USING ERRCODE = '42501';
  END IF;

  -- Gövdeleri okumadan, get_shared_entities ile AYNI görünürlük predikatı.
  SELECT COALESCE(array_agg(e.id ORDER BY e.id), '{}'::TEXT[]) INTO v_ids
    FROM public.v_shared_entities e
   WHERE e.world_id = p_world_id;

  RETURN v_ids;
END $$;

GRANT EXECUTE ON FUNCTION public.get_shared_entity_ids(TEXT) TO authenticated;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM H — Kota sabitleri ve sınırlar (§2.14)
-- ──────────────────────────────────────────────────────────────────────────
-- Postgres free tier 500 MB ve dolunca uygulama YAZMAYI bırakır (R2 gibi LRU
-- atmaz). Kota aşımı asla yerel yazmayı durdurmaz — yalnızca push reddedilir.
--
-- 088'in dersi: CHECK ifadesi fonksiyon çağıramaz (immutability), o yüzden
-- sabit iki yerde durur ve BİRLİKTE değiştirilir.

CREATE OR REPLACE FUNCTION public.max_rows_per_world()
RETURNS INT LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $$ SELECT 20000 $$;

CREATE OR REPLACE FUNCTION public.max_entity_row_bytes()
RETURNS BIGINT LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $$ SELECT 262144::bigint $$;

CREATE OR REPLACE FUNCTION public.max_online_packages_per_user()
RETURNS INT LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $$ SELECT 20 $$;

CREATE OR REPLACE FUNCTION public.max_cloud_bytes_per_user()
RETURNS BIGINT LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $$ SELECT 524288000::bigint $$;  -- 500 MB

GRANT EXECUTE ON FUNCTION public.max_rows_per_world()            TO authenticated;
GRANT EXECUTE ON FUNCTION public.max_entity_row_bytes()          TO authenticated;
GRANT EXECUTE ON FUNCTION public.max_online_packages_per_user()  TO authenticated;
GRANT EXECUTE ON FUNCTION public.max_cloud_bytes_per_user()      TO authenticated;

-- H.1 Kart satırı 256 KB (entity_shares'in yarısı). Sabit: max_entity_row_bytes().
ALTER TABLE public.world_entities
  DROP CONSTRAINT IF EXISTS chk_world_entities_row_size;
ALTER TABLE public.world_entities
  ADD CONSTRAINT chk_world_entities_row_size
  CHECK (octet_length(fields_json) + octet_length(description)
         + octet_length(dm_notes) <= 262144)
  NOT VALID;

-- H.2 fields_json GERÇEKTEN bir JSON nesnesi olmalı.
-- Güvenlik sınırı, kolaylık değil: get_shared_entities redaksiyonu
-- `fields_json::jsonb - keys` yapıyor; bozuk ya da skaler bir satır o
-- sorguyu patlatır ve dünyadaki HER oyuncunun okuması durur. Yazarken
-- reddetmek, okurken patlamaktan iyidir.
ALTER TABLE public.world_entities
  DROP CONSTRAINT IF EXISTS chk_world_entities_fields_object;
ALTER TABLE public.world_entities
  ADD CONSTRAINT chk_world_entities_fields_object
  CHECK (jsonb_typeof(fields_json::jsonb) = 'object')
  NOT VALID;

ALTER TABLE public.user_package_entities
  DROP CONSTRAINT IF EXISTS chk_user_package_entities_fields_object;
ALTER TABLE public.user_package_entities
  ADD CONSTRAINT chk_user_package_entities_fields_object
  CHECK (jsonb_typeof(fields_json::jsonb) = 'object')
  NOT VALID;

-- H.3 Dünya başına kart satırı: 20.000. 088'in deseni — yalnızca INSERT
-- sayar, rutin UPDATE tam sınırda patlamasın.
CREATE OR REPLACE FUNCTION public.enforce_world_row_limits()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE v_count INT;
BEGIN
  SELECT count(*) INTO v_count
    FROM public.world_entities WHERE world_id = NEW.world_id;

  IF v_count >= public.max_rows_per_world() THEN
    RAISE EXCEPTION 'world row limit reached (%/%)',
      v_count, public.max_rows_per_world() USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_enforce_world_row_limits ON public.world_entities;
CREATE TRIGGER trg_enforce_world_row_limits
  BEFORE INSERT ON public.world_entities
  FOR EACH ROW EXECUTE FUNCTION public.enforce_world_row_limits();

-- H.4 Kişi başı online paket: 20.
CREATE OR REPLACE FUNCTION public.enforce_user_package_limits()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE v_count INT;
BEGIN
  SELECT count(*) INTO v_count
    FROM public.user_packages WHERE owner_id = NEW.owner_id;

  IF v_count >= public.max_online_packages_per_user() THEN
    RAISE EXCEPTION 'online package limit reached (%/%)',
      v_count, public.max_online_packages_per_user()
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_enforce_user_package_limits ON public.user_packages;
CREATE TRIGGER trg_enforce_user_package_limits
  BEFORE INSERT ON public.user_packages
  FOR EACH ROW EXECUTE FUNCTION public.enforce_user_package_limits();

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM I — Realtime
-- ──────────────────────────────────────────────────────────────────────────
-- §2.3'ün kararı: CDC değil, artımlı çekme. Yayına giren TEK yeni tablo
-- `world_revisions` — 26 tabloya abonelik yerine dünya başına nadiren düşen
-- tek sinyal. Var olan abonelikler BU migration'da budanmıyor (istemci hâlâ
-- onları kullanıyor); budama Faz 5.5'te.
--
-- REPLICA IDENTITY: varsayılan (PK) yeterli. Satır dört kolon; 052'nin FULL
-- ayarı büyük entity satırları içindi, burada gereksiz vergi olurdu.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND NOT EXISTS (
       SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'world_revisions') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.world_revisions;
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
