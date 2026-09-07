-- ============================================================================
-- 088_share_payload_limits.sql — entity_shares gövde + satır sayısı sınırları
-- ============================================================================
-- Neden (docs/media-storage-redesign.md → "Postgres tarafı"):
--   078 kart gövdesini `entity_shares.payload_json`'a taşıdı ama hiçbir sınır
--   koymadı: ne satır sayısı ne gövde boyutu. Diğer her eksende limit var
--   (055: karakter 10, dünya 10, paket 10) — paylaşımda yoktu. Karakter
--   yaratım kategorilerinin otomatik paylaşımı (yeni model, madde 2) bunu tek
--   başına şişirebilir: dünyaya özgü binlerce spell/item kartı olan bir DM tek
--   dünya açtığında binlerce satır yazar.
--
-- Sınırlar:
--   • Kart başına gövde : 512 KB  → CHECK (octet_length)
--   • Dünya başına satır: 4000    → max_shares_per_world() + BEFORE INSERT trg
--
-- En kötü hâlde dünya başına ~2 GB, gerçekte ~40 MB. Trigger
-- `enforce_world_character_limits` (055) kalıbının birebir aynısı.
--
-- NOT: bu iki sayı elle seçildi ve R2 havuz sayılarından daha erken ölçülmeli —
-- Postgres dolduğunda LRU atmaz, yazma tamamen patlar.
--
-- Kullanım: Supabase Dashboard > SQL Editor > New Query > Yapıştır > Run
-- ============================================================================

-- ── 1. Kart başına gövde: 512 KB ───────────────────────────────────────────
-- NOT VALID: yeni/güncellenen satırlarda tam olarak zorlanır, mevcut tabloyu
-- taramaz. Beta verisinde 512 KB üstü satır beklenmiyor; olsaydı da migration
-- onun yüzünden patlamamalı.
ALTER TABLE public.entity_shares
  DROP CONSTRAINT IF EXISTS chk_entity_shares_payload_size;
ALTER TABLE public.entity_shares
  ADD CONSTRAINT chk_entity_shares_payload_size
  CHECK (payload_json IS NULL OR octet_length(payload_json) <= 524288)
  NOT VALID;

COMMENT ON CONSTRAINT chk_entity_shares_payload_size ON public.entity_shares IS
  'Kart gövdesi tavanı 512 KB. Sabiti değiştirirken max_share_payload_bytes() '
  'ile birlikte güncelle — CHECK ifadesi fonksiyon çağıramaz (immutability).';

-- Client tarafının pre-check yapabilmesi için okunabilir sabit. CHECK bunu
-- ÇAĞIRMAZ (Postgres CHECK'te fonksiyon değişikliği geriye yansımaz) — iki
-- yerde tutulur, birlikte değiştirilir.
CREATE OR REPLACE FUNCTION public.max_share_payload_bytes()
RETURNS BIGINT LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $$ SELECT 524288::bigint $$;

GRANT EXECUTE ON FUNCTION public.max_share_payload_bytes() TO authenticated;

-- ── 2. Dünya başına paylaşım satırı: 4000 ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.max_shares_per_world()
RETURNS INT LANGUAGE sql IMMUTABLE
SET search_path = public, pg_temp
AS $$ SELECT 4000 $$;

GRANT EXECUTE ON FUNCTION public.max_shares_per_world() TO authenticated;

-- Yalnızca INSERT sayar: rutin `payload_json` UPDATE'i tam 4000'de yanlışlıkla
-- patlamasın (055'teki `IS DISTINCT FROM` korumasının bu tablodaki karşılığı —
-- burada world_id hiç değişmediği için UPDATE'i tamamen dışarıda bırakmak
-- yeterli). Un-share DELETE her zaman serbest.
CREATE OR REPLACE FUNCTION public.enforce_world_share_limits()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  v_count INT;
BEGIN
  SELECT count(*) INTO v_count
    FROM public.entity_shares
   WHERE world_id = NEW.world_id;

  IF v_count >= public.max_shares_per_world() THEN
    RAISE EXCEPTION 'world share limit reached (%/%)',
      v_count, public.max_shares_per_world()
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_enforce_world_share_limits ON public.entity_shares;
CREATE TRIGGER trg_enforce_world_share_limits
  BEFORE INSERT ON public.entity_shares
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_world_share_limits();

NOTIFY pgrst, 'reload schema';
