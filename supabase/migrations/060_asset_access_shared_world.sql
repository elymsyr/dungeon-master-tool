-- ============================================================================
-- 060_asset_access_shared_world.sql — Counted asset'leri dünya üyelerine aç
-- ============================================================================
-- get_asset_access şimdiye dek SADECE uploader'a izin veriyordu (002, TODO).
-- Sonuç: paylaşılan/projekte edilen entity kartlarının `dmt-asset://` resimleri
-- oyuncuda 403 → kırık resim. transient resimler get_transient_access ile
-- zaten çalışıyordu; bu migration counted asset'leri aynı kurala getirir:
-- "istek sahibi ile uploader ortak bir dünyada üye mi?"
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_asset_access(
  p_user_id UUID,
  p_r2_key  TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  -- Asset community_assets'te var olmalı; uploader her zaman erişir, aksi
  -- halde uploader ile ortak dünya üyeliği (get_transient_access ile aynı).
  SELECT EXISTS (
    SELECT 1
    FROM public.community_assets ca
    WHERE ca.r2_object_key = p_r2_key
      AND (
        ca.uploader_id = p_user_id
        OR EXISTS (
          SELECT 1
          FROM public.world_members a
          JOIN public.world_members b ON a.world_id = b.world_id
          WHERE a.user_id = p_user_id
            AND b.user_id = ca.uploader_id
        )
      )
  );
$$;

REVOKE ALL ON FUNCTION public.get_asset_access(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_asset_access(UUID, TEXT) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_asset_access(UUID, TEXT) TO service_role;

NOTIFY pgrst, 'reload schema';
