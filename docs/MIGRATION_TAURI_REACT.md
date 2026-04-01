# Tech Stack Migration: PyQt6 → Tauri + React + FastAPI

**Date:** 2026-04-01
**Current Version:** alpha-v0.8.4
**Target:** Cross-platform (Desktop + Mobile + Web) from single codebase

---

## 1. Executive Summary

### Current Stack
- **UI:** PyQt6 Widgets (53 files, ~15,000 LOC)
- **Core Logic:** Pure Python (20+ files, ~7,000 LOC, UI-free)
- **Data:** MsgPack binary per campaign
- **Audio:** QMediaPlayer (PyQt6 dependency)
- **Build:** PyInstaller → Linux/Windows/Mac executables

### Target Stack
- **Desktop Shell:** Tauri v2 (Rust, system WebView, ~3-5MB binary)
- **Frontend:** React + TypeScript + Vite
- **Backend:** Python FastAPI (wraps existing core logic)
- **Audio:** Howler.js (Web Audio API)
- **Build:** Tauri CLI → desktop + mobile

### Strategy: Strangler Fig
Incremental migration in 4 phases. Each phase produces a usable app. The existing Python core (`core/`) is copied verbatim into the backend — zero rewrite needed for business logic.

### Effort Estimate
- **Backend (FastAPI):** ~2,500-3,000 LOC (thin wrappers around existing core)
- **Frontend (React):** ~14,000-18,000 LOC
- **Tauri glue:** ~500 LOC
- **Timeline:** 5-7 months solo, 3-4 months with 2-3 developers

---

## 2. Architecture Overview

### Current (PyQt6)

```
main.py → QApplication → MainWindow
  ├─ EntitySidebar
  ├─ QTabWidget
  │   ├─ DatabaseTab (dual-panel entity editor)
  │   ├─ MindMapTab (QGraphicsScene node editor)
  │   ├─ MapTab (world map with pins)
  │   └─ SessionTab (notes, combat tracker)
  ├─ SoundpadPanel (right-side, collapsible)
  ├─ PdfPanel (right-side, collapsible)
  └─ PlayerWindow (separate QMainWindow on 2nd monitor)

DataManager (facade)
  ├─ EntityRepository
  ├─ SessionRepository
  ├─ CampaignManager
  ├─ MapDataManager
  ├─ LibraryManager
  └─ SettingsManager
EventBus (pub/sub)
NetworkBridge (socket.io skeleton)
```

### Target (Tauri + React + FastAPI)

```
┌─────────────────────────────────────────────────┐
│  Tauri Shell (Rust)                              │
│  - Launches FastAPI sidecar                      │
│  - System WebView hosts React app                │
│  - Multi-window (DM + Player)                    │
│  - Native file dialogs, system tray              │
└─────────────┬───────────────────────────────────┘
              │ localhost:8765
┌─────────────▼───────────────────────────────────┐
│  React Frontend (TypeScript)                     │
│  ├─ features/ (campaign, entities, session,      │
│  │   battlemap, mindmap, worldmap, audio, player)│
│  ├─ store/ (Zustand)                             │
│  ├─ api/ (REST client + WebSocket hooks)         │
│  └─ themes/ (CSS variables, 11 themes)           │
└─────────────┬──────────┬────────────────────────┘
        REST  │          │ WebSocket
┌─────────────▼──────────▼────────────────────────┐
│  FastAPI Backend (Python)                        │
│  ├─ routers/ (campaigns, entities, sessions,     │
│  │   maps, mindmaps, library, settings, assets)  │
│  ├─ ws/ (WebSocket hub, broadcasts EventBus)     │
│  └─ core/ (EXISTING CODE — zero changes)         │
│      ├─ entity_repository.py                     │
│      ├─ session_repository.py                    │
│      ├─ campaign_manager.py                      │
│      ├─ event_bus.py                             │
│      ├─ models.py                                │
│      └─ api/ (D&D 5e client)                     │
└─────────────────────────────────────────────────┘
```

### Data Flow

```
React UI ──REST──▶ FastAPI Router ──▶ Core (existing Python)
                                          │
React UI ◀──WS─── WebSocket Hub ◀── EventBus.publish()
    │
Player Window ◀──WS──┘ (separate browser window)
```

