# 43 — i18n Localization Spec

> **For Claude.** Turkish + English UI. SRD content stays English (CC BY 4.0).
> **Target:** `flutter_app/lib/l10n/`, `flutter_app/lib/presentation/i18n/`

## Stack

- `flutter_localizations` (Material/Cupertino strings).
- `intl` package.
- ARB files per locale.
- Code-gen via `flutter gen-l10n`.

## Setup

`pubspec.yaml`:

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0

flutter:
  generate: true
```

`l10n.yaml` at project root:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
output-dir: lib/l10n/generated
synthetic-package: false
```

Run `flutter gen-l10n` to generate `app_localizations.dart`.

## ARB Files

```
flutter_app/lib/l10n/
├── app_en.arb     # English (template)
└── app_tr.arb     # Turkish
```

### Sample `app_en.arb`

```json
{
  "@@locale": "en",
  "appTitle": "Dungeon Master Tool",
  "@appTitle": {"description": "Application title"},

  "common_save": "Save",
  "common_cancel": "Cancel",
  "common_delete": "Delete",
  "common_edit": "Edit",
  "common_create": "Create",
  "common_back": "Back",
  "common_next": "Next",
  "common_confirm": "Confirm",
  "common_loading": "Loading...",
  "common_error": "Error",

  "hub_tab_worlds": "Worlds",
  "hub_tab_characters": "Characters",
  "hub_tab_packages": "Packages",
  "hub_tab_marketplace": "Marketplace",
  "hub_tab_settings": "Settings",

  "character_creation_title": "Create Character",
  "character_creation_step_class": "Choose Class",
  "character_creation_step_origin": "Choose Origin",
  "character_creation_step_abilities": "Determine Abilities",
  "character_creation_step_alignment": "Choose Alignment",
  "character_creation_step_details": "Fill Details",
  "character_creation_step_review": "Review",

  "ability_strength": "Strength",
  "ability_dexterity": "Dexterity",
  "ability_constitution": "Constitution",
  "ability_intelligence": "Intelligence",
  "ability_wisdom": "Wisdom",
  "ability_charisma": "Charisma",

  "ability_short_strength": "STR",
  "ability_short_dexterity": "DEX",
  "ability_short_constitution": "CON",
  "ability_short_intelligence": "INT",
  "ability_short_wisdom": "WIS",
  "ability_short_charisma": "CHA",

  "combat_tab_initiative": "Initiative",
  "combat_round": "Round {round}",
  "@combat_round": {"placeholders": {"round": {"type": "int"}}},
  "combat_apply_damage": "Apply Damage",
  "combat_apply_healing": "Apply Healing",

  "online_create_session": "Create Game",
  "online_join_session": "Join Game",
  "online_game_code_label": "Game code",
  "online_game_code_invalid": "Game code not found or session is closed",

  "upgrade_notice_title": "Big update",
  "upgrade_notice_body": "This version replaces the previous flexible Template system with native D&D 5e support. Your previous campaigns, characters, and templates have been removed because they cannot be automatically converted to the new format.",

  "spell_slot_label": "Level {level}",
  "@spell_slot_label": {"placeholders": {"level": {"type": "int"}}}
}
```

### Sample `app_tr.arb`

```json
{
  "@@locale": "tr",
  "appTitle": "Zindan Efendisi Aracı",

  "common_save": "Kaydet",
  "common_cancel": "İptal",
  "common_delete": "Sil",
  "common_edit": "Düzenle",
  "common_create": "Oluştur",
  "common_back": "Geri",
  "common_next": "İleri",
  "common_confirm": "Onayla",
  "common_loading": "Yükleniyor...",
  "common_error": "Hata",

  "hub_tab_worlds": "Dünyalar",
  "hub_tab_characters": "Karakterler",
  "hub_tab_packages": "Paketler",
  "hub_tab_marketplace": "Pazaryeri",
  "hub_tab_settings": "Ayarlar",

  "character_creation_title": "Karakter Oluştur",
  "character_creation_step_class": "Sınıf Seç",
  "character_creation_step_origin": "Köken Seç",
  "character_creation_step_abilities": "Yetenek Puanları",
  "character_creation_step_alignment": "Hizalanma",
  "character_creation_step_details": "Ayrıntılar",
  "character_creation_step_review": "Önizleme",

  "ability_strength": "Güç",
  "ability_dexterity": "Çeviklik",
  "ability_constitution": "Dayanıklılık",
  "ability_intelligence": "Zeka",
  "ability_wisdom": "Bilgelik",
  "ability_charisma": "Karizma",

  "ability_short_strength": "GÜÇ",
  "ability_short_dexterity": "ÇEV",
  "ability_short_constitution": "DAY",
  "ability_short_intelligence": "ZEK",
  "ability_short_wisdom": "BİL",
  "ability_short_charisma": "KAR",

  "combat_tab_initiative": "İnisiyatif",
  "combat_round": "Tur {round}",
  "combat_apply_damage": "Hasar Uygula",
  "combat_apply_healing": "İyileştirme Uygula",

  "online_create_session": "Oyun Oluştur",
  "online_join_session": "Oyuna Katıl",
  "online_game_code_label": "Oyun kodu",
  "online_game_code_invalid": "Oyun kodu bulunamadı veya oturum kapalı",

  "upgrade_notice_title": "Büyük güncelleme",
  "upgrade_notice_body": "Bu sürüm önceki esnek Şablon sistemini yerini DnD 5e doğrudan desteğe bırakıyor. Önceki kampanyalarınız, karakterleriniz ve şablonlarınız yeni formata otomatik dönüştürülemediği için silindi.",

  "spell_slot_label": "Seviye {level}"
}
```

