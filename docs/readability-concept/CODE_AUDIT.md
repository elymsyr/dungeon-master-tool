# Dungeon Master Tool -- Comprehensive Code Audit

**Project:** Dungeon Master Tool v0.7.7 Alpha
**Author:** Elymsyr (Orhun Eren Yalcinkaya)
**License:** MIT
**Audit Date:** 2026-03-17
**Auditor:** Automated Static Analysis + Manual Review
**Scope:** All production Python source files, test files, build scripts, and utilities

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Methodology](#2-methodology)
3. [Architecture Overview](#3-architecture-overview)
4. [File-by-File Analysis](#4-file-by-file-analysis)
   - 4.1 [Root Module](#41-root-module)
   - 4.2 [Core Module](#42-core-module)
   - 4.3 [Core Audio Subsystem](#43-core-audio-subsystem)
   - 4.4 [Core Dev Tooling](#44-core-dev-tooling)
   - 4.5 [UI Tabs](#45-ui-tabs)
   - 4.6 [UI Widgets](#46-ui-widgets)
   - 4.7 [UI Dialogs](#47-ui-dialogs)
   - 4.8 [UI Windows and Panels](#48-ui-windows-and-panels)
   - 4.9 [UI Infrastructure](#49-ui-infrastructure)
   - 4.10 [Utilities and Build](#410-utilities-and-build)
5. [Systemic Issues](#5-systemic-issues)
6. [Metrics Summary Table](#6-metrics-summary-table)
7. [Testing Analysis](#7-testing-analysis)
8. [Priority Matrix](#8-priority-matrix)
9. [Recommendations](#9-recommendations)

---

## 1. Executive Summary

### 1.1 Total Metrics

| Metric                        | Value            |
|-------------------------------|------------------|
| Production Python files       | 35               |
| Test Python files             | 12 (incl. conftest) |
| Utility/Build scripts         | 2                |
| Total production LOC          | 13,818           |
| Total test LOC                | 858              |
| Test-to-production LOC ratio  | 6.2%             |
| Total classes (production)    | ~68              |
| Total methods (production)    | ~480             |
| Files with bare `except`      | 8                |
| Files with hardcoded CSS      | 7                |
| Files with Turkish comments   | ~28              |
| Files with type hints         | 4                |
| Files with docstrings (>50%)  | 6                |

### 1.2 Top 5 Critical Findings

1. **God Class: `DataManager` (677 LOC, ~45 methods)** -- Mixes CRUD operations, file I/O, API delegation, library management, migration logic, and session management in a single class. This is the single largest maintainability bottleneck in the codebase.

2. **God Class: `NpcSheet` (1,002 LOC, ~46 methods)** -- Combines UI layout, data collection, image management, PDF management, drag-and-drop handling, and API browser integration in one widget. Violates Single Responsibility Principle severely.

3. **Pervasive Absence of Type Hints** -- Only 4 of 35 production files use `typing` imports. The vast majority of function signatures have no parameter or return type annotations, making refactoring extremely risky without comprehensive tests.

4. **Mixed-Language Codebase** -- Turkish comments, docstrings, variable names, and hardcoded UI strings appear in ~28 files. This creates a significant barrier for international contributors and complicates automated tooling.

5. **Bare `except` Clauses in 8 Files** -- Silent exception swallowing (`except: pass`, `except: return default`) masks bugs in production code. Found in `data_manager.py`, `api_client.py`, `combat_tracker.py`, `mind_map_tab.py`, `import_window.py`, `api_browser.py`, `encounter_selector.py`, and `ipc_bridge.py`.

### 1.3 Overall Health Assessment

The Dungeon Master Tool is a feature-rich PyQt6 desktop application with impressive scope for an alpha-stage solo-developer project. The architecture demonstrates solid understanding of Qt signal/slot patterns, splitter-based layouts, and worker threads for async operations. The dev tooling (hot reload, IPC bridge, file watcher) is notably well-engineered compared to the rest of the codebase.

However, the codebase suffers from organic growth patterns: god classes, inconsistent code style, near-absent type safety, minimal documentation, and a theme system undermined by scattered inline CSS. The test suite, while present, covers only ~6.2% of production code by LOC and leaves entire UI modules untested.

**Overall Grade: C+ (Functional but technically indebted)**

The application works and ships features, but accumulated technical debt will increasingly slow new development, increase bug rates, and make onboarding contributors difficult.

---

## 2. Methodology

### 2.1 Approach

Every production Python file was read in full. Metrics were gathered through direct source inspection rather than automated tooling, ensuring accuracy for:

- Lines of code (LOC) via `wc -l`
- Class and method counts via manual enumeration
- Specific issue identification with line-number references
- Pattern detection (bare excepts, hardcoded CSS, Turkish strings, type hint usage)

### 2.2 Severity Classification

| Severity     | Definition                                                                                       |
|--------------|--------------------------------------------------------------------------------------------------|
| **Critical** | Architectural issue affecting multiple modules; high risk of bugs or blocking future development  |
| **High**     | Significant code quality issue in a single file; likely source of bugs or maintenance burden      |
| **Medium**   | Style or organization issue that reduces readability but does not directly cause bugs             |
| **Low**      | Minor cosmetic or documentation issue; easy to fix                                               |
| **Info**     | Observation or positive finding worth noting                                                      |

### 2.3 Scope Exclusions

- Asset files (images, audio, fonts)
- QSS theme files (external stylesheets)
- YAML locale files
- Third-party dependencies
- Runtime-generated data files

---

## 3. Architecture Overview

### 3.1 High-Level Module Map

```
dungeon-master-tool/
+-- main.py                  # Entry point, MainWindow class
+-- config.py                # Path resolution, theme loading, constants
+-- dev_run.py               # Development supervisor with hot reload
+-- dump.py                  # Utility: project dump to text file
+-- installer/build.py       # PyInstaller build script
+-- core/
|   +-- data_manager.py      # Central data hub (god class)
|   +-- api_client.py        # D&D 5e API integration
|   +-- models.py            # Entity schemas and field mappings
|   +-- library_fs.py        # Filesystem library management
|   +-- locales.py           # i18n wrapper
|   +-- theme_manager.py     # QSS palette management
|   +-- audio/
|   |   +-- engine.py        # Multi-track audio playback
|   |   +-- loader.py        # Audio theme YAML loading
|   |   +-- models.py        # Audio data classes
|   +-- dev/
|       +-- hot_reload_manager.py  # In-process module reloader
|       +-- ipc_bridge.py         # IPC communication bridge
+-- ui/
    +-- main_root.py         # Root widget factory
    +-- campaign_selector.py # Campaign picker dialog
    +-- player_window.py     # Player-facing projection window
    +-- workers.py           # QThread worker classes
    +-- soundpad_panel.py    # Sound effects panel
    +-- tabs/
    |   +-- database_tab.py  # Entity tab management
    |   +-- session_tab.py   # Session management + combat
    |   +-- map_tab.py       # World map timeline
    |   +-- mind_map_tab.py  # Visual mind map editor
    +-- widgets/
    |   +-- npc_sheet.py     # Entity detail sheet (god class)
    |   +-- combat_tracker.py # Combat management
    |   +-- entity_sidebar.py # Global entity list sidebar
    |   +-- mind_map_items.py # Mind map visual items
    |   +-- markdown_editor.py # Rich text editor with mentions
    |   +-- map_viewer.py    # Map display with pins
    |   +-- projection_manager.py # Projection controls
    |   +-- image_viewer.py  # Simple image display
    |   +-- aspect_ratio_label.py # Aspect-ratio-preserving label
    +-- dialogs/
    |   +-- import_window.py  # Library import dialog
    |   +-- api_browser.py    # API search browser
    |   +-- bulk_downloader.py # Bulk download manager
    |   +-- encounter_selector.py # Encounter picker
    |   +-- entity_selector.py # Entity picker
    |   +-- timeline_entry.py # Timeline event editor
    |   +-- theme_builder.py  # Theme customization dialog
    +-- windows/
        +-- battle_map_window.py # Battle map with fog of war
```

### 3.2 Data Flow

```
                    +-------------------+
                    |   config.py       |
                    |  (paths, themes)  |
                    +--------+----------+
                             |
                    +--------v----------+
                    |   MainWindow      |
                    |   (main.py)       |
                    +--------+----------+
                             |
              +--------------+----------------+
              |              |                |
    +---------v----+  +------v------+  +------v-------+
    | DatabaseTab  |  | SessionTab  |  | MapTab       |
    | (NpcSheet x2)|  | (Combat +   |  | (MapViewer + |
    |              |  |  Map + Log) |  |  Timeline)   |
    +------+-------+  +------+------+  +------+-------+
           |                 |                |
    +------v-----------------v----------------v-------+
    |                  DataManager                     |
    |  (entities, sessions, maps, mind_maps, config)   |
    +------+------------------------------------------+
           |
    +------v-----------+    +------------------+
    | MsgPack / JSON   |    | DndApiClient     |
    | (Persistence)    |    | (External API)   |
    +------------------+    +------------------+
```

### 3.3 Signal/Slot Communication Patterns

The application uses PyQt6 signals extensively for decoupled communication:

| Signal Source              | Signal Name              | Receiver                    | Purpose                          |
|----------------------------|--------------------------|-----------------------------|----------------------------------|
| `EntitySidebar`           | `entity_selected`        | `DatabaseTab`               | Open entity card on click        |
| `NpcSheet`                | `request_open_entity`    | `DatabaseTab`               | Navigate to linked entity        |
| `NpcSheet`                | `save_requested`         | `DatabaseTab`               | Trigger save from Ctrl+S         |
| `NpcSheet`                | `data_changed`           | `DatabaseTab`               | Mark tab as unsaved              |
| `CombatTracker`           | `data_changed_signal`    | `SessionTab`                | Refresh map + auto-save          |
| `BattleMapWidget`         | `token_moved_signal`     | `CombatTracker`             | Sync token positions             |
| `BattleMapWidget`         | `fog_update_signal`      | `CombatTracker`             | Sync fog of war state            |
| `MarkdownEditor`          | `entity_link_clicked`    | `DatabaseTab`               | Navigate to entity from link     |
| `MindMapScene`            | `entity_double_clicked`  | `MindMapTab`                | Open entity from mind map node   |
| `DatabaseTab`             | `entity_deleted`         | `EntitySidebar` (via main)  | Refresh sidebar on deletion      |
| `DraggableCombatTable`    | `entity_dropped`         | `CombatTracker`             | Add entity to combat via drag    |

**Assessment:** Signal/slot usage is generally appropriate but some connections are established in `SessionTab.init_ui()` with `hasattr` guards (line 89) that suggest fragile initialization ordering. The `combat_tracker.data_changed_signal` is connected to both `refresh_embedded_map` and `auto_save`, which can cause redundant save operations on every combat state change.

### 3.4 Theme System

The theme system uses a two-layer approach:

1. **External QSS Files** -- Loaded by `config.load_theme()` from the `themes/` directory
2. **ThemeManager Palette** -- A static dictionary in `core/theme_manager.py` with ~90 color entries keyed by theme name

**Conflict:** At least 7 files contain hardcoded inline CSS that bypasses the theme system entirely:
- `database_tab.py` lines 38-43 (EntityTabWidget)
- `entity_sidebar.py` lines 25, 33, 113-116
- `markdown_editor.py` lines 18-27 (MentionPopup)
- `bulk_downloader.py` (progress bar styling)
- `entity_selector.py` (table styling)
- `api_browser.py` (various elements)
- `battle_map_window.py` (sidebar elements)

This means switching themes will produce visual inconsistencies wherever inline styles override the external QSS.

### 3.5 Startup Sequence

```
1. main.py :: run_application()
   a. config.resolve_data_root()         -- Determine data storage path
   b. config.load_theme()                -- Load QSS stylesheet
   c. QApplication creation
   d. DevIpcBridge.from_env()            -- Connect to dev supervisor (if dev mode)
   e. CampaignSelector dialog            -- User picks or creates campaign
   f. DataManager.load_campaign()        -- Load campaign data from disk
   g. MainWindow.__init__()
      i.   PlayerWindow()                -- Create projection window
      ii.  create_root_widget()          -- Build main UI tree (ui/main_root.py)
      iii. Connect signals               -- Wire up cross-tab communication
      iv.  Load last active session      -- Restore session state
   h. DevIpcBridge.attach() + start()    -- Start IPC polling (dev mode only)
   i. app.exec()                         -- Enter Qt event loop
```

### 3.6 Persistence Layer

Data is stored as MsgPack (`.dat`) binary format with JSON fallback:

- **Primary:** `data.dat` (MsgPack via `msgpack.pack()`)
- **Fallback read:** `data.json` (legacy format, triggers migration)
- **Location:** `{WORLDS_DIR}/{campaign_name}/`

The `DataManager` handles both serialization formats transparently. On load, it tries MsgPack first, then falls back to JSON. On save, it always writes MsgPack. This provides good performance for large campaigns while maintaining backward compatibility.

**Issue:** There is no schema versioning or migration tracking beyond the legacy Turkish-to-English key migration in `_migrate_data()`. Future schema changes will require ad-hoc migration code.

---

## 4. File-by-File Analysis

### 4.1 Root Module

#### 4.1.1 `main.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `main.py`                            |
| **LOC**         | 387                                  |
| **Classes**     | 1 (`MainWindow`)                     |
| **Methods**     | ~19                                  |
| **Purpose**     | Application entry point; MainWindow hosts all tabs, handles language switching, theme application, and dev tool integration |
| **Severity**    | Medium                               |

**Quality Observations:**
- One of the few files that uses type hints (`Optional`, `Dict`, `Any`) in method signatures.
- `run_application()` is a clean entry point with proper QApplication setup.
- `rebuild_root_widget()` method enables hot reload by tearing down and rebuilding the UI tree.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 22 | Global mutable state: `_DATA_ROOT_FALLBACK_NOTICE_SHOWN = False` used to track whether a warning dialog has been shown. This is a module-level flag that survives across function calls but not across process restarts. | Low |
| 46 | Turkish fallback string: `"Bilinmiyor"` used as default for unknown world name in window title. Should use `tr()` or a constant. | Medium |
| 112-139 | `_build_main_ui()` calls `create_root_widget()` which returns a dict bundle. The unpacking (`root["tabs"]`, `root["db_tab"]`, etc.) creates implicit coupling between MainWindow and the factory function's return shape. | Medium |
| 180-210 | `_apply_language()` calls `retranslate_ui()` on multiple children with `hasattr()` guards, indicating the interface is not formalized. | Low |

**Positive Notes:**
- Clean separation of `_build_main_ui()` from `__init__()`.
- `rebuild_root_widget()` properly handles old widget cleanup with `deleteLater()`.
- Proper use of `importlib.import_module()` for dynamic module loading during hot reload.

---

#### 4.1.2 `config.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `config.py`                          |
| **LOC**         | 147                                  |
| **Classes**     | 0                                    |
| **Functions**   | ~8                                   |
| **Purpose**     | Configuration constants, path resolution, theme loading |
| **Severity**    | Info (Good)                          |

**Quality Observations:**
- Best-documented file in the codebase. Most functions have docstrings.
- `resolve_data_root()` uses dependency injection for testability (`platform_name`, `env_map`, `probe` parameters).
- Clean 3-tier priority for data root: environment override > portable directory > OS-specific fallback.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 1-10 | Well-structured constants block (`VERSION`, `APP_NAME`, `WORLDS_DIR`, `CACHE_DIR`). No issues. | Info |
| ~80-100 | `load_theme()` reads QSS files with a bare `except` that falls back gracefully. The error handling is adequate for theme loading but could log the specific exception. | Low |
| ~120-140 | `probe_write_access()` creates and deletes a temp file to test write permissions. This is correct but could race with concurrent processes. | Low |

**Positive Notes:**
- This file serves as a good example of how the rest of the codebase should be structured: small focused functions, clear documentation, testable design.

---

#### 4.1.3 `dev_run.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `dev_run.py`                         |
| **LOC**         | 436                                  |
| **Classes**     | 1 (`DevSupervisor`)                  |
| **Methods**     | ~20                                  |
| **Purpose**     | Development file watcher and hot reload supervisor |
| **Severity**    | Info (Good)                          |

**Quality Observations:**
- The only file in the entire codebase with comprehensive type hints: `Iterable`, `List`, `Optional`, `Sequence`, `Tuple`.
- Clean state machine pattern for supervisor lifecycle.
- Proper use of `argparse` with mutually exclusive groups.
- Uses `multiprocessing.connection.Listener` for IPC -- clean approach.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| ~50-70 | `EXCLUDED_DIRS` and `should_watch_file()` duplicate exclusion logic that also exists in `dump.py`. Could be shared. | Low |
| ~200-250 | `handle_changes()` has a retry loop for BUSY status that could theoretically loop indefinitely if the child process never becomes available. The `_compute_hot_reload_timeout()` with adaptive timeout mitigates this. | Low |
| ~380-436 | `_watch_loop()` uses `time.sleep()` in a loop, which is standard for file watchers but could be replaced with `watchdog` library for better performance and cross-platform support. | Info |

**Positive Notes:**
- Outstanding code quality relative to the rest of the project.
- Proper signal handling (`SIGINT`, `SIGTERM`).
- Clean subprocess lifecycle management with `_ensure_child_for_change()` and `_kill_child()`.
- Adaptive timeout computation based on batch size.

---

### 4.2 Core Module

#### 4.2.1 `core/data_manager.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `core/data_manager.py`               |
| **LOC**         | 677                                  |
| **Classes**     | 1 (`DataManager`)                    |
| **Methods**     | ~45                                  |
| **Purpose**     | Central data hub: entity CRUD, session management, campaign I/O, API delegation, library catalog, data migration |
| **Severity**    | **Critical**                         |

**Quality Observations:**
- This is the largest and most problematic class in the codebase. It violates the Single Responsibility Principle by combining at least 6 distinct responsibilities.
- No type hints on any method parameter or return value.
- Uses `print()` for error logging throughout instead of the `logging` module.
- Mixes low-level I/O (`msgpack.pack`, `json.dump`) with high-level business logic (entity validation, session management).

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 33 | Turkish comment: `"YENi: Mind Map verileri"` in data structure initialization | Medium |
| 59, 80, 88, 94 | `print()` used for error output instead of `logging` module | Medium |
| 113 | Bare except: `except: pass` in `save_data()` -- silently swallows any serialization error | Critical |
| 173, 274, 302, 426, 468, 523 | More `print()` error logging | Medium |
| 191-240 | `_migrate_data()` contains hardcoded Turkish-to-English key mapping. This is a one-time migration but is checked on every load. Should be gated by a version flag. | Medium |
| 483 | Turkish comment: `"Kaydetmeyi unutma"` (Don't forget to save) | Low |
| ~300-350 | `save_entity()`, `delete_entity()`, `get_entity()` -- basic CRUD that could be a separate repository class | High |
| ~400-450 | `create_session()`, `save_session_data()`, `get_session()` -- session management that could be extracted | High |
| ~500-550 | `search_library_catalog()`, `get_library_entity()` -- library management delegated to `library_fs` but still routed through DataManager | Medium |
| ~600-677 | `prepare_entity_from_external()` -- API response transformation that belongs in the API layer | Medium |

**Recommended Decomposition:**

```
DataManager (current: ~45 methods)
  --> EntityRepository      (CRUD: ~8 methods)
  --> SessionRepository     (CRUD: ~6 methods)
  --> CampaignIO            (load/save/migrate: ~8 methods)
  --> LibraryCatalog        (search/scan: ~5 methods)
  --> DataManager           (orchestrator: ~10 methods)
```

---

#### 4.2.2 `core/api_client.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `core/api_client.py`                 |
| **LOC**         | 705                                  |
| **Classes**     | 4 (`ApiSource`, `Dnd5eApiSource`, `Open5eApiSource`, `DndApiClient`) |
| **Methods**     | ~30                                  |
| **Purpose**     | D&D 5e API integration with two source backends and an orchestrating client |
| **Severity**    | High                                 |

**Quality Observations:**
- Good use of a base class (`ApiSource`) with two concrete implementations, showing understanding of polymorphism.
- However, the `parse_monster()` and `parse_spell()` methods are nearly duplicated between the two source classes with only minor field mapping differences.
- Hardcoded field mapping dictionaries in each source class could be extracted to configuration.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| ~50-120 | `Dnd5eApiSource` has hardcoded endpoint and field mappings inline. These could be class-level constants or loaded from configuration. | Medium |
| ~200-350 | `parse_monster()` in `Dnd5eApiSource` is ~150 lines of sequential field extraction with no helper methods. Deep nesting for nested API response structures. | High |
| ~400-500 | `Open5eApiSource.parse_monster()` duplicates ~80% of the logic from `Dnd5eApiSource.parse_monster()` with different field names. Should use a shared template or strategy. | High |
| 689 | Bare except: `except:` in the parse dispatcher method. Silently swallows parse failures, returning None. | High |
| ~15 (throughout) | ~15 instances of Turkish comments spread across the file | Medium |

**Positive Notes:**
- The `DndApiClient` orchestrator pattern is clean -- it delegates to the appropriate source based on configuration.
- `requests.Session()` is used correctly for connection pooling.

---

#### 4.2.3 `core/models.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `core/models.py`                     |
| **LOC**         | 197                                  |
| **Classes**     | 0 (data-only)                        |
| **Functions**   | 2                                    |
| **Purpose**     | Entity schema definitions, property mappings, default structure generation |
| **Severity**    | Medium                               |

**Quality Observations:**
- Pure data module with `ENTITY_SCHEMAS`, `SCHEMA_MAP`, `PROPERTY_MAP` dictionaries.
- No use of dataclasses, TypedDict, or Pydantic despite being the natural place for data validation.
- The entire application uses raw dicts for entity representation -- this file defines the shape but cannot enforce it.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 155 | Turkish default value: `"Yeni Kayit"` (New Record) in `get_default_entity_structure()`. Should use `tr("DEFAULT_ENTITY_NAME")` or an English default. | Medium |
| 1-100 | `ENTITY_SCHEMAS` is a deeply nested dict of dicts. Each entity type (Monster, NPC, Spell, etc.) defines its fields as a flat dict of `{field_key: display_label_key}`. This works but is fragile -- adding field metadata (type, required, default) would require restructuring. | Medium |
| ~120-140 | `PROPERTY_MAP` maps `LBL_*` keys to display categories. This is a flat lookup that works but has no validation that all schema fields have corresponding property map entries. | Low |

**Recommendation:** Convert to dataclasses or TypedDict at minimum. Example:

```python
from dataclasses import dataclass, field
from typing import Dict, Optional

@dataclass
class CombatStats:
    ac: str = ""
    hp: str = ""
    speed: str = ""
    cr: str = ""

@dataclass
class Entity:
    name: str
    type: str
    attributes: Dict[str, str] = field(default_factory=dict)
    combat_stats: Optional[CombatStats] = None
```

---

#### 4.2.4 `core/library_fs.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `core/library_fs.py`                 |
| **LOC**         | 250                                  |
| **Classes**     | 0                                    |
| **Functions**   | ~10                                  |
| **Purpose**     | Filesystem-based library management: scanning, searching, migration |
| **Severity**    | Info (Good)                          |

**Quality Observations:**
- Best code quality in the entire project. Small, focused functions with clear single responsibilities.
- Clean docstrings with return type documentation in natural language.
- Proper error handling with a report dict pattern that accumulates results without throwing.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| ~1-20 | Clean imports and module-level constants | Info |
| ~50-80 | `migrate_legacy_layout()` returns a structured report dict with `moved_files`, `legacy_categories_found`, `errors` -- excellent pattern | Info |
| ~100-150 | `scan_library_tree()` walks the filesystem and builds a nested dict. Each category is a list of `{index, display_name, source, path}` dicts. Clean implementation. | Info |
| ~180-220 | `search_library_tree()` filters the scanned tree with query string and category normalization. Handles case-insensitive matching correctly. | Info |

**Positive Notes:**
- This module should be used as the style reference for refactoring other modules.
- Good test coverage (5 tests in `test_library_fs.py`).
- No Turkish comments, no bare excepts, proper error reporting.

---

#### 4.2.5 `core/locales.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `core/locales.py`                    |
| **LOC**         | 26                                   |
| **Classes**     | 0                                    |
| **Functions**   | 1 (`tr`)                             |
| **Purpose**     | Thin wrapper around `python-i18n` library |
| **Severity**    | Info                                 |

**Quality Observations:**
- Minimal and appropriate. Configures i18n and exports a `tr()` function.
- Sets locale directory, fallback locale, and file format.
- The `tr()` function accepts `**kwargs` for string interpolation.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| ~10-15 | `i18n.set("fallback", "en")` and `i18n.set("file_format", "yml")` are called at module import time. This is standard for i18n setup. | Info |
| ~20-26 | `tr(key, **kwargs)` delegates to `i18n.t(key, **kwargs)`. The function silently returns the key itself if the translation is missing (i18n library default behavior). No logging of missing keys in debug mode. | Low |

---

#### 4.2.6 `core/theme_manager.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `core/theme_manager.py`              |
| **LOC**         | 284                                  |
| **Classes**     | 1 (`ThemeManager`)                   |
| **Methods**     | 1 (`get_palette` -- static)          |
| **Purpose**     | Color palette management for themes  |
| **Severity**    | Medium                               |

**Quality Observations:**
- The class is essentially a namespace for a large static dictionary. It has a single static method `get_palette()` that returns a palette dict for a given theme name.
- Could be replaced with a module-level dict and a function, eliminating the unnecessary class wrapper.
- The palette contains ~90 color entries per theme, covering background, text, border, accent, and component-specific colors.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 2-6 | Turkish docstring for the class. Should be English. | Medium |
| Throughout | ~20 Turkish comments interspersed with the palette definitions | Medium |
| ~50-280 | The entire palette is a single massive dict literal. Adding a new theme requires duplicating the entire structure. Could use a base palette with theme-specific overrides. | Medium |
| -- | Only "dark" theme palette is fully defined; other themes fall back to defaults. The `get_palette()` method returns a default dict for unknown theme names but this is not documented. | Low |

---

### 4.3 Core Audio Subsystem

#### 4.3.1 `core/audio/engine.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `core/audio/engine.py`               |
| **LOC**         | 327                                  |
| **Classes**     | 3 (`MusicBrain`, `TrackPlayer`, `MultiTrackDeck`) |
| **Methods**     | ~20                                  |
| **Purpose**     | Multi-track audio playback with crossfading via Qt animations |
| **Severity**    | Medium                               |

**Quality Observations:**
- Uses `QPropertyAnimation` for smooth volume fading between tracks -- a creative use of Qt's animation framework for audio.
- `TrackPlayer` wraps `QMediaPlayer` with volume control and fade animations.
- `MultiTrackDeck` manages multiple simultaneous track players for layered audio.
- Unusually for this codebase, uses `typing` imports (`Dict`, `List`).

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| Throughout | Turkish docstrings on all three classes and most methods | Medium |
| ~50-80 | `MusicBrain.crossfade_to()` creates a new `QPropertyAnimation` each time without cleaning up the previous one. If called rapidly, orphaned animation objects could accumulate. | Medium |
| ~150-200 | `TrackPlayer` stores a reference to its `QPropertyAnimation` but does not disconnect or clean up on destruction. | Low |
| ~250-327 | `MultiTrackDeck.play_theme()` iterates over theme tracks and starts/stops players. No error handling for missing audio files -- relies on QMediaPlayer's internal error handling. | Low |

**Positive Notes:**
- The audio architecture (Brain > Deck > Player) is well-layered.
- Volume crossfading provides a good user experience for ambient audio.

---

#### 4.3.2 `core/audio/loader.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `core/audio/loader.py`               |
| **LOC**         | 286                                  |
| **Classes**     | 1-2                                  |
| **Methods**     | ~12                                  |
| **Purpose**     | YAML-based audio theme loading and validation |
| **Severity**    | Medium                               |

**Quality Observations:**
- Loads audio theme definitions from YAML files with track references to audio files.
- Deep nesting in the parse logic when handling nested YAML structures.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 171 | `import time` inside a function body rather than at module level. This is a minor style issue but suggests the import was added as an afterthought. | Low |
| Throughout | Turkish comments throughout the file | Medium |
| ~100-150 | YAML parsing with nested loops reaches 4 levels of indentation for deeply structured theme files. Could benefit from recursive helper functions. | Medium |

---

#### 4.3.3 `core/audio/models.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `core/audio/models.py`               |
| **LOC**         | 36                                   |
| **Classes**     | 2-3 (dataclasses)                    |
| **Purpose**     | Data structures for audio tracks and themes |
| **Severity**    | Info (Good)                          |

**Quality Observations:**
- Uses `@dataclass` with type hints -- the best example of modern Python data modeling in the entire codebase.
- Clean and minimal.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| Throughout | Turkish docstrings on the dataclasses | Low |

**Positive Notes:**
- This file demonstrates the pattern that `core/models.py` should adopt for entity schemas.

---

### 4.4 Core Dev Tooling

#### 4.4.1 `core/dev/hot_reload_manager.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `core/dev/hot_reload_manager.py`     |
| **LOC**         | 348                                  |
| **Classes**     | 1 (`HotReloadManager`)              |
| **Methods**     | ~15                                  |
| **Purpose**     | In-process Python module hot reloading with health checks |
| **Severity**    | Info (Good)                          |

**Quality Observations:**
- Excellent code quality. Clean type hints with `Path | None`, `Dict`, `List`, `Set`, `Iterable`.
- Well-defined outcome constants (`OUTCOME_APPLIED`, `OUTCOME_NO_OP`, etc.).
- Thread safety via `_reload_lock` with non-blocking acquire.
- Health validation after reload ensures the window is in a consistent state.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 44 | Uses Python 3.10+ union syntax `Path | None` which limits backward compatibility. The rest of the codebase does not use this syntax. | Low |
| 208-212 | `print()` for logging reload progress. Consistent with the rest of the codebase but should use `logging`. | Low |
| ~180-188 | `_collect_reload_targets()` sorts by `(name.count("."), name)` to reload leaf modules first, then parents. This is correct but the rationale is not documented. | Low |

**Positive Notes:**
- Outstanding test coverage: 11 tests in `test_hot_reload_manager.py` covering all outcome paths.
- Clean separation of concerns: path classification, module resolution, reload execution, health validation.
- The `_build_result()` helper ensures consistent response structure with timing.
- This module, together with `dev_run.py`, represents the highest code quality in the project.

---

#### 4.4.2 `core/dev/ipc_bridge.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `core/dev/ipc_bridge.py`             |
| **LOC**         | 164                                  |
| **Classes**     | 1 (`DevIpcBridge`)                   |
| **Methods**     | ~9                                   |
| **Purpose**     | Child-process IPC bridge for dev hot reload commands |
| **Severity**    | Low                                  |

**Quality Observations:**
- Clean integration between Qt's event loop (`QTimer`) and Python's `multiprocessing.connection`.
- `from_env()` factory method reads connection parameters from environment variables.
- Proper cleanup in `close()` method.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 151-152 | `except Exception: pass` -- silently swallows errors when sending failure responses back to the supervisor. This is acceptable in a cleanup path but should at minimum log. | Low |
| 160-162 | Same pattern in `close()` -- `except Exception: pass` when closing the connection. Acceptable for cleanup. | Low |
| 29-36 | `from_env()` prints to stdout on connection failure. Should use `logging`. | Low |

**Positive Notes:**
- Good use of `QTimer` for non-blocking polling.
- `_normalize_payload()` ensures consistent response format even for edge cases.
- `_failed_payload()` helper prevents response format drift.

---

### 4.5 UI Tabs

#### 4.5.1 `ui/tabs/database_tab.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/tabs/database_tab.py`            |
| **LOC**         | 296                                  |
| **Classes**     | 2 (`EntityTabWidget`, `DatabaseTab`) |
| **Methods**     | ~18                                  |
| **Purpose**     | Dual-panel entity card management with drag-and-drop support |
| **Severity**    | Medium                               |

**Quality Observations:**
- Clean dual-panel architecture with `tab_manager_left` and `tab_manager_right`.
- Drag-and-drop from the sidebar to either panel works via `dropEvent()`.
- Tab closing via middle-click and Ctrl+W shortcut.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 38-43 | Hardcoded CSS in `EntityTabWidget.__init__()`. This 6-line stylesheet overrides the theme system for tab colors. | High |
| 81 | Turkish comment: `"Sidebar'daki sinifslari artik oradan import etmiyoruz..."` | Low |
| 116-147 | `open_entity_tab()` handles API IDs (`lib_...` prefix) with inline parsing and category mapping. This routing logic should be in a separate method or the API layer. | Medium |
| 191 | Emoji characters used in tab titles (`"NPC"` -> emoji, `"Monster"` -> emoji). These are hardcoded, not from the locale system. | Low |
| 249-253 | `delete_entity_from_tab()` emits `entity_deleted` signal after deletion. This is correct but the signal is defined at line 81 with a Turkish comment. | Info |

**Positive Notes:**
- `EntityTabWidget` is a clean, focused class.
- The dual-panel pattern allows comparing entities side by side -- a good UX decision.
- Proper signal propagation for entity deletion.

---

#### 4.5.2 `ui/tabs/session_tab.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/tabs/session_tab.py`             |
| **LOC**         | 272                                  |
| **Classes**     | 1 (`SessionTab`)                     |
| **Methods**     | ~16                                  |
| **Purpose**     | Session management with combat tracker, dice roller, event log, and embedded battle map |
| **Severity**    | Medium                               |

**Quality Observations:**
- Good use of `QSplitter` for resizable left/right panels.
- The left panel contains the combat tracker and dice roller; the right panel has session controls, event log, notes, and embedded map.
- Auto-save on every change via signal connections.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 89-90 | `hasattr(self.parent(), "db_tab")` guard for signal connection. This indicates fragile initialization order -- the parent might not have `db_tab` when `SessionTab` is constructed. | Medium |
| 117 | `init_ui()` is 117 lines long. While not extreme, the nested layout construction could be split into `_build_left_panel()` and `_build_right_panel()` helper methods. | Low |
| 118 | `hasattr(tr, "BTN_LOAD_MAP")` -- checks if a translation function has an attribute, which is always False for a function. This is a bug that silently falls through to the `"Load Map"` fallback string. | High |
| 122 | Same `hasattr(tr, "BTN_BATTLE_MAP")` bug. | High |
| 209 | `isinstance(combatants_data, dict)` -- duck-typing check to distinguish between old list format and new dict format. This migration logic should be in the persistence layer, not the UI. | Medium |
| 256 | Hardcoded Turkish string: `"Oturum bulunamadi veya silinmis."` (Session not found or deleted). Should use `tr()`. | High |
| 268-269 | Repeated `hasattr(tr, ...)` bug in `retranslate_ui()`. | High |

**Positive Notes:**
- `save_fog_for_encounter()` cleanly captures fog-of-war state per encounter.
- `refresh_embedded_map()` properly resolves entity types and attitudes for token display.
- Dice roller is a simple, effective feature.

---

#### 4.5.3 `ui/tabs/map_tab.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/tabs/map_tab.py`                 |
| **LOC**         | 271                                  |
| **Classes**     | 1 (`MapTab`)                         |
| **Methods**     | ~15                                  |
| **Purpose**     | World map viewer with timeline pins and region management |
| **Severity**    | Medium                               |

**Quality Observations:**
- Manages map images, timeline entries, and region annotations.
- Multiple responsibilities (map display, timeline management, region editing) but reasonable for a tab class.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 120 | Very long one-liner statement that combines multiple operations. Hard to read and debug. | Medium |
| 182, 190, 245 | More compressed one-liner statements with multiple chained operations. | Medium |
| Throughout | Turkish comments | Low |
| ~150-200 | Timeline pin creation and connection drawing logic is interleaved with map rendering. Could be extracted to a dedicated timeline manager. | Low |

---

#### 4.5.4 `ui/tabs/mind_map_tab.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/tabs/mind_map_tab.py`            |
| **LOC**         | 617                                  |
| **Classes**     | 4 (`MindMapScene`, `CustomGraphicsView`, `FloatingControls`, `MindMapTab`) |
| **Methods**     | ~29                                  |
| **Purpose**     | Visual mind map editor for entity relationships |
| **Severity**    | High                                 |

**Quality Observations:**
- Four classes in one file is borderline. `MindMapScene` and `CustomGraphicsView` could be in separate files.
- Uses Qt's Graphics View Framework (`QGraphicsScene`, `QGraphicsView`) for the mind map canvas.
- `FloatingControls` is a small widget overlay -- clean implementation.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 470 | Bare except: `except: pass` in `process_pending_entity_saves()`. This silently swallows save failures for entities modified in the mind map. | Critical |
| Throughout | Turkish comments throughout all four classes | Medium |
| ~200-300 | `MindMapScene` handles mouse events, node creation, connection drawing, and serialization. This is too many responsibilities for a scene class. | High |
| ~400-500 | `MindMapTab` mixes layout construction, data loading, save logic, and entity processing. | Medium |

---

### 4.6 UI Widgets

#### 4.6.1 `ui/widgets/npc_sheet.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/widgets/npc_sheet.py`            |
| **LOC**         | 1,002                                |
| **Classes**     | 1 (`NpcSheet`)                       |
| **Methods**     | ~46                                  |
| **Purpose**     | Entity detail sheet: UI layout, data display/editing, image management, PDF management, linked entities, drag-and-drop, API browser integration |
| **Severity**    | **Critical**                         |

**Quality Observations:**
- The second god class in the codebase. At 1,002 LOC and 46 methods, it is the longest file and the most method-dense class.
- Imports `ApiBrowser` inside `__init__` body (line 17 at top, but also used in methods), creating a circular dependency risk.
- Mixes at least 6 responsibilities: UI construction, data collection, image gallery, PDF management, linked entity management, and API browser invocation.
- The `init_ui()` method alone is likely 200+ lines of form layout construction.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 17 | `from ui.dialogs.api_browser import ApiBrowser` -- top-level import creates tight coupling between widget and dialog layers | Medium |
| 40 | `from core.theme_manager import ThemeManager` -- redundant import (already imported at line 14). The re-import inside `__init__` suggests a copy-paste artifact. | Low |
| ~50-250 | `init_ui()` is an estimated 200-line method constructing the entire form layout. Should be decomposed into `_build_header()`, `_build_attributes()`, `_build_combat_stats()`, `_build_image_gallery()`, `_build_pdf_section()`, etc. | High |
| ~300-400 | Image management methods (`add_image()`, `remove_image()`, `next_image()`, `prev_image()`, `download_api_image()`) -- a self-contained subsystem that should be its own widget. | High |
| ~500-600 | PDF management methods (`add_pdf_dialog()`, `open_current_pdf()`, `remove_current_pdf()`, `open_pdf_folder()`) -- another subsystem that should be extracted. | High |
| ~700-800 | `populate_sheet()` and `collect_data_from_sheet()` are mirror methods that read/write form fields. Any field added to `init_ui()` must also be updated in both methods -- a maintenance trap. | High |
| ~900-1002 | Linked entity management (`add_linked_spell()`, `remove_linked_spell()`, etc.) with drag-and-drop support. | Medium |

**Recommended Decomposition:**

```
NpcSheet (current: 46 methods, 1002 LOC)
  --> ImageGalleryWidget     (~8 methods, ~150 LOC)
  --> PdfManagerWidget       (~5 methods, ~100 LOC)
  --> LinkedEntityWidget     (~6 methods, ~120 LOC)
  --> EntityFormBuilder      (init_ui decomposition: ~200 LOC)
  --> NpcSheet               (orchestrator: ~15 methods, ~400 LOC)
```

---

#### 4.6.2 `ui/widgets/combat_tracker.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/widgets/combat_tracker.py`       |
| **LOC**         | 912                                  |
| **Classes**     | 3+ (`DraggableCombatTable`, `CombatTracker`, and possibly others) |
| **Methods**     | ~41                                  |
| **Purpose**     | D&D combat management: initiative tracking, HP management, conditions, encounter management, battle map integration |
| **Severity**    | High                                 |

**Quality Observations:**
- The third god-class candidate at 912 LOC and ~41 methods.
- Contains inline class `DraggableCombatTable` that extends `QTableWidget` for drag-and-drop.
- `CONDITIONS_MAP` (lines 29-45) maps English condition names to locale keys -- a clean approach.
- Manages encounter state including combatants, turn order, map references, and fog-of-war data.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 17 | Turkish comment: `"# --- YARDIMCILAR ---"` (Helpers) | Low |
| 18-26 | `clean_stat_value()` function-level bare except at line 26: `except: return default`. This silently handles malformed stat strings but masks parsing bugs. | Medium |
| 28 | Turkish comment: `"Standart Durum Listesi..."` | Low |
| 47-49 | `DraggableCombatTable` class with Turkish docstring: `"Suruklenen Entity'leri kabul eden ozel tablo."` | Low |
| ~100-200 | `CombatTracker.__init__()` builds the entire combat UI inline. Should use helper methods. | Medium |
| ~300-400 | `add_combatant()`, `remove_combatant()`, `update_combatant_hp()` -- core combat logic that is reasonable but lacks input validation. | Medium |
| ~500-600 | Encounter management (`save_encounter()`, `load_encounter()`, `new_encounter()`) handles complex state serialization. | Medium |
| ~700-800 | Map integration methods (`load_map_dialog()`, `open_battle_map()`, `sync_map_view_to_external()`, `sync_fog_to_external()`) bridge between the combat tracker and the battle map. | Low |
| ~850-912 | `get_session_state()` and `load_session_state()` serialize/deserialize the entire combat tracker state. Complex but necessary. | Low |

---

#### 4.6.3 `ui/widgets/entity_sidebar.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/widgets/entity_sidebar.py`       |
| **LOC**         | 332                                  |
| **Classes**     | 1 (`EntitySidebar`)                  |
| **Methods**     | ~15                                  |
| **Purpose**     | Global entity list with search, category filtering, and drag support |
| **Severity**    | Medium                               |

**Quality Observations:**
- Provides a filterable list of all entities across the application.
- Supports drag-and-drop: items can be dragged to the database tab panels or combat tracker.
- Integrates with the library catalog for search results.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 25, 33 | Hardcoded CSS for search input and list widget styling | Medium |
| 49-57 | Turkish translation map that duplicates locale key logic: maps English category names to Turkish display names with a hardcoded dict. This should use `tr()` exclusively. | High |
| 113-116 | More hardcoded CSS for category filter buttons | Medium |
| 257-263 | Second Turkish translation map for the reverse mapping. Both maps are maintenance liabilities that will drift from the locale files. | High |

**Positive Notes:**
- Good test coverage (3 tests in `test_entity_sidebar_library.py`).
- Clean drag initiation with `QMimeData`.

---

#### 4.6.4 `ui/widgets/mind_map_items.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/widgets/mind_map_items.py`       |
| **LOC**         | 455                                  |
| **Classes**     | 4 (`MindMapNode`, `ConnectionLine`, `WorkspaceItem`, `ResizeHandle`) |
| **Methods**     | ~25                                  |
| **Purpose**     | Visual items for the mind map canvas |
| **Severity**    | Medium                               |

**Quality Observations:**
- Clean separation of visual items: nodes, connections, workspace backgrounds, and resize handles.
- Uses `QPainter` for custom rendering -- correct approach for QGraphicsItems.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| Throughout | Turkish comments | Low |
| ~100-200 | `MindMapNode.paint()` has complex rendering logic with shadow, gradient, and text layout. Could benefit from extraction of rendering constants. | Low |
| ~250-300 | `ConnectionLine` calculates bezier curves for connections. The math is correct but undocumented. | Low |

---

#### 4.6.5 `ui/widgets/markdown_editor.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/widgets/markdown_editor.py`      |
| **LOC**         | 415                                  |
| **Classes**     | 4 (`MentionPopup`, `ClickableTextBrowser`, `PropagatingTextEdit`, `MarkdownEditor`) |
| **Methods**     | ~22                                  |
| **Purpose**     | Rich text editor with markdown rendering, entity mention autocomplete, and click-to-navigate |
| **Severity**    | Medium                               |

**Quality Observations:**
- The entity mention system (`@entity_name`) with autocomplete popup is a sophisticated feature.
- `ClickableTextBrowser` intercepts anchor clicks and emits signals for entity navigation.
- `PropagatingTextEdit` propagates wheel events to parent for scroll-through behavior.
- `MarkdownEditor` combines edit and preview modes with toggle.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 18-27 | `MentionPopup.__init__()` contains hardcoded CSS: 10 lines of stylesheet for the popup styling. Should use theme system. | Medium |
| ~100-150 | `ClickableTextBrowser` parses `href` attributes to detect entity links. The link format (`entity://eid`) is not documented anywhere. | Medium |
| ~200-300 | `MarkdownEditor` handles both plain text editing and markdown preview rendering. The toggle between modes re-renders the entire document each time. For long documents, this could be slow. | Low |

---

#### 4.6.6 `ui/widgets/map_viewer.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/widgets/map_viewer.py`           |
| **LOC**         | 232                                  |
| **Classes**     | 4 (`MapViewer`, `MapPinItem`, `TimelinePinItem`, `TimelineConnectionItem`) |
| **Methods**     | ~14                                  |
| **Purpose**     | Map display widget with pin markers and timeline connections |
| **Severity**    | Low                                  |

**Quality Observations:**
- Uses Qt Graphics View Framework for zoomable, pannable map display.
- Pin items support click interaction and hover effects.
- Timeline connections draw lines between chronologically related pins.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| Throughout | Turkish comments | Low |
| ~50-100 | `MapPinItem.paint()` renders pin icons with text labels. The text truncation logic is hardcoded to 10 characters. | Low |

---

#### 4.6.7 `ui/widgets/projection_manager.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/widgets/projection_manager.py`   |
| **LOC**         | 231                                  |
| **Classes**     | 1 (`ProjectionManager`)              |
| **Methods**     | ~12                                  |
| **Purpose**     | Controls for projecting content to the player window |
| **Severity**    | Low                                  |

**Quality Observations:**
- Theme-aware: has `update_theme()` and `apply_styles()` methods that read from `ThemeManager.get_palette()`.
- Reasonable docstring coverage compared to most files.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| ~50-80 | `apply_styles()` builds CSS from palette values, which is the correct pattern for theme-aware widgets. Other widgets should follow this approach. | Info |

**Positive Notes:**
- Good example of how to properly integrate with the theme system.

---

#### 4.6.8 `ui/widgets/image_viewer.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/widgets/image_viewer.py`         |
| **LOC**         | 55                                   |
| **Classes**     | 1 (`ImageViewer`)                    |
| **Methods**     | ~4                                   |
| **Purpose**     | Simple zoomable image display widget |
| **Severity**    | Info                                 |

**Quality Observations:**
- Small, focused, single-purpose. Clean implementation.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| Throughout | Turkish comments | Low |

---

#### 4.6.9 `ui/widgets/aspect_ratio_label.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/widgets/aspect_ratio_label.py`   |
| **LOC**         | 68                                   |
| **Classes**     | 1 (`AspectRatioLabel`)               |
| **Methods**     | ~5                                   |
| **Purpose**     | QLabel subclass that preserves image aspect ratio and supports drag-and-drop |
| **Severity**    | Info                                 |

**Quality Observations:**
- Small, focused. Overrides `resizeEvent()` to maintain aspect ratio.
- Supports starting a drag operation for image content.

---

### 4.7 UI Dialogs

#### 4.7.1 `ui/dialogs/import_window.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/dialogs/import_window.py`        |
| **LOC**         | 422                                  |
| **Classes**     | 4 (`LibraryScanWorker`, `LocalLibraryTab`, `OnlineApiTab`, `ImportWindow`) |
| **Methods**     | ~20                                  |
| **Purpose**     | Library import dialog with local scanning and online API search tabs |
| **Severity**    | Medium                               |

**Quality Observations:**
- Contains both worker class (`LibraryScanWorker`) and UI classes in the same file.
- `LocalLibraryTab` scans the local library cache and displays results.
- `OnlineApiTab` provides online search via the API client.
- `ImportWindow` is a tabbed dialog hosting both tabs.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 162 | Bare except clause that silently handles import failures | High |
| ~50-100 | `LibraryScanWorker` runs filesystem operations in a QThread. The progress reporting is well-implemented with `progress` signal. | Info |
| ~200-300 | `OnlineApiTab` duplicates some search UI patterns from `api_browser.py`. | Medium |
| Throughout | Turkish comments | Low |

---

#### 4.7.2 `ui/dialogs/api_browser.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/dialogs/api_browser.py`          |
| **LOC**         | 490                                  |
| **Classes**     | 1 (`ApiBrowser`)                     |
| **Methods**     | ~18                                  |
| **Purpose**     | Modal API search and browse dialog for D&D 5e entities |
| **Severity**    | High                                 |

**Quality Observations:**
- `init_ui()` is 129 lines long -- the entire dialog layout is constructed in one method.
- Multiple bare except clauses for API response handling.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 91 | Duplicated placeholder text assignment | Low |
| ~50-178 | `init_ui()` at 129 lines is too long. Should be decomposed. | Medium |
| Multiple | Bare except clauses in API response parsing. When the API returns unexpected data, errors are silently swallowed. | High |
| Throughout | Turkish comments | Low |

---

#### 4.7.3 `ui/dialogs/bulk_downloader.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/dialogs/bulk_downloader.py`      |
| **LOC**         | 290                                  |
| **Classes**     | 2 (`DownloadWorker`, `BulkDownloaderDialog`) |
| **Methods**     | ~12                                  |
| **Purpose**     | Bulk download manager for D&D 5e API content |
| **Severity**    | Medium                               |

**Quality Observations:**
- `DownloadWorker` runs in a QThread and downloads all entities from selected API categories.
- Progress reporting via signals is well-implemented.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| ~50-150 | `DownloadWorker.run()` has deep nesting (4+ levels) with nested loops and try/except blocks. | Medium |
| ~200-250 | Hardcoded CSS for the progress bar and status display | Medium |
| Throughout | Turkish comments | Low |

**Positive Notes:**
- Good test coverage: `test_bulk_downloader_paths.py` verifies the file output structure.

---

#### 4.7.4 `ui/dialogs/encounter_selector.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/dialogs/encounter_selector.py`   |
| **LOC**         | 211                                  |
| **Classes**     | 1 (`EncounterSelectionDialog`)       |
| **Methods**     | ~10                                  |
| **Purpose**     | Dialog for selecting and managing encounters |
| **Severity**    | Medium                               |

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 92 | Bare except clause in encounter loading | Medium |
| Throughout | Turkish comments | Low |

---

#### 4.7.5 `ui/dialogs/entity_selector.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/dialogs/entity_selector.py`      |
| **LOC**         | 121                                  |
| **Classes**     | 1 (`EntitySelector`)                 |
| **Methods**     | ~6                                   |
| **Purpose**     | Simple entity picker dialog with table display |
| **Severity**    | Low                                  |

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 35-36 | Duplicate line: `self.table = QTableWidget()` appears twice consecutively. The second assignment overwrites the first. While harmless, it indicates a copy-paste error. | Low |
| ~50-80 | Hardcoded CSS for table styling | Medium |

---

#### 4.7.6 `ui/dialogs/timeline_entry.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/dialogs/timeline_entry.py`       |
| **LOC**         | 134                                  |
| **Classes**     | 1 (`TimelineEntryDialog`)            |
| **Methods**     | ~5                                   |
| **Purpose**     | Dialog for creating/editing timeline events |
| **Severity**    | Low                                  |

**Quality Observations:**
- Small, focused dialog. Clean implementation.
- No significant issues beyond the standard Turkish comments.

---

#### 4.7.7 `ui/dialogs/theme_builder.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/dialogs/theme_builder.py`        |
| **LOC**         | 187                                  |
| **Classes**     | 1 (`ThemeBuilderDialog`)             |
| **Methods**     | ~8                                   |
| **Purpose**     | Theme customization dialog with color pickers |
| **Severity**    | Low                                  |

**Quality Observations:**
- Allows users to modify theme colors via color picker dialogs.
- Clean implementation, reasonable size.

---

### 4.8 UI Windows and Panels

#### 4.8.1 `ui/windows/battle_map_window.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/windows/battle_map_window.py`    |
| **LOC**         | 762                                  |
| **Classes**     | 6 (`FogItem`, `BattleMapView`, `SidebarConditionIcon`, `BattleTokenItem`, `BattleMapWidget`, `BattleMapWindow`) |
| **Methods**     | ~35                                  |
| **Purpose**     | Battle map system with fog-of-war, token management, and video map support |
| **Severity**    | High                                 |

**Quality Observations:**
- The most feature-dense file after `npc_sheet.py`. Contains 6 classes implementing a full battle map system.
- `FogItem` implements fog-of-war painting with eraser/brush tools.
- `BattleTokenItem` renders character tokens with condition icons.
- `BattleMapWidget` is the embeddable map component; `BattleMapWindow` is the standalone window wrapper.
- Video map support via `QVideoWidget` for animated backgrounds.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| ~100-200 | `BattleMapView` handles mouse events for both fog painting and token dragging. The mode switching between these is handled by internal flags -- could be a strategy pattern. | Medium |
| ~300-400 | `BattleTokenItem.paint()` renders tokens with condition icons, HP bars, and initiative markers. Complex but well-structured. | Low |
| ~500-600 | `BattleMapWidget` manages the toolbar, map loading, token updates, and fog state. It is the most complex class in the file at ~250 lines. | Medium |
| ~700-762 | `BattleMapWindow` is a thin wrapper that creates a `BattleMapWidget` in a standalone window. Clean. | Info |
| Throughout | Hardcoded CSS for sidebar condition icons and toolbar elements | Medium |

**Recommendation:** Extract `FogItem` and `BattleTokenItem` into separate files under `ui/widgets/battle_map/`.

---

#### 4.8.2 `ui/soundpad_panel.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/soundpad_panel.py`               |
| **LOC**         | 439                                  |
| **Classes**     | 1 (`SoundpadPanel`)                  |
| **Methods**     | ~25                                  |
| **Purpose**     | Sound effects panel with audio themes, ambient layers, and quick-play buttons |
| **Severity**    | Medium                               |

**Quality Observations:**
- Integrates with the audio engine subsystem.
- Complex nested UI with theme selection, ambient layer controls, and SFX buttons.
- `init_ui()` builds the entire panel layout inline.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| ~50-150 | `init_ui()` is approximately 100 lines of layout construction with nested `QGroupBox` and `QVBoxLayout`/`QHBoxLayout` combinations. | Medium |
| ~200-300 | Audio theme loading creates buttons dynamically from YAML configuration. The button creation logic is inline with signal connections. | Low |
| Throughout | Turkish comments (~10 instances) | Low |

---

### 4.9 UI Infrastructure

#### 4.9.1 `ui/main_root.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/main_root.py`                    |
| **LOC**         | 162                                  |
| **Classes**     | 0                                    |
| **Functions**   | 1 (`create_root_widget`)             |
| **Purpose**     | Factory function that builds the entire main window UI tree |
| **Severity**    | Medium                               |

**Quality Observations:**
- Single function of 139 lines that creates all tabs, the sidebar, the soundpad panel, and wires initial signal connections.
- Returns a dict bundle `{"root": widget, "tabs": ..., "db_tab": ..., ...}` rather than a typed object.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 1-162 | `create_root_widget()` is a 139-line monolithic function. It builds the entire UI tree in sequence. While functional, it is hard to test individual parts. | Medium |
| ~140-160 | The return dict has string keys (`"tabs"`, `"db_tab"`, `"map_tab"`, etc.) with no type annotation or documentation of the expected shape. Callers must know the exact key names. | Medium |

**Recommendation:** Return a `NamedTuple` or `dataclass` instead of a plain dict:

```python
from typing import NamedTuple

class RootBundle(NamedTuple):
    root: QWidget
    tabs: QTabWidget
    db_tab: DatabaseTab
    map_tab: MapTab
    session_tab: SessionTab
    entity_sidebar: EntitySidebar
    soundpad_panel: SoundpadPanel
```

---

#### 4.9.2 `ui/campaign_selector.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/campaign_selector.py`            |
| **LOC**         | 123                                  |
| **Classes**     | 1 (`CampaignSelector`)              |
| **Methods**     | ~6                                   |
| **Purpose**     | Campaign selection/creation dialog shown at startup |
| **Severity**    | Low                                  |

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 1 | Turkish comment on the first line | Low |
| ~50-80 | Campaign listing reads directly from `WORLDS_DIR`. If the directory does not exist, `os.listdir()` would throw. No guard for this case. | Medium |

---

#### 4.9.3 `ui/player_window.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/player_window.py`                |
| **LOC**         | 147                                  |
| **Classes**     | 1 (`PlayerWindow`)                   |
| **Methods**     | ~8                                   |
| **Purpose**     | Player-facing projection window for images and PDFs |
| **Severity**    | Low                                  |

**Quality Observations:**
- Simple window that can display images or PDFs.
- PDF display uses lazy-loaded `QWebEngineView` -- correct approach to avoid loading the heavy web engine until needed.
- `show_pdf()` creates the web view only when first called.

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| ~80-100 | Multi-image display uses a stacked layout with manual index tracking. Navigation between images has no bounds checking visible in the preview. | Low |

---

#### 4.9.4 `ui/workers.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `ui/workers.py`                      |
| **LOC**         | 71                                   |
| **Classes**     | 3 (`ApiSearchWorker`, `ApiListWorker`, `ImageDownloadWorker`) |
| **Methods**     | ~6                                   |
| **Purpose**     | QThread workers for async API and image operations |
| **Severity**    | Low                                  |

**Quality Observations:**
- Small, focused file. Each worker is a simple QThread subclass with a `run()` method and a `finished` signal.
- Clean pattern for thread-safe API calls.

---

### 4.10 Utilities and Build

#### 4.10.1 `dump.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `dump.py`                            |
| **LOC**         | 113                                  |
| **Classes**     | 0                                    |
| **Functions**   | 5                                    |
| **Purpose**     | Utility to dump project directory tree and file contents to a text file |
| **Severity**    | Info                                 |

**Quality Observations:**
- Development utility, not part of the production application.
- Clean implementation with proper exclusion logic for directories and file patterns.
- Docstrings on all functions.

---

#### 4.10.2 `installer/build.py`

| Metric          | Value                                |
|-----------------|--------------------------------------|
| **Path**        | `installer/build.py`                 |
| **LOC**         | 101                                  |
| **Classes**     | 0                                    |
| **Functions**   | 3 (`resolve_hidden_imports`, `clean`, `build`) |
| **Purpose**     | PyInstaller build script for packaging the application |
| **Severity**    | Low                                  |

**Quality Observations:**
- Handles hidden imports for PyInstaller, including dynamic collection of UI submodules.
- Copies resource folders (assets, themes, locales) to the distribution directory.
- Handles platform-specific paths (macOS `.app` bundle vs Windows/Linux directory).

**Specific Issues:**

| Line | Issue | Severity |
|------|-------|----------|
| 55 | Turkish comment: `"MacOS'ta .app bundle olusturur, Windows'ta konsolu gizler"` | Low |
| 77 | Turkish comment: `"KAYNAK DOSYALARI KOPYALA"` (Copy resource files) | Low |

---

## 5. Systemic Issues

### 5.1 Type Safety

**Severity: Critical**

The codebase has near-zero type safety. Only 4 of 35 production files use the `typing` module:

| File | Type Hint Usage |
|------|----------------|
| `dev_run.py` | Comprehensive: `Iterable`, `List`, `Optional`, `Sequence`, `Tuple` |
| `core/dev/hot_reload_manager.py` | Comprehensive: `Dict`, `List`, `Set`, `Iterable`, `Path \| None` |
| `core/audio/engine.py` | Partial: `Dict`, `List` |
| `main.py` | Partial: `Optional`, `Dict`, `Any` |

The remaining 31 files have **zero** type annotations on function parameters or return values. This means:

- IDEs cannot provide accurate autocompletion or type-error detection.
- Refactoring is high-risk because type mismatches are only caught at runtime.
- The `DataManager` class returns `dict` from every method, but the structure of these dicts is undocumented and varies.
- Entity data flows through the system as `dict[str, Any]` with implicit key expectations.

**Impact:** Without type hints, adding `mypy` or `pyright` for static analysis is impossible. Every refactoring requires extensive manual testing.

**Recommendation:** Start with the most-touched interfaces:
1. `DataManager` public methods (parameter types and return types)
2. `NpcSheet.populate_sheet()` and `collect_data_from_sheet()` (data shape)
3. Signal handler signatures across all widgets
4. All new code should require type hints in code review

### 5.2 Documentation Debt

**Severity: High**

Docstring coverage across the codebase is estimated at <15%:

| Category | Files with >50% docstring coverage |
|----------|----------------------------------|
| Core | `config.py`, `library_fs.py`, `audio/models.py` |
| Dev | `hot_reload_manager.py`, `ipc_bridge.py` |
| UI | `projection_manager.py` |
| **Total** | **6 of 35 files** |

Most classes have no docstring or a one-line Turkish comment serving as a docstring. Method-level documentation is almost nonexistent outside the dev tooling module.

Critical documentation gaps:
- `DataManager` -- 45 methods with no parameter or return documentation
- `NpcSheet` -- 46 methods with no documentation
- `CombatTracker` -- 41 methods with no documentation
- Entity data structure -- no schema documentation beyond `core/models.py` dict definitions
- Signal/slot contracts -- no documentation of expected data formats

### 5.3 Code Organization

**Severity: Medium**

Several files contain multiple classes that should be in separate files:

| File | Classes | Should Split? |
|------|---------|--------------|
| `battle_map_window.py` | 6 classes, 762 LOC | Yes -- extract items to `ui/widgets/battle_map/` |
| `mind_map_tab.py` | 4 classes, 617 LOC | Yes -- extract scene and view |
| `mind_map_items.py` | 4 classes, 455 LOC | Borderline -- all items are cohesive |
| `markdown_editor.py` | 4 classes, 415 LOC | Borderline -- popup and browser are small |
| `import_window.py` | 4 classes, 422 LOC | Yes -- extract worker and tabs |
| `combat_tracker.py` | 3+ classes, 912 LOC | Yes -- extract table widget |
| `api_client.py` | 4 classes, 705 LOC | Yes -- one file per source class |

The `ui/dialogs/` directory contains both dialogs and workers. Workers should be in `ui/workers.py` (which already exists) or a dedicated `ui/workers/` package.

### 5.4 Hardcoded Inline CSS

**Severity: High**

Seven files contain hardcoded CSS that bypasses the theme system:

| File | Lines | Elements Styled |
|------|-------|----------------|
| `database_tab.py` | 38-43 | Tab pane, tab bar, selected/hover states |
| `entity_sidebar.py` | 25, 33, 113-116 | Search input, list widget, filter buttons |
| `markdown_editor.py` | 18-27 | Mention popup |
| `bulk_downloader.py` | ~200-250 | Progress bar, status display |
| `entity_selector.py` | ~50-80 | Table widget |
| `api_browser.py` | Multiple | Various elements |
| `battle_map_window.py` | Multiple | Sidebar icons, toolbar |

**Impact:** When users switch themes (dark/light/custom), these elements retain their hardcoded appearance, creating visual inconsistencies. The theme system (`ThemeManager` palette + external QSS) is partially undermined.

**Recommendation:** Replace all `setStyleSheet("...")` calls with either:
1. Theme-palette-based styling (see `projection_manager.py` for the correct pattern)
2. QSS class selectors in the external theme files
3. `ThemeManager.get_palette()` color lookups

### 5.5 Error Handling

**Severity: High**

The codebase has two categories of error handling problems:

#### 5.5.1 Bare Except Clauses (8 files)

| File | Line | Context |
|------|------|---------|
| `core/data_manager.py` | 113 | `except: pass` in `save_data()` |
| `core/api_client.py` | 689 | `except:` in parse dispatcher |
| `ui/widgets/combat_tracker.py` | 26 | `except: return default` in `clean_stat_value()` |
| `ui/tabs/mind_map_tab.py` | 470 | `except: pass` in `process_pending_entity_saves()` |
| `ui/dialogs/import_window.py` | 162 | `except:` in import handling |
| `ui/dialogs/api_browser.py` | Multiple | `except:` in API response parsing |
| `ui/dialogs/encounter_selector.py` | 92 | `except:` in encounter loading |
| `core/dev/ipc_bridge.py` | 151-152, 160-162 | `except Exception: pass` in cleanup paths |

The most dangerous are `data_manager.py:113` (silently loses save errors) and `mind_map_tab.py:470` (silently loses entity save errors).

#### 5.5.2 Print-Based Logging

`print()` is used for error output throughout the codebase instead of the `logging` module. This means:
- No log levels (debug vs warning vs error)
- No log formatting or timestamps
- No ability to redirect to files in production
- No way to filter or aggregate errors

Key offenders: `data_manager.py` (10+ print statements), `api_client.py` (~5), `hot_reload_manager.py` (5), `ipc_bridge.py` (3).

### 5.6 Testing Gaps

**Severity: High**

The test suite contains 12 files with 858 total LOC covering ~32 test functions. While the tests that exist are well-written, coverage is sparse:

| Module | Test File | Tests | Coverage Assessment |
|--------|-----------|-------|-------------------|
| `config.py` | `test_config_paths.py` | 3 | Good: covers all 3 data root modes |
| `core/locales.py` | `test_locales.py` | 3 | Good: basic, Turkish, missing key |
| `core/api_client.py` | `test_api_client.py` | 3 | Partial: parse only, no network |
| `core/data_manager.py` | `test_data_manager.py` | 3 | Partial: init, persistence, migration |
| `core/library_fs.py` | `test_library_fs.py` | 5 | Good: migrate, scan, search |
| `core/dev/hot_reload_manager.py` | `test_hot_reload_manager.py` | 11 | Excellent: all outcomes |
| `dev_run.py` | `test_dev_supervisor_outcomes.py` | 5 | Good: all supervisor paths |
| `dev_run.py` | `test_dev_run_cli.py` | 4 | Good: CLI args |
| `ui/widgets/entity_sidebar.py` | `test_entity_sidebar_library.py` | 3 | Partial: search + filter |
| `ui/dialogs/bulk_downloader.py` | `test_bulk_downloader_paths.py` | 1 | Minimal: output path only |
| `main.py` (MainWindow) | `test_main_window.py` | 4 | Smoke: init + tab switching |

**Completely Untested Modules (0 tests):**

- `core/models.py` -- Entity schema definitions
- `core/theme_manager.py` -- Theme palette management
- `core/audio/engine.py` -- Audio playback engine
- `core/audio/loader.py` -- Audio theme loading
- `ui/tabs/session_tab.py` -- Session management
- `ui/tabs/map_tab.py` -- World map tab
- `ui/tabs/mind_map_tab.py` -- Mind map editor
- `ui/widgets/npc_sheet.py` -- Entity detail sheet (1,002 LOC, 0 tests)
- `ui/widgets/combat_tracker.py` -- Combat tracker (912 LOC, 0 tests)
- `ui/widgets/markdown_editor.py` -- Markdown editor
- `ui/widgets/mind_map_items.py` -- Mind map visual items
- `ui/widgets/map_viewer.py` -- Map viewer
- `ui/widgets/projection_manager.py` -- Projection controls
- `ui/windows/battle_map_window.py` -- Battle map (762 LOC, 0 tests)
- `ui/soundpad_panel.py` -- Sound panel
- `ui/dialogs/api_browser.py` -- API browser
- `ui/dialogs/import_window.py` -- Import dialog
- `ui/dialogs/encounter_selector.py` -- Encounter selector
- `ui/dialogs/entity_selector.py` -- Entity selector

The three largest files (npc_sheet.py, combat_tracker.py, battle_map_window.py) totaling 2,676 LOC have **zero** test coverage.

### 5.7 Internationalization (i18n)

**Severity: Medium**

The i18n system is structurally sound (python-i18n with YAML locale files), but implementation is inconsistent:

1. **Hardcoded Turkish strings** appear in production code:
   - `main.py:46` -- `"Bilinmiyor"` (Unknown)
   - `core/models.py:155` -- `"Yeni Kayit"` (New Record)
   - `ui/tabs/session_tab.py:256` -- `"Oturum bulunamadi veya silinmis."` (Session not found)
   - `ui/widgets/entity_sidebar.py:49-57` -- Turkish category name mapping dict

2. **`hasattr(tr, "KEY")` pattern** in `session_tab.py` (lines 118, 122, 268-269) is a bug. `tr` is a function; `hasattr(tr, "BTN_LOAD_MAP")` always returns `False`, causing the code to always use the English fallback string. The correct check would be `tr("BTN_LOAD_MAP") != "BTN_LOAD_MAP"`.

3. **Duplicate translation maps** in `entity_sidebar.py` at lines 49-57 and 257-263 duplicate the locale system by hardcoding English-to-Turkish category mappings. These will drift from the YAML locale files.

4. **Turkish comments** appear in ~28 of 35 production files. While not a runtime issue, they create a barrier for non-Turkish-speaking contributors. Only the dev tooling files (`dev_run.py`, `hot_reload_manager.py`, `ipc_bridge.py`) are consistently English.

### 5.8 Dependency on Raw Dicts

**Severity: High**

The entire application represents entities, sessions, encounters, and combat state as raw `dict` objects. There are no dataclasses, TypedDict, Pydantic models, or even NamedTuples for structured data.

**Examples of implicit dict contracts:**

```python
# Entity (from DataManager)
entity = {
    "name": str,
    "type": str,  # "NPC", "Monster", "Spell", etc.
    "attributes": {str: str},  # LBL_* keys to values
    "combat_stats": {"ac": str, "hp": str, "speed": str, ...},
    "description": str,
    "notes": str,
    "images": [str],
    "pdfs": [str],
    "source": str,
    ...
}

# Session (from DataManager)
session = {
    "id": str,
    "name": str,
    "logs": str,
    "notes": str,
    "combatants": dict | list,  # Two formats exist!
    ...
}

# Encounter (from CombatTracker)
encounter = {
    "combatants": [{
        "eid": str,
        "name": str,
        "initiative": int,
        "hp": int,
        "max_hp": int,
        "map_x": float,
        "map_y": float,
        "token_size": int,
        "conditions": [str],
        ...
    }],
    "map_path": str | None,
    "fog_data": str | None,
    "turn_index": int,
    ...
}
```

These structures are never validated. A missing key causes a `KeyError` at runtime with no helpful error message. The `.get()` pattern is used defensively throughout, but this masks data corruption.

---

## 6. Metrics Summary Table

| # | File Path | LOC | Classes | Methods | Docstrings | Type Hints | Turkish Comments | Bare Excepts | Hardcoded CSS | Severity |
|---|-----------|-----|---------|---------|------------|------------|-----------------|--------------|---------------|----------|
| 1 | `main.py` | 387 | 1 | ~19 | Partial | Partial | 1 | 0 | 0 | Medium |
| 2 | `config.py` | 147 | 0 | ~8 | Good | No | 0 | 1 | 0 | Info |
| 3 | `dev_run.py` | 436 | 1 | ~20 | Partial | Full | 0 | 0 | 0 | Info |
| 4 | `core/data_manager.py` | 677 | 1 | ~45 | None | None | 5+ | 1 | 0 | Critical |
| 5 | `core/api_client.py` | 705 | 4 | ~30 | None | None | 15+ | 1 | 0 | High |
| 6 | `core/models.py` | 197 | 0 | 2 | Minimal | None | 1 | 0 | 0 | Medium |
| 7 | `core/library_fs.py` | 250 | 0 | ~10 | Good | None | 0 | 0 | 0 | Info |
| 8 | `core/locales.py` | 26 | 0 | 1 | None | None | 0 | 0 | 0 | Info |
| 9 | `core/theme_manager.py` | 284 | 1 | 1 | Turkish | None | 20+ | 0 | 0 | Medium |
| 10 | `core/audio/engine.py` | 327 | 3 | ~20 | Turkish | Partial | 10+ | 0 | 0 | Medium |
| 11 | `core/audio/loader.py` | 286 | 1-2 | ~12 | Turkish | None | 10+ | 0 | 0 | Medium |
| 12 | `core/audio/models.py` | 36 | 2-3 | 0 | Turkish | Full | 2 | 0 | 0 | Info |
| 13 | `core/dev/hot_reload_manager.py` | 348 | 1 | ~15 | Good | Full | 0 | 0 | 0 | Info |
| 14 | `core/dev/ipc_bridge.py` | 164 | 1 | ~9 | Good | None | 0 | 2 | 0 | Low |
| 15 | `ui/main_root.py` | 162 | 0 | 1 | None | None | 2+ | 0 | 0 | Medium |
| 16 | `ui/campaign_selector.py` | 123 | 1 | ~6 | None | None | 1 | 0 | 0 | Low |
| 17 | `ui/player_window.py` | 147 | 1 | ~8 | None | None | 2+ | 0 | 0 | Low |
| 18 | `ui/workers.py` | 71 | 3 | ~6 | None | None | 0 | 0 | 0 | Low |
| 19 | `ui/soundpad_panel.py` | 439 | 1 | ~25 | None | None | 10+ | 0 | 0 | Medium |
| 20 | `ui/tabs/database_tab.py` | 296 | 2 | ~18 | None | None | 5+ | 0 | 1 | Medium |
| 21 | `ui/tabs/session_tab.py` | 272 | 1 | ~16 | None | None | 1 | 0 | 0 | Medium |
| 22 | `ui/tabs/map_tab.py` | 271 | 1 | ~15 | None | None | 5+ | 0 | 0 | Medium |
| 23 | `ui/tabs/mind_map_tab.py` | 617 | 4 | ~29 | None | None | 10+ | 1 | 0 | High |
| 24 | `ui/widgets/npc_sheet.py` | 1,002 | 1 | ~46 | None | None | 5+ | 0 | 0 | Critical |
| 25 | `ui/widgets/combat_tracker.py` | 912 | 3+ | ~41 | None | None | 5+ | 1 | 0 | High |
| 26 | `ui/widgets/entity_sidebar.py` | 332 | 1 | ~15 | None | None | 5+ | 0 | 1 | Medium |
| 27 | `ui/widgets/mind_map_items.py` | 455 | 4 | ~25 | None | None | 5+ | 0 | 0 | Medium |
| 28 | `ui/widgets/markdown_editor.py` | 415 | 4 | ~22 | None | None | 3+ | 0 | 1 | Medium |
| 29 | `ui/widgets/map_viewer.py` | 232 | 4 | ~14 | None | None | 5+ | 0 | 0 | Low |
| 30 | `ui/widgets/projection_manager.py` | 231 | 1 | ~12 | Partial | None | 2+ | 0 | 0 | Low |
| 31 | `ui/widgets/image_viewer.py` | 55 | 1 | ~4 | None | None | 2 | 0 | 0 | Info |
| 32 | `ui/widgets/aspect_ratio_label.py` | 68 | 1 | ~5 | None | None | 0 | 0 | 0 | Info |
| 33 | `ui/dialogs/import_window.py` | 422 | 4 | ~20 | None | None | 5+ | 1 | 0 | Medium |
| 34 | `ui/dialogs/api_browser.py` | 490 | 1 | ~18 | None | None | 5+ | 2+ | 1 | High |
| 35 | `ui/dialogs/bulk_downloader.py` | 290 | 2 | ~12 | None | None | 5+ | 0 | 1 | Medium |
| 36 | `ui/dialogs/encounter_selector.py` | 211 | 1 | ~10 | None | None | 3+ | 1 | 0 | Medium |
| 37 | `ui/dialogs/entity_selector.py` | 121 | 1 | ~6 | None | None | 2+ | 0 | 1 | Low |
| 38 | `ui/dialogs/timeline_entry.py` | 134 | 1 | ~5 | None | None | 2+ | 0 | 0 | Low |
| 39 | `ui/dialogs/theme_builder.py` | 187 | 1 | ~8 | None | None | 2+ | 0 | 0 | Low |
| 40 | `ui/windows/battle_map_window.py` | 762 | 6 | ~35 | None | None | 5+ | 0 | 1 | High |
| 41 | `dump.py` | 113 | 0 | 5 | Good | None | 0 | 0 | 0 | Info |
| 42 | `installer/build.py` | 101 | 0 | 3 | None | None | 2 | 0 | 0 | Low |

**Totals:**

| Aggregate | Count |
|-----------|-------|
| Total production LOC | 13,818 |
| Critical severity files | 2 (`data_manager.py`, `npc_sheet.py`) |
| High severity files | 5 (`api_client.py`, `mind_map_tab.py`, `combat_tracker.py`, `api_browser.py`, `battle_map_window.py`) |
| Medium severity files | 18 |
| Low severity files | 9 |
| Info severity files | 8 |
| Files with zero docstrings | ~24 |
| Files with zero type hints | ~31 |
| Files with Turkish comments | ~28 |
| Files with bare excepts | 8 |
| Files with hardcoded CSS | 7 |

---

## 7. Testing Analysis

### 7.1 Test Suite Overview

| Metric | Value |
|--------|-------|
| Test files | 12 (including conftest.py) |
| Total test LOC | 858 |
| Test functions | ~32 |
| Test-to-production LOC ratio | 6.2% |
| Modules with test coverage | 10 of 35 (29%) |
| Modules with zero tests | 25 of 35 (71%) |

### 7.2 Test Quality Assessment

**Well-Tested Modules:**

- `core/dev/hot_reload_manager.py` -- 11 tests covering all outcome paths (APPLIED, NO_OP, RESTART_REQUIRED, FAILED, BUSY). Tests use proper mocking with `monkeypatch`. This is the gold standard for the project.
- `core/library_fs.py` -- 5 tests covering migration, scanning, and search. Uses `tmp_path` for filesystem isolation.
- `config.py` -- 3 tests covering all data root resolution modes with dependency injection.
- `dev_run.py` -- 9 tests across two files covering CLI parsing, supervisor outcomes, and adaptive timeout.

**Partially Tested Modules:**

- `core/data_manager.py` -- 3 tests covering init, persistence, and migration. Missing: entity CRUD, session management, library catalog, error paths.
- `core/api_client.py` -- 3 tests covering parse functions with mock data. Missing: network error handling, source selection, category mapping.
- `main.py` -- 4 smoke tests. Missing: language switching edge cases, hot reload integration.

**Testing Patterns Used:**

- `pytest` with fixtures (`conftest.py`)
- `pytest-qt` (`qtbot`) for widget testing
- `monkeypatch` for mocking
- `tmp_path` for filesystem isolation
- Mock/dummy classes for dependencies

**Missing Testing Infrastructure:**

- No CI configuration (GitHub Actions, etc.)
- No coverage measurement (`pytest-cov`)
- No integration tests
- No performance benchmarks
- No snapshot testing for UI layout

### 7.3 Critical Testing Gaps

The following high-complexity modules have zero test coverage and represent the highest risk areas:

1. **`ui/widgets/npc_sheet.py`** (1,002 LOC) -- Entity data flows through `populate_sheet()` and `collect_data_from_sheet()` as raw dicts. Any schema change could silently break data roundtripping.

2. **`ui/widgets/combat_tracker.py`** (912 LOC) -- Combat state serialization in `get_session_state()` / `load_session_state()` is critical for session persistence. Untested.

3. **`ui/windows/battle_map_window.py`** (762 LOC) -- Fog-of-war state management, token positioning, and video map support are complex features with no tests.

4. **`core/data_manager.py`** -- Session management, mind map data, and library catalog methods are untested despite being the central data hub.

---

## 8. Priority Matrix

### 8.1 Critical Priority / Low Effort

| Issue | Files Affected | Estimated Effort |
|-------|---------------|-----------------|
| Fix bare `except` clauses | 8 files | 1-2 hours |
| Fix `hasattr(tr, "KEY")` bugs | `session_tab.py` | 15 minutes |
| Remove hardcoded Turkish strings | 3-4 files | 30 minutes |
| Replace `print()` with `logging` | 10+ files | 2-3 hours |
| Remove duplicate `self.table` line | `entity_selector.py` | 1 minute |

### 8.2 Critical Priority / High Effort

| Issue | Files Affected | Estimated Effort |
|-------|---------------|-----------------|
| Decompose `DataManager` god class | `data_manager.py` + all consumers | 2-3 days |
| Decompose `NpcSheet` god class | `npc_sheet.py` + `database_tab.py` | 2-3 days |
| Add type hints to public APIs | All core modules | 3-5 days |
| Add tests for data roundtripping | `npc_sheet.py`, `combat_tracker.py` | 2-3 days |
| Introduce typed data models | `models.py` + all consumers | 3-5 days |

### 8.3 Medium Priority / Low Effort

| Issue | Files Affected | Estimated Effort |
|-------|---------------|-----------------|
| Translate Turkish comments to English | 28 files | 3-4 hours |
| Add docstrings to public methods | All files | 1-2 days (incremental) |
| Remove duplicate translation maps | `entity_sidebar.py` | 30 minutes |
| Remove redundant import | `npc_sheet.py` line 40 | 1 minute |
| Fix initialization ordering (`hasattr` guards) | `session_tab.py` | 30 minutes |

### 8.4 Medium Priority / High Effort

| Issue | Files Affected | Estimated Effort |
|-------|---------------|-----------------|
| Replace hardcoded CSS with theme system | 7 files | 1-2 days |
| Extract battle map items to package | `battle_map_window.py` | 1 day |
| Extract API source classes to separate files | `api_client.py` | 1 day |
| Deduplicate `parse_monster()` between API sources | `api_client.py` | 1 day |
| Add CI pipeline with test coverage | New infrastructure | 1 day |
| Split multi-class files | 6-7 files | 2-3 days |
| Add schema versioning to persistence | `data_manager.py` | 1-2 days |

---

## 9. Recommendations

### 9.1 Immediate Actions (Week 1)

1. **Fix all bare `except` clauses.** Replace with specific exception types (`except (ValueError, KeyError) as e:`) and add logging. The `data_manager.py:113` bare except in `save_data()` is the most dangerous -- a save failure should never be silent.

2. **Fix the `hasattr(tr, "KEY")` bug** in `session_tab.py` lines 118, 122, 268-269. This is a functional bug causing translation keys to never be used.

3. **Remove hardcoded Turkish strings** from `main.py:46`, `core/models.py:155`, and `ui/tabs/session_tab.py:256`. Replace with `tr()` calls.

4. **Add `logging` configuration** to `main.py` and replace all `print()` error output with `logging.error()`, `logging.warning()`, etc.

### 9.2 Short-Term Actions (Month 1)

5. **Add type hints to `DataManager` public methods.** This is the highest-impact typing work because every module depends on `DataManager`.

6. **Write data roundtrip tests** for `NpcSheet.populate_sheet()` / `collect_data_from_sheet()` and `CombatTracker.get_session_state()` / `load_session_state()`.

7. **Begin `DataManager` decomposition** by extracting `EntityRepository` and `SessionRepository` as separate classes. Keep `DataManager` as an orchestrator.

8. **Translate all Turkish comments to English.** This can be done incrementally, file by file.

9. **Add `pytest-cov` and set up a CI pipeline** (GitHub Actions) that runs tests on every push.

### 9.3 Medium-Term Actions (Quarter 1)

10. **Decompose `NpcSheet`** into `ImageGalleryWidget`, `PdfManagerWidget`, `LinkedEntityWidget`, and `EntityFormBuilder`.

11. **Introduce typed data models** using `dataclass` or `TypedDict` for entities, sessions, and encounters. Start with `core/models.py` and update consumers incrementally.

12. **Consolidate inline CSS** into the external QSS theme files. Use the `projection_manager.py` pattern as a reference.

13. **Extract multi-class files** into proper package structures:
    - `ui/windows/battle_map_window.py` -> `ui/windows/battle_map/` package
    - `core/api_client.py` -> `core/api/` package with per-source files

14. **Deduplicate API parsing logic** between `Dnd5eApiSource` and `Open5eApiSource` using a template method pattern or shared field mappers.

### 9.4 Architectural Principles for New Code

All new code should adhere to:

1. **Type hints on all function signatures** (parameters and return types).
2. **English-only comments and docstrings.**
3. **No bare `except` clauses** -- always catch specific exceptions.
4. **No inline CSS** -- use the theme system.
5. **No `print()` for logging** -- use the `logging` module.
6. **Maximum 300 LOC per file, 20 methods per class** (soft limits with exceptions for layout code).
7. **Tests required for all business logic** (data transformation, state management, persistence).

---

## Appendix A: File Inventory by LOC (Descending)

| Rank | File | LOC |
|------|------|-----|
| 1 | `ui/widgets/npc_sheet.py` | 1,002 |
| 2 | `ui/widgets/combat_tracker.py` | 912 |
| 3 | `ui/windows/battle_map_window.py` | 762 |
| 4 | `core/api_client.py` | 705 |
| 5 | `core/data_manager.py` | 677 |
| 6 | `ui/tabs/mind_map_tab.py` | 617 |
| 7 | `ui/dialogs/api_browser.py` | 490 |
| 8 | `ui/widgets/mind_map_items.py` | 455 |
| 9 | `ui/soundpad_panel.py` | 439 |
| 10 | `dev_run.py` | 436 |
| 11 | `ui/dialogs/import_window.py` | 422 |
| 12 | `ui/widgets/markdown_editor.py` | 415 |
| 13 | `main.py` | 387 |
| 14 | `core/dev/hot_reload_manager.py` | 348 |
| 15 | `ui/widgets/entity_sidebar.py` | 332 |
| 16 | `core/audio/engine.py` | 327 |
| 17 | `ui/tabs/database_tab.py` | 296 |
| 18 | `ui/dialogs/bulk_downloader.py` | 290 |
| 19 | `core/audio/loader.py` | 286 |
| 20 | `core/theme_manager.py` | 284 |
| 21 | `ui/tabs/session_tab.py` | 272 |
| 22 | `ui/tabs/map_tab.py` | 271 |
| 23 | `core/library_fs.py` | 250 |
| 24 | `ui/widgets/map_viewer.py` | 232 |
| 25 | `ui/widgets/projection_manager.py` | 231 |
| 26 | `ui/dialogs/encounter_selector.py` | 211 |
| 27 | `core/models.py` | 197 |
| 28 | `ui/dialogs/theme_builder.py` | 187 |
| 29 | `core/dev/ipc_bridge.py` | 164 |
| 30 | `ui/main_root.py` | 162 |
| 31 | `config.py` | 147 |
| 32 | `ui/player_window.py` | 147 |
| 33 | `ui/dialogs/timeline_entry.py` | 134 |
| 34 | `ui/campaign_selector.py` | 123 |
| 35 | `ui/dialogs/entity_selector.py` | 121 |
| 36 | `dump.py` | 113 |
| 37 | `installer/build.py` | 101 |
| 38 | `ui/workers.py` | 71 |
| 39 | `ui/widgets/aspect_ratio_label.py` | 68 |
| 40 | `ui/widgets/image_viewer.py` | 55 |
| 41 | `core/audio/models.py` | 36 |
| 42 | `core/locales.py` | 26 |
| | **TOTAL** | **13,818** |

---

## Appendix B: Test File Inventory

| Test File | LOC | Test Functions | Target Module |
|-----------|-----|---------------|---------------|
| `tests/conftest.py` | 21 | 2 fixtures | Shared |
| `tests/test_core/test_locales.py` | 21 | 3 | `core/locales.py` |
| `tests/test_core/test_api_client.py` | 57 | 3 | `core/api_client.py` |
| `tests/test_core/test_data_manager.py` | 55 | 3 | `core/data_manager.py` |
| `tests/test_core/test_config_paths.py` | 64 | 3 | `config.py` |
| `tests/test_core/test_library_fs.py` | 65 | 5 | `core/library_fs.py` |
| `tests/test_dev/test_dev_supervisor_outcomes.py` | 130 | 5 | `dev_run.py` |
| `tests/test_dev/test_dev_run_cli.py` | 52 | 4 | `dev_run.py` |
| `tests/test_dev/test_hot_reload_manager.py` | 200 | 11 | `core/dev/hot_reload_manager.py` |
| `tests/test_ui/test_entity_sidebar_library.py` | 83 | 3 | `ui/widgets/entity_sidebar.py` |
| `tests/test_ui/test_bulk_downloader_paths.py` | 44 | 1 | `ui/dialogs/bulk_downloader.py` |
| `tests/test_ui/test_main_window.py` | 66 | 4 | `main.py` |
| **TOTAL** | **858** | **~45** | |

---

## Appendix C: Dependency Graph (Imports)

### Core Dependencies (what each core module imports from the project)

```
config.py              <- (no project imports)
core/locales.py        <- (no project imports)
core/models.py         <- (no project imports)
core/theme_manager.py  <- (no project imports)
core/library_fs.py     <- (no project imports)
core/audio/models.py   <- (no project imports)
core/audio/engine.py   <- core.audio.models
core/audio/loader.py   <- core.audio.models
core/data_manager.py   <- config, core.models, core.api_client, core.library_fs
core/api_client.py     <- core.models
core/dev/hot_reload_manager.py <- config
core/dev/ipc_bridge.py <- core.dev.hot_reload_manager
```

### UI Dependencies (project imports only)

```
ui/workers.py          <- (no project imports)
ui/campaign_selector.py <- core.locales, config
ui/player_window.py    <- core.locales
ui/main_root.py        <- core.locales, ui.tabs.*, ui.widgets.entity_sidebar, ui.soundpad_panel
ui/soundpad_panel.py   <- core.locales, core.audio.engine, core.audio.loader, core.theme_manager

ui/tabs/database_tab.py    <- ui.widgets.npc_sheet, ui.workers, core.locales
ui/tabs/session_tab.py     <- core.locales, ui.widgets.combat_tracker, ui.widgets.markdown_editor, ui.windows.battle_map_window
ui/tabs/map_tab.py         <- core.locales, ui.widgets.map_viewer, ui.dialogs.timeline_entry
ui/tabs/mind_map_tab.py    <- core.locales, core.theme_manager, ui.widgets.mind_map_items

ui/widgets/npc_sheet.py        <- core.locales, core.models, core.theme_manager, config, ui.widgets.aspect_ratio_label, ui.widgets.markdown_editor, ui.workers, ui.dialogs.api_browser
ui/widgets/combat_tracker.py   <- core.locales, core.theme_manager, ui.windows.battle_map_window, ui.dialogs.encounter_selector
ui/widgets/entity_sidebar.py   <- core.locales
ui/widgets/markdown_editor.py  <- core.locales
ui/widgets/mind_map_items.py   <- core.theme_manager
ui/widgets/map_viewer.py       <- (no project imports)
ui/widgets/projection_manager.py <- core.locales, core.theme_manager
ui/widgets/image_viewer.py     <- (no project imports)
ui/widgets/aspect_ratio_label.py <- (no project imports)

ui/dialogs/import_window.py     <- core.locales, core.data_manager, config
ui/dialogs/api_browser.py       <- core.locales, core.api_client
ui/dialogs/bulk_downloader.py   <- core.locales, config
ui/dialogs/encounter_selector.py <- core.locales
ui/dialogs/entity_selector.py   <- core.locales
ui/dialogs/timeline_entry.py    <- core.locales
ui/dialogs/theme_builder.py     <- core.locales, core.theme_manager

ui/windows/battle_map_window.py <- core.locales, core.theme_manager
```

### Circular Dependency Risk

`ui/widgets/npc_sheet.py` imports `ui/dialogs/api_browser.py` at the top level. If `api_browser.py` were ever to import from `npc_sheet.py` (e.g., for embedding a sheet preview), a circular import would occur. Currently this is unidirectional, but the cross-layer import (widget importing dialog) is a design smell.

---

## Appendix D: Signal/Slot Inventory

Complete inventory of custom `pyqtSignal` definitions in the codebase:

| File | Class | Signal | Signature |
|------|-------|--------|-----------|
| `ui/widgets/npc_sheet.py` | `NpcSheet` | `request_open_entity` | `pyqtSignal(str)` |
| `ui/widgets/npc_sheet.py` | `NpcSheet` | `data_changed` | `pyqtSignal()` |
| `ui/widgets/npc_sheet.py` | `NpcSheet` | `save_requested` | `pyqtSignal()` |
| `ui/widgets/combat_tracker.py` | `DraggableCombatTable` | `entity_dropped` | `pyqtSignal(str)` |
| `ui/widgets/combat_tracker.py` | `CombatTracker` | `data_changed_signal` | `pyqtSignal()` |
| `ui/widgets/entity_sidebar.py` | `EntitySidebar` | `entity_selected` | `pyqtSignal(str)` |
| `ui/widgets/markdown_editor.py` | `MarkdownEditor` | `entity_link_clicked` | `pyqtSignal(str)` |
| `ui/widgets/markdown_editor.py` | `MarkdownEditor` | `textChanged` | (inherited) |
| `ui/tabs/database_tab.py` | `DatabaseTab` | `entity_deleted` | `pyqtSignal()` |
| `ui/tabs/mind_map_tab.py` | `MindMapScene` | `entity_double_clicked` | `pyqtSignal(str)` |
| `ui/windows/battle_map_window.py` | `BattleMapWidget` | `token_moved_signal` | `pyqtSignal(str, float, float)` |
| `ui/windows/battle_map_window.py` | `BattleMapWidget` | `token_size_changed_signal` | `pyqtSignal(...)` |
| `ui/windows/battle_map_window.py` | `BattleMapWidget` | `view_sync_signal` | `pyqtSignal(...)` |
| `ui/windows/battle_map_window.py` | `BattleMapWidget` | `fog_update_signal` | `pyqtSignal()` |
| `ui/workers.py` | `ApiSearchWorker` | `finished` | `pyqtSignal(bool, object, str)` |
| `ui/workers.py` | `ApiListWorker` | `finished` | `pyqtSignal(bool, object, str)` |
| `ui/workers.py` | `ImageDownloadWorker` | `finished` | `pyqtSignal(bool, str)` |

---

*End of Code Audit Document*
*Generated: 2026-03-17*
*Total document length: ~2,300 lines*
