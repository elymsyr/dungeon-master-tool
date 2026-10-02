-- ============================================================================
-- wipe_user_content.sql
--   Kullanıcıların BÜTÜN online içeriğini siler; official içerik kalır.
--   SQL Editor'de çalıştır. Varsayılan ROLLBACK ile biter (kuru çalıştırma):
--   sondaki sayımlara bak, doğruysa ROLLBACK'i COMMIT yap, yeniden çalıştır.
--
--   Silinen: online dünyalar ve bütün ayna satırları, üyelik/davet/paylaşım,
--   online karakterler, online paketler, dünya/paket/karakter medyası
--   satırları, marketplace ilanları ve havuzu, ücretsiz medya, oyun ilanları,
--   gönderiler, beğeniler, mesajlar.
--   Kalan: hesaplar (auth.users, profiles, follows), adminlik ve ban
--   tabloları, admin log'u, bildirimler, hata raporları. Official katalog
--   DB'de değil, R2'nin `catalog/` önekinde — buraya dokunulmuyor.
--
--   CASCADE YOK, bilerek: listede olmayan bir tablo bunlardan birine FK ile
--   bağlıysa TRUNCATE hata verir ve hiçbir şey silinmez. Hata verirse o
--   tabloyu bana getir.
--
--   Sonra elle: Storage bucket'ları (wipe_storage.sh) ve R2 (catalog/ HARİÇ).
--   Worker'ın /admin/purge-all ucunu KULLANMA — catalog/'u da siler.
-- ============================================================================

BEGIN;

TRUNCATE TABLE
  -- Online dünyalar
  public.worlds,
  public.world_members,
  public.world_invites,
  public.world_member_state,
  public.world_projection,
  public.world_packages,
  public.entity_shares,
  public.world_revisions,
  public.world_tombstones,
  public.world_settings,
  public.world_entities,
  public.world_map_data,
  public.world_map_pins,
  public.world_timeline_pins,
  public.world_mind_map_nodes,
  public.world_mind_map_edges,
  public.world_sessions,
  public.world_encounters,
  public.world_combatants,
  public.world_installed_packages,
  public.world_media,
  -- Karakterler
  public.world_characters,
  public.character_revisions,
  public.character_tombstones,
  -- Paketler
  public.user_packages,
  public.user_package_entities,
  public.user_package_schemas,
  public.user_package_tombstones,
  -- Medya metadata'sı ve R2 silme kuyruğu (R2'yi elle boşaltıyoruz; kuyruk
  -- kalırsa cron olmayan key'leri silmeye uğraşır)
  public.pub_assets,
  public.pub_asset_refs,
  public.free_media_assets,
  public.community_assets,
  public.r2_evict_queue,
  -- Marketplace ve sosyal
  public.marketplace_listings,
  public.game_listings,
  public.game_listing_applications,
  public.posts,
  public.post_likes,
  public.conversations,
  public.conversation_members,
  public.messages;

-- Kalan her public tablonun satır sayısı. Yukarıdakiler 0 olmalı; listede
-- yeni bir içerik tablosu görürsen (satırı > 0, adı tanıdık değil) bana getir.
SELECT table_name,
       (xpath('/row/c/text()',
              query_to_xml(format('select count(*) as c from public.%I',
                                  table_name), false, true, '')))[1]::text::int
         AS rows
  FROM information_schema.tables
 WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
 ORDER BY rows DESC, table_name;

ROLLBACK;  -- doğruysa COMMIT yap
