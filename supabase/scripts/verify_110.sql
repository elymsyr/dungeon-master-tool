-- ============================================================================
-- verify_110.sql — bildirim resimleri bucket'ı (110) self-check. Hiçbir kalıcı
-- değişiklik yapmaz.
-- ============================================================================
-- Kullanım: Supabase Dashboard > SQL Editor > yapıştır > Run.
-- Sonunda ROLLBACK var; başarılıysa "110 OK" notice'i döner, aksi halde ilk
-- başarısız assertion exception olarak patlar.
--
-- Kapsam:
--   1. Bucket: public, 10 MB, yalnız jpeg/png/webp.
--   2. Admin kendi klasörüne obje yazabilir.
--   3. Admin olmayan yazamaz (RLS).
--   4. Admin olmayan admin'in objesini göremez → remove() ile silemez.
--   5. Başka bir admin objeyi görür; DELETE politikası is_admin() ister.
-- Supabase storage.objects'te doğrudan DELETE'i trigger ile yasaklar
-- (storage.protect_delete), bu yüzden silme yetkisi SELECT görünürlüğü +
-- politika tanımından doğrulanır; gerçek silme Storage API'nin işi.
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_admin UUID := gen_random_uuid();
  v_user  UUID := gen_random_uuid();
  v_admin2 UUID := gen_random_uuid();
  v_ok    BOOLEAN;
  v_n     INT;
BEGIN
  -- ══ 1 — Bucket ═════════════════════════════════════════════════════════
  ASSERT EXISTS (SELECT 1 FROM storage.buckets
                  WHERE id = 'notification-images'
                    AND public
                    AND file_size_limit = 10485760
                    AND allowed_mime_types @> ARRAY['image/jpeg','image/png','image/webp']
                    AND cardinality(allowed_mime_types) = 3),
    '1.1 notification-images bucket yok ya da ayarları yanlış';

  INSERT INTO auth.users (id, aud, role, email) VALUES
    (v_admin, 'authenticated', 'authenticated', 'a110@test.local'),
    (v_user,  'authenticated', 'authenticated', 'u110@test.local'),
    (v_admin2, 'authenticated', 'authenticated', 'b110@test.local');
  INSERT INTO public.app_admins (user_id) VALUES (v_admin), (v_admin2);

  -- ══ 2 — Admin yazar ════════════════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  ASSERT auth.uid() = v_admin, '0 rol taklidi çalışmadı';
  INSERT INTO storage.objects (bucket_id, name, owner)
    VALUES ('notification-images', v_admin || '/1_b1.png', v_admin);

  -- ══ 3 — Admin olmayan yazamaz ══════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_user, 'role', 'authenticated')::text, true);
  v_ok := false;
  BEGIN
    INSERT INTO storage.objects (bucket_id, name, owner)
      VALUES ('notification-images', v_user || '/1_b2.png', v_user);
  EXCEPTION WHEN insufficient_privilege THEN v_ok := true;
  END;
  ASSERT v_ok, '3.1 admin olmayan bildirim resmi yükleyebildi';

  -- ══ 4 — Admin olmayan göremez (remove() önce SELECT eder) ══════════════
  SELECT count(*) INTO v_n FROM storage.objects
   WHERE bucket_id = 'notification-images';
  ASSERT v_n = 0, '4.1 admin olmayan bildirim resimlerini görüyor';

  -- ══ 5 — Başka admin görür; silme yalnız admin ══════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_admin2, 'role', 'authenticated')::text, true);
  SELECT count(*) INTO v_n FROM storage.objects
   WHERE bucket_id = 'notification-images';
  ASSERT v_n = 1, '5.1 admin başka admin''in resmini görmüyor';
  PERFORM set_config('role', 'postgres', true);
  ASSERT EXISTS (SELECT 1 FROM pg_policies
                  WHERE schemaname = 'storage' AND tablename = 'objects'
                    AND policyname = 'notification-images admin delete'
                    AND cmd = 'DELETE'
                    AND qual LIKE '%is_admin()%'),
    '5.2 DELETE politikası yok ya da is_admin() istemiyor';

  RAISE NOTICE '110 OK';
END $$;

ROLLBACK;
