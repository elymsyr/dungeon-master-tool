-- ============================================================================
-- 091_admin_delete_releases_media.sql — moderatör silmesi medyayı da bıraksın.
-- ============================================================================
-- Sorun: admin_delete_marketplace_listing sadece satırı siliyordu; pinlenmiş
-- pub_asset_refs kalıyor, refcount hiç 0'a düşmüyor, obje evict kuyruğuna
-- girmiyor ve R2'de sonsuza kadar duruyor. Sahibin silmesi doğru yapıyor
-- (client pub_asset_release çağırıyor).
--
-- Neden pub_asset_release çağrılmıyor: o fonksiyon auth.uid() ile sahiplik
-- filtreliyor; admin ≠ owner olduğu için 0 satır silerdi. Ref'leri doğrudan
-- düşürüyoruz, obje silimi 089'daki trg_drop_orphan_pub_asset'in işi.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_delete_marketplace_listing(p_listing UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_owner UUID;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  PERFORM public._assert_admin_rate_limit();

  SELECT owner_id INTO v_owner FROM public.marketplace_listings WHERE id = p_listing;
  IF v_owner IS NULL THEN
    RETURN;
  END IF;

  DELETE FROM public.marketplace_listings WHERE id = p_listing;

  -- Pinlenmiş medyayı bırak; son ref gidince trigger objeyi kuyruğa atar.
  DELETE FROM public.pub_asset_refs WHERE ref_key = p_listing::TEXT;

  INSERT INTO public.admin_audit_log (admin_id, action, target_user_id, target_entity_id)
  VALUES (auth.uid(), 'delete_marketplace_listing', v_owner, p_listing::TEXT);
END $$;

GRANT EXECUTE ON FUNCTION public.admin_delete_marketplace_listing(UUID) TO authenticated;
