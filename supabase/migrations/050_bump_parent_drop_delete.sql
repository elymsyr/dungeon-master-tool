-- 050: Fix world DELETE crash that 049 didn't catch.
--
-- Real sequence (root cause clarified):
--   1. DELETE FROM worlds WHERE id = X
--   2. BEFORE DELETE trg_world_delete_chars (mig 039) fires
--      → DELETE FROM world_characters WHERE world_id = X AND owner_id IS NULL
--   3. Each of those child DELETEs fires AFTER DELETE
--      trg_world_characters_bump_parent (mig 048)
--      → tg_bump_parent_world() → UPDATE worlds SET updated_at = now() ...
--      → SUCCEEDS (worlds row not yet pending-delete; still inside BEFORE trg).
--   4. BEFORE trigger returns, postgres tries the actual worlds DELETE
--      → "tuple to be deleted was already modified by an operation triggered
--        by the current command" because step 3 marked the row dirty.
--
-- Mig 049's EXCEPTION block never fires because step 3's UPDATE doesn't
-- throw — the crash is at step 4, outside any trigger we own.
--
-- Fix: deterministic skip. Bump function returns early on DELETE so step 3's
-- UPDATE never happens. Also skip when pg_trigger_depth() > 1 (nested trigger
-- contexts like release_chars_on_leave that update world_characters during a
-- world cascade).

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
    RETURN OLD;
  END IF;

  wid := NEW.world_id;
  IF wid IS NOT NULL THEN
    IF pg_trigger_depth() > 1 THEN
      RETURN NEW;
    END IF;

    BEGIN
      UPDATE public.worlds SET updated_at = now() WHERE id = wid;
    EXCEPTION WHEN OTHERS THEN
      -- Parent gone or mid-modify — bump is moot.
      NULL;
    END;
  END IF;
  RETURN NEW;
END $$;
