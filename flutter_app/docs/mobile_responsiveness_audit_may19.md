# Mobile Responsiveness & Keyboard Latency Audit — 2026-05-19

User-reported friction on mobile:

1. **Klavye yavaş açılıyor** — landing/login, world/character/package creation, DB search, map'e entity ekleme, session log entry, post writing alanlarında belirgin gecikme.
2. **Session log @ mention dropdown** klavyenin altına gidip görünmüyordu.
3. **Genel mobil optimizasyon** ihtiyacı.

Plan dosyası: `~/.claude/plans/mobilde-giri-ekran-d-nya-prancy-eich.md`.

## Root Cause Summary

İki anti-pattern birleşince mobilde IME açılışı sırasında frame budget aşılıyor:

**A) `MediaQuery.viewInsets.bottom` üst widget'tan okunuyor.** Keyboard her animasyon frame'inde (~150-300ms boyunca her 16ms'de) parent tüm tree'yi rebuild ediyor — palette, l10n, gradient, language picker, form alanları yeniden inşa.

**B) Geniş scope `ref.watch` / `ref.listen` çağrıları.** MainScreen 45 watch, Hub 6 tab eager-load, Wizard 3x `ref.listen` üst build()'te. Keyboard açılırken background sync emit ederse → parent rebuild → TextField IME state thrash.

---

## SHIPPED 2026-05-19

### K1 — Landing screen viewInsets izolasyonu ✅
**File**: `lib/presentation/screens/landing/landing_screen.dart`

- `_buildAuthLanding`'ten `MediaQuery.viewInsetsOf` okuma kaldırıldı.
- `Scaffold.resizeToAvoidBottomInset` (default true) form'u yukarı itiyor — manuel `bottom: bottomInset + 24` padding sökülmüş.
- Tagline ayrı `_KeyboardAwareTagline` stateless widget'a çıkarıldı; viewInsets sadece o widget'ta okunuyor.
- Background gradient `RepaintBoundary` ile sarılı — keyboard frame'lerinde repaint cache'den gelir.

### M1+M2 — Mention overlay keyboard-aware ✅
**File**: `lib/presentation/widgets/markdown_text_area.dart`

- Pozisyon hesabı `MediaQuery.viewInsets.bottom`'u çıkarıyor (`usableHeight = mq.size.height - keyboardHeight`).
- Mobilde (width < 600) overlay her zaman cursor'un ÜSTÜNDE açılıyor; wide ekranda below-first.
- Üst clamp status bar/notch için: `top.clamp(mq.padding.top + 4, usableHeight - overlayMaxHeight)`.
- Width ekrana sığacak şekilde `(mq.size.width - 16).clamp(40, 320)`.
- `WidgetsBindingObserver` + `didChangeMetrics` → keyboard yükselir/iner anında `_mentionOverlay?.markNeedsBuild()` ile yeniden konumlanıyor.

### K3 — Session quick-add dialog autofocus defer ✅
**File**: `lib/presentation/screens/session/session_screen.dart` (`_showQuickAddDialog`)

- `autofocus: true` kaldırıldı, `nameFocus = FocusNode()` + `Future.delayed(180ms, requestFocus)` ile dialog transition sonrası IME açılıyor.

### K4 — Worlds + Packages create dialog autofocus defer ✅
**Files**:
- `lib/presentation/screens/hub/worlds_tab.dart` (world create)
- `lib/presentation/screens/hub/packages_tab.dart` (pkg create + copy)
- `lib/presentation/screens/map/world_map_screen.dart` (`_showAddPinDialog`)

Hepsinde aynı pattern: `autofocus: true` → `FocusNode` + `Future.delayed(180ms)`. Dialog enter animasyonu + IME açılışı artık ardışık, paralel değil.

### O2 — Hub eager-load postFrame ✅
**File**: `lib/presentation/screens/hub/hub_screen.dart`

3 list provider (campaignInfoList, characterList, packageList) build() içinden alındı, `WidgetsBinding.instance.addPostFrameCallback`'a taşındı. Cold start ilk frame'i 3 ağır query'i yığmıyor; warm-load arka planda. LazyIndexedStack zaten ilk gerçek render'da watch'lıyor.

### O3 — CharactersTab `RepaintBoundary` ✅
**File**: `lib/presentation/screens/hub/characters_tab.dart`

Her char row `RepaintBoundary` ile sarmalandı — selection değişimi paint cache invalidate sınırlı. Tam ValueNotifier refactor deferred (panel + list ortak `_selectedIndex` paylaşımı setState ile gerekli, refactor kazanç düşük + risk artar).

### O5 — Image cacheWidth eksik 2 yer ✅
**Files**:
- `lib/presentation/screens/characters/character_editor_screen.dart:692` (portrait 260px)
- `lib/presentation/screens/characters/wizard/character_creation_wizard_screen.dart:1760` (avatar 96px)

Diğer Image.* çağrıları audit denetiminden geçti — zaten cacheWidth kullanıyorlar. Sadece bu iki yer eksikti.

