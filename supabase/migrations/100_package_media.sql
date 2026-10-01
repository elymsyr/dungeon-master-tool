-- ============================================================================
-- 100_package_media.sql — Faz 5e: online paketin medyası da R2'de
-- ============================================================================
-- Bkz. docs/online-sync-redesign.md §4.8.6 (Faz 5e).
--
-- Neden: paket 4b'den beri satır satır buluta çıkıyor, 5c'den beri ikinci
-- cihaza iniyor — ama baytları değil. Kart satırındaki `dmt-content://` ref'i
-- gidiyor, işaret ettiği görsel hiçbir yerde yok: ikinci cihaza inen paket
-- görselsiz. 5d'nin bütün yığını dünyaya bağlıydı (PK `(world_id, sha256)`,
-- `worlds` FK'sı, üyelik RLS'i, kotanın sahibi `worlds` üstünden).
--
-- Karar (belge §4.8.5'in önerisi): kardeş tablo değil, **tek tablo**.
-- `world_media` ikinci bir kapsam kolonu alır (`package_id`); satır ya bir
-- dünyanın ya bir paketin, ikisinin birden değil. Kişi başı 1 GB bütün
-- kapsamların toplamı (5g karakteri de buraya ekleyecek); kardeş tablo kota
-- fonksiyonunu, tahliyeyi ve imza yolunu çoğaltırdı. Tablonun adı tarihsel
-- kaldı: yeniden adlandırmak istemciye ve eski doğrulama betiklerine
-- dokunurdu, kazancı yalnız isim.
--
-- Ne yapar:
--   A) `world_media.package_id` (FK `user_packages`, CASCADE). `world_id`
--      nullable; tam olarak bir kapsam (CHECK). PK yerine kapsam başına bir
--      UNIQUE — NULL'lar çakışmaz.
--   B) `media_r2_key` — key yerleşiminin tek tanımı: `worlds/{id}/{sha}{ext}`
--      ya da `packages/{id}/{sha}{ext}`. Trigger ve imza RPC'leri buradan;
--      worker artık key kurmuyor.
--   C) RLS: dünya satırını üyeler okur, sahip siler (değişmedi); paket
--      satırını yalnız paketin sahibi okur ve siler — paket paylaşılmıyor.
--   D) Kota: `_media_usage` paket medyasını da kullanıcıya sayar.
--   E) Tahliye: silinen satırın key'i `media_r2_key`'den; `r2_evict_pop`
--      `packages/` önekinin canlılığına da bakar. Paket buluttan silinince
--      (yerele alma, yerel silme, hesap silme) CASCADE → kuyruk → cron.
--   F) Kapsamlı RPC'ler: `media_reserve(_scope, _id, _items)`,
--      `media_confirm(_scope, _id, _shas)`; worker için
--      `media_sign_put(p_user, p_scope, p_id, p_shas)` ve
--      `media_sign_get(p_user, p_shas)`, ikisi de tam `r2_key` döner. 099'un
--      dünyaya bağlı dört RPC'si düşer.
--
-- Deploy sırası: önce 100, hemen ardından worker (eski worker 099'un imza
-- RPC'lerini çağırıyor, arada imza 502 döner), sonra uygulama. 100'den önceki
-- istemci dünya medyası yükleyemez (rezervasyon RPC'si gitti); indirme çalışır.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run.
-- Doğrulama: scripts/verify_100.sql (ve 100'ün adlarına geçen verify_099.sql)
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM A — İkinci kapsam: package_id
-- ──────────────────────────────────────────────────────────────────────────
ALTER TABLE public.world_media
  ADD COLUMN IF NOT EXISTS package_id TEXT
    REFERENCES public.user_packages(id) ON DELETE CASCADE;

-- PK önce düşmeli: PK kolonu nullable yapılamaz.
ALTER TABLE public.world_media DROP CONSTRAINT IF EXISTS world_media_pkey;
ALTER TABLE public.world_media ALTER COLUMN world_id DROP NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conrelid = 'public.world_media'::regclass
                    AND conname = 'world_media_world_sha_key') THEN
    ALTER TABLE public.world_media
      ADD CONSTRAINT world_media_world_sha_key UNIQUE (world_id, sha256);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conrelid = 'public.world_media'::regclass
                    AND conname = 'world_media_package_sha_key') THEN
    ALTER TABLE public.world_media
      ADD CONSTRAINT world_media_package_sha_key UNIQUE (package_id, sha256);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conrelid = 'public.world_media'::regclass
                    AND conname = 'world_media_one_scope') THEN
    ALTER TABLE public.world_media
      ADD CONSTRAINT world_media_one_scope
      CHECK (num_nonnulls(world_id, package_id) = 1);
  END IF;
