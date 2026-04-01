# Dungeon Master Tool v2 — Development Roadmap

**Version:** 2.0.0 (Target)
**Date:** 2026-04-01
**Stack:** Tauri v2 + React + TypeScript + Python FastAPI
**Estimated Duration:** 18-22 weeks (solo developer)

---

## Table of Contents

1. [Phase 0: Environment Setup & Project Initialization](#phase-0-environment-setup--project-initialization)
2. [Phase 1: Backend API Foundation](#phase-1-backend-api-foundation)
3. [Phase 2: Core UI — Campaign, Sidebar, Entity Editor](#phase-2-core-ui--campaign-sidebar-entity-editor)
4. [Phase 3: Session, Combat Tracker & Timeline](#phase-3-session-combat-tracker--timeline)
5. [Phase 4: Battle Map Engine](#phase-4-battle-map-engine)
6. [Phase 5: Mind Map Engine](#phase-5-mind-map-engine)
7. [Phase 6: Audio, Player Screen & PDF](#phase-6-audio-player-screen--pdf)
8. [Phase 7: Polish, Testing & Mobile](#phase-7-polish-testing--mobile)
9. [Phase 8: Online Play Foundation (Future)](#phase-8-online-play-foundation-future)
10. [Dependency Graph](#dependency-graph)
11. [Risk Register](#risk-register)

---

## Phase 0: Environment Setup & Project Initialization

**Duration:** 5-7 days
**Goal:** Working "Hello World" with Tauri + React + FastAPI all connected

### Sprint 0.1: Install Development Tools (Day 1)

#### System Prerequisites

**macOS:**
```bash
# Xcode Command Line Tools
xcode-select --install

# Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Core tools
brew install node python@3.12 rust
brew install pnpm          # Fast package manager (replaces npm)

# Tauri system dependencies (macOS needs nothing extra)
```

**Ubuntu/Debian Linux:**
```bash
# System packages
sudo apt update
sudo apt install -y \
  build-essential \
  curl \
  wget \
  libssl-dev \
  libgtk-3-dev \
  libwebkit2gtk-4.1-dev \
  librsvg2-dev \
  libayatana-appindicator3-dev \
  javascript-common

# Node.js (v20 LTS via nvm)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
source ~/.bashrc
nvm install 20
nvm use 20

# PNPM
npm install -g pnpm

# Rust (via rustup)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Python 3.12
sudo apt install -y python3.12 python3.12-venv python3-pip

# Tauri CLI
cargo install tauri-cli
```

**Windows:**
```powershell
# Install via winget (Windows Package Manager)
winget install Microsoft.VisualStudio.2022.BuildTools  # C++ build tools
winget install Rustlang.Rustup
winget install OpenJS.NodeJS.LTS
winget install Python.Python.3.12

# PNPM
npm install -g pnpm

# Tauri CLI
cargo install tauri-cli

# WebView2 (usually pre-installed on Windows 10/11)
# If missing: https://developer.microsoft.com/microsoft-edge/webview2/
```

#### Verify Installations

```bash
node --version     # v20.x.x
pnpm --version     # 9.x.x
rustc --version    # 1.78+
cargo --version    # 1.78+
python3 --version  # 3.12+
cargo tauri --version  # tauri-cli 2.x.x
```

**Acceptance Criteria:**
- [ ] All tools installed and version-verified
- [ ] `cargo tauri info` shows no missing dependencies

---

### Sprint 0.2: Initialize Monorepo (Day 1-2)

#### Create Project Structure

```bash
mkdir dungeon-master-tool-v2 && cd dungeon-master-tool-v2

# Initialize root package.json
pnpm init

# Create workspace config
cat > pnpm-workspace.yaml << 'EOF'
packages:
  - "apps/*"
  - "packages/*"
EOF

# Create directory structure
mkdir -p apps/desktop/src-tauri/src
mkdir -p apps/web
mkdir -p apps/mobile
mkdir -p packages/ui/src/{features,components,hooks,store,api,themes,i18n,types}
mkdir -p packages/shared/src
mkdir -p backend/{routers,ws,services,core,tests}
mkdir -p e2e/tests
```

#### Initialize Tauri + React (Desktop App)

```bash
cd apps/desktop

# Create Vite + React + TypeScript project
pnpm create vite . --template react-ts

# Install React dependencies
pnpm add react react-dom react-router-dom
pnpm add -D @types/react @types/react-dom typescript vite

# Initialize Tauri
cargo tauri init
# - Frontend URL: http://localhost:5173
# - Dev command: pnpm dev
# - Build command: pnpm build
# - Output: ../dist
```

#### Initialize FastAPI Backend

```bash
cd ../../backend

# Create Python virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install fastapi uvicorn[standard] pydantic websockets
pip install msgpack requests python-i18n PyYAML Pillow
pip install python-socketio[client]

# Create requirements.txt
pip freeze > requirements.txt

# Create entry point
cat > server.py << 'PYEOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Dungeon Master Tool API", version="2.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

@app.get("/api/health")
def health():
    return {"status": "ok", "version": "2.0.0"}
PYEOF
```

#### Copy Core Logic

```bash
# Copy the entire core/ directory from v1
cp -r /path/to/dungeon-master-tool/core/ backend/core/

# Copy config.py (will need adaptation)
cp /path/to/dungeon-master-tool/config.py backend/config.py

# Copy locale files
cp -r /path/to/dungeon-master-tool/locales/ backend/locales/

# Copy assets (soundpad library, condition icons, etc.)
cp -r /path/to/dungeon-master-tool/assets/ backend/assets/

# Verify core imports work
cd backend && python -c "from core.data_manager import DataManager; print('Core loaded OK')"
```

**Acceptance Criteria:**
- [ ] `cd apps/desktop && pnpm dev` → Vite dev server starts on :5173
- [ ] `cd backend && uvicorn server:app --reload --port 8765` → FastAPI starts
- [ ] `curl http://localhost:8765/api/health` → `{"status": "ok"}`
- [ ] `cargo tauri dev` from apps/desktop → Tauri window opens showing React app

---

### Sprint 0.3: Wire Tauri + React + FastAPI Together (Day 2-3)

#### Tasks

1. **Configure Vite proxy** — React dev server proxies `/api` requests to FastAPI:
```typescript
// apps/desktop/vite.config.ts
export default defineConfig({
  server: {
    proxy: {
      '/api': 'http://localhost:8765',
      '/ws': { target: 'ws://localhost:8765', ws: true }
    }
  }
});
```

2. **Create API client** — Fetch wrapper for React:
```typescript
// packages/ui/src/api/client.ts
const API_BASE = '/api';
export async function fetchApi<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, { ...options, headers: { 'Content-Type': 'application/json' } });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}
```

3. **Verify end-to-end** — React fetches health check from FastAPI through Vite proxy

4. **Configure Tauri sidecar** — Tauri launches FastAPI on app start (for production builds; dev mode uses separate terminals)

**Acceptance Criteria:**
- [ ] React component calls `/api/health` and displays response
- [ ] Tauri window shows the React app with API data
- [ ] Hot reload works: edit React → see changes, edit Python → uvicorn reloads

---

### Sprint 0.4: Shared Packages Setup (Day 3-5)

#### Tasks

1. **Set up packages/ui** — Shared React components exported as a package:
```json
// packages/ui/package.json
{ "name": "@dm-tool/ui", "main": "src/index.ts" }
```

2. **Set up packages/shared** — Shared TypeScript types and constants:
```json
// packages/shared/package.json
{ "name": "@dm-tool/shared", "main": "src/index.ts" }
```

3. **Define TypeScript entity types** — Convert Python entity schema to TypeScript (see SYSTEM_ARCHITECTURE.md Section 5.3)

4. **Set up Tailwind CSS** — Install and configure with theme CSS variables:
```bash
cd packages/ui && pnpm add -D tailwindcss @tailwindcss/vite
```

5. **Set up react-i18next** — Convert YAML locale files to JSON, configure i18n:
```bash
pnpm add react-i18next i18next
# Convert: python -c "import yaml, json; print(json.dumps(yaml.safe_load(open('locales/en.yml'))))" > locales/en.json
```

6. **Set up Zustand** — Create initial stores (uiStore for theme, language):
```bash
pnpm add zustand
```

7. **Set up TanStack Query** — Configure query client:
```bash
pnpm add @tanstack/react-query
```

8. **Install Turborepo** — Monorepo build orchestration:
```bash
pnpm add -D turbo -w
```

**Acceptance Criteria:**
- [ ] `packages/ui` components importable from `apps/desktop`
- [ ] Theme switching works (dark/light via CSS variables)
- [ ] `t('BTN_ADD')` returns translated string
- [ ] Zustand uiStore persists theme selection

---

### Sprint 0.5: Development Workflow (Day 5-7)

#### Tasks

1. **Three-terminal development script:**
```bash
# dev.sh
#!/bin/bash
# Terminal 1: Backend
(cd backend && source .venv/bin/activate && uvicorn server:app --reload --port 8765) &
# Terminal 2: Frontend
(cd apps/desktop && pnpm dev) &
# Terminal 3: Tauri (optional)
# cd apps/desktop && cargo tauri dev
wait
```

2. **ESLint + Prettier** — Frontend code quality:
```bash
pnpm add -D eslint prettier eslint-config-prettier @typescript-eslint/eslint-plugin
```

3. **Vitest** — Frontend testing framework:
```bash
pnpm add -D vitest @testing-library/react @testing-library/jest-dom jsdom
```

4. **Playwright** — E2E testing:
```bash
pnpm add -D @playwright/test
npx playwright install
```

5. **Backend testing** — Copy existing tests from v1:
```bash
cp -r /path/to/dungeon-master-tool/tests/ backend/tests/
pip install pytest pytest-asyncio httpx  # httpx for FastAPI TestClient
```

6. **Git setup** — Initialize repo, gitignore, pre-commit hooks:
```bash
git init
cat > .gitignore << 'EOF'
node_modules/
.venv/
target/
dist/
__pycache__/
*.pyc
.env
EOF
```

**Acceptance Criteria:**
- [ ] `pnpm dev` starts both frontend and backend
- [ ] `pnpm test` runs Vitest
- [ ] `cd backend && pytest` runs existing Python tests
- [ ] ESLint + Prettier configured and working
- [ ] Git repository initialized with clean .gitignore

---

## Phase 1: Backend API Foundation

**Duration:** 8-10 days
**Goal:** Full REST API wrapping all existing core logic + WebSocket events

### Sprint 1.1: Campaign & Settings Routes (Day 1-2)

#### Tasks

1. **Campaign Router:**
```python
# backend/routers/campaigns.py
@router.get("/")
def list_campaigns(): return dm.get_available_campaigns()

@router.post("/")
def create_campaign(body: CampaignCreate): return dm.create_campaign(body.world_name)

@router.post("/{name}/load")
def load_campaign(name: str): return dm.load_campaign_by_name(name)

@router.get("/current")
def get_current(): return {"world_name": dm.data.get("world_name"), "entity_count": len(dm.data.get("entities", {}))}
```

2. **Settings Router:**
```python
@router.get("/")
def get_settings(): return dm.load_settings()

@router.put("/")
def save_settings(body: dict): dm.save_settings(body)
```

3. **Backend tests** for campaign CRUD

**Acceptance Criteria:**
- [ ] `GET /api/campaigns` returns campaign list
- [ ] `POST /api/campaigns` creates new campaign
- [ ] `POST /api/campaigns/{name}/load` loads campaign
- [ ] Settings endpoints work

---

### Sprint 1.2: Entity Routes (Day 3-4)

#### Tasks

1. **Entity Router** — Full CRUD:
```python
@router.get("/")
def list_entities(type: str = None, search: str = None): ...

@router.get("/{id}")
def get_entity(id: str): ...

@router.post("/")
def create_entity(body: dict): return dm.save_entity(None, body)

@router.put("/{id}")
def update_entity(id: str, body: dict): return dm.save_entity(id, body)

@router.delete("/{id}")
def delete_entity(id: str): dm.delete_entity(id)

@router.get("/mentions")
def get_mentions(): return dm.get_all_entity_mentions()

@router.post("/import")
def import_entity(body: dict): return dm.import_entity_with_dependencies(body)

@router.post("/fetch")
def fetch_from_api(body: FetchRequest): return dm.fetch_from_api(body.category, body.query)
```

2. **Pydantic models** for request/response validation
3. **Tests** for entity CRUD

**Acceptance Criteria:**
- [ ] Full entity CRUD via REST
- [ ] Entity search/filter works
- [ ] Import from D&D API works

---

### Sprint 1.3: Session, Map & Mind Map Routes (Day 5-6)

#### Tasks

1. **Session Router** — CRUD + combatant management
2. **Map Router** — Pins, timeline, image management
3. **Mind Map Router** — Node/edge CRUD, snapshot save
4. **Tests** for each router

**Acceptance Criteria:**
- [ ] Session CRUD works
- [ ] Map pin CRUD works
- [ ] Mind map save/load works

---

### Sprint 1.4: Library, Asset & Audio Routes (Day 7-8)

#### Tasks

1. **Library Router** — API index, fetch details, search
2. **Asset Router** — Image/PDF upload, file serving
3. **Audio Router** — Library metadata, audio file streaming
4. **Tests**

**Acceptance Criteria:**
- [ ] `GET /api/library/index/monsters?page=1` returns paginated list
- [ ] `POST /api/assets/images` uploads and returns relative path
- [ ] `GET /api/assets/{path}` serves files
- [ ] `GET /api/audio/file/{path}` streams audio

---

### Sprint 1.5: WebSocket Foundation (Day 9-10)

#### Tasks

1. **WebSocket Manager** — Connection management, broadcasting
2. **EventBus → WebSocket bridge** — Subscribe to all EventBus events, forward to connected clients
3. **Client-side WebSocket hook** — `useWebSocket()` React hook
4. **Test** — Connect, receive events, disconnect

**Acceptance Criteria:**
- [ ] WebSocket connects at `/ws`
- [ ] Entity CRUD triggers WebSocket events
- [ ] Multiple clients receive broadcasts
- [ ] Reconnection on disconnect

---

## Phase 2: Core UI — Campaign, Sidebar, Entity Editor

**Duration:** 12-15 days
**Goal:** Campaign selection, entity browsing, and full NPC sheet editing

### Sprint 2.1: Campaign Selector (Day 1-2)

#### Tasks

1. **CampaignSelector.tsx** — List campaigns, create new, load selected
2. **React Router** — `/` → campaign selector, `/app` → main layout
3. **Language selector** on campaign screen
4. **Auto-load last campaign** (from settings)

**Acceptance Criteria:**
- [ ] List campaigns from API
- [ ] Create new campaign
- [ ] Select and load campaign → navigate to /app
- [ ] Language switching works

---

### Sprint 2.2: Main Layout Shell (Day 3-4)

#### Tasks

1. **MainLayout.tsx** — Toolbar + sidebar + tabs + right panel
2. **Toolbar** — Theme combo, language combo, edit mode toggle, player screen button, export
3. **Tab navigation** — Database, Mind Map, Map, Session tabs
4. **Sidebar container** — Resizable panel (CSS resize or drag handle)
5. **Right panel container** — Collapsible soundpad/PDF area
6. **Theme switching** — CSS variable injection, 11 themes

**Acceptance Criteria:**
- [ ] Main layout renders with toolbar, sidebar, tabs
- [ ] Tab switching works
- [ ] Theme switching applies to all components
- [ ] Sidebar resizable
- [ ] Right panel toggles

---

### Sprint 2.3: Entity Sidebar (Day 5-7)

#### Tasks

1. **EntitySidebar.tsx** — Virtualized list (react-virtuoso for performance)
2. **Search** — Real-time search with debounce
3. **Category filter** — Dropdown or chip filter by entity type
4. **Entity badges** — Type icon, source indicator
5. **Click to open** — Opens entity in database tab
6. **Drag source** — `@dnd-kit` drag for dropping into combat/mind map
7. **WebSocket sync** — Entity created/deleted events refresh list

**Acceptance Criteria:**
- [ ] Displays all entities from loaded campaign
- [ ] Search filters in real-time
- [ ] Category filter works
- [ ] Click opens entity in editor
- [ ] Entity list updates when entities are created/deleted

---

### Sprint 2.4: NPC Sheet — Core Editor (Day 8-10)

#### Tasks

1. **NpcSheet.tsx** — Main editor with 6+ tabs
2. **Metadata section** — Image gallery, name, type, source, tags, location
3. **Description** — TipTap markdown editor with view/edit mode
4. **Dynamic attributes** — Render form fields from `ENTITY_SCHEMAS[type]`
5. **DM Notes** — Separate markdown editor
6. **Edit mode** — Toggle read-only / editable globally
7. **Save/Delete** — Ctrl+S saves, delete button with confirmation
8. **ImageGallery.tsx** — Multi-image carousel, add/remove images

**Acceptance Criteria:**
- [ ] Open entity → all fields populated
- [ ] Edit and save entity
- [ ] Type change updates dynamic attributes
- [ ] Image gallery works (view, add, remove, navigate)
- [ ] Edit mode toggle locks/unlocks all fields

---

### Sprint 2.5: NPC Sheet — Sub-Tabs (Day 11-13)

#### Tasks

1. **StatsTab** — Ability scores (STR-CHA), combat stats (HP/AC/Speed), defense (saves, immunities)
2. **ActionsTab** — Traits, actions, reactions, legendary actions (add/remove cards)
3. **SpellsTab** — Linked spells from database + manual spell dialog
4. **InventoryTab** — Linked equipment + custom items
5. **DocsTab** — PDF list with add/remove/project buttons
6. **BattlemapsTab** — Battlemap image list with thumbnails

**Acceptance Criteria:**
- [ ] All 6 sub-tabs render and save correctly
- [ ] Feature cards (traits/actions) add/remove/edit
- [ ] Linked entity widget (spells/items) search and link
- [ ] Manual spell dialog with "save to DB" option
- [ ] PDF project button emits event

---

### Sprint 2.6: Database Tab — Dual Panel (Day 14-15)

#### Tasks

1. **DatabaseTab.tsx** — Dual-panel workspace (left/right entity editors)
2. **Tab management** — Open multiple entities as tabs within each panel
3. **Unsaved indicator** — Tab title shows `*` when dirty
4. **API entity import** — Open entity from library search into editor

**Acceptance Criteria:**
- [ ] Open entities in left or right panel
- [ ] Multiple tabs per panel
- [ ] Save/close tabs
- [ ] Unsaved changes indicator

---

### Sprint 2.7: Markdown Editor (Day 15)

#### Tasks

1. **MarkdownEditor.tsx** — TipTap with dual mode (edit/preview)
2. **Entity @mention** — Autocomplete popup when typing `@`
3. **Entity links** — `[@Name](entity://id)` clickable in preview
4. **Theme-aware rendering** — HTML styling from theme variables

**Acceptance Criteria:**
- [ ] Write markdown, see rendered preview
- [ ] Type `@` → autocomplete shows entities
- [ ] Click entity link → opens entity in editor
- [ ] Rendering uses theme colors

---

## Phase 3: Session, Combat Tracker & Timeline

**Duration:** 10-12 days
**Goal:** Full session management with combat tracking

### Sprint 3.1: Session Tab — Notes & Timeline (Day 1-3)

#### Tasks

1. **SessionTab.tsx** — Session list, create/delete sessions
2. **Session notes** — Markdown editor for DM notes
3. **Event log** — Markdown editor for session logs
4. **Timeline** — Visual timeline of events (day-based)
5. **Active session** — Highlight and auto-load last active

**Acceptance Criteria:**
- [ ] Create/switch sessions
- [ ] Notes and logs save per session
- [ ] Timeline displays events

---

### Sprint 3.2: Combat Tracker — Table (Day 4-6)

#### Tasks

1. **CombatTracker.tsx** — Encounter management (create, rename, delete, switch)
2. **CombatTable.tsx** — Table with columns: Name, Init, AC, HP, Conditions
3. **HpBar.tsx** — HP +/- buttons with progress bar, color by percentage
4. **ConditionBadge.tsx** — Condition icons with duration countdown
5. **Quick add row** — Name + Init + HP fields for fast combatant entry
6. **Drag-and-drop** — Drag entity from sidebar into combat table
7. **Turn management** — Next turn button, active row highlight, round counter

**Acceptance Criteria:**
- [ ] Add combatants manually and via drag-drop
- [ ] HP increase/decrease with visual feedback
- [ ] Conditions add/remove with duration tracking
- [ ] Turn advancement with round counting
- [ ] Encounter save/load per session

---

### Sprint 3.3: Combat — Initiative & Sorting (Day 7-8)

#### Tasks

1. **Roll initiative** — Random roll + modifier
2. **Manual initiative edit** — Click-to-edit initiative values
3. **Sort by initiative** — Descending order
4. **Drag reorder** — Manual position override
5. **Row context menu** — Edit, delete, duplicate combatant

**Acceptance Criteria:**
- [ ] Roll initiative for all combatants
- [ ] Manual initiative editing
- [ ] Sorted display
- [ ] Context menu actions

---

### Sprint 3.4: Combat — WebSocket Sync (Day 9-10)

#### Tasks

1. **Real-time HP updates** — WebSocket broadcasts HP changes
2. **Turn sync** — All connected clients see current turn
3. **Condition sync** — Condition changes broadcast
4. **Player view integration** — Combat sidebar in player window (read-only)

**Acceptance Criteria:**
- [ ] Open two browser tabs → HP change visible in both
- [ ] Turn advancement syncs across tabs
- [ ] Player view shows combat sidebar

---

### Sprint 3.5: World Map Tab (Day 11-12)

#### Tasks

1. **MapTab.tsx** — World map image display with pan/zoom
2. **Entity pins** — Clickable pins on map linked to entities
3. **Timeline pins** — Day-based event markers
4. **Pin CRUD** — Add, move, delete pins
5. **Pin color/note editing** — Right-click or click to edit

**Acceptance Criteria:**
- [ ] Map image displays with pan/zoom
- [ ] Add pins linked to entities
- [ ] Click pin → open entity
- [ ] Timeline pins display with day numbers

---

## Phase 4: Battle Map Engine

**Duration:** 15-18 days
**Goal:** Full battle map with tokens, fog, grid, tools

### Sprint 4.1: Canvas Foundation (Day 1-3)

#### Tasks

1. **BattleMap.tsx** — Konva Stage with zoom/pan
2. **Map background layer** — Load and display map image
3. **Grid overlay layer** — Configurable cell size, toggle visibility
4. **Toolbar** — Tool selector buttons (Navigate, Ruler, Circle, Draw, Fog)
5. **Grid controls** — Cell size, snap toggle, feet per cell

**Acceptance Criteria:**
- [ ] Map image displays on canvas
- [ ] Pan (drag) and zoom (scroll) work
- [ ] Grid overlay toggles on/off
- [ ] Grid size configurable

---

### Sprint 4.2: Token System (Day 4-6)

#### Tasks

1. **TokenLayer.tsx** — Render tokens as Konva circles
2. **Token images** — Entity portrait as fill pattern
3. **Token colors** — Border color by attitude (player/hostile/friendly/neutral)
4. **Token drag** — DM can drag tokens, snap to grid
5. **Token size** — Global slider + per-token override
6. **Token CRUD** — Add from combat list, remove via context menu
7. **Token labels** — Entity name below token

**Acceptance Criteria:**
- [ ] Tokens render with entity images
- [ ] Color-coded borders
- [ ] Drag to move, snap to grid
- [ ] Size slider works
- [ ] Labels display

---

### Sprint 4.3: Fog of War (Day 7-10)

#### Tasks

1. **FogOfWarLayer.tsx** — Offscreen canvas compositing
2. **Fog add tool** — Click-drag polygon → fill black (hide area)
3. **Fog erase tool** — Click-drag polygon → clear to transparent (reveal area)
4. **Fog fill** — One-click fill entire map with fog
5. **Fog clear** — One-click remove all fog
6. **Fog serialization** — Base64 PNG for save/load
7. **Visual feedback** — Show polygon outline while drawing
8. **DM vs Player** — DM sees semi-transparent fog; player sees opaque

**Acceptance Criteria:**
- [ ] Draw polygons to add/remove fog
- [ ] Fog persists across session save/load
- [ ] Player view shows opaque fog
- [ ] Fill/clear buttons work

---

### Sprint 4.4: Measurement & Drawing Tools (Day 11-13)

#### Tasks

1. **Ruler tool** — Line with distance label (feet + squares)
2. **Circle tool** — Circle with radius label
3. **Drawing tool** — Freehand annotation with brush width/color
4. **Annotation serialization** — Base64 PNG save/load
5. **Clear annotations** — One-click clear
6. **Clear measurements** — One-click clear

**Acceptance Criteria:**
- [ ] Ruler shows distance in feet
- [ ] Circle shows radius
- [ ] Freehand drawing works
- [ ] Annotations persist

---

### Sprint 4.5: Battle Map — DM/Player Sync (Day 14-16)

#### Tasks

1. **WebSocket sync** — Token moves, fog changes, annotations broadcast via WebSocket
2. **Player battle map** — Read-only view (no tools, no editing)
3. **Real-time updates** — Token position changes appear instantly on player view
4. **Fog sync** — Fog reveals/hides sync to player
5. **Combat integration** — Battle map bridge reads combatants from session
6. **Video map support** — Animated map backgrounds (MP4/WebM via `<video>`)

**Acceptance Criteria:**
- [ ] DM moves token → player sees movement instantly
- [ ] DM reveals fog → player sees revealed area
- [ ] Player view is read-only (no tools)
- [ ] Combat list ↔ token list synchronized

---

## Phase 5: Mind Map Engine

**Duration:** 10-12 days
**Goal:** Full mind map editor with nodes, connections, undo/redo

### Sprint 5.1: React Flow Foundation (Day 1-3)

#### Tasks

1. **MindMapTab.tsx** — React Flow canvas with zoom/pan
2. **Note node** — TipTap markdown editor inside node
3. **Entity node** — Entity summary card inside node
4. **Image node** — Aspect-ratio image display
5. **Workspace node** — Background grouping container with dashed border
6. **Context menu** — Right-click canvas → add node options

**Acceptance Criteria:**
- [ ] Create/delete note, entity, image, workspace nodes
- [ ] Drag to position nodes
- [ ] Edit markdown in note nodes
- [ ] Entity data displays in entity nodes

---

### Sprint 5.2: Connections & Layout (Day 4-6)

#### Tasks

1. **Bezier edge connections** — Custom edge component with theme colors
2. **Connection creation** — Drag from node handle to another node
3. **Connection deletion** — Right-click edge → delete
4. **Node resize** — Drag handles on node corners
5. **LOD zoom** — Simplified rendering at low zoom levels
6. **Auto-fit view** — Fit all nodes in viewport on load

**Acceptance Criteria:**
- [ ] Connect nodes with bezier curves
- [ ] Delete connections
- [ ] Resize nodes
- [ ] Zoom out → simplified node rendering

---

### Sprint 5.3: Undo/Redo & Persistence (Day 7-9)

#### Tasks

1. **Undo/Redo** — Snapshot-based history (50 steps), Ctrl+Z / Ctrl+Shift+Z
2. **Autosave** — Debounced save (2000ms) on any change
3. **Save/Load** — Persist to `/api/mindmaps/{id}`
4. **Multiple mind maps** — Create/switch between mind maps
5. **Entity drag-drop** — Drag entity from sidebar onto canvas → create entity node

**Acceptance Criteria:**
- [ ] Undo/redo 50 steps
- [ ] Autosave triggers after changes
- [ ] Mind map persists across app restart
- [ ] Drag entity from sidebar → new entity node

---

### Sprint 5.4: Mind Map Polish (Day 10-12)

#### Tasks

1. **Minimap** — React Flow built-in minimap
2. **Workspace coloring** — Color picker for workspace nodes
3. **Node projection** — Project entity/image to player window
4. **Keyboard shortcuts** — Ctrl+Z, Delete, Escape
5. **Touch support** — Pinch zoom, tap to select (for future mobile)

**Acceptance Criteria:**
- [ ] Minimap shows overview
- [ ] Workspace color editing
- [ ] Project to player works
- [ ] Keyboard shortcuts work

---

## Phase 6: Audio, Player Screen & PDF

**Duration:** 10-12 days
**Goal:** Complete audio system, player projection, and PDF viewing

### Sprint 6.1: Soundpad Panel (Day 1-4)

#### Tasks

1. **SoundpadPanel.tsx** — 3-tab panel (Music, Ambience, SFX)
2. **useAudioEngine.ts** — Howler.js wrapper with dual-deck crossfade
3. **Music tab** — Theme selector, state buttons (Normal/Combat/Victory), intensity slider
4. **Ambience tab** — 4 slots, file selector, volume per slot
5. **SFX tab** — Grid of SFX buttons, click to play
6. **Master volume** — Global volume control
7. **Stop all** — Emergency stop button
8. **Audio file streaming** — Load audio from `/api/audio/file/{path}`

**Acceptance Criteria:**
- [ ] Load audio themes from library
- [ ] Switch music states with crossfade
- [ ] Play ambience in 4 slots simultaneously
- [ ] SFX plays on click
- [ ] Master volume affects all audio

---

### Sprint 6.2: Player Screen (Day 5-7)

#### Tasks

1. **PlayerView.tsx** — Content router based on projection commands
2. **Image mode** — Single/multi image view with auto-layout
3. **Battle map mode** — Read-only battle map (tokens + fog)
4. **Black screen mode** — Full black overlay
5. **Stat block mode** — HTML entity stat block
6. **PDF mode** — Embedded PDF viewer
7. **Tauri multi-window** — Open player as second Tauri window
8. **Browser fallback** — `window.open('/player')` for web mode
9. **WebSocket sync** — DM commands → player view changes

**Acceptance Criteria:**
- [ ] DM can switch player view between all 5 modes
- [ ] Battle map syncs in real-time
- [ ] Works as both Tauri window and browser tab

---

### Sprint 6.3: PDF Viewer & Panel (Day 8-9)

#### Tasks

1. **PdfViewer.tsx** — react-pdf based viewer with page navigation and zoom
2. **PdfPanel.tsx** — Collapsible right-side panel
3. **Project PDF** — Entity docs tab → project button → PDF panel
4. **Middle-mouse drag** — Pan PDF pages
5. **Open file** — File dialog to open local PDF

**Acceptance Criteria:**
- [ ] View PDF with page navigation
- [ ] Zoom controls work
- [ ] Project from entity docs tab
- [ ] Pan with middle mouse

---

### Sprint 6.4: API Browser & Import (Day 10-12)

#### Tasks

1. **ApiBrowser.tsx** — Browse D&D 5e API (monsters, spells, equipment)
2. **Pagination** — Page navigation
3. **Preview** — Click item to preview details
4. **Import** — Import entity into campaign database
5. **Bulk download** — Download all entries from a category
6. **Source switching** — Switch between D&D 5e API and Open5e

**Acceptance Criteria:**
- [ ] Browse paginated API index
- [ ] Preview entity details
- [ ] Import creates entity in database
- [ ] Source switching works

---

## Phase 7: Polish, Testing & Mobile

**Duration:** 10-14 days
**Goal:** Production quality, comprehensive testing, mobile support

### Sprint 7.1: Keyboard Shortcuts & DnD (Day 1-2)

#### Tasks

1. **Global shortcuts** — Ctrl+E (edit mode), Ctrl+S (save), Escape (close dialog)
2. **Per-feature shortcuts** — Ctrl+Z (mind map undo), Shift+Enter (markdown save)
3. **Drag-and-drop** — Entity sidebar → combat table, sidebar → mind map
4. **Context menus** — Right-click menus for combat, mind map, entity list

**Acceptance Criteria:**
- [ ] All keyboard shortcuts from v1 reimplemented
- [ ] Drag-drop works across features
- [ ] Context menus functional

---

### Sprint 7.2: Dialog Components (Day 3-4)

#### Tasks

1. **EntitySelector** — Modal to pick entities (for links, pins)
2. **EncounterSelector** — Choose encounter to load
3. **TimelineEntry** — Create/edit timeline events
4. **ManualSpellDialog** — Manual spell creation with DB save option
5. **ConfirmDialog** — Generic confirmation modal
6. **ImportWindow** — Library browser with import

**Acceptance Criteria:**
- [ ] All dialog interactions from v1 working
- [ ] Modals are accessible (keyboard navigable, focus trap)

---

### Sprint 7.3: Testing (Day 5-8)

#### Tasks

1. **Backend tests** — pytest for all routers (>80% coverage on routers/)
2. **Frontend unit tests** — Vitest for Zustand stores, utility functions
3. **Component tests** — React Testing Library for key components
4. **E2E tests** — Playwright for critical flows:
   - Campaign creation → entity creation → combat → save
   - Mind map creation → node CRUD → connection
   - Battle map → token placement → fog reveal
5. **Cross-browser testing** — Chrome, Firefox, Safari WebView

**Acceptance Criteria:**
- [ ] Backend: >80% router coverage
- [ ] Frontend: >60% coverage on stores and utils
- [ ] E2E: 10+ critical flow tests passing
- [ ] No console errors in any test run

---

### Sprint 7.4: Performance Optimization (Day 9-10)

#### Tasks

1. **Virtual scrolling** — Entity sidebar (react-virtuoso) for 1000+ entities
2. **Canvas layer caching** — Konva layer caching for battle map
3. **Debounced saves** — Prevent save storms on rapid edits
4. **Image lazy loading** — Intersection Observer for entity images
5. **Bundle splitting** — Vite code splitting for features (battle map, mind map loaded on demand)
6. **WebSocket reconnection** — Auto-reconnect with exponential backoff

**Acceptance Criteria:**
- [ ] Sidebar smooth with 1000 entities
- [ ] Battle map 60fps with 50 tokens
- [ ] Bundle size < 2MB (gzipped)
- [ ] WebSocket reconnects automatically

---

### Sprint 7.5: Mobile Support (Day 11-14)

#### Tasks

1. **Responsive layouts** — Mobile-first CSS for player view
2. **Touch interactions** — Pinch zoom, tap to select, swipe navigation
3. **Capacitor setup** — Initialize Android/iOS projects
4. **Player-only mobile** — Mobile app shows only player view
5. **APK build** — Generate Android APK
6. **iOS build** — Generate iOS IPA (requires Mac)
7. **Mobile testing** — Test on real devices

**Acceptance Criteria:**
- [ ] Player view renders correctly on 360px wide screens
- [ ] Touch zoom/pan works on battle map
- [ ] Android APK installs and connects to desktop backend
- [ ] No horizontal scroll on any mobile page

---

## Phase 8: Online Play Foundation (Future)

**Duration:** 8-12 weeks (separate project phase)
**Goal:** Multi-user online play with authentication

### Sprint 8.1: Authentication
- JWT-based auth (login/register)
- Role system (DM vs Player)
- Campaign invitations (share links)

### Sprint 8.2: Multi-User Sync
- Conflict resolution (last-write-wins or CRDT)
- Player-specific entity access (own character sheet)
- DM-only features gated on role

### Sprint 8.3: Database Migration
- SQLite for single-user (replace MsgPack)
- PostgreSQL for hosted servers
- Data migration tool (MsgPack → SQL)

### Sprint 8.4: Deployment
- Docker container for self-hosted servers
- Cloud deployment (Railway, Fly.io, or Vercel)
- CDN for static assets

---

## Dependency Graph

```
Phase 0 (Setup)
    │
    ▼
Phase 1 (Backend API) ─────────────────────────────┐
    │                                                │
    ▼                                                │
Phase 2 (Core UI: Campaign, Sidebar, Entity Editor) │
    │                                                │
    ├──────────────┬──────────────┐                  │
    ▼              ▼              ▼                  │
Phase 3        Phase 4        Phase 5                │
(Session/      (Battle Map)   (Mind Map)             │
 Combat)           │              │                  │
    │              │              │                  │
    └──────────────┴──────────────┘                  │
                   │                                  │
                   ▼                                  │
              Phase 6 (Audio, Player Screen, PDF) ◄──┘
                   │
                   ▼
              Phase 7 (Polish, Testing, Mobile)
                   │
                   ▼
              Phase 8 (Online Play — Future)
```

**Notes:**
- Phases 3, 4, 5 can be developed in parallel after Phase 2
- Phase 6 depends on Phase 4 (battle map player view)
- Phase 7 is integration and polish across all features
- Phase 8 is a future project phase, not part of v2.0

---

## Risk Register

| # | Risk | Impact | Likelihood | Mitigation | Phase |
|---|------|--------|------------|------------|-------|
| 1 | Fog of war canvas performance on large maps | High | Medium | Limit fog resolution to 2048px; use offscreen canvas; profile in Sprint 4.3 | 4 |
| 2 | Konva.js token hit detection with 50+ tokens | Medium | Low | Enable layer caching; use spatial index for hit testing | 4 |
| 3 | react-flow rich content in nodes causes focus issues | Medium | Medium | Prototype in Sprint 5.1; fallback to side-panel editing if needed | 5 |
| 4 | Howler.js crossfade timing differs from QMediaPlayer | Low | Medium | Use `fade()` with `requestAnimationFrame`; test with real music files | 6 |
| 5 | Tauri sidecar packaging adds 50MB+ | Low | High | Accept for desktop; mobile is WebView-only (no sidecar) | 7 |
| 6 | WebView rendering differences across platforms | Medium | Medium | Test on all three platforms early (Sprint 0.5) | 0 |
| 7 | Python core imports fail when copied to backend | High | Low | Run `python -c "from core.data_manager import DataManager"` immediately | 0 |
| 8 | YAML locale files have encoding issues in JSON conversion | Low | Low | Use `yaml.safe_load()` with explicit UTF-8 encoding | 0 |
| 9 | TipTap entity @mention autocomplete performance | Low | Low | Debounce query, limit results to 20 | 2 |
| 10 | Capacitor Android build fails | Medium | Medium | Have Tauri Mobile as backup; test early in Sprint 7.5 | 7 |

---

## Summary

| Phase | Duration | Key Deliverable |
|-------|----------|-----------------|
| Phase 0: Setup | 5-7 days | Working Tauri + React + FastAPI skeleton |
| Phase 1: Backend | 8-10 days | Full REST API + WebSocket |
| Phase 2: Core UI | 12-15 days | Campaign, sidebar, entity editor |
| Phase 3: Session | 10-12 days | Session management, combat tracker, world map |
| Phase 4: Battle Map | 15-18 days | Canvas battle map with fog, tokens, tools |
| Phase 5: Mind Map | 10-12 days | Node editor with connections, undo/redo |
| Phase 6: Audio & Player | 10-12 days | Soundpad, player screen, PDF, API browser |
| Phase 7: Polish & Mobile | 10-14 days | Testing, performance, Android/iOS build |
| **Total** | **80-100 days** | **~18-22 weeks** |
| Phase 8: Online (Future) | 8-12 weeks | Authentication, multi-user, cloud deploy |
