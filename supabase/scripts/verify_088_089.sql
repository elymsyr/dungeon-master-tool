-- ============================================================================
-- verify_088_089.sql — 088 + 089 self-check. Hiçbir kalıcı değişiklik yapmaz.
-- ============================================================================
-- Kullanım: Supabase Dashboard > SQL Editor > yapıştır > Run.
-- Sonunda ROLLBACK var; başarılıysa tek satır "088+089 OK" döner, aksi halde
-- ilk başarısız assertion exception olarak patlar.
--
-- Kapsam: yalnızca auth.uid() gerektirmeyen yollar — CHECK/trigger katmanı.
-- Cap RPC'si (pub_asset_reserve) oturum gerektirdiği
-- için burada değil; onlar client akışından doğrulanır.
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_user  UUID;
  v_sha   TEXT := repeat('a', 64);
  v_key   TEXT;
BEGIN
  SELECT id INTO v_user FROM auth.users LIMIT 1;
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'no auth.users row — bu script gerçek bir DB''de çalışır';
  END IF;

  -- ── 088.1 — sabitler yerinde ────────────────────────────────────────────
  ASSERT public.max_shares_per_world()    = 4000,   'share cap != 4000';

  -- ── 088.2 — 512 KB gövde sınırı 103'te sütunla birlikte düştü ──────────

  -- ── 088.3 — satır limiti trigger'ı bağlı ────────────────────────────────
  ASSERT EXISTS (SELECT 1 FROM pg_trigger
                  WHERE tgname = 'trg_enforce_world_share_limits'
                    AND NOT tgisinternal),
         'entity_shares satır limiti trigger''ı yok';

  -- ── 089.1 — havuz bütçeleri ─────────────────────────────────────────────
  -- 099'dan beri iki havuz tavanı yok; tek toplam tavan verify_099'da.
  ASSERT public.pinned_per_user_cap_bytes()  = 524288000::bigint,  'pinned/user != 500MB';

  -- ── 089.2 — refcount: son ref gidene kadar obje durur ───────────────────
  INSERT INTO public.pub_assets (sha256, ext, bytes, mime_type)
    VALUES (v_sha, '.png', 1234, 'image/png');
  INSERT INTO public.pub_asset_refs (sha256, owner_id, ref_key)
    VALUES (v_sha, v_user, 'listing-A'), (v_sha, v_user, 'listing-B');

  DELETE FROM public.pub_asset_refs WHERE sha256 = v_sha AND ref_key = 'listing-A';
  ASSERT EXISTS (SELECT 1 FROM public.pub_assets WHERE sha256 = v_sha),
         'obje hâlâ referanslıyken silindi';
  ASSERT NOT EXISTS (SELECT 1 FROM public.r2_evict_queue WHERE sha256 = v_sha),
         'referanslı obje erken kuyruğa atıldı';

  -- ── 089.3 — son ref gidince obje düşer + doğru r2_key kuyruğa girer ─────
  DELETE FROM public.pub_asset_refs WHERE sha256 = v_sha AND ref_key = 'listing-B';
  ASSERT NOT EXISTS (SELECT 1 FROM public.pub_assets WHERE sha256 = v_sha),
         'son ref gitti ama obje düşmedi';
  SELECT r2_key INTO v_key FROM public.r2_evict_queue WHERE sha256 = v_sha;
  ASSERT v_key = 'pub/' || v_sha || '.png',
         format('yanlış r2_key kuyruğa girdi: %s', v_key);

  RAISE NOTICE '088+089 OK';
END $$;

ROLLBACK;