---

## 3. Backend API Design

### Campaign Routes (`/api/campaigns`)
| Method | Path | Description | Source |
|--------|------|-------------|--------|
| GET | `/api/campaigns` | List available campaigns | `CampaignManager.get_available()` |
| POST | `/api/campaigns` | Create campaign | `CampaignManager.create()` |
| POST | `/api/campaigns/{name}/load` | Load campaign | `CampaignManager.load_by_name()` |
| GET | `/api/campaigns/current` | Get current campaign info | `DataManager.data["world_name"]` |

### Entity Routes (`/api/entities`)
| Method | Path | Description | Source |
|--------|------|-------------|--------|
| GET | `/api/entities` | List entities (filter by type, search) | `DataManager.data["entities"]` |
| GET | `/api/entities/{id}` | Get entity | `DataManager.data["entities"][id]` |
| POST | `/api/entities` | Create entity | `EntityRepository.save(None, data)` |
| PUT | `/api/entities/{id}` | Update entity | `EntityRepository.save(id, data)` |
| DELETE | `/api/entities/{id}` | Delete entity | `EntityRepository.delete(id)` |
| GET | `/api/entities/mentions` | All mentions (for autocomplete) | `EntityRepository.get_all_mentions()` |
| POST | `/api/entities/import` | Import with dependencies | `EntityRepository.import_with_dependencies()` |
| POST | `/api/entities/fetch` | Fetch from D&D API | `DataManager.fetch_from_api()` |

### Session Routes (`/api/sessions`)
| Method | Path | Description | Source |
|--------|------|-------------|--------|
| GET | `/api/sessions` | List sessions | `DataManager.data["sessions"]` |
| GET | `/api/sessions/{id}` | Get session | `SessionRepository.get(id)` |
| POST | `/api/sessions` | Create session | `SessionRepository.create(name)` |
| PUT | `/api/sessions/{id}` | Save session data | `SessionRepository.save_data()` |
| PUT | `/api/sessions/{id}/activate` | Set active session | `SessionRepository.set_active(id)` |

### Map Routes (`/api/maps`)
| Method | Path | Description | Source |
|--------|------|-------------|--------|
| GET | `/api/maps` | Get map data | `DataManager.data["map_data"]` |
| PUT | `/api/maps/image` | Set map image | `DataManager.set_map_image()` |
| POST | `/api/maps/pins` | Add pin | `DataManager.add_pin()` |
| PUT | `/api/maps/pins/{id}` | Update pin | `DataManager.update_map_pin()` |
| DELETE | `/api/maps/pins/{id}` | Remove pin | `DataManager.remove_specific_pin()` |
| POST | `/api/maps/timeline` | Add timeline pin | `DataManager.add_timeline_pin()` |

### Mind Map Routes (`/api/mindmaps`)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/mindmaps` | List mind maps |
| GET | `/api/mindmaps/{id}` | Get mind map (nodes, connections, viewpoint) |
| PUT | `/api/mindmaps/{id}` | Save mind map snapshot |

### Library Routes (`/api/library`)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/library/index/{category}` | Paginated API index |
| GET | `/api/library/details/{category}/{name}` | Fetch entity details |
| GET | `/api/library/search` | Search catalog |
| POST | `/api/library/refresh` | Refresh cache |