END $$;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM B — Key yerleşimi ve kapsamın sahibi
-- ──────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.media_r2_key(
  _world   TEXT,
  _package TEXT,
  _sha     TEXT,
  _ext     TEXT
) RETURNS TEXT
LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT CASE WHEN _world IS NOT NULL THEN 'worlds/' || _world
              ELSE 'packages/' || _package END
         || '/' || _sha || _ext
$$;

-- Çağıran kapsamın sahibi mi? Kapsamın id'si R2 key'inin parçası: güvenli
-- karakterler dışındaki id reddedilir (worker da aynı kalıba bakıyor). Her
-- zaman true/false — NULL, `IF NOT` kapısından sessizce geçerdi.
CREATE OR REPLACE FUNCTION public._media_scope_owner(
  _scope TEXT,
  _id    TEXT,
  _uid   UUID
) RETURNS BOOLEAN
LANGUAGE sql STABLE
SET search_path = public, pg_temp
AS $$
  SELECT COALESCE(_id ~ '^[A-Za-z0-9_-]{1,100}$', FALSE) AND CASE _scope
    WHEN 'world'   THEN EXISTS (SELECT 1 FROM public.worlds
                                 WHERE id = _id AND owner_id = _uid)
    WHEN 'package' THEN EXISTS (SELECT 1 FROM public.user_packages
                                 WHERE id = _id AND owner_id = _uid)
    ELSE FALSE
  END
$$;

REVOKE ALL ON FUNCTION public._media_scope_owner(TEXT, TEXT, UUID)
  FROM PUBLIC, anon, authenticated;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM C — RLS
-- ──────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "world_media: members read" ON public.world_media;
DROP POLICY IF EXISTS "world_media: scope read" ON public.world_media;
CREATE POLICY "world_media: scope read" ON public.world_media
  FOR SELECT USING (
    public.is_world_member(world_id)
    OR EXISTS (SELECT 1 FROM public.user_packages p
                WHERE p.id = world_media.package_id
                  AND p.owner_id = (SELECT auth.uid()))
  );

DROP POLICY IF EXISTS "world_media: owner delete" ON public.world_media;
DROP POLICY IF EXISTS "world_media: scope owner delete" ON public.world_media;
CREATE POLICY "world_media: scope owner delete" ON public.world_media
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.worlds w
             WHERE w.id = world_media.world_id
               AND w.owner_id = (SELECT auth.uid()))
    OR EXISTS (SELECT 1 FROM public.user_packages p
                WHERE p.id = world_media.package_id
                  AND p.owner_id = (SELECT auth.uid()))
  );

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM D — Kota: paket medyası da kullanıcının
-- ──────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._media_usage(_uid UUID)
RETURNS TABLE (user_used BIGINT, total_used BIGINT)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    (SELECT COALESCE(SUM(m.bytes), 0)::bigint
       FROM public.world_media m
       LEFT JOIN public.worlds w        ON w.id = m.world_id
       LEFT JOIN public.user_packages p ON p.id = m.package_id
      WHERE COALESCE(w.owner_id, p.owner_id) = _uid),
    ((SELECT COALESCE(SUM(bytes), 0) FROM public.world_media)
     + (SELECT COALESCE(SUM(bytes), 0) FROM public.pub_assets))::bigint