### O11 — Marketplace parallel-await ✅
**File**: `lib/presentation/widgets/marketplace_panel.dart`

Nested `ownedAsync.when → sourceAsync.when` waterfall pattern sökülmüş: ikisi paralel watch, `hasValue` kontrolü ile single progress, ikisi de hazır olunca tek render. İki ardışık loading state stutter'ı yok.

---

## DEFERRED (Future PRs)

### K2 — Character Creation Wizard ref scope (P0)
**File**: `lib/presentation/screens/characters/wizard/character_creation_wizard_screen.dart`

Problem: Üst `build()`'te 3 `ref.watch` (characterDraftProvider, allTemplatesProvider, campaignListProvider) + 3 `ref.listen`. `characterDraftProvider` her keystroke emit ederse tüm Stepper rebuild oluyor — _DebouncedTextField parent'a fayda etmiyor.

Fix plan (riski yüksek, 4500 LOC dosya):
- Her step'i ayrı ConsumerWidget'a çıkar; o step kendi `ref.watch(characterDraftProvider.select((d) => d.fieldOfInterest))` ile sınırlandırsın.
- `allTemplatesProvider` ve `campaignListProvider` Stepper dışı `_TemplatesGate` widget'ına alınsın; templates+worlds yüklenene kadar gate, sonra çocuk render.
- `activatingWorld` flag'i `setState` yerine `ValueNotifier<bool>` ile `ValueListenableBuilder` ile sadece spinner suffix'i rebuild olsun.

### K5 — Entity Sidebar Search Focus (P1)
**File**: `lib/presentation/widgets/entity_sidebar.dart` lines 312-331

Debounce + cached filter sig zaten doğru (line 88). Asıl problem: MainScreen rebuild olunca sidebar focus kayboluyor.

Fix:
- Search TextField'ı `_SidebarSearchField` ayrı `ConsumerStatefulWidget`'a çıkar.
- Kendi `FocusNode` instance'ını state'te tut.
- Parent MainScreen rebuild olduğunda focus state korunur (widget identity stable).
- Alternatif: `PageStorageKey` + `AutomaticKeepAliveClientMixin` (eğer sidebar lazily mount ediliyorsa).

### K6 — Map Timeline Dialog
İncelendi (`timeline_entry_dialog.dart`): mevcut kodda autofocus zaten yok. Yapısal sorun gözükmüyor → SKIP.

### O6 — Battle map repaint throttle (SKIP)
İncelendi (`battle_map_notifier.dart:762,769` + `battle_map_painter.dart:41`): `strokeTick` zaten `ValueNotifier<int>` + `Listenable.merge` ile painter'a verilmiş — Riverpod widget rebuild'i yok, sadece RenderObject repaint. Pan event'leri zaten ~16ms aralıkla geliyor. Ek throttle çizim feedback'inde stutter yaratır. SKIP.

### O8 — EntityCard schema field cache (SKIP)
İncelendi (`entity_card.dart:108-131`): `_schemaCache` Expando ile schema bazlı zaten cache'li, `_getSchemaCache(cat)` her schema için bir kez hesaplıyor. Audit varsayımı yanlıştı. SKIP.

### O14 — Token image cache leak (SKIP)
İncelendi (`battle_map_projection_view.dart:134-137`): `_preloadTokenImages` zaten stale key'leri `_tokenImageCache.remove(p)?.dispose()` ile temizliyor. SKIP.

### K5 — Sidebar search isolated (SKIP)
İncelendi (`entity_sidebar.dart:52-120`): `_searchController` + debounce State'te zaten korunuyor, parent MainScreen rebuild Element tree state'i preserve eder. Audit varsayımı doğrulanmadı. SKIP.

### O1 — MainScreen .select() projeksiyonları (P0)
**File**: `lib/presentation/screens/main_screen.dart`

45 `ref.watch/read` tek build()'de — `.select()` yok. Sidebar + tab content + nav her provider değişiminde tetikleniyor.

Fix plan:
- Tüm karmaşık provider'lara `.select((s) => s.minimalField)` ekle:
  - `activeCampaignProvider.select((s) => s?.id)` (id değişene kadar rebuild yok)
  - `entityProvider.select((m) => m.length)` (sidebar count badge için)
  - `syncStateProvider.select((s) => s.isOnline)` (online indicator için)
- Sidebar (entity list + search) ayrı `Consumer((ctx, ref, _) {...})` branch.
- Tab content (IndexedStack) ayrı `Consumer` branch.
- NavigationRail destinations'u `static const _kDestinations = [...]`'a çek (line 1013-1018).

### O2 — Hub Lazy Tabs (P1)
**File**: `lib/presentation/screens/hub/hub_screen.dart` lines 257-259

6 tab provider eager loading. Session screen'deki `_visitedBottomTabs` pattern'ini buraya genişlet:
- `_visitedTabs = <int>{0}` (varsayılan tab seti).
- `IndexedStack` çocuklarını `_visitedTabs.contains(i) ? tabBuilder(i) : SizedBox.shrink()` ile koşullu mount.
- Tab tıklanırsa `_visitedTabs.add(index)`.