### Asset & Settings Routes
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/assets/images` | Upload image |
| POST | `/api/assets/pdfs` | Upload PDF |
| GET | `/api/assets/{path}` | Serve asset file |
| GET | `/api/settings` | Get settings |
| PUT | `/api/settings` | Save settings |
| GET | `/api/audio/library` | Get soundpad library |
| GET | `/api/audio/file/{path}` | Stream audio file |

### WebSocket (`/ws`)
Bidirectional event stream. Events follow existing Pydantic models in `core/network/events.py` (22 event types already defined). Server broadcasts all `EventBus.publish()` calls to connected clients.

Key real-time events:
- `entity.created`, `entity.updated`, `entity.deleted`
- `combat.hp_changed`, `combat.turn_changed`, `combat.conditions_changed`
- `battlemap.token_moved`, `battlemap.fog_updated`, `battlemap.annotation_updated`
- `projection.content_set`, `projection.mode_changed`
- `theme.changed`, `language.changed`

---

## 4. Frontend Architecture

### Tech Stack
| Concern | Library | Rationale |
|---------|---------|-----------|
| UI Framework | React 18+ TypeScript | Ecosystem, component reuse |
| Build | Vite | Fast HMR, Tauri integration |
| State | Zustand | Lightweight, no boilerplate |
| API | TanStack Query | Caching, auto-refetch |
| Real-time | Custom WebSocket hook | Matches existing EventBus |
| Canvas | react-konva (Konva.js) | Battle map layers, hit detection |
| Mind Map | react-flow | DOM nodes for rich content |
| Markdown | TipTap | Entity @mention autocomplete |
| Audio | Howler.js | Crossfade, multi-track, Web Audio |
| DnD | @dnd-kit/core | Accessible, flexible |
| CSS | Tailwind + CSS variables | Theme switching, responsive |
| Hotkeys | react-hotkeys-hook | Keyboard shortcuts |
| PDF | react-pdf (PDF.js) | Page rendering, zoom |

### Component Hierarchy
```
App.tsx
├─ CampaignSelector (login screen)
└─ MainLayout
   ├─ Toolbar (buttons, theme/lang combos)
   ├─ Sidebar (EntitySidebar — filterable list)
   ├─ TabPanel
   │  ├─ DatabaseTab → NpcSheet (8 sub-tabs)
   │  ├─ MindMapTab → react-flow canvas
   │  ├─ MapTab → world map + pins
   │  └─ SessionTab → notes + CombatTracker
   ├─ SoundpadPanel (right-side, collapsible)
   └─ PdfPanel (right-side, collapsible)

PlayerView (separate window)
├─ ImageViewer
├─ BattleMapPlayerView
├─ StatBlockViewer
├─ PdfViewer
└─ BlackScreen
```

### Zustand Store Design
```typescript
// Each store mirrors a DataManager sub-manager
entityStore     → EntityRepository methods
sessionStore    → SessionRepository methods
battleMapStore  → Battle map state (tokens, fog, grid, tools)
mindMapStore    → Mind map state (nodes, connections, undo history)
audioStore      → Soundpad state (theme, volumes, active states)
playerStore     → What player window is showing
uiStore         → Theme, sidebar visibility, panel states, edit mode
```

---

## 5. Feature Migration Matrix

| # | Feature | Current LOC | Web Library | Effort (days) | React LOC |
|---|---------|------------|-------------|---------------|-----------|
| 1 | Battle Map | 1,563 | react-konva | 15-20 | ~2,500 |
| 2 | Mind Map | 1,373 | react-flow | 12-15 | ~2,000 |
| 3 | Player Window | 447 | Tauri multi-window + WS | 8-10 | ~800 |
| 4 | Combat Tracker | ~700 | @tanstack/react-table + @dnd-kit | 8-10 | ~1,200 |
| 5 | NPC Sheet | ~1,830 | react-hook-form, react-tabs | 10-12 | ~1,800 |
| 6 | Soundpad | ~1,097 | Howler.js | 8-10 | ~1,000 |
| 7 | Session Tab | ~400 | react-markdown | 4-5 | ~600 |
| 8 | Map Tab | ~400 | react-konva or CSS positioning | 4-5 | ~600 |
| 9 | Entity Sidebar | ~350 | @dnd-kit, virtualized list | 3-4 | ~500 |
| 10 | API Browser | ~300 | TanStack Query | 3-4 | ~400 |
| 11 | Markdown Editor | 447 | TipTap | 5-6 | ~600 |
| 12 | Campaign Selector | ~100 | — | 1-2 | ~200 |
| 13 | Theme System | 333 | CSS variables + context | 3-4 | ~400 |
| 14 | PDF Panel | ~200 | react-pdf | 2-3 | ~300 |
| 15 | Dialogs | ~800 | Radix UI / Headless UI | 4-5 | ~600 |
| | **Total** | **~9,340** | | **~90-110** | **~13,500** |

---

## 6. Battle Map Migration (Detailed)

The hardest single component. Current: `ui/windows/battle_map_window.py` (1,563 LOC).

### Layer Architecture (Konva.js)
```
<Stage>                          (QGraphicsScene equivalent)
  <Layer> Map background         (QGraphicsPixmapItem, z=-100)
  <Layer> Grid overlay           (GridItem, z=50)
  <Layer> Annotation/drawing     (QImage-based, z=100)
  <Layer> Token layer            (BattleTokenItem ellipses, z=100-150)
  <Layer> Fog of war             (FogItem pixel painting, z=200)
  <Layer> Measurement overlay    (MeasurementOverlayItem, z=150)
