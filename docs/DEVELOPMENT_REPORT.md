# Dungeon Master Tool — Online Transition: Comprehensive Development Report

> ⚠️ **SUPERSEDED — Kept for historical reference only**
> This document has been superseded by:
> - `docs/ONLINE.md` — Online system vision, architecture, and design (authoritative)
> - `docs/ONLINE_SPRINT.md` — Sprint 3–8 execution plan (authoritative)
> Do not update this document. Update the superseding documents instead.

> **Document version:** 1.0
> **Date:** March 16, 2026
> **Scope:** Architecture, phase plan, security, performance, testing, operations, versioning
> **Source documents:** `docs/archive/ONLINE_*.md`, `docs/archive/SPRINT_DETAILED_REPORTS.md`

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Vision, Goals and Success Criteria](#2-vision-goals-and-success-criteria)
3. [Current System Analysis](#3-current-system-analysis)
4. [Target Architecture](#4-target-architecture)
5. [Technology Stack](#5-technology-stack)
6. [Role and Permission Model](#6-role-and-permission-model)
7. [REST API Design](#7-rest-api-design)
8. [WebSocket Event Catalog](#8-websocket-event-catalog)
9. [Database Design](#9-database-design)
10. [Asset Management](#10-asset-management)
11. [Security Design](#11-security-design)
12. [Performance and Scalability](#12-performance-and-scalability)
13. [Network Resilience](#13-network-resilience)
14. [Phase-Based Implementation Plan](#14-phase-based-implementation-plan)
15. [Testing Strategy](#15-testing-strategy)
16. [Deployment](#16-deployment)
17. [Observability](#17-observability)
18. [Versioning and Feature Flags](#18-versioning-and-feature-flags)
19. [Risk Register](#19-risk-register)
20. [Technical Debt and Refactoring Priorities](#20-technical-debt-and-refactoring-priorities)
21. [Conclusion](#21-conclusion)
22. [Appendices](#appendices)

---

## 1. Executive Summary

Dungeon Master Tool is an offline-first PyQt6 desktop application (Alpha v0.7.7) for tabletop RPG game masters. The online transition is not simply adding a network layer — it requires:

- Evolving the application architecture to a **hybrid client-server model**
- Formalizing a **role and permission model** (DM, Player, Observer)
- Building a **real-time event-driven backbone** for synchronization
- Implementing **asset distribution, caching, security, backup, and observability** layers

### Recommended Strategy

1. Treat Phase 0 and Phase 1 as a single "Online MVP Core"
2. Roll out Phase 2 features (audio + mind map + player instance) in a controlled, measurable way
3. Manage Phase 3 and Phase 4 as product maturation and operational scaling phases

### Critical Success Factor

**Phase discipline:** Phase 0 must be completed before any online work begins. Each phase has formal exit criteria that must be met before proceeding.

---

## 2. Vision, Goals and Success Criteria

### 2.1 Product Vision

A platform that:
- Preserves the DM's desktop power and control
- Allows players to join sessions with minimal friction (6-character code, no account initially required)
- Synchronizes maps, media, audio, and interactive gameplay elements in real-time
- Remains secure, measurable, and scalable

### 2.2 Business Goals

- Add online capabilities without disrupting existing offline users
- Establish the technical foundation for a subscription model
- Enable transition to hosted server infrastructure

### 2.3 Technical Success Criteria (KPIs)

| KPI | Target |
|-----|--------|
| P95 event latency (publish → client apply) | < 120ms |
| 5MB map first load time (general internet) | < 3 seconds |
| Warm cache load time | < 1 second |
| Session reconnect + state recovery | < 5 seconds |
| Unauthorized content leakage to player RAM/disk | Zero |
| Critical security breaches | Zero |

---

## 3. Current System Analysis

### 3.1 Codebase Structure and Module Map

**Language:** Python 3.10+
**GUI Framework:** PyQt6
**Total source files:** 56 Python files
**Total lines of code:** ~11,500
**Test files:** 12 files (~850 lines)

#### Complete File Inventory

| File | Lines | Module | Role | Online Impact |
|------|-------|--------|------|---------------|
| `main.py` | 387 | Entry | Application entry, MainWindow, run loop | Must support DM/Player mode selection |
| `config.py` | 147 | Config | Path resolution, theme loading | Must add server URL, auth token storage |
| `core/data_manager.py` | 677 | Core | Central data hub — entity CRUD, campaign I/O, API client, library cache | Must be extended with event emission for all state mutations |
| `core/api_client.py` | 705 | Core | D&D 5e + Open5e API integration | No direct online impact |
| `core/models.py` | 197 | Core | Entity schemas (15 types), legacy migration maps | Must add Pydantic equivalents for network transfer |
| `core/library_fs.py` | 250 | Core | Local library filesystem scan/migration | No direct online impact |
| `core/locales.py` | 26 | Core | i18n setup (python-i18n wrapper) | No change needed |
| `core/theme_manager.py` | 284 | Core | UI theme palette management (11 themes) | No change needed |
| `core/audio/engine.py` | 327 | Audio | MusicBrain layered audio engine | Must expose state for serialization and sync |
| `core/audio/models.py` | 36 | Audio | Audio data structures (LoopNode, Track, MusicState, Theme) | Must be serializable for AUDIO_STATE events |
| `core/audio/loader.py` | 286 | Audio | Soundpad theme file loading from YAML | No direct online impact |
| `core/dev/hot_reload_manager.py` | 348 | Dev | Hot reload state machine | Dev-only, no online impact |
| `core/dev/ipc_bridge.py` | 164 | Dev | IPC communication for dev mode | Dev-only, no online impact |
| `ui/main_root.py` | 162 | UI | Widget factory (create_root_widget) | Must support DM/Player mode switching, Session Control panel |
| `ui/campaign_selector.py` | 123 | UI | World selection dialog | Must add online login/join flow |
| `ui/player_window.py` | 147 | UI | Player screen projection (second monitor) | Must accept remote content via WebSocket |
| `ui/soundpad_panel.py` | 439 | UI | Audio control panel | Must emit events for audio state changes |
| `ui/tabs/database_tab.py` | 296 | UI | Entity/content browser (dual-panel) | Must support shared/restricted entity views |
| `ui/tabs/mind_map_tab.py` | 617 | UI | Infinite canvas mind map | Must support push/receive node sync |
| `ui/tabs/map_tab.py` | 271 | UI | World map with timeline/pins | Must support real-time pin/fog sync |
| `ui/tabs/session_tab.py` | 272 | UI | Session management + embedded combat | Must integrate online session controls |
| `ui/widgets/combat_tracker.py` | 912 | UI | Initiative, HP, conditions, tokens | Must sync combat state in real-time |
| `ui/widgets/npc_sheet.py` | 1002 | UI | Rich entity editor | Must support shared/restricted field rendering |
| `ui/widgets/entity_sidebar.py` | 332 | UI | Quick entity search/filter | No direct online impact |
| `ui/widgets/mind_map_items.py` | 455 | UI | Canvas drawing (nodes, connections) | Must add origin/visibility/sync_id metadata |
| `ui/widgets/map_viewer.py` | 232 | UI | Map display + fog of war overlay | Must accept remote fog state |
| `ui/widgets/markdown_editor.py` | 415 | UI | Rich text editing with HTML preview | No direct online impact |
| `ui/widgets/projection_manager.py` | 231 | UI | Drag-drop image projection bar | Must emit network events in addition to local signals |
| `ui/widgets/combat_tracker.py` | 912 | UI | Combat management HUD | Must broadcast combat state |
| `ui/widgets/image_viewer.py` | 55 | UI | Image display widget | No direct online impact |
| `ui/widgets/aspect_ratio_label.py` | 68 | UI | Aspect-ratio preserving label | No direct online impact |
| `ui/windows/battle_map_window.py` | 762 | UI | Battle map + fog of war window | Must sync fog state with players |
| `ui/dialogs/api_browser.py` | 490 | UI | D&D API browser dialog | No direct online impact |
| `ui/dialogs/bulk_downloader.py` | 290 | UI | Content bulk downloader | No direct online impact |
| `ui/dialogs/import_window.py` | 422 | UI | Import wizard | No direct online impact |
| `ui/dialogs/encounter_selector.py` | 211 | UI | Encounter builder dialog | No direct online impact |
| `ui/dialogs/entity_selector.py` | 121 | UI | Entity selection dialog | No direct online impact |
| `ui/dialogs/theme_builder.py` | 187 | UI | Custom theme editor | No direct online impact |
| `ui/dialogs/timeline_entry.py` | 134 | UI | Timeline pin editor | No direct online impact |
| `ui/workers.py` | 71 | UI | Background worker threads | No direct online impact |
| `dev_run.py` | 436 | Dev | Hot reload development runner | Dev-only |
| `dump.py` | 113 | Utility | Debug dump utility | Dev-only |
| `installer/build.py` | 101 | Build | PyInstaller build script | Must include new server dependencies |

### 3.2 Data Flow

```
┌──────────────────────────────────────────────────────────────┐
│                  DataManager (Central Hub)                     │
│  self.data = {                                                │
│    "world_name": str,                                         │
│    "entities": { eid: entity_dict, ... },                     │
│    "map_data": { "image_path", "pins", "timeline" },          │
│    "sessions": [{ "id", "name", "date", "notes",              │
│                    "logs", "combatants" }],                    │
│    "last_active_session_id": str,                             │
│    "mind_maps": { mind_map_id: { "nodes", "connections" } }   │
│  }                                                            │
│  Persistence: MsgPack (.dat) primary, JSON fallback           │
└──────────────────┬───────────────────────────────────────────┘
                   │ PyQt6 Signals
    ┌──────────────┼──────────────┐
    ▼              ▼              ▼
┌────────┐  ┌──────────┐  ┌────────────┐
│ UI Tabs │  │ Dialogs  │  │ PlayerWindow│
│ (4 tabs)│  │ (7 types)│  │ (projection)│
└────────┘  └──────────┘  └────────────┘
```

**Write Path:**
1. User edits entity in NpcSheet widget
2. `data_changed` signal emitted
3. `collect_data_from_sheet()` called
4. `DataManager.save_entity()` writes to `self.data["entities"]`
5. `DataManager.save_data()` serializes to `campaign_folder/data.dat` via MsgPack

**Read Path:**
1. `load_campaign(folder)` loads `.dat` (MsgPack) or `.json` fallback
2. Integrity checks (sessions, entities, maps exist)
3. Path migration (absolute → relative)
4. Schema migration (legacy Turkish → English via `SCHEMA_MAP`)
5. UI tabs populate from `self.data` dict

### 3.3 UI Architecture

```
MainWindow (QMainWindow)
├── Toolbar
│   ├── btn_toggle_player → PlayerWindow (QMainWindow, second screen)
│   ├── btn_export_txt
│   ├── btn_toggle_sound
│   ├── projection_manager → ProjectionManager (drag-drop zone)
│   ├── lbl_campaign
│   ├── combo_language (EN/TR/DE/FR)
│   ├── combo_theme (11 themes)
│   └── btn_switch_world
├── content_splitter (QSplitter)
│   ├── entity_sidebar → EntitySidebar (entity search/filter)
│   ├── tabs (QTabWidget)
│   │   ├── Tab 0: DatabaseTab (dual-panel entity sheets)
│   │   ├── Tab 1: MindMapTab (infinite canvas)
│   │   ├── Tab 2: MapTab (world map + timeline)
│   │   └── Tab 3: SessionTab (session + combat tracker)
│   └── soundpad_panel → SoundpadPanel (audio controls)
└── PlayerWindow (separate QMainWindow)
    └── QStackedWidget
        ├── Page 0: Multi-image viewer
        ├── Page 1: Stat block viewer
        └── Page 2: PDF viewer (QWebEngineView)
```

### 3.4 Current Data Models

#### Entity Structure (`core/models.py:153`)

```python
{
    "name": str,
    "type": str,           # NPC, Monster, Spell, Equipment, Class, Race,
                            # Location, Player, Quest, Lore, Status Effect,
                            # Feat, Background, Plane, Condition
    "source": str,
    "description": str,
    "images": [str],        # Relative paths to campaign assets
    "image_path": str,      # Legacy single image (kept for compatibility)
    "battlemaps": [str],    # For Location type
    "tags": [str],
    "attributes": {},       # Type-specific properties (see ENTITY_SCHEMAS)
    "stats": {"STR": 10, "DEX": 10, "CON": 10, "INT": 10, "WIS": 10, "CHA": 10},
    "combat_stats": {"hp": "", "max_hp": "", "ac": "", "speed": "",
                     "cr": "", "xp": "", "initiative": ""},
    "traits": [], "actions": [], "reactions": [], "legendary_actions": [],
    "spells": [], "custom_spells": [],
    "equipment_ids": [], "inventory": [],
    "pdfs": [],
    "location_id": None,
    "dm_notes": str,        # DM-only notes (never shared with players)
    "saving_throws": str, "damage_vulnerabilities": str,
    "damage_resistances": str, "damage_immunities": str,
    "condition_immunities": str, "proficiency_bonus": str,
    "passive_perception": str, "skills": str
}
```

#### Session Structure

```python
{
    "id": "uuid-v4",
    "name": str,
    "date": str,
    "notes": str,           # Rich Markdown
    "logs": str,            # Combat event log
    "combatants": [{
        "entity_id": str,
        "name": str, "hp": int, "max_hp": int,
        "ac": int, "initiative": int,
        "conditions": [{"name": str, "duration": int, "max_duration": int}],
        "token_state": {"tile_x": int, "tile_y": int}
    }]
}
```

#### Mind Map Structure

```python
{
    "nodes": {
        "node_id": {
            "pos": {"x": float, "y": float},
            "size": {"w": float, "h": float},
            "text": str,
            "type": str,     # "note", "entity", "workspace"
            "color": str
        }
    },
    "connections": [{"start_id": str, "end_id": str}]
}
```

#### Audio State (from `core/audio/engine.py` and `core/audio/models.py`)

```python
# MusicBrain state components:
{
    "current_theme_id": str,
    "current_state_id": str,       # "Normal", "Combat", "Victory"
    "current_intensity_level": str, # "base", "level1", "level2"
    "master_volume": float,        # 0.0 - 1.0
    "ambience_slots": [
        {"id": str_or_null, "volume": float}  # Up to N ambience slots
    ]
}
```

### 3.5 Gap Analysis

| Area | Current State | Required for Online |
|------|--------------|-------------------|
| Network layer | None | WebSocket + REST API |
| Authentication | None | JWT + session membership |
| Event bus | Direct Qt signals only | EventManager abstraction layer |
| Centralized state | DataManager.data dict | Server-authoritative session state |
| Permission model | None (single user) | Role-based (DM/Player/Observer) |
| Content sharing | Local projection only | Network-based with visibility rules |
| Audio sync | Local MusicBrain only | Real-time audio state broadcast |
| Asset distribution | Local filesystem | Signed URL proxy + client cache |
| Observability | print() statements | Structured logging + metrics + alerts |
| Deployment | Desktop binary only | Docker Compose + Nginx + TLS |

---

## 4. Target Architecture

### 4.1 Hybrid Client-Server Model

```
┌─────────────────┐     ┌─────────────────┐
│   DM App         │     │   Player App     │
│   (PyQt6)        │     │   (PyQt6)        │
│   Master Client  │     │   Restricted     │
│                  │     │   Client         │
└────────┬─────────┘     └────────┬─────────┘
         │ WebSocket + REST        │ WebSocket + REST
         │                         │
    ┌────▼─────────────────────────▼────┐
    │        FastAPI Gateway             │
    │   + python-socketio (ASGI)         │
    │   Auth, Session, Event Routing     │
    └────┬──────────┬──────────┬────────┘
         │          │          │
    ┌────▼───┐ ┌───▼───┐ ┌───▼──────┐
    │ Redis   │ │Postgres│ │  MinIO    │
    │ Session │ │ Users  │ │  Assets   │
    │ PubSub  │ │ Audit  │ │  Backup   │
    │ Rate    │ │ Events │ │           │
    └─────────┘ └────────┘ └──────────┘
```

### 4.2 Bounded Context Definitions

| Context | Responsibility | Primary Store |
|---------|---------------|--------------|
| `identity` | Login, JWT tokens, subscription entitlements | PostgreSQL |
| `session` | Create/join/close, participant lifecycle, join keys | Redis + PostgreSQL |
| `sync` | Map, mind map, audio, combat event routing | Redis PubSub |
| `assets` | Upload, proxy, cache invalidation, signed URLs | MinIO |
| `gameplay` | Event log, dice, restricted card views | PostgreSQL |

### 4.3 Data Flow Principles

1. **Server-authoritative session state** — the server is the single source of truth for active session state
2. **Client-side optimistic UI** — only for low-risk actions (e.g., local audio volume adjustment)
3. **Required event envelope fields:** `event_id`, `session_id`, `ts`, `schema_version`, `seq`
4. **Idempotent client apply pipeline** — deduplicate by `event_id`
5. **At-least-once delivery assumption** — clients must handle duplicate events

### 4.4 Key Architectural Decisions

1. **EventManager as abstraction layer:** A new `core/event_manager.py` sits between DataManager/UI and the network layer. The same code path works offline (local signals) and online (WebSocket events).

2. **DataManager event emission:** `DataManager.save_data()` currently writes directly to MsgPack. Online mode adds: `save_data()` → `emit event` → `server receives` → `broadcasts to peers`.

3. **MusicBrain state serialization:** `MusicBrain` maintains state across `master_volume`, `current_state_id`, `current_intensity_level`, and ambience slot volumes. All must be serializable for `AUDIO_STATE` events.

4. **PlayerWindow as remote display:** `player_window.py`'s `add_image_to_view()`, `show_stat_block()`, `show_pdf()` are called directly. Online mode requires these to accept data from WebSocket events.

5. **Mind map node origin tracking:** `MindMapNode` currently has no ownership metadata. Online version needs `origin` (DM/player), `visibility` (private/shared), and `sync_id` fields.

6. **Server directory:** A new `server/` directory at project root for FastAPI backend, keeping client code in existing structure.

---

## 5. Technology Stack

### 5.1 Desktop Application (DM + Player)

| Component | Technology |
|-----------|-----------|
| Language | Python 3.12 |
| GUI Framework | PyQt6 |
| WebSocket Client | `python-socketio[asyncio_client]` |
| Data Validation | Pydantic v2 |
| Serialization | MsgPack (local), JSON (network) |
| Testing | pytest + pytest-qt + pytest-mock |

### 5.2 Backend and Real-time Layer

| Component | Technology |
|-----------|-----------|
| API Framework | FastAPI |
| WebSocket Server | `python-socketio` (ASGI mount) |
| ASGI Server | Uvicorn + Gunicorn |
| Session/Presence | Redis 7 |
| Persistent Data | PostgreSQL 16 |
| Migrations | Alembic |
| Auth | PyJWT + bcrypt |

### 5.3 Asset and Storage

| Component | Technology |
|-----------|-----------|
| Object Storage | MinIO (S3-compatible, self-hosted) |
| Client Cache | Local filesystem (versioned) |
| Backup | PostgreSQL dump + MinIO bucket snapshot |

### 5.4 Observability and Operations

| Component | Technology |
|-----------|-----------|
| Metrics | Prometheus + Grafana |
| Logging | Loki + Promtail (structured JSON) |
| CI/CD | GitHub Actions + SSH-based Docker Compose deploy |

### 5.5 Self-Hosted Deployment

| Component | Technology |
|-----------|-----------|
| OS | Ubuntu Server 24.04 LTS |
| Container Runtime | Docker + Docker Compose |
| Reverse Proxy + TLS | Nginx + Let's Encrypt (Certbot) |
| DNS Structure | `api.<domain>`, `ws.<domain>`, `assets.<domain>` |
| Security | UFW, fail2ban, SSH key-only access |

---

## 6. Role and Permission Model

### 6.1 Roles

| Role | Description |
|------|-------------|
| `DM_OWNER` | Full control — session management, content sharing, player management |
| `PLAYER` | Restricted access — view permitted content, interact within allowed scope |
| `OBSERVER` | Read-only — view only, no interaction (optional, future) |

### 6.2 Permission Scopes

| Scope | Description |
|-------|-------------|
| `session:manage` | Create, close, configure sessions |
| `session:join` | Join an active session |
| `player:kick` | Remove a player from session |
| `asset:read:scoped` | Read assets within session scope |
| `asset:upload` | Upload assets to session |
| `mindmap:push` | Push mind map nodes to players |
| `mindmap:edit:own` | Edit own workspace nodes |
| `audio:control` | Control audio playback for all |
| `audio:volume:local` | Adjust local volume only |
| `gameplay:dice:roll` | Roll dice (results visible to all) |
| `gameplay:log:read` | Read event log |
| `entity:share` | Share entities with visibility level |
| `entity:view:shared` | View shared entities |
| `combat:manage` | Manage combat tracker |
| `combat:view` | View combat state |

### 6.3 Content Visibility Levels

| Level | Description |
|-------|-------------|
| `private_dm` | DM-only — never sent to any player client |
| `shared_full` | Full content shared with permitted players |
| `shared_restricted` | Redacted version — `dm_notes`, secret info, and DM-flagged fields stripped server-side |

### 6.4 Permission Matrix

| Scope | DM_OWNER | PLAYER | OBSERVER |
|-------|----------|--------|----------|
| `session:manage` | Yes | No | No |
| `session:join` | Yes | Yes | Yes |
| `player:kick` | Yes | No | No |
| `asset:read:scoped` | Yes | Yes | Yes |
| `asset:upload` | Yes | No | No |
| `mindmap:push` | Yes | No | No |
| `mindmap:edit:own` | Yes | Yes | No |
| `audio:control` | Yes | No | No |
| `audio:volume:local` | Yes | Yes | Yes |
| `gameplay:dice:roll` | Yes | Yes | No |
| `gameplay:log:read` | Yes | Yes | Yes |
| `entity:share` | Yes | No | No |
| `entity:view:shared` | Yes | Yes | Yes |
| `combat:manage` | Yes | No | No |
| `combat:view` | Yes | Yes | Yes |

### 6.5 Auth Guard Middleware

```python
# server/auth/guard.py
from functools import wraps
from fastapi import HTTPException, Depends
from server.auth.jwt import get_current_user
from server.sessions.service import get_participant_role

ROLE_SCOPES = {
    "DM_OWNER": {"session:manage", "session:join", "player:kick", "asset:read:scoped",
                  "asset:upload", "mindmap:push", "mindmap:edit:own", "audio:control",
                  "audio:volume:local", "gameplay:dice:roll", "gameplay:log:read",
                  "entity:share", "entity:view:shared", "combat:manage", "combat:view"},
    "PLAYER":   {"session:join", "asset:read:scoped", "mindmap:edit:own",
                  "audio:volume:local", "gameplay:dice:roll", "gameplay:log:read",
                  "entity:view:shared", "combat:view"},
    "OBSERVER": {"session:join", "asset:read:scoped", "audio:volume:local",
                  "gameplay:log:read", "entity:view:shared", "combat:view"},
}

def require_scope(scope: str):
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, user=Depends(get_current_user),
                          session_id: str = None, **kwargs):
            role = await get_participant_role(session_id, user.id)
            if scope not in ROLE_SCOPES.get(role, set()):
                raise HTTPException(403, f"Scope '{scope}' required")
            return await func(*args, user=user, session_id=session_id, **kwargs)
        return wrapper
    return decorator
```

---

## 7. REST API Design

### 7.1 Base URL

```
https://api.<domain>/v1
```

### 7.2 Error Format

All error responses follow this structure:

```json
{
    "error": {
        "code": "INVALID_JOIN_KEY",
        "message": "The join key has expired or is invalid.",
        "details": {}
    }
}
```

### 7.3 Endpoints

#### `POST /v1/auth/register`

Register a new DM account.

| Field | Value |
|-------|-------|
| Auth | None |
| Request Body | `{"username": str, "email": str, "password": str}` |
| Response 201 | `{"user_id": str, "username": str, "access_token": str, "refresh_token": str, "expires_in": int}` |
| Response 409 | Error: `USERNAME_TAKEN` or `EMAIL_TAKEN` |

#### `POST /v1/auth/login`

Authenticate and receive tokens.

| Field | Value |
|-------|-------|
| Auth | None |
| Request Body | `{"username": str, "password": str}` |
| Response 200 | `{"user_id": str, "username": str, "access_token": str, "refresh_token": str, "expires_in": int}` |
| Response 401 | Error: `INVALID_CREDENTIALS` |

#### `POST /v1/auth/refresh`

Refresh an expired access token.

| Field | Value |
|-------|-------|
| Auth | None |
| Request Body | `{"refresh_token": str}` |
| Response 200 | `{"access_token": str, "refresh_token": str, "expires_in": int}` |
| Response 401 | Error: `INVALID_REFRESH_TOKEN` |

#### `GET /v1/auth/me`

Get current user profile.

| Field | Value |
|-------|-------|
| Auth | Bearer JWT |
| Response 200 | `{"user_id": str, "username": str, "email": str, "created_at": str}` |

#### `POST /v1/sessions`

Create a new game session (DM only).

| Field | Value |
|-------|-------|
| Auth | Bearer JWT |
| Scope | `session:manage` |
| Request Body | `{"world_name": str, "max_players": int (default 10)}` |
| Response 201 | `{"session_id": str, "join_key": str (6 chars), "join_key_expires_at": str, "ws_url": str}` |

#### `GET /v1/sessions/{session_id}`

Get session details.

| Field | Value |
|-------|-------|
| Auth | Bearer JWT |
| Scope | `session:join` (must be participant) |
| Response 200 | `{"session_id": str, "world_name": str, "status": "active"\|"closed", "dm": {"user_id": str, "username": str}, "participants": [{"user_id": str, "username": str, "role": str, "connected": bool}], "created_at": str}` |

#### `POST /v1/sessions/{session_id}/join`

Join an active session as a player.

| Field | Value |
|-------|-------|
| Auth | Bearer JWT (or anonymous with display name) |
| Request Body | `{"join_key": str, "display_name": str (optional if authenticated)}` |
| Response 200 | `{"session_id": str, "role": "PLAYER", "ws_url": str, "participant_id": str}` |
| Response 404 | Error: `INVALID_JOIN_KEY` |
| Response 409 | Error: `SESSION_FULL` |
| Response 410 | Error: `SESSION_CLOSED` |

#### `POST /v1/sessions/{session_id}/close`

Close a session (DM only).

| Field | Value |
|-------|-------|
| Auth | Bearer JWT |
| Scope | `session:manage` |
| Response 200 | `{"session_id": str, "status": "closed", "closed_at": str}` |

#### `POST /v1/assets/presign`

Request a presigned upload URL.

| Field | Value |
|-------|-------|
| Auth | Bearer JWT |
| Scope | `asset:upload` |
| Request Body | `{"session_id": str, "filename": str, "content_type": str, "size_bytes": int}` |
| Response 200 | `{"asset_id": str, "upload_url": str, "upload_expires_at": str}` |
| Response 413 | Error: `FILE_TOO_LARGE` (max 50MB) |

#### `GET /v1/assets/{asset_id}`

Get a time-limited download URL for an asset.

| Field | Value |
|-------|-------|
| Auth | Bearer JWT |
| Scope | `asset:read:scoped` |
| Response 200 | `{"asset_id": str, "download_url": str, "expires_at": str, "content_type": str, "size_bytes": int}` |
| Response 403 | Error: `ASSET_NOT_IN_SESSION_SCOPE` |

#### `GET /v1/sessions/{session_id}/state`

Get full session state snapshot (used for initial sync and reconnect fallback).

| Field | Value |
|-------|-------|
| Auth | Bearer JWT |
| Scope | `session:join` |
| Response 200 | Full session state object (see WebSocket section for structure) |

#### `POST /v1/sessions/{session_id}/backup`

Create a world backup (DM only).

| Field | Value |
|-------|-------|
| Auth | Bearer JWT |
| Scope | `session:manage` |
| Response 202 | `{"backup_id": str, "status": "in_progress"}` |

---

## 8. WebSocket Event Catalog

### 8.1 Connection Lifecycle

```
Client                          Server
  │                                │
  ├── WS connect ─────────────────►│
  │◄── connection_ack ────────────┤
  │                                │
  ├── authenticate ───────────────►│  (JWT token)
  │◄── auth_success ──────────────┤  (user_id, role)
  │                                │
  ├── join_session ───────────────►│  (session_id)
  │◄── session_snapshot ──────────┤  (full state)
  │                                │
  │   ◄── heartbeat ──────────►   │  (every 30s)
  │                                │
  │   ◄── events ─────────────►   │  (bidirectional)
  │                                │
  ├── disconnect ─────────────────►│
  │◄── disconnect_ack ────────────┤
```

### 8.2 Event Envelope

Every WebSocket event MUST be wrapped in this envelope:

```python
# shared/events/envelope.py
from pydantic import BaseModel, Field
from datetime import datetime
from uuid import uuid4
from enum import Enum

class EventType(str, Enum):
    # Session
    SESSION_STATE = "SESSION_STATE"
    PLAYER_JOINED = "PLAYER_JOINED"
    PLAYER_LEFT = "PLAYER_LEFT"
    SESSION_CLOSED = "SESSION_CLOSED"

    # Map / Projection
    MAP_STATE_SYNC = "MAP_STATE_SYNC"
    PROJECTION_UPDATE = "PROJECTION_UPDATE"
    FOG_OF_WAR_UPDATE = "FOG_OF_WAR_UPDATE"

    # Mind Map
    MINDMAP_PUSH = "MINDMAP_PUSH"
    MINDMAP_NODE_UPDATE = "MINDMAP_NODE_UPDATE"
    MINDMAP_LINK_SYNC = "MINDMAP_LINK_SYNC"
    MINDMAP_NODE_DELETE = "MINDMAP_NODE_DELETE"

    # Audio
    AUDIO_STATE = "AUDIO_STATE"
    AUDIO_CROSSFADE = "AUDIO_CROSSFADE"
    AUDIO_AMBIENCE_UPDATE = "AUDIO_AMBIENCE_UPDATE"
    AUDIO_SFX_TRIGGER = "AUDIO_SFX_TRIGGER"

    # Gameplay
    DICE_ROLL_REQUEST = "DICE_ROLL_REQUEST"
    DICE_ROLL_RESULT = "DICE_ROLL_RESULT"
    EVENT_LOG_APPEND = "EVENT_LOG_APPEND"
    COMBAT_STATE_SYNC = "COMBAT_STATE_SYNC"

    # Entity
    ENTITY_SHARE = "ENTITY_SHARE"
    ENTITY_UPDATE_SHARED = "ENTITY_UPDATE_SHARED"
    CARD_VIEW_GRANT = "CARD_VIEW_GRANT"

class SenderInfo(BaseModel):
    role: str        # "DM_OWNER", "PLAYER", "OBSERVER"
    user_id: str
    username: str

class EventEnvelope(BaseModel):
    event_id: str = Field(default_factory=lambda: str(uuid4()))
    schema_version: str = "1.0"
    session_id: str
    event: EventType
    sender: SenderInfo
    ts: datetime = Field(default_factory=datetime.utcnow)
    seq: int           # Monotonically increasing per session
    payload: dict      # Type-specific payload (see below)
```

**Example JSON:**

```json
{
    "event_id": "550e8400-e29b-41d4-a716-446655440000",
    "schema_version": "1.0",
    "session_id": "XY1234",
    "event": "AUDIO_STATE",
    "sender": {"role": "DM_OWNER", "user_id": "dm-1", "username": "Eren"},
    "ts": "2026-03-16T14:30:00Z",
    "seq": 1203,
    "payload": {}
}
```

### 8.3 Session Events

#### SESSION_STATE

Direction: Server → All Clients
Trigger: Session state change (periodic broadcast or on-change)

```python
class SessionStatePayload(BaseModel):
    status: str                    # "active", "paused", "closed"
    dm_status: str                 # "online", "away"
    active_players: list[dict]     # [{"user_id", "username", "connected"}]
    current_view: str              # "BATTLE_MAP", "PROJECTION", "MIND_MAP"

# Idempotency: Replace entire session state on client. Safe to replay.
```

#### PLAYER_JOINED

Direction: Server → All Clients
Trigger: New player joins session

```python
class PlayerJoinedPayload(BaseModel):
    user_id: str
    username: str
    role: str        # "PLAYER" or "OBSERVER"

# Idempotency: Upsert to participant list by user_id. Safe to replay.
```

#### PLAYER_LEFT

Direction: Server → All Clients
Trigger: Player disconnects or is kicked

```python
class PlayerLeftPayload(BaseModel):
    user_id: str
    username: str
    reason: str      # "disconnect", "kicked", "timeout"

# Idempotency: Remove from participant list by user_id. Safe to replay.
```

#### SESSION_CLOSED

Direction: Server → All Clients
Trigger: DM closes the session

```python
class SessionClosedPayload(BaseModel):
    reason: str      # "dm_closed", "timeout", "error"
    closed_at: str

# Idempotency: Mark session as closed. Safe to replay.
```

### 8.4 Map / Projection Events

#### MAP_STATE_SYNC

Direction: DM → Server → Players
Trigger: Map changes (image, grid, pins update)

```python
class MapStateSyncPayload(BaseModel):
    image_asset_id: str | None     # Asset ID for current map image
    grid_enabled: bool
    grid_size: int                  # px
    pins: list[dict]               # Visible pins only (filtered by DM permission)
    viewport: dict                 # {"x": float, "y": float, "zoom": float}

# Idempotency: Full replace of map state. Safe to replay.
```

#### PROJECTION_UPDATE

Direction: DM → Server → Players
Trigger: DM changes projected content

```python
class ProjectionUpdatePayload(BaseModel):
    projection_type: str           # "image", "stat_block", "pdf", "clear"
    asset_ids: list[str]           # Asset IDs for projected content
    layout: str                    # "single", "split_2", "split_3", "split_4"
    stat_block_data: dict | None   # If projection_type is "stat_block"

# Idempotency: Full replace of projection state. Safe to replay.
```

#### FOG_OF_WAR_UPDATE

Direction: DM → Server → Players
Trigger: DM draws/erases fog

```python
class FogOfWarUpdatePayload(BaseModel):
    action: str                    # "reveal", "hide", "full_reset"
    regions: list[dict]            # [{"points": [{"x": float, "y": float}]}]
    fog_snapshot_asset_id: str | None  # Full fog state as image (for reconnect)

# Idempotency: Apply action sequentially by seq number. On gap, request snapshot.
```

### 8.5 Mind Map Events

#### MINDMAP_PUSH

Direction: DM → Server → Target Players
Trigger: DM shares a mind map node

```python
class MindmapPushPayload(BaseModel):
    node_id: str
    node_type: str                 # "note", "entity", "image"
    content: str                   # Text content or entity_id
    position: dict                 # {"x": float, "y": float}
    size: dict                     # {"w": float, "h": float}
    color: str | None
    origin: str                    # "dm"
    visibility: str                # "shared_full" or "shared_restricted"
    target_players: list[str] | None  # None = all players
    entity_data: dict | None       # If node_type is "entity", pre-loaded entity data

# Idempotency: Upsert node by node_id. Safe to replay.
```

#### MINDMAP_NODE_UPDATE

Direction: Any (within permission) → Server → Session
Trigger: Node position, content, or size changed

```python
class MindmapNodeUpdatePayload(BaseModel):
    node_id: str
    updates: dict                  # Partial update: any of {position, size, content, color}

# Idempotency: Apply partial update. Last-write-wins on conflict.
```

#### MINDMAP_LINK_SYNC

Direction: DM → Server → Players
Trigger: Connection between nodes created/removed

```python
class MindmapLinkSyncPayload(BaseModel):
    action: str                    # "add" or "remove"
    connection: dict               # {"start_id": str, "end_id": str}

# Idempotency: Add is idempotent (set-based). Remove is idempotent.
```

#### MINDMAP_NODE_DELETE

Direction: DM → Server → Players
Trigger: DM deletes a shared node

```python
class MindmapNodeDeletePayload(BaseModel):
    node_id: str

# Idempotency: Remove if exists. No-op if already removed.
```

### 8.6 Audio Events

#### AUDIO_STATE

Direction: DM → Server → Players
Trigger: Theme, intensity, or volume change

```python
class AudioStatePayload(BaseModel):
    theme_id: str
    state_id: str                  # "Normal", "Combat", "Victory"
    intensity_level: str           # "base", "level1", "level2"
    master_volume: float           # 0.0 - 1.0
    ambience_slots: list[dict]     # [{"id": str|None, "volume": float}]
    server_time: str               # ISO 8601 — for sync reference

# Idempotency: Full replace of audio state. Safe to replay.
```

#### AUDIO_CROSSFADE

Direction: DM → Server → Players
Trigger: Intensity slider or state change with crossfade

```python
class AudioCrossfadePayload(BaseModel):
    from_state: str
    to_state: str
    from_intensity: str
    to_intensity: str
    crossfade_duration_ms: int     # e.g. 2000
    start_at: str                  # Server timestamp for synchronized start

# Idempotency: Apply if start_at is in future or within tolerance. Ignore stale.
```

#### AUDIO_AMBIENCE_UPDATE

Direction: DM → Server → Players
Trigger: Ambience slot change

```python
class AudioAmbienceUpdatePayload(BaseModel):
    slot_index: int
    ambience_id: str | None        # None = stop slot
    volume: float

# Idempotency: Full replace of slot state. Safe to replay.
```

#### AUDIO_SFX_TRIGGER

Direction: DM → Server → Players
Trigger: SFX button press

```python
class AudioSfxTriggerPayload(BaseModel):
    sfx_id: str
    volume: float

# Idempotency: Fire-and-forget. Duplicate play is acceptable (within dedup window).
```

### 8.7 Gameplay Events

#### DICE_ROLL_REQUEST

Direction: Player/DM → Server
Trigger: Dice roll initiated

```python
class DiceRollRequestPayload(BaseModel):
    dice_formula: str              # e.g. "2d6+3", "1d20"
    roll_type: str                 # "attack", "damage", "save", "check", "custom"
    label: str                     # e.g. "Longsword Attack"

# Server generates result — client NEVER generates dice values.
```

#### DICE_ROLL_RESULT

Direction: Server → All Clients
Trigger: Server processes dice roll

```python
class DiceRollResultPayload(BaseModel):
    request_event_id: str          # Links to DICE_ROLL_REQUEST
    roller_user_id: str
    roller_username: str
    dice_formula: str
    individual_rolls: list[int]    # [4, 6] for 2d6
    modifier: int
    total: int
    roll_type: str
    label: str

# Idempotency: Deduplicate by request_event_id. Safe to replay.
```

#### EVENT_LOG_APPEND

Direction: Server → All Clients
Trigger: Combat action, dice roll, or DM-initiated log entry

```python
class EventLogAppendPayload(BaseModel):
    log_id: str
    log_type: str                  # "combat_action", "dice_roll", "dm_note", "system"
    round_number: int | None
    actor: str                     # Username or entity name
    description: str               # Human-readable description
    details: dict | None           # Structured data (damage, healing, etc.)

# Idempotency: Append-only log. Deduplicate by log_id.
```

#### COMBAT_STATE_SYNC

Direction: DM → Server → Players
Trigger: Combat tracker state change

```python
class CombatStateSyncPayload(BaseModel):
    is_combat_active: bool
    current_round: int
    current_turn_entity_id: str | None
    combatants: list[dict]         # Combatant list with HP, AC, initiative, conditions
    # Note: DM-only fields (dm_notes, hidden entities) stripped for PLAYER role

# Idempotency: Full replace of combat state. Safe to replay.
```

### 8.8 Entity Events

#### ENTITY_SHARE

Direction: DM → Server → Target Players
Trigger: DM shares an entity with players

```python
class EntitySharePayload(BaseModel):
    entity_id: str
    visibility: str                # "shared_full" or "shared_restricted"
    entity_data: dict              # Full or redacted entity data
    target_players: list[str] | None  # None = all players

# Idempotency: Upsert shared entity by entity_id. Safe to replay.
```

#### ENTITY_UPDATE_SHARED

Direction: DM → Server → Players
Trigger: Shared entity modified by DM

```python
class EntityUpdateSharedPayload(BaseModel):
    entity_id: str
    updates: dict                  # Partial entity update (visible fields only)
    visibility: str

# Idempotency: Apply partial update. Last-write-wins.
```

#### CARD_VIEW_GRANT

Direction: DM → Server → Specific Player
Trigger: DM grants/revokes card database access

```python
class CardViewGrantPayload(BaseModel):
    entity_id: str
    granted_to: str                # user_id
    visibility: str                # "shared_full", "shared_restricted", "revoked"

# Idempotency: Upsert grant by (entity_id, granted_to). Safe to replay.
```

### 8.9 Reliability Rules

1. **At-least-once delivery** — clients must handle duplicate events via `event_id`
2. **`seq` ordering** — monotonically increasing per session; client detects gaps
3. **Gap detection** — if `received_seq > expected_seq + 1`, request incremental resync
4. **Resync failure** — after 3 failed retry attempts, request full snapshot via `GET /v1/sessions/{id}/state`
5. **Idempotent apply** — every event handler must be safe to apply multiple times

---

## 9. Database Design

### 9.1 PostgreSQL Schema

```sql
-- ============================================
-- Users and Authentication
-- ============================================

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

-- ============================================
-- Sessions
-- ============================================

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

-- ============================================
-- Session Participants
-- ============================================

CREATE TABLE session_participants (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES users(id),       -- NULL for anonymous players
    display_name    VARCHAR(100) NOT NULL,
    role            VARCHAR(20) NOT NULL DEFAULT 'PLAYER'
                    CHECK (role IN ('DM_OWNER', 'PLAYER', 'OBSERVER')),
    joined_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    left_at         TIMESTAMPTZ,
    is_connected    BOOLEAN NOT NULL DEFAULT false,

    UNIQUE (session_id, user_id)
);

CREATE INDEX idx_participants_session ON session_participants (session_id);

-- ============================================
-- Shared Entities (entity visibility grants)
-- ============================================

CREATE TABLE shared_entities (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    entity_id       VARCHAR(255) NOT NULL,            -- From DM's local entity ID
    visibility      VARCHAR(30) NOT NULL DEFAULT 'shared_full'
                    CHECK (visibility IN ('shared_full', 'shared_restricted', 'revoked')),
    granted_to      UUID REFERENCES users(id),        -- NULL = all session players
    entity_snapshot JSONB NOT NULL,                    -- Cached entity data (redacted if restricted)
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (session_id, entity_id, granted_to)
);

CREATE INDEX idx_shared_session ON shared_entities (session_id);

-- ============================================
-- Event Log (append-only)
-- ============================================

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

-- ============================================
-- Dice Rolls (immutable audit trail)
-- ============================================

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

-- ============================================
-- Audit Log
-- ============================================

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

### 9.2 Redis Key Patterns

| Key Pattern | Type | TTL | Purpose |
|-------------|------|-----|---------|
| `session:{id}:state` | Hash | Session lifetime | Active session state (status, participant list, current view) |
| `session:{id}:seq` | String (counter) | Session lifetime | Current sequence number for events |
| `session:{id}:participants` | Set | Session lifetime | Set of connected user IDs |
| `session:{id}:events:{seq_start}:{seq_end}` | List | 1 hour | Recent event buffer for delta resync |
| `joinkey:{key}` | String | 24 hours | Maps join key → session_id |
| `user:{id}:active_session` | String | Session lifetime | Current active session for user |
| `ws:conn:{socket_id}` | Hash | Connection lifetime | Socket metadata (user_id, session_id, role) |
| `ratelimit:{ip}:{endpoint}` | String (counter) | 1 minute | Rate limiting counter |
| `ratelimit:join_attempt:{ip}` | String (counter) | 15 minutes | Join attempt throttle |

### 9.3 Migration Strategy (MsgPack → PostgreSQL)

The local MsgPack `data.dat` files remain the primary storage for offline DM campaigns. PostgreSQL stores **only online session metadata** — it does NOT replace local campaign storage.

Data flow:
1. DM starts an online session → session record created in PostgreSQL
2. DM shares entities → entity snapshot stored in `shared_entities` table
3. Dice rolls and event log → stored in PostgreSQL for audit
4. Session closes → session marked as closed, data archived

Local `data.dat` remains the authoritative campaign storage. PostgreSQL is the authoritative **session** storage.

---

## 10. Asset Management

### 10.1 MinIO Bucket Structure

```
dm-assets/
├── sessions/
│   └── {session_id}/
│       ├── maps/           # Battle map images
│       ├── projections/    # Projected images
│       ├── audio/          # Shared audio files
│       ├── mindmap/        # Shared mind map node images
│       └── entities/       # Entity images
└── backups/
    └── {user_id}/
        └── {backup_id}/   # World backup archives
```

### 10.2 Upload Flow

1. DM client requests presigned upload URL: `POST /v1/assets/presign`
2. Server generates presigned MinIO PUT URL (TTL: 5 minutes)
3. Client uploads directly to MinIO
4. Server confirms upload and records asset metadata
5. Server generates presigned download URL on demand

### 10.3 Signed URL Generation

```python
# server/assets/service.py
import boto3
from datetime import timedelta

def generate_download_url(asset_id: str, session_id: str, user_role: str) -> str:
    """Generate a time-limited, scoped download URL."""
    # Verify asset belongs to session
    # Verify user has asset:read:scoped permission

    client = boto3.client('s3', endpoint_url=MINIO_URL)
    url = client.generate_presigned_url(
        'get_object',
        Params={
            'Bucket': 'dm-assets',
            'Key': f'sessions/{session_id}/maps/{asset_id}'
        },
        ExpiresIn=60  # 60 seconds
    )
    return url
```

### 10.4 Client Cache Strategy

| Content Type | Cache Location | TTL | Invalidation |
|-------------|---------------|-----|-------------|
| Map images | `cache/online/maps/` | Until session close | Asset ID change |
| Audio files | `cache/online/audio/` | 7 days | Version hash mismatch |
| Entity images | `cache/online/entities/` | Until session close | Asset ID change |
| Projection images | In-memory only | Current projection | Next projection event |

### 10.5 File Size Limits

| Content Type | Max Size |
|-------------|---------|
| Map image | 50 MB |
| Audio file | 20 MB |
| Entity image | 10 MB |
| PDF document | 30 MB |
| Total per session | 500 MB |

---

## 11. Security Design

### 11.1 JWT Implementation

| Token | Lifetime | Storage |
|-------|----------|---------|
| Access Token | 15 minutes | In-memory (client) |
| Refresh Token | 7 days | Secure local storage |

**Access Token Payload:**
```json
{
    "sub": "user-uuid",
    "username": "Eren",
    "iat": 1711234567,
    "exp": 1711235467,
    "jti": "token-uuid"
}
```

**Refresh Token Rotation:** Each refresh request invalidates the old refresh token and issues a new pair. If a revoked refresh token is used, all tokens for that user are invalidated (token family revocation).

### 11.2 WebSocket Authentication

1. Client connects via WebSocket
2. Client sends `authenticate` event with JWT access token
3. Server validates token, extracts user identity
4. Server associates socket connection with user and session
5. If token expires during connection, server sends `token_expired` event; client refreshes and re-authenticates without disconnecting

### 11.3 Rate Limiting

| Endpoint | Limit | Window |
|----------|-------|--------|
| `POST /auth/login` | 5 attempts | 15 minutes per IP |
| `POST /sessions/{id}/join` | 10 attempts | 15 minutes per IP |
| `POST /assets/presign` | 30 requests | 1 minute per user |
| WebSocket events | 100 events | 1 second per connection |

### 11.4 Input Validation

- All REST request bodies validated via Pydantic models
- WebSocket event payloads validated via Pydantic before processing
- File upload content-type verified against actual file magic bytes
- SQL injection prevention via SQLAlchemy parameterized queries
- XSS prevention: all user-generated content HTML-escaped before rendering

### 11.5 Audit Logging

The following actions are logged to the `audit_log` table:

- Session create/close
- Player join/kick
- Permission changes (entity share/revoke)
- Restricted content access
- Failed authentication attempts
- Asset upload/download

### 11.6 OWASP Checklist

| Category | Mitigation |
|----------|-----------|
| Injection | Parameterized queries, Pydantic validation |
| Broken Authentication | JWT rotation, bcrypt hashing, rate limiting |
| Sensitive Data Exposure | TLS mandatory, signed asset URLs, server-side redaction |
| Broken Access Control | Role-based auth guard on every endpoint/event |
| Security Misconfiguration | Docker secrets, no default credentials |
| XSS | HTML escaping, Content-Security-Policy headers |
| CSRF | JWT-based auth (no cookies), SameSite headers |

---

## 12. Performance and Scalability

### 12.1 Target Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| P50 event latency | < 50ms | Server-side histogram |
| P95 event latency | < 120ms | Server-side histogram |
| Reconnect success rate | > 99% | Counter ratio |
| Cache hit ratio (assets) | > 80% | Client-side counter |
| Asset throughput | > 10 MB/s | Server-side gauge |

### 12.2 Sync Strategy: Snapshot + Diff

- **Initial join:** Full state snapshot sent to new client
- **Ongoing:** Only changed fields sent as incremental events
- **Reconnect:** Delta resync from last known `seq`, fallback to full snapshot
- **Large state (fog of war):** Compressed binary snapshot stored as asset

### 12.3 Event Coalescing

For high-frequency events (e.g., slider movements, drag operations):

```python
# Client-side coalescing
class EventCoalescer:
    def __init__(self, delay_ms=100):
        self.delay_ms = delay_ms
        self.pending = {}

    def queue(self, event_type, payload):
        """Queue event; if same type is pending, replace payload."""
        self.pending[event_type] = payload
        # Timer fires after delay_ms → emit latest payload
```

Coalesce targets:
- `AUDIO_STATE` (volume slider) → 100ms debounce
- `MINDMAP_NODE_UPDATE` (drag position) → 150ms debounce
- `FOG_OF_WAR_UPDATE` (drawing) → 200ms batch

### 12.4 Horizontal Scaling Notes

Current architecture supports **single-server deployment** (sufficient for 50 concurrent players). For future horizontal scaling:

- Redis PubSub handles cross-instance event routing
- Sticky sessions via Nginx `ip_hash` for WebSocket connections
- Stateless FastAPI workers behind load balancer
- MinIO supports distributed mode

---

## 13. Network Resilience

### 13.1 Reconnect Strategy

```
State Machine:
  CONNECTED ──(network drop)──► RECONNECTING
  RECONNECTING ──(attempt 1: 1s delay)──► CONNECTED or RETRY
  RETRY ──(attempt 2: 2s delay)──► CONNECTED or RETRY
  RETRY ──(attempt 3: 4s delay)──► CONNECTED or RETRY
  RETRY ──(attempt 4: 8s delay)──► CONNECTED or RETRY
  RETRY ──(attempt 5: 16s delay)──► CONNECTED or DISCONNECTED
  DISCONNECTED ──(user action)──► RECONNECTING
```

Exponential backoff: `delay = min(2^attempt * 1000, 16000)` ms, with ±20% jitter.

### 13.2 Sequence-Based Ordering

- Server assigns monotonically increasing `seq` per session
- Client tracks `last_received_seq`
- On receive: if `event.seq == last_received_seq + 1` → apply normally
- If `event.seq > last_received_seq + 1` → gap detected → request delta resync
- If `event.seq <= last_received_seq` → duplicate → ignore (idempotent)

### 13.3 Delta Resync

1. Client sends `resync_request` with `from_seq` and `to_seq`
2. Server retrieves buffered events from Redis (`session:{id}:events:{range}`)
3. Server sends events in order
4. Client applies events sequentially

### 13.4 Full Snapshot Fallback

If delta resync fails (events expired from Redis buffer):

1. Client requests `GET /v1/sessions/{id}/state`
2. Server returns complete session state
3. Client replaces entire local state
4. Client updates `last_received_seq` to server's current `seq`

### 13.5 Offline Grace Period

- Session state is preserved server-side for **30 minutes** after all clients disconnect
- DM can reconnect within this window without losing state
- After 30 minutes, session is automatically paused (not closed)
- DM can resume a paused session at any time

---

## 14. Phase-Based Implementation Plan

### Phase 0: Foundations and Internal Cleanup

**Goal:** Standardize UI/UX and establish client-side infrastructure before online transition.

**Deliverables:**
- Single-window player view (battle map + player screen in tabs)
- GM player screen control panel
- Embedded PDF/Image viewer
- Socket.io client + EventManager abstraction
- UI standardization (button sizes, layouts)

**Files to modify:**
- `ui/main_root.py` — Player view + battle map single-window merge
- `ui/player_window.py` — GM control panel integration
- `ui/windows/battle_map_window.py` — Embed within session tab
- `themes/*.qss` — Common style tokens

**Files to create:**
- `core/event_manager.py` — EventManager class
- `core/socket_client.py` — python-socketio wrapper

**Exit Criteria:**
- Player projection controlled from single window
- Socket layer passes smoke test with mock server
- UI regression tests pass

---

### Phase 1: Hub MVP

**Goal:** Minimum viable online core — DM and players can securely join the same session.

**Deliverables:**
- FastAPI gateway + JWT authentication
- Session create/join with 6-character join key
- Basic image/map sync
- Asset proxying with signed URLs

**Files to create:**
- `server/` directory (complete FastAPI project)
- `docker-compose.yml` (development environment)
- `server/migrations/` (Alembic PostgreSQL migrations)

**Exit Criteria:**
- DM creates session, player joins, map/projection syncs
- Unauthorized asset access blocked in security test
- 5MB map loads in < 3 seconds

---

### Phase 2: Interactive MVP

**Goal:** Real-time interactive features — audio and mind map synchronization.

**Deliverables:**
- Soundpad/MusicBrain sync with crossfade
- Mind map push and connection sync
- Standalone player instance join mode
- Audio file auto-caching

**Files to modify:**
- `core/audio/engine.py` — State serialization
- `ui/soundpad_panel.py` — Event emission
- `ui/tabs/mind_map_tab.py` — Push/receive sync
- `ui/widgets/mind_map_items.py` — Origin/visibility metadata

**Exit Criteria:**
- Multi-player audio state deviation within acceptable threshold
- Pushed mind map items appear consistently on all players
- Audio files auto-download on cache miss

---

### Phase 3: Advanced Gameplay Mechanics

**Goal:** Shared gameplay experience with event log, dice, and card sharing.

**Deliverables:**
- Automated event log (append-only, per-round)
- Server-authoritative shared dice roller
- Restricted card database views
- Player character sheets with DM approval flow

**Files to modify:**
- `ui/tabs/session_tab.py` — Event log integration
- `ui/widgets/combat_tracker.py` — Combat state broadcast
- `ui/tabs/database_tab.py` — Shared/restricted entity views
- `ui/widgets/npc_sheet.py` — Restricted field rendering

**Exit Criteria:**
- Same event history displayed consistently on DM/player screens
- Role-based data restrictions verified
- Dice results auditable and tamper-proof

---

### Phase 4: Cloud and Deployment

**Goal:** Internet-accessible production deployment with backup and hosted model foundation.

**Deliverables:**
- Self-hosted production deployment (VPS) with domain/TLS
- World backup/restore with integrity verification
- Voice chat via WebRTC (feature-flagged)
- Official hosted server operational foundation

**Files to create:**
- `docker-compose.prod.yml` — Production stack
- `nginx/` — Nginx configuration
- `.github/workflows/deploy.yml` — CI/CD deployment pipeline
- `scripts/backup.sh` — Automated backup script

**Exit Criteria:**
- DM can open session to internet in one step
- Backup/restore smoke test passes
- 3-hour soak test completes successfully

---

## 15. Testing Strategy

### 15.1 Test Pyramid

```
         ┌──────────┐
         │   E2E    │  5-10 scenarios
         │ (Playwright│
         │  + WS)   │
        ┌┴──────────┴┐
        │ Integration │  30-50 tests
        │  (API +     │
        │   Redis +   │
        │   WS flow)  │
       ┌┴─────────────┴┐
       │   Unit Tests   │  100+ tests
       │  (EventManager,│
       │   AuthGuard,   │
       │   State Reducer)│
       └────────────────┘
```

### 15.2 Unit Test Targets

| Module | Test Focus |
|--------|-----------|
| `core/event_manager.py` | Subscribe/emit lifecycle, offline/online mode switching |
| `server/auth/` | JWT generation/validation, refresh rotation, password hashing |
| `server/auth/guard.py` | Scope verification per role |
| `server/sessions/service.py` | Session lifecycle, join key generation/expiry |
| Event payload models | Pydantic validation, serialization round-trip |
| `core/socket_client.py` | Connect/disconnect/reconnect state machine |

### 15.3 Integration Test Scenarios

| Scenario | Description |
|----------|-------------|
| Auth flow | Register → login → refresh → me |
| Session lifecycle | Create → join → events → close |
| Asset flow | Presign → upload → download → verify |
| Map sync | DM updates map → player receives sync |
| Mind map push | DM pushes node → player receives → reconnect preserves |
| Audio sync | DM changes state → all players receive |
| Permission check | Player attempts DM-only action → 403 |
| Rate limiting | Exceed login limit → 429 |

### 15.4 E2E Test Scenarios

| Scenario | Description |
|----------|-------------|
| Full session | DM creates session, 2 players join, map shown, dice rolled, session closed |
| Reconnect | Player disconnects → reconnects → state recovered |
| Security | Player attempts to access restricted entity → blocked |
| Performance | 10 concurrent players, measure P95 latency |
| Soak test | 3+ hour continuous session |

### 15.5 CI Pipeline Test Steps

```yaml
# .github/workflows/test.yml
steps:
  - name: Unit tests
    run: pytest tests/test_core/ tests/test_server/ -v --cov
  - name: Integration tests
    run: docker compose -f docker-compose.test.yml up -d && pytest tests/test_integration/ -v
  - name: Security scan
    run: bandit -r server/ -f json
  - name: Type check
    run: mypy server/ core/ --strict
```

---

## 16. Deployment

### 16.1 Docker Compose (Development)

```yaml
# docker-compose.yml
version: "3.9"

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

### 16.2 Docker Compose (Production)

```yaml
# docker-compose.prod.yml
version: "3.9"

services:
  api:
    image: ghcr.io/<org>/dm-tool-server:${TAG}
    restart: always
    environment:
      - DATABASE_URL=postgresql://dm:${DB_PASSWORD}@postgres:5432/dmtool
      - REDIS_URL=redis://redis:6379/0
      - MINIO_URL=http://minio:9000
      - MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}
      - MINIO_SECRET_KEY=${MINIO_SECRET_KEY}
      - JWT_SECRET=${JWT_SECRET}
      - CORS_ORIGINS=https://${DOMAIN}
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

volumes:
  pgdata:
  miniodata:
  certbot-webroot:

networks:
  internal:
  web:
```

### 16.3 Nginx Configuration

```nginx
# nginx/nginx.conf
worker_processes auto;
events { worker_connections 1024; }

http {
    upstream api_backend {
        server api:8000;
    }

    # Rate limiting zones
    limit_req_zone $binary_remote_addr zone=api_general:10m rate=30r/s;
    limit_req_zone $binary_remote_addr zone=auth_login:10m rate=5r/m;

    # HTTP → HTTPS redirect
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

    # API + WebSocket
    server {
        listen 443 ssl http2;
        server_name api.example.com ws.example.com;

        ssl_certificate     /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;
        ssl_protocols       TLSv1.2 TLSv1.3;

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
    }

    # Assets (MinIO proxy)
    server {
        listen 443 ssl http2;
        server_name assets.example.com;

        ssl_certificate     /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;

        location / {
            proxy_pass http://minio:9000;
            proxy_set_header Host $host;
            client_max_body_size 50m;
        }
    }
}
```

### 16.4 Backup Strategy

```bash
#!/bin/bash
# scripts/backup.sh — Daily backup script (run via cron)

BACKUP_DIR="/backups/$(date +%Y-%m-%d)"
mkdir -p "$BACKUP_DIR"

# PostgreSQL dump
docker compose exec -T postgres pg_dump -U dm dmtool | gzip > "$BACKUP_DIR/postgres.sql.gz"

# MinIO bucket snapshot
docker compose exec -T minio mc mirror /data "$BACKUP_DIR/minio/"

# Verify integrity
pg_restore --list "$BACKUP_DIR/postgres.sql.gz" > /dev/null 2>&1
echo "Backup completed: $BACKUP_DIR"

# Retain last 30 days
find /backups -maxdepth 1 -type d -mtime +30 -exec rm -rf {} +
```

### 16.5 Rollback Procedure

1. Stop current deployment: `docker compose -f docker-compose.prod.yml down`
2. Restore database: `gunzip < postgres.sql.gz | docker compose exec -T postgres psql -U dm dmtool`
3. Restore MinIO: `docker compose exec -T minio mc mirror /backup/minio/ /data/`
4. Redeploy previous version: `TAG=previous docker compose -f docker-compose.prod.yml up -d`

---

## 17. Observability

### 17.1 Structured Logging

All server logs use JSON format with correlation IDs:

```json
{
    "timestamp": "2026-03-16T14:30:00Z",
    "level": "INFO",
    "logger": "server.sessions",
    "message": "Player joined session",
    "session_id": "abc123",
    "user_id": "user-456",
    "event_id": "evt-789",
    "duration_ms": 45
}
```

### 17.2 Prometheus Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `ws_connected_clients` | Gauge | Current WebSocket connections |
| `ws_events_total` | Counter | Total events processed (by type) |
| `event_delivery_latency_ms` | Histogram | Time from emit to client ack |
| `asset_download_duration_ms` | Histogram | Asset download time |
| `asset_download_size_bytes` | Histogram | Asset download size |
| `sync_resync_count` | Counter | Delta/full resync requests |
| `auth_attempts_total` | Counter | Login attempts (by result) |
| `session_active_count` | Gauge | Currently active sessions |
| `http_request_duration_ms` | Histogram | REST API response time |

### 17.3 Alerting Rules

| Alert | Condition | Severity |
|-------|-----------|----------|
| High event latency | P95 > 200ms for 5 minutes | Warning |
| Critical event latency | P95 > 500ms for 2 minutes | Critical |
| Reconnect failure spike | Failure rate > 10% for 5 minutes | Warning |
| Unauthorized access | > 10 forbidden requests in 1 minute | Critical |
| Database connection pool | Available connections < 3 | Warning |
| Redis memory | Usage > 80% | Warning |
| Disk space | Available < 10% | Critical |

---

## 18. Versioning and Feature Flags

### 18.1 Semantic Versioning

- **Major:** Breaking API/event schema changes
- **Minor:** New features, backward-compatible
- **Patch:** Bug fixes

Current: `0.7.7` (Alpha)
Target: `1.0.0` (GA with online features)

### 18.2 Release Trains

| Stage | Audience | Criteria |
|-------|----------|----------|
| `alpha` | Internal team + limited testers | Feature complete for current sprint |
| `beta` | Invited DM groups | All quality gates passed |
| `ga` | General availability | 30-day beta with zero critical issues |

### 18.3 Feature Flags

| Flag | Default | Description |
|------|---------|-------------|
| `online_session_enabled` | false | Enable online session creation |
| `mindmap_sync_enabled` | false | Enable mind map push/sync |
| `audio_sync_enabled` | false | Enable audio synchronization |
| `dice_roller_shared` | false | Enable server-side shared dice |
| `voice_chat_enabled` | false | Enable WebRTC voice chat |
| `event_log_auto` | false | Enable automated combat event logging |

### 18.4 Backward Compatibility

- Event schema minor versions must be backward-readable
- Breaking changes require a dual-write/conversion period
- Clients must gracefully handle unknown event types (log and ignore)

---

## 19. Risk Register

### Risk 1: Phase 0 Skipped or Rushed

| Field | Value |
|-------|-------|
| Impact | High — all online features built on unstable UI foundation |
| Probability | Medium — pressure to ship online features quickly |
| Mitigation | Phase 0 exit criteria enforced; no Phase 1 work begins until met |

### Risk 2: Permission Model Gaps

| Field | Value |
|-------|-------|
| Impact | Critical — data leakage, trust loss |
| Probability | Medium — complex permission matrix |
| Mitigation | Scope-based auth guard on every endpoint/event; comprehensive security tests; audit logging |

### Risk 3: Audio Synchronization Drift

| Field | Value |
|-------|-------|
| Impact | Medium — degraded user experience |
| Probability | High — network latency varies |
| Mitigation | Server-time reference (`start_at`), jitter tolerance window, periodic re-alignment |

### Risk 4: Network State Drift

| Field | Value |
|-------|-------|
| Impact | Medium — inconsistent player screens |
| Probability | Medium — unreliable connections |
| Mitigation | Seq-based ordering, delta resync, full snapshot fallback |

### Risk 5: Single Server Bottleneck

| Field | Value |
|-------|-------|
| Impact | Medium — performance degradation under load |
| Probability | Low — initial target is 10-50 players |
| Mitigation | Redis PubSub for future horizontal scaling; performance benchmarks each sprint |

### Risk 6: Asset URL Sharing

| Field | Value |
|-------|-------|
| Impact | Medium — unauthorized content access |
| Probability | Low — URLs are short-lived |
| Mitigation | 60-second TTL, session-scoped, single-use token option |

---

## 20. Technical Debt and Refactoring Priorities

### Priority 1: EventManager Abstraction

**Current:** UI widgets call `DataManager` directly and rely on Qt signals for inter-widget communication.
**Target:** `EventManager` sits between UI/DataManager and network layer. Same interface works offline and online.
**Impact:** Required before any online feature.

### Priority 2: Centralized State Layer

**Current:** `DataManager.data` is a flat Python dict, accessed directly by all UI widgets.
**Target:** State mutations go through a controlled pipeline with event emission hooks.
**Impact:** Required for reliable state synchronization.

### Priority 3: Player Mode Code Isolation

**Current:** Single application binary with DM-only features.
**Target:** Modular packaging where Player mode excludes DM-only modules (session management, entity editing).
**Impact:** Reduces player client size and attack surface.

### Priority 4: Common Style System

**Current:** Each QSS theme file defines styles independently; inconsistent button sizes and spacing.
**Target:** Common style tokens (button sizes, padding, typography) applied across all themes.
**Impact:** Required for Phase 0 UI standardization.

---

## 21. Conclusion

The online transition is technically feasible and represents a high-impact product investment. The critical success factor is **phase transition discipline:**

1. **Phase 0 must complete** before online core begins
2. **Phase 1 delivers a simple but secure MVP** — authentication, sessions, basic sync
3. **Phase 2 and beyond** use feature flags and metrics for controlled, measurable rollout

This document serves as the reference specification for all implementation decisions. The companion document `SPRINT_MAP.md` provides the sprint-by-sprint execution plan with file-level implementation detail.

---

## Appendices

### Appendix A: File Map (Current → Target)

| Current File | Online Changes Required |
|-------------|----------------------|
| `core/data_manager.py` | Add event emission hooks to all state mutation methods |
| `core/event_manager.py` | **NEW** — EventManager abstraction (offline/online) |
| `core/socket_client.py` | **NEW** — python-socketio wrapper with reconnect |
| `core/audio/engine.py` | Add state serialization methods |
| `core/audio/models.py` | Add Pydantic equivalents for network transfer |
| `core/models.py` | Add Pydantic entity models for API transfer |
| `config.py` | Add server URL, auth token storage paths |
| `main.py` | Add DM/Player mode selection |
| `ui/main_root.py` | Support DM/Player mode UI, Session Control panel |
| `ui/campaign_selector.py` | Add online login/join flow |
| `ui/player_window.py` | Accept remote content via WebSocket |
| `ui/soundpad_panel.py` | Emit audio state change events |
| `ui/tabs/database_tab.py` | Shared/restricted entity views |
| `ui/tabs/mind_map_tab.py` | Push/receive node sync |
| `ui/tabs/map_tab.py` | Real-time pin/fog sync |
| `ui/tabs/session_tab.py` | Online session controls |
| `ui/widgets/combat_tracker.py` | Combat state broadcast |
| `ui/widgets/npc_sheet.py` | Restricted field rendering |
| `ui/widgets/mind_map_items.py` | Origin/visibility/sync_id fields |
| `ui/widgets/map_viewer.py` | Accept remote fog state |
| `ui/widgets/projection_manager.py` | Emit projection events |
| `ui/windows/battle_map_window.py` | Sync fog state with players |
| `server/` | **NEW** — Complete FastAPI backend |
| `docker-compose.yml` | **NEW** — Development environment |
| `docker-compose.prod.yml` | **NEW** — Production environment |
| `nginx/` | **NEW** — Nginx configuration |

### Appendix B: Full API Endpoint Table

| Method | Path | Auth | Scope | Description |
|--------|------|------|-------|-------------|
| POST | `/v1/auth/register` | None | — | Register new user |
| POST | `/v1/auth/login` | None | — | Authenticate |
| POST | `/v1/auth/refresh` | None | — | Refresh tokens |
| GET | `/v1/auth/me` | JWT | — | Get profile |
| POST | `/v1/sessions` | JWT | `session:manage` | Create session |
| GET | `/v1/sessions/{id}` | JWT | `session:join` | Get session |
| POST | `/v1/sessions/{id}/join` | JWT/Anon | — | Join session |
| POST | `/v1/sessions/{id}/close` | JWT | `session:manage` | Close session |
| GET | `/v1/sessions/{id}/state` | JWT | `session:join` | Full state snapshot |
| POST | `/v1/sessions/{id}/backup` | JWT | `session:manage` | Create backup |
| POST | `/v1/assets/presign` | JWT | `asset:upload` | Presigned upload URL |
| GET | `/v1/assets/{id}` | JWT | `asset:read:scoped` | Asset download URL |

### Appendix C: Full WebSocket Event Table

| Event | Direction | Trigger | Idempotency |
|-------|-----------|---------|-------------|
| SESSION_STATE | Server → All | State change | Full replace |
| PLAYER_JOINED | Server → All | Player joins | Upsert by user_id |
| PLAYER_LEFT | Server → All | Player leaves | Remove by user_id |
| SESSION_CLOSED | Server → All | DM closes | Mark closed |
| MAP_STATE_SYNC | DM → All | Map change | Full replace |
| PROJECTION_UPDATE | DM → All | Projection change | Full replace |
| FOG_OF_WAR_UPDATE | DM → All | Fog draw/erase | Sequential by seq |
| MINDMAP_PUSH | DM → Target | Share node | Upsert by node_id |
| MINDMAP_NODE_UPDATE | Any → All | Node edit | Last-write-wins |
| MINDMAP_LINK_SYNC | DM → All | Connection change | Set-based |
| MINDMAP_NODE_DELETE | DM → All | Node delete | Remove if exists |
| AUDIO_STATE | DM → All | Audio change | Full replace |
| AUDIO_CROSSFADE | DM → All | Crossfade trigger | Apply if not stale |
| AUDIO_AMBIENCE_UPDATE | DM → All | Ambience change | Full replace slot |
| AUDIO_SFX_TRIGGER | DM → All | SFX play | Fire-and-forget |
| DICE_ROLL_REQUEST | Any → Server | Roll dice | Server processes |
| DICE_ROLL_RESULT | Server → All | Roll complete | Dedup by request_id |
| EVENT_LOG_APPEND | Server → All | Log entry | Dedup by log_id |
| COMBAT_STATE_SYNC | DM → All | Combat change | Full replace |
| ENTITY_SHARE | DM → Target | Share entity | Upsert by entity_id |
| ENTITY_UPDATE_SHARED | DM → All | Update shared | Last-write-wins |
| CARD_VIEW_GRANT | DM → Player | Grant/revoke | Upsert by (entity,user) |

### Appendix D: PostgreSQL Full Schema

See [Section 9.1](#91-postgresql-schema) for complete DDL.

### Appendix E: Docker Compose Example

See [Section 16.1](#161-docker-compose-development) and [Section 16.2](#162-docker-compose-production).

### Appendix F: Glossary

| Term | Definition |
|------|-----------|
| DM | Dungeon Master — the game session host and referee |
| Player | A participant in a game session controlled by the DM |
| Session | An active online game instance with DM and players |
| Join Key | A 6-character alphanumeric code used to join a session |
| Entity | Any game object (NPC, Monster, Spell, Equipment, etc.) |
| Projection | Content displayed on the player's screen by the DM |
| Fog of War | A visibility mask overlay on battle maps |
| Mind Map | An infinite canvas for organizing campaign notes and entities |
| MusicBrain | The layered audio engine that manages themes, states, and intensity levels |
| Soundpad | The UI panel for controlling audio playback |
| EventManager | Abstraction layer between UI/data and network layer |
| Seq | Sequence number — monotonically increasing event counter per session |
