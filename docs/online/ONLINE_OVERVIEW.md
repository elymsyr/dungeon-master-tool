# Dungeon Master Tool — Online System Overview

> **Document version:** 1.0
> **Date:** March 18, 2026
> **Status:** Definitive Architecture Reference
> **Scope:** Complete online system architecture, goals, specifications, and implementation strategy
> **Audience:** Engineering, product, operations, and external contributors
> **Companion documents:** `docs/DEVELOPMENT_REPORT.md` (technical deep-dive), `docs/SPRINT_MAP.md` (sprint execution plan)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Product Vision and Goals](#2-product-vision-and-goals)
3. [Technical Success Criteria](#3-technical-success-criteria)
4. [Current System Analysis](#4-current-system-analysis)
5. [Target Architecture](#5-target-architecture)
6. [Technology Stack](#6-technology-stack)
7. [Role and Permission Model](#7-role-and-permission-model)
8. [REST API Design](#8-rest-api-design)
9. [WebSocket Event Catalog](#9-websocket-event-catalog)
10. [Database Design](#10-database-design)
11. [Asset Management](#11-asset-management)
12. [Security Design](#12-security-design)
13. [Performance and Scalability](#13-performance-and-scalability)
14. [Network Resilience](#14-network-resilience)
15. [Phase-Based Implementation Plan](#15-phase-based-implementation-plan)
16. [Testing Strategy](#16-testing-strategy)
17. [Deployment and Operations](#17-deployment-and-operations)
18. [Feature Flags and Versioning](#18-feature-flags-and-versioning)
19. [Risk Register](#19-risk-register)

---

## 1. Executive Summary

### 1.1 What This Document Is

This document is the **definitive online system architecture and goals reference** for Dungeon Master Tool. It consolidates, reorganizes, and expands upon the content originally developed in `docs/DEVELOPMENT_REPORT.md` and `docs/SPRINT_MAP.md`, providing a single authoritative source for every architectural decision, protocol specification, and implementation guideline related to the online transition.

### 1.2 The Application

Dungeon Master Tool is an offline-first PyQt6 desktop application (Alpha v0.7.7) designed for tabletop RPG game masters. It provides a comprehensive suite of tools for campaign management, including entity databases, interactive mind maps, battle maps with fog of war, a layered audio engine (MusicBrain), combat tracking, and multi-format content projection to a player screen.

### 1.3 What "Online" Means

The online transition is not a simple network layer addition. It represents a fundamental architectural evolution that touches every layer of the application:

- **Architecture:** Evolving from a single-user desktop application to a **hybrid client-server model** where the DM desktop application acts as the master client and player instances connect as restricted clients through a centralized server.
- **Identity and Access:** Introducing a **role and permission model** (DM, Player, Observer) where the server enforces content visibility rules and prevents unauthorized data exposure.
- **Real-Time Synchronization:** Building a **real-time event-driven backbone** that keeps maps, audio, mind maps, combat state, and projected content synchronized across all connected clients.
- **Infrastructure:** Implementing **asset distribution, caching, security, backup, and observability** layers that support both self-hosted and hosted deployment models.
- **Business Foundation:** Establishing the technical groundwork for a **subscription model** and **hosted service** without compromising the offline-first experience that existing users rely on.

### 1.4 Strategic Approach

The online transition follows a phased strategy with strict entry and exit criteria at each phase boundary:

1. **Phase 0 (Foundations):** Internal cleanup, UI consolidation, EventManager abstraction layer, and socket infrastructure. No online features ship until this phase completes.
2. **Phase 1 (Online MVP Core):** Authentication, session management, basic map and projection synchronization, and asset proxying. The minimum viable online experience.
3. **Phase 2 (Enhanced Sync):** Audio synchronization, mind map push/receive, and standalone player instance. The interactive online experience.
4. **Phase 3 (Product Maturation):** Automated event log, server-authoritative dice roller, restricted card views, and player character sheets. The complete online gameplay experience.
5. **Phase 4 (Operational Scaling):** Self-hosted production deployment, backup/restore, voice chat (feature-flagged), and hosted server foundation. The production-ready online platform.

### 1.5 Critical Success Factor

**Phase discipline.** Phase 0 must be completed before any online work begins. Each subsequent phase has formal exit criteria that must be met before proceeding. This discipline prevents the accumulation of technical debt that would undermine the reliability and security of the online system.

### 1.6 Current Status

As of March 18, 2026, the project is in **Sprint 1 of Phase 0** (March 9 - March 20, 2026). Active work includes UI consolidation, the EventManager skeleton, and common style token standardization. The sprint dependency chain runs through 8 sprints concluding at the end of June 2026.

---

## 2. Product Vision and Goals

### 2.1 Core Vision

Dungeon Master Tool aspires to be a platform that:

- **Preserves the DM's desktop power and control** — the offline experience remains the primary mode, and the DM retains full authority over every aspect of their campaign. Online capabilities augment but never diminish the desktop experience.
- **Allows players to join sessions with minimal friction** — a player should be able to join a game session by entering a 6-character alphanumeric code, with no account creation required for basic participation. The barrier to entry for a new player at a table must be measured in seconds, not minutes.
- **Synchronizes maps, media, audio, and interactive gameplay elements in real-time** — when the DM changes the battle map, adjusts the soundtrack, shares an entity card, or advances combat, every connected player sees and hears the change within milliseconds.
- **Remains secure, measurable, and scalable** — sensitive DM content (notes, hidden entities, unrevealed map areas) is never transmitted to unauthorized clients, and the system provides clear metrics on performance, reliability, and usage.

### 2.2 Preserve Offline-First Power

The offline-first principle is non-negotiable. The online transition must satisfy these constraints:

- **Zero degradation of offline functionality.** Every feature that works today in offline mode must continue to work identically when the server is unreachable. Campaign data remains stored locally in MsgPack format. The DM never depends on an internet connection to run their campaign.
- **Additive online capabilities.** Online features are layered on top of the existing architecture through the EventManager abstraction. When the EventManager is in `LOCAL` mode, events dispatch directly to local subscribers. When in `ONLINE` mode, events route through the WebSocket layer to the server and back to all clients.
- **Graceful degradation.** If the network connection drops during an online session, the DM application continues to function locally. Players see a reconnecting indicator. When connectivity resumes, state is resynchronized automatically.
- **No forced migration.** Existing campaign data files (`data.dat` in MsgPack format) are not migrated to a server database. The local filesystem remains the authoritative campaign storage. The server stores only session metadata, shared entity snapshots, event logs, and asset references.

### 2.3 Minimal-Friction Player Join

The player join experience is designed around the principle that tabletop RPG sessions often include newcomers who should not face technology barriers:

- **6-character join code.** The DM creates an online session and receives a short alphanumeric code (e.g., `XY1234`). Players enter this code in their client application to join instantly.
- **No account required for basic play.** Anonymous players can join with just a display name and the join code. Account creation is optional and unlocks persistent features like saved character sheets and session history.
- **Automatic asset delivery.** When a player joins, all currently visible content (maps, projected images, audio state) is delivered automatically. The player does not need to download or configure anything manually.
- **Join key expiration.** Join keys expire after 24 hours by default but can be regenerated by the DM at any time. This prevents stale codes from being used to access sessions unintentionally.

### 2.4 Real-Time Synchronization

The synchronization system must handle four distinct content categories, each with different update patterns and latency requirements:

| Content Category | Update Pattern | Latency Target | Conflict Strategy |
|-----------------|---------------|----------------|-------------------|
| Maps and projection | Full state replace | < 3s (first load), < 120ms (updates) | Server-authoritative, last-write-wins |
| Audio state | Full state replace + crossfade commands | < 120ms (state), sync-tolerant (audio) | Server-time reference for crossfade alignment |
| Combat tracker | Full state replace | < 120ms | DM-authoritative, server-validated |
| Mind map nodes | Incremental upsert | < 200ms | Last-write-wins with origin tracking |

### 2.5 Subscription Foundation

The online system establishes the technical foundation for a future subscription model without implementing billing or payment processing in the initial release:

- **Storage quotas** are defined per plan tier (free, standard, premium) and enforced at the asset upload layer.
- **Session participant limits** are configurable per account, defaulting to 10 players.
- **Feature flags** control access to advanced features (voice chat, extended storage, backup automation).
- **Usage metrics** are collected to inform future pricing decisions.

The subscription infrastructure is designed to be layered in after the core online system is stable, without requiring architectural changes.

### 2.6 Self-Hosted and Hosted Options

The deployment model supports two operating modes:

- **Self-hosted:** A DM (or their technically inclined friend) runs the server stack on their own VPS or home server using Docker Compose. The server stack includes FastAPI, PostgreSQL, Redis, MinIO, and Nginx with TLS. A comprehensive deployment guide and automation scripts are provided.
- **Hosted:** An official hosted instance operated by the project team, where DMs create accounts and run sessions without managing infrastructure. The hosted option shares the same codebase and configuration as the self-hosted option, differing only in operational management.

Both options use identical server images and configuration formats, ensuring that a DM can migrate between self-hosted and hosted deployments by exporting and importing their session data.

---

## 3. Technical Success Criteria

### 3.1 Key Performance Indicators

The following KPIs define the measurable success thresholds for the online system. Each KPI has a target value, a measurement method, and a frequency at which it is evaluated.

| KPI | Target | Measurement | Evaluation Frequency |
|-----|--------|-------------|---------------------|
| P50 event latency (publish to client apply) | < 50ms | Server-side Prometheus histogram (`event_delivery_latency_ms`) | Continuous |
| P95 event latency (publish to client apply) | < 120ms | Server-side Prometheus histogram (`event_delivery_latency_ms`) | Continuous |
| P99 event latency (publish to client apply) | < 300ms | Server-side Prometheus histogram (`event_delivery_latency_ms`) | Continuous |
| 5MB map first load time (general internet) | < 3 seconds | Client-side timer from request to render complete | Per-session |
| Warm cache map load time | < 1 second | Client-side timer from cache hit to render complete | Per-session |
| Session reconnect and state recovery | < 5 seconds | Client-side timer from disconnect detection to full state recovery | Per-reconnect event |
| Unauthorized content leakage to player RAM/disk | Zero | Security audit, integration tests, code review | Per-release |
| Critical security breaches | Zero | Penetration testing, audit log monitoring | Continuous |
| Reconnect success rate | > 99% | Counter ratio (`successful_reconnects / total_reconnect_attempts`) | Continuous |
| Asset cache hit ratio | > 80% | Client-side counter (cache hits / total asset requests) | Per-session |
| Server uptime (hosted) | > 99.5% | Infrastructure monitoring | Monthly |

### 3.2 Load Testing Targets

The following load test scenarios define the capacity envelope the system must support:

| Scenario | Concurrent Sessions | Players per Session | Total Connections | Duration |
|----------|-------------------|--------------------|--------------------|----------|
| Baseline | 5 | 5 | 30 | 1 hour |
| Standard | 10 | 8 | 90 | 2 hours |
| Stress | 20 | 10 | 220 | 30 minutes |
| Soak | 5 | 5 | 30 | 3+ hours |

All scenarios must meet the P95 latency target. The stress scenario is allowed to degrade to P95 < 200ms. The soak scenario must complete without memory leaks, connection pool exhaustion, or Redis key accumulation.

### 3.3 Security Compliance Targets

| Requirement | Target | Validation |
|------------|--------|-----------|
| All REST endpoints authenticated (except registration and login) | 100% | Automated API test suite |
| All WebSocket events authorized against permission model | 100% | Integration test matrix |
| Sensitive DM data never transmitted to unauthorized clients | Zero violations | Security-focused E2E tests |
| Rate limiting active on all public endpoints | 100% | Load test verification |
| TLS enforced on all production connections | 100% | Certificate monitoring |
| Password storage using bcrypt with cost factor >= 12 | 100% | Unit test verification |

### 3.4 Quality Gates per Sprint

Each sprint must pass these quality gates before its deliverables are considered complete:

| Gate | Criteria |
|------|----------|
| Code review | All PRs reviewed and approved by at least one other team member |
| Unit test coverage | > 80% for new server code, > 70% for modified client code |
| Integration tests | All defined scenarios pass |
| Security scan | Zero high/critical findings from Bandit (Python) |
| Type checking | `mypy --strict` passes on `server/` and `core/` directories |
| Performance benchmark | All KPIs met in staging environment |

---

## 4. Current System Analysis

### 4.1 Technology Profile

| Attribute | Value |
|-----------|-------|
| Language | Python 3.10+ |
| GUI Framework | PyQt6 |
| Total source files | 56 Python files |
| Total lines of code | ~11,500 |
| Test files | 12 files (~850 lines) |
| Local persistence | MsgPack (`.dat`) primary, JSON fallback |
| Package distribution | PyInstaller binary |
| Version | Alpha v0.7.7 |

### 4.2 Complete Codebase Module Map

The following table catalogs every source file in the current codebase, its module classification, its primary responsibility, and the nature and scope of changes required for the online transition.

#### Core Modules

| File | Lines | Role | Online Impact |
|------|-------|------|---------------|
| `main.py` | 387 | Application entry point, MainWindow creation, run loop | Must support DM/Player mode selection at startup |
| `config.py` | 147 | Path resolution, theme loading, configuration management | Must add server URL, auth token storage paths, online mode settings |
| `core/data_manager.py` | 677 | Central data hub: entity CRUD, campaign I/O, API client integration, library cache | Must be extended with event emission for all state mutations; primary integration point for EventManager |
| `core/api_client.py` | 705 | D&D 5e and Open5e external API integration for content import | No direct online impact; operates independently of session system |
| `core/models.py` | 197 | Entity schemas (15 types), legacy migration maps, schema definitions | Must add Pydantic equivalents for network transfer; existing dict-based schemas remain for local storage |
| `core/library_fs.py` | 250 | Local library filesystem scan and migration utilities | No direct online impact; local-only functionality |
| `core/locales.py` | 26 | Internationalization setup (python-i18n wrapper) | No change needed |
| `core/theme_manager.py` | 284 | UI theme palette management (11 themes) | No change needed; themes are client-local |

#### Audio Modules

| File | Lines | Role | Online Impact |
|------|-------|------|---------------|
| `core/audio/engine.py` | 327 | MusicBrain layered audio engine (themes, states, intensity, ambience) | Must expose state for serialization and sync; add `get_state()` and `apply_state()` methods |
| `core/audio/models.py` | 36 | Audio data structures (LoopNode, Track, MusicState, Theme) | Must be serializable for AUDIO_STATE events; add Pydantic model equivalents |
| `core/audio/loader.py` | 286 | Soundpad theme file loading from YAML configuration | No direct online impact; theme loading is local-only |

#### Development Modules

| File | Lines | Role | Online Impact |
|------|-------|------|---------------|
| `core/dev/hot_reload_manager.py` | 348 | Hot reload state machine for development mode | Dev-only, no online impact |
| `core/dev/ipc_bridge.py` | 164 | IPC communication for development mode | Dev-only, no online impact |
| `dev_run.py` | 436 | Hot reload development runner | Dev-only |
| `dump.py` | 113 | Debug dump utility | Dev-only |

#### UI Root and Navigation

| File | Lines | Role | Online Impact |
|------|-------|------|---------------|
| `ui/main_root.py` | 162 | Widget factory (`create_root_widget`), main layout composition | Must support DM/Player mode switching and Session Control panel integration |
| `ui/campaign_selector.py` | 123 | World selection dialog at startup | Must add online login/join flow as an alternative to local world selection |
| `ui/player_window.py` | 147 | Player screen projection (second monitor display) | Must accept remote content via WebSocket events instead of only local signals |

#### UI Tabs

| File | Lines | Role | Online Impact |
|------|-------|------|---------------|
| `ui/tabs/database_tab.py` | 296 | Entity/content browser (dual-panel layout) | Must support shared/restricted entity views based on player permissions |
| `ui/tabs/mind_map_tab.py` | 617 | Infinite canvas mind map with nodes and connections | Must support push/receive node sync and multi-user editing |
| `ui/tabs/map_tab.py` | 271 | World map with timeline and location pins | Must support real-time pin and fog of war synchronization |
| `ui/tabs/session_tab.py` | 272 | Session management and embedded combat tracker | Must integrate online session controls (create, join, close, player list) |

#### UI Widgets

| File | Lines | Role | Online Impact |
|------|-------|------|---------------|
| `ui/widgets/combat_tracker.py` | 912 | Initiative tracking, HP, conditions, token management | Must sync combat state in real-time; DM-only fields stripped for players |
| `ui/widgets/npc_sheet.py` | 1002 | Rich entity editor with all field types | Must support shared/restricted field rendering based on visibility level |
| `ui/widgets/entity_sidebar.py` | 332 | Quick entity search and filter panel | No direct online impact; operates on local data |
| `ui/widgets/mind_map_items.py` | 455 | Canvas drawing primitives (nodes, connections, workspace items) | Must add origin, visibility, and sync_id metadata to all node types |
| `ui/widgets/map_viewer.py` | 232 | Map display widget with fog of war overlay | Must accept remote fog state from server broadcasts |
| `ui/widgets/markdown_editor.py` | 415 | Rich text editing with HTML preview | No direct online impact; editing is local |
| `ui/widgets/projection_manager.py` | 231 | Drag-drop image projection bar | Must emit network events in addition to local Qt signals |
| `ui/widgets/image_viewer.py` | 55 | Simple image display widget | No direct online impact |
| `ui/widgets/aspect_ratio_label.py` | 68 | Aspect-ratio preserving QLabel | No direct online impact |

#### UI Windows

| File | Lines | Role | Online Impact |
|------|-------|------|---------------|
| `ui/windows/battle_map_window.py` | 762 | Battle map with fog of war management, grid overlay, token placement | Must sync fog state, grid changes, and token positions with all connected players |

#### UI Dialogs

| File | Lines | Role | Online Impact |
|------|-------|------|---------------|
| `ui/dialogs/api_browser.py` | 490 | D&D content API browser | No direct online impact |
| `ui/dialogs/bulk_downloader.py` | 290 | Content bulk downloader from external APIs | No direct online impact |
| `ui/dialogs/import_window.py` | 422 | Campaign import wizard | No direct online impact |
| `ui/dialogs/encounter_selector.py` | 211 | Encounter builder dialog | No direct online impact |
| `ui/dialogs/entity_selector.py` | 121 | Entity selection dialog | No direct online impact |
| `ui/dialogs/theme_builder.py` | 187 | Custom theme editor | No direct online impact |
| `ui/dialogs/timeline_entry.py` | 134 | Timeline pin editor | No direct online impact |

#### Utility and Build

| File | Lines | Role | Online Impact |
|------|-------|------|---------------|
| `ui/workers.py` | 71 | Background worker threads | No direct online impact |
| `installer/build.py` | 101 | PyInstaller build script | Must include new server-related dependencies (python-socketio, pydantic) |

### 4.3 Online Impact Assessment Summary

| Category | Files | Online-Impacted Files | Percentage |
|----------|-------|----------------------|------------|
| Core | 8 | 4 | 50% |
| Audio | 3 | 2 | 67% |
| Dev | 4 | 0 | 0% |
| UI Root/Nav | 3 | 3 | 100% |
| UI Tabs | 4 | 4 | 100% |
| UI Widgets | 9 | 5 | 56% |
| UI Windows | 1 | 1 | 100% |
| UI Dialogs | 7 | 0 | 0% |
| Utility/Build | 2 | 1 | 50% |
| **Total** | **41** | **20** | **49%** |

New files to be created for online functionality:

| New File | Module | Purpose |
|----------|--------|---------|
| `core/event_manager.py` | Core | EventManager abstraction layer (local/online dispatch) |
| `core/socket_client.py` | Core | python-socketio wrapper with reconnect state machine |
| `server/` (directory) | Server | Complete FastAPI backend (auth, sessions, events, assets) |
| `docker-compose.yml` | DevOps | Development environment orchestration |
| `docker-compose.prod.yml` | DevOps | Production environment orchestration |
| `nginx/` (directory) | DevOps | Reverse proxy and TLS configuration |
| `.github/workflows/deploy.yml` | CI/CD | Deployment pipeline |
| `scripts/backup.sh` | Ops | Automated backup script |

### 4.4 Signal and Slot Architecture Analysis

The current application uses PyQt6's signal/slot mechanism exclusively for inter-component communication. This analysis identifies every signal pathway that must be intercepted by the EventManager for online event routing.

#### DataManager Signals

`DataManager` is the central hub. All data mutations flow through it and trigger Qt signals that UI widgets listen to:

```
DataManager.data_changed → Multiple UI widgets refresh
DataManager.entity_updated → NpcSheet, EntitySidebar, DatabaseTab
DataManager.campaign_loaded → All tabs reinitialize
DataManager.session_changed → SessionTab, CombatTracker
```

**Online impact:** Every signal emission point in DataManager must also emit a corresponding event through EventManager. The EventManager then routes events locally (offline mode) or through the WebSocket (online mode).

#### Player Window Signals

The player window receives content through direct method calls from the DM's main window:

```
ProjectionManager.projection_changed → PlayerWindow.add_image_to_view()
NpcSheet.share_to_player → PlayerWindow.show_stat_block()
MapViewer.projection_changed → PlayerWindow.show_pdf() / show_image()
```

**Online impact:** These direct method calls must be replaced with event emissions. In online mode, the events are sent to the server and broadcast to player clients, which then call the equivalent display methods on their local PlayerWindow instances.

#### Combat Tracker Signals

The combat tracker has the most complex internal signal graph:

```
CombatTracker.initiative_changed → reorder combatant list
CombatTracker.hp_changed → update HP display, check death
CombatTracker.condition_added → update condition list
CombatTracker.turn_advanced → highlight current combatant
CombatTracker.combat_started → set combat active flag
CombatTracker.combat_ended → clear combat state
```

**Online impact:** All combat state changes must be captured as a single `COMBAT_STATE_SYNC` event containing the full combat state. This avoids complex partial-update synchronization for combat state, which changes infrequently but involves many interdependent fields.

#### Mind Map Signals

Mind map interactions involve both node-level and canvas-level signals:

```
MindMapNode.position_changed → canvas updates connections
MindMapNode.content_changed → node redraws
MindMapNode.size_changed → canvas updates connections
MindMapTab.node_added → canvas adds visual item
MindMapTab.node_deleted → canvas removes visual item
MindMapTab.connection_added → canvas draws connection line
MindMapTab.connection_removed → canvas removes connection line
```

**Online impact:** Node changes use incremental `MINDMAP_NODE_UPDATE` events with debouncing. Node creation and deletion use `MINDMAP_PUSH` and `MINDMAP_NODE_DELETE` events. Connection changes use `MINDMAP_LINK_SYNC` events. Each node gains `origin`, `visibility`, and `sync_id` metadata fields.

#### Audio Engine Signals

The MusicBrain audio engine manages layered state:

```
MusicBrain.theme_changed → SoundpadPanel updates UI
MusicBrain.state_changed → SoundpadPanel updates intensity display
MusicBrain.volume_changed → SoundpadPanel updates slider
MusicBrain.ambience_changed → SoundpadPanel updates ambience slots
```

**Online impact:** All state changes emit `AUDIO_STATE` events. Crossfade transitions emit `AUDIO_CROSSFADE` events with server-time synchronization references. Volume slider movements are debounced (100ms) before emitting.

### 4.5 Serialization Format Considerations

#### Current: MsgPack

The application uses MsgPack as its primary local persistence format:

- **Campaign data:** `campaign_folder/data.dat` contains the complete campaign state serialized as MsgPack binary.
- **Advantages:** Compact binary format, fast serialization/deserialization, handles nested Python dicts natively.
- **Limitations:** No schema enforcement, no versioning, no type safety at serialization boundary.

#### Network: JSON over WebSocket

For network transfer, the system uses JSON:

- **Rationale:** Human-readable for debugging, universally supported, Pydantic models serialize to JSON natively.
- **Event payloads:** All WebSocket events use JSON serialization with Pydantic model validation on both sides.
- **REST API:** Standard JSON request/response format.

#### Migration Consideration

MsgPack local files are not migrated to JSON or to the server database. The dual-format approach is intentional:

- **Local storage:** MsgPack remains for performance and backward compatibility. The `data.dat` file is the authoritative campaign source.
- **Network transfer:** JSON for interoperability and debuggability. Pydantic models serve as the translation layer between MsgPack-backed Python dicts and JSON-serialized network payloads.
- **Server storage:** PostgreSQL with JSONB columns for flexible entity snapshots. Only session metadata and shared content are stored server-side.

### 4.6 Gap Analysis

| Area | Current State | Required for Online | Gap Severity |
|------|--------------|-------------------|-------------|
| Network layer | None | WebSocket + REST API with authentication | Critical |
| Authentication | None | JWT + session membership + refresh rotation | Critical |
| Event bus | Direct Qt signals only | EventManager abstraction with local/online modes | Critical |
| Centralized state | DataManager.data dict with direct access | Server-authoritative session state with event emission | Critical |
| Permission model | None (single user) | Role-based access control (DM/Player/Observer) | Critical |
| Content sharing | Local projection only | Network-based projection with visibility rules | High |
| Audio sync | Local MusicBrain only | Real-time audio state broadcast with crossfade sync | High |
| Asset distribution | Local filesystem | Signed URL proxy + client-side cache management | High |
| Observability | print() statements | Structured logging + Prometheus metrics + alerts | Medium |
| Deployment | Desktop binary only | Docker Compose + Nginx + TLS + CI/CD | Medium |
| Testing | 12 test files (~850 lines) | Comprehensive unit + integration + E2E + load tests | Medium |

---

## 5. Target Architecture

### 5.1 Hybrid Client-Server Model

The online architecture follows a hybrid model where the DM desktop application retains full campaign authority while a centralized server mediates real-time communication between participants.

```
┌──────────────────────────┐          ┌──────────────────────────┐
│    DM Application         │          │    Player Application     │
│    (PyQt6 Desktop)        │          │    (PyQt6 Desktop)        │
│                           │          │                           │
│  ┌──────────────────────┐ │          │  ┌──────────────────────┐ │
│  │    EventManager       │ │          │  │    EventManager       │ │
│  │  (LOCAL or ONLINE)    │ │          │  │  (ONLINE only)        │ │
│  └───────┬──────────────┘ │          │  └───────┬──────────────┘ │
│          │                │          │          │                │
│  ┌───────▼──────────────┐ │          │  ┌───────▼──────────────┐ │
│  │   Socket Client       │ │          │  │   Socket Client       │ │
│  │  (python-socketio)    │ │          │  │  (python-socketio)    │ │
│  └───────┬──────────────┘ │          │  └───────┬──────────────┘ │
└──────────┼───────────────┘          └──────────┼───────────────┘
           │ WSS + HTTPS                          │ WSS + HTTPS
           │                                      │
    ┌──────▼──────────────────────────────────────▼──────┐
    │                 Nginx Reverse Proxy                  │
    │              (TLS termination, rate limiting)        │
    └──────┬──────────────────────────────────────────────┘
           │
    ┌──────▼──────────────────────────────────────────────┐
    │              FastAPI Gateway Server                   │
    │                                                      │
    │  ┌────────────┐ ┌─────────────┐ ┌────────────────┐  │
    │  │ Auth Module │ │ Session Mgr │ │ Event Router   │  │
    │  │ (JWT,       │ │ (Create,    │ │ (Pub/Sub,      │  │
    │  │  refresh,   │ │  join,      │ │  filtering,    │  │
    │  │  guard)     │ │  close,     │ │  seq tracking) │  │
    │  └─────┬──────┘ │  kick)      │ └───────┬────────┘  │
    │        │        └──────┬──────┘         │            │
    │  ┌─────▼──────────────▼────────────────▼──────────┐ │
    │  │            python-socketio (ASGI)               │ │
    │  │       WebSocket connection management           │ │
    │  └────────────────────────────────────────────────┘ │
    └──────┬──────────┬──────────┬──────────────────────┘
           │          │          │
    ┌──────▼───┐ ┌───▼────┐ ┌──▼────────┐
    │  Redis    │ │Postgres│ │   MinIO    │
    │           │ │        │ │            │
    │ - Session │ │ - Users│ │ - Maps     │
    │   state   │ │ - Audit│ │ - Audio    │
    │ - PubSub  │ │ - Event│ │ - Images   │
    │ - Rate    │ │   log  │ │ - Backups  │
    │   limits  │ │ - Dice │ │            │
    │ - Event   │ │ - Share│ │            │
    │   buffer  │ │   grants││            │
    └──────────┘ └────────┘ └───────────┘
```

### 5.2 Bounded Contexts

The server is organized into five bounded contexts, each with clear responsibility boundaries and a designated primary data store:

| Context | Responsibility | Primary Store | Key Operations |
|---------|---------------|--------------|----------------|
| `identity` | User registration, login, JWT token lifecycle, subscription entitlements | PostgreSQL | Register, login, refresh, profile |
| `session` | Session create/join/close, participant lifecycle, join key management, session state | Redis + PostgreSQL | Create session, generate join key, track participants |
| `campaign` | Shared entity management, entity visibility grants, DM content protection | PostgreSQL (JSONB) | Share entity, update visibility, redact restricted fields |
| `media` | Asset upload, presigned URL generation, cache invalidation, storage quota enforcement | MinIO (S3-compatible) | Presign upload, generate download URL, enforce quotas |
| `sync` | Real-time event routing, sequence tracking, delta/full resync, event coalescing | Redis PubSub + Buffer | Route events, track seq, buffer for resync |

#### Context Interaction Patterns

```
identity ──(auth token)──► session ──(session_id, role)──► sync
                                   ──(session_id)────────► media
                                   ──(session_id)────────► campaign
```

- The `identity` context issues JWT tokens that all other contexts validate.
- The `session` context is the gateway: all operations require a valid session membership.
- The `sync` context is the real-time backbone: it receives events from the `session` context and routes them to connected clients.
- The `media` context is the asset layer: it handles file storage and retrieval, scoped to sessions.
- The `campaign` context manages what content is visible to which participants, applying redaction rules server-side.

### 5.3 Data Flow Principles

The following principles govern all data flow in the online system:

1. **Server-authoritative session state.** The server is the single source of truth for active session state. When conflicts arise, the server's state wins.

2. **Client-side optimistic UI.** Only for low-risk, non-shared actions (e.g., local audio volume adjustment, drag preview during mind map editing). Optimistic updates are reverted if the server rejects the action.

3. **Required event envelope fields.** Every event transmitted over WebSocket must include: `event_id` (UUID), `session_id`, `ts` (ISO 8601 timestamp), `schema_version`, and `seq` (monotonically increasing sequence number per session).

4. **Idempotent client apply pipeline.** Every event handler on the client must be safe to execute multiple times with the same event. Deduplication is performed by `event_id`.

5. **At-least-once delivery assumption.** The system assumes events may be delivered more than once. Clients must handle duplicates gracefully.

6. **DM-authoritative content decisions.** The DM decides what is shared, with whom, and at what visibility level. The server enforces these decisions but does not override them.

7. **Server-side content redaction.** When an entity is shared with `shared_restricted` visibility, the server strips `dm_notes`, hidden fields, and DM-flagged content before transmitting to player clients. The unredacted data never leaves the server for unauthorized recipients.

### 5.4 Key Architectural Decisions

#### Decision 1: EventManager as Universal Abstraction

The `EventManager` class (`core/event_manager.py`) is the central abstraction that enables the same application code to work in both offline and online modes:

- In `LOCAL` mode: `EventManager.emit()` dispatches events directly to local subscriber callbacks. No network involvement.
- In `ONLINE` mode: `EventManager.emit()` sends events through the `SocketClient` to the server, which validates, sequences, and broadcasts them to appropriate clients.

This design means that UI widgets and DataManager do not need to know whether they are operating online. They emit events and subscribe to events through the same API regardless of mode.

#### Decision 2: DataManager Event Emission Hooks

`DataManager.save_data()` currently writes directly to MsgPack. The online extension adds an event emission step:

```
save_data() → serialize to MsgPack (local) → emit event (if online) → server receives → broadcasts to peers
```

This is additive: the local save path is unchanged. The event emission is a new step that only executes when EventManager is in ONLINE mode.

#### Decision 3: MusicBrain State Serialization

The MusicBrain audio engine manages complex layered state across `master_volume`, `current_state_id`, `current_intensity_level`, and ambience slot volumes. For online sync:

- A new `get_state()` method returns the complete audio state as a serializable dict.
- A new `apply_state()` method accepts a state dict and transitions the engine to match, including crossfade handling.
- Crossfade operations use server-provided timestamps (`start_at`) for synchronized playback across clients.

#### Decision 4: PlayerWindow as Remote Display

In offline mode, `PlayerWindow` methods (`add_image_to_view()`, `show_stat_block()`, `show_pdf()`) are called directly from the DM's main window. In online mode:

- The DM client emits `PROJECTION_UPDATE` events when projecting content.
- The server broadcasts these events to player clients.
- Player clients call the equivalent `PlayerWindow` methods locally in response to the received events.

#### Decision 5: Mind Map Node Origin Tracking

`MindMapNode` currently has no ownership metadata. Online mode adds three fields:

- `origin`: Who created the node (`"dm"` or a `user_id`).
- `visibility`: Who can see it (`"private"`, `"shared_full"`, `"shared_restricted"`).
- `sync_id`: A stable identifier used for network synchronization, distinct from the local canvas item ID.

#### Decision 6: Server Directory Separation

The server code lives in a new `server/` directory at the project root, completely separate from the client code. Shared type definitions (event envelopes, Pydantic models) live in a `shared/` directory importable by both client and server.

---

## 6. Technology Stack

### 6.1 Desktop Application (DM and Player Client)

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| Language | Python | 3.12+ | Application language |
| GUI Framework | PyQt6 | 6.6+ | Desktop UI rendering |
| WebSocket Client | python-socketio[asyncio_client] | 5.10+ | Real-time server communication |
| Data Validation | Pydantic | v2.5+ | Event payload and API model validation |
| Local Serialization | MsgPack (msgpack-python) | 1.0+ | Campaign data persistence |
| HTTP Client | httpx | 0.25+ | REST API communication |
| Testing | pytest + pytest-qt + pytest-mock | Latest | Client-side test suite |
| Type Checking | mypy | Latest | Static type analysis |

### 6.2 Backend Server

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| API Framework | FastAPI | 0.109+ | REST API and ASGI application host |
| WebSocket Server | python-socketio | 5.10+ | Real-time event routing (ASGI mount) |
| ASGI Server | Uvicorn + Gunicorn | Latest | Production ASGI serving with worker management |
| ORM and Database | SQLAlchemy | 2.0+ | PostgreSQL interaction with async support |
| Migrations | Alembic | 1.13+ | Database schema migration management |
| Authentication | PyJWT + bcrypt | Latest | JWT token generation/validation + password hashing |
| Session and Cache | redis-py (async) | 5.0+ | Session state, PubSub, rate limiting, event buffer |
| Validation | Pydantic | v2.5+ | Request/response model validation |
| Task Queue | None (future: Celery) | — | Deferred to Phase 4 if background tasks are needed |

### 6.3 Data Stores

| Store | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| Relational Database | PostgreSQL | 16+ | Users, sessions, audit log, event log, dice rolls, shared entities |
| Cache and PubSub | Redis | 7+ | Session state, event routing, rate limiting, reconnect buffer |
| Object Storage | MinIO | Latest | S3-compatible storage for maps, audio, images, backups |

### 6.4 Observability Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Metrics Collection | Prometheus | Time-series metrics (latency, connections, event counts) |
| Metrics Visualization | Grafana | Dashboards and alerting |
| Log Aggregation | Loki + Promtail | Structured JSON log collection and search |
| Application Logging | Python structlog | Structured log emission with correlation IDs |

### 6.5 Infrastructure and Deployment

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Container Runtime | Docker + Docker Compose | Application containerization and orchestration |
| Reverse Proxy | Nginx | TLS termination, rate limiting, WebSocket upgrade, static asset serving |
| TLS Certificates | Let's Encrypt (Certbot) | Automated TLS certificate issuance and renewal |
| CI/CD | GitHub Actions | Automated testing, building, and deployment |
| Operating System | Ubuntu Server 24.04 LTS | Production server operating system |
| DNS Structure | `api.<domain>`, `ws.<domain>`, `assets.<domain>` | Service endpoint separation |
| Firewall | UFW | Network access control |
| Intrusion Prevention | fail2ban | Automated IP banning for brute force attempts |
| SSH | Key-only access | Secure server administration |

### 6.6 Development Tools

| Tool | Purpose |
|------|---------|
| Ruff | Python linting and formatting |
| mypy | Static type checking |
| Bandit | Security-focused static analysis |
| pytest-cov | Code coverage measurement |
| Docker Compose (dev profile) | Local development environment with hot reload |

---

## 7. Role and Permission Model

### 7.1 Role Definitions

The system defines three roles that govern what actions a participant can perform within a session:

| Role | Code | Description | Account Required |
|------|------|-------------|-----------------|
| Dungeon Master | `DM_OWNER` | Full control over the session. Creates, manages, and closes sessions. Controls all content sharing, audio, maps, and combat. Has unrestricted access to all campaign data. | Yes |
| Player | `PLAYER` | Restricted access. Can view content shared by the DM, edit their own mind map workspace nodes, roll dice, and view combat state. Cannot see DM-only content. | No (anonymous join supported) |
| Observer | `OBSERVER` | Read-only access. Can view all shared content and the event log but cannot interact with any game mechanics. Useful for spectators or stream audiences. | No (anonymous join supported) |

### 7.2 Permission Scopes

Permissions are defined as scopes. Each role is assigned a set of scopes that determine which operations it can perform:

| Scope | Description | Applies To |
|-------|-------------|-----------|
| `session:manage` | Create, close, configure, and pause sessions | REST + WS |
| `session:join` | Join an active session as a participant | REST |
| `player:kick` | Remove a player or observer from the session | REST + WS |
| `asset:read:scoped` | Read (download) assets that are within the current session scope | REST |
| `asset:upload` | Upload new assets to the session storage | REST |
| `mindmap:push` | Push mind map nodes to player views | WS |
| `mindmap:edit:own` | Edit mind map nodes that the user owns (workspace nodes) | WS |
| `audio:control` | Control audio playback (theme, state, intensity) for all participants | WS |
| `audio:volume:local` | Adjust local audio volume (does not affect other participants) | Client-local |
| `gameplay:dice:roll` | Initiate a dice roll (result generated server-side) | WS |
| `gameplay:log:read` | Read the session event log | REST + WS |
| `entity:share` | Share entities from campaign with specified visibility level | WS |
| `entity:view:shared` | View entities that have been shared within the session | WS |
| `combat:manage` | Manage combat tracker (add/remove combatants, advance turns, modify HP) | WS |
| `combat:view` | View combat state (initiative order, HP, conditions) | WS |

### 7.3 Permission Matrix

| Scope | DM_OWNER | PLAYER | OBSERVER |
|-------|----------|--------|----------|
| `session:manage` | Granted | Denied | Denied |
| `session:join` | Granted | Granted | Granted |
| `player:kick` | Granted | Denied | Denied |
| `asset:read:scoped` | Granted | Granted | Granted |
| `asset:upload` | Granted | Denied | Denied |
| `mindmap:push` | Granted | Denied | Denied |
| `mindmap:edit:own` | Granted | Granted | Denied |
| `audio:control` | Granted | Denied | Denied |
| `audio:volume:local` | Granted | Granted | Granted |
| `gameplay:dice:roll` | Granted | Granted | Denied |
| `gameplay:log:read` | Granted | Granted | Granted |
| `entity:share` | Granted | Denied | Denied |
| `entity:view:shared` | Granted | Granted | Granted |
| `combat:manage` | Granted | Denied | Denied |
| `combat:view` | Granted | Granted | Granted |

### 7.4 Content Visibility Levels

When a DM shares content with players, they specify a visibility level that controls how much information the player receives:

| Level | Code | Description | Server Behavior |
|-------|------|-------------|-----------------|
| Private (DM only) | `private_dm` | Content is never sent to any player client. This is the default for all campaign content. | Content is excluded from all player-bound events. |
| Full Shared | `shared_full` | Complete content shared with permitted players. All fields are visible. | Entity snapshot sent without modification. |
| Restricted Shared | `shared_restricted` | Redacted version. DM notes, secret information, and DM-flagged fields are stripped server-side before transmission. | Server applies redaction rules to entity snapshot before sending to players. |
| Revoked | `revoked` | Previously shared content is withdrawn from player view. | Server sends revocation event; client removes content from local display. |

#### Redaction Rules for `shared_restricted` Visibility

The following fields are always stripped from entities with `shared_restricted` visibility:

- `dm_notes` (always private)
- Any field key containing `secret` or `hidden` in its name
- `location_id` (reveals campaign geography)
- `custom_spells` (DM homebrew)
- Fields explicitly marked as restricted by the DM via a per-entity `restricted_fields` list

### 7.5 Session Join Flow

The following sequence describes how a player joins an online session:

```
Player Client                        Server                          DM Client
     │                                  │                                │
     │  1. POST /v1/sessions/{id}/join  │                                │
     │     { join_key, display_name }   │                                │
     │─────────────────────────────────►│                                │
     │                                  │  2. Validate join_key          │
     │                                  │     Check session active       │
     │                                  │     Check max_players          │
     │                                  │     Create participant record  │
     │                                  │                                │
     │  3. Response 200                 │                                │
     │     { session_id, role,          │                                │
     │       ws_url, participant_id }   │                                │
     │◄─────────────────────────────────│                                │
     │                                  │                                │
     │  4. WebSocket connect            │                                │
     │─────────────────────────────────►│                                │
     │                                  │                                │
     │  5. authenticate { jwt_token }   │                                │
     │─────────────────────────────────►│                                │
     │                                  │  6. Validate token             │
     │  7. auth_success                 │     Associate socket with user │
     │◄─────────────────────────────────│                                │
     │                                  │                                │
     │  8. join_session { session_id }  │                                │
     │─────────────────────────────────►│                                │
     │                                  │  9. Add to session room        │
     │  10. session_snapshot            │     Load current state         │
     │      { full session state }      │                                │
     │◄─────────────────────────────────│                                │
     │                                  │                                │
     │                                  │  11. PLAYER_JOINED event       │
     │                                  │─────────────────────────────►  │
     │                                  │                                │
     │  12. Render initial state        │                                │
     │      (map, audio, combat, etc.)  │                                │
```

### 7.6 Account Lifecycle

| State | Description | Transitions |
|-------|-------------|-------------|
| Anonymous | Player joins with display name only. No persistent identity. | Can upgrade to Registered. |
| Registered | User has created an account with username, email, and password. | Can be Suspended or Deleted. |
| Suspended | Account temporarily disabled (e.g., terms violation). Cannot log in or join sessions. | Can be Reinstated or Deleted. |
| Deleted | Account permanently removed. Associated session data anonymized. | Terminal state. |

Anonymous players have no persistent identity across sessions. Their `participant_id` is session-scoped and discarded when the session closes. If they want session history or persistent character sheets, they must create an account.

### 7.7 Auth Guard Implementation

The server enforces permissions through a middleware decorator applied to every REST endpoint and WebSocket event handler:

```python
# server/auth/guard.py
ROLE_SCOPES = {
    "DM_OWNER": {
        "session:manage", "session:join", "player:kick",
        "asset:read:scoped", "asset:upload",
        "mindmap:push", "mindmap:edit:own",
        "audio:control", "audio:volume:local",
        "gameplay:dice:roll", "gameplay:log:read",
        "entity:share", "entity:view:shared",
        "combat:manage", "combat:view"
    },
    "PLAYER": {
        "session:join", "asset:read:scoped",
        "mindmap:edit:own", "audio:volume:local",
        "gameplay:dice:roll", "gameplay:log:read",
        "entity:view:shared", "combat:view"
    },
    "OBSERVER": {
        "session:join", "asset:read:scoped",
        "audio:volume:local", "gameplay:log:read",
        "entity:view:shared", "combat:view"
    },
}

def require_scope(scope: str):
    """Decorator that verifies the authenticated user has the required scope
    for their role within the specified session."""
    # 1. Extract user from JWT token
    # 2. Look up user's role in the session
    # 3. Check if role's scope set includes required scope
    # 4. Raise 403 if not authorized
    # 5. Proceed with handler if authorized
```

---

## 8. REST API Design

### 8.1 Base URL and Conventions

**Base URL:** `https://api.<domain>/v1`

**Conventions:**

- All request and response bodies use JSON format with `Content-Type: application/json`.
- Authentication is via `Authorization: Bearer <jwt_token>` header.
- Dates are in ISO 8601 format with timezone (`2026-03-18T14:30:00Z`).
- UUIDs are used for all resource identifiers.
- Pagination uses cursor-based pagination with `?cursor=<last_id>&limit=<n>` query parameters.
- Rate limiting responses include `Retry-After` header with seconds until next allowed request.

### 8.2 Error Response Format

All error responses follow a consistent structure:

```json
{
    "error": {
        "code": "ERROR_CODE_CONSTANT",
        "message": "Human-readable description of the error.",
        "details": {}
    }
}
```

**Standard Error Codes:**

| HTTP Status | Code | Description |
|-------------|------|-------------|
| 400 | `VALIDATION_ERROR` | Request body failed Pydantic validation |
| 401 | `INVALID_CREDENTIALS` | Username or password incorrect |
| 401 | `TOKEN_EXPIRED` | JWT access token has expired |
| 401 | `INVALID_REFRESH_TOKEN` | Refresh token is invalid or revoked |
| 403 | `INSUFFICIENT_SCOPE` | User role lacks required permission scope |
| 404 | `RESOURCE_NOT_FOUND` | Requested resource does not exist |
| 404 | `INVALID_JOIN_KEY` | Join key does not match any active session |
| 409 | `USERNAME_TAKEN` | Registration username already exists |
| 409 | `EMAIL_TAKEN` | Registration email already exists |
| 409 | `SESSION_FULL` | Session has reached max_players limit |
| 410 | `SESSION_CLOSED` | Session is no longer active |
| 413 | `FILE_TOO_LARGE` | Upload exceeds maximum allowed size |
| 429 | `RATE_LIMITED` | Too many requests; retry after specified interval |
| 500 | `INTERNAL_ERROR` | Unexpected server error |

### 8.3 Authentication Endpoints

#### POST /v1/auth/register

Register a new DM account.

| Field | Value |
|-------|-------|
| Authentication | None required |
| Rate Limit | 3 requests per 15 minutes per IP |
| Request Body | `{"username": string (3-50 chars), "email": string (valid email), "password": string (8+ chars)}` |
| Response 201 | `{"user_id": uuid, "username": string, "access_token": string, "refresh_token": string, "expires_in": int}` |
| Response 409 | Error: `USERNAME_TAKEN` or `EMAIL_TAKEN` |
| Response 400 | Error: `VALIDATION_ERROR` (password too short, invalid email, etc.) |

#### POST /v1/auth/login

Authenticate an existing user and receive token pair.

| Field | Value |
|-------|-------|
| Authentication | None required |
| Rate Limit | 5 attempts per 15 minutes per IP |
| Request Body | `{"username": string, "password": string}` |
| Response 200 | `{"user_id": uuid, "username": string, "access_token": string, "refresh_token": string, "expires_in": int}` |
| Response 401 | Error: `INVALID_CREDENTIALS` |

#### POST /v1/auth/refresh

Exchange a valid refresh token for a new token pair. Implements refresh token rotation: the old refresh token is invalidated immediately.

| Field | Value |
|-------|-------|
| Authentication | None required |
| Rate Limit | 10 requests per minute per IP |
| Request Body | `{"refresh_token": string}` |
| Response 200 | `{"access_token": string, "refresh_token": string, "expires_in": int}` |
| Response 401 | Error: `INVALID_REFRESH_TOKEN` |

#### GET /v1/auth/me

Retrieve the authenticated user's profile.

| Field | Value |
|-------|-------|
| Authentication | Bearer JWT |
| Response 200 | `{"user_id": uuid, "username": string, "email": string, "created_at": string}` |

### 8.4 Session Endpoints

#### POST /v1/sessions

Create a new game session. Only authenticated DM accounts can create sessions.

| Field | Value |
|-------|-------|
| Authentication | Bearer JWT |
| Required Scope | `session:manage` |
| Request Body | `{"world_name": string, "max_players": int (default 10, max 50)}` |
| Response 201 | `{"session_id": uuid, "join_key": string (6 alphanumeric chars), "join_key_expires_at": string, "ws_url": string}` |

The `join_key` is a randomly generated 6-character alphanumeric code (uppercase letters and digits, excluding ambiguous characters like O/0, I/1, L). It expires after 24 hours but can be regenerated.

#### GET /v1/sessions/{session_id}

Retrieve session details. The requesting user must be a participant in the session.

| Field | Value |
|-------|-------|
| Authentication | Bearer JWT |
| Required Scope | `session:join` (must be participant) |
| Response 200 | See schema below |

```json
{
    "session_id": "uuid",
    "world_name": "string",
    "status": "active | paused | closed",
    "dm": {
        "user_id": "uuid",
        "username": "string"
    },
    "participants": [
        {
            "user_id": "uuid | null",
            "display_name": "string",
            "role": "DM_OWNER | PLAYER | OBSERVER",
            "connected": true
        }
    ],
    "max_players": 10,
    "created_at": "ISO 8601",
    "join_key": "string (DM only, null for players)",
    "join_key_expires_at": "ISO 8601 (DM only, null for players)"
}
```

#### POST /v1/sessions/{session_id}/join

Join an active session as a player or observer.

| Field | Value |
|-------|-------|
| Authentication | Bearer JWT or anonymous (display name required) |
| Rate Limit | 10 attempts per 15 minutes per IP |
| Request Body | `{"join_key": string, "display_name": string (required if anonymous)}` |
| Response 200 | `{"session_id": uuid, "role": "PLAYER", "ws_url": string, "participant_id": uuid}` |
| Response 404 | Error: `INVALID_JOIN_KEY` |
| Response 409 | Error: `SESSION_FULL` |
| Response 410 | Error: `SESSION_CLOSED` |

#### POST /v1/sessions/{session_id}/close

Close a session permanently. All connected clients receive a `SESSION_CLOSED` event.

| Field | Value |
|-------|-------|
| Authentication | Bearer JWT |
| Required Scope | `session:manage` |
| Response 200 | `{"session_id": uuid, "status": "closed", "closed_at": string}` |

#### POST /v1/sessions/{session_id}/kick/{participant_id}

Remove a participant from the session. The kicked participant's WebSocket connection is closed.

| Field | Value |
|-------|-------|
| Authentication | Bearer JWT |
| Required Scope | `player:kick` |
| Response 200 | `{"participant_id": uuid, "kicked": true}` |
| Response 404 | Error: `RESOURCE_NOT_FOUND` (participant not in session) |

#### GET /v1/sessions/{session_id}/state

Retrieve the complete current session state. Used for initial synchronization and as a fallback when delta resync fails.

| Field | Value |
|-------|-------|
| Authentication | Bearer JWT |
| Required Scope | `session:join` |
| Response 200 | Full session state object (see Section 9 for structure) |

The response is filtered based on the requesting user's role. DM_OWNER receives unredacted state; PLAYER and OBSERVER receive state with redaction rules applied.

#### POST /v1/sessions/{session_id}/regenerate-key

Generate a new join key for the session, invalidating the previous one.

| Field | Value |
|-------|-------|
| Authentication | Bearer JWT |
| Required Scope | `session:manage` |
| Response 200 | `{"join_key": string, "join_key_expires_at": string}` |

### 8.5 Asset Endpoints

#### POST /v1/assets/presign

Request a presigned upload URL for direct client-to-MinIO upload.

| Field | Value |
|-------|-------|
| Authentication | Bearer JWT |
| Required Scope | `asset:upload` |
| Rate Limit | 30 requests per minute per user |
| Request Body | `{"session_id": uuid, "filename": string, "content_type": string, "size_bytes": int}` |
| Response 200 | `{"asset_id": uuid, "upload_url": string, "upload_expires_at": string}` |
| Response 413 | Error: `FILE_TOO_LARGE` |

Content type validation:

| Allowed Content Type | Max Size |
|---------------------|---------|
| `image/png`, `image/jpeg`, `image/webp` | 50 MB |
| `audio/mpeg`, `audio/ogg`, `audio/wav` | 20 MB |
| `application/pdf` | 30 MB |

#### POST /v1/assets/{asset_id}/confirm

Confirm that a presigned upload completed successfully. The server verifies the object exists in MinIO and records asset metadata.

| Field | Value |
|-------|-------|
| Authentication | Bearer JWT |
| Required Scope | `asset:upload` |
| Response 200 | `{"asset_id": uuid, "status": "confirmed", "size_bytes": int}` |
| Response 404 | Error: `RESOURCE_NOT_FOUND` (upload not found in storage) |

#### GET /v1/assets/{asset_id}

Get a time-limited download URL for an asset. The asset must belong to a session the user is participating in.

| Field | Value |
|-------|-------|
| Authentication | Bearer JWT |
| Required Scope | `asset:read:scoped` |
| Response 200 | `{"asset_id": uuid, "download_url": string, "expires_at": string, "content_type": string, "size_bytes": int}` |
| Response 403 | Error: `ASSET_NOT_IN_SESSION_SCOPE` |

### 8.6 Backup Endpoints

#### POST /v1/sessions/{session_id}/backup

Initiate a world backup. The server snapshots the session state, shared entities, and associated assets.

| Field | Value |
|-------|-------|
| Authentication | Bearer JWT |
| Required Scope | `session:manage` |
| Response 202 | `{"backup_id": uuid, "status": "in_progress"}` |

#### GET /v1/backups/{backup_id}

Check backup status and retrieve download URL when complete.

| Field | Value |
|-------|-------|
| Authentication | Bearer JWT |
| Response 200 | `{"backup_id": uuid, "status": "in_progress | completed | failed", "download_url": string | null, "size_bytes": int | null, "created_at": string}` |

### 8.7 Pagination, Filtering, and Sorting

For list endpoints (session participants, event log, dice roll history):

- **Pagination:** Cursor-based using `?cursor=<last_id>&limit=<n>` (default limit: 50, max: 200).
- **Filtering:** Query parameters specific to each resource (e.g., `?log_type=dice_roll` for event log).
- **Sorting:** `?sort=created_at&order=desc` (default: descending by creation time).

Example: `GET /v1/sessions/{id}/events?cursor=evt-123&limit=50&log_type=combat_action`

---

## 9. WebSocket Event Catalog

### 9.1 Connection Lifecycle

The WebSocket connection follows a strict lifecycle with authentication and session binding:

```
Client                                    Server
  │                                          │
  ├── WebSocket connect (WSS) ──────────────►│
  │◄── connection_ack ──────────────────────┤  (server_version, capabilities)
  │                                          │
  ├── authenticate { token: jwt } ─────────►│
  │                                          │  Validate JWT
  │                                          │  Associate socket with user
  │◄── auth_success { user_id, username } ──┤
  │                                          │
  ├── join_session { session_id } ──────────►│
  │                                          │  Validate membership
  │                                          │  Add to session room
  │                                          │  Load current state
  │◄── session_snapshot { full_state } ─────┤
  │                                          │
  │   ◄── heartbeat (ping/pong) ──────────► │  Every 30 seconds
  │                                          │
  │   ◄── game events ───────────────────►  │  Bidirectional, filtered by role
  │                                          │
  │◄── token_expiring { expires_in } ──────┤  Warning 60s before expiry
  │                                          │
  ├── reauthenticate { new_token } ────────►│  Seamless token refresh
  │◄── auth_success ───────────────────────┤
  │                                          │
  ├── leave_session ────────────────────────►│
  │◄── leave_ack ──────────────────────────┤
  │                                          │
  ├── disconnect ───────────────────────────►│
  │◄── disconnect_ack ─────────────────────┤
```

### 9.2 Event Envelope Format

Every WebSocket event is wrapped in a standardized envelope that provides identification, ordering, and routing metadata:

```json
{
    "event_id": "550e8400-e29b-41d4-a716-446655440000",
    "schema_version": "1.0",
    "session_id": "XY1234",
    "event": "EVENT_TYPE",
    "sender": {
        "role": "DM_OWNER",
        "user_id": "user-uuid",
        "username": "DisplayName"
    },
    "ts": "2026-03-18T14:30:00Z",
    "seq": 1203,
    "payload": {}
}
```

**Required Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `event_id` | UUID string | Unique identifier for this event instance. Used for deduplication. |
| `schema_version` | String | Event schema version (e.g., `"1.0"`). Enables backward-compatible evolution. |
| `session_id` | String | The session this event belongs to. |
| `event` | Enum string | The event type constant (see catalog below). |
| `sender` | Object | Information about the event originator. |
| `ts` | ISO 8601 string | Timestamp when the event was created (server time for server-generated events). |
| `seq` | Integer | Monotonically increasing sequence number per session. Assigned by server. |
| `payload` | Object | Type-specific event data (see individual event definitions). |

### 9.3 Event Naming Conventions

Events follow a consistent naming pattern: `{DOMAIN}_{ACTION}` in UPPER_SNAKE_CASE.

| Domain | Events |
|--------|--------|
| SESSION | `SESSION_STATE`, `PLAYER_JOINED`, `PLAYER_LEFT`, `SESSION_CLOSED` |
| MAP | `MAP_STATE_SYNC` |
| PROJECTION | `PROJECTION_UPDATE` |
| FOG | `FOG_OF_WAR_UPDATE` |
| MINDMAP | `MINDMAP_PUSH`, `MINDMAP_NODE_UPDATE`, `MINDMAP_LINK_SYNC`, `MINDMAP_NODE_DELETE` |
| AUDIO | `AUDIO_STATE`, `AUDIO_CROSSFADE`, `AUDIO_AMBIENCE_UPDATE`, `AUDIO_SFX_TRIGGER` |
| DICE | `DICE_ROLL_REQUEST`, `DICE_ROLL_RESULT` |
| EVENT_LOG | `EVENT_LOG_APPEND` |
| COMBAT | `COMBAT_STATE_SYNC` |
| ENTITY | `ENTITY_SHARE`, `ENTITY_UPDATE_SHARED`, `CARD_VIEW_GRANT` |

### 9.4 Session Events

#### SESSION_STATE

| Property | Value |
|----------|-------|
| Direction | Server to All Clients |
| Trigger | Session state change (status, participant list, current view) |
| Idempotency | Full replace of session state on client. Safe to replay. |

Payload:

```json
{
    "status": "active | paused | closed",
    "dm_status": "online | away",
    "active_players": [
        {"user_id": "uuid", "username": "string", "connected": true}
    ],
    "current_view": "BATTLE_MAP | PROJECTION | MIND_MAP | NONE"
}
```

#### PLAYER_JOINED

| Property | Value |
|----------|-------|
| Direction | Server to All Clients |
| Trigger | New player or observer joins the session |
| Idempotency | Upsert to participant list by `user_id`. Safe to replay. |

Payload:

```json
{
    "user_id": "uuid",
    "username": "string",
    "role": "PLAYER | OBSERVER"
}
```

#### PLAYER_LEFT

| Property | Value |
|----------|-------|
| Direction | Server to All Clients |
| Trigger | Player disconnects, is kicked, or times out |
| Idempotency | Remove from participant list by `user_id`. Safe to replay. |

Payload:

```json
{
    "user_id": "uuid",
    "username": "string",
    "reason": "disconnect | kicked | timeout"
}
```

#### SESSION_CLOSED

| Property | Value |
|----------|-------|
| Direction | Server to All Clients |
| Trigger | DM closes the session or session auto-closes due to timeout |
| Idempotency | Mark session as closed. Safe to replay. |

Payload:

```json
{
    "reason": "dm_closed | timeout | error",
    "closed_at": "ISO 8601"
}
```

### 9.5 Map and Projection Events

#### MAP_STATE_SYNC

| Property | Value |
|----------|-------|
| Direction | DM to Server to Players |
| Trigger | Map image, grid, or visible pins change |
| Idempotency | Full replace of map state. Safe to replay. |

Payload:

```json
{
    "image_asset_id": "uuid | null",
    "grid_enabled": true,
    "grid_size": 50,
    "pins": [
        {"id": "uuid", "x": 100.0, "y": 200.0, "label": "string", "icon": "string"}
    ],
    "viewport": {"x": 0.0, "y": 0.0, "zoom": 1.0}
}
```

The `pins` array contains only pins the DM has marked as visible to players. Hidden pins are excluded server-side.

#### PROJECTION_UPDATE

| Property | Value |
|----------|-------|
| Direction | DM to Server to Players |
| Trigger | DM changes projected content on the player screen |
| Idempotency | Full replace of projection state. Safe to replay. |

Payload:

```json
{
    "projection_type": "image | stat_block | pdf | clear",
    "asset_ids": ["uuid"],
    "layout": "single | split_2 | split_3 | split_4",
    "stat_block_data": {}
}
```

When `projection_type` is `"clear"`, all other fields are empty/null and the player screen is cleared.

#### FOG_OF_WAR_UPDATE

| Property | Value |
|----------|-------|
| Direction | DM to Server to Players |
| Trigger | DM draws or erases fog of war regions on battle map |
| Idempotency | Apply action sequentially by `seq` number. On gap, request fog snapshot. |

Payload:

```json
{
    "action": "reveal | hide | full_reset",
    "regions": [
        {"points": [{"x": 0.0, "y": 0.0}, {"x": 100.0, "y": 0.0}, {"x": 100.0, "y": 100.0}]}
    ],
    "fog_snapshot_asset_id": "uuid | null"
}
```

The `fog_snapshot_asset_id` is included periodically (every 50 fog operations or on reconnect) as a full fog state image that clients can use to reconstruct the complete fog state without replaying all individual operations.

### 9.6 Mind Map Events

#### MINDMAP_PUSH

| Property | Value |
|----------|-------|
| Direction | DM to Server to Target Players |
| Trigger | DM shares a mind map node with players |
| Idempotency | Upsert node by `node_id`. Safe to replay. |

Payload:

```json
{
    "node_id": "uuid",
    "node_type": "note | entity | image",
    "content": "string (text content or entity_id)",
    "position": {"x": 100.0, "y": 200.0},
    "size": {"w": 200.0, "h": 150.0},
    "color": "#FF5733 | null",
    "origin": "dm",
    "visibility": "shared_full | shared_restricted",
    "target_players": ["user-uuid"] ,
    "entity_data": {}
}
```

When `target_players` is `null`, the node is shared with all players. When specified, only listed players receive the node.

#### MINDMAP_NODE_UPDATE

| Property | Value |
|----------|-------|
| Direction | Any (within permission) to Server to Session |
| Trigger | Node position, content, size, or color changed |
| Idempotency | Apply partial update. Last-write-wins on conflict. |

Payload:

```json
{
    "node_id": "uuid",
    "updates": {
        "position": {"x": 150.0, "y": 250.0},
        "size": {"w": 220.0, "h": 170.0},
        "content": "Updated text",
        "color": "#33FF57"
    }
}
```

Only changed fields are included in `updates`. The server validates that the sender has permission to edit the node (DM can edit all, Player can edit only own workspace nodes).

#### MINDMAP_LINK_SYNC

| Property | Value |
|----------|-------|
| Direction | DM to Server to Players |
| Trigger | Connection between nodes created or removed |
| Idempotency | Add is idempotent (set-based). Remove is idempotent (no-op if missing). |

Payload:

```json
{
    "action": "add | remove",
    "connection": {"start_id": "node-uuid", "end_id": "node-uuid"}
}
```

#### MINDMAP_NODE_DELETE

| Property | Value |
|----------|-------|
| Direction | DM to Server to Players |
| Trigger | DM deletes a shared node |
| Idempotency | Remove if exists. No-op if already removed. |

Payload:

```json
{
    "node_id": "uuid"
}
```

### 9.7 Audio Events

#### AUDIO_STATE

| Property | Value |
|----------|-------|
| Direction | DM to Server to Players |
| Trigger | Theme, state, intensity, or master volume change |
| Idempotency | Full replace of audio state. Safe to replay. |

Payload:

```json
{
    "theme_id": "string",
    "state_id": "Normal | Combat | Victory",
    "intensity_level": "base | level1 | level2",
    "master_volume": 0.75,
    "ambience_slots": [
        {"id": "string | null", "volume": 0.5}
    ],
    "server_time": "ISO 8601"
}
```

The `server_time` field provides a reference timestamp that clients can use to calculate drift and align audio playback.

#### AUDIO_CROSSFADE

| Property | Value |
|----------|-------|
| Direction | DM to Server to Players |
| Trigger | Intensity slider or state change with crossfade transition |
| Idempotency | Apply if `start_at` is in future or within tolerance (500ms). Ignore stale events. |

Payload:

```json
{
    "from_state": "Normal",
    "to_state": "Combat",
    "from_intensity": "base",
    "to_intensity": "level1",
    "crossfade_duration_ms": 2000,
    "start_at": "ISO 8601"
}
```

#### AUDIO_AMBIENCE_UPDATE

| Property | Value |
|----------|-------|
| Direction | DM to Server to Players |
| Trigger | Individual ambience slot change |
| Idempotency | Full replace of the specific slot state. Safe to replay. |

Payload:

```json
{
    "slot_index": 0,
    "ambience_id": "string | null",
    "volume": 0.6
}
```

Setting `ambience_id` to `null` stops the ambience in that slot.

#### AUDIO_SFX_TRIGGER

| Property | Value |
|----------|-------|
| Direction | DM to Server to Players |
| Trigger | DM presses a sound effect button |
| Idempotency | Fire-and-forget. Duplicate play within a 200ms dedup window is suppressed. |

Payload:

```json
{
    "sfx_id": "string",
    "volume": 0.8
}
```

### 9.8 Gameplay Events

#### DICE_ROLL_REQUEST

| Property | Value |
|----------|-------|
| Direction | Player or DM to Server |
| Trigger | User initiates a dice roll |
| Idempotency | Server generates result. Client never generates dice values. |

Payload:

```json
{
    "dice_formula": "2d6+3",
    "roll_type": "attack | damage | save | check | custom",
    "label": "Longsword Attack"
}
```

The server is the sole authority for generating random dice results, preventing client-side tampering.

#### DICE_ROLL_RESULT

| Property | Value |
|----------|-------|
| Direction | Server to All Clients |
| Trigger | Server processes a dice roll request |
| Idempotency | Deduplicate by `request_event_id`. Safe to replay. |

Payload:

```json
{
    "request_event_id": "uuid (links to DICE_ROLL_REQUEST)",
    "roller_user_id": "uuid",
    "roller_username": "string",
    "dice_formula": "2d6+3",
    "individual_rolls": [4, 6],
    "modifier": 3,
    "total": 13,
    "roll_type": "attack",
    "label": "Longsword Attack"
}
```

#### EVENT_LOG_APPEND

| Property | Value |
|----------|-------|
| Direction | Server to All Clients |
| Trigger | Combat action, dice roll, or DM-initiated log entry |
| Idempotency | Append-only log. Deduplicate by `log_id`. |

Payload:

```json
{
    "log_id": "uuid",
    "log_type": "combat_action | dice_roll | dm_note | system",
    "round_number": 3,
    "actor": "Goblin Archer",
    "description": "Goblin Archer attacks Paladin with shortbow. Rolls 15 vs AC 18. Miss.",
    "details": {
        "attack_roll": 15,
        "target_ac": 18,
        "hit": false
    }
}
```

#### COMBAT_STATE_SYNC

| Property | Value |
|----------|-------|
| Direction | DM to Server to Players |
| Trigger | Combat tracker state change (initiative, HP, conditions, turn advance) |
| Idempotency | Full replace of combat state. Safe to replay. |

Payload:

```json
{
    "is_combat_active": true,
    "current_round": 3,
    "current_turn_entity_id": "entity-uuid",
    "combatants": [
        {
            "entity_id": "uuid",
            "name": "Goblin Archer",
            "hp": 7,
            "max_hp": 12,
            "ac": 13,
            "initiative": 18,
            "conditions": [
                {"name": "Poisoned", "duration": 2, "max_duration": 3}
            ],
            "token_state": {"tile_x": 5, "tile_y": 3},
            "is_visible": true
        }
    ]
}
```

DM-only fields (hidden combatants, DM notes per combatant) are stripped server-side before sending to PLAYER and OBSERVER roles. The `is_visible` field is only included in the DM view; players only receive combatants where `is_visible` is true.

### 9.9 Entity Events

#### ENTITY_SHARE

| Property | Value |
|----------|-------|
| Direction | DM to Server to Target Players |
| Trigger | DM shares an entity from their campaign with session participants |
| Idempotency | Upsert shared entity by `entity_id`. Safe to replay. |

Payload:

```json
{
    "entity_id": "uuid",
    "visibility": "shared_full | shared_restricted",
    "entity_data": {},
    "target_players": ["user-uuid"]
}
```

The `entity_data` is the complete entity dict (for `shared_full`) or the redacted entity dict (for `shared_restricted`). The server applies redaction rules before forwarding to players.

#### ENTITY_UPDATE_SHARED

| Property | Value |
|----------|-------|
| Direction | DM to Server to Players |
| Trigger | DM modifies an entity that has already been shared |
| Idempotency | Apply partial update. Last-write-wins. |

Payload:

```json
{
    "entity_id": "uuid",
    "updates": {},
    "visibility": "shared_full | shared_restricted"
}
```

#### CARD_VIEW_GRANT

| Property | Value |
|----------|-------|
| Direction | DM to Server to Specific Player |
| Trigger | DM grants or revokes a player's access to view a specific entity card |
| Idempotency | Upsert grant by `(entity_id, granted_to)`. Safe to replay. |

Payload:

```json
{
    "entity_id": "uuid",
    "granted_to": "user-uuid",
    "visibility": "shared_full | shared_restricted | revoked"
}
```

### 9.10 Reliability Rules

1. **At-least-once delivery.** Clients must handle duplicate events. Deduplication is performed by checking `event_id` against a local set of recently processed event IDs (sliding window of 1000 events).

2. **Sequence ordering.** The `seq` field is monotonically increasing per session. The server assigns `seq` values atomically using Redis `INCR` on `session:{id}:seq`.

3. **Gap detection.** If a client receives an event where `event.seq > last_received_seq + 1`, a gap has been detected. The client requests a delta resync for the missing range.

4. **Resync cascade.** If delta resync fails (events expired from buffer), the client falls back to a full snapshot via `GET /v1/sessions/{id}/state`.

5. **Idempotent apply.** Every event handler must be safe to execute multiple times with the same event data. Event definitions above specify the idempotency strategy for each type.

6. **Unknown event tolerance.** Clients must gracefully handle unknown event types by logging them and ignoring the payload. This enables server-side feature additions without requiring client updates.

### 9.11 Event Pub/Sub Patterns

The server uses Redis PubSub channels for event distribution:

| Channel Pattern | Purpose | Subscribers |
|----------------|---------|-------------|
| `session:{id}:events` | All session events | All connected clients in session |
| `session:{id}:dm` | DM-only events (hidden combatant updates, private notifications) | DM client only |
| `user:{id}:direct` | Direct messages to specific user (card grants, kicks) | Specific user client |

The FastAPI server subscribes to relevant Redis channels and forwards events to connected WebSocket clients, applying role-based filtering before transmission.

---

## 10. Database Design

### 10.1 Entity-Relationship Diagram

```
┌──────────────┐       ┌───────────────────────┐
│    users      │       │       sessions         │
│──────────────│       │───────────────────────│
│ PK id (UUID)  │◄──────│ FK owner_id (UUID)     │
│ username       │  1:N  │ PK id (UUID)           │
│ email          │       │ world_name             │
│ password_hash  │       │ status                 │
│ created_at     │       │ join_key               │
│ updated_at     │       │ join_key_expires_at    │
└──────────────┘       │ max_players            │
        │               │ last_seq               │
        │               │ created_at             │
        │               │ closed_at              │
        │               └───────────┬───────────┘
        │                           │
        │  ┌────────────────────────┤ 1:N
        │  │                        │
        │  │  ┌─────────────────────▼───────────────┐
        │  │  │     session_participants             │
        │  │  │─────────────────────────────────────│
        │  │  │ PK id (UUID)                         │
        ├──┼──│ FK session_id (UUID)                 │
        │  │  │ FK user_id (UUID, nullable)          │
        │  │  │ display_name                         │
        │  │  │ role (DM_OWNER/PLAYER/OBSERVER)      │
        │  │  │ joined_at                            │
        │  │  │ left_at                              │
        │  │  │ is_connected                         │
        │  │  │ UNIQUE(session_id, user_id)          │
        │  │  └─────────────────────────────────────┘
        │  │
        │  │  ┌─────────────────────▼───────────────┐
        │  │  │       shared_entities                │
        │  │  │─────────────────────────────────────│
        │  │  │ PK id (UUID)                         │
        │  ├──│ FK session_id (UUID)                 │
        │  │  │ entity_id (VARCHAR)                  │
        │  │  │ visibility                           │
        │  │  │ FK granted_to (UUID, nullable)       │
        │  │  │ entity_snapshot (JSONB)              │
        │  │  │ created_at                           │
        │  │  │ updated_at                           │
        │  │  │ UNIQUE(session_id, entity_id,        │
        │  │  │        granted_to)                   │
        │  │  └─────────────────────────────────────┘
        │  │
        │  │  ┌─────────────────────▼───────────────┐
        │  │  │         event_log                    │
        │  │  │─────────────────────────────────────│
        │  │  │ PK id (UUID)                         │
        │  ├──│ FK session_id (UUID)                 │
        │  │  │ log_type                             │
        │  │  │ round_number                         │
        │  │  │ actor                                │
        │  │  │ description                          │
        │  │  │ details (JSONB)                      │
        │  │  │ created_at                           │
        │  │  └─────────────────────────────────────┘
        │  │
        │  │  ┌─────────────────────▼───────────────┐
        │  │  │         dice_rolls                   │
        │  │  │─────────────────────────────────────│
        │  │  │ PK id (UUID)                         │
        │  ├──│ FK session_id (UUID)                 │
        │  │  │ FK roller_id (UUID, nullable)        │
        │  │  │ roller_name                          │
        │  │  │ dice_formula                         │
        │  │  │ individual_rolls (INT[])             │
        │  │  │ modifier                             │
        │  │  │ total                                │
        │  │  │ roll_type                            │
        │  │  │ label                                │
        │  │  │ created_at                           │
        │  │  └─────────────────────────────────────┘
        │
        │     ┌─────────────────────────────────────┐
        │     │         audit_log                    │
        │     │─────────────────────────────────────│
        │     │ PK id (UUID)                         │
        └─────│ FK user_id (UUID, nullable)          │
              │ action                               │
              │ resource_type                        │
              │ resource_id                          │
              │ details (JSONB)                      │
              │ ip_address (INET)                    │
              │ created_at                           │
              └─────────────────────────────────────┘
```

### 10.2 Table Schemas with Types and Constraints

#### users

```sql
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username        VARCHAR(50) UNIQUE NOT NULL,
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_username ON users (username);
CREATE INDEX idx_users_email ON users (email);
```

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, auto-generated | Unique user identifier |
| username | VARCHAR(50) | UNIQUE, NOT NULL | Display name, 3-50 characters |
| email | VARCHAR(255) | UNIQUE, NOT NULL | Email address for account recovery |
| password_hash | VARCHAR(255) | NOT NULL | bcrypt hash (cost factor 12) |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Account creation timestamp |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last profile update timestamp |

#### sessions

```sql
CREATE TABLE sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id        UUID NOT NULL REFERENCES users(id),
    world_name      VARCHAR(255) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'paused', 'closed')),
    join_key        VARCHAR(6) UNIQUE,
    join_key_expires_at TIMESTAMPTZ,
    max_players     INT NOT NULL DEFAULT 10,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_at       TIMESTAMPTZ,
    last_seq        BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX idx_sessions_owner ON sessions (owner_id);
CREATE INDEX idx_sessions_join_key ON sessions (join_key) WHERE status = 'active';
CREATE INDEX idx_sessions_status ON sessions (status);
```

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, auto-generated | Unique session identifier |
| owner_id | UUID | FK users(id), NOT NULL | DM who owns this session |
| world_name | VARCHAR(255) | NOT NULL | Campaign/world name for display |
| status | VARCHAR(20) | CHECK in (active, paused, closed) | Session lifecycle state |
| join_key | VARCHAR(6) | UNIQUE | 6-character join code |
| join_key_expires_at | TIMESTAMPTZ | Nullable | When the join key expires |
| max_players | INT | NOT NULL, DEFAULT 10 | Maximum participant count |
| created_at | TIMESTAMPTZ | NOT NULL | Session creation timestamp |
| closed_at | TIMESTAMPTZ | Nullable | When session was closed |
| last_seq | BIGINT | NOT NULL, DEFAULT 0 | Last assigned event sequence number |

#### session_participants

```sql
CREATE TABLE session_participants (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES users(id),
    display_name    VARCHAR(100) NOT NULL,
    role            VARCHAR(20) NOT NULL DEFAULT 'PLAYER'
                    CHECK (role IN ('DM_OWNER', 'PLAYER', 'OBSERVER')),
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    left_at         TIMESTAMPTZ,
    is_connected    BOOLEAN NOT NULL DEFAULT false,

    UNIQUE (session_id, user_id)
);

CREATE INDEX idx_participants_session ON session_participants (session_id);
```

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | Unique participant record |
| session_id | UUID | FK sessions(id), CASCADE | Session this participant belongs to |
| user_id | UUID | FK users(id), nullable | User account (null for anonymous players) |
| display_name | VARCHAR(100) | NOT NULL | Name displayed in session |
| role | VARCHAR(20) | CHECK in (DM_OWNER, PLAYER, OBSERVER) | Participant role |
| joined_at | TIMESTAMPTZ | NOT NULL | When participant joined |
| left_at | TIMESTAMPTZ | Nullable | When participant left (null if still active) |
| is_connected | BOOLEAN | NOT NULL, DEFAULT false | Current WebSocket connection status |

#### shared_entities

```sql
CREATE TABLE shared_entities (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    entity_id       VARCHAR(255) NOT NULL,
    visibility      VARCHAR(30) NOT NULL DEFAULT 'shared_full'
                    CHECK (visibility IN ('shared_full', 'shared_restricted', 'revoked')),
    granted_to      UUID REFERENCES users(id),
    entity_snapshot JSONB NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (session_id, entity_id, granted_to)
);

CREATE INDEX idx_shared_session ON shared_entities (session_id);
CREATE INDEX idx_shared_entity ON shared_entities (session_id, entity_id);
```

#### event_log

```sql
CREATE TABLE event_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    log_type        VARCHAR(50) NOT NULL,
    round_number    INT,
    actor           VARCHAR(255),
    description     TEXT NOT NULL,
    details         JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_event_log_session ON event_log (session_id, created_at);
CREATE INDEX idx_event_log_type ON event_log (session_id, log_type);
```

#### dice_rolls

```sql
CREATE TABLE dice_rolls (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    roller_id       UUID REFERENCES users(id),
    roller_name     VARCHAR(100) NOT NULL,
    dice_formula    VARCHAR(100) NOT NULL,
    individual_rolls INT[] NOT NULL,
    modifier        INT NOT NULL DEFAULT 0,
    total           INT NOT NULL,
    roll_type       VARCHAR(50),
    label           VARCHAR(255),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_dice_rolls_session ON dice_rolls (session_id, created_at);
```

#### audit_log

```sql
CREATE TABLE audit_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID REFERENCES users(id),
    action          VARCHAR(100) NOT NULL,
    resource_type   VARCHAR(50),
    resource_id     VARCHAR(255),
    details         JSONB,
    ip_address      INET,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_user ON audit_log (user_id, created_at);
CREATE INDEX idx_audit_action ON audit_log (action, created_at);
```

### 10.3 Redis Key Patterns

| Key Pattern | Type | TTL | Purpose |
|-------------|------|-----|---------|
| `session:{id}:state` | Hash | Session lifetime | Active session state (status, participants, current view) |
| `session:{id}:seq` | String (counter) | Session lifetime | Current event sequence number (INCR atomic) |
| `session:{id}:participants` | Set | Session lifetime | Set of currently connected user IDs |
| `session:{id}:events:{seq_start}:{seq_end}` | List | 1 hour | Recent event buffer for delta resync |
| `session:{id}:combat` | Hash | Session lifetime | Current combat state snapshot |
| `session:{id}:audio` | Hash | Session lifetime | Current audio state snapshot |
| `session:{id}:map` | Hash | Session lifetime | Current map state snapshot |
| `joinkey:{key}` | String | 24 hours | Maps join key to session_id |
| `user:{id}:active_session` | String | Session lifetime | Current active session for user |
| `ws:conn:{socket_id}` | Hash | Connection lifetime | Socket metadata (user_id, session_id, role) |
| `ratelimit:{ip}:{endpoint}` | String (counter) | 1 minute | Rate limiting counter |
| `ratelimit:join_attempt:{ip}` | String (counter) | 15 minutes | Join attempt throttle |
| `ratelimit:login:{ip}` | String (counter) | 15 minutes | Login attempt throttle |

### 10.4 Migration Strategy (MsgPack to Server)

The local MsgPack `data.dat` files remain the primary storage for offline DM campaigns. PostgreSQL stores only online session metadata. This is an intentional architectural decision, not a limitation:

**What stays local (MsgPack `data.dat`):**
- Complete campaign data (entities, maps, sessions, mind maps)
- Campaign configuration and preferences
- Local audio theme definitions
- All DM-private content

**What goes to PostgreSQL:**
- User accounts and authentication state
- Session metadata (create, join, close, participant list)
- Shared entity snapshots (cached copies for player delivery)
- Event log entries (combat actions, dice rolls, system events)
- Audit trail (security-relevant actions)

**What goes to Redis:**
- Active session state (real-time, ephemeral)
- Event sequence tracking
- Event buffers for reconnect resync
- Rate limiting counters

**What goes to MinIO:**
- Uploaded map images (for distribution to players)
- Uploaded audio files (for distribution to players)
- Entity images shared during sessions
- World backups

The data flow for a typical session:

1. DM starts online session: Session record created in PostgreSQL, state initialized in Redis.
2. DM shares entities: Entity snapshot serialized from local MsgPack data, stored in `shared_entities` table with appropriate visibility and redaction applied.
3. Players join: Participant records created in PostgreSQL, connections tracked in Redis.
4. Dice rolls and combat: Results stored in PostgreSQL (`dice_rolls`, `event_log`).
5. Session closes: Session marked closed in PostgreSQL, Redis state cleaned up after grace period.

---

## 11. Asset Management

### 11.1 Storage Architecture

Assets are stored in MinIO, an S3-compatible object storage service. The bucket structure is organized by session:

```
dm-assets/                          (MinIO bucket)
├── sessions/
│   └── {session_id}/
│       ├── maps/                   Battle map images
│       │   ├── {asset_id}.png
│       │   └── {asset_id}.jpg
│       ├── projections/            Projected images and content
│       │   └── {asset_id}.png
│       ├── audio/                  Shared audio files
│       │   ├── {asset_id}.mp3
│       │   └── {asset_id}.ogg
│       ├── mindmap/                Mind map node images
│       │   └── {asset_id}.png
│       ├── entities/               Entity images
│       │   └── {asset_id}.jpg
│       └── fog/                    Fog of war snapshots
│           └── {asset_id}.png
└── backups/
    └── {user_id}/
        └── {backup_id}/
            ├── metadata.json       Backup metadata
            ├── state.json          Session state snapshot
            └── assets.tar.gz       Associated asset archive
```

### 11.2 Upload Flow

The upload process uses presigned URLs to allow direct client-to-MinIO uploads without streaming through the application server:

```
DM Client                    FastAPI Server               MinIO
    │                              │                         │
    │  1. POST /v1/assets/presign  │                         │
    │     { session_id, filename,  │                         │
    │       content_type, size }   │                         │
    │─────────────────────────────►│                         │
    │                              │  2. Validate request    │
    │                              │     Check quota         │
    │                              │     Generate asset_id   │
    │                              │                         │
    │                              │  3. Generate presigned  │
    │                              │     PUT URL             │
    │                              │────────────────────────►│
    │                              │◄────────────────────────│
    │                              │                         │
    │  4. Response                 │                         │
    │     { asset_id, upload_url } │                         │
    │◄─────────────────────────────│                         │
    │                              │                         │
    │  5. PUT upload_url           │                         │
    │     (direct binary upload)   │                         │
    │─────────────────────────────────────────────────────►  │
    │                              │                         │
    │  6. Upload complete (200)    │                         │
    │◄─────────────────────────────────────────────────────  │
    │                              │                         │
    │  7. POST /v1/assets/{id}/    │                         │
    │     confirm                  │                         │
    │─────────────────────────────►│                         │
    │                              │  8. Verify object       │
    │                              │     exists in MinIO     │
    │                              │────────────────────────►│
    │                              │◄────────────────────────│
    │                              │                         │
    │                              │  9. Record metadata     │
    │                              │     in PostgreSQL       │
    │                              │                         │
    │  10. Confirmed               │                         │
    │◄─────────────────────────────│                         │
```

### 11.3 Download Flow

When a player needs to download an asset:

1. Player client requests asset download URL: `GET /v1/assets/{asset_id}`
2. Server verifies the player is a participant in the session that owns the asset.
3. Server generates a presigned GET URL with a 60-second TTL.
4. Client downloads directly from MinIO using the presigned URL.
5. Client caches the downloaded file locally for the duration of the session.

### 11.4 Chunked Upload for Large Files

For files larger than 10MB, the client uses multipart upload:

1. Client requests presigned URLs for each chunk (chunk size: 5MB).
2. Client uploads chunks in parallel (max 3 concurrent uploads).
3. After all chunks are uploaded, client sends a completion request.
4. Server initiates MinIO multipart upload completion.
5. Server records the assembled asset metadata.

This allows a 50MB battle map to upload in approximately 10 chunks, with parallel upload reducing total transfer time significantly on connections with adequate bandwidth.

### 11.5 CDN Distribution Strategy

For self-hosted deployments, Nginx acts as a caching reverse proxy in front of MinIO:

```
Client → Nginx (cache layer) → MinIO (origin)
```

Nginx caching configuration:

- **Cache location:** `/var/cache/nginx/assets`
- **Cache key:** `$request_uri`
- **Cache duration:** 1 hour for active session assets, 24 hours for backup assets
- **Cache size:** 2GB maximum
- **Cache bypass:** When `Cache-Control: no-cache` header is present

For hosted deployments, a CDN (Cloudflare or similar) can be placed in front of Nginx for edge caching, but this is not required for the initial release.

### 11.6 Client-Side Caching Strategy

| Content Type | Cache Directory | TTL | Invalidation Trigger | Max Cache Size |
|-------------|----------------|-----|---------------------|---------------|
| Map images | `cache/online/maps/` | Until session close | New `MAP_STATE_SYNC` event with different `image_asset_id` | 200 MB |
| Audio files | `cache/online/audio/` | 7 days | Version hash mismatch in `AUDIO_STATE` event | 500 MB |
| Entity images | `cache/online/entities/` | Until session close | New `ENTITY_SHARE` event with updated images | 100 MB |
| Projection images | In-memory only | Current projection only | Next `PROJECTION_UPDATE` event | 50 MB |
| Fog snapshots | `cache/online/fog/` | Until next snapshot | New `FOG_OF_WAR_UPDATE` with `fog_snapshot_asset_id` | 50 MB |

Cache eviction uses LRU (Least Recently Used) when the cache directory exceeds its maximum size. On session close, session-scoped cache entries are marked for cleanup but not immediately deleted (they may be useful if the player reconnects to the same DM's next session with the same assets).

### 11.7 Storage Quotas per Plan

| Plan | Total Storage | Max Session Assets | Max Sessions | Max Players per Session |
|------|--------------|-------------------|-------------|----------------------|
| Free | 1 GB | 200 MB | 3 concurrent | 5 |
| Standard | 10 GB | 1 GB | 10 concurrent | 15 |
| Premium | 50 GB | 5 GB | Unlimited | 50 |

Quotas are enforced at the presigned URL generation step. If a DM exceeds their storage quota, the server returns a `413 FILE_TOO_LARGE` error with details indicating the quota has been reached.

### 11.8 File Size Limits

| Content Type | Max File Size | Allowed Formats |
|-------------|--------------|----------------|
| Map image | 50 MB | PNG, JPEG, WebP |
| Audio file | 20 MB | MP3, OGG, WAV |
| Entity image | 10 MB | PNG, JPEG, WebP |
| PDF document | 30 MB | PDF |

File type validation is performed twice:
1. **At presign time:** Content type is checked against the allowed list.
2. **At confirmation time:** The uploaded file's magic bytes are verified against the declared content type. Mismatches result in the asset being rejected and deleted.

---

## 12. Security Design

### 12.1 Authentication Flow

The authentication system uses JWT (JSON Web Tokens) with refresh token rotation:

```
Client                              Server
  │                                    │
  │  POST /v1/auth/login               │
  │  { username, password }            │
  │───────────────────────────────────►│
  │                                    │  Validate credentials
  │                                    │  Hash comparison (bcrypt)
  │                                    │  Generate access + refresh tokens
  │  { access_token, refresh_token,    │
  │    expires_in: 900 }               │
  │◄───────────────────────────────────│
  │                                    │
  │  ... 14 minutes later ...          │
  │                                    │
  │  POST /v1/auth/refresh             │
  │  { refresh_token }                 │
  │───────────────────────────────────►│
  │                                    │  Validate refresh token
  │                                    │  Invalidate old refresh token
  │                                    │  Generate new token pair
  │  { access_token, refresh_token,    │
  │    expires_in: 900 }               │
  │◄───────────────────────────────────│
```

#### Token Specifications

| Token Type | Lifetime | Storage Location | Rotation |
|-----------|----------|-----------------|----------|
| Access Token | 15 minutes | In-memory (client-side) | Refreshed before expiry |
| Refresh Token | 7 days | Secure local storage (client-side) | Rotated on each use |

#### Access Token Payload

```json
{
    "sub": "user-uuid",
    "username": "DisplayName",
    "iat": 1711234567,
    "exp": 1711235467,
    "jti": "unique-token-id"
}
```

#### Refresh Token Rotation

Each refresh request invalidates the old refresh token and issues a new pair. This prevents token replay attacks. If a revoked refresh token is used (indicating possible token theft), all tokens for that user are invalidated immediately (token family revocation), forcing re-authentication.

### 12.2 WebSocket Authentication

WebSocket connections authenticate after the initial handshake:

1. Client establishes WebSocket connection (WSS).
2. Client sends `authenticate` event with the current JWT access token.
3. Server validates the token signature, expiration, and user existence.
4. Server associates the socket connection with the authenticated user.
5. If the access token expires during an active connection, the server sends a `token_expiring` event 60 seconds before expiry.
6. Client refreshes the token via REST and sends a `reauthenticate` event with the new token.
7. The WebSocket connection is maintained throughout the token refresh process.

### 12.3 Authorization Enforcement

Authorization is enforced at three levels:

1. **REST API level:** The `require_scope()` decorator checks the user's role against the required scope for each endpoint.
2. **WebSocket event level:** The event router checks the sender's role before processing any event. Events from unauthorized roles are silently dropped and logged.
3. **Data level:** The shared entity service applies visibility-based redaction before any entity data leaves the server bound for a player client.

The authorization chain for a typical event:

```
Client emits event
    → Server receives event
    → Extract user from socket metadata
    → Look up user's role in session
    → Check if role grants required scope
    → If authorized: process event, assign seq, broadcast
    → If unauthorized: log violation, drop event, optionally notify client
```

### 12.4 Data Isolation

Data isolation ensures that participants in one session cannot access data from another session:

- **Session scoping:** All database queries include `session_id` as a required parameter. There are no cross-session queries in the application layer.
- **Asset scoping:** Assets are stored in session-specific MinIO paths. Presigned URLs are generated with session validation.
- **Redis key scoping:** All Redis keys include the session ID. Key patterns use the format `session:{id}:*`.
- **WebSocket room scoping:** Each session has its own Socket.IO room. Events are broadcast only within the room.

### 12.5 Rate Limiting

Rate limiting is implemented at two levels: Nginx (network layer) and application (logic layer).

#### Nginx Rate Limits

| Zone | Rate | Burst | Scope |
|------|------|-------|-------|
| `api_general` | 30 requests/second | 50 | Per IP, all API endpoints |
| `auth_login` | 5 requests/minute | 3 | Per IP, auth endpoints only |

#### Application Rate Limits (Redis-backed)

| Endpoint/Action | Limit | Window | Scope |
|----------------|-------|--------|-------|
| `POST /auth/login` | 5 attempts | 15 minutes | Per IP |
| `POST /auth/register` | 3 attempts | 15 minutes | Per IP |
| `POST /sessions/{id}/join` | 10 attempts | 15 minutes | Per IP |
| `POST /assets/presign` | 30 requests | 1 minute | Per authenticated user |
| WebSocket events | 100 events | 1 second | Per connection |
| Dice roll requests | 10 requests | 10 seconds | Per user per session |

Rate limit exceeded responses include `Retry-After` header:

```json
{
    "error": {
        "code": "RATE_LIMITED",
        "message": "Too many requests. Please retry after 45 seconds.",
        "details": {"retry_after": 45}
    }
}
```

### 12.6 Input Validation

All external input is validated before processing:

- **REST request bodies:** Validated via Pydantic models with field-level constraints (type, length, format, allowed values).
- **WebSocket event payloads:** Validated via Pydantic models before event processing. Invalid payloads are rejected with an error event.
- **File uploads:** Content-type verified against actual file magic bytes using `python-magic`. MIME type declared in the presign request must match the actual uploaded file.
- **SQL injection prevention:** All database queries use SQLAlchemy's parameterized query interface. No raw SQL string concatenation.
- **XSS prevention:** All user-generated content (display names, entity text, mind map content) is HTML-escaped before rendering in any client.
- **Path traversal prevention:** Asset filenames are sanitized and replaced with UUIDs. Original filenames are stored as metadata but never used for filesystem paths.

### 12.7 Encryption

| Layer | Mechanism | Details |
|-------|-----------|---------|
| In transit | TLS 1.2+ | Enforced by Nginx. All HTTP and WebSocket connections use HTTPS/WSS. |
| At rest (database) | PostgreSQL encryption | Transparent data encryption via filesystem-level encryption (LUKS on Linux). |
| At rest (objects) | MinIO server-side encryption | SSE-S3 encryption enabled on the `dm-assets` bucket. |
| Passwords | bcrypt | Cost factor 12. Salt automatically generated per password. |
| Tokens | HMAC-SHA256 | JWT tokens signed with a 256-bit secret key stored as an environment variable. |

### 12.8 Audit Logging

The following actions are recorded in the `audit_log` table:

| Action Category | Specific Actions |
|----------------|-----------------|
| Authentication | `auth.register`, `auth.login`, `auth.login_failed`, `auth.refresh`, `auth.token_revoked` |
| Session management | `session.create`, `session.close`, `session.pause`, `session.resume` |
| Participant management | `session.player_joined`, `session.player_kicked`, `session.player_left` |
| Content sharing | `entity.shared`, `entity.visibility_changed`, `entity.revoked` |
| Asset operations | `asset.uploaded`, `asset.downloaded`, `asset.deleted` |
| Security events | `auth.rate_limited`, `auth.scope_violation`, `session.unauthorized_access` |

Each audit entry includes: user ID, action name, resource type, resource ID, IP address, timestamp, and optional details (JSONB).

### 12.9 OWASP Top 10 Mitigation Matrix

| OWASP Category | Risk | Mitigation |
|---------------|------|-----------|
| A01: Broken Access Control | Unauthorized data access | Role-based auth guard on every endpoint and event; server-side content redaction; session data isolation |
| A02: Cryptographic Failures | Data exposure | TLS 1.2+ mandatory; bcrypt password hashing; signed JWTs; encrypted object storage |
| A03: Injection | SQL injection, command injection | SQLAlchemy parameterized queries; Pydantic input validation; no shell commands from user input |
| A04: Insecure Design | Architectural vulnerabilities | Threat modeling per phase; server-authoritative state; zero-trust between client and server |
| A05: Security Misconfiguration | Default credentials, open ports | Docker secrets for all credentials; no default passwords; UFW firewall; SSH key-only access |
| A06: Vulnerable Components | Dependency vulnerabilities | Dependabot alerts; `pip-audit` in CI pipeline; minimal dependency set |
| A07: Authentication Failures | Brute force, credential stuffing | Rate limiting (5 attempts/15min); refresh token rotation; token family revocation |
| A08: Data Integrity Failures | Tampered events | Server-authoritative state; server-generated dice rolls; event sequence validation |
| A09: Logging Failures | Undetected breaches | Comprehensive audit log; structured JSON logging; alerting on security events |
| A10: SSRF | Server-side request forgery | No user-controlled URLs in server requests; MinIO accessed only via internal network |

---

## 13. Performance and Scalability

### 13.1 Connection Pooling

#### PostgreSQL Connection Pool

| Parameter | Development | Production |
|-----------|------------|------------|
| `pool_size` | 5 | 20 |
| `max_overflow` | 5 | 10 |
| `pool_timeout` | 30s | 30s |
| `pool_recycle` | 1800s | 1800s |
| `pool_pre_ping` | True | True |

SQLAlchemy's async engine manages the connection pool. `pool_pre_ping` ensures stale connections are detected and recycled before use.

#### Redis Connection Pool

| Parameter | Development | Production |
|-----------|------------|------------|
| `max_connections` | 10 | 50 |
| `socket_timeout` | 5s | 5s |
| `retry_on_timeout` | True | True |

### 13.2 Horizontal Scaling Strategy

The initial deployment targets a single-server architecture sufficient for approximately 50 concurrent players across multiple sessions. The architecture is designed to scale horizontally when needed:

#### Single-Server Architecture (Phase 1-3)

```
                    Internet
                       │
                   ┌───▼───┐
                   │ Nginx  │
                   └───┬───┘
                       │
                ┌──────▼──────┐
                │   FastAPI    │
                │  (4 workers) │
                └──┬───┬───┬──┘
                   │   │   │
            ┌──────┘   │   └──────┐
            ▼          ▼          ▼
        ┌───────┐ ┌────────┐ ┌───────┐
        │ Redis │ │Postgres│ │ MinIO │
        └───────┘ └────────┘ └───────┘
```

#### Horizontal Scaling Architecture (Phase 4+, if needed)

```
                    Internet
                       │
                   ┌───▼───┐
                   │  LB    │  (Nginx or cloud LB)
                   └───┬───┘
                       │
            ┌──────────┼──────────┐
            ▼          ▼          ▼
       ┌────────┐ ┌────────┐ ┌────────┐
       │FastAPI │ │FastAPI │ │FastAPI │
       │Worker 1│ │Worker 2│ │Worker 3│
       └───┬────┘ └───┬────┘ └───┬────┘
           │          │          │
           └──────────┼──────────┘
                      │
           ┌──────────┼──────────┐
           ▼          ▼          ▼
       ┌───────┐ ┌────────┐ ┌───────┐
       │ Redis │ │Postgres│ │ MinIO │
       │Cluster│ │  (RDS) │ │(Dist.)│
       └───────┘ └────────┘ └───────┘
```

Key scaling mechanisms:

- **Redis PubSub** handles cross-instance event routing. When Worker 1 receives an event for a session with clients connected to Worker 2, Redis PubSub delivers the event to Worker 2.
- **Sticky sessions** via Nginx `ip_hash` directive ensure WebSocket connections from the same client always reach the same worker, reducing cross-instance chatter.
- **Stateless workers** share no in-memory state. All session state is in Redis, all persistent data is in PostgreSQL.
- **MinIO distributed mode** supports multi-node deployment with erasure coding for data durability.

### 13.3 Event Coalescing

High-frequency UI events (slider movements, drag operations) must be coalesced to prevent network flooding:

| Event Type | Coalescing Strategy | Delay |
|-----------|-------------------|-------|
| `AUDIO_STATE` (volume slider) | Debounce: only send the latest state after the delay | 100ms |
| `MINDMAP_NODE_UPDATE` (drag position) | Debounce: only send the final position after the delay | 150ms |
| `FOG_OF_WAR_UPDATE` (drawing) | Batch: collect all fog operations within the window and send as a single event | 200ms |
| `COMBAT_STATE_SYNC` | No coalescing: send immediately on every state change | 0ms |

Client-side coalescing implementation:

```python
class EventCoalescer:
    """Coalesces rapid-fire events into single transmissions."""

    def __init__(self, delay_ms: int = 100):
        self.delay_ms = delay_ms
        self.pending: dict[str, dict] = {}
        self.timers: dict[str, QTimer] = {}

    def queue(self, event_type: str, payload: dict) -> None:
        """Queue an event. If the same type is already pending, replace the payload."""
        self.pending[event_type] = payload
        if event_type not in self.timers:
            timer = QTimer()
            timer.setSingleShot(True)
            timer.timeout.connect(lambda: self._flush(event_type))
            self.timers[event_type] = timer
        self.timers[event_type].start(self.delay_ms)

    def _flush(self, event_type: str) -> None:
        """Send the latest payload for this event type."""
        if event_type in self.pending:
            payload = self.pending.pop(event_type)
            event_manager.emit(event_type, payload)
```

### 13.4 Sync Strategy: Snapshot and Diff

The synchronization strategy uses a combination of full snapshots and incremental diffs:

- **Initial join:** Full state snapshot sent to new client. This includes map state, audio state, combat state, shared entities, and projection state.
- **Ongoing:** Only changed fields sent as incremental events. Each event carries the minimal payload needed to update the client.
- **Reconnect:** Delta resync from last known `seq`, using the Redis event buffer. Fallback to full snapshot if delta resync fails.
- **Large state (fog of war):** Compressed binary snapshots stored as assets in MinIO. Referenced by `fog_snapshot_asset_id` in fog events. Created every 50 fog operations or on session state save.

### 13.5 Caching Layers

```
┌──────────────────────────────────────────────┐
│ Layer 1: Client Memory Cache                  │
│ - Current projection image                    │
│ - Current combat state                        │
│ - Active session state                        │
│ - TTL: Current session only                   │
├──────────────────────────────────────────────┤
│ Layer 2: Client Disk Cache                    │
│ - Map images (cache/online/maps/)             │
│ - Audio files (cache/online/audio/)           │
│ - Entity images (cache/online/entities/)      │
│ - TTL: Session-scoped or 7 days (audio)       │
├──────────────────────────────────────────────┤
│ Layer 3: Nginx Proxy Cache                    │
│ - Static assets served from MinIO             │
│ - TTL: 1 hour for active, 24h for backups    │
│ - Size: 2GB maximum                           │
├──────────────────────────────────────────────┤
│ Layer 4: Redis State Cache                    │
│ - Active session state snapshots              │
│ - Event buffers for delta resync              │
│ - TTL: Session lifetime + 30min grace         │
├──────────────────────────────────────────────┤
│ Layer 5: MinIO Origin Storage                 │
│ - All uploaded assets (authoritative)         │
│ - Backup archives                             │
│ - No TTL (persistent)                         │
└──────────────────────────────────────────────┘
```

### 13.6 Load Testing Targets

| Test Type | Tool | Scenario | Success Criteria |
|-----------|------|----------|-----------------|
| Baseline throughput | Locust | 30 WebSocket clients, steady event stream | P95 < 120ms, 0 errors |
| Connection storm | Locust | 50 clients connect simultaneously | All connections established within 10s |
| Event burst | Locust | 500 events in 5 seconds | No event loss, P95 < 200ms |
| Sustained load | Locust | 90 clients for 2 hours | No memory leaks, stable latency |
| Asset delivery | Locust | 10 concurrent 5MB map downloads | All complete within 3s |
| Soak test | Locust | 30 clients for 3+ hours | No degradation over time |

---

## 14. Network Resilience

### 14.1 Reconnect Protocol

The client maintains a state machine for connection management:

```
                    ┌──────────────┐
                    │              │
       ┌───────────►  CONNECTED   ◄───────────┐
       │            │              │            │
       │            └──────┬───────┘            │
       │                   │                    │
       │          network drop or               │
       │          server error                  │
       │                   │                    │
       │            ┌──────▼───────┐            │
       │            │              │            │
       │            │ RECONNECTING │            │
       │            │              │            │
       │            └──────┬───────┘            │
       │                   │                    │
       │          attempt 1: 1s delay           │
       │                   │                    │
       │            ┌──────▼───────┐      success
       │            │              ├────────────┘
       │            │    RETRY     │
       │            │              ├────────────┐
       │            └──────┬───────┘            │
       │                   │                    │
       │          attempts 2-5:             success
       │          exponential backoff           │
       │          (2s, 4s, 8s, 16s)             │
       │                   │                    │
       │          max attempts exceeded         │
       │                   │                    │
       │            ┌──────▼───────┐            │
       │            │              │            │
       │            │ DISCONNECTED │            │
       │            │              │            │
       │            └──────┬───────┘            │
       │                   │                    │
       │          user clicks "Reconnect"       │
       │                   │                    │
       └───────────────────┘                    │
                                                │
```

**Backoff formula:** `delay = min(2^attempt * 1000, 16000)` milliseconds, with a random jitter of +/- 20% to prevent thundering herd.

**Reconnect sequence after successful connection:**
1. Re-authenticate using current access token (or refresh first if expired).
2. Re-join session room.
3. Send `resync_request` with `last_received_seq`.
4. Server sends delta events or full snapshot.
5. Client applies state updates.
6. Resume normal event flow.

### 14.2 Offline Queue

When the client detects a disconnect, it queues outgoing events locally:

- Events emitted during disconnect are stored in an in-memory queue (max 200 events).
- When the connection is restored, queued events are sent in order.
- The server validates each queued event against the current session state and applies those that are still valid.
- Events that conflict with the current server state are rejected silently (e.g., a combat action for a combatant that has since been removed).

Queue overflow policy: If the queue exceeds 200 events, the oldest events are dropped and the client will request a full snapshot on reconnect instead of relying on the queue.

### 14.3 State Recovery

After reconnection, state recovery proceeds through three tiers:

**Tier 1: Delta Resync (preferred)**
1. Client sends `resync_request` with `from_seq` (last received) and session ID.
2. Server retrieves buffered events from Redis (`session:{id}:events:{range}`).
3. Server sends events in order with their original `seq` numbers.
4. Client applies events sequentially, updating `last_received_seq`.

**Tier 2: Full Snapshot (fallback)**
If delta resync fails (events expired from 1-hour Redis buffer or 3 failed delta attempts):
1. Client requests `GET /v1/sessions/{id}/state`.
2. Server assembles complete current state from Redis and PostgreSQL.
3. Client replaces entire local session state.
4. Client sets `last_received_seq` to the server's current sequence number.

**Tier 3: Session Rejoin (last resort)**
If the full snapshot also fails (e.g., server restart during recovery):
1. Client performs the full join flow again (authenticate, join_session, receive snapshot).
2. This is equivalent to a new join and ensures consistent state.

### 14.4 Conflict Resolution

Since the DM is the authoritative content creator and the server is the authoritative state holder, conflict resolution follows simple rules:

| Conflict Type | Resolution Strategy | Rationale |
|--------------|-------------------|-----------|
| Two clients update the same mind map node simultaneously | Last-write-wins (by server timestamp) | Mind map edits are non-critical; the latest change is likely the intended one |
| DM and player edit the same combat state | DM wins (server rejects player combat edits) | Only DM has `combat:manage` scope |
| Audio state received while audio is transitioning | Apply latest `AUDIO_STATE`; cancel in-progress crossfade | Audio state is full-replace; latest state is correct |
| Map update received while client is loading previous map | Cancel previous load; start loading new map | Map state is full-replace; only current map matters |
| Fog update with seq gap | Request fog snapshot asset | Fog requires sequential application; snapshot is the safe recovery |

### 14.5 Offline Grace Period

When all clients disconnect from a session:

- **Session state is preserved in Redis for 30 minutes.** This covers brief network outages, DM computer restarts, and bathroom breaks.
- **After 30 minutes with no connected clients,** the session is automatically paused (not closed). The state is persisted to PostgreSQL for long-term storage.
- **The DM can resume a paused session at any time** by reconnecting and issuing a resume command. Players can rejoin with the same join key if it has not expired.
- **Sessions are never automatically closed.** Only the DM can explicitly close a session. This prevents data loss from network issues.

### 14.6 Heartbeat and Timeout

| Parameter | Value |
|-----------|-------|
| Heartbeat interval (ping) | 30 seconds |
| Pong timeout | 10 seconds |
| Connection considered dead after | 2 missed pongs (70 seconds) |
| Player timeout before removal from active list | 120 seconds |
| DM timeout before session pause warning | 300 seconds (5 minutes) |

---

## 15. Phase-Based Implementation Plan

### Phase 0: Pre-Online Preparation

**Sprints:** Sprint 1 (Mar 9-20) and Sprint 2 (Mar 23 - Apr 3)

**Goal:** Standardize UI/UX and establish client-side infrastructure before any online code is written. This phase ensures a stable foundation that online features can build upon.

**Deliverables:**

| Deliverable | Description | Sprint |
|------------|-------------|--------|
| Single-window player view | Battle map and player screen combined as tabs within a single window | Sprint 1 |
| GM player screen control panel | DM can control projection status, toggle player screen, manage displayed content | Sprint 1 |
| UI standardization | Common style tokens (button sizes: 28/36/44px, spacing, typography, padding) across all 11 themes | Sprint 1 |
| EventManager skeleton | `core/event_manager.py` with `emit()`, `subscribe()`, `unsubscribe()`, local dispatch | Sprint 1 |
| Embedded viewer | PDF and image content displayed in embedded QWebEngineView | Sprint 2 |
| Socket client layer | `core/socket_client.py` with python-socketio wrapper and reconnect state machine | Sprint 2 |
| Socket smoke test | Client connects to a mock server, sends/receives events, handles disconnect | Sprint 2 |

**Entry Criteria:**
- Existing test suite passes (all 12 test files green)
- No blocking bugs in current Alpha v0.7.7

**Exit Criteria:**
- Player projection controlled from single window (manual verification)
- EventManager unit tests pass (subscribe, emit, mode switching)
- Socket layer passes smoke test with mock server
- UI regression tests pass (button sizes, spacing consistent across themes)
- No existing functionality broken

---

### Phase 1: Online MVP Core

**Sprints:** Sprint 3 (Apr 6-17) and Sprint 4 (Apr 20 - May 1)

**Goal:** Minimum viable online core. DM and players can securely join the same session and see synchronized maps and projected content.

**Deliverables:**

| Deliverable | Description | Sprint |
|------------|-------------|--------|
| FastAPI gateway | Server project structure, ASGI application, health check | Sprint 3 |
| JWT authentication | Register, login, refresh, token rotation, auth guard middleware | Sprint 3 |
| Session management | Create session, generate join key, join session, close session | Sprint 3 |
| PostgreSQL schema | Users, sessions, participants tables with Alembic migrations | Sprint 3 |
| Docker Compose (dev) | Development environment with FastAPI, PostgreSQL, Redis, MinIO | Sprint 3 |
| Asset proxying | Presigned upload/download URLs, MinIO bucket structure, quota enforcement | Sprint 4 |
| Map synchronization | `MAP_STATE_SYNC` and `PROJECTION_UPDATE` events working end-to-end | Sprint 4 |
| Fog of war sync | `FOG_OF_WAR_UPDATE` events with snapshot fallback | Sprint 4 |
| Combat state sync | `COMBAT_STATE_SYNC` events with role-based field filtering | Sprint 4 |

**Entry Criteria:**
- Phase 0 exit criteria fully met
- EventManager and socket client layer functional
- All Phase 0 tests pass

**Exit Criteria:**
- DM creates session, player joins with 6-char code, map and projection sync working
- Unauthorized asset access blocked (security test passes)
- 5MB map loads in < 3 seconds on general internet connection
- JWT authentication flow works end-to-end (register, login, refresh, guard)
- Integration tests for session lifecycle pass

---

### Phase 2: Enhanced Synchronization

**Sprints:** Sprint 5 (May 4-15) and Sprint 6 (May 18-29)

**Goal:** Real-time interactive features that make the online experience engaging: audio synchronization, mind map collaboration, and standalone player instance.

**Deliverables:**

| Deliverable | Description | Sprint |
|------------|-------------|--------|
| Mind map push/receive | `MINDMAP_PUSH`, `MINDMAP_NODE_UPDATE`, `MINDMAP_LINK_SYNC`, `MINDMAP_NODE_DELETE` | Sprint 5 |
| Mind map ownership | Node origin, visibility, and sync_id metadata on all node types | Sprint 5 |
| Reconnect with resync | Delta resync from Redis event buffer, full snapshot fallback | Sprint 5 |
| Audio state sync | `AUDIO_STATE` event with full state replacement | Sprint 6 |
| Audio crossfade sync | `AUDIO_CROSSFADE` event with server-time alignment | Sprint 6 |
| Ambience and SFX sync | `AUDIO_AMBIENCE_UPDATE` and `AUDIO_SFX_TRIGGER` events | Sprint 6 |
| Standalone player instance | Player can launch application in join mode without a local campaign | Sprint 6 |
| Audio file caching | Client-side audio cache with version hash validation | Sprint 6 |
| Performance benchmarks | P95 latency, reconnect timing, and asset throughput measured | Sprint 6 |

**Entry Criteria:**
- Phase 1 exit criteria fully met
- Map and projection sync stable
- Authentication and session management reliable

**Exit Criteria:**
- Multi-player audio state deviation within 500ms tolerance across all clients
- Pushed mind map items appear consistently on all players within 200ms
- Audio files auto-download on cache miss
- Reconnect with state recovery completes in < 5 seconds
- Player instance can join and view content without local campaign
- Performance benchmarks meet KPI targets

---

### Phase 3: Product Maturation

**Sprints:** Sprint 7 (Jun 1-12)

**Goal:** Complete the online gameplay experience with shared event log, server-authoritative dice rolling, and permission-controlled entity views.

**Deliverables:**

| Deliverable | Description | Sprint |
|------------|-------------|--------|
| Automated event log | `EVENT_LOG_APPEND` events generated for combat actions, dice rolls, system events | Sprint 7 |
| Shared dice roller | `DICE_ROLL_REQUEST` and `DICE_ROLL_RESULT` events, server-generated random values | Sprint 7 |
| Restricted entity views | `ENTITY_SHARE` and `CARD_VIEW_GRANT` events with server-side redaction | Sprint 7 |
| Entity visibility UI | DM can toggle entity visibility (private, shared_full, shared_restricted) from NpcSheet | Sprint 7 |
| Event log UI | SessionTab displays event log with filtering by type and round | Sprint 7 |
| Dice result UI | Visual dice result display on all clients with roller attribution | Sprint 7 |

**Entry Criteria:**
- Phase 2 exit criteria fully met
- Audio, mind map, and reconnect features stable
- Performance benchmarks consistently meeting targets

**Exit Criteria:**
- Same event history displayed consistently on DM and player screens
- Role-based data restrictions verified (player cannot see DM-only fields)
- Dice results are auditable, tamper-proof, and consistent across all clients
- Entity redaction verified (dm_notes never appears in player-bound events)

---

### Phase 4: Operational Scaling

**Sprints:** Sprint 8 (Jun 15-26)

**Goal:** Production-ready deployment with backup/restore, self-hosted deployment guide, and the foundation for hosted service operation.

**Deliverables:**

| Deliverable | Description | Sprint |
|------------|-------------|--------|
| Production Docker Compose | `docker-compose.prod.yml` with Nginx, TLS, security hardening | Sprint 8 |
| Nginx configuration | Reverse proxy, TLS termination, rate limiting, WebSocket upgrade, asset caching | Sprint 8 |
| CI/CD pipeline | GitHub Actions workflow for testing, building, and deploying | Sprint 8 |
| Backup/restore | `POST /v1/sessions/{id}/backup`, automated daily backups, integrity verification | Sprint 8 |
| Self-hosted deployment guide | Step-by-step guide for VPS deployment with Docker Compose | Sprint 8 |
| Voice chat (feature-flagged) | WebRTC voice chat integration, disabled by default | Sprint 8 |
| Soak test | 3+ hour continuous session test with all features active | Sprint 8 |
| Observability stack | Prometheus metrics, Grafana dashboards, Loki log aggregation, alerting rules | Sprint 8 |

**Entry Criteria:**
- Phase 3 exit criteria fully met
- All online features functional and stable
- No critical or high security findings

**Exit Criteria:**
- DM can open session to internet from self-hosted server with one-step domain/TLS setup
- Backup/restore smoke test passes (backup, delete, restore, verify integrity)
- 3-hour soak test completes with no degradation, memory leaks, or connection issues
- Monitoring dashboards show all KPI metrics within target ranges
- Deployment guide tested by a team member who did not write it

---

## 16. Testing Strategy

### 16.1 Test Pyramid

```
              ┌────────────┐
              │    E2E      │  5-10 scenarios
              │ (Full flow  │  Multi-client, end-to-end
              │  tests)     │
             ┌┴────────────┴┐
             │ Integration   │  30-50 tests
             │ (API + WS +   │  Server with real Redis/Postgres
             │  Redis flow)  │
            ┌┴──────────────┴┐
            │   Unit Tests    │  100+ tests
            │ (EventManager,  │  Isolated, mocked dependencies
            │  AuthGuard,     │
            │  State Reducer, │
            │  Pydantic models)│
            └────────────────┘
```

### 16.2 Unit Test Targets

| Module | Test Focus | Minimum Tests |
|--------|-----------|--------------|
| `core/event_manager.py` | Subscribe/emit lifecycle, offline/online mode switching, error handling | 15 |
| `core/socket_client.py` | Connect/disconnect/reconnect state machine, backoff calculation, queue management | 12 |
| `server/auth/jwt.py` | Token generation, validation, expiration, refresh rotation, family revocation | 10 |
| `server/auth/guard.py` | Scope verification per role, missing scope rejection, unknown role handling | 8 |
| `server/sessions/service.py` | Session lifecycle, join key generation/expiry, participant management | 12 |
| Event payload models | Pydantic validation round-trip, required field enforcement, optional field handling | 20 |
| Redaction logic | Entity field stripping for `shared_restricted`, preservation for `shared_full` | 8 |
| Event coalescer | Debounce timing, payload replacement, flush behavior | 6 |
| Dice roll engine | Formula parsing, individual rolls, modifier application, edge cases | 10 |

### 16.3 Integration Test Scenarios

| Scenario | Description | Assertions |
|----------|-------------|-----------|
| Auth flow | Register, login, refresh, get profile | Tokens valid, profile matches |
| Session lifecycle | Create session, join, verify participants, close | All state transitions correct |
| Map sync | DM updates map, player receives `MAP_STATE_SYNC` | Player map matches DM map |
| Audio sync | DM changes audio state, player receives `AUDIO_STATE` | Audio state identical on both clients |
| Mind map push | DM pushes node, player receives, DM updates, player receives update | Node appears and updates correctly |
| Combat sync | DM starts combat, adds combatants, player sees filtered view | Player does not see hidden combatants |
| Entity sharing | DM shares entity with `shared_restricted`, player receives | Player does not see `dm_notes` |
| Reconnect flow | Player disconnects, reconnects, receives delta resync | State consistent after reconnect |
| Permission check | Player attempts DM-only action (create session, kick player) | 403 response for all unauthorized actions |
| Rate limiting | Exceed login rate limit | 429 response with `Retry-After` header |
| Asset upload | Presign, upload to MinIO, confirm, download | Asset retrievable with correct content |
| Join key expiry | Use expired join key | 404 `INVALID_JOIN_KEY` |

### 16.4 End-to-End Test Scenarios

| Scenario | Description | Duration |
|----------|-------------|----------|
| Full session flow | DM creates session, 2 players join, map displayed, dice rolled, combat started, entities shared, session closed | 5 minutes |
| Reconnect resilience | Player disconnects 5 times during active session, reconnects each time, verifies state consistency | 3 minutes |
| Security boundary | Player attempts every DM-only operation (session manage, entity share, combat manage, audio control) | 2 minutes |
| Performance | 10 concurrent players, DM rapidly changes map, audio, and combat | 10 minutes |
| Soak test | 5 players, continuous activity (dice rolls, map changes, mind map edits) for 3+ hours | 3 hours |
| Cross-version | Client v1.0 connects to server v1.1 (backward compatibility check) | 5 minutes |

### 16.5 Load Test Specifications

Tool: Locust (Python-based load testing framework)

| Test | Virtual Users | Ramp-Up | Duration | Metrics |
|------|--------------|---------|----------|---------|
| Connection storm | 50 WS clients | 10/second | 30 seconds | Time to connect, connection success rate |
| Steady state | 90 WS clients | 5/second | 2 hours | P50/P95/P99 latency, error rate |
| Event burst | 30 WS clients, 500 events | Instant | 5 seconds | Event loss rate, max latency |
| Asset throughput | 20 concurrent downloads | Instant | 1 minute | Bytes/second, completion time |

### 16.6 Test Environment Setup

| Environment | Infrastructure | Data | Purpose |
|------------|---------------|------|---------|
| Local dev | Docker Compose on developer machine | Seed data from fixtures | Development and debugging |
| CI | GitHub Actions with Docker Compose | Fresh database per run | Automated testing on every PR |
| Staging | Dedicated VPS matching production spec | Copy of test campaign data | Pre-release validation |
| Production | Production VPS | Live data | Monitoring and canary testing only |

### 16.7 CI/CD Pipeline

```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  lint:
    steps:
      - name: Ruff lint
        run: ruff check .
      - name: Ruff format check
        run: ruff format --check .

  typecheck:
    steps:
      - name: mypy strict
        run: mypy server/ core/ --strict

  security:
    steps:
      - name: Bandit scan
        run: bandit -r server/ -f json -o bandit-report.json
      - name: pip-audit
        run: pip-audit

  unit-tests:
    steps:
      - name: Run unit tests
        run: pytest tests/test_core/ tests/test_server/ -v --cov --cov-report=xml
      - name: Coverage check
        run: coverage report --fail-under=80

  integration-tests:
    services: [postgres, redis, minio]
    steps:
      - name: Run migrations
        run: alembic upgrade head
      - name: Run integration tests
        run: pytest tests/test_integration/ -v

  e2e-tests:
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Start full stack
        run: docker compose -f docker-compose.test.yml up -d
      - name: Run E2E tests
        run: pytest tests/test_e2e/ -v
      - name: Tear down
        run: docker compose -f docker-compose.test.yml down
```

---

## 17. Deployment and Operations

### 17.1 Infrastructure Requirements

#### Minimum Server Specifications (Self-Hosted)

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 2 vCPU | 4 vCPU |
| RAM | 4 GB | 8 GB |
| Storage | 40 GB SSD | 100 GB SSD |
| Bandwidth | 100 Mbps | 1 Gbps |
| OS | Ubuntu 22.04+ LTS | Ubuntu 24.04 LTS |

#### Software Requirements

| Software | Version | Required |
|----------|---------|----------|
| Docker | 24.0+ | Yes |
| Docker Compose | v2.20+ | Yes |
| Nginx | 1.24+ | Yes (via Docker) |
| Certbot | 2.0+ | Yes (for TLS) |

### 17.2 Development Docker Compose

The development environment provides hot-reload and debug-friendly configuration:

```yaml
# docker-compose.yml (development)
services:
  api:
    build:
      context: .
      dockerfile: server/Dockerfile
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://dm:dm_secret@postgres:5432/dmtool
      - REDIS_URL=redis://redis:6379/0
      - MINIO_URL=http://minio:9000
      - MINIO_ACCESS_KEY=minioadmin
      - MINIO_SECRET_KEY=minioadmin
      - JWT_SECRET=${JWT_SECRET}
      - CORS_ORIGINS=*
      - LOG_LEVEL=DEBUG
    volumes:
      - ./server:/app/server    # Hot reload
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: dmtool
      POSTGRES_USER: dm
      POSTGRES_PASSWORD: dm_secret
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U dm -d dmtool"]
      interval: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      retries: 5

  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    volumes:
      - miniodata:/data

volumes:
  pgdata:
  miniodata:
```

### 17.3 Production Docker Compose

The production environment adds security hardening, persistent volumes, and internal networking:

```yaml
# docker-compose.prod.yml
services:
  api:
    image: ghcr.io/<org>/dm-tool-server:${TAG}
    restart: always
    environment:
      - DATABASE_URL=postgresql://dm:${DB_PASSWORD}@postgres:5432/dmtool
      - REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379/0
      - MINIO_URL=http://minio:9000
      - MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}
      - MINIO_SECRET_KEY=${MINIO_SECRET_KEY}
      - JWT_SECRET=${JWT_SECRET}
      - CORS_ORIGINS=https://${DOMAIN}
      - LOG_LEVEL=INFO
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - internal
      - web

  postgres:
    image: postgres:16-alpine
    restart: always
    environment:
      POSTGRES_DB: dmtool
      POSTGRES_USER: dm
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U dm -d dmtool"]
      interval: 10s
      retries: 5
    networks:
      - internal

  redis:
    image: redis:7-alpine
    restart: always
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redisdata:/data
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      retries: 5
    networks:
      - internal

  minio:
    image: minio/minio
    restart: always
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ACCESS_KEY}
      MINIO_ROOT_PASSWORD: ${MINIO_SECRET_KEY}
    volumes:
      - miniodata:/data
    networks:
      - internal

  nginx:
    image: nginx:alpine
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - certbot-webroot:/var/www/certbot:ro
    depends_on:
      - api
    networks:
      - web
      - internal

volumes:
  pgdata:
  redisdata:
  miniodata:
  certbot-webroot:

networks:
  internal:
    driver: bridge
  web:
    driver: bridge
```

### 17.4 Nginx Configuration

```nginx
worker_processes auto;
events { worker_connections 1024; }

http {
    upstream api_backend {
        server api:8000;
    }

    # Rate limiting zones
    limit_req_zone $binary_remote_addr zone=api_general:10m rate=30r/s;
    limit_req_zone $binary_remote_addr zone=auth_login:10m rate=5r/m;

    # HTTP to HTTPS redirect
    server {
        listen 80;
        server_name api.example.com ws.example.com assets.example.com;

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        location / {
            return 301 https://$host$request_uri;
        }
    }

    # API and WebSocket server
    server {
        listen 443 ssl http2;
        server_name api.example.com ws.example.com;

        ssl_certificate     /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;
        ssl_protocols       TLSv1.2 TLSv1.3;
        ssl_ciphers         HIGH:!aNULL:!MD5;

        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

        # REST API
        location /v1/ {
            limit_req zone=api_general burst=50 nodelay;
            proxy_pass http://api_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Auth endpoints (stricter rate limit)
        location /v1/auth/ {
            limit_req zone=auth_login burst=3 nodelay;
            proxy_pass http://api_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        # WebSocket
        location /socket.io/ {
            proxy_pass http://api_backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_read_timeout 86400;
        }

        # Health check
        location /health {
            proxy_pass http://api_backend;
        }
    }

    # Assets server (MinIO proxy with caching)
    server {
        listen 443 ssl http2;
        server_name assets.example.com;

        ssl_certificate     /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;

        # Proxy cache
        proxy_cache_path /var/cache/nginx/assets levels=1:2
                         keys_zone=asset_cache:10m max_size=2g
                         inactive=1h use_temp_path=off;

        location / {
            proxy_cache asset_cache;
            proxy_cache_valid 200 1h;
            proxy_cache_use_stale error timeout updating;

            proxy_pass http://minio:9000;
            proxy_set_header Host $host;
            client_max_body_size 50m;

            add_header X-Cache-Status $upstream_cache_status;
        }
    }
}
```

### 17.5 Monitoring and Alerting

#### Prometheus Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `ws_connected_clients` | Gauge | session_id | Current WebSocket connections per session |
| `ws_events_total` | Counter | event_type, session_id | Total events processed |
| `event_delivery_latency_ms` | Histogram | event_type | Time from emit to client acknowledgement |
| `asset_download_duration_ms` | Histogram | content_type | Asset download completion time |
| `asset_download_size_bytes` | Histogram | content_type | Asset download size |
| `sync_resync_count` | Counter | type (delta/full) | Number of resync operations |
| `auth_attempts_total` | Counter | result (success/failure) | Login attempt counter |
| `session_active_count` | Gauge | — | Currently active sessions |
| `http_request_duration_ms` | Histogram | method, endpoint, status | REST API response time |
| `db_pool_available` | Gauge | — | Available database connections |
| `redis_memory_used_bytes` | Gauge | — | Redis memory consumption |

#### Grafana Dashboards

| Dashboard | Panels |
|-----------|--------|
| Overview | Active sessions, connected players, event rate, error rate |
| Performance | P50/P95/P99 latency, asset throughput, cache hit ratio |
| Security | Failed auth attempts, rate limit hits, unauthorized access attempts |
| Infrastructure | CPU, memory, disk, network, database connections, Redis memory |

#### Alerting Rules

| Alert | Condition | Severity | Notification |
|-------|-----------|----------|-------------|
| High event latency | P95 > 200ms for 5 minutes | Warning | Slack channel |
| Critical event latency | P95 > 500ms for 2 minutes | Critical | Slack + PagerDuty |
| Reconnect failure spike | Failure rate > 10% for 5 minutes | Warning | Slack channel |
| Unauthorized access burst | > 10 forbidden requests in 1 minute from same IP | Critical | Slack + PagerDuty |
| Database connection pool low | Available connections < 3 for 2 minutes | Warning | Slack channel |
| Redis memory high | Usage > 80% of configured max | Warning | Slack channel |
| Disk space critical | Available < 10% | Critical | Slack + PagerDuty |
| API error rate high | 5xx rate > 5% for 5 minutes | Critical | Slack + PagerDuty |
| Session count approaching limit | Active sessions > 80% of server capacity | Warning | Slack channel |

### 17.6 Backup and Disaster Recovery

#### Automated Backup Schedule

| Component | Frequency | Retention | Method |
|-----------|----------|-----------|--------|
| PostgreSQL | Daily at 02:00 UTC | 30 days | `pg_dump` compressed with gzip |
| MinIO assets | Daily at 03:00 UTC | 30 days | `mc mirror` to backup volume |
| Redis (RDB) | Every 6 hours | 7 days | Redis BGSAVE + copy |

#### Backup Script

```bash
#!/bin/bash
# scripts/backup.sh
set -euo pipefail

BACKUP_DIR="/backups/$(date +%Y-%m-%d_%H%M)"
mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting backup to $BACKUP_DIR"

# PostgreSQL dump
docker compose -f docker-compose.prod.yml exec -T postgres \
    pg_dump -U dm dmtool | gzip > "$BACKUP_DIR/postgres.sql.gz"
echo "[$(date)] PostgreSQL backup complete"

# MinIO bucket snapshot
docker compose -f docker-compose.prod.yml exec -T minio \
    mc mirror /data "$BACKUP_DIR/minio/" 2>/dev/null || true
echo "[$(date)] MinIO backup complete"

# Redis RDB
docker compose -f docker-compose.prod.yml exec -T redis \
    redis-cli -a "${REDIS_PASSWORD}" BGSAVE
sleep 5
docker cp "$(docker compose -f docker-compose.prod.yml ps -q redis)":/data/dump.rdb \
    "$BACKUP_DIR/redis.rdb"
echo "[$(date)] Redis backup complete"

# Verify PostgreSQL backup integrity
gunzip -t "$BACKUP_DIR/postgres.sql.gz" && echo "PostgreSQL backup integrity OK"

# Calculate backup size
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
echo "[$(date)] Backup complete: $BACKUP_DIR ($BACKUP_SIZE)"

# Retain last 30 days
find /backups -maxdepth 1 -type d -mtime +30 -exec rm -rf {} +
echo "[$(date)] Old backups cleaned up"
```

#### Disaster Recovery Procedure

**Scenario: Complete server failure**

1. Provision new server meeting minimum specifications.
2. Install Docker and Docker Compose.
3. Clone repository and copy production configuration.
4. Copy latest backup to new server.
5. Restore PostgreSQL: `gunzip < postgres.sql.gz | docker compose exec -T postgres psql -U dm dmtool`
6. Restore MinIO: Copy backup MinIO directory to volume mount.
7. Start stack: `docker compose -f docker-compose.prod.yml up -d`
8. Verify restoration: Run health checks and manual session test.
9. Update DNS records to point to new server.
10. Monitor for 1 hour before confirming recovery complete.

**Recovery Time Objective (RTO):** 2 hours
**Recovery Point Objective (RPO):** 24 hours (daily backup)

#### Rollback Procedure

If a deployment introduces a breaking issue:

1. Stop current deployment: `docker compose -f docker-compose.prod.yml down`
2. Restore database from pre-deployment backup if needed.
3. Deploy previous image version: `TAG=previous-tag docker compose -f docker-compose.prod.yml up -d`
4. Verify rollback: Run health checks.
5. Investigate the issue in staging before re-attempting deployment.

### 17.7 Self-Hosted Deployment Guide

The self-hosted deployment process for a DM who wants to run their own server:

**Prerequisites:**
- A VPS or dedicated server with the minimum specifications
- A domain name with DNS access
- Basic familiarity with the Linux command line

**Steps:**

1. **Server setup:** Install Ubuntu 24.04 LTS, Docker, Docker Compose. Configure UFW firewall (ports 80, 443, SSH). Set up SSH key-only access.

2. **DNS configuration:** Create A records for `api.yourdomain.com`, `ws.yourdomain.com`, `assets.yourdomain.com` pointing to the server IP.

3. **TLS certificates:** Run Certbot to obtain Let's Encrypt certificates for all three subdomains.

4. **Application deployment:** Clone the repository, copy `.env.example` to `.env`, fill in secrets (JWT_SECRET, DB_PASSWORD, REDIS_PASSWORD, MINIO_ACCESS_KEY, MINIO_SECRET_KEY, DOMAIN).

5. **Start the stack:** `docker compose -f docker-compose.prod.yml up -d`

6. **Verify:** Open `https://api.yourdomain.com/health` in a browser. Should return `{"status": "ok"}`.

7. **Configure DM application:** In the desktop application, go to Settings, enter `https://api.yourdomain.com` as the server URL.

8. **Create account and first session:** Register via the application, create a session, share the join code with players.

---

## 18. Feature Flags and Versioning

### 18.1 Feature Flag Catalog

| Flag | Default | Phase | Description | Rollout Criteria |
|------|---------|-------|-------------|-----------------|
| `online_session_enabled` | false | Phase 1 | Enable online session creation in DM application | Phase 1 exit criteria met |
| `player_join_enabled` | false | Phase 1 | Enable player join flow | Phase 1 exit criteria met |
| `map_sync_enabled` | false | Phase 1 | Enable map and projection synchronization | Phase 1 exit criteria met |
| `combat_sync_enabled` | false | Phase 1 | Enable combat state synchronization | Phase 1 exit criteria met |
| `mindmap_sync_enabled` | false | Phase 2 | Enable mind map push/receive synchronization | Phase 2 exit criteria met |
| `audio_sync_enabled` | false | Phase 2 | Enable audio state synchronization | Phase 2 exit criteria met |
| `player_instance_enabled` | false | Phase 2 | Enable standalone player instance mode | Phase 2 exit criteria met |
| `dice_roller_shared` | false | Phase 3 | Enable server-authoritative shared dice | Phase 3 exit criteria met |
| `event_log_auto` | false | Phase 3 | Enable automated combat event logging | Phase 3 exit criteria met |
| `entity_sharing_enabled` | false | Phase 3 | Enable entity sharing with visibility controls | Phase 3 exit criteria met |
| `voice_chat_enabled` | false | Phase 4 | Enable WebRTC voice chat | Phase 4 + dedicated testing |
| `backup_enabled` | false | Phase 4 | Enable server-side world backup/restore | Phase 4 exit criteria met |

### 18.2 Flag Storage and Evaluation

Flags are stored at two levels:

- **Server-side flags:** Stored in Redis under `flags:{flag_name}` keys. Evaluated on every request. Can be toggled without deployment.
- **Client-side flags:** Retrieved from `GET /v1/flags` endpoint on application startup and cached locally. Refreshed every 5 minutes.

Flag evaluation order:
1. Check user-level override (for beta testers).
2. Check server-side flag value.
3. Fall back to client-side cached value.
4. Fall back to hardcoded default.

### 18.3 Rollout Strategy

Feature rollout follows a graduated approach:

| Stage | Audience | Duration | Criteria to Advance |
|-------|----------|----------|-------------------|
| Internal | Development team only | 1 week | All tests pass, no blocking bugs |
| Alpha | Internal team + 3-5 invited DMs | 1 week | No critical issues, KPIs met |
| Beta | 20-50 invited DM groups | 2 weeks | No critical issues, positive feedback, KPIs stable |
| General Availability | All users | Ongoing | 30-day beta with zero critical issues |

Rollback procedure for feature flags: Set the flag to `false` in Redis. Change takes effect on next client flag refresh (within 5 minutes) or immediately for server-side checks.

### 18.4 Semantic Versioning

The project uses semantic versioning (SemVer):

- **Major (X.0.0):** Breaking changes to API endpoints, WebSocket event schemas, or database schema that require coordinated client-server updates.
- **Minor (0.X.0):** New features, new event types, new API endpoints. Backward-compatible.
- **Patch (0.0.X):** Bug fixes, performance improvements, security patches. No behavioral changes.

**Current version:** 0.7.7 (Alpha)
**Target GA version:** 1.0.0 (after Phase 4 completion)

### 18.5 Release Train

| Stage | Audience | Entry Criteria |
|-------|----------|---------------|
| Alpha (`0.x.x-alpha.N`) | Internal team + limited testers | Feature complete for current sprint |
| Beta (`0.x.x-beta.N`) | Invited DM groups | All quality gates passed, phase exit criteria met |
| Release Candidate (`0.x.x-rc.N`) | Extended beta group | 2-week beta with zero critical issues |
| General Availability (`1.0.0`) | All users | 30-day RC period with zero critical issues, all Phase 4 criteria met |

### 18.6 Client-Server Version Compatibility

The client and server may be at different versions. Compatibility rules:

- **Server must support current and previous minor versions of client.** A server at v1.2.0 must accept clients at v1.1.x and v1.2.x.
- **Clients must gracefully handle unknown event types.** If the server sends an event type the client does not recognize, the client logs it and ignores it. This allows server-side feature additions without requiring immediate client updates.
- **Breaking changes require dual-write period.** If an event schema changes in a breaking way, the server sends both old and new format during a transition period, allowing clients time to update.
- **Version negotiation on connect.** The `connection_ack` message from the server includes the server version. The client compares this against its minimum compatible version and warns the user if an update is needed.

---

## 19. Risk Register

### Risk 1: Phase 0 Skipped or Rushed

| Field | Value |
|-------|-------|
| Category | Technical |
| Impact | High |
| Probability | Medium |
| Description | Pressure to ship online features quickly leads to skipping or rushing Phase 0 (UI consolidation, EventManager, socket infrastructure). All online features built on an unstable foundation. |
| Mitigation | Phase 0 exit criteria are non-negotiable. No Phase 1 work begins until all Phase 0 exit criteria are verified. Sprint retrospective explicitly reviews Phase 0 completeness. |
| Contingency | If Phase 0 issues are discovered during Phase 1, halt Phase 1 and complete the missing Phase 0 work before proceeding. |
| Owner | Tech Lead |

### Risk 2: Permission Model Gaps

| Field | Value |
|-------|-------|
| Category | Security |
| Impact | Critical |
| Probability | Medium |
| Description | The permission model has gaps that allow unauthorized data access. A player sees DM-only content, or a player from one session accesses data from another session. |
| Mitigation | Scope-based auth guard on every REST endpoint and WebSocket event handler. Comprehensive security-focused integration tests. Audit logging for all access decisions. Server-side content redaction (never rely on client-side filtering). |
| Contingency | Immediate hotfix deployment. Audit log review to assess exposure scope. Notification to affected DMs. |
| Owner | Backend Developer |

### Risk 3: Audio Synchronization Drift

| Field | Value |
|-------|-------|
| Category | Technical |
| Impact | Medium |
| Probability | High |
| Description | Network latency variation causes audio playback to drift between clients, resulting in noticeably different audio experiences across the table. |
| Mitigation | Server-time reference (`start_at` field) for crossfade synchronization. 500ms jitter tolerance window. Periodic full `AUDIO_STATE` re-alignment events (every 30 seconds during active playback). Client-side time offset calculation based on server heartbeat. |
| Contingency | Accept minor audio drift as non-critical. Provide "resync audio" button for manual re-alignment. Document expected behavior in user guide. |
| Owner | Desktop Developer |

### Risk 4: Network State Drift

| Field | Value |
|-------|-------|
| Category | Technical |
| Impact | Medium |
| Probability | Medium |
| Description | Unreliable network connections cause clients to miss events, leading to inconsistent state across players (e.g., one player sees an old map while others see the new one). |
| Mitigation | Monotonic sequence numbers per session. Gap detection triggers automatic delta resync. Full snapshot fallback if delta resync fails. Idempotent event handlers. |
| Contingency | Provide "force refresh" button that requests a full state snapshot. Add client-side visual indicator when state may be stale. |
| Owner | Backend Developer |

### Risk 5: Single Server Bottleneck

| Field | Value |
|-------|-------|
| Category | Operational |
| Impact | Medium |
| Probability | Low (for initial scale) |
| Description | A single server cannot handle the number of concurrent sessions and players if adoption exceeds expectations. |
| Mitigation | Architecture designed for horizontal scaling from the start (Redis PubSub for cross-instance routing, stateless workers, sticky sessions). Performance benchmarks every sprint. Capacity planning based on actual usage metrics. |
| Contingency | Deploy additional worker instances behind load balancer. Migrate to managed Redis and PostgreSQL if self-hosted capacity is insufficient. |
| Owner | DevOps |

### Risk 6: Asset URL Sharing and Leakage

| Field | Value |
|-------|-------|
| Category | Security |
| Impact | Medium |
| Probability | Low |
| Description | A player copies a presigned MinIO URL and shares it externally, allowing unauthorized access to session content. |
| Mitigation | Presigned URLs expire after 60 seconds. URLs are session-scoped and validated against the requesting user's session membership. Single-use token option available for high-sensitivity content. |
| Contingency | Rotate MinIO access keys if widespread leakage is detected. Add IP-binding to presigned URLs (restricts download to requesting IP). |
| Owner | Backend Developer |

### Risk 7: Data Loss from Server Failure

| Field | Value |
|-------|-------|
| Category | Operational |
| Impact | High |
| Probability | Low |
| Description | Server hardware failure or data corruption leads to loss of session data, user accounts, or uploaded assets. |
| Mitigation | Automated daily backups with 30-day retention. PostgreSQL WAL archiving for point-in-time recovery. MinIO bucket versioning. Backup integrity verification in backup script. Documented disaster recovery procedure. |
| Contingency | Follow disaster recovery procedure (Section 17.6). Provision new server and restore from latest backup. RTO: 2 hours, RPO: 24 hours. |
| Owner | DevOps |

### Risk 8: WebSocket Connection Instability

| Field | Value |
|-------|-------|
| Category | Technical |
| Impact | Medium |
| Probability | Medium |
| Description | WebSocket connections frequently drop due to NAT timeouts, firewall interference, or mobile network transitions, causing poor user experience. |
| Mitigation | 30-second heartbeat to keep connections alive through NAT. Exponential backoff reconnect with jitter. Delta resync on reconnect. Client-side event queue for offline period. |
| Contingency | Fall back to HTTP long-polling if WebSocket is consistently blocked. Add connection quality indicator in UI. |
| Owner | Desktop Developer |

### Risk 9: Scope Creep in Online Features

| Field | Value |
|-------|-------|
| Category | Business |
| Impact | Medium |
| Probability | High |
| Description | Feature requests during development expand the online scope beyond what can be delivered in the planned timeline, leading to delays and incomplete features. |
| Mitigation | Strict sprint goals with defined scope. Feature flags for all new capabilities. Each feature requires a written specification before implementation begins. Backlog grooming every sprint. |
| Contingency | Defer non-critical features to post-GA releases. Ship GA with the minimum viable feature set (Phase 1 + Phase 2). |
| Owner | Tech Lead |

### Risk 10: Offline-First Regression

| Field | Value |
|-------|-------|
| Category | Technical |
| Impact | High |
| Probability | Medium |
| Description | Online feature development inadvertently breaks offline functionality, degrading the experience for existing users who do not use online features. |
| Mitigation | Comprehensive regression test suite for offline mode. EventManager LOCAL mode as the default. Feature flags default to false (online features opt-in). Separate test runs for offline-only and online scenarios. |
| Contingency | Revert offending changes. Prioritize offline stability over online feature delivery. |
| Owner | Desktop Developer |

### Risk 11: Third-Party Dependency Vulnerabilities

| Field | Value |
|-------|-------|
| Category | Security |
| Impact | High |
| Probability | Medium |
| Description | A vulnerability is discovered in a critical dependency (FastAPI, python-socketio, PyJWT, SQLAlchemy) that requires immediate patching. |
| Mitigation | Dependabot alerts enabled on GitHub. `pip-audit` runs in CI pipeline. Minimal dependency set (avoid unnecessary packages). Pin dependency versions with regular update reviews. |
| Contingency | Immediate patch deployment for critical vulnerabilities. Temporary workaround (e.g., WAF rule, rate limit tightening) while patch is prepared. |
| Owner | DevOps |

### Risk 12: Subscription Model Technical Debt

| Field | Value |
|-------|-------|
| Category | Business |
| Impact | Low (currently), Medium (long-term) |
| Probability | Medium |
| Description | The subscription and quota enforcement system is deferred, leading to technical debt when it needs to be retrofitted into the architecture. |
| Mitigation | Storage quotas and participant limits are implemented from Phase 1 with configurable defaults. The enforcement layer exists even if billing does not. Plan constants are stored in configuration, not hardcoded. |
| Contingency | Dedicate a focused sprint to subscription integration when the business decision is made. The enforcement hooks are already in place. |
| Owner | Tech Lead |

---

## Appendices

### Appendix A: Complete File Map (Current to Target)

| Current File | Online Changes Required | Phase |
|-------------|----------------------|-------|
| `main.py` | Add DM/Player mode selection, server URL configuration | Phase 0 |
| `config.py` | Add server URL, auth token storage paths, online mode flags | Phase 0 |
| `core/data_manager.py` | Add event emission hooks to all state mutation methods | Phase 0-1 |
| `core/models.py` | Add Pydantic entity models for network transfer | Phase 1 |
| `core/audio/engine.py` | Add `get_state()` and `apply_state()` methods | Phase 2 |
| `core/audio/models.py` | Add Pydantic equivalents for AUDIO_STATE events | Phase 2 |
| `ui/main_root.py` | Support DM/Player mode UI, Session Control panel | Phase 0 |
| `ui/campaign_selector.py` | Add online login/join flow | Phase 1 |
| `ui/player_window.py` | Accept remote content via WebSocket events | Phase 1 |
| `ui/soundpad_panel.py` | Emit audio state change events | Phase 2 |
| `ui/tabs/database_tab.py` | Shared/restricted entity views | Phase 3 |
| `ui/tabs/mind_map_tab.py` | Push/receive node sync | Phase 2 |
| `ui/tabs/map_tab.py` | Real-time pin/fog sync | Phase 1 |
| `ui/tabs/session_tab.py` | Online session controls, event log display | Phase 1, 3 |
| `ui/widgets/combat_tracker.py` | Combat state broadcast, role-based field filtering | Phase 1 |
| `ui/widgets/npc_sheet.py` | Restricted field rendering based on visibility level | Phase 3 |
| `ui/widgets/mind_map_items.py` | Add origin, visibility, sync_id metadata fields | Phase 2 |
| `ui/widgets/map_viewer.py` | Accept remote fog state from server | Phase 1 |
| `ui/widgets/projection_manager.py` | Emit projection events via EventManager | Phase 1 |
| `ui/windows/battle_map_window.py` | Sync fog state with connected players | Phase 1 |
| `installer/build.py` | Include python-socketio, pydantic, httpx dependencies | Phase 1 |
| `core/event_manager.py` | **NEW** EventManager abstraction (local/online dispatch) | Phase 0 |
| `core/socket_client.py` | **NEW** python-socketio wrapper with reconnect state machine | Phase 0 |
| `server/` | **NEW** Complete FastAPI backend | Phase 1 |
| `docker-compose.yml` | **NEW** Development environment | Phase 1 |
| `docker-compose.prod.yml` | **NEW** Production environment | Phase 4 |
| `nginx/` | **NEW** Reverse proxy configuration | Phase 4 |
| `.github/workflows/` | **NEW** CI/CD pipeline | Phase 1 |
| `scripts/backup.sh` | **NEW** Automated backup script | Phase 4 |

### Appendix B: Complete API Endpoint Reference

| Method | Path | Auth | Scope | Phase | Description |
|--------|------|------|-------|-------|-------------|
| POST | `/v1/auth/register` | None | — | 1 | Register new user account |
| POST | `/v1/auth/login` | None | — | 1 | Authenticate and receive tokens |
| POST | `/v1/auth/refresh` | None | — | 1 | Refresh expired access token |
| GET | `/v1/auth/me` | JWT | — | 1 | Get current user profile |
| POST | `/v1/sessions` | JWT | `session:manage` | 1 | Create new game session |
| GET | `/v1/sessions/{id}` | JWT | `session:join` | 1 | Get session details |
| POST | `/v1/sessions/{id}/join` | JWT/Anon | — | 1 | Join session with join key |
| POST | `/v1/sessions/{id}/close` | JWT | `session:manage` | 1 | Close session |
| POST | `/v1/sessions/{id}/kick/{pid}` | JWT | `player:kick` | 1 | Remove participant |
| GET | `/v1/sessions/{id}/state` | JWT | `session:join` | 1 | Full state snapshot |
| POST | `/v1/sessions/{id}/regenerate-key` | JWT | `session:manage` | 1 | Generate new join key |
| POST | `/v1/assets/presign` | JWT | `asset:upload` | 1 | Request presigned upload URL |
| POST | `/v1/assets/{id}/confirm` | JWT | `asset:upload` | 1 | Confirm upload completion |
| GET | `/v1/assets/{id}` | JWT | `asset:read:scoped` | 1 | Get asset download URL |
| POST | `/v1/sessions/{id}/backup` | JWT | `session:manage` | 4 | Initiate world backup |
| GET | `/v1/backups/{id}` | JWT | — | 4 | Check backup status |
| GET | `/v1/flags` | JWT | — | 1 | Get feature flag values |
| GET | `/health` | None | — | 1 | Server health check |

### Appendix C: Complete WebSocket Event Reference

| Event | Direction | Phase | Trigger | Idempotency Strategy |
|-------|-----------|-------|---------|---------------------|
| `SESSION_STATE` | Server to All | 1 | Session state change | Full replace |
| `PLAYER_JOINED` | Server to All | 1 | Player joins session | Upsert by user_id |
| `PLAYER_LEFT` | Server to All | 1 | Player leaves/kicked/timeout | Remove by user_id |
| `SESSION_CLOSED` | Server to All | 1 | DM closes session | Mark closed |
| `MAP_STATE_SYNC` | DM to All | 1 | Map image/grid/pins change | Full replace |
| `PROJECTION_UPDATE` | DM to All | 1 | Projected content change | Full replace |
| `FOG_OF_WAR_UPDATE` | DM to All | 1 | Fog draw/erase | Sequential by seq |
| `COMBAT_STATE_SYNC` | DM to All | 1 | Combat tracker change | Full replace |
| `MINDMAP_PUSH` | DM to Target | 2 | DM shares node | Upsert by node_id |
| `MINDMAP_NODE_UPDATE` | Any to All | 2 | Node edit | Last-write-wins |
| `MINDMAP_LINK_SYNC` | DM to All | 2 | Connection add/remove | Set-based |
| `MINDMAP_NODE_DELETE` | DM to All | 2 | Node deletion | Remove if exists |
| `AUDIO_STATE` | DM to All | 2 | Audio state change | Full replace |
| `AUDIO_CROSSFADE` | DM to All | 2 | Crossfade trigger | Apply if not stale |
| `AUDIO_AMBIENCE_UPDATE` | DM to All | 2 | Ambience slot change | Full replace slot |
| `AUDIO_SFX_TRIGGER` | DM to All | 2 | SFX play | Fire-and-forget |
| `DICE_ROLL_REQUEST` | Any to Server | 3 | User rolls dice | Server processes |
| `DICE_ROLL_RESULT` | Server to All | 3 | Roll complete | Dedup by request_id |
| `EVENT_LOG_APPEND` | Server to All | 3 | Log entry created | Dedup by log_id |
| `ENTITY_SHARE` | DM to Target | 3 | Entity shared | Upsert by entity_id |
| `ENTITY_UPDATE_SHARED` | DM to All | 3 | Shared entity updated | Last-write-wins |
| `CARD_VIEW_GRANT` | DM to Player | 3 | Access grant/revoke | Upsert by (entity, user) |

### Appendix D: Glossary

| Term | Definition |
|------|-----------|
| DM | Dungeon Master. The game session host, referee, and content creator. Has full control over all campaign and session elements. |
| Player | A participant in a tabletop RPG session, controlled by the DM's permission settings. Views shared content and interacts within allowed scope. |
| Observer | A read-only participant. Can view shared content but cannot interact with game mechanics. Intended for spectators or stream audiences. |
| Session | An active online game instance connecting a DM with one or more players through the server. Has a unique ID and join key. |
| Join Key | A 6-character alphanumeric code (e.g., `XY1234`) used by players to join a session. Expires after 24 hours. |
| Entity | Any game object in the campaign database. Types include NPC, Monster, Spell, Equipment, Class, Race, Location, Player, Quest, Lore, Status Effect, Feat, Background, Plane, and Condition. |
| Projection | Content displayed on the player screen by the DM. Can be images, stat blocks, or PDFs in various layout configurations. |
| Fog of War | A visibility mask overlay on battle maps that the DM reveals or hides to control what players can see of the map. |
| Mind Map | An infinite canvas for organizing campaign notes, entities, and ideas as connected nodes. Supports multi-user editing with origin tracking. |
| MusicBrain | The layered audio engine that manages themes, states (Normal/Combat/Victory), intensity levels, ambience slots, and sound effects. |
| Soundpad | The UI panel for controlling MusicBrain audio playback, including theme selection, state switching, volume control, and ambience management. |
| EventManager | The abstraction layer between UI/DataManager and the network layer. Routes events locally (offline) or through WebSocket (online) using the same API. |
| Seq | Sequence number. A monotonically increasing integer counter per session, assigned by the server to each event. Used for ordering and gap detection. |
| Delta Resync | Recovery mechanism where the client requests missed events (by seq range) from the server's Redis buffer to catch up after a brief disconnect. |
| Full Snapshot | Recovery mechanism where the client requests the complete current session state when delta resync is not possible. |
| Presigned URL | A time-limited, pre-authenticated URL generated by the server that allows direct client-to-MinIO file upload or download without exposing storage credentials. |
| Event Coalescing | Client-side technique that batches rapid-fire events (e.g., slider movements) into single network transmissions to prevent flooding. |
| Auth Guard | Server middleware that verifies the authenticated user has the required permission scope for the requested operation. |
| Token Family Revocation | Security mechanism where using a previously revoked refresh token triggers invalidation of all tokens for that user, forcing re-authentication. |

---

*This document is the authoritative reference for the Dungeon Master Tool online system. All implementation decisions should align with the architecture, protocols, and specifications defined here. For sprint-level implementation details, refer to `docs/SPRINT_MAP.md`. For additional technical context, refer to `docs/DEVELOPMENT_REPORT.md`.*
