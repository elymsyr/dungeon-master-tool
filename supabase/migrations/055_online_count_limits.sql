-- ============================================================================
-- 055_online_count_limits.sql — Per-user / per-world sayı limitleri
-- ============================================================================
-- Yeni limitler:
--   - online karakter / kullanıcı : 10
--   - online dünya   / kullanıcı : 10
--   - karakter       / dünya     : 10
--   - online package / kullanıcı : 10
--
-- Server-side source-of-truth: world_characters BEFORE INSERT/UPDATE trigger +
-- publish_world / publish_personal_package RPC içi sayım. Client tarafı ayrıca
-- pre-check yapar ama asıl yetki burada. Limit aşımı `check_violation` (SQLSTATE
-- 23514) ERRCODE'u ile fırlatılır → client net mesaja çevirir.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

-- ── 1. Konfigüre edilebilir limit sabitleri ────────────────────────────────
-- beta_slot_cap() pattern'i — tek noktadan değiştirilebilir IMMUTABLE fn.

CREATE OR REPLACE FUNCTION public.max_online_characters_per_user()
RETURNS INT LANGUAGE sql IMMUTABLE AS $$ SELECT 10 $$;

CREATE OR REPLACE FUNCTION public.max_online_worlds_per_user()
RETURNS INT LANGUAGE sql IMMUTABLE AS $$ SELECT 10 $$;

CREATE OR REPLACE FUNCTION public.max_characters_per_world()
RETURNS INT LANGUAGE sql IMMUTABLE AS $$ SELECT 10 $$;

CREATE OR REPLACE FUNCTION public.max_online_packages_per_user()
RETURNS INT LANGUAGE sql IMMUTABLE AS $$ SELECT 10 $$;

-- ── 2. world_characters limit trigger ──────────────────────────────────────
-- İki eksen: (a) bir dünyadaki karakter sayısı, (b) bir kullanıcının sahip
-- olduğu online karakter sayısı. Yalnızca ilgili eksen GERÇEKTEN değiştiğinde
-- yeniden sayar (`IS DISTINCT FROM`) — rutin payload_json UPDATE'i tam 10'da
-- yanlışlıkla patlamasın. `id <> NEW.id` ile satırın kendisi dışlanır.
--
-- claim_character / assign_character owner_id'yi değiştirir → kazanan kullanıcı
-- yeniden doğrulanır. release_character / remove_from_world ekseni NULL'a düşer
-- → hiçbir limit kontrolü tetiklenmez (dünyadan/sahiplikten çıkış hep serbest).

CREATE OR REPLACE FUNCTION public.enforce_world_character_limits()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_count INT;
BEGIN
  -- (a) Per-world: dünyadaki toplam karakter.
  IF NEW.world_id IS NOT NULL
     AND (TG_OP = 'INSERT' OR OLD.world_id IS DISTINCT FROM NEW.world_id) THEN
    SELECT count(*) INTO v_count
      FROM public.world_characters
     WHERE world_id = NEW.world_id AND id <> NEW.id;
    IF v_count >= public.max_characters_per_world() THEN
      RAISE EXCEPTION 'world character limit reached (%/%)',
        v_count, public.max_characters_per_world()
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  -- (b) Per-user: kullanıcının sahip olduğu online karakterler (orphan dahil).
  IF NEW.owner_id IS NOT NULL
     AND (TG_OP = 'INSERT' OR OLD.owner_id IS DISTINCT FROM NEW.owner_id) THEN
    SELECT count(*) INTO v_count
      FROM public.world_characters
     WHERE owner_id = NEW.owner_id AND id <> NEW.id;
    IF v_count >= public.max_online_characters_per_user() THEN
      RAISE EXCEPTION 'online character limit reached (%/%)',
        v_count, public.max_online_characters_per_user()
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_enforce_world_char_limits ON public.world_characters;
CREATE TRIGGER trg_enforce_world_char_limits
  BEFORE INSERT OR UPDATE ON public.world_characters
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_world_character_limits();

-- ── 3. publish_world — yeni dünya için per-user limit ──────────────────────
-- 029'un gövdesi + INSERT branch'ine sayım eklendi. UPDATE branch (mevcut
-- dünyayı yeniden publish) saymaz.

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
  v_world_count    INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  SELECT owner_id INTO v_existing_owner
  FROM public.worlds WHERE id = p_world_id;

  IF v_existing_owner IS NULL THEN
    -- Yeni dünya — per-user online dünya limiti.
    SELECT count(*) INTO v_world_count
    FROM public.worlds WHERE owner_id = auth.uid();
    IF v_world_count >= public.max_online_worlds_per_user() THEN
      RAISE EXCEPTION 'online world limit reached (%/%)',
        v_world_count, public.max_online_worlds_per_user()
        USING ERRCODE = 'check_violation';
    END IF;

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

  -- DM membership idempotent.
  INSERT INTO public.world_members (world_id, user_id, role)
  VALUES (p_world_id, auth.uid(), 'dm')
  ON CONFLICT (world_id, user_id) DO UPDATE SET role = 'dm';
END $$;

GRANT EXECUTE ON FUNCTION
  public.publish_world(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- ── 4. publish_personal_package — yeni package için per-user limit ─────────
-- 033'teki `INSERT ... ON CONFLICT DO UPDATE` upsert insert/update ayırt
-- edemiyor → explicit branch'e çevrildi (publish_world pattern'i).

CREATE OR REPLACE FUNCTION public.publish_personal_package(
  p_package_name TEXT,
  p_state_json TEXT
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_exists    BOOLEAN;
  v_pkg_count INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required' USING ERRCODE = '42501';
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.personal_packages
     WHERE owner_id = auth.uid() AND package_name = p_package_name
  ) INTO v_exists;

  IF NOT v_exists THEN
    -- Yeni package — per-user online package limiti.
    SELECT count(*) INTO v_pkg_count
    FROM public.personal_packages WHERE owner_id = auth.uid();
    IF v_pkg_count >= public.max_online_packages_per_user() THEN
      RAISE EXCEPTION 'online package limit reached (%/%)',
        v_pkg_count, public.max_online_packages_per_user()
        USING ERRCODE = 'check_violation';
    END IF;
    INSERT INTO public.personal_packages (owner_id, package_name, state_json)
    VALUES (auth.uid(), p_package_name, p_state_json);
  ELSE
    UPDATE public.personal_packages
       SET state_json = p_state_json,
           updated_at = now()
     WHERE owner_id = auth.uid() AND package_name = p_package_name;
  END IF;
END $$;

GRANT EXECUTE ON FUNCTION
  public.publish_personal_package(TEXT, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
