-- ============================================================================
-- Migration 035 — world_entities.is_builtin flag + RLS update
-- ============================================================================
-- Built-in (SRD core pack) entity'leri tüm world üyelerine otomatik görünür
-- yapar. Custom (DM tarafından oluşturulmuş veya kopyalanmış) entity'ler
-- önceden olduğu gibi entity_shares mekanizmasına tabi kalır.
--
-- Detection: DM client-side `pushEntity` sırasında local Drift `packageId`
-- built-in SRD pack id'sine eşit ve `linked = true` ise `is_builtin = true`
-- yazar. Heuristic backfill `source = 'SRD 5.2.1' AND linked` ile eski
-- mirror push'lar için kapatılır; yeni push'lar bu değeri overwrite eder.
-- ============================================================================

ALTER TABLE public.world_entities
  ADD COLUMN IF NOT EXISTS is_builtin BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_world_entities_world_builtin
  ON public.world_entities (world_id, is_builtin);

-- Backfill: önceki mirror push'lar `is_builtin` yazmadığı için heuristic.
UPDATE public.world_entities
   SET is_builtin = true
 WHERE linked = true
   AND source = 'SRD 5.2.1';

-- RLS: player built-in entity'leri de görsün.
DROP POLICY IF EXISTS "Entities: dm reads all, player reads shared+owned" ON public.world_entities;
DROP POLICY IF EXISTS "Entities: dm reads all, player reads builtin+shared+owned" ON public.world_entities;
CREATE POLICY "Entities: dm reads all, player reads builtin+shared+owned"
  ON public.world_entities FOR SELECT
  USING (
    public.is_world_dm(world_id)
    OR (
      public.is_world_member(world_id) AND (
        world_entities.is_builtin = true
        OR EXISTS (
          SELECT 1 FROM public.entity_shares s
          WHERE s.entity_id = world_entities.id
            AND s.world_id  = world_entities.world_id
            AND (s.shared_with IS NULL OR s.shared_with = auth.uid())
        )
        OR EXISTS (
          SELECT 1 FROM public.world_characters c
          WHERE c.world_id = world_entities.world_id
            AND c.owner_id = auth.uid()
            AND c.referenced_entity_ids ? world_entities.id
        )
      )
    )
  );
