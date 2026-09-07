-- ============================================================================
-- 089_media_pool_budgets.sql — R2 havuzunun iki sınıfa bölünmesi
-- ============================================================================
-- Neden (docs/media-storage-redesign.md → "R2 havuzunun iki sınıfı"):
--   Bugün tek bir 10 GB'lık transient havuzu var ve marketplace medyası
--   `{userId}/{sha}` altında kullanıcı-prefix'li duruyor → iki kişi aynı
--   görseli yayınlarsa iki kopya. Ayrıca `pinned` ile `transient` tek bütçeyi
--   paylaşsaydı, pinned büyüdükçe LRU'nun yiyebileceği alan sıfıra iner ve
--   paylaşımlar sessizce patlardı.
--
-- Yeni bölünme:
--   • pinned    (`pub/{sha}.{ext}`)          : 5 GB tavan, eviction YOK,
--                                              refcount 0 → silinir,
--                                              yayıncı başına 500 MB.
--   • transient (`transient/{uid}/{sha}.{ext}`): 5 GB rezerv, kendi içinde LRU.
--
-- Bu migration'da değişen:
--   1. transient: per-user cap KALDIRILDI (kota diye bir şey yok), yerine
--      dosya başına 100 MB emniyet kapağı; pool 10 GB → 5 GB.
--   2. pub_assets + pub_asset_refs (içerik-adresli dedup + refcount).
--   3. transient_evict_queue'ya `r2_key` — kuyruk artık transient'e özel değil,
--      pinned düşüşleri de aynı worker sweep'inden geçer.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

-- ── 1. Havuz bütçesi sabitleri ─────────────────────────────────────────────
-- Hepsi elle seçilmiş sayılar; ölçüm çıkınca ayarlanır. Tek noktadan
-- değiştirilebilir IMMUTABLE fn kalıbı (055 / 065).

CREATE OR REPLACE FUNCTION public.transient_pool_cap_bytes()
RETURNS BIGINT LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $$ SELECT (5::bigint * 1024 * 1024 * 1024) $$;   -- 5 GB transient rezervi

-- Kota değil, emniyet kapağı: tek bir upload havuzu sarsmasın.
CREATE OR REPLACE FUNCTION public.transient_max_file_bytes()
RETURNS BIGINT LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $$ SELECT (100::bigint * 1024 * 1024) $$;        -- 100 MB / dosya

CREATE OR REPLACE FUNCTION public.pinned_pool_cap_bytes()
RETURNS BIGINT LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $$ SELECT (5::bigint * 1024 * 1024 * 1024) $$;   -- 5 GB marketplace dilimi

CREATE OR REPLACE FUNCTION public.pinned_per_user_cap_bytes()
RETURNS BIGINT LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $$ SELECT (500::bigint * 1024 * 1024) $$;        -- 500 MB / yayıncı

GRANT EXECUTE ON FUNCTION public.transient_max_file_bytes()   TO authenticated;
GRANT EXECUTE ON FUNCTION public.pinned_pool_cap_bytes()      TO authenticated;
GRANT EXECUTE ON FUNCTION public.pinned_per_user_cap_bytes()  TO authenticated;

-- ── 2. transient_evict_queue — genel amaçlı R2 silme kuyruğu ───────────────
-- `r2_key` NULL ise eski davranış (`transient/{uploader}/{sha}{ext}`); pinned
-- düşüşleri tam key yazar. Worker sweep'i tek endpoint olarak kalır.
ALTER TABLE public.transient_evict_queue
  ADD COLUMN IF NOT EXISTS r2_key TEXT;

-- RETURNS TABLE'a yeni kolon eklemek dönüş tipini değiştirir; CREATE OR REPLACE
-- bunu yapamaz (42P13). Önce düşür. Çağıranı yalnızca Worker sweep'i (service_role).
DROP FUNCTION IF EXISTS public.transient_evict_pop(INT);

