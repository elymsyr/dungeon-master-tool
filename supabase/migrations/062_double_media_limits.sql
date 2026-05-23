-- ============================================================================
-- 062_double_media_limits.sql — Per-resim + toplam quota limitlerini 2x'le
-- ============================================================================
-- Mevcut limitler telefon kamerasından gelen resimler için çok düşüktü.
-- Bu migration:
--   1) free-media bucket per-file limitini 2 MB → 4 MB çıkarır.
--   2) Beta program quota'sını 50 MB → 100 MB çıkarır.
--
-- Eş zamanlı değişiklikler (kod tarafında):
--   • cloudflare/wrangler.toml  → MAX_UPLOAD_BYTES 20MB, USER_QUOTA_BYTES 100MB
--   • cloudflare/src/worker.ts   → KIND_MAX_BYTES 2/5 MB → 4/10 MB
--   • flutter_app/.../media_kind.dart → MediaKind.maxBytes 4/10 MB
--   • flutter_app/.../asset_service.dart → maxItemBytes 20 MB
--   • flutter_app/.../cloud_backup_repository_impl.dart → 20 MB / 100 MB
--   • flutter_app/.../beta_provider.dart → quotaBytes 100 MB
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

-- ── 1. free-media bucket file_size_limit ────────────────────────────────────
-- 053_free_media_bucket.sql 2 MB ile yaratmıştı; storage bucket'taki limit
-- Supabase Storage tarafından önceden enforce edilir, client check'inden önce.

UPDATE storage.buckets
   SET file_size_limit = 4194304  -- 4 MB
 WHERE id = 'free-media';

-- ── 2. Beta program quota 50 MB → 100 MB ────────────────────────────────────
-- 007_beta_program.sql `get_beta_quota_bytes()` 50 MB hardcoded. RPC/RLS
-- check'leri bu fonksiyona dayanır; yenisi `IMMUTABLE` kalır.

CREATE OR REPLACE FUNCTION public.get_beta_quota_bytes()
RETURNS BIGINT LANGUAGE sql IMMUTABLE AS $$ SELECT (100 * 1024 * 1024)::bigint $$;

NOTIFY pgrst, 'reload schema';
