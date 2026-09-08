-- 092: Talep-üzerine medya akışı — oyuncu eksik SHA bildirir, DM yükler.
--
-- Neden (docs/media-storage-redesign.md, Phase C):
--   Bugün DM bir kartı paylaşırken kartın TÜM yerel görsellerini eager olarak
--   yüklüyor. Yeni modelde transient havuza yalnızca "o an gerçekten birine
--   eksik olan" bayt girer:
--
--     1. DM paylaşırken görselleri yüklemez; payload'daki ref'leri
--        `dmt-transient://{sha}{ext}` içerik-adresli hâle çevirir (baytlar
--        hâlâ yalnızca DM'in diskinde).
--     2. Oyuncu satırı uygular, çözemediği SHA'ları bildirir →
--        world_members.missing_shas.
--     3. DM bu güncellemeyi CDC ile görür, yalnızca listedeki SHA'ları
--        transient'e yükler.
--     4. Oyuncu indirir, listesini yeniden yazar (çözülenler düşer).
--
--   Yeni abone tablo yok: `world_members` zaten beş abone tablodan biri.
--
-- Neden RLS policy değil RPC:
--   Oyuncuya `world_members` üzerinde düz self-UPDATE vermek, WITH CHECK
--   OLD satırı göremediği için `role`'ü 'player' → 'dm' yapmasına izin
--   verirdi. SECURITY DEFINER RPC yalnızca tek kolona dokunur.

ALTER TABLE public.world_members
  ADD COLUMN IF NOT EXISTS missing_shas TEXT[] NOT NULL DEFAULT '{}';

COMMENT ON COLUMN public.world_members.missing_shas IS
  'Bu üyenin çözemediği transient SHA-256''lar. Oyuncu report_missing_shas ile '
  'tam listeyi yazar (idempotent, çözülenler kendiliğinden düşer); DM CDC ile '
  'görüp yalnızca bunları transient havuza yükler.';

-- Tavan: 055/065/088'deki değiştirilebilir IMMUTABLE fn kalıbı.
CREATE OR REPLACE FUNCTION public.max_missing_shas()
RETURNS INT LANGUAGE sql IMMUTABLE
SET search_path = public
AS $$ SELECT 500 $$;

GRANT EXECUTE ON FUNCTION public.max_missing_shas() TO authenticated;

-- Oyuncu kendi üyelik satırının SADECE missing_shas kolonunu yazar.
-- Liste tümüyle değiştirilir: oyuncu her seferinde "hâlâ eksik olanlar"ı
-- gönderir, dolayısıyla ayrı bir temizleme yoluna gerek yok.
CREATE OR REPLACE FUNCTION public.report_missing_shas(
  _world TEXT,
  _shas  TEXT[]
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_clean TEXT[];
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = 'P0001';
  END IF;
  IF NOT public.is_world_member(_world) THEN
    RAISE EXCEPTION 'not_a_member' USING ERRCODE = 'P0001';
  END IF;

  -- Yalnızca sha256 hex'i kabul et + tekilleştir + tavana kırp. Kolon
  -- oyuncu tarafından yazılıyor; DM'in okuduğu şeyin şekli garanti olsun.
  SELECT ARRAY(
    SELECT s FROM (
      SELECT DISTINCT lower(s) AS s
      FROM unnest(COALESCE(_shas, '{}')) AS s
      WHERE s ~ '^[0-9a-fA-F]{64}$'
    ) q
    ORDER BY s
    LIMIT public.max_missing_shas()
  ) INTO v_clean;

  UPDATE public.world_members
     SET missing_shas = v_clean
   WHERE world_id = _world AND user_id = v_uid
     AND missing_shas IS DISTINCT FROM v_clean;
END
$$;

REVOKE ALL ON FUNCTION public.report_missing_shas(TEXT, TEXT[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.report_missing_shas(TEXT, TEXT[]) FROM anon;
GRANT EXECUTE ON FUNCTION public.report_missing_shas(TEXT, TEXT[]) TO authenticated;

NOTIFY pgrst, 'reload schema';
