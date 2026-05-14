-- ============================================================================
-- 028_whoami_diagnostic.sql — DMT online multiplayer diagnostic helper
-- ============================================================================
-- Client tarafında "auth.uid() ne döner?" sorusunu cevaplamak için minimal
-- RPC. publishWorld başarısız olduğunda Flutter log'una bu çağrının sonucu
-- düşer; client'ın gönderdiği uid ile server'ın gördüğü uid karşılaştırılır.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.whoami()
RETURNS TABLE (uid UUID, has_jwt BOOLEAN)
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public
AS $$
  SELECT auth.uid(), auth.uid() IS NOT NULL;
$$;

GRANT EXECUTE ON FUNCTION public.whoami() TO authenticated, anon;

NOTIFY pgrst, 'reload schema';