</Stage>
```

### Fog of War — Offscreen Canvas
Current uses QImage with QPainter composition modes. Web equivalent:

```typescript
// Offscreen canvas sized to map
const fogCanvas = document.createElement('canvas');
const ctx = fogCanvas.getContext('2d')!;

// Fill black (all fog)
ctx.fillStyle = 'rgba(0, 0, 0, 1)';
ctx.fillRect(0, 0, width, height);

// REVEAL: 'destination-out' ≡ CompositionMode_Clear
ctx.globalCompositeOperation = 'destination-out';
ctx.beginPath();
ctx.moveTo(points[0].x, points[0].y);
points.forEach(p => ctx.lineTo(p.x, p.y));
ctx.fill();

// ADD FOG: 'source-over' ≡ CompositionMode_SourceOver
ctx.globalCompositeOperation = 'source-over';
ctx.fillStyle = 'rgba(0, 0, 0, 1)';
// ... draw polygon ...
```

Serialization: `fogCanvas.toDataURL('image/png')` → base64 string (same as current).

### Tokens
```typescript
<Circle
  x={token.x} y={token.y}
  radius={tokenSize / 2}
  fillPatternImage={tokenImage}   // entity portrait
  stroke={borderColor}            // attitude: green/red/gray/blue
  strokeWidth={3}
  draggable={isDmView}
  onDragEnd={(e) => {
    const pos = gridSnap ? snapToGrid(e.target.position()) : e.target.position();
    onTokenMove(token.id, pos.x, pos.y);
  }}
/>
```

### DM vs Player View
- **DM:** Full toolbar (navigate, ruler, circle, draw, fog add/erase), token drag, grid controls
- **Player:** Read-only rendering. Receives state via WebSocket `battlemap.state_update` events

---

## 7. Mind Map Migration

### Recommended: react-flow

react-flow is purpose-built for node editors. Nodes are **real React components** (not canvas elements), so embedding markdown editors, entity cards, and images works naturally.

```typescript
const nodeTypes = {
  note:      NoteNode,       // TipTap markdown editor inside
  entity:    EntityNode,     // Entity summary card inside
  image:     ImageNode,      // <img> element inside
  workspace: WorkspaceNode,  // Dashed border container
};
```

### Connections
react-flow supports bezier edges natively. Custom edge component for theme-aware colors.

### Undo/Redo
Snapshot-based history (current: 50-element array with deep copies):
```typescript
const useUndoRedo = (maxHistory = 50) => {
  const [history, setHistory] = useState<MindMapState[]>([]);
  const [index, setIndex] = useState(-1);
  // pushSnapshot, undo, redo
};
```

### LOD (Level of Detail)
react-flow has built-in zoom. At low zoom levels, switch node content to simplified view:
```typescript
const NoteNode = ({ data, selected }) => {
  const zoom = useStore(s => s.transform[2]);
  if (zoom < 0.2) return <SimplifiedNode label={data.title} />;
  if (zoom < 0.4) return <CompactNode label={data.title} preview={data.preview} />;
  return <FullNoteNode data={data} />;
};
```

---

## 8. Player/DM Screen Separation

### Desktop (Tauri)
Tauri v2 supports multiple windows. Player window opens as a second `WebviewWindow`:
```rust
// src-tauri/src/main.rs
let player_window = tauri::WebviewWindowBuilder::new(
    &app, "player", tauri::WebviewUrl::App("/player".into())
).build()?;
```

### Web
`window.open('/player', 'player_view')` opens a separate browser tab/window.

### Mobile
Mobile devices are **player-only clients**. The DM runs the full desktop app; players connect via browser to the same FastAPI backend. The `/player` route renders a touch-optimized player view.

### Communication
DM actions → WebSocket → Player window. Events:
```typescript
// DM sends via WebSocket:
{ type: "projection.content_set", payload: { mode: "battlemap" } }
{ type: "battlemap.state_update", payload: { tokens, fog_data, ... } }
{ type: "projection.content_set", payload: { mode: "image", src: "/api/assets/img.png" } }
{ type: "projection.content_set", payload: { mode: "blank" } }
```

---

## 9. Audio System Migration

### Current Architecture
- `MusicBrain` with dual `MultiTrackDeck` (A/B crossfade)
- 4 ambience slots (`AmbiencePlayer`)
- 8 SFX pool players
- QPropertyAnimation for volume crossfade (3000ms InOutCubic)

### Web Equivalent: Howler.js
```typescript
// Dual-deck crossfade
const transitionToState = (stateName: string) => {
  const inactiveHowl = new Howl({ src: [trackUrl], loop: true });
  inactiveHowl.play();
  activeHowl.fade(masterVolume, 0, 3000);   // fade out
  inactiveHowl.fade(0, masterVolume, 3000);  // fade in
  [activeDeck, inactiveDeck] = [inactiveDeck, activeDeck];
};
```

Audio files served by backend: `GET /api/audio/file/{path}` streams from `assets/soundpad/`.

---

## 10. Data Migration & Compatibility

**Zero data migration needed.** The FastAPI backend loads the same MsgPack campaign files using the same `CampaignManager.load()` code. The entire `core/` directory is copied verbatim.

Campaign structure unchanged:
```
worlds/{campaign_name}/
  ├─ data.dat          (MsgPack binary — same format)
  └─ assets/           (images, PDFs — served via /api/assets/)