CREATE FUNCTION public.transient_evict_pop(_limit INT DEFAULT 20)
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
  )
  DELETE FROM public.transient_evict_queue q
   USING picked
   WHERE q.id = picked.id
  RETURNING q.id, q.sha256, q.ext, q.uploader_id, q.r2_key;
END $$;

REVOKE ALL ON FUNCTION public.transient_evict_pop(INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.transient_evict_pop(INT) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.transient_evict_pop(INT) TO service_role;

-- ── 3. transient_reserve — per-user cap kaldırıldı ─────────────────────────
-- Eski gövde (065) iki kapı tutuyordu: per-user 100 MB + global LRU. Yeni
-- modelde kullanıcı başına transient sınırı YOK: havuz genelinde LRU zaten en
-- eski DOKUNULANI atar, yeni yükleneni değil — tek bir masanın anlık yükü
-- başka masaların taze içeriğini öldürmez. Kalan tek kapı dosya başına tavan.
CREATE OR REPLACE FUNCTION public.transient_reserve(
  _bytes BIGINT,
  _world TEXT
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid         UUID := auth.uid();
  v_global_used BIGINT;
  v_victim      RECORD;
  v_evicted     INT := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_signed_in' USING ERRCODE = '42501';
  END IF;
  IF _bytes IS NULL OR _bytes <= 0 THEN
    RAISE EXCEPTION 'invalid_bytes' USING ERRCODE = '22023';
  END IF;
  IF _bytes > public.transient_max_file_bytes() THEN
    RAISE EXCEPTION 'transient_file_too_large' USING ERRCODE = 'P0001',
      HINT = format('new=%s max=%s', _bytes, public.transient_max_file_bytes());
  END IF;

  -- Global LRU eviction — yeni dosyaya yer açana kadar en eski dokunulanı sil.
  LOOP
    SELECT COALESCE(SUM(bytes), 0) INTO v_global_used
      FROM public.transient_shares;
    EXIT WHEN v_global_used + _bytes <= public.transient_pool_cap_bytes();

    SELECT id, uploader_id, sha256, ext
      INTO v_victim
      FROM public.transient_shares
     ORDER BY last_used_at ASC
     LIMIT 1;
    EXIT WHEN v_victim.id IS NULL;

    INSERT INTO public.transient_evict_queue (sha256, ext, uploader_id)
      VALUES (v_victim.sha256, v_victim.ext, v_victim.uploader_id);
    DELETE FROM public.transient_shares WHERE id = v_victim.id;
    v_evicted := v_evicted + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', TRUE,
    'global_used', v_global_used,
    'evicted', v_evicted
  );
END $$;

GRANT EXECUTE ON FUNCTION public.transient_reserve(BIGINT, TEXT) TO authenticated;

-- Artık okuyucusu yok. Eski client'lar bunu hiç çağırmıyordu (yalnızca
-- transient_reserve içinden kullanılıyordu), o yüzden düşürmek güvenli.
DROP FUNCTION IF EXISTS public.transient_per_user_cap_bytes();

