-- ============================================================================
-- 110_notification_images.sql
--   Admin bildirimlerinin banner + gövde resimleri.
--   • Bucket `notification-images`: public (içerik public URL ile RLS'siz
--     servis edilir), 10 MB, yalnız jpeg/png/webp.
--   • Yol: {adminUid}/{ms}_{blockId}.{ext}. Veri notifications.blocks'ta
--     {id,type:'image',url,path,link?,banner?} olarak durur — tablo ve RPC'ler
--     değişmez.
--   • INSERT / DELETE yalnız is_admin(). SELECT 058 gibi sahibin klasörüyle
--     sınırlı; ek olarak admin her şeyi görür, çünkü storage remove() SELECT
--     de ister ve bir admin başka admin'in bildirimini silebilmeli.
-- ============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'notification-images',
  'notification-images',
  true,
  10485760,  -- 10 MB
  ARRAY['image/jpeg','image/png','image/webp']
)
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "notification-images admin insert" ON storage.objects;
CREATE POLICY "notification-images admin insert"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'notification-images' AND public.is_admin());

DROP POLICY IF EXISTS "notification-images admin delete" ON storage.objects;
CREATE POLICY "notification-images admin delete"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'notification-images' AND public.is_admin());

DROP POLICY IF EXISTS "notification-images owner read" ON storage.objects;
CREATE POLICY "notification-images owner read"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'notification-images'
    AND (auth.uid()::text = (storage.foldername(name))[1] OR public.is_admin())
  );

NOTIFY pgrst, 'reload schema';