```

Settings stay as JSON in cache directory. Browser-side UI state (panel sizes, tab indices) stored in `localStorage`.

---

## 11. Build & Deployment

### Desktop (Tauri v2)
```
dungeon-master-tool-v2/
  src-tauri/
    Cargo.toml
    tauri.conf.json    (windows, sidecar, permissions)
    src/main.rs        (launch FastAPI sidecar, configure webview)
  src/                 (React app — Vite build)
  backend/             (FastAPI — bundled as PyInstaller sidecar)
```

Tauri launches the FastAPI executable as a **sidecar process**. React connects to `http://localhost:{port}`.

Build output: `.msi` (Windows), `.dmg` (Mac), `.AppImage` (Linux) — each ~50-60MB (Tauri ~5MB + PyInstaller sidecar ~50MB).

### Mobile
- **Tauri Mobile (v2):** Android/iOS via native WebView. Backend runs on DM's desktop; mobile connects over network.
- **Capacitor (fallback):** If Tauri Mobile is unstable, Capacitor wraps the same React app.
- Mobile clients are **player-only** — no local backend, connect to DM's server.

### Web
Static React SPA served by FastAPI:
```python
app.mount("/", StaticFiles(directory="dist", html=True))
```
Deploy as Docker container or systemd service.

---

## 12. Development Workflow

### Hot Reload
```bash
# Terminal 1: Backend
uvicorn server:app --reload --port 8765

# Terminal 2: Frontend (Vite HMR)
npm run dev  # localhost:5173, proxy /api → :8765

# Terminal 3: Tauri dev (optional)
cargo tauri dev  # WebView points to Vite dev server
```

### Testing
| Layer | Tool | Scope |
|-------|------|-------|
| Backend | pytest | Existing tests + FastAPI TestClient |
| Frontend | Vitest + RTL | Component unit tests |
| E2E | Playwright | Full stack integration |

---

## 13. Migration Phases

### Phase 0: Skeleton (Week 1-2)
- Initialize Tauri v2 + React + Vite
- Set up FastAPI with health check
- Copy `core/` into backend
- Implement campaign routes
- Build CampaignSelector component
- **Deliverable:** App that lists, creates, loads campaigns

