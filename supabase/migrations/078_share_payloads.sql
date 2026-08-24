-- 078: entity_shares satırları paylaşılan kartın GÖVDESİNİ de taşısın.
--
-- Neden:
--   entity_shares şimdiye kadar yalnızca bir görünürlük işaretiydi:
--   (entity_id, world_id, shared_with). Kartın içeriği `world_entities`
--   aynasından geliyordu — yani oyuncunun cihazında DM'in TÜM dünyası
--   duruyordu ve paylaşım sadece hangisinin gösterileceğini seçiyordu.
--
--   077 o aynayı kaldırdı. Artık paylaşım satırı kendi içeriğini taşır:
--   `payload_json`, `entityToRaw()`'un ürettiği blob (campaign blob'undaki
--   `entities` haritasının satır şekli). Oyuncu bunu doğrudan kendi yerel
--   blob'una yazar; paylaşımı geri alınca satır silinir ve gövde de düşer.
--
--   NULL payload = linked (paket / built-in) kart: gövdesi zaten oyuncunun
--   kurulu paketinden gelir, kopyalamak gereksiz olurdu.
--
-- RLS değişmiyor: okuma `is_world_member(world_id)`, yazma `is_world_dm`.
-- REPLICA IDENTITY FULL zaten 052'de ayarlı — un-share DELETE'i `world_id`
-- taşıdığı için realtime filtresine takılıyor.

ALTER TABLE public.entity_shares
  ADD COLUMN IF NOT EXISTS payload_json TEXT;

COMMENT ON COLUMN public.entity_shares.payload_json IS
  'Paylaşılan entity''nin tam JSON gövdesi (entityToRaw şekli). Oyuncunun tek '
  'içerik kaynağı — world_entities aynası 077''de kaldırıldı. NULL = linked '
  'kart, gövdesi kurulu paketten gelir. Görseller AssetRef''e çevrilmiş '
  'olmalı, aksi halde oyuncu çözemez (bkz. entity_share_prepare.dart).';

NOTIFY pgrst, 'reload schema';
