# 📝 To-Do List & Roadmap

> **v2.0 — Flutter Rewrite**
> The app has been rewritten from PyQt to Flutter. Supports Android, iOS, Windows, Linux, and macOS.

---

## ✅ Completed Features

- [x] **Combat Tracker** — Initiative, HP bar, turn tracking, conditions, auto event log (51 tests)
- [x] **Battle Map** — 6 layers (grid, token, annotation, fog, terrain, decal), all tools (selection, draw, erase, measure, fog), scroll/zoom, token drag/resize
- [x] **Entity System** — Schema-driven entity card, 16 field widget types (text, textarea, integer, boolean, enum, markdown, image, file, tag, date, stat block, dice roller, etc.)
- [x] **Campaign Management** — Create/load/save/delete campaigns, world schema management, entity templates
- [x] **Session Management** — Session creation, encounter setup, turn management, event log
- [x] **Database Screen** — Entity database with dual-panel splitter and filtering
- [x] **PDF Viewer** — pdfrx integration, page navigation, zoom
- [x] **Dice Roller** — d4/d6/d8/d10/d12/d20/d100
- [x] **Settings** — 11 themes (dark/light), 4 languages (EN/TR/DE/FR), SharedPreferences persistence
- [x] **Drift Database** — 14 tables, 6 DAOs, v5 migration system, MsgPack legacy fallback
- [x] **Template System** — Built-in D&D 5e schema + user-defined templates, compatibility check, sync
- [x] **Package System** — Package import/export, schema and entity packaging
- [x] **Localization** — 4 languages (EN/TR/DE/FR), ARB-based flutter gen-l10n
- [x] **Hub Screen** — Templates, Worlds, Settings, Packages, Social tabs

---

## 🚧 In Progress

### Mind Map (85%)
- [x] Infinite canvas, node/edge CRUD, undo/redo, workspace menu, Bézier connections, LOD (46 tests)
- [ ] Drift schema normalization — replace `state_json` blob with dedicated columns

### World Map (85%)
- [x] Map load/save, pin system (location + timeline), fog-of-war, epoch timeline (19 tests)
- [ ] Drift schema normalization — replace `state_json` blob with dedicated columns

### Soundpad / Audio (40%)
- [x] flutter_soloud engine, gapless loops, volume fade, track queuing
- [x] soundpad_provider (Riverpod), soundpad_loader
- [ ] Standalone SoundpadPanel screen (dedicated UI)
- [ ] YAML theme loader (read soundpad theme files)
- [ ] Smoother loop transitions (prevent audio glitches)
- [ ] Mid-length transition sound support

### Player Window / Second Screen (5%)
- [x] desktop_multi_window infrastructure, projection views (battle map, entity card, image, black screen)
- [ ] Full UI and control panel
- [ ] State sync (DM → Player)
- [ ] Mobile/tablet dual-screen support

---

## 📋 To-Do (By Priority)

### 🔴 High Priority

- [ ] **Drift Schema Normalization (v6)** — Migrate mind map, world map, and combat state from `state_json` blobs to dedicated tables. Critical for online sync and query performance.
- [ ] **Repository Abstraction** — Extract `EntityRepository`, `MapRepository`, `MindMapRepository` interfaces. Currently embedded in campaign_repository_impl.
- [ ] **Soundpad Panel** — Standalone soundpad screen + YAML theme loading. Audio engine is ready, UI is missing.

### 🟡 Medium Priority

- [ ] **Player Window Polish** — Full second-screen UI, projector controls, mobile adaptation.
- [ ] **D&D 5e API Client** — HTTP client, spell/class/equipment browser, bulk downloader. Currently only URL constants defined (`dnd5eapi.co`, `open5e.com`).
- [ ] **Mobile UX** — Responsive layouts for Android/iOS, gesture handling, platform-specific UX improvements.
- [ ] **Soundpad Transitions** — Smoother loop switching, mid-length transition sounds.

### ⚪ Long Term

- [ ] **Online Multiplayer (Supabase)**
  - [ ] `SupabaseNetworkBridge` implementation
  - [ ] Auth service
  - [ ] RLS policies
  - [ ] Realtime event forwarding
  - [ ] Asset storage (Cloudflare R2)
- [ ] **Random Generators** — NPC generator (names, stats, traits), encounter generator.
- [ ] **Image to Note (OCR)** — Convert handout/text images to editable notes.
- [ ] **Integrations** — D&D Beyond, Obsidian MD.
- [ ] **Web Platform** — Web access via static hosting.
- [ ] **Pre-built Content** — Ready-made worlds and "One-Click" campaign setups.

---

## 🏗️ Technical Debt

- [ ] Normalize `state_json` blob usage into Drift tables (mind map, world map, combat)
- [ ] Extract entity/map/mind map repositories from campaign_repository_impl
- [ ] Increase test coverage (currently 223 tests across 13 files)
- [ ] Add `flutter analyze` + `flutter test` to CI

---

## 📋 Changelog

### v2.0.0 — Flutter Rewrite

- **Full platform support:** Android, iOS, Windows, Linux, macOS
- **Clean Architecture:** Domain / Data / Application / Presentation layers
- **Riverpod state management:** 14 providers with reactive state
- **Drift SQLite:** 14 tables, 6 DAOs, migration system
- **Battle Map:** 6-layer canvas (grid, token, annotation, fog, terrain, decal)
- **Mind Map:** Infinite canvas, Bézier connections, LOD rendering, undo/redo
- **World Map:** Pin system, epoch timeline, fog-of-war
- **Entity System:** Schema-driven, 16 field widget types
- **Combat Tracker:** Initiative, HP, conditions, auto event log
- **Template & Package System:** Built-in D&D 5e schema, package import/export
- **Audio Engine:** flutter_soloud with gapless loops, volume fade
- **PDF Viewer:** pdfrx integration
- **Localization:** 4 languages (EN/TR/DE/FR)
- **11 themes:** Dark/light variants
