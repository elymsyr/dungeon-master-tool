-- Hangi tablo/satır `world_revisions`'ı artırdı? (§4.8 "Bekleyen doğrulama" 2)
-- Salt okunur. Supabase SQL editöründe olduğu gibi çalışır.
--
-- Ölçüme başlarken okuduğun revizyonu `since` satırına yaz.

WITH p AS (SELECT '47272f9a-baf7-4eb6-acdf-267f8dfc6b4e'::text AS w, 55::bigint AS since),
r AS (
  SELECT 'world_entities' t, e.id::text row_id, e.revision, e.updated_at
    FROM public.world_entities e, p WHERE e.world_id = p.w
  UNION ALL SELECT 'world_settings',  x.world_id::text,  x.revision, x.updated_at FROM public.world_settings  x, p WHERE x.world_id = p.w
  UNION ALL SELECT 'world_map_data',  x.world_id::text,  x.revision, x.updated_at FROM public.world_map_data  x, p WHERE x.world_id = p.w
  UNION ALL SELECT 'world_sessions',  x.id::text,        x.revision, x.updated_at FROM public.world_sessions  x, p WHERE x.world_id = p.w
  UNION ALL SELECT 'world_mind_map_nodes', x.id::text,   x.revision, x.updated_at FROM public.world_mind_map_nodes x, p WHERE x.world_id = p.w
  UNION ALL SELECT 'world_mind_map_edges', x.id::text,   x.revision, x.updated_at FROM public.world_mind_map_edges x, p WHERE x.world_id = p.w
  UNION ALL SELECT 'world_encounters', x.id::text,       x.revision, x.updated_at FROM public.world_encounters x, p WHERE x.world_id = p.w
  UNION ALL SELECT 'world_combatants', x.id::text,       x.revision, x.updated_at FROM public.world_combatants x, p WHERE x.world_id = p.w
  UNION ALL SELECT 'world_map_pins',   x.id::text,       x.revision, x.updated_at FROM public.world_map_pins   x, p WHERE x.world_id = p.w
  UNION ALL SELECT 'world_timeline_pins', x.id::text,    x.revision, x.updated_at FROM public.world_timeline_pins x, p WHERE x.world_id = p.w
  UNION ALL SELECT 'world_installed_packages', x.package_id::text, x.revision, x.updated_at FROM public.world_installed_packages x, p WHERE x.world_id = p.w
  UNION ALL SELECT 'world_member_state', x.user_id::text, x.revision, x.updated_at FROM public.world_member_state x, p WHERE x.world_id = p.w
  UNION ALL SELECT 'world_characters',  x.id::text,      x.revision, x.updated_at FROM public.world_characters  x, p WHERE x.world_id = p.w
)
SELECT r.t, r.row_id, r.revision, r.updated_at
FROM r, p WHERE r.revision > p.since ORDER BY r.revision;

-- Silme mi artırdı? (tombstone trigger'ı da sayacı çeviriyor)
SELECT table_name, row_id, revision, deleted_at
FROM public.world_tombstones
WHERE world_id = '47272f9a-baf7-4eb6-acdf-267f8dfc6b4e'
ORDER BY revision DESC LIMIT 10;
