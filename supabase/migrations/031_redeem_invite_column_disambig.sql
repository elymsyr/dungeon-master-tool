-- ============================================================================
-- 031_redeem_invite_column_disambig.sql — redeem_world_invite hotfix
-- ============================================================================
-- Sorun: 026'daki `redeem_world_invite` PL/pgSQL fonksiyonu
--   `RETURNS TABLE (world_id TEXT, world_name TEXT)`
-- şeklinde OUT parametreleri tanımlamıştı. Fonksiyon gövdesindeki
--   `SELECT w.id, w.world_name FROM public.worlds w ...`
-- ifadesinde `world_name`, hem OUT değişken adına hem de
-- `public.worlds.world_name` sütun adına denk geldiği için PostgreSQL
-- "column reference \"world_name\" is ambiguous" hatası fırlatıyor ve
-- davet kodu kullanılamıyor.
--
-- Çözüm: gövdeye `#variable_conflict use_column` direktifi ekle. Böylece
-- isim çakışmasında parser her zaman sütunu tercih eder. RETURNS TABLE
-- imzası ve RPC sözleşmesi (PostgREST → Dart client) değişmiyor.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.redeem_world_invite(p_code TEXT)
RETURNS TABLE (world_id TEXT, world_name TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
#variable_conflict use_column
DECLARE
  v_world_id   TEXT;
  v_uses_left  INT;
  v_expires_at TIMESTAMPTZ;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required';
  END IF;

  SELECT i.world_id, i.uses_left, i.expires_at
    INTO v_world_id, v_uses_left, v_expires_at
  FROM public.world_invites i
  WHERE i.code = upper(p_code)
  FOR UPDATE;

  IF v_world_id IS NULL THEN
    RAISE EXCEPTION 'invite not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_uses_left <= 0 THEN
    RAISE EXCEPTION 'invite exhausted' USING ERRCODE = 'P0003';
  END IF;
  IF v_expires_at IS NOT NULL AND v_expires_at < now() THEN
    RAISE EXCEPTION 'invite expired' USING ERRCODE = 'P0004';
  END IF;

  INSERT INTO public.world_members (world_id, user_id, role)
  VALUES (v_world_id, auth.uid(), 'player')
  ON CONFLICT (world_id, user_id) DO NOTHING;

  UPDATE public.world_invites
     SET uses_left = uses_left - 1
   WHERE code = upper(p_code);

  RETURN QUERY
    SELECT w.id, w.world_name FROM public.worlds w WHERE w.id = v_world_id;
END $$;

GRANT EXECUTE ON FUNCTION public.redeem_world_invite(TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
