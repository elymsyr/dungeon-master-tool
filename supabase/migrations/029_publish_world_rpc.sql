-- ============================================================================
-- 029_publish_world_rpc.sql — Make Online akışı için RLS-bypass RPC
-- ============================================================================
-- Sorun: client.upsert('worlds') PostgREST → INSERT ... ON CONFLICT DO UPDATE.
-- UPDATE branch'ı `is_world_dm(id)` kontrolüne takılıyor — eğer önceki
-- publish denemesi worlds row'u bıraktıysa ama tg_world_insert_dm_member
-- (RLS yüzünden) member satırını ekleyemediyse, kullanıcı row'u UPDATE
-- edemiyor ve "Make Online" 42501 hatası dönüyor.
--
-- Çözüm: tek atomik RPC. INSERT veya UPDATE'i açıkça branch'lar,
-- member row'unu ON CONFLICT ile garanti eder, RLS'i SET row_security=off
-- ile bypass eder. Yetki sahibi olmayan kullanıcılar açık hata alır.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.publish_world(
  p_world_id      TEXT,
  p_world_name    TEXT,
  p_template_id   TEXT,
  p_template_hash TEXT,
  p_state_json    TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_existing_owner UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  SELECT owner_id INTO v_existing_owner
  FROM public.worlds WHERE id = p_world_id;

  IF v_existing_owner IS NULL THEN
    INSERT INTO public.worlds (
      id, owner_id, world_name, template_id, template_hash, state_json
    ) VALUES (
      p_world_id, auth.uid(), p_world_name,
      p_template_id, p_template_hash, p_state_json
    );
  ELSIF v_existing_owner = auth.uid() THEN
    UPDATE public.worlds
       SET world_name    = p_world_name,
           template_id   = p_template_id,
           template_hash = p_template_hash,
           state_json    = p_state_json,
           updated_at    = now()
     WHERE id = p_world_id;
  ELSE
    RAISE EXCEPTION 'world % owned by different user (%)',
      p_world_id, v_existing_owner USING ERRCODE = '42501';
  END IF;

  -- DM membership idempotent (trigger'ın RLS sorunundan bağımsız).
  INSERT INTO public.world_members (world_id, user_id, role)
  VALUES (p_world_id, auth.uid(), 'dm')
  ON CONFLICT (world_id, user_id) DO UPDATE SET role = 'dm';
END $$;

GRANT EXECUTE ON FUNCTION
  public.publish_world(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
