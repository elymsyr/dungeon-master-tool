-- 077: Bulut sync'i (CDC world mirror) kaldır.
--
-- Neden:
--   Dünyanın tamamı — entity'ler, harita, oturumlar, ayarlar, mind-map —
--   satır satır Postgres'e aynalanıyordu. İki sonucu vardı:
--     1. Oyuncunun cihazına DM'in paylaşmadığı içerik de iniyordu; gizlilik
--        yalnızca istemci tarafındaki `visibleEntityProvider` filtresiydi.
--     2. Cihazdan cihaza taşıma için buluta bağımlılık vardı; oysa artık LAN
--        sync var ve yerel Drift zaten kaynak-doğru.
--
--   Online oyun kaldı ama artık "DM'in paylaşımları" kanalı üzerinden akıyor:
--     world_projection  → DM'in canlı yayını
--     entity_shares     → DM'in paylaştığı kartlar (payload'ı 078 ekliyor)
--     world_characters  → oyuncunun karakter sayfası
--     world_packages    → DM'in dünyaya paylaştığı paketler
--     world_members / world_invites / worlds → üyelik ve dünya meta'sı
--
-- DOKUNULMAYANLAR: yukarıdaki beş tablo, tüm sosyal/marketplace/admin/
--   bug-report/notification yüzeyi, medya-R2 tarafı (053/054/060/065,
--   get_asset_access, check_asset_quota, get_user_total_storage_used) ve
--   072-075 güvenlik sertleştirmeleri.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. Realtime publication'dan çıkar (tablo düşmeden önce)
-- ─────────────────────────────────────────────────────────────────────────
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'world_entities', 'world_mind_map_nodes', 'world_mind_map_edges',
    'world_map_data', 'world_sessions', 'world_settings',
    'personal_packages', 'personal_package_entities',
    'world_battlemap_mark_ops', 'cloud_backups'
  ] LOOP
    BEGIN
      EXECUTE format(
        'ALTER PUBLICATION supabase_realtime DROP TABLE public.%I', t);
    EXCEPTION WHEN OTHERS THEN
      NULL; -- publication'da yoksa sessiz geç
    END;
  END LOOP;
END $$;

-- ─────────────────────────────────────────────────────────────────────────
-- 2. publish_world — artık içerik yüklemiyor
--    Dünyayı online yapmak = `worlds` satırı + DM üyeliği. Oyuncuya giden
--    her şey sonradan, DM paylaştıkça akar. `p_state_json` parametresi
--    kalkıyor → imza değişiyor → eski overload DROP edilmeli.
-- ─────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.publish_world(TEXT, TEXT, TEXT, TEXT, TEXT);

