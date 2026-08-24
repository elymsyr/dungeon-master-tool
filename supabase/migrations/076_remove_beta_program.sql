-- 076: Beta programını tamamen kaldır.
--
-- Neden:
--   Beta programı 90 slotlu, admin onaylı bir erişim kapısıydı. Program
--   kapandı: uygulamayı indiren herkes tam erişimli. Kapı üç katmandaydı —
--   RLS politikaları, RPC gövdelerindeki RAISE'ler ve istemci kontrolleri.
--   Sunucu tarafı ÖNCE gitmeli; tersi olursa istemci kontrolü kalkar ama
--   sunucu '42501 beta membership required' fırlatmaya devam eder.
--
-- Sıra bu dosyada zorunlu:
--   1. is_beta_active(...) referans eden HER politika önce beta'sızlaştırılır
--      (politikalar fonksiyona bağımlılık kaydı yaratır — önce onlar
--      temizlenmeden DROP FUNCTION bağımlılık hatası verir).
--   2. Sonra trigger, cron job, fonksiyonlar ve tablolar düşer.
--
-- Kapsam dışı (077'de): ban_user / admin_delete_user gövdelerindeki
--   `DELETE FROM beta_participants` satırları — o fonksiyonlar 077'de
--   cloud_backups kaldırılırken zaten yeniden yazılıyor, iki kez yazmamak
--   için ikisi orada birleşti. İki migration birlikte deploy edilir.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. Hayatta kalan RPC'lerden beta kapısını çıkar
-- ─────────────────────────────────────────────────────────────────────────

-- publish_listing_snapshot — marketplace'e paylaşım. Artık sadece hesap ister
-- (INSERT'ün RLS'i `auth.uid() = owner_id` ile zaten sahipliği zorluyor).
CREATE OR REPLACE FUNCTION public.publish_listing_snapshot(
  p_listing_id      UUID,
  p_item_type       TEXT,
  p_title           TEXT,
  p_description     TEXT,
  p_language        TEXT,
  p_tags            TEXT[],
  p_changelog       TEXT,
  p_content_hash    TEXT,
  p_payload_path    TEXT,
  p_size_bytes      BIGINT,
  p_cover_image_b64 TEXT  DEFAULT NULL,
  p_template_name   TEXT  DEFAULT NULL,
  p_content_summary JSONB DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_new_id UUID := COALESCE(p_listing_id, gen_random_uuid());
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required to publish to the marketplace'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.marketplace_listings (
    id, owner_id, item_type, title, description, language,
    tags, changelog, content_hash, payload_path, size_bytes, cover_image_b64,
    template_name, content_summary
  ) VALUES (
    v_new_id, auth.uid(), p_item_type, p_title, p_description, p_language,
    COALESCE(p_tags, '{}'), p_changelog, p_content_hash, p_payload_path,
    p_size_bytes, p_cover_image_b64, p_template_name, p_content_summary
  );
  RETURN v_new_id;
END $$;

-- share_package_to_world — DM'in dünyaya paket paylaşması. DM kontrolü kalır.
CREATE OR REPLACE FUNCTION public.share_package_to_world(
  p_world_id     TEXT,
  p_package_name TEXT,
  p_state_json   TEXT
) RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id TEXT;
BEGIN
  IF NOT public.is_world_dm(p_world_id) THEN
    RAISE EXCEPTION 'dm only' USING ERRCODE = '42501';
  END IF;

  SELECT package_id INTO v_id
    FROM public.world_packages
   WHERE world_id = p_world_id
     AND package_name = p_package_name;

  IF v_id IS NULL THEN
    v_id := gen_random_uuid()::TEXT;
    INSERT INTO public.world_packages
      (package_id, world_id, package_name, shared_by, state_json)
    VALUES
      (v_id, p_world_id, p_package_name, auth.uid(), p_state_json);
  ELSE
    UPDATE public.world_packages
       SET state_json = p_state_json,
           shared_by  = auth.uid(),
           updated_at = now()
     WHERE package_id = v_id;
  END IF;

  RETURN v_id;
END $$;

-- ─────────────────────────────────────────────────────────────────────────
-- 2. is_beta_active referans eden TÜM politikaları beta'sızlaştır
--    (075'teki `(SELECT auth.uid())` sarmalaması korunur — o bir perf düzeltmesi)
-- ─────────────────────────────────────────────────────────────────────────

-- Kalıcı yüzeyler
ALTER POLICY "Owner inserts own listings" ON public.marketplace_listings
    WITH CHECK ((SELECT auth.uid()) = owner_id);

ALTER POLICY "Worlds: dm update" ON public.worlds
    USING (is_world_dm(id));

ALTER POLICY "Worlds: owner insert" ON public.worlds
    WITH CHECK ((SELECT auth.uid()) = owner_id);

ALTER POLICY "Chars: insert" ON public.world_characters
    WITH CHECK (
      (world_id IS NULL AND owner_id = (SELECT auth.uid()))
      OR (world_id IS NOT NULL AND is_world_member(world_id)
          AND (owner_id = (SELECT auth.uid()) OR is_world_dm(world_id)))
    );

-- community_assets: adı da yalan olmasın, yeniden adlandırılıyor.
DROP POLICY IF EXISTS "community_assets beta insert" ON public.community_assets;
CREATE POLICY "community_assets owner insert"
  ON public.community_assets FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = uploader_id);

-- 077'de tabloları düşene kadar bağımlılığı kesmek için gerekenler.
ALTER POLICY "cloud_backups beta insert" ON public.cloud_backups
    WITH CHECK ((SELECT auth.uid()) = user_id);

ALTER POLICY "cloud_backups beta update" ON public.cloud_backups
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

ALTER POLICY "ppe: owner all" ON public.personal_package_entities
    USING (owner_id = (SELECT auth.uid()))
    WITH CHECK (owner_id = (SELECT auth.uid()));

ALTER POLICY "personal_packages: owner all" ON public.personal_packages
    USING (owner_id = (SELECT auth.uid()))
    WITH CHECK (owner_id = (SELECT auth.uid()));

-- storage.objects: campaign-backups bucket'ı 077'de bucket ile birlikte gider,
-- ama fonksiyon bağımlılığı şimdi kesilmeli.
DROP POLICY IF EXISTS "campaign-backups beta insert" ON storage.objects;

-- ─────────────────────────────────────────────────────────────────────────
-- 3. user_heartbeat — beta_participants bump'ını çıkar
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.user_heartbeat()
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RETURN;
  END IF;

  UPDATE public.profiles
     SET last_active_at = now()
   WHERE user_id = v_user;
END $$;

-- ─────────────────────────────────────────────────────────────────────────
-- 4. Admin kullanıcı listeleri — is_beta kolonunu kaldır
--    (RETURNS TABLE imzası değişiyor → DROP zorunlu)
-- ─────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_all_users_summary();
DROP FUNCTION IF EXISTS public.search_users(TEXT);

CREATE FUNCTION public.get_all_users_summary()
RETURNS TABLE (
  user_id            UUID,
  email              TEXT,
  username           TEXT,
  provider           TEXT,
  created_at         TIMESTAMPTZ,
  is_banned          BOOLEAN,
  storage_bytes      BIGINT,
  last_active_at     TIMESTAMPTZ,
  app_version        TEXT,
  platform           TEXT,
  online_restricted  BOOLEAN,
  online_restricted_reason TEXT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  RETURN QUERY
  SELECT
    u.id AS user_id,
    u.email::TEXT,
    p.username,
    COALESCE(u.raw_app_meta_data->>'provider', 'email')::TEXT AS provider,
    u.created_at,
    EXISTS (SELECT 1 FROM public.banned_users bu WHERE bu.user_id = u.id)    AS is_banned,
    COALESCE(public.get_user_total_storage_used(u.id), 0)::BIGINT            AS storage_bytes,
    p.last_active_at,
    p.app_version,
    p.platform,
    COALESCE(p.online_restricted, false),
    p.online_restricted_reason
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.user_id = u.id
  ORDER BY u.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_all_users_summary() TO authenticated;

CREATE FUNCTION public.search_users(p_query TEXT)
RETURNS TABLE (
  user_id            UUID,
  email              TEXT,
  username           TEXT,
  provider           TEXT,
  created_at         TIMESTAMPTZ,
  is_banned          BOOLEAN,
  storage_bytes      BIGINT,
  last_active_at     TIMESTAMPTZ,
  app_version        TEXT,
  platform           TEXT,
  online_restricted  BOOLEAN,
  online_restricted_reason TEXT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  q TEXT := '%' || lower(COALESCE(p_query, '')) || '%';
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required';
  END IF;

  RETURN QUERY
  SELECT
    u.id AS user_id,
    u.email::TEXT,
    p.username,
    COALESCE(u.raw_app_meta_data->>'provider', 'email')::TEXT AS provider,
    u.created_at,
    EXISTS (SELECT 1 FROM public.banned_users bu WHERE bu.user_id = u.id)    AS is_banned,
    COALESCE(public.get_user_total_storage_used(u.id), 0)::BIGINT            AS storage_bytes,
    p.last_active_at,
    p.app_version,
    p.platform,
    COALESCE(p.online_restricted, false),
    p.online_restricted_reason
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.user_id = u.id
  WHERE lower(COALESCE(u.email, '')) LIKE q
     OR lower(COALESCE(p.username, '')) LIKE q
  ORDER BY u.created_at DESC
  LIMIT 200;
END;
$$;

GRANT EXECUTE ON FUNCTION public.search_users(TEXT) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- 5. Trigger, cron job, realtime publication
-- ─────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_beta_quota_cloud_backups ON public.cloud_backups;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('sweep_inactive_beta_daily');
  END IF;
EXCEPTION WHEN OTHERS THEN
  -- job zaten yoksa sessiz geç
  NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE public.beta_participants;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE public.beta_requests;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- ─────────────────────────────────────────────────────────────────────────
-- 6. Fonksiyonlar
-- ─────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.enforce_beta_quota_on_backup();
DROP FUNCTION IF EXISTS public.admin_list_beta_requests();
DROP FUNCTION IF EXISTS public.admin_list_beta_participants();
DROP FUNCTION IF EXISTS public.admin_approve_beta_request(UUID);
DROP FUNCTION IF EXISTS public.admin_reject_beta_request(UUID);
DROP FUNCTION IF EXISTS public.admin_revoke_beta(UUID);
DROP FUNCTION IF EXISTS public.request_beta(TEXT);
DROP FUNCTION IF EXISTS public.cancel_beta_request();
DROP FUNCTION IF EXISTS public.join_beta();
DROP FUNCTION IF EXISTS public.leave_beta();
DROP FUNCTION IF EXISTS public._leave_beta_for(UUID);
DROP FUNCTION IF EXISTS public._grant_beta_slot(UUID);
DROP FUNCTION IF EXISTS public._purge_beta_user(UUID);
DROP FUNCTION IF EXISTS public.beta_heartbeat();
DROP FUNCTION IF EXISTS public.sweep_inactive_beta();
DROP FUNCTION IF EXISTS public.get_beta_status();
DROP FUNCTION IF EXISTS public.get_beta_quota_used(UUID);
DROP FUNCTION IF EXISTS public.get_beta_quota_bytes();
DROP FUNCTION IF EXISTS public.beta_user_quota_bytes();
DROP FUNCTION IF EXISTS public.beta_slot_cap();
DROP FUNCTION IF EXISTS public.beta_inactivity_days();
DROP FUNCTION IF EXISTS public.is_beta_active(UUID);

-- ─────────────────────────────────────────────────────────────────────────
-- 7. Tablolar
-- ─────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS public.beta_requests;
DROP TABLE IF EXISTS public.beta_participants;

NOTIFY pgrst, 'reload schema';
