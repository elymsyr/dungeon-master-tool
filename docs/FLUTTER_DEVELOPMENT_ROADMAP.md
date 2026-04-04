# Flutter Development Roadmap & Sprint Plan

> **Proje:** Dungeon Master Tool v2.0 (Flutter)
> **Kaynak:** Python/PyQt6 v0.8.4 → Flutter/Dart
> **Sprint Süresi:** 10 iş günü (2 takvim haftası)
> **Tahmini Toplam:** 12 Sprint (~24 hafta)

---

## İçindekiler

0. [Güncel Durum (Nisan 2026)](#0-güncel-durum-nisan-2026)
1. [Platform Stratejisi](#1-platform-stratejisi)
2. [Responsive UI Mimarisi](#2-responsive-ui-mimarisi)
3. [Ekran Bazlı Responsive Tasarım](#3-ekran-bazlı-responsive-tasarım)
4. [Second Screen: Desktop vs Mobile](#4-second-screen-desktop-vs-mobile)
5. [Sprint Planı](#5-sprint-planı)
6. [Definition of Done](#6-definition-of-done)
7. [KPI ve Performans Hedefleri](#7-kpi-ve-performans-hedefleri)
8. [Risk Yönetimi](#8-risk-yönetimi)

---

## 0. Güncel Durum (Nisan 2026)

> Son güncelleme: **2026-04-04** | Branch: `flutter` | ~90 Dart dosyası, ~200 KB kaynak kod

### Genel İlerleme

| Sprint | Konu | Tamamlanma | Notlar |
|--------|------|-----------|--------|
| Sprint 0 | Proje Kurulumu & Foundation | **~90%** | Schema migration eksik; 4 unit test yazıldı |
| Sprint 1 | Schema-Driven Entity Card & FieldWidgetFactory | **~90%** | `entity_card.dart`, `field_widget_factory.dart`, `entity_sidebar.dart` tam; NpcSheet alt tab'ları klasörlendirilmemiş |
| Sprint 2 | Advanced Widgets + Template Studio | **~55%** | `template_editor.dart` (1515 satır) tam; Markdown/Image/File/Tag/Date widget'ları eksik; `ImportDialog` yok |
| Sprint 3 | Session + Combat Tracker | **~80%** | `session_screen.dart` (867 satır), `combat_provider.dart` tam; mobile layout ve `EncounterColumnDialog` eksik |
| Sprint 4 | Battle Map | **~85%** | 6 katman, tüm araçlar, scroll zoom, fit-to-screen tam; mobile toolbar (bottom sheet) eksik |
| Sprint 5 | Mind Map + World Map | **~0%** | `mind_map/` ve `map/` klasörleri boş — hiç başlanmadı |
| Sprint 6 | Soundpad + PDF + Polish | **~5%** | Sadece tema/dil altyapısı var; AudioEngine, SoundpadPanel, PDF viewer yok |
| Sprint 7 | Dual Screen + Mobile Adaptation | **~0%** | Başlanmadı |
| Sprint 8 | API Integration + Library | **~0%** | `datasources/remote/` boş; başlanmadı |
| Sprint 9–12 | Online + Deployment | **~0%** | Başlanmadı |

### Tamamlanan Önemli Bileşenler

**Altyapı & Domain:**
- ✅ Clean Architecture (domain / data / application / presentation katmanları)
- ✅ Tüm domain entity'leri Freezed ile (`entity`, `campaign`, `session`, `encounter`, `mind_map`, `map_data`, `audio_models`)
- ✅ Schema sistemi: `WorldSchema`, `EntityCategorySchema`, `FieldSchema`, `FieldGroup`, `CategoryRule`, `EncounterLayout`, `EncounterConfig`
- ✅ `generateDefaultDnd5eSchema()` — 15 kategori, tam alan tanımları
- ✅ `CampaignLocalDataSource` (MsgPack I/O), `CampaignRepositoryImpl`
- ✅ `AppPaths` (portable + platform-aware), `ScreenType` breakpoint sistemi
- ✅ `AppEventBus` service, `RuleEngine` (D&D 5e hesaplamalar)
- ✅ `ThemeNotifier` + `LocaleNotifier` (11 tema, 4 dil — EN/TR/DE/FR)
- ✅ `DmToolColors` ThemeExtension (432 satır, 80+ renk değişkeni)

**Ekranlar & Widget'lar:**
- ✅ `LandingScreen` → `CampaignSelectorScreen` → `MainScreen` (tam 4-tab navigasyon)
- ✅ `HubScreen` (TemplatesTab, WorldsTab, SettingsTab, SocialTab)
- ✅ `TemplateEditor` (69 KB / 1515 satır — kategori + alan + encounter config yönetimi)
- ✅ `DatabaseScreen` (dual-panel splitter, filtreleme)
- ✅ `EntityCard` (28 KB / 746 satır — schema-driven render)
- ✅ `FieldWidgetFactory` (30 KB / 782 satır — 16 field tipi)
- ✅ `EntitySidebar` (347 satır)
- ✅ `SessionScreen` (37 KB / 867 satır — combat tracker, dice roller, event log, notes)
- ✅ `CombatProvider` (473 satır — initiative, HP, conditions, turn advance)
- ✅ `HpBar`, `ConditionBadge`, `ResizableSplit`
- ✅ `BattleMapScreen` + `BattleMapNotifier` + `BattleMapPainter` (6 katman, tüm araçlar, scroll zoom, fit-to-screen)
- ✅ `BattleMapToolbar` (2 satır, grid kontrolleri), `TokenWidget` (drag + resize)
- ✅ `EntitySelectorDialog`

**Testler:**
- ✅ `default_schema_test.dart`, `entity_test.dart`, `field_group_test.dart`, `widget_test.dart`

### Eksik / Sıradaki Öncelikler

| Öncelik | Bileşen | Sprint |
|---------|---------|--------|
| 🔴 Yüksek | Mind Map canvas + node'lar (sonsuz canvas, LOD, Bézier) | Sprint 5 |
| 🔴 Yüksek | World Map screen + pin sistemi | Sprint 5 |
| 🔴 Yüksek | `MarkdownFieldWidget` (dual mode + @mention) | Sprint 2 |
| 🔴 Yüksek | `ImageFieldWidget` + `ImageGallery` | Sprint 2 |
| 🟠 Orta | `AudioEngine` + `SoundpadPanel` | Sprint 6 |
| 🟠 Orta | `PdfViewerWidget` (pdfrx) | Sprint 6 |
| 🟠 Orta | Schema migration (`data/schema/` boş) | Sprint 0 kalan |
| 🟠 Orta | Battle map mobile toolbar (bottom sheet) | Sprint 4 kalan |
| 🟠 Orta | `EncounterColumnDialog`, session mobile layout | Sprint 3 kalan |
| 🟡 Düşük | `FileFieldWidget`, `TagListFieldWidget`, `DateFieldWidget` | Sprint 2 |
| 🟡 Düşük | `ImportDialog`, API browser, bulk downloader | Sprint 2 / Sprint 8 |
| 🟡 Düşük | `NpcSheet` alt tab klasörü (`npc_sheet/`) | Sprint 1 refactor |
| 🟡 Düşük | Dual Screen / Player Window (`screen/` boş) | Sprint 7 |
| ⚪ Beklemede | Online (NetworkBridge, sunucu, WebRTC) | Sprint 9–11 |

---

## 1. Platform Stratejisi

### 1.1 Build Hedefleri

| Platform | Öncelik | Build Format | Hedef Sprint |
|---|---|---|---|
| Windows 10/11 | P0 (Birincil) | MSIX / Inno Setup | Sprint 1'den itibaren |
| Linux (Ubuntu/Fedora/Arch) | P0 (Birincil) | AppImage / Flatpak | Sprint 1'den itibaren |
| macOS 12+ (Intel + Apple Silicon) | P1 | DMG / App Bundle | Sprint 3'ten itibaren |
| Android 10+ | P1 | APK / AAB (Play Store) | Sprint 7'den itibaren |
| iOS 15+ | P2 | IPA (App Store) | Sprint 9'dan itibaren |
| Web (Chrome/Firefox/Safari) | P3 | Static hosting | Sprint 11'den itibaren |

### 1.2 Platform-Specific Özellik Matrisi

| Özellik | Desktop (Win/Linux/macOS) | Tablet (iPad/Android Tab) | Mobil (Phone) |
|---|---|---|---|
| DM Modu (tam özellik) | Tam | Tam | Kısıtlı (*) |
| Player Modu | Tam | Tam | Tam |
| Dual Screen (ikinci pencere) | Native window | PiP / Split screen | Screen share (WebRTC) |
| Battle Map (DM) | 6 katman + tüm araçlar | 6 katman + touch araçlar | Sadece görüntüleme + basit fog |
| Battle Map (Player) | Read-only canvas | Read-only canvas | Read-only canvas |
| Mind Map | Tam (LOD + tüm node tipleri) | Tam | Sadece görüntüleme + basit düzenleme |
| Combat Tracker | Tam tablo + drag-drop | Tam tablo + drag-drop | Kompakt kart listesi |
| Soundpad | 3-tab panel (müzik/ambience/sfx) | Tam | Mini player (müzik + quick SFX) |
| PDF Viewer | Embedded panel | Embedded panel | Tam ekran modal |
| Entity Editor (NpcSheet) | 8-tab scrollable | 8-tab scrollable | Tek-tab accordion |
| Entity Sidebar | Sol panel (250-350px) | Sol drawer | Bottom sheet |
| Toolbar | Horizontal bar + projection | Horizontal bar | Compact top bar + FAB menü |

> (*) Mobil DM modu: Combat tracker, entity yönetimi, dice roller ve basit battle map kontrolü. Mind map düzenleme ve tam battle map araçları yok.

---

## 2. Responsive UI Mimarisi

### 2.1 Breakpoint Sistemi

```dart
enum ScreenType { phone, tablet, desktop }

ScreenType getScreenType(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width < 600) return ScreenType.phone;
  if (width < 1200) return ScreenType.tablet;
  return ScreenType.desktop;
}
```

| Breakpoint | Cihaz | Layout Stratejisi |
|---|---|---|
| < 600px | Telefon | Tek panel, bottom nav, sheet/modal'lar |
| 600-1200px | Tablet / Küçük laptop | İki panel, side nav, drawer'lar |
| > 1200px | Desktop | Çoklu panel, splitter'lar, ayrı pencereler |

### 2.2 Navigation Dönüşümü

**Desktop (> 1200px):**
```
┌─────────────────────────────────────────────────────┐
│ Toolbar (campaign label + projection + controls)     │
├──────┬──────────────────────┬───────────┬───────────┤
│      │                      │           │           │
│ Side │   Tab Content        │ Soundpad  │  PDF      │
│ bar  │   (Database/Session/ │ (optional)│ (optional)│
│      │    MindMap/Map)      │           │           │
│      │                      │           │           │
├──────┴──────────────────────┴───────────┴───────────┤
│ Status bar (connection status)                       │
└─────────────────────────────────────────────────────┘
```

**Tablet (600-1200px):**
```
┌─────────────────────────────────────┐
│ Top bar (compact toolbar)           │
├──────┬──────────────────────────────┤
│      │                              │
│ Side │   Tab Content                │
│ Rail │   (full width)               │
│      │                              │
│      │                              │
├──────┴──────────────────────────────┤
│ Bottom bar (soundpad mini / status) │
└─────────────────────────────────────┘
   ↑ Sidebar: NavigationRail (icons)
   ↑ Soundpad/PDF: Drawer (right)
```

**Mobile (< 600px):**
```
┌──────────────────────────┐
│ App bar (minimal)        │
├──────────────────────────┤
│                          │
│   Full-screen content    │
│   (tek ekran)            │
│                          │
│                          │
├──────────────────────────┤
│ Bottom Nav               │
│ (DB | Session | Map | ⋯) │
└──────────────────────────┘
   ↑ Entity sidebar: Bottom sheet
   ↑ Soundpad: Bottom sheet (mini)
   ↑ PDF: Full-screen modal
   ↑ NpcSheet: Full-screen route
```

### 2.3 Adaptive Layout Widget

```dart
class AdaptiveLayout extends StatelessWidget {
  final Widget Function(BuildContext) phone;
  final Widget Function(BuildContext) tablet;
  final Widget Function(BuildContext) desktop;

  const AdaptiveLayout({
    required this.phone,
    required this.tablet,
    required this.desktop,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return switch (getScreenType(context)) {
      ScreenType.phone => phone(context),
      ScreenType.tablet => tablet(context),
      ScreenType.desktop => desktop(context),
    };
  }
}
```

### 2.4 Splitter → Responsive Dönüşüm

Mevcut PyQt6 QSplitter kullanımları:

| Mevcut Splitter | Desktop | Tablet | Mobile |
|---|---|---|---|
| Main: Sidebar + Content + Soundpad + PDF | `MultiSplitView` 4-panel | Rail + Content + Drawer | Bottom nav + Content + Sheet |
| Database: Entity panel 1 + Entity panel 2 | `MultiSplitView` 2-panel | Tek panel + tab | Tek panel |
| Session: Tracker + (Log + Tabs) | `MultiSplitView` horizontal | `MultiSplitView` horizontal | Vertical stack |
| Session Right: Log + Bottom tabs | `MultiSplitView` vertical | Aynı | Tab'lar arası geçiş |

---

## 3. Ekran Bazlı Responsive Tasarım

### 3.1 Database Ekranı

**Desktop:**
```
┌──────────┬───────────────────┬───────────────────┐
│ Sidebar  │  Entity Tab 1     │  Entity Tab 2     │
│ (search, │  (NpcSheet)       │  (NpcSheet)       │
│  filter, │                   │                   │
│  list)   │                   │                   │
│  300px   │      50%          │      50%          │
└──────────┴───────────────────┴───────────────────┘
```

**Tablet:**
```
┌──────┬───────────────────────────────────────────┐
│ Rail │  Single Entity Panel                      │
│ (60) │  (NpcSheet - tabbed, full width)          │
│      │                                           │
│      │  [Entity tabs at top]                     │
└──────┴───────────────────────────────────────────┘
   ↑ Sidebar: Drawer (left swipe)
   ↑ İkinci entity: Tab sistemi (tek panel)
```

**Mobile:**
```
┌──────────────────────────┐
│ Search bar + filter icon │
├──────────────────────────┤
│                          │
│  Entity List             │
│  (tam ekran liste)       │
│                          │
├──────────────────────────┤
│ [+] New Entity FAB       │
└──────────────────────────┘
   ↑ Entity tap → Full-screen NpcSheet route
   ↑ NpcSheet: Tek-tab accordion layout
```

### 3.2 NpcSheet Responsive Layout

**Desktop / Tablet (> 600px):**
- Üst: Görsel galerisi (sol) + Metadata form (sağ) — yan yana
- 8-tab widget: Stats, Spells, Actions, Inventory, Description, Images, Docs, Battle Maps
- Alt: DM Notes (kırmızı kenarlıklı kutu)

**Mobile (< 600px):**
- Üst: Görsel galerisi (tam genişlik, compact)
- Metadata: Vertical form (tam genişlik)
- Sekme yerine: Expandable sections (accordion)
  - Stats (varsayılan açık)
  - Combat Stats
  - Description
  - Spells (sayı badge'i)
  - Actions (sayı badge'i)
  - Inventory (sayı badge'i)
  - Docs / Battle Maps
- Alt: DM Notes
- FAB: Save + Delete actions

```dart
class NpcSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompact = getScreenType(context) == ScreenType.phone;

    if (isCompact) {
      return _NpcSheetMobile(entity: entity);   // Accordion layout
    }
    return _NpcSheetDesktop(entity: entity);     // Tab layout
  }
}
```

### 3.3 Session Ekranı

**Desktop:**
```
┌───────────────────┬─────────────────────────────────┐
│ Combat Tracker    │  Session Controls (top bar)      │
│ ┌───────────────┐ │  ┌─────────────────────────────┐ │
│ │ Initiative    │ │  │ Event Log / Notes            │ │
│ │ Table         │ │  │ (splitter)                   │ │
│ │               │ │  ├─────────────────────────────┤ │
│ ├───────────────┤ │  │ Bottom Tabs:                │ │
│ │ Dice Roller   │ │  │ [Notes|BattleMap|Player|    │ │
│ │ (d4-d100)     │ │  │  EntityStats]               │ │
│ └───────────────┘ │  └─────────────────────────────┘ │
│      40%          │              60%                  │
└───────────────────┴─────────────────────────────────┘
```

**Tablet:**
- Aynı layout, combat tracker daraltılmış (30%/70%)
- Dice roller: Floating action button menüsüne taşınır

**Mobile:**
```
┌──────────────────────────┐
│ Session top bar           │
│ (encounter selector)      │
├──────────────────────────┤
│ ┌────────────────────────┐│
│ │ Combat Table           ││
│ │ (compact card list)    ││
│ │ ┌──────┬──────┬──────┐ ││
│ │ │ Gob  │ War  │ Mage │ ││
│ │ │ HP■■ │ HP■■ │ HP■  │ ││
│ │ └──────┴──────┴──────┘ ││
│ └────────────────────────┘│
│ [Next Turn] [Round: 3]    │
├──────────────────────────┤
│ Tabs: Log | Notes | Map   │
│ (swipeable tab content)   │
├──────────────────────────┤
│ 🎲 FAB (dice roller sheet)│
└──────────────────────────┘
```

### 3.4 Battle Map

**Desktop / Tablet:**
- Tam 6 katmanlı canvas + toolbar (2 satır)
- Token drag-and-drop
- Tüm araçlar (navigate, ruler, circle, draw, fog)
- Grid kontrolleri (cell size, feet, snap)

**Mobile (DM Modu):**
- Canvas: Tam ekran, touch gesture'lar (pinch zoom, two-finger pan)
- Toolbar: Bottom sheet (yukarı kaydırarak aç)
  - Araçlar: Navigate, Fog (basitleştirilmiş), Token ekle
  - Ruler/Circle: Uzun basma ile erişim
  - Draw: Parmak çizim modu
- Grid: Basitleştirilmiş toggle (açık/kapalı)
- Token: Uzun basma → sürükle

**Mobile (Player Modu):**
- Read-only canvas (sadece görüntüleme)
- Pinch zoom + pan
- Token pozisyonları sync
- Fog sync
- Turn order overlay (üst kısımda horizontal scroll)

```dart
class BattleMapScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screen = getScreenType(context);

    return Scaffold(
      body: BattleMapCanvas(isDmView: widget.isDmView),
      // Desktop: Üst toolbar
      appBar: screen == ScreenType.desktop ? _buildDesktopToolbar() : null,
      // Mobile: Bottom sheet toolbar
      bottomSheet: screen == ScreenType.phone ? _buildMobileToolbar() : null,
      // Tablet: Floating toolbar
      floatingActionButton: screen == ScreenType.tablet ? _buildTabletFAB() : null,
    );
  }
}
```

### 3.5 Mind Map

**Desktop:**
- Sonsuz canvas + floating controls (zoom, node oluştur, grid toggle)
- LOD 3 zonalı sistem
- Tüm node tipleri (Note, Entity, Image, Workspace)
- Bézier bağlantılar + shift-drag ile bağlama
- Undo/Redo (Ctrl+Z)

**Tablet:**
- Aynı canvas + touch gesture optimize
- Floating controls daha büyük (touch-friendly)
- Node oluşturma: FAB menü
- Bağlantı: Uzun basma + sürükle

**Mobile:**
- Canvas: Read-only görüntüleme + pinch zoom
- Basit düzenleme:
  - Note node oluştur/düzenle (basitleştirilmiş)
  - Mevcut bağlantıları görüntüle
  - Entity node'a tap → Entity detayı (full-screen)
- Tam düzenleme yok (desktop/tablet gerekli)

### 3.6 Soundpad

**Desktop:**
```
┌─────────────────────┐
│ Soundpad Panel      │
│ [Music|Ambience|SFX]│
│ ┌─────────────────┐ │
│ │ Theme: Forest   │ │
│ │ [Normal][Combat]│ │
│ │ Intensity: ■■□  │ │
│ └─────────────────┘ │
│ ┌─────────────────┐ │
│ │ Ambience x4     │ │
│ │ Rain  ▪▪▪▪▪ 70% │ │
│ │ Fire  ▪▪▪   50% │ │
│ └─────────────────┘ │
│ Master: ▪▪▪▪ 50%   │
│ [Stop All]          │
└─────────────────────┘
```

**Tablet:**
- Right drawer (swipe from right edge)
- Aynı 3-tab yapısı

**Mobile — Mini Player:**
```
┌──────────────────────────┐
│ 🎵 Forest - Combat ▶ ■■□ │  ← Persistent mini bar (bottom nav üstünde)
└──────────────────────────┘
   ↑ Tap → Full-screen Soundpad bottom sheet
```

Mini player'da:
- Aktif tema + state gösterimi
- Play/Pause + Intensity quick control
- Master volume slider
- Tap → tam soundpad açılır

---

## 4. Second Screen: Desktop vs Mobile

### 4.1 Desktop — Native Multi-Window (Mevcut Davranış)

```
┌─────────────────────┐    ┌─────────────────────┐
│   DM Window         │    │   Player Window      │
│   (Monitor 1)       │    │   (Monitor 2)        │
│                     │    │                      │
│   Tam DM araçları   │◄──►│   5-sayfa stack:     │
│                     │    │   - Images            │
│                     │    │   - Battle Map        │
│                     │    │   - Black Screen      │
│                     │    │   - Stat Block        │
│                     │    │   - PDF               │
└─────────────────────┘    └─────────────────────┘
      Signal/Provider sync
```

**Paket:** `desktop_multi_window`
**Sync:** `ProviderContainer` paylaşımı + `DesktopMultiWindow.invokeMethod()`
**Monitor:** `screen_retriever` ile ikinci monitör otomatik tespit

### 4.2 Tablet — Split Screen / PiP

**iPadOS / Android Tablet:**
- DM uygulaması + Player uygulaması yan yana (Split View)
- Veya: DM uygulaması tam ekran + Player PiP (Picture-in-Picture)

**Implementasyon:**
- Player window ayrı bir `Activity` / `ViewController` olarak açılır
- Android: `launchMode="singleInstance"` + PiP mode
- iPadOS: Multi-window (Scenes API)

```dart
// Tablet split/PiP player window
class PlayerWindowLauncher {
  static Future<void> openPlayerView(BuildContext context) async {
    if (Platform.isAndroid || Platform.isIOS) {
      // Tablet: Ayrı activity/scene olarak aç
      await MethodChannel('player_window').invokeMethod('open');
    } else {
      // Desktop: desktop_multi_window ile ayrı pencere
      await DesktopMultiWindow.createWindow(...);
    }
  }
}
```

### 4.3 Mobile — Screen Share (WebRTC)

Mobil cihazlarda ikinci fiziksel ekran olmadığı için, **WebRTC tabanlı ekran paylaşımı** ile player'lara içerik yansıtılır.

**Mimari:**

```
┌──────────────┐     WebRTC      ┌──────────────────┐
│ DM Phone     │ ──────────────► │ Player Phone/Tab  │
│              │   (P2P veya     │                   │
│ Projection   │    TURN server) │ Player View       │
│ content      │                 │ (tam ekran)       │
└──────────────┘                 └──────────────────┘
```

**Akış:**
1. DM "Share Screen" butonuna basar
2. Uygulama 6 karakterlik oda kodu üretir (veya mevcut session kodu)
3. Player'lar kodu girer → WebRTC P2P bağlantı kurulur
4. DM'in projection state'i (görsel, battle map, stat block) player'lara stream edilir

**İki Mod:**

**Mod A — Rendered Stream (Basit):**
- DM tarafında projection content bir `RepaintBoundary` ile sarılır
- Her frame `toImage()` ile capture edilir (15-30 FPS)
- JPEG olarak WebRTC data channel üzerinden gönderilir
- Player tarafında `Image.memory()` ile gösterilir
- **Avantaj:** Basit implementasyon, tüm content tipleri desteklenir
- **Dezavantaj:** Bant genişliği yüksek, player interaktivite yok

**Mod B — State Sync (Gelişmiş, Online ile entegre):**
- Projection state JSON olarak gönderilir (aktif sayfa, görsel path'leri, fog data, token pozisyonları)
- Player tarafında aynı widget'lar lokal olarak render edilir
- Asset'ler önceden transfer edilir veya CDN'den çekilir
- **Avantaj:** Düşük bant genişliği, player zoom/pan yapabilir
- **Dezavantaj:** Tüm asset'lerin player'da olması gerekir

**Öneri:** Sprint 7-8'de Mod A (basit stream) ile başla, Sprint 10-11'de Mod B (state sync) ile geliştir.

```dart
// Screen share service
class ScreenShareService {
  late final RTCPeerConnection _peerConnection;
  late final RTCDataChannel _dataChannel;
  Timer? _captureTimer;

  /// DM tarafı: Projection content'i capture et ve gönder
  Future<void> startSharing(GlobalKey projectionKey) async {
    _captureTimer = Timer.periodic(
      const Duration(milliseconds: 66), // ~15 FPS
      (_) async {
        final boundary = projectionKey.currentContext!
            .findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        // JPEG encode + WebRTC data channel ile gönder
        _dataChannel.send(RTCDataChannelMessage.fromBinary(byteData!.buffer.asUint8List()));
      },
    );
  }

  /// Player tarafı: Stream'i al ve göster
  Stream<Uint8List> get incomingFrames => _frameController.stream;
}
```

### 4.4 Platform Karar Matrisi

| Durum | Çözüm | Paket |
|---|---|---|
| Desktop, 2 monitör var | Native ikinci pencere | `desktop_multi_window` |
| Desktop, tek monitör | Native pencere (1/2 ekran) | `desktop_multi_window` |
| Tablet, iPadOS/Android | Split View / PiP | Platform native APIs |
| Mobil, offline (aynı oda) | WebRTC P2P screen share | `flutter_webrtc` |
| Mobil, online | Server relay (socket.io) | `socket_io_client` |
| Web browser | Yeni tab/pencere | `dart:html` window.open |

---

## 5. Sprint Planı

### Sprint 0 — Proje Kurulumu & Schema-Driven Foundation (Gün 1-10) · `~90% TAMAMLANDI`

**Hedef:** Çalışan iskelet uygulama, schema-driven entity sistemi, kampanya açabilir, tema değiştirebilir.

| # | Task | Dosyalar | Tahmin | Kabul Kriterleri |
|---|---|---|---|---|
| 0.1 | ~~Flutter proje oluşturma, dizin yapısı~~ ✅ | Tüm `lib/` klasörleri | 2s | `flutter run` çalışır |
| 0.2 | ~~`AppPaths` — config.py port (portable + platform)~~ ✅ | `lib/core/config/app_paths.dart` | 2s | Windows + Linux'ta doğru path |
| 0.3 | ~~Breakpoint sistemi + `ScreenType`~~ ✅ | `lib/core/utils/screen_type.dart` | 1s | Pencere boyutuna göre layout değişir |
| 0.4 | ~~Riverpod provider skeleton~~ ✅ | `lib/application/providers/*.dart` | 3s | Compile hatasız |
| 0.5 | ~~`AppEventBus` service~~ ✅ | `lib/application/services/event_bus.dart` | 1s | Event emit/listen çalışır |
| 0.6 | ~~**Schema domain modelleri**~~ ✅ | `lib/domain/entities/schema/` | 4s | 16 FieldType tanımlı, Freezed build çalışır |
| 0.7 | ~~**`generateDefaultDnd5eSchema()`**~~ ✅ | `lib/domain/entities/schema/default_dnd5e_schema.dart` | 4s | 15 kategori, tüm alan tipleri |
| 0.8 | ~~**`EncounterLayout` + `EncounterColumn`**~~ ✅ | `lib/domain/entities/schema/encounter_layout.dart` | 2s | Default D&D layout: name, init, HP, AC, conditions |
| 0.9 | ~~Domain entities: `Entity`, `Campaign`, `Session`, `Encounter`, `Combatant`~~ ✅ | `lib/domain/entities/` | 3s | Entity.fields map-based, Freezed + g.dart build çalışır |
| 0.10 | ~~Domain entities: `MindMapNode`, `MindMapEdge`, `MapData`, `AudioModels`~~ ✅ | `lib/domain/entities/` | 2s | Freezed build_runner çalışır |
| 0.11 | ~~`CampaignLocalDataSource` — MsgPack okuma/yazma~~ ✅ | `lib/data/datasources/local/campaign_local_ds.dart` | 3s | MsgPack I/O çalışır |
| 0.12 | **Schema migration: `lib/data/schema/schema_migration.dart`** ❌ | `lib/data/schema/` (boş) | 3s | Eski kampanya açılınca world_schema oluşur, veri kaybı yok |
| 0.13 | Legacy uyumluluk: `SCHEMA_MAP`, `PROPERTY_MAP` ❌ | `lib/data/schema/legacy_maps.dart` | 1s | TR→EN dönüşüm testi geçer |
| 0.14 | ~~`DmToolColors` ThemeExtension (80+ renk)~~ ✅ | `lib/presentation/theme/dm_tool_colors.dart` | 2s | 432 satır, tüm renk alanları tanımlı |
| 0.15 | ~~11 tema paleti tanımlama~~ ✅ | `lib/presentation/theme/palettes.dart` | 4s | 11 palet build hatasız |
| 0.16 | ~~`ThemeNotifier` + runtime tema değiştirme~~ ✅ | `lib/application/providers/theme_provider.dart` | 1s | Tema anlık değişir |
| 0.17 | ~~4 dil dosyası (EN/TR/DE/FR)~~ ✅ | `lib/presentation/l10n/` | 3s | 4 dil ARB çalışır |
| 0.18 | ~~`LocaleNotifier` + runtime dil değiştirme~~ ✅ | `lib/application/providers/locale_provider.dart` | 1s | Dil anlık değişir |
| 0.19 | ~~`CampaignSelectorScreen`~~ ✅ | `lib/presentation/screens/campaign_selector/` | 3s | Kampanya listesi, seçim/oluşturma |
| 0.20 | ~~`MainScreen` (tab bar + navigasyon)~~ ✅ | `lib/presentation/screens/main_screen.dart` | 2s | 4 tab arası geçiş + responsive nav |
| 0.21 | `SettingsRepository` impl ⚠️ | `lib/data/repositories/settings_repository_impl.dart` | 2s | Tema/dil/volume kaydedilir (settings_tab.dart var, repository impl yok) |
| 0.22 | ~~Schema + Entity unit testleri~~ ✅ (kısmi) | `test/domain/` | 2s | `default_schema_test`, `entity_test`, `field_group_test` yazıldı |
| **Toplam** | | | **51s** | |

**Sprint 0 Doğrulama:**
- Mevcut Python kampanya `.dat` dosyası Flutter'da açılır + otomatik schema migration
- Yeni kampanya oluşturulunca 15 kategorili D&D 5e default schema gömülü gelir
- Tema ve dil değiştirilebilir
- Desktop + mobil layout skeleton çalışır

---

### Sprint 1 — Schema-Driven Entity Card & FieldWidgetFactory (Gün 11-20) · `~90% TAMAMLANDI`

**Hedef:** Schema-driven entity card rendering, FieldWidgetFactory, sidebar. Entity card'lar hardcoded değil, WorldSchema'dan dinamik olarak üretilir.

| # | Task | Tahmin | Kabul Kriterleri |
|---|---|---|---|
| 1.1 | ~~`EntityRepository` CRUD impl (schema-aware)~~ ✅ | 4s | `entity_provider.dart` içinde CRUD işlenir |
| 1.2 | ~~`EntityNotifier` + `WorldSchemaNotifier` provider'ları~~ ✅ | 3s | `entity_provider.dart` (219 satır) çalışır |
| 1.3 | ~~**`FieldWidgetFactory`** — 16 field tipi~~ ✅ | 4s | `field_widget_factory.dart` (782 satır) tam |
| 1.4 | ~~**Core field widget'ları** (Text, TextArea, Integer, Float, Boolean)~~ ✅ | 3s | FieldWidgetFactory içinde tam |
| 1.5 | ~~**`EnumFieldWidget`** (dropdown)~~ ✅ | 2s | FieldWidgetFactory içinde tam |
| 1.6 | ~~**`RelationFieldWidget`** (entity selector)~~ ✅ | 3s | FieldWidgetFactory + EntitySelectorDialog |
| 1.7 | ~~**`StatBlockFieldWidget`** (6 ability score + modifier)~~ ✅ | 3s | FieldWidgetFactory içinde, mod hesaplama çalışır |
| 1.8 | ~~**`CombatStatsFieldWidget`** (HP, AC, Speed, CR, vb.)~~ ✅ | 2s | FieldWidgetFactory içinde tam |
| 1.9 | ~~**`ActionListFieldWidget`** (traits, actions, reactions)~~ ✅ | 3s | FieldWidgetFactory içinde, collapsible |
| 1.10 | ~~**`SpellListFieldWidget`**~~ ✅ | 3s | FieldWidgetFactory içinde tam |
| 1.11 | ~~**`EntityCard`** — Schema-driven rendering~~ ✅ | 3s | `entity_card.dart` (746 satır) tam |
| 1.12 | ~~`EntitySidebar` — Desktop~~ ✅ | 3s | `entity_sidebar.dart` (347 satır) tam |
| 1.13 | `EntitySidebar` — Mobile (bottom sheet) ⚠️ | 2s | Kısmi; bottom sheet adaptasyonu eksik |
| 1.14 | ~~`DatabaseScreen` — Desktop dual-panel~~ ✅ | 3s | `database_screen.dart` (460 satır) tam |
| 1.15 | ~~Global Edit Mode toggle~~ ✅ | 2s | `ui_state_provider.dart` içinde |
| 1.16 | ~~DM Notes section~~ ✅ | 1s | `entity_card.dart` içinde kırmızı kenarlıklı kutu |
| 1.17 | Entity CRUD + FieldWidget unit/widget testleri ❌ | 3s | Test yazılmadı |
| **Toplam** | | **47s** | |

**Sprint 1 Doğrulama:**
- 15 entity tipi schema-driven olarak oluşturulabilir/düzenlenebilir/silinebilir
- NPC kartında StatBlock, CombatStats, ActionList, SpellList doğru render
- Spell kartında Level(enum), School(text), vb. schema'dan dinamik render
- Sidebar filtreleri WorldSchema.categories'den geliyor (hardcoded değil)
- Yeni bir kategori eklendiğinde (schema'ya elle) otomatik sidebar'da görünür

---

### Sprint 2 — Advanced Widgets + Template Studio (Gün 21-30) · `~55% TAMAMLANDI`

**Hedef:** Kalan field widget'ları, MarkdownEditor, ImageGallery, Template Studio.

| # | Task | Tahmin | Kabul Kriterleri |
|---|---|---|---|
| 2.1 | **`MarkdownFieldWidget`** — dual mode + @mention ❌ | 5s | Toggle çalışır, @mention entity listesi, link oluşturur |
| 2.2 | **`ImageFieldWidget`** + `ImageGallery` ❌ | 3s | Birden fazla görsel, swipe, zoom, import |
| 2.3 | **`FileFieldWidget`** (PDF listesi + import) ❌ | 2s | PDF ekleme, silme, "Project PDF" butonu |
| 2.4 | **`TagListFieldWidget`** ❌ | 1s | Chip-based tag ekleme/silme |
| 2.5 | **`DateFieldWidget`** ❌ | 1s | Date picker |
| 2.6 | Image import (file_picker + campaign assets'e kopyala) ❌ | 2s | Görsel seçilir, assets/'e kaydedilir |
| 2.7 | Entity `prepare_from_external()` + dependency resolution ❌ | 3s | API'den gelen veri → entity.fields map'ine dönüşür |
| 2.8 | `ImportDialog` (basic) ❌ | 2s | Manuel entity import |
| 2.9 | ~~**`TemplateStudioDialog`** — Kategori yönetimi~~ ✅ | 4s | `template_editor.dart` (1515 satır) içinde tam |
| 2.10 | ~~**`TemplateStudioDialog`** — Field yönetimi~~ ✅ | 4s | `template_editor.dart` içinde tam |
| 2.11 | ~~**`TemplateStudioDialog`** — Field editor~~ ✅ | 3s | Tüm FieldSchema alanları düzenlenebilir |
| 2.12 | ~~**Template I/O** — `.dmt-template` export/import~~ ✅ | 3s | `template_local_ds.dart` ile çalışır |
| 2.13 | Widget test'leri (FieldWidgets + TemplateStudio) ❌ | 2s | Test yazılmadı |
| **Toplam** | | **35s** | |

**Sprint 2 Doğrulama:**
- Tüm 16 FieldType widget'ı çalışır
- MarkdownEditor @mention çalışır
- Template Studio'dan yeni kategori (ör. "Faction") eklenebilir, alanları tanımlanabilir
- Schema `.dmt-template` olarak export edilip başka kampanyaya import edilebilir
- Yeni eklenen kategori entity card'da schema-driven olarak render edilir

---

### Sprint 3 — Session + Combat Tracker (Gün 31-40) · `~80% TAMAMLANDI`

**Hedef:** Tam savaş yönetimi, oturum takibi, dice roller.

| # | Task | Tahmin | Kabul Kriterleri |
|---|---|---|---|
| 3.1 | `SessionRepository` impl ⚠️ | 2s | Session state `combat_provider.dart` içinde yönetiliyor, ayrı repository yok |
| 3.2 | ~~`SessionNotifier` / `CombatNotifier` provider~~ ✅ | 2s | `combat_provider.dart` (473 satır) tam |
| 3.3 | ~~`SessionScreen` — Desktop layout~~ ✅ | 3s | `session_screen.dart` (867 satır) — splitter, log, tabs tam |
| 3.4 | `SessionScreen` — Mobile layout ❌ | 2s | Compact card list + tab bar eksik |
| 3.5 | ~~`CombatNotifier` (Initiative, HP, condition, turn advance)~~ ✅ | 4s | Tam çalışır |
| 3.6 | ~~`CombatTable` — Desktop (schema-driven kolonlar)~~ ✅ | 4s | `session_screen.dart` içinde tam |
| 3.7 | `CombatTable` — Mobile (compact card list) ❌ | 3s | Eksik |
| 3.7b | `EncounterColumnDialog` ❌ | 2s | Kolon konfigürasyonu yok |
| 3.8 | ~~`CombatControlsBar` (round/turn, next turn)~~ ✅ | 2s | `session_screen.dart` içinde çalışır |
| 3.9 | ~~`HpBar` widget~~ ✅ | 1s | `hp_bar.dart` (43 satır) tam |
| 3.10 | ~~`ConditionBadge` widget~~ ✅ | 2s | `condition_badge.dart` (42 satır) tam |
| 3.11 | ~~Auto event log~~ ✅ | 2s | `combat_provider.dart` içinde otomatik log |
| 3.12 | ~~`DiceRoller` — Desktop~~ ✅ | 1s | `session_screen.dart` içinde d4-d100 çalışır |
| 3.13 | `DiceRoller` — Mobile (FAB + bottom sheet) ❌ | 2s | Eksik |
| 3.14 | ~~Session notes~~ ✅ | 1s | `session_screen.dart` içinde notes kaydedilir |
| 3.15 | ~~Session autosave~~ ✅ | 1s | Debounce çalışır |
| 3.16 | Entity Stats tab (read-only NpcSheet) ⚠️ | 2s | Combatant seçimi var, tam entity sheet eksik |
| 3.17 | Combat test'leri ❌ | 2s | Test yazılmadı |
| **Toplam** | | **38s** | |

**Sprint 3 Doğrulama:** Tam combat encounter oynanabilir. Initiative, HP, conditions çalışır. Combat tracker kolonları EncounterLayout'tan okunur. Custom field kolonu eklenebilir. Desktop + mobile layout doğru. Auto event log yazılır.

---

### Sprint 4 — Battle Map (Gün 41-50) · `~85% TAMAMLANDI`

**Hedef:** 6 katmanlı canvas, fog, araçlar, token'lar.

| # | Task | Tahmin | Kabul Kriterleri |
|---|---|---|---|
| 4.1 | ~~`BattleMapCanvas` iskelet (GestureDetector + Stack)~~ ✅ | 3s | Zoom/pan + scroll zoom çalışır |
| 4.2 | ~~Background layer (ui.Image paint)~~ ✅ | 2s | Harita görseli yüklenir |
| 4.3 | ~~Grid layer (configurable cell size)~~ ✅ | 2s | Grid gösterilir/gizlenir |
| 4.4 | ~~Draw layer (freehand Path, erase)~~ ✅ | 3s | Çizim + silme çalışır |
| 4.5 | ~~Fog layer (BlendMode.clear compositing)~~ ✅ | 4s | Fog add/erase polygon çalışır |
| 4.6 | ~~Measurement layer (ruler + circle, feet/squares label)~~ ✅ | 3s | Mesafe doğru hesaplanır |
| 4.7 | ~~Token layer — widget'lar, drag, resize~~ ✅ | 4s | Token sürükleme + per-token boyut override |
| 4.8 | Token boyut slider + per-token override | 2s | Global + bireysel boyut |
| 4.9 | Grid snap | 1s | Token'lar grid hücresine yapışır |
| 4.10 | `BattleMapTool` abstract + NavigateTool | 1s | Pan + middle-mouse |
| 4.11 | RulerTool + CircleTool | 2s | Kalıcı ölçümler, Navigate tık ile sil |
| 4.12 | DrawTool + EraseTool | 2s | Freehand çizim + silme |
| 4.13 | FogTool (add/erase) | 2s | Sol=fog ekle, sağ=fog sil |
| 4.14 | Battle map toolbar — Desktop (2 satır) | 2s | Araç butonları + grid kontrolleri |
| 4.8 | ~~Token boyut slider + per-token override~~ ✅ | 2s | Toolbar slider + resize dialog çalışır |
| 4.9 | ~~Grid snap~~ ✅ | 1s | Token'lar grid hücresine yapışır |
| 4.10 | ~~NavigateTool (pan + pinch-zoom)~~ ✅ | 1s | GestureDetector onScaleStart/Update tam |
| 4.11 | ~~RulerTool + CircleTool~~ ✅ | 2s | Kalıcı ölçümler, Navigate tık ile sil |
| 4.12 | ~~DrawTool + EraseTool~~ ✅ | 2s | Freehand çizim + silme |
| 4.13 | ~~FogTool (add/erase)~~ ✅ | 2s | Polygon fog add/erase çalışır |
| 4.14 | ~~Battle map toolbar — Desktop (2 satır)~~ ✅ | 2s | `battle_map_toolbar.dart` (381 satır) tam |
| 4.15 | Battle map toolbar — Mobile (bottom sheet) ❌ | 2s | `tools/` klasörü boş, eksik |
| 4.16 | ~~Fog/annotation/measurement persistence~~ ✅ | 2s | Base64 encode/decode ile persist |
| 4.17 | ~~Büyük görsel desteği~~ ✅ | 1s | `_loadImageFromFile` + async yükleme |
| 4.18 | ~~Scroll zoom (mouse wheel)~~ ✅ | 1s | `Listener` + `zoomAtPoint` eklendi (2026-04-04) |
| 4.19 | ~~Fit-to-screen (`resetView`)~~ ✅ | 1s | Haritayı viewport'a sığdırır (2026-04-04) |
| **Toplam** | | **38s** | |

**Sprint 4 Doğrulama:** 6 katman doğru sırada render. Fog compositing çalışır. Tüm araçlar desktop + mobile'da çalışır.

---

### Sprint 5 — Mind Map + World Map (Gün 51-60) · `~0% — BAŞLANMADI`

**Hedef:** Sonsuz canvas, LOD, node tipleri, dünya haritası.

| # | Task | Tahmin | Kabul Kriterleri |
|---|---|---|---|
| 5.1 | `MindMapCanvas` (InteractiveViewer.builder + Stack) | 3s | Sonsuz scroll + zoom |
| 5.2 | `MindMapGridPainter` (zoom-adaptive grid) | 1s | Grid zoom < 0.15'te gizlenir |
| 5.3 | LOD sistemi (3 zona: Full/Reduced/Template) | 3s | Zoom threshold'larında geçiş |
| 5.4 | Note node (MarkdownEditor, sarı bg) | 2s | Oluştur, düzenle, taşı |
| 5.5 | Entity node (compact NpcSheet, koyu bg) | 3s | Sidebar'dan drag-drop oluşturma |
| 5.6 | Image node (AspectRatio, transparent) | 2s | Görsel yükle, resize |
| 5.7 | Template mode (inverse-scale labels) | 2s | Zoom < 0.1'de okunabilir başlık |
| 5.8 | `ConnectionPainter` (Cubic Bézier) | 2s | Bağlantı çizgileri, seçim highlight |
| 5.9 | Connection oluşturma (Shift+drag / uzun basma) | 2s | İki node arası bağlantı |
| 5.10 | Node drag + resize (min 150x100) | 2s | Handle ile boyut değiştir |
| 5.11 | Undo/Redo (Command pattern, 50 max, Ctrl+Z) | 3s | 50 adım geri/ileri |
| 5.12 | Autosave (2s debounce) | 1s | Değişiklikten 2s sonra kaydet |
| 5.13 | Right-click context menu | 1s | Düzenle, sil, çoğalt, bağla |
| 5.14 | Mind map — mobile read-only view + basit düzenleme | 2s | Görüntüleme + not ekleme |
| 5.15 | `MapScreen` (dünya haritası + pin sistemi) | 3s | Harita yükle, zoom/pan |
| 5.16 | Entity pin'leri (renk kodlu) | 2s | NPC=turuncu, Monster=kırmızı, vb. |
| 5.17 | Timeline pin'leri (gün bazlı, parent-child) | 3s | Timeline oluştur/düzenle/sil |
| 5.18 | Map filtreler + "Project Map" butonu | 1s | Filtrele, player'a yansıt |
| **Toplam** | | **38s** | |

**Sprint 5 Doğrulama:** Mind map node'ları oluşturulabilir/bağlanabilir. LOD geçişleri sorunsuz. World map pin'leri çalışır.

---

### Sprint 6 — Soundpad + PDF + Polish (Gün 61-70) · `~5% — BAŞLANMADI`

**Hedef:** Audio engine, soundpad UI, PDF viewer, UI polish.

| # | Task | Tahmin | Kabul Kriterleri |
|---|---|---|---|
| 6.1 | `AudioEngine` — just_audio ile MusicDeck A/B | 4s | Track yükleme, çalma, durdurma |
| 6.2 | Crossfade sistemi (3s InOutCubic) | 3s | State geçişlerinde smooth crossfade |
| 6.3 | Intensity mask (base, level1, level2) | 2s | Intensity arttıkça katman eklenir |
| 6.4 | Ambience slot'ları (4x, infinite loop, per-slot volume) | 2s | 4 eşzamanlı ambience |
| 6.5 | SFX slot'ları (8x, one-shot) | 1s | 8 eşzamanlı SFX |
| 6.6 | Master volume (tüm player'ları etkiler) | 1s | Global volume çalışır |
| 6.7 | Theme YAML loader | 2s | Mevcut YAML dosyaları parse edilir |
| 6.8 | `SoundpadPanel` — Desktop (3-tab: music/ambience/sfx) | 3s | Tam kontrol paneli |
| 6.9 | `SoundpadPanel` — Tablet (right drawer) | 1s | Drawer açılır/kapanır |
| 6.10 | `SoundpadPanel` — Mobile (mini player + bottom sheet) | 3s | Persistent mini bar + tam sheet |
| 6.11 | `PdfViewerWidget` (pdfrx) | 2s | PDF açılır, zoom, scroll |
| 6.12 | PDF panel — Desktop (sağ panel, collapsible) | 1s | Soundpad ile karşılıklı exclusive |
| 6.13 | PDF panel — Mobile (full-screen modal) | 1s | Modal route |
| 6.14 | "Project PDF" akışı (entity → projection) | 1s | PDF player window'a gönderilir |
| 6.15 | `ProjectionManager` widget (drag-drop thumbnails) | 2s | Görsel sürükle-bırak, thumbnail strip |
| 6.16 | Toolbar — Desktop (tam toolbar) | 2s | Campaign label, projection, controls |
| 6.17 | Toolbar — Mobile (compact app bar + overflow menu) | 2s | Temel aksiyonlar + menü |
| 6.18 | Tüm 11 temanın görsel doğrulaması | 2s | Renkler doğru uygulanır |
| 6.19 | Tüm 4 dilin doğrulaması | 1s | Eksik key yok |
| **Toplam** | | **36s** | |

**Sprint 6 Doğrulama:** Müzik temaları crossfade ile çalışır. Ambience + SFX eşzamanlı. Soundpad desktop/tablet/mobile'da düzgün. PDF görüntüleme çalışır.

---

### Sprint 7 — Dual Screen + Mobile Adaptation (Gün 71-80) · `~0% — BAŞLANMADI`

**Hedef:** İkinci ekran (desktop), screen share başlangıcı (mobile), tam responsive polish.

| # | Task | Tahmin | Kabul Kriterleri |
|---|---|---|---|
| 7.1 | `desktop_multi_window` entegrasyonu + multi-window routing | 3s | İkinci pencere açılır |
| 7.2 | `PlayerWindowApp` — 5-sayfa IndexedStack | 3s | Images, BattleMap, Black, Stats, PDF |
| 7.3 | `ProjectionNotifier` — state management | 2s | showImages/showBattleMap/toggleBlack/showStats/showPdf |
| 7.4 | Pencereler arası state sync (invokeMethod) | 3s | DM → Player state anlık güncellenir |
| 7.5 | `BattleMapBridgeService` (combat → player routing) | 2s | Fog, annotation, token sync |
| 7.6 | `ScreenTab` — DM kontrol paneli | 3s | Mode switch, image layout, projection list |
| 7.7 | İkinci monitör otomatik tespit (`screen_retriever`) | 1s | 2. monitörde tam ekran açılır |
| 7.8 | Tablet: Split screen / PiP player mode | 3s | iPadOS + Android tablet split |
| 7.9 | Mobile: WebRTC P2P altyapı (flutter_webrtc) | 4s | Peer bağlantı kurulur |
| 7.10 | Mobile: Screen share — Mod A (rendered stream, 15 FPS) | 4s | DM projection → Player stream |
| 7.11 | Mobile: Screen share — oda kodu + bağlantı UI | 2s | 6-char kod, QR code seçeneği |
| 7.12 | Mobile: Player view (tam ekran, stream alımı) | 2s | Gelen frame gösterilir |
| 7.13 | Battle map touch gesture optimization | 2s | Pinch zoom, two-finger pan |
| 7.14 | Responsive final polish (tüm ekranlar) | 3s | Phone/tablet/desktop breakpoint'lar |
| **Toplam** | | **37s** | |

**Sprint 7 Doğrulama:** Desktop'ta ikinci pencere çalışır, fog sync olur. Mobile'da screen share bağlantı kurulur ve content stream edilir. Tüm ekranlar 3 breakpoint'ta düzgün.

---

### Sprint 8 — API Integration + Library (Gün 81-90) · `~0% — BAŞLANMADI`

**Hedef:** D&D API, import, library cache.

| # | Task | Tahmin | Kabul Kriterleri |
|---|---|---|---|
| 8.1 | `BaseApiSource` abstract class | 1s | Abstract interface tanımlı |
| 8.2 | `Dnd5eApiSource` (Dio + cache interceptor) | 3s | API çağrıları çalışır |
| 8.3 | `Open5eApiSource` | 2s | Open5e sorgulama çalışır |
| 8.4 | `EntityParser` (API response → Entity) | 3s | Monster/Spell/Equipment parse |
| 8.5 | `LibraryCacheDataSource` (dosya tabanlı) | 2s | Cache yazma/okuma |
| 8.6 | `LibraryRepository` (search, fetch, cache) | 3s | Önce cache, sonra API |
| 8.7 | `ApiBrowserDialog` — Desktop (search + paginate + preview) | 4s | Kategori seçimi, arama, sayfalama |
| 8.8 | `ApiBrowserDialog` — Mobile (full-screen + search) | 2s | Tam ekran liste + arama |
| 8.9 | `BulkDownloaderDialog` (toplu indirme) | 3s | Batch download + progress |
| 8.10 | `ImportDialog` (çoklu kaynak) | 2s | API'den veya dosyadan import |
| 8.11 | Entity dependency resolution (Monster → Spells/Equipment auto-import) | 3s | Bağımlılıklar otomatik çekilir |
| 8.12 | Sidebar library toggle (offline cache arama) | 1s | Toggle ile cache sonuçları |
| 8.13 | API entegrasyon testleri | 2s | Mock API ile test |
| **Toplam** | | **31s** | |

**Sprint 8 Doğrulama:** Monster/Spell araması çalışır. Cache'leme doğru. Import + dependency resolution çalışır.

---

### Sprint 9 — Online: Foundation (Gün 91-100) · `~0% — BAŞLANMADI`

**Hedef:** Event sistemi, NetworkBridge, sunucu iskeleti.

| # | Task | Tahmin | Kabul Kriterleri |
|---|---|---|---|
| 9.1 | 24 event payload Freezed class'ları | 4s | Tüm tipler + fromJson/toJson |
| 9.2 | `EventEnvelope` Freezed class | 1s | UUID, timestamp, type, payload |
| 9.3 | `NetworkBridge` — connection state machine | 3s | DISCONNECTED→CONNECTING→CONNECTED→ERROR |
| 9.4 | `NetworkBridge` — event queuing + flush | 2s | Offline'da kuyruklar, bağlantıda gönderir |
| 9.5 | `AppEventBus` → `NetworkBridge` wiring | 2s | Online events otomatik forward |
| 9.6 | `SocketClient` (socket_io_client wrapper) | 3s | Connect, disconnect, event emit/listen |
| 9.7 | Connection status badge (status bar) | 1s | Renk: gri/turuncu/yeşil/kırmızı |
| 9.8 | Server: FastAPI + python-socketio ASGI skeleton | 4s | Health check endpoint çalışır |
| 9.9 | Server: PostgreSQL schema migration | 3s | Tüm tablolar oluşturulur |
| 9.10 | Server: JWT auth (register, login, refresh) | 4s | Token alım + yenileme |
| 9.11 | Server: Session create + join (6-char code) | 3s | DM session açar, player katılır |
| 9.12 | Server: Basic event relay (no filtering) | 3s | DM event → tüm participant'lara |
| 9.13 | Flutter: Auth UI (login/register dialog) | 2s | Giriş/kayıt formu |
| 9.14 | Flutter: Session create/join UI | 2s | Oda oluştur/katıl |
| **Toplam** | | **37s** | |

**Sprint 9 Doğrulama:** DM session oluşturur, player kod ile katılır, basit event relay çalışır.

---

### Sprint 10 — Online: Full Sync (Gün 101-110) · `~0% — BAŞLANMADI`

**Hedef:** Delta sync, reconnect, asset management, screen share gelişmiş.

| # | Task | Tahmin | Kabul Kriterleri |
|---|---|---|---|
| 10.1 | Server: Event log persistence (revision-based) | 3s | Event'ler sıralı kaydedilir |
| 10.2 | Server: Permission filtering (DM/Player/Observer) | 3s | private_dm event'ler filtrelenir |
| 10.3 | Server: Snapshot endpoint (current state) | 3s | Player join'de tam state |
| 10.4 | Server: Delta resync (revision-based) | 3s | < 200 event → delta, > 200 → snapshot |
| 10.5 | Flutter: Reconnect state machine | 2s | Bağlantı kopunca auto-reconnect |
| 10.6 | Flutter: Delta apply + conflict resolution (last-write-wins) | 3s | Event'ler UI'ya uygulanır |
| 10.7 | Server: Asset upload (MinIO + signed URL) | 3s | Görsel/PDF yükleme |
| 10.8 | Flutter: Asset upload/download | 2s | DM asset yükler, player indirir |
| 10.9 | Server: Rate limiting (DM 30/s, Player 5/s) | 1s | Aşırı event throttle edilir |
| 10.10 | Flutter: Client-side debounce (fog 200ms, mindmap 100ms) | 1s | High-freq event'ler debounce |
| 10.11 | Mobile: Screen share Mod B (state sync, low bandwidth) | 4s | Projection state JSON olarak sync |
| 10.12 | Mobile: Screen share asset pre-transfer | 2s | Görseller önceden gönderilir |
| 10.13 | Audio state broadcast + player mirror | 2s | DM müzik değişince player'da da değişir |
| 10.14 | Online integration testleri | 3s | Full flow: create → join → sync → disconnect → reconnect |
| **Toplam** | | **35s** | |

**Sprint 10 Doğrulama:** Player disconnect/reconnect mid-session, tam state < 5 saniyede yüklenir. Permission filtering çalışır. Mobile screen share state sync ile çalışır.

---

### Sprint 11 — Online: Gameplay + Mobile Polish (Gün 111-120) · `~0% — BAŞLANMADI`

**Hedef:** Server-side dice, restricted entity view, mobile finalization.

| # | Task | Tahmin | Kabul Kriterleri |
|---|---|---|---|
| 11.1 | Server: Server-side dice roller | 3s | d4-d100, tüm katılımcılara broadcast |
| 11.2 | Flutter: Online dice roller UI (result broadcast) | 2s | Zar sonucu tüm ekranlarda görünür |
| 11.3 | Server: Event log query (player-filtered) | 2s | Player sadece kendi event'lerini görür |
| 11.4 | Server: Restricted entity view (field-level redaction) | 3s | HP → "Bloodied/Healthy", gizli alanlar filtrelenmiş |
| 11.5 | Flutter: Player entity card (restricted view) | 2s | Kısıtlı alanlar gösterilmez |
| 11.6 | Server: Real-time visibility toggle (DM controls) | 2s | DM anlık olarak alan paylaşabilir |
| 11.7 | Mobile: DM mode final polish | 3s | Combat tracker, entity, dice — mobile optimized |
| 11.8 | Mobile: Player mode final polish | 3s | Battle map view, entity cards, dice — mobile optimized |
| 11.9 | Mobile: Screen share reliability (WebRTC ICE handling) | 2s | NAT traversal, STUN/TURN |
| 11.10 | Mobile: Touch gesture final polish (battle map, mind map) | 2s | Pinch, pan, long-press tutarlı |
| 11.11 | Keyboard shortcuts (desktop) | 2s | Ctrl+E, Ctrl+S, Ctrl+Z, Delete |
| 11.12 | Accessibility basics (semantics, contrast) | 2s | Screen reader basics, kontrast oranları |
| 11.13 | Performance profiling (battle map, mind map, large campaigns) | 3s | 500+ entity, 100+ node, büyük harita |
| **Toplam** | | **31s** | |

**Sprint 11 Doğrulama:** Server-side dice tüm katılımcılara eşzamanlı. Restricted entity view çalışır. Mobile DM + Player modları kullanılabilir.

---

### Sprint 12 — Deployment, Testing & Beta (Gün 121-130) · `~0% — BAŞLANMADI`

**Hedef:** Production dağıtım, test suite, beta hazırlık.

| # | Task | Tahmin | Kabul Kriterleri |
|---|---|---|---|
| 12.1 | Unit test'ler: Domain entities + repositories | 4s | > 70% coverage core |
| 12.2 | Widget test'ler: Kritik ekranlar | 4s | NpcSheet, CombatTable, BattleMap, MindMap |
| 12.3 | Integration test'ler: Full combat flow | 2s | Create encounter → combat → save |
| 12.4 | Integration test'ler: Online flow | 2s | Create session → join → sync → dice |
| 12.5 | Integration test'ler: Campaign backward compat | 1s | Python .dat → Flutter okuma |
| 12.6 | Server: Docker Compose (Nginx, PG, Redis, MinIO, API) | 3s | `docker-compose up` ile çalışır |
| 12.7 | Server: TLS setup guide (Let's Encrypt) | 1s | HTTPS çalışır |
| 12.8 | Server: Backup/restore prosedürü | 1s | pg_dump + MinIO export |
| 12.9 | Server: Grafana monitoring dashboard | 2s | Latency, connections, errors |
| 12.10 | Windows packaging (MSIX + Inno Setup) | 2s | Windows installer çalışır |
| 12.11 | Linux packaging (AppImage + Flatpak) | 2s | AppImage çalışır |
| 12.12 | macOS packaging (DMG) | 2s | DMG oluşturulur ve çalışır |
| 12.13 | Android packaging (APK + Play Store hazırlık) | 2s | APK cihazda çalışır |
| 12.14 | iOS packaging (TestFlight) | 2s | TestFlight build çalışır |
| 12.15 | Backward compat testi (tüm mevcut kampanyalar) | 2s | 3+ farklı kampanya açılır |
| 12.16 | 11 temanın tüm platformlarda görsel QA | 2s | Screenshot karşılaştırma |
| 12.17 | 4 dilin tüm ekranlarda QA | 1s | Eksik/taşan string yok |
| 12.18 | Beta release notes + kullanıcı rehberi | 2s | Release dokümanı hazır |
| **Toplam** | | **37s** | |

**Sprint 12 Doğrulama:** Tüm test'ler geçer. 5 platformda (Win/Linux/macOS/Android/iOS) build çalışır. Server docker-compose ile ayağa kalkar. 3+ mevcut kampanya başarıyla açılır.

---

## 6. Definition of Done

### Kod Kalitesi
- [ ] `dart analyze` sıfır hata
- [ ] `dart format` uygulanmış
- [ ] Yeni `print()` çağrısı yok (tümü `logger` kullanır)
- [ ] Hardcoded string yok (tümü `L10n.of(context).xxx` kullanır)
- [ ] Yeni UI string'leri 4 dilde mevcut (EN, TR, DE, FR)
- [ ] Tema renkleri `DmToolColors` extension'dan alınır (hardcoded hex yok)

### Responsive
- [ ] Phone (< 600px) breakpoint'ta çalışır
- [ ] Tablet (600-1200px) breakpoint'ta çalışır
- [ ] Desktop (> 1200px) breakpoint'ta çalışır
- [ ] Landscape ve portrait orientation desteklenir (mobile/tablet)

### Testing
- [ ] Mevcut test'ler geçer (sıfır regression)
- [ ] Yeni `domain/` fonksiyonları için unit test
- [ ] Kritik widget'lar için widget test
- [ ] Coverage hedefleri:
  - Sprint 3 sonrası: >= 40%
  - Sprint 6 sonrası: >= 55%
  - Sprint 9 sonrası: >= 65%
  - Sprint 12 sonrası: >= 75%

### Platform
- [ ] Windows 10/11'de çalışır
- [ ] Ubuntu 22.04+ / Fedora 38+'da çalışır
- [ ] macOS 12+'da çalışır (Sprint 3'ten itibaren)
- [ ] Android 10+'da çalışır (Sprint 7'den itibaren)
- [ ] iOS 15+'da çalışır (Sprint 9'dan itibaren)

### Review
- [ ] 100+ LOC değişiklik → code review
- [ ] Kabul kriterleri doğrulanmış
- [ ] Sprint retrospektif notları yazılmış

---

## 7. KPI ve Performans Hedefleri

### Teknik KPI'lar

| Metrik | Hedef | Ölçüm |
|---|---|---|
| Kampanya açılma süresi (500 entity) | < 2 saniye | Profiler |
| Battle map render (4K harita + 20 token) | 60 FPS | DevTools |
| Mind map render (100 node, LOD geçişi) | 60 FPS | DevTools |
| Tema değiştirme | < 200ms | Stopwatch |
| MsgPack save (500 entity kampanya) | < 500ms | Stopwatch |
| İkinci pencere açılma (desktop) | < 1 saniye | Manual |
| Screen share latency (mobile, P2P) | < 200ms | RTCStats |
| Online event latency (DM→Player, P95) | < 120ms | Server metrics |
| Reconnect + delta resync | < 5 saniye | Server metrics |
| APK boyutu | < 50 MB | Build output |
| Windows installer boyutu | < 80 MB | Build output |

### Ürün KPI'ları (Beta)

| KPI | Hedef |
|---|---|
| Beta kullanıcı başına haftalık session | >= 2 |
| Player join sürtünmesi (kod → bağlı) | < 60 saniye |
| DM memnuniyet skoru | >= 4.0 / 5.0 |
| P1 bug oranı (session başına) | 0 |
| Mevcut kampanya uyumluluk oranı | 100% |
| Mobile kullanılabilirlik skoru (SUS) | >= 70 |

---

## 8. Risk Yönetimi

### R1: desktop_multi_window Paket Stabilitesi

**Olasılık:** Orta | **Etki:** Yüksek

**Risk:** `desktop_multi_window` paketi aktif olarak geliştirilmiyor veya platform-specific bug'lar içeriyor.

**Azaltma:**
- Sprint 7'nin ilk gününde proof-of-concept test
- Yedek plan: Aynı pencere içinde split view (SplitView widget)
- Windows/Linux/macOS'ta ayrı ayrı test

### R2: just_audio Desktop Desteği

**Olasılık:** Düşük | **Etki:** Yüksek

**Risk:** `just_audio` desktop platformlarında stabil çalışmayabilir veya crossfade desteği yetersiz olabilir.

**Azaltma:**
- Sprint 6 başında audio PoC
- Yedek: `audioplayers` paketi veya platform-specific native audio bridge
- Crossfade yerine hard switch fallback

### R3: MsgPack Backward Compat

**Olasılık:** Düşük | **Etki:** Kritik

**Risk:** Python msgpack ve Dart msgpack_dart arasında format farklılıkları olabilir.

**Azaltma:**
- Sprint 0'da ilk test (Task 0.9)
- 3+ farklı gerçek kampanya dosyasıyla test
- Fallback: JSON okuma desteği (mevcut Python app JSON de destekliyor)

### R4: Mobile Battle Map Performansı

**Olasılık:** Orta | **Etki:** Orta

**Risk:** Büyük battle map (4K+) mobile cihazlarda yavaş render olabilir.

**Azaltma:**
- Tile-based rendering (sadece görünür bölge)
- Mobile'da düşük çözünürlük fallback
- Fog ve annotation'lar düşük çözünürlükte render

### R5: WebRTC Mobile Screen Share Güvenilirliği

**Olasılık:** Orta | **Etki:** Orta

**Risk:** NAT traversal sorunları, yüksek latency, bant genişliği.

**Azaltma:**
- STUN + TURN server kullan (coturn)
- Mod A (rendered stream) baseline olarak her zaman çalışır
- Fallback: Online server üzerinden event-based sync (Mod B)
- Adaptive frame rate (WiFi'de 30 FPS, LTE'de 10 FPS)

### R6: Flutter Desktop Widget Yeterliliği

**Olasılık:** Düşük | **Etki:** Orta

**Risk:** Bazı PyQt6 widget'ların Flutter karşılığı yeterince olgun olmayabilir (QGraphicsScene, QSplitter).

**Azaltma:**
- CustomPainter QGraphicsScene'in yerini alır (tam kontrol)
- `multi_split_view` paketi splitter için yeterli
- Eksik widget: Custom widget yaz (Flutter'ın widget sistemi güçlü)

### R7: App Store / Play Store Ret Riski

**Olasılık:** Düşük | **Etki:** Orta

**Risk:** D&D referansları telif/marka sorununa yol açabilir.

**Azaltma:**
- Yalnızca SRD (OGL) içerik kullan
- D&D Beyond entegrasyonu → kullanıcının kendi hesabı
- Uygulama adında "D&D" veya "Dungeons & Dragons" kullanma
- "TTRPG Dungeon Master Tool" gibi jenerik isimlendirme

---

## Sprint Özet Takvimi

```
Sprint 0  ████████████ Foundation + Config + Themes + i18n
Sprint 1  ████████████ Entity Core (CRUD + Sidebar + NpcSheet basic)
Sprint 2  ████████████ Entity Advanced (Markdown + Spells + Actions + Import)
Sprint 3  ████████████ Session + Combat Tracker + Dice
Sprint 4  ████████████ Battle Map (6 katman + araçlar + fog)
Sprint 5  ████████████ Mind Map + World Map
Sprint 6  ████████████ Soundpad + PDF + UI Polish
Sprint 7  ████████████ Dual Screen + Screen Share + Mobile Responsive
Sprint 8  ████████████ API Integration + Library
Sprint 9  ████████████ Online: Auth + Session + Basic Relay
Sprint 10 ████████████ Online: Full Sync + Reconnect + Assets
Sprint 11 ████████████ Online: Gameplay + Mobile Polish
Sprint 12 ████████████ Deployment + Testing + Beta
─────────────────────────────────────────────────────
          Hafta 1-2    3-4    5-6    7-8    9-10   11-12
                       13-14  15-16  17-18  19-20  21-22  23-24
```

**Toplam: 12 Sprint = ~24 hafta (~6 ay)**

### Milestone'lar

| Milestone | Sprint | Tarih (tahmini) | Çıktı |
|---|---|---|---|
| **Alpha 1 — Offline Core** | Sprint 3 sonu | Hafta 6 | Entity + Combat çalışır |
| **Alpha 2 — Full Offline** | Sprint 6 sonu | Hafta 12 | Tüm offline özellikler |
| **Alpha 3 — Multi-Platform** | Sprint 7 sonu | Hafta 14 | Desktop dual screen + mobile |
| **Beta 1 — Online Preview** | Sprint 9 sonu | Hafta 18 | Basit online session |
| **Beta 2 — Online Full** | Sprint 11 sonu | Hafta 22 | Tam online + gameplay |
| **Release Candidate** | Sprint 12 sonu | Hafta 24 | Tüm platformlar, test'ler, deployment |
