-- F6 cleanup: world_entities.is_builtin column retires.
--
-- F1 stopped writing built-in rows to `world_entities` (synthesized at
-- read-time from `installed_packages` + `package_entities`). F4 dropped
-- the bulk push path so no client computes the flag. The RLS read policy
-- (035) referenced `is_builtin`; we recreate it without that branch first,
-- then drop the column.
--
-- Player visibility after this migration: shares + entity refs only.
-- Built-in entries never reach the cloud, so removing the column-level
-- carve-out does not regress player UX.

BEGIN;

DROP POLICY IF EXISTS
  "Entities: dm reads all, player reads builtin+shared+owned"
  ON public.world_entities;

CREATE POLICY "Entities: dm reads all, player reads shared+owned"
  ON public.world_entities FOR SELECT
  USING (
    public.is_world_dm(world_id)
    OR (
      public.is_world_member(world_id) AND (
        EXISTS (
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

DROP INDEX IF EXISTS public.idx_world_entities_world_builtin;
ALTER TABLE public.world_entities DROP COLUMN IF EXISTS is_builtin;

COMMIT;

NOTIFY pgrst, 'reload schema';
