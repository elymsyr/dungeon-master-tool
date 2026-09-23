-- ============================================================================
-- 099_world_media.sql — Faz 5d: multiplayer dünyanın medyası kalıcı olarak R2'de
-- ============================================================================
-- Bkz. docs/online-sync-redesign.md §4.8.3 (Faz 5d).
--
-- Neden: medya bugüne kadar talep üzerine akıyordu (092) — oyuncu eksik sha'yı
-- `missing_shas`'e yazıyor, DM'in AÇIK cihazı onu LRU'lu transient havuza
-- yüklüyordu. DM'in ikinci cihazına görsel hiç gelmiyordu (kendi uid'sinden
-- gelen talebi "kendim" sayıyordu) ve DM çevrimdışıyken oyuncunun yeni cihazı
-- görselsiz kalıyordu. Yeni model: multiplayer açılınca dünyanın bütün medyası
-- `worlds/{worldId}/{sha}{ext}` altında, dünya yaşadıkça durur.
--
-- Ne yapar:
--   A) Sabitler: toplam R2 tavanı (9 GB, `pub/` dahil), kişi başı dünya
--      medyası (1 GB), tür başına dosya limiti.
--   B) `world_media` — dünyanın buluttaki medya listesi. Satır rezervasyonla
--      doğar (`uploaded = false`), PUT bitince istemci onaylar.
--   C) Tahliye kuyruğu `r2_evict_queue` adını alır (tek sınıfa bağlı değil),
--      her satır tam `r2_key` taşır. Dünya medyasının satırı silinince (tek
--      tek ya da dünya CASCADE ile) key kuyruğa düşer, cron R2'den siler.
--   D) İstemci RPC'leri: `world_media_reserve`, `world_media_confirm`,
--      `get_media_quota`. Worker RPC'leri (service_role): `world_media_sign_put`,
--      `world_media_sign_get` — toplu imzanın tek izin sorgusu.
--   E) `pub_asset_reserve` iki havuz tavanı yerine tek toplam tavana bakar.
--   F) Transient'in sökülmesi: `transient_shares`, reserve/touch/access
--      RPC'leri, `missing_shas`. Kalan transient objeler önce kuyruğa atılır.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run.
-- Doğrulama: scripts/verify_099.sql
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM A — Sabitler (055/065/089'un değiştirilebilir IMMUTABLE fn kalıbı)
-- ──────────────────────────────────────────────────────────────────────────

-- R2 free tier 10 GB; 1 GB pay bırakılıyor. `pub/` ve `worlds/` birlikte.
CREATE OR REPLACE FUNCTION public.media_total_cap_bytes()
RETURNS BIGINT LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $$ SELECT (9::bigint * 1024 * 1024 * 1024) $$;

-- Kullanıcının BÜTÜN dünyalarının medyası toplamı.
CREATE OR REPLACE FUNCTION public.world_media_user_cap_bytes()
RETURNS BIGINT LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $$ SELECT (1::bigint * 1024 * 1024 * 1024) $$;

-- Tür başına dosya limiti. Anahtarlar istemcinin `MediaKind.wireName`'i;
-- bilinmeyen tür NULL döner ve rezervasyon onu reddeder.
CREATE OR REPLACE FUNCTION public.world_media_max_bytes(_kind TEXT)
RETURNS BIGINT LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT CASE _kind
    WHEN 'battle_map'         THEN 10::bigint * 1024 * 1024  -- dünya + savaş haritası
    WHEN 'world_entity_image' THEN  5::bigint * 1024 * 1024  -- diğer her şey
    WHEN 'world_audio'        THEN 10::bigint * 1024 * 1024
    WHEN 'world_pdf'          THEN 20::bigint * 1024 * 1024
  END
$$;

GRANT EXECUTE ON FUNCTION public.media_total_cap_bytes()        TO authenticated;
GRANT EXECUTE ON FUNCTION public.world_media_user_cap_bytes()   TO authenticated;
GRANT EXECUTE ON FUNCTION public.world_media_max_bytes(TEXT)    TO authenticated;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM B — world_media
-- ──────────────────────────────────────────────────────────────────────────
-- Kimlik (world_id, sha256): aynı görsel iki dünyada iki satır, iki obje —
-- dünya başına prefix silmeyi tek CASCADE'e indiriyor, bedeli dedup'un
-- olmaması (belgede bilinçli sınır).
CREATE TABLE IF NOT EXISTS public.world_media (
  world_id   TEXT        NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  sha256     TEXT        NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
  -- R2 key'inin parçası: yalnız nokta + kısa alfanümerik ya da boş.
  ext        TEXT        NOT NULL CHECK (ext ~ '^(\.[a-z0-9]{1,10})?$'),
  bytes      BIGINT      NOT NULL CHECK (bytes > 0),
  kind       TEXT        NOT NULL,
  mime       TEXT        NOT NULL,
  -- Rezervasyon satırı PUT'tan önce yazılır; istemci PUT bitince onaylar.
  -- Onaysız satır okunamaz (imza verilmez) ama kotaya sayılır.
  uploaded   BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (world_id, sha256)
);
-- İmza (get) sha ile arıyor, dünyayı bilmeden.
CREATE INDEX IF NOT EXISTS idx_world_media_sha ON public.world_media (sha256);

ALTER TABLE public.world_media ENABLE ROW LEVEL SECURITY;

-- Sahip ve üyeler listeyi okur (DM'in cihazı neyin bulutta olduğunu buradan
-- bilir). Yazma RPC'den: sahiplik + kota tek yerde. Silme sahibin — yetim
-- medyayı istemci temizliyor.
DROP POLICY IF EXISTS "world_media: members read" ON public.world_media;
CREATE POLICY "world_media: members read" ON public.world_media
  FOR SELECT USING (public.is_world_member(world_id));

DROP POLICY IF EXISTS "world_media: owner delete" ON public.world_media;
CREATE POLICY "world_media: owner delete" ON public.world_media
  FOR DELETE USING (EXISTS (
    SELECT 1 FROM public.worlds w
     WHERE w.id = world_media.world_id AND w.owner_id = (SELECT auth.uid())
  ));

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM C — Tahliye kuyruğu: transient_evict_queue → r2_evict_queue
-- ──────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF to_regclass('public.transient_evict_queue') IS NOT NULL
     AND to_regclass('public.r2_evict_queue') IS NULL THEN
    ALTER TABLE public.transient_evict_queue RENAME TO r2_evict_queue;
    ALTER INDEX IF EXISTS public.transient_evict_queue_pkey
      RENAME TO r2_evict_queue_pkey;
    ALTER INDEX IF EXISTS public.idx_transient_evict_queue_enq
      RENAME TO idx_r2_evict_queue_enq;
    ALTER SEQUENCE IF EXISTS public.transient_evict_queue_id_seq
      RENAME TO r2_evict_queue_id_seq;
  END IF;
END $$;

-- Transient objeler R2'de yetim kalmasın: tablo düşmeden önce hepsi kuyruğa.
-- NULL `r2_key` eski transient kalıbıydı; tam key'e çevrilir.
DO $$
BEGIN
  IF to_regclass('public.transient_shares') IS NOT NULL THEN
    INSERT INTO public.r2_evict_queue (sha256, ext, uploader_id, r2_key)
    SELECT sha256, ext, uploader_id,
           'transient/' || uploader_id || '/' || sha256 || ext
      FROM public.transient_shares;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_schema = 'public' AND table_name = 'r2_evict_queue'
                AND column_name = 'uploader_id') THEN
    UPDATE public.r2_evict_queue
       SET r2_key = 'transient/' || uploader_id || '/' || sha256 || ext
     WHERE r2_key IS NULL;
  END IF;
