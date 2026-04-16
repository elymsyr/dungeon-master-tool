-- ============================================================================
-- DMT Beta Program — Supabase SQL Migration
-- ============================================================================
-- Cloud save özelliğini yalnızca ilk 200 "beta" kullanıcısına açar, her kullanıcıya
-- 50 MB quota verir ve 7 gün inaktif olanların cloud verisini + beta slot'unu
-- otomatik temizler. Posts beta gate'li DEĞİL — yalnızca spam'i önlemek için
-- sliding window rate limit uygulanır (1m:2, 1h:10, 24h:30).
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
--
-- Ön koşul: `pg_cron` extension'ı Dashboard > Database > Extensions panelinden
-- etkinleştirilmiş olmalıdır. Aksi hâlde migration'ın cron.schedule satırı
-- "schema cron does not exist" hatası verir; extension'ı enable ettikten sonra
-- migration'ı yeniden çalıştırın.
-- ============================================================================

-- ── 1. Ayarlanabilir sabitler (tek yerden değiştirmek için fonksiyon) ──────

CREATE OR REPLACE FUNCTION public.beta_slot_cap()
RETURNS INT LANGUAGE sql IMMUTABLE AS $$ SELECT 200 $$;

CREATE OR REPLACE FUNCTION public.beta_user_quota_bytes()
RETURNS BIGINT LANGUAGE sql IMMUTABLE AS $$ SELECT (50 * 1024 * 1024)::bigint $$;

CREATE OR REPLACE FUNCTION public.beta_inactivity_days()
RETURNS INT LANGUAGE sql IMMUTABLE AS $$ SELECT 7 $$;

-- Post rate limit pencereleri (başlangıç değerleri; dataya göre ayarlanabilir).
CREATE OR REPLACE FUNCTION public.post_rate_per_minute()
RETURNS INT LANGUAGE sql IMMUTABLE AS $$ SELECT 2 $$;

CREATE OR REPLACE FUNCTION public.post_rate_per_hour()
RETURNS INT LANGUAGE sql IMMUTABLE AS $$ SELECT 10 $$;

CREATE OR REPLACE FUNCTION public.post_rate_per_day()
RETURNS INT LANGUAGE sql IMMUTABLE AS $$ SELECT 30 $$;

-- ── 2. beta_participants tablosu ────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.beta_participants (
  user_id        UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_active_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  slot_number    INT UNIQUE                        -- 1..N, audit için
);

CREATE INDEX IF NOT EXISTS idx_beta_participants_last_active
  ON public.beta_participants (last_active_at);

ALTER TABLE public.beta_participants ENABLE ROW LEVEL SECURITY;

