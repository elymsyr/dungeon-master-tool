-- 049: Fix world DELETE crash — "tuple to be deleted was already modified
-- by an operation triggered by the current command".
--
-- Repro:
--   DELETE FROM worlds WHERE id = X
--     → BEFORE DELETE trg_world_delete_chars fires (mig 039)
--     → DELETE FROM world_characters WHERE world_id = X AND owner_id IS NULL
--     → AFTER DELETE trg_world_characters_bump_parent fires (mig 048)
--     → UPDATE worlds SET updated_at = now() WHERE id = X
--     → Postgres errors: worlds row X already in pending-delete state.
--
-- Fix: in tg_bump_parent_world, wrap the parent UPDATE in an exception
-- block. If the parent is mid-delete (or already gone), bump is moot.
-- Other failure modes are rare and silent-skip is acceptable for a
-- timestamp tick.

CREATE OR REPLACE FUNCTION public.tg_bump_parent_world()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  wid TEXT;
BEGIN
  IF TG_OP = 'DELETE' THEN
    wid := OLD.world_id;
  ELSE
    wid := NEW.world_id;
  END IF;
  IF wid IS NOT NULL THEN
    BEGIN
      UPDATE public.worlds SET updated_at = now() WHERE id = wid;
    EXCEPTION WHEN OTHERS THEN
      -- Parent mid-delete (cascade) or gone — bump is moot.
      NULL;
    END;
  END IF;
  RETURN COALESCE(NEW, OLD);
END $$;
