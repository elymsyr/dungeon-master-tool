-- ============================================================================
-- 061_battlemap_mark_ops.sql — BattleMap marks append-only ops tablosu (F8)
-- ============================================================================
-- F8: her stroke/fog/circle/ruler için full state re-upload eden eski
-- `world_battlemap_marks` yolundan vazgeçildi; bu tablo append-only event
-- log'u tutar. Client snapshot (eski tablo) + ops merge ile render eder.
-- DM-side periodic compaction (5dk veya 500 op) yeni snapshot yazar +
-- eski op'ları siler — depo tablosunun şişmesini önler.
--
-- Migration sıralaması: 060'tan sonra; 062+ sonraki feature'lar.
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

-- ── A — Table ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.world_battlemap_mark_ops (
  op_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  world_id     TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  encounter_id TEXT NOT NULL,
  author_id    UUID NOT NULL REFERENCES auth.users(id),
  kind         TEXT NOT NULL,        -- stroke | fog | circle | ruler | erase
  payload_json TEXT NOT NULL,
  seq          BIGINT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bm_ops_enc_seq
  ON public.world_battlemap_mark_ops (world_id, encounter_id, seq);

CREATE INDEX IF NOT EXISTS idx_bm_ops_world_created
  ON public.world_battlemap_mark_ops (world_id, created_at);

-- ── B — RLS ─────────────────────────────────────────────────────────────────
-- SELECT = dünya üyesi (oyuncu marks'ı render eder).
-- INSERT = dünya üyesi (DM + oyuncular kendi op'larını yazar; collab paint).
-- DELETE = DM (compaction yetkisi DM'de).
-- UPDATE = yok (append-only).

ALTER TABLE public.world_battlemap_mark_ops ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "BMOps: member read" ON public.world_battlemap_mark_ops;
CREATE POLICY "BMOps: member read"
  ON public.world_battlemap_mark_ops FOR SELECT
  USING (public.is_world_member(world_id));

DROP POLICY IF EXISTS "BMOps: member insert" ON public.world_battlemap_mark_ops;
CREATE POLICY "BMOps: member insert"
  ON public.world_battlemap_mark_ops FOR INSERT
  WITH CHECK (
    public.is_world_member(world_id)
    AND author_id = auth.uid()
  );

DROP POLICY IF EXISTS "BMOps: dm delete" ON public.world_battlemap_mark_ops;
CREATE POLICY "BMOps: dm delete"
  ON public.world_battlemap_mark_ops FOR DELETE
  USING (public.is_world_dm(world_id));

-- ── C — Realtime publication + REPLICA IDENTITY FULL ────────────────────────
-- FULL: DELETE event'inin oldRecord'u world_id + encounter_id taşısın →
-- player local mirror'dan ilgili op'ları silebilsin.

ALTER TABLE public.world_battlemap_mark_ops REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'world_battlemap_mark_ops'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.world_battlemap_mark_ops;
  END IF;
END $$;

-- ── D — Compaction RPC (DM-only) ────────────────────────────────────────────
-- DM compaction sırasında atomic olarak: (1) yeni snapshot'u eski
-- `world_battlemap_marks` tablosuna upsert et + `seq_high_water_mark` set,
-- (2) seq <= high_water_mark olan tüm ops'ları sil.

CREATE OR REPLACE FUNCTION public.compact_battlemap_marks(
  p_world_id TEXT,
  p_encounter_id TEXT,
  p_high_water BIGINT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  IF NOT public.is_world_dm(p_world_id) THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  DELETE FROM public.world_battlemap_mark_ops
   WHERE world_id = p_world_id
     AND encounter_id = p_encounter_id
     AND seq <= p_high_water;
END;
$$;

REVOKE ALL ON FUNCTION public.compact_battlemap_marks(TEXT, TEXT, BIGINT)
  FROM public;
GRANT EXECUTE ON FUNCTION public.compact_battlemap_marks(TEXT, TEXT, BIGINT)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
