-- 032_release_chars_on_leave.sql
--
-- When a player leaves a world (self-leave) or a DM kicks them
-- (`removeMember()` deletes their `world_members` row), any characters they
-- owned in that world should automatically become "free" again: ownership
-- is cleared and the character is re-added to the claim pool so any other
-- player can pick it up.
--
-- This used to require a follow-up DM action ("mark available"). The
-- trigger below makes the release implicit so neither side has to remember.
--
-- Fires on AFTER DELETE of world_members. SECURITY DEFINER bypasses the
-- character_claim_pool RLS (`ClaimPool: dm writes`) so a self-leave by a
-- player can still seed the pool — the trigger is the system actor.

CREATE OR REPLACE FUNCTION public.tg_release_owned_chars_on_leave()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Null out ownership on this user's characters in this world.
  UPDATE public.world_characters
     SET owner_id = NULL,
         updated_at = now()
   WHERE world_id = OLD.world_id
     AND owner_id = OLD.user_id;

  -- Re-add each just-released character to the claim pool. Existing pool
  -- rows are flipped back to available; new rows are inserted.
  INSERT INTO public.character_claim_pool
        (character_id, world_id, available, claimed_by, claimed_at)
  SELECT wc.id, wc.world_id, true, NULL, NULL
    FROM public.world_characters wc
   WHERE wc.world_id = OLD.world_id
     AND wc.owner_id IS NULL
     AND EXISTS (
       -- Only the rows we just released — avoid re-pooling pre-existing
       -- DM-only characters that happened to have null owner_id.
       SELECT 1
         FROM public.world_characters wc2
        WHERE wc2.id = wc.id
          AND wc2.updated_at >= now() - interval '1 second'
     )
  ON CONFLICT (character_id) DO UPDATE
    SET available = true,
        claimed_by = NULL,
        claimed_at = NULL;

  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_release_chars_on_leave ON public.world_members;
CREATE TRIGGER trg_release_chars_on_leave
  AFTER DELETE ON public.world_members
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_release_owned_chars_on_leave();
