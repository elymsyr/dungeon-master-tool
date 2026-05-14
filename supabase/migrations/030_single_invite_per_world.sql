-- ============================================================================
-- 030_single_invite_per_world.sql — Tek paylaşılabilir davet kodu / world
-- ============================================================================
-- UX değişiklik: PR-O1 (026) her invite tek-kullanımlık + N kullanım
-- destekliyordu. Yeni model — her online world için bir aktif kod;
-- DM regenerate ettiğinde eski kod ölür, yeni kod doğar. Tüm oyuncular
-- aynı kodu kullanır. uses_left "büyük sayı" (99999) ile pratikte sınırsız.
-- ============================================================================

-- ── A — Mevcut row'ları world bazında deduplicate et (en yenisi kalsın) ──
DELETE FROM public.world_invites a
USING public.world_invites b
WHERE a.world_id = b.world_id AND a.created_at < b.created_at;

-- ── B — world_id üzerinde UNIQUE kısıtı ─────────────────────────────────
ALTER TABLE public.world_invites
  DROP CONSTRAINT IF EXISTS uq_world_invites_world;
ALTER TABLE public.world_invites
  ADD CONSTRAINT uq_world_invites_world UNIQUE (world_id);

-- ── C — RPC'ler ──────────────────────────────────────────────────────────
-- ensure_world_invite: aktif kodu döner; yoksa yeni üretir.
CREATE OR REPLACE FUNCTION public.ensure_world_invite(p_world_id TEXT)
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_code   TEXT;
  v_alpha  CONSTANT TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_attempt INT := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;
  IF NOT public.is_world_dm(p_world_id) THEN
    RAISE EXCEPTION 'dm role required' USING ERRCODE = '42501';
  END IF;

  SELECT code INTO v_code
  FROM public.world_invites
  WHERE world_id = p_world_id;

  IF v_code IS NOT NULL THEN
    RETURN v_code;
  END IF;

  LOOP
    v_attempt := v_attempt + 1;
    IF v_attempt > 10 THEN
      RAISE EXCEPTION 'could not generate unique invite code';
    END IF;
    v_code := '';
    FOR i IN 1..8 LOOP
      v_code := v_code || substr(v_alpha,
        1 + floor(random() * length(v_alpha))::INT, 1);
    END LOOP;
    BEGIN
      INSERT INTO public.world_invites
        (code, world_id, created_by, uses_left, expires_at)
      VALUES (v_code, p_world_id, auth.uid(), 99999, NULL);
      RETURN v_code;
    EXCEPTION WHEN unique_violation THEN
      CONTINUE;
    END;
  END LOOP;
END $$;

GRANT EXECUTE ON FUNCTION public.ensure_world_invite(TEXT) TO authenticated;

-- regenerate_world_invite: eski kodu sil + yeni üret.
CREATE OR REPLACE FUNCTION public.regenerate_world_invite(p_world_id TEXT)
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;
  IF NOT public.is_world_dm(p_world_id) THEN
    RAISE EXCEPTION 'dm role required' USING ERRCODE = '42501';
  END IF;
  DELETE FROM public.world_invites WHERE world_id = p_world_id;
  RETURN public.ensure_world_invite(p_world_id);
END $$;

GRANT EXECUTE ON FUNCTION public.regenerate_world_invite(TEXT) TO authenticated;

-- ── D — redeem_world_invite uses_left decrement davranışı korunur ──────
-- 99999 başlangıç değeri ile pratik olarak limitsiz. DM regenerate edince
-- yeni kod = yeni 99999 sayacı.

NOTIFY pgrst, 'reload schema';
