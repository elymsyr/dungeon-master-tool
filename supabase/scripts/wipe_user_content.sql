-- ============================================================================
-- wipe_user_content.sql
--   Kullanıcıların BÜTÜN online içeriğini siler; official içerik kalır.
--   SQL Editor'de olduğu gibi çalıştır — ÇALIŞTIRINCA SİLER, kuru çalıştırma
--   yok. Sondaki tablo her public tablonun satır sayısını ve silinip
--   silinmediğini (`hedef`) gösterir: `hedef` satırları 0 olmalı.
--
--   SQL Editor yalnız SON statement'ın sonucunu gösterir; bu yüzden script
--   sayım SELECT'iyle biter. Hepsi tek sorgu = tek örtük transaction: bir
--   hata olursa hiçbir şey silinmez.
--
--   Silinen: online dünyalar ve bütün ayna satırları, üyelik/davet/paylaşım,
--   online karakterler, online paketler, dünya/paket/karakter medyası
--   satırları, marketplace ilanları ve havuzu, ücretsiz medya, oyun ilanları,
--   gönderiler, beğeniler, mesajlar.
--   Kalan: hesaplar (auth.users, profiles, follows), adminlik ve ban
--   tabloları, admin log'u, bildirimler, hata raporları. Official katalog
--   DB'de değil, R2'nin `catalog/` önekinde — buraya dokunulmuyor.
--
--   Listede olup DB'de olmayan tablo atlanır (`hedef` true, `rows` NULL).
--   CASCADE YOK, bilerek: listede olmayan bir tablo bunlardan birine FK ile
--   bağlıysa TRUNCATE hata verir ve hiçbir şey silinmez. Hata verirse o
--   tabloyu bana getir.
--
--   Sonra elle: Storage bucket'ları (wipe_storage.sh) ve R2 (catalog/ HARİÇ).
--   Worker'ın /admin/purge-all ucunu KULLANMA — catalog/'u da siler.
-- ============================================================================

DROP TABLE IF EXISTS pg_temp.wipe_targets;
CREATE TEMP TABLE wipe_targets (t text PRIMARY KEY);
INSERT INTO wipe_targets (t) VALUES
  -- Online dünyalar
  ('worlds'),
  ('world_members'),
  ('world_invites'),
  ('world_member_state'),
  ('world_projection'),
  ('world_packages'),
  ('entity_shares'),
  ('world_revisions'),
  ('world_tombstones'),
  ('world_settings'),
  ('world_entities'),
  ('world_map_data'),
  ('world_map_pins'),
  ('world_timeline_pins'),
  ('world_mind_map_nodes'),
  ('world_mind_map_edges'),
  ('world_sessions'),
  ('world_encounters'),
  ('world_combatants'),
  ('world_installed_packages'),
  ('world_media'),
  -- Karakterler
  ('world_characters'),
  ('character_revisions'),
  ('character_tombstones'),
  -- Paketler
  ('user_packages'),
  ('user_package_entities'),
  ('user_package_schemas'),
  ('user_package_tombstones'),
  -- Medya metadata'sı ve R2 silme kuyruğu (R2'yi elle boşaltıyoruz; kuyruk
  -- kalırsa cron olmayan key'leri silmeye uğraşır)
  ('pub_assets'),
  ('pub_asset_refs'),
  ('free_media_assets'),
  ('community_assets'),
  ('r2_evict_queue'),
  -- Marketplace ve sosyal
  ('marketplace_listings'),
  ('game_listings'),
  ('game_listing_applications'),
  ('posts'),
  ('post_likes'),
  ('conversations'),
  ('conversation_members'),
  ('messages');

DO $$
DECLARE
  v_list text;
BEGIN
  SELECT string_agg(format('public.%I', t), ', ')
    INTO v_list
    FROM wipe_targets
   WHERE to_regclass(format('public.%I', t)) IS NOT NULL;
  IF v_list IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE ' || v_list;
  END IF;
END $$;

-- Her public tablonun satır sayısı. Listede yeni bir içerik tablosu görürsen
-- (hedef false, satırı > 0, adı tanıdık değil) bana getir.
SELECT coalesce(i.table_name, w.t) AS table_name,
       w.t IS NOT NULL AS hedef,
       CASE WHEN i.table_name IS NOT NULL THEN
         (xpath('/row/c/text()',
                query_to_xml(format('select count(*) as c from public.%I',
                                    i.table_name), false, true, '')))[1]::text::int
       END AS rows
  FROM (SELECT table_name::text
          FROM information_schema.tables
         WHERE table_schema = 'public' AND table_type = 'BASE TABLE') i
  FULL JOIN wipe_targets w ON w.t = i.table_name
 ORDER BY hedef DESC, rows DESC NULLS LAST, table_name;
