# Dungeon Master Tool — Flutter

D&D Dungeon Master Tool'un Flutter ile yeniden yazılmış versiyonu.

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
sudo apt-get install -y clang ninja-build libgtk-3-dev pkg-config libglib2.0-dev lld libstdc++-12-dev cmake
```

### Doğrulama

```bash
flutter doctor
```

`Linux toolchain` satırının yeşil `[✓]` olması yeterli. Android toolchain uyarısı görmezden gelinebilir (desktop-first proje).

## Kurulum

```bash
cd flutter_app
flutter pub get
```

## Çalıştırma

### Linux Desktop (Geliştirme)

```bash
flutter run -d linux
```

Uygulama penceresi açılır. Terminal'de aktif komutlar:

| Tuş | İşlev |
|-----|-------|
| `r` | Hot reload (kod değişikliklerini anında uygular) |
| `R` | Hot restart (state'i sıfırlar, uygulamayı yeniden başlatır) |
| `q` | Uygulamayı kapat |
| `d` | Uygulamayı çalışır bırakıp terminal'den ayrıl |

### Chrome (Web)

```bash
flutter run -d chrome
```

### Release Build

```bash
# Linux
flutter build linux --release
# Çıktı: build/linux/x64/release/bundle/

# Android APK
flutter build apk --release

# Windows
flutter build windows --release
```

## Code Generation

Freezed ve Riverpod modelleri için code generation gerekir:

```bash
# Tek seferlik
dart run build_runner build --delete-conflicting-outputs

# Watch mode (dosya değişince otomatik üret)
dart run build_runner watch --delete-conflicting-outputs
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
