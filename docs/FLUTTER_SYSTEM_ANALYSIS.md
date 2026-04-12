# Dungeon Master Tool — Flutter Sistem Analizi

> **Versiyon:** v4.0.0-beta+1
> **Son güncelleme:** 2026-04-12
> **Kapsam:** Frontend (Flutter/Dart) + Backend (Supabase + Drift) tam mimari analiz
> **Amaç:** Onboarding referansı, sprint planlama, teknik borç takibi

Bu döküman; uygulamanın kod organizasyonu, veri katmanı, özellik olgunluğu, build/CI tooling ve teknik borç durumunun **tek noktadan** görülebilmesi için hazırlanmıştır. Detaylı sprint planı için [FLUTTER_DEVELOPMENT_ROADMAP.md](FLUTTER_DEVELOPMENT_ROADMAP.md), kapsamlı mimari blueprint için [FLUTTER_MIGRATION_BLUEPRINT.md](FLUTTER_MIGRATION_BLUEPRINT.md), online stack ayrıntıları için [ONLINE_REPORT.md](ONLINE_REPORT.md) dökümanlarına bakın.

---

## İçindekiler

1. [Yönetici Özeti](#1-yönetici-özeti)
2. [Mimari Genel Bakış](#2-mimari-genel-bakış)
3. [Frontend — Presentation Katmanı](#3-frontend--presentation-katmanı)
4. [Application Katmanı — Riverpod State](#4-application-katmanı--riverpod-state)
5. [Domain Katmanı](#5-domain-katmanı)
6. [Backend — Supabase Katmanı](#6-backend--supabase-katmanı)
7. [Backend — Drift (Local) Katmanı](#7-backend--drift-local-katmanı)
8. [Data Katmanı — Datasources & Repositories](#8-data-katmanı--datasources--repositories)
9. [Özellik Olgunluk Matrisi](#9-özellik-olgunluk-matrisi)
10. [Hibrit Online/Offline Mimarisi](#10-hibrit-onlineoffline-mimarisi)
11. [Build, Tooling & CI/CD](#11-build-tooling--cicd)
12. [Test Durumu](#12-test-durumu)
13. [Kod Metrikleri & En Büyük Dosyalar](#13-kod-metrikleri--en-büyük-dosyalar)
14. [Teknik Borç & İyileştirme Alanları](#14-teknik-borç--iyileştirme-alanları)
15. [Roadmap Görünümü](#15-roadmap-görünümü)
16. [Ekler — Hızlı Navigasyon](#16-ekler--hızlı-navigasyon)

---

## 1. Yönetici Özeti

**Dungeon Master Tool**, tabletop RPG kampanya yönetimi için **offline-first**, çoklu platform destekli bir uygulamadır. Orijinal Python/PyQt6 v0.8.4 implementasyonu Flutter/Dart'a tamamen yeniden yazılmıştır. Beta v4.0.0 ile birlikte versiyonlanmış marketplace snapshot + lineage sistemi, sosyal hub, in-app yardım, ve UI polish süreçleri tamamlanmıştır.

### Proje Kimliği

| Alan | Değer |
| :--- | :--- |
| **Paket adı** | `dungeon_master_tool` |
| **Versiyon** | `4.0.0-beta+1` |
| **Dart SDK** | `^3.11.4` |
| **Flutter (CI pinned)** | `3.41.6` |
| **Lisans** | CC BY-NC 4.0 |
| **Mimari** | Clean Architecture (Domain / Data / Application / Presentation / Core) |
| **State Mgmt** | Riverpod (`flutter_riverpod 2.6.1`) |
| **Local DB** | Drift SQLite (`drift 2.22.1`) |
| **Online** | Supabase (`supabase_flutter 2.8.0`) — Postgres + Realtime + Storage + Auth |
| **Models** | Freezed + json_serializable |
| **Routing** | go_router 14.8.1 |
| **Audio** | flutter_soloud 3.1.0 (gapless game audio) |
| **PDF** | pdfrx 2.2.24 |
| **Diller** | EN / TR / DE / FR (4 lokal) |
| **Platformlar** | Android / iOS / Windows / Linux / macOS / Web |

### Kod Metrikleri (Snapshot — 2026-04-12)

| Metrik | Değer |
| :--- | ---: |
| Toplam Dart dosyası (`lib/`) | **296** |
| Toplam kod satırı (`lib/`) | **92,241** |
| Test dosyası (`test/`) | **14** |
| Lokalizasyon (her dil) | ~340 anahtar |
| Supabase migration | **6** SQL dosyası |
| Drift tablo sayısı | **14** |
| Riverpod provider dosyası | **25** |
| Ana ekran (screen) sayısı | **13** klasör + 2 kök ekran |

### Sprint Durumu (Hızlı Bakış)

| Sprint | Konu | Durum |
| :---: | :--- | :---: |
| 0 | Foundation, schema migration | ✅ 100% |
| 1 | Schema-driven entity card | ✅ 100% |
| 2 | Field widgets + templates | ✅ 100% |
| 3 | Session + combat tracker | ✅ 100% |
| 4 | Battle map (6 katman) | ✅ 100% |
| 5 | Mind map + world map | ⚠️ ~85% |
| 6 | Soundpad + PDF + polish | ⚠️ ~40% |
| 7 | Dual screen + mobile polish | ⏳ ~5% |
| 8 | API integration + library | ⏳ |
| 9 | Online: Supabase NetworkBridge | ⚠️ ~25% |
| 10–12 | Sync + gameplay + deploy | ⏳ |

---

## 2. Mimari Genel Bakış

Uygulama klasik **Clean Architecture** akışını izler. Bağımlılıklar yalnızca dış katmandan iç katmana doğrudur (`presentation → application → domain ← data`). `core/` framework-agnostik yardımcılar barındırır.

```
┌─────────────────────────────────────────────────────┐
│  presentation/   Widgets, Screens, Dialogs, l10n    │
│         ↓ ref.watch / ref.read                      │
├─────────────────────────────────────────────────────┤
│  application/    Riverpod providers + services      │
│         ↓ uses repositories / DAOs                  │
├──────────────────────┬──────────────────────────────┤
│  domain/             │  data/                       │
│  Pure Dart entities, │  Drift (local) +             │
│  events, contracts   │  Supabase (remote) impl      │
│                      │  + datasources + services    │
└──────────────────────┴──────────────────────────────┘
                  ↑
           core/ — config, errors, extensions, utils
```

### Katman Dosya Dağılımı

| Katman | Yaklaşık Dosya Sayısı | Rol |
| :--- | ---: | :--- |
| `domain/` | ~89 | Freezed entity'ler, event tipleri, abstract sözleşmeler |
| `data/` | ~57 | Drift tabloları/DAO'ları, remote/local datasources, services |
| `application/` | ~40 | Riverpod provider'lar, application services |
| `presentation/` | ~102 | Screens, widgets, dialogs, theme, l10n, router |
| `core/` | ~30 | Config, constants, extensions, errors, utilities |

### `lib/` Klasör Ağacı

```
flutter_app/lib/
├── main.dart                  # Entry point — ProviderScope, window setup
├── app.dart                   # MaterialApp.router, tema, lokalizasyon
├── core/
│   ├── config/                # AppConfig, app paths, supabase config
│   ├── constants/             # DB & UI constants
│   ├── errors/                # AppException tipleri
│   ├── extensions/            # Context, string, number ext'leri
│   ├── services/              # Settings, library, profanity, rule engine
│   └── utils/                 # screen_type, deep_copy
│
├── domain/
│   ├── entities/              # 89 Freezed model
│   │   ├── events/            # event_envelope, event_types, game_snapshot
│   │   ├── projection/        # battle_map_snapshot, entity_snapshot
│   │   └── ...                # campaign, entity, session, mind_map, audio,
│   │                          # marketplace_listing, map_data, package_info...
│   ├── exceptions/
│   ├── repositories/          # (minimal — interface'ler büyük ölçüde provider'larda)
│   └── usecases/              # (TODO — şu an provider'larda inline)
│
├── data/
│   ├── database/              # Drift SQLite root
│   │   ├── app_database.dart
│   │   ├── tables/            # 14 tablo tanımı
│   │   └── daos/              # CampaignDao, EntityDao, SessionDao, MapDao, MindMapDao
│   ├── datasources/
│   │   ├── local/             # campaign/template/package/marketplace_links local DS
│   │   └── remote/            # cloud_backup, posts, messages, profiles, follows,
│   │                          # game_listings, marketplace_listings remote DS
│   ├── repositories/          # Repository implementations
│   ├── network/               # NetworkBridge abstract + NoOp impl
│   ├── schema/                # default_dnd5e_schema.dart (15 D&D 5e kategori)
│   └── services/              # marketplace_sync, snapshot builders, state_snapshot
│
├── application/
│   ├── providers/             # 25 Riverpod provider
│   └── services/              # audio_engine, app_event_bus, …
│
└── presentation/
    ├── screens/               # 13 alt klasör + 2 kök screen
    ├── widgets/               # field_widgets/, sidebar'lar, panel'ler
    ├── dialogs/               # publish_snapshot, marketplace_*, theme_builder, …
    ├── theme/                 # DmToolColors, theme extensions
    ├── l10n/                  # app_en/tr/de/fr.arb + generated stubs
    └── router/                # app_router.dart (go_router)
```

---

## 3. Frontend — Presentation Katmanı

### 3.1 Ana Ekranlar (`lib/presentation/screens/`)

| Klasör / Dosya | Amaç |
| :--- | :--- |
| [landing/](../flutter_app/lib/presentation/screens/landing/) | İlk açılış ekranı |
| [campaign_selector/](../flutter_app/lib/presentation/screens/campaign_selector/) | Mevcut kampanyaların seçimi/oluşturma |
| [main_screen.dart](../flutter_app/lib/presentation/screens/main_screen.dart) | Kök tab navigasyonu (oturum sırasında) |
| [session/](../flutter_app/lib/presentation/screens/session/) | Combat tracker + event log + sahne yönetimi |
| [battle_map/](../flutter_app/lib/presentation/screens/battle_map/) | 6 katmanlı battle map (grid/token/annotation/fog/terrain/decal) |
| [mind_map/](../flutter_app/lib/presentation/screens/mind_map/) | Sonsuz canvas mind map (LOD render, Bézier edges) |
| [map/](../flutter_app/lib/presentation/screens/map/) | Dünya haritası — pin & timeline |
| [hub/](../flutter_app/lib/presentation/screens/hub/) | Worlds / Templates / Packages / Settings tab grubu |
| [social/](../flutter_app/lib/presentation/screens/social/) | Feed / Marketplace / Messages / Players (Supabase ağ katmanı) |
| [database/](../flutter_app/lib/presentation/screens/database/) | Entity browser (kampanya içi varlık veritabanı) |
| [player_window/](../flutter_app/lib/presentation/screens/player_window/) | İkinci ekran projeksiyon penceresi (dual-screen) |
| [profile/](../flutter_app/lib/presentation/screens/profile/) | Kullanıcı profil sayfası |
| [admin/](../flutter_app/lib/presentation/screens/admin/) | Admin paneli (gate'li) |
| [package_screen.dart](../flutter_app/lib/presentation/screens/package_screen.dart) | Paket detay ekranı |

### 3.2 Hub Tab Yapısı

`hub/` ve `social/` altında, iç içe sekme bazlı bir kabuk vardır:

- **Hub sekmeleri:** `worlds_tab`, `templates_tab`, `packages_tab`, `settings_tab`. Her tab'ın AppBar'ında **HelpIconButton** (`?`) ile açılan, lokalize in-app yardım dialog'u bulunur.
- **Social shell** (`social_shell.dart`): `feed_tab`, `marketplace_tab`, `messages_tab`, `players_tab` sekmelerini barındırır. Marketplace sekmesi snapshot publish + my snapshots paneline ev sahipliği yapar.
- Desktop sol kenar çubuğu, `NavigationRail` yerine 56 dp genişliğindeki özel `_HubSideRail` widget'ı ile çizilir (Material varsayılanı 72 dp).

### 3.3 Widget Kütüphanesi (`lib/presentation/widgets/`)

| Widget | Amaç |
| :--- | :--- |
| `field_widgets/field_widget_factory.dart` | 16 farklı field tipini şema bazlı render eden fabrika |
| `field_widgets/markdown_field_widget.dart` | Edit/preview toggle markdown alanı |
| `field_widgets/image_field_widget.dart` + `image_gallery.dart` | Çoklu görsel + zoom |
| `field_widgets/dice_roller_field_widget.dart` | Inline zar atışı |
| `field_widgets/tag_field_widget.dart`, `date_field_widget.dart` | Tag chip / tarih |
| `marketplace_panel.dart` | Item settings dialog'larında "Share to Marketplace" alanı |
| `my_snapshots_panel.dart` | Bir öğenin yayınlanmış snapshot tarihçesi |
| `hp_bar.dart`, `condition_badge.dart` | Combat tracker görselleri |
| `entity_sidebar.dart`, `pdf_sidebar.dart`, `soundmap_sidebar.dart` | Yan paneller |
| `resizable_split.dart` | Sürükleme ile boyutlanan split-view |
| `global_loading_overlay.dart`, `save_sync_indicator.dart` | Global UI durum göstergeleri |

**Şu anda desteklenen 16 field tipi** (factory üzerinden): text, markdown, image, file/PDF, stat block, dice roller, tag, date, number, boolean, selection (dropdown), multi-selection, color picker, rich text, phone/email, URL.

### 3.4 Dialog Kataloğu (`lib/presentation/dialogs/`)

| Dialog | Akış |
| :--- | :--- |
| `publish_snapshot_dialog.dart` | Marketplace yayını: title, description, language, tags, changelog + "Start fresh lineage" toggle |
| `marketplace_update_prompt_dialog.dart` | Yeni snapshot bildirimi: changelog gösterir, **replace local copy** veya **download as new copy** seçimi |
| `marketplace_preview_dialog.dart` | Listeleme önizlemesi (görsel, açıklama, lineage geçmişi) |
| `entity_selector_dialog.dart` | Entity seçici (kampanyadan veya pakettenden) |
| `import_dialog.dart` | `.dmt` paket import akışı |
| `theme_builder_dialog.dart` | Custom theme oluşturma |
| `profile_edit_dialog.dart` | Kullanıcı profil düzenleme |
| `confirm_sign_out_dialog.dart` | Oturum kapatma onayı |

### 3.5 Routing — `lib/presentation/router/app_router.dart`

`go_router` tabanlı, kampanya kimliğini path parameter olarak taşır. Auth state ve kampanya seçim guard'ları routing seviyesinde kontrol edilir. Player window dual-screen modunda ayrı bir `MaterialApp.router` instance'ı ile çalışır.

### 3.6 Tema (`lib/presentation/theme/`)

- **`DmToolColors`** ThemeExtension: 80+ semantik renk değişkeni (primary, surface, accent, hp_full, hp_low, condition_*, …).
- **11 tema varyantı** (her biri light + dark): Indigo, Deep Purple, Cyan, Teal, Green, Amber, Orange, Red, Pink, Blue Grey, Grey.
- Custom theme builder dialog ile kullanıcı kendi temasını oluşturabilir.
- Tema seçimi `theme_provider.dart` üzerinden persist edilir (`shared_preferences`).

### 3.7 Lokalizasyon (`lib/presentation/l10n/`)

- **4 dil:** İngilizce (`app_en.arb`), Türkçe (`app_tr.arb`), Almanca (`app_de.arb`), Fransızca (`app_fr.arb`).
- ARB başına ~340 anahtar; beta v4.0.0 sprintinde marketplace snapshot, update prompt, my-snapshots ve help dialog'ları için ~80 yeni key eklendi.
- `flutter gen-l10n` ile `app_localizations*.dart` üretilir.
- Fallback placeholder yok — her key dört dilde tam çeviridir.

---

## 4. Application Katmanı — Riverpod State

### 4.1 Provider Envanteri (25 Provider)

`lib/application/providers/` altındaki provider dosyaları:

| Provider | Kategori | Ana Sorumluluk |
| :--- | :--- | :--- |
| [admin_provider.dart](../flutter_app/lib/application/providers/admin_provider.dart) | Auth | Admin role gate kontrolü |
| [auth_provider.dart](../flutter_app/lib/application/providers/auth_provider.dart) | Auth | Supabase session + sign in/up/out |
| [user_session_provider.dart](../flutter_app/lib/application/providers/user_session_provider.dart) | Auth | Aktif kullanıcı bilgisi cache |
| [profile_provider.dart](../flutter_app/lib/application/providers/profile_provider.dart) | Auth | Profil düzenleme state |
| [campaign_provider.dart](../flutter_app/lib/application/providers/campaign_provider.dart) | Domain | Aktif kampanya seçimi & CRUD |
| [entity_provider.dart](../flutter_app/lib/application/providers/entity_provider.dart) | Domain | Şema-tabanlı entity CRUD |
| [combat_provider.dart](../flutter_app/lib/application/providers/combat_provider.dart) | Gameplay | Encounter, combatant, turn, HP, conditions |
| [template_provider.dart](../flutter_app/lib/application/providers/template_provider.dart) | Domain | Şablon CRUD + editör state |
| [package_provider.dart](../flutter_app/lib/application/providers/package_provider.dart) | Domain | Paket CRUD + import/export |
| [soundpad_provider.dart](../flutter_app/lib/application/providers/soundpad_provider.dart) | Audio | Layered audio engine state |
| [projection_provider.dart](../flutter_app/lib/application/providers/projection_provider.dart) | Dual screen | Player window view kontrolü |
| [projection_output_provider.dart](../flutter_app/lib/application/providers/projection_output_provider.dart) | Dual screen | Output rendering state |
| [marketplace_listing_provider.dart](../flutter_app/lib/application/providers/marketplace_listing_provider.dart) | Online | Snapshot publish + lineage + update prompts |
| [cloud_sync_provider.dart](../flutter_app/lib/application/providers/cloud_sync_provider.dart) | Online | Genel sync durumu indicator |
| [cloud_backup_provider.dart](../flutter_app/lib/application/providers/cloud_backup_provider.dart) | Online | Bulut yedekleme akışı |
| [social_providers.dart](../flutter_app/lib/application/providers/social_providers.dart) | Online | Posts, conversations, messages, listings |
| [follows_provider.dart](../flutter_app/lib/application/providers/follows_provider.dart) | Online | Takip toggle + listeleri |
| [media_provider.dart](../flutter_app/lib/application/providers/media_provider.dart) | Cache | Görsel/medya cache |
| [event_bus_provider.dart](../flutter_app/lib/application/providers/event_bus_provider.dart) | Cross-cutting | `AppEventBus` exposure |
| [theme_provider.dart](../flutter_app/lib/application/providers/theme_provider.dart) | UI | 11 tema seçimi + persist |
| [locale_provider.dart](../flutter_app/lib/application/providers/locale_provider.dart) | UI | 4 dil seçimi + persist |
| [ui_state_provider.dart](../flutter_app/lib/application/providers/ui_state_provider.dart) | UI | Dialog/panel açık-kapalı durumu |
| [undo_redo_provider.dart](../flutter_app/lib/application/providers/undo_redo_provider.dart) | UX | Undo/redo stack |
| [save_state_provider.dart](../flutter_app/lib/application/providers/save_state_provider.dart) | UX | "Kaydedildi / sync ediliyor" indicator |
| [global_loading_provider.dart](../flutter_app/lib/application/providers/global_loading_provider.dart) | UX | Global loading overlay yönetimi |

### 4.2 Kritik Notifier'lar — Detay

- **`combat_provider`** — `CombatNotifier` (StateNotifier). Encounter ekleme, combatant initiative sıralama, HP delta, condition ekle/sil, turn advance, event log üretimi. 51 unit testle kaplı.
- **`marketplace_listing_provider`** — Snapshot publish akışı, lineage chain takip, no-op publish detection, mute/dismiss state, "imported from @owner" drift banner verisi.
- **`cloud_sync_provider` + `cloud_backup_provider`** — `cloud_backups` tablosuna gzipped state snapshot upload/download, RLS user-scoped okuma, conflict free overwrite stratejisi.
- **`soundpad_provider`** — `audio_engine.dart` (flutter_soloud wrapper) üzerinde layered track playback, gapless loop, fade volume kontrolü.
- **`projection_provider`** — Dual-screen modunda hangi içeriğin (battle map, mind map, image, blank) player window'a yansıtılacağını yönetir. Sprint 7 hedefi.
- **`auth_provider`** — Supabase auth state stream'ini Riverpod state'ine bağlar; routing guard'ları ve sosyal feature gating bu provider'a watch eder.

### 4.3 Application Services (`lib/application/services/`)

- **`audio_engine.dart`** — `flutter_soloud` initialize, track register, layered mixer kontrolü.
- **`app_event_bus.dart`** — Cross-cutting event yayını: domain mutation → UI snackbar / log / online relay.

`marketplace_sync_service.dart`, `battle_map_snapshot_builder.dart`, `entity_snapshot_builder.dart`, `state_snapshot_service.dart` ise [data/services/](../flutter_app/lib/data/services/) altında yaşar (bkz. §8).

---

## 5. Domain Katmanı

### 5.1 Entity Kataloğu

`lib/domain/entities/` altında ~89 dosya bulunur. Tüm entity'ler Freezed `@freezed` ile immutable ve `fromJson`/`toJson` üretir.

### 5.2 Ana Entity'ler

| Entity | Konum | Açıklama |
| :--- | :--- | :--- |
| `Campaign` | [campaign.dart](../flutter_app/lib/domain/entities/campaign.dart) | Kampanya kök modeli — name, description, schema, entities |
| `Entity` | [entity.dart](../flutter_app/lib/domain/entities/entity.dart) | Şema-driven varlık (NPC, item, location, vb.) |
| `Session`, `Encounter`, `Combatant` | [session.dart](../flutter_app/lib/domain/entities/session.dart) | Combat tracker veri yapıları |
| `MindMap` (nodes/edges) | [mind_map.dart](../flutter_app/lib/domain/entities/mind_map.dart) | Sonsuz canvas mind map state |
| `MapData` | [map_data.dart](../flutter_app/lib/domain/entities/map_data.dart) | Dünya haritası, pinler, timeline |
| `MarketplaceListing` | [marketplace_listing.dart](../flutter_app/lib/domain/entities/marketplace_listing.dart) | Snapshot + `lineage_id`, `is_current`, `superseded_by` |
| `PackageInfo` | [package_info.dart](../flutter_app/lib/domain/entities/package_info.dart) | Paket meta verisi |
| `UserProfile` | profil ve sosyal alanlar | |
| `EventEnvelope` | [events/event_envelope.dart](../flutter_app/lib/domain/entities/events/event_envelope.dart) | Cross-cutting event wire format |
| `AudioModels` | [audio/](../flutter_app/lib/domain/entities/audio/) | Soundpad theme, track, layer modelleri |

### 5.3 Event Tipleri — `domain/entities/events/event_types.dart`

24 sabit event tipi tanımlıdır: ENTITY_CREATED/UPDATED/DELETED, COMBAT_TURN_ADVANCED, COMBATANT_HP_CHANGED, MAP_PIN_ADDED/MOVED, MIND_MAP_NODE_CREATED, MIND_MAP_EDGE_ADDED, SOUNDPAD_TRACK_PLAYED, AUDIO_STATE_CHANGED ve diğer cross-cutting akışlar.

`EventEnvelope` her event için `forwardToOnline` flag'i taşır — Supabase Realtime'a relay edilip edilmeyeceğini belirler.

### 5.4 Repository Interface'leri

Şu an formal abstract repository interface'leri minimum düzeyde (`domain/repositories/` neredeyse boş). Uygulamada repository sözleşmeleri büyük ölçüde provider'lar içinde inline şekilde tutulmakta, data implementasyonları doğrudan DAO + remote DS'leri çağırmakta. Sprint 9 sonrası bu sözleşmeleri formalleştirmek planlı bir teknik borçtur.

---

## 6. Backend — Supabase Katmanı

### 6.1 Migration Haritası

`supabase/migrations/` altında 6 SQL dosyası vardır. Her biri additive — Drift schema'sıyla birebir ayna olacak şekilde tasarlanmıştır.

| Migration | İçerik |
| :--- | :--- |
| **001_cloud_backups.sql** | `cloud_backups` tablosu (user_id, item_id, type, storage_path, size_bytes, entity_count, schema_version). RLS: "Users manage own backups" (`auth.uid() = user_id`). Storage bucket: `campaign-backups` (private). Index: `(user_id, created_at DESC)`, `(user_id, type)`, `(user_id, item_id, type)`. |
| **002_community_assets.sql** | Topluluk varlık deposu temel şeması. |
| **003_social.sql** | `profiles`, `follows`, `posts`, `conversations`, `messages` — sosyal ağ çekirdeği. Realtime channel kullanımı için RLS politikaları. |
| **004_likes_and_storage.sql** | `post_likes` + ek storage bucket'ları (avatar, post images). |
| **005_game_listings_and_marketplace.sql** | `game_listings` + apply/applications akışı. İlk marketplace iskeletinin (`shared_items`) eklendiği migration. |
| **006_marketplace_listings.sql** | Beta v4.0.0 — eski `shared_items` tablosu DROP edilir; **`marketplace_listings`** tablosu (`lineage_id`, `is_current`, `superseded_by`). RPC: **`publish_marketplace_snapshot`** — atomik insert + previous current row's `superseded_by` update + flip `is_current`. RLS: public read on current snapshots, owner-only writes. Index: "current listings per lineage" + "by owner / by type". Storage bucket `shared-payloads` (gzipped snapshot payloads, 3.0'dan reuse). |

### 6.2 Auth Akışı

- `supabase_flutter` başlangıçta `main.dart` içinde initialize edilir (URL + anon key dart-define ile inject).
- Session persist `shared_preferences` üzerinden Supabase SDK tarafından otomatik yönetilir.
- `auth_provider.dart` Supabase auth state stream'ini Riverpod'a expose eder; routing guard'ları ve sosyal feature gating bu provider'a watch eder.

### 6.3 Realtime

- **Messaging:** `messages_remote_ds.dart` üzerinden conversation channel subscription.
- **Game listings:** Apply/listing güncellemeleri için kanal aboneliği.

### 6.4 Storage Bucket'lar

| Bucket | Amaç | Görünürlük |
| :--- | :--- | :--- |
| `campaign-backups` | Kullanıcı kampanya yedekleri (gzipped state) | Private (user-scoped) |
| `shared-payloads` | Marketplace snapshot payload'ları (gzipped) | Public read (current snapshot) |
| Avatar / post image bucket'lar | Sosyal feature görselleri | Public read |

---

## 7. Backend — Drift (Local) Katmanı

### 7.1 Tablo Envanteri (14 Tablo)

`lib/data/database/tables/`:

| Tablo | Amaç |
| :--- | :--- |
| `campaigns_table.dart` | Kampanya kök kaydı |
| `world_schemas_table.dart` | Şema (kategori + field) tanımları |
| `entities_table.dart` | Şema-driven varlıklar |
| `sessions_table.dart` | Oyun oturumları |
| `encounters_table.dart` | Savaş ayarları |
| `combatants_table.dart` | Initiative sıralı combatants |
| `combat_conditions_table.dart` | Status effects (poisoned, blessed vb.) |
| `map_pins_table.dart` | Dünya harita pinleri |
| `timeline_pins_table.dart` | Timeline olayları (epoch yönetimi) |
| `mind_map_nodes_table.dart` | Mind map node'ları |
| `mind_map_edges_table.dart` | Mind map bağlantıları |
| `packages_table.dart` | Paket kayıtları |
| `package_schemas_table.dart` | Pakete ait şemalar |
| `package_entities_table.dart` | Pakete ait entity'ler |

### 7.2 DAO Haritası

`lib/data/database/daos/`:

| DAO | Operasyonlar |
| :--- | :--- |
| `CampaignDao` | insert/update/delete + watchAll/watchById |
| `EntityDao` | insert/update/delete + watchByCategory + arama |
| `SessionDao` | session + encounter + combatant + condition CRUD |
| `MapDao` | map_pin + timeline_pin watch/CRUD |
| `MindMapDao` | node + edge insert/delete/watch |

### 7.3 Schema & Migration

- Generated `app_database.g.dart` ~17K satır (drift_dev tarafından üretilir).
- Schema versiyonu Drift `MigrationStrategy` ile yönetilir; legacy `.dmt` (MsgPack) paketler migration kodu üzerinden Drift'e yüklenir (Sprint 0 kapsamında).
- Local schema ile Supabase migration'lar birebir ayna kalacak şekilde tutulur — bu sayede `cloud_backup` upload/download tek yönlü serialize ile yapılabilir.

---

## 8. Data Katmanı — Datasources & Repositories

### 8.1 Remote Datasources (`lib/data/datasources/remote/`)

| Datasource | Sorumluluk |
| :--- | :--- |
| `cloud_backup_remote_ds.dart` | `cloud_backups` tablo + storage bucket upload/download |
| `posts_remote_ds.dart` | Sosyal feed post CRUD + like |
| `messages_remote_ds.dart` | Conversations, messages, realtime channel subscription |
| `profiles_remote_ds.dart` | Profil okuma/yazma + arama |
| `follows_remote_ds.dart` | Follow / unfollow + listeler |
| `game_listings_remote_ds.dart` | "Looking for group" oyun ilanları + applications |
| `marketplace_listings_remote_ds.dart` | `marketplace_listings` CRUD + `publish_marketplace_snapshot` RPC çağrısı |

### 8.2 Local Datasources (`lib/data/datasources/local/`)

| Datasource | Sorumluluk |
| :--- | :--- |
| `campaign_local_ds.dart` | Drift CampaignDao üzerinden kampanya CRUD |
| `template_local_ds.dart` | Şablon CRUD (Drift) |
| `package_local_ds.dart` | Paket import/export Drift entegrasyonu |
| `marketplace_links_local_ds.dart` | İndirilen marketplace öğelerinin lineage bağlarını tutan local index |

### 8.3 Network Bridge

[lib/data/network/network_bridge.dart](../flutter_app/lib/data/network/network_bridge.dart) (abstract) ve `no_op_network_bridge.dart` (production default) mevcuttur. **Supabase backed `SupabaseNetworkBridge` — Sprint 9 hedefi (TODO).** EventEnvelope stream'i bu bridge üzerinden Realtime'a relay edilecek; presence ve session-code tabanlı multiplayer Sprint 9-10 kapsamı.

### 8.4 Data Services (`lib/data/services/`)

- **`marketplace_sync_service.dart`** — Snapshot publish akışını koordine eder: payload build → gzip → storage upload → RPC çağrısı → local lineage index update.
- **`battle_map_snapshot_builder.dart`** — Battle map state'ini wire format'a çevirir (dual-screen + cloud backup).
- **`entity_snapshot_builder.dart`** — Entity diff snapshot'ı.
- **`state_snapshot_service.dart`** — Kampanya genel state snapshot servisi (cloud backup + projection).

---

## 9. Özellik Olgunluk Matrisi

| Özellik | Sprint | Tamamlanma | Ana Konum | Eksik / TODO |
| :--- | :---: | :---: | :--- | :--- |
| **Combat Tracker** | 3 | ✅ 100% | [session/](../flutter_app/lib/presentation/screens/session/) + [combat_provider.dart](../flutter_app/lib/application/providers/combat_provider.dart) | — |
| **Battle Map** (6 katman) | 4 | ✅ 100% | [battle_map/](../flutter_app/lib/presentation/screens/battle_map/) | Performans benchmark eksik |
| **Mind Map** | 5 | ⚠️ ~85% | [mind_map/](../flutter_app/lib/presentation/screens/mind_map/) | Persistence `state_json` blob'da; normalize tablolara taşıma TODO |
| **World Map** | 5 | ⚠️ ~85% | [map/world_map_screen.dart](../flutter_app/lib/presentation/screens/map/) | Aynı persistence borcu |
| **Entity System** (16 field) | 2 | ✅ 100% | [field_widgets/](../flutter_app/lib/presentation/widgets/field_widgets/) | — |
| **Templates + Packages** | 2 | ✅ 100% | [hub/](../flutter_app/lib/presentation/screens/hub/) | — |
| **Marketplace Snapshot + Lineage** | 8+ | ✅ ~90% | [marketplace_listing_provider.dart](../flutter_app/lib/application/providers/marketplace_listing_provider.dart) + [006_marketplace_listings.sql](../supabase/migrations/006_marketplace_listings.sql) | İleri test coverage |
| **Social Hub** (Feed/Messages/Players) | 8 | ✅ ~90% | [social/](../flutter_app/lib/presentation/screens/social/) + [social_providers.dart](../flutter_app/lib/application/providers/social_providers.dart) | İleri test, moderation |
| **Soundpad** | 6 | ⚠️ ~40% | [soundpad_provider.dart](../flutter_app/lib/application/providers/soundpad_provider.dart) + audio_engine | SoundpadPanel UI + YAML loader UI TODO |
| **PDF Viewer** | 6 | ✅ 100% | `pdf_sidebar.dart` (pdfrx) | — |
| **Dual Screen / Player Window** | 7 | ⚠️ ~5% | [player_window/](../flutter_app/lib/presentation/screens/player_window/) + projection_provider | Notifier + persistence + UI eksik |
| **Settings + Localization + Theme** | — | ✅ 100% | hub/settings_tab + theme/ + l10n/ | — |
| **Online Sync (Supabase)** | 9 | ⚠️ ~25% | [network/](../flutter_app/lib/data/network/) | `SupabaseNetworkBridge` impl yok |
| **In-app Help (HelpIconButton)** | 8+ | ✅ 100% | hub/social tab AppBar'larında | — |

---

## 10. Hibrit Online/Offline Mimarisi

### 10.1 Prensip

Drift SQLite **primary** veri kaynağıdır. Supabase aynı şemanın online aynası olarak çalışır. `NetworkBridge` arabiriminin üretim varsayılanı `NoOpNetworkBridge`'tir — yani **online özellikler tamamen opt-in**, internet olmasa da uygulama çalışır.

### 10.2 Snapshot Publish Akışı

`PublishSnapshotDialog` → `marketplace_listing_provider.publishSnapshot(...)` → `marketplace_sync_service.dart`:

1. **Payload build:** İlgili local item (world / template / package) Drift'ten okunur, JSON → gzip.
2. **Storage upload:** `shared-payloads` bucket'ına gzipped payload yüklenir.
3. **Atomic RPC:** `publish_marketplace_snapshot` RPC çağrısı:
   - Önceki "current" satırı bulup `superseded_by = new_id`, `is_current = false` yapar.
   - Yeni satırı `is_current = true`, aynı `lineage_id` ile insert eder.
   - "Start fresh lineage" toggle'lı ise yeni `lineage_id` üretir.
4. **No-op detection:** Hash karşılaştırması ile değişmemiş içerik için yayın engellenir, lokalize SnackBar gösterilir.
5. **Local index update:** `marketplace_links_local_ds` indeksi güncellenir, my snapshots paneline reflection.

### 10.3 Update Prompt Akışı

`marketplace_update_prompt_dialog.dart` ve `marketplaceUpdatePromptProvider`:

```
Local item lineage_id var
       ↓
Polling / on-open check → Supabase'ten current snapshot çek
       ↓
local.snapshot_id ≠ remote.current_id ?
       ↓ evet
Mute / dismiss durumu kontrol et
       ↓ değilse
Prompt göster: changelog + iki aksiyon
       ├── Replace local copy (aynı local ID, lineage chain devam)
       └── Download as new copy (fork — yeni local ID, lineage break)
```

### 10.4 Drift Banner

İndirilmiş bir snapshot lokal olarak edit edildiğinde "imported from @owner" banner'ı gösterilir — bu sayede kullanıcı kopyanın kaynağını her zaman görür ve yanlışlıkla "kendi içeriği" gibi yayınlama riski önlenir.

### 10.5 Event Forwarding

`EventEnvelope.forwardToOnline = true` olan event'ler `AppEventBus` üzerinden `NetworkBridge.emitEvent(...)`'e relay edilir. Şu an `NoOpNetworkBridge` bu çağrıları drop eder; Sprint 9'da Supabase Realtime channel'a aktarılacak.

---

## 11. Build, Tooling & CI/CD

### 11.1 Bağımlılık Tablosu (`flutter_app/pubspec.yaml`)

| Kategori | Paket | Versiyon |
| :--- | :--- | :--- |
| State | `flutter_riverpod` | ^2.6.1 |
| State (gen) | `riverpod_annotation` | ^2.6.1 |
| Models | `freezed_annotation` | ^3.0.0 |
| Models | `json_annotation` | ^4.9.0 |
| Local DB | `drift` | ^2.22.1 |
| Local DB | `sqlite3_flutter_libs` | ^0.5.0 |
| Storage | `msgpack_dart` | ^1.0.1 |
| Storage | `shared_preferences` | ^2.5.3 |
| Storage | `path_provider` | ^2.1.5 |
| Online | `supabase_flutter` | ^2.8.0 |
| Routing | `go_router` | ^14.8.1 |
| Audio | `flutter_soloud` | ^3.1.0 |
| PDF | `pdfrx` | ^2.2.24 |
| YAML | `yaml` | ^3.1.2 |
| Markdown | `flutter_markdown` | ^0.7.7+1 |
| Desktop | `window_manager` | ^0.4.3 |
| Desktop | `desktop_multi_window` | ^0.2.1 |
| Desktop | `screen_retriever` | ^0.2.0 |
| Util | `uuid` | ^4.5.1 |
| Util | `crypto` | ^3.0.5 |
| Util | `logger` | ^2.5.0 |
| Util | `url_launcher` | ^6.3.1 |
| Util | `file_picker` | ^10.3.10 |

**Dev / Code generation:** `build_runner ^2.4.15`, `freezed ^3.0.0`, `riverpod_generator ^2.6.3`, `json_serializable ^6.9.4`, `drift_dev ^2.22.1`, `custom_lint ^0.7.5`, `riverpod_lint ^2.6.3`, `flutter_lints ^6.0.0`, `flutter_launcher_icons ^0.14.3`.

### 11.2 Code Generation

```bash
# Tek seferlik
dart run build_runner build --delete-conflicting-outputs

# Watch mode
dart run build_runner watch --delete-conflicting-outputs
```

Üretilen dosya tipleri: `*.freezed.dart` (immutable models), `*.g.dart` (json serialization, riverpod providers, drift database), `app_localizations*.dart` (l10n).

### 11.3 Lint

[analysis_options.yaml](../flutter_app/analysis_options.yaml) içinde `flutter_lints` paket kuralları + `custom_lint` (riverpod_lint plugin'i) etkindir. Riverpod-spesifik analiz `dart run custom_lint` ile çalıştırılır.

### 11.4 CI/CD — `.github/workflows/build.yml`

| Job | Runner | Çıktı |
| :--- | :--- | :--- |
| Android | ubuntu-22.04 | `DungeonMasterTool-Android.apk` |
| Windows | windows-2022 | `DungeonMasterTool-Windows.zip` |
| Linux | ubuntu-22.04 | `DungeonMasterTool-Linux.zip` |
| iOS | macos-14 | `DungeonMasterTool-iOS.ipa` (unsigned) |
| macOS | macos-14 | `DungeonMasterTool-MacOS.zip` |

- **Tetikleyici:** GitHub release publication + manuel `workflow_dispatch`.
- **Flutter version pinned:** `3.41.6`.
- **Build adımları:** checkout → platform deps → `flutter pub get` → `dart run build_runner build --delete-conflicting-outputs` → `flutter build <platform> --release --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…` → archive → upload to release.
- **Web:** CI'da yok (deneysel).

### 11.5 Platform Klasörleri

`flutter_app/` altında: `android/`, `ios/`, `windows/`, `linux/`, `macos/`, `web/` — hepsi mevcut.

---

## 12. Test Durumu

- **14 test dosyası**, tahmini ~3.2K satır test kodu, ~220+ test case.
- **Kapsanan alanlar:**
  - Combat: encounter, combatant, turn, HP, conditions, serialization (~51 test)
  - Mind map: notifier + node/edge state (~46 test)
  - World map: pin + timeline (~19 test)
  - Field widgets: text, textarea, integer, boolean, enum, statBlock, dice (~34 test)
  - Domain entity parser/schema testleri
- **Eksik kalan alanlar:**
  - `data/repositories` ve `data/datasources` testleri (mock Supabase / drift in-memory ile)
  - Marketplace publish + update prompt akışı end-to-end testi
  - Sosyal feature'lar (posts, messages, follows) integration testleri
  - Performance benchmark testleri (büyük mind map, battle map)
  - Widget golden testleri (tema/lokalizasyon doğrulama)

---

## 13. Kod Metrikleri & En Büyük Dosyalar

### 13.1 Genel Sayım

| Metrik | Değer |
| :--- | ---: |
| `lib/` dart dosyası | 296 |
| `lib/` toplam satır | 92,241 |
| `test/` dart dosyası | 14 |
| Supabase migration | 6 |
| Drift tablo | 14 |
| Riverpod provider | 25 |
| Lokal dil | 4 (EN/TR/DE/FR) |
| Platform | 6 (Android/iOS/Windows/Linux/macOS/Web) |

### 13.2 Katman Dosya Dağılımı

| Katman | Dosya Sayısı (yaklaşık) |
| :--- | ---: |
| `domain/` | 89 |
| `data/` | 57 |
| `application/` | 40 |
| `presentation/` | 102 |
| `core/` | 30 |

### 13.3 Dikkat Çeken Büyük Dosyalar

`*.g.dart` ve `*.freezed.dart` dosyaları üretilmiştir, manuel maintenance gerektirmez. El yazılı en büyük dosyalar genellikle:

- `presentation/screens/map/world_map_screen.dart` (~2255 satır) — pin + timeline + harita render birleşiği
- `presentation/screens/hub/template_editor.dart` — şablon editör (kategori + alan + encounter config)
- `presentation/screens/session/session_screen.dart` (~1843 satır) — combat tracker + event log
- `presentation/widgets/field_widgets/field_widget_factory.dart` (~1569 satır) — 16 field tipi
- `presentation/screens/mind_map/mind_map_node_widget.dart` (~1130 satır)
- `presentation/screens/hub/settings_tab.dart` — settings paneli

> **Not:** Bu dosyaların bazıları çoklu sorumluluk taşır (UI + state coordination); ileride feature klasörlerine bölme adayı.

---

## 14. Teknik Borç & İyileştirme Alanları

| Öncelik | Konu | Detay |
| :---: | :--- | :--- |
| 🔴 | **Mind map persistence normalize** | Şu an `state_json` blob; `mind_map_nodes`/`mind_map_edges` tablolarına tam taşıma TODO |
| 🔴 | **`SupabaseNetworkBridge` impl** | Sprint 9 — Realtime relay + presence + session-code multiplayer |
| 🟠 | **Soundpad Panel UI** | YAML theme loader UI eksik; engine hazır |
| 🟠 | **Dual screen tam entegrasyon** | Sprint 7 — projection notifier + persistence + UI |
| 🟠 | **Repository interface formalization** | Provider'lar içine inline yazılmış kontratları `domain/repositories/` altına çıkarma |
| 🟡 | **Test coverage genişletme** | data layer + marketplace + social akışları |
| 🟡 | **Performance benchmark** | Büyük mind map / battle map render latency ölçümü |
| 🟡 | **Web platform tam destek** | CI'da yok, deneysel |
| 🟡 | **Widget golden testleri** | Tema + lokalizasyon regression koruması |
| 🟢 | **Büyük dosyaların bölünmesi** | 1500+ satırlık screen dosyalarının feature klasörlerine taşınması |

---

## 15. Roadmap Görünümü

[FLUTTER_DEVELOPMENT_ROADMAP.md](FLUTTER_DEVELOPMENT_ROADMAP.md) v2'den özet (2026-04 itibarıyla):

| Sprint | Konu | Durum |
| :---: | :--- | :--- |
| 0 | Foundation, schema migration, legacy maps | ✅ 100% |
| 1 | Schema-driven entity card | ✅ 100% |
| 2 | Field widgets + templates | ✅ 100% |
| 3 | Combat tracker + sessions | ✅ 100% |
| 4 | Battle map (6 katman) | ✅ 100% |
| 5 | Mind map + world map | ⚠️ ~85% |
| 6 | Soundpad + PDF + polish | ⚠️ ~40% |
| 7 | Dual screen + mobile polish | ⏳ ~5% |
| 8 | API integration + library | ⏳ |
| 9 | Online: Supabase NetworkBridge + auth flow | ⚠️ ~25% |
| 10 | Online: Sync + multiplayer | ⏳ |
| 11 | Online: Gameplay sync (combat, map state) | ⏳ |
| 12 | Online: Deploy + observability | ⏳ |

**Önümüzdeki en kritik iş bloğu:** Mind map persistence normalize → Soundpad UI tamamlama → `SupabaseNetworkBridge` implement → Sync state machine → Player instance multiplayer.

---

## 16. Ekler — Hızlı Navigasyon

### 16.1 Kök Dosyalar

- [flutter_app/lib/main.dart](../flutter_app/lib/main.dart) — Entry point, ProviderScope, window manager init
- [flutter_app/lib/app.dart](../flutter_app/lib/app.dart) — `MaterialApp.router`, tema, lokalizasyon
- [flutter_app/lib/presentation/router/app_router.dart](../flutter_app/lib/presentation/router/app_router.dart) — go_router config
- [flutter_app/pubspec.yaml](../flutter_app/pubspec.yaml) — Dependencies
- [flutter_app/analysis_options.yaml](../flutter_app/analysis_options.yaml) — Lint config
- [.github/workflows/build.yml](../.github/workflows/build.yml) — CI

### 16.2 Backend / Veri

- [supabase/migrations/001_cloud_backups.sql](../supabase/migrations/001_cloud_backups.sql)
- [supabase/migrations/002_community_assets.sql](../supabase/migrations/002_community_assets.sql)
- [supabase/migrations/003_social.sql](../supabase/migrations/003_social.sql)
- [supabase/migrations/004_likes_and_storage.sql](../supabase/migrations/004_likes_and_storage.sql)
- [supabase/migrations/005_game_listings_and_marketplace.sql](../supabase/migrations/005_game_listings_and_marketplace.sql)
- [supabase/migrations/006_marketplace_listings.sql](../supabase/migrations/006_marketplace_listings.sql)
- [flutter_app/lib/data/database/](../flutter_app/lib/data/database/)
- [flutter_app/lib/data/datasources/remote/](../flutter_app/lib/data/datasources/remote/)
- [flutter_app/lib/data/datasources/local/](../flutter_app/lib/data/datasources/local/)
- [flutter_app/lib/data/network/network_bridge.dart](../flutter_app/lib/data/network/network_bridge.dart)
- [flutter_app/lib/data/services/](../flutter_app/lib/data/services/)

### 16.3 Application / State

- [flutter_app/lib/application/providers/](../flutter_app/lib/application/providers/) — 25 provider
- [flutter_app/lib/application/services/](../flutter_app/lib/application/services/)

### 16.4 Domain

- [flutter_app/lib/domain/entities/marketplace_listing.dart](../flutter_app/lib/domain/entities/marketplace_listing.dart)
- [flutter_app/lib/domain/entities/campaign.dart](../flutter_app/lib/domain/entities/campaign.dart)
- [flutter_app/lib/domain/entities/session.dart](../flutter_app/lib/domain/entities/session.dart)
- [flutter_app/lib/domain/entities/mind_map.dart](../flutter_app/lib/domain/entities/mind_map.dart)
- [flutter_app/lib/domain/entities/map_data.dart](../flutter_app/lib/domain/entities/map_data.dart)
- [flutter_app/lib/domain/entities/events/event_envelope.dart](../flutter_app/lib/domain/entities/events/event_envelope.dart)
- [flutter_app/lib/domain/entities/events/event_types.dart](../flutter_app/lib/domain/entities/events/event_types.dart)

### 16.5 Frontend

- [flutter_app/lib/presentation/screens/social/](../flutter_app/lib/presentation/screens/social/) — Sosyal hub
- [flutter_app/lib/presentation/screens/hub/](../flutter_app/lib/presentation/screens/hub/) — Worlds/Templates/Packages/Settings
- [flutter_app/lib/presentation/screens/session/](../flutter_app/lib/presentation/screens/session/) — Combat tracker
- [flutter_app/lib/presentation/screens/battle_map/](../flutter_app/lib/presentation/screens/battle_map/)
- [flutter_app/lib/presentation/screens/mind_map/](../flutter_app/lib/presentation/screens/mind_map/)
- [flutter_app/lib/presentation/screens/map/](../flutter_app/lib/presentation/screens/map/)
- [flutter_app/lib/presentation/widgets/field_widgets/](../flutter_app/lib/presentation/widgets/field_widgets/)
- [flutter_app/lib/presentation/dialogs/](../flutter_app/lib/presentation/dialogs/)
- [flutter_app/lib/presentation/l10n/](../flutter_app/lib/presentation/l10n/)
- [flutter_app/lib/presentation/theme/](../flutter_app/lib/presentation/theme/)

### 16.6 İlgili Dökümanlar

- [FLUTTER_MIGRATION_BLUEPRINT.md](FLUTTER_MIGRATION_BLUEPRINT.md) — Tam mimari blueprint (v2.1)
- [FLUTTER_DEVELOPMENT_ROADMAP.md](FLUTTER_DEVELOPMENT_ROADMAP.md) — Sprint planı (v2.0)
- [ONLINE_REPORT.md](ONLINE_REPORT.md) — Hibrit online stack & cost model
- [DEVELOPMENT_REPORT.md](DEVELOPMENT_REPORT.md) — Eski Python/PyQt6 referansı (deprecated)
- [releases/beta-v4.0.0.md](releases/beta-v4.0.0.md) — Marketplace snapshot + lineage release notes
- [releases/beta-v3.0.0.md](releases/beta-v3.0.0.md) — Sosyal hub release notes
