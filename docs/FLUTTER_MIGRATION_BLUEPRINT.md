# Flutter Migration Blueprint — Dungeon Master Tool v2.0

> **Kaynak Uygulama:** Python 3.10+ / PyQt6 (v0.8.4)
> **Hedef:** Flutter/Dart — Desktop öncelikli, gelecekte mobile
> **Prensip:** UI ve çalışma mantığı birebir korunarak yeniden yazım

---

## Yönetici Özeti

Bu doküman, mevcut Python/PyQt6 Dungeon Master Tool uygulamasının Flutter ile sıfırdan yazılması için kapsamlı bir teknik rehberdir. Mevcut uygulama ~124 Python dosyası, ~12.000+ LOC, 15 ana özellik, 11 tema, 4 dil desteği ve offline-first mimari ile olgun bir masaüstü uygulamasıdır.

Doküman şunları kapsar: sistem mimarisi, proje yapısı, veri modelleri, tüm interaktif sistemlerin (battle map, mind map, combat tracker, soundpad) Flutter karşılıkları, dual screen yönetimi, yerel ve çevrimiçi depolama, database şeması, API entegrasyonu, tema sistemi, lokalizasyon, ve fazlı migrasyon stratejisi.

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
10. [Online Mimari ve Database Şeması](#10-online-mimari-ve-database-şeması)
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
| `core/entity_repository.py` | `lib/domain/repositories/` (abstract) + `lib/data/repositories/` (impl) | Repository interface + concrete |
| `core/session_repository.py` | `lib/domain/repositories/session_repository.dart` + impl | Session CRUD |
| `core/map_data_manager.py` | `lib/domain/repositories/map_repository.dart` + impl | Pin, timeline CRUD |
| `core/campaign_manager.py` | `lib/data/repositories/campaign_repository_impl.dart` | Kampanya I/O |
| `core/library_manager.py` | `lib/data/repositories/library_repository_impl.dart` | API cache yönetimi |
| `core/settings_manager.py` | `lib/data/repositories/settings_repository_impl.dart` | Ayarlar |
| `core/data_manager.py` (facade) | `lib/application/providers/` | Riverpod provider'lar |
| `core/event_bus.py` | Riverpod `ref.watch/listen` + `AppEventBus` service | Reaktif state + cross-cutting events |
| `core/network/bridge.py` | `lib/data/network/network_bridge.dart` | WebSocket state machine |
| `core/network/events.py` (24 model) | `lib/domain/entities/events/` | Freezed event envelope'ları |
| `core/audio/engine.py` | `lib/application/services/audio_engine.dart` | Multi-deck audio |
| `core/audio/models.py` | `lib/domain/entities/audio/` | Theme, MusicState, Track, LoopNode |
| `ui/` (PyQt6 widgets) | `lib/presentation/` | Flutter widget'ları |
| `ui/presenters/` (MVP) | `lib/presentation/controllers/` | Riverpod AsyncNotifier/StateNotifier |

### 1.3 Neden Riverpod (BLoC Değil)

1. **DataManager facade pattern → Provider tree:** Mevcut DataManager, alt yöneticileri merkezi olarak koordine eder. Riverpod'un provider sistemi bu yapıyı doğal karşılar — her alt yönetici bir provider family olur.
2. **CRUD operasyonları için az boilerplate:** BLoC, her CRUD operasyonu için Event + State + Bloc sınıfı gerektirir. Riverpod'un `AsyncNotifier`'ı aynı tek yönlü veri akışını daha az ceremoniyle sağlar.
3. **Multi-window state paylaşımı:** Player window (ikinci ekran) aynı state'i paylaşmalı. Riverpod'un `ProviderContainer`'ı override'larla bu sorunu çözer — her iki pencere aynı container'dan okur.
4. **EventBus karşılığı:** `ref.listen` ve `ref.watch` çoğu cross-component iletişimi karşılar. Geriye kalan (NetworkBridge'e event forwarding) için hafif bir `StreamController` bus yeterlidir.

### 1.4 EventBus Mimarisi

```dart
/// Cross-cutting events — NetworkBridge entegrasyon noktası.
/// Çoğu UI iletişimi Riverpod ref.watch üzerinden akar.
/// Bu bus sadece online sync ve widget-tree dışı dinleyiciler içindir.
sealed class AppEvent {
  final String type;
  final Map<String, dynamic> payload;
  const AppEvent(this.type, this.payload);
}

class AppEventBus {
  final _controller = StreamController<AppEvent>.broadcast();
  Stream<AppEvent> get stream => _controller.stream;
  void emit(AppEvent event) => _controller.add(event);
  void dispose() => _controller.close();
}

@riverpod
AppEventBus appEventBus(Ref ref) {
  final bus = AppEventBus();
  ref.onDispose(bus.dispose);
  return bus;
}
```

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

## 3. Entity Veri Modelleri

### 3.1 Temel Entity Yapısı

Mevcut Python'daki `get_default_entity_structure()` (kaynak: `core/models.py:153-198`) birebir port edilecek:

```dart
@freezed
class Entity with _$Entity {
  const factory Entity({
    required String id,
    @Default('New Record') String name,
    @Default('NPC') String type,
    @Default('') String source,
    @Default('') String description,
    @Default([]) List<String> images,
    @Default('') String imagePath,
    @Default([]) List<String> battlemaps,
    @Default([]) List<String> tags,
    @Default({}) Map<String, dynamic> attributes,

    // Stats
    @Default(EntityStats()) EntityStats stats,
    @Default(CombatStats()) CombatStats combatStats,

    // Lists
    @Default([]) List<EntityAction> traits,
    @Default([]) List<EntityAction> actions,
    @Default([]) List<EntityAction> reactions,
    @Default([]) List<EntityAction> legendaryActions,

    // Spells
    @Default([]) List<String> spells,           // Linked spell entity ID'leri
    @Default([]) List<Map<String, dynamic>> customSpells,  // Inline spell verileri

    // Inventory
    @Default([]) List<String> equipmentIds,     // Linked equipment entity ID'leri
    @Default([]) List<Map<String, dynamic>> inventory,     // Inline inventory

    // Documents
    @Default([]) List<String> pdfs,
    String? locationId,

    @Default('') String dmNotes,

    // Advanced Stats
    @Default('') String savingThrows,
    @Default('') String damageVulnerabilities,
    @Default('') String damageResistances,
    @Default('') String damageImmunities,
    @Default('') String conditionImmunities,
    @Default('') String proficiencyBonus,
    @Default('') String passivePerception,
    @Default('') String skills,
  }) = _Entity;

  factory Entity.fromJson(Map<String, dynamic> json) => _$EntityFromJson(json);
}

@freezed
class EntityStats with _$EntityStats {
  const factory EntityStats({
    @Default(10) int str,
    @Default(10) int dex,
    @Default(10) int con,
    @Default(10) int int_,
    @Default(10) int wis,
    @Default(10) int cha,
  }) = _EntityStats;

  factory EntityStats.fromJson(Map<String, dynamic> json) => _$EntityStatsFromJson(json);
}

@freezed
class CombatStats with _$CombatStats {
  const factory CombatStats({
    @Default('') String hp,
    @Default('') String maxHp,
    @Default('') String ac,
    @Default('') String speed,
    @Default('') String cr,
    @Default('') String xp,
    @Default('') String initiative,
  }) = _CombatStats;

  factory CombatStats.fromJson(Map<String, dynamic> json) => _$CombatStatsFromJson(json);
}
```

### 3.2 Entity Tipi Şemaları (ENTITY_SCHEMAS)

15 entity tipi ve her birinin özel alanları (kaynak: `core/models.py:1-83`):

```dart
/// Her entity tipinin ek özel alanlarını tanımlar.
/// Python'daki ENTITY_SCHEMAS dict'inin karşılığı.
enum FieldType { text, combo, entitySelect }

class SchemaField {
  final String labelKey;     // Lokalizasyon anahtarı (ör. "LBL_RACE")
  final FieldType type;
  final dynamic options;     // combo: List<String>, entitySelect: String (hedef entity tipi), text: null

  const SchemaField(this.labelKey, this.type, this.options);
}

const Map<String, List<SchemaField>> entitySchemas = {
  'NPC': [
    SchemaField('LBL_RACE', FieldType.entitySelect, 'Race'),
    SchemaField('LBL_CLASS', FieldType.entitySelect, 'Class'),
    SchemaField('LBL_LEVEL', FieldType.text, null),
    SchemaField('LBL_ATTITUDE', FieldType.combo, ['LBL_ATTR_FRIENDLY', 'LBL_ATTR_NEUTRAL', 'LBL_ATTR_HOSTILE']),
    SchemaField('LBL_ATTR_LOCATION', FieldType.entitySelect, 'Location'),
  ],
  'Monster': [
    SchemaField('LBL_CR', FieldType.text, null),
    SchemaField('LBL_ATTACK_TYPE', FieldType.text, null),
  ],
  'Spell': [
    SchemaField('LBL_LEVEL', FieldType.combo, ['Cantrip', '1', '2', '3', '4', '5', '6', '7', '8', '9']),
    SchemaField('LBL_SCHOOL', FieldType.text, null),
    SchemaField('LBL_CASTING_TIME', FieldType.text, null),
    SchemaField('LBL_RANGE', FieldType.text, null),
    SchemaField('LBL_DURATION', FieldType.text, null),
    SchemaField('LBL_COMPONENTS', FieldType.text, null),
  ],
  'Equipment': [
    SchemaField('LBL_CATEGORY', FieldType.text, null),
    SchemaField('LBL_RARITY', FieldType.text, null),
    SchemaField('LBL_ATTUNEMENT', FieldType.text, null),
    SchemaField('LBL_COST', FieldType.text, null),
    SchemaField('LBL_WEIGHT', FieldType.text, null),
    SchemaField('LBL_DAMAGE_DICE', FieldType.text, null),
    SchemaField('LBL_DAMAGE_TYPE', FieldType.text, null),
    SchemaField('LBL_RANGE', FieldType.text, null),
    SchemaField('LBL_AC', FieldType.text, null),
    SchemaField('LBL_REQUIREMENTS', FieldType.text, null),
    SchemaField('LBL_PROPERTIES', FieldType.text, null),
  ],
  'Class': [
    SchemaField('LBL_HIT_DIE', FieldType.text, null),
    SchemaField('LBL_MAIN_STATS', FieldType.text, null),
    SchemaField('LBL_PROFICIENCIES', FieldType.text, null),
  ],
  'Race': [
    SchemaField('LBL_SPEED', FieldType.text, null),
    SchemaField('LBL_SIZE', FieldType.combo, ['Small', 'Medium', 'Large']),
    SchemaField('LBL_ALIGNMENT', FieldType.text, null),
    SchemaField('LBL_LANGUAGE', FieldType.text, null),
  ],
  'Location': [
    SchemaField('LBL_DANGER_LEVEL', FieldType.combo, ['LBL_DANGER_SAFE', 'LBL_DANGER_LOW', 'LBL_DANGER_MEDIUM', 'LBL_DANGER_HIGH']),
    SchemaField('LBL_ENVIRONMENT', FieldType.text, null),
  ],
  'Player': [
    SchemaField('LBL_CLASS', FieldType.entitySelect, 'Class'),
    SchemaField('LBL_RACE', FieldType.entitySelect, 'Race'),
    SchemaField('LBL_LEVEL', FieldType.text, null),
  ],
  'Quest': [
    SchemaField('LBL_STATUS', FieldType.combo, ['LBL_STATUS_NOT_STARTED', 'LBL_STATUS_ACTIVE', 'LBL_STATUS_COMPLETED']),
    SchemaField('LBL_GIVER', FieldType.text, null),
    SchemaField('LBL_REWARD', FieldType.text, null),
  ],
  'Lore': [
    SchemaField('LBL_CATEGORY', FieldType.combo, ['LBL_LORE_HISTORY', 'LBL_LORE_GEOGRAPHY', 'LBL_LORE_RELIGION', 'LBL_LORE_CULTURE', 'LBL_LORE_OTHER']),
    SchemaField('LBL_SECRET_INFO', FieldType.text, null),
  ],
  'Status Effect': [
    SchemaField('LBL_DURATION_TURNS', FieldType.text, null),
    SchemaField('LBL_EFFECT_TYPE', FieldType.combo, ['LBL_TYPE_BUFF', 'LBL_TYPE_DEBUFF', 'LBL_TYPE_CONDITION']),
    SchemaField('LBL_LINKED_CONDITION', FieldType.entitySelect, 'Condition'),
  ],
  'Feat': [
    SchemaField('LBL_PREREQUISITE', FieldType.text, null),
  ],
  'Background': [
    SchemaField('LBL_SKILL_PROFICIENCIES', FieldType.text, null),
    SchemaField('LBL_TOOL_PROFICIENCIES', FieldType.text, null),
    SchemaField('LBL_LANGUAGES', FieldType.text, null),
    SchemaField('LBL_EQUIPMENT', FieldType.text, null),
  ],
  'Plane': [
    SchemaField('LBL_TYPE', FieldType.text, null),
  ],
  'Condition': [
    SchemaField('LBL_EFFECTS', FieldType.text, null),
  ],
};
```

### 3.3 Legacy Uyumluluk

Mevcut Türkçe → İngilizce migration map'leri (kaynak: `core/models.py:86-151`) `lib/data/models/legacy_maps.dart` dosyasında tutulacak:

```dart
/// Eski Türkçe entity tip isimlerinden İngilizce'ye dönüşüm.
const Map<String, String> schemaMap = {
  'Canavar': 'Monster',
  'Büyü (Spell)': 'Spell',
  'Eşya (Equipment)': 'Equipment',
  // ... tüm 14 mapping
};

/// Eski Türkçe alan etiketlerinden lokalizasyon anahtarlarına dönüşüm.
const Map<String, String> propertyMap = {
  'Irk': 'LBL_RACE',
  'Sınıf': 'LBL_CLASS',
  // ... tüm 30+ mapping
};
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

### 6.5 Combat Table UI

```dart
class CombatTable extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final combatants = ref.watch(combatProvider.select((s) => s.sortedCombatants));
    final palette = Theme.of(context).extension<DmToolColors>()!;

    return ReorderableListView.builder(
      itemCount: combatants.length,
      onReorder: (oldIndex, newIndex) => ref.read(combatProvider.notifier).reorder(oldIndex, newIndex),
      itemBuilder: (context, index) {
        final c = combatants[index];
        final isActive = index == ref.watch(combatProvider).currentEncounter?.turnIndex;

        return ListTile(
          key: ValueKey(c.id),
          tileColor: isActive ? palette.tokenBorderActive.withOpacity(0.1) : null,
          leading: Text('${c.init}', style: TextStyle(fontWeight: FontWeight.bold)),
          title: Text(c.name),
          subtitle: Row(children: [
            Text('AC: ${c.ac}'),
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

### 7.3 Flutter Audio Engine — just_audio

```dart
class AudioEngine {
  // --- Music Decks ---
  late MusicDeck _deckA;
  late MusicDeck _deckB;
  late MusicDeck _activeDeck;
  late MusicDeck _inactiveDeck;

  // --- Crossfade ---
  double _masterVolume = 0.5;
  double _fadeRatio = 1.0;
  AnimationController? _fadeAnimation;

  // --- Ambience (4 slot) ---
  final List<AmbienceSlot> _ambienceSlots = List.generate(4, (_) => AmbienceSlot());
  final List<double> _ambienceSlotVolumes = List.filled(4, 0.7);

  // --- SFX (8 slot) ---
  final List<SfxSlot> _sfxPool = List.generate(8, (_) => SfxSlot());

  // State
  AudioTheme? _currentTheme;
  String? _currentStateId;
  int _intensityLevel = 0;

  /// Crossfade: 3 saniyelik InOutCubic animasyon
  Future<void> setState(String stateName) async {
    if (_currentTheme == null || stateName == _currentStateId) return;
    final targetState = _currentTheme!.states[stateName];
    if (targetState == null) return;

    // Inactive deck'e yeni state yükle
    await _inactiveDeck.loadState(targetState);
    _inactiveDeck.setIntensityMask(_getMaskForLevel(_intensityLevel));
    _inactiveDeck.setVolume(0.0);
    _inactiveDeck.play();

    // Deck'leri swap et
    final temp = _activeDeck;
    _activeDeck = _inactiveDeck;
    _inactiveDeck = temp;
    _currentStateId = stateName;

    // 3 saniyelik crossfade animasyonu
    await _animateFadeRatio(
      from: 0.0,
      to: 1.0,
      duration: const Duration(seconds: 3),
      curve: Curves.easeInOutCubic,
    );
  }

  void _updateVolumes() {
    _activeDeck.setVolume(_masterVolume * _fadeRatio);
    _inactiveDeck.setVolume(_masterVolume * (1.0 - _fadeRatio));
  }

  List<String> _getMaskForLevel(int level) {
    return ['base', ...List.generate(level, (i) => 'level${i + 1}')];
  }
}

/// Her deck birden fazla eşzamanlı AudioPlayer yönetir (intensity katmanları)
class MusicDeck {
  final Map<String, AudioPlayer> _players = {};
  List<String> _activeLevels = ['base'];
  double _targetVolume = 0.0;

  Future<void> loadState(MusicState state) async {
    await disposeAll();
    for (final entry in state.tracks.entries) {
      final player = AudioPlayer();
      if (entry.value.sequence.isNotEmpty) {
        await player.setFilePath(entry.value.sequence.first.filePath);
        await player.setLoopMode(LoopMode.all);
      }
      _players[entry.key] = player;
    }
  }

  void setIntensityMask(List<String> levels) {
    _activeLevels = levels;
    _updateMix();
  }

  void _updateMix() {
    for (final entry in _players.entries) {
      final target = _activeLevels.contains(entry.key) ? _targetVolume : 0.0;
      // 1.5 saniyelik fade
      entry.value.setVolume(target);
    }
  }
}
```

### 7.4 Ambience ve SFX

```dart
class AmbienceSlot {
  final AudioPlayer player = AudioPlayer();
  String? currentAmbienceId;

  Future<void> play(String filePath) async {
    await player.setFilePath(filePath);
    await player.setLoopMode(LoopMode.all);
    player.play();
  }

  Future<void> stop() async {
    await player.stop();
    currentAmbienceId = null;
  }
}

class SfxSlot {
  final AudioPlayer player = AudioPlayer();
  bool busy = false;

  Future<void> play(String filePath, double volume) async {
    busy = true;
    await player.setFilePath(filePath);
    await player.setVolume(volume);
    player.play();
    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        busy = false;
      }
    });
  }
}
```

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

### 9.1 Kampanya Verisi — MsgPack

Mevcut: `worlds/[CampaignName]/data.dat` (MsgPack binary)

```dart
class CampaignLocalDataSource {
  Future<Map<String, dynamic>> load(String campaignPath) async {
    final datFile = File(path.join(campaignPath, 'data.dat'));

    if (await datFile.exists()) {
      // MsgPack (birincil format)
      final bytes = await datFile.readAsBytes();
      return msgpack_dart.deserialize(bytes) as Map<String, dynamic>;
    }

    // JSON fallback (legacy)
    final jsonFile = File(path.join(campaignPath, 'data.json'));
    if (await jsonFile.exists()) {
      final content = await jsonFile.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    }

    throw CampaignNotFoundException(campaignPath);
  }

  Future<void> save(String campaignPath, Map<String, dynamic> data) async {
    final datFile = File(path.join(campaignPath, 'data.dat'));
    final bytes = msgpack_dart.serialize(data);
    await datFile.writeAsBytes(bytes);
  }
}
```

**Geriye uyumluluk:** `msgpack_dart` paketi Python'un `msgpack` kütüphanesiyle uyumlu format kullanır. Mevcut Python ile oluşturulan `.dat` dosyaları doğrudan okunabilir.

### 9.2 Kampanya Veri Yapısı

```dart
/// data.dat içeriğinin yapısı
/*
{
  "world_name": String,
  "entities": {
    "uuid-1": { ... entity fields ... },
    "uuid-2": { ... }
  },
  "map_data": {
    "image_path": String,
    "pins": [
      {"id": String, "x": double, "y": double, "entity_id": String, "color": String, "note": String}
    ],
    "timeline": [
      {"id": String, "x": double, "y": double, "day": int, "note": String,
       "parent_id": String?, "entity_ids": [String], "color": String?, "session_id": String?}
    ]
  },
  "sessions": [
    {
      "id": String,
      "name": String,
      "notes": String,
      "logs": String,
      "encounters": [
        {
          "id": String,
          "name": String,
          "combatants": [...],
          "round": int,
          "turn_index": int,
          "map_path": String?,
          "token_positions": {"token_id": {"x": double, "y": double}},
          "token_size": int,
          "token_size_overrides": {"token_id": int},
          "grid_size": int,
          "grid_visible": bool,
          "grid_snap": bool,
          "feet_per_cell": int,
          // fog_data ve annotation_data ayrı binary olarak saklanır
        }
      ]
    }
  ],
  "last_active_session_id": String?,
  "mind_maps": {
    "map_id": {
      "nodes": [...],
      "edges": [...],
      "undo_stack": [...]
    }
  }
}
*/
```

### 9.3 Dosya Yolu Çözümleme

Mevcut: `config.py` — `BASE_DIR`, `WORLDS_DIR`, `CACHE_DIR`, `SOUNDPAD_ROOT`

```dart
class AppPaths {
  static late String baseDir;
  static late String worldsDir;
  static late String cacheDir;
  static late String soundpadRoot;

  static Future<void> initialize() async {
    // Portable mode: exe yanında worlds/ dizini varsa onu kullan
    final exeDir = path.dirname(Platform.resolvedExecutable);
    final portableWorlds = Directory(path.join(exeDir, 'worlds'));

    if (await portableWorlds.exists()) {
      baseDir = exeDir;
    } else {
      // Platform-specific data dizini
      final appDocDir = await getApplicationDocumentsDirectory();
      baseDir = path.join(appDocDir.path, 'DungeonMasterTool');
    }

    worldsDir = path.join(baseDir, 'worlds');
    cacheDir = path.join(baseDir, 'cache');
    soundpadRoot = path.join(baseDir, 'assets', 'soundpad');

    // Dizinleri oluştur
    await Directory(worldsDir).create(recursive: true);
    await Directory(cacheDir).create(recursive: true);
  }

  /// Relatif yolu kampanya bazlı absolute yola çevir
  static String resolve(String relativePath, String campaignPath) {
    if (path.isAbsolute(relativePath)) return relativePath;
    return path.normalize(path.join(campaignPath, relativePath.replaceAll('\\', '/')));
  }
}
```

### 9.4 Ayarlar — SharedPreferences

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

### 9.5 API Cache — Dosya Tabanlı

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
└── settings.json
```

---

## 10. Online Mimari ve Database Şeması

### 10.1 Genel Bakış

Mevcut tasarım: `docs/ONLINE.md` (851 satır)

**Temel prensipler:**
1. **DM egemenliği** — Server oyun state'i değiştiremez; sadece DM kararlarını iletir
2. **Offline-first** — Online özellikler isteğe bağlı; tüm özellikler ağ olmadan çalışır
3. **Minimal oyuncu sürtünmesi** — 6 karakterlik kod + isim yeterli (hesap opsiyonel)
4. **Sıfır içerik sızıntısı** — Özel içerik sunucu tarafında filtrelenir
5. **Artımlı sync** — Delta event'ler, snapshot değil
6. **DM client kaynak** — Doğruluk kaynağı her zaman DM'in masaüstü uygulaması

### 10.2 Sunucu Stack

| Bileşen | Teknoloji | Amaç |
|---|---|---|
| API Server | FastAPI (Python) | REST + WebSocket gateway |
| WebSocket | python-socketio (async ASGI) | Real-time event relay |
| Database | PostgreSQL 16 | Kalıcı veri |
| Cache/PubSub | Redis 7 | Session cache, event broadcast |
| Asset Storage | MinIO (S3-uyumlu) | Görsel/PDF depolama |
| Auth | JWT (RS256) | Access (15 dk) + Refresh token |

### 10.3 PostgreSQL Database Şeması

```sql
-- ===================================================================
-- IDENTITY CONTEXT
-- ===================================================================

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,  -- bcrypt, cost=12
    display_name    VARCHAR(100) NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE refresh_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash      VARCHAR(255) NOT NULL,  -- SHA-256
    expires_at      TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT now(),
    revoked         BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);

-- ===================================================================
-- SESSION CONTEXT
-- ===================================================================

CREATE TABLE sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dm_user_id      UUID NOT NULL REFERENCES users(id),
    campaign_id     VARCHAR(255) NOT NULL,    -- Yerel kampanya klasör adı
    session_name    VARCHAR(255) NOT NULL,
    join_code       VARCHAR(6) UNIQUE,        -- Aktifken dolu, bitince NULL
    state           VARCHAR(20) NOT NULL DEFAULT 'waiting'
                    CHECK (state IN ('waiting', 'active', 'ended')),
    created_at      TIMESTAMPTZ DEFAULT now(),
    ended_at        TIMESTAMPTZ,
    current_snapshot JSONB                    -- Reconnect için son durum snapshot'ı
);

CREATE INDEX idx_sessions_join_code ON sessions(join_code) WHERE join_code IS NOT NULL;
CREATE INDEX idx_sessions_dm ON sessions(dm_user_id, created_at DESC);

CREATE TABLE session_participants (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    user_id         UUID,                     -- NULL = anonim oyuncu
    display_name    VARCHAR(100) NOT NULL,
    role            VARCHAR(20) NOT NULL DEFAULT 'PLAYER'
                    CHECK (role IN ('DM_OWNER', 'PLAYER', 'OBSERVER')),
    joined_at       TIMESTAMPTZ DEFAULT now(),
    disconnected_at TIMESTAMPTZ,
    is_connected    BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_participants_session ON session_participants(session_id);

-- ===================================================================
-- SYNC CONTEXT
-- ===================================================================

CREATE TABLE event_log (
    id              BIGSERIAL PRIMARY KEY,
    event_id        UUID NOT NULL UNIQUE,     -- Client-generated UUID (idempotency)
    session_id      UUID NOT NULL REFERENCES sessions(id),
    event_type      VARCHAR(100) NOT NULL,
    sender_id       UUID,                     -- Gönderen user_id
    sender_role     VARCHAR(20) NOT NULL,
    revision        BIGINT NOT NULL,          -- Session-bazlı monoton sayaç
    payload         JSONB NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_event_log_session_rev ON event_log(session_id, revision);
CREATE INDEX idx_event_log_session_type ON event_log(session_id, event_type);

-- ===================================================================
-- ASSETS CONTEXT
-- ===================================================================

CREATE TABLE assets (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID REFERENCES sessions(id),
    uploaded_by     UUID NOT NULL REFERENCES users(id),
    filename        VARCHAR(500) NOT NULL,
    mime_type       VARCHAR(100) NOT NULL,
    size_bytes      BIGINT NOT NULL,
    sha256_hash     VARCHAR(64) NOT NULL,
    minio_key       VARCHAR(500) NOT NULL,    -- MinIO object key
    created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_assets_session ON assets(session_id);
CREATE INDEX idx_assets_hash ON assets(sha256_hash);

-- ===================================================================
-- GAMEPLAY CONTEXT
-- ===================================================================

CREATE TABLE dice_rolls (
    id              BIGSERIAL PRIMARY KEY,
    session_id      UUID NOT NULL REFERENCES sessions(id),
    roller_id       UUID,
    roller_name     VARCHAR(100) NOT NULL,
    notation        VARCHAR(100) NOT NULL,    -- "2d6+3"
    individual_rolls INTEGER[] NOT NULL,      -- {4, 5}
    modifier        INTEGER DEFAULT 0,
    total           INTEGER NOT NULL,
    purpose         VARCHAR(255),             -- "Attack roll", "Saving throw"
    created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_dice_rolls_session ON dice_rolls(session_id, created_at);

-- ===================================================================
-- AUDIT LOG
-- ===================================================================

CREATE TABLE audit_log (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID,
    action          VARCHAR(100) NOT NULL,
    details         JSONB,
    ip_address      INET,
    created_at      TIMESTAMPTZ DEFAULT now()
);
```

### 10.4 24 Event Tipi (Freezed Classes)

Mevcut: `core/network/events.py` (225 satır)

```dart
// --- Event Envelope ---
@freezed
class EventEnvelope with _$EventEnvelope {
  const factory EventEnvelope({
    @Default('') String eventId,    // UUID
    required String eventType,
    String? sessionId,
    String? campaignId,
    required DateTime emittedAt,
    required Map<String, dynamic> payload,
  }) = _EventEnvelope;

  factory EventEnvelope.fromJson(Map<String, dynamic> json) =>
      _$EventEnvelopeFromJson(json);
}

// --- Campaign Payloads ---
@freezed class CampaignLoadedPayload with _$CampaignLoadedPayload { ... }
@freezed class CampaignSavedPayload with _$CampaignSavedPayload { ... }
@freezed class CampaignCreatedPayload with _$CampaignCreatedPayload { ... }

// --- Entity Payloads ---
@freezed class EntityCreatedPayload with _$EntityCreatedPayload {
  const factory EntityCreatedPayload({
    required String entityId,
    @Default('') String entityType,
    @Default('') String name,
  }) = _EntityCreatedPayload;
}
@freezed class EntityUpdatedPayload with _$EntityUpdatedPayload {
  const factory EntityUpdatedPayload({
    required String entityId,
    @Default([]) List<String> changedFields,
  }) = _EntityUpdatedPayload;
}
@freezed class EntityDeletedPayload with _$EntityDeletedPayload {
  const factory EntityDeletedPayload({
    required String entityId,
    @Default('') String entityType,
  }) = _EntityDeletedPayload;
}

// --- Session Payloads ---
@freezed class SessionCreatedPayload ...
@freezed class SessionActivatedPayload ...
@freezed class CombatantAddedPayload ...
@freezed class CombatantUpdatedPayload ...
@freezed class TurnAdvancedPayload ...

// --- Map Payloads ---
@freezed class MapImageSetPayload ...
@freezed class MapFogUpdatedPayload { fog_data: String (base64 PNG mask) }
@freezed class MapPinAddedPayload { pin_id, x, y, label }
@freezed class MapPinRemovedPayload { pin_id }

// --- MindMap Payloads ---
@freezed class MindMapNodeCreatedPayload { map_id, node_id, label, x, y }
@freezed class MindMapNodeUpdatedPayload { map_id, node_id, changes }
@freezed class MindMapNodeDeletedPayload { map_id, node_id }
@freezed class MindMapEdgeCreatedPayload { map_id, edge_id, source_id, target_id }
@freezed class MindMapEdgeDeletedPayload { map_id, edge_id }

// --- Projection Payloads ---
@freezed class ProjectionContentPayload { content_type: [map|entity|image|pdf|blank], content_ref }
@freezed class ProjectionModeChangedPayload { mode: [map|content] }

// --- Audio Payloads ---
@freezed class AudioStatePayload { theme, intensity, master_volume }
@freezed class AudioTrackTriggeredPayload { track_id, track_name }
```

### 10.5 NetworkBridge — Connection State Machine

```dart
enum ConnectionState { disconnected, connecting, connected, error }

class NetworkBridge {
  final AppEventBus _eventBus;
  ConnectionState _state = ConnectionState.disconnected;
  final List<EventEnvelope> _pendingQueue = [];
  io.Socket? _socket;

  /// Online'a yönlendirilecek event tipleri
  static const onlineEvents = {
    'entity.created', 'entity.updated', 'entity.deleted',
    'session.combatant_added', 'session.combatant_updated', 'session.turn_advanced',
    'map.image_set', 'map.fog_updated', 'map.pin_added', 'map.pin_removed',
    'mindmap.node_created', 'mindmap.node_updated', 'mindmap.node_deleted',
    'mindmap.edge_created', 'mindmap.edge_deleted',
    'projection.content_set', 'audio.state_changed',
  };

  void connect(String serverUrl, String token) { ... }
  void disconnect() { ... }

  void _onAnyEvent(AppEvent event) {
    if (!onlineEvents.contains(event.type)) return;
    final envelope = EventEnvelope(
      eventId: const Uuid().v4(),
      eventType: event.type,
      emittedAt: DateTime.now().toUtc(),
      payload: event.payload,
    );

    if (_state == ConnectionState.connected) {
      _send(envelope);
    } else {
      _pendingQueue.add(envelope);
    }
  }

  void _flushQueue() {
    for (final envelope in _pendingQueue) { _send(envelope); }
    _pendingQueue.clear();
  }
}
```

### 10.6 Sync Stratejisi

- **İlk katılım:** Tam state snapshot (harita, savaş, paylaşılan entity'ler, audio state)
- **Artımlı:** Sadece delta event'ler
- **Reconnect:** < 200 kaçırılan event → delta replay; > 200 → yeni snapshot
- **Rate limiting (client):** Fog 200ms/event, mind map 100ms/event
- **Rate limiting (server):** DM max 30 event/s, Player max 5 event/s
- **Delivery:** At-least-once, UUID-based idempotency

### 10.7 Permission Modeli

| Rol | Görebilecekler | Yapabilecekler |
|---|---|---|
| DM_OWNER | Her şey | Her şey |
| PLAYER | shared_full + shared_restricted | Zar at, condition bildir |
| OBSERVER | shared_full + shared_restricted | Sadece izle |

**Content visibility:**
- `private_dm` — Oyunculara asla gönderilmez (DM notes, gizli entity alanları)
- `shared_full` — Tam erişim (paylaşılan entity'ler, harita)
- `shared_restricted` — Kısıtlı alanlar (ör. HP yerine "Bloodied/Healthy" gösterilir)

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
| State Management | `flutter_riverpod` | ^2.5 | Provider'lar ve reaktif state |
| Code Generation | `riverpod_annotation` | ^2.3 | @riverpod annotation desteği |
| Immutable Models | `freezed_annotation` | ^2.4 | Freezed data class annotation'ları |
| JSON Serialization | `json_annotation` | ^4.9 | JSON serialization annotation'ları |
| HTTP Client | `dio` | ^5.4 | REST API çağrıları + interceptor'lar |
| WebSocket | `socket_io_client` | ^2.0 | Online session event relay |

### 16.2 Storage Paketleri

| Alan | Paket | Versiyon | Amaç |
|---|---|---|---|
| MsgPack | `msgpack_dart` | ^1.0 | Kampanya dosyası I/O (geriye uyumlu) |
| Settings | `shared_preferences` | ^2.2 | Kullanıcı ayarları |
| File Paths | `path_provider` | ^2.1 | Platform-specific dizinler |
| Path Utils | `path` | ^1.9 | Dosya yolu manipülasyonu |

### 16.3 UI Paketleri

| Alan | Paket | Versiyon | Amaç |
|---|---|---|---|
| Routing | `go_router` | ^14.0 | Declarative navigation |
| Markdown | `flutter_markdown` | ^0.7 | Markdown preview rendering |
| HTML | `flutter_html` | ^3.0 | Stat block HTML rendering |
| PDF | `pdfrx` | ^1.0 | PDF doküman görüntüleme |
| File Picker | `file_picker` | ^8.0 | Görsel/PDF import |
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
| Audio | `just_audio` | ^0.9 | Tüm audio playback (music, ambience, SFX) |

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

### Faz 0 — Foundation (Hafta 1-2)

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

### Faz 1 — Entity Management + Database Tab (Hafta 3-5)

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

### Faz 2 — Session + Combat Tracker (Hafta 6-7)

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

### Faz 3 — Battle Map (Hafta 8-10)

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

### Faz 4 — Mind Map (Hafta 11-12)

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

### Faz 5 — World Map + Soundpad + PDF (Hafta 13-14)

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

### Faz 8 — Online System (Hafta 18-21)

**Hedef:** Çevrimiçi oyun altyapısı

- [ ] `NetworkBridge` — connection state machine port'u
- [ ] 24 event payload Freezed class'ları
- [ ] `AppEventBus` → `NetworkBridge` wire
- [ ] `socket_io_client` entegrasyonu
- [ ] Connection status badge (durum çubuğunda gösterge)
- [ ] Sunucu kurulumu (FastAPI + PostgreSQL + Redis + MinIO)
- [ ] Database migration'ları (yukarıdaki şema)
- [ ] Auth akışı (JWT RS256, kayıt, giriş, refresh)
- [ ] Session create (DM) / join (Player, 6-char code)
- [ ] Event relay (server-side permission filtering)
- [ ] Snapshot + delta sync
- [ ] Reconnect handling
- [ ] Rate limiting (client + server)

**Doğrulama:** DM session oluşturur, player kod ile katılır, battle map gerçek zamanlı sync olur.

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