### O3 — CharactersTab list rebuild (P1)
**File**: `lib/presentation/screens/hub/characters_tab.dart` lines 194-250

Selection state ListView'i tamamen rebuild ediyor.

Fix:
- List item'ı `class _CharRow extends StatelessWidget` (const where possible).
- Selection state'i `ValueNotifier<int> _selectedNotifier` ile gate; ListView item builder `ValueListenableBuilder` içinde sadece kendi index'inin selected olup olmadığını izlesin.

### O4 — ListView itemExtent (P1)
**Files**: `feed_tab.dart`, `game_listings_tab.dart`, `marketplace_tab.dart`, `messages_tab.dart`, `group_settings_screen.dart` ve diğer 11 dosya.

Sabit yükseklikli item'lar için:
```dart
ListView.builder(
  itemExtent: 120, // feed
  itemBuilder: ...
)
```
Feed 120, messages 64, listings 96 (item içeriğine göre ölç).

### O5 — Image cacheWidth (P1)
27 `Image.network/file` raw çağrısı.

Fix: `AssetRefImage`'in line 93-94'deki pattern'i (zaten `cachePxFromLogical(context, displayWidth)` kullanıyor) tüm Image çağrılarına yay:
```dart
Image.network(
  url,
  cacheWidth: cachePxFromLogical(context, 100), // thumb için 100dp
)
```

### O6 — Battle map repaint throttle (P1)
**File**: `lib/presentation/screens/battle_map/battle_map_screen.dart` lines 125-140

`strokeTick` her pan event'inde fire ediyor. Fix:
- Stroke state'i `_StrokeListenable extends ChangeNotifier`'a ayır.
- `notifyListeners` 16ms throttled: `if (DateTime.now().difference(_lastTick).inMilliseconds < 16) return;`.

### O7 — Drift watch() full-list (P1)
17 DAO `watchByWorld()` row değişiminde tam liste kopyalıyor.

→ Row-level sync redesign (May 17) zaten bunu hedefliyor. F7/F8 fazında DAO'lar dönüştürülürken:
- `select(...).where(...).watch().distinct()` filtre subscription time'da.
- Single-row update → single-row emit (mevcut bulk list emit yerine).

### O8 — EntityCard schema field filter (P1)
**File**: `lib/presentation/screens/database/entity_card.dart` lines 111-114

`visible.where(...).toList()` her build çalışıyor. Fix: `FutureProvider.family<List<Field>, String>` ile (categoryId, schemaVersion) tuple cache.

### O9-O14 — Diğer P2 kalemleri
- Profile waterfall (`profile_screen.dart` 54-277) → single `userProfileSummaryProvider` tuple.
- Mind map full JSON serialize → diff/patch (row-level sync ile birlikte).
- Marketplace dual-provider sequential → `Future.wait` tek provider.
- NavigationRail `List.generate` her build → static const.
- Sync engine ana isolate JSON parse → `compute()` isolate.
- Token image cache leak → `removeWhere`.

---

## PR Sırası (Kalanlar)

1. **PR-O4** — ListView itemExtent (feed/messages/marketplace/listings). Mekanik ama her item'ın gerçek yüksekliği ölçülerek doğrulanmalı.
2. **PR-O1** — MainScreen `.select()` projeksiyonları (yüksek risk, 45 ref.watch).
3. **PR-K2** — Wizard step-by-step Consumer'a böl (yüksek risk, 4500 LOC dosya).
4. **PR-O9** — Profile screen single summary provider.
5. **PR-O10** — Mind map differential serialize (row-level sync ile birlikte).
6. **PR-O12** — NavigationRail destinations list cache (marginal).
7. **PR-O13** — Sync engine `compute()` isolate JSON parse.

## Verification

### Klavye latency (K1/K3/K4)
- Mobil emülatör (Pixel 6 + iPhone SE).
- `flutter run --profile` ile profile build.
- DevTools Performance overlay → keyboard açılışında 60 FPS sınırı (raster + ui ≤16ms).
- Test akışları:
  1. Landing → email tap → keyboard açılış < 250ms, frame drop yok.
  2. Hub → "New World" dialog → name field tap → dialog transition + keyboard ardışık (paralel değil).
  3. Hub → "New Package" dialog → aynı.
  4. Session → Quick Add (combatant) → aynı.
  5. Map → Add Pin → aynı.

### Mention overlay (M1+M2)
1. Session log'a tap, `@a` yaz → dropdown keyboard ÜSTÜNDE.
2. Portrait + landscape.
3. Cursor ekran altındayken `@` → overlay üst clamp doğru.
4. Dropdown açıkken keyboard dismiss → overlay yer değiştir.
5. Wide ekran (≥600dp) → below-first davranışı korunmuş.

### Analyzer
`flutter analyze` 0 hata. Mevcut warning'ler (level_up_planner, feats_class.dart unused) bu PR'larla ilgili değil — pre-existing.

`flutter test` user feedback ile skip — analyzer + manuel yeterli.