-- ── 4. pub_assets — içerik-adresli marketplace medyası ─────────────────────
-- Key şeması `pub/{sha}.{ext}`: kullanıcı prefix'i YOK, dolayısıyla iki kişi
-- aynı görseli yayınlarsa tek kopya durur.
CREATE TABLE IF NOT EXISTS public.pub_assets (
  sha256     TEXT PRIMARY KEY CHECK (sha256 ~ '^[0-9a-f]{64}$'),
  ext        TEXT   NOT NULL DEFAULT '.png',
  bytes      BIGINT NOT NULL CHECK (bytes > 0),
  mime_type  TEXT   NOT NULL DEFAULT 'application/octet-stream',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Refcount SAYIM olarak tutulur, sayaç kolonu olarak değil: sayaç drift eder,
-- satır etmez (bir listing iki kez release edilirse ikinci DELETE no-op'tur).
CREATE TABLE IF NOT EXISTS public.pub_asset_refs (
  sha256     TEXT NOT NULL REFERENCES public.pub_assets(sha256) ON DELETE CASCADE,
  owner_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  ref_key    TEXT NOT NULL,   -- listing/paket kimliği; aynı sha birden çok
                              -- yayında geçebilir, her biri ayrı ref.
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (sha256, owner_id, ref_key)
);
CREATE INDEX IF NOT EXISTS idx_pub_asset_refs_owner
  ON public.pub_asset_refs (owner_id);

ALTER TABLE public.pub_assets     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pub_asset_refs ENABLE ROW LEVEL SECURITY;
-- Client'a doğrudan policy verilmiyor: tüm yazma/okuma aşağıdaki SECURITY
-- DEFINER RPC'lerinden geçer (worker service_role ile RLS'i zaten bypass eder).

-- ── 5. pub_asset_reserve — yayın öncesi dedup + cap kontrolü ───────────────
-- Client yayın yolunda her medya için çağırır. `exists=true` dönerse R2 PUT
-- ATLANIR — obje zaten havuzda. Refcount her hâlükârda artar.
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
  v_pool_used  BIGINT;
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

  SELECT TRUE INTO v_exists FROM public.pub_assets WHERE sha256 = _sha;
  v_exists := COALESCE(v_exists, FALSE);

  -- Pool tavanı yalnızca GERÇEKTEN yeni bayt için: dedup hit yeni yer kaplamaz.
  IF NOT v_exists THEN
    SELECT COALESCE(SUM(bytes), 0) INTO v_pool_used FROM public.pub_assets;
    IF v_pool_used + _bytes > public.pinned_pool_cap_bytes() THEN
      RAISE EXCEPTION 'pool_full' USING ERRCODE = 'P0001',
        HINT = format('used=%s new=%s cap=%s',
                      v_pool_used, _bytes, public.pinned_pool_cap_bytes());
    END IF;
  END IF;

  -- Yayıncı payı: refslediği DISTINCT sha'ların toplam baytı. Aynı sha'yı iki
  -- listing'de kullanmak payı iki kez saymaz — depoda tek kopya var.
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
    'exists', v_exists,          -- true → R2 PUT atla
    'key', 'pub/' || _sha || COALESCE(NULLIF(_ext, ''), '.png'),
    'user_used', v_user_used
  );
END $$;

GRANT EXECUTE ON FUNCTION
  public.pub_asset_reserve(TEXT, TEXT, BIGINT, TEXT, TEXT) TO authenticated;

-- ── 6. Refcount düşüşü — AFTER DELETE trigger ─────────────────────────────
-- RPC'de değil trigger'da: `pub_asset_refs.owner_id` auth.users'a CASCADE'li,
-- yani hesap silme ref satırlarını RPC'ye hiç uğramadan yok eder. Sayımı
-- burada yapmak, "son ref gitti → obje kimseye lazım değil" kuralının TEK
-- yerde durmasını sağlar; release / moderasyon / hesap silme aynı yoldan geçer.
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

  -- R2 silimi worker sweep'ine bırakılır; uploader_id kuyruk şemasının eski
  -- (transient) kolonu, pinned satırlarda anlamsız — `r2_key` yetkilidir.
  INSERT INTO public.transient_evict_queue (sha256, ext, uploader_id, r2_key)
    VALUES (OLD.sha256, v_ext,
            '00000000-0000-0000-0000-000000000000'::uuid,
            'pub/' || OLD.sha256 || v_ext);
  DELETE FROM public.pub_assets WHERE sha256 = OLD.sha256;
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS trg_drop_orphan_pub_asset ON public.pub_asset_refs;
CREATE TRIGGER trg_drop_orphan_pub_asset
  AFTER DELETE ON public.pub_asset_refs
  FOR EACH ROW
  EXECUTE FUNCTION public.drop_orphan_pub_asset();

