-- ============================================================================
-- 103 — entity_shares saf izin tablosu (online-sync-redesign.md §2.5, §4.8.11)
-- ============================================================================
-- 078 kart gövdesini `entity_shares.payload_json`'a taşımıştı. Faz 5.5b'den
-- beri oyuncu gövdeyi DM'in bulut aynasından (`get_shared_entities`, sunucuda
-- kırpılmış) alıyor ve kartı yerelde tutuyor (102); istemci artık sütunu ne
-- yazıyor ne okuyor. Herkesin güncel sürümde olduğu varsayılıyor (kullanıcı,
-- 2026-10-02): eski istemci bu sütuna yazmaya çalışırsa paylaşımı düşer.
--
-- Düşenler: sütun, 088'in 512 KB CHECK'i ve sabit fonksiyonu. 088'in dünya
-- başına 4000 satır tavanı (`max_shares_per_world`) kalıyor.
--
-- İdempotent.
-- ============================================================================

ALTER TABLE public.entity_shares
  DROP CONSTRAINT IF EXISTS chk_entity_shares_payload_size;
ALTER TABLE public.entity_shares
  DROP COLUMN IF EXISTS payload_json;
DROP FUNCTION IF EXISTS public.max_share_payload_bytes();

COMMENT ON TABLE public.entity_shares IS
  'Yalnız izin: "bu dünyanın üyeleri (ya da shared_with) bu kartı okuyabilir". '
  'Gövde world_entities''te; oyuncunun tek kapısı get_shared_entities (102).';

NOTIFY pgrst, 'reload schema';
