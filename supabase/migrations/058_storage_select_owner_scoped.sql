-- ============================================================================
-- 058_storage_select_owner_scoped.sql
--   Tighten the SELECT policy on the public image buckets.
--
-- `free-media`, `avatars` and `post-images` each had a bucket-wide SELECT
-- policy on storage.objects:  USING (bucket_id = '<bucket>').  A bucket-wide
-- SELECT lets ANY client call `storage.list()` and enumerate every object —
-- harvesting every uploader UUID and the full image inventory.
--
-- These buckets are PUBLIC: file *contents* are served RLS-free through the
-- public URL endpoint, so image display is unaffected. The SELECT policy only
-- gates the authenticated list()/download() API. Scoping it to the caller's
-- own folder ({uid}/...) kills cross-user enumeration while leaving owners
-- able to list/manage their own objects (e.g. the leave-beta storage wipe).
--
-- free-media note: FreeMediaService.resolveFreeMedia() previously fetched
-- other users' images via the authenticated download() API (which needs a
-- bucket-wide SELECT). The client is switched to the public URL in the same
-- change set, so owner-scoped SELECT is safe for free-media too.
-- ============================================================================

DROP POLICY IF EXISTS "free-media public read" ON storage.objects;
CREATE POLICY "free-media owner read"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'free-media'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "avatars public read" ON storage.objects;
CREATE POLICY "avatars owner read"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "post-images public read" ON storage.objects;
CREATE POLICY "post-images owner read"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'post-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

NOTIFY pgrst, 'reload schema';