### Phase 1: Data Layer + CRUD (Week 3-5)
- Entity routes + WebSocket broadcasting
- EntitySidebar (search, filter, drag source)
- NpcSheet (8-tab editor)
- Session routes + SessionTab
- Settings routes + theme system (CSS variables)
- Asset upload/serve
- MarkdownEditor with @mention
- **Deliverable:** Full entity management, session notes, themes

### Phase 2: Medium Features (Week 6-8)
- MapTab (world map + pins)
- API Browser (D&D 5e fetch + import)
- PDF Panel (collapsible right-side viewer)
- ImageGallery, dialogs
- Keyboard shortcuts
- **Deliverable:** Feature parity for medium features

### Phase 3: Complex Features (Week 9-14)
- **Battle Map** (2-3 weeks): Konva.js canvas, tokens, fog, grid, tools, DM↔player sync
- **Combat Tracker** (1-2 weeks): table, HP bars, conditions, initiative, encounters
- **Mind Map** (2 weeks): react-flow, node types, connections, undo/redo, LOD
- **Soundpad** (1 week): Howler.js engine, 3-tab panel, crossfade
- **Player Window** (1 week): Tauri multi-window, WebSocket content switching
- **Deliverable:** Full feature parity

### Phase 4: Polish + Mobile (Week 15-18)
- E2E tests (Playwright)
- Performance optimization (virtual lists, canvas caching)
- Mobile-responsive player view
- Tauri Mobile / Capacitor build
- Documentation
- **Deliverable:** Production-ready, desktop + mobile

---

## 14. Risk Assessment

### High Risk
| Risk | Mitigation |
|------|-----------|
| Fog of war performance on large maps (4000x4000+) | Limit fog resolution to 2048px, use offscreen canvas, profile early |
| Konva.js feature gap vs QGraphicsScene | Prototype battle map first (Phase 3 week 1), fall back to Pixi.js if needed |
| Tauri sidecar adds ~50MB to bundle | Accept for desktop; mobile is player-only (no sidecar) |
| Audio crossfade timing differences | Use Howler.js `fade()` with requestAnimationFrame, test with real music |

### Medium Risk
| Risk | Mitigation |
|------|-----------|
| Rich content in mind map react-flow nodes | Prototype early; if problematic, use side-panel editing |
| Web can't place windows on specific monitors | Tauri multi-window API for desktop; web users drag manually |
| Theme parity (11 themes, ~80 vars each) | Generate CSS variable files from `ThemeManager.PALETTES` programmatically |

### Low Risk
| Risk | Mitigation |
|------|-----------|
| i18n migration | react-i18next, import existing locale YAML files |
| PDF viewing | react-pdf (PDF.js) is mature |
| File dialogs | Tauri `@tauri-apps/plugin-dialog`; web fallback `<input type="file">` |

---

## 15. Current Codebase — What Stays, What Changes

### Copied Verbatim (core/ → backend/core/)
```
core/models.py
core/locales.py
core/library_fs.py
core/data_manager.py
core/entity_repository.py
core/session_repository.py
core/campaign_manager.py
core/library_manager.py
core/settings_manager.py
core/event_bus.py
core/theme_manager.py
core/api/*.py (7 files)
core/network/*.py (2 files)
core/audio/loader.py
core/audio/models.py
config.py
```

### Needs Abstraction (1 file)
```
core/audio/engine.py → Extract AudioBackend ABC (QMediaPlayer → backend stays for dev testing)
```

### Replaced by React (53 files — NOT deleted, kept for reference)
```
ui/**/*.py              → src/features/**/*.tsx
ui/widgets/**/*.py      → src/components/**/*.tsx
ui/tabs/**/*.py         → src/features/**/*.tsx
ui/dialogs/**/*.py      → src/components/dialogs/**/*.tsx
ui/windows/**/*.py      → src/features/battlemap/**/*.tsx
ui/main_root.py         → src/App.tsx
ui/campaign_selector.py → src/features/campaign/CampaignSelector.tsx
ui/soundpad_panel.py    → src/features/audio/SoundpadPanel.tsx
ui/pdf_panel.py         → src/components/PdfPanel.tsx
main.py                 → src-tauri/src/main.rs + backend/server.py
```