CREATE FUNCTION public.publish_world(
  p_world_id      TEXT,
  p_world_name    TEXT,
  p_template_id   TEXT,
  p_template_hash TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_existing_owner UUID;
  v_world_count    INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  SELECT owner_id INTO v_existing_owner
  FROM public.worlds WHERE id = p_world_id;

  IF v_existing_owner IS NULL THEN
    -- Yeni dünya — per-user online dünya limiti.
    SELECT count(*) INTO v_world_count
    FROM public.worlds WHERE owner_id = auth.uid();
    IF v_world_count >= public.max_online_worlds_per_user() THEN
      RAISE EXCEPTION 'online world limit reached (%/%)',
        v_world_count, public.max_online_worlds_per_user()
        USING ERRCODE = 'check_violation';
    END IF;

    INSERT INTO public.worlds (
      id, owner_id, world_name, template_id, template_hash
    ) VALUES (
      p_world_id, auth.uid(), p_world_name, p_template_id, p_template_hash
    );
  ELSIF v_existing_owner = auth.uid() THEN
    UPDATE public.worlds
       SET world_name    = p_world_name,
           template_id   = p_template_id,
           template_hash = p_template_hash,
           updated_at    = now()
     WHERE id = p_world_id;
  ELSE
    RAISE EXCEPTION 'world % owned by different user (%)',
      p_world_id, v_existing_owner USING ERRCODE = '42501';
  END IF;

  -- DM membership idempotent.
  INSERT INTO public.world_members (world_id, user_id, role)
  VALUES (p_world_id, auth.uid(), 'dm')
  ON CONFLICT (world_id, user_id) DO UPDATE SET role = 'dm';
END $$;

GRANT EXECUTE ON FUNCTION
  public.publish_world(TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- 3. Aynalama trigger'ları — yalnızca reconciler'ın LWW'si için vardı
-- ─────────────────────────────────────────────────────────────────────────
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT c.relname AS tbl, t.tgname AS trg
      FROM pg_trigger t
      JOIN pg_class c ON c.oid = t.tgrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public'
       AND NOT t.tgisinternal
       AND t.tgname LIKE '%bump_parent%'
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I', r.trg, r.tbl);
  END LOOP;
END $$;

DROP FUNCTION IF EXISTS public.tg_bump_parent_world();

-- ─────────────────────────────────────────────────────────────────────────
-- 4. Personal package ("Make Online") RPC'leri
-- ─────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.publish_personal_package(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.unpublish_personal_package(TEXT);
DROP FUNCTION IF EXISTS public.publish_personal_package_entity(TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.delete_personal_package_entity(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.max_online_packages_per_user();
DROP FUNCTION IF EXISTS public.max_online_characters_per_user();

-- Battle-map collab denemesi: istemcisi hiç bağlanmadı (bkz. 061 başlığı).
DROP FUNCTION IF EXISTS public.compact_battlemap_marks(TEXT, TEXT, BIGINT);

-- ─────────────────────────────────────────────────────────────────────────
-- 5. ban_user / admin_delete_user — artık var olmayan tablolara dokunmasın
--    (076'nın kapsamı dışında bırakılan beta_participants satırı da burada
--    temizleniyor; iki migration birlikte deploy edilir.)
-- ─────────────────────────────────────────────────────────────────────────
DO $$
DECLARE r RECORD; v_src TEXT;
BEGIN
  FOR r IN
    SELECT p.oid, p.proname,
           pg_get_function_identity_arguments(p.oid) AS args
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN ('ban_user', 'admin_delete_user')
  LOOP
    v_src := pg_get_functiondef(r.oid);
    v_src := regexp_replace(
      v_src,
      '\s*DELETE FROM public\.(cloud_backups|beta_participants|personal_packages|personal_package_entities|world_entities)[^;]*;',
      '', 'g');
    EXECUTE v_src;
  END LOOP;
END $$;

-- ─────────────────────────────────────────────────────────────────────────
-- 6. Mirror tabloları
--    Sıra önemli: child'lar önce (FK'ler ON DELETE CASCADE ama açık olalım).
-- ─────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS public.world_battlemap_mark_ops CASCADE;
DROP TABLE IF EXISTS public.personal_package_entities CASCADE;
DROP TABLE IF EXISTS public.personal_packages        CASCADE;
DROP TABLE IF EXISTS public.world_mind_map_edges     CASCADE;
DROP TABLE IF EXISTS public.world_mind_map_nodes     CASCADE;
DROP TABLE IF EXISTS public.world_entities           CASCADE;
DROP TABLE IF EXISTS public.world_map_data           CASCADE;
DROP TABLE IF EXISTS public.world_sessions           CASCADE;
DROP TABLE IF EXISTS public.world_settings           CASCADE;
DROP TABLE IF EXISTS public.cloud_backups            CASCADE;

-- `worlds.state_json` — dünyanın tamamını taşıyan blob. Artık yazılmıyor.
ALTER TABLE public.worlds DROP COLUMN IF EXISTS state_json;

-- ─────────────────────────────────────────────────────────────────────────
-- 7. campaign-backups storage bucket
-- ─────────────────────────────────────────────────────────────────────────
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT polname FROM pg_policy
     WHERE polrelid = 'storage.objects'::regclass
       AND polname ILIKE '%campaign-backups%'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', r.polname);
  END LOOP;
END $$;

DELETE FROM storage.objects WHERE bucket_id = 'campaign-backups';
DELETE FROM storage.buckets WHERE id = 'campaign-backups';

NOTIFY pgrst, 'reload schema';
