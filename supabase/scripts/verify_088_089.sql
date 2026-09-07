-- ============================================================================
-- verify_088_089.sql — 088 + 089 self-check. Hiçbir kalıcı değişiklik yapmaz.
-- ============================================================================
-- Kullanım: Supabase Dashboard > SQL Editor > yapıştır > Run.
-- Sonunda ROLLBACK var; başarılıysa tek satır "088+089 OK" döner, aksi halde
-- ilk başarısız assertion exception olarak patlar.
--
-- Kapsam: yalnızca auth.uid() gerektirmeyen yollar — CHECK/trigger katmanı.
-- Cap RPC'leri (transient_reserve / pub_asset_reserve) oturum gerektirdiği
-- için burada değil; onlar client akışından doğrulanır.
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_user  UUID;
  v_world TEXT;
  v_sha   TEXT := repeat('a', 64);
  v_ok    BOOLEAN;
  v_key   TEXT;
BEGIN
  SELECT id INTO v_user FROM auth.users LIMIT 1;
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'no auth.users row — bu script gerçek bir DB''de çalışır';
  END IF;

  -- ── 088.1 — sabitler yerinde ────────────────────────────────────────────
  ASSERT public.max_share_payload_bytes() = 524288, 'payload cap != 512KB';
  ASSERT public.max_shares_per_world()    = 4000,   'share cap != 4000';

  -- ── 088.2 — 512 KB üstü gövde reddedilir ────────────────────────────────
  -- Yalnızca NOT NULL kolonlar: `state_json` 077'de düşürüldü (bulut aynası yok).
  INSERT INTO public.worlds (id, owner_id, world_name)
    VALUES ('verify-088', v_user, 'verify')
    RETURNING id INTO v_world;

  v_ok := FALSE;
  BEGIN
    INSERT INTO public.entity_shares (entity_id, world_id, shared_by, payload_json)
      VALUES ('e1', v_world, v_user, repeat('x', 524289));
  EXCEPTION WHEN check_violation THEN
    v_ok := TRUE;
  END;
  ASSERT v_ok, '512 KB üstü payload_json kabul edildi';

  -- Tam sınırda olan geçer.
  INSERT INTO public.entity_shares (entity_id, world_id, shared_by, payload_json)
    VALUES ('e2', v_world, v_user, repeat('x', 524288));

  -- ── 088.3 — satır limiti trigger'ı bağlı ────────────────────────────────
  ASSERT EXISTS (SELECT 1 FROM pg_trigger
                  WHERE tgname = 'trg_enforce_world_share_limits'
                    AND NOT tgisinternal),
         'entity_shares satır limiti trigger''ı yok';

  -- ── 089.1 — havuz bütçeleri ─────────────────────────────────────────────
  ASSERT public.transient_pool_cap_bytes()   = 5368709120::bigint, 'transient pool != 5GB';
  ASSERT public.transient_max_file_bytes()   = 104857600::bigint,  'transient file != 100MB';
  ASSERT public.pinned_pool_cap_bytes()      = 5368709120::bigint, 'pinned pool != 5GB';
  ASSERT public.pinned_per_user_cap_bytes()  = 524288000::bigint,  'pinned/user != 500MB';
  ASSERT NOT EXISTS (SELECT 1 FROM pg_proc
                      WHERE proname = 'transient_per_user_cap_bytes'),
         'transient_per_user_cap_bytes hâlâ duruyor';

  -- ── 089.2 — refcount: son ref gidene kadar obje durur ───────────────────
  INSERT INTO public.pub_assets (sha256, ext, bytes, mime_type)
    VALUES (v_sha, '.png', 1234, 'image/png');
  INSERT INTO public.pub_asset_refs (sha256, owner_id, ref_key)
    VALUES (v_sha, v_user, 'listing-A'), (v_sha, v_user, 'listing-B');

  DELETE FROM public.pub_asset_refs WHERE sha256 = v_sha AND ref_key = 'listing-A';
  ASSERT EXISTS (SELECT 1 FROM public.pub_assets WHERE sha256 = v_sha),
         'obje hâlâ referanslıyken silindi';
  ASSERT NOT EXISTS (SELECT 1 FROM public.transient_evict_queue WHERE sha256 = v_sha),
         'referanslı obje erken kuyruğa atıldı';

  -- ── 089.3 — son ref gidince obje düşer + doğru r2_key kuyruğa girer ─────
  DELETE FROM public.pub_asset_refs WHERE sha256 = v_sha AND ref_key = 'listing-B';
  ASSERT NOT EXISTS (SELECT 1 FROM public.pub_assets WHERE sha256 = v_sha),
         'son ref gitti ama obje düşmedi';
  SELECT r2_key INTO v_key FROM public.transient_evict_queue WHERE sha256 = v_sha;
  ASSERT v_key = 'pub/' || v_sha || '.png',
         format('yanlış r2_key kuyruğa girdi: %s', v_key);

  RAISE NOTICE '088+089 OK';
END $$;

ROLLBACK;
