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
-- Kolon-kapsamlı: `profiles` RLS'i `USING (true)` olduğu için tam tablo
-- GRANT'i `last_active_at`, `app_version`, `platform` ve moderasyon alanı
-- `online_restricted_reason`'ı da hesapsız internete açardı. Listing kartının
-- ihtiyacı olan dört kolon yeter.
GRANT SELECT (user_id, username, display_name, avatar_url)
  ON public.profiles TO anon;

NOTIFY pgrst, 'reload schema';
