# Pre-Online Requirements — Dungeon Master Tool

> **Document Status:** Active
> **Last Updated:** 2026-03-22
> **Supersedes:** `docs/archive/PRE_ONLINE_COMMUNITY_DEVELOPER_GUIDE.md`
> **Companion Document:** `docs/PRE_ONLINE_SPRINT.md` (sprint breakdown)
> **Scope:** All work that must be complete before the online infrastructure phase begins (Phase 1, Sprint 3)

---

## Table of Contents

1. [Scope and Definition](#1-scope-and-definition)
2. [Stability Gate — Definition of Pre-Online Ready](#2-stability-gate--definition-of-pre-online-ready)
3. [Mandatory UI/UX Tasks](#3-mandatory-uiux-tasks)
4. [EventManager Architecture](#4-eventmanager-architecture)
5. [Advanced Offline Features](#5-advanced-offline-features)
6. [Risk Register](#6-risk-register)

---

## 1. Scope and Definition

### What Is "Pre-Online"?

The pre-online phase encompasses every improvement, refactoring, and feature that must be completed while the application is still **offline-only**. The goal is to establish a stable, polished foundation so that the online transition (Sprints 3–8) introduces only one new variable at a time: the network layer.

Going online with a fragile or inconsistent UI, without the EventManager abstraction, or without the embedded viewer capabilities would create a compounding risk: every online bug would be difficult to distinguish from a pre-existing UI bug.

### What "Pre-Online Ready" Means

The application is pre-online ready when:

1. The offline feature set is **complete** — no known P1 bugs, all core workflows functional
2. The UI is **consistent** — visual polish, standardized controls, no jarring layout differences between tabs
3. The **EventManager** abstraction is in place — all state mutations flow through it; the network bridge can be bolted on without restructuring UI code
4. **Embedded viewers** are operational — PDFs and remote images can be displayed without launching an external browser
5. The **socket client skeleton** exists — connection/disconnection state is tracked, ready for Phase 1 auth
6. The codebase meets the **readability baseline** — imports organized, critical docstrings in place, no Turkish comments (see `docs/READABILITY_CONCEPT.md`)

### Relationship to Other Documents

| Document | Relationship |
|---|---|
| `docs/PRE_ONLINE_SPRINT.md` | Sprint-level execution plan for all pre-online tasks |
| `docs/ONLINE.md` | Architecture of what comes after; pre-online work directly enables it |
| `docs/READABILITY_CONCEPT.md` | Readability tasks that run in parallel during pre-online phase |

---

## 2. Stability Gate — Definition of Pre-Online Ready

All of the following criteria must be met before Phase 1 (Sprint 3) begins:

### Functional Gates

- [ ] All 7 Mandatory UI/UX tasks (Section 3) merged and verified
- [ ] EventManager local dispatch fully operational (Section 4)
- [ ] Socket.io client skeleton integrated with connection state machine
- [ ] Embedded PDF viewer operational (local files + remote URLs)
- [ ] No known Priority 1 (crash or data loss) bugs open

### Quality Gates

- [ ] Test coverage ≥ 60% on `core/` modules
- [ ] `ruff` linting passes on all core files (no violations)
- [ ] All Turkish comments removed from core files
- [ ] Module docstrings added to all `core/` files

### Localization Gates

- [ ] All new UI strings added to EN/TR/DE/FR locale files
- [ ] No hardcoded English strings in UI widgets (all via `tr()`)
- [ ] All 4 locales tested against the updated UI

---

## 3. Mandatory UI/UX Tasks

These seven tasks are **hard blockers** for the online phase. They must be completed in Sprint 1–2.

---

### Task 1: GM Player Screen Control Panel

**Priority:** CRITICAL
**Status:** In Progress (Sprint 1)

**Description:**
The DM must be able to control what the player-facing projection window shows — switching between map view, entity cards, and images — from within the main DM interface. Currently, the player window is controlled indirectly through context menus, making the workflow confusing and slow during live sessions.

**Requirements:**
- A dedicated control panel (sidebar or floating toolbar) in the DM's main window
- Quick-switch buttons: Map View | Entity Card | Image | Blank Screen
- Live preview thumbnail of what the player window currently shows
- "Lock" toggle — prevents accidental changes to the player window during session
- Keyboard shortcut support for all switching actions (configurable)

**Acceptance Criteria:**
- DM can switch player window content in under 2 seconds without using context menus
- Lock state persists across session save/restore
- Control panel is accessible from all 4 main tabs

---

### Task 2: Single Player Screen Window

**Priority:** CRITICAL
**Status:** Planned

**Description:**
Currently, the battle map window and the projection/player window are separate windows that can be positioned independently. This creates confusion: which window is "the player screen"? The player screen must be a single, unified window that the DM positions on the second monitor.

**Requirements:**
- Merge the projection window and the battle map display into one unified `PlayerWindow`
- The `PlayerWindow` has two modes: **Map Mode** (battle map with optional fog) and **Content Mode** (entity cards, images, PDFs)
- DM controls which mode is active via the GM Screen Control Panel (Task 1)
- Window remembers position/size/monitor assignment across restarts
- Full-screen mode support with single keystroke

**Acceptance Criteria:**
- There is exactly one secondary window that the DM opens for the player display
- All content types (map, images, stat blocks, PDFs) can be displayed in that one window
- Switching modes does not cause window flickering or repositioning

---

### Task 3: Auto Event Log During Combat

**Priority:** HIGH
**Status:** Planned

**Description:**
During combat, significant events (damage dealt, conditions applied, creature death, initiative changes) should be automatically recorded in a scrollable event log visible to the DM. This replaces the need for manual note-taking during high-speed combat.

**Requirements:**
- Auto-log panel embedded in the combat tracker or as a side panel
- Events logged automatically: HP changes (with amount and source), condition apply/remove, combatant add/remove, turn advance, death saves
- DM can add freeform notes to the log during combat
- Log is append-only (no editing past entries)
- Log persists with the session save file
- Optional: filter log by combatant or event type

**Acceptance Criteria:**
- Every HP change in combat tracker is reflected in the event log within 100ms
- Log survives application restart when loaded with the same session
- DM can export the log as plain text

---

### Task 4: Free Single Import (Spell/Item to Character)

**Priority:** HIGH
**Status:** Planned

**Description:**
Currently, importing a spell or item to a character requires first importing it into the campaign database, then linking it to the character. This is a friction-heavy two-step process for quick lookups. A "free import" allows the DM to attach an Open5e entity directly to a character sheet without it persisting in the campaign database.

**Requirements:**
- "Quick Link" button on NPC/PC sheet that opens the API browser in single-select mode
- The selected entity is linked to the sheet (for the session) without being saved to the campaign database
- Quick-linked entities are stored in the session file but clearly marked as "temporary" / "not in library"
- DM can promote a quick-linked entity to the full library with one click
- On session reload, quick-linked entities are restored (fetched from API cache if available, re-fetched if not)

**Acceptance Criteria:**
- DM can link a spell to a character in under 10 seconds from a blank state
- Quick-linked entities render identically to full-library entities on the character sheet
- Temporary entities are visually distinguished from library entities in the link list

---

### Task 5: Embedded PDF Viewer

**Priority:** HIGH
**Status:** In Progress (Sprint 2)

**Description:**
The DM tool currently opens PDFs in the system's default PDF viewer, which breaks focus during sessions. An embedded viewer allows PDFs to be displayed both in the DM's reference panel and pushed to the player window.

**Requirements:**
- In-app PDF viewer supporting local file paths and remote URLs (HTTP/HTTPS)
- Navigation: next/previous page, page number jump, fit-width/fit-page zoom
- Bookmarks panel (extracted from PDF metadata if available)
- Can be sent to the Player Window (player sees current page, DM controls)
- Supports drag-and-drop of `.pdf` files onto the viewer area

**Technical Notes:**
- Use `PyMuPDF` (`fitz`) for rendering — produces high-quality page images at any zoom
- Render each page as a `QPixmap` and display in a `QScrollArea`
- For remote URLs, download to a temp cache file first (streaming for large files)

**Acceptance Criteria:**
- A 50-page rulebook PDF opens within 2 seconds (local file)
- Page rendering at 150% zoom produces legible text without blurriness
- DM can send the current page to the player window; player sees it within 500ms (local)

---

### Task 6: UI Standardization

**Priority:** MEDIUM
**Status:** In Progress (Sprint 1)

**Description:**
Button sizes, font sizes, spacing, and widget styles are inconsistent across the four main tabs and various dialogs. This makes the application feel unpolished and increases DM cognitive load during sessions.

**Requirements:**

**Button Standardization:**
- Primary action buttons: `height: 32px`, `min-width: 80px`, `border-radius: 4px`
- Icon-only buttons: `24×24px` or `32×32px` (two standard sizes)
- Danger actions (Delete, Clear): red accent, requires double-click confirmation

**Typography:**
- Section headers: 13pt semi-bold
- Body text / field labels: 11pt regular
- Monospace fields (dice expressions, ID fields): 10pt monospace

**Layout:**
- Consistent panel padding: 8px inner, 4px between controls
- Tab content area: minimum 400px width before scrollbars appear
- Dialog minimum size: 480×320px

**Spacing:**
- All spacing values must be multiples of 4px
- Consistent separator line weight (1px) and color (theme border color)

**Acceptance Criteria:**
- All 4 main tabs pass a visual review confirming consistent button sizes
- No hardcoded color values in widget code (all via theme palette)
- UI looks visually coherent at 100%, 125%, and 150% DPI scaling

---

### Task 7: Soundpad Transition Smoothing

**Priority:** MEDIUM
**Status:** Planned

**Description:**
Currently, switching audio tracks in the soundpad causes an abrupt cut or pop. Smooth crossfades between tracks are expected for a professional DM tool and make session atmosphere management feel less jarring.

**Requirements:**
- Configurable crossfade duration: 0ms (instant), 500ms, 1000ms, 2000ms (default: 1000ms)
- Crossfade applies when: switching active theme, changing intensity level, manually triggering a new track
- Fade-out on session end (2 seconds)
- Volume levels during crossfade follow a constant-power curve (not linear, to avoid perceived loudness dip)
- Crossfade setting persists in user preferences

**Acceptance Criteria:**
- No audible click or pop when switching between any two audio tracks
- Crossfade timing matches the configured duration (within ±100ms)
- Constant-power curve is visually verifiable with a sine/cosine fade shape

---

## 4. EventManager Architecture

The EventManager is the single most important architectural addition in the pre-online phase. It creates a clean separation between the data layer (`DataManager`), the UI layer (tabs and widgets), and the network layer (to be added in Phase 1). Without it, the online integration requires invasive surgery on every UI widget.

### 4.1 Design Rationale

**Problem:** Currently, `DataManager` is called directly by UI components, and UI components call each other directly. There is no single place where "something changed" events can be intercepted and forwarded to a WebSocket.

**Solution:** Every state mutation emits a named event through `EventManager`. UI components subscribe to events they care about. The network bridge (Sprint 2 skeleton, Sprint 3 full implementation) subscribes to the same events and forwards them to the server.

```
Current flow:
  UI Widget ──direct call──> DataManager ──signal──> Other UI Widget

Target flow:
  UI Widget ──call──> DataManager ──emits event──> EventManager
                                                        │
                                               ┌────────┴──────────┐
                                               ▼                   ▼
                                          UI Widgets         Network Bridge
                                        (subscribe)         (subscribe, sends WS)
```

### 4.2 EventManager Interface

```python
# core/event_manager.py

from typing import Any, Callable

EventPayload = dict[str, Any]
EventHandler = Callable[[EventPayload], None]

class EventManager:
    """Central event bus decoupling DataManager, UI, and network layers.

    All state mutations in DataManager emit a named event through this bus.
    UI components and the network bridge subscribe to the events they care about.

    In offline mode, events are dispatched synchronously.
    In online mode, the NetworkBridge subscribes and forwards events to the server.
    """

    def emit(self, event_type: str, payload: EventPayload) -> None:
        """Emit a named event to all registered handlers."""

    def subscribe(self, event_type: str, handler: EventHandler) -> None:
        """Register a callback to be invoked when event_type is emitted."""

    def unsubscribe(self, event_type: str, handler: EventHandler) -> None:
        """Deregister a previously registered handler."""

    def subscribe_all(self, handler: EventHandler) -> None:
        """Register a catch-all handler invoked for every event (used by network bridge)."""
```

### 4.3 Event Catalogue (Phase 0 — Local Events)

These are the events that must be emitted during the pre-online phase. The network bridge will forward a subset of these to the server in Phase 1.

#### Campaign Events

| Event Type | Trigger | Payload Keys |
|---|---|---|
| `campaign.loaded` | Campaign folder opened | `campaign_path`, `world_name` |
| `campaign.saved` | Campaign saved to disk | `campaign_path` |
| `campaign.closed` | Campaign unloaded | — |

#### Entity Events

| Event Type | Trigger | Payload Keys |
|---|---|---|
| `entity.created` | New entity added | `entity_id`, `entity_type`, `name` |
| `entity.updated` | Entity fields modified | `entity_id`, `changed_fields` |
| `entity.deleted` | Entity removed | `entity_id`, `entity_type` |

#### Session Events

| Event Type | Trigger | Payload Keys |
|---|---|---|
| `session.created` | New session started | `session_id`, `session_name` |
| `session.activated` | Existing session made active | `session_id` |
| `session.combatant_added` | Combatant joins combat | `session_id`, `combatant_id`, `name` |
| `session.combatant_updated` | HP/conditions changed | `session_id`, `combatant_id`, `changes` |
| `session.turn_advanced` | Turn order advances | `session_id`, `new_active_combatant_id` |

#### Map Events

| Event Type | Trigger | Payload Keys |
|---|---|---|
| `map.image_set` | Map background image changed | `image_path` |
| `map.fog_updated` | Fog-of-war mask changed | `fog_data` (serialized) |
| `map.pin_added` | Map pin created | `pin_id`, `x`, `y`, `label` |
| `map.pin_removed` | Map pin deleted | `pin_id` |

#### Mind Map Events

| Event Type | Trigger | Payload Keys |
|---|---|---|
| `mindmap.node_created` | Node added to mind map | `map_id`, `node_id`, `label`, `x`, `y` |
| `mindmap.node_updated` | Node moved or edited | `map_id`, `node_id`, `changes` |
| `mindmap.node_deleted` | Node removed | `map_id`, `node_id` |
| `mindmap.edge_created` | Connection between nodes | `map_id`, `edge_id`, `source_id`, `target_id` |
| `mindmap.edge_deleted` | Connection removed | `map_id`, `edge_id` |

#### Projection Events

| Event Type | Trigger | Payload Keys |
|---|---|---|
| `projection.content_set` | Player window content changed | `content_type`, `content_ref` |
| `projection.mode_changed` | Map ↔ Content mode switch | `mode` (`map` or `content`) |

#### Audio Events

| Event Type | Trigger | Payload Keys |
|---|---|---|
| `audio.state_changed` | Theme, intensity, or volume changed | `theme`, `intensity`, `master_volume` |
| `audio.track_triggered` | Soundpad button pressed | `track_id`, `track_name` |

### 4.4 DataManager Integration

`DataManager` must be updated to call `EventManager.emit()` on all state-mutating methods. The EventManager instance is passed to DataManager at construction time (dependency injection, not singleton):

```python
class DataManager:
    def __init__(self, event_manager: EventManager) -> None:
        self._events = event_manager

    def save_entity(self, entity_id: str, data: EntityDict) -> None:
        """Save entity and emit update event."""
        # ... existing save logic ...
        self._events.emit("entity.updated", {
            "entity_id": entity_id,
            "changed_fields": list(data.keys()),
        })
```

### 4.5 UI Widget Integration

UI widgets subscribe to events in their `__init__` or setup method and unsubscribe in their `closeEvent`:

```python
class DatabaseTab(QWidget):
    def __init__(self, event_manager: EventManager) -> None:
        super().__init__()
        self._events = event_manager
        self._events.subscribe("entity.updated", self._on_entity_updated)
        self._events.subscribe("entity.deleted", self._on_entity_deleted)

    def _on_entity_updated(self, payload: EventPayload) -> None:
        entity_id = payload["entity_id"]
        self._refresh_entity_row(entity_id)

    def closeEvent(self, event: QCloseEvent) -> None:
        self._events.unsubscribe("entity.updated", self._on_entity_updated)
        self._events.unsubscribe("entity.deleted", self._on_entity_deleted)
        super().closeEvent(event)
```

### 4.6 Network Bridge Hook (Sprint 2 Skeleton)

The network bridge subscribes to all events and forwards those tagged for online sync:

```python
ONLINE_EVENTS = {
    "entity.updated", "entity.deleted", "entity.created",
    "session.combatant_updated", "session.turn_advanced",
    "map.fog_updated", "map.pin_added", "map.pin_removed",
    "mindmap.node_created", "mindmap.node_updated", "mindmap.node_deleted",
    "projection.content_set",
    "audio.state_changed",
}

class NetworkBridge:
    def __init__(self, event_manager: EventManager) -> None:
        self._events = event_manager
        self._events.subscribe_all(self._on_any_event)

    def _on_any_event(self, event_type: str, payload: EventPayload) -> None:
        if event_type not in ONLINE_EVENTS:
            return
        if not self._is_connected():
            self._queue_for_resync(event_type, payload)
            return
        self._send_to_server(event_type, payload)
```

---

## 5. Advanced Offline Features

These features extend the offline capability of the application and are valuable both standalone and as the foundation for future online features. They are **not hard blockers** for the online phase but should be completed during the pre-online period to avoid deferred technical debt.

### Initiative A: Dynamic Card & World Templates

**Purpose:** Allow DMs to create custom entity categories with user-defined fields. A "Faction" card in a science-fiction campaign needs different fields than a D&D NPC.

#### 5.1 Dynamic Field System

Every entity type should support user-defined fields in addition to the built-in schema. Supported field types:

| Field Type | Description | Example Use |
|---|---|---|
| `text` | Single-line string | Character title, faction motto |
| `markdown` | Multi-line rich text | Backstory, description |
| `integer` | Whole number | Level cap, allegiance score |
| `float` | Decimal number | Initiative modifier (precise) |
| `boolean` | Yes/No toggle | Is this NPC a recurring villain? |
| `enum` | Dropdown from a defined list | Alignment, rarity, size |
| `date` | Campaign date | Date of death, treaty signing |
| `image` | Image file reference | Secondary portrait |
| `file` | Any file attachment | Reference PDF |
| `relation` | Link to another entity | "Reports to: [entity_id]" |
| `formula` | Computed from other fields | `"{STR} + {level} / 2"` |

**Field Definition Schema:**

```json
{
  "field_id": "allegiance_score",
  "label": "Allegiance Score",
  "type": "integer",
  "default": 0,
  "min": -100,
  "max": 100,
  "required": false,
  "visible_on_card": true,
  "visible_in_encounter_table": true,
  "group": "Relationships"
}
```

#### 5.2 World Template Packaging

DMs should be able to package their custom entity schemas, world settings, and starter data into a `.dmt-template` file for sharing via the Community Wiki (Initiative C).

**Template file format** (ZIP archive with `.dmt-template` extension):

```
my-template.dmt-template
├── manifest.json           # Package metadata
├── schemas/
│   ├── npc_schema.json     # Custom entity type definitions
│   ├── faction_schema.json
│   └── ...
├── world_settings.json     # Default world name, calendar system, etc.
├── starter_data/
│   └── ...                 # Optional example entities
└── assets/
    └── ...                 # Optional icon/image assets
```

**Manifest schema:**
```json
{
  "package_id": "com.example.my-campaign-world",
  "title": "Steampunk Adventures",
  "author": "DM Username",
  "version": "1.0.0",
  "app_version_min": "0.8.0",
  "license": "CC-BY-SA-4.0",
  "tags": ["steampunk", "homebrew", "sci-fi"],
  "description": "Custom schemas for a steampunk campaign world."
}
```

#### 5.3 Migration Layer

When a template changes field definitions, existing campaign data must be migrated without data loss:

- Adding new fields: set to `default` value for all existing entities
- Removing fields: field value is preserved in an `_archived_fields` dict (not deleted)
- Changing field type: attempt coercion; on failure, move original value to `_archived_fields`

All migrations are logged to a `migration_report.json` in the campaign folder.

---

### Initiative B: Advanced Battlemap

**Purpose:** Expand the battle map beyond single-image fog-of-war to support multi-grid types, measurement, and annotation.

#### 5.4 Multi-Grid Support

| Grid Type | Description |
|---|---|
| `none` | No grid overlay (use background image grid) |
| `square` | Standard square grid with configurable cell size |
| `hex_pointy` | Hexagonal grid, pointy-top orientation |
| `hex_flat` | Hexagonal grid, flat-top orientation |
| `isometric` | Diamond grid for isometric maps |

Grid configuration is stored per-battlemap and persists across sessions:
```json
{
  "grid_type": "hex_pointy",
  "cell_size_px": 40,
  "unit_name": "ft",
  "units_per_cell": 5,
  "grid_color": "#ffffff",
  "grid_opacity": 0.3,
  "origin_x": 0,
  "origin_y": 0
}
```

#### 5.5 Measurement Tools

- **Ruler:** Click-drag to measure distance; displays in configured units (ft, m, squares)
- **Cone:** Defined by origin point + angle + length
- **Circle/Sphere:** Defined by center + radius
- **Line:** Defined by two points, width configurable (for line AoE spells)
- All measurements snap to grid when grid is active

#### 5.6 Drawing Layer

A persistent drawing layer sits above the map image but below tokens:

- **Tools:** Freehand pen, straight line, rectangle, ellipse, arrow, text annotation
- **Styling:** Stroke color, fill color, line width, opacity
- **Undo/Redo:** Full undo history (per session, not persisted across restarts)
- **Visibility:** DM-only drawings vs. shared drawings (shared are visible on player window)
- **Layers:** At minimum: DM layer (hidden from players), shared layer (visible to all)

#### 5.7 Persistent Battlemap Configuration

All battlemap settings (grid, drawing layer contents, fog state, image path) are saved in the campaign's map data JSON. When a session is saved and reloaded, the map is fully restored — including DM-only drawings.

---

### Initiative C: Community Wiki & Package Standards

**Purpose:** Enable the community to create, share, and install world templates, asset packs, and content packages through a moderated package registry.

#### 5.8 Package Types

| Package Type | Contents | File Extension |
|---|---|---|
| `template` | Entity schemas + world settings | `.dmt-template` |
| `world` | Full starter campaign (schema + entities + some assets) | `.dmt-world` |
| `asset-pack` | Images, audio files | `.dmt-assets` |
| `ruleset` | System-specific entity schemas + SRD data | `.dmt-ruleset` |

#### 5.9 Package Safety Requirements

Before any package is importable:

1. **Checksum validation** — SHA-256 hash in manifest must match actual file
2. **File type whitelist** — Only these file types permitted inside packages:
   - Images: `.png`, `.jpg`, `.webp`, `.svg`
   - Audio: `.mp3`, `.ogg`, `.wav`, `.flac`
   - Data: `.json`, `.yaml`
   - Documents: `.pdf`, `.md`
3. **No executable files** — `.py`, `.exe`, `.sh`, `.bat` are rejected unconditionally
4. **Import preview** — DM sees a summary of what will be added before confirming
5. **Sandbox isolation** — Package assets are copied to a quarantine folder before integration

#### 5.10 Package Metadata Standard

```json
{
  "package_id": "com.example.package",
  "package_type": "template",
  "title": "Package Title",
  "author": "Author Name",
  "author_url": "https://example.com",
  "version": "1.2.0",
  "app_version_min": "0.8.0",
  "app_version_max": null,
  "license": "CC-BY-4.0",
  "tags": ["fantasy", "homebrew"],
  "description": "Short description of the package.",
  "checksum_sha256": "abc123...",
  "created_at": "2026-01-15T00:00:00Z",
  "updated_at": "2026-03-01T00:00:00Z"
}
```

#### 5.11 Moderation Foundation

For future online moderation support:

| Status | Meaning |
|---|---|
| `draft` | Uploaded but not publicly visible |
| `published` | Approved and publicly searchable |
| `flagged` | Under review due to user reports |
| `deprecated` | Still installable, but marked as outdated |
| `removed` | Delisted; existing installs unaffected |

---

## 6. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Single Player Window merge breaks existing fog-of-war behavior | MEDIUM | HIGH | Add regression tests for fog state before merging windows; feature-flag the new window |
| EventManager introduces performance overhead on high-frequency events | LOW | MEDIUM | Benchmark event dispatch with 100 events/second during combat; add batching if needed |
| PDF viewer (`PyMuPDF`) has large binary footprint in installer | MEDIUM | MEDIUM | Measure installer size impact; consider optional install or bundling only the library |
| Soundpad crossfade causes desync between audio layers | MEDIUM | MEDIUM | Implement constant-power crossfade with automated timing test |
| Dynamic field migration corrupts existing campaign data | LOW | CRITICAL | Mandatory backup before migration; migration is a copy-on-write operation |
| Community package with malicious filenames escapes sandbox | LOW | HIGH | Strict path traversal checks; only accept flat or explicitly whitelisted directory structures |
| Sprint 2 socket skeleton delays if PyMuPDF integration overruns | MEDIUM | MEDIUM | PDF viewer and socket skeleton are independent; parallelize if needed |

---

## Appendix A: Pre-Online Task Status Tracker

| Task | Sprint | Assignee | Status |
|---|---|---|---|
| GM Player Screen Control Panel | 1 | — | In Progress |
| UI Button Standardization | 1 | — | In Progress |
| EventManager local dispatch | 1 | — | In Progress |
| Single Player Screen Window | 2 | — | Planned |
| Embedded PDF Viewer | 2 | — | Planned |
| Socket.io client skeleton | 2 | — | Planned |
| Event schema v1 | 2 | — | Planned |
| Auto Event Log | Post-Sprint 2 | — | Backlog |
| Free Single Import | Post-Sprint 2 | — | Backlog |
| Soundpad Transition Smoothing | Post-Sprint 2 | — | Backlog |
| Dynamic Card & World Templates | Post-Sprint 2 | — | Backlog |
| Advanced Battlemap | Post-Sprint 2 | — | Backlog |
| Community Wiki Foundation | Post-Sprint 2 | — | Backlog |
