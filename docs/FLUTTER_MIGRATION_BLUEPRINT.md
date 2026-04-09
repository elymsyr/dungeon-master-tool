# Flutter Migration Blueprint — Dungeon Master Tool v2.0

> **Kaynak Uygulama:** Python 3.10+ / PyQt6 (v0.8.4)
> **Hedef:** Flutter/Dart — Desktop öncelikli, mobile/tablet ikincil
> **Prensip:** UI ve çalışma mantığı birebir korunarak yeniden yazım
> **Doküman versiyonu:** v2.1 (2026-04-09)

---

## Yönetici Özeti

Bu doküman, mevcut Python/PyQt6 Dungeon Master Tool uygulamasının Flutter ile sıfırdan yazılması için kapsamlı bir teknik rehberdir. Mevcut uygulama ~124 Python dosyası, ~12.000+ LOC, 15 ana özellik, 11 tema, 4 dil desteği ve offline-first mimari ile olgun bir masaüstü uygulamasıdır. Flutter portu **2026-04-09** itibarıyla 167 Dart dosya / ~56K LOC / 13 test dosyası / 223 test seviyesinde, Sprint 0–4 tamamen ve Sprint 5'in büyük çoğunluğu bitmiş durumdadır.

Doküman şunları kapsar: sistem mimarisi, proje yapısı, veri modelleri, tüm interaktif sistemlerin (battle map, mind map, combat tracker, soundpad) Flutter karşılıkları, dual screen yönetimi, **Drift (SQLite) yerel depolama**, **Supabase + Cloudflare R2 hibrit online mimari**, API entegrasyonu, tema sistemi, lokalizasyon ve fazlı migrasyon stratejisi.

### v2.1 Mimari Güncellemeler (2026-04)

Bu sürüm üç büyük mimari kararı yansıtır:

| Alan | Eski (v1.0) | Yeni (v2.1) | Sebep |
|---|---|---|---|
| **Yerel storage** | MsgPack flat file (`worlds/{name}/data.dat`) | **Drift (SQLite)** — 11 tablo, schema v2 | Tip güvenliği, transactional yazma, Supabase mirror |
| **Online stack** | FastAPI + Postgres + Redis + MinIO + python-socketio (self-hosted) | **Supabase (Auth + Postgres + Realtime) + Cloudflare R2 + Workers** | Sıfır sunucu maliyeti, hazır JWT, zero egress |
| **Audio engine** | `just_audio` ^0.9 | **`flutter_soloud` ^3.1** | Cross-platform stabilite, gapless loop, built-in fade, CPU-side mixing |

MsgPack artık **yalnızca** `.dmt` paket import/export için kullanılır. `socket_io_client` planı tamamen iptal edildi; tüm online iletişim `supabase_flutter` SDK üzerinden Realtime Broadcast ile yapılır. Detay: `docs/ONLINE_REPORT.md` (v2.0 — Hibrit Online Teknik Rapor).

---

## İçindekiler

