# Dungeon Master Tool --- Pre-Online Development Guide

> **Document version:** 2.0
> **Date:** March 18, 2026
> **Language:** English
> **Classification:** Internal Development Reference
> **Scope:** Complete specification of all offline/preparation-phase work required before full online rollout
> **Supersedes:** `docs/PRE_ONLINE_COMMUNITY_DEVELOPER_GUIDE.md` (v1.0, March 17, 2026)
> **Related documents:**
> - `docs/DEVELOPMENT_REPORT.md` --- Online Transition Architecture Report
> - `docs/PRE_ONLINE_COMMUNITY_DEVELOPER_GUIDE.md` --- Original community guide (now a summary subset of this document)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current State Assessment](#2-current-state-assessment)
3. [Pre-Online Objectives](#3-pre-online-objectives)
4. [Initiative A: UI/UX Standardization](#4-initiative-a-uiux-standardization)
5. [Initiative B: Card and World Template System](#5-initiative-b-card-and-world-template-system)
6. [Initiative C: Advanced Battlemap Development](#6-initiative-c-advanced-battlemap-development)
7. [Initiative D: Community Wiki and Content Sharing](#7-initiative-d-community-wiki-and-content-sharing)
8. [Initiative E: Audio System Improvements](#8-initiative-e-audio-system-improvements)
9. [Initiative F: Auto Event Log System](#9-initiative-f-auto-event-log-system)
10. [Initiative G: Embedded PDF Viewer](#10-initiative-g-embedded-pdf-viewer)
11. [Initiative H: Free Single Import](#11-initiative-h-free-single-import)
12. [Initiative I: Code Quality Foundations](#12-initiative-i-code-quality-foundations)
13. [Dependency Graph](#13-dependency-graph)
14. [Quality Gates](#14-quality-gates)
15. [Risk Register](#15-risk-register)
16. [Expected Outcomes](#16-expected-outcomes)

---

## 1. Executive Summary

### 1.1 Purpose of This Document

This document is the authoritative, comprehensive specification for all development work that must be completed **before** the Dungeon Master Tool transitions to online multiplayer capability. It expands significantly on the original `PRE_ONLINE_COMMUNITY_DEVELOPER_GUIDE.md`, adding full technical depth, architectural guidance, data model schemas, UI/UX specifications, code quality mandates, and project management structure to each initiative.

The online transition --- as detailed in `docs/DEVELOPMENT_REPORT.md` --- involves evolving the application from a single-user offline desktop tool into a hybrid client-server platform with real-time synchronization, role-based access, and asset distribution. That transition cannot succeed on top of the current codebase without significant preparatory work. This document defines that preparatory work.

### 1.2 What Must Be Done

Nine initiatives have been identified, spanning product features, infrastructure improvements, and code quality foundations:

| ID | Initiative | Category |
|----|-----------|----------|
| A | UI/UX Standardization | Infrastructure |
| B | Card and World Template System | Product Feature |
| C | Advanced Battlemap Development | Product Feature |
| D | Community Wiki and Content Sharing | Product Feature |
| E | Audio System Improvements | Product Feature |
| F | Auto Event Log System | Product Feature |
| G | Embedded PDF Viewer | Product Feature |
| H | Free Single Import | Product Feature |
| I | Code Quality Foundations | Infrastructure |

### 1.3 Why This Matters

The online system will introduce WebSocket event routing, REST API endpoints, role-based content visibility, and real-time state synchronization. Every component that participates in online communication must:

1. Have clean, well-typed interfaces for serialization.
2. Emit structured events rather than relying on tightly-coupled Qt signals.
3. Use consistent UI patterns that can adapt to both DM and Player rendering modes.
4. Store data in schema-driven, versioned formats that can be transmitted over the network.
5. Follow English naming conventions and structured logging for operational observability.

If these foundations are not established first, the online integration will be forced to work around legacy patterns, leading to compounding technical debt, fragile synchronization logic, and a degraded user experience.

### 1.4 Scope Boundaries

**In scope:**
- All nine initiatives described in this document
- Changes to existing source files, data models, and UI components
- New modules and packages required to support these initiatives
- Test coverage for all new and modified functionality
- Migration tooling for existing campaign data

**Out of scope:**
- Server-side infrastructure (FastAPI, Redis, PostgreSQL, MinIO)
- Network layer implementation (WebSocket, REST API)
- Authentication and authorization systems
- Deployment and operations tooling
- Mobile or web client development

### 1.5 Success Criteria (Program Level)

The pre-online phase is considered complete when **all** of the following are true:

1. All nine initiatives have passed their individual Definition of Done (see each section).
2. All existing campaigns load correctly through the migration layer with zero data loss.
3. The application has zero `print()` statements in production code (replaced by structured logging).
4. All Python source files have type hints on public function signatures.
5. All source code comments and variable names are in English.
6. The test suite passes with no failures and covers all critical paths.
7. UI layouts are consistent across all windows and dialogs when tested at 1280x720, 1920x1080, and 2560x1440 resolutions.
8. The battlemap performs at 60fps with maps up to 4096x4096 pixels with 50 tokens.
9. A complete world template can be exported, transferred to another machine, and imported without errors.

---

## 2. Current State Assessment

### 2.1 Codebase Health Snapshot

| Metric | Value | Assessment |
|--------|-------|------------|
| Language | Python 3.10+ | Adequate |
| GUI Framework | PyQt6 | Adequate |
| Total source files | 56 Python files | Moderate size |
| Total lines of code | ~11,500 | Manageable |
| Test files | 12 files (~850 lines) | **Insufficient** --- roughly 7% test coverage |
| Entity types | 15 hardcoded types | **Rigid** --- must become dynamic |
| Data format | MsgPack primary, JSON fallback | Adequate but needs schema versioning |
| Theme system | 11 QSS themes + ThemeManager palette | Good foundation, but inline CSS exists |
| Localization | 4 languages (EN, TR, DE, FR) via python-i18n | Adequate |
| Audio engine | MusicBrain (layered, multi-track) | Functional but lacks transitions |
| Battlemap | Single grid mode (square), fog of war, tokens | **Needs significant expansion** |
| `__init__.py` files | Only 2 exist (`core/audio/`, `core/dev/`) | **Missing** in `core/`, `ui/`, `ui/tabs/`, `ui/widgets/`, `ui/dialogs/`, `ui/windows/`, `tests/` |
| Inline `setStyleSheet()` calls | 86 occurrences across 24 files | **High** --- should migrate to QSS |
| `print()` statements | 62 occurrences across 15 files | **Must be replaced** with logging |
| Type hints (parameter annotations) | ~55 annotations across 10 files | **Very low** coverage |
| Return type annotations | ~25 across 8 files | **Very low** coverage |
| Legacy Turkish in code | Present in comments, some variable names, default values | **Must be standardized** to English |

### 2.2 Technical Debt Inventory

The following items represent accumulated technical debt that must be addressed during the pre-online phase. Each item is tagged with the initiative(s) that will address it.

#### TD-001: Hardcoded Entity Schema (Initiative B)

**Current state:** Entity types and their attribute schemas are defined as static Python dictionaries in `core/models.py` (lines 1--83). The 15 entity types (`NPC`, `Monster`, `Spell`, `Equipment`, `Class`, `Race`, `Location`, `Player`, `Quest`, `Lore`, `Status Effect`, `Feat`, `Background`, `Plane`, `Condition`) each have a fixed list of attribute fields defined as tuples of `(label_key, widget_type, options)`.

**Impact:** Users cannot add custom entity types, rename existing ones, or modify the fields available for any type. This severely limits the tool's applicability beyond D&D 5e.

**Resolution:** Initiative B introduces a dynamic schema engine that replaces the static `ENTITY_SCHEMAS` dictionary with a database-driven, user-configurable schema system.

#### TD-002: Inline CSS Throughout UI (Initiative A)

**Current state:** There are 86 `setStyleSheet()` calls spread across 24 Python files. Many of these set colors, fonts, margins, and other visual properties directly in Python code rather than using the QSS theme files.

**Examples found in:**
- `ui/player_window.py` (4 calls) --- hardcoded background colors and font families
- `ui/widgets/npc_sheet.py` (9 calls) --- extensive inline styling
- `ui/widgets/entity_sidebar.py` (8 calls) --- hardcoded colors for search/filter UI
- `ui/windows/battle_map_window.py` (7 calls) --- fog and control styling
- `ui/tabs/mind_map_tab.py` (7 calls) --- canvas and node styling
- `ui/tabs/map_tab.py` (6 calls) --- map viewer styling

**Impact:** Theme changes do not fully propagate; some elements remain stuck in their hardcoded colors. Adding new themes requires checking every inline style. Visual consistency is impossible to guarantee.

**Resolution:** Initiative A mandates migration of all inline styles to QSS theme files and ThemeManager palette references.

#### TD-003: Missing `__init__.py` Files (Initiative I)

**Current state:** Only `core/audio/__init__.py` and `core/dev/__init__.py` exist. The following packages lack `__init__.py`:
- `core/`
- `ui/`
- `ui/tabs/`
- `ui/widgets/`
- `ui/dialogs/`
- `ui/windows/`
- `tests/`
- `tests/test_core/`
- `tests/test_dev/`
- `tests/test_ui/`

**Impact:** While Python 3.3+ supports namespace packages (implicit `__init__.py`), the absence of these files prevents proper package-level imports, makes the module structure ambiguous to tooling, and blocks future use of `__init__.py` for controlled public API exposure.

**Resolution:** Initiative I adds `__init__.py` files to all packages.

#### TD-004: `print()` Instead of Logging (Initiative I)

**Current state:** 62 `print()` calls across 15 files serve as the only form of runtime diagnostics. The heaviest offenders are:
- `core/data_manager.py` (12 calls)
- `dev_run.py` (15 calls)
- `installer/build.py` (7 calls)
- `core/dev/hot_reload_manager.py` (6 calls)
- `core/api_client.py` (5 calls)

**Impact:** No log levels, no structured output, no ability to route logs to files or monitoring systems. When the online system adds server-side logging, the client must emit compatible structured events.

**Resolution:** Initiative I introduces a logging framework with structured output.

#### TD-005: Minimal Type Hints (Initiative I)

**Current state:** Only ~55 parameter type annotations and ~25 return type annotations exist across the entire codebase. The vast majority of functions have no type information.

**Impact:** IDE support is degraded. Refactoring is risky. Future API serialization layers (Pydantic models for network transfer) will require type-annotated data classes.

**Resolution:** Initiative I mandates type hints on all public function signatures.

#### TD-006: Legacy Turkish Language Artifacts (Initiative I)

**Current state:** While the application supports i18n through locale files, the codebase itself contains Turkish-language artifacts:
- Default entity name: `"Yeni Kayit"` in `core/models.py` line 155
- Comments in Turkish throughout `core/audio/engine.py`, `ui/widgets/combat_tracker.py`, `core/data_manager.py`
- Variable names with Turkish abbreviations in several files
- The `SCHEMA_MAP` and `PROPERTY_MAP` in `core/models.py` map legacy Turkish keys to English

**Impact:** New contributors who do not speak Turkish cannot understand comments. Code reviews are complicated by mixed-language identifiers.

**Resolution:** Initiative I standardizes all code, comments, and identifiers to English. The `SCHEMA_MAP` and `PROPERTY_MAP` remain for backward compatibility but are clearly documented as legacy migration aids.

#### TD-007: Inconsistent UI Layout Patterns (Initiative A)

**Current state:** Button sizes, spacing, margins, and alignment vary across windows and dialogs. The GitHub issue #30 specifically calls out inconsistent button sizes. The toolbar in `ui/main_root.py` uses manual spacing (`addSpacing(10)`, `addStretch()`). Combat tracker, session tab, and database tab each use different layout strategies for similar UI patterns.

**Impact:** The application looks unprofessional. When Player mode UI is introduced for online, inconsistent patterns will be amplified across two rendering contexts.

**Resolution:** Initiative A standardizes all layouts.

#### TD-008: Player Window Lacks DM Control (Initiative A)

**Current state:** `ui/player_window.py` is a simple `QMainWindow` with a `QStackedWidget` containing three pages (multi-image viewer, stat block, PDF viewer). The DM has no dedicated control surface for managing what the player sees --- projection is handled through the `ProjectionManager` drag-drop bar in the toolbar and by individual entity/map actions.

**Impact:** DM workflow is cumbersome. The DM must mentally track what is currently projected. There is no queue, no preview, no control over layout or visibility timing.

**Resolution:** Initiative A introduces a GM Player Screen Control panel.

#### TD-009: Separate Battle Map and Player View Windows (Initiative A)

**Current state:** The battle map opens in a separate `BattleMapWindow` (or embedded `BattleMapWidget` in the session tab). The player view is a completely separate `PlayerWindow`. There is no unified player-facing window that combines the battle map with other player content.

**Impact:** Players in local play must look at two different windows or the DM must manually switch. In online play, the player client needs a single unified view.

**Resolution:** Initiative A creates a Single Player Window that combines battle map and player view.

#### TD-010: No Event Logging in Combat (Initiative F)

**Current state:** Combat actions (damage, healing, condition changes, round advancement) are tracked in the combat tracker widget state but not persisted as a structured event log. The session `logs` field exists but is a free-text string that must be manually written.

**Impact:** DMs cannot review what happened in previous rounds. There is no audit trail for combat resolution. Online sync will require structured combat events.

**Resolution:** Initiative F implements an automatic event log system.

### 2.3 Readiness Gaps for Online Transition

The following table maps each online requirement (from `DEVELOPMENT_REPORT.md` Section 3.5) to the pre-online initiative that addresses the gap:

| Online Requirement | Current Gap | Pre-Online Initiative |
|-------------------|-------------|----------------------|
| Event bus abstraction | Direct Qt signals only | I (Code Quality) |
| Role-based content rendering | Single-user UI only | A (UI/UX Standardization) |
| Schema-driven entity model | Hardcoded 15-type model | B (Card/Template System) |
| Sync-ready battlemap | Single grid, no layer IDs | C (Battlemap Development) |
| Content package format | No package standard | D (Community Wiki) |
| Audio state serialization | Local-only engine | E (Audio Improvements) |
| Combat event streaming | No structured events | F (Event Log System) |
| Embedded document viewing | Basic PDF in Player Window | G (PDF Viewer) |
| Entity cross-referencing | Requires card DB intermediary | H (Free Single Import) |
| Structured logging | print() statements | I (Code Quality) |
| Type-safe data transfer | No type hints | I (Code Quality) |

### 2.4 Architecture Overview (Current)

For reference, the current application architecture is:

```
MainWindow (QMainWindow)
+-- Toolbar
|   +-- btn_toggle_player --> PlayerWindow (QMainWindow, second screen)
|   +-- btn_export_txt
|   +-- btn_toggle_sound
|   +-- projection_manager --> ProjectionManager (drag-drop zone)
|   +-- lbl_campaign
|   +-- combo_language (EN/TR/DE/FR)
|   +-- combo_theme (11 themes)
|   +-- btn_switch_world
+-- content_splitter (QSplitter)
|   +-- entity_sidebar --> EntitySidebar (entity search/filter)
|   +-- tabs (QTabWidget)
|   |   +-- Tab 0: DatabaseTab (dual-panel entity sheets)
|   |   +-- Tab 1: MindMapTab (infinite canvas)
|   |   +-- Tab 2: MapTab (world map + timeline)
|   |   +-- Tab 3: SessionTab (session + combat tracker)
|   +-- soundpad_panel --> SoundpadPanel (audio controls)
+-- PlayerWindow (separate QMainWindow)
    +-- QStackedWidget
        +-- Page 0: Multi-image viewer
        +-- Page 1: Stat block viewer
        +-- Page 2: PDF viewer (QWebEngineView)
```

**Data flow:** All state mutations pass through `DataManager`, which holds `self.data` as a Python dictionary. Persistence is via MsgPack (`.dat`) with JSON fallback. UI components communicate via PyQt6 signals.

**Key file sizes:**
- `ui/widgets/npc_sheet.py` --- 1002 lines (largest widget, entity editor)
- `ui/widgets/combat_tracker.py` --- 912 lines (combat management HUD)
- `ui/windows/battle_map_window.py` --- 762 lines (battle map + fog of war)
- `core/api_client.py` --- 705 lines (D&D 5e API integration)
- `core/data_manager.py` --- 677 lines (central data hub)
- `ui/tabs/mind_map_tab.py` --- 617 lines (infinite canvas)

---

## 3. Pre-Online Objectives

### 3.1 Program Principles

These principles govern all pre-online development decisions:

#### Principle 1: Offline-First, Online-Ready

Every feature must work locally first and expose clean boundaries for future synchronization. No feature may require a network connection. Data structures must include fields (even if initially unused) that will be needed for online sync, such as `sync_id`, `created_by`, `visibility`, and `version`.

#### Principle 2: User-Owned Data

World definitions, entity schemas, battlemap settings, and all campaign content remain under the user's full control. Data must be portable, exportable, and readable without the application running. No vendor lock-in on data formats.

#### Principle 3: Extensibility Over Hardcoding

Core systems must shift from fixed, code-defined rules to configurable, schema-driven behavior. The template system (Initiative B) is the primary expression of this principle, but it applies broadly: audio themes, battlemap grid configurations, encounter layouts, and UI preferences should all be data-driven.

#### Principle 4: Backward Compatibility

Existing campaigns must continue to load correctly. Any schema changes must include migration logic. The application must support at least one full release cycle of dual-read compatibility (old format + new format) before deprecating the old format.

#### Principle 5: English-First Codebase

All code, comments, variable names, class names, and internal identifiers must be in English. User-facing strings continue to use the i18n system. This principle is non-negotiable for the open-source community phase.

#### Principle 6: Test Before Ship

No initiative is complete without test coverage for its critical paths. New modules must have corresponding test files. Modified modules must have updated tests.

### 3.2 Measurable Success Criteria by Initiative

| Initiative | Success Criterion | Measurement Method |
|-----------|-------------------|-------------------|
| A: UI/UX | Zero inline `setStyleSheet()` calls with hardcoded colors | Grep count = 0 (excluding ThemeManager palette usage) |
| A: UI/UX | All buttons consistent size at 1920x1080 | Visual QA checklist |
| A: UI/UX | GM Player Screen Control panel functional | Manual test: DM can queue, preview, and push content |
| A: UI/UX | Single Player Window operational | Manual test: battle map + player content in one window |
| B: Template | Users can create custom entity categories | Automated CRUD test |
| B: Template | Template export/import round-trip succeeds | Automated test with checksum validation |
| B: Template | Existing campaigns load via migration | Automated regression test |
| C: Battlemap | Three grid modes operational (square, hex pointy, hex flat) | Automated rendering test |
| C: Battlemap | Distance measurement works with configurable units | Manual test + unit test |
| C: Battlemap | Drawing layer functional with undo/redo | Manual test |
| D: Wiki | Package export produces valid `.dmt-template` | Automated validation test |
| D: Wiki | Package import blocks unsafe content | Automated security test |
| E: Audio | Loop transitions have no audible gap | Manual listening test |
| E: Audio | Mid-length transition sounds play correctly | Automated state machine test |
| F: Event Log | Combat round events auto-logged | Automated combat simulation test |
| G: PDF | PDF renders in Session/Docs tab | Manual test with sample PDFs |
| H: Import | Entity imported directly without card DB step | Manual test + automated flow test |
| I: Quality | Zero `print()` in production code | Grep count = 0 (excluding tests and dev tools) |
| I: Quality | All public functions have type hints | mypy or pyright check passes |
| I: Quality | All comments and identifiers in English | Manual code review |

### 3.3 Delivery Philosophy

Work should proceed in the following general order:

1. **Foundation First (Initiative I):** Code quality improvements can be done incrementally alongside other work, but the logging framework and package structure should be established early so all new code follows the new patterns.

2. **UI Framework (Initiative A):** UI standardization provides the visual and structural foundation for all other feature work. The GM Player Screen Control and Single Player Window are architectural changes that affect how features are surfaced.

3. **Core Features (Initiatives B, C, E, F, G, H):** These can proceed in parallel once the foundation is in place. Initiative B (Template System) is the largest and should start early.

4. **Community Layer (Initiative D):** Depends on Initiative B (template system must exist before templates can be packaged and shared).

---

## 4. Initiative A: UI/UX Standardization

### 4.1 Overview

This initiative addresses all user interface consistency, layout, and structural issues that must be resolved before the online transition introduces DM/Player rendering modes.

### 4.2 Workstream A1: GM Player Screen Control

#### Problem Statement

The DM currently has no dedicated interface for controlling what appears on the Player Window. Content is pushed to the player through scattered mechanisms:
- Drag-drop in the `ProjectionManager` toolbar (images only)
- Individual entity/map actions that call `player_window.show_image()` or `player_window.show_stat_block()`
- Battle map fog/token state that is implicitly visible when the player window shows the battle map

There is no queue, no preview, no ability to prepare content before revealing it, and no unified view of what the player currently sees.

#### Solution Design

Introduce a **GM Player Screen Control** panel, accessible from the toolbar or as a dockable sidebar.

##### UI Components

1. **Current View Preview** --- A thumbnail showing exactly what the Player Window currently displays.
2. **Content Queue** --- A list of prepared items (images, stat blocks, maps, PDFs) that the DM can push to the player with one click.
3. **Quick Actions** --- Buttons for common operations:
   - "Show Battle Map" --- switches player view to the active battle map
   - "Show Image" --- opens file picker or accepts drag-drop
   - "Show Stat Block" --- opens entity selector
   - "Show PDF" --- opens file picker
   - "Clear Screen" --- returns player view to black/splash
4. **Layout Control** --- Radio buttons or dropdown to select player view layout:
   - Single content (full screen)
   - Split horizontal (two content panes)
   - Split vertical (two content panes)
   - Battle map with sidebar (map + stat block)
5. **Visibility Toggle** --- Master switch to black out the player screen (useful during setup).

##### Data Model

```python
@dataclass
class PlayerScreenState:
    layout_mode: str  # "single", "split_h", "split_v", "map_sidebar"
    content_slots: List[ContentSlot]  # One per layout pane
    is_blacked_out: bool
    queue: List[QueuedContent]

@dataclass
class ContentSlot:
    slot_id: str
    content_type: str  # "image", "stat_block", "battle_map", "pdf", "empty"
    content_ref: str   # File path, entity ID, or map ID
    zoom_level: float
    scroll_position: Tuple[float, float]

@dataclass
class QueuedContent:
    content_type: str
    content_ref: str
    label: str  # Display name in queue list
    added_at: float  # Timestamp
```

##### Implementation Notes

- The GM Player Screen Control panel should be a `QDockWidget` so it can be docked to any edge or floated.
- The preview thumbnail should update in real-time using a timer-based screenshot of the Player Window (low frequency, ~2fps is sufficient).
- The content queue persists with the session data so it survives application restarts.
- All actions emit signals that will later be wired to WebSocket events for online sync.

##### Files Affected

| File | Change |
|------|--------|
| `ui/player_window.py` | Add layout mode support, slot-based content rendering |
| `ui/main_root.py` | Add GM control panel dock widget |
| `main.py` | Wire dock widget visibility and persistence |
| **NEW** `ui/widgets/gm_screen_control.py` | GM Player Screen Control panel widget |
| **NEW** `ui/widgets/content_queue.py` | Content queue list widget |

##### Definition of Done

- DM can queue content items and push them to the player view with one click.
- DM can see a live preview of the player view.
- DM can switch between layout modes (single, split, map+sidebar).
- DM can black out the player screen instantly.
- Content queue persists across session saves.

---

### 4.3 Workstream A2: Single Player Window

#### Problem Statement

Currently, the battle map and the player view are separate windows with separate rendering paths. The `BattleMapWindow` (762 lines) manages its own graphics scene, fog, tokens, and controls. The `PlayerWindow` (147 lines) has a `QStackedWidget` with three content pages. There is no way for a player to see the battle map and other content (stat blocks, images) simultaneously in a single window.

For online play, the player client will need a single unified window that combines all player-visible content.

#### Solution Design

Create a **unified Player Window** that integrates the battle map view with other content types in a single window.

##### Architecture

```
PlayerWindow (QMainWindow)
+-- Central Widget
    +-- QSplitter (configurable orientation)
        +-- Primary Pane
        |   +-- QStackedWidget
        |       +-- BattleMapView (read-only, fog-applied)
        |       +-- Multi-image viewer
        |       +-- Stat block viewer
        |       +-- PDF viewer
        +-- Secondary Pane (optional, collapsible)
            +-- QStackedWidget
                +-- (same content types as primary)
```

##### Key Design Decisions

1. **Read-only battle map for players.** The player view of the battle map shows fog-of-war state as set by the DM but does not allow the player to modify fog, move tokens (until online mode), or change grid settings. This is achieved by creating a `PlayerBattleMapView` subclass of `BattleMapView` that disables editing interactions.

2. **DM controls remain in the DM window.** The battle map controls (fog tools, token management, grid settings) remain in the `BattleMapWidget` embedded in the SessionTab. The Player Window only receives the rendered view state.

3. **Layout driven by GM control.** The GM Player Screen Control panel (Workstream A1) determines which content appears in which pane. The Player Window itself is a passive display surface.

4. **Single window, selectable content per pane.** Each pane can independently display any content type. The GM decides the configuration.

##### Synchronization Between DM and Player Battle Map Views

The DM's battle map and the player's battle map view must stay synchronized:
- Token positions, sizes, and visibility
- Fog of war state (player sees revealed areas only)
- Map image (background)
- Grid overlay (if enabled for players)

This is achieved through a **shared state model** that both views observe:

```python
@dataclass
class BattleMapSharedState:
    map_image_path: str
    grid_config: GridConfig
    tokens: List[TokenState]
    fog_image_data: bytes  # Serialized QImage
    player_viewport: Optional[QRectF]  # If DM controls player viewport
```

The DM's `BattleMapWidget` writes to this shared state. The Player Window's `PlayerBattleMapView` reads from it. In the offline phase, this is done via direct Python object reference. In the online phase, this shared state will be serialized and transmitted via WebSocket.

##### Files Affected

| File | Change |
|------|--------|
| `ui/player_window.py` | Major refactor: splitter-based layout, slot system |
| `ui/windows/battle_map_window.py` | Extract shared state model, create PlayerBattleMapView |
| `ui/main_root.py` | Update player window initialization |
| **NEW** `ui/widgets/player_battle_map_view.py` | Read-only battle map view for player |
| **NEW** `core/battle_map_state.py` | Shared battle map state model |

##### Definition of Done

- Player Window displays battle map and other content simultaneously in split layout.
- Battle map view in Player Window is read-only (no fog editing, no token dragging).
- DM fog changes are immediately reflected in the Player Window.
- Token movement in DM view is immediately reflected in Player view.
- Player Window works correctly at various resolutions (1280x720 through 2560x1440).

---

### 4.4 Workstream A3: Standardize UI Layouts (Issue #30)

#### Problem Statement

GitHub issue #30 identifies inconsistent button sizes and layouts across the application. Investigation reveals the problem is broader:

1. **Button sizing:** No standard button sizes. Some buttons use fixed widths, others expand to fill available space, others are sized by their text content.
2. **Spacing and margins:** Inconsistent use of `setContentsMargins()` and `addSpacing()`. Values range from 0 to 20 pixels with no clear pattern.
3. **Alignment:** Some panels left-align controls, others center them, others use a mix.
4. **Group box styling:** `QGroupBox` usage varies. Some sections use them, others use `QFrame` with custom borders, others use no container at all.
5. **Font sizes:** Some labels have hardcoded font sizes via inline CSS, others inherit from the theme.

#### Solution Design

##### Establish a Layout Constants Module

Create a `ui/constants.py` file that defines all layout constants:

```python
"""UI layout constants for consistent spacing and sizing across the application."""

# Spacing
SPACING_XS = 2    # Tight spacing between related elements
SPACING_SM = 4    # Standard inner spacing
SPACING_MD = 8    # Standard outer spacing
SPACING_LG = 12   # Section spacing
SPACING_XL = 16   # Major section spacing
SPACING_XXL = 24  # Page-level spacing

# Margins
MARGIN_NONE = (0, 0, 0, 0)
MARGIN_TIGHT = (4, 4, 4, 4)
MARGIN_STANDARD = (8, 8, 8, 8)
MARGIN_COMFORTABLE = (12, 12, 12, 12)
MARGIN_PAGE = (16, 16, 16, 16)

# Button sizes
BTN_HEIGHT_SM = 24
BTN_HEIGHT_MD = 32
BTN_HEIGHT_LG = 40
BTN_MIN_WIDTH_SM = 60
BTN_MIN_WIDTH_MD = 80
BTN_MIN_WIDTH_LG = 120

# Icon sizes
ICON_SIZE_SM = 16
ICON_SIZE_MD = 24
ICON_SIZE_LG = 32
ICON_SIZE_XL = 48

# Widget constraints
SIDEBAR_MIN_WIDTH = 200
SIDEBAR_MAX_WIDTH = 400
PANEL_MIN_WIDTH = 300
DIALOG_MIN_WIDTH = 400
DIALOG_MIN_HEIGHT = 300
```

##### Standardize All Layouts

Every UI file must be updated to use constants from `ui/constants.py` instead of magic numbers. This is a file-by-file refactoring effort.

##### Layout Rules

1. **Toolbars:** Use `SPACING_SM` between buttons, `SPACING_LG` between button groups, `MARGIN_TIGHT` for container margins.
2. **Tab content areas:** Use `MARGIN_STANDARD` for outer margins, `SPACING_MD` between widgets.
3. **Dialog boxes:** Use `MARGIN_COMFORTABLE` for outer margins, `SPACING_MD` between form rows, `SPACING_LG` between sections.
4. **Buttons in button bars:** Right-aligned, `SPACING_SM` between buttons, all buttons same height (`BTN_HEIGHT_MD`).
5. **Group boxes:** Use consistently for any related group of 3+ controls. Never use `QFrame` with manual borders as a substitute.
6. **Labels:** Never hardcode font size. Use object names (`setObjectName()`) and let QSS handle font styling.

##### Files Affected

All UI files (24+ files) will be modified. Priority order:

1. `ui/main_root.py` --- Toolbar standardization
2. `ui/tabs/session_tab.py` --- Session panel layout
3. `ui/widgets/combat_tracker.py` --- Combat HUD layout
4. `ui/tabs/database_tab.py` --- Entity browser layout
5. `ui/widgets/npc_sheet.py` --- Entity editor layout
6. `ui/soundpad_panel.py` --- Audio control layout
7. `ui/dialogs/*.py` --- All dialog layouts
8. `ui/widgets/*.py` --- Remaining widget layouts

##### Definition of Done

- `ui/constants.py` exists and is imported by all UI files.
- Zero magic numbers for spacing, margins, or sizes in UI code.
- All buttons in button bars are the same height.
- Visual QA passes at 1280x720, 1920x1080, and 2560x1440 resolutions.
- GitHub issue #30 is closed.

---

### 4.5 Workstream A4: Remove Hardcoded CSS, Migrate to QSS Theme System

#### Problem Statement

86 `setStyleSheet()` calls across 24 files set visual properties directly in Python code. This means:
- Theme changes do not fully propagate.
- Adding new themes requires auditing every Python file.
- Some elements have "dead" styles that are immediately overwritten by inline CSS.

#### Solution Design

##### Phase 1: Audit and Categorize

Classify each `setStyleSheet()` call into one of three categories:

1. **Theme-dependent styling** --- Colors, fonts, borders that should change with the theme. These must move to QSS files.
2. **Structural styling** --- Fixed layout properties (margins, alignment) that do not change with themes. These can remain as inline styles but should use constants.
3. **Dynamic styling** --- Styles that change at runtime based on state (e.g., HP bar colors, active turn highlighting). These should use `ThemeManager.get_palette()` and apply the palette color dynamically.

##### Phase 2: Extend QSS Files

For each category-1 style, add the appropriate CSS rule to all 11 theme QSS files. Use object names (`setObjectName()`) for targeting.

Example transformation:

**Before (in Python):**
```python
self.stat_viewer.setStyleSheet(f"""
    QTextBrowser {{
        background-color: {p.get('markdown_bg', '#1a1a1a')};
        color: {p.get('markdown_text', '#e0e0e0')};
        border: none;
        padding: 20px;
        font-family: 'Segoe UI', serif;
    }}
""")
```

**After (in QSS file):**
```css
QTextBrowser#statViewer {
    background-color: @markdown_bg;
    color: @markdown_text;
    border: none;
    padding: 20px;
    font-family: 'Segoe UI', serif;
}
```

**After (in Python):**
```python
self.stat_viewer.setObjectName("statViewer")
```

##### Phase 3: ThemeManager Palette Expansion

The `ThemeManager` already has a palette system with ~50 color keys. Expand it to cover all colors currently hardcoded in `setStyleSheet()` calls. Each theme palette must define all keys.

##### Phase 4: QSS Preprocessor (Optional Enhancement)

Consider adding a simple QSS preprocessor that replaces `@variable_name` tokens in QSS files with values from the ThemeManager palette. This allows QSS files to reference palette colors by name rather than hardcoding hex values. This would be implemented as a transformation step in `config.load_theme()`.

##### Files Affected

All 24 files with `setStyleSheet()` calls, plus all 11 QSS theme files.

##### Definition of Done

- Zero `setStyleSheet()` calls that contain hardcoded color values (hex codes, rgb() values).
- All 11 themes render correctly with no visual artifacts.
- Theme switching updates all visible elements without requiring window restart.
- `ThemeManager` palette contains all color keys needed by all components.

---

### 4.6 Workstream A5: Responsive Layout Improvements

#### Problem Statement

The application's layout was designed for a single resolution range (~1920x1080). At lower resolutions (1280x720 --- common on laptops), some elements overflow, scrollbars appear unexpectedly, and text is truncated. At higher resolutions (2560x1440 and above), elements appear too small with excessive whitespace.

#### Solution Design

1. **Minimum window size:** Set `MainWindow.setMinimumSize(1024, 600)` to prevent unusable layouts.
2. **Splitter proportions:** Replace fixed pixel sizes in `content_splitter.setSizes([300, 1000, 0])` with ratio-based sizing that adapts to available space.
3. **Scrollable panels:** Wrap all content panels in `QScrollArea` where content may exceed available height. Currently, only some panels use scroll areas.
4. **Font scaling:** Use relative font sizes in QSS (`em` or `%` units where supported) rather than absolute pixel sizes.
5. **DPI awareness:** Ensure the application respects the system DPI setting. PyQt6 handles most of this automatically, but verify that custom-drawn elements (battle map grid, mind map nodes, condition icons) scale correctly.
6. **Test matrix:** Test at three resolutions (1280x720, 1920x1080, 2560x1440) and two DPI settings (100%, 150%).

##### Definition of Done

- Application is usable at 1280x720 with no overlapping elements or truncated text.
- Application looks proportional at 2560x1440.
- All custom-drawn elements scale with DPI.

---

### 4.7 Workstream A6: Accessibility Basics

#### Problem Statement

The application currently has no accessibility considerations. While full WCAG compliance is not in scope for the pre-online phase, basic accessibility foundations should be established.

#### Solution Design

1. **Keyboard navigation:** Ensure all interactive elements are reachable via Tab key. Set tab order explicitly in complex dialogs.
2. **Tooltips:** Add tooltips to all buttons that use only icons (no text label). Currently, some icon-only buttons have tooltips, others do not.
3. **Color contrast:** Verify that all theme palettes meet minimum contrast ratios (4.5:1 for normal text, 3:1 for large text). Adjust palettes where needed.
4. **Screen reader labels:** Set `accessibleName` and `accessibleDescription` on all interactive widgets. This is a low-cost, high-value foundation.
5. **Focus indicators:** Ensure QSS themes define visible focus indicators for keyboard navigation.

##### Definition of Done

- All interactive elements reachable via keyboard Tab navigation.
- All icon-only buttons have descriptive tooltips.
- At least the Dark and Light themes pass contrast ratio checks.
- `accessibleName` is set on all buttons, inputs, and interactive widgets.

---

## 5. Initiative B: Card and World Template System

### 5.1 Overview

This initiative transforms the entity data model from a fixed, hardcoded schema into a dynamic, user-configurable template system. It is the single most impactful pre-online initiative because it fundamentally changes how data is structured, stored, and rendered.

### 5.2 Product Goal

Allow users to fully customize entity categories and card fields, then package these customizations into reusable world templates. The system must support:

- Creating entirely new entity categories (e.g., Faction, Relic, Hex, Vehicle, Deity)
- Removing or renaming existing categories
- Adding, removing, and reordering fields within any category
- Defining field types with validation rules
- Using custom fields in the Encounter/Combat views
- Exporting the complete schema as a `.dmt-template` package
- Importing templates into new or existing worlds

### 5.3 Core Capabilities

#### B1: Dynamic Entity Category Management

##### Current State

Entity types are a hardcoded list in `core/models.py`:
```
NPC, Monster, Spell, Equipment, Class, Race, Location, Player, Quest,
Lore, Status Effect, Feat, Background, Plane, Condition
```

The `ENTITY_SCHEMAS` dictionary maps each type to a fixed list of attribute field definitions. The `get_default_entity_structure()` function returns a single universal entity structure with all possible fields, regardless of type.

##### Target State

Entity categories are defined in a `world_schema` data structure that is part of the campaign data. Users can:

1. **Create custom categories** with a name, icon, color, and sort order.
2. **Rename existing categories** (the internal `slug` remains stable for data references).
3. **Archive categories** that are no longer needed (entities remain accessible but the category is hidden from creation UI).
4. **Delete categories** with a dependency check that warns if entities of that type exist.
5. **Reorder categories** in the sidebar and creation dialogs.

##### Category Schema

```python
@dataclass
class EntityCategorySchema:
    category_id: str          # UUID, stable identifier
    schema_id: str            # Reference to parent WorldSchema
    name: str                 # Display name (user-editable)
    slug: str                 # Internal identifier (auto-generated from name, immutable after creation)
    icon: str                 # Icon identifier or path
    color: str                # Hex color for UI accents
    is_builtin: bool          # True for default D&D 5e categories
    is_archived: bool         # True if hidden from creation UI
    order_index: int          # Sort order in sidebar/dialogs
    created_at: str           # ISO 8601 timestamp
    updated_at: str           # ISO 8601 timestamp
    fields: List[FieldSchema] # Ordered list of field definitions
```

##### Behavior Rules

- Built-in categories (`is_builtin=True`) can be renamed and archived but not deleted.
- Custom categories can be fully deleted if no entities reference them.
- The `slug` is generated from the initial `name` using a deterministic slugify function and never changes.
- Category names must be unique within a world schema.
- Category `order_index` values are recalculated when categories are reordered.

---

#### B2: Dynamic Field Definitions

##### Current State

Fields are defined as tuples in `ENTITY_SCHEMAS`:
```python
("LBL_RACE", "entity_select", "Race")  # (label_key, widget_type, options)
```

This supports only three widget types: `text`, `combo`, and `entity_select`. There is no validation, no default values, no field-level visibility control, and no way for users to add fields.

##### Target State

Fields are fully configurable data objects with rich type support.

##### Field Schema

```python
@dataclass
class FieldSchema:
    field_id: str              # UUID, stable identifier
    category_id: str           # Reference to parent category
    field_key: str             # Internal key (auto-generated, immutable)
    label: str                 # Display label (user-editable)
    field_type: FieldType      # Enum of supported types
    required: bool             # Whether the field must have a value
    default_value: Any         # Default value for new entities
    placeholder: str           # Placeholder text for empty fields
    help_text: str             # Tooltip/help text for the field
    validation: FieldValidation  # Type-specific validation rules
    visibility: FieldVisibility  # Who can see this field
    order_index: int           # Sort order within category
    is_builtin: bool           # True for default fields
    created_at: str            # ISO 8601 timestamp
    updated_at: str            # ISO 8601 timestamp
```

##### Supported Field Types

```python
class FieldType(Enum):
    TEXT = "text"                   # Single-line text input
    TEXTAREA = "textarea"          # Multi-line text input
    MARKDOWN = "markdown"          # Rich text with markdown editor
    INTEGER = "integer"            # Whole number input
    FLOAT = "float"                # Decimal number input
    BOOLEAN = "boolean"            # Checkbox
    ENUM = "enum"                  # Dropdown with predefined options
    DATE = "date"                  # Date picker
    IMAGE = "image"                # Image file reference
    FILE = "file"                  # General file reference
    RELATION = "relation"          # Reference to another entity
    TAG_LIST = "tag_list"          # List of text tags
    STAT_BLOCK = "stat_block"      # D&D-style ability score block (STR/DEX/CON/INT/WIS/CHA)
    COMBAT_STATS = "combat_stats"  # HP, AC, Speed, CR, XP, Initiative block
    ACTION_LIST = "action_list"    # List of named actions with descriptions
    SPELL_LIST = "spell_list"      # List of spell references
    FORMULA = "formula"            # Computed field (Phase 2, optional)
```

##### Validation Rules

```python
@dataclass
class FieldValidation:
    min_value: Optional[float] = None      # For numeric types
    max_value: Optional[float] = None      # For numeric types
    min_length: Optional[int] = None       # For text types
    max_length: Optional[int] = None       # For text types
    pattern: Optional[str] = None          # Regex pattern for text types
    allowed_values: Optional[List[str]] = None  # For enum type
    allowed_types: Optional[List[str]] = None   # For relation type (category slugs)
    allowed_extensions: Optional[List[str]] = None  # For file/image types
    custom_message: Optional[str] = None   # Error message override
```

##### Field Visibility

```python
class FieldVisibility(Enum):
    SHARED = "shared"       # Visible to DM and players (in online mode)
    DM_ONLY = "dm_only"     # Visible only to DM
    PRIVATE = "private"     # Visible only to the entity owner (future)
```

---

#### B3: World Template Packaging

##### Package Format

World templates are exported as `.dmt-template` files, which are ZIP archives with a defined internal structure:

```
my-template.dmt-template (ZIP archive)
|-- manifest.json
|-- schema/
|   |-- world_schema.json
|   |-- categories/
|   |   |-- npc.json
|   |   |-- monster.json
|   |   |-- custom_faction.json
|   |   |-- ...
|   |-- encounter_layouts/
|       |-- default.json
|-- assets/
|   |-- icons/
|   |   |-- faction.png
|   |   |-- ...
|   |-- previews/
|       |-- template_preview.png
|-- README.md (optional)
```

##### Manifest Schema

```json
{
    "manifest_version": "1.0",
    "package_type": "template",
    "package_id": "uuid-v4",
    "title": "Dark Fantasy World Template",
    "description": "A template for grim, low-magic settings...",
    "author": "AuthorName",
    "version": "1.0.0",
    "created_at": "2026-03-18T12:00:00Z",
    "compatible_app_versions": ">=0.8.0",
    "license": "CC-BY-4.0",
    "tags": ["dark-fantasy", "low-magic", "gritty"],
    "checksum": "sha256:abc123...",
    "categories_count": 18,
    "fields_count": 95,
    "includes_encounter_layouts": true,
    "includes_custom_icons": true
}
```

##### Version Compatibility

Templates include a `compatible_app_versions` field using semver range syntax. The import process checks this against the current application version and warns or blocks if incompatible.

##### Template Integrity

- The `checksum` in the manifest covers all files in the archive except the manifest itself.
- Import validates the checksum before applying.
- Import also validates schema structure (all required fields present, no unknown field types).

---

#### B4: Encounter Integration Upgrade

##### Current State

The combat tracker in `ui/widgets/combat_tracker.py` uses a hardcoded set of columns: name, HP, max HP, AC, initiative, and conditions. The combatant data structure is fixed:

```python
{
    "entity_id": str,
    "name": str, "hp": int, "max_hp": int,
    "ac": int, "initiative": int,
    "conditions": [{"name": str, "duration": int, "max_duration": int}],
    "token_state": {"tile_x": int, "tile_y": int}
}
```

##### Target State

The encounter layout is configurable. The DM can select which fields from the entity schema appear as columns in the combat tracker.

##### Encounter Layout Schema

```python
@dataclass
class EncounterLayout:
    layout_id: str           # UUID
    schema_id: str           # Reference to WorldSchema
    name: str                # Layout name (e.g., "Standard D&D", "Stress-based")
    columns: List[EncounterColumn]
    sort_rules: List[SortRule]
    derived_stats: List[DerivedStat]  # Optional computed columns

@dataclass
class EncounterColumn:
    field_key: str           # Reference to FieldSchema.field_key, or built-in key
    display_label: str       # Column header text
    width: int               # Column width in pixels (or 0 for auto)
    is_editable: bool        # Whether DM can edit during combat
    format_template: str     # Display format (e.g., "{value}/{max_value}")

@dataclass
class SortRule:
    field_key: str
    direction: str           # "asc" or "desc"
    priority: int            # Sort priority (lower = higher priority)

@dataclass
class DerivedStat:
    key: str                 # Unique key for the derived stat
    label: str               # Display label
    formula: str             # Expression (e.g., "{hp}/{max_hp}*100" for HP percentage)
    format_template: str     # Display format
```

##### Built-in Encounter Columns

The following columns are always available regardless of schema:
- `name` --- Entity name (always present, always first)
- `initiative` --- Initiative roll (always available, default sort column)
- `hp` / `max_hp` --- Hit points
- `ac` --- Armor class
- `conditions` --- Active conditions list

Custom columns reference field keys from the entity schema.

---

### 5.4 Full Data Model Design

#### World Schema (Top Level)

```python
@dataclass
class WorldSchema:
    schema_id: str            # UUID
    name: str                 # Schema name (e.g., "D&D 5e Standard", "Shadowdark")
    version: str              # Semver string
    base_system: Optional[str]  # Optional reference to a known game system
    description: str          # Human-readable description
    categories: List[EntityCategorySchema]
    encounter_layouts: List[EncounterLayout]
    created_at: str           # ISO 8601
    updated_at: str           # ISO 8601
    metadata: Dict[str, Any]  # Extensible metadata
```

#### Default Schema Generation

When a world is loaded that does not have a `world_schema`, the migration layer generates a default schema from the current `ENTITY_SCHEMAS` dictionary:

```python
def generate_default_schema() -> WorldSchema:
    """
    Generates a WorldSchema that exactly replicates the current hardcoded
    ENTITY_SCHEMAS, ensuring backward compatibility.
    """
    schema = WorldSchema(
        schema_id=str(uuid.uuid4()),
        name="D&D 5e (Default)",
        version="1.0.0",
        base_system="dnd5e",
        description="Auto-generated schema matching the built-in D&D 5e entity model.",
        categories=[],
        encounter_layouts=[],
        created_at=datetime.utcnow().isoformat(),
        updated_at=datetime.utcnow().isoformat(),
        metadata={}
    )

    for type_name, fields in ENTITY_SCHEMAS.items():
        category = EntityCategorySchema(
            category_id=str(uuid.uuid4()),
            schema_id=schema.schema_id,
            name=type_name,
            slug=slugify(type_name),
            icon=f"default_{slugify(type_name)}",
            color=DEFAULT_CATEGORY_COLORS.get(type_name, "#808080"),
            is_builtin=True,
            is_archived=False,
            order_index=list(ENTITY_SCHEMAS.keys()).index(type_name),
            created_at=schema.created_at,
            updated_at=schema.updated_at,
            fields=[]
        )

        for idx, (label_key, widget_type, options) in enumerate(fields):
            field = FieldSchema(
                field_id=str(uuid.uuid4()),
                category_id=category.category_id,
                field_key=label_key_to_field_key(label_key),
                label=label_key,
                field_type=map_widget_type_to_field_type(widget_type),
                required=False,
                default_value=None,
                placeholder="",
                help_text="",
                validation=FieldValidation(),
                visibility=FieldVisibility.SHARED,
                order_index=idx,
                is_builtin=True,
                created_at=schema.created_at,
                updated_at=schema.updated_at,
            )
            category.fields.append(field)

        schema.categories.append(category)

    return schema
```

#### Widget Type Mapping

```python
WIDGET_TYPE_MAP = {
    "text": FieldType.TEXT,
    "combo": FieldType.ENUM,
    "entity_select": FieldType.RELATION,
}
```

#### Storage

The world schema is stored as part of the campaign data:

```python
self.data = {
    "world_name": str,
    "world_schema": dict,    # Serialized WorldSchema
    "entities": {},
    "map_data": {},
    "sessions": [],
    "last_active_session_id": None,
    "mind_maps": {}
}
```

The schema is serialized alongside the rest of the campaign data in MsgPack format.

### 5.5 Migration Strategy

#### Migration Goals

1. Every existing campaign must load without error after the schema system is introduced.
2. No user action is required --- migration is automatic and transparent.
3. A backup of the pre-migration data is created before any changes are written.

#### Migration Steps

##### Step 1: Detect Schema Absence

When `DataManager.load_campaign()` loads a campaign that does not contain a `world_schema` key, the migration is triggered.

##### Step 2: Create Backup

Before any modification, copy the current `data.dat` (or `data.json`) to `data.dat.pre-schema-migration.bak`.

##### Step 3: Generate Default Schema

Call `generate_default_schema()` to create a `WorldSchema` that matches the current hardcoded model.

##### Step 4: Map Existing Entities

For each entity in `self.data["entities"]`:
1. Look up the entity's `type` in the generated schema.
2. Verify all `attributes` keys match field keys in the schema.
3. For any missing fields (entity has data that is not in the schema), add the field to the schema as a custom text field.
4. For any extra fields (schema has fields not in the entity), set the entity's value to the field's default.

##### Step 5: Handle Legacy Turkish Data

For entities with Turkish-language type names or attribute keys:
1. Map the type name through `SCHEMA_MAP` to get the English name.
2. Map attribute keys through `PROPERTY_MAP` to get the English label keys.
3. Update the entity's data in place.
4. Log each mapping applied.

##### Step 6: Persist

Write the updated `self.data` (now including `world_schema`) to disk.

##### Step 7: Verify

Reload the data and confirm:
- All entities load correctly.
- The schema contains all expected categories and fields.
- No data was lost.

#### Legacy Fallback

For at least one release cycle after the schema migration is introduced, the application must support loading campaigns in both formats:
- **New format:** Campaign data includes `world_schema`.
- **Legacy format:** Campaign data does not include `world_schema` (migration is applied on load).

This dual-read capability ensures users who share campaign files between machines running different versions do not lose data.

### 5.6 UI/UX Workstreams

#### B-UI-1: Template Studio

The Template Studio is a dedicated dialog or tab where users manage their world schema.

##### Layout

```
Template Studio Dialog (QDialog, 900x700 minimum)
+-- Left Panel (250px)
|   +-- Category List (QListWidget with drag-to-reorder)
|   +-- [+ New Category] button
|   +-- [Archive] / [Delete] buttons
+-- Right Panel (expandable)
    +-- Category Header
    |   +-- Name (editable QLineEdit)
    |   +-- Icon selector
    |   +-- Color picker
    +-- Field List (QTableWidget with drag-to-reorder)
    |   +-- Columns: Order | Label | Type | Required | Default | Visibility | Actions
    |   +-- [+ Add Field] button
    +-- Field Editor (expandable panel, shown when field is selected)
        +-- All FieldSchema properties as form inputs
        +-- Type-specific validation editor
        +-- Preview of rendered field
```

##### Interactions

1. Selecting a category in the left panel loads its fields in the right panel.
2. Clicking "Add Field" adds a new field at the bottom of the list with default values.
3. Double-clicking a field row opens the Field Editor panel.
4. Drag-and-drop on the category list and field list reorders items.
5. A "Preview" button shows how an entity card would look with the current field configuration.
6. "Save" writes the schema changes to the campaign data.
7. "Export as Template" triggers the `.dmt-template` export flow.
8. "Import Template" triggers the import flow with conflict resolution.

#### B-UI-2: Entity Card Renderer

The `npc_sheet.py` (currently 1002 lines) must be refactored to render entity cards dynamically based on the field schema rather than hardcoded field lists.

##### Architecture Change

**Current flow:**
```
NpcSheet.load_entity(entity_data)
  -> Hardcoded: create QLineEdit for "name"
  -> Hardcoded: create combo for "attitude"
  -> Hardcoded: create text fields for each attribute in ENTITY_SCHEMAS[type]
  -> Hardcoded: create stat block widget
  -> Hardcoded: create action list widgets
  -> ...
```

**Target flow:**
```
NpcSheet.load_entity(entity_data, field_schemas)
  -> For each field in field_schemas (ordered by order_index):
       -> Look up field_type
       -> Instantiate appropriate widget from FieldWidgetFactory
       -> Populate widget with entity_data[field.field_key]
       -> Connect widget change signal to entity data update
```

##### Field Widget Factory

```python
class FieldWidgetFactory:
    """Creates the appropriate Qt widget for a given field type."""

    WIDGET_MAP = {
        FieldType.TEXT: TextFieldWidget,
        FieldType.TEXTAREA: TextAreaFieldWidget,
        FieldType.MARKDOWN: MarkdownFieldWidget,
        FieldType.INTEGER: IntegerFieldWidget,
        FieldType.FLOAT: FloatFieldWidget,
        FieldType.BOOLEAN: BooleanFieldWidget,
        FieldType.ENUM: EnumFieldWidget,
        FieldType.DATE: DateFieldWidget,
        FieldType.IMAGE: ImageFieldWidget,
        FieldType.FILE: FileFieldWidget,
        FieldType.RELATION: RelationFieldWidget,
        FieldType.TAG_LIST: TagListFieldWidget,
        FieldType.STAT_BLOCK: StatBlockFieldWidget,
        FieldType.COMBAT_STATS: CombatStatsFieldWidget,
        FieldType.ACTION_LIST: ActionListFieldWidget,
        FieldType.SPELL_LIST: SpellListFieldWidget,
    }

    @staticmethod
    def create(field_schema: FieldSchema, value: Any,
               data_manager: DataManager) -> QWidget:
        widget_class = FieldWidgetFactory.WIDGET_MAP.get(field_schema.field_type)
        if widget_class is None:
            return FallbackTextWidget(field_schema, value)
        return widget_class(field_schema, value, data_manager)
```

Each field widget class must:
1. Accept a `FieldSchema` and current value in its constructor.
2. Render the appropriate input control.
3. Emit a `value_changed` signal when the user modifies the value.
4. Support `get_value()` and `set_value()` methods.
5. Apply validation rules from the schema and display error messages.

#### B-UI-3: Encounter Column Configurator

A dialog accessible from the combat tracker that allows the DM to configure which fields appear as columns.

##### Layout

```
Encounter Column Configurator (QDialog)
+-- Available Fields (QListWidget)
|   +-- All fields from all categories in the current schema
+-- [->] [<-] buttons (add/remove columns)
+-- Active Columns (QListWidget with drag-to-reorder)
|   +-- Currently configured columns
+-- Column Properties (panel, shown when column is selected)
|   +-- Display label (QLineEdit)
|   +-- Width (QSpinBox)
|   +-- Editable during combat (QCheckBox)
|   +-- Format template (QLineEdit)
+-- Sort Rules (section)
|   +-- Sort field (QComboBox from active columns)
|   +-- Direction (asc/desc)
+-- Preview (bottom section)
    +-- Sample combat tracker with 3-5 dummy combatants using current configuration
```

### 5.7 New Files Required

| File | Purpose |
|------|---------|
| `core/schema/world_schema.py` | WorldSchema, EntityCategorySchema, FieldSchema dataclasses |
| `core/schema/field_types.py` | FieldType enum, FieldValidation, FieldVisibility |
| `core/schema/encounter_layout.py` | EncounterLayout, EncounterColumn, SortRule, DerivedStat |
| `core/schema/migration.py` | Migration logic for legacy campaigns |
| `core/schema/template_io.py` | Template export/import (ZIP packaging) |
| `core/schema/default_schema.py` | Default D&D 5e schema generation |
| `core/schema/__init__.py` | Package init |
| `ui/dialogs/template_studio.py` | Template Studio dialog |
| `ui/dialogs/encounter_configurator.py` | Encounter Column Configurator dialog |
| `ui/widgets/field_widgets.py` | Field widget implementations |
| `ui/widgets/field_widget_factory.py` | Factory for creating field widgets |
| `tests/test_core/test_schema.py` | Schema CRUD tests |
| `tests/test_core/test_migration.py` | Migration tests |
| `tests/test_core/test_template_io.py` | Template export/import tests |

### 5.8 Definition of Done

- Users can create, edit, rename, reorder, archive, and delete entity categories without manual file editing.
- Users can add, edit, reorder, and remove fields within any category with full type and validation support.
- Existing campaigns load with an auto-generated default schema that preserves all data.
- The entity editor (NpcSheet) dynamically renders fields based on the schema.
- The combat tracker can display custom columns from the entity schema.
- Template export produces a valid `.dmt-template` ZIP archive with manifest and checksum.
- Template import validates integrity and applies the schema with conflict resolution.
- Regression tests cover migration for all 15 built-in entity types.
- CRUD tests cover category and field operations.
- Round-trip tests verify template export -> import produces identical schemas.

---

## 6. Initiative C: Advanced Battlemap Development

### 6.1 Overview

The battlemap is currently a single-grid-mode (square) tactical surface with fog of war, token placement, and basic zoom/pan. This initiative upgrades it into a system-agnostic tactical surface supporting multiple grid systems, measurement tools, drawing layers, and improved DM controls.

### 6.2 Product Goal

A battlemap engine that works for any tabletop RPG system, not just D&D 5e with its 5-foot square grid. DMs running Shadowdark, GURPS, Warhammer, or homebrew systems should all find the battlemap useful.

### 6.3 Core Capabilities

#### C1: Multi-Grid Support

##### Grid Modes

| Mode | Description | Cell Shape | Coordinate System |
|------|-------------|------------|-------------------|
| `square` | Standard square grid (current) | Square | (col, row) |
| `hex_pointy` | Hexagonal grid, pointy-top orientation | Hexagon | Offset or axial |
| `hex_flat` | Hexagonal grid, flat-top orientation | Hexagon | Offset or axial |
| `isometric` | Isometric diamond grid (Phase 2) | Diamond | (col, row) with isometric transform |
| `none` | No grid overlay | N/A | Pixel coordinates |

##### Grid Configuration

```python
@dataclass
class GridConfig:
    grid_mode: str            # "square", "hex_pointy", "hex_flat", "isometric", "none"
    cell_size_px: int         # Size of one cell in pixels (width for hex, side for square)
    offset_x: float           # Grid origin X offset from map origin
    offset_y: float           # Grid origin Y offset from map origin
    line_color: str           # Grid line color (hex)
    line_opacity: float       # Grid line opacity (0.0 - 1.0)
    line_thickness: float     # Grid line thickness in pixels
    snap_to_grid: bool        # Whether tokens snap to grid cells
    show_coordinates: bool    # Whether to display cell coordinates
    unit_label: str           # Display unit (e.g., "ft", "m", "squares")
    unit_per_cell: float      # How many units per cell (e.g., 5.0 for D&D 5ft squares)
```

##### Grid Rendering

Each grid mode requires its own rendering implementation:

**Square grid:** Horizontal and vertical lines at regular intervals. This is the current implementation.

**Hex pointy-top grid:** Hexagons with vertices pointing up and down.
- Cell width: `cell_size * sqrt(3)`
- Cell height: `cell_size * 2`
- Row offset: Even rows offset right by half cell width

**Hex flat-top grid:** Hexagons with flat edges on top and bottom.
- Cell width: `cell_size * 2`
- Cell height: `cell_size * sqrt(3)`
- Column offset: Even columns offset down by half cell height

**Coordinate conversion functions** are needed for each grid type:
- `pixel_to_cell(x, y, config) -> (col, row)`
- `cell_to_pixel(col, row, config) -> (center_x, center_y)`
- `cell_neighbors(col, row, config) -> List[(col, row)]`
- `cell_distance(col1, row1, col2, row2, config) -> float`

##### Token Snapping

Token placement must snap to the appropriate cell center for each grid mode:
- Square: snap to cell center
- Hex: snap to hex center
- None: no snapping (free placement)

Large tokens (occupying multiple cells) must handle multi-cell snapping correctly.

---

#### C2: Measurement Tools

##### Distance Ruler

A tool that measures the distance between two points on the map, expressed in the configured unit.

**Behavior:**
1. DM activates the ruler tool (toolbar button or keyboard shortcut).
2. DM clicks the start point.
3. As the DM moves the mouse, a line is drawn from start to cursor with the distance displayed.
4. DM clicks to place a waypoint. The segment distance and total distance are shown.
5. DM double-clicks or presses Enter to complete the measurement.
6. Right-click or Escape cancels the measurement.

**Distance calculation:**
- Square grid: Count cells in the path. Diagonal movement can be configured as: Euclidean distance, 5/10/5 alternating, or simple diagonal = 1 cell.
- Hex grid: Count hex steps along the path.
- No grid: Pixel distance converted to units.

##### Area Templates (Phase 2)

Shape templates for ability areas of effect:
- **Circle/Sphere:** Radius from center point
- **Cone:** Origin, direction, and angle
- **Line:** Origin, direction, length, and width
- **Cube/Square:** Origin and side length

These are rendered as semi-transparent overlays on the map.

---

#### C3: Drawing and Markup Layer

##### Drawing Tools

| Tool | Description |
|------|-------------|
| Freehand | Free-draw with configurable color and thickness |
| Line | Straight line between two points |
| Rectangle | Rectangle defined by two corner points |
| Ellipse | Ellipse defined by bounding rectangle |
| Arrow | Line with arrowhead |
| Text | Text annotation at a point |
| Polygon | Multi-point closed polygon |

##### Layer System

Drawings exist on a dedicated layer separate from the map, grid, tokens, and fog:

```
Z-order (top to bottom):
  300  - UI overlays (measurement display, tooltips)
  200  - Fog of war
  150  - Drawing layer (DM annotations)
  100  - Token layer
   50  - Grid overlay
    0  - Map image (background)
```

##### Drawing Object Model

```python
@dataclass
class DrawingObject:
    drawing_id: str           # UUID, sync-ready
    shape_type: str           # "freehand", "line", "rectangle", "ellipse", "arrow", "text", "polygon"
    points: List[Tuple[float, float]]  # Shape-defining points
    style: DrawingStyle       # Visual style
    layer: str                # "dm_annotations", "shared_annotations"
    created_by: str           # User identifier (prep for online)
    created_at: str           # ISO 8601
    is_visible: bool          # DM can toggle visibility

@dataclass
class DrawingStyle:
    stroke_color: str         # Hex color
    stroke_width: float       # Pixels
    stroke_opacity: float     # 0.0 - 1.0
    fill_color: Optional[str] # Hex color (None = no fill)
    fill_opacity: float       # 0.0 - 1.0
    font_size: Optional[int]  # For text annotations
    font_family: Optional[str]  # For text annotations
    line_style: str           # "solid", "dashed", "dotted"
```

##### Undo/Redo

Drawing actions are tracked in an undo stack:

```python
@dataclass
class DrawingAction:
    action_type: str          # "add", "remove", "modify"
    drawing_id: str
    before_state: Optional[DrawingObject]  # For "modify" and "remove"
    after_state: Optional[DrawingObject]   # For "add" and "modify"
```

The undo stack is maintained per battle map session. Maximum stack depth: 100 actions.

---

#### C4: Expanded DM Control Surface

##### Current State

The battle map controls are scattered:
- Fog tools (add/remove/clear) are buttons in the `BattleMapWidget`
- Token management is done through the combat tracker table
- Grid settings are not exposed in the UI
- Zoom/pan is mouse-only

##### Target State

A dedicated **DM Battlemap Toolbar** with organized tool groups:

```
DM Battlemap Toolbar
+-- View Group
|   +-- Zoom In / Zoom Out / Zoom to Fit
|   +-- Pan tool (hand cursor)
|   +-- Center on active token
+-- Grid Group
|   +-- Grid mode selector (square/hex/none)
|   +-- Grid size slider
|   +-- Grid visibility toggle
|   +-- Grid settings dialog (color, opacity, snap, units)
+-- Fog Group
|   +-- Fog add tool (polygon draw)
|   +-- Fog remove tool (polygon erase)
|   +-- Fog fill (cover entire map)
|   +-- Fog clear (reveal entire map)
|   +-- Fog visibility toggle (show/hide fog on DM view)
+-- Draw Group
|   +-- Tool selector (freehand, line, rect, ellipse, arrow, text, polygon)
|   +-- Color picker
|   +-- Stroke width slider
|   +-- Fill toggle
|   +-- Undo / Redo
|   +-- Clear all drawings
+-- Token Group
|   +-- Add token (from entity)
|   +-- Token size selector (1x1, 2x2, 3x3, 4x4)
|   +-- Token visibility toggle (show/hide for players)
+-- Measurement Group
    +-- Distance ruler toggle
    +-- Unit display
```

##### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `F` | Toggle fog add tool |
| `R` | Toggle fog remove tool |
| `D` | Toggle freehand draw tool |
| `M` | Toggle measurement ruler |
| `G` | Toggle grid visibility |
| `Space` | Toggle pan mode |
| `Ctrl+Z` | Undo drawing |
| `Ctrl+Y` | Redo drawing |
| `+` / `-` | Zoom in / out |
| `0` | Zoom to fit |
| `Tab` | Center on next combatant |

---

### 6.4 Technical Architecture

#### Render Layer System

The battle map uses a `QGraphicsScene` with items organized by Z-value into logical layers:

```python
class BattleMapLayers:
    MAP_IMAGE = 0
    GRID_OVERLAY = 50
    TOKEN_LAYER = 100
    DRAWING_LAYER = 150
    FOG_LAYER = 200
    UI_OVERLAY = 300
```

Each layer can be independently toggled visible/invisible in the DM view. The player view always shows: map image, grid (if enabled), tokens (visible ones only), fog (applied), and shared drawings.

#### Persistence

Battle map state is persisted as part of the encounter/session data:

```python
{
    "battlemap": {
        "map_image_path": str,
        "grid_config": {...},           # Serialized GridConfig
        "fog_data": str,                # Base64-encoded fog image
        "drawings": [...],              # List of serialized DrawingObjects
        "tokens": [...],                # List of token states
        "viewport": {                   # Last DM viewport
            "center_x": float,
            "center_y": float,
            "zoom": float
        }
    }
}
```

#### Sync-Ready Identifiers

All battlemap objects use UUIDs for identification:
- `drawing_id` for each drawing object
- `token_id` for each token
- `map_id` for the battle map instance

These deterministic IDs enable future online sync where specific objects can be referenced across client and server.

#### Performance Budget

| Metric | Target |
|--------|--------|
| Frame rate (60fps target) | Map up to 4096x4096, 50 tokens, 100 drawings |
| Fog update latency | < 50ms for polygon operations |
| Grid rendering | < 16ms per frame (to maintain 60fps) |
| Token drag responsiveness | < 16ms input-to-visual lag |

##### Optimization Strategies

1. **Tile-based rendering:** For large maps, divide the background into tiles and only render visible tiles.
2. **Cached grid overlay:** Render the grid to an off-screen image and only regenerate when grid settings change or zoom changes significantly.
3. **Batched drawing updates:** Collect multiple drawing operations and apply them in a single paint cycle.
4. **Level-of-detail for tokens:** At low zoom levels, render tokens as simple colored circles instead of full portrait images.

### 6.5 New Files Required

| File | Purpose |
|------|---------|
| `core/battlemap/grid_config.py` | GridConfig dataclass and grid math utilities |
| `core/battlemap/grid_renderer.py` | Grid rendering for each grid mode |
| `core/battlemap/drawing_objects.py` | DrawingObject, DrawingStyle, DrawingAction models |
| `core/battlemap/measurement.py` | Distance calculation and ruler logic |
| `core/battlemap/__init__.py` | Package init |
| `ui/widgets/battlemap_toolbar.py` | DM Battlemap Toolbar widget |
| `ui/widgets/drawing_tools.py` | Drawing tool implementations |
| `ui/widgets/grid_settings_dialog.py` | Grid configuration dialog |
| `tests/test_core/test_grid_math.py` | Grid coordinate conversion tests |
| `tests/test_core/test_measurement.py` | Distance measurement tests |
| `tests/test_core/test_drawing.py` | Drawing CRUD and undo/redo tests |

### 6.6 Definition of Done

- DM can switch between square, hex (pointy), and hex (flat) grid modes during encounter setup.
- Grid size, color, opacity, and snapping are configurable.
- Distance measurement ruler works correctly for all grid modes with configurable units.
- DM can draw freehand, lines, rectangles, ellipses, and text annotations.
- Drawing actions support undo/redo (minimum 100 steps).
- All battlemap state (grid, drawings, fog, tokens) persists with the encounter.
- Battlemap controls are organized in a dedicated toolbar.
- Keyboard shortcuts work for common actions.
- Performance remains above 30fps with a 4096x4096 map, 50 tokens, and 100 drawings.
- Player view correctly displays fog-revealed areas and visible tokens.

---

## 7. Initiative D: Community Wiki and Content Sharing

### 7.1 Overview

This initiative creates the foundation for a community content ecosystem where users can publish, discover, and install shared content. Since this is pre-online work, the focus is on local/offline package tooling with a structure that can seamlessly evolve into an online catalog.

### 7.2 Product Goal

Enable users to:
1. Export their world templates, complete worlds, and asset collections as shareable packages.
2. Import packages from other users with validation and conflict resolution.
3. Browse a local catalog of available packages.
4. Trust that imported packages are safe and compatible.

### 7.3 Package Specification

#### Package Types

##### Template Package (`.dmt-template`)

Contains a world schema only (categories, fields, encounter layouts). No entity data.

**Use case:** "I made a great schema for running Shadowdark campaigns. Here is the template so you can use the same entity structure."

##### World Package (`.dmt-world`)

Contains a world schema plus entity data, map data, session templates, and assets.

**Use case:** "I prepared a complete module with locations, NPCs, monsters, and maps. Here is everything you need to run it."

##### Asset Pack (`.dmt-assets`)

Contains reusable assets (images, tokens, maps, audio themes) without schema or entity data.

**Use case:** "Here are 100 fantasy token images you can use in your games."

#### Internal Structure (All Package Types)

```
package-file.dmt-{type} (ZIP archive)
|-- manifest.json              # Package metadata and integrity info
|-- content/                   # Package type-specific content
|   |-- schema/                # (template and world only)
|   |   |-- world_schema.json
|   |   |-- categories/
|   |   |-- encounter_layouts/
|   |-- entities/              # (world only)
|   |   |-- {entity_id}.json   # One file per entity
|   |-- maps/                  # (world and asset only)
|   |   |-- {map_id}/
|   |       |-- map_data.json
|   |       |-- map_image.png
|   |-- sessions/              # (world only)
|   |   |-- {session_id}.json
|   |-- mind_maps/             # (world only)
|       |-- {mind_map_id}.json
|-- assets/                    # Shared assets
|   |-- images/                # Entity images, token images
|   |-- audio/                 # Audio themes and sound effects
|   |-- icons/                 # Custom category icons
|   |-- tokens/                # Battle map tokens
|   |-- pdfs/                  # PDF documents
|-- previews/                  # Package preview images
|   |-- thumbnail.png          # Required: 400x300 package thumbnail
|   |-- screenshots/           # Optional: additional screenshots
|-- LICENSE                    # License file
|-- README.md                  # Optional: human-readable description
```

#### Manifest Schema (Complete)

```json
{
    "manifest_version": "1.0",
    "package_type": "template|world|assets",
    "package_id": "uuid-v4",
    "title": "Package Title",
    "description": "Detailed description of the package contents and purpose.",
    "author": {
        "name": "Author Name",
        "contact": "optional-email@example.com",
        "url": "https://optional-website.com"
    },
    "version": "1.0.0",
    "created_at": "2026-03-18T12:00:00Z",
    "updated_at": "2026-03-18T12:00:00Z",
    "compatible_app_versions": ">=0.8.0",
    "license": "CC-BY-4.0",
    "tags": ["fantasy", "dark", "low-magic"],
    "language": "en",
    "game_system": "Shadowdark",
    "content_summary": {
        "categories_count": 18,
        "fields_count": 95,
        "entities_count": 150,
        "maps_count": 12,
        "sessions_count": 5,
        "assets_count": 200,
        "total_size_bytes": 52428800
    },
    "dependencies": [],
    "checksum": {
        "algorithm": "sha256",
        "value": "abc123def456..."
    },
    "file_whitelist_version": "1.0"
}
```

#### Safety and Validation

##### File Type Whitelist

Only the following file types are permitted inside packages:

| Category | Allowed Extensions |
|----------|-------------------|
| Data | `.json`, `.yaml`, `.yml` |
| Images | `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.svg` |
| Audio | `.mp3`, `.ogg`, `.wav`, `.flac` |
| Documents | `.pdf`, `.md`, `.txt` |
| Icons | `.png`, `.svg`, `.ico` |

Any package containing files outside this whitelist is rejected during import.

##### Integrity Validation

1. **Checksum verification:** The SHA-256 checksum in the manifest is computed over all files in the archive (excluding the manifest itself). On import, the checksum is recalculated and compared.
2. **Manifest schema validation:** The manifest must conform to the defined JSON schema. Missing required fields or unknown fields cause import failure.
3. **Content structure validation:** The internal directory structure must match the expected layout for the package type.
4. **Size limits:** Individual files must not exceed 100MB. Total package size must not exceed 1GB. These limits are configurable.
5. **Path traversal prevention:** All file paths in the archive are checked for directory traversal attacks (`../`, absolute paths).

##### Import Preview

Before any package is applied, the user sees a preview dialog showing:
- Package metadata (title, author, version, description)
- Content summary (number of entities, maps, assets)
- Compatibility status (app version check)
- Conflict analysis (what will be overwritten, what is new)
- License information
- "Apply" and "Cancel" buttons

### 7.4 Publisher Tools

#### Export Package Wizard

A step-by-step wizard dialog for creating packages:

##### Step 1: Package Type Selection
- Radio buttons: Template, World, Asset Pack
- Brief description of each type

##### Step 2: Content Selection
- For Template: automatically includes current world schema
- For World: checkboxes for which components to include (entities, maps, sessions, mind maps)
- For Assets: file/folder browser to select assets

##### Step 3: Metadata
- Title (required)
- Description (required)
- Author name (required, pre-filled from settings)
- Version (required, default "1.0.0")
- Tags (comma-separated or tag picker)
- Game system (optional text)
- License selector (dropdown with common licenses: CC-BY, CC-BY-SA, CC-BY-NC, CC0, MIT, Custom)

##### Step 4: Preview and Thumbnail
- Auto-generated content summary
- Thumbnail image selector (optional)
- Screenshot selector (optional)

##### Step 5: Validation and Export
- Run all validation checks
- Display validation results (pass/fail for each check)
- File save dialog for the output package

#### Validation Summary

The validation step checks:
1. All required metadata fields are filled.
2. All referenced files exist and are within the whitelist.
3. The schema (if included) is internally consistent.
4. Entity references are valid (no dangling entity_id references).
5. Total package size is within limits.
6. Checksum is computed and embedded in the manifest.

### 7.5 Consumer Tools

#### Local Package Browser

A dialog for browsing locally available packages (stored in a designated folder like `{DATA_ROOT}/packages/`).

##### Layout

```
Package Browser Dialog (QDialog, 1000x700)
+-- Top Bar
|   +-- Search box
|   +-- Filter dropdowns: Type, Tags, Game System, License
|   +-- Sort: Name, Date, Size
+-- Package List (left panel, 350px)
|   +-- Package cards showing: thumbnail, title, author, version, tags
|   +-- Scroll with lazy loading
+-- Package Detail (right panel)
    +-- Large thumbnail / screenshots
    +-- Full metadata display
    +-- Content summary
    +-- Compatibility status
    +-- [Install] / [Update] / [Remove] buttons
    +-- License display
```

##### Install Flow

1. User selects a package and clicks "Install".
2. Validation runs (checksum, file whitelist, schema compatibility).
3. Conflict analysis runs:
   - If the package is a template and the current world already has a schema, show merge options.
   - If the package is a world, show options for creating a new world or merging into existing.
   - If the package is an asset pack, show the target directory and any file name conflicts.
4. Conflict resolution dialog:
   - For each conflict: Keep existing, Replace with imported, Rename imported.
   - "Apply to all" checkbox for bulk resolution.
5. Import executes with a progress bar.
6. Post-import summary shows what was added, modified, and skipped.

### 7.6 Moderation Foundations

While full moderation is an online-phase concern, the pre-online phase establishes the data structures and workflows that moderation will use.

#### Content Status Model

```python
class ContentStatus(Enum):
    DRAFT = "draft"           # Not yet published, author-only
    PUBLISHED = "published"   # Available in catalog
    FLAGGED = "flagged"       # Under review due to a report
    DEPRECATED = "deprecated" # No longer recommended, still downloadable
    REMOVED = "removed"       # Removed from catalog, not downloadable
```

Every package manifest includes a `status` field (default: `draft`). The local package browser only shows `published` packages by default (with a toggle to show all).

#### Report Metadata Schema

```json
{
    "report_id": "uuid-v4",
    "package_id": "uuid-v4",
    "reporter_id": "anonymous",
    "report_type": "content_violation|copyright|malicious|other",
    "description": "Free-text description of the issue",
    "created_at": "2026-03-18T12:00:00Z",
    "status": "pending|reviewed|resolved|dismissed"
}
```

This schema is defined now but the reporting UI and workflow are implemented in the online phase.

#### Audit-Ready Package Manifest

The manifest includes all information needed for future moderation:
- Author identity (name, contact)
- License declaration
- Content summary (allows automated screening)
- Checksum (prevents post-publication tampering)
- File whitelist version (ensures safety standards were applied)

### 7.7 New Files Required

| File | Purpose |
|------|---------|
| `core/packages/package_types.py` | Package type enums and constants |
| `core/packages/manifest.py` | Manifest dataclass and validation |
| `core/packages/exporter.py` | Package export logic |
| `core/packages/importer.py` | Package import and validation logic |
| `core/packages/integrity.py` | Checksum computation and verification |
| `core/packages/conflict_resolver.py` | Import conflict detection and resolution |
| `core/packages/__init__.py` | Package init |
| `ui/dialogs/export_wizard.py` | Export package wizard dialog |
| `ui/dialogs/package_browser.py` | Local package browser dialog |
| `ui/dialogs/import_preview.py` | Import preview and conflict resolution dialog |
| `tests/test_core/test_package_export.py` | Export tests |
| `tests/test_core/test_package_import.py` | Import and validation tests |
| `tests/test_core/test_package_integrity.py` | Checksum and security tests |

### 7.8 Definition of Done

- Users can export template, world, and asset packages through the export wizard.
- Exported packages conform to the specified internal structure and manifest schema.
- Import validates checksums, file whitelists, and schema compatibility.
- Import blocks packages with unsafe file types or path traversal attempts.
- Import shows a preview with conflict analysis before applying.
- The local package browser can list, search, filter, and sort available packages.
- Package manifests are versioned and include all required metadata.
- The data structures support future migration to a server-hosted catalog without format changes.

---

## 8. Initiative E: Audio System Improvements

### 8.1 Overview

The audio system (`MusicBrain` engine in `core/audio/engine.py`) provides layered, multi-track audio playback with themes, states (Normal, Combat, Victory), and ambience slots. This initiative addresses audio quality issues --- specifically abrupt transitions between loops and the lack of transitional sound effects.

### 8.2 Current Audio Architecture

```
MusicBrain (QObject)
+-- active_deck: MultiTrackDeck
|   +-- players: Dict[str, TrackPlayer]
|       +-- Each TrackPlayer wraps QMediaPlayer + QAudioOutput
|       +-- volume property with QPropertyAnimation for fading
+-- crossfade_deck: MultiTrackDeck (for transitions)
+-- ambience_players: List[TrackPlayer]
+-- sfx_player: QMediaPlayer (one-shot sounds)
```

**Current state transitions:**
1. DM selects a new state (e.g., Normal -> Combat).
2. The active deck fades out over ~1500ms.
3. The crossfade deck loads the new state tracks and fades in over ~1500ms.
4. When the fade completes, the decks swap roles.

**Problem:** The crossfade is a simple volume fade, which creates an audible gap or overlap depending on the audio content. There is no support for transition sounds (stingers) between states.

### 8.3 Workstream E1: Soundpad Transitions (Issue #29)

#### Problem Statement

GitHub issue #29 reports two problems:
1. Loop switching causes audio glitches (pops, gaps, or unnatural overlaps).
2. There is no support for "mid-length" transition sounds between loops.

#### Root Cause Analysis

The `TrackPlayer.fade_to()` method uses `QPropertyAnimation` with an `InOutQuad` easing curve. The fade duration is fixed at 1500ms. The problems are:

1. **Glitch at loop boundary:** The `_on_position_changed` method detects loop completion by checking if `position < self.last_position`, which is unreliable for very short loops or when the position jumps due to buffering.
2. **No gap management:** When transitioning between states, there is a moment when both decks are audible. If the musical keys or tempos do not match, this sounds bad.
3. **No transition sounds:** The engine has no concept of a one-shot transition sound (stinger) that plays during a crossfade.

#### Solution Design

##### Improved Crossfade Logic

```python
class CrossfadeController:
    """Manages smooth transitions between audio states."""

    def transition(self, from_deck: MultiTrackDeck, to_deck: MultiTrackDeck,
                   transition_config: TransitionConfig):
        """
        Execute a state transition with configurable crossfade behavior.
        """
        # Phase 1: Pre-transition (optional stinger)
        if transition_config.stinger_path:
            self.play_stinger(transition_config.stinger_path,
                            transition_config.stinger_volume)

        # Phase 2: Fade out current
        from_deck.fade_to(0.0, duration=transition_config.fade_out_ms)

        # Phase 3: Wait for overlap period
        # (stinger fills the gap)
        QTimer.singleShot(transition_config.gap_ms,
                         lambda: self._start_fade_in(to_deck, transition_config))

    def _start_fade_in(self, to_deck, config):
        """Start the fade-in of the new state."""
        to_deck.deck_volume = 0.0
        to_deck.play()
        to_deck.fade_to(config.target_volume, duration=config.fade_in_ms)
```

##### Transition Configuration

```python
@dataclass
class TransitionConfig:
    fade_out_ms: int = 2000        # Duration of fade-out
    fade_in_ms: int = 2000         # Duration of fade-in
    gap_ms: int = 500              # Gap between fade-out end and fade-in start
    overlap_ms: int = 0            # Overlap (if > 0, fade-in starts before fade-out ends)
    stinger_path: Optional[str] = None  # Path to transition sound
    stinger_volume: float = 0.8    # Volume of transition sound
    stinger_delay_ms: int = 0      # Delay before stinger plays
    easing_out: str = "InOutQuad"  # Easing curve for fade-out
    easing_in: str = "InOutQuad"   # Easing curve for fade-in
```

Themes can define transition configs per state pair:
```yaml
transitions:
  Normal->Combat:
    fade_out_ms: 1000
    fade_in_ms: 1500
    stinger: "stingers/battle_start.ogg"
    stinger_volume: 0.9
  Combat->Victory:
    fade_out_ms: 2000
    fade_in_ms: 3000
    stinger: "stingers/victory_fanfare.ogg"
  Combat->Normal:
    fade_out_ms: 2500
    fade_in_ms: 2000
```

### 8.4 Workstream E2: Loop Switching Improvements

#### Problem

When the engine switches loops within a state (e.g., changing intensity levels), the transition can create pops or phase cancellation artifacts.

#### Solution

1. **Beat-aligned switching:** If the audio file includes BPM metadata (or it is specified in the theme YAML), schedule loop switches to occur at beat boundaries. This prevents cutting off a phrase mid-note.

2. **Pre-buffered next loop:** When the current loop is approaching its end (within 500ms), pre-load and buffer the next loop so the switch is instantaneous.

3. **Micro-crossfade:** Apply a very short crossfade (50-100ms) at loop boundaries to eliminate clicks. This is shorter than the state transition crossfade and is essentially a declicking filter.

```python
class TrackPlayer(QObject):
    DECL_CROSSFADE_MS = 80  # Micro-crossfade to prevent clicks

    def _on_position_changed(self, position):
        duration = self.player.duration()
        if duration <= 0:
            return

        # Near end of loop - prepare for seamless loop or switch
        remaining = duration - position
        if remaining < self.DECL_CROSSFADE_MS and remaining > 0:
            self._apply_micro_fade_out()

        # Detect loop restart
        if position < self.last_position and position < 500:
            self._apply_micro_fade_in()
            self.loop_finished.emit()

        self.last_position = position

    def _apply_micro_fade_out(self):
        """Quick fade to prevent click at loop end."""
        self.fade_to(self._volume * 0.3, duration=self.DECL_CROSSFADE_MS)

    def _apply_micro_fade_in(self):
        """Quick fade in after loop restart."""
        self.audio.setVolume(0.0)
        self.fade_to(self._volume, duration=self.DECL_CROSSFADE_MS)
```

### 8.5 Workstream E3: Mid-Length Transition Sounds

#### Feature Description

A "stinger" is a short musical phrase (1-5 seconds) that plays during state transitions to bridge the gap between the outgoing and incoming loops. Examples:
- A dramatic drum hit when combat starts
- A triumphant horn phrase when combat ends in victory
- A somber string swell when transitioning to exploration after a loss

#### Implementation

1. **Stinger files:** Stored in the theme's `stingers/` directory.
2. **Stinger playback:** Uses a dedicated `QMediaPlayer` instance (separate from the loop players and SFX player) so it does not interfere with other audio.
3. **Stinger timing:** Controlled by the `TransitionConfig.stinger_delay_ms` parameter.
4. **Volume ducking:** During stinger playback, the ambience tracks are ducked by 30% to make the stinger more prominent.

```python
class StingerPlayer(QObject):
    """Dedicated player for transition stinger sounds."""
    finished = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.player = QMediaPlayer()
        self.audio = QAudioOutput()
        self.player.setAudioOutput(self.audio)
        self.player.mediaStatusChanged.connect(self._on_status)

    def play(self, file_path: str, volume: float = 0.8):
        if not os.path.exists(file_path):
            return
        self.audio.setVolume(volume)
        self.player.setSource(QUrl.fromLocalFile(os.path.abspath(file_path)))
        self.player.play()

    def _on_status(self, status):
        if status == QMediaPlayer.MediaStatus.EndOfMedia:
            self.finished.emit()
```

### 8.6 Workstream E4: Audio Engine Optimizations

#### Memory Management

- Release `QMediaPlayer` resources when a theme is unloaded.
- Limit the number of simultaneously active `TrackPlayer` instances.
- Pre-load only the current state and the most likely next state (e.g., Normal pre-loads Combat tracks).

#### State Serialization

Prepare the audio engine state for future online sync:

```python
@dataclass
class AudioEngineState:
    """Serializable snapshot of the audio engine state."""
    theme_id: Optional[str]
    state_id: Optional[str]
    intensity_level: str
    master_volume: float
    ambience_slots: List[Dict[str, Any]]
    is_playing: bool
    transition_in_progress: bool

    def to_dict(self) -> dict:
        """Serialize to a plain dict for network transmission."""
        return {
            "theme_id": self.theme_id,
            "state_id": self.state_id,
            "intensity_level": self.intensity_level,
            "master_volume": self.master_volume,
            "ambience_slots": self.ambience_slots,
            "is_playing": self.is_playing,
        }
```

### 8.7 Files Affected and New Files

| File | Change |
|------|--------|
| `core/audio/engine.py` | Refactor transition logic, add CrossfadeController, StingerPlayer |
| `core/audio/models.py` | Add TransitionConfig, AudioEngineState |
| `core/audio/loader.py` | Parse transition configs from theme YAML |
| `ui/soundpad_panel.py` | UI for transition settings (optional, DM-configurable fade times) |
| `tests/test_core/test_audio_transitions.py` | **NEW** Transition logic tests |
| `tests/test_core/test_audio_state.py` | **NEW** Audio state serialization tests |

### 8.8 Definition of Done

- State transitions use configurable crossfade with stinger support.
- Loop switching has no audible clicks or pops (micro-crossfade applied).
- Themes can define per-transition stinger sounds and fade timings.
- Audio engine state is serializable for future online sync.
- GitHub issue #29 is closed.
- Manual listening test passes for all transition types (Normal->Combat, Combat->Victory, Combat->Normal).

---

## 9. Initiative F: Auto Event Log System

### 9.1 Overview

Combat is currently a visual-only experience in the session tab. Actions taken during combat (damage dealt, healing applied, conditions added, rounds advanced) are tracked in the widget state but not persisted as a structured event log. The `session.logs` field exists but is a free-text string that must be manually written by the DM.

This initiative implements automatic event logging for combat.

### 9.2 Product Goal

Every significant combat event is automatically recorded in a structured, readable log that:
1. Provides a round-by-round history of combat.
2. Can be reviewed after the session.
3. Displays in the Session/Docs tab.
4. Uses a structured format suitable for future online event streaming.

### 9.3 Event Types

```python
class CombatEventType(Enum):
    COMBAT_START = "combat_start"
    COMBAT_END = "combat_end"
    ROUND_START = "round_start"
    ROUND_END = "round_end"
    TURN_START = "turn_start"
    TURN_END = "turn_end"
    DAMAGE_DEALT = "damage_dealt"
    HEALING_APPLIED = "healing_applied"
    CONDITION_ADDED = "condition_added"
    CONDITION_REMOVED = "condition_removed"
    CONDITION_EXPIRED = "condition_expired"
    HP_CHANGED = "hp_changed"
    INITIATIVE_ROLLED = "initiative_rolled"
    COMBATANT_ADDED = "combatant_added"
    COMBATANT_REMOVED = "combatant_removed"
    COMBATANT_DEFEATED = "combatant_defeated"
    TOKEN_MOVED = "token_moved"
    DICE_ROLL = "dice_roll"
    DM_NOTE = "dm_note"
```

### 9.4 Event Data Model

```python
@dataclass
class CombatEvent:
    event_id: str              # UUID
    event_type: CombatEventType
    timestamp: str             # ISO 8601
    round_number: int          # Current combat round
    turn_order_index: int      # Whose turn it is (index in initiative order)
    actor_id: Optional[str]    # Entity ID of the acting combatant
    actor_name: str            # Display name (cached for log readability)
    target_id: Optional[str]   # Entity ID of the target (if applicable)
    target_name: Optional[str] # Target display name
    details: Dict[str, Any]    # Event-type-specific details

@dataclass
class DamageDetails:
    amount: int
    damage_type: str           # "slashing", "fire", etc.
    is_critical: bool
    previous_hp: int
    new_hp: int
    source: str                # "weapon", "spell", "environment", etc.

@dataclass
class HealingDetails:
    amount: int
    previous_hp: int
    new_hp: int
    source: str

@dataclass
class ConditionDetails:
    condition_name: str
    duration: int
    max_duration: int
    source: Optional[str]

@dataclass
class DiceRollDetails:
    notation: str              # "2d6+3", "1d20"
    rolls: List[int]           # Individual die results
    modifier: int
    total: int
    purpose: str               # "attack", "damage", "saving_throw", "ability_check"
```

### 9.5 Event Log Storage

Events are stored as a list within the session data:

```python
session = {
    "id": "uuid",
    "name": "Session 5",
    "date": "2026-03-18",
    "notes": "...",
    "logs": "...",                    # Existing free-text log (preserved)
    "combat_events": [                # NEW: structured event log
        {
            "event_id": "...",
            "event_type": "damage_dealt",
            "timestamp": "2026-03-18T19:45:30Z",
            "round_number": 3,
            "turn_order_index": 2,
            "actor_id": "...",
            "actor_name": "Goblin Archer",
            "target_id": "...",
            "target_name": "Thorin",
            "details": {
                "amount": 7,
                "damage_type": "piercing",
                "is_critical": false,
                "previous_hp": 25,
                "new_hp": 18,
                "source": "weapon"
            }
        }
    ],
    "combatants": [...]
}
```

### 9.6 Event Emission Points

Events are emitted from the `CombatTracker` widget at these interaction points:

| User Action | Event Type | Emission Point |
|-------------|-----------|----------------|
| Start combat (load encounter) | `COMBAT_START` | `load_encounter()` |
| End combat | `COMBAT_END` | `clear_combatants()` or explicit end |
| Advance round | `ROUND_START`, `ROUND_END` | `next_turn()` when wrapping |
| Advance turn | `TURN_START`, `TURN_END` | `next_turn()` |
| Edit HP (decrease) | `DAMAGE_DEALT` | HP cell edit handler |
| Edit HP (increase) | `HEALING_APPLIED` | HP cell edit handler |
| Add condition | `CONDITION_ADDED` | Condition dialog confirm |
| Remove condition | `CONDITION_REMOVED` | Condition remove button |
| Condition expires (duration reaches 0) | `CONDITION_EXPIRED` | Round advance handler |
| HP reaches 0 | `COMBATANT_DEFEATED` | HP change handler |
| Roll initiative | `INITIATIVE_ROLLED` | Initiative roll handler |
| Add combatant | `COMBATANT_ADDED` | Entity drop handler |
| Remove combatant | `COMBATANT_REMOVED` | Context menu remove |
| Move token on battlemap | `TOKEN_MOVED` | Token drag end handler |
| Roll dice (session tab) | `DICE_ROLL` | `roll_dice()` |

### 9.7 Event Log Display

#### In-Session Live Feed

A new widget in the Session Tab shows a live scrolling feed of combat events during play:

```
+-- Combat Event Feed (QTextBrowser or QListWidget)
    +-- [Round 3]
    |   +-- Goblin Archer's turn
    |   +-- Goblin Archer deals 7 piercing damage to Thorin (25 -> 18 HP)
    |   +-- Thorin's turn
    |   +-- Thorin deals 12 slashing damage to Goblin Archer (15 -> 3 HP)
    |   +-- Thorin moves to (5, 8)
    +-- [Round 4]
        +-- Goblin Archer's turn
        +-- ...
```

#### Post-Session Review

The event log is rendered as formatted HTML in the session's log viewer:
- Events are grouped by round.
- Damage events are color-coded (red for damage, green for healing).
- Defeated combatants are highlighted.
- Statistics summary at the end: total damage dealt, total healing, rounds elapsed, combatants defeated.

#### Event Log Formatting

```python
class EventLogFormatter:
    """Formats combat events into human-readable text and HTML."""

    def format_event(self, event: CombatEvent) -> str:
        """Returns a plain-text representation of the event."""
        formatters = {
            CombatEventType.DAMAGE_DEALT: self._fmt_damage,
            CombatEventType.HEALING_APPLIED: self._fmt_healing,
            CombatEventType.CONDITION_ADDED: self._fmt_condition_add,
            CombatEventType.CONDITION_REMOVED: self._fmt_condition_remove,
            CombatEventType.ROUND_START: self._fmt_round_start,
            CombatEventType.COMBATANT_DEFEATED: self._fmt_defeat,
            CombatEventType.DICE_ROLL: self._fmt_dice,
            # ... other formatters
        }
        formatter = formatters.get(event.event_type, self._fmt_generic)
        return formatter(event)

    def _fmt_damage(self, event: CombatEvent) -> str:
        d = event.details
        crit = " (CRITICAL)" if d.get("is_critical") else ""
        return (f"{event.actor_name} deals {d['amount']} {d.get('damage_type', '')} "
                f"damage to {event.target_name}{crit} "
                f"({d['previous_hp']} -> {d['new_hp']} HP)")

    def _fmt_healing(self, event: CombatEvent) -> str:
        d = event.details
        return (f"{event.actor_name} heals {event.target_name} for {d['amount']} HP "
                f"({d['previous_hp']} -> {d['new_hp']} HP)")

    def _fmt_round_start(self, event: CombatEvent) -> str:
        return f"--- Round {event.round_number} ---"

    def _fmt_defeat(self, event: CombatEvent) -> str:
        return f"{event.target_name} has been defeated!"

    def _fmt_dice(self, event: CombatEvent) -> str:
        d = event.details
        rolls_str = ", ".join(str(r) for r in d.get("rolls", []))
        return f"{event.actor_name} rolls {d['notation']}: [{rolls_str}] + {d.get('modifier', 0)} = {d['total']}"
```

### 9.8 New Files Required

| File | Purpose |
|------|---------|
| `core/combat/events.py` | CombatEvent, CombatEventType, detail dataclasses |
| `core/combat/event_log.py` | Event log storage and querying |
| `core/combat/event_formatter.py` | Text and HTML formatting |
| `core/combat/__init__.py` | Package init |
| `ui/widgets/event_feed.py` | Live event feed widget |
| `tests/test_core/test_combat_events.py` | Event creation and formatting tests |

### 9.9 Definition of Done

- All combat actions listed in Section 9.6 automatically generate structured events.
- Events are stored in the session data and persist across saves.
- A live event feed displays during combat in the Session Tab.
- Post-session review shows a formatted, grouped event log.
- Event data model is compatible with future WebSocket streaming.
- Existing sessions that lack `combat_events` load without error (empty list default).

---

## 10. Initiative G: Embedded PDF Viewer

### 10.1 Overview

The application needs a native PDF viewer that integrates into the Session/Docs tab, allowing DMs to reference rulebooks, module PDFs, and handouts without switching to an external application.

### 10.2 Current State

PDF viewing exists in the `PlayerWindow` using `QWebEngineView`:

```python
def show_pdf(self, pdf_path):
    if self.pdf_viewer is None:
        from PyQt6.QtWebEngineWidgets import QWebEngineView
        self.pdf_viewer = QWebEngineView()
        # ... setup
    self.stack.setCurrentIndex(self.pdf_viewer_index)
    local_url = QUrl.fromLocalFile(pdf_path)
    self.pdf_viewer.setUrl(local_url)
```

This is player-facing only. The DM has no integrated PDF viewer in the main window.

### 10.3 Target State

#### Session/Docs Tab Integration

Add a "Docs" sub-tab within the Session Tab (or as a new top-level tab) that provides:

1. **PDF file list:** Shows all PDFs associated with the current campaign (from entity `pdfs` fields and a campaign-level `docs/` directory).
2. **Embedded PDF viewer:** Renders the selected PDF using `QWebEngineView`.
3. **Quick navigation:** Page number input, next/previous page buttons, zoom controls.
4. **Entity linking:** DM can associate PDF pages with entities (e.g., "Monster Manual page 156 = Beholder stat block") for quick cross-reference.

#### Layout Design

```
Session Tab
+-- Sub-tabs (QTabWidget)
    +-- Combat (existing combat tracker + event feed)
    +-- Notes (existing session notes editor)
    +-- Docs (NEW)
        +-- Left Panel (200px)
        |   +-- PDF File List (QListWidget)
        |   +-- [+ Add PDF] button
        |   +-- [Remove] button
        +-- Right Panel (expandable)
            +-- PDF Toolbar
            |   +-- [<] [>] Page navigation
            |   +-- Page number input / total pages display
            |   +-- Zoom controls (+/-/fit)
            |   +-- [Project to Player] button
            +-- QWebEngineView (PDF renderer)
```

### 10.4 PDF Rendering Approach

#### Primary: QWebEngineView

Use `QWebEngineView` with built-in PDF rendering (Chromium's PDF viewer). This is already proven in the Player Window.

**Advantages:**
- No additional dependencies.
- Good rendering quality.
- Supports bookmarks, text selection, and search.

**Disadvantages:**
- Heavy dependency (QtWebEngine).
- Limited programmatic control over the rendered PDF.
- Memory usage can be high for large PDFs.

#### Configuration

```python
class PdfViewerConfig:
    enable_text_selection: bool = True
    default_zoom: float = 1.0
    remember_position: bool = True  # Remember last-viewed page per PDF
    max_recent_pdfs: int = 20
```

### 10.5 Campaign PDF Management

PDFs associated with a campaign are tracked in the campaign data:

```python
self.data["campaign_pdfs"] = [
    {
        "pdf_id": "uuid",
        "file_path": "relative/path/to/file.pdf",
        "display_name": "Monster Manual",
        "last_viewed_page": 156,
        "bookmarks": [
            {"page": 156, "label": "Beholder", "entity_id": "optional-link"}
        ],
        "added_at": "2026-03-18T12:00:00Z"
    }
]
```

### 10.6 Annotation Support (Future Phase)

While full annotation is out of scope for the pre-online phase, the data model should accommodate future annotations:

```python
@dataclass
class PdfAnnotation:
    annotation_id: str
    pdf_id: str
    page: int
    rect: Tuple[float, float, float, float]  # x, y, width, height (relative to page)
    annotation_type: str  # "highlight", "note", "link"
    content: str          # Note text or link target
    color: str            # Hex color for highlights
    created_at: str
```

This is defined as a data model only; the UI for creating annotations is deferred.

### 10.7 Files Affected and New Files

| File | Change |
|------|--------|
| `ui/tabs/session_tab.py` | Add Docs sub-tab |
| `core/data_manager.py` | Add campaign_pdfs to data structure, save/load logic |
| **NEW** `ui/widgets/pdf_viewer.py` | Embedded PDF viewer widget |
| **NEW** `ui/widgets/pdf_file_list.py` | PDF file list with management |
| `tests/test_ui/test_pdf_viewer.py` | **NEW** PDF viewer integration tests |

### 10.8 Definition of Done

- DM can add PDFs to the campaign and view them in the Session/Docs tab.
- PDF viewer supports page navigation, zoom, and basic controls.
- DM can project a PDF to the Player Window.
- PDF viewer remembers last-viewed page per document.
- Campaign PDF associations persist across saves.
- Application handles missing PDF files gracefully (warning, not crash).

---

## 11. Initiative H: Free Single Import

### 11.1 Overview

Currently, when a DM wants to use a spell, item, or monster from the D&D 5e API, they must first import it into the card entity database and then reference it from another entity. This is cumbersome for quick lookups during play.

### 11.2 Product Goal

Allow users to import an entity from external data sources (D&D 5e API, Open5e) directly into any other entity's related fields (e.g., a character's spell list, an NPC's equipment) without requiring the entity to exist in the campaign database first.

### 11.3 Current Import Flow

```
1. DM opens API Browser dialog
2. DM searches for "Fireball"
3. DM clicks "Import" -> Fireball is created as a Spell entity in the campaign database
4. DM opens NPC "Gandalf" in the entity editor
5. DM manually adds Fireball to Gandalf's spell list by searching/selecting it
```

**Problems:**
- Two separate operations for a single conceptual action.
- The campaign database gets cluttered with imported entities that may only be referenced once.
- The DM's workflow is interrupted by the import step.

### 11.4 Target Flow

```
1. DM opens NPC "Gandalf" in the entity editor
2. In the Spells section, DM clicks "Add Spell"
3. A dialog appears with two tabs:
   a. "Campaign" tab: search existing campaign spells
   b. "Import" tab: search D&D 5e API / Open5e
4. DM searches "Fireball" in the Import tab
5. DM clicks "Add to Gandalf"
6. Fireball is imported and linked to Gandalf in one step
```

### 11.5 UX Flow Design

#### Unified Entity Picker Dialog

A new dialog that combines local search with API import:

```
Entity Picker Dialog (QDialog, 700x500)
+-- Tab Bar
|   +-- "Campaign" tab
|   +-- "D&D 5e API" tab
|   +-- "Open5e" tab
+-- Campaign Tab
|   +-- Search box
|   +-- Entity list (filtered by type)
|   +-- [Select] button
+-- API Tab
|   +-- Search box
|   +-- Results list (from API)
|   +-- Entity preview panel
|   +-- [Import & Select] button
|   +-- Options:
|       +-- [ ] Also add to campaign database (checkbox, default: unchecked)
|       +-- [ ] Import full details (checkbox, default: checked)
```

#### Import Behavior

When "Import & Select" is clicked:

**Option A: Lightweight reference (checkbox unchecked)**
- The entity data is embedded directly in the parent entity's relation field.
- No new entity is created in the campaign database.
- The data includes: name, type, source, and key attributes.
- Trade-off: Data may become stale if the API content updates.

**Option B: Full import (checkbox checked)**
- A new entity is created in the campaign database (same as current import).
- The parent entity references the new entity by ID.
- The DM can later edit the imported entity.

#### Data Model for Lightweight References

```python
@dataclass
class InlineEntityReference:
    """A lightweight entity reference embedded directly in another entity."""
    ref_type: str               # "campaign" or "inline"
    entity_id: Optional[str]    # Campaign entity ID (if ref_type="campaign")
    inline_data: Optional[Dict] # Embedded entity data (if ref_type="inline")
    source_api: Optional[str]   # "dnd5e", "open5e" (if imported from API)
    source_index: Optional[str] # API index/slug for re-fetching
    imported_at: Optional[str]  # ISO 8601 timestamp
```

### 11.6 Integration Points

The Free Single Import feature must be available in all entity editor fields that reference other entities:

| Parent Entity | Relation Field | Target Entity Types |
|---------------|---------------|-------------------|
| NPC / Player | Spells | Spell |
| NPC / Player | Equipment / Inventory | Equipment |
| NPC / Player | Race | Race |
| NPC / Player | Class | Class |
| NPC | Location | Location |
| Status Effect | Linked Condition | Condition |
| Any (custom schema) | Relation fields | As configured |

The `RelationFieldWidget` (from Initiative B's field widget system) must support the unified entity picker.

### 11.7 API Client Changes

The `core/api_client.py` (705 lines) currently supports searching and fetching entity data from the D&D 5e API. Changes needed:

1. **Return structured data:** Instead of returning raw API JSON, return data mapped to the entity structure.
2. **Partial fetch support:** Allow fetching only the fields needed for a lightweight reference without downloading the full entity.
3. **Cache API results:** Use the existing `CACHE_DIR` to cache API responses and reduce repeated network calls.

### 11.8 Files Affected and New Files

| File | Change |
|------|--------|
| `core/api_client.py` | Add structured entity mapping, partial fetch, improved caching |
| `core/models.py` | Add InlineEntityReference model |
| `ui/dialogs/entity_selector.py` | Major refactor: add API tabs, unified picker |
| `ui/widgets/npc_sheet.py` | Update relation field handling to support inline references |
| `ui/widgets/field_widgets.py` | RelationFieldWidget uses unified picker |
| **NEW** `ui/dialogs/unified_entity_picker.py` | Unified entity picker dialog |
| `tests/test_core/test_api_client.py` | Add structured mapping tests |
| **NEW** `tests/test_ui/test_entity_picker.py` | Picker integration tests |

### 11.9 Definition of Done

- DM can add a spell/item/etc. to an entity directly from the API without first importing it to the campaign database.
- The unified entity picker shows both campaign entities and API search results.
- Lightweight references (inline data) work correctly and display properly in the entity editor.
- Full import option creates a proper campaign entity.
- API results are cached to avoid redundant network calls.
- The feature works for all relation fields in both built-in and custom schemas.

---

## 12. Initiative I: Code Quality Foundations

### 12.1 Overview

This initiative addresses cross-cutting code quality concerns that affect developer productivity, code maintainability, and readiness for the online transition. It is not a single feature but a set of mandates that apply to all code, both existing and new.

### 12.2 Workstream I1: Type Hints Rollout

#### Current State

Only ~55 parameter type annotations and ~25 return type annotations exist across the entire codebase. Most functions look like:

```python
def save_entity(self, entity_id, entity_data):
    ...
```

#### Target State

All public function signatures have type hints:

```python
def save_entity(self, entity_id: str, entity_data: Dict[str, Any]) -> bool:
    ...
```

#### Rollout Strategy

1. **Phase 1: Core module.** Add type hints to all public methods in `core/` packages first, since these are the data layer that will need Pydantic models for online.
2. **Phase 2: UI layer.** Add type hints to all public methods in `ui/` packages.
3. **Phase 3: Dataclasses.** Convert all data structures (currently plain dicts) to typed dataclasses or TypedDicts where practical.
4. **Phase 4: Strict mode.** Configure mypy or pyright in the CI pipeline to enforce type checking.

#### Rules

- All new code must include type hints on all function signatures.
- Private methods (prefixed with `_`) should have type hints but it is not mandatory.
- Use `Optional[X]` rather than `X | None` for Python 3.10 compatibility.
- Use `from __future__ import annotations` in all files for forward reference support.
- Prefer specific types (`List[str]`, `Dict[str, Any]`) over `list`, `dict` in annotations.

#### Priority Files for Type Hints

| File | Reason |
|------|--------|
| `core/data_manager.py` | Central data hub, 45+ methods |
| `core/models.py` | Entity schemas and structure |
| `core/api_client.py` | External API integration, 49+ methods |
| `core/audio/engine.py` | Audio engine, will need state serialization |
| `core/audio/models.py` | Already partially typed, complete it |
| `core/library_fs.py` | Library filesystem operations |
| `config.py` | Application configuration |

---

### 12.3 Workstream I2: Logging Framework

#### Current State

62 `print()` statements serve as the only diagnostics. Example from `core/data_manager.py`:

```python
print(f"Cache DAT load error: {e}")
print(f"Cache save error: {e}")
```

#### Target State

A structured logging system using Python's built-in `logging` module.

#### Logger Configuration

```python
# core/logging_config.py

import logging
import logging.handlers
import os
from config import DATA_ROOT

LOG_DIR = os.path.join(DATA_ROOT, "logs")
os.makedirs(LOG_DIR, exist_ok=True)

def setup_logging(level: str = "INFO", log_to_file: bool = True) -> None:
    """Configure application-wide logging."""
    root_logger = logging.getLogger("dmt")
    root_logger.setLevel(getattr(logging, level.upper(), logging.INFO))

    # Console handler
    console = logging.StreamHandler()
    console.setLevel(logging.INFO)
    console.setFormatter(logging.Formatter(
        "%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%H:%M:%S"
    ))
    root_logger.addHandler(console)

    # File handler (rotating, 5MB per file, 3 backups)
    if log_to_file:
        file_handler = logging.handlers.RotatingFileHandler(
            os.path.join(LOG_DIR, "dmt.log"),
            maxBytes=5 * 1024 * 1024,
            backupCount=3,
            encoding="utf-8"
        )
        file_handler.setLevel(logging.DEBUG)
        file_handler.setFormatter(logging.Formatter(
            "%(asctime)s [%(levelname)s] %(name)s (%(filename)s:%(lineno)d): %(message)s"
        ))
        root_logger.addHandler(file_handler)
```

#### Logger Usage Pattern

Each module gets its own logger:

```python
import logging

logger = logging.getLogger("dmt.core.data_manager")

class DataManager:
    def reload_library_cache(self):
        logger.info("Reloading library cache")
        try:
            # ...
        except Exception as e:
            logger.error("Cache DAT load error: %s", e, exc_info=True)
```

#### Migration Plan

1. Create `core/logging_config.py` with the setup function.
2. Call `setup_logging()` in `main.py` before any other imports.
3. Go file by file, replacing each `print()` with the appropriate log call:
   - `print(f"Error: ...")` -> `logger.error(...)`
   - `print(f"Warning: ...")` -> `logger.warning(...)`
   - `print(f"Loaded ...")` -> `logger.info(...)`
   - `print(f"Debug: ...")` -> `logger.debug(...)`
4. Remove all `print()` statements from production code.
5. Keep `print()` in `dev_run.py` and `dump.py` (dev tools) but add a comment explaining why.

#### Log Levels Guide

| Level | Use For |
|-------|---------|
| `DEBUG` | Detailed diagnostic information (data contents, state transitions) |
| `INFO` | Confirmation that things are working (campaign loaded, entity saved) |
| `WARNING` | Something unexpected but recoverable (missing file, fallback used) |
| `ERROR` | Something failed but the application continues (save failed, API error) |
| `CRITICAL` | Application cannot continue (data corruption, missing required resource) |

---

### 12.4 Workstream I3: English Language Standardization

#### Current State

The codebase contains Turkish language artifacts in:
- Comments throughout `core/audio/engine.py`, `ui/widgets/combat_tracker.py`, `core/data_manager.py`, and others
- Default values: `"Yeni Kayit"` (New Record) in `core/models.py`
- Variable names: scattered abbreviations
- Class/method docstrings
- Inline UI text that bypasses the i18n system

#### Target State

All code artifacts are in English. User-facing text continues to use the `tr()` localization function.

#### Migration Plan

1. **Comments:** Translate all Turkish comments to English. This is a manual, file-by-file process.
2. **Default values:** Replace `"Yeni Kayit"` with `"New Entity"` or better, use `tr("DEFAULT_ENTITY_NAME")`.
3. **Variable names:** Rename any Turkish-named variables to English equivalents. Use IDE refactoring to ensure all references are updated.
4. **Docstrings:** Translate all docstrings to English.
5. **Inline text:** Find any user-facing text that is not wrapped in `tr()` and either wrap it or move it to locale files.

#### Files Requiring Translation

Based on code inspection, the following files have significant Turkish content:

| File | Turkish Content |
|------|----------------|
| `core/audio/engine.py` | Comments, docstrings (e.g., "Tek bir muzik katmanini yoneten oynatici") |
| `ui/widgets/combat_tracker.py` | Comments ("YARDIMCILAR", "Suruklenen Entity'leri kabul eden ozel tablo"), condition map comments |
| `core/data_manager.py` | Comments ("Kutüphane indeksini MsgPack olarak kaydeder") |
| `core/theme_manager.py` | Palette key comments (e.g., "Sonsuz arka plan", "Izgara cizgileri") |
| `core/models.py` | Default entity name, some comments |
| `ui/soundpad_panel.py` | Comments ("Varsayilan %50") |
| `main.py` | Default world name fallback ("Bilinmiyor") |

---

### 12.5 Workstream I4: Package Structure (`__init__.py` Files)

#### Current State

Only `core/audio/__init__.py` and `core/dev/__init__.py` exist. All other directories are implicit namespace packages.

#### Target State

Every Python package directory has an `__init__.py` file. These files serve three purposes:

1. **Explicit package declaration:** Makes the package structure unambiguous.
2. **Public API surface:** Exposes the key classes/functions that other modules should import.
3. **Tooling compatibility:** Enables proper behavior in IDEs, linters, and test runners.

#### Files to Create

```
core/__init__.py
ui/__init__.py
ui/tabs/__init__.py
ui/widgets/__init__.py
ui/dialogs/__init__.py
ui/windows/__init__.py
tests/__init__.py
tests/test_core/__init__.py
tests/test_dev/__init__.py
tests/test_ui/__init__.py
```

Additionally, new packages created by other initiatives will include `__init__.py`:
```
core/schema/__init__.py
core/battlemap/__init__.py
core/combat/__init__.py
core/packages/__init__.py
```

#### Content Guidelines

Most `__init__.py` files should be minimal:

```python
"""Core package for Dungeon Master Tool."""
```

For packages with a clear public API, `__init__.py` can re-export key classes:

```python
"""Schema management for the dynamic entity model."""
from .world_schema import WorldSchema, EntityCategorySchema, FieldSchema
from .field_types import FieldType, FieldValidation, FieldVisibility

__all__ = [
    "WorldSchema", "EntityCategorySchema", "FieldSchema",
    "FieldType", "FieldValidation", "FieldVisibility",
]
```

---

### 12.6 Workstream I5: Error Handling Improvements

#### Current State

Error handling is inconsistent. Common patterns found:

```python
# Pattern 1: Bare except
try:
    return int(digits) if digits else default
except: return default

# Pattern 2: Catch-and-print
except Exception as e:
    print(f"Cache save error: {e}")

# Pattern 3: Silent swallow
except OSError:
    pass
```

#### Target State

1. **No bare `except:` clauses.** Always catch specific exceptions.
2. **Log all caught exceptions.** Replace `print()` with `logger.error()` or `logger.warning()`.
3. **User-facing errors use dialogs.** Critical errors that affect the user should show a `QMessageBox`, not just log.
4. **Recoverable errors use fallbacks.** Document the fallback behavior.

#### Error Handling Guidelines

```python
# CORRECT: Specific exception, logging, fallback documented
try:
    with open(cache_path, "rb") as f:
        data = msgpack.unpack(f, raw=False)
except (FileNotFoundError, msgpack.UnpackException) as e:
    logger.warning("Cache load failed, using empty cache: %s", e)
    data = {}  # Fallback: empty cache

# CORRECT: Critical error with user notification
try:
    self._write_data(path, data)
except OSError as e:
    logger.error("Failed to save campaign data: %s", e, exc_info=True)
    QMessageBox.critical(
        None,
        tr("ERROR_SAVE_FAILED_TITLE"),
        tr("ERROR_SAVE_FAILED_MSG", error=str(e))
    )

# WRONG: Bare except
try:
    value = int(s)
except:
    value = 0

# CORRECT: Specific exception
try:
    value = int(s)
except (ValueError, TypeError):
    value = 0
```

#### Priority Files for Error Handling Review

| File | Issue |
|------|-------|
| `core/data_manager.py` | 12 print-based error handlers |
| `core/api_client.py` | 5 print-based error handlers, network errors need retry logic |
| `core/audio/engine.py` | Missing error handling for file-not-found |
| `ui/widgets/combat_tracker.py` | Bare `except:` in `clean_stat_value()` |
| `ui/player_window.py` | Print-based error in image update |

### 12.7 New Files Required

| File | Purpose |
|------|---------|
| `core/__init__.py` | Package init |
| `core/logging_config.py` | Logging configuration |
| `ui/__init__.py` | Package init |
| `ui/tabs/__init__.py` | Package init |
| `ui/widgets/__init__.py` | Package init |
| `ui/dialogs/__init__.py` | Package init |
| `ui/windows/__init__.py` | Package init |
| `ui/constants.py` | UI layout constants (also used by Initiative A) |
| `tests/__init__.py` | Package init |
| `tests/test_core/__init__.py` | Package init |
| `tests/test_dev/__init__.py` | Package init |
| `tests/test_ui/__init__.py` | Package init |

### 12.8 Definition of Done

- All public functions in `core/` and `ui/` packages have type hints on parameters and return values.
- Zero `print()` statements in production code (excluding `dev_run.py` and `dump.py`).
- Structured logging is operational with console and file handlers.
- All comments, docstrings, variable names, and default values are in English.
- All Python package directories have `__init__.py` files.
- No bare `except:` clauses in production code.
- All caught exceptions are logged at the appropriate level.

---

## 13. Dependency Graph

### 13.1 Initiative Dependencies

The following table shows which initiatives depend on which. An initiative cannot be considered complete until its dependencies are also complete.

| Initiative | Depends On | Reason |
|-----------|-----------|--------|
| A (UI/UX) | I (Code Quality) partial | Constants module, logging framework should exist before UI refactoring |
| B (Template) | I (Code Quality) partial | Type hints and package structure needed for schema module |
| C (Battlemap) | A (UI/UX) partial | Battlemap toolbar depends on UI standardization |
| D (Wiki) | B (Template) | Package format depends on template system |
| E (Audio) | I (Code Quality) partial | Logging needed for audio diagnostics |
| F (Event Log) | I (Code Quality) partial | Logging and type hints for event model |
| G (PDF Viewer) | A (UI/UX) partial | Session tab restructuring |
| H (Free Import) | B (Template) partial | Relation field widgets from template system |
| I (Code Quality) | None | Foundation, no dependencies |

### 13.2 Recommended Execution Order

```
Phase 0 (Foundation):
  I-I4: Package structure (__init__.py files)  [1 day]
  I-I2: Logging framework setup                [2 days]
  I-I3: English language pass (comments)       [3 days]
  A-A3: UI constants module                    [1 day]

Phase 1 (Core Infrastructure):
  A-A4: QSS migration (remove inline CSS)      [5 days]
  A-A3: Layout standardization                  [5 days]
  I-I1: Type hints (core/ packages)             [5 days]
  I-I5: Error handling review                   [3 days]

Phase 2 (Major Features - Parallel Track A):
  B: Card and World Template System             [15 days]
    B1: Dynamic categories                      [3 days]
    B2: Dynamic fields                          [4 days]
    B3: Template packaging                      [3 days]
    B4: Encounter integration                   [3 days]
    B-UI: Template Studio + Card Renderer       [5 days]
    B-Migration: Legacy migration               [2 days]

Phase 2 (Major Features - Parallel Track B):
  C: Advanced Battlemap                         [12 days]
    C1: Multi-grid support                      [4 days]
    C2: Measurement tools                       [3 days]
    C3: Drawing layer                           [3 days]
    C4: DM control surface                      [2 days]

Phase 2 (Major Features - Parallel Track C):
  E: Audio improvements                         [5 days]
  F: Event log system                           [5 days]
  G: PDF viewer                                 [3 days]

Phase 3 (Integration):
  A-A1: GM Player Screen Control                [5 days]
  A-A2: Single Player Window                    [5 days]
  H: Free Single Import                         [5 days]
  I-I1: Type hints (ui/ packages)               [5 days]

Phase 4 (Community):
  D: Community Wiki & Content Sharing           [10 days]

Phase 5 (Polish):
  A-A5: Responsive layout improvements          [3 days]
  A-A6: Accessibility basics                    [3 days]
  Final regression testing                      [5 days]
```

### 13.3 Dependency Visualization

```
                    I (Code Quality - Foundation)
                    |
        +-----------+-----------+
        |           |           |
        v           v           v
   A (UI/UX)   B (Template)  E (Audio)
        |           |           |
        |     +-----+-----+    |
        |     |           |    |
        v     v           v    v
   C (Battlemap)    D (Wiki)  F (Event Log)
        |                      |
        v                      v
   G (PDF Viewer)        H (Free Import)
```

### 13.4 Critical Path

The critical path (longest chain of dependent work) is:

```
I (Foundation, 5 days) -> B (Template, 15 days) -> D (Wiki, 10 days) -> Final Testing (5 days)
= 35 days minimum
```

The battlemap and audio work can proceed in parallel on a separate track.

---

## 14. Quality Gates

### 14.1 Testing Requirements by Initiative

#### Initiative A: UI/UX Standardization

| Test Type | Description | Pass Criteria |
|-----------|-------------|---------------|
| Visual QA | Screenshot comparison at 3 resolutions | No layout breaks, no overlapping elements |
| Inline CSS audit | Grep for hardcoded colors in setStyleSheet | Zero matches (excluding palette references) |
| Theme switching | Switch through all 11 themes with all tabs visible | No visual artifacts, all elements update |
| Keyboard navigation | Tab through all interactive elements | All elements reachable, focus visible |
| Player window layout | Test all layout modes with content | Content renders correctly in all modes |

#### Initiative B: Card and World Template System

| Test Type | Description | Pass Criteria |
|-----------|-------------|---------------|
| Unit: Category CRUD | Create, read, update, delete categories | All operations succeed, data persists |
| Unit: Field CRUD | Create, read, update, delete fields | All operations succeed, validation applies |
| Unit: Schema serialization | Serialize and deserialize WorldSchema | Round-trip produces identical data |
| Integration: Migration | Load every legacy campaign format | All entities load, no data loss |
| Integration: Template export | Export a template with 15+ categories | Valid ZIP, valid manifest, valid checksum |
| Integration: Template import | Import the exported template into a new world | Schema matches, no errors |
| Integration: Entity rendering | Open entity of each type with dynamic schema | All fields render with correct widgets |
| Performance: Schema load | Load schema with 50 categories, 500 fields | < 100ms load time |

#### Initiative C: Advanced Battlemap

| Test Type | Description | Pass Criteria |
|-----------|-------------|---------------|
| Unit: Grid math | Coordinate conversions for all grid types | All conversions correct within 0.001 tolerance |
| Unit: Distance calculation | Distance measurement for all grid types | Correct for straight, diagonal, and multi-segment paths |
| Unit: Drawing CRUD | Create, modify, undo, redo drawings | All operations correct, undo/redo stack consistent |
| Integration: Grid rendering | Render each grid type with various sizes | Grid lines align correctly at all zoom levels |
| Performance: Stress test | 4096x4096 map, 50 tokens, 100 drawings | Maintains 30fps minimum |
| Integration: Fog sync | DM fog changes reflect in player view | Player view updates within 100ms |

#### Initiative D: Community Wiki

| Test Type | Description | Pass Criteria |
|-----------|-------------|---------------|
| Unit: Manifest validation | Validate correct and incorrect manifests | Correct manifests pass, incorrect ones fail with specific errors |
| Unit: Checksum | Compute and verify checksums | Checksums match for identical content, differ for modified content |
| Security: File whitelist | Import package with disallowed file types | Import is rejected with clear error message |
| Security: Path traversal | Import package with `../` in file paths | Import is rejected |
| Integration: Export/Import | Full round-trip of each package type | Imported content matches exported content |
| Integration: Conflict resolution | Import template into world with existing schema | Conflicts detected and resolved per user choice |

#### Initiative E: Audio

| Test Type | Description | Pass Criteria |
|-----------|-------------|---------------|
| Unit: Transition config | Parse transition configs from YAML | Configs loaded correctly with correct values |
| Unit: State serialization | Serialize and deserialize AudioEngineState | Round-trip produces identical state |
| Integration: Crossfade | Trigger all state transitions | Smooth transitions with no audible gap |
| Integration: Stinger | Trigger transition with stinger configured | Stinger plays at correct time and volume |
| Manual: Listening test | Human auditor listens to all transition types | No pops, clicks, or unnatural overlaps |

#### Initiative F: Event Log

| Test Type | Description | Pass Criteria |
|-----------|-------------|---------------|
| Unit: Event creation | Create each event type | All required fields populated |
| Unit: Event formatting | Format each event type as text and HTML | Output matches expected format |
| Integration: Combat simulation | Run a 5-round combat with all event types | All events logged in correct order |
| Integration: Persistence | Save and reload session with events | Events survive save/load cycle |
| Integration: Legacy load | Load session without combat_events field | Session loads with empty event list |

#### Initiative G: PDF Viewer

| Test Type | Description | Pass Criteria |
|-----------|-------------|---------------|
| Integration: PDF rendering | Open 3 different PDFs (small, medium, large) | All render correctly |
| Integration: Navigation | Navigate pages, zoom, fit to width | Controls work correctly |
| Integration: Persistence | Close and reopen PDF | Last viewed page is restored |
| Edge case: Missing file | Open PDF that has been deleted | Warning dialog, no crash |

#### Initiative H: Free Single Import

| Test Type | Description | Pass Criteria |
|-----------|-------------|---------------|
| Integration: Inline import | Import spell from API directly to character | Spell appears in character's spell list |
| Integration: Full import | Import spell with "add to database" checked | Spell entity created and linked |
| Integration: Cache | Search same term twice | Second search uses cache, faster response |
| Edge case: Network error | Attempt API import with no internet | Graceful error message |

#### Initiative I: Code Quality

| Test Type | Description | Pass Criteria |
|-----------|-------------|---------------|
| Static: print() audit | Grep for print() in production code | Zero matches (exclude dev tools) |
| Static: type hints | Run mypy on core/ and ui/ | No errors |
| Static: bare except | Grep for `except:` (no exception type) | Zero matches |
| Static: __init__.py | Check all package directories | All have __init__.py |
| Static: English audit | Manual review of comments | No Turkish comments in production code |

### 14.2 Regression Tests

The following regression tests must pass after any initiative is completed:

| Test | Description |
|------|-------------|
| Campaign load (legacy JSON) | Load a campaign saved in JSON format |
| Campaign load (MsgPack) | Load a campaign saved in MsgPack format |
| Campaign load (Turkish entities) | Load a campaign with Turkish-named entity types |
| Entity CRUD | Create, read, update, delete an entity |
| Session CRUD | Create, read, update, delete a session |
| Combat tracker | Start combat, add combatants, advance rounds, end combat |
| Map rendering | Load world map with pins and timeline |
| Mind map | Create nodes, connections, move nodes |
| Theme switching | Switch between all 11 themes |
| Language switching | Switch between all 4 languages |
| Player window | Open player window, project image, project stat block |

### 14.3 Performance Benchmarks

| Component | Metric | Target | Method |
|-----------|--------|--------|--------|
| Campaign load | Time to load 500-entity world | < 2 seconds | Automated test with timer |
| Schema load | Time to load schema with 50 categories | < 100ms | Automated test with timer |
| Entity editor | Time to open entity with 30 fields | < 500ms | Automated test with timer |
| Battlemap render | FPS with 4096x4096 map, 50 tokens | > 30fps | QElapsedTimer in paint event |
| Template export | Time to export 500-entity world | < 5 seconds | Automated test with timer |
| Template import | Time to import 500-entity world | < 10 seconds | Automated test with timer |
| API search | Time for API search with cache hit | < 100ms | Automated test with timer |
| Application startup | Time from launch to UI visible | < 3 seconds | Manual timing |

---

## 15. Risk Register

### 15.1 Initiative A Risks

#### Risk A-1: QSS Migration Breaks Theme Rendering

**Probability:** Medium
**Impact:** High
**Description:** Moving styles from inline Python to QSS files may cause visual regressions in some themes, especially themes with unusual color schemes (Grim, Baldur's Gate).

**Mitigation:**
- Create automated screenshot comparison tests for each theme.
- Migrate one file at a time, testing after each migration.
- Keep a rollback plan: the original inline styles are preserved in version control.

#### Risk A-2: Single Player Window Performance

**Probability:** Low
**Impact:** Medium
**Description:** Rendering the battle map in both the DM window and the Player window simultaneously could cause performance issues, especially with large maps.

**Mitigation:**
- Use a shared state model rather than duplicating the scene.
- The Player view uses a separate, simpler renderer (no editing controls, no fog tool overlay).
- Performance test with the target benchmark (4096x4096 map) before finalizing the architecture.

### 15.2 Initiative B Risks

#### Risk B-1: Schema Complexity Explosion

**Probability:** Medium
**Impact:** High
**Description:** Giving users full control over schemas could lead to excessively complex or broken schemas that cause performance or rendering issues.

**Mitigation:**
- Set limits on schema complexity: maximum 50 categories, maximum 30 fields per category.
- Validate schemas on save: check for circular references, invalid field types, and other structural issues.
- Provide a "Reset to Default" option that restores the built-in D&D 5e schema.
- Show warnings for potentially problematic configurations (e.g., 20+ fields in a category).

#### Risk B-2: Migration Breaks Existing Campaigns

**Probability:** Medium
**Impact:** Critical
**Description:** The automatic migration from fixed schemas to dynamic schemas could lose or corrupt data in edge cases (unusual entity types, modified data files, corrupted data).

**Mitigation:**
- Create backup before migration (automatic).
- Test migration against a diverse corpus of campaign files.
- Support dual-read (old + new format) for one release cycle.
- Provide a manual "re-migrate" tool that re-runs migration with debug output.
- Log every migration decision for post-mortem analysis.

#### Risk B-3: NpcSheet Refactoring Scope

**Probability:** High
**Impact:** Medium
**Description:** The `npc_sheet.py` file is 1002 lines of tightly-coupled UI code. Refactoring it to use dynamic field rendering is a major effort that could introduce regressions in entity editing.

**Mitigation:**
- Keep the old rendering code path as a fallback for one release cycle.
- Introduce the field widget factory incrementally: start with simple types (text, number, boolean), then add complex types (relation, action list).
- Comprehensive integration tests for entity editing flows.

### 15.3 Initiative C Risks

#### Risk C-1: Hex Grid Math Complexity

**Probability:** Medium
**Impact:** Medium
**Description:** Hexagonal grid coordinate systems are non-trivial. Bugs in coordinate conversion could cause token misplacement, incorrect distance calculations, and rendering artifacts.

**Mitigation:**
- Use a well-documented coordinate system (Red Blob Games reference implementation).
- Extensive unit tests for coordinate conversions.
- Visual debug mode that overlays coordinates on the grid for developer testing.

#### Risk C-2: Battlemap Feature Bloat

**Probability:** Medium
**Impact:** Medium
**Description:** The battlemap wishlist (isometric grids, area templates, animated tokens) could expand beyond the pre-online scope.

**Mitigation:**
- Strictly scope Phase 1: square grid, hex grids, measurement, basic drawing, DM toolbar.
- Defer isometric grid, area templates, and advanced features to Phase 2 (post-online foundation).
- Define "nice to have" vs "must have" for each sub-feature.

### 15.4 Initiative D Risks

#### Risk D-1: Unsafe Community Packages

**Probability:** Medium
**Impact:** High
**Description:** Despite file whitelisting and checksum validation, malicious or corrupted packages could cause issues (e.g., extremely large files that consume disk space, deeply nested directory structures that cause path length issues).

**Mitigation:**
- Enforce per-file and total package size limits.
- Limit directory nesting depth to 10 levels.
- Run all import validation in a sandboxed temporary directory before applying.
- Provide an "undo import" feature that removes all imported content.

#### Risk D-2: Package Format Instability

**Probability:** Low
**Impact:** High
**Description:** If the package format changes after early adopters have created packages, backward compatibility becomes a burden.

**Mitigation:**
- Include `manifest_version` in the manifest.
- Design the format to be forward-compatible: unknown fields are ignored, not rejected.
- Commit to the v1.0 manifest format for at least one year before introducing breaking changes.

### 15.5 Initiative E Risks

#### Risk E-1: Audio Quality Regression

**Probability:** Medium
**Impact:** Medium
**Description:** Changes to the crossfade logic could introduce new audio artifacts (clicks, timing issues, volume jumps) that are worse than the current behavior.

**Mitigation:**
- A/B testing: keep the old crossfade code as an option, let testers compare.
- Manual listening tests with diverse audio content (orchestral, ambient, electronic).
- Test on multiple audio hardware configurations.

### 15.6 Initiative F Risks

#### Risk F-1: Event Log Performance

**Probability:** Low
**Impact:** Medium
**Description:** In very long combats (100+ rounds, common in mass battles), the event log could grow large enough to affect save/load performance.

**Mitigation:**
- Events are stored as a flat list (no nesting), which is efficient for MsgPack serialization.
- Implement a configurable maximum event count per session (default: 10,000).
- Older events can be archived to a separate file if the limit is reached.

### 15.7 Initiative G Risks

#### Risk G-1: QtWebEngine Dependency Size

**Probability:** Low
**Impact:** Low
**Description:** `QWebEngineView` adds significant binary size (~100MB) to the packaged application.

**Mitigation:**
- The dependency already exists (used in Player Window for PDF rendering).
- No additional cost for the embedded PDF viewer.

### 15.8 Initiative H Risks

#### Risk H-1: API Rate Limiting

**Probability:** Medium
**Impact:** Low
**Description:** Heavy use of the Free Single Import feature could hit API rate limits on dnd5eapi.co or Open5e.

**Mitigation:**
- Aggressive caching: cache all API responses for 24 hours.
- Rate limit client-side: maximum 10 requests per minute.
- Show a clear error message when rate-limited.

### 15.9 Initiative I Risks

#### Risk I-1: Type Hint False Sense of Security

**Probability:** Low
**Impact:** Low
**Description:** Adding type hints without runtime enforcement could give a false sense of type safety.

**Mitigation:**
- Run mypy in the CI pipeline.
- Use `@dataclass` with type-checked fields for data models.
- Gradually introduce runtime validation where it matters (data ingestion, API responses).

#### Risk I-2: Logging Overhead

**Probability:** Low
**Impact:** Low
**Description:** Excessive logging could affect performance, especially in hot paths like battlemap rendering.

**Mitigation:**
- Use `DEBUG` level for hot-path logging, which is disabled by default.
- Avoid string formatting in log calls when the log level would suppress the message (use `%s` style, not f-strings).
- Profile after logging is added to verify no performance regression.

### 15.10 Program-Level Risks

#### Risk P-1: Scope Creep

**Probability:** High
**Impact:** High
**Description:** Nine initiatives with extensive specifications create risk of scope expansion as implementation reveals additional requirements.

**Mitigation:**
- Each initiative has a clear Definition of Done. Work stops when the DoD is met.
- Defer "Phase 2" and "optional" items explicitly. Do not revisit until core scope is complete.
- Weekly scope reviews to identify and reject scope additions.

#### Risk P-2: Integration Conflicts

**Probability:** Medium
**Impact:** Medium
**Description:** Multiple initiatives modifying the same files (e.g., `data_manager.py`, `combat_tracker.py`, `session_tab.py`) could create merge conflicts and integration issues.

**Mitigation:**
- Initiative I (Code Quality) goes first and establishes the foundation that other initiatives build on.
- When two initiatives modify the same file, coordinate through documented interface boundaries.
- Use feature branches and frequent integration.

#### Risk P-3: Single Developer Bandwidth

**Probability:** High
**Impact:** High
**Description:** If this is a single-developer project, the estimated 80+ days of work may take significantly longer in calendar time.

**Mitigation:**
- Prioritize ruthlessly. The critical path (I -> B -> D) should be the primary focus.
- Ship initiatives incrementally. Each initiative delivers value independently.
- Consider community contributions for lower-risk initiatives (C, G, H).

---

## 16. Expected Outcomes

### 16.1 Product State After Pre-Online Completion

When all nine initiatives are complete, the Dungeon Master Tool will be:

#### For Users

1. **System-agnostic.** The dynamic template system allows any tabletop RPG to be modeled. D&D 5e, Pathfinder, Shadowdark, Call of Cthulhu, GURPS, Warhammer, or any homebrew system can define custom entity types and fields.

2. **Visually consistent.** All windows, tabs, dialogs, and panels follow the same spacing, sizing, and styling rules. All 11 themes render correctly across the entire application.

3. **Tactically powerful.** The battlemap supports square and hexagonal grids, distance measurement, drawing annotations, and a dedicated DM control toolbar. DMs can run complex tactical encounters with confidence.

4. **Audio-rich.** State transitions are smooth with configurable crossfades and optional transition stingers. The audio experience is professional-grade.

5. **Well-documented (in-game).** Combat events are automatically logged, providing a round-by-round record for post-session review. PDF rulebooks are viewable inline.

6. **Community-ready.** World templates and content packs can be exported, shared, and imported with integrity validation. The foundation for a community content ecosystem is in place.

7. **Ergonomic for DMs.** The GM Player Screen Control panel gives DMs full control over what players see. The Single Player Window combines all player content in one place. Free Single Import eliminates the two-step entity import workflow.

#### For the Codebase

1. **Type-safe.** All public functions have type hints. Data models use typed dataclasses. Static analysis catches type errors before runtime.

2. **Observable.** Structured logging replaces print() statements. Log files are rotated and available for debugging. The path to production monitoring is clear.

3. **English-first.** All code, comments, and identifiers are in English. International contributors can read and understand the codebase.

4. **Well-structured.** All packages have `__init__.py` files. The module hierarchy is clean and intentional.

5. **Schema-driven.** The entity model is configurable at runtime, not compile time. The data format is versioned and migration-ready.

6. **Sync-ready.** All significant objects have UUIDs. State models are serializable. Event types are defined. The online transition can wire these interfaces to WebSocket events without restructuring the data layer.

7. **Tested.** Critical paths have automated tests. Regression tests cover legacy compatibility. Performance benchmarks define acceptable thresholds.

### 16.2 Online Transition Readiness Checklist

After pre-online completion, the following online-transition work can begin immediately:

| Online Phase | Prerequisite Met By |
|-------------|-------------------|
| EventManager abstraction layer | Initiative I (logging + typed signals) |
| WebSocket event routing | Initiative F (event types defined) + Initiative I (type hints) |
| Audio state sync | Initiative E (state serialization) |
| Battlemap sync | Initiative C (sync-ready IDs, shared state model) |
| Combat state sync | Initiative F (event log) + Initiative B (schema-driven entities) |
| Role-based content rendering | Initiative A (player window modes) + Initiative B (field visibility) |
| Content distribution | Initiative D (package format) |
| Server-side validation | Initiative B (schema validation) + Initiative D (integrity checks) |
| Client-side permission model | Initiative A (GM control panel) + Initiative B (field visibility) |

### 16.3 Metrics to Track Post-Completion

| Metric | Measurement | Target |
|--------|-------------|--------|
| Test coverage | Lines covered / total lines | > 60% |
| Type hint coverage | Annotated functions / total functions | > 90% for public methods |
| Inline CSS count | `setStyleSheet()` calls with hardcoded colors | 0 |
| `print()` count | print() in production code | 0 |
| Turkish artifacts | Turkish comments/identifiers in production code | 0 |
| Campaign load success rate | Legacy campaigns that load without error | 100% |
| Template round-trip success | Export -> Import produces identical schema | 100% |
| Battlemap FPS | Frames per second at target load | > 30fps |
| Application startup time | Launch to UI visible | < 3 seconds |

---

## Appendix A: File Inventory and Initiative Mapping

This appendix maps every existing source file to the initiative(s) that will modify it.

| File | Lines | Initiative(s) |
|------|-------|---------------|
| `main.py` | 387 | A, I |
| `config.py` | 147 | I |
| `core/data_manager.py` | 677 | B, F, G, I |
| `core/api_client.py` | 705 | H, I |
| `core/models.py` | 197 | B, H, I |
| `core/library_fs.py` | 250 | I |
| `core/locales.py` | 26 | I |
| `core/theme_manager.py` | 284 | A, I |
| `core/audio/engine.py` | 327 | E, I |
| `core/audio/models.py` | 36 | E, I |
| `core/audio/loader.py` | 286 | E, I |
| `core/dev/hot_reload_manager.py` | 348 | I |
| `core/dev/ipc_bridge.py` | 164 | I |
| `ui/main_root.py` | 162 | A, G |
| `ui/campaign_selector.py` | 123 | A, I |
| `ui/player_window.py` | 147 | A |
| `ui/soundpad_panel.py` | 439 | A, E, I |
| `ui/tabs/database_tab.py` | 296 | A, B, I |
| `ui/tabs/mind_map_tab.py` | 617 | A, I |
| `ui/tabs/map_tab.py` | 271 | A, I |
| `ui/tabs/session_tab.py` | 272 | A, F, G, I |
| `ui/widgets/combat_tracker.py` | 912 | A, B, C, F, I |
| `ui/widgets/npc_sheet.py` | 1002 | A, B, H, I |
| `ui/widgets/entity_sidebar.py` | 332 | A, B, I |
| `ui/widgets/mind_map_items.py` | 455 | A, I |
| `ui/widgets/map_viewer.py` | 232 | A, I |
| `ui/widgets/markdown_editor.py` | 415 | A, I |
| `ui/widgets/projection_manager.py` | 231 | A, I |
| `ui/widgets/image_viewer.py` | 55 | I |
| `ui/widgets/aspect_ratio_label.py` | 68 | I |
| `ui/windows/battle_map_window.py` | 762 | A, C, I |
| `ui/dialogs/api_browser.py` | 490 | A, H, I |
| `ui/dialogs/bulk_downloader.py` | 290 | A, I |
| `ui/dialogs/import_window.py` | 422 | A, I |
| `ui/dialogs/encounter_selector.py` | 211 | A, B, I |
| `ui/dialogs/entity_selector.py` | 121 | A, H, I |
| `ui/dialogs/theme_builder.py` | 187 | A, I |
| `ui/dialogs/timeline_entry.py` | 134 | A, I |
| `ui/workers.py` | 71 | I |

---

## Appendix B: New Files Created by Pre-Online Initiatives

| File | Initiative | Purpose |
|------|-----------|---------|
| `core/__init__.py` | I | Package init |
| `core/logging_config.py` | I | Logging configuration |
| `core/battle_map_state.py` | A | Shared battle map state model |
| `core/schema/__init__.py` | B | Package init |
| `core/schema/world_schema.py` | B | WorldSchema, EntityCategorySchema, FieldSchema |
| `core/schema/field_types.py` | B | FieldType, FieldValidation, FieldVisibility |
| `core/schema/encounter_layout.py` | B | EncounterLayout configuration |
| `core/schema/migration.py` | B | Legacy campaign migration |
| `core/schema/template_io.py` | B | Template export/import |
| `core/schema/default_schema.py` | B | Default D&D 5e schema generation |
| `core/battlemap/__init__.py` | C | Package init |
| `core/battlemap/grid_config.py` | C | Grid configuration and math |
| `core/battlemap/grid_renderer.py` | C | Grid rendering implementations |
| `core/battlemap/drawing_objects.py` | C | Drawing object models |
| `core/battlemap/measurement.py` | C | Distance measurement logic |
| `core/packages/__init__.py` | D | Package init |
| `core/packages/package_types.py` | D | Package type enums |
| `core/packages/manifest.py` | D | Manifest validation |
| `core/packages/exporter.py` | D | Package export logic |
| `core/packages/importer.py` | D | Package import logic |
| `core/packages/integrity.py` | D | Checksum and security |
| `core/packages/conflict_resolver.py` | D | Import conflict resolution |
| `core/combat/__init__.py` | F | Package init |
| `core/combat/events.py` | F | Combat event models |
| `core/combat/event_log.py` | F | Event log storage |
| `core/combat/event_formatter.py` | F | Event formatting |
| `ui/__init__.py` | I | Package init |
| `ui/constants.py` | A | UI layout constants |
| `ui/tabs/__init__.py` | I | Package init |
| `ui/widgets/__init__.py` | I | Package init |
| `ui/widgets/gm_screen_control.py` | A | GM Player Screen Control |
| `ui/widgets/content_queue.py` | A | Content queue widget |
| `ui/widgets/player_battle_map_view.py` | A | Read-only player battle map |
| `ui/widgets/battlemap_toolbar.py` | C | DM battlemap toolbar |
| `ui/widgets/drawing_tools.py` | C | Drawing tool implementations |
| `ui/widgets/grid_settings_dialog.py` | C | Grid configuration dialog |
| `ui/widgets/field_widgets.py` | B | Dynamic field widgets |
| `ui/widgets/field_widget_factory.py` | B | Field widget factory |
| `ui/widgets/event_feed.py` | F | Live combat event feed |
| `ui/widgets/pdf_viewer.py` | G | Embedded PDF viewer |
| `ui/widgets/pdf_file_list.py` | G | PDF file management |
| `ui/dialogs/__init__.py` | I | Package init |
| `ui/dialogs/template_studio.py` | B | Template Studio dialog |
| `ui/dialogs/encounter_configurator.py` | B | Encounter column configurator |
| `ui/dialogs/export_wizard.py` | D | Package export wizard |
| `ui/dialogs/package_browser.py` | D | Local package browser |
| `ui/dialogs/import_preview.py` | D | Import preview dialog |
| `ui/dialogs/unified_entity_picker.py` | H | Unified entity picker |
| `ui/windows/__init__.py` | I | Package init |
| `tests/__init__.py` | I | Package init |
| `tests/test_core/__init__.py` | I | Package init |
| `tests/test_core/test_schema.py` | B | Schema CRUD tests |
| `tests/test_core/test_migration.py` | B | Migration tests |
| `tests/test_core/test_template_io.py` | B | Template export/import tests |
| `tests/test_core/test_grid_math.py` | C | Grid coordinate tests |
| `tests/test_core/test_measurement.py` | C | Distance measurement tests |
| `tests/test_core/test_drawing.py` | C | Drawing CRUD tests |
| `tests/test_core/test_package_export.py` | D | Package export tests |
| `tests/test_core/test_package_import.py` | D | Package import tests |
| `tests/test_core/test_package_integrity.py` | D | Security tests |
| `tests/test_core/test_audio_transitions.py` | E | Audio transition tests |
| `tests/test_core/test_audio_state.py` | E | Audio state tests |
| `tests/test_core/test_combat_events.py` | F | Combat event tests |
| `tests/test_dev/__init__.py` | I | Package init |
| `tests/test_ui/__init__.py` | I | Package init |
| `tests/test_ui/test_pdf_viewer.py` | G | PDF viewer tests |
| `tests/test_ui/test_entity_picker.py` | H | Entity picker tests |

---

## Appendix C: Glossary

| Term | Definition |
|------|-----------|
| **Campaign** | A saved world with all its entities, maps, sessions, and mind maps |
| **Category** | A type of entity (e.g., NPC, Monster, Spell). Currently hardcoded, will become dynamic |
| **Entity** | A single game object (character, item, location, etc.) stored in the campaign |
| **Field** | A single property of an entity (e.g., "HP", "Race", "Description") |
| **Field Schema** | The definition of a field: its type, validation rules, and display configuration |
| **World Schema** | The complete definition of all entity categories and their fields for a campaign |
| **Template** | A packaged world schema that can be shared and reused |
| **MusicBrain** | The layered audio engine that manages themes, states, and crossfades |
| **State (Audio)** | A mood configuration (Normal, Combat, Victory) with associated tracks |
| **Stinger** | A short transitional sound played between audio state changes |
| **Fog of War** | The black overlay on the battle map that hides unexplored areas from players |
| **QSS** | Qt Style Sheets, CSS-like styling system for Qt widgets |
| **ThemeManager** | The class that manages color palettes for elements not controllable by QSS |
| **DataManager** | The central data hub that handles all campaign CRUD operations |
| **MsgPack** | MessagePack, a binary serialization format used for campaign data storage |
| **Sync-ready** | Designed with identifiers and state structures that can be transmitted over a network |
| **DM** | Dungeon Master / Game Master, the user who runs the game |
| **Player** | A game participant who controls a character |
| **Online Transition** | The project phase that adds multiplayer networking to the application |
| **Pre-Online** | The preparation phase (this document's scope) that must complete before online work begins |

---

*End of document.*