## Usage in Code

```dart
import 'package:flutter_app/l10n/generated/app_localizations.dart';

class HubScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    final l10n = AppLocalizations.of(ctx)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: TabBarView(children: [
        Tab(child: Text(l10n.hub_tab_worlds)),
        // ...
      ]),
    );
  }
}
```

## Locale Selection

```dart
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(_loadInitial());

  static Locale _loadInitial() {
    // Read from SharedPreferences. Default = system locale if supported, else 'en'.
    final saved = _prefs.getString('locale');
    if (saved != null) return Locale(saved);
    final sys = WidgetsBinding.instance.platformDispatcher.locale;
    return _supported.contains(sys.languageCode) ? sys : const Locale('en');
  }

  Future<void> setLocale(String langCode) async {
    state = Locale(langCode);
    await _prefs.setString('locale', langCode);
  }

  static const _supported = ['en', 'tr'];
}
```

`MaterialApp.router`:

```dart
MaterialApp.router(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('en'), Locale('tr')],
  locale: ref.watch(localeProvider),
  // ...
)
```

## Settings UI

Settings screen → "Language" dropdown:

```dart
DropdownButton<String>(
  value: ref.watch(localeProvider).languageCode,
  items: const [
    DropdownMenuItem(value: 'en', child: Text('English')),
    DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
  ],
  onChanged: (v) => v != null ? ref.read(localeProvider.notifier).setLocale(v) : null,
)
```

## SRD Content (English-Only)

Per CC BY 4.0 attribution, SRD text (spell descriptions, monster names, feature text) must be reproduced verbatim with attribution if redistributed. We keep it English to preserve fidelity.

UI strings around SRD content (labels, headers, button text) ARE translated. Example:

```
[ Cast Spell ]            ← UI label (translated to "Büyü Yap")
Fireball                  ← spell name (NOT translated; English original)
Level 3 Evocation         ← spell metadata (level number translated, school NOT translated for now)
Casting Time: 1 action    ← header label translated; "1 action" content English
"A bright streak flashes..."  ← description verbatim English
```

For a fully Turkish player experience: future work to add a community translation layer (separate ARB-like file mapping spell IDs to Turkish text). Out of MVP. Add note in marketplace package format ([14](./14-package-system-redesign.md)) for translation packs.

## Numbers, Dates, Currencies

Use `intl`'s built-in formatters:

```dart
DateFormat.yMMMd(Localizations.localeOf(ctx).toString()).format(date);
NumberFormat.currency(symbol: '', decimalDigits: 0).format(value);
```

D&D-specific units:
- Feet (ft) — keep "ft" in EN, "ft" in TR (no widely-used Turkish abbreviation; or use "ayak" expanded form).
- HP, AC, etc. — keep as untranslated abbreviations.

## Pluralization

ICU plural messages:

```json
"combat_combatants_count": "{count, plural, =0{No combatants} =1{1 combatant} other{{count} combatants}}",
"@combat_combatants_count": {
  "placeholders": {"count": {"type": "int"}}
}
```

## Translator Workflow

- `app_en.arb` is the source of truth.
- New strings added there first.
- `app_tr.arb` updated by translator.
- CI lints: every `tr` key matches an `en` key (no orphans, no missing).

```bash
# Lint script (pseudo)
diff <(jq -r 'keys[]' app_en.arb | sort) <(jq -r 'keys[]' app_tr.arb | sort)
```

## Acceptance

- App opens in system language if Turkish or English; else English.
- User can switch in Settings; preference persists.
- All hardcoded UI strings replaced with `l10n.xxx` lookups.
- No raw English strings appear in TR mode (lint catches).
- SRD content (spell names, descriptions) remains English in both modes.

## Open Questions

1. Auto-detect Turkish system locale on first run? → Yes.
2. Translation pack format for SRD content (community contributed)? → Future. Spec in marketplace doc revision.
3. RTL support (Arabic, Hebrew)? → Out of MVP. Both supported langs are LTR.