-- pub_asset_release — bir yayının medya ref'lerini bırak. Obje silimi yukarıdaki
-- trigger'ın işi. `_sha` NULL → o ref_key'in TÜM medyası. auth.uid() NULL
-- (service_role / moderasyon) ise sahiplik filtresi uygulanmaz.
CREATE OR REPLACE FUNCTION public.pub_asset_release(
  _ref_key TEXT,
  _sha     TEXT DEFAULT NULL
) RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid     UUID := auth.uid();
  v_removed INT;
BEGIN
  IF _ref_key IS NULL OR _ref_key = '' THEN
    RAISE EXCEPTION 'invalid_ref_key' USING ERRCODE = '22023';
  END IF;

  DELETE FROM public.pub_asset_refs r
   WHERE r.ref_key = _ref_key
     AND (_sha IS NULL OR r.sha256 = _sha)
     AND (v_uid IS NULL OR r.owner_id = v_uid);

  GET DIAGNOSTICS v_removed = ROW_COUNT;
  RETURN v_removed;
END $$;

GRANT EXECUTE ON FUNCTION public.pub_asset_release(TEXT, TEXT) TO authenticated;

-- ── 7. get_pub_upload_allowed — worker PUT kapısı ──────────────────────────
-- `pub/{sha}` key'inde kullanıcı prefix'i yok, dolayısıyla worker prefix
-- eşleşmesiyle yetki veremez. Onun yerine: rezervasyon var mı? checkTransient
-- Access ile aynı kalıp, service_role'dan çağrılır.
CREATE OR REPLACE FUNCTION public.get_pub_upload_allowed(
  p_user_id UUID,
  p_sha     TEXT
) RETURNS BOOLEAN
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.pub_asset_refs
     WHERE sha256 = p_sha AND owner_id = p_user_id
  );
$$;

REVOKE ALL ON FUNCTION public.get_pub_upload_allowed(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_pub_upload_allowed(UUID, TEXT) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_pub_upload_allowed(UUID, TEXT) TO service_role;

-- ── 8. get_r2_pool_stats — admin görünürlüğü ──────────────────────────────
-- Mevcut get_system_storage_stats() yalnızca Supabase storage.objects'i sayar,
-- R2 havuzunu görmez. Bu onun R2 karşılığı; admin panelindeki Storage sekmesi
-- (henüz yok) bunu okur. Yayın reddi sürpriz olmasın diye şimdiden konuyor.
CREATE OR REPLACE FUNCTION public.get_r2_pool_stats()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'admin required' USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'pinned', (
      SELECT jsonb_build_object(
        'used_bytes',   COALESCE(SUM(bytes), 0),
        'cap_bytes',    public.pinned_pool_cap_bytes(),
        'object_count', count(*),
        -- Dedup tasarrufu: refcount'a göre şişmiş boyut eksi gerçek boyut.
        'dedup_saved_bytes', COALESCE((
          SELECT SUM(a.bytes * (r.n - 1))
            FROM public.pub_assets a
            JOIN (SELECT sha256, count(*) AS n
                    FROM public.pub_asset_refs GROUP BY sha256) r
              ON r.sha256 = a.sha256
        ), 0)
      ) FROM public.pub_assets
    ),
    'transient', (
      SELECT jsonb_build_object(
        'used_bytes',        COALESCE(SUM(bytes), 0),
        'cap_bytes',         public.transient_pool_cap_bytes(),
        'max_file_bytes',    public.transient_max_file_bytes(),
        'object_count',      count(*),
        'oldest_last_used',  MIN(last_used_at)
      ) FROM public.transient_shares
    ),
    'evict_queue_depth', (SELECT count(*) FROM public.transient_evict_queue)
  );
END $$;

REVOKE ALL ON FUNCTION public.get_r2_pool_stats() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_r2_pool_stats() FROM anon;
GRANT EXECUTE ON FUNCTION public.get_r2_pool_stats() TO authenticated;

NOTIFY pgrst, 'reload schema';
