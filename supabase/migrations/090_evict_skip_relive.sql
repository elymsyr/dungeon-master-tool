-- ============================================================================
-- 090_evict_skip_relive.sql — kuyruktaki satır bayatlamışsa R2'da SİLME.
-- ============================================================================
-- Sorun: anahtarlar içerik adresli (`pub/{sha}{ext}`). Bir obje refcount 0'a
-- düşüp kuyruğa girdikten SONRA aynı sha yeniden pinlenirse (aynı görsel başka
-- bir yayına konur, ya da yarıda kalan bir yayın tekrar denenir), kuyruktaki
-- eski satır sweep'te CANLI objeyi siler. Canlıda görüldü: aynı sha 2.5 sn
-- arayla iki kez kuyruğa girmişti.
--
-- Çözüm: pop sırasında sha hâlâ canlıysa satırı kuyruktan düş ama worker'a
-- DÖNDÜRME. Karar burada, çünkü DELETE ile kontrol aynı transaction'da olmalı.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.transient_evict_pop(_limit INT DEFAULT 20)
RETURNS TABLE (id BIGINT, sha256 TEXT, ext TEXT, uploader_id UUID, r2_key TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH picked AS (
    SELECT q.id
      FROM public.transient_evict_queue q
     ORDER BY q.enqueued_at ASC
     LIMIT _limit
     FOR UPDATE SKIP LOCKED
  ), popped AS (
    DELETE FROM public.transient_evict_queue q
     USING picked
     WHERE q.id = picked.id
    RETURNING q.id, q.sha256, q.ext, q.uploader_id, q.r2_key
  )
  SELECT p.id, p.sha256, p.ext, p.uploader_id, p.r2_key
    FROM popped p
   -- Sınıfına göre bak: `r2_key` dolu satır pinned (`pub/`), NULL satır
   -- transient. İkisi ayrı anahtar uzayı — transient kopyanın varlığı pinned
   -- objeyi kurtarmaz, tersi de geçerli.
   WHERE CASE
           WHEN p.r2_key IS NOT NULL
             THEN NOT EXISTS (SELECT 1 FROM public.pub_assets a
                               WHERE a.sha256 = p.sha256)
           ELSE NOT EXISTS (SELECT 1 FROM public.transient_shares t
                             WHERE t.sha256 = p.sha256
                               AND t.uploader_id = p.uploader_id)
         END;
END $$;

REVOKE ALL ON FUNCTION public.transient_evict_pop(INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.transient_evict_pop(INT) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.transient_evict_pop(INT) TO service_role;

NOTIFY pgrst, 'reload schema';
