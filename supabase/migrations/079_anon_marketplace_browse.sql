-- 079: Marketplace gezinmesini hesapsız kullanıcılara aç.
--
-- Neden:
--   `marketplace_listings` RLS SELECT'i zaten `USING (true)` — katalog
--   herkese okunabilir olacak şekilde tasarlanmıştı. Ama `anon` rolüne tablo
--   GRANT'i verilmediği için pratikte yalnızca giriş yapmış kullanıcı
--   görebiliyordu, istemci de buna uyup listeyi boş döndürüyordu.
--
--   Kapı bir adım sonraya taşınıyor:
--     - Gezinme        → herkes (bu migration)
--     - Resmi katalog  → herkes (R2, worker'da zaten public GET)
--     - Kullanıcı içeriğini İNDİRME → hesap ister (`shared-payloads` bucket
--       politikası `authenticated` — DEĞİŞMİYOR)
--     - Paylaşma       → hesap ister (`publish_listing_snapshot` + RLS INSERT
--       `auth.uid() = owner_id` — DEĞİŞMİYOR)

GRANT SELECT ON public.marketplace_listings TO anon;

-- Listing kartı yazarın kullanıcı adını gösteriyor (`profiles` join'i).
-- Sadece SELECT; profiles'ın kendi RLS'i hangi satırların görüneceğini
-- belirlemeye devam eder.
GRANT SELECT ON public.profiles TO anon;

NOTIFY pgrst, 'reload schema';
