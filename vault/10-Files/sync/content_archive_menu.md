---
type: file-note
domain: sync
path: flutter_app/lib/presentation/widgets/content_archive_menu.dart
layer: presentation
language: dart
status: active
updated: 2026-09-22
tags: [file]
---

# `content_archive_menu.dart`

> [!abstract] Primary Purpose
> `.dmtz` dışa/içe aktarmanın tek giriş noktası. Hub'ın Dünyalar ve Paketler
> sekmelerinde iki eylemli bir düğme, karakter düzenleyicide yalnız dışa
> aktaran bir ikon düğmesi. Dosya seçimi, [[content_archive]] çağrısı,
> sonucun snackbar'a yazılması ve doğru liste provider'ının invalidate
> edilmesi burada.

## Inputs / Outputs
**Inputs**
- Parametreler: `type` (`ContentItemType`), `selectedId`, `selectedName`, `showImport`.
- Providers: `contentCodecProvider`; invalidate için `campaignInfoListProvider` / `packageListProvider` / `characterListProvider`.
- `FilePicker` — masaüstünde `saveFile`/`pickFiles`, mobilde `getApplicationDocumentsDirectory`.

**Outputs**
- Diske `.dmtz` yazar ya da okur; uygulanan içerik [[content_codec]] üzerinden Drift'e iner.
- Snackbar: `contentArchiveExported` / `contentArchiveImported` / `…WithSkips` / `…Unsupported` / `…Failed`.

## Dependencies & Links
- Depends on: [[content_archive]], [[content_codec]], [[content_item]]
- Used by: `hub/worlds_tab.dart`, `hub/packages_tab.dart`, `characters/character_editor_screen.dart`
- Domain map: [[Sync-and-Realtime]]

## Key Logic / Variables
- **Görünüm temadan gelir, widget'ta sabit değer yoktur.** Tetikleyici gerçek bir `OutlinedButton.icon` — yanındaki "Kopyala" ile aynı widget türü, dolayısıyla yükseklik, kenarlık, zemin, köşe yarıçapı, dolgu ve hover/press renkleri `outlinedButtonTheme`'den okunur ve her temada kendiliğinden doğrudur.
  - İlk sürüm çıplak bir `PopupMenuButton`'dı. Onun tetikleyicisi içeride bir `IconButton`: kenarlıksız, zeminsiz, 48×48 — komşusu 137×48 iken satırda sırıtıyordu.
  - Menü `MenuAnchor` ile **değil** `showMenu` ile açılıyor: uygulamanın öbür dokuz menüsü `PopupMenuButton` ve tema `popupMenuTheme` tanımlıyor; `MenuAnchor` o yüzeyi almaz, tek başına farklı görünürdü. Konum hesabı `PopupMenuButton`'ın kendi içinde yaptığının aynısı.
- **Tek eylem kalınca menü yok.** `showImport: false` (karakter düzenleyici — kullanıcı kuralı "karakteri yalnızca dünya içinden import edebiliriz") doğrudan `IconButton` döndürür, `iconSize: 18` + `visualDensity: compact` ile yanındaki geri/ileri düğmelerinin ölçüsünde.
- **İçe aktarma seçili öğeden bağımsız.** Dosyanın manifest'i türü zaten söylüyor; hangi sekmeden açılırsa açılsın çalışır ve `result.ref.type`'a göre doğru listeyi tazeler. Dışa aktarma ise seçim ister — seçim yoksa menü açılır ama o madde kapalıdır.
- `ponytail:` mobilde kaydetme diyaloğu yok — `FilePicker.saveFile` orada baytları istiyor, biz diske akıtıyoruz. Dosya Documents'a yazılıp yolu snackbar'da gösteriliyor.
- Arşiv `finally` içinde kapatılır (`ContentArchive.close`), hata yolunda da.

## Notes
- Test: `test/presentation/content_archive_menu_test.dart` — tetikleyicinin `OutlinedButton` olduğunu (yani görünümü temadan aldığını) iki temada bağlar, tek eylemli hâlin `IconButton` olduğunu ve seçim yokken dışa aktarmanın kapalı geldiğini doğrular. Yükseklik eşitliği tek başına ayırt etmiyor: ölçüldü, eski `IconButton` da 48 px idi (Material'ın asgari dokunma hedefi).
