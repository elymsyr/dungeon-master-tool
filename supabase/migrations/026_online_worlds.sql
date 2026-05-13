-- ============================================================================
-- DMT Online Multiplayer Foundation — Supabase SQL Migration
-- ============================================================================
-- World sahipliği, üyelik, davet kodu, entity/mind-map/karakter mirror'ı,
-- paylaşım kayıtları ve karakter claim havuzu. PR-O1.
--
-- Plan: /home/eren/.claude/plans/imdi-b-y-k-bir-al-ma-mossy-ember.md
--
-- Yapı: önce TÜM tablolar oluşturulur, sonra TÜM RLS politikaları + triggers
-- + RPC'ler. Sıralama ileri-referans hatalarını önler (world_entities RLS
-- entity_shares + world_characters'a bakar).
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run.
-- ============================================================================

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM A — Tablolar
-- ──────────────────────────────────────────────────────────────────────────

-- A.1 worlds — online (paylaşılan) campaign metadata + state mirror.
CREATE TABLE IF NOT EXISTS public.worlds (
  id            TEXT PRIMARY KEY,            -- mirror of local campaign.id (UUID)
  owner_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  world_name    TEXT NOT NULL,
  template_id   TEXT,
  template_hash TEXT,
  state_json    TEXT NOT NULL DEFAULT '{}',  -- mirror of campaigns.stateJson
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_worlds_owner ON public.worlds (owner_id);

-- A.2 world_members — (world_id, user_id) → role.
CREATE TABLE IF NOT EXISTS public.world_members (
  world_id   TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role       TEXT NOT NULL CHECK (role IN ('dm','player')),
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (world_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_world_members_user ON public.world_members (user_id);

-- A.3 world_invites — 8 karakter base32 davet kodu.
CREATE TABLE IF NOT EXISTS public.world_invites (
  code        TEXT PRIMARY KEY,
  world_id    TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  created_by  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  expires_at  TIMESTAMPTZ,
  uses_left   INT NOT NULL DEFAULT 1 CHECK (uses_left >= 0),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_world_invites_world ON public.world_invites (world_id);

-- A.4 world_entities — Drift Entities tablosunun mirror'ı.
CREATE TABLE IF NOT EXISTS public.world_entities (
  id                TEXT PRIMARY KEY,
  world_id          TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  category_slug     TEXT NOT NULL,
  name              TEXT NOT NULL,
  source            TEXT NOT NULL DEFAULT '',
  description       TEXT NOT NULL DEFAULT '',
  image_path        TEXT NOT NULL DEFAULT '',
  images_json       TEXT NOT NULL DEFAULT '[]',
  tags_json         TEXT NOT NULL DEFAULT '[]',
  dm_notes          TEXT NOT NULL DEFAULT '',
  pdfs_json         TEXT NOT NULL DEFAULT '[]',
  location_id       TEXT,
  fields_json       TEXT NOT NULL DEFAULT '{}',
  package_id        TEXT,
  package_entity_id TEXT,
  linked            BOOLEAN NOT NULL DEFAULT false,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_world_entities_world ON public.world_entities (world_id);
CREATE INDEX IF NOT EXISTS idx_world_entities_world_category
  ON public.world_entities (world_id, category_slug);

-- A.5 world_mind_map_nodes — per-player veya DM haritası.
-- map_id konvansiyonu:
--   'default'         → DM'in ana haritası (player göremez)
--   'player_<uid>'    → o oyuncuya özel (sadece kendisi + DM)
CREATE TABLE IF NOT EXISTS public.world_mind_map_nodes (
  id          TEXT PRIMARY KEY,
  world_id    TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  map_id      TEXT NOT NULL,
  label       TEXT NOT NULL DEFAULT '',
  node_type   TEXT NOT NULL DEFAULT 'note',
  x           DOUBLE PRECISION NOT NULL DEFAULT 0,
  y           DOUBLE PRECISION NOT NULL DEFAULT 0,
  width       DOUBLE PRECISION NOT NULL DEFAULT 150,
  height      DOUBLE PRECISION NOT NULL DEFAULT 80,
  entity_id   TEXT,
  image_url   TEXT,
  content     TEXT NOT NULL DEFAULT '',
  style_json  TEXT NOT NULL DEFAULT '{}',
  color       TEXT NOT NULL DEFAULT '',
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_mind_map_nodes_world_map
  ON public.world_mind_map_nodes (world_id, map_id);

-- A.6 world_mind_map_edges.
CREATE TABLE IF NOT EXISTS public.world_mind_map_edges (
  id          TEXT PRIMARY KEY,
  world_id    TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  map_id      TEXT NOT NULL,
  source_id   TEXT NOT NULL,
  target_id   TEXT NOT NULL,
  label       TEXT NOT NULL DEFAULT '',
  style_json  TEXT NOT NULL DEFAULT '{}',
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_mind_map_edges_world_map
  ON public.world_mind_map_edges (world_id, map_id);

-- A.7 world_characters — Hub-level Character mirror.
-- referenced_entity_ids: karakterin field/inventory'sinde gönderilen entity
-- id'leri (JSONB array). entity_shares dışındaki implicit görünürlük için
-- RLS bu sütunu kullanır. DM client her save'de yeniden hesaplar.
CREATE TABLE IF NOT EXISTS public.world_characters (
  id                     TEXT PRIMARY KEY,
  world_id               TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  owner_id               UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  template_id            TEXT NOT NULL,
  template_name          TEXT NOT NULL,
  payload_json           TEXT NOT NULL DEFAULT '{}',  -- full Character JSON
  referenced_entity_ids  JSONB NOT NULL DEFAULT '[]',
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_world_characters_world ON public.world_characters (world_id);
CREATE INDEX IF NOT EXISTS idx_world_characters_owner ON public.world_characters (owner_id);
CREATE INDEX IF NOT EXISTS idx_world_characters_refs
  ON public.world_characters USING GIN (referenced_entity_ids);

-- A.8 entity_shares — DM "Paylaş" sonucu kayıtlar.
-- shared_with NULL = tüm world üyeleri.
-- PK expression desteklemediği için synthetic id + iki partial unique index.
-- (Realtime CDC tabloya PK ya da REPLICA IDENTITY FULL ister.)
CREATE TABLE IF NOT EXISTS public.entity_shares (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_id    TEXT NOT NULL,
  world_id     TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  shared_with  UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  shared_by    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  shared_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_entity_shares_per_user
  ON public.entity_shares (entity_id, world_id, shared_with)
  WHERE shared_with IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_entity_shares_worldwide
  ON public.entity_shares (entity_id, world_id)
  WHERE shared_with IS NULL;
CREATE INDEX IF NOT EXISTS idx_entity_shares_world ON public.entity_shares (world_id);
CREATE INDEX IF NOT EXISTS idx_entity_shares_target
  ON public.entity_shares (world_id, shared_with);

-- A.9 character_claim_pool — DM "available for claim" işaretli karakterler.
CREATE TABLE IF NOT EXISTS public.character_claim_pool (
  character_id  TEXT PRIMARY KEY REFERENCES public.world_characters(id) ON DELETE CASCADE,
  world_id      TEXT NOT NULL REFERENCES public.worlds(id) ON DELETE CASCADE,
  available     BOOLEAN NOT NULL DEFAULT true,
  claimed_by    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  claimed_at    TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_claim_pool_world_avail
  ON public.character_claim_pool (world_id, available);

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM B — Yardımcı Fonksiyonlar
-- ──────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.is_world_member(p_world TEXT)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.world_members
    WHERE world_id = p_world AND user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.is_world_dm(p_world TEXT)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.world_members
    WHERE world_id = p_world AND user_id = auth.uid() AND role = 'dm'
  );
$$;

-- Mind map erişim kontrolü: DM her şeyi görür; player sadece 'player_<uid>'
-- ile eşleşen map'i.
CREATE OR REPLACE FUNCTION public.can_access_map(p_world TEXT, p_map TEXT)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    public.is_world_dm(p_world)
    OR (
      public.is_world_member(p_world)
      AND p_map = 'player_' || auth.uid()::TEXT
    );
$$;

GRANT EXECUTE ON FUNCTION public.is_world_member(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_world_dm(TEXT)     TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_access_map(TEXT, TEXT) TO authenticated;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM C — RLS Aç + Politikalar
-- ──────────────────────────────────────────────────────────────────────────

ALTER TABLE public.worlds                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_members           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_invites           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_entities          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_mind_map_nodes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_mind_map_edges    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_characters        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entity_shares           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.character_claim_pool    ENABLE ROW LEVEL SECURITY;

-- C.1 worlds
DROP POLICY IF EXISTS "Worlds: members read" ON public.worlds;
CREATE POLICY "Worlds: members read"
  ON public.worlds FOR SELECT
  USING (public.is_world_member(id));

DROP POLICY IF EXISTS "Worlds: owner insert" ON public.worlds;
CREATE POLICY "Worlds: owner insert"
  ON public.worlds FOR INSERT
  WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Worlds: dm update" ON public.worlds;
CREATE POLICY "Worlds: dm update"
  ON public.worlds FOR UPDATE
  USING (public.is_world_dm(id))
  WITH CHECK (public.is_world_dm(id));

DROP POLICY IF EXISTS "Worlds: owner delete" ON public.worlds;
CREATE POLICY "Worlds: owner delete"
  ON public.worlds FOR DELETE
  USING (auth.uid() = owner_id);

-- C.2 world_members
DROP POLICY IF EXISTS "Members: visible to fellow members" ON public.world_members;
CREATE POLICY "Members: visible to fellow members"
  ON public.world_members FOR SELECT
  USING (public.is_world_member(world_id));

DROP POLICY IF EXISTS "Members: dm manages" ON public.world_members;
CREATE POLICY "Members: dm manages"
  ON public.world_members FOR ALL
  USING (public.is_world_dm(world_id))
  WITH CHECK (public.is_world_dm(world_id));

DROP POLICY IF EXISTS "Members: self leave" ON public.world_members;
CREATE POLICY "Members: self leave"
  ON public.world_members FOR DELETE
  USING (auth.uid() = user_id AND role <> 'dm');

-- C.3 world_invites — sadece DM yönetir/listeler. Redemption RPC SECURITY DEFINER.
DROP POLICY IF EXISTS "Invites: dm reads" ON public.world_invites;
CREATE POLICY "Invites: dm reads"
  ON public.world_invites FOR SELECT
  USING (public.is_world_dm(world_id));

DROP POLICY IF EXISTS "Invites: dm manages" ON public.world_invites;
CREATE POLICY "Invites: dm manages"
  ON public.world_invites FOR ALL
  USING (public.is_world_dm(world_id))
  WITH CHECK (public.is_world_dm(world_id));

-- C.4 world_entities — DM full; player sadece (shared ∪ kendi char'ında ref).
DROP POLICY IF EXISTS "Entities: dm reads all, player reads shared+owned" ON public.world_entities;
CREATE POLICY "Entities: dm reads all, player reads shared+owned"
  ON public.world_entities FOR SELECT
  USING (
    public.is_world_dm(world_id)
    OR (
      public.is_world_member(world_id) AND (
        EXISTS (
          SELECT 1 FROM public.entity_shares s
          WHERE s.entity_id = world_entities.id
            AND s.world_id  = world_entities.world_id
            AND (s.shared_with IS NULL OR s.shared_with = auth.uid())
        )
        OR EXISTS (
          SELECT 1 FROM public.world_characters c
          WHERE c.world_id = world_entities.world_id
            AND c.owner_id = auth.uid()
            AND c.referenced_entity_ids ? world_entities.id
        )
      )
    )
  );

DROP POLICY IF EXISTS "Entities: dm writes" ON public.world_entities;
CREATE POLICY "Entities: dm writes"
  ON public.world_entities FOR ALL
  USING (public.is_world_dm(world_id))
  WITH CHECK (public.is_world_dm(world_id));

-- C.5 world_mind_map_nodes
DROP POLICY IF EXISTS "MMNodes: scoped access" ON public.world_mind_map_nodes;
CREATE POLICY "MMNodes: scoped access"
  ON public.world_mind_map_nodes FOR ALL
  USING (public.can_access_map(world_id, map_id))
  WITH CHECK (public.can_access_map(world_id, map_id));

-- C.6 world_mind_map_edges
DROP POLICY IF EXISTS "MMEdges: scoped access" ON public.world_mind_map_edges;
CREATE POLICY "MMEdges: scoped access"
  ON public.world_mind_map_edges FOR ALL
  USING (public.can_access_map(world_id, map_id))
  WITH CHECK (public.can_access_map(world_id, map_id));

-- C.7 world_characters — DM full; player sadece kendi karakteri.
DROP POLICY IF EXISTS "Chars: dm full" ON public.world_characters;
CREATE POLICY "Chars: dm full"
  ON public.world_characters FOR ALL
  USING (public.is_world_dm(world_id))
  WITH CHECK (public.is_world_dm(world_id));

DROP POLICY IF EXISTS "Chars: player reads own" ON public.world_characters;
CREATE POLICY "Chars: player reads own"
  ON public.world_characters FOR SELECT
  USING (public.is_world_member(world_id) AND owner_id = auth.uid());

DROP POLICY IF EXISTS "Chars: player writes own" ON public.world_characters;
CREATE POLICY "Chars: player writes own"
  ON public.world_characters FOR UPDATE
  USING (public.is_world_member(world_id) AND owner_id = auth.uid())
  WITH CHECK (public.is_world_member(world_id) AND owner_id = auth.uid());

DROP POLICY IF EXISTS "Chars: player inserts own" ON public.world_characters;
CREATE POLICY "Chars: player inserts own"
  ON public.world_characters FOR INSERT
  WITH CHECK (public.is_world_member(world_id) AND owner_id = auth.uid());

-- C.8 entity_shares
DROP POLICY IF EXISTS "Shares: scoped read" ON public.entity_shares;
CREATE POLICY "Shares: scoped read"
  ON public.entity_shares FOR SELECT
  USING (
    public.is_world_dm(world_id)
    OR (
      public.is_world_member(world_id)
      AND (shared_with IS NULL OR shared_with = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Shares: dm writes" ON public.entity_shares;
CREATE POLICY "Shares: dm writes"
  ON public.entity_shares FOR ALL
  USING (public.is_world_dm(world_id))
  WITH CHECK (public.is_world_dm(world_id));

-- C.9 character_claim_pool
DROP POLICY IF EXISTS "ClaimPool: members read" ON public.character_claim_pool;
CREATE POLICY "ClaimPool: members read"
  ON public.character_claim_pool FOR SELECT
  USING (public.is_world_member(world_id));

DROP POLICY IF EXISTS "ClaimPool: dm writes" ON public.character_claim_pool;
CREATE POLICY "ClaimPool: dm writes"
  ON public.character_claim_pool FOR ALL
  USING (public.is_world_dm(world_id))
  WITH CHECK (public.is_world_dm(world_id));

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM D — Trigger'lar
-- ──────────────────────────────────────────────────────────────────────────

-- D.1 worlds INSERT sonrası DM otomatik member.
CREATE OR REPLACE FUNCTION public.tg_world_insert_dm_member()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.world_members (world_id, user_id, role)
  VALUES (NEW.id, NEW.owner_id, 'dm')
  ON CONFLICT (world_id, user_id) DO UPDATE SET role = 'dm';
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_world_insert_dm_member ON public.worlds;
CREATE TRIGGER trg_world_insert_dm_member
  AFTER INSERT ON public.worlds
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_world_insert_dm_member();

-- D.2 updated_at bump (last-writer-wins reconcile için kritik).
CREATE OR REPLACE FUNCTION public.tg_bump_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_worlds_bump_updated  ON public.worlds;
CREATE TRIGGER trg_worlds_bump_updated
  BEFORE UPDATE ON public.worlds
  FOR EACH ROW EXECUTE FUNCTION public.tg_bump_updated_at();

DROP TRIGGER IF EXISTS trg_entities_bump_updated ON public.world_entities;
CREATE TRIGGER trg_entities_bump_updated
  BEFORE UPDATE ON public.world_entities
  FOR EACH ROW EXECUTE FUNCTION public.tg_bump_updated_at();

DROP TRIGGER IF EXISTS trg_mm_nodes_bump_updated ON public.world_mind_map_nodes;
CREATE TRIGGER trg_mm_nodes_bump_updated
  BEFORE UPDATE ON public.world_mind_map_nodes
  FOR EACH ROW EXECUTE FUNCTION public.tg_bump_updated_at();

DROP TRIGGER IF EXISTS trg_mm_edges_bump_updated ON public.world_mind_map_edges;
CREATE TRIGGER trg_mm_edges_bump_updated
  BEFORE UPDATE ON public.world_mind_map_edges
  FOR EACH ROW EXECUTE FUNCTION public.tg_bump_updated_at();

DROP TRIGGER IF EXISTS trg_chars_bump_updated ON public.world_characters;
CREATE TRIGGER trg_chars_bump_updated
  BEFORE UPDATE ON public.world_characters
  FOR EACH ROW EXECUTE FUNCTION public.tg_bump_updated_at();

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM E — RPC'ler (invite üretme/kullanma, claim)
-- ──────────────────────────────────────────────────────────────────────────

-- E.1 create_world_invite — DM 8 karakter base32 kod üretir.
-- Alfabe ambigous-free: I, 1, 0, O harf/rakamları yok.
CREATE OR REPLACE FUNCTION public.create_world_invite(
  p_world_id     TEXT,
  p_expires_secs INT DEFAULT NULL,
  p_uses         INT DEFAULT 1
) RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_alpha   CONSTANT TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code    TEXT;
  v_attempt INT := 0;
BEGIN
  IF NOT public.is_world_dm(p_world_id) THEN
    RAISE EXCEPTION 'dm role required for world %', p_world_id USING ERRCODE = '42501';
  END IF;
  IF p_uses < 1 OR p_uses > 100 THEN
    RAISE EXCEPTION 'p_uses must be between 1 and 100';
  END IF;

  LOOP
    v_attempt := v_attempt + 1;
    IF v_attempt > 10 THEN
      RAISE EXCEPTION 'could not generate unique invite code after 10 attempts';
    END IF;

    v_code := '';
    FOR i IN 1..8 LOOP
      v_code := v_code || substr(v_alpha, 1 + floor(random() * length(v_alpha))::INT, 1);
    END LOOP;

    BEGIN
      INSERT INTO public.world_invites (code, world_id, created_by, expires_at, uses_left)
      VALUES (
        v_code,
        p_world_id,
        auth.uid(),
        CASE WHEN p_expires_secs IS NULL THEN NULL
             ELSE now() + (p_expires_secs || ' seconds')::INTERVAL END,
        p_uses
      );
      RETURN v_code;
    EXCEPTION WHEN unique_violation THEN
      CONTINUE;
    END;
  END LOOP;
END $$;

GRANT EXECUTE ON FUNCTION public.create_world_invite(TEXT, INT, INT) TO authenticated;

-- E.2 redeem_world_invite — player kodu kullanır, world_members'a eklenir.
CREATE OR REPLACE FUNCTION public.redeem_world_invite(p_code TEXT)
RETURNS TABLE (world_id TEXT, world_name TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
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

-- E.3 claim_character — pool'dan al, owner_id güncelle.
CREATE OR REPLACE FUNCTION public.claim_character(p_character_id TEXT)
RETURNS TABLE (character_id TEXT, world_id TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_world_id  TEXT;
  v_available BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'auth required';
  END IF;

  SELECT cp.world_id, cp.available
    INTO v_world_id, v_available
  FROM public.character_claim_pool cp
  WHERE cp.character_id = p_character_id
  FOR UPDATE;

  IF v_world_id IS NULL THEN
    RAISE EXCEPTION 'character not in claim pool' USING ERRCODE = 'P0002';
  END IF;
  IF NOT v_available THEN
    RAISE EXCEPTION 'character already claimed' USING ERRCODE = 'P0003';
  END IF;
  IF NOT public.is_world_member(v_world_id) THEN
    RAISE EXCEPTION 'not a world member' USING ERRCODE = '42501';
  END IF;

  UPDATE public.character_claim_pool
     SET available = false,
         claimed_by = auth.uid(),
         claimed_at = now()
   WHERE character_id = p_character_id;

  UPDATE public.world_characters
     SET owner_id   = auth.uid(),
         updated_at = now()
   WHERE id = p_character_id;

  RETURN QUERY SELECT p_character_id, v_world_id;
END $$;

GRANT EXECUTE ON FUNCTION public.claim_character(TEXT) TO authenticated;

-- ──────────────────────────────────────────────────────────────────────────
-- BÖLÜM F — Realtime Publication
-- ──────────────────────────────────────────────────────────────────────────
-- Postgres CDC bu tablolardaki INSERT/UPDATE/DELETE'leri client'lara yayar.
-- supabase_realtime publication Supabase'de varsayılan olarak var.
-- Idempotent: tablo publication'da ise sessizce geç.

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'worlds', 'world_members', 'world_entities',
    'world_mind_map_nodes', 'world_mind_map_edges',
    'world_characters', 'entity_shares', 'character_claim_pool'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END $$;

-- ── PostgREST schema cache reload ──────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
