-- ============================================================================
-- 064_beta_full_reset.sql — Mass beta wipe (one-shot, IRREVERSIBLE)
-- ============================================================================
-- Tüm beta_participants için 057'deki leave_beta cascade'ini uygular.
-- Migration deploy edilince bir kez çalışır; tekrar tetiklenirse beta tablosu
-- zaten boş olduğundan no-op.
--
-- Yapılan:
--   1. leave_beta() gövdesi `_leave_beta_for(uid uuid)` helper'a taşınır;
--      mevcut leave_beta() artık helper'ı auth.uid() ile çağırır (sözleşme
--      aynı kalır → client davranışı değişmez).
--   2. DO bloğu beta_participants'taki her user_id için helper'ı çalıştırır.
--   3. Storage objelerinin temizliği:
--      • storage.objects DELETE buradan yapılabilir (SECURITY DEFINER admin
--        context). campaign-backups + free-media bucket'larında tüm satırlar
--        zaten silinen kullanıcılar dahil HİÇBİR beta kalmadığı için TÜM
--        satırlar wipe edilir.
--      • R2 objeleri SQL'den silinemez — worker garbage-collect'i community
--        _assets satırı olmayanları zaten temizler; ayrıca worker'a manuel
--        `/admin/purge-all-users` çağrısı yapılır (runbook).
--
-- KORUNUR (sözleşme 057 ile aynı): posts, game_listings, conversations,
-- messages, profiles, follows.
-- ============================================================================

-- ── 1. _leave_beta_for(uid) — admin-callable purge helper ──────────────────
CREATE OR REPLACE FUNCTION public._leave_beta_for(p_user UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF p_user IS NULL THEN
    RETURN FALSE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.beta_participants WHERE user_id = p_user) THEN
    RETURN FALSE;
  END IF;

  DELETE FROM public.worlds WHERE owner_id = p_user;

  DELETE FROM public.world_characters
   WHERE owner_id = p_user AND world_id IS NULL;

  DELETE FROM public.personal_package_entities WHERE owner_id = p_user;
  DELETE FROM public.personal_packages         WHERE owner_id = p_user;

  DELETE FROM public.marketplace_listings WHERE owner_id = p_user;

  DELETE FROM public.free_media_assets WHERE owner_id    = p_user;
  DELETE FROM public.community_assets  WHERE uploader_id = p_user;
  DELETE FROM public.transient_shares  WHERE uploader_id = p_user;
  DELETE FROM public.cloud_backups     WHERE user_id     = p_user;

  DELETE FROM public.beta_participants WHERE user_id = p_user;

  RETURN TRUE;
END $$;

-- Helper SADECE service_role + internal trigger'lar tarafından çağrılabilir.
REVOKE ALL ON FUNCTION public._leave_beta_for(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._leave_beta_for(UUID) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public._leave_beta_for(UUID) TO service_role;

-- ── 2. leave_beta() — public RPC artık helper'ı çağırır ────────────────────
CREATE OR REPLACE FUNCTION public.leave_beta()
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN
    RETURN FALSE;
  END IF;
  RETURN public._leave_beta_for(v_user);
END $$;

GRANT EXECUTE ON FUNCTION public.leave_beta() TO authenticated;

-- ── 3. Mass wipe — every current beta participant ──────────────────────────
DO $$
DECLARE
  v_uid UUID;
  v_count INT := 0;
BEGIN
  FOR v_uid IN SELECT user_id FROM public.beta_participants LOOP
    PERFORM public._leave_beta_for(v_uid);
    v_count := v_count + 1;
  END LOOP;
  RAISE NOTICE 'beta_full_reset: purged % participant(s)', v_count;
END $$;

-- ── 4. Storage cleanup notu ────────────────────────────────────────────────
-- Supabase `storage.protect_delete()` trigger'ı direct DELETE'i bloklar
-- (`42501: Direct deletion from storage tables is not allowed`). Bu yüzden
-- `campaign-backups` ve `free-media` bucket'larındaki orphan objeleri burada
-- silemeyiz. Migration sonrası manuel temizlik:
--
--   A) Dashboard yolu (önerilen):
--      Supabase Dashboard → Storage → bucket seç → tüm objeleri seç → Delete
--      (campaign-backups + free-media için ayrı ayrı)
--
--   B) Service-role script (npm install @supabase/supabase-js):
--      const sb = createClient(URL, SERVICE_ROLE_KEY);
--      const { data } = await sb.storage.from('campaign-backups').list('', {limit: 1000});
--      await sb.storage.from('campaign-backups').remove(data.map(f => f.name));
--      // free-media için tekrarla
--
-- ── 5. R2 cleanup notu ─────────────────────────────────────────────────────
-- dmt-assets (Cloudflare R2) bucket SQL'den dokunulamaz. Deploy sonrası:
--   curl -X POST https://<worker>/admin/purge-all-users \
--        -H "Authorization: Bearer $ADMIN_TOKEN"
-- (Worker endpoint'i 064 ile birlikte deploy edilir.)

NOTIFY pgrst, 'reload schema';
