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
