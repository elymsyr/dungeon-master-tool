-- F1 built-in decouple: the SRD pack ships locally with every client and
-- no longer needs per-world copies in the cloud. Drop every `is_builtin`
-- row so subsequent pushes start clean. The `is_builtin` column is kept
-- for one release (F6 retires it) so older clients can still read.

BEGIN;

DELETE FROM public.world_entities
 WHERE is_builtin = true;

COMMIT;
