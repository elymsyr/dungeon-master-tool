# Dungeon Master Tool v2 — System Architecture

**Version:** 2.0.0 (Target)
**Date:** 2026-04-01
**Stack:** Tauri v2 + React + TypeScript + Python FastAPI
**Platforms:** Desktop (Windows/macOS/Linux) + Mobile (Android/iOS) + Web

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Technology Stack](#2-technology-stack)
3. [Monorepo Structure](#3-monorepo-structure)
4. [Backend Architecture (FastAPI)](#4-backend-architecture-fastapi)
5. [Frontend Architecture (React)](#5-frontend-architecture-react)
6. [Desktop Shell (Tauri v2)](#6-desktop-shell-tauri-v2)
7. [API Design](#7-api-design)
8. [WebSocket Protocol](#8-websocket-protocol)
9. [State Management](#9-state-management)
10. [Data Layer & Persistence](#10-data-layer--persistence)
11. [Theme System](#11-theme-system)
12. [Localization System](#12-localization-system)
13. [Audio System](#13-audio-system)
14. [Battle Map Engine](#14-battle-map-engine)
15. [Mind Map Engine](#15-mind-map-engine)
16. [Player Screen & Projection](#16-player-screen--projection)
17. [Authentication & Online Play (Future)](#17-authentication--online-play-future)
18. [Build & Deployment](#18-build--deployment)
19. [Security Considerations](#19-security-considerations)
20. [Performance Targets](#20-performance-targets)

---

## 1. Architecture Overview

### 1.1 High-Level Architecture

The Dungeon Master Tool v2 follows a **client-server architecture** where the backend serves a REST + WebSocket API and the frontend is a React single-page application. For desktop deployment, Tauri v2 wraps the frontend in a native window and launches the backend as a sidecar process.

```
┌──────────────────────────────────────────────────────────────┐
│                    TAURI v2 SHELL (Rust)                      │
│  ┌────────────────────┐    ┌──────────────────────────────┐  │
│  │   System WebView   │    │   FastAPI Sidecar Process    │  │
│  │   (React App)      │◄──►│   (Python Backend)           │  │
│  │                    │REST│                              │  │
│  │   localhost:5173   │ +  │   localhost:8765             │  │
│  │                    │ WS │                              │  │
│  └────────────────────┘    └──────────────────────────────┘  │
│         ▲                           ▲                        │
│         │ Tauri IPC                 │ File System             │
│         ▼                           ▼                        │
│  ┌─────────────┐            ┌─────────────────┐             │
│  │ Native APIs │            │ Campaign Files   │             │
│  │ (Dialogs,   │            │ (worlds/*.dat)   │             │
│  │  Tray, etc) │            │ (assets/*)       │             │
│  └─────────────┘            └─────────────────┘             │
└──────────────────────────────────────────────────────────────┘
```

### 1.2 Communication Patterns

| Pattern | Use Case | Protocol |
|---------|----------|----------|
| Request/Response | CRUD operations (entities, sessions, maps) | REST (HTTP JSON) |
| Server Push | Real-time updates (combat HP, fog of war, turn changes) | WebSocket |
| File Transfer | Image/PDF upload, audio streaming | REST multipart + streaming |
| Tauri IPC | Native file dialogs, system tray, window management | Tauri Commands (Rust ↔ JS) |

### 1.3 Deployment Modes

| Mode | Frontend | Backend | Use Case |
|------|----------|---------|----------|
| **Desktop (Tauri)** | Embedded WebView | Sidecar process | DM's primary workstation |
| **Web** | Browser | Remote server | Players accessing DM's game |
| **Mobile** | WebView (Capacitor/Tauri Mobile) | Remote server | Players on phones/tablets |
| **LAN** | Browser on any device | DM's desktop server | Local table play |

---

## 2. Technology Stack

### 2.1 Exact Versions

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| **Desktop Shell** | Tauri | v2.x | Native window, sidecar management, file dialogs |
| **Frontend Framework** | React | 18.x | Component-based UI |
| **Language** | TypeScript | 5.x | Type-safe frontend code |
| **Build Tool** | Vite | 6.x | Fast HMR, Tauri integration |
| **State Management** | Zustand | 5.x | Lightweight reactive stores |
| **API Client** | TanStack Query | 5.x | Caching, auto-refetch, optimistic updates |
| **Canvas** | Konva.js + react-konva | 9.x | Battle map, fog of war |
| **Node Editor** | React Flow | 12.x | Mind map nodes and edges |
| **Markdown** | TipTap | 2.x | Rich text editor with extensions |
| **Audio** | Howler.js | 2.x | Multi-track audio, crossfade |
| **DnD** | @dnd-kit/core | 6.x | Drag and drop |
| **CSS** | Tailwind CSS | 4.x | Utility-first styling |
| **Hotkeys** | react-hotkeys-hook | 4.x | Keyboard shortcuts |
| **PDF** | react-pdf | 9.x | PDF rendering (PDF.js) |
| **i18n** | react-i18next | 15.x | Internationalization |
| **Routing** | React Router | 7.x | Client-side routing |
| **Icons** | Lucide React | 0.4x | Consistent icon set |
| **Backend Framework** | FastAPI | 0.115.x | Async REST + WebSocket |
| **Python** | Python | 3.12+ | Backend runtime |
| **ASGI Server** | Uvicorn | 0.34.x | Production ASGI server |
| **Validation** | Pydantic | 2.x | Request/response validation |
| **WebSocket** | python-socketio | 5.x | Real-time events |
| **Serialization** | msgpack | 1.x | Campaign data persistence |
| **HTTP Client** | requests | 2.x | External API calls |
| **Testing (Frontend)** | Vitest | 2.x | Unit/component tests |
| **Testing (E2E)** | Playwright | 1.x | End-to-end tests |
| **Testing (Backend)** | pytest | 8.x | Backend tests |

### 2.2 Dependency Justification

**Why Tauri over Electron?**
- Binary size: ~5MB vs ~150MB
- RAM usage: ~20-40MB vs ~80-150MB
- Startup time: <0.5s vs 1-3s
- Tauri v2 supports Android/iOS (Tauri Mobile)

**Why Zustand over Redux?**
- Zero boilerplate (no actions, reducers, dispatch)
- 1KB bundle size vs 7KB
- Direct state mutation (Immer-like)
- Perfect for deeply nested D&D entity data

**Why Konva.js over Fabric.js?**
- Layered architecture matches QGraphicsScene z-ordering
- Better performance with many objects (token-heavy maps)
- React bindings (react-konva) are first-class
- Built-in hit detection and event system

**Why React Flow over Konva for Mind Map?**
- Nodes are DOM elements (real React components)
- Rich interactive content inside nodes (markdown editors, entity cards)
- Built-in zoom, pan, minimap, edge routing
- Undo/redo support

---

## 3. Monorepo Structure

```
dungeon-master-tool-v2/
│
├── package.json                    # Root workspace config
├── pnpm-workspace.yaml             # PNPM workspace definition
├── turbo.json                      # Turborepo build orchestration
│
├── apps/
│   ├── desktop/                    # Tauri desktop app
│   │   ├── src-tauri/
│   │   │   ├── Cargo.toml          # Rust dependencies
│   │   │   ├── tauri.conf.json     # Window config, sidecar, permissions
│   │   │   ├── capabilities/       # Tauri v2 capability files
│   │   │   └── src/
│   │   │       ├── main.rs         # Launch sidecar, configure windows
│   │   │       └── commands.rs     # Tauri IPC commands
│   │   ├── index.html              # Vite entry
│   │   ├── vite.config.ts
│   │   ├── tsconfig.json
│   │   └── package.json
│   │
│   ├── web/                        # Web-only build (no Tauri)
│   │   ├── vite.config.ts
│   │   └── package.json
│   │
│   └── mobile/                     # Capacitor mobile wrapper
│       ├── capacitor.config.ts
│       ├── android/                # Android project (generated)
│       ├── ios/                    # iOS project (generated)
│       └── package.json
│
├── packages/
│   ├── ui/                         # Shared React components
│   │   ├── src/
│   │   │   ├── features/           # Feature modules
│   │   │   │   ├── campaign/       # Campaign selector
│   │   │   │   ├── entities/       # Entity sidebar, NPC sheet
│   │   │   │   ├── session/        # Session tab, combat tracker
│   │   │   │   ├── battlemap/      # Battle map canvas
│   │   │   │   ├── mindmap/        # Mind map editor
│   │   │   │   ├── worldmap/       # World map with pins
│   │   │   │   ├── audio/          # Soundpad panel
│   │   │   │   └── player/         # Player screen view
│   │   │   ├── components/         # Shared components
│   │   │   │   ├── MarkdownEditor.tsx
│   │   │   │   ├── ImageViewer.tsx
│   │   │   │   ├── PdfViewer.tsx
│   │   │   │   ├── HpBar.tsx
│   │   │   │   ├── ConditionBadge.tsx
│   │   │   │   ├── EntitySelector.tsx
│   │   │   │   └── dialogs/
│   │   │   ├── hooks/              # Custom React hooks
│   │   │   │   ├── useWebSocket.ts
│   │   │   │   ├── useHotkeys.ts
│   │   │   │   ├── useTheme.ts
│   │   │   │   ├── useAutoSave.ts
│   │   │   │   └── useAudioEngine.ts
│   │   │   ├── store/              # Zustand stores
│   │   │   │   ├── campaignStore.ts
│   │   │   │   ├── entityStore.ts
│   │   │   │   ├── sessionStore.ts
│   │   │   │   ├── battleMapStore.ts
│   │   │   │   ├── mindMapStore.ts
│   │   │   │   ├── audioStore.ts
│   │   │   │   ├── playerStore.ts
│   │   │   │   └── uiStore.ts
│   │   │   ├── api/                # API client layer
│   │   │   │   ├── client.ts       # Axios/fetch wrapper
│   │   │   │   ├── queries.ts      # TanStack Query hooks
│   │   │   │   └── websocket.ts    # WebSocket connection manager
│   │   │   ├── themes/             # Theme definitions
│   │   │   │   ├── index.ts        # Theme provider
│   │   │   │   ├── tokens.ts       # Design tokens (from ThemeManager palettes)
│   │   │   │   └── dark.css        # Theme CSS (11 files)
│   │   │   ├── i18n/               # Localization
│   │   │   │   ├── index.ts
│   │   │   │   └── locales/        # Copied from current locales/
│   │   │   └── types/              # Shared TypeScript types
│   │   │       ├── entity.ts
│   │   │       ├── session.ts
│   │   │       ├── battlemap.ts
│   │   │       └── events.ts
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   └── shared/                     # Shared constants, types, utilities
│       ├── src/
│       │   ├── constants.ts        # Entity types, schema definitions
│       │   ├── events.ts           # Event type definitions (mirrors Pydantic models)
│       │   └── utils.ts
│       └── package.json
│
├── backend/                        # Python FastAPI backend
│   ├── pyproject.toml              # Python project config
│   ├── requirements.txt            # Python dependencies
│   ├── server.py                   # FastAPI app entry point
│   ├── routers/                    # API route handlers
│   │   ├── __init__.py
│   │   ├── campaigns.py
│   │   ├── entities.py
│   │   ├── sessions.py
│   │   ├── maps.py
│   │   ├── mindmaps.py
│   │   ├── library.py
│   │   ├── settings.py
│   │   ├── assets.py
│   │   └── audio.py
│   ├── ws/                         # WebSocket management
│   │   ├── __init__.py
│   │   ├── manager.py              # Connection manager, broadcasting
│   │   └── handlers.py             # Event-specific handlers
│   ├── services/                   # Business logic wrappers
│   │   ├── __init__.py
│   │   └── game_service.py         # Orchestrates DataManager
│   ├── core/                       # COPIED FROM CURRENT PROJECT (zero changes)
│   │   ├── data_manager.py
│   │   ├── entity_repository.py
│   │   ├── session_repository.py
│   │   ├── campaign_manager.py
│   │   ├── map_data_manager.py
│   │   ├── library_manager.py
│   │   ├── settings_manager.py
│   │   ├── event_bus.py
│   │   ├── models.py
│   │   ├── locales.py
│   │   ├── theme_manager.py
│   │   ├── library_fs.py
│   │   ├── log_config.py
│   │   ├── api/                    # D&D API sources
│   │   ├── audio/                  # Audio models + loader
│   │   └── network/                # Event schemas
│   ├── config.py                   # Adapted from current config.py
│   └── tests/                      # Backend tests
│       ├── test_campaigns.py
│       ├── test_entities.py
│       └── test_sessions.py
│
├── e2e/                            # End-to-end tests (Playwright)
│   ├── playwright.config.ts
│   └── tests/
│       ├── campaign.spec.ts
│       ├── entity.spec.ts
│       └── combat.spec.ts
│
└── docs/                           # Documentation
    ├── v2/
    │   ├── SYSTEM_ARCHITECTURE.md  # This document
    │   └── DEVELOPMENT_ROADMAP.md  # Sprint plan
    └── api/
        └── openapi.json            # Auto-generated from FastAPI
```

---

## 4. Backend Architecture (FastAPI)

### 4.1 Application Structure

```python
# backend/server.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from core.data_manager import DataManager
from core.event_bus import EventBus
from core.log_config import setup_logging
from ws.manager import WebSocketManager

app = FastAPI(title="Dungeon Master Tool API", version="2.0.0")

# CORS for development (Vite dev server on :5173)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# Singleton services
data_manager = DataManager()
event_bus = EventBus()
ws_manager = WebSocketManager(event_bus)
data_manager.set_event_bus(event_bus)

# Register routers
from routers import campaigns, entities, sessions, maps, mindmaps, library, settings, assets, audio
app.include_router(campaigns.router, prefix="/api/campaigns", tags=["campaigns"])
app.include_router(entities.router, prefix="/api/entities", tags=["entities"])
app.include_router(sessions.router, prefix="/api/sessions", tags=["sessions"])
app.include_router(maps.router, prefix="/api/maps", tags=["maps"])
app.include_router(mindmaps.router, prefix="/api/mindmaps", tags=["mindmaps"])
app.include_router(library.router, prefix="/api/library", tags=["library"])
app.include_router(settings.router, prefix="/api/settings", tags=["settings"])
app.include_router(assets.router, prefix="/api/assets", tags=["assets"])
app.include_router(audio.router, prefix="/api/audio", tags=["audio"])

# WebSocket endpoint
@app.websocket("/ws")
async def websocket_endpoint(websocket):
    await ws_manager.handle_connection(websocket)

# Serve frontend in production
# app.mount("/", StaticFiles(directory="../apps/desktop/dist", html=True))
```

### 4.2 Service Layer

The service layer is a thin wrapper around the existing `DataManager` and its sub-managers. No business logic is duplicated — it is all delegated to the existing Python core.

```python
# backend/services/game_service.py
class GameService:
    """Wraps DataManager for FastAPI route handlers."""
    
    def __init__(self, dm: DataManager, ws: WebSocketManager):
        self.dm = dm
        self.ws = ws
    
    async def save_entity(self, eid: str | None, data: dict) -> str:
        result_id = self.dm.save_entity(eid, data)
        await self.ws.broadcast("entity.updated", {"entity_id": result_id})
        return result_id
    
    async def advance_turn(self, session_id: str, combatant_id: str):
        # ... update session, broadcast to all clients including player window
        await self.ws.broadcast("session.turn_advanced", {
            "session_id": session_id,
            "new_active_combatant_id": combatant_id
        })
```

### 4.3 WebSocket Manager

```python
# backend/ws/manager.py
class WebSocketManager:
    """Manages WebSocket connections and broadcasts EventBus events."""
    
    def __init__(self, event_bus: EventBus):
        self._connections: list[WebSocket] = []
        self._event_bus = event_bus
        # Subscribe to all events and forward to WebSocket clients
        for event_type in EVENT_PAYLOAD_MODELS:
            event_bus.subscribe(event_type, lambda **kw, et=event_type: self._queue_broadcast(et, kw))
    
    async def handle_connection(self, websocket: WebSocket):
        await websocket.accept()
        self._connections.append(websocket)
        try:
            while True:
                data = await websocket.receive_json()
                await self._handle_client_message(websocket, data)
        except WebSocketDisconnect:
            self._connections.remove(websocket)
    
    async def broadcast(self, event_type: str, payload: dict):
        message = {"event_type": event_type, "payload": payload}
        for conn in self._connections:
            await conn.send_json(message)
```

### 4.4 Existing Core Integration

The entire `core/` directory from the current project is copied into `backend/core/` **without modification**. The only file that needs adaptation is `config.py` to resolve paths relative to the backend directory instead of the PyQt6 app directory.

**Files copied verbatim (zero changes):**
- `core/data_manager.py` (339 LOC)
- `core/entity_repository.py` (143 LOC)
- `core/session_repository.py` (83 LOC)
- `core/campaign_manager.py` (218 LOC)
- `core/map_data_manager.py` (~180 LOC)
- `core/library_manager.py` (~250 LOC)
- `core/settings_manager.py` (47 LOC)
- `core/event_bus.py` (55 LOC)
- `core/models.py` (~200 LOC)
- `core/locales.py` (~30 LOC)
- `core/theme_manager.py` (333 LOC)
- `core/library_fs.py` (~150 LOC)
- `core/log_config.py` (~40 LOC)
- `core/api/*.py` (7 files)
- `core/audio/loader.py`, `core/audio/models.py`
- `core/network/events.py` (Pydantic event schemas)

**File adapted:**
- `config.py` — Path resolution updated for server context

**File NOT copied (PyQt6 dependency):**
- `core/audio/engine.py` — Uses QMediaPlayer. Audio playback moves to frontend.

---

## 5. Frontend Architecture (React)

### 5.1 Component Hierarchy

```
<App>
  <ThemeProvider>
    <WebSocketProvider>
      <Router>
        <Route path="/" element={<CampaignSelector />} />
        <Route path="/app" element={<MainLayout />}>
          <Toolbar />
          <Sidebar> <EntitySidebar /> </Sidebar>
          <TabPanel>
            <DatabaseTab />    // NPC Sheet editor (dual-panel)
            <MindMapTab />     // React Flow canvas
            <MapTab />         // World map with pins
            <SessionTab />     // Notes + Combat tracker
          </TabPanel>
          <RightPanel>         // Collapsible
            <SoundpadPanel />  // OR
            <PdfPanel />       // Mutually exclusive
          </RightPanel>
        </Route>
        <Route path="/player" element={<PlayerView />} />
      </Router>
    </WebSocketProvider>
  </ThemeProvider>
</App>
```

### 5.2 Feature Modules

Each feature is self-contained with its own components, hooks, and types:

```
features/entities/
├── EntitySidebar.tsx         # Left sidebar with search/filter
├── NpcSheet.tsx              # Main entity editor
├── NpcSheetStatsTab.tsx      # Ability scores, combat stats
├── NpcSheetActionsTab.tsx    # Traits, actions, reactions, legendary
├── NpcSheetSpellsTab.tsx     # Linked spells + manual add
├── NpcSheetInventoryTab.tsx  # Equipment links + custom items
├── NpcSheetDocsTab.tsx       # PDFs with project button
├── ImageGallery.tsx          # Multi-image gallery with navigation
├── LinkedEntityWidget.tsx    # Linked entity list (spells/items)
└── ManualSpellDialog.tsx     # Manual spell creation modal
```

### 5.3 TypeScript Type Definitions

```typescript
// packages/ui/src/types/entity.ts
export interface Entity {
  name: string;
  type: EntityType;
  source: string;
  description: string;
  images: string[];
  image_path: string;
  battlemaps: string[];
  tags: string[];
  attributes: Record<string, string>;
  stats: AbilityScores;
  combat_stats: CombatStats;
  traits: FeatureItem[];
  actions: FeatureItem[];
  reactions: FeatureItem[];
  legendary_actions: FeatureItem[];
  spells: string[];           // Entity IDs
  custom_spells: CustomSpell[];
  equipment_ids: string[];    // Entity IDs
  inventory: InventoryItem[];
  pdfs: string[];
  location_id: string | null;
  dm_notes: string;
  saving_throws: string;
  damage_vulnerabilities: string;
  damage_resistances: string;
  damage_immunities: string;
  condition_immunities: string;
  proficiency_bonus: string;
  passive_perception: string;
  skills: string;
}

export type EntityType =
  | "NPC" | "Monster" | "Spell" | "Equipment" | "Class" | "Race"
  | "Location" | "Player" | "Quest" | "Lore" | "Status Effect"
  | "Feat" | "Background" | "Plane" | "Condition";

export interface AbilityScores {
  STR: number; DEX: number; CON: number;
  INT: number; WIS: number; CHA: number;
}

export interface CombatStats {
  hp: string; max_hp: string; ac: string; speed: string;
  cr: string; xp: string; initiative: string;
}

export interface FeatureItem {
  name: string;
  desc: string;
}

export interface CustomSpell {
  name: string;
  desc: string;
  attributes: Record<string, string>;
}

// packages/ui/src/types/session.ts
export interface Session {
  id: string;
  name: string;
  date: string;
  notes: string;
  logs: string;
  combatants: Combatant[];
}

export interface Combatant {
  id: string;
  name: string;
  entity_id: string | null;
  initiative: number;
  hp: number;
  max_hp: number;
  ac: number;
  status_effects: ConditionEntry[];
}

export interface ConditionEntry {
  name: string;
  icon: string | null;
  duration: number;
  max_duration: number;
}

// packages/ui/src/types/battlemap.ts
export interface BattleMapState {
  map_image: string;
  tokens: BattleToken[];
  fog_data: string;          // base64 PNG
  annotation_data: string;   // base64 PNG
  grid_size: number;
  grid_visible: boolean;
  grid_snap: boolean;
  feet_per_cell: number;
  token_size: number;
}

export interface BattleToken {
  id: string;
  entity_id: string | null;
  x: number;
  y: number;
  size_override: number | null;
  attitude: "player" | "hostile" | "friendly" | "neutral";
}

// packages/ui/src/types/mindmap.ts
export interface MindMapData {
  nodes: MindMapNode[];
  connections: MindMapEdge[];
  workspaces: MindMapWorkspace[];
  viewport: { x: number; y: number; zoom: number };
}

export interface MindMapNode {
  id: string;
  type: "note" | "entity" | "image";
  x: number;
  y: number;
  w: number;
  h: number;
  content: string;
  extra: Record<string, any>;
}

export interface MindMapEdge {
  from: string;
  to: string;
}

export interface MindMapWorkspace {
  id: string;
  name: string;
  x: number; y: number;
  w: number; h: number;
  color: string;
}
```

---

## 6. Desktop Shell (Tauri v2)

### 6.1 Tauri Configuration

```json
// apps/desktop/src-tauri/tauri.conf.json
{
  "productName": "Dungeon Master Tool",
  "version": "2.0.0",
  "identifier": "com.elymsyr.dungeon-master-tool",
  "build": {
    "frontendDist": "../dist"
  },
  "app": {
    "windows": [
      {
        "title": "Dungeon Master Tool",
        "width": 1400,
        "height": 900,
        "minWidth": 800,
        "minHeight": 600,
        "resizable": true
      }
    ]
  },
  "bundle": {
    "active": true,
    "targets": ["msi", "dmg", "appimage", "deb"],
    "externalBin": ["backend/dungeon-master-tool-api"],
    "resources": ["../../backend/core/", "../../locales/", "../../assets/"]
  },
  "plugins": {
    "dialog": { "all": true },
    "fs": { "scope": ["$APPDATA/**", "$HOME/**"] },
    "shell": { "open": true }
  }
}
```

### 6.2 Sidecar Launch

```rust
// apps/desktop/src-tauri/src/main.rs
use tauri::Manager;

fn main() {
    tauri::Builder::default()
        .setup(|app| {
            // Launch FastAPI sidecar
            let sidecar = app.shell()
                .sidecar("dungeon-master-tool-api")
                .expect("failed to find sidecar")
                .args(["--port", "8765"])
                .spawn()
                .expect("failed to start sidecar");
            
            // Store sidecar handle for cleanup
            app.manage(sidecar);
            
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            open_player_window,
            get_platform_info,
        ])
        .run(tauri::generate_context!())
        .expect("error while running application");
}

#[tauri::command]
async fn open_player_window(app: tauri::AppHandle) -> Result<(), String> {
    tauri::WebviewWindowBuilder::new(
        &app,
        "player",
        tauri::WebviewUrl::App("/player".into()),
    )
    .title("Player View")
    .build()
    .map_err(|e| e.to_string())?;
    Ok(())
}
```

### 6.3 Multi-Window Architecture

| Window | Purpose | Size | Content |
|--------|---------|------|---------|
| Main | DM workspace | 1400×900 | Full app (sidebar, tabs, panels) |
| Player | Player projection | 800×600 | Read-only content (images, battle map, PDF) |

The player window connects to the same FastAPI backend via WebSocket and receives projection commands from the DM window. On desktop, Tauri creates a second native window. On web, `window.open()` opens a new browser tab.

---

## 7. API Design

### 7.1 REST Endpoints

Full API specification with request/response schemas:

#### Campaigns
```
GET    /api/campaigns                          → CampaignListResponse
POST   /api/campaigns                          → CampaignCreateResponse
       Body: { "world_name": string }
POST   /api/campaigns/{name}/load              → CampaignLoadResponse
GET    /api/campaigns/current                  → CampaignCurrentResponse
```

#### Entities
```
GET    /api/entities                           → EntityListResponse
       Query: ?type=NPC&search=dragon&page=1
GET    /api/entities/{id}                      → Entity
POST   /api/entities                           → EntityCreateResponse
       Body: Entity (partial)
PUT    /api/entities/{id}                      → EntityUpdateResponse
       Body: Entity (partial)
DELETE /api/entities/{id}                      → 204 No Content
GET    /api/entities/mentions                  → EntityMentionListResponse
POST   /api/entities/import                    → EntityImportResponse
       Body: { "data": object, "type_override": string? }
POST   /api/entities/fetch                     → EntityFetchResponse
       Body: { "category": string, "query": string }
```

#### Sessions
```
GET    /api/sessions                           → SessionListResponse
GET    /api/sessions/{id}                      → Session
POST   /api/sessions                           → SessionCreateResponse
       Body: { "name": string }
PUT    /api/sessions/{id}                      → SessionUpdateResponse
       Body: { "notes": string, "logs": string, "combatants": Combatant[] }
PUT    /api/sessions/{id}/activate             → 200 OK
GET    /api/sessions/active                    → { "session_id": string | null }
```

#### Maps
```
GET    /api/maps                               → MapData
PUT    /api/maps/image                         → 200 OK
       Body: { "image_path": string }
POST   /api/maps/pins                          → PinCreateResponse
PUT    /api/maps/pins/{id}                     → 200 OK
PUT    /api/maps/pins/{id}/move                → 200 OK
       Body: { "x": number, "y": number }
DELETE /api/maps/pins/{id}                     → 204 No Content
POST   /api/maps/timeline                      → TimelinePinCreateResponse
PUT    /api/maps/timeline/{id}                 → 200 OK
DELETE /api/maps/timeline/{id}                 → 204 No Content
```

#### Mind Maps
```
GET    /api/mindmaps                           → MindMapListResponse
GET    /api/mindmaps/{id}                      → MindMapData
PUT    /api/mindmaps/{id}                      → 200 OK
       Body: MindMapData
```

#### Library
```
GET    /api/library/index/{category}           → LibraryIndexResponse
       Query: ?page=1&search=fireball
GET    /api/library/details/{category}/{name}  → Entity (parsed from API)
GET    /api/library/search                     → LibrarySearchResponse
       Query: ?q=dragon&source=dnd5e
POST   /api/library/refresh                    → 200 OK
```

#### Settings
```
GET    /api/settings                           → Settings
PUT    /api/settings                           → 200 OK
       Body: Settings (partial)
```

#### Assets
```
POST   /api/assets/images                      → AssetUploadResponse
       Body: multipart/form-data (file)
POST   /api/assets/pdfs                        → AssetUploadResponse
       Body: multipart/form-data (file)
GET    /api/assets/{path:path}                 → File (binary stream)
```

#### Audio
```
GET    /api/audio/library                      → AudioLibrary
GET    /api/audio/themes                       → AudioThemeList
GET    /api/audio/file/{path:path}             → Audio stream
```

---

## 8. WebSocket Protocol

### 8.1 Connection

```
WS /ws?client_type=dm|player&session_id=xxx
```

### 8.2 Message Format

All messages follow the `EventEnvelope` schema from `core/network/events.py`:

```typescript
interface WebSocketMessage {
  event_id: string;       // UUID
  event_type: string;     // "entity.updated", "session.turn_advanced", etc.
  session_id?: string;
  campaign_id?: string;
  emitted_at: string;     // ISO 8601
  payload: Record<string, any>;
}
```

### 8.3 Event Types (24 total)

| Event | Direction | Payload | Use Case |
|-------|-----------|---------|----------|
| `campaign.loaded` | Server→Client | `{campaign_path, world_name}` | Campaign loaded |
| `campaign.saved` | Server→Client | `{campaign_path}` | Data persisted |
| `entity.created` | Server→All | `{entity_id, entity_type, name}` | New entity |
| `entity.updated` | Server→All | `{entity_id, changed_fields}` | Entity modified |
| `entity.deleted` | Server→All | `{entity_id, entity_type}` | Entity removed |
| `session.created` | Server→All | `{session_id, session_name}` | New session |
| `session.activated` | Server→All | `{session_id}` | Session switched |
| `session.combatant_added` | Server→All | `{session_id, combatant_id, name}` | Combat entry |
| `session.combatant_updated` | Server→All | `{session_id, combatant_id, changes}` | HP/condition change |
| `session.turn_advanced` | Server→All | `{session_id, new_active_combatant_id}` | Next turn |
| `map.image_set` | Server→All | `{image_path}` | Map background changed |
| `map.fog_updated` | Server→All | `{fog_data}` | Fog reveal/hide |
| `map.pin_added` | Server→All | `{pin_id, x, y, label}` | New map pin |
| `map.pin_removed` | Server→All | `{pin_id}` | Pin deleted |
| `mindmap.node_created` | Server→All | `{map_id, node_id, label, x, y}` | New node |
| `mindmap.node_updated` | Server→All | `{map_id, node_id, changes}` | Node modified |
| `mindmap.node_deleted` | Server→All | `{map_id, node_id}` | Node removed |
| `mindmap.edge_created` | Server→All | `{map_id, edge_id, source_id, target_id}` | New connection |
| `mindmap.edge_deleted` | Server→All | `{map_id, edge_id}` | Connection removed |
| `projection.content_set` | DM→Player | `{content_type, content_ref}` | Change player view |
| `projection.mode_changed` | DM→Player | `{mode}` | Switch projection mode |
| `audio.state_changed` | Server→All | `{theme, intensity, master_volume}` | Audio state sync |
| `audio.track_triggered` | Server→All | `{track_id, track_name}` | SFX played |
| `theme.changed` | Server→All | `{theme_name}` | Theme switched |

---

## 9. State Management

### 9.1 Zustand Store Architecture

```typescript
// packages/ui/src/store/entityStore.ts
import { create } from 'zustand';

interface EntityStore {
  entities: Record<string, Entity>;
  selectedId: string | null;
  filter: { search: string; types: EntityType[] };

  // Actions
  setEntities: (entities: Record<string, Entity>) => void;
  updateEntity: (id: string, data: Partial<Entity>) => void;
  removeEntity: (id: string) => void;
  selectEntity: (id: string | null) => void;
  setFilter: (filter: Partial<EntityStore['filter']>) => void;
}

export const useEntityStore = create<EntityStore>((set) => ({
  entities: {},
  selectedId: null,
  filter: { search: '', types: [] },
  
  setEntities: (entities) => set({ entities }),
  updateEntity: (id, data) => set((state) => ({
    entities: { ...state.entities, [id]: { ...state.entities[id], ...data } }
  })),
  removeEntity: (id) => set((state) => {
    const { [id]: _, ...rest } = state.entities;
    return { entities: rest };
  }),
  selectEntity: (id) => set({ selectedId: id }),
  setFilter: (filter) => set((state) => ({
    filter: { ...state.filter, ...filter }
  })),
}));
```

### 9.2 WebSocket → Store Sync

```typescript
// packages/ui/src/api/websocket.ts
export function setupWebSocketSync(socket: WebSocket) {
  socket.onmessage = (event) => {
    const { event_type, payload } = JSON.parse(event.data);
    
    switch (event_type) {
      case 'entity.updated':
        useEntityStore.getState().updateEntity(payload.entity_id, payload);
        break;
      case 'entity.deleted':
        useEntityStore.getState().removeEntity(payload.entity_id);
        break;
      case 'session.turn_advanced':
        useSessionStore.getState().setActiveTurn(payload.new_active_combatant_id);
        break;
      case 'projection.content_set':
        usePlayerStore.getState().setContent(payload.content_type, payload.content_ref);
        break;
      // ... all 24 event types
    }
  };
}
```

---

## 10. Data Layer & Persistence

### 10.1 Current Format (Preserved)

Campaign data is stored as **MsgPack binary** files. This format is retained for backward compatibility with v1 campaigns.

```
worlds/{campaign_name}/
├── data.dat              # MsgPack binary (main data file)
├── data.json             # JSON (legacy, auto-migrated to .dat)
└── assets/
    ├── {uuid}_image.png  # Imported images
    ├── {uuid}_doc.pdf    # Imported PDFs
    └── soundpad/         # Audio library
        ├── soundpad_library.yaml
        └── {theme_name}/
            ├── theme.yaml
            └── *.mp3, *.ogg, *.wav
```

### 10.2 Future: Database Migration Path (Online Play)

When online play is implemented, the data layer can be migrated to SQLite (single-player) or PostgreSQL (multi-player server):

```sql
-- Future schema (not implemented in v2.0)
CREATE TABLE campaigns (
  id UUID PRIMARY KEY,
  world_name TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE entities (
  id UUID PRIMARY KEY,
  campaign_id UUID REFERENCES campaigns(id),
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  data JSONB NOT NULL,  -- Full entity dict
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE sessions (
  id UUID PRIMARY KEY,
  campaign_id UUID REFERENCES campaigns(id),
  name TEXT NOT NULL,
  notes TEXT DEFAULT '',
  logs TEXT DEFAULT '',
  combatants JSONB DEFAULT '[]',
  created_at TIMESTAMP DEFAULT NOW()
);
```

The `DataManager` facade abstracts the storage backend, so switching from MsgPack files to SQLite/PostgreSQL only requires implementing new repository backends — no frontend changes needed.

---

## 11. Theme System

### 11.1 CSS Custom Properties

Each theme is defined as a set of CSS custom properties (variables), generated from the current `ThemeManager.PALETTES`:

```css
/* packages/ui/src/themes/dark.css */
:root[data-theme="dark"] {
  /* Surface colors */
  --bg-primary: #2b2b2b;
  --bg-secondary: #1e1e1e;
  --bg-card: #1e1e1e;
  --bg-input: #1e1e1e;
  
  /* Text colors */
  --text-primary: #e0e0e0;
  --text-secondary: #aaaaaa;
  --text-accent: #42a5f5;
  
  /* Border colors */
  --border-primary: #444444;
  --border-accent: #42a5f5;
  
  /* Button colors */
  --btn-default-bg: #3c3f41;
  --btn-primary-bg: #1565c0;
  --btn-success-bg: #2e7d32;
  --btn-danger-bg: #c62828;
  --btn-action-bg: #f9a825;
  
  /* Combat colors */
  --hp-high: #2e7d32;
  --hp-med: #fbc02d;
  --hp-low: #c62828;
  --token-player: #4caf50;
  --token-hostile: #ef5350;
  --token-friendly: #42a5f5;
  --token-neutral: #bdbdbd;
  
  /* Canvas colors */
  --canvas-bg: #181818;
  --grid-color: #2b2b2b;
  --node-bg-note: #fff9c4;
  --node-bg-entity: #2b2b2b;
  
  /* ... 50+ more variables per theme */
}
```

### 11.2 Theme Provider

```typescript
// packages/ui/src/themes/index.ts
export const THEMES = [
  'dark', 'light', 'baldur', 'discord', 'grim', 'midnight',
  'emerald', 'parchment', 'ocean', 'frost', 'amethyst'
] as const;

export type ThemeName = typeof THEMES[number];

export function applyTheme(theme: ThemeName) {
  document.documentElement.setAttribute('data-theme', theme);
}
```

### 11.3 Tailwind Integration

```typescript
// tailwind.config.ts
export default {
  theme: {
    extend: {
      colors: {
        primary: 'var(--bg-primary)',
        secondary: 'var(--bg-secondary)',
        card: 'var(--bg-card)',
        accent: 'var(--text-accent)',
        // ... maps CSS variables to Tailwind utilities
      }
    }
  }
};
```

Usage in components:
```tsx
<div className="bg-primary text-primary border border-primary">
  <button className="bg-btn-success-bg text-white">Add</button>
</div>
```

---

## 12. Localization System

### 12.1 react-i18next Setup

The existing YAML locale files (`en.yml`, `tr.yml`, `de.yml`, `fr.yml`) are converted to JSON and loaded by react-i18next:

```typescript
// packages/ui/src/i18n/index.ts
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

import en from './locales/en.json';
import tr from './locales/tr.json';
import de from './locales/de.json';
import fr from './locales/fr.json';

i18n.use(initReactI18next).init({
  resources: { en: { translation: en }, tr: { translation: tr }, de: { translation: de }, fr: { translation: fr } },
  lng: 'en',
  fallbackLng: 'en',
  interpolation: { escapeValue: false },
});
```

### 12.2 Locale Key Convention

All existing keys (e.g., `BTN_ADD`, `LBL_NAME`, `TAB_SESSION`) are preserved. The frontend uses the same keys:

```tsx
import { useTranslation } from 'react-i18next';

function AddButton() {
  const { t } = useTranslation();
  return <button>{t('BTN_ADD')}</button>;
}
```

---

## 13. Audio System

### 13.1 Howler.js Engine

The audio engine replicates the current `MusicBrain` dual-deck architecture:

```typescript
// packages/ui/src/hooks/useAudioEngine.ts

interface AudioEngine {
  // Music (dual-deck crossfade)
  loadTheme(theme: AudioTheme): void;
  transitionToState(stateName: string): void;
  setIntensity(level: number): void;
  
  // Ambience (4 parallel slots)
  playAmbience(slot: number, trackId: string, volume: number): void;
  stopAmbience(slot?: number): void;
  
  // SFX
  playSfx(sfxId: string): void;
  
  // Master
  setMasterVolume(volume: number): void;
  stopAll(): void;
}
```

### 13.2 Crossfade Implementation

```typescript
function transitionToState(stateName: string) {
  const newState = currentTheme.states[stateName];
  const newHowl = new Howl({ src: [trackUrl], loop: true, volume: 0 });
  
  newHowl.play();
  activeHowl.fade(masterVolume, 0, 3000);  // 3s fade out
  newHowl.fade(0, masterVolume, 3000);     // 3s fade in
  
  setTimeout(() => { activeHowl.unload(); }, 3500);
  activeHowl = newHowl;
}
```

### 13.3 Audio File Serving

Audio files are served by the backend:
```
GET /api/audio/file/forest/combat/base.mp3 → streams file from assets/soundpad/
```

---

## 14. Battle Map Engine

### 14.1 Konva.js Layer Architecture

```tsx
<Stage width={viewportWidth} height={viewportHeight}>
  <Layer name="background">
    <Image image={mapImage} />                    {/* z: -100 */}
  </Layer>
  <Layer name="grid">
    <GridOverlay cellSize={gridSize} visible={gridVisible} />  {/* z: 50 */}
  </Layer>
  <Layer name="annotations">
    <Image image={annotationCanvas} />            {/* z: 100 */}
  </Layer>
  <Layer name="tokens">
    {tokens.map(t => <TokenCircle key={t.id} {...t} />)}  {/* z: 100-150 */}
  </Layer>
  <Layer name="fog">
    <Image image={fogCanvas} />                   {/* z: 200 */}
  </Layer>
  <Layer name="measurements">
    <MeasurementOverlay />                        {/* z: 150 */}
  </Layer>
</Stage>
```

### 14.2 Fog of War (Offscreen Canvas Compositing)

```typescript
// Reveal area (CompositionMode_Clear equivalent)
fogCtx.globalCompositeOperation = 'destination-out';
fogCtx.beginPath();
points.forEach((p, i) => i === 0 ? fogCtx.moveTo(p.x, p.y) : fogCtx.lineTo(p.x, p.y));
fogCtx.fill();

// Add fog (CompositionMode_SourceOver equivalent)
fogCtx.globalCompositeOperation = 'source-over';
fogCtx.fillStyle = 'rgba(0, 0, 0, 1)';
fogCtx.beginPath();
// ... polygon points
fogCtx.fill();

// Serialize
const fogBase64 = fogCanvas.toDataURL('image/png');
```

### 14.3 Tools

| Tool | Current | Web Implementation |
|------|---------|-------------------|
| Navigate | Pan/zoom via mouse | Konva Stage draggable + wheel zoom |
| Ruler | Line + distance label | Konva Line + Text, calculated from grid |
| Circle | Circle + radius label | Konva Circle + Text |
| Draw | Freehand brush strokes | Offscreen canvas with lineTo |
| Fog Add | Polygon → black paint | Offscreen canvas, source-over |
| Fog Erase | Polygon → clear paint | Offscreen canvas, destination-out |

---

## 15. Mind Map Engine

### 15.1 React Flow Architecture

```tsx
<ReactFlow
  nodes={nodes}
  edges={edges}
  nodeTypes={nodeTypes}
  edgeTypes={edgeTypes}
  onNodesChange={onNodesChange}
  onEdgesChange={onEdgesChange}
  onConnect={onConnect}
  fitView
  minZoom={0.1}
  maxZoom={2}
>
  <Controls />
  <MiniMap />
  <Background variant="dots" />
</ReactFlow>
```

### 15.2 Custom Node Types

```typescript
const nodeTypes = {
  note: NoteNode,       // TipTap markdown editor
  entity: EntityNode,   // Entity summary card
  image: ImageNode,     // Aspect-ratio image
  workspace: WorkspaceNode, // Dashed border container (group)
};
```

### 15.3 Undo/Redo

Snapshot-based history with Zustand middleware:

```typescript
const useMindMapStore = create<MindMapStore>()(
  temporal(
    (set) => ({
      nodes: [],
      edges: [],
      // ... actions
    }),
    { limit: 50 }
  )
);
```

---

## 16. Player Screen & Projection

### 16.1 Content Modes

| Mode | Content | DM Control |
|------|---------|------------|
| `image` | Single or multi-image view | Select images from gallery |
| `battlemap` | Read-only battle map (tokens + fog) | Real-time via WebSocket |
| `blank` | Black screen | One-click toggle |
| `statblock` | HTML stat block | Select entity |
| `pdf` | PDF viewer | Select from docs tab |

### 16.2 WebSocket Projection Protocol

```typescript
// DM sends
ws.send({ event_type: "projection.content_set", payload: { content_type: "battlemap" } });

// Player receives and renders
const PlayerView = () => {
  const { mode, data } = usePlayerStore();
  switch (mode) {
    case 'image': return <ImageViewer images={data.images} />;
    case 'battlemap': return <BattleMapViewer state={data.battlemap} />;
    case 'blank': return <div className="bg-black w-full h-full" />;
    case 'statblock': return <StatBlock html={data.html} />;
    case 'pdf': return <PdfViewer url={data.url} />;
  }
};
```

### 16.3 Mobile Player View

Mobile clients render only the player view — no DM controls. The UI is touch-optimized with larger buttons and swipe gestures. Mobile connects to the DM's desktop backend via LAN or internet URL.

---

## 17. Authentication & Online Play (Future)

### 17.1 Local Mode (v2.0 — No Auth)

In local/LAN mode, the backend serves all requests without authentication. This is the default for desktop deployment.

### 17.2 Online Mode (Future Sprint)

When deployed as a web server for remote play:

```
POST /api/auth/register    → Create account
POST /api/auth/login       → Get JWT token
GET  /api/auth/me          → Get current user

# All other endpoints require Authorization: Bearer <token>
# WebSocket connections require token in query: /ws?token=xxx

# Roles:
# - dm: Full access (CRUD, projection, combat control)
# - player: Read-only + own character sheet editing
```

### 17.3 Session Sharing

```
POST /api/campaigns/{id}/invite  → Generate invite link
GET  /api/join/{invite_code}     → Join campaign as player
```

---

## 18. Build & Deployment

### 18.1 Desktop Build Pipeline

```bash
# 1. Build React frontend
cd apps/desktop && pnpm build

# 2. Build FastAPI sidecar (PyInstaller)
cd backend && pyinstaller --onefile server.py -n dungeon-master-tool-api

# 3. Build Tauri desktop app
cd apps/desktop && pnpm tauri build
# Output: target/release/bundle/
#   - Windows: .msi installer
#   - macOS: .dmg
#   - Linux: .AppImage, .deb
```

### 18.2 Mobile Build

```bash
# Android (Capacitor)
cd apps/mobile
npx cap add android
npx cap sync
npx cap open android  # Opens Android Studio

# iOS (Capacitor)
npx cap add ios
npx cap sync
npx cap open ios  # Opens Xcode
```

### 18.3 Web Deployment

```bash
# Build static SPA
cd apps/web && pnpm build

# Deploy with FastAPI serving static files
cd backend && uvicorn server:app --host 0.0.0.0 --port 8765
```

---

## 19. Security Considerations

| Concern | Mitigation |
|---------|-----------|
| **CORS** | Restrict origins in production (no `*` wildcard) |
| **File access** | Tauri's fs plugin scoped to app data directory |
| **SQL injection** | No SQL (MsgPack files); future DB uses ORM (SQLAlchemy) |
| **XSS** | React auto-escapes; TipTap sanitizes markdown HTML |
| **WebSocket spoofing** | Token-based auth in online mode |
| **Path traversal** | `get_full_path()` validates paths against campaign root |
| **Sidecar** | FastAPI binds to localhost only (no external access in desktop mode) |

---

## 20. Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| **App startup** | <2s | Tauri shell + sidecar launch |
| **Page navigation** | <100ms | Client-side routing, no full reload |
| **Entity CRUD** | <200ms | REST round-trip + MsgPack save |
| **Battle map render** | 60fps | Konva.js canvas with layer caching |
| **Fog of war update** | <50ms | Offscreen canvas compositing |
| **Mind map (100 nodes)** | 30fps+ | React Flow with virtualization |
| **Audio crossfade** | Seamless | Howler.js dual-deck, 3s InOutCubic |
| **WebSocket latency** | <50ms | Local network, JSON serialization |
| **Desktop binary size** | <60MB | Tauri ~5MB + sidecar ~50MB |
| **Mobile app size** | <10MB | WebView-only (no sidecar) |
