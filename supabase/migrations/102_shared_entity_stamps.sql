-- ============================================================================
-- 102 — Oyuncunun kart doğrulaması (online-sync-redesign.md §4.8.10)
-- ============================================================================
-- Faz 5.5b'de oyuncu her açılışta izinli kartların hepsini çekiyordu. Artık
-- kartlar oyuncunun yerel Drift'inde duruyor; açılışta ve her sinyalde yalnız
-- DOĞRULAMA yapılıyor:
--
--   get_shared_entity_stamps(world)     → izinli kartların (id, updated_at,
--                                         linked) listesi, gövdesiz
--   get_shared_entities(world, 0, ids)  → yalnız yerelde olmayan ya da
--                                         buluttaki hali daha yeni olanlar
--
-- Listede olmayan yerel kart paylaşımı geri çekilmiş karttır: oyuncuda gri
-- kalır (§2.5).
--
-- İkisi de 094'ün `v_shared_entities`'inden okur — görünürlük predikatı tek
-- yerde kalır (094 §G'nin uyarısı). `updated_at` istemcinin düzenleme zamanı
-- (§2.8), oyuncunun yerel satırı da onu taşıyor; karşılaştırma bunun üstünden.
--
-- İdempotent. Eski istemcinin iki parametreli çağrısı `p_ids` varsayılanıyla
-- aynen çalışır.
-- ============================================================================

DROP FUNCTION IF EXISTS public.get_shared_entities(TEXT, BIGINT);
DROP FUNCTION IF EXISTS public.get_shared_entities(TEXT, BIGINT, TEXT[]);
CREATE FUNCTION public.get_shared_entities(
  p_world_id       TEXT,
  p_since_revision BIGINT DEFAULT 0,
  p_ids            TEXT[] DEFAULT NULL
)
RETURNS TABLE (
  id                TEXT,
  world_id          TEXT,
  category_slug     TEXT,
  name              TEXT,
  source            TEXT,
  description       TEXT,
  image_path        TEXT,
  images_json       TEXT,
  tags_json         TEXT,
  pdfs_json         TEXT,
  location_id       TEXT,
  fields_json       TEXT,
  package_id        TEXT,
  package_entity_id TEXT,
  linked            BOOLEAN,
  revision          BIGINT,
  updated_at        TIMESTAMPTZ
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF NOT public.is_world_member(p_world_id) THEN
    RAISE EXCEPTION 'not a member of world %', p_world_id USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    e.id, e.world_id, e.category_slug, e.name, e.source, e.description,
    e.image_path, e.images_json, e.tags_json, e.pdfs_json, e.location_id,
    CASE WHEN e.dm_only_keys = '{}'::TEXT[]
         THEN e.fields_json
         ELSE (e.fields_json::jsonb - e.dm_only_keys)::TEXT
    END,
    e.package_id, e.package_entity_id, e.linked, e.revision, e.updated_at
  FROM public.v_shared_entities e
  WHERE e.world_id = p_world_id
    AND e.revision > COALESCE(p_since_revision, 0)
    AND (p_ids IS NULL OR e.id = ANY (p_ids));
END $$;

GRANT EXECUTE ON FUNCTION public.get_shared_entities(TEXT, BIGINT, TEXT[])
  TO authenticated;

COMMENT ON FUNCTION public.get_shared_entities(TEXT, BIGINT, TEXT[]) IS
  'Oyuncunun kart okumak için TEK kapısı. world_entities''e doğrudan RLS '
  'erişimi yoktur. dm_notes hiç seçilmez, dm_only_keys anahtarları '
  'fields_json''dan çıkarılır, dm_only_keys NULL ise kart döndürülmez. '
  'p_ids verilirse yalnız o kartlar (102: doğrulamanın eksik/değişen listesi).';

DROP FUNCTION IF EXISTS public.get_shared_entity_stamps(TEXT);
CREATE FUNCTION public.get_shared_entity_stamps(p_world_id TEXT)
RETURNS TABLE (id TEXT, updated_at TIMESTAMPTZ, linked BOOLEAN)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF NOT public.is_world_member(p_world_id) THEN
    RAISE EXCEPTION 'not a member of world %', p_world_id USING ERRCODE = '42501';
  END IF;

  -- Gövdeleri okumadan, get_shared_entities ile AYNI görünürlük predikatı.
  RETURN QUERY
  SELECT e.id, e.updated_at, e.linked
    FROM public.v_shared_entities e
   WHERE e.world_id = p_world_id;
END $$;

GRANT EXECUTE ON FUNCTION public.get_shared_entity_stamps(TEXT) TO authenticated;

COMMENT ON FUNCTION public.get_shared_entity_stamps(TEXT) IS
  'Oyuncunun kart doğrulaması: izinli kartların id + düzenleme zamanı, '
  'gövdesiz. İstemci yerelle karşılaştırıp yalnız eksik/değişeni '
  'get_shared_entities(world, 0, ids) ile çeker; listede olmayan yerel kart '
  'geri çekilmiştir (gri).';

NOTIFY pgrst, 'reload schema';