END $$;

ALTER TABLE public.r2_evict_queue DROP COLUMN IF EXISTS uploader_id;
ALTER TABLE public.r2_evict_queue ALTER COLUMN r2_key SET NOT NULL;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM D — Satır silinince obje kuyruğa
-- ──────────────────────────────────────────────────────────────────────────
-- Trigger'da, RPC'de değil: dünya silme / multiplayer kapatma (worlds CASCADE)
-- ve hesap silme (auth.users → worlds CASCADE) RPC'ye hiç uğramıyor. Onaysız
-- satırın objesi de kuyruğa girer — PUT bitip onay kopmuş olabilir; olmayan
-- key'i silmek no-op.
CREATE OR REPLACE FUNCTION public.enqueue_world_media_evict()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  INSERT INTO public.r2_evict_queue (sha256, ext, r2_key)
    VALUES (OLD.sha256, OLD.ext,
            'worlds/' || OLD.world_id || '/' || OLD.sha256 || OLD.ext);
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS trg_world_media_evict ON public.world_media;
CREATE TRIGGER trg_world_media_evict
  AFTER DELETE ON public.world_media
  FOR EACH ROW EXECUTE FUNCTION public.enqueue_world_media_evict();

-- 090'ın kuralı sınıfa göre: kuyruktaki satır bayatlamışsa (obje o arada
-- yeniden canlandıysa) kuyruktan düşer ama worker'a DÖNMEZ. İçerik-adresli
-- key'lerde bu gerçek bir yarış — silinen sha birkaç dakika sonra aynı
-- dünyaya yeniden yüklenebiliyor.
DROP FUNCTION IF EXISTS public.transient_evict_pop(INT);
DROP FUNCTION IF EXISTS public.r2_evict_pop(INT);
CREATE FUNCTION public.r2_evict_pop(_limit INT DEFAULT 20)
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
           ELSE TRUE
         END;
