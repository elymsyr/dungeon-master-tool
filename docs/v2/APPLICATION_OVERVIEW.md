# Dungeon Master Tool — Application Overview & Technical Specification

**Version:** 0.8.4 (Alpha)
**Author:** Orhun Eren Yalçınkaya (Elymsyr)
**License:** MIT
**Repository:** [github.com/Elymsyr/dungeon-master-tool](https://github.com/Elymsyr/dungeon-master-tool)
**Purpose:** This document provides a comprehensive description of the Dungeon Master Tool — its features, architecture, data model, platform ambitions, and future vision. It is intended for technical evaluators assessing cross-platform deployment strategies. This document does not recommend any specific technology; it provides the information necessary for an evaluator to make that decision independently.

---

## Table of Contents

1. [Product Vision & Positioning](#1-product-vision--positioning)
2. [Feature Catalog — What the Application Does](#2-feature-catalog--what-the-application-does)
3. [Platform Targets & Display Architecture](#3-platform-targets--display-architecture)
4. [Current Technology Stack (v0.8.4)](#4-current-technology-stack-v084)
5. [Application Architecture — How It Works](#5-application-architecture--how-it-works)
6. [Data Model & Persistence](#6-data-model--persistence)
7. [Entity System & World Building](#7-entity-system--world-building)
8. [Battle Map Engine](#8-battle-map-engine)
9. [Mind Map & Campaign Planning](#9-mind-map--campaign-planning)
10. [Combat Tracker System](#10-combat-tracker-system)
11. [Audio & Atmosphere Engine](#11-audio--atmosphere-engine)
12. [Projection, Screen Sharing & Multi-Display](#12-projection-screen-sharing--multi-display)
13. [Session Management & Timeline](#13-session-management--timeline)
14. [World Map & Geography](#14-world-map--geography)
15. [API Integration & Content Library](#15-api-integration--content-library)
16. [Theming & Localization](#16-theming--localization)
17. [Real-Time Event System & Network Architecture](#17-real-time-event-system--network-architecture)
18. [Online Play — Vision & Architecture](#18-online-play--vision--architecture)
19. [Pre-Online Stability Requirements](#19-pre-online-stability-requirements)
20. [Planned Features — Full Roadmap](#20-planned-features--full-roadmap)
21. [Codebase Statistics & Quality Indicators](#21-codebase-statistics--quality-indicators)
22. [Competitive Context](#22-competitive-context)

---

## 1. Product Vision & Positioning

### 1.1 What Is the Dungeon Master Tool?

The Dungeon Master Tool is a **comprehensive campaign management application** for tabletop role-playing game Dungeon Masters (DMs). It unifies entity management, combat tracking, battle maps with fog of war, campaign planning mind maps, world mapping with timelines, adaptive atmospheric audio, and a real-time player projection system into a single offline-first application.

It is not a virtual tabletop (VTT) focused on grid-based token movement. It is a **DM's command center** — a unified workspace where every aspect of running a tabletop RPG campaign is managed from a single interface, with seamless projection of content to players.

### 1.2 Core Design Principles

1. **Offline-First** — The application works entirely without internet. All campaign data, images, audio, and PDFs are stored locally. Network connectivity is additive, never required. A power outage or Wi-Fi failure during a session has zero impact on the DM's workflow.

2. **DM-Centric Workflow** — Every feature is designed from the Dungeon Master's perspective. The DM has full sovereignty over what players see, when they see it, and how the atmosphere sounds. Players are recipients of curated content, not co-editors.

3. **Dual-Screen Native** — The application is architecturally designed around a two-display setup: one screen for the DM's comprehensive workspace, one screen projected to players. This is a first-class architectural concern — the player window is a separate process/window that receives rendering commands from the DM's workspace.

4. **System-Agnostic Core** — While the default data structures follow D&D 5e conventions, the entity system supports 15 customizable entity types with user-definable attributes. The long-term vision includes fully dynamic entity schemas for any RPG system (Pathfinder, Call of Cthulhu, GURPS, homebrew).

5. **Batteries Included** — Audio management, combat tracking, fog of war, PDF viewing, mind mapping, markdown editing, and content projection are all built-in. No plugin ecosystem or third-party tool is required for the core DM workflow.

### 1.3 Target Users

- **Primary (Now):** Tabletop RPG Dungeon Masters running in-person sessions with a physical table + monitor/TV for players
- **Secondary (Now):** DMs preparing campaigns between sessions (world building, NPC creation, story planning)
- **Future (Online Phase):** Remote/hybrid play groups with 1 DM + N players on separate devices
- **Future (Mobile):** Players accessing campaign content and combat status from personal devices

---

## 2. Feature Catalog — What the Application Does

### 2.1 Implemented Features (v0.8.4 — Production Alpha)

| # | Feature | Description | Complexity |
|---|---------|-------------|-----------|
| 1 | **Entity Management** | CRUD for 15 entity types (NPC, Monster, Spell, Equipment, Class, Race, Location, Player, Quest, Lore, Status Effect, Feat, Background, Plane, Condition) with an 8-tab detail editor. Each entity has type-specific dynamic attributes, markdown description, image gallery, PDF attachments, and DM-only notes. | High |
| 2 | **Combat Tracker** | Real-time initiative tracking, HP bars with visual color coding (healthy/wounded/critical), condition badges with turn-based duration countdown, encounter management (create/rename/delete/switch), drag-and-drop entity import, auto-generated event log. Round counter, turn highlighting, quick-add form for on-the-fly combatants. | High |
| 3 | **Battle Map** | Image-based battle map with 6 layers: background, grid overlay (configurable cell size + snap), freehand drawing, tokens (draggable circles with entity portraits and attitude-coded borders), fog of war (pixel-level compositing with add/erase polygon tools), and measurement overlay (persistent rulers + circles with distance labels in feet/squares). DM view shows semi-transparent fog; player view shows opaque fog. Real-time sync between DM and player screens. | Very High |
| 4 | **Mind Map** | Infinite zoomable canvas for campaign planning with 4 node types: Note (markdown editor), Entity (embedded entity card), Image (aspect-ratio display), Workspace (colored container grouping). Cubic bezier connections between nodes. 50-step undo/redo history. Level-of-Detail (LOD) rendering with 3 zoom zones for performance. Debounced autosave. Right-click context menus for node CRUD and connection management. | Very High |
| 5 | **World Map** | Image-based world map with entity pins (clickable, linked to entity cards), timeline pins (day-based markers with chained connections and color propagation), and category filtering. Pan/zoom navigation. Pins linked to both entities and sessions for cross-referencing. | Medium |
| 6 | **Soundpad** | Multi-track audio engine with 3 categories: Music (theme-based with states like Normal/Combat/Victory and 5 intensity levels), Ambience (4 simultaneous slots), and SFX (8-player pool). Dual-deck crossfade system with 3-second constant-power transition (InOutCubic easing). YAML-defined theme libraries. Master volume control. All audio stored locally. | High |
| 7 | **Player Projection** | Second-window content display controlled entirely by the DM. 5 content modes: multi-image gallery (auto-layout 1-4 images), battle map (read-only with fog), PDF viewer, HTML stat block, and black screen. The player window is a separate native window that can be placed on a second monitor, targeted for screen sharing, or wirelessly projected via Miracast/AirPlay. | High |
| 8 | **Session Management** | Multiple sessions per campaign with separate notes (markdown), event logs (auto-generated + manual), and combat state (full encounter persistence including token positions, fog state, and conditions). Active session tracking with auto-load on startup. | Medium |
| 9 | **PDF Viewer** | Embedded PDF viewer with page navigation, zoom (fit-width/fit-page/manual), middle-mouse drag panning, and "Project PDF" button that sends the current document to the right-side panel or player window. Supports local files. Right-side collapsible panel (mutually exclusive with soundpad). | Medium |
| 10 | **API Integration** | D&D 5e SRD and Open5e content fetching with local caching. Paginated browsing, search, preview, single import, and bulk download. Automatic dependency resolution (importing a monster auto-imports its referenced spells). Abstract source pattern allows adding new API sources. | Medium |
| 11 | **Markdown Editor** | Dual-mode editor (raw markdown / rendered HTML). Entity @mention autocomplete (type `@` to search and link entities). Entity links (`[@Name](entity://id)`) are clickable in preview mode and open the linked entity in the editor. Theme-aware HTML rendering. Used in entity descriptions, DM notes, session logs, and mind map note nodes. | Medium |
| 12 | **Theme System** | 11 hand-crafted color themes (Dark, Light, Midnight, Amethyst, Baldur, Discord, Emerald, Frost, Grim, Ocean, Parchment), each defining ~80 color variables. Runtime theme switching with instant application (no restart). All styling via external stylesheet files — zero hardcoded colors in widget code. | Low |
| 13 | **Localization** | 4 languages (English, Turkish, German, French) with ~250 locale keys each. YAML-based locale files. Runtime language switching. All UI strings use the `tr()` localization function. | Low |
| 14 | **Global Edit Mode** | Single toolbar toggle that locks/unlocks ALL text inputs across the entire application simultaneously. Prevents accidental edits during live sessions. Keyboard shortcut (Ctrl+E). | Low |
| 15 | **Image Gallery** | Multi-image per entity with navigation arrows, counter, add/remove buttons. Lazy download from API sources. Used in entity editor and player projection. | Low |

### 2.2 Feature Interaction Map

```
Entity Sidebar ──drag──> Combat Tracker ──sync──> Battle Map Tokens
      │                        │                        │
      │ click                  │ HP/conditions          │ fog/tokens
      ▼                        ▼                        ▼
Entity Editor ────────> Session Event Log     Player Window (2nd screen)
      │                        │                        ▲
      │ @mention               │ session data           │ projection commands
      ▼                        ▼                        │
Markdown Editor         Session Notes           DM Screen Controls
      │                                                 │
      │ entity links                                    │ content switching
      ▼                                                 ▼
Mind Map Nodes ──connections──> Mind Map Edges    Soundpad Audio ──crossfade──> Speakers
```

---

## 3. Platform Targets & Display Architecture

### 3.1 Current Platform Support

| Platform | Role | Status |
|----------|------|--------|
| **Windows 10/11** | DM workstation (full features) | ✅ Production |
| **macOS 12+** | DM workstation (full features) | ✅ Production |
| **Linux (Ubuntu/Fedora/Arch)** | DM workstation (full features) | ✅ Production |

### 3.2 Target Platform Support (Future)

| Platform | Role | Status |
|----------|------|--------|
| **Android tablet** | Player client + lightweight DM | Planned |
| **Android phone** | Player client only | Planned |
| **iOS iPad** | Player client + lightweight DM | Planned |
| **iOS iPhone** | Player client only | Planned |
| **Web browser** | Player client + remote DM access | Planned |

### 3.3 Display Architecture — Dual Monitor Setup

The primary use case is a DM sitting at a table with two displays:

```
┌──────────────────────────┐    ┌──────────────────────────┐
│   DM's Primary Monitor    │    │  Player's Display         │
│                          │    │  (TV/Projector/Tablet)     │
│  ┌────────┬─────────────┐│    │                            │
│  │Sidebar │  Workspace   ││    │  ┌──────────────────────┐ │
│  │        │  (4 tabs:    ││    │  │                      │ │
│  │Entity  │   Database/  ││    │  │  Content controlled   │ │
│  │List    │   Session/   ││    │  │  entirely by DM:      │ │
│  │Search  │   Mind Map/  ││    │  │                      │ │
│  │Filter  │   World Map) ││    │  │  • Battle Map + Fog  │ │
│  │        │              ││    │  │  • Image Gallery     │ │
│  │        ├──────────────┤│    │  │  • PDF Document      │ │
│  │        │ Right Panel  ││    │  │  • Entity Stat Block │ │
│  │        │ (Soundpad    ││    │  │  • Black Screen      │ │
│  │        │  or PDF)     ││    │  │                      │ │
│  └────────┴──────────────┘│    │  └──────────────────────┘ │
│  [Toolbar: Edit/Theme/etc]│    │  [Combat Sidebar (HP/Turn)]│
└──────────────────────────┘    └──────────────────────────┘
```

### 3.4 Screen Sharing & Wireless Projection

For scenarios where a direct second monitor is not available:

| Scenario | Solution |
|----------|----------|
| **No second monitor at table** | Miracast/AirPlay/Chromecast from the player window to a wireless TV display |
| **DM streaming to Discord/Twitch** | OBS/Discord window capture targeting the player window (titled "Player View") |
| **DM on laptop, players remote** | Players connect to DM's server via browser/app. WebSocket sync for all content modes |
| **Mixed: local + remote players** | Local TV receives wireless projection + remote players connect via browser simultaneously |
| **Mobile devices at table** | Players open browser on phone/tablet, connect to DM's local server via LAN URL |

The player window is architecturally a **content receiver** that accepts rendering commands from the DM workspace. This decoupling means the player view can be delivered through any display technology:
- Native desktop window on a second monitor
- Miracast/AirPlay wireless display
- Browser tab (same or different computer)
- Mobile app (phone/tablet)
- OBS window capture source for streaming
- WebSocket-connected remote client

### 3.5 Mobile Display Considerations

| Device | DM Features | Player Features |
|--------|------------|-----------------|
| **Tablet (10"+)** | Entity browsing/editing, combat tracker, session notes | Full player view, battle map pinch-zoom, stat blocks |
| **Phone (<7")** | Emergency entity lookup only | Combat sidebar (HP/turn), simplified battle map, stat blocks |

Mobile DM mode intentionally excludes complex canvas interactions (battle map editing, mind map editing, fog painting) due to touch input limitations. These remain desktop-only features.

---

## 4. Current Technology Stack (v0.8.4)

### 4.1 Runtime Dependencies

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Language** | Python | 3.10+ | All application code |
| **UI Framework** | PyQt6 | 6.x | Desktop widgets, multi-window, QGraphicsScene |
| **Web Engine** | PyQt6-WebEngine | 6.x | Listed but not actively used in current code |
| **HTTP Client** | requests | 2.x | External API calls (D&D 5e, Open5e) |
| **Localization** | python-i18n | 0.3.x | Multi-language support (YAML locale files) |
| **Config** | PyYAML | 6.x | YAML configuration parsing |
| **Data Serialization** | msgpack | 1.x | Binary campaign data persistence |
| **Markdown Rendering** | markdown | 3.x | Markdown → HTML conversion |
| **Image Processing** | Pillow | 10.x | Image manipulation and format handling |
| **PDF Rendering** | PyMuPDF (fitz) | ≥1.23.0 | Page-level PDF rendering to pixmaps |
| **WebSocket Client** | python-socketio[client] | ≥5.11.0 | Socket.io client (network bridge skeleton) |
| **Data Validation** | pydantic | ≥2.0.0 | Event payload schemas, API models |
| **Desktop Build** | PyInstaller | 5.x | Package to standalone executables |

### 4.2 Development Dependencies

| Component | Technology | Purpose |
|-----------|-----------|---------|
| pytest | 8.x | Unit and integration testing |
| pytest-qt | 4.x | PyQt6 widget testing |
| pytest-mock | 3.x | Mocking framework |
| watchfiles | 0.21.x | Hot reload file monitoring (dev mode) |
| ruff | 0.4.x | Python linting (configured in pyproject.toml) |
| mypy | 1.x | Optional static type checking |

### 4.3 Audio Technology

The audio engine (`core/audio/engine.py`) uses PyQt6's multimedia modules:
- `QMediaPlayer` for audio file playback
- `QAudioOutput` for volume control per track
- `QPropertyAnimation` for smooth volume crossfade (constant-power curve)

This is the **only PyQt6 dependency within the core logic layer** (all other core modules are pure Python). An abstraction interface is planned to decouple this.

### 4.4 Canvas / Graphics Technology

The application uses PyQt6's `QGraphicsScene` / `QGraphicsView` framework for:
- **Battle Map:** Layered scene with background pixmap, grid overlay, fog of war (QImage compositing), token circles (QGraphicsEllipseItem), measurement overlay, and annotation layer (freehand QImage painting)
- **Mind Map:** Scene with custom QGraphicsObject nodes (embedding real Qt widgets via QGraphicsProxyWidget), QPainterPath bezier connections, and WorkspaceItem containers
- **World Map:** Scene with background pixmap and positioned pin items

### 4.5 Stylesheet System

All visual styling is defined in external QSS (Qt Style Sheet) files:
- 11 theme-specific `.qss` files (dark.qss, light.qss, baldur.qss, etc.)
- 1 shared `common.qss` file with objectName-based structural rules
- `ThemeManager` provides runtime palette dictionaries (~80 color variables per theme) for canvas elements that cannot be styled via QSS

### 4.6 Build System

- **PyInstaller** produces standalone executables for each platform
- Installer scripts: `installer/build.py` (cross-platform), `install.sh` (Debian/Ubuntu/Fedora), `install-arch.sh` (Arch Linux)
- Resources bundled: `assets/`, `themes/`, `locales/`
- Output: `.exe` (Windows), `.dmg` (macOS), `.AppImage` (Linux)
- Binary size: ~60-80MB (includes Python runtime)

---

## 5. Application Architecture — How It Works

### 5.1 Layer Separation

```
┌─────────────────────────────────────┐
│            UI Layer                  │  53 files, ~15,000 LOC
│  (Currently PyQt6 Widgets)          │  Framework-specific rendering
│  Tabs, Dialogs, Widgets, Windows    │  All platform-specific code
└──────────────┬──────────────────────┘
               │ calls methods on
┌──────────────▼──────────────────────┐
│         Presenter Layer              │  3 files, ~500 LOC
│  (Business logic orchestration)     │  CombatPresenter, NpcPresenter
│  Signal/event-based communication   │  Framework-minimal (uses QObject signals)
└──────────────┬──────────────────────┘
               │ delegates to
┌──────────────▼──────────────────────┐
│           Core Layer                 │  20+ files, ~7,000 LOC
│  (Pure Python — ZERO UI imports)    │  Fully portable across frameworks
│  DataManager → 6 sub-managers       │
│  EventBus, NetworkBridge, Models    │
│  API Client, Audio Models, Config   │
└──────────────┬──────────────────────┘
               │ reads/writes
┌──────────────▼──────────────────────┐
│        Persistence Layer             │  MsgPack binary files
│  worlds/{name}/data.dat             │  + assets/ (images, PDFs, audio)
│  cache/settings.json                │  + library/ (API cache)
└─────────────────────────────────────┘
```

### 5.2 Core Layer — Portable Business Logic

The core layer contains **zero imports from any UI framework** (with one exception: the audio engine). This means the entire core layer can be reused in any alternative tech stack without modification.

| Component | File | LOC | Responsibility | UI Dependencies |
|-----------|------|-----|---------------|-----------------|
| **DataManager** | `core/data_manager.py` | 339 | Orchestrator facade | None |
| **EntityRepository** | `core/entity_repository.py` | 143 | Entity CRUD + dependency resolution | None |
| **SessionRepository** | `core/session_repository.py` | 83 | Session CRUD + combat state | None |
| **CampaignManager** | `core/campaign_manager.py` | 218 | Campaign load/create/migrate | None |
| **MapDataManager** | `core/map_data_manager.py` | ~180 | Map pins + timeline operations | None |
| **LibraryManager** | `core/library_manager.py` | ~250 | API cache + offline library | None |
| **SettingsManager** | `core/settings_manager.py` | 47 | User preferences (JSON) | None |
| **EventBus** | `core/event_bus.py` | 55 | In-process pub/sub (24 event types) | None |
| **NetworkBridge** | `core/network/bridge.py` | 178 | Connection state machine + event forwarding | None |
| **Event Schemas** | `core/network/events.py` | ~200 | Pydantic v2 payload models (24 types) | None |
| **Models** | `core/models.py` | ~200 | Entity schemas (15 types) + legacy migration | None |
| **API Client** | `core/api/*.py` | 7 files | D&D 5e + Open5e with abstract base | None |
| **Audio Models** | `core/audio/models.py` | 36 | Theme → State → Track → LoopNode | None |
| **Audio Loader** | `core/audio/loader.py` | 292 | YAML library parsing | None |
| **Audio Engine** | `core/audio/engine.py` | 324 | Playback + crossfade | **QMediaPlayer** ⚠️ |
| **ThemeManager** | `core/theme_manager.py` | 333 | 11 palette definitions | None |
| **Locales** | `core/locales.py` | ~30 | i18n setup | None |
| **Config** | `config.py` | ~120 | Path resolution, constants | None |

### 5.3 UI Layer — Framework-Specific (53 Files)

The UI layer is entirely PyQt6 Widgets-based. Key components:

| Component | Files | LOC | Canvas? |
|-----------|-------|-----|---------|
| Main Window + Root Layout | 2 | ~500 | No |
| Entity Sidebar | 1 | ~350 | No |
| NPC Sheet (8-tab editor) | 6 | ~1,830 | No |
| Combat Tracker (table + controls) | 5 | ~700 | No |
| Battle Map (canvas, fog, tokens, tools) | 1 | 1,563 | **QGraphicsScene** |
| Mind Map (canvas, nodes, connections) | 2 | 1,373 | **QGraphicsScene** |
| Session Tab | 1 | ~400 | No |
| Map Tab | 1 | ~400 | No |
| Screen Tab (projection controls) | 1 | ~200 | No |
| Player Window | 1 | 447 | Contains battle map |
| Soundpad Panel | 1 | 445 | No |
| PDF Panel + Viewer | 2 | ~400 | No |
| Markdown Editor | 1 | 447 | No |
| Dialogs (7 types) | 8 | ~800 | No |
| Workers (background threads) | 1 | ~200 | No |
| Presenters | 2 | ~500 | No |
| Other widgets | ~17 | ~3,000 | No |

### 5.4 Sub-Manager Architecture (Repository Pattern)

DataManager acts as a **thin facade** delegating to 6 focused sub-managers:

```
DataManager (facade, 339 LOC)
├── EntityRepository      → save(), delete(), import_with_dependencies(), get_all_mentions()
├── SessionRepository     → create(), get(), save_data(), set_active()
├── CampaignManager       → get_available(), load_by_name(), create()
├── MapDataManager        → add_pin(), move_pin(), add_timeline_pin()
├── LibraryManager        → get_api_index(), fetch_details_from_api(), search_library_catalog()
└── SettingsManager       → load(), save()
```

All sub-managers operate on a shared `data` dictionary (the live campaign state). `save_data()` serializes this dict to MsgPack binary on disk.

---

## 6. Data Model & Persistence

### 6.1 Storage Format

Campaign data is stored as **MsgPack binary** files (`.dat`). MsgPack was chosen for:
- 3-5x faster serialization than JSON
- ~40% smaller than equivalent JSON
- Binary-safe (handles UTF-8, special characters, binary references)
- Cross-platform (identical format on Windows/macOS/Linux)

Legacy JSON format (`.json`) is supported with automatic migration to MsgPack on first load.

### 6.2 Campaign File Structure

```
worlds/{campaign_name}/
├── data.dat              # MsgPack binary — all campaign data
├── data.json             # Legacy JSON (auto-migrated to .dat)
└── assets/
    ├── {uuid}_portrait.png    # Imported entity images
    ├── {uuid}_document.pdf    # Imported PDF files
    ├── {uuid}_battlemap.jpg   # Battle map images
    └── soundpad/              # Audio library
        ├── soundpad_library.yaml  # Ambience/SFX definitions
        └── {theme_name}/
            ├── theme.yaml         # Theme structure definition
            └── *.mp3, *.ogg       # Audio files
```

### 6.3 Campaign Data Schema (Complete)

```
Campaign = {
    world_name: string,
    entities: {
        [entity_id: UUID]: {
            name: string,
            type: EntityType,          // 15 types (see Section 7)
            source: string,
            description: string,       // markdown
            images: string[],          // relative paths to assets/
            tags: string[],
            attributes: {[key]: string},  // dynamic per entity type
            stats: { STR: int, DEX: int, CON: int, INT: int, WIS: int, CHA: int },
            combat_stats: { hp: string, max_hp: string, ac: string, speed: string, cr: string, xp: string, initiative: string },
            traits: [{ name: string, desc: string }],
            actions: [{ name: string, desc: string }],
            reactions: [{ name: string, desc: string }],
            legendary_actions: [{ name: string, desc: string }],
            spells: string[],              // entity IDs (linked spells)
            custom_spells: [{ name: string, desc: string, attributes: {} }],
            equipment_ids: string[],       // entity IDs (linked equipment)
            inventory: [{ name: string, desc: string }],
            pdfs: string[],               // relative paths to assets/
            location_id: string | null,    // entity ID (linked location)
            dm_notes: string,              // markdown (DM-only)
            saving_throws: string,
            damage_vulnerabilities: string,
            damage_resistances: string,
            damage_immunities: string,
            condition_immunities: string,
            proficiency_bonus: string,
            passive_perception: string,
            skills: string
        }
    },
    map_data: {
        image_path: string,            // relative path to map background
        pins: [{
            id: UUID,
            x: float, y: float,
            entity_id: UUID,
            color: string | null,
            note: string
        }],
        timeline: [{
            id: UUID,
            x: float, y: float,
            day: int,
            note: string,
            parent_id: UUID | null,     // chain link to previous event
            entity_ids: UUID[],
            color: string | null,
            session_id: UUID | null
        }]
    },
    sessions: [{
        id: UUID,
        name: string,
        date: string,
        notes: string,                  // markdown
        logs: string,                   // markdown (auto-generated combat log)
        combatants: [{
            id: UUID,
            name: string,
            entity_id: UUID | null,
            initiative: number,
            hp: number, max_hp: number, ac: number,
            status_effects: [{
                name: string,
                icon: string | null,
                duration: int,
                max_duration: int
            }]
        }]
    }],
    last_active_session_id: UUID | null,
    mind_maps: {
        [map_id: UUID]: {
            nodes: [{
                id: UUID,
                type: "note" | "entity" | "image",
                x: float, y: float, w: float, h: float,
                content: string,
                extra: { entity_id?: UUID, image_path?: string }
            }],
            connections: [{ from: UUID, to: UUID }],
            workspaces: [{
                id: UUID,
                name: string,
                x: float, y: float, w: float, h: float,
                color: string
            }],
            viewport: { x: float, y: float, zoom: float }
        }
    }
}
```

### 6.4 Settings (Separate from Campaign)

```
cache/settings.json = {
    language: "EN" | "TR" | "DE" | "FR",
    theme: "dark" | "light" | "baldur" | ... (11 themes)
}
```

### 6.5 Library Cache (Separate from Campaign)

```
cache/
├── reference_indexes.dat          # MsgPack: API response index cache
└── library/
    ├── dnd5e/                     # Per-source cache
    │   ├── monsters/{name}.json   # Individual entity cache
    │   ├── spells/{name}.json
    │   └── equipment/{name}.json
    └── open5e/
        └── (same structure)
```

---

## 7. Entity System & World Building

### 7.1 Entity Types (15 Categories)

| Type | Dynamic Attributes | Use Case |
|------|-------------------|----------|
| **NPC** | Race (entity_select→Race), Class (entity_select→Class), Level, Attitude (Friendly/Neutral/Hostile), Location (entity_select→Location) | Non-player characters |
| **Monster** | Challenge Rating, Attack Type | Creatures and enemies |
| **Player** | Class, Race, Level | Player characters |
| **Spell** | Level (Cantrip-9), School, Casting Time, Range, Duration, Components | Magic spells |
| **Equipment** | Category, Rarity, Attunement, Cost, Weight, Damage Dice, Damage Type, Range, AC, Requirements, Properties | Items and weapons |
| **Class** | Hit Die, Main Stats, Proficiencies | Character classes |
| **Race** | Speed, Size (Small/Medium/Large), Alignment, Language | Character races |
| **Location** | Danger Level (Safe/Low/Medium/High), Environment | Places in the world |
| **Quest** | Status (Not Started/Active/Completed), Giver, Reward | Story objectives |
| **Lore** | Category (History/Geography/Religion/Culture/Other), Secret Info | World knowledge |
| **Status Effect** | Duration (turns), Effect Type (Buff/Debuff/Condition), Linked Condition | Combat conditions |
| **Feat** | Prerequisite | Character feats |
| **Background** | Skill Proficiencies, Tool Proficiencies, Languages, Equipment | Character backgrounds |
| **Plane** | Type | Planes of existence |
| **Condition** | Effects | Game conditions (poisoned, stunned, etc.) |

### 7.2 Attribute Field Types

Each dynamic attribute is defined as a tuple `(label_key, field_type, options)`:

| Field Type | Rendering | Example |
|-----------|-----------|---------|
| `text` | Free-form text input | School: "Evocation" |
| `combo` | Dropdown with predefined options | Level: ["Cantrip", "1"..."9"] |
| `entity_select` | Dropdown populated from entities of a specific type | Race: (shows all Race entities) |

### 7.3 Entity Relationships

Entities reference each other via ID-based links:
- **Spells → Entity:** NPC/Monster "knows" spells (linked by entity ID)
- **Equipment → Entity:** NPC "carries" equipment (linked by entity ID)
- **NPC → Location:** NPC "resides at" a location (via location_id)
- **NPC/Monster → Class/Race:** Linked via entity_select attributes
- **Markdown @mentions:** Any entity can reference any other via `[@Name](entity://id)` links

### 7.4 Future: Dynamic Entity Types (Planned)

Allow DMs to define completely custom entity types and attributes for non-D&D systems:

**Planned field types:** text, markdown, integer, float, boolean, enum, date, image, file, relation (entity link), formula (computed from other fields)

**World Template Packaging:** Custom schemas + starter data packaged as `.dmt-template` files (ZIP archives with manifest, schemas, and optional assets) for sharing between DMs.

---

## 8. Battle Map Engine

### 8.1 Layer Architecture

| Layer | Z-Order | Content | Technology |
|-------|---------|---------|------------|
| Background | -100 | Map image (JPEG/PNG, up to 4000×4000px) | QGraphicsPixmapItem |
| Grid | 50 | Square grid overlay (configurable cell size) | Custom QGraphicsItem |
| Annotations | 100 | Freehand brush drawings | QImage with QPainter |
| Tokens | 100-150 | Combatant circles with entity portraits | QGraphicsEllipseItem |
| Measurements | 150 | Ruler lines and circle overlays with labels | Custom QGraphicsItem |
| Fog of War | 200 | Pixel-based opacity mask | QImage with composition modes |

### 8.2 Fog of War — Pixel Compositing

The fog system uses full-resolution image compositing:
- **Mask:** QImage matching map dimensions, Format_ARGB32
- **Add fog:** QPainter with `CompositionMode_SourceOver` fills black pixels via polygon path
- **Reveal area:** QPainter with `CompositionMode_Clear` erases pixels to transparent via polygon path
- **Serialization:** QImage → PNG bytes → base64 string (stored in session data)
- **DM view:** Semi-transparent fog (can see behind it)
- **Player view:** Fully opaque fog (hidden areas appear black)

### 8.3 Token System

- Image fill from entity portrait (QBrush with QPixmap)
- Border color: green (player), red (hostile), blue (friendly), gray (neutral), orange (active turn)
- Draggable with optional snap-to-grid
- Global size slider + per-token size override
- Name labels below tokens

### 8.4 Measurement Tools

- **Ruler:** Click-drag line with distance label (feet + grid squares)
- **Circle:** Click-drag radius with area label (feet)
- **Persistent:** Measurements remain until explicitly cleared (unique among tabletop tools)
- **Grid-aware:** Distance = `pixel_distance / cell_size × feet_per_cell`

### 8.5 Battle Map State Persistence

Full state serialized per session:
```
{ tokens: [...], fog_data: base64_png, annotation_data: base64_png,
  grid_size: int, grid_visible: bool, grid_snap: bool, feet_per_cell: int }
```

### 8.6 Future: Advanced Battle Map (Planned)

- Multi-grid support: square, hex (pointy-top/flat-top), isometric
- Cone/line AoE templates
- DM-only vs shared drawing layers
- Advanced measurement shapes (cone, line with width)

---

## 9. Mind Map & Campaign Planning

### 9.1 Node Types

| Type | Content | Size |
|------|---------|------|
| **Note** | Markdown editor (dual mode: edit/preview) | Variable (resizable) |
| **Entity** | Embedded entity summary card | Fixed based on content |
| **Image** | Aspect-ratio image display | Variable (resizable) |
| **Workspace** | Dashed border container for grouping | Variable (resizable, colored) |

### 9.2 Connections

Cubic bezier curves between node centers. Theme-aware colors (normal: gray, selected: accent). Right-click to delete.

### 9.3 Level-of-Detail (LOD) Rendering

| Zoom Level | Detail | Performance |
|------------|--------|-------------|
| ≥ 0.4 | Full: shadows, text, images, embedded editors | Standard |
| 0.2 – 0.4 | No shadows, device-coordinate caching | Optimized |
| < 0.2 | Simplified rectangles + inverse-scaled labels | Maximum |

### 9.4 Undo/Redo

50-snapshot history. Ctrl+Z / Ctrl+Shift+Z. Snapshots on: node move/resize/delete, content change, connection change.

### 9.5 Autosave

2000ms debounced save after any change. Persisted to campaign MsgPack file.

---

## 10. Combat Tracker System

### 10.1 Encounter Management

Multiple encounters per session. Create/rename/delete/switch. Full state serialized with session save.

### 10.2 Combatant Tracking

- HP progress bar: green (>50%), yellow (20-50%), red (<20%)
- +/- buttons for quick HP adjustment
- Condition badges with duration countdown (auto-expire at 0)
- Initiative order with drag reorder
- Round counter with auto-increment
- Active turn highlighting in table

### 10.3 Auto Event Log

Every combat action generates a timestamped entry:
- HP changes (damage/healing with amounts)
- Condition apply/remove
- Turn and round changes
- Combatant add/remove

---

## 11. Audio & Atmosphere Engine

### 11.1 Hierarchical Model

```
MusicBrain (Master Controller, master_volume: 0.0-1.0)
├── Music Layer (Dual-Deck A/B Crossfade, 3s InOutCubic)
│   └── Theme → State → Track → LoopNode
│       Intensity Levels: base, level1, level2, level3, level4, level5
├── Ambience Layer (4 Independent Slots, per-slot volume)
└── SFX Layer (8 Pooled Players, fire-and-forget)
```

### 11.2 Theme Definition (YAML)

```yaml
name: "Forest"
states:
  normal:
    base: { file: "forest_ambience.mp3", repeat: 0 }
    level1: { file: "birds.mp3" }
  combat:
    base: { file: "drums.mp3" }
    level2: { file: "strings.mp3" }
```

### 11.3 Crossfade

Dual-deck (A/B) crossfade with constant-power curve (InOutCubic, 3000ms). Active deck fades out while inactive deck fades in, then deck references swap. Prevents loudness dip during transitions.

### 11.4 Audio Format Support

`.wav`, `.mp3`, `.ogg`, `.flac`, `.m4a` — all stored locally in `assets/soundpad/`.

---

## 12. Projection, Screen Sharing & Multi-Display

### 12.1 Content Modes

| Mode | Content | Control |
|------|---------|---------|
| **Image** | 1-4 images with auto-layout (full/split/grid) | DM selects images |
| **Battle Map** | Live map with tokens + fog (read-only) | Real-time sync from DM |
| **PDF** | Embedded PDF viewer | DM selects document |
| **Stat Block** | HTML-rendered entity stats | DM selects entity |
| **Black Screen** | Solid black (dramatic reveal) | One-click toggle |

### 12.2 Multi-Image Layout

| Image Count | Layout |
|-------------|--------|
| 1 | Full viewport |
| 2 | Horizontal 50/50 split |
| 3 | Top full + bottom 50/50 |
| 4+ | 2×N grid |

### 12.3 Display Delivery Methods

The player window is a content receiver accepting rendering commands via signals/events. It can be delivered through:
- **Direct second monitor** — native window placed on secondary display
- **Miracast/AirPlay** — wireless projection from the player window to a TV
- **Screen sharing** — OBS, Discord, Zoom targeting the player window
- **WebSocket** — remote clients receive the same projection commands over network
- **Mobile** — phone/tablet app rendering the player view

---

## 13. Session Management & Timeline

### 13.1 Session Structure

Each session stores: name, date, DM notes (markdown), event log (markdown, auto-generated + manual), and full combat state (combatants with HP, conditions, initiative, token positions, fog state).

### 13.2 Timeline

World map timeline with day-numbered pins. Pins linked to entities and sessions. Chain connections via parent_id for multi-step journeys. Color propagation across chains.

---

## 14. World Map & Geography

Image-based world map with pan/zoom. Entity pins (clickable → open entity). Timeline pins (day-based markers). Pin CRUD with color/note editing. Location entities show a "residents list" (all entities referencing that location).

---

## 15. API Integration & Content Library

### 15.1 External Sources

| Source | URL | Content |
|--------|-----|---------|
| D&D 5e SRD | dnd5eapi.co | Monsters, Spells, Equipment, Classes, Races, Feats, Conditions, Backgrounds |
| Open5e | open5e.com | Extended monster/spell library with community content |

### 15.2 Import Pipeline

```
External API → Raw JSON → EntityParser → Normalized Entity Dict → EntityRepository.save()
                                ↓
                   Detect referenced spells/items (_detected_spell_indices)
                                ↓
                   Auto-import dependencies (deduplicated by name)
```

### 15.3 Abstract Source Pattern

`ApiSource` abstract base class with concrete implementations (`Dnd5eApiSource`, `Open5eApiSource`). Methods: `get_list()`, `get_details()`, `search()`, `get_supported_categories()`, `get_documents()`. New API sources can be added by implementing this interface.

---

## 16. Theming & Localization

### 16.1 Themes (11)

Dark, Light, Midnight, Amethyst, Baldur (Baldur's Gate), Discord, Emerald, Frost, Grim, Ocean, Parchment. Each defines ~80 color variables controlling all surface, text, button, canvas, and combat colors. Runtime switching — no restart required.

### 16.2 Localization (4 Languages)

English, Turkish, German, French. ~250 locale keys per language (YAML files). Runtime switching. All UI strings via `tr(key)` function.

---

## 17. Real-Time Event System & Network Architecture

### 17.1 EventBus (Local, Implemented)

In-process publish/subscribe with named events. 24 event types defined with Pydantic v2 payload schemas. Every data mutation publishes an event. Exception-safe handler invocation.

### 17.2 Event Catalog (24 Types)

| Domain | Events |
|--------|--------|
| Campaign | `campaign.loaded`, `campaign.saved`, `campaign.created` |
| Entity | `entity.created`, `entity.updated`, `entity.deleted` |
| Session | `session.created`, `session.activated`, `session.combatant_added`, `session.combatant_updated`, `session.turn_advanced` |
| Map | `map.image_set`, `map.fog_updated`, `map.pin_added`, `map.pin_removed` |
| Mind Map | `mindmap.node_created`, `mindmap.node_updated`, `mindmap.node_deleted`, `mindmap.edge_created`, `mindmap.edge_deleted` |
| Projection | `projection.content_set`, `projection.mode_changed` |
| Audio | `audio.state_changed`, `audio.track_triggered` |

### 17.3 NetworkBridge (Skeleton, Implemented)

Connection state machine: `DISCONNECTED → CONNECTING → CONNECTED → ERROR`. Defines 17 event types to forward to server. Pending event queue for offline-to-online sync. Socket.io client integration point (ready for implementation).

### 17.4 Event Schema (Pydantic v2)

All 24 event types have validated payload models. Example:
```python
class EntityUpdatedPayload(BaseModel):
    entity_id: str
    changed_fields: list[str] = Field(default_factory=list)

class MapFogUpdatedPayload(BaseModel):
    fog_data: str  # base64-encoded PNG

class TurnAdvancedPayload(BaseModel):
    session_id: str
    new_active_combatant_id: str
```

---

## 18. Online Play — Vision & Architecture

### 18.1 Vision

> *"Preserve the full power of the DM's desktop tool. Let players join with minimal friction — a single 6-character code."*

The DM controls everything. Players are guests, not peers. Every feature works offline. Online connectivity enhances but never requires. Content marked private is never transmitted to players — not even encrypted.

### 18.2 User Experience

**DM:** Clicks "Start Online Session" → receives 6-character join code → shares with players → continues using the app exactly as offline. All changes auto-sync to connected players.

**Player (Web):** Opens browser URL → enters join code + display name → instantly sees DM's projected content (battle map, images, stat blocks).

**Player (Desktop/Mobile):** Opens app in Player Mode → enters join code → simplified player-only interface.

### 18.3 Server Architecture (Planned)

```
FastAPI + python-socketio (ASGI)
├── /auth/*          — JWT authentication (DMs require accounts; players optional)
├── /sessions/*      — Create, join (6-char code), list, archive
├── /assets/*        — Signed URL proxy for images/audio
├── Socket.io /session namespace — Event relay with permission enforcement
│   └── Rooms: session:{id} (all), session:{id}:dm (DM-only)
├── PostgreSQL       — Session data, event log, user accounts
├── Redis            — PubSub, rate limiting, session cache
└── MinIO            — S3-compatible asset storage
```

### 18.4 Permission Model

| Role | Capabilities |
|------|-------------|
| **DM** | Full access: entity CRUD, fog editing, combat control, audio, projection |
| **Player** | View projected content, own character sheet editing, dice rolling, chat |
| **Spectator** | View projected content only (for streams/audiences) |

### 18.5 Key Design Decisions

- **DM client is source of truth** — server is a relay, not a game engine
- **Incremental sync** — events carry deltas, not full state snapshots
- **Asset proxy** — large files served via MinIO signed URLs, not through WebSocket
- **Zero content leakage** — private DM content never sent to player clients
- **Graceful degradation** — network dropout handled; pending events queued for reconnection

### 18.6 Online-Only Features (Future)

- **Server-side dice roller** — cryptographically secure, prevents cheating
- **In-game chat** — text chat with dice commands visible to all
- **Restricted entity views** — DM marks fields as private/shared per entity
- **Session history** — archived sessions with full event logs
- **Cloud deployment** — Docker containers, self-hosted or cloud-hosted options

---

## 19. Pre-Online Stability Requirements

Before the online phase begins, these stability gates must be met:

### 19.1 Functional Gates (Defined in docs/PRE_ONLINE.md)

| Gate | Status |
|------|--------|
| All 7 mandatory UI/UX tasks complete | 6/7 complete (Soundpad transition remaining) |
| EventManager local dispatch operational | ✅ Complete (EventBus) |
| Socket.io client skeleton integrated | ✅ Complete (NetworkBridge) |
| Embedded PDF viewer operational | ✅ Complete |
| No Priority 1 bugs | ✅ Clean |

### 19.2 Quality Gates

| Gate | Status |
|------|--------|
| Test coverage ≥ 60% on core/ | Not yet verified |
| ruff linting passes | Configured in pyproject.toml |
| Turkish comments removed from core | ✅ Complete |
| Module docstrings on core/ files | Partially complete |

### 19.3 Localization Gates

| Gate | Status |
|------|--------|
| All new UI strings in EN/TR/DE/FR | ✅ Complete |
| No hardcoded English in UI | ✅ Mostly complete |
| All 4 locales tested | Not yet verified |

---

## 20. Planned Features — Full Roadmap

### 20.1 World Building & Customization

| Feature | Description | Documented In |
|---------|-------------|--------------|
| **Dynamic Entity Types** | User-defined entity schemas with custom field types (text, markdown, integer, float, boolean, enum, date, image, file, relation, formula) | docs/PRE_ONLINE.md §5.1 |
| **World Templates** | Shareable `.dmt-template` packages (ZIP with manifest, schemas, starter data, assets) | docs/PRE_ONLINE.md §5.2 |
| **Custom Import** | CSV/XML import into custom world structures | TODO.md |
| **Faction System** | Faction entities with reputation tracking per PC | Conceptual |
| **Calendar System** | Custom in-game calendars with events and holidays | Conceptual |
| **Economy Tracker** | Party gold, item prices, shop inventories | Conceptual |
| **Random Tables** | Custom random encounter/loot/NPC name tables | Conceptual |

### 20.2 Dungeon Mastering Tools

| Feature | Description |
|---------|-------------|
| **Encounter Builder** | CR calculator, difficulty estimation, monster grouping |
| **Advanced Battle Map** | Hex grids, isometric, cone/line AoE, DM-only drawing layers (docs/PRE_ONLINE.md §5.4-5.7) |
| **Dice Roller** | Shared dice with history, custom expressions, advantage/disadvantage |
| **Stat Block Generator** | Quick NPC/monster creation from templates |
| **Random Generators** | NPC name/trait generator, encounter generator |
| **Folder-based Audio Randomization** | Point to folder → random track each loop |

### 20.3 Player Features (Online)

| Feature | Description |
|---------|-------------|
| **Character Sheet Viewer** | Player-editable character sheet (own PC only) |
| **Player Dice Roller** | Server-side rolls visible to DM and all players |
| **In-Game Chat** | Text chat with dice commands |
| **Inventory Management** | Player manages own inventory |
| **Spell Slot Tracker** | Visual spell slot management |

### 20.4 Social & Community

| Feature | Description | Documented In |
|---------|-------------|--------------|
| **Package Registry** | Community-shared templates, assets, rulesets | docs/PRE_ONLINE.md §5.8-5.11 |
| **Package Types** | `.dmt-template`, `.dmt-world`, `.dmt-assets`, `.dmt-ruleset` | docs/PRE_ONLINE.md §5.8 |
| **Safety Standards** | SHA-256 checksum, file type whitelist, no executables, import preview | docs/PRE_ONLINE.md §5.9 |
| **Moderation** | Draft → Published → Flagged → Deprecated → Removed lifecycle | docs/PRE_ONLINE.md §5.11 |
| **Public Campaign Profiles** | Share campaign summaries, art, and session recaps | Conceptual |
| **Webhook Integration** | Discord/Slack notifications for session events | Conceptual |

### 20.5 Technical Improvements

| Feature | Description |
|---------|-------------|
| **Plugin System** | Third-party extensions via standardized API |
| **Export** | Campaign export to PDF, JSON, or Markdown |
| **Backup & Restore** | Versioned campaign backups with restore points |
| **Image to Note (OCR)** | Convert handout images to editable text |
| **D&D Beyond Integration** | Character import from D&D Beyond |
| **Obsidian MD Integration** | Two-way sync with Obsidian vault |

---

## 21. Codebase Statistics & Quality Indicators

### 21.1 Size Metrics (v0.8.4)

| Metric | Value |
|--------|-------|
| Total Python files | 107 |
| Total lines of code | 22,881 |
| UI layer files (framework-dependent) | 53 |
| UI layer LOC | ~15,000 |
| Core layer files (portable, UI-free) | 20+ |
| Core layer LOC | ~7,000 |
| Test files | 13 |
| Test LOC | ~900 |
| Theme files | 12 (11 themes + 1 common) |
| Locale files | 4 (EN, TR, DE, FR) |
| Entity types | 15 |
| Event types | 24 (all with Pydantic v2 schemas) |
| Theme palettes | 11 (~80 color variables each) |

### 21.2 Architecture Quality

| Indicator | Status |
|-----------|--------|
| Repository pattern (data access) | ✅ 6 focused sub-managers |
| Event-driven communication | ✅ EventBus (24 event types) |
| Presenter layer (business logic) | ✅ CombatPresenter, NpcPresenter |
| Network event schemas (Pydantic v2) | ✅ 24 validated payload models |
| Zero bare `except` clauses | ✅ |
| Structured logging (`logging` module) | ✅ 37 files |
| Type hints on public APIs | ~60% |
| English-only code comments | ✅ |
| `__init__.py` in all packages | ✅ |
| UI-free core layer | ✅ (1 exception: audio engine) |

### 21.3 IMPROVEMENT_ROADMAP Completion

| Phase | Status |
|-------|--------|
| Phase 1: Foundation (logging, type hints, comments, bare except) | 100% |
| Phase 2: God Class Decomposition (DataManager, NpcSheet, CombatTracker) | 100% |
| Phase 3: UI Consistency (inline CSS → QSS, theme fixes, button standardization) | 100% |
| Phase 4: Architecture Patterns (API abstraction, presenters, event bus) | 95% |
| Phase 5: Testing & Documentation | 70% |

---

## 22. Competitive Context

### 22.1 Market Comparison

| Tool | Type | Offline | Online | Audio | DM Screen | Mind Map | Mobile |
|------|------|---------|--------|-------|-----------|----------|--------|
| **Roll20** | VTT (browser) | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Foundry VTT** | VTT (self-host) | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Fantasy Grounds** | VTT (desktop) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Owlbear Rodeo** | VTT (browser) | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **World Anvil** | World building | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ |
| **DM Helper** | Notes tool | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **DungeonMasterTool** | **DM Command Center** | **✅** | **Planned** | **✅** | **✅** | **✅** | **Planned** |

### 22.2 Key Differentiators

1. **DM Projection System** — Built-in second-monitor projection with real-time battle map sync. No competitor offers this as a native feature.
2. **Adaptive Audio Engine** — Multi-track intensity-driven audio with constant-power crossfade. Unique among tabletop tools.
3. **Offline-First + Online-Ready** — Full functionality offline; designed for seamless online transition.
4. **Unified Workspace** — Combat, notes, maps, audio, mind map, and projection in one application.
5. **Mind Map Campaign Planning** — Infinite canvas with LOD rendering for story arc planning. Rare among RPG tools.
6. **System-Agnostic Entity Model** — Extensible beyond D&D 5e with planned dynamic entity types.
7. **Open Source (MIT)** — Full source code access for customization and extension.

---

*This document provides a complete product and technical specification of the Dungeon Master Tool. An evaluator should be able to assess any technology stack for deploying this application across desktop (Windows, macOS, Linux), mobile (Android, iOS), and web platforms based solely on the information provided here.*