-- Kullanıcı yalnızca kendi satırını okuyabilir (slot sayıları RPC'den gelir).
DROP POLICY IF EXISTS "beta_participants self read" ON public.beta_participants;
CREATE POLICY "beta_participants self read"
  ON public.beta_participants FOR SELECT
  USING (auth.uid() = user_id);

-- Direkt INSERT/UPDATE/DELETE yok — tüm mutasyonlar SECURITY DEFINER RPC'lerle.

-- ── 3. is_beta_active — RLS policy'lerinde kullanılacak ────────────────────

CREATE OR REPLACE FUNCTION public.is_beta_active(p_user UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.beta_participants WHERE user_id = p_user
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_beta_active(UUID) TO authenticated, anon;

-- ── 4. get_beta_quota_used — 50 MB'a sayılan storage toplamı ───────────────
-- Posts ve marketplace_listings quota'ya dahil EDİLMEZ. cloud_backups +
-- community_assets toplamı. (mevcut get_user_total_storage_used fonksiyonuna
-- dokunulmaz — başka callsite'ler için davranış aynı kalır.)

CREATE OR REPLACE FUNCTION public.get_beta_quota_used(p_user_id UUID)
RETURNS BIGINT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT
    COALESCE((SELECT SUM(size_bytes) FROM public.cloud_backups
              WHERE user_id = p_user_id), 0)
    +
    COALESCE((SELECT SUM(size_bytes) FROM public.community_assets
              WHERE uploader_id = p_user_id), 0);
$$;

GRANT EXECUTE ON FUNCTION public.get_beta_quota_used(UUID) TO authenticated;

-- ── 5. join_beta() — atomik slot kapma ─────────────────────────────────────
-- pg_advisory_xact_lock serialize eder; LOCK TABLE EXCLUSIVE kullanmayız çünkü
-- SELECT trafiğini bloklar. Advisory key session-scoped, txn sonunda release.

DROP FUNCTION IF EXISTS public.join_beta();
CREATE OR REPLACE FUNCTION public.join_beta()
RETURNS TABLE (status TEXT, assigned_slot INT, slots_remaining INT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_user UUID := auth.uid();
  v_cap  INT := public.beta_slot_cap();
  v_count INT;
  v_slot INT;
BEGIN
  IF v_user IS NULL THEN
    RETURN QUERY SELECT 'not_signed_in'::TEXT, NULL::INT, v_cap;
    RETURN;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('beta_join_lock'));

  -- Zaten beta'da mı?
  IF EXISTS (SELECT 1 FROM public.beta_participants bp WHERE bp.user_id = v_user) THEN
    SELECT bp.slot_number INTO v_slot
      FROM public.beta_participants bp WHERE bp.user_id = v_user;
    RETURN QUERY
      SELECT
        'already'::TEXT,
        v_slot,
        GREATEST(0, v_cap - (SELECT count(*)::int FROM public.beta_participants));
    RETURN;
  END IF;

  SELECT count(*)::int INTO v_count FROM public.beta_participants;
  IF v_count >= v_cap THEN
    RETURN QUERY SELECT 'full'::TEXT, NULL::INT, 0;
    RETURN;
  END IF;

  -- slot_number'ı "ilk boş küçük sayı" olarak seç (re-join sonrası slot geri
  -- gelsin diye). Küçük ölçekte GAP+1 SQL'i verimli.
  SELECT COALESCE(
    (SELECT MIN(n) FROM generate_series(1, v_cap) n
       WHERE n NOT IN (SELECT bp.slot_number FROM public.beta_participants bp WHERE bp.slot_number IS NOT NULL)),
    v_count + 1
  ) INTO v_slot;

  INSERT INTO public.beta_participants (user_id, slot_number)
    VALUES (v_user, v_slot);

  RETURN QUERY
    SELECT 'joined'::TEXT, v_slot, v_cap - (v_count + 1);
END $$;

GRANT EXECUTE ON FUNCTION public.join_beta() TO authenticated;

-- ── 6. beta_heartbeat — app resume olunca çağrılır ─────────────────────────

CREATE OR REPLACE FUNCTION public.beta_heartbeat()
RETURNS VOID
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  UPDATE public.beta_participants
     SET last_active_at = now()
   WHERE user_id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.beta_heartbeat() TO authenticated;

-- ── 6b. leave_beta — kullanıcı kendi isteğiyle beta'dan çıkar ──────────────
-- Sweep ile aynı temizlik: cloud_backups + storage objects + community_assets
-- + beta_participants row. Post'lar ve marketplace dokunulmaz.

CREATE OR REPLACE FUNCTION public.leave_beta()
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RETURN FALSE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.beta_participants WHERE user_id = v_user) THEN
    RETURN FALSE;
  END IF;

  -- Not: storage.objects client tarafında Storage API ile silinir (Supabase
  -- RLS "Direct deletion from storage tables is not allowed" diye reddediyor).
  DELETE FROM public.cloud_backups WHERE user_id = v_user;

  DELETE FROM public.community_assets WHERE uploader_id = v_user;

  DELETE FROM public.beta_participants WHERE user_id = v_user;

  RETURN TRUE;
END $$;

GRANT EXECUTE ON FUNCTION public.leave_beta() TO authenticated;

-- ── 7. get_beta_status — client tek RPC çağrısıyla özet alır ───────────────

CREATE OR REPLACE FUNCTION public.get_beta_status()
RETURNS TABLE (
  is_active       BOOLEAN,
  joined_at       TIMESTAMPTZ,
  last_active_at  TIMESTAMPTZ,
  slot_number     INT,
  slots_remaining INT,
  slot_cap        INT,
  quota_bytes     BIGINT,
  used_bytes      BIGINT,
  inactivity_days INT
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_user UUID := auth.uid();
BEGIN
  RETURN QUERY
  SELECT
    (bp.user_id IS NOT NULL)::boolean AS is_active,
    bp.joined_at,
    bp.last_active_at,
    bp.slot_number,
    GREATEST(0, public.beta_slot_cap()
             - (SELECT count(*)::int FROM public.beta_participants))::int
      AS slots_remaining,
    public.beta_slot_cap() AS slot_cap,
    public.beta_user_quota_bytes() AS quota_bytes,
    CASE WHEN v_user IS NULL THEN 0::bigint
         ELSE COALESCE(public.get_beta_quota_used(v_user), 0)
    END AS used_bytes,
    public.beta_inactivity_days() AS inactivity_days
  FROM (SELECT v_user AS uid) u
  LEFT JOIN public.beta_participants bp ON bp.user_id = u.uid;
END $$;

GRANT EXECUTE ON FUNCTION public.get_beta_status() TO authenticated, anon;

-- ── 8. sweep_inactive_beta — pg_cron tarafından günlük tetiklenir ─────────
-- 7 gün inaktif kullanıcılar için:
--   (a) cloud_backups satırları
--   (b) storage.objects (campaign-backups bucket'ında kullanıcının klasörü)
--   (c) community_assets satırları (+ R2 objeler — worker yapar, burada sadece
--       metadata temizlenir; uploader'ın R2 nesneleri sonraki garbage-collect
--       tarafından hizalanır)
--   (d) beta_participants satırı → slot serbest
-- Post'lar ve marketplace_listings dokunulmaz.

CREATE OR REPLACE FUNCTION public.sweep_inactive_beta()
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_cutoff TIMESTAMPTZ := now() - (public.beta_inactivity_days() || ' days')::interval;
  v_user_ids UUID[];
  v_count INT;
BEGIN
  SELECT array_agg(user_id) INTO v_user_ids
    FROM public.beta_participants
   WHERE last_active_at < v_cutoff;

  IF v_user_ids IS NULL THEN
    RETURN 0;
  END IF;

  -- (a) cloud_backups metadata
  DELETE FROM public.cloud_backups WHERE user_id = ANY(v_user_ids);

  -- (b) Supabase Storage objeleri: path format {user_id}/...
  DELETE FROM storage.objects
   WHERE bucket_id = 'campaign-backups'
     AND (storage.foldername(name))[1] = ANY(
           SELECT x::text FROM unnest(v_user_ids) AS x
         );

  -- (c) community_assets metadata (R2 nesneleri worker tarafından temizlenir)
  DELETE FROM public.community_assets WHERE uploader_id = ANY(v_user_ids);

  -- (d) beta_participants → slot boşalır
  DELETE FROM public.beta_participants WHERE user_id = ANY(v_user_ids);

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END $$;

-- Sadece service_role çağırabilsin.
REVOKE ALL ON FUNCTION public.sweep_inactive_beta() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sweep_inactive_beta() FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sweep_inactive_beta() TO service_role;

-- ── 9. RLS policy güncellemeleri — yalnızca cloud save & assets beta-gated ─

-- 9a. cloud_backups: "Users manage own backups" policy'sini 4 parçaya böl.
DROP POLICY IF EXISTS "Users manage own backups" ON public.cloud_backups;
DROP POLICY IF EXISTS "cloud_backups self read" ON public.cloud_backups;
DROP POLICY IF EXISTS "cloud_backups beta insert" ON public.cloud_backups;
DROP POLICY IF EXISTS "cloud_backups beta update" ON public.cloud_backups;
DROP POLICY IF EXISTS "cloud_backups self delete" ON public.cloud_backups;

CREATE POLICY "cloud_backups self read"
  ON public.cloud_backups FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "cloud_backups beta insert"
  ON public.cloud_backups FOR INSERT
  WITH CHECK (auth.uid() = user_id AND public.is_beta_active(auth.uid()));

CREATE POLICY "cloud_backups beta update"
  ON public.cloud_backups FOR UPDATE
  USING (auth.uid() = user_id AND public.is_beta_active(auth.uid()))
  WITH CHECK (auth.uid() = user_id AND public.is_beta_active(auth.uid()));

CREATE POLICY "cloud_backups self delete"
  ON public.cloud_backups FOR DELETE
  USING (auth.uid() = user_id);

-- 9b. community_assets: INSERT beta-gated, diğer işlemler ownership.
DROP POLICY IF EXISTS "Uploader manages own assets" ON public.community_assets;
DROP POLICY IF EXISTS "community_assets self read" ON public.community_assets;
DROP POLICY IF EXISTS "community_assets beta insert" ON public.community_assets;
DROP POLICY IF EXISTS "community_assets owner update" ON public.community_assets;
DROP POLICY IF EXISTS "community_assets owner delete" ON public.community_assets;

CREATE POLICY "community_assets self read"
  ON public.community_assets FOR SELECT
  USING (auth.uid() = uploader_id);

CREATE POLICY "community_assets beta insert"
  ON public.community_assets FOR INSERT
  WITH CHECK (auth.uid() = uploader_id AND public.is_beta_active(auth.uid()));

CREATE POLICY "community_assets owner update"
  ON public.community_assets FOR UPDATE
  USING (auth.uid() = uploader_id)
  WITH CHECK (auth.uid() = uploader_id);

CREATE POLICY "community_assets owner delete"
  ON public.community_assets FOR DELETE
  USING (auth.uid() = uploader_id);

-- 9c. storage.objects — campaign-backups bucket INSERT beta-gated.
DROP POLICY IF EXISTS "Users can upload to own folder" ON storage.objects;
DROP POLICY IF EXISTS "campaign-backups beta insert" ON storage.objects;

CREATE POLICY "campaign-backups beta insert"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'campaign-backups'
    AND auth.uid()::text = (storage.foldername(name))[1]
    AND public.is_beta_active(auth.uid())
  );

-- posts ve post-images RLS'i dokunulmaz — post gate yok.

-- ── 10. Beta quota enforcement trigger (defense-in-depth) ──────────────────

CREATE OR REPLACE FUNCTION public.enforce_beta_quota_on_backup()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_used BIGINT;
  v_cap  BIGINT := public.beta_user_quota_bytes();
  v_delta BIGINT;
BEGIN
  IF NOT public.is_beta_active(NEW.user_id) THEN
    RETURN NEW; -- RLS zaten bloklayacak; güvenlik için no-op.
  END IF;

  v_delta := NEW.size_bytes - COALESCE(
    (CASE WHEN TG_OP = 'UPDATE' THEN OLD.size_bytes ELSE 0 END),
    0
  );

  IF v_delta <= 0 THEN
    RETURN NEW; -- row shrinking veya sabit kalıyor — quota'ya bakma.
  END IF;

  SELECT COALESCE(public.get_beta_quota_used(NEW.user_id), 0) INTO v_used;

  IF v_used + v_delta > v_cap THEN
    RAISE EXCEPTION
      'beta quota exceeded: % + % > %', v_used, v_delta, v_cap
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_beta_quota_cloud_backups ON public.cloud_backups;
CREATE TRIGGER trg_beta_quota_cloud_backups
  BEFORE INSERT OR UPDATE ON public.cloud_backups
  FOR EACH ROW EXECUTE FUNCTION public.enforce_beta_quota_on_backup();

-- ── 11. Post rate limit trigger ────────────────────────────────────────────
-- Beta gate YOK — tüm kullanıcılara sliding window rate limit. Exception
-- fırlatıldığında insert rollback olur; spam detection için posts tablosu
-- zaten zaman damgası ile audit sağlar (alttaki view'a bakın).

CREATE OR REPLACE FUNCTION public.enforce_post_rate_limit()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_1m INT; v_1h INT; v_24h INT;
BEGIN
  IF NEW.author_id IS NULL THEN RETURN NEW; END IF;

  SELECT count(*) INTO v_1m FROM public.posts
   WHERE author_id = NEW.author_id
     AND created_at > now() - interval '1 minute';
  IF v_1m >= public.post_rate_per_minute() THEN
    RAISE EXCEPTION 'post_rate_limit_exceeded (1m: %)', v_1m
      USING ERRCODE = 'check_violation', HINT = 'window=1m';
  END IF;

  SELECT count(*) INTO v_1h FROM public.posts
   WHERE author_id = NEW.author_id
     AND created_at > now() - interval '1 hour';
  IF v_1h >= public.post_rate_per_hour() THEN
    RAISE EXCEPTION 'post_rate_limit_exceeded (1h: %)', v_1h
      USING ERRCODE = 'check_violation', HINT = 'window=1h';
  END IF;

  SELECT count(*) INTO v_24h FROM public.posts
   WHERE author_id = NEW.author_id
     AND created_at > now() - interval '24 hours';
  IF v_24h >= public.post_rate_per_day() THEN
    RAISE EXCEPTION 'post_rate_limit_exceeded (24h: %)', v_24h
      USING ERRCODE = 'check_violation', HINT = 'window=24h';
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_post_rate_limit ON public.posts;
CREATE TRIGGER trg_post_rate_limit
  BEFORE INSERT ON public.posts
  FOR EACH ROW EXECUTE FUNCTION public.enforce_post_rate_limit();

-- ── 12. post_abuse_candidates — spam detection view (admin only) ───────────
-- Son 24 saatte >=15 post atan kullanıcılar. Admin dashboard bu view'i sorar.

CREATE OR REPLACE VIEW public.post_abuse_candidates AS
  SELECT
    author_id,
    count(*) AS posts_last_24h,
    MAX(created_at) AS last_post_at,
    MIN(created_at) AS first_post_in_window
  FROM public.posts
  WHERE created_at > now() - interval '24 hours'
  GROUP BY author_id
  HAVING count(*) >= 15
  ORDER BY count(*) DESC;

-- View anon/authenticated'a açık değil; admin'ler service_role veya RPC ile sorar.
REVOKE ALL ON public.post_abuse_candidates FROM PUBLIC;
REVOKE ALL ON public.post_abuse_candidates FROM anon, authenticated;
GRANT SELECT ON public.post_abuse_candidates TO service_role;

-- ── 13. pg_cron schedule — günlük sweep ────────────────────────────────────
-- pg_cron Supabase'de extensions schema'sında. Dashboard'dan enable edilmiş
-- olmalı. Schedule idempotent (aynı isimli eski job'ı temizleyip yeniden kur).

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobid)
      FROM cron.job WHERE jobname = 'sweep_inactive_beta_daily';
    PERFORM cron.schedule(
      'sweep_inactive_beta_daily',
      '0 3 * * *',
      $cron$ SELECT public.sweep_inactive_beta(); $cron$
    );
  ELSE
    RAISE NOTICE 'pg_cron extension not installed — sweep_inactive_beta_daily NOT scheduled. Enable pg_cron in Supabase Dashboard > Database > Extensions and re-run this migration.';
  END IF;
END $$;
