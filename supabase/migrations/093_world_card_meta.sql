-- 093: Dünyanın kart kimliği (açıklama / etiket / kapak) oyuncuya da gitsin.
--
-- Neden:
--   077 bulut aynasını kaldırdığında dünya metadata'sı da onunla gitti:
--   katılan oyuncu isimden ibaret boş bir kabuk görüyordu — hub kartında
--   açıklama yok, banner yok. 077'nin kendi ayrımına göre `worlds` satırı
--   "üyelik ve dünya meta'sı" taşımalı; eksik olan tek şey meta'nın kendisiydi.
--
-- Neden tek JSON kolon:
--   Taşınan şey `world_settings.settings_json`'daki `metadata` map'inin
--   whitelist'lenmiş bir alt kümesi (description / tags / cover_image_path).
--   Kolon başına bir ALTER yerine aynı map'i taşımak client tarafında da
--   tek encode/decode demek.
--
-- Kapak: DM'in yerel dosya yolu anlamsız olurdu; client kapağı önce
--   free-media havuzuna yükleyip `dmt-public://` ref'i yazar (kapaklar zaten
--   quota'ya sayılmayan ücretsiz kind — bkz. 053).
--
-- RLS: yeni policy yok. Yazan "Worlds: dm update", okuyan "Worlds: members
--   read" — ikisi de 026'dan beri yerinde.

ALTER TABLE public.worlds
  ADD COLUMN IF NOT EXISTS meta_json TEXT;

COMMENT ON COLUMN public.worlds.meta_json IS
  'Dünya kartı meta''sı: {description, tags, cover_image_path}. DM kaydettikçe '
  'yazılır; oyuncu davet kodunu kullanırken ve `worlds` CDC UPDATE''inde '
  'yerel world_settings.metadata''sına uygular. cover_image_path bir '
  'dmt-public:// ref''idir — DM''in yerel yolu asla yazılmaz.';

NOTIFY pgrst, 'reload schema';