$$;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM E — Tahliye
-- ──────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.enqueue_world_media_evict()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  INSERT INTO public.r2_evict_queue (sha256, ext, r2_key)
    VALUES (OLD.sha256, OLD.ext,
            public.media_r2_key(OLD.world_id, OLD.package_id,
                                OLD.sha256, OLD.ext));
  RETURN NULL;
END $$;

-- 099'un gövdesi + `packages/` dalı: kuyruktaki satır bayatlamışsa (aynı sha
-- o arada aynı pakete yeniden yüklendiyse) kuyruktan düşer, worker'a dönmez.
CREATE OR REPLACE FUNCTION public.r2_evict_pop(_limit INT DEFAULT 20)
RETURNS TABLE (id BIGINT, r2_key TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH picked AS (
    SELECT q.id
      FROM public.r2_evict_queue q
     ORDER BY q.enqueued_at ASC
     LIMIT _limit
     FOR UPDATE SKIP LOCKED
  ), popped AS (
    DELETE FROM public.r2_evict_queue q
     USING picked
     WHERE q.id = picked.id
    RETURNING q.id, q.sha256, q.r2_key
  )
  SELECT p.id, p.r2_key
    FROM popped p
   WHERE CASE
           WHEN p.r2_key LIKE 'pub/%'
             THEN NOT EXISTS (SELECT 1 FROM public.pub_assets a
                               WHERE a.sha256 = p.sha256)
           WHEN p.r2_key LIKE 'worlds/%'
             THEN NOT EXISTS (SELECT 1 FROM public.world_media m
                               WHERE m.world_id = split_part(p.r2_key, '/', 2)
                                 AND m.sha256 = p.sha256)
           WHEN p.r2_key LIKE 'packages/%'
             THEN NOT EXISTS (SELECT 1 FROM public.world_media m
                               WHERE m.package_id = split_part(p.r2_key, '/', 2)
                                 AND m.sha256 = p.sha256)
           ELSE TRUE
         END;
END $$;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM F — Kapsamlı RPC'ler
-- ──────────────────────────────────────────────────────────────────────────

-- 099'un `world_media_reserve`'ü, kapsamlı: `_scope` 'world' | 'package'.
-- Kurallar aynı — limiti aşan `too_large`'da, yüklenmiş sha atlanır,
-- onaysız olan yeniden döner, tavan aşılırsa hiçbir satır yazılmaz.
-- Dönüş: {upload: [sha...], too_large: [sha...]}.
--
-- ponytail: tek global advisory lock (099'daki gibi) — kullanıcı başına
-- kilide ancak darboğaz olursa geç; toplam tavan için yine global gerekir.
CREATE OR REPLACE FUNCTION public.media_reserve(
  _scope TEXT,
  _id    TEXT,
  _items JSONB
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid       UUID := auth.uid();
  v_world     TEXT := CASE WHEN _scope = 'world'   THEN _id END;
  v_package   TEXT := CASE WHEN _scope = 'package' THEN _id END;
  v_item      JSONB;
  v_sha       TEXT;
  v_ext       TEXT;
  v_kind      TEXT;
  v_mime      TEXT;
  v_bytes     BIGINT;
  v_max       BIGINT;
  v_uploaded  BOOLEAN;
  v_new       JSONB := '[]'::jsonb;   -- bulutta hiç olmayanlar
  v_new_bytes BIGINT := 0;
  v_upload    TEXT[] := '{}';
  v_too_large TEXT[] := '{}';
  v_u         RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_signed_in' USING ERRCODE = '42501';
  END IF;
  IF NOT public._media_scope_owner(_scope, _id, v_uid) THEN
    RAISE EXCEPTION 'not_scope_owner' USING ERRCODE = '42501';
  END IF;
  IF jsonb_typeof(_items) IS DISTINCT FROM 'array'
     OR jsonb_array_length(_items) > 500 THEN
    RAISE EXCEPTION 'invalid_items' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('media_reserve'));

  FOR v_item IN SELECT * FROM jsonb_array_elements(_items) LOOP
    v_sha   := lower(v_item->>'sha');
    v_ext   := lower(COALESCE(v_item->>'ext', ''));
    v_kind  := v_item->>'kind';
    v_mime  := lower(COALESCE(v_item->>'mime', ''));
    v_bytes := (v_item->>'bytes')::bigint;
    v_max   := public.world_media_max_bytes(v_kind);

    IF v_sha IS NULL OR v_sha !~ '^[0-9a-f]{64}$'
       OR v_ext !~ '^(\.[a-z0-9]{1,10})?$'
       OR v_max IS NULL
       OR v_bytes IS NULL OR v_bytes <= 0
       OR NOT (v_mime ~ '^(image|audio)/[a-z0-9.+-]+$'
               OR v_mime IN ('application/pdf', 'application/octet-stream')) THEN
      RAISE EXCEPTION 'invalid_item' USING ERRCODE = '22023',
        HINT = v_item::text;
    END IF;

    IF v_bytes > v_max THEN
      v_too_large := array_append(v_too_large, v_sha);
      CONTINUE;
    END IF;
    IF v_sha = ANY(v_upload) THEN
      CONTINUE;   -- aynı partide iki kez
    END IF;

    SELECT uploaded INTO v_uploaded FROM public.world_media
     WHERE sha256 = v_sha
       AND (world_id = v_world OR package_id = v_package);
    IF FOUND THEN
      IF NOT v_uploaded THEN
        v_upload := array_append(v_upload, v_sha);
      END IF;
      CONTINUE;
    END IF;

    v_upload := array_append(v_upload, v_sha);
    v_new := v_new || jsonb_build_object('sha', v_sha, 'ext', v_ext,
               'bytes', v_bytes, 'kind', v_kind, 'mime', v_mime);
    v_new_bytes := v_new_bytes + v_bytes;
  END LOOP;

  IF v_new_bytes > 0 THEN
    SELECT * INTO v_u FROM public._media_usage(v_uid);
    IF v_u.user_used + v_new_bytes > public.world_media_user_cap_bytes() THEN
      RAISE EXCEPTION 'media_user_full' USING ERRCODE = 'P0001',
        HINT = format('used=%s new=%s cap=%s', v_u.user_used, v_new_bytes,
                      public.world_media_user_cap_bytes());
    END IF;
    IF v_u.total_used + v_new_bytes > public.media_total_cap_bytes() THEN
      RAISE EXCEPTION 'media_pool_full' USING ERRCODE = 'P0001',
        HINT = format('used=%s new=%s cap=%s', v_u.total_used, v_new_bytes,
                      public.media_total_cap_bytes());
    END IF;

    INSERT INTO public.world_media
      (world_id, package_id, sha256, ext, bytes, kind, mime)
    SELECT v_world, v_package, n->>'sha', n->>'ext', (n->>'bytes')::bigint,
           n->>'kind', n->>'mime'
      FROM jsonb_array_elements(v_new) n;
  END IF;

  RETURN jsonb_build_object('upload', to_jsonb(v_upload),
                            'too_large', to_jsonb(v_too_large));
END $$;

REVOKE ALL ON FUNCTION public.media_reserve(TEXT, TEXT, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.media_reserve(TEXT, TEXT, JSONB) TO authenticated;

-- PUT'u biten sha'lar okunabilir olur. Onay yalan söylerse zarar gören tek
-- şey çağıranın kendi dünyası ya da paketi.
CREATE OR REPLACE FUNCTION public.media_confirm(
  _scope TEXT,
  _id    TEXT,
  _shas  TEXT[]
) RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_n INT;
BEGIN
  IF NOT public._media_scope_owner(_scope, _id, auth.uid()) THEN
    RAISE EXCEPTION 'not_scope_owner' USING ERRCODE = '42501';
  END IF;
  UPDATE public.world_media
     SET uploaded = TRUE
   WHERE (world_id   = CASE WHEN _scope = 'world'   THEN _id END
       OR package_id = CASE WHEN _scope = 'package' THEN _id END)
     AND sha256 = ANY(_shas)
     AND NOT uploaded;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END $$;

REVOKE ALL ON FUNCTION public.media_confirm(TEXT, TEXT, TEXT[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.media_confirm(TEXT, TEXT, TEXT[]) TO authenticated;

-- ── Worker RPC'leri (service_role) ────────────────────────────────────────
-- Worker her imza isteğinde bunlardan TEK birini çağırır: N sha, bir sorgu.

-- PUT imzası: yalnız kapsamın sahibine, yalnız o kapsamda rezerve edilmiş
-- sha'lar. `bytes` ve `mime` imzaya bağlanır.
CREATE OR REPLACE FUNCTION public.media_sign_put(
  p_user  UUID,
  p_scope TEXT,
  p_id    TEXT,
  p_shas  TEXT[]
) RETURNS TABLE (sha256 TEXT, r2_key TEXT, bytes BIGINT, mime TEXT)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT m.sha256,
         public.media_r2_key(m.world_id, m.package_id, m.sha256, m.ext),
         m.bytes, m.mime
    FROM public.world_media m
   WHERE public._media_scope_owner(p_scope, p_id, p_user)
     AND m.sha256 = ANY(p_shas)
     AND (m.world_id   = CASE WHEN p_scope = 'world'   THEN p_id END
       OR m.package_id = CASE WHEN p_scope = 'package' THEN p_id END);
$$;

-- GET imzası: çağıranın üyesi olduğu bir dünyada ya da sahibi olduğu bir
-- pakette yüklenmiş sha. İstemci kapsamı söylemiyor: ref yalnız sha taşıyor.
CREATE OR REPLACE FUNCTION public.media_sign_get(
  p_user UUID,
  p_shas TEXT[]
) RETURNS TABLE (sha256 TEXT, r2_key TEXT)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT DISTINCT ON (m.sha256) m.sha256,
         public.media_r2_key(m.world_id, m.package_id, m.sha256, m.ext)
    FROM public.world_media m
   WHERE m.sha256 = ANY(p_shas)
     AND m.uploaded
     AND (EXISTS (SELECT 1 FROM public.world_members wm
                   WHERE wm.world_id = m.world_id AND wm.user_id = p_user)
          OR EXISTS (SELECT 1 FROM public.user_packages up
                      WHERE up.id = m.package_id AND up.owner_id = p_user))
   ORDER BY m.sha256, m.created_at;
$$;

REVOKE ALL ON FUNCTION public.media_sign_put(UUID, TEXT, TEXT, TEXT[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.media_sign_get(UUID, TEXT[])             FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.media_sign_put(UUID, TEXT, TEXT, TEXT[]) TO service_role;
GRANT EXECUTE ON FUNCTION public.media_sign_get(UUID, TEXT[])             TO service_role;

-- 099'un dünyaya bağlı RPC'leri: yerlerini yukarıdakiler aldı.
DROP FUNCTION IF EXISTS public.world_media_reserve(TEXT, JSONB);
DROP FUNCTION IF EXISTS public.world_media_confirm(TEXT, TEXT[]);
DROP FUNCTION IF EXISTS public.world_media_sign_put(UUID, TEXT, TEXT[]);
DROP FUNCTION IF EXISTS public.world_media_sign_get(UUID, TEXT[]);

NOTIFY pgrst, 'reload schema';