END $$;

REVOKE ALL ON FUNCTION public.r2_evict_pop(INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.r2_evict_pop(INT) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.r2_evict_pop(INT) TO service_role;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM E — İstemci RPC'leri
-- ──────────────────────────────────────────────────────────────────────────

-- Kullanıcının dünya medyası + R2'nin toplam doluluğu. Rezervasyon ve
-- "multiplayer aç"ın ön hesabı aynı sayıyı okusun diye tek yerde.
CREATE OR REPLACE FUNCTION public._media_usage(_uid UUID)
RETURNS TABLE (user_used BIGINT, total_used BIGINT)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    (SELECT COALESCE(SUM(m.bytes), 0)::bigint
       FROM public.world_media m
       JOIN public.worlds w ON w.id = m.world_id
      WHERE w.owner_id = _uid),
    ((SELECT COALESCE(SUM(bytes), 0) FROM public.world_media)
     + (SELECT COALESCE(SUM(bytes), 0) FROM public.pub_assets))::bigint
$$;

REVOKE ALL ON FUNCTION public._media_usage(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._media_usage(UUID) FROM anon, authenticated;

-- "Multiplayer aç" bu sayıya bakıp dünyayı hiç yayınlamadan reddedebilir.
CREATE OR REPLACE FUNCTION public.get_media_quota()
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_u   RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_signed_in' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_u FROM public._media_usage(v_uid);
  RETURN jsonb_build_object(
    'user_used',  v_u.user_used,
    'user_cap',   public.world_media_user_cap_bytes(),
    'total_used', v_u.total_used,
    'total_cap',  public.media_total_cap_bytes()
  );
END $$;

REVOKE ALL ON FUNCTION public.get_media_quota() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_media_quota() TO authenticated;

-- Yüklemeden önce: `_items` = [{sha, ext, bytes, kind, mime}, ...].
--   * Çağıran dünyanın sahibi değilse reddedilir.
--   * Limiti aşan dosya reddedilmez, `too_large`'da döner (parti sürsün).
--   * Zaten yüklenmiş sha atlanır; rezerve edilip yüklenmemiş olan yeniden
--     döner (yarıda kalan tur tamamlanır). Kotaya yalnız YENİ bayt sayılır.
--   * Kişi başı ya da toplam tavan aşılırsa hiçbir satır yazılmaz.
-- Dönüş: {upload: [sha...], too_large: [sha...]}.
--
-- ponytail: tek global advisory lock — iki eşzamanlı rezervasyon tavanı birlikte
-- aşmasın. Yükleme hacmi düşük; darboğaz olursa kullanıcı başına kilide geç
-- (toplam tavan için yine global olanı gerekir).
CREATE OR REPLACE FUNCTION public.world_media_reserve(_world TEXT, _items JSONB)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid       UUID := auth.uid();
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
  IF NOT EXISTS (SELECT 1 FROM public.worlds
                  WHERE id = _world AND owner_id = v_uid) THEN
    RAISE EXCEPTION 'not_world_owner' USING ERRCODE = '42501';
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
     WHERE world_id = _world AND sha256 = v_sha;
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

    INSERT INTO public.world_media (world_id, sha256, ext, bytes, kind, mime)
    SELECT _world, n->>'sha', n->>'ext', (n->>'bytes')::bigint,
           n->>'kind', n->>'mime'
      FROM jsonb_array_elements(v_new) n;
  END IF;

  RETURN jsonb_build_object('upload', to_jsonb(v_upload),
                            'too_large', to_jsonb(v_too_large));
END $$;

REVOKE ALL ON FUNCTION public.world_media_reserve(TEXT, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.world_media_reserve(TEXT, JSONB) TO authenticated;

-- PUT'u biten sha'lar okunabilir olur. Onay yalan söylerse zarar gören tek
-- dünya çağıranın kendi dünyası.
CREATE OR REPLACE FUNCTION public.world_media_confirm(_world TEXT, _shas TEXT[])
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_n INT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.worlds
                  WHERE id = _world AND owner_id = auth.uid()) THEN
    RAISE EXCEPTION 'not_world_owner' USING ERRCODE = '42501';
  END IF;
  UPDATE public.world_media
     SET uploaded = TRUE
   WHERE world_id = _world AND sha256 = ANY(_shas) AND NOT uploaded;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END $$;

REVOKE ALL ON FUNCTION public.world_media_confirm(TEXT, TEXT[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.world_media_confirm(TEXT, TEXT[]) TO authenticated;

-- ── Worker RPC'leri (service_role) ────────────────────────────────────────
-- Worker her imza isteğinde bunlardan TEK birini çağırır: N sha, bir sorgu.

-- PUT imzası: yalnız dünyanın sahibi, yalnız rezerve edilmiş sha. Dönen
-- `bytes` ve `mime` imzaya bağlanır — R2 farklı boyuttaki gövdeyi reddeder.
CREATE OR REPLACE FUNCTION public.world_media_sign_put(
  p_user  UUID,
  p_world TEXT,
  p_shas  TEXT[]
) RETURNS TABLE (sha256 TEXT, ext TEXT, bytes BIGINT, mime TEXT)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT m.sha256, m.ext, m.bytes, m.mime
    FROM public.world_media m
    JOIN public.worlds w ON w.id = m.world_id
   WHERE m.world_id = p_world
     AND w.owner_id = p_user
     AND m.sha256 = ANY(p_shas);
$$;

-- GET imzası: çağıranın üyesi (sahip dahil — DM'in de üyelik satırı var)
-- olduğu herhangi bir dünyada yüklenmiş sha. İstemci dünyayı söylemiyor:
-- ref yalnız sha taşıyor.
CREATE OR REPLACE FUNCTION public.world_media_sign_get(
  p_user UUID,
  p_shas TEXT[]
) RETURNS TABLE (sha256 TEXT, world_id TEXT, ext TEXT)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT DISTINCT ON (m.sha256) m.sha256, m.world_id, m.ext
    FROM public.world_media m
    JOIN public.world_members wm
      ON wm.world_id = m.world_id AND wm.user_id = p_user
   WHERE m.sha256 = ANY(p_shas)
     AND m.uploaded
   ORDER BY m.sha256, m.created_at;
$$;

REVOKE ALL ON FUNCTION public.world_media_sign_put(UUID, TEXT, TEXT[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.world_media_sign_get(UUID, TEXT[])       FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.world_media_sign_put(UUID, TEXT, TEXT[]) TO service_role;
GRANT EXECUTE ON FUNCTION public.world_media_sign_get(UUID, TEXT[])       TO service_role;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM F — pub/ tarafı: tek toplam tavan, yeni kuyruk
-- ──────────────────────────────────────────────────────────────────────────
-- 089'un gövdesi; değişen tek şey havuz kontrolü: `pinned_pool_cap_bytes`
-- (5 GB) yerine dünya medyasıyla paylaşılan `media_total_cap_bytes` (9 GB).
CREATE OR REPLACE FUNCTION public.pub_asset_reserve(
  _sha     TEXT,
  _ext     TEXT,
  _bytes   BIGINT,
  _mime    TEXT,
  _ref_key TEXT
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid        UUID := auth.uid();
  v_exists     BOOLEAN;
  v_user_used  BIGINT;
  v_u          RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_signed_in' USING ERRCODE = '42501';
  END IF;
  IF _sha IS NULL OR _sha !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'invalid_sha' USING ERRCODE = '22023';
  END IF;
  IF _bytes IS NULL OR _bytes <= 0 THEN
    RAISE EXCEPTION 'invalid_bytes' USING ERRCODE = '22023';
  END IF;
  IF _ref_key IS NULL OR _ref_key = '' THEN
    RAISE EXCEPTION 'invalid_ref_key' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('media_reserve'));

  SELECT TRUE INTO v_exists FROM public.pub_assets WHERE sha256 = _sha;
  v_exists := COALESCE(v_exists, FALSE);

  -- Toplam tavan yalnızca GERÇEKTEN yeni bayt için: dedup hit yer kaplamaz.
  IF NOT v_exists THEN
    SELECT * INTO v_u FROM public._media_usage(v_uid);
    IF v_u.total_used + _bytes > public.media_total_cap_bytes() THEN
      RAISE EXCEPTION 'pool_full' USING ERRCODE = 'P0001',
        HINT = format('used=%s new=%s cap=%s',
                      v_u.total_used, _bytes, public.media_total_cap_bytes());
    END IF;
  END IF;

  SELECT COALESCE(SUM(a.bytes), 0) INTO v_user_used
    FROM public.pub_assets a
   WHERE a.sha256 <> _sha
     AND EXISTS (SELECT 1 FROM public.pub_asset_refs r
                  WHERE r.sha256 = a.sha256 AND r.owner_id = v_uid);
  IF v_user_used + _bytes > public.pinned_per_user_cap_bytes() THEN
    RAISE EXCEPTION 'pinned_user_full' USING ERRCODE = 'P0001',
      HINT = format('used=%s new=%s cap=%s',
                    v_user_used, _bytes, public.pinned_per_user_cap_bytes());
  END IF;

  INSERT INTO public.pub_assets (sha256, ext, bytes, mime_type)
    VALUES (_sha, COALESCE(NULLIF(_ext, ''), '.png'), _bytes,
            COALESCE(NULLIF(_mime, ''), 'application/octet-stream'))
    ON CONFLICT (sha256) DO NOTHING;

  INSERT INTO public.pub_asset_refs (sha256, owner_id, ref_key)
    VALUES (_sha, v_uid, _ref_key)
    ON CONFLICT DO NOTHING;

  RETURN jsonb_build_object(
    'ok', TRUE,
    'exists', v_exists,
    'key', 'pub/' || _sha || COALESCE(NULLIF(_ext, ''), '.png'),
    'user_used', v_user_used
  );
END $$;

GRANT EXECUTE ON FUNCTION
  public.pub_asset_reserve(TEXT, TEXT, BIGINT, TEXT, TEXT) TO authenticated;

-- 089'un gövdesi; yeni kuyruğa yazar (uploader_id kolonu gitti).
CREATE OR REPLACE FUNCTION public.drop_orphan_pub_asset()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_ext TEXT;
BEGIN
  IF EXISTS (SELECT 1 FROM public.pub_asset_refs WHERE sha256 = OLD.sha256) THEN
    RETURN NULL;   -- başka listing hâlâ kullanıyor
  END IF;

  SELECT ext INTO v_ext FROM public.pub_assets WHERE sha256 = OLD.sha256;
  IF NOT FOUND THEN
    RETURN NULL;   -- pub_assets zaten gitmiş (CASCADE bu yönde de tetikler)
  END IF;

  INSERT INTO public.r2_evict_queue (sha256, ext, r2_key)
    VALUES (OLD.sha256, v_ext, 'pub/' || OLD.sha256 || v_ext);
  DELETE FROM public.pub_assets WHERE sha256 = OLD.sha256;
  RETURN NULL;
END $$;

-- Admin Storage sekmesi. Tek tavan, iki kullanıcı: marketplace (`pub/`) ve
-- dünya medyası (`worlds/`).
CREATE OR REPLACE FUNCTION public.get_r2_pool_stats()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required' USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'cap_bytes', public.media_total_cap_bytes(),
    'pinned', (
      SELECT jsonb_build_object(
        'used_bytes',   COALESCE(SUM(bytes), 0),
        'object_count', count(*),
        'dedup_saved_bytes', COALESCE((
          SELECT SUM(a.bytes * (r.n - 1))
            FROM public.pub_assets a
            JOIN (SELECT sha256, count(*) AS n
                    FROM public.pub_asset_refs GROUP BY sha256) r
              ON r.sha256 = a.sha256
        ), 0)
      ) FROM public.pub_assets
    ),
    'world_media', (
      SELECT jsonb_build_object(
        'used_bytes',     COALESCE(SUM(bytes), 0),
        'object_count',   count(*),
        'world_count',    count(DISTINCT world_id),
        'user_cap_bytes', public.world_media_user_cap_bytes()
      ) FROM public.world_media
    ),
    'evict_queue_depth', (SELECT count(*) FROM public.r2_evict_queue)
  );
END $$;

REVOKE ALL ON FUNCTION public.get_r2_pool_stats() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_r2_pool_stats() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_r2_pool_stats() TO authenticated;

-- 060'ın gövdesi; yalnız yorum değişti (eski katman adı gitti).
CREATE OR REPLACE FUNCTION public.get_asset_access(p_user_id UUID, p_r2_key TEXT)
RETURNS BOOLEAN
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  -- Emekli sayılan katman (`{userId}/…`): asset community_assets'te olmalı;
  -- uploader her zaman erişir, aksi halde uploader ile ortak dünya üyeliği.
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

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM G — Transient'in sökülmesi
-- ──────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication_tables
              WHERE pubname = 'supabase_realtime'
                AND schemaname = 'public' AND tablename = 'transient_shares') THEN
    ALTER PUBLICATION supabase_realtime DROP TABLE public.transient_shares;
  END IF;
END $$;

DROP TABLE IF EXISTS public.transient_shares;

DROP FUNCTION IF EXISTS public.get_transient_access(UUID, UUID);
DROP FUNCTION IF EXISTS public.transient_reserve(BIGINT, TEXT);
DROP FUNCTION IF EXISTS public.transient_touch(TEXT);
DROP FUNCTION IF EXISTS public.transient_max_file_bytes();
DROP FUNCTION IF EXISTS public.transient_pool_cap_bytes();
DROP FUNCTION IF EXISTS public.pinned_pool_cap_bytes();

-- Talep-üzerine medya (092): oyuncu artık bir şey istemiyor, bayt zaten bulutta.
DROP FUNCTION IF EXISTS public.report_missing_shas(TEXT, TEXT[]);
DROP FUNCTION IF EXISTS public.max_missing_shas();
ALTER TABLE public.world_members DROP COLUMN IF EXISTS missing_shas;

NOTIFY pgrst, 'reload schema';
