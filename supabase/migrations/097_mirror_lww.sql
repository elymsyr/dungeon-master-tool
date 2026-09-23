-- ============================================================================
-- 097_mirror_lww.sql — Faz 5b: "son düzenleyen kazanır" sunucuda da
-- ============================================================================
-- Bkz. docs/online-sync-redesign.md §2.8 (tek kural: zamanı doğru yerden al),
-- §4.9 (Faz 5b).
--
-- Sorun:
--   §2.8'in kuralı istemcide uygulanıyordu (pull: yerel `updated_at` gelenden
--   büyük ya da eşitse satır atılır), sunucuda uygulanmıyordu. Push düz upsert:
--   bulutta ne varsa ezer. Belgenin kendi örneği bu yüzden kırıktı:
--
--     telefon çevrimdışı 14:00'te kartı düzenler
--     laptop 15:00'te düzenler, push → bulut 15:00
--     telefon 16:00'da ağa girer, push → bulut 14:00   ← varış zamanı kazandı
--     laptop pull: yerel 15:00 > bulut 14:00 → atar
--
--   Sonuç kayıp bile değil, KALICI AYRIŞMA: laptop 15:00'i, bulut ve telefon
--   14:00'ü tutar ve kimse kimseyi düzeltmez. Faz 5b'nin canlı sinyali bunu
--   seyrek bir durumdan her çevrimdışı dönüşe taşıyor.
--
--   Silme tarafında aynısı: A kartı sildi (tombstone), çevrimdışı B o karta
--   silmeden ÖNCE dokunmuştu. B ağa girip push edince upsert satırı yeniden
--   INSERT eder — silinmiş kart dirilir ve her cihaza geri iner.
--
-- Ne yapar:
--   A) 16 tabloya BEFORE UPDATE: gelen `updated_at` buluttakinden ESKİYSE
--      satır yazılmaz (RETURN NULL → upsert o satırı sessizce atlar).
--   B) Dünyaya bağlı 13 tabloya BEFORE INSERT: aynı satırın tombstone'u
--      gelen düzenlemeden YENİYSE satır yazılmaz.
--   C) 096'nın echo guard'ındaki delik: upsert'ün INSERT dalı, satır zaten
--      varsa da sayacı yakıyordu. Artık yakmıyor (ayrıntı bölümün başında).
--
-- Eşitlik (`=`) bilerek geçiyor: `next_package_revision` paketin satırını
-- `updated_at`'e dokunmadan günceller, `claim_character` gibi RPC'ler de öyle.
-- `<=` onların yazmasını da yutardı. Aynı saniyede iki cihazdan farklı içerik
-- gelmesi kabul edilen sınır (belge §4.9).
--
-- Trigger adları `trg_<tablo>_lww_*`: aynı zamanlamadaki trigger'lar ada göre
-- sırayla koşar ve `lww` < `stamp_rev` — atlanan satır revizyon YAKMAZ, sinyal
-- çıkmaz.
--
-- Ne YAPMAZ — bilinçli:
--   * Tombstone'un `deleted_at`'i hâlâ sunucunun `now()`'ı, silmenin kendi
--     zamanı değil. Çevrimdışı yapılıp geç gönderilen silme olduğundan yeni
--     görünür → belirsizlik silmenin lehine çözülür. Cihazlar yine aynı sonuca
--     varır (pull aynı karşılaştırmayı yapıyor).
--   * Paket tablolarına B yok: paket silmesinin tombstone'u yok (Faz 5c).
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run.
-- Doğrulama: scripts/verify_097.sql
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM A — Eski düzenleme yeniyi ezmesin
-- ──────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tg_skip_row()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN NULL;  -- WHEN şartı karar verdi; burası yalnız atlar
END $$;

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'world_entities', 'world_settings', 'world_map_data', 'world_sessions',
    'world_mind_map_nodes', 'world_mind_map_edges', 'world_encounters',
    'world_combatants', 'world_map_pins', 'world_timeline_pins',
    'world_installed_packages', 'world_member_state', 'world_characters',
    'user_packages', 'user_package_entities', 'user_package_schemas'
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_lww_upd ON public.%I', t, t);
    EXECUTE format(
      'CREATE TRIGGER trg_%s_lww_upd BEFORE UPDATE ON public.%I '
      'FOR EACH ROW WHEN (NEW.updated_at < OLD.updated_at) '
      'EXECUTE FUNCTION public.tg_skip_row()', t, t);
  END LOOP;
END $$;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM B — Silinmiş satır eski bir düzenlemeyle dirilmesin
-- ──────────────────────────────────────────────────────────────────────────
-- TG_ARGV[0] = satırın kimlik kolonu; 094 E.6'daki tombstone trigger'ıyla
-- aynı liste. `upsert` var olan satırda da önce BEFORE INSERT'ten geçer; orada
-- da tutarlı: tombstone'dan eski bir düzenleme, tombstone'dan sonra dirilmiş
-- bir satırdan da eskidir ve A zaten atlardı.
--
-- SECURITY DEFINER + row_security off: oyuncu kendi karakterini yazarken DM'in
-- bıraktığı tombstone'u da görebilmeli (F.2 ona yalnız kendininkini açıyor).
CREATE OR REPLACE FUNCTION public.tg_skip_buried_insert()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.world_tombstones t
     WHERE t.world_id   = NEW.world_id
       AND t.table_name = TG_TABLE_NAME
       AND t.row_id     = to_jsonb(NEW) ->> TG_ARGV[0]
       AND t.deleted_at > NEW.updated_at) THEN
    RETURN NULL;
  END IF;
  RETURN NEW;
