# Dungeon Master Tool — Flutter App

Cross-platform D&D kampanya yönetim aracı. Android, iOS, Windows, Linux ve macOS destekler.

## Gereksinimler

### Flutter SDK

```bash
cd ~
git clone https://github.com/flutter/flutter.git -b stable .flutter-sdk
echo 'export PATH="$HOME/.flutter-sdk/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
flutter --version
```

### Linux Desktop Build Bağımlılıkları (Ubuntu/Debian)

```bash
sudo apt-get install -y clang ninja-build libgtk-3-dev pkg-config libglib2.0-dev lld libstdc++-12-dev cmake libasound2-dev
```

### Android

Android build için [Android Studio](https://developer.android.com/studio) veya Android SDK kurulumu gerekir.

### Doğrulama

```bash
flutter doctor
```

## Kurulum

```bash
cd flutter_app
flutter pub get
```

## Code Generation

Freezed, Riverpod ve Drift modelleri için code generation gerekir:

```bash
# Tek seferlik
dart run build_runner build --delete-conflicting-outputs

# Watch mode (dosya değişince otomatik üret)
dart run build_runner watch --delete-conflicting-outputs
```

## Çalıştırma

```bash
# Linux Desktop
flutter run -d linux

# macOS Desktop
flutter run -d macos

# Windows Desktop
flutter run -d windows

# Android
flutter run -d android

# iOS
flutter run -d ios

# Chrome (Web)
flutter run -d chrome
```

Terminal'de aktif komutlar:

| Tuş | İşlev |
|-----|-------|
| `r` | Hot reload (kod değişikliklerini anında uygular) |
| `R` | Hot restart (state'i sıfırlar, uygulamayı yeniden başlatır) |
| `q` | Uygulamayı kapat |
| `d` | Uygulamayı çalışır bırakıp terminal'den ayrıl |

## Release Build

```bash
# Android APK
flutter build apk --release

# iOS (unsigned)
flutter build ios --release --no-codesign

# Linux
flutter build linux --release
# Çıktı: build/linux/x64/release/bundle/

# Windows
flutter build windows --release

# macOS
flutter build macos --release
```

## Localization

Yeni çeviri anahtarı eklemek için:

1. `lib/presentation/l10n/app_en.arb` dosyasına yeni key ekle
2. Aynı key'i `app_tr.arb`, `app_de.arb`, `app_fr.arb` dosyalarına da ekle
3. `flutter gen-l10n` çalıştır (veya `flutter run` otomatik üretir)
4. Kodda `L10n.of(context)!.keyName` ile kullan

## Analiz ve Testler

```bash
# Statik analiz
flutter analyze

# Testler
flutter test

# Belirli bir test dosyası
flutter test test/widget_test.dart
```

## Proje Yapısı

```
lib/
├── main.dart                    # Entry point, ProviderScope
├── app.dart                     # MaterialApp, tema, lokalizasyon
├── core/                        # Constants, config, utils
├── domain/                      # Pure Dart: entities, repositories (abstract)
│   └── entities/schema/         # WorldSchema, FieldSchema, FieldType
├── data/                        # Repository impl, datasources, network
├── application/                 # Riverpod providers, services
└── presentation/                # UI: screens, widgets, theme, l10n, dialogs
    └── widgets/field_widgets/   # Schema-driven field widget'lar
```

Detaylı mimari: `../docs/FLUTTER_MIGRATION_BLUEPRINT.md`
Sprint planı: `../docs/FLUTTER_DEVELOPMENT_ROADMAP.md`

## Developer: İçerik Yayınlama (R2 / Cloudflare Worker)

Marketplace içeriği private bir R2 bucket'ında durur, önünde `dmt-assets` worker'ı vardır.
`GET /catalog/*` herkese açıktır; `PUT` / `DELETE` `ADMIN_TOKEN` ister.

```bash
export DMT_WORKER_URL=https://dmt-assets.dungeon-master-tool.workers.dev
export ADMIN_TOKEN=<wrangler secret: ADMIN_TOKEN>
```

`DMT_WORKER_URL`'in default'u koda gömülüdür (`lib/core/config/worker_config.dart`),
uygulamayı çalıştırmak için dart-define şart değil. Bu iki env var sadece **yayınlama**
içindir.

### 1. Dünya değiştiyse: blueprint → pkg.json

`assets/worlds/<dir>/` altında `world-blueprint.json` veya `manifest.json` düzenlediysen:

```bash
cd flutter_app
dart run tool/content/convert_blueprint.dart --dir assets/worlds/<dir> --check   # doğrula
dart run tool/content/convert_blueprint.dart --dir assets/worlds/<dir>           # üret
```

Çözümlenemeyen bir `_ref`, şemada olmayan bir alan veya eksik bir medya dosyası
non-zero exit verir — bozuk dünya asla yayına çıkmaz.

**Sürüm bump zorunlu:** R2 yolları versiyonlu ve değişmezdir
(`catalog/world-media/<slug>@<ver>/...`). `manifest.json` içindeki `version`'ı
artırmadan yayınlarsan yeni dosyalar eski sürüme yazılmaz, kullanıcı eskiyi görmeye
devam eder.

### 2. Katalog manifest'ini üret

```bash
dart run tool/catalog_publish/bin/build_catalog.dart
# → assets/first_party/manifest.json   (22 entr(ies): 19 package, 3 world)
```

### 3. Yayınla

```bash
dart run tool/catalog_publish/bin/publish_catalog.dart --dry-run   # önce provası
dart run tool/catalog_publish/bin/publish_catalog.dart             # gerçek yükleme
```

Çıktı satırları:

| Satır | Anlamı |
|---|---|
| `= ...@1.1.0.json.gz (already present)` | Versiyonlu obje zaten var, atlandı |
| `~ ...@1.0.1.json.gz (93 KB)` | Yeni sürüm, yükleniyor |
| `· <slug>: 75 media object(s), 1 external link(s) not uploaded` | 75 medya yüklendi; `pdf_url` bir **link**, dosya değil — bilerek yüklenmiyor |

`manifest.json` her zaman **en son** yüklenir; böylece index yalnızca bucket'ta hâlihazırda
duran objeleri gösterir.

> ⚠️ Macera PDF'leri asla bucket'a yüklenmez — `all-rights-reserved`. Yayıncının linki
> `manifest.json` → `files.pdf_url` alanında durur; uygulama onu hem Marketplace kartının
> altında hem de dünyanın sabitlenmiş campaign sayfasında link olarak gösterir.
> Eksik bir PDF'i bucket'a koyarak "düzeltme".

### 4. Banner'lar

Banner'lar ayrı bir script ile yüklenir (`publish_catalog` bunlara dokunmaz):

```bash
./../cloudflare/upload_banners.sh      # flutter_app/ içindeysen
# veya repo kökünden: ./cloudflare/upload_banners.sh
```

`assets/first_party/banners/*.jpg` → `catalog/banners/<slug>.jpg`. Uygulama kartları
bundle'daki kopyayı kullanır; R2 aynası web/dış kullanım içindir.

Banner objeleri `immutable, max-age=1y` ile servis edilir. **Bir banner'ın içeriğini
değiştirdiysen** `lib/data/services/first_party_catalog_service.dart` içindeki
`kBannerAssetVersion` sabitini artır — URL `?v=N` cache-buster'ı odur, artırmazsan
kimse yeni görseli görmez.

### 5. Doğrulama

```bash
curl -s -o /dev/null -w '%{http_code}\n' "$DMT_WORKER_URL/catalog/manifest.json"   # 200
flutter test test/application/services/world_catalog_publish_test.dart
```

(Worker `HEAD` kabul etmez — `curl -I` 405 döner, GET kullan.)
