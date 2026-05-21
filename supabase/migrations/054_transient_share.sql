-- ============================================================================
-- 054_transient_share.sql — Storage-dolu geçici medya paylaşımı
-- ============================================================================
-- DM storage'ı doluyken bir resmi oyunculara (second screen / card share) ile
-- gösterdiğinde, resim sayılan cloud'a KALICI yazılmaz. Bunun yerine:
--   - binary R2'da `transient/{uploader}/{sha}.{ext}` key'ine yazılır (Worker
--     quota check'i atlar; R2 lifecycle rule N gün sonra otomatik siler),
--   - bu tablo "şu an gösteriliyor" manifest'i olarak realtime ile dağıtılır.
-- Oyuncular SHA ile local cache'i kontrol eder → varsa sıfır transfer.
--
-- ⚠ transient objeler ve bu tablo HİÇBİR quota toplamına dahil DEĞİLDİR.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

-- ── 1. transient_shares tablosu ────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.transient_shares (
  id          UUID PRIMARY KEY,
  world_id    TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  uploader_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sha256      TEXT NOT NULL,
  ext         TEXT NOT NULL DEFAULT '.png',
  session_id  UUID,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_transient_shares_world
  ON public.transient_shares (world_id);

-- ── 2. Row Level Security ──────────────────────────────────────────────────
-- SELECT: dünya üyeleri (oyuncular gösterilen resmi çözebilsin).
-- WRITE : dünya DM'i + uploader = kendisi.

ALTER TABLE public.transient_shares ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "transient_shares: members read" ON public.transient_shares;
CREATE POLICY "transient_shares: members read"
  ON public.transient_shares FOR SELECT
  USING (public.is_world_member(world_id));

DROP POLICY IF EXISTS "transient_shares: dm write" ON public.transient_shares;
CREATE POLICY "transient_shares: dm write"
  ON public.transient_shares FOR ALL
  USING (public.is_world_dm(world_id) AND uploader_id = auth.uid())
  WITH CHECK (public.is_world_dm(world_id) AND uploader_id = auth.uid());

-- ── 3. get_transient_access — Worker GET erişim kontrolü ───────────────────
-- transient objelerin community_assets satırı yok; Worker indirme onayı için
-- "iki kullanıcı ortak bir dünyada üye mi?" sorusunu bu fonksiyonla sorar.

CREATE OR REPLACE FUNCTION public.get_transient_access(
  p_user_id     UUID,
  p_uploader_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  -- Uploader kendi objesine her zaman erişir; aksi halde ortak dünya üyeliği.
  SELECT p_user_id = p_uploader_id
    OR EXISTS (
      SELECT 1
      FROM public.world_members a
      JOIN public.world_members b ON a.world_id = b.world_id
      WHERE a.user_id = p_user_id
        AND b.user_id = p_uploader_id
    );
$$;

REVOKE ALL ON FUNCTION public.get_transient_access(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_transient_access(UUID, UUID)
  FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_transient_access(UUID, UUID)
  TO service_role;

-- ── 4. Realtime publication + REPLICA IDENTITY FULL ────────────────────────
-- FULL: un-share DELETE event'i satır verisini taşısın (migration 051/052
-- dersi) — oyuncu gösterimi kapattığını öğrensin.

ALTER TABLE public.transient_shares REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'transient_shares'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.transient_shares;
  END IF;
END $$;

-- ── 5. Quota invariant ─────────────────────────────────────────────────────
-- transient_shares ve `transient/` R2 objeleri KASITLI olarak hiçbir quota
-- fonksiyonuna (get_user_total_storage_used / get_beta_quota_used) dahil
-- DEĞİLDİR. Geçici paylaşımın quota'ya sayılmaması buna bağlıdır.

NOTIFY pgrst, 'reload schema';