END $$;

DO $$
DECLARE r RECORD;
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
      'DROP TRIGGER IF EXISTS trg_%s_lww_ins ON public.%I', r.tbl, r.tbl);
    EXECUTE format(
      'CREATE TRIGGER trg_%s_lww_ins BEFORE INSERT ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION public.tg_skip_buried_insert(%L)',
      r.tbl, r.tbl, r.key_col);
  END LOOP;
END $$;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM C — Upsert'ün INSERT dalı sayacı yakmasın (096'nın deliği)
-- ──────────────────────────────────────────────────────────────────────────
-- PostgREST'in upsert'i `INSERT … ON CONFLICT DO UPDATE`. Postgres BEFORE
-- INSERT trigger'larını çakışma kontrolünden ÖNCE koşturur: var olan bir
-- satırın upsert'inde de `trg_*_stamp_rev_ins` → `next_world_revision()`
-- çağrılıyor, sayaç artıyor (Realtime'a bir mesaj), sonra satır UPDATE dalına
-- düşüyor. 096'nın echo guard'ı yalnız UPDATE dalını koruyordu: içerik aynı
-- bile olsa her upsert bir revizyon yakıyordu, içerik değiştiyse İKİ — biri
-- hiçbir satırın taşımadığı ölü bir revizyon. verify_096 guard'ı düz UPDATE
-- ile test ettiği için görmedi.
--
-- Ölü revizyonun ikinci bedeli: istemci kendi push'unun yankısını "dönen
-- revizyonlar boşluksuz mu" diye tanıyor (CloudPushService.ownRunEnd). Her
-- güncellemede bir boşluk olsaydı o kontrol hiç tutmazdı.
--
-- Düzeltme: INSERT dalında satır zaten varsa damgalama — kararı UPDATE dalı
-- versin (içerik değiştiyse damgalar, aynıysa 096'nın guard'ı susturur).
-- Önerilen satırın `revision`'ı 0 kalır ama çakışmada kullanılmaz: upsert
-- yalnız gönderilen kolonları SET ediyor ve istemci `revision` göndermiyor.
-- Trigger argümanları tablonun PK kolonları (094).
CREATE OR REPLACE FUNCTION public.tg_stamp_world_revision()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_hit BOOLEAN := false;
BEGIN
  IF TG_OP = 'INSERT' AND TG_NARGS > 0 THEN
    EXECUTE format('SELECT EXISTS (SELECT 1 FROM public.%I WHERE %s)',
      TG_TABLE_NAME,
      (SELECT string_agg(format('%I = ($1).%I', k, k), ' AND ')
         FROM unnest(TG_ARGV) AS k))
      INTO v_hit USING NEW;
    IF v_hit THEN RETURN NEW; END IF;
  END IF;
  NEW.revision := public.next_world_revision(NEW.world_id);
  RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.tg_stamp_package_revision()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_hit BOOLEAN := false;
BEGIN
  IF TG_TABLE_NAME = 'user_packages' THEN
    -- Paketin kendi sayacı satırın içinde; INSERT dalı yan etkisiz.
    NEW.revision := COALESCE(OLD.revision, 0) + 1;
    RETURN NEW;
  END IF;
  IF TG_OP = 'INSERT' AND TG_NARGS > 0 THEN
    EXECUTE format('SELECT EXISTS (SELECT 1 FROM public.%I WHERE %s)',
      TG_TABLE_NAME,
      (SELECT string_agg(format('%I = ($1).%I', k, k), ' AND ')
         FROM unnest(TG_ARGV) AS k))
      INTO v_hit USING NEW;
    IF v_hit THEN RETURN NEW; END IF;
  END IF;
  NEW.revision := public.next_package_revision(NEW.package_id);
  RETURN NEW;
END $$;

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('world_entities',           'public.tg_stamp_world_revision',   '''id'''),
      ('world_settings',           'public.tg_stamp_world_revision',   '''world_id'''),
      ('world_map_data',           'public.tg_stamp_world_revision',   '''world_id'''),
      ('world_sessions',           'public.tg_stamp_world_revision',   '''id'''),
      ('world_mind_map_nodes',     'public.tg_stamp_world_revision',   '''id'''),
      ('world_mind_map_edges',     'public.tg_stamp_world_revision',   '''id'''),
      ('world_encounters',         'public.tg_stamp_world_revision',   '''id'''),
      ('world_combatants',         'public.tg_stamp_world_revision',   '''id'''),
      ('world_map_pins',           'public.tg_stamp_world_revision',   '''id'''),
      ('world_timeline_pins',      'public.tg_stamp_world_revision',   '''id'''),
      ('world_installed_packages', 'public.tg_stamp_world_revision',   '''world_id'', ''package_id'''),
      ('world_member_state',       'public.tg_stamp_world_revision',   '''world_id'', ''user_id'''),
      ('world_characters',         'public.tg_stamp_world_revision',   '''id'''),
      ('user_package_entities',    'public.tg_stamp_package_revision', '''id'''),
      ('user_package_schemas',     'public.tg_stamp_package_revision', '''id''')
    ) AS t(tbl, fn, keys)
  LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_%s_stamp_rev_ins ON public.%I', r.tbl, r.tbl);
    EXECUTE format(
      'CREATE TRIGGER trg_%s_stamp_rev_ins BEFORE INSERT ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION %s(%s)', r.tbl, r.tbl, r.fn, r.keys);
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
