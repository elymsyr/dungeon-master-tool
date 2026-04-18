# DMT Supabase

Bu dizin, Dungeon Master Tool'un Supabase tarafındaki SQL migration'larını
ve operasyonel komutları içerir.

## Migration sırası

| # | Dosya | Sprint |
|---|---|---|
| 001 | `migrations/001_cloud_backups.sql` | Sprint 8 — cloud backup metadata |
| 002 | `migrations/002_community_assets.sql` | Sprint 10 — R2 asset metadata + storage RPC'leri |
| 003 | `migrations/003_social.sql` | Sprint 11 / v3.0.0-beta — sosyal özellikler |

Her migration **idempotent** yazılmıştır (`IF NOT EXISTS`, `DROP POLICY IF
EXISTS`, `CREATE OR REPLACE`). Sırayla Supabase Dashboard > SQL Editor > New
Query'de çalıştırılır.

## Storage bucket'ları

`003_social.sql` çalıştırıldıktan sonra Dashboard > Storage > New bucket
üzerinden şu bucket'lar oluşturulmalı:

| Bucket | Public | Açıklama |
|---|---|---|
| `avatars` | ✅ Public | Profil avatar görselleri |
| `post-images` | ✅ Public | Feed post resimleri |
| `shared-payloads` | 🔒 Private | Public yapılan world/template/package payload'ları (gzip JSON) |

## Admin atama (kaynak kodda DEĞİL)

`v3.0.0-beta` ile gelen admin gate, admin email'lerini kaynak kodda **tutmaz**.
Admin yetkisi `public.app_admins` tablosuna user_id eklenerek verilir ve
istemci yalnızca `is_admin()` RPC üzerinden bool olarak öğrenir.

İlk admin'i atamak için Supabase SQL Editor'da **bir kerelik** şu komutu
çalıştırın:

```sql
INSERT INTO public.app_admins (user_id)
SELECT id FROM auth.users
WHERE email = 'orhun868@gmail.com'
ON CONFLICT (user_id) DO NOTHING;
```

> ⚠️ Bu komut bilerek `migrations/` altında **değildir**. Repoya seed olarak
> koymak email'i versiyon kontrolüne sokar; tüm projenin amacı email'i kod
> dışında tutmak.

### Admin'i kaldırma

```sql
DELETE FROM public.app_admins
USING auth.users
WHERE app_admins.user_id = auth.users.id
  AND auth.users.email = 'orhun868@gmail.com';
```

### Admin yetkisini kontrol etme

İstemci tarafından:

```dart
final isAdmin = await Supabase.instance.client.rpc('is_admin');
```

Veya doğrudan SQL:

```sql
SELECT public.is_admin();
-- ↑ Sadece auth user context'i içinden anlamlı (auth.uid() okur).
```

## Ek operasyonel notlar

- **Row Level Security (RLS)** her social tablosunda aktiftir; hassas tablolar
  (`messages`, `conversations`) yalnızca üyelerine açıktır.
- **Storage quota** `get_user_total_storage_used()` RPC'si üzerinden
  cloud_backups + community_assets + posts + shared_items toplamını döner.
  Default kullanıcı kotası **50 MB** (`profiles.storage_quota_bytes`).
- **`profile_counts` view** takipçi/takip sayıları için lazy hesaplanır;
  büyük ölçekte materialize edilebilir.

## Dashboard-only ayarlar (migration'a girmeyen)

Yeni bir Supabase projesi ayağa kaldırıldığında aşağıdaki adımlar Dashboard'dan
**elle** yapılmalı — SQL migration'a sığmazlar:

- **Leaked password protection**: Authentication → Providers → Email → "Leaked
  password protection" açık olmalı. HaveIBeenPwned DB'sine karşı şifre kontrolü
  yapar; `024_linter_fixes.sql` SQL tarafını kapatsa da bu bayrak Dashboard'da
  kalır.
