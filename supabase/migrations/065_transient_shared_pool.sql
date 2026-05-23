-- ============================================================================
-- 065_transient_shared_pool.sql — Paylaşımlı transient havuz + LRU eviction
-- ============================================================================
-- Mevcut model: transient_shares satırı + R2 `transient/` prefix quota'dan
-- muaf, sadece R2 lifecycle (~1 gün) ile temizleniyor — explicit cap yok.
--
-- Yeni model:
--   • Per-user cap: 100 MB. Aşan upload `transient_per_user_full` exception.
--   • Global pool cap: 10 GB. Aşıldığında en eski (`last_used_at` ASC) satır
--     silinir, R2 silimi için `transient_evict_queue` kuyruğuna yazılır,
--     worker `/transient/evict-sweep` endpoint'i kuyruğu işler.
--   • LRU touch: oyuncu/Worker bir transient asset'i download ettiğinde
--     `transient_touch(sha)` RPC'si `last_used_at = now()` yapar.
--
-- Schema değişiklikleri:
--   • transient_shares: bytes, last_used_at, mime_type kolonları + LRU/uploader
--     index'leri.
--   • Yeni tablo: transient_evict_queue.
--   • Yeni RPC'ler: transient_reserve, transient_touch, transient_pool_cap_bytes,
--     transient_evict_pop (service_role only).
-- ============================================================================

-- ── 1. transient_shares — yeni kolonlar ────────────────────────────────────
ALTER TABLE public.transient_shares
  ADD COLUMN IF NOT EXISTS bytes        BIGINT     NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS mime_type    TEXT       NOT NULL DEFAULT 'application/octet-stream',
  ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_transient_shares_last_used
  ON public.transient_shares (last_used_at);
CREATE INDEX IF NOT EXISTS idx_transient_shares_uploader
  ON public.transient_shares (uploader_id);
CREATE INDEX IF NOT EXISTS idx_transient_shares_sha
  ON public.transient_shares (sha256);

-- ── 2. transient_evict_queue — worker R2 cleanup kuyruğu ───────────────────
CREATE TABLE IF NOT EXISTS public.transient_evict_queue (
  id          BIGSERIAL PRIMARY KEY,
  sha256      TEXT NOT NULL,
  ext         TEXT NOT NULL DEFAULT '.png',
  uploader_id UUID NOT NULL,
  enqueued_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_transient_evict_queue_enq
  ON public.transient_evict_queue (enqueued_at);

ALTER TABLE public.transient_evict_queue ENABLE ROW LEVEL SECURITY;
-- Sadece service_role görür/yazar; client'lara hiçbir policy verilmez.

-- ── 3. Sabitler ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.transient_per_user_cap_bytes()
RETURNS BIGINT LANGUAGE sql IMMUTABLE
AS $$ SELECT (100::bigint * 1024 * 1024) $$;

CREATE OR REPLACE FUNCTION public.transient_pool_cap_bytes()
RETURNS BIGINT LANGUAGE sql IMMUTABLE
AS $$ SELECT (10::bigint * 1024 * 1024 * 1024) $$;  -- 10 GB global

-- ── 4. transient_reserve — upload öncesi cap kontrolü + LRU eviction ───────
-- Client upload'tan önce bu RPC'yi çağırır. OK ise R2 PUT'a geçer, satır
-- INSERT'i upload başarısı sonrası yapılır (varolan akış uploadTransientShare).
-- _bytes: yüklenecek dosyanın boyutu.

CREATE OR REPLACE FUNCTION public.transient_reserve(
  _bytes BIGINT,
  _world TEXT
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid           UUID := auth.uid();
  v_per_user_used BIGINT;
  v_global_used   BIGINT;
  v_victim        RECORD;
  v_evicted       INT := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_signed_in' USING ERRCODE = '42501';
  END IF;
  IF _bytes IS NULL OR _bytes <= 0 THEN
    RAISE EXCEPTION 'invalid_bytes' USING ERRCODE = '22023';
  END IF;
  IF _bytes > public.transient_per_user_cap_bytes() THEN
    RAISE EXCEPTION 'transient_file_too_large' USING ERRCODE = 'P0001';
  END IF;

  -- Per-user cap: kullanıcının mevcut transient toplamı + yeni dosya ≤ 100 MB.
  SELECT COALESCE(SUM(bytes), 0) INTO v_per_user_used
    FROM public.transient_shares WHERE uploader_id = v_uid;
  IF v_per_user_used + _bytes > public.transient_per_user_cap_bytes() THEN
    RAISE EXCEPTION 'transient_per_user_full'
      USING ERRCODE = 'P0001',
            HINT = format('used=%s new=%s cap=%s',
                          v_per_user_used, _bytes,
                          public.transient_per_user_cap_bytes());
  END IF;

  -- Global pool LRU eviction — yeni dosyaya yer açana kadar en eski sil.
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

    -- R2 cleanup kuyruğuna yaz, sonra DB satırını sil (CDC delete event'i
    -- realtime ile oyunculara dağılır → projeksiyon görüntüsü düşer).
    INSERT INTO public.transient_evict_queue (sha256, ext, uploader_id)
      VALUES (v_victim.sha256, v_victim.ext, v_victim.uploader_id);
    DELETE FROM public.transient_shares WHERE id = v_victim.id;
    v_evicted := v_evicted + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', TRUE,
    'per_user_used', v_per_user_used,
    'global_used', v_global_used,
    'evicted', v_evicted
  );
END $$;

GRANT EXECUTE ON FUNCTION public.transient_reserve(BIGINT, TEXT) TO authenticated;

-- ── 5. transient_touch — LRU update (download/erişim) ──────────────────────
CREATE OR REPLACE FUNCTION public.transient_touch(_sha TEXT)
RETURNS VOID
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  UPDATE public.transient_shares
     SET last_used_at = now()
   WHERE sha256 = _sha;
$$;

GRANT EXECUTE ON FUNCTION public.transient_touch(TEXT) TO authenticated;

-- ── 6. transient_evict_pop — worker sweep endpoint için ────────────────────
-- Worker bu RPC ile kuyruktan N satır alır, R2 DELETE yapar, sonra row'ları
-- siler. FOR UPDATE SKIP LOCKED ile aynı anda iki worker conflict etmez.
CREATE OR REPLACE FUNCTION public.transient_evict_pop(_limit INT DEFAULT 20)
RETURNS TABLE (id BIGINT, sha256 TEXT, ext TEXT, uploader_id UUID)
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
  RETURNING q.id, q.sha256, q.ext, q.uploader_id;
END $$;

REVOKE ALL ON FUNCTION public.transient_evict_pop(INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.transient_evict_pop(INT) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.transient_evict_pop(INT) TO service_role;

-- ── 7. Backfill — varolan satırlara default bytes (0) zaten DEFAULT ile yazıldı.
-- Boyut bilgisini bilmediğimiz için 0; bir sonraki touch/upload düzeltir. Bu
-- mevcut LRU davranışını bozmaz (sıfır-bayt eviction her zaman güvenli).

NOTIFY pgrst, 'reload schema';
