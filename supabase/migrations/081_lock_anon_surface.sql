-- 081: `anon` rolünün okuyabildiği yüzeyi, uygulamanın kendi niyetine indir.
--
-- Neden:
--   Supabase proje kurulumu `GRANT ALL ON ALL TABLES IN SCHEMA public TO anon`
--   çalıştırır. `public` şemasındaki HER tabloda anon'un SELECT/INSERT/UPDATE/
--   DELETE grant'i vardı. Yazma tarafını RLS tutuyor (hiçbir tabloda
--   `WITH CHECK (true)` olan yazma policy'si yok — tarandı), ama SELECT
--   policy'si `USING (true)` olan tablolarda okumayı tutan hiçbir şey yok:
--
--     profiles      "Profiles are public"      → username, last_active_at,
--                                                app_version, platform,
--                                                online_restricted_reason
--     follows       "Follows are public"       → kim kimi takip ediyor
--     posts         "Posts are public"         → tüm gönderiler
--     post_likes    "Likes are public read"    → tüm beğeniler
--     game_listings "Game listings public read"→ tüm oyun ilanları
--
--   Bu, uygulamanın kendi mimari tablosuyla çelişiyor: account_gate.dart
--   `profile`, `follows`, `notifications` için `requiresAccount: true` diyor
--   ve gerekçesi "verisi Supabase RLS'in arkasında". Değildi — kapı GRANT
--   katmanındaydı ve açıktı. Publishable anahtar istemcide gömülü olduğu için
--   hesapsız herkes bu yüzeyi çekebiliyordu.
--
--   079 bunu kolon-kapsamlı bir GRANT ile çözmeye çalıştı ama GRANT'ler
--   toplanır, daraltmaz — var olan tablo-kapsamlı grant durduğu sürece
--   kolon grant'i no-op'tur. Önce REVOKE gerekiyor.
--
-- Açık kalan tek yüzey, account_gate.dart'ın `marketplace(requiresAccount:
-- false)` satırının tarif ettiği kadarı:
--   - katalog gezinmesi → marketplace_listings
--   - kartın yazar adı  → profiles'ın dört kolonu
-- Payload İNDİRME (`shared-payloads` bucket policy'si `authenticated`) ve
-- PAYLAŞMA (`publish_listing_snapshot` + RLS INSERT) hesap istemeye devam
-- eder — bu migration onlara dokunmuyor.
--
-- Not: RLS policy'leri DEĞİŞMİYOR. `authenticated` rolünün grant'leri de aynı
-- kalıyor; giriş yapmış kullanıcı için hiçbir şey değişmez.

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;

-- Bundan sonra oluşturulacak tablolar da otomatik açılmasın. Yalnızca
-- `postgres` grantor'ı için tanımlanabilir (migration'lar bu rolle çalışır);
-- `supabase_admin` grantor'lı ikinci varsayılan kayıt platformun kendisine
-- ait ve buradan değiştirilemez.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon;

-- Hesapsız gezinme yüzeyi — 079'un niyeti, bu sefer gerçekten dar.
GRANT SELECT ON public.marketplace_listings TO anon;
GRANT SELECT (user_id, username, display_name, avatar_url)
  ON public.profiles TO anon;

NOTIFY pgrst, 'reload schema';
