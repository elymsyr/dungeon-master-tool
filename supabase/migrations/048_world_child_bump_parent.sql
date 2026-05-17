-- 048: child table writes bump parent worlds.updated_at so SaveInfoSection
-- ("Cloud" timestamp) advances when entity/settings/map/session/char edits
-- land. Post-F6 row-level migration left parent untouched (publish_world
-- RPC retired). RLS bypass via SECURITY DEFINER so player-owned writes
-- (world_characters) can also tick the parent.

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
    UPDATE public.worlds SET updated_at = now() WHERE id = wid;
  END IF;
  RETURN COALESCE(NEW, OLD);
END $$;

-- world_entities
DROP TRIGGER IF EXISTS trg_world_entities_bump_parent ON public.world_entities;
CREATE TRIGGER trg_world_entities_bump_parent
  AFTER INSERT OR UPDATE OR DELETE ON public.world_entities
  FOR EACH ROW EXECUTE FUNCTION public.tg_bump_parent_world();

-- world_settings
DROP TRIGGER IF EXISTS trg_world_settings_bump_parent ON public.world_settings;
CREATE TRIGGER trg_world_settings_bump_parent
  AFTER INSERT OR UPDATE OR DELETE ON public.world_settings
  FOR EACH ROW EXECUTE FUNCTION public.tg_bump_parent_world();

-- world_map_data
DROP TRIGGER IF EXISTS trg_world_map_data_bump_parent ON public.world_map_data;
CREATE TRIGGER trg_world_map_data_bump_parent
  AFTER INSERT OR UPDATE OR DELETE ON public.world_map_data
  FOR EACH ROW EXECUTE FUNCTION public.tg_bump_parent_world();

-- world_sessions
DROP TRIGGER IF EXISTS trg_world_sessions_bump_parent ON public.world_sessions;
CREATE TRIGGER trg_world_sessions_bump_parent
  AFTER INSERT OR UPDATE OR DELETE ON public.world_sessions
  FOR EACH ROW EXECUTE FUNCTION public.tg_bump_parent_world();

-- world_characters
DROP TRIGGER IF EXISTS trg_world_characters_bump_parent ON public.world_characters;
CREATE TRIGGER trg_world_characters_bump_parent
  AFTER INSERT OR UPDATE OR DELETE ON public.world_characters
  FOR EACH ROW EXECUTE FUNCTION public.tg_bump_parent_world();

-- Note: world_packages, world_mind_map_nodes/_edges intentionally excluded —
-- these aren't part of the active-world save surface; add later if needed.