1. [Sistem Mimarisi](#1-sistem-mimarisi)
2. [Proje Yapısı](#2-proje-yapısı)
3. [Entity Veri Modelleri](#3-entity-veri-modelleri)
4. [Battle Map Sistemi](#4-battle-map-sistemi)
5. [Mind Map Sistemi](#5-mind-map-sistemi)
6. [Combat Tracker](#6-combat-tracker)
7. [Soundpad ve Audio Engine](#7-soundpad-ve-audio-engine)
8. [Dual Screen / Player Window](#8-dual-screen--player-window)
9. [Yerel Depolama](#9-yerel-depolama)
10. [Hibrit Online Mimari (Supabase + Cloudflare)](#10-hibrit-online-mimari-supabase--cloudflare)
11. [API Entegrasyonu](#11-api-entegrasyonu)
12. [Tema Sistemi](#12-tema-sistemi)
13. [Lokalizasyon](#13-lokalizasyon)
14. [PDF Viewer](#14-pdf-viewer)
15. [Platform Desteği ve Dağıtım](#15-platform-desteği-ve-dağıtım)
16. [Paket Listesi](#16-paket-listesi)
17. [Migration Fazları](#17-migration-fazları)

---

## 1. Sistem Mimarisi

### 1.1 Mimari Seçim: Clean Architecture + Riverpod

Mevcut Python uygulaması zaten katmanlı bir mimariye sahip:
- **Core katmanı** (`core/`): Pure Python, PyQt bağımlılığı yok — iş mantığı, repository'ler, event bus
- **UI katmanı** (`ui/`): PyQt6 widget'ları, presenter'lar
- **DataManager facade**: Tüm alt yöneticileri (entity, session, map, campaign, library, settings) koordine eder

Bu yapı Clean Architecture + Riverpod'a doğal olarak eşlenir.

### 1.2 Katman Eşleştirme Tablosu

| Mevcut Python | Flutter Karşılığı | Açıklama |
|---|---|---|
| `core/models.py` | `lib/domain/entities/` | Freezed data class'ları (15 entity tipi) |
| — | **`lib/data/database/tables/`** | **Drift table tanımları** — 11 tablo (campaigns, world_schemas, entities, sessions, encounters, combatants, combat_conditions, map_pins, timeline_pins, mind_map_nodes, mind_map_edges) |
| — | **`lib/data/database/daos/`** | **DAO sınıfları (5 adet)** — campaign, entity, session, map, mind_map |
| — | **`lib/data/database/app_database.dart`** | **Drift database root** + `MigrationStrategy` (schemaVersion=2) |
| `core/entity_repository.py` | `lib/domain/repositories/entity_repository.dart` (abstract — TODO) + Drift DAO entegrasyonu | Repository interface + concrete |
| `core/session_repository.py` | `lib/domain/repositories/session_repository.dart` + impl | Session CRUD |
| `core/map_data_manager.py` | `lib/domain/repositories/map_repository.dart` + impl (TODO) | Pin, timeline CRUD |
| `core/campaign_manager.py` | `lib/data/repositories/campaign_repository_impl.dart` | Kampanya I/O — Drift primary + MsgPack legacy fallback |
| `core/library_manager.py` | `lib/data/repositories/library_repository_impl.dart` | API cache yönetimi |
| `core/settings_manager.py` | `lib/data/repositories/settings_repository_impl.dart` | Ayarlar |
| `core/data_manager.py` (facade) | `lib/application/providers/` | Riverpod provider'lar |
| `core/event_bus.py` | Riverpod `ref.watch/listen` + **`AppEventBus`** service (`EventEnvelope` tabanlı) | Reaktif state + cross-cutting events + online forward |
| `core/network/bridge.py` | **`lib/data/network/network_bridge.dart`** + `no_op_network_bridge.dart` | Abstract bridge + offline default; Supabase impl Sprint 9'da |
| `core/network/events.py` (24 model) | **`lib/domain/entities/events/event_envelope.dart`** + `event_types.dart` (24 sabit, 17 online-forwarded) | Freezed event envelope + tip sabitleri |
| `core/audio/engine.py` | `lib/application/services/audio_engine.dart` (`flutter_soloud` tabanlı) | SoLoud handle pool, gapless loop, built-in fade |
| `core/audio/models.py` | `lib/domain/entities/audio/` | Theme, MusicState, Track, LoopNode |
| `ui/` (PyQt6 widgets) | `lib/presentation/` | Flutter widget'ları |
| `ui/presenters/` (MVP) | `lib/presentation/controllers/` | Riverpod AsyncNotifier/StateNotifier |

### 1.3 Neden Riverpod (BLoC Değil)

1. **DataManager facade pattern → Provider tree:** Mevcut DataManager, alt yöneticileri merkezi olarak koordine eder. Riverpod'un provider sistemi bu yapıyı doğal karşılar — her alt yönetici bir provider family olur.
2. **CRUD operasyonları için az boilerplate:** BLoC, her CRUD operasyonu için Event + State + Bloc sınıfı gerektirir. Riverpod'un `AsyncNotifier`'ı aynı tek yönlü veri akışını daha az ceremoniyle sağlar.
3. **Multi-window state paylaşımı:** Player window (ikinci ekran) aynı state'i paylaşmalı. Riverpod'un `ProviderContainer`'ı override'larla bu sorunu çözer — her iki pencere aynı container'dan okur.
4. **EventBus karşılığı:** `ref.listen` ve `ref.watch` çoğu cross-component iletişimi karşılar. Geriye kalan (NetworkBridge'e event forwarding) için hafif bir `StreamController` bus yeterlidir.

### 1.4 EventBus + EventEnvelope Mimarisi

Tüm cross-cutting event'ler tek wire format olan `EventEnvelope` üzerinden akar. Bu zarf hem offline (yalnızca local stream) hem de online (Supabase Realtime broadcast) tarafından kullanılır.

```dart
@freezed
class EventEnvelope with _$EventEnvelope {
  const factory EventEnvelope({
    required String eventId,        // UUID v4 (idempotency)
    required String eventType,      // "entity.created", "session.turn_advanced", ...
    String? sessionId,              // Online session ID (offline iken null)
    String? campaignId,
    required DateTime emittedAt,
    required Map<String, dynamic> payload,
  }) = _EventEnvelope;

  factory EventEnvelope.now(String type, Map<String, dynamic> payload) =>
      EventEnvelope(
        eventId: const Uuid().v4(),
        eventType: type,
        emittedAt: DateTime.now().toUtc(),
        payload: payload,
      );

  factory EventEnvelope.fromJson(Map<String, dynamic> json) =>
      _$EventEnvelopeFromJson(json);
}

typedef EventInterceptor = void Function(EventEnvelope event);

class AppEventBus {
  final _controller = StreamController<EventEnvelope>.broadcast();
  EventInterceptor? _networkInterceptor;  // Sprint 9'da SupabaseNetworkBridge kaydolur

  /// Tüm event'leri dinleyen stream — UI provider'ları + bridge bunu okur.
  Stream<EventEnvelope> get allEvents => _controller.stream;

  /// Lokal kaynaklı (Notifier'lardan gelen) event'i emit eder.
  /// Bridge interceptor yüklüyse, online forward da tetiklenir.
  void emit(EventEnvelope event) {
    _controller.add(event);
    _networkInterceptor?.call(event);
  }

  /// Remote'tan gelen event'i lokal'e enjekte eder (UI update için).
  /// Bridge yalnızca incoming event flow'da bunu çağırır.
  void injectRemote(EventEnvelope event) => _controller.add(event);

  void registerNetworkInterceptor(EventInterceptor? interceptor) {
    _networkInterceptor = interceptor;
  }

  void dispose() => _controller.close();
}

@riverpod
AppEventBus appEventBus(Ref ref) {
  final bus = AppEventBus();
  ref.onDispose(bus.dispose);
  return bus;
}
```

**Tip sabitleri** `lib/domain/entities/events/event_types.dart` içinde `EventTypes` sınıfı altında 24 sabit olarak tutulur (ör. `EventTypes.entityCreated`, `EventTypes.sessionTurnAdvanced`). `EventTypes.onlineEvents` set'i yalnızca network'e forward edilecek event tiplerini içerir (17 adet). Bu liste Python `core/network/events.py` `EVENT_PAYLOAD_MODELS` ile birebir uyumludur.

### 1.5 Provider Mimarisi

```dart
// Kampanya state — DataManager.data karşılığı
@riverpod
class CampaignNotifier extends _$CampaignNotifier {
  @override
  FutureOr<Campaign> build() async {
    return ref.read(campaignRepositoryProvider).loadActive();
  }

  Future<void> loadCampaign(String folder) async { ... }
  Future<void> createCampaign(String worldName) async { ... }
}

// Entity state — EntityRepository + DataManager.save_entity() karşılığı
@riverpod
class EntityNotifier extends _$EntityNotifier {
  @override
  FutureOr<Map<String, Entity>> build() {
    final campaign = ref.watch(campaignProvider);
    return campaign.valueOrNull?.entities ?? {};
  }

  Future<String> saveEntity(String? eid, Map<String, dynamic> data) async {
    final id = await ref.read(entityRepositoryProvider).save(eid, data);
    ref.read(appEventBusProvider).emit(AppEvent(
      eid == null ? 'entity.created' : 'entity.updated',
      {'entity_id': id},
    ));
    return id;
  }

  void deleteEntity(String eid) {
    ref.read(entityRepositoryProvider).delete(eid);
    ref.read(appEventBusProvider).emit(AppEvent('entity.deleted', {'entity_id': eid}));
  }
}
```

---

## 2. Proje Yapısı

```
dungeon_master_tool/
├── lib/
│   ├── main.dart                              # App entry, ProviderScope, multi-window routing
│   ├── app.dart                               # MaterialApp, router, theme wiring
│   │
│   ├── core/                                  # Paylaşılan yardımcılar
│   │   ├── constants.dart                     # APP_NAME, API_BASE_URL, VERSION
│   │   ├── config/
│   │   │   ├── app_paths.dart                 # config.py path resolution karşılığı
│   │   │   └── environment.dart               # Platform tespiti, data root
│   │   ├── extensions/                        # Dart extension method'ları
│   │   ├── errors/                            # Failure class'ları
│   │   └── utils/                             # UUID, tarih, string helper'ları
│   │
│   ├── domain/                                # Pure Dart — Flutter import'u YOK
│   │   ├── entities/
│   │   │   ├── campaign.dart                  # Campaign Freezed class
│   │   │   ├── entity.dart                    # Entity + EntitySchema (15 tip)
│   │   │   ├── session.dart                   # Session data
│   │   │   ├── encounter.dart                 # Encounter + Combatant (CombatModel karşılığı)
│   │   │   ├── mind_map.dart                  # MindMapNode, MindMapEdge, MindMapWorkspace
│   │   │   ├── map_data.dart                  # MapPin, TimelinePin, MapData
│   │   │   ├── audio/
│   │   │   │   └── audio_models.dart          # Theme, MusicState, Track, LoopNode
│   │   │   └── events/
│   │   │       ├── event_envelope.dart        # EventEnvelope Freezed class
│   │   │       └── event_payloads.dart        # 24 payload tipi (Freezed)
│   │   │
│   │   ├── repositories/                      # Abstract interface'ler
│   │   │   ├── entity_repository.dart
│   │   │   ├── session_repository.dart
│   │   │   ├── campaign_repository.dart
│   │   │   ├── map_repository.dart
│   │   │   ├── settings_repository.dart
│   │   │   └── library_repository.dart
│   │   │
│   │   └── usecases/                          # Tek sorumluluk komutları
│   │       ├── save_entity.dart
│   │       ├── fetch_from_api.dart
│   │       ├── import_entity_with_deps.dart
│   │       └── resolve_entity_dependencies.dart
│   │
│   ├── data/                                  # Implementasyon katmanı
│   │   ├── repositories/                      # Concrete repository implementasyonları
│   │   │   ├── entity_repository_impl.dart
│   │   │   ├── session_repository_impl.dart
│   │   │   ├── campaign_repository_impl.dart
│   │   │   ├── map_repository_impl.dart
│   │   │   ├── settings_repository_impl.dart
│   │   │   └── library_repository_impl.dart
│   │   │
│   │   ├── datasources/
│   │   │   ├── local/
│   │   │   │   ├── campaign_local_ds.dart     # MsgPack dosya I/O
│   │   │   │   ├── settings_local_ds.dart     # SharedPreferences / JSON
│   │   │   │   └── library_cache_ds.dart      # Yerel API cache
│   │   │   └── remote/
│   │   │       ├── dnd5e_api_source.dart      # D&D 5e SRD client
│   │   │       ├── open5e_api_source.dart     # Open5e client
│   │   │       ├── base_api_source.dart       # Abstract kaynak interface
│   │   │       └── entity_parser.dart         # API response → Entity dönüşümü
│   │   │
│   │   ├── models/                            # DTO / serialization modelleri
│   │   │   ├── entity_dto.dart
│   │   │   ├── campaign_dto.dart
│   │   │   └── legacy_maps.dart               # SCHEMA_MAP + PROPERTY_MAP (TR→EN uyumluluk)
│   │   │
│   │   └── network/
│   │       ├── network_bridge.dart            # WebSocket state machine
│   │       └── socket_client.dart             # socket_io_client wrapper
│   │
│   ├── application/                           # Uygulama servisleri + provider'lar
│   │   ├── providers/
│   │   │   ├── campaign_provider.dart         # Kampanya state
│   │   │   ├── entity_provider.dart           # Entity CRUD state
│   │   │   ├── session_provider.dart          # Session state
│   │   │   ├── combat_provider.dart           # Combat/encounter state
│   │   │   ├── mind_map_provider.dart         # Mind map state
│   │   │   ├── map_provider.dart              # World map state
│   │   │   ├── audio_provider.dart            # Audio engine state
│   │   │   ├── theme_provider.dart            # Tema seçimi
│   │   │   ├── locale_provider.dart           # Dil seçimi
│   │   │   ├── edit_mode_provider.dart        # Global edit lock
│   │   │   └── projection_provider.dart       # Player window state
│   │   │
│   │   └── services/
│   │       ├── event_bus.dart                 # StreamController-based pub/sub
│   │       ├── audio_engine.dart              # MusicBrain karşılığı
│   │       └── projection_service.dart        # Multi-window koordinasyonu
│   │
│   └── presentation/
│       ├── router/
│       │   └── app_router.dart                # go_router yapılandırması
│       │
│       ├── theme/
│       │   ├── app_theme.dart                 # ThemeData builder
│       │   ├── palette.dart                   # ThemeManager.PALETTES karşılığı (11 palet)
│       │   └── dm_tool_colors.dart            # ThemeExtension (80+ renk değişkeni)
│       │
│       ├── l10n/                              # Lokalizasyon ARB dosyaları
│       │   ├── app_en.arb
│       │   ├── app_tr.arb
│       │   ├── app_de.arb
│       │   └── app_fr.arb
│       │
│       ├── screens/
│       │   ├── main_screen.dart               # MainWindow karşılığı (tab host + toolbar)
│       │   ├── campaign_selector_screen.dart   # Kampanya seçim/oluşturma
│       │   │
│       │   ├── database/                      # DatabaseTab
│       │   │   ├── database_screen.dart       # Splitter: sidebar + card panel
│       │   │   ├── entity_sidebar.dart        # Sol panel: liste, arama, filtreler
│       │   │   └── npc_sheet/
│       │   │       ├── npc_sheet.dart          # Ana entity editor (8 tab host)
│       │   │       ├── stats_tab.dart          # STR/DEX/CON/INT/WIS/CHA + combat stats
│       │   │       ├── spells_tab.dart         # Spells listesi + manual add dialog
│       │   │       ├── actions_tab.dart        # Actions, reactions, legendary actions
│       │   │       ├── inventory_tab.dart      # Equipment + inventory
│       │   │       ├── description_tab.dart    # Markdown açıklama
│       │   │       ├── images_tab.dart         # Görsel galerisi
│       │   │       ├── docs_tab.dart           # PDF listesi + Project butonu
│       │   │       └── dm_notes_tab.dart       # DM özel notları
│       │   │
│       │   ├── mind_map/                      # MindMapTab
│       │   │   ├── mind_map_screen.dart       # Toolbar + canvas host
│       │   │   ├── mind_map_canvas.dart       # InteractiveViewer + CustomPainter
│       │   │   ├── mind_map_node.dart         # LOD-aware node widget
│       │   │   └── connection_painter.dart    # Bézier curve painter
│       │   │
│       │   ├── map/                           # MapTab (dünya haritası)
│       │   │   ├── map_screen.dart            # Harita + pin + timeline
│       │   │   ├── map_pin_widget.dart        # Renk kodlu pin
│       │   │   └── timeline_editor.dart       # Timeline event editor
│       │   │
│       │   ├── session/                       # SessionTab
│       │   │   ├── session_screen.dart        # Session yönetimi + combat host
│       │   │   ├── session_notes.dart         # Markdown not editörü
│       │   │   └── combat/
│       │   │       ├── combat_tracker.dart    # Orchestrator widget
│       │   │       ├── combat_controls.dart   # Round/turn kontrolleri
│       │   │       ├── combatant_list.dart    # Combatant ekleme UI
│       │   │       └── combat_table.dart      # Initiative tablosu + HP bar + condition
│       │   │
│       │   ├── battle_map/
│       │   │   ├── battle_map_screen.dart     # Toolbar + canvas host
│       │   │   ├── battle_map_canvas.dart     # 6-katmanlı Stack + InteractiveViewer
│       │   │   ├── layers/
│       │   │   │   ├── background_layer.dart  # Harita görseli
│       │   │   │   ├── grid_layer.dart        # Grid overlay
│       │   │   │   ├── draw_layer.dart        # Freehand çizim
│       │   │   │   ├── token_layer.dart       # Token widget'ları
│       │   │   │   ├── fog_layer.dart         # Fog of war (BlendMode.clear)
│       │   │   │   └── measurement_layer.dart # Ruler + circle overlay
│       │   │   └── tools/
│       │   │       ├── battle_map_tool.dart   # Abstract tool interface
│       │   │       ├── navigate_tool.dart
│       │   │       ├── ruler_tool.dart
│       │   │       ├── circle_tool.dart
│       │   │       ├── draw_tool.dart
│       │   │       └── fog_tool.dart          # FogAdd + FogErase
│       │   │
│       │   └── screen/                        # ScreenTab (DM kontrol paneli)
│       │       └── screen_tab.dart            # Projection mode switching
│       │
│       ├── widgets/                           # Yeniden kullanılabilir widget'lar
│       │   ├── markdown_editor.dart           # Dual-mode (edit/preview) + @mention
│       │   ├── image_gallery.dart             # Multi-image carousel
│       │   ├── image_viewer.dart              # Zoomable tek görsel
│       │   ├── pdf_viewer_widget.dart         # pdfrx wrapper
│       │   ├── soundpad_panel.dart            # Audio kontrol paneli
│       │   ├── projection_manager.dart        # Görsel sürükle-bırak + thumbnail
│       │   ├── hp_bar.dart                    # HP progress bar (renkli)
│       │   ├── condition_badge.dart           # Condition icon + duration
│       │   ├── entity_link_chip.dart          # @mention entity bağlantısı
│       │   └── dice_roller.dart               # d4-d100 zar atma
│       │
│       └── dialogs/
│           ├── api_browser_dialog.dart        # D&D API tarayıcı
│           ├── bulk_downloader_dialog.dart     # Toplu indirme
│           ├── import_dialog.dart             # Entity import
│           ├── entity_selector_dialog.dart     # Hızlı entity seçimi
│           ├── encounter_selector_dialog.dart  # Encounter seçimi
│           ├── theme_builder_dialog.dart       # Özel tema oluşturma
│           ├── timeline_entry_dialog.dart      # Timeline event düzenleme
│           └── manual_spell_dialog.dart        # Manuel spell ekleme
│
├── test/                                      # lib/ yapısını yansıtır
│   ├── domain/
│   ├── data/
│   ├── application/
│   └── presentation/
│
├── assets/
│   ├── soundpad/                              # Audio dosyaları (theme YAML + ses)
│   ├── images/                                # Uygulama ikonları
│   └── fonts/                                 # Özel fontlar (varsa)
│
├── pubspec.yaml
├── l10n.yaml                                  # Lokalizasyon yapılandırması
└── analysis_options.yaml                      # Lint kuralları
```

---

## 3. Schema-Driven Entity Sistemi

> **Temel Prensip:** Flutter uygulaması 1. günden itibaren schema-driven mimari ile inşa edilir. Mevcut 15 hardcoded entity tipi, "D&D 5e (Default)" world template'i olarak gömülü gelir. Kullanıcılar yeni kategori ve alan ekleyebilir, şablonları `.dmt-template` olarak dışa/içe aktarabilir.

Kaynak tasarım: `docs/pre-online/PRE_ONLINE_DEVELOPMENT_GUIDE.md` — Initiative B

### 3.1 WorldSchema — Üst Düzey Şema

Her kampanya bir `WorldSchema` taşır. Schema, entity kategorilerini, alan tanımlarını ve encounter layout'larını tanımlar.

```dart
@freezed
class WorldSchema with _$WorldSchema {
  const factory WorldSchema({
    required String schemaId,
    @Default('D&D 5e (Default)') String name,
    @Default('1.0.0') String version,
    String? baseSystem,                         // "dnd5e", "pathfinder", "gurps", null (custom)
    @Default('') String description,
    @Default([]) List<EntityCategorySchema> categories,
    @Default([]) List<EncounterLayout> encounterLayouts,
    @Default({}) Map<String, dynamic> metadata,
    required String createdAt,
    required String updatedAt,
  }) = _WorldSchema;

  factory WorldSchema.fromJson(Map<String, dynamic> json) => _$WorldSchemaFromJson(json);
}
```

### 3.2 EntityCategorySchema — Kategori Tanımı

Her entity tipi (NPC, Monster, Spell, vb.) bir `EntityCategorySchema` olarak tanımlanır. Kullanıcılar yeni kategoriler oluşturabilir (ör. Faction, Relic, Vehicle, Deity).

```dart
@freezed
class EntityCategorySchema with _$EntityCategorySchema {
  const factory EntityCategorySchema({
    required String categoryId,               // UUID, stabil tanımlayıcı
    required String schemaId,                 // Parent WorldSchema referansı
    required String name,                     // Gösterim adı (kullanıcı düzenleyebilir)
    required String slug,                     // Internal ID (oluşturulunca sabit, değişmez)
    @Default('') String icon,                 // İkon tanımlayıcı veya path
    @Default('#808080') String color,         // Hex renk (UI aksanları için)
    @Default(false) bool isBuiltin,           // true = varsayılan D&D 5e kategorisi
    @Default(false) bool isArchived,          // true = oluşturma UI'dan gizli
    @Default(0) int orderIndex,               // Sidebar/dialog sıralama
    @Default([]) List<FieldSchema> fields,    // Sıralı alan tanımları
    required String createdAt,
    required String updatedAt,
  }) = _EntityCategorySchema;

  factory EntityCategorySchema.fromJson(Map<String, dynamic> json) =>
      _$EntityCategorySchemaFromJson(json);
}
```

**Davranış kuralları:**
- Built-in kategoriler (`isBuiltin=true`) yeniden adlandırılabilir ve arşivlenebilir ama silinemez
- Custom kategoriler, referans eden entity yoksa tamamen silinebilir
- `slug` ilk `name`'den deterministic slugify ile üretilir, sonra asla değişmez
- Kategori isimleri bir world schema içinde benzersiz olmalı

### 3.3 FieldSchema — Alan Tanımı

Her alan zengin tip desteği, validation kuralları ve görünürlük kontrolü ile tanımlanır.

```dart
@freezed
class FieldSchema with _$FieldSchema {
  const factory FieldSchema({
    required String fieldId,                  // UUID
    required String categoryId,               // Parent kategori referansı
    required String fieldKey,                 // Internal key (auto-generated, immutable)
    required String label,                    // Gösterim etiketi (düzenlenebilir)
    required FieldType fieldType,             // Alan tipi enum
    @Default(false) bool required_,           // Zorunlu alan mı
    @Default(null) dynamic defaultValue,      // Yeni entity'ler için varsayılan değer
    @Default('') String placeholder,          // Boş alan placeholder
    @Default('') String helpText,             // Tooltip yardım metni
    @Default(FieldValidation()) FieldValidation validation,
    @Default(FieldVisibility.shared) FieldVisibility visibility,
    @Default(0) int orderIndex,               // Kategori içi sıralama
    @Default(false) bool isBuiltin,           // true = varsayılan alan
    required String createdAt,
    required String updatedAt,
  }) = _FieldSchema;

  factory FieldSchema.fromJson(Map<String, dynamic> json) => _$FieldSchemaFromJson(json);
}
```

### 3.4 FieldType — 16 Desteklenen Alan Tipi

```dart
enum FieldType {
  text,           // Tek satır metin (QLineEdit karşılığı)
  textarea,       // Çok satırlı metin
  markdown,       // MarkdownEditor ile zengin metin
  integer,        // Tam sayı
  float_,         // Ondalık sayı
  boolean_,       // Checkbox
  enum_,          // Dropdown (combo karşılığı) — önceden tanımlı seçenekler
  date,           // Tarih seçici
  image,          // Görsel dosya referansı
  file,           // Genel dosya referansı
  relation,       // Başka entity'ye referans (entity_select karşılığı)
  tagList,        // Metin etiketleri listesi
  statBlock,      // Ability score bloğu (STR/DEX/CON/INT/WIS/CHA — veya custom)
  combatStats,    // HP, AC, Speed, CR, XP, Initiative bloğu
  actionList,     // İsimli aksiyon listesi (traits, actions, reactions, legendary)
  spellList,      // Spell referansları listesi
}
```

**Mevcut Python → Flutter alan tipi eşleştirme:**

| Python widget_type | Flutter FieldType | Açıklama |
|---|---|---|
| `"text"` | `FieldType.text` | Tek satır metin |
| `"combo"` | `FieldType.enum_` | Dropdown, allowedValues |
| `"entity_select"` | `FieldType.relation` | Entity referansı, allowedTypes |

### 3.5 FieldValidation ve FieldVisibility

```dart
@freezed
class FieldValidation with _$FieldValidation {
  const factory FieldValidation({
    double? minValue,                           // Numeric tipler için
    double? maxValue,
    int? minLength,                             // Text tipler için
    int? maxLength,
    String? pattern,                            // Regex pattern (text)
    List<String>? allowedValues,                // enum tipi için seçenekler
    List<String>? allowedTypes,                 // relation tipi için (kategori slug'ları)
    List<String>? allowedExtensions,            // file/image tipi için
    String? customMessage,                      // Hata mesajı override
  }) = _FieldValidation;

  factory FieldValidation.fromJson(Map<String, dynamic> json) =>
      _$FieldValidationFromJson(json);
}

enum FieldVisibility {
  shared,         // DM ve player'lar görebilir (online modda)
  dmOnly,         // Sadece DM görebilir
  private_,       // Sadece entity sahibi görebilir (gelecekte)
}
```

### 3.6 EncounterLayout — Configurable Combat Tracker

Mevcut hardcoded combat tracker kolonları (name, HP, AC, initiative, conditions) yerine, schema-driven konfigürasyon:

```dart
@freezed
class EncounterLayout with _$EncounterLayout {
  const factory EncounterLayout({
    required String layoutId,
    required String schemaId,
    @Default('Standard D&D') String name,
    @Default([]) List<EncounterColumn> columns,
    @Default([]) List<SortRule> sortRules,
    @Default([]) List<DerivedStat> derivedStats,
  }) = _EncounterLayout;

  factory EncounterLayout.fromJson(Map<String, dynamic> json) =>
      _$EncounterLayoutFromJson(json);
}

@freezed
class EncounterColumn with _$EncounterColumn {
  const factory EncounterColumn({
    required String fieldKey,             // FieldSchema.fieldKey veya built-in key
    required String displayLabel,
    @Default(0) int width,                // 0 = auto
    @Default(false) bool isEditable,      // Combat sırasında düzenlenebilir mi
    @Default('{value}') String formatTemplate,
  }) = _EncounterColumn;

  factory EncounterColumn.fromJson(Map<String, dynamic> json) =>
      _$EncounterColumnFromJson(json);
}

@freezed
class SortRule with _$SortRule {
  const factory SortRule({
    required String fieldKey,
    @Default('desc') String direction,
    @Default(0) int priority,
  }) = _SortRule;

  factory SortRule.fromJson(Map<String, dynamic> json) => _$SortRuleFromJson(json);
}
```

**Built-in encounter kolonları** (schema'dan bağımsız, her zaman mevcut):
- `name` — Entity adı (her zaman ilk)
- `initiative` — Initiative roll (varsayılan sıralama kolonu)
- `hp` / `max_hp` — Hit points
- `ac` — Armor class
- `conditions` — Aktif condition listesi

### 3.7 Entity Veri Modeli — Schema-Driven

Entity artık hardcoded alanlar taşımaz. Tüm veriler `fields` map'inde, schema'ya göre saklanır:

```dart
@freezed
class Entity with _$Entity {
  const factory Entity({
    required String id,
    @Default('New Record') String name,
    required String categorySlug,                    // WorldSchema'daki kategori slug'ı
    @Default('') String source,
    @Default('') String description,
    @Default([]) List<String> images,
    @Default('') String imagePath,
    @Default([]) List<String> tags,
    @Default('') String dmNotes,
    @Default([]) List<String> pdfs,
    String? locationId,

    /// Schema-driven alanlar.
    /// Key = FieldSchema.fieldKey, Value = alan değeri.
    /// FieldType'a göre value tipi değişir:
    ///   text/textarea/markdown → String
    ///   integer → int
    ///   float → double
    ///   boolean → bool
    ///   enum → String (seçili değer)
    ///   relation → String (hedef entity ID)
    ///   tagList → List<String>
    ///   statBlock → Map<String, int> (ör. {"STR": 10, "DEX": 14, ...})
    ///   combatStats → Map<String, String> (ör. {"hp": "45", "ac": "16", ...})
    ///   actionList → List<Map<String, String>> (ör. [{"name": "...", "desc": "..."}])
    ///   spellList → List<String> (spell entity ID'leri)
    ///   image → String (dosya path)
    ///   file → String (dosya path)
    ///   date → String (ISO 8601)
    @Default({}) Map<String, dynamic> fields,
  }) = _Entity;

  factory Entity.fromJson(Map<String, dynamic> json) => _$EntityFromJson(json);
}
```

### 3.8 Default D&D 5e Schema — Gömülü Varsayılan

Mevcut 15 entity tipi, uygulama ile birlikte gelen "D&D 5e (Default)" template olarak tanımlanır. Yeni kampanya oluşturulduğunda bu schema otomatik uygulanır.

```dart
/// Mevcut Python ENTITY_SCHEMAS + get_default_entity_structure() yapısından
/// otomatik üretilen varsayılan D&D 5e WorldSchema.
WorldSchema generateDefaultDnd5eSchema() {
  final now = DateTime.now().toUtc().toIso8601String();
  final schemaId = const Uuid().v4();

  return WorldSchema(
    schemaId: schemaId,
    name: 'D&D 5e (Default)',
    version: '1.0.0',
    baseSystem: 'dnd5e',
    description: 'Built-in D&D 5e entity model with 15 categories.',
    categories: _buildDefaultCategories(schemaId, now),
    encounterLayouts: [_buildDefaultEncounterLayout(schemaId)],
    createdAt: now,
    updatedAt: now,
  );
}
```

**Varsayılan 15 Kategori ve Alanları:**

| Kategori | Slug | Renk | Özel Alanlar | Ortak Alanlar |
|---|---|---|---|---|
| **NPC** | `npc` | `#ff9800` | Race(relation), Class(relation), Level(text), Attitude(enum), Location(relation) | statBlock, combatStats, actionList, spellList, markdown description, images, pdfs, dmNotes |
| **Monster** | `monster` | `#d32f2f` | CR(text), Attack Type(text) | statBlock, combatStats, actionList, spellList, markdown description, images, pdfs, dmNotes |
| **Player** | `player` | `#4caf50` | Class(relation), Race(relation), Level(text) | statBlock, combatStats, actionList, spellList, markdown description, images, pdfs, dmNotes |
| **Spell** | `spell` | `#7b1fa2` | Level(enum:Cantrip-9), School(text), Casting Time(text), Range(text), Duration(text), Components(text) | markdown description |
| **Equipment** | `equipment` | `#795548` | Category(text), Rarity(text), Attunement(text), Cost(text), Weight(text), Damage Dice(text), Damage Type(text), Range(text), AC(text), Requirements(text), Properties(text) | markdown description |
| **Class** | `class` | `#1976d2` | Hit Die(text), Main Stats(text), Proficiencies(text) | markdown description |
| **Race** | `race` | `#00897b` | Speed(text), Size(enum:Small/Medium/Large), Alignment(text), Language(text) | markdown description |
| **Location** | `location` | `#2e7d32` | Danger Level(enum:Safe/Low/Medium/High), Environment(text) | markdown description, images |
| **Quest** | `quest` | `#f57c00` | Status(enum:Not Started/Active/Completed), Giver(text), Reward(text) | markdown description |
| **Lore** | `lore` | `#5c6bc0` | Category(enum:History/Geography/Religion/Culture/Other), Secret Info(text) | markdown description |
| **Status Effect** | `status-effect` | `#e91e63` | Duration Turns(text), Effect Type(enum:Buff/Debuff/Condition), Linked Condition(relation) | markdown description |
| **Feat** | `feat` | `#ff7043` | Prerequisite(text) | markdown description |
| **Background** | `background` | `#8d6e63` | Skill Proficiencies(text), Tool Proficiencies(text), Languages(text), Equipment(text) | markdown description |
| **Plane** | `plane` | `#26c6da` | Type(text) | markdown description |
| **Condition** | `condition` | `#ab47bc` | Effects(text) | markdown description |

**Ortak alanlar (NPC/Monster/Player'a özel olarak schema'da tanımlanır):**
- `statBlock` → `{"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10}`
- `combatStats` → `{"hp": "", "max_hp": "", "ac": "", "speed": "", "cr": "", "xp": "", "initiative": ""}`
- `actionList` (x4) → traits, actions, reactions, legendary_actions
- `spellList` → linked spell entity ID'leri

### 3.9 FieldWidgetFactory — Schema-Driven UI Rendering

Entity card UI, hardcoded widget'lar yerine `FieldWidgetFactory` pattern ile render edilir:

```dart
class FieldWidgetFactory {
  static const Map<FieldType, Widget Function(FieldSchema, dynamic, WidgetRef)> _widgetMap = {
    FieldType.text: TextFieldWidget.new,
    FieldType.textarea: TextAreaFieldWidget.new,
    FieldType.markdown: MarkdownFieldWidget.new,
    FieldType.integer: IntegerFieldWidget.new,
    FieldType.float_: FloatFieldWidget.new,
    FieldType.boolean_: BooleanFieldWidget.new,
    FieldType.enum_: EnumFieldWidget.new,
    FieldType.date: DateFieldWidget.new,
    FieldType.image: ImageFieldWidget.new,
    FieldType.file: FileFieldWidget.new,
    FieldType.relation: RelationFieldWidget.new,
    FieldType.tagList: TagListFieldWidget.new,
    FieldType.statBlock: StatBlockFieldWidget.new,
    FieldType.combatStats: CombatStatsFieldWidget.new,
    FieldType.actionList: ActionListFieldWidget.new,
    FieldType.spellList: SpellListFieldWidget.new,
  };

  static Widget create(FieldSchema schema, dynamic value, WidgetRef ref) {
    final builder = _widgetMap[schema.fieldType];
    if (builder == null) return FallbackTextWidget(schema: schema, value: value);
    return builder(schema, value, ref);
  }
}
```

**Her field widget:**
1. Constructor'da `FieldSchema` + mevcut değer alır
2. Uygun input kontrolünü render eder
3. Değer değişince `onChanged` callback ile bildirir
4. Schema'dan validation kurallarını uygular, hata mesajı gösterir
5. Edit mode'a uyar (readOnly toggle)
6. `FieldVisibility`'ye göre DM-only alanları gizler/gösterir

### 3.10 Entity Card Rendering Akışı

**Mevcut Python (hardcoded):**
```
NpcSheet.load_entity(entity_data)
  → Hardcoded: QLineEdit for "name"
  → Hardcoded: create combo for "attitude"
  → Hardcoded: ENTITY_SCHEMAS[type]'dan text/combo/entity_select
  → Hardcoded: stat block widget
  → Hardcoded: action list widgets
```

**Yeni Flutter (schema-driven):**
```
EntityCard.build(entity, categorySchema)
  → For each field in categorySchema.fields (ordered by orderIndex):
       → FieldWidgetFactory.create(field, entity.fields[field.fieldKey])
       → Widget render edilir
       → onChange → entity.fields[field.fieldKey] güncellenir
```

```dart
class EntityCard extends ConsumerWidget {
  final Entity entity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schema = ref.watch(worldSchemaProvider);
    final category = schema.categories.firstWhere(
      (c) => c.slug == entity.categorySlug,
    );

    return SingleChildScrollView(
      child: Column(
        children: [
          // Üst: Görsel + metadata (name, category, source, tags)
          _EntityHeader(entity: entity, category: category),

          // Description (markdown)
          _DescriptionSection(entity: entity),

          // Schema-driven dynamic fields
          for (final field in category.fields.sortedBy((f) => f.orderIndex))
            FieldWidgetFactory.create(
              field,
              entity.fields[field.fieldKey],
              ref,
            ),

          // DM Notes
          _DmNotesSection(entity: entity),
        ],
      ),
    );
  }
}
```

### 3.11 Template Studio — Şema Düzenleme UI

Kullanıcıların world schema'yı düzenleyebildiği dialog:

```
Template Studio Dialog (900x700 min)
┌──────────────┬───────────────────────────────────────┐
│ Categories   │ Category: NPC                          │
│ ┌──────────┐ │ ┌─────────────────────────────────────┐│
│ │ NPC      │ │ │ Name: [NPC          ]  Icon: [🧙]  ││
│ │ Monster  │ │ │ Color: [#ff9800]                    ││
│ │ Spell    │ │ ├─────────────────────────────────────┤│
│ │ Equip.   │ │ │ Fields:                             ││
│ │ Class    │ │ │ # | Label     | Type     | Req | V  ││
│ │ Race     │ │ │ 1 | Race      | relation | ✗   | S  ││
│ │ Location │ │ │ 2 | Class     | relation | ✗   | S  ││
│ │ Player   │ │ │ 3 | Level     | text     | ✗   | S  ││
│ │ Quest    │ │ │ 4 | Attitude  | enum     | ✗   | S  ││
│ │ ...      │ │ │ 5 | Stats     | statBlock| ✗   | S  ││
│ ├──────────┤ │ │ [+ Add Field]                       ││
│ │[+New Cat]│ │ ├─────────────────────────────────────┤│
│ │[Archive] │ │ │ Field Editor (expanded):             ││
│ │[Delete]  │ │ │ Label: [Race]  Key: race (readonly) ││
│ └──────────┘ │ │ Type: [relation ▾]  Required: [ ]   ││
│              │ │ Allowed types: [Race]                ││
│              │ │ Visibility: [Shared ▾]               ││
│              │ └─────────────────────────────────────┘│
│              │ [Save] [Export Template] [Import]       │
└──────────────┴───────────────────────────────────────┘
```

### 3.12 Template Paketleme — .dmt-template

World template'ler `.dmt-template` ZIP arşivleri olarak dışa/içe aktarılır:

```
my-template.dmt-template (ZIP)
├── manifest.json               # Versiyon, yazar, uyumluluk, checksum
├── schema/
│   ├── world_schema.json       # Root WorldSchema
│   ├── categories/
│   │   ├── npc.json
│   │   ├── monster.json
│   │   ├── custom_faction.json # Kullanıcı-tanımlı tipler
│   │   └── ...
│   └── encounter_layouts/
│       └── default.json
├── assets/
│   ├── icons/                  # Kategori ikonları
│   └── previews/               # Template önizleme görseli
└── README.md (opsiyonel)
```

### 3.13 Legacy Kampanya Migration

Mevcut Python kampanyaları (`world_schema` alanı olmayan) otomatik migrate edilir:

1. **Tespit:** `data["world_schema"]` anahtarı yoksa migration tetiklenir
2. **Backup:** `data.dat` → `data.dat.pre-schema-migration.bak`
3. **Schema üret:** `generateDefaultDnd5eSchema()` ile varsayılan D&D 5e schema
4. **Entity'leri map'le:** Her entity'nin `type` → category slug, `attributes` → `fields`
5. **Türkçe legacy:** `SCHEMA_MAP` + `PROPERTY_MAP` ile TR→EN dönüşüm
6. **Kaydet:** Güncellenmiş veri + `world_schema` ile disk'e yaz
7. **Doğrula:** Yeniden yükle, veri kaybı olmadığını kontrol et

```dart
// lib/data/models/legacy_maps.dart
const Map<String, String> schemaMap = {
  'Canavar': 'monster', 'Büyü (Spell)': 'spell',
  'Eşya (Equipment)': 'equipment', 'Sınıf (Class)': 'class',
  'Irk (Race)': 'race', 'Mekan': 'location', 'Oyuncu': 'player',
  'Görev': 'quest', 'Lore': 'lore', 'Durum Etkisi': 'status-effect',
  'Feat': 'feat', 'Background': 'background', 'Plane': 'plane',
  'Condition': 'condition',
};

const Map<String, String> propertyMap = {
  'Irk': 'race', 'Sınıf': 'class_', 'Seviye': 'level',
  'Tavır': 'attitude', 'Konum': 'location',
  // ... tüm 30+ mapping
};
```

### 3.14 Proje Yapısı Güncellemesi (Schema Dosyaları)

```
lib/domain/entities/schema/
├── world_schema.dart              # WorldSchema Freezed class
├── entity_category_schema.dart    # EntityCategorySchema Freezed class
├── field_schema.dart              # FieldSchema + FieldType + FieldValidation + FieldVisibility
├── encounter_layout.dart          # EncounterLayout + EncounterColumn + SortRule + DerivedStat
├── default_dnd5e_schema.dart      # generateDefaultDnd5eSchema() fonksiyonu
└── template_io.dart               # .dmt-template ZIP import/export

lib/data/schema/
├── schema_migration.dart          # Legacy kampanya → schema migration
└── legacy_maps.dart               # SCHEMA_MAP + PROPERTY_MAP (TR→EN)

lib/presentation/widgets/field_widgets/
├── field_widget_factory.dart      # FieldWidgetFactory
├── text_field_widget.dart         # FieldType.text
├── textarea_field_widget.dart     # FieldType.textarea
├── markdown_field_widget.dart     # FieldType.markdown
├── integer_field_widget.dart      # FieldType.integer
├── float_field_widget.dart        # FieldType.float_
├── boolean_field_widget.dart      # FieldType.boolean_
├── enum_field_widget.dart         # FieldType.enum_ (dropdown)
├── date_field_widget.dart         # FieldType.date
├── image_field_widget.dart        # FieldType.image
├── file_field_widget.dart         # FieldType.file
├── relation_field_widget.dart     # FieldType.relation (entity selector)
├── tag_list_field_widget.dart     # FieldType.tagList
├── stat_block_field_widget.dart   # FieldType.statBlock (ability scores)
├── combat_stats_field_widget.dart # FieldType.combatStats (HP/AC/Speed/...)
├── action_list_field_widget.dart  # FieldType.actionList
├── spell_list_field_widget.dart   # FieldType.spellList
└── fallback_text_widget.dart      # Bilinmeyen tip fallback

lib/presentation/dialogs/
├── template_studio_dialog.dart    # Template Studio (schema düzenleme)
└── encounter_column_dialog.dart   # Combat tracker kolon konfigürasyonu
```

---

## 4. Battle Map Sistemi

### 4.1 Mevcut Yapı

Kaynak: `ui/windows/battle_map_window.py` (1563 satır)

Mevcut yapı QGraphicsScene üzerinde 6 katmanlı bir sistem kullanır. Her katman farklı Z-value'da bir QGraphicsItem'dır.

### 4.2 Flutter Mimarisi: 6 Katmanlı CustomPainter + InteractiveViewer

```dart
class BattleMapCanvas extends ConsumerStatefulWidget {
  final bool isDmView; // true = DM, false = Player (read-only)
  const BattleMapCanvas({required this.isDmView, super.key});

  @override
  ConsumerState<BattleMapCanvas> createState() => _BattleMapCanvasState();
}

class _BattleMapCanvasState extends ConsumerState<BattleMapCanvas> {
  final TransformationController _transformController = TransformationController();
  BattleMapTool? _activeTool;

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(battleMapProvider);
    final palette = Theme.of(context).extension<DmToolColors>()!;

    return Listener(
      onPointerDown: (e) => _activeTool?.onPointerDown(e),
      onPointerMove: (e) => _activeTool?.onPointerMove(e),
      onPointerUp: (e) => _activeTool?.onPointerUp(e),
      child: InteractiveViewer.builder(
        transformationController: _transformController,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        minScale: 0.1,
        maxScale: 5.0,
        builder: (context, viewport) {
          return SizedBox(
            width: mapState.mapWidth,
            height: mapState.mapHeight,
            child: Stack(
              children: [
                // Katman 1-3, 5-6: CustomPaint
                CustomPaint(
                  painter: BattleMapPainter(
                    backgroundImage: mapState.backgroundImage,
                    gridState: mapState.gridState,
                    drawPaths: mapState.drawPaths,
                    fogData: mapState.fogData,
                    rulers: mapState.rulers,
                    circles: mapState.circles,
                    activeMeasurement: mapState.activeMeasurement,
                    palette: palette,
                    zoom: _transformController.value.getMaxScaleOnAxis(),
                  ),
                  size: Size(mapState.mapWidth, mapState.mapHeight),
                ),
                // Katman 4: Token widget'ları (interaktif)
                ...mapState.tokens.map((token) => _buildTokenWidget(token, palette)),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

### 4.3 BattleMapPainter — Katmanlı Rendering

```dart
class BattleMapPainter extends CustomPainter {
  // ... constructor parameters ...

  @override
  void paint(Canvas canvas, Size size) {
    // KATMAN 1: Background (Z=-100)
    _paintBackground(canvas, size);

    // KATMAN 2: Grid Overlay (Z=50)
    if (gridState.visible && zoom >= 0.15) {
      _paintGrid(canvas, size);
    }

    // KATMAN 3: Freehand Drawing (Z=75)
    _paintDrawings(canvas, size);

    // KATMAN 5: Fog of War (Z=200)
    _paintFog(canvas, size);

    // KATMAN 6: Rulers & Circles (Z=150)
    _paintMeasurements(canvas, size);
  }
}
```

### 4.4 Fog of War — BlendMode Compositing

Mevcut Python'da `QPainter.CompositionMode_Clear` kullanılıyor. Flutter karşılığı:

```dart
void _paintFog(Canvas canvas, Size size) {
  // Fog'u ayrı bir layer'da çiz
  canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

  // Tam siyah fog
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()..color = Colors.black.withOpacity(0.85),
  );

  // Açılmış alanları BlendMode.clear ile kes
  for (final revealedPath in fogRevealedPaths) {
    canvas.drawPath(
      revealedPath,
      Paint()..blendMode = BlendMode.clear,
    );
  }

  canvas.restore();
}
```

### 4.5 Tool Sistemi — Strategy Pattern

Mevcut: `TOOL_NAVIGATE`, `TOOL_RULER`, `TOOL_CIRCLE`, `TOOL_DRAW`, `TOOL_FOG_ADD`, `TOOL_FOG_ERASE`

```dart
abstract class BattleMapTool {
  void onPointerDown(PointerDownEvent event);
  void onPointerMove(PointerMoveEvent event);
  void onPointerUp(PointerUpEvent event);
  void paint(Canvas canvas, Size size); // Araç-specific overlay (aktif çizim)
  MouseCursor get cursor;
}

class RulerTool implements BattleMapTool {
  Offset? _start;
  Offset? _end;

  @override
  void onPointerDown(PointerDownEvent event) => _start = event.localPosition;

  @override
  void onPointerMove(PointerMoveEvent event) => _end = event.localPosition;

  @override
  void onPointerUp(PointerUpEvent event) {
    if (_start != null && _end != null) {
      // Kalıcı ruler olarak kaydet
      onRulerCreated?.call(Ruler(_start!, _end!));
    }
    _start = null; _end = null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_start != null && _end != null) {
      _drawRulerLine(canvas, _start!, _end!);
      _drawDistanceLabel(canvas, _start!, _end!); // feet + grid squares
    }
  }

  @override
  MouseCursor get cursor => SystemMouseCursors.crosshair;
}
```

### 4.6 Token Rendering

```dart
Widget _buildTokenWidget(Token token, DmToolColors palette) {
  final borderColor = switch (token.attitude) {
    Attitude.player   => palette.tokenBorderPlayer,   // #4caf50 (yeşil)
    Attitude.hostile   => palette.tokenBorderHostile,  // #ef5350 (kırmızı)
    Attitude.friendly  => palette.tokenBorderFriendly, // #42a5f5 (mavi)
    Attitude.neutral   => palette.tokenBorderNeutral,  // #bdbdbd (gri)
  };

  final isActive = token.id == activeTokenId;
  final displayBorder = isActive ? palette.tokenBorderActive : borderColor; // Aktif: turuncu

  return Positioned(
    left: token.x - token.size / 2,
    top: token.y - token.size / 2,
    child: GestureDetector(
      onPanUpdate: widget.isDmView ? (d) => _onTokenDrag(token.id, d) : null,
      child: Container(
        width: token.size.toDouble(),
        height: token.size.toDouble(),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: displayBorder, width: 3),
          image: token.imagePath != null
            ? DecorationImage(image: FileImage(File(token.imagePath!)), fit: BoxFit.cover)
            : null,
          color: token.imagePath == null ? borderColor.withOpacity(0.3) : null,
        ),
        child: token.imagePath == null
          ? Center(child: Text(token.name[0], style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
          : null,
      ),
    ),
  );
}
```

### 4.7 Measurement Overlay

Mevcut formül: `feet = (distance_px / cell_size) * feet_per_cell`

```dart
void _drawRulerLine(Canvas canvas, Offset start, Offset end) {
  final distance = (end - start).distance;
  final gridSquares = distance / gridState.cellSize;
  final feet = gridSquares * gridState.feetPerCell;

  // Çizgi
  canvas.drawLine(start, end, Paint()
    ..color = Colors.yellow
    ..strokeWidth = 2.0 / zoom); // Zoom-independent kalınlık

  // Etiket: "30 ft (6 sq)"
  final label = '${feet.round()} ft (${gridSquares.toStringAsFixed(1)} sq)';
  final midPoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
  _drawLabel(canvas, midPoint, label);
}
```

### 4.8 Grid State Yapısı

```dart
@freezed
class GridState with _$GridState {
  const factory GridState({
    @Default(50) int cellSize,
    @Default(false) bool visible,
    @Default(false) bool snap,
    @Default(5) int feetPerCell,
  }) = _GridState;
}
```

---

## 5. Mind Map Sistemi

### 5.1 Mevcut Yapı

Kaynak: `ui/tabs/mind_map_tab.py` (822 satır) + `ui/widgets/mind_map_items.py` (551 satır)

QGraphicsScene üzerinde sonsuz canvas, LOD sistemi, 4 node tipi, Bézier bağlantıları.

### 5.2 Flutter Mimarisi

```dart
class MindMapCanvas extends ConsumerStatefulWidget {
  final String mapId;
  const MindMapCanvas({required this.mapId, super.key});

  @override
  ConsumerState<MindMapCanvas> createState() => _MindMapCanvasState();
}

class _MindMapCanvasState extends ConsumerState<MindMapCanvas> {
  final TransformationController _transform = TransformationController();
  double _currentZoom = 1.0;

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mindMapProvider(widget.mapId));
    final palette = Theme.of(context).extension<DmToolColors>()!;

    return InteractiveViewer.builder(
      transformationController: _transform,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: 0.05,
      maxScale: 3.0,
      onInteractionUpdate: (details) {
        setState(() {
          _currentZoom = _transform.value.getMaxScaleOnAxis();
        });
      },
      builder: (context, viewport) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Arka plan grid
            CustomPaint(
              painter: MindMapGridPainter(
                zoom: _currentZoom,
                palette: palette,
              ),
              size: Size.infinite,
            ),

            // Bağlantı çizgileri (Bézier)
            CustomPaint(
              painter: ConnectionPainter(
                edges: mapState.edges,
                nodePositions: mapState.nodePositionMap,
                selectedEdgeId: mapState.selectedEdgeId,
                palette: palette,
              ),
            ),

            // Node'lar — LOD-aware
            for (final node in _visibleNodes(mapState.nodes, viewport))
              Positioned(
                left: node.x,
                top: node.y,
                child: _currentZoom < 0.1
                  ? _buildTemplateNode(node, palette)  // Zona 2: basitleştirilmiş
                  : _currentZoom < 0.4
                    ? _buildReducedNode(node, palette)  // Zona 1: cache'li
                    : _buildFullNode(node, palette),    // Zona 0: tam kalite
              ),
          ],
        );
      },
    );
  }
}
```

### 5.3 LOD Sistemi (3 Zona)

Mevcut Python'daki `_LOD_THRESHOLD` = 0.2 ve 3 zonalı sistem:

| Zona | Zoom Aralığı | Rendering | Açıklama |
|---|---|---|---|
| 0 (Full) | >= 0.4 | Tam widget + gölge efekti | Markdown preview, entity card, image |
| 1 (Reduced) | 0.1 - 0.4 | Widget + RepaintBoundary cache | Gölge kaldırılmış, cache kullanır |
| 2 (Template) | < 0.1 | Renkli Container + inverse-scale Text | Sadece dikdörtgen + başlık |

```dart
/// Zona 2: Template mode — inverse-scaled label
Widget _buildTemplateNode(MindMapNode node, DmToolColors palette) {
  final bgColor = switch (node.type) {
    NodeType.note => palette.nodeBgNote,
    NodeType.entity => palette.nodeBgEntity,
    NodeType.image => Colors.transparent,
    NodeType.workspace => palette.canvasBg,
  };

  // Font boyutu: zoom ile ters orantılı (her zaman okunabilir)
  final fontSize = max(10.0, 13.0 / max(_currentZoom, 0.01));

  return Container(
    width: node.width,
    height: node.height,
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(4),
    ),
    child: OverflowBox(
      alignment: Alignment.center,
      maxWidth: double.infinity,
      child: Text(
        node.title,
        style: TextStyle(fontSize: fontSize, color: palette.nodeText),
        textAlign: TextAlign.center,
        overflow: TextOverflow.visible,
      ),
    ),
  );
}
```

### 5.4 Bézier Bağlantıları

```dart
class ConnectionPainter extends CustomPainter {
  // ... fields ...

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final from = nodePositions[edge.sourceId];
      final to = nodePositions[edge.targetId];
      if (from == null || to == null) continue;

      final isSelected = edge.id == selectedEdgeId;
      final paint = Paint()
        ..color = isSelected ? palette.lineSelected : palette.lineColor
        ..strokeWidth = isSelected ? 3.0 : 2.0
        ..style = isSelected ? PaintingStyle.stroke : PaintingStyle.stroke;

      if (isSelected) {
        paint.strokeCap = StrokeCap.round;
        // Dashed line efekti
      }

      // Cubic Bézier
      final path = Path()
        ..moveTo(from.center.dx, from.center.dy);

      final dx = (to.center.dx - from.center.dx) * 0.5;
      path.cubicTo(
        from.center.dx + dx, from.center.dy,
        to.center.dx - dx, to.center.dy,
        to.center.dx, to.center.dy,
      );

      canvas.drawPath(path, paint);
    }
  }
}
```

### 5.5 4 Node Tipi

| Tip | İçerik | Arka Plan | Border Radius |
|---|---|---|---|
| Note | MarkdownEditor widget | `#fff9c4` (açık sarı) | 0px |
| Entity | NpcSheet (kompakt) | `#2b2b2b` (koyu) | 6px |
| Image | AspectRatio image viewer | Transparent | 0px |
| Workspace | Alt-canvas container | Canvas BG | 0px |

### 5.6 Undo/Redo — Command Pattern

```dart
abstract class MindMapCommand {
  void execute(MindMapState state);
  void undo(MindMapState state);
}

class MoveNodeCommand implements MindMapCommand {
  final String nodeId;
  final Offset oldPosition;
  final Offset newPosition;
  // ... execute() ve undo() implementasyonu
}

@riverpod
class MindMapUndoStack extends _$MindMapUndoStack {
  static const _maxSize = 50;
  final List<MindMapCommand> _undoStack = [];
  final List<MindMapCommand> _redoStack = [];

  void execute(MindMapCommand command) {
    command.execute(state);
    _undoStack.add(command);
    if (_undoStack.length > _maxSize) _undoStack.removeAt(0);
    _redoStack.clear();
    _triggerAutosave();
  }

  void undo() { /* _undoStack.removeLast().undo(state); _redoStack.add(...) */ }
  void redo() { /* _redoStack.removeLast().execute(state); _undoStack.add(...) */ }

  Timer? _autosaveTimer;
  void _triggerAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 2), () => _save());
  }
}
```

### 5.7 Grid Rendering

```dart
class MindMapGridPainter extends CustomPainter {
  final double zoom;
  final DmToolColors palette;

  @override
  void paint(Canvas canvas, Size size) {
    // Zoom < 0.15'te grid'i atla (performans)
    if (zoom < 0.15) return;

    // Düşük zoom'da grid spacing artır
    final baseSpacing = 30.0;
    final spacing = zoom < 0.5 ? baseSpacing * 3 : baseSpacing;

    final paint = Paint()
      ..color = palette.gridColor
      ..strokeWidth = 1.0;

    // Nokta grid çiz
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }
}
```

---

## 6. Combat Tracker

### 6.1 Mevcut MVP Yapısı

Kaynak: `ui/widgets/combat_tracker.py` (291), `ui/presenters/combat_presenter.py` (513), `ui/widgets/combat_table.py` (443)

```
CombatTracker (orchestrator)
├── CombatModel (pure data, no Qt)
├── BattleMapBridge (window lifecycle)
├── CombatControlsWidget (UI: round/turn)
├── CombatantListWidget (table view)
└── CombatPresenter (business logic)
```

### 6.2 Flutter Karşılığı

| Python | Dart | Rol |
|---|---|---|
| `CombatModel` | `Encounter` + `CombatState` Freezed | Pure state |
| `CombatPresenter` | `CombatNotifier` (Riverpod AsyncNotifier) | İş mantığı |
| `CombatTracker` | `CombatTrackerScreen` (ConsumerWidget) | UI orchestrator |
| `CombatControlsWidget` | `CombatControlsBar` | Round/turn UI |
| `CombatantListWidget` | `CombatantListView` | Combatant ekleme |
| `DraggableCombatTable` | `CombatTable` (ReorderableListView) | Initiative tablosu |
| `BattleMapBridge` | `BattleMapBridgeService` (Riverpod) | Player window routing |

### 6.3 Encounter Data Model

```dart
@freezed
class Encounter with _$Encounter {
  const factory Encounter({
    required String id,
    @Default('') String name,
    @Default([]) List<Combatant> combatants,
    String? mapPath,
    @Default(50) int tokenSize,
    @Default({}) Map<String, int> tokenSizeOverrides,
    @Default(-1) int turnIndex,
    @Default(1) int round,
    @Default({}) Map<String, Offset> tokenPositions,
    @Default(GridState()) GridState gridState,
    String? encounterLayoutId,  // WorldSchema'daki EncounterLayout referansı
    // Fog ve annotation verileri ayrı yönetilir (büyük blob'lar)
  }) = _Encounter;

  factory Encounter.fromJson(Map<String, dynamic> json) => _$EncounterFromJson(json);
}

@freezed
class Combatant with _$Combatant {
  const factory Combatant({
    required String id,
    required String name,
    @Default(0) int init,
    @Default(10) int ac,
    @Default(10) int hp,
    @Default(10) int maxHp,
    String? entityId,
    @Default([]) List<CombatCondition> conditions,
    String? tokenId,
  }) = _Combatant;

  factory Combatant.fromJson(Map<String, dynamic> json) => _$CombatantFromJson(json);
}

@freezed
class CombatCondition with _$CombatCondition {
  const factory CombatCondition({
    required String name,
    int? duration, // Tur sayısı, null = süresiz
  }) = _CombatCondition;
}
```

### 6.4 CombatNotifier — İş Mantığı

```dart
@riverpod
class CombatNotifier extends _$CombatNotifier {
  @override
  CombatState build() => const CombatState();

  void advanceTurn() {
    final enc = state.currentEncounter;
    if (enc == null || enc.combatants.isEmpty) return;

    var newIndex = enc.turnIndex + 1;
    var newRound = enc.round;
    if (newIndex >= enc.combatants.length) {
      newIndex = 0;
      newRound++;
      // Condition süreleri düşür
      _decrementConditions();
    }

    state = state.copyWith(
      currentEncounter: enc.copyWith(turnIndex: newIndex, round: newRound),
    );

    _logEvent('Round $newRound — ${enc.combatants[newIndex].name}\'s turn');
  }

  void modifyHp(String combatantId, int delta) {
    // HP güncelle, log yaz, auto-save tetikle
  }

  void addCondition(String combatantId, String conditionName, int? duration) {
    // Condition ekle, log yaz
  }

  void rollInitiative(String combatantId) {
    // d20 + initiative bonus, tabloya sırala
  }
}
```

### 6.5 Combat Table UI — Schema-Driven Kolonlar

Combat tracker kolonları artık `EncounterLayout`'tan okunur. Built-in kolonlar (name, initiative, hp, ac, conditions) her zaman mevcuttur; ek kolonlar schema'dan gelir.

```dart
class CombatTable extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final combatState = ref.watch(combatProvider);
    final encounter = combatState.currentEncounter;
    final palette = Theme.of(context).extension<DmToolColors>()!;

    // Schema-driven encounter layout
    final schema = ref.watch(worldSchemaProvider);
    final layout = schema.encounterLayouts.firstWhere(
      (l) => l.layoutId == encounter?.encounterLayoutId,
      orElse: () => schema.encounterLayouts.first, // Default layout
    );

    return ReorderableListView.builder(
      itemCount: encounter?.combatants.length ?? 0,
      onReorder: (oldIndex, newIndex) =>
        ref.read(combatProvider.notifier).reorder(oldIndex, newIndex),
      itemBuilder: (context, index) {
        final c = encounter!.combatants[index];
        final isActive = index == encounter.turnIndex;

        return ListTile(
          key: ValueKey(c.id),
          tileColor: isActive ? palette.tokenBorderActive.withOpacity(0.1) : null,
          leading: Text('${c.init}', style: const TextStyle(fontWeight: FontWeight.bold)),
          title: Text(c.name),
          subtitle: Row(children: [
            // Schema-driven kolonlar
            for (final col in layout.columns)
              _buildColumnWidget(col, c, palette),
            const SizedBox(width: 8),
            Expanded(child: HpBar(hp: c.hp, maxHp: c.maxHp, palette: palette)),
          ]),
          trailing: Wrap(
            spacing: 2,
            children: c.conditions.map((cond) =>
              ConditionBadge(condition: cond, palette: palette)
            ).toList(),
          ),
        );
      },
    );
  }

  Widget _buildColumnWidget(EncounterColumn col, Combatant c, DmToolColors palette) {
    // Built-in keys: "name", "initiative", "hp", "ac", "conditions"
    // Custom keys: FieldSchema.fieldKey → entity.fields[key] üzerinden oku
    // ...
  }
}
```

### 6.6 Predefined Conditions (15 adet)

Blinded, Charmed, Deafened, Frightened, Grappled, Incapacitated, Invisible, Paralyzed, Petrified, Poisoned, Prone, Restrained, Stunned, Unconscious, Exhaustion

---

## 7. Soundpad ve Audio Engine

### 7.1 Mevcut Yapı

Kaynak: `core/audio/engine.py` (325 satır), `core/audio/models.py` (37 satır), `ui/soundpad_panel.py` (445 satır)

### 7.2 Audio Model Hiyerarşisi

```
Theme (ör. "Forest")
├── State: "Normal"
│   ├── Track: "base"      → LoopNode(file_path, repeat_count=0)
│   ├── Track: "level1"    → LoopNode(...)
│   └── Track: "level2"    → LoopNode(...)
├── State: "Combat"
│   ├── Track: "base"      → LoopNode(...)
│   └── Track: "level1"    → LoopNode(...)
└── State: "Victory"
    └── Track: "base"      → LoopNode(...)
```

```dart
@freezed
class AudioTheme with _$AudioTheme {
  const factory AudioTheme({
    required String name,
    @Default('') String id,
    @Default({}) Map<String, MusicState> states,
  }) = _AudioTheme;
}

@freezed
class MusicState with _$MusicState {
  const factory MusicState({
    required String name,
    @Default({}) Map<String, AudioTrack> tracks,
  }) = _MusicState;
}

@freezed
class AudioTrack with _$AudioTrack {
  const factory AudioTrack({
    required String name,
    @Default([]) List<LoopNode> sequence,
  }) = _AudioTrack;
}

@freezed
class LoopNode with _$LoopNode {
  const factory LoopNode({
    required String filePath,
    @Default(0) int repeatCount, // 0 = infinite loop
  }) = _LoopNode;
}
```

### 7.3 Flutter Audio Engine — flutter_soloud

> **Karar:** v2.1'de `just_audio` yerine **`flutter_soloud` 3.1.0** seçildi. SoLoud bir game audio engine olduğu için CPU-side mixing yapar, gapless loop ve built-in `fadeVolume()` sunar; desktop platformlarda `just_audio`'dan daha stabildir. Ses kaynakları **handle** olarak yönetilir (her `play()` çağrısı bir handle döndürür).

```dart
import 'package:flutter_soloud/flutter_soloud.dart';

class AudioEngine {
  final SoLoud _soloud = SoLoud.instance;

  // --- Music: 2 paralel handle (crossfade) ---
  SoundHandle? _activeMusicHandle;
  SoundHandle? _fadingMusicHandle;
  AudioSource? _activeSource;

  // --- Intensity layers (base, level1, level2) — paralel handle pool ---
  final Map<String, SoundHandle> _intensityHandles = {};

  // --- Ambience (4 slot, infinite loop) ---
  final List<SoundHandle?> _ambienceSlots = List.filled(4, null);
  final List<double> _ambienceSlotVolumes = List.filled(4, 0.7);

  // --- SFX (8 slot, one-shot, auto-cleanup) ---
  final List<SoundHandle?> _sfxPool = List.filled(8, null);

  // State
  AudioTheme? _currentTheme;
  String? _currentStateId;
  int _intensityLevel = 0;
  double _masterVolume = 0.5;

  Future<void> initialize() async {
    await _soloud.init();
    _soloud.setGlobalVolume(_masterVolume);
  }

  /// Crossfade: SoLoud built-in fadeVolume + 3s
  Future<void> setState(String stateName) async {
    if (_currentTheme == null || stateName == _currentStateId) return;
    final targetState = _currentTheme!.states[stateName];
    if (targetState == null) return;

    // 1. Yeni track'i 0 volume ile başlat
    final newSource = await _soloud.loadFile(
      targetState.tracks['base']!.sequence.first.filePath,
    );
    final newHandle = await _soloud.play(newSource, volume: 0.0, looping: true);

    // 2. Eski track'i fade-out, yeni track'i fade-in (paralel, 3s)
    if (_activeMusicHandle != null) {
      _soloud.fadeVolume(_activeMusicHandle!, 0.0, const Duration(seconds: 3));
      _soloud.scheduleStop(_activeMusicHandle!, const Duration(seconds: 3));
    }
    _soloud.fadeVolume(newHandle, _masterVolume, const Duration(seconds: 3));

    _activeMusicHandle = newHandle;
    _activeSource = newSource;
    _currentStateId = stateName;
  }

  /// Intensity arttıkça paralel layer'lar açılır.
  Future<void> setIntensity(int level) async {
    _intensityLevel = level;
    final wantedLayers = ['base', for (var i = 1; i <= level; i++) 'level$i'];

    // Eksik layer'ları başlat
    for (final layerId in wantedLayers) {
      if (_intensityHandles.containsKey(layerId)) continue;
      final track = _currentTheme?.states[_currentStateId]?.tracks[layerId];
      if (track == null) continue;
      final source = await _soloud.loadFile(track.sequence.first.filePath);
      final handle = await _soloud.play(source, volume: 0.0, looping: true);
      _soloud.fadeVolume(handle, _masterVolume, const Duration(milliseconds: 1500));
      _intensityHandles[layerId] = handle;
    }

    // Fazladan layer'ları kapat
    final toRemove = _intensityHandles.keys
        .where((id) => !wantedLayers.contains(id))
        .toList();
    for (final id in toRemove) {
      final h = _intensityHandles.remove(id)!;
      _soloud.fadeVolume(h, 0.0, const Duration(milliseconds: 1500));
      _soloud.scheduleStop(h, const Duration(milliseconds: 1500));
    }
  }

  void setMasterVolume(double v) {
    _masterVolume = v;
    _soloud.setGlobalVolume(v);
  }
}
```

### 7.4 Ambience ve SFX

```dart
extension AudioEngineSlots on AudioEngine {
  /// Ambience: infinite loop, 4 paralel slot
  Future<void> playAmbience(int slotIndex, String filePath) async {
    if (_ambienceSlots[slotIndex] != null) {
      _soloud.stop(_ambienceSlots[slotIndex]!);
    }
    final source = await _soloud.loadFile(filePath);
    final handle = await _soloud.play(
      source,
      volume: _ambienceSlotVolumes[slotIndex],
      looping: true,
    );
    _ambienceSlots[slotIndex] = handle;
  }

  void stopAmbience(int slotIndex) {
    final h = _ambienceSlots[slotIndex];
    if (h != null) {
      _soloud.fadeVolume(h, 0.0, const Duration(milliseconds: 500));
      _soloud.scheduleStop(h, const Duration(milliseconds: 500));
      _ambienceSlots[slotIndex] = null;
    }
  }

  /// SFX: one-shot, auto-cleanup (SoLoud handle bittiğinde otomatik free)
  Future<void> playSfx(String filePath, {double volume = 1.0}) async {
    final source = await _soloud.loadFile(filePath);
    await _soloud.play(source, volume: volume, looping: false);
    // SoLoud handle bittiğinde otomatik dispose, cleanup gerekmez
  }
}
```

**SoLoud avantajları:**
- ✅ **Gapless loop:** PCM-level seamless loop, just_audio'nun sample-edge gap problemi yok
- ✅ **Built-in fade:** `fadeVolume(handle, target, duration)` — animasyon controller gerekmez
- ✅ **CPU mixing:** Tüm handle'lar tek output stream'de mix'lenir, OS audio session sayısı 1
- ✅ **3D positioning (opsiyonel):** Gelecekte battle map'te konum-tabanlı ses
- ⚠️ **Düşük seviye API:** `just_audio`'nun stream/playlist soyutlamaları yok; track yönetimi manuel

---

## 8. Dual Screen / Player Window

### 8.1 Mevcut Yapı

Kaynak: `ui/player_window.py` (448 satır) — ayrı QMainWindow, 5 sayfalı QStackedWidget

### 8.2 Multi-Window Yaklaşımı: desktop_multi_window

```dart
// main.dart — Multi-window entry point routing
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (args.isNotEmpty && args.first == 'multi_window') {
    // Alt pencere (Player Window)
    final windowId = int.parse(args[1]);
    final argument = args.length > 2 ? args[2] : '{}';
    runApp(ProviderScope(
      child: PlayerWindowApp(windowId: windowId),
    ));
  } else {
    // Ana pencere (DM Tool)
    runApp(const ProviderScope(child: MainApp()));
  }
}
```

### 8.3 Player Window Açma

```dart
Future<void> openPlayerWindow() async {
  final screens = await screenRetriever.getAllDisplays();
  Rect? targetRect;

  if (screens.length > 1) {
    // İkinci monitör varsa orada aç
    final secondScreen = screens[1];
    targetRect = Rect.fromLTWH(
      secondScreen.visiblePosition!.dx,
      secondScreen.visiblePosition!.dy,
      secondScreen.size.width,
      secondScreen.size.height,
    );
  }

  final window = await DesktopMultiWindow.createWindow(jsonEncode({
    'type': 'player_window',
  }));

  window.setTitle('Player View - Second Screen');
  if (targetRect != null) {
    window.setFrame(targetRect);
  } else {
    window.setFrame(const Rect.fromLTWH(100, 100, 800, 600));
  }
  window.show();
}
```

### 8.4 Player Window — 5 Sayfa

```dart
class PlayerWindowApp extends ConsumerWidget {
  final int windowId;
  const PlayerWindowApp({required this.windowId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projection = ref.watch(projectionProvider);

    return MaterialApp(
      theme: ref.watch(themeProvider),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: IndexedStack(
          index: projection.activePage,
          children: [
            // Sayfa 0: Multi-Image Viewer
            MultiImageViewer(images: projection.activeImages),

            // Sayfa 1: Battle Map (read-only)
            BattleMapCanvas(isDmView: false),

            // Sayfa 2: Black Screen
            const ColoredBox(color: Colors.black),

            // Sayfa 3: Character Sheet (HTML)
            HtmlWidget(projection.statBlockHtml),

            // Sayfa 4: PDF Viewer
            if (projection.pdfPath != null)
              PdfViewer.file(projection.pdfPath!),
          ],
        ),
      ),
    );
  }
}
```

### 8.5 Projection State Management

```dart
@freezed
class ProjectionState with _$ProjectionState {
  const factory ProjectionState({
    @Default(0) int activePage,     // 0=images, 1=battlemap, 2=black, 3=stats, 4=pdf
    @Default([]) List<String> activeImages,
    @Default('side_by_side') String imageLayoutMode,
    @Default(false) bool blackScreen,
    String? statBlockHtml,
    String? pdfPath,
  }) = _ProjectionState;
}

@riverpod
class ProjectionNotifier extends _$ProjectionNotifier {
  @override
  ProjectionState build() => const ProjectionState();

  void showImages(List<String> paths) =>
    state = state.copyWith(activePage: 0, activeImages: paths, blackScreen: false);

  void showBattleMap() =>
    state = state.copyWith(activePage: 1, blackScreen: false);

  void toggleBlackScreen() =>
    state = state.copyWith(
      activePage: state.blackScreen ? state.activePage : 2,
      blackScreen: !state.blackScreen,
    );

  void showStatBlock(String html) =>
    state = state.copyWith(activePage: 3, statBlockHtml: html, blackScreen: false);

  void showPdf(String path) =>
    state = state.copyWith(activePage: 4, pdfPath: path, blackScreen: false);

  void addImage(String path) =>
    state = state.copyWith(
      activeImages: [...state.activeImages, path],
      activePage: 0,
    );

  void removeImage(String path) =>
    state = state.copyWith(
      activeImages: state.activeImages.where((p) => p != path).toList(),
    );
}
```

### 8.6 Pencereler Arası State Senkronizasyonu

`desktop_multi_window` pencereler arasında `DesktopMultiWindow.invokeMethod()` ile iletişim sağlar. ProjectionProvider state değişiklikleri bu kanal üzerinden player window'a iletilir.

---

## 9. Yerel Depolama

### 9.1 Storage Stratejisi — Drift (SQLite) Primary

v2.1 ile birlikte yerel depolama tamamen **Drift (SQLite)** üzerine taşındı. MsgPack flat file formatı sadece iki amaç için kalır:
1. **Legacy migration** — Eski Python `data.dat` dosyalarını ilk açılışta SQLite'a aktarmak
2. **`.dmt` paket import/export** — Kampanyaları paylaşmak/yedeklemek için

| Veri | Önceki | Şimdi |
|---|---|---|
| Kampanya + entity'ler + schema | `worlds/{name}/data.dat` (MsgPack) | `dmt.sqlite` Drift veritabanı |
| Combat state, map data, mind map | `data.dat` içinde nested | **`campaigns.state_json`** TEXT blob (henüz normalize edilmedi) |
| Settings (tema, dil, volume) | JSON file | `SharedPreferences` |
| API library cache | `cache/library/{source}/{type}/{id}.json` | Aynı (filesystem cache) |

### 9.2 Drift Database — `lib/data/database/app_database.dart`

```dart
@DriftDatabase(
  tables: [
    Campaigns,
    WorldSchemas,
    Entities,
    Sessions,
    Encounters,
    Combatants,
    CombatConditions,
    MapPins,
    TimelinePins,
    MindMapNodes,
    MindMapEdges,
  ],
  daos: [
    CampaignDao,
    EntityDao,
    SessionDao,
    MapDao,
    MindMapDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2: campaigns.state_json eklendi (un-normalized blob)
            await m.addColumn(campaigns, campaigns.stateJson);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(dir.path, 'DungeonMasterTool'));
    if (!dbDir.existsSync()) dbDir.createSync(recursive: true);
    final file = File(p.join(dbDir.path, 'dmt.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
```

**SQLite dosyası:** `getApplicationSupportDirectory()/DungeonMasterTool/dmt.sqlite`

### 9.3 Tablo Şemaları (Supabase Mirror)

Drift tabloları **Supabase PostgreSQL şemasıyla birebir uyumlu** tasarlandı, böylece online geçişte aynı kolon adları/tipleri kullanılır ve client-server arasında DTO mapping sıfıra iner.

| Tablo | Kolonlar | FK |
|-------|---------|-----|
| **campaigns** | `id` (UUID PK), `world_name`, `state_json` (TEXT default `'{}'`), `created_at`, `updated_at` | — |
| **world_schemas** | `id` PK, `campaign_id` FK, `name`, `version`, `base_system`, `description`, `categories_json`, `encounter_config_json`, `encounter_layouts_json`, `metadata_json`, `created_at`, `updated_at` | → campaigns |
| **entities** | `id` PK, `campaign_id` FK, `category_slug`, `name`, `source`, `description`, `image_path`, `images_json`, `tags_json`, `dm_notes`, `pdfs_json`, `location_id` (self-FK nullable), `fields_json`, `created_at`, `updated_at` | → campaigns |
| **sessions** | `id` PK, `campaign_id` FK, `name`, `notes`, `logs`, `is_active`, `created_at`, `updated_at` | → campaigns |
| **encounters** | `id` PK, `session_id` FK, `campaign_id` FK, `name`, `map_path`, `token_size`, `grid_size`, `grid_visible`, `grid_snap`, `feet_per_cell`, `fog_data`, `annotation_data`, `encounter_layout_id`, `turn_index`, `round`, `token_positions_json`, `token_size_multipliers_json`, `sort_order`, `created_at` | → sessions |
| **combatants** | `id` PK, `encounter_id` FK, `entity_id` FK (nullable), `name`, `init`, `ac`, `hp`, `max_hp`, `token_id`, `sort_order` | → encounters, → entities |
| **combat_conditions** | `id` PK, `combatant_id` FK, `name`, `duration`, `initial_duration`, `entity_id` (nullable) | → combatants |
| **map_pins** | `id` PK, `campaign_id` FK, `x`, `y`, `label`, `pin_type`, `entity_id` FK (nullable), `note`, `color`, `style_json` | → campaigns, → entities |
| **timeline_pins** | `id` PK, `campaign_id` FK, `x`, `y`, `day`, `note`, `entity_ids_json`, `session_id` FK (nullable), `parent_ids_json`, `color` | → campaigns |
| **mind_map_nodes** | `id` PK, `campaign_id` FK, `label`, `node_type`, `x`, `y`, `width`, `height`, `entity_id` FK (nullable), `image_url`, `content`, `style_json`, `color` | → campaigns, → entities |
| **mind_map_edges** | `id` PK, `campaign_id` FK, `source_id` FK, `target_id` FK, `label`, `style_json` | → mind_map_nodes |

> `*_json` kolonları (`fields_json`, `categories_json`, `encounter_config_json`, vb.) Drift'te `TEXT` tutulur, Supabase'de `jsonb` olur. Bu, schema-driven entity sisteminin esnekliğini korur — yeni alan eklendiğinde DDL migration gerekmez.

### 9.4 `state_json` Blob Stratejisi

Henüz normalize edilmeyen üç alan `campaigns.state_json` TEXT kolonunda JSON blob olarak tutulur:
- `combat_state` — Aktif encounter, turn order, condition'lar
- `map_data` — Dünya haritası pinleri, fog, timeline
- `mind_maps` — Workspace'ler, node konumları, undo stack

Bu pragmatik geçici çözüm sayesinde:
- Yeni feature'lar **schema migration tetiklemeden** eklenebilir
- Mind/world map UI çalışmaya devam ederken normalize çalışması paralel ilerleyebilir
- Sprint 5 sonu görevi (`5.19`): bu blob'u `mind_map_nodes`/`mind_map_edges`/`map_pins`/`timeline_pins` tablolarına taşımak

### 9.5 DAO Pattern

```dart
@DriftAccessor(tables: [Campaigns])
class CampaignDao extends DatabaseAccessor<AppDatabase> with _$CampaignDaoMixin {
  CampaignDao(super.db);

  Future<List<Campaign>> getAll() => select(campaigns).get();

  Future<List<String>> getAvailableNames() async {
    final rows = await select(campaigns).get();
    return rows.map((c) => c.worldName).toList();
  }

  Future<Campaign?> getByName(String name) =>
      (select(campaigns)..where((t) => t.worldName.equals(name)))
          .getSingleOrNull();

  Future<Campaign?> getById(String id) =>
      (select(campaigns)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> createCampaign(CampaignsCompanion data) =>
      into(campaigns).insert(data);

  Future<void> updateCampaign(CampaignsCompanion data) =>
      update(campaigns).replace(data);

  Future<int> deleteCampaign(String id) =>
      (delete(campaigns)..where((t) => t.id.equals(id))).go();
}
```

DAO'lar `lib/data/database/daos/` altında:
- `campaign_dao.dart` — campaigns CRUD
- `entity_dao.dart` — entities CRUD + category/tag filtreleme
- `session_dao.dart` — sessions + encounters + combatants (TODO: bağlantı)
- `map_dao.dart` — map_pins + timeline_pins (TODO: bağlantı)
- `mind_map_dao.dart` — mind_map_nodes + mind_map_edges (TODO: bağlantı)

### 9.6 Repository Layer

`CampaignRepositoryImpl` Drift DAO'larını **legacy MsgPack fallback** ile birleştirir:

```dart
class CampaignRepositoryImpl implements CampaignRepository {
  final AppDatabase _db;
  final CampaignLocalDataSource _localDs;  // MsgPack reader

  @override
  Future<Map<String, dynamic>> load(String campaignName) async {
    // 1. Önce SQLite'da ara
    final existing = await _db.campaignDao.getByName(campaignName);
    if (existing != null) return _loadFromDb(existing.id);

    // 2. Yoksa legacy .dat dosyasını oku, parse et, SQLite'a migrate et
    final path = p.join(AppPaths.worldsDir, campaignName);
    final data = await _localDs.load(path);
    SchemaMigration.migrate(data);
    await _migrateToDb(campaignName, data);
    return data;
  }

  @override
  Future<void> save(String campaignName, Map<String, dynamic> data) async {
    final existing = await _db.campaignDao.getByName(campaignName);
    if (existing != null) {
      await _saveToDb(existing.id, data);
    } else {
      // Yeni kampanya — direkt SQLite
      final id = data['world_id'] as String? ?? const Uuid().v4();
      data['world_id'] = id;
      await _db.campaignDao.createCampaign(
        CampaignsCompanion.insert(id: id, worldName: campaignName),
      );
      await _saveToDb(id, data);
    }
  }
}
```

### 9.7 Legacy MsgPack Migration

Mevcut Python kullanıcılarının `.dat` dosyaları otomatik olarak Drift'e aktarılır:

1. App ilk açıldığında: Drift SQLite oluşturulur (boş)
2. Kullanıcı eski kampanyayı açar: `_loadFromDb` SQLite'ta bulamaz
3. `CampaignLocalDataSource.load()` ile `worlds/{name}/data.dat` MsgPack okunur
4. `SchemaMigration.migrate()` — TR→EN field map, default schema backfill
5. `_migrateToDb()` — Drift transaction içinde tüm tablolara dağıtılır
6. (Opsiyonel) `data.dat` → `data.dat.bak` olarak yedeklenir, bir daha okunmaz

Bu yaklaşım sayesinde mevcut kullanıcılar kayıpsız geçiş yapar; yeni kampanyalar ise direkt SQLite'da oluşturulur.

### 9.8 `.dmt` Export/Import (Paylaşım Formatı)

`.dmt` paketleri tam kampanya snapshot'larını paylaşmak için kullanılır:

```
my-campaign.dmt (ZIP)
├── manifest.json          # Versiyon, yazar, dependency listesi
├── data.msgpack           # Drift'ten dump edilmiş tam state
├── assets/
│   ├── images/
│   ├── audio/             # SoLoud için pre-cached müzik dosyaları
│   └── pdfs/
└── README.md (opsiyonel)
```

**Export:** Drift tablolarından okunur → JSON dict → MsgPack serialize → ZIP
**Import:** ZIP unzip → MsgPack deserialize → SchemaMigration → Drift'e yaz

`.dmt-template` ise farklıdır: yalnızca world schema (kategori + alan tanımları), entity'ler değil — Section 3.12'ye bakın.

### 9.9 Dosya Yolu Çözümleme — `AppPaths`

```dart
class AppPaths {
  static late String baseDir;       // Uygulama veri kökü
  static late String worldsDir;     // Eski .dat dosyaları (legacy)
  static late String cacheDir;      // API cache + asset cache
  static late String soundpadRoot;  // Theme YAML + audio assets

  static Future<void> initialize() async {
    // Portable mode: exe yanında worlds/ dizini varsa onu kullan
    final exeDir = path.dirname(Platform.resolvedExecutable);
    final portableWorlds = Directory(path.join(exeDir, 'worlds'));

    if (await portableWorlds.exists()) {
      baseDir = exeDir;
    } else {
      final appSupportDir = await getApplicationSupportDirectory();
      baseDir = path.join(appSupportDir.path, 'DungeonMasterTool');
    }

    worldsDir = path.join(baseDir, 'worlds');     // Sadece migration için okunur
    cacheDir = path.join(baseDir, 'cache');
    soundpadRoot = path.join(baseDir, 'assets', 'soundpad');

    await Directory(baseDir).create(recursive: true);
    await Directory(cacheDir).create(recursive: true);
  }

  /// Relatif yolu kampanya bazlı absolute yola çevir
  static String resolve(String relativePath, String campaignPath) {
    if (path.isAbsolute(relativePath)) return relativePath;
    return path.normalize(path.join(campaignPath, relativePath.replaceAll('\\', '/')));
  }
}
```

> Drift SQLite dosyası `getApplicationSupportDirectory()/DungeonMasterTool/dmt.sqlite` olarak ayrıdır; `AppPaths.baseDir` ile aynı kök ama farklı dosya.

### 9.10 Ayarlar — SharedPreferences

```dart
class SettingsLocalDataSource {
  final SharedPreferences _prefs;

  String get currentTheme => _prefs.getString('theme') ?? 'dark';
  String get language => _prefs.getString('language') ?? 'en';
  String? get lastCampaign => _prefs.getString('last_campaign');
  double get masterVolume => _prefs.getDouble('master_volume') ?? 0.5;

  Future<void> setTheme(String theme) => _prefs.setString('theme', theme);
  Future<void> setLanguage(String lang) => _prefs.setString('language', lang);
  Future<void> setLastCampaign(String path) => _prefs.setString('last_campaign', path);
}
```

### 9.11 API Cache — Dosya Tabanlı

```
cache/
├── library/
│   ├── dnd5e/
│   │   ├── spells/
│   │   │   ├── fireball.json
│   │   │   └── magic-missile.json
│   │   ├── monsters/
│   │   ├── equipment/
│   │   └── ...
│   └── open5e/
│       └── ...
└── assets/
    └── {sha256}.bin       # R2 download local cache (Sprint 10)
```

---

## 10. Hibrit Online Mimari (Supabase + Cloudflare)

> **Detaylı teknik rapor:** `docs/ONLINE_REPORT.md` v2.0 — Hibrit Online Mimarisi

### 10.1 Mimari Felsefesi

DMT'nin online katmanı **offline-first** prensibine dayalıdır: her özellik internet olmadan çalışmalı, online sadece **opt-in** ekstra bir katman olmalıdır. Bu felsefe altı ana prensibe yansır:

1. **DM as Source of Truth** — DM'in lokal `dmt.sqlite` veritabanı tek doğruluk kaynağıdır; server hiçbir oyun state'ini değiştiremez, sadece event relay yapar
2. **Sıfır sunucu maliyeti** — Tüm bileşenler free tier'larda kalmalı; ücretli plan opsiyonel
3. **Açık kaynak güvenliği** — Kod açık olduğu için güvenlik matematiğe (JWT) dayanır, gizli secret'a değil
4. **Minimal oyuncu sürtünmesi** — 6-char join code + display name yeterli; full hesap opsiyonel
5. **İçerik sahipliği** — DM kendi dünyasını her an `.dmt` olarak export edebilir
6. **Artımlı sync** — Delta event'ler, ancak gerektiğinde snapshot fallback

### 10.2 Stack Değişikliği — v1.0 → v2.1

v1.0 blueprint'inde tarif edilen FastAPI + PostgreSQL + Redis + MinIO + python-socketio self-hosted stack'i **terkedildi**. Yeni stack tamamen managed servisler üzerine kuruludur:

| Eski (v1.0) | Yeni (v2.1) | Sebep |
|---|---|---|
| FastAPI + python-socketio | **Supabase Realtime (Broadcast)** | Sıfır sunucu maliyeti, hazır JWT, Dart SDK olgun |
| PostgreSQL self-hosted | **Supabase Postgres + RLS** | Built-in row-level security, managed backups |
| Redis self-hosted | **Supabase Realtime channel** | Tek bağımlılık, broadcast pub/sub built-in |
| MinIO self-hosted | **Cloudflare R2 + Worker** | Sıfır egress maliyeti, edge cache |
| JWT RS256 (kendi sunucu) | **Supabase JWT** | SDK desteği, refresh token yönetimi hazır |
| socket_io_client (Dart) | **supabase_flutter** | Realtime + Auth + Storage tek SDK |

### 10.3 Stack Tablosu

| Bileşen | Teknoloji | Free Tier | Amaç |
|---|---|---|---|
| **Auth + JWT** | Supabase Auth | 50k MAU | Email/password, refresh token |
| **Database** | Supabase Postgres | 500MB | Sessions, participants, event log, community market |
| **Realtime** | Supabase Broadcast | 200 concurrent WS | DM↔Player event relay, fire-and-forget |
| **Asset Storage** | Cloudflare R2 | 10GB + zero egress | Görsel, PDF, audio (büyük dosyalar) |
| **Asset Gateway** | Cloudflare Worker | 100k req/day | JWT verify + RLS check + R2 stream |
| **Rate Limiting** | Cloudflare KV | 1k op/day | 20 download/saat per user |
| **Mobile P2P** | flutter_webrtc + Cloudflare TURN | (Sprint 11) | Screen share, low latency |

### 10.4 Database Şeması — Supabase Mirror

Section 9.3'teki Drift tabloları **Supabase'de aynen** mevcut olur (kolon adları/tipleri birebir). Ek olarak yalnızca server-side tablolar:

```sql
-- Users — Supabase Auth tarafından otomatik yönetilir
-- (auth.users tablosu, kendimiz yaratmıyoruz)

-- Active game sessions
CREATE TABLE game_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dm_user_id      UUID NOT NULL REFERENCES auth.users(id),
    campaign_id     UUID NOT NULL,                -- DM'in lokal campaign UUID
    session_name    VARCHAR(255) NOT NULL,
    join_code       VARCHAR(6) UNIQUE,            -- Aktifken dolu, bitince NULL
    state           VARCHAR(20) NOT NULL DEFAULT 'waiting'
                    CHECK (state IN ('waiting', 'active', 'ended')),
    created_at      TIMESTAMPTZ DEFAULT now(),
    ended_at        TIMESTAMPTZ
);

CREATE INDEX idx_sessions_join_code
    ON game_sessions(join_code) WHERE join_code IS NOT NULL;

-- Session participants (DM, players, observers)
CREATE TABLE session_participants (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID NOT NULL REFERENCES game_sessions(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES auth.users(id),  -- NULL = anonim oyuncu
    display_name    VARCHAR(100) NOT NULL,
    role            VARCHAR(20) NOT NULL DEFAULT 'PLAYER'
                    CHECK (role IN ('DM_OWNER', 'PLAYER', 'OBSERVER')),
    joined_at       TIMESTAMPTZ DEFAULT now(),
    is_connected    BOOLEAN DEFAULT TRUE
);

-- Event log — revision-based delta sync için
CREATE TABLE event_log (
    id              BIGSERIAL PRIMARY KEY,
    event_id        UUID NOT NULL UNIQUE,         -- Client UUID (idempotency)
    session_id      UUID NOT NULL REFERENCES game_sessions(id),
    event_type      VARCHAR(100) NOT NULL,
    sender_id       UUID,
    sender_role     VARCHAR(20) NOT NULL,
    revision        BIGINT NOT NULL,              -- Session-bazlı monoton sayaç
    payload         JSONB NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_event_log_session_rev ON event_log(session_id, revision);

-- Community market: paylaşılan .dmt paketleri
CREATE TABLE community_worlds (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id       UUID NOT NULL REFERENCES auth.users(id),
    title           VARCHAR(255) NOT NULL,
    description     TEXT,
    r2_object_key   VARCHAR(500) NOT NULL,        -- R2'deki .dmt path
    download_count  INT DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- Asset metadata (R2 object'lere referans)
CREATE TABLE community_assets (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    world_id        UUID REFERENCES community_worlds(id),
    session_id      UUID REFERENCES game_sessions(id),
    uploader_id     UUID NOT NULL REFERENCES auth.users(id),
    filename        VARCHAR(500) NOT NULL,
    sha256_hash     VARCHAR(64) NOT NULL,
    size_bytes      BIGINT NOT NULL,
    r2_object_key   VARCHAR(500) NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT now()
);
```

**RLS Policies (örnekler):**

```sql
-- DM yalnızca kendi session'larını yönetebilir
CREATE POLICY "DM owns session" ON game_sessions
    FOR ALL USING (auth.uid() = dm_user_id);

-- Player'lar session'ı join_code ile okuyabilir
CREATE POLICY "Players read session by code" ON game_sessions
    FOR SELECT USING (join_code IS NOT NULL);

-- Participant'lar yalnızca kendi katıldıkları session'ları görür
CREATE POLICY "Participant sees own sessions" ON session_participants
    FOR SELECT USING (user_id = auth.uid() OR session_id IN (
        SELECT id FROM game_sessions WHERE dm_user_id = auth.uid()
    ));

-- Event log: DM her şeyi yazar; player yalnızca kendi session'ından okur
CREATE POLICY "Read event log in joined session" ON event_log
    FOR SELECT USING (session_id IN (
        SELECT session_id FROM session_participants WHERE user_id = auth.uid()
    ));
```

### 10.5 EventEnvelope — Tek Wire Format

Section 1.4'te tanımlanan `EventEnvelope` Freezed class'ı tüm online iletişim için kullanılır. 24 event tipi vardır; 17'si `EventTypes.onlineEvents` set'inde tanımlı ve network'e forward edilir:

| Domain | Tipler |
|---|---|
| Campaign | `campaign.loaded`, `campaign.saved`, `campaign.created` *(local-only)* |
| Entity | `entity.created`, `entity.updated`, `entity.deleted` |
| Session | `session.created`, `session.activated`, `session.combatant_added`, `session.combatant_updated`, `session.turn_advanced` |
| Map | `map.image_set`, `map.fog_updated`, `map.pin_added`, `map.pin_removed` |
| Mind Map | `mindmap.node_created`, `mindmap.node_updated`, `mindmap.node_deleted`, `mindmap.edge_created`, `mindmap.edge_deleted` |
| Projection | `projection.content_set`, `projection.mode_changed` |
| Audio | `audio.state_changed`, `audio.track_triggered` |

### 10.6 NetworkBridge Mimarisi

```dart
// lib/data/network/network_bridge.dart
abstract class NetworkBridge {
  Stream<ConnectionStatus> get statusStream;
  ConnectionStatus get status;

  Future<void> connect(String sessionId, String accessToken);
  Future<void> disconnect();

  /// AppEventBus interceptor — outgoing event flow
  void broadcast(EventEnvelope event);

  /// Incoming event stream — bridge subscribe edip AppEventBus.injectRemote() çağırır
  Stream<EventEnvelope> get incomingEvents;

  /// Snapshot transferi (player join'de DM yollar)
  Future<void> sendSnapshot(GameSnapshot snapshot, {required String toUserId});
}

class NoOpNetworkBridge implements NetworkBridge {
  @override
  ConnectionStatus get status => ConnectionStatus.disconnected;
  // ... tüm metodlar no-op
}

class SupabaseNetworkBridge implements NetworkBridge {
  final SupabaseClient _client;
  RealtimeChannel? _channel;
  final List<EventEnvelope> _pendingQueue = [];

  @override
  Future<void> connect(String sessionId, String accessToken) async {
    _channel = _client.channel('session:$sessionId')
      ..onBroadcast(
        event: 'event',
        callback: (payload, [_]) {
          final env = EventEnvelope.fromJson(payload['envelope'] as Map<String, dynamic>);
          _incomingController.add(env);
        },
      )
      ..subscribe();
  }

  @override
  void broadcast(EventEnvelope event) {
    if (_channel == null) {
      _pendingQueue.add(event);
      return;
    }
    _channel!.sendBroadcastMessage(event: 'event', payload: {'envelope': event.toJson()});
  }
}
```

**Connection state machine:**

```
disconnected → connecting → connected → error
       ↑                                 │
       └─────────────────────────────────┘
```

### 10.7 Snapshot & Recovery — DM as Source of Truth

Player join veya reconnect'te kayıp event'leri kapatmak için iki strateji:

| Senaryo | Strateji |
|---|---|
| İlk join | Tam `GameSnapshot` (DM Drift'ten capture eder, broadcast eder, player restore eder) |
| Reconnect, < 200 event kayıp | **Delta resync** — `event_log` tablosundan revision aralığı çekilir, replay |
| Reconnect, > 200 event kayıp | **Snapshot fallback** — Tam state yeniden gönderilir |

```dart
class StateSnapshotService {
  final AppDatabase _db;

  /// DM tarafı: lokal Drift'ten tam state çıkar
  Future<GameSnapshot> capture(String campaignId) async {
    return GameSnapshot(
      campaignId: campaignId,
      capturedAt: DateTime.now().toUtc(),
      entities: await _db.entityDao.getAllForCampaign(campaignId),
      sessions: await _db.sessionDao.getAllForCampaign(campaignId),
      mapData: await _db.mapDao.getAllForCampaign(campaignId),
      mindMaps: await _db.mindMapDao.getAllForCampaign(campaignId),
      // ...
    );
  }

  /// Player tarafı: gelen snapshot'ı lokal Drift'e yaz
  Future<void> restore(GameSnapshot snapshot) async {
    await _db.transaction(() async {
      await _db.entityDao.replaceAll(snapshot.campaignId, snapshot.entities);
      await _db.sessionDao.replaceAll(snapshot.campaignId, snapshot.sessions);
      // ...
    });
  }
}
```

### 10.8 Cloudflare R2 + Worker Asset Pipeline

Büyük dosyalar (görseller, PDF, audio) Supabase Storage yerine **Cloudflare R2**'da tutulur (sıfır egress maliyeti). R2 bucket'ı tamamen private; tüm erişim **Cloudflare Worker** üzerinden geçer.

**Worker Akışı (TypeScript):**

```typescript
// cloudflare/worker.ts
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const auth = request.headers.get('Authorization');
    if (!auth?.startsWith('Bearer ')) return new Response('Unauthorized', { status: 401 });

    // 1. Supabase JWT verify
    const token = auth.slice(7);
    const payload = await verifyJwt(token, env.SUPABASE_JWT_SECRET);
    if (!payload) return new Response('Invalid token', { status: 401 });

    const userId = payload.sub;

    // 2. RLS check via Supabase REST API (service role)
    const objectKey = new URL(request.url).pathname.slice(1);
    const allowed = await checkAssetAccess(userId, objectKey, env);
    if (!allowed) return new Response('Forbidden', { status: 403 });

    // 3. Rate limit (KV-backed counter)
    const rateKey = `rate:${userId}:${new Date().toISOString().slice(0, 13)}`;
    const count = parseInt((await env.RATE_KV.get(rateKey)) ?? '0');
    if (count >= 20) return new Response('Too Many Requests', { status: 429 });
    await env.RATE_KV.put(rateKey, (count + 1).toString(), { expirationTtl: 3600 });

    // 4. R2 stream
    const obj = await env.R2_BUCKET.get(objectKey);
    if (!obj) return new Response('Not Found', { status: 404 });
    return new Response(obj.body, {
      headers: {
        'Content-Type': obj.httpMetadata?.contentType ?? 'application/octet-stream',
        'Cache-Control': 'private, max-age=3600',
      },
    });
  },
};
```

**Flutter `AssetService`:**

```dart
class AssetService {
  final SupabaseClient _supabase;
  final Dio _dio;

  /// Player: Worker proxy üzerinden R2'dan indir
  Future<File> downloadAsset(String objectKey) async {
    final localCache = File(p.join(AppPaths.cacheDir, 'assets', _hash(objectKey)));
    if (await localCache.exists()) return localCache;

    final token = _supabase.auth.currentSession!.accessToken;
    final response = await _dio.get<List<int>>(
      '${_workerBaseUrl}/$objectKey',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: ResponseType.bytes,
      ),
    );

    await localCache.create(recursive: true);
    await localCache.writeAsBytes(response.data!);
    return localCache;
  }

  /// DM: Worker presigned URL ile R2'ya yükle
  Future<String> uploadAsset(File file, String campaignId) async {
    // ... presigned PUT URL request → upload → return objectKey
  }
}
```

### 10.9 Audio Trigger Pattern

Yüksek kaliteli müzik dosyalarını online stream etmek bant genişliği ve senkronizasyon felaketidir. Çözüm: **dosyalar pre-cached, sadece JSON command broadcast**.

1. `.dmt` paketi tüm ses dosyalarını içerir → DM ve player'lar oyuna girmeden önce indirir (Worker üzerinden)
2. DM müzik temasını değiştirdiğinde → `EventEnvelope(eventType: 'audio.state_changed', payload: {theme: 'forest', state: 'combat', intensity: 0.8})`
3. Player'lar bu JSON'u alır → lokal `flutter_soloud` engine kendi cihazında dosyayı oynatır
4. **Bant tüketimi:** baytlar düzeyinde
5. **Gecikme:** sıfır

### 10.10 Permission Modeli ve Visibility

| Rol | Görebilecekler | Yapabilecekler |
|---|---|---|
| `DM_OWNER` | Her şey | Her şey |
| `PLAYER` | shared_full + shared_restricted | Zar at, condition bildir, kendi token'ını hareket ettir |
| `OBSERVER` | shared_full + shared_restricted | Sadece izle |

**Field-level visibility:**
- `private_dm` — Sadece DM görür; payload server'a bile gitmez (client-side filter + RLS doğrulama)
- `shared_full` — Tüm katılımcılar tam erişir
- `shared_restricted` — HP gibi alanlar maskelenmiş gösterilir (`"Bloodied" / "Healthy"`)

### 10.11 Rate Limiting ve Throttling

| Kanal | Limit | Uygulama |
|---|---|---|
| Worker R2 download | 20/saat per user | Cloudflare KV counter |
| Supabase Realtime emit | DM 30/s, Player 5/s | Server-side throttle (Supabase plan) |
| Auth login | 5/dk per IP | Supabase built-in |
| Client fog updates | 200ms debounce | Flutter side |
| Client mind map updates | 100ms debounce | Flutter side |

### 10.12 Bölünmüş Ağ Mimarisi

Supabase Free Tier'ın **200 concurrent WebSocket** limiti darboğazdır. Çözüm: market/community sayfaları **HTTP REST**, sadece aktif oyun masaları **Realtime**.

| Özellik | Protokol | WS limit tüketimi |
|---|---|---|
| Community market browse | HTTP REST | Sıfır |
| .dmt download | HTTP (Worker) | Sıfır |
| Profile/settings | HTTP REST | Sıfır |
| Active game session | Realtime Broadcast | DM + 4-5 player ≈ 5-6 WS |

200 limit ile ~33-40 paralel oyun masası mümkün. Kullanıcı session'dan kalktığında kanal **derhal** kapatılır.

> **Tarihsel not:** v1.0 blueprint'i bu noktada ayrıntılı `users / refresh_tokens / sessions / session_participants / event_log / assets / dice_rolls / audit_log` PostgreSQL şemaları + 24 ayrı Freezed payload sınıfı + custom `socket_io_client` NetworkBridge state machine içeriyordu. Bu içerik **tamamen kaldırıldı** çünkü:
> - PostgreSQL şemaları artık Supabase'de RLS policies ile yönetiliyor (Section 10.4)
> - 24 payload sınıfı yerine **tek `EventEnvelope` Freezed class'ı** kullanılıyor (Section 1.4); tip bilgisi `EventTypes` sabit string'lerinde
> - NetworkBridge artık `supabase_flutter` Realtime channel üzerinden çalışıyor (Section 10.6)
> - Detaylı protokol akışları, JWT lifetime, rate limit numaraları, RLS örnekleri için: **`docs/ONLINE_REPORT.md` v2.0**

---

## 11. API Entegrasyonu

### 11.1 Mevcut Yapı

Kaynak: `core/api/base_source.py`, `core/api/dnd5e_source.py`, `core/api/open5e_source.py`, `core/api_client.py`

### 11.2 Abstract Source Pattern

```dart
abstract class ApiSource {
  String get sourceId;        // "dnd5e" veya "open5e"
  String get baseUrl;
  List<String> get categories;

  Future<List<Map<String, dynamic>>> fetchIndex(String category, {int page = 1, Map<String, String>? filters});
  Future<Map<String, dynamic>> fetchDetails(String category, String index);
  Map<String, dynamic> parseToEntity(Map<String, dynamic> rawData, String category);
}

class Dnd5eApiSource implements ApiSource {
  @override String get sourceId => 'dnd5e';
  @override String get baseUrl => 'https://www.dnd5eapi.co/api';
  @override List<String> get categories => ['monsters', 'spells', 'equipment', 'classes', 'races', 'conditions', 'features'];

  @override
  Future<Map<String, dynamic>> fetchDetails(String category, String index) async {
    final response = await _dio.get('/$category/$index');
    return response.data;
  }
}

class Open5eApiSource implements ApiSource {
  @override String get sourceId => 'open5e';
  @override String get baseUrl => 'https://api.open5e.com/v1';
  // ...
}
```

### 11.3 HTTP Client — Dio

```dart
final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  // Cache interceptor
  dio.interceptors.add(CacheInterceptor(
    cacheDir: AppPaths.cacheDir,
    maxAge: const Duration(days: 30),
  ));

  return dio;
});
```

### 11.4 Library Cache

```dart
class LibraryCacheDataSource {
  /// Cache'den oku, yoksa null döndür
  Future<Map<String, dynamic>?> get(String source, String category, String index) async {
    final file = File(path.join(AppPaths.cacheDir, 'library', source, category, '$index.json'));
    if (await file.exists()) {
      return jsonDecode(await file.readAsString());
    }
    return null;
  }

  /// Cache'e yaz
  Future<void> put(String source, String category, String index, Map<String, dynamic> data) async {
    final dir = Directory(path.join(AppPaths.cacheDir, 'library', source, category));
    await dir.create(recursive: true);
    final file = File(path.join(dir.path, '$index.json'));
    await file.writeAsString(jsonEncode(data));
  }
}
```

---

## 12. Tema Sistemi

### 12.1 Mevcut Yapı

Kaynak: `core/theme_manager.py` — 11 tema, her biri 80+ renk değişkeni
Kaynak: `themes/*.qss` — 12 QSS dosyası

### 12.2 ThemeExtension — DmToolColors

```dart
class DmToolColors extends ThemeExtension<DmToolColors> {
  // --- Mind Map & Canvas ---
  final Color canvasBg;
  final Color gridColor;
  final Color nodeBgNote;
  final Color nodeBgEntity;
  final Color nodeText;
  final Color lineColor;
  final Color lineSelected;
  final Color uiResizeHandle;
  final Color uiResizeHandleInactive;

  // --- Markdown Editor ---
  final Color htmlText;
  final Color htmlLink;
  final Color htmlHeader;
  final Color htmlCodeBg;

  // --- Floating Controls ---
  final Color uiFloatingBg;
  final Color uiFloatingBorder;
  final Color uiFloatingText;
  final Color uiFloatingHoverBg;
  final Color uiFloatingHoverText;

  // --- Autosave Indicator ---
  final Color uiAutosaveBg;
  final Color uiAutosaveTextSaved;
  final Color uiAutosaveTextEditing;

  // --- Projection Manager ---
  final Color uiProjectionBg;
  final Color uiProjectionBorder;
  final Color uiProjectionHoverBg;
  final Color uiProjectionHoverBorder;
  final Color uiThumbnailBg;
  final Color uiThumbnailBorder;

  // --- Combat & Tokens ---
  final Color tokenBorderPlayer;
  final Color tokenBorderHostile;
  final Color tokenBorderFriendly;
  final Color tokenBorderNeutral;
  final Color tokenBorderActive;

  // --- HP Bar ---
  final Color hpBarHigh;
  final Color hpBarMed;
  final Color hpBarLow;
  final Color hpWidgetBg;
  final Color hpBtnDecreaseBg;
  final Color hpBtnDecreaseHover;
  final Color hpBtnIncreaseBg;
  final Color hpBtnIncreaseHover;

  // --- Condition Icons ---
  final Color conditionDefaultBg;
  final Color conditionDurationBg;
  final Color conditionText;

  // --- Battle Map ---
  final Color fogPenAdd;
  final Color fogPenRemove;
  final Color fogTempPath;

  // --- Map Pins ---
  final Color pinNpc;
  final Color pinMonster;
  final Color pinLocation;
  final Color pinPlayer;
  final Color pinDefault;
  final Color timelinePinBg;
  final Color timelineSessionBg;

  // --- DM Notes ---
  final Color dmNoteBorder;
  final Color dmNoteTitle;

  // --- Entity Sidebar ---
  final Color sidebarLabelSecondary;
  final Color sidebarLabelDim;
  final Color sidebarDivider;
  final Color sidebarFilterBg;

  // --- Tab Bars ---
  final Color tabBg;
  final Color tabActiveBg;
  final Color tabHoverBg;
  final Color tabText;
  final Color tabActiveText;

  const DmToolColors({ /* tüm alanlar required */ });

  @override
  ThemeExtension<DmToolColors> copyWith({ /* tüm alanlar */ }) { ... }

  @override
  ThemeExtension<DmToolColors> lerp(DmToolColors? other, double t) {
    if (other == null) return this;
    return DmToolColors(
      canvasBg: Color.lerp(canvasBg, other.canvasBg, t)!,
      gridColor: Color.lerp(gridColor, other.gridColor, t)!,
      // ... tüm alanlar için lerp
    );
  }
}
```

### 12.3 11 Tema Paleti

```dart
const Map<String, DmToolColors> themePalettes = {
  'dark': DmToolColors(
    canvasBg: Color(0xFF181818),
    gridColor: Color(0xFF2B2B2B),
    nodeBgNote: Color(0xFFFFF9C4),
    nodeBgEntity: Color(0xFF2B2B2B),
    tokenBorderPlayer: Color(0xFF4CAF50),
    tokenBorderHostile: Color(0xFFEF5350),
    tokenBorderFriendly: Color(0xFF42A5F5),
    tokenBorderNeutral: Color(0xFFBDBDBD),
    tokenBorderActive: Color(0xFFFFB74D),
    hpBarHigh: Color(0xFF2E7D32),
    hpBarMed: Color(0xFFFBC02D),
    hpBarLow: Color(0xFFC62828),
    // ... diğer 80+ alan
  ),
  'light': DmToolColors( ... ),
  'parchment': DmToolColors( ... ),
  'ocean': DmToolColors( ... ),
  'emerald': DmToolColors( ... ),
  'midnight': DmToolColors( ... ),
  'discord': DmToolColors( ... ),
  'baldur': DmToolColors( ... ),
  'grim': DmToolColors( ... ),
  'frost': DmToolColors( ... ),
  'amethyst': DmToolColors( ... ),
};
```

### 12.4 Runtime Tema Değiştirme

```dart
@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  @override
  String build() {
    return ref.read(settingsRepositoryProvider).currentTheme;
  }

  void setTheme(String themeName) {
    ref.read(settingsRepositoryProvider).setTheme(themeName);
    state = themeName;
  }
}

// app.dart içinde kullanım
MaterialApp(
  theme: buildThemeData(ref.watch(themeProvider)),
  // ...
)

ThemeData buildThemeData(String themeName) {
  final palette = themePalettes[themeName] ?? themePalettes['dark']!;
  return ThemeData(
    brightness: _isDark(themeName) ? Brightness.dark : Brightness.light,
    extensions: [palette],
    // ... diğer ThemeData ayarları
  );
}
```

---

## 13. Lokalizasyon

### 13.1 Mevcut Yapı

Kaynak: `locales/en.yml`, `locales/tr.yml`, `locales/de.yml`, `locales/fr.yml` — ~250 anahtar

### 13.2 Flutter Lokalizasyon — ARB Dosyaları

`l10n.yaml` yapılandırması:

```yaml
arb-dir: lib/presentation/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: L10n
```

**YAML → ARB dönüşüm kuralı:**
- `BTN_SAVE` → `btnSave`
- `MSG_LOADED_FROM_CACHE` → `msgLoadedFromCache`
- `LBL_RACE` → `lblRace`

```json
// app_en.arb (örnek)
{
  "@@locale": "en",
  "btnSave": "Save",
  "btnDelete": "Delete",
  "btnCancel": "Cancel",
  "lblRace": "Race",
  "lblClass": "Class",
  "lblLevel": "Level",
  "lblAttitude": "Attitude",
  "lblAttrFriendly": "Friendly",
  "lblAttrNeutral": "Neutral",
  "lblAttrHostile": "Hostile",
  "msgLoadedFromCache": "Loaded from cache",
  "msgFetchedFromApi": "Fetched from API",
  "msgDatabaseExists": "Already exists in database"
}
```

### 13.3 Kullanım

```dart
// Python'daki tr("BTN_SAVE") karşılığı:
Text(L10n.of(context).btnSave)
```

### 13.4 Runtime Dil Değiştirme

```dart
@riverpod
class LocaleNotifier extends _$LocaleNotifier {
  @override
  Locale build() {
    final lang = ref.read(settingsRepositoryProvider).language;
    return Locale(lang);
  }

  void setLocale(String languageCode) {
    ref.read(settingsRepositoryProvider).setLanguage(languageCode);
    state = Locale(languageCode);
  }
}

// app.dart
MaterialApp(
  locale: ref.watch(localeProvider),
  supportedLocales: const [Locale('en'), Locale('tr'), Locale('de'), Locale('fr')],
  localizationsDelegates: L10n.localizationsDelegates,
)
```

---

## 14. PDF Viewer

### 14.1 Paket: pdfrx

```dart
class PdfViewerWidget extends StatelessWidget {
  final String filePath;
  const PdfViewerWidget({required this.filePath, super.key});

  @override
  Widget build(BuildContext context) {
    return PdfViewer.file(
      filePath,
      params: const PdfViewerParams(
        enableTextSelection: true,
        scrollDirection: Axis.vertical,
        maxScale: 5.0,
      ),
    );
  }
}
```

### 14.2 "Project PDF" Akışı

1. Entity'nin Docs tab'ında "Project PDF" butonuna tıkla
2. `ref.read(projectionProvider.notifier).showPdf(pdfPath)` çağır
3. Player window `ref.watch(projectionProvider)` ile güncellenir
4. Player window'da `PdfViewerWidget` render edilir

---

## 15. Platform Desteği ve Dağıtım

### 15.1 Hedef Platformlar

| Platform | Build Format | Window Management | Öncelik |
|---|---|---|---|
| Windows 10/11 (64-bit) | MSIX / Inno Setup | `window_manager` + `desktop_multi_window` | Birincil |
| macOS 12+ (Intel + Apple Silicon) | DMG / App Bundle | Aynı paketler (Cocoa) | Birincil |
| Linux (Ubuntu, Fedora, Arch) | AppImage / Flatpak / Snap | Aynı paketler (GTK) | Birincil |
| Android (gelecek) | APK / AAB | Tek pencere (Player Mode) | İkincil |
| iOS (gelecek) | IPA | Tek pencere (Player Mode) | İkincil |
| Web (gelecek) | Static hosting | Tek pencere (Player Mode) | Üçüncül |

### 15.2 Desktop Paketleri

```yaml
# pubspec.yaml
dependencies:
  window_manager: ^0.4.2         # Pencere boyutu, başlık, minimize/maximize
  desktop_multi_window: ^0.2.3   # İkinci pencere (Player View)
  screen_retriever: ^0.2.0       # Bağlı monitörleri tespit
```

### 15.3 Build Komutları

```bash
# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release

# Android (gelecekte)
flutter build apk --release
```

---

## 16. Paket Listesi

### 16.1 Core Paketler

| Alan | Paket | Versiyon | Amaç |
|---|---|---|---|
| State Management | `flutter_riverpod` | ^2.6 | Provider'lar ve reaktif state |
| Code Generation | `riverpod_annotation` | ^2.6 | @riverpod annotation desteği |
| Immutable Models | `freezed_annotation` | ^3.0 | Freezed data class annotation'ları |
| JSON Serialization | `json_annotation` | ^4.9 | JSON serialization annotation'ları |
| HTTP Client | `dio` | ^5.4 | REST API çağrıları + interceptor'lar (Cloudflare Worker proxy) |
| **Realtime + Auth + Storage** | **`supabase_flutter`** | **^2.x** | **Supabase Auth + Realtime Broadcast + Postgres + Storage tek SDK** *(Sprint 9'da eklenecek)* |

### 16.2 Storage Paketleri

| Alan | Paket | Versiyon | Amaç |
|---|---|---|---|
| **SQLite ORM** | **`drift`** | **^2.22** | **Birincil yerel storage — 11 tablo, schema v2** |
| **SQLite native** | **`sqlite3_flutter_libs`** | **^0.5** | **SQLite engine bundling** |
| MsgPack | `msgpack_dart` | ^1.0 | **Sadece** `.dmt` paket import/export (legacy migration + paylaşım) |
| Settings | `shared_preferences` | ^2.5 | Kullanıcı ayarları (tema, dil, master volume) |
| File Paths | `path_provider` | ^2.1 | Platform-specific dizinler |
| Path Utils | `path` | ^1.9 | Dosya yolu manipülasyonu |

### 16.3 UI Paketleri

| Alan | Paket | Versiyon | Amaç |
|---|---|---|---|
| Routing | `go_router` | ^14.8 | Declarative navigation |
| Markdown | `flutter_markdown` | ^0.7 | Markdown preview rendering |
| File Picker | `file_picker` | ^10.0 | Görsel/PDF import |
| Splitter | `multi_split_view` | ^3.0 | Yeniden boyutlandırılabilir paneller |

### 16.4 Desktop Paketleri

| Alan | Paket | Versiyon | Amaç |
|---|---|---|---|
| Window | `window_manager` | ^0.4 | Ana pencere kontrolü |
| Multi-Window | `desktop_multi_window` | ^0.2 | Player projection penceresi |
| Screen | `screen_retriever` | ^0.2 | Monitor geometrisi tespiti |

### 16.5 Media Paketleri

| Alan | Paket | Versiyon | Amaç |
|---|---|---|---|
| **Audio** | **`flutter_soloud`** | **^3.1** | **SoLoud game audio engine — gapless loop, built-in fade, CPU-side mixing, 3D positioning hazır** |
| **PDF** | **`pdfrx`** | **^2.2** | **PDF doküman görüntüleme** |
| YAML | `yaml` | ^3.1 | Soundpad theme YAML config parse |

### 16.6 Utility Paketleri

| Alan | Paket | Versiyon | Amaç |
|---|---|---|---|
| UUID | `uuid` | ^4.0 | Entity/session ID üretimi |
| Logging | `logger` | ^2.0 | Yapılandırılmış loglama |
| Localization | `intl` | built-in | i18n desteği |

### 16.7 Dev Dependencies

| Alan | Paket | Versiyon | Amaç |
|---|---|---|---|
| Build Runner | `build_runner` | ^2.4 | Freezed/Riverpod code generation |
| Freezed | `freezed` | ^2.5 | Immutable model code generation |
| Riverpod Gen | `riverpod_generator` | ^2.4 | Provider code generation |
| JSON Gen | `json_serializable` | ^6.8 | JSON serialization code generation |
| Testing | `flutter_test` | built-in | Widget ve unit test'ler |
| Mockito | `mockito` | ^5.4 | Mock'lama |
| Lint | `flutter_lints` | ^4.0 | Lint kuralları |

---

## 17. Migration Fazları

> **Durum (2026-04-09):** Faz 0–4 %100, Faz 5 ~%85, Faz 6 ~%40, Faz 7 ~%5, Faz 8 ~%25 (sub-faz 8a kısmen). Detaylı sprint progress: `docs/FLUTTER_DEVELOPMENT_ROADMAP.md` Section 0.

### Faz 0 — Foundation (Hafta 1-2) · `✅ Tamamlandı`

**Hedef:** Proje iskeleti, temel altyapı, veri katmanı

- [ ] Flutter proje oluşturma + dizin yapısı
- [ ] `AppPaths` — config.py path resolution port'u
- [ ] Domain entities: `Entity`, `Campaign`, `Session`, `Encounter`, `MindMapNode/Edge`, `MapData`, `AudioModels`
- [ ] `ENTITY_SCHEMAS` ve `get_default_entity_structure()` port'u
- [ ] Legacy uyumluluk map'leri (`SCHEMA_MAP`, `PROPERTY_MAP`)
- [ ] MsgPack file I/O (`CampaignLocalDataSource`) — mevcut `.dat` dosya okuma testi
- [ ] Riverpod provider skeleton (campaign, entity, session, combat, mindmap, map, audio, theme, locale)
- [ ] `AppEventBus` service
- [ ] 11 tema paleti (`DmToolColors` ThemeExtension)
- [ ] 4 dil ARB dosyaları (YAML → ARB dönüşüm script'i)
- [ ] `CampaignSelectorScreen` — kampanya seçim/oluşturma ekranı
- [ ] Temel `MainScreen` iskeleti (tab bar + boş tab'lar)

**Doğrulama:** Mevcut Python kampanya `.dat` dosyası Flutter'da açılabilir.

### Faz 1 — Entity Management + Database Tab (Hafta 3-5) · `✅ Tamamlandı`

**Hedef:** Tam entity yönetimi, arama, filtreleme

- [ ] `EntityRepository` CRUD implementasyonu
- [ ] `EntitySidebar` — liste, arama, tip filtresi, sürükle kaynağı
- [ ] `NpcSheet` — 8 tab host widget
  - [ ] Stats tab (STR/DEX/CON/INT/WIS/CHA + combat stats)
  - [ ] Description tab (MarkdownEditor)
  - [ ] Spells tab (linked + custom spells, ManualSpellDialog)
  - [ ] Actions tab (traits, actions, reactions, legendary actions)
  - [ ] Inventory tab (linked equipment + inline inventory)
  - [ ] Images tab (görsel galerisi + import)
  - [ ] Docs tab (PDF listesi + "Project PDF" butonu)
  - [ ] DM Notes tab (gizli notlar, kırmızı kenarlık)
- [ ] `MarkdownEditor` — dual-mode (edit/preview) + @mention entity autocomplete
- [ ] `ImageGallery` — multi-image carousel, zoom, import
- [ ] Global Edit Mode toggle (toolbar'da kilit ikonu)
- [ ] Settings dialog (tema, dil, ses seviyesi)

**Doğrulama:** Tüm 15 entity tipi oluşturulabilir, düzenlenebilir, silinebilir. @mention çalışır.

### Faz 2 — Session + Combat Tracker (Hafta 6-7) · `✅ Tamamlandı`

**Hedef:** Tam savaş yönetimi, oturum takibi

- [ ] `SessionRepository` implementasyonu
- [ ] `SessionScreen` — oturum seçici, notlar, loglar
- [ ] `CombatNotifier` — iş mantığı (initiative, HP, conditions, turn advance)
- [ ] `CombatTrackerScreen` — orchestrator widget
- [ ] `CombatControlsBar` — round/turn kontrolleri, "Round N" gösterge
- [ ] `CombatTable` — ReorderableListView, HP bar, condition badge'leri
- [ ] `CombatantListView` — combatant ekleme UI (entity drag-drop)
- [ ] `HpBar` widget — renkli progress bar (high/med/low)
- [ ] `ConditionBadge` widget — 24x24 yuvarlak badge + süre
- [ ] Condition sistemi — 15 predefined, süre takibi, auto-decrement
- [ ] Auto event log — HP değişikliği, condition, round mesajları
- [ ] `DiceRoller` widget — d4, d6, d8, d10, d12, d20, d100
- [ ] Session autosave (400ms debounce)

**Doğrulama:** Tam combat encounter oynanabilir, loglar otomatik yazılır.

### Faz 3 — Battle Map (Hafta 8-10) · `✅ Tamamlandı`

**Hedef:** Tam 6 katmanlı savaş haritası

- [ ] `BattleMapCanvas` — InteractiveViewer + Stack + CustomPainter
- [ ] `BattleMapPainter` — 6 katmanlı rendering
  - [ ] Background layer (ui.Image)
  - [ ] Grid layer (cell size, feet_per_cell, zoom < 0.15 gizle)
  - [ ] Draw layer (freehand Path nesneleri)
  - [ ] Fog layer (BlendMode.clear compositing)
  - [ ] Measurement layer (ruler + circle overlay, feet + squares label)
- [ ] Token layer — `Positioned` widget'lar, GestureDetector drag
  - [ ] Attitude-renkli border (player/hostile/friendly/neutral/active)
  - [ ] Token boyut slider + per-token override
  - [ ] Grid snap
- [ ] Tool system (Strategy pattern)
  - [ ] NavigateTool (pan, middle-mouse always)
  - [ ] RulerTool (mesafe çizgisi + label)
  - [ ] CircleTool (yarıçap + label)
  - [ ] DrawTool (freehand + erase)
  - [ ] FogTool (left-click add, right-click erase)
- [ ] Toolbar UI (2 satır: araçlar + grid kontrolleri)
- [ ] Fog/annotation/ruler/circle persistence per-encounter
- [ ] Büyük görsel desteği (1 GB+ decoded)

**Doğrulama:** 6 katman doğru sırada render ediliyor. Fog, draw, ruler player window'a sync oluyor.

### Faz 4 — Mind Map (Hafta 11-12) · `✅ %85 — UI tamam, persistence normalize bekliyor`

**Hedef:** Tam sonsuz canvas, LOD, bağlantılar

- [ ] `MindMapCanvas` — InteractiveViewer.builder + Stack
- [ ] LOD sistemi (3 zona: Full >= 0.4, Reduced 0.1-0.4, Template < 0.1)
- [ ] 4 node tipi
  - [ ] Note node (MarkdownEditor, sarı arka plan)
  - [ ] Entity node (kompakt NpcSheet, koyu arka plan)
  - [ ] Image node (AspectRatio viewer, transparent)
  - [ ] Workspace node (alt-canvas container)
- [ ] `ConnectionPainter` — Cubic Bézier curves
- [ ] Template mode — inverse-scale readable labels
- [ ] Node interaction: drag, resize (min 150x100), select
- [ ] Connection oluşturma (Shift+drag)
- [ ] Right-click context menu (düzenle, sil, çoğalt, renk değiştir, bağla)
- [ ] Undo/Redo (Command pattern, 50 entry max, Ctrl+Z / Ctrl+Shift+Z)
- [ ] Autosave (2 saniyelik debounce)
- [ ] Entity sidebar'dan sürükle-bırak node oluşturma
- [ ] Grid rendering (zoom < 0.15'te gizle, düşük zoom'da spacing artır)

**Doğrulama:** Node'lar oluşturulabilir, bağlanabilir, taşınabilir. LOD zoom ile sorunsuz geçiş yapar.

### Faz 5 — World Map + Soundpad + PDF (Hafta 13-14) · `~%50 — World Map UI tamam, SoLoud entegre, SoundpadPanel UI bekliyor`

**Hedef:** Dünya haritası, audio sistemi, PDF görüntüleme

- [ ] `MapScreen` — dünya haritası + pin sistemi
  - [ ] Entity pin'leri (renk kodlu: NPC=turuncu, Monster=kırmızı, Location=yeşil, Player=yeşil, default=mavi)
  - [ ] Timeline pin'leri (gün bazlı, parent-child bağlantı, entity ilişkilendirme)
  - [ ] Filtreler (entity tipi, timeline tipi)
  - [ ] "Project Map" butonu
- [ ] `AudioEngine` — just_audio ile implementasyon
  - [ ] MusicDeck A/B + 3 saniyelik crossfade
  - [ ] 4 ambience slot (infinite loop, per-slot volume)
  - [ ] 8 SFX slot (one-shot)
  - [ ] Master volume
  - [ ] Theme → State → Track → LoopNode hiyerarşisi
  - [ ] Intensity mask (base, level1, level2)
- [ ] `SoundpadPanel` UI
  - [ ] Theme seçici
  - [ ] State butonları (Normal, Combat, Victory, ...)
  - [ ] Intensity slider
  - [ ] Ambience slot'ları (4x combobox + volume slider)
  - [ ] SFX grid
  - [ ] Master volume slider
- [ ] `PdfViewerWidget` — pdfrx wrapper
  - [ ] Sağ panel olarak katlanabilir
  - [ ] Soundpad ile karşılıklı exclusion
  - [ ] Entity Docs tab'ından "Project PDF"

**Doğrulama:** Müzik temaları crossfade ile geçiş yapabilir. Ambience + SFX eşzamanlı çalabilir.

### Faz 6 — Dual Screen / Player Window (Hafta 15-16)

**Hedef:** İkinci ekran projection

- [ ] `desktop_multi_window` entegrasyonu
- [ ] Multi-window entry point routing (`main.dart`)
- [ ] `PlayerWindowApp` — 5 sayfalı IndexedStack
  - [ ] Multi-Image Viewer (auto-layout: 1/2-3/4+ images)
  - [ ] Battle Map (read-only, fog/annotation/ruler sync)
  - [ ] Black Screen
  - [ ] Character Sheet (flutter_html stat block)
  - [ ] PDF Viewer
- [ ] `ProjectionNotifier` — state management
- [ ] `BattleMapBridgeService` — combat state routing to player window
- [ ] `ScreenTab` — DM kontrol paneli (mode switch, image layout, projection list)
- [ ] `ProjectionManager` widget — görsel sürükle-bırak + thumbnail strip
- [ ] İkinci monitör otomatik tespiti (`screen_retriever`)
- [ ] Pencereler arası state senkronizasyonu

**Doğrulama:** DM pencereden harita/görsel/PDF player window'a yansır. Fog gerçek zamanlı sync olur.

### Faz 7 — API Integration + Library (Hafta 17)

**Hedef:** D&D API entegrasyonu, içerik tarayıcı

- [ ] `Dnd5eApiSource` implementasyonu (Dio + cache interceptor)
- [ ] `Open5eApiSource` implementasyonu
- [ ] `EntityParser` — API response → Entity dönüşümü
- [ ] `LibraryCacheDataSource` — dosya tabanlı cache
- [ ] `LibraryRepository` — search, fetch, cache yönetimi
- [ ] `ApiBrowserDialog` — kategori seçimi, arama, sayfalama
- [ ] `BulkDownloaderDialog` — toplu indirme (spells, monsters)
- [ ] `ImportDialog` — çoklu kaynak import

**Doğrulama:** D&D 5e SRD'den monster/spell aranabilir, indirilir, entity olarak kaydedilir.

### Faz 8 — Online System (Supabase + R2) (Hafta 18-21)

**Hedef:** Çevrimiçi oyun altyapısı (Supabase Auth + Realtime + Cloudflare R2/Worker). v1.0'daki FastAPI/PostgreSQL/Redis/MinIO planı **terkedildi**; detay Section 10.

**Sub-faz 8a — Foundation (Sprint 9)** (✅ kısmen tamam):
- [x] `EventEnvelope` Freezed class
- [x] `EventTypes` (24 sabit, 17 online-forwarded — Python `core/network/events.py` ile uyumlu)
- [x] `AppEventBus` (StreamController + interceptor hook)
- [x] `NetworkBridge` abstract + `NoOpNetworkBridge`
- [x] `SessionManager` abstract + `NoOpSessionManager`
- [x] `GameSnapshot` Freezed class
- [ ] `supabase_flutter` SDK pubspec entegrasyonu
- [ ] `SupabaseAuthService` — signUp/signIn/signOut + JWT refresh
- [ ] `SupabaseNetworkBridge` impl (Realtime channel `session:{join_code}`)
- [ ] `SupabaseSessionManager` impl + 6-char join code üretimi
- [ ] Supabase project setup + SQL migrations (game_sessions, session_participants, event_log, community_*)
- [ ] RLS policies (DM kendi session, player join_code ile, event_log filter)
- [ ] Auth UI (login/register/forgot dialog)
- [ ] Session create/join UI
- [ ] Connection status badge

**Sub-faz 8b — Sync + Assets (Sprint 10)**:
- [ ] `event_log` revision counter trigger
- [ ] `StateSnapshotService` — capture/restore (Drift direct query)
- [ ] Reconnect state machine (auto-retry + backoff)
- [ ] Delta resync (revision-based replay; > 200 → snapshot fallback)
- [ ] **Cloudflare R2 bucket setup** (private, public erişim kapalı)
- [ ] **Cloudflare Worker** (TypeScript) — Supabase JWT verify + RLS check + KV rate limit + R2 stream
- [ ] `AssetService` — DM presigned upload + Player Worker proxy download + local sha256 cache
- [ ] **Audio Trigger pattern** — SoLoud pre-cached, sadece JSON broadcast
- [ ] Client-side debounce (fog 200ms, mind map 100ms)

**Sub-faz 8c — Mobile + Polish (Sprint 11)**:
- [ ] `flutter_webrtc` mobile screen share (P2P + Cloudflare TURN)
- [ ] Permission filtering (DM_OWNER / PLAYER / OBSERVER, `private_dm` field redaction)
- [ ] Mobile DM/Player mode polish

**Doğrulama:** DM session oluşturur, player 6-char kod ile katılır, snapshot transferi < 3s, basit event broadcast iki taraflı çalışır, Worker JWT doğrulaması 401/403/429 doğru döner.

### Faz 9 — Polish + Test (Hafta 22-23)

**Hedef:** Kalite güvence, performans, paketleme

- [ ] Unit test'ler (domain entities, repositories, usecases)
- [ ] Widget test'ler (kritik ekranlar)
- [ ] Integration test'ler (kampanya load/save, combat flow, API fetch)
- [ ] Performans optimizasyonu
  - [ ] Battle map: büyük haritalar, çok sayıda token
  - [ ] Mind map: 100+ node ile LOD performansı
  - [ ] Kampanya: 500+ entity ile yükleme süresi
- [ ] Keyboard shortcuts
  - [ ] Ctrl+E: Global edit mode toggle
  - [ ] Ctrl+S: Save
  - [ ] Ctrl+Z / Ctrl+Shift+Z: Mind map undo/redo
  - [ ] Delete: Selection sil
- [ ] Platform-specific paketleme
  - [ ] Windows: MSIX + Inno Setup installer
  - [ ] macOS: DMG
  - [ ] Linux: AppImage + Flatpak
- [ ] Mevcut `.dat` backward compatibility tam test
- [ ] Tüm 11 temanın görsel doğrulaması
- [ ] Tüm 4 dilin eksik çeviri kontrolü

**Doğrulama:** Tüm test'ler geçer. Mevcut Python kampanyaları Flutter'da açılır.

---

## Ek: Widget Eşleştirme Tablosu

| PyQt6 Widget | Flutter Karşılığı | Not |
|---|---|---|
| `QMainWindow` | `Scaffold` + `TabBar` | Desktop chrome: `window_manager` |
| `QTabWidget` | `TabBarView` / `NavigationRail` | Desktop-uygun yan nav |
| `QStackedWidget` | `IndexedStack` | Player window sayfa geçişi |
| `QSplitter` | `MultiSplitView` | `multi_split_view` paketi |
| `QGraphicsScene/View` | `InteractiveViewer` + `CustomPainter` | Battle map, mind map |
| `QListWidget` | `ListView.builder` | Entity sidebar |
| `QTextEdit` | `TextField(maxLines: null)` | readOnly: editMode kontrolü |
| `QComboBox` | `DropdownButton` / `DropdownMenu` | |
| `QSlider` | `Slider` | Volume, token boyut |
| `QScrollArea` | `SingleChildScrollView` | NPC sheet scroll |
| `QMenu` (context) | `showMenu()` / `PopupMenuButton` | Sag-tık menüleri |
| `QFileDialog` | `file_picker` paketi | Cross-platform |
| `QMessageBox` | `showDialog` + `AlertDialog` | |
| `QInputDialog` | Custom dialog + `TextField` | |
| `QGroupBox` | `Card` + `Column` with header | |
| `QFrame[featureCard]` | Custom `FeatureCard` widget | Sol kenarlık stilize |
| `QFrame[combatCard]` | Custom `CombatantCard` widget | Attitude-renkli kenarlık |
| `QProgressBar` | `LinearProgressIndicator` / custom | HP bar |
| `QMediaPlayer` | `AudioPlayer` (just_audio) | Tüm audio |
| `QPropertyAnimation` | `AnimationController` + `Tween` | Crossfade, volume fade |
| `QGraphicsPixmapItem` | `CustomPainter` + `canvas.drawImage` | Battle map layers |
| `QPainter` | `Canvas` (CustomPainter.paint) | Tüm custom çizim |

---

## Ek: Kritik Dosya Referansları

| Dosya | Satır | Flutter Karşılığı |
|---|---|---|
| `core/models.py` | 198 | `lib/domain/entities/entity.dart` |
| `core/data_manager.py` | 339 | `lib/application/providers/*.dart` |
| `core/event_bus.py` | 55 | `lib/application/services/event_bus.dart` |
| `core/network/events.py` | 225 | `lib/domain/entities/events/` |
| `core/network/bridge.py` | 179 | `lib/data/network/network_bridge.dart` |
| `core/audio/engine.py` | 325 | `lib/application/services/audio_engine.dart` |
| `core/audio/models.py` | 37 | `lib/domain/entities/audio/audio_models.dart` |
| `core/theme_manager.py` | 100+ | `lib/presentation/theme/dm_tool_colors.dart` |
| `ui/windows/battle_map_window.py` | 1563 | `lib/presentation/screens/battle_map/` |
| `ui/tabs/mind_map_tab.py` | 822 | `lib/presentation/screens/mind_map/` |
| `ui/widgets/mind_map_items.py` | 551 | `lib/presentation/screens/mind_map/mind_map_node.dart` |
| `ui/player_window.py` | 448 | `PlayerWindowApp` (ayrı entry point) |
| `ui/widgets/combat_tracker.py` | 291 | `lib/presentation/screens/session/combat/` |
| `ui/presenters/combat_presenter.py` | 513 | `lib/application/providers/combat_provider.dart` |
| `ui/soundpad_panel.py` | 445 | `lib/presentation/widgets/soundpad_panel.dart` |
| `ui/tabs/session_tab.py` | 412 | `lib/presentation/screens/session/` |
| `ui/tabs/map_tab.py` | 276 | `lib/presentation/screens/map/` |
