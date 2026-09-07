-- ============================================================================
-- verify_publish_media.sql — medyalı bir marketplace yayınından SONRA çalıştır.
-- ============================================================================
-- Kullanım: uygulamadan görselli bir paket/karakter yayınla, sonra Dashboard >
-- SQL Editor'de bunu çalıştır. Hiçbir şey yazmaz, yalnızca okur.
--
-- Beklenen: 1) yayın için pub_assets satırları var, 2) her satırın ref_key'i
-- listing id'sine eşit, 3) havuz sayaçları objeleri görüyor.
-- ============================================================================

-- 1) En son eklenen pinned objeler + hangi yayına bağlılar.
SELECT a.sha256, a.ext, a.bytes, a.mime_type, a.created_at,
       r.ref_key, r.owner_id
  FROM public.pub_assets a
  LEFT JOIN public.pub_asset_refs r USING (sha256)
 ORDER BY a.created_at DESC
 LIMIT 20;

-- 2) Ref'siz obje = sızıntı (yayın yarıda kaldı ya da release çalışmadı).
SELECT a.sha256, a.bytes, a.created_at
  FROM public.pub_assets a
 WHERE NOT EXISTS (SELECT 1 FROM public.pub_asset_refs r WHERE r.sha256 = a.sha256);

-- 3) ref_key gerçekten bir listing'e karşılık geliyor mu?
SELECT r.ref_key, count(*) AS asset_count,
       EXISTS (SELECT 1 FROM public.marketplace_listings l
                WHERE l.id::text = r.ref_key) AS listing_exists
  FROM public.pub_asset_refs r
 GROUP BY r.ref_key
 ORDER BY 3, 1;

-- 4) Havuz sayaçları — admin Storage sekmesindeki barlarla aynı olmalı.
-- get_r2_pool_stats() burada çağrılamaz: is_admin() auth.uid()'e bakar, SQL
-- Editor'de oturum yok ('admin required'). Aynı toplamlar doğrudan:
SELECT 'pinned' AS pool,
       COALESCE(SUM(bytes), 0) AS used_bytes,
       public.pinned_pool_cap_bytes() AS cap_bytes,
       count(*) AS object_count
  FROM public.pub_assets
UNION ALL
SELECT 'transient',
       COALESCE(SUM(bytes), 0),
       public.transient_pool_cap_bytes(),
       count(*)
  FROM public.transient_shares;

SELECT count(*) AS evict_queue_depth FROM public.transient_evict_queue;
