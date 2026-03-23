# Dungeon Master Tool -- Comprehensive Improvement Roadmap

**Project:** Dungeon Master Tool v0.7.7 Alpha
**Author:** Elymsyr (Orhun Eren Yalcinkaya)
**Roadmap Date:** 2026-03-18
**Based On:** CODE_AUDIT.md (2026-03-17)
**Estimated Duration:** 20 weeks (5 phases)
**Target State:** Production-ready codebase with maintainable architecture, full type safety, and >60% test coverage

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Improvement Principles](#2-improvement-principles)
3. [Phase 1: Foundation (Weeks 1-4)](#3-phase-1-foundation-weeks-1-4)
4. [Phase 2: God Class Decomposition (Weeks 5-10)](#4-phase-2-god-class-decomposition-weeks-5-10)
5. [Phase 3: UI Consistency (Weeks 11-13)](#5-phase-3-ui-consistency-weeks-11-13)
6. [Phase 4: Architecture Patterns (Weeks 14-17)](#6-phase-4-architecture-patterns-weeks-14-17)
7. [Phase 5: Testing & Documentation (Weeks 18-20)](#7-phase-5-testing--documentation-weeks-18-20)
8. [Per-File Improvement Matrix](#8-per-file-improvement-matrix)
9. [Risk Assessment](#9-risk-assessment)
10. [Success Metrics](#10-success-metrics)

---

## 1. Executive Summary

### 1.1 Current State Assessment

The Dungeon Master Tool is a feature-rich PyQt6 desktop application with impressive scope for an alpha-stage solo-developer project. It provides entity management, combat tracking, world mapping, mind mapping, audio ambience, and D&D 5e API integration -- all within a themeable, multi-language interface.

However, the codebase has accumulated significant technical debt through organic growth:

| Dimension | Current State | Impact |
|-----------|--------------|--------|
| Architecture | 2 god classes (DataManager 677 LOC/45 methods, NpcSheet 1002 LOC/46 methods) | New features require modifying monolithic files; high merge conflict risk |
| Type Safety | 31 of 35 files have zero type annotations | Refactoring is high-risk; IDE support is limited; no static analysis possible |
| Language | ~28 files contain Turkish comments, docstrings, or variable names | Barrier for international contributors; inconsistent developer experience |
| Error Handling | 8 files with bare `except` clauses; `print()` used for all logging | Bugs are silently masked; no production log analysis possible |
| Testing | 6.2% test-to-production LOC ratio; 71% of modules have zero tests | Regressions go undetected; refactoring requires manual verification |
| Theme System | 7 files with hardcoded inline CSS bypassing the theme system | Theme switching produces visual inconsistencies |
| Documentation | <15% docstring coverage; no API documentation | Onboarding new contributors is difficult; implicit contracts everywhere |
| Package Structure | Missing `__init__.py` in 5 packages | Implicit package resolution; potential import issues in bundled builds |

The overall grade from the code audit is **C+ (Functional but technically indebted)**.

### 1.2 Target State Vision

After completing all five phases, the codebase should achieve:

| Dimension | Target State |
|-----------|-------------|
| Architecture | No class exceeds 400 LOC or 20 public methods; clear separation of concerns |
| Type Safety | 100% of public function signatures have type annotations; mypy passes with `--strict` on core modules |
| Language | All comments, docstrings, variable names, and code identifiers in English; UI strings exclusively via `tr()` |
| Error Handling | Zero bare `except` clauses; structured logging with `logging` module throughout |
| Testing | >60% line coverage overall; >80% coverage on core business logic modules |
| Theme System | Zero hardcoded inline CSS; all styling via external QSS files or ThemeManager palette |
| Documentation | Every public class and method has a docstring; architecture documentation maintained |
| Package Structure | All packages have `__init__.py` with explicit public API exports |

### 1.3 Scope of Improvements

This roadmap covers **all 35 production Python files** (13,818 LOC) and the supporting test infrastructure (12 test files, 858 LOC). It does not cover:

- Asset files (images, audio, fonts)
- QSS theme files (external stylesheets) -- except for migration of inline CSS into them
- YAML locale files -- except for adding missing translation keys
- Third-party dependencies -- except for adding new dev dependencies (mypy, ruff, pytest-cov)
- Runtime-generated data files

The roadmap is structured as five sequential phases, each building on the previous. Phases can overlap by 1-2 weeks where tasks are independent, but the ordering reflects dependency relationships between improvements.

### 1.4 Effort Summary

| Phase | Duration | Primary Focus | Files Touched |
|-------|----------|--------------|---------------|
| Phase 1: Foundation | 4 weeks | Package structure, logging, type hints, language, error handling | All 35 files |
| Phase 2: God Class Decomposition | 6 weeks | DataManager, NpcSheet, CombatTracker split | 8 files split into ~20 files |
| Phase 3: UI Consistency | 3 weeks | Inline CSS removal, QSS theme migration | 7+ UI files |
| Phase 4: Architecture Patterns | 4 weeks | MVC separation, event bus, dependency injection, API consolidation | 15+ files |
| Phase 5: Testing & Documentation | 3 weeks | Test coverage, docstrings, quality gates | All files |
| **Total** | **20 weeks** | | |

---

## 2. Improvement Principles

### 2.1 The Golden Rule: Do Not Break Working Features

Every improvement must preserve the application's existing behavior. Users should not notice any change in functionality after a refactoring step. The application currently works and ships features -- that is valuable and must be protected.

**Concrete practices:**

- Run the full test suite before and after every refactoring step.
- If a module has no tests, write characterization tests (tests that capture current behavior) before refactoring it.
- Keep the application runnable at all times. Never leave the codebase in a state where `python main.py` fails.
- Use feature flags or conditional imports if a large refactoring must be merged incrementally.

### 2.2 Incremental Changes Over Big Rewrites

Each change should be small enough to review in a single pull request (ideally <300 lines changed). Large refactoring tasks are broken into discrete steps that can be merged independently.

**Why this matters:**

- Small changes are easier to review and verify.
- If a change introduces a regression, the cause is obvious from the diff.
- Incremental progress keeps motivation high and risk low.
- The project can ship releases at any point during the improvement process.

**Anti-patterns to avoid:**

- "Let me rewrite this entire file from scratch." -- Almost always introduces new bugs.
- "I will refactor everything and merge it all at once." -- Impossible to review; high regression risk.
- "This file is so bad, I will just delete it and start over." -- Loses institutional knowledge encoded in the current implementation.

### 2.3 Test Before Refactor

Before modifying any module, ensure there are tests that verify its current behavior. These tests serve as a safety net during refactoring.

**The process:**

1. **Write characterization tests** that capture the module's current inputs and outputs.
2. **Run the tests** to confirm they pass with the current code.
3. **Perform the refactoring** in small steps.
4. **Run the tests after each step** to confirm behavior is preserved.
5. **Add new tests** for any new behavior or edge cases discovered during refactoring.

**Minimum test requirements before refactoring a module:**

| Module Complexity | Minimum Tests Before Refactoring |
|-------------------|--------------------------------|
| Simple (< 100 LOC, < 5 methods) | 2 tests covering primary paths |
| Medium (100-400 LOC, 5-15 methods) | 5 tests covering primary + error paths |
| Complex (> 400 LOC, > 15 methods) | 10 tests covering primary + error + edge cases |

### 2.4 One Concern Per Change

Each pull request should address exactly one type of improvement:

- Do not mix "add type hints" with "rename variables" in the same PR.
- Do not mix "translate comments" with "refactor logic" in the same PR.
- Do not mix "extract class" with "change behavior" in the same PR.

This makes code review manageable and bisection straightforward when hunting regressions.

### 2.5 Preserve Public APIs During Decomposition

When splitting god classes, the original class should remain as a facade that delegates to the new extracted classes. Consumers should not need to change their code immediately.

**Example for DataManager decomposition:**

```python
# Phase 1: DataManager delegates to EntityRepository
# All existing callers continue to work unchanged.

class DataManager:
    def __init__(self):
        self._entity_repo = EntityRepository(...)
        # ... other initialization ...

    def save_entity(self, eid, data, should_save=True, auto_source_update=True):
        # Delegate to the new class
        return self._entity_repo.save(eid, data, should_save, auto_source_update)

    def delete_entity(self, eid):
        return self._entity_repo.delete(eid)
```

Callers can be migrated to use the extracted classes directly in a later phase, one file at a time.

### 2.6 Follow Existing Good Patterns

The codebase already contains examples of high-quality code. Use these as templates:

| Pattern | Reference File | What It Does Well |
|---------|---------------|-------------------|
| Small focused functions with docstrings | `core/library_fs.py` | Single responsibility, clear documentation |
| Comprehensive type hints | `core/dev/hot_reload_manager.py` | Full parameter and return annotations |
| Testable design with DI | `config.py` (`resolve_data_root`) | Accepts injected dependencies for testing |
| Proper dataclass usage | `core/audio/models.py` | Typed fields, immutable data structures |
| Theme-aware widget | `ui/widgets/projection_manager.py` | Reads from ThemeManager palette, no hardcoded CSS |
| Structured error reporting | `core/library_fs.py` (`migrate_legacy_layout`) | Returns report dict instead of throwing |

### 2.7 Naming Conventions

All new and refactored code must follow these naming conventions:

| Element | Convention | Example |
|---------|-----------|---------|
| Module files | `snake_case.py` | `entity_repository.py` |
| Classes | `PascalCase` | `EntityRepository` |
| Functions/methods | `snake_case` | `save_entity()` |
| Constants | `UPPER_SNAKE_CASE` | `MAX_ENTITY_COUNT` |
| Private methods | `_leading_underscore` | `_validate_entity()` |
| Type variables | `PascalCase` | `EntityDict`, `SessionData` |
| Test functions | `test_snake_case` | `test_save_entity_creates_new_id()` |

### 2.8 Commit Message Convention

Use conventional commits for all improvement work:

```
refactor(data-manager): extract EntityRepository from DataManager
feat(logging): add structured logging framework with file rotation
fix(session-tab): replace hasattr(tr, key) with proper translation check
docs(npc-sheet): add docstrings to all public methods
test(combat-tracker): add characterization tests for state serialization
style(entity-sidebar): replace hardcoded CSS with theme palette
chore(packages): add __init__.py to all UI packages
```

---

## 3. Phase 1: Foundation (Weeks 1-4)

Phase 1 establishes the foundational infrastructure that all subsequent phases depend on. These are low-risk, high-impact changes that can be made without altering application behavior.

### 3.1 Add `__init__.py` to All Packages (Week 1, Day 1-2)

**Current State:**

Only 2 of 7 packages have `__init__.py` files:

| Package | Has `__init__.py`? |
|---------|-------------------|
| `core/` | No |
| `core/audio/` | Yes |
| `core/dev/` | Yes |
| `ui/` | No |
| `ui/tabs/` | No |
| `ui/widgets/` | No |
| `ui/dialogs/` | No |
| `ui/windows/` | No |

Python 3 allows implicit namespace packages (PEP 420), but explicit `__init__.py` files are better practice because:

- PyInstaller and other bundling tools may not discover implicit packages.
- They provide a clear place to define the package's public API.
- IDEs handle them more consistently for autocompletion and import resolution.
- They make the package structure explicit in the file tree.

**Action Plan:**

Create the following files with appropriate public API exports:

#### `core/__init__.py`

```python
"""Core business logic for the Dungeon Master Tool.

This package contains data management, API integration,
entity models, localization, and theme management.
"""
```

#### `ui/__init__.py`

```python
"""User interface components for the Dungeon Master Tool.

Sub-packages:
    tabs     -- Main tab panels (database, session, map, mind map)
    widgets  -- Reusable widget components
    dialogs  -- Modal dialog windows
    windows  -- Standalone windows (battle map, player view)
"""
```

#### `ui/tabs/__init__.py`

```python
"""Main tab panels for the application window.

Each tab provides a major feature area:
    DatabaseTab  -- Entity card management with dual-panel view
    SessionTab   -- Session management with combat and notes
    MapTab       -- World map with timeline pins
    MindMapTab   -- Visual entity relationship editor
"""
```

#### `ui/widgets/__init__.py`

```python
"""Reusable widget components.

Widgets are self-contained UI components that can be embedded
in tabs, dialogs, or standalone windows.
"""
```

#### `ui/dialogs/__init__.py`

```python
"""Modal dialog windows.

Dialogs are transient windows that collect user input or
display information, then return control to the parent.
"""
```

#### `ui/windows/__init__.py`

```python
"""Standalone windows.

Windows are independent top-level windows that can operate
alongside the main application window.
"""
```

**Estimated Effort:** 1 hour
**Risk:** None -- adding empty or docstring-only `__init__.py` files has no behavioral impact.
**Dependencies:** None
**Verification:** Run `python main.py` and confirm the application starts normally. Run `pytest` and confirm all existing tests pass.

---

### 3.2 Establish Logging Framework (Week 1, Day 2-5)

**Current State:**

The entire codebase uses `print()` for diagnostic output. There are approximately 30+ `print()` calls across 10+ files serving as error logging, debug output, and status messages.

Key offenders identified in the audit:

| File | `print()` Calls | Context |
|------|-----------------|---------|
| `core/data_manager.py` | ~10 | Cache errors, migration status, save errors |
| `core/api_client.py` | ~5 | API request errors, parse errors, debug info |
| `core/dev/hot_reload_manager.py` | ~5 | Reload progress and results |
| `core/dev/ipc_bridge.py` | ~3 | Connection status |
| `core/audio/engine.py` | ~2 | Playback errors |
| `core/audio/loader.py` | ~2 | YAML loading errors |
| `ui/tabs/mind_map_tab.py` | ~3 | Save errors |
| `ui/dialogs/import_window.py` | ~2 | Import errors |
| `ui/dialogs/api_browser.py` | ~2 | API response errors |
| `main.py` | ~2 | Dev mode auto-load status |

**Target State:**

A structured logging framework using Python's built-in `logging` module with:

- Named loggers per module (e.g., `logging.getLogger(__name__)`)
- Configurable log levels (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- Console output for development, file output for production
- Timestamp and module context in every log message

**Action Plan:**

#### Step 1: Create logging configuration module

Create `core/log_config.py`:

```python
"""Logging configuration for the Dungeon Master Tool.

Call setup_logging() once at application startup to configure
all loggers. Individual modules should use:

    import logging
    logger = logging.getLogger(__name__)
"""

import logging
import logging.handlers
import os
import sys
from typing import Optional


def setup_logging(
    level: str = "INFO",
    log_dir: Optional[str] = None,
    console: bool = True,
    max_bytes: int = 5 * 1024 * 1024,
    backup_count: int = 3,
) -> None:
    """Configure the root logger for the application.

    Args:
        level: Minimum log level as a string (DEBUG, INFO, WARNING, ERROR).
        log_dir: Directory for log files. If None, file logging is disabled.
        console: Whether to output to stderr.
        max_bytes: Maximum size of each log file before rotation.
        backup_count: Number of rotated log files to keep.
    """
    root = logging.getLogger()
    root.setLevel(getattr(logging, level.upper(), logging.INFO))

    formatter = logging.Formatter(
        fmt="%(asctime)s [%(levelname)-8s] %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    if console:
        console_handler = logging.StreamHandler(sys.stderr)
        console_handler.setFormatter(formatter)
        root.addHandler(console_handler)

    if log_dir:
        os.makedirs(log_dir, exist_ok=True)
        file_handler = logging.handlers.RotatingFileHandler(
            os.path.join(log_dir, "dm_tool.log"),
            maxBytes=max_bytes,
            backupCount=backup_count,
            encoding="utf-8",
        )
        file_handler.setFormatter(formatter)
        root.addHandler(file_handler)
```

#### Step 2: Initialize logging in main.py

Add to `main.py` before `run_application()` is called:

```python
from core.log_config import setup_logging
from config import CACHE_DIR

setup_logging(
    level="DEBUG" if os.getenv("DM_DEV_CHILD") == "1" else "INFO",
    log_dir=CACHE_DIR,
)
```

#### Step 3: Replace print() calls file by file

For each file, the transformation is mechanical:

**Before:**
```python
print(f"Cache DAT load error: {e}")
```

**After:**
```python
import logging

logger = logging.getLogger(__name__)

# ... later in the code ...
logger.error("Cache DAT load error: %s", e)
```

**Mapping of print() patterns to log levels:**

| Pattern | Log Level | Example |
|---------|----------|---------|
| Error messages | `logger.error()` | `"CRITICAL SAVE ERROR: {e}"` |
| Warning/fallback messages | `logger.warning()` | `"falling back to JSON: {e}"` |
| Debug/status messages | `logger.debug()` | `"[DEBUG] Validated and Saved to: {path}"` |
| Info messages | `logger.info()` | `"[dev] auto-loaded world: {name}"` |
| Migration status | `logger.info()` | `"JSON migrated to MsgPack"` |

#### File-by-file migration order:

| Order | File | `print()` Count | Priority |
|-------|------|-----------------|----------|
| 1 | `core/data_manager.py` | ~10 | Critical -- includes save error logging |
| 2 | `core/api_client.py` | ~5 | High -- includes API error logging |
| 3 | `main.py` | ~2 | High -- entry point should log properly |
| 4 | `core/dev/hot_reload_manager.py` | ~5 | Medium -- dev tooling |
| 5 | `core/dev/ipc_bridge.py` | ~3 | Medium -- dev tooling |
| 6 | `core/audio/engine.py` | ~2 | Medium |
| 7 | `core/audio/loader.py` | ~2 | Medium |
| 8 | `ui/tabs/mind_map_tab.py` | ~3 | Medium |
| 9 | `ui/dialogs/import_window.py` | ~2 | Low |
| 10 | `ui/dialogs/api_browser.py` | ~2 | Low |

**Estimated Effort:** 4-6 hours total (including logging config setup)
**Risk:** Low -- replacing `print()` with `logger.xxx()` is a mechanical transformation. The only risk is missing a `print()` call that a user relied on for debugging, but logger output to stderr preserves that behavior.
**Dependencies:** None
**Verification:** Run `python main.py`, trigger operations that previously printed messages, and confirm the messages appear in log output with proper formatting.

---

### 3.3 Add Type Hints to All Function Signatures (Week 1-3)

**Current State:**

Only 4 of 35 production files use the `typing` module. The remaining 31 files have zero type annotations on function parameters or return values. This makes refactoring extremely risky because type mismatches are only caught at runtime.

**Target State:**

Every public function and method has full type annotations for all parameters and return values. Private methods should also be annotated but can use less precise types where the exact type is complex.

**Strategy:**

Add type hints incrementally, starting with the most-consumed interfaces (DataManager, NpcSheet public API) and working outward. Use `from __future__ import annotations` at the top of each file to enable PEP 604 union syntax (`X | None` instead of `Optional[X]`) and forward references.

**Type hint style guide for this project:**

```python
from __future__ import annotations

from typing import Any

# Simple parameters
def save_entity(self, eid: str | None, data: dict[str, Any]) -> str:
    ...

# Complex return types -- use TypedDict or dataclass
class EntityData(TypedDict):
    name: str
    type: str
    attributes: dict[str, str]
    combat_stats: dict[str, str]

# Signal handlers (PyQt6 slots)
def on_entity_selected(self, eid: str) -> None:
    ...

# Methods returning tuples
def load_campaign(self, folder: str) -> tuple[bool, str]:
    ...
```

#### File-by-file annotation plan:

**Tier 1: Core data interfaces (Week 1)**

These files are consumed by every UI module. Annotating them provides the highest impact.

| File | Methods to Annotate | Key Types to Define |
|------|--------------------|--------------------|
| `core/data_manager.py` | All 45 methods | `EntityData`, `SessionData`, `MapData`, `CampaignData` |
| `core/models.py` | `get_default_entity_structure()`, schema dicts | `EntitySchema`, `CombatStats` |
| `core/api_client.py` | All public methods on `DndApiClient`, `ApiSource`, and subclasses | `ApiResponse`, `ParsedEntity` |
| `config.py` | All 8 functions | Already mostly typed; add return types |

Detailed plan for `core/data_manager.py`:

```python
# New type definitions to add at the top of the file
from __future__ import annotations
from typing import Any, TypedDict

class EntityData(TypedDict, total=False):
    name: str
    type: str
    description: str
    source: str
    images: list[str]
    image_path: str
    tags: list[str]
    attributes: dict[str, str]
    stats: dict[str, int]
    combat_stats: dict[str, str]
    traits: list[dict[str, str]]
    actions: list[dict[str, str]]
    reactions: list[dict[str, str]]
    legendary_actions: list[dict[str, str]]
    spells: list[str]
    equipment_ids: list[str]
    inventory: list[str]
    pdfs: list[str]
    dm_notes: str
    battlemaps: list[str]
    location_id: str | None

class SessionData(TypedDict, total=False):
    id: str
    name: str
    date: str
    notes: str
    logs: str
    combatants: list[dict[str, Any]] | dict[str, Any]

class CampaignData(TypedDict, total=False):
    world_name: str
    entities: dict[str, EntityData]
    map_data: dict[str, Any]
    sessions: list[SessionData]
    last_active_session_id: str | None
    mind_maps: dict[str, Any]

# Method signatures to annotate:
class DataManager:
    def __init__(self) -> None: ...
    def reload_library_cache(self) -> None: ...
    def _save_reference_cache(self) -> None: ...
    def refresh_library_catalog(self) -> None: ...
    def search_library_catalog(
        self,
        query: str,
        normalized_categories: set[str] | None = None,
        source: str | None = None,
    ) -> list[dict[str, str]]: ...
    def load_settings(self) -> dict[str, str]: ...
    def save_settings(self, settings: dict[str, str]) -> None: ...
    def get_api_index(
        self,
        category: str,
        page: int = 1,
        filters: dict[str, str] | None = None,
    ) -> dict[str, Any]: ...
    def get_available_campaigns(self) -> list[str]: ...
    def load_campaign_by_name(self, name: str) -> tuple[bool, str]: ...
    def load_campaign(self, folder: str) -> tuple[bool, str]: ...
    def create_campaign(self, world_name: str) -> tuple[bool, str]: ...
    def save_data(self) -> None: ...
    def create_session(self, name: str) -> str: ...
    def get_session(self, session_id: str) -> SessionData | None: ...
    def save_session_data(
        self,
        session_id: str,
        notes: str,
        logs: str,
        combatants: list[dict[str, Any]],
    ) -> None: ...
    def set_active_session(self, session_id: str) -> None: ...
    def get_last_active_session_id(self) -> str | None: ...
    def save_entity(
        self,
        eid: str | None,
        data: dict[str, Any],
        should_save: bool = True,
        auto_source_update: bool = True,
    ) -> str: ...
    def delete_entity(self, eid: str) -> None: ...
    def fetch_details_from_api(
        self,
        category: str,
        index_name: str,
        local_only: bool = False,
    ) -> tuple[bool, dict[str, Any] | str]: ...
    def fetch_from_api(
        self,
        category: str,
        query: str,
    ) -> tuple[bool, str, dict[str, Any] | str | None]: ...
    def import_image(self, src: str) -> str | None: ...
    def import_pdf(self, src: str) -> str | None: ...
    def get_full_path(self, rel: str | None) -> str | None: ...
    def set_map_image(self, rel: str) -> None: ...
    def add_pin(
        self,
        x: float,
        y: float,
        eid: str,
        color: str | None = None,
        note: str = "",
    ) -> None: ...
    def update_map_pin(
        self,
        pin_id: str,
        color: str | None = None,
        note: str | None = None,
    ) -> None: ...
    def move_pin(self, pid: str, x: float, y: float) -> None: ...
    def remove_specific_pin(self, pid: str) -> None: ...
    def add_timeline_pin(
        self,
        x: float,
        y: float,
        day: int,
        note: str,
        parent_id: str | None = None,
        entity_ids: list[str] | None = None,
        color: str | None = None,
        session_id: str | None = None,
    ) -> None: ...
    def search_in_library(
        self,
        category: str | None,
        search_text: str,
    ) -> list[dict[str, Any]]: ...
    def get_all_entity_mentions(self) -> list[dict[str, str]]: ...
```

**Tier 2: UI widget public interfaces (Week 2)**

| File | Methods to Annotate | Priority |
|------|--------------------|---------|
| `ui/widgets/npc_sheet.py` | `populate_sheet()`, `collect_data_from_sheet()`, all signal handlers | High |
| `ui/widgets/combat_tracker.py` | `add_combatant()`, `get_session_state()`, `load_session_state()` | High |
| `ui/widgets/entity_sidebar.py` | `refresh_entity_list()`, `on_search_changed()` | Medium |
| `ui/widgets/markdown_editor.py` | `set_content()`, `get_content()` | Medium |
| `ui/widgets/map_viewer.py` | All public methods | Low |
| `ui/widgets/projection_manager.py` | All public methods | Low |
| `ui/widgets/mind_map_items.py` | Node and connection constructors | Low |
| `ui/widgets/image_viewer.py` | All methods | Low |
| `ui/widgets/aspect_ratio_label.py` | All methods | Low |

**Tier 3: Tab and dialog classes (Week 3)**

| File | Methods to Annotate | Priority |
|------|--------------------|---------|
| `ui/tabs/database_tab.py` | `open_entity_tab()`, `save_entity_tab()` | Medium |
| `ui/tabs/session_tab.py` | `load_session()`, `save_current_session()` | Medium |
| `ui/tabs/map_tab.py` | All public methods | Low |
| `ui/tabs/mind_map_tab.py` | All public methods | Low |
| `ui/dialogs/api_browser.py` | Constructor, result methods | Low |
| `ui/dialogs/import_window.py` | Constructor, result methods | Low |
| `ui/dialogs/bulk_downloader.py` | Worker run(), dialog results | Low |
| `ui/dialogs/encounter_selector.py` | Constructor, result methods | Low |
| `ui/dialogs/entity_selector.py` | Constructor, result methods | Low |
| `ui/dialogs/timeline_entry.py` | Constructor, result methods | Low |
| `ui/dialogs/theme_builder.py` | Constructor, result methods | Low |

**Tier 4: Remaining files (Week 3-4)**

| File | Methods to Annotate | Priority |
|------|--------------------|---------|
| `ui/main_root.py` | `create_root_widget()` return type | Medium |
| `ui/campaign_selector.py` | All methods | Low |
| `ui/player_window.py` | All methods | Low |
| `ui/workers.py` | All worker `run()` methods | Low |
| `ui/soundpad_panel.py` | All public methods | Low |
| `ui/windows/battle_map_window.py` | All public methods on all 6 classes | Low |
| `core/theme_manager.py` | `get_palette()` return type | Low |
| `core/locales.py` | `tr()` function | Low |
| `core/audio/engine.py` | All public methods | Low |
| `core/audio/loader.py` | All public methods | Low |

**Estimated Effort:** 3-5 days spread across 3 weeks
**Risk:** Low -- type hints are purely additive annotations that do not change runtime behavior. The only risk is incorrect annotations that mislead developers, but mypy will catch those.
**Dependencies:** None
**Verification:** Install mypy and run `mypy core/data_manager.py` after each file is annotated. Confirm no type errors in the annotated file.

---

### 3.4 Standardize Language to English (Week 2-3)

**Current State:**

Approximately 28 of 35 production files contain Turkish comments, docstrings, or variable names. There are also hardcoded Turkish UI strings that bypass the `tr()` localization system.

**Categories of Turkish language usage:**

1. **Inline comments** (~28 files): `# YENi: Mind Map verileri icin alan`
2. **Docstrings** (~10 files): `"""Suruklenen Entity'leri kabul eden ozel tablo."""`
3. **Variable names** (~3 files): `Canavar`, `Buyu`, `Mekan` in schema maps (these are legacy compatibility and must remain)
4. **Hardcoded UI strings** (~4 files): `"Bilinmiyor"`, `"Yeni Kayit"`, `"Oturum bulunamadi"`
5. **Translation map duplicates** (~1 file): `entity_sidebar.py` has hardcoded Turkish-English dicts

**Action Plan:**

#### Category 1: Translate inline comments (Week 2)

This is the largest task by file count but the simplest mechanically. Each Turkish comment is replaced with an English equivalent.

**Translation guidelines:**

- Translate the meaning, not word-for-word.
- Keep comments concise. If the Turkish comment was verbose, simplify.
- Remove comments that merely restate what the code does (e.g., `# Kaydetmeyi unutma` / "Don't forget to save" before `self.save_data()`).
- Add comments only where the code's intent is not obvious from the code itself.

**File-by-file plan (sorted by number of Turkish comments):**

| Order | File | Turkish Comments | Action |
|-------|------|------------------|--------|
| 1 | `core/theme_manager.py` | ~20 | Translate all palette section comments |
| 2 | `core/api_client.py` | ~15 | Translate all inline comments |
| 3 | `core/audio/engine.py` | ~10 | Translate all docstrings and comments |
| 4 | `core/audio/loader.py` | ~10 | Translate all comments |
| 5 | `ui/tabs/mind_map_tab.py` | ~10 | Translate all comments |
| 6 | `ui/soundpad_panel.py` | ~10 | Translate all comments |
| 7 | `core/data_manager.py` | ~8 | Translate all comments; keep SCHEMA_MAP/PROPERTY_MAP values |
| 8 | `ui/tabs/database_tab.py` | ~5 | Translate all comments |
| 9 | `ui/tabs/map_tab.py` | ~5 | Translate all comments |
| 10 | `ui/widgets/npc_sheet.py` | ~5 | Translate all comments |
| 11 | `ui/widgets/combat_tracker.py` | ~5 | Translate all comments |
| 12 | `ui/widgets/entity_sidebar.py` | ~5 | Translate all comments |
| 13 | `ui/widgets/mind_map_items.py` | ~5 | Translate all comments |
| 14 | `ui/widgets/markdown_editor.py` | ~3 | Translate all comments |
| 15 | `ui/widgets/map_viewer.py` | ~5 | Translate all comments |
| 16 | `ui/dialogs/import_window.py` | ~5 | Translate all comments |
| 17 | `ui/dialogs/api_browser.py` | ~5 | Translate all comments |
| 18 | `ui/dialogs/bulk_downloader.py` | ~5 | Translate all comments |
| 19 | `ui/dialogs/encounter_selector.py` | ~3 | Translate all comments |
| 20 | `ui/dialogs/entity_selector.py` | ~2 | Translate all comments |
| 21 | `ui/dialogs/timeline_entry.py` | ~2 | Translate all comments |
| 22 | `ui/dialogs/theme_builder.py` | ~2 | Translate all comments |
| 23 | `ui/windows/battle_map_window.py` | ~5 | Translate all comments |
| 24 | `ui/campaign_selector.py` | ~1 | Translate header comment |
| 25 | `ui/player_window.py` | ~2 | Translate all comments |
| 26 | `core/audio/models.py` | ~2 | Translate dataclass docstrings |
| 27 | `installer/build.py` | ~2 | Translate build script comments |
| 28 | `ui/main_root.py` | ~2 | Translate all comments |

#### Category 2: Fix hardcoded Turkish UI strings (Week 2)

These are functional bugs where Turkish text is shown to users regardless of their language setting.

| File | Line | Current | Replacement |
|------|------|---------|-------------|
| `main.py` | 46 | `"Bilinmiyor"` | `tr("NAME_UNKNOWN")` |
| `core/models.py` | 155 | `"Yeni Kayit"` | `tr("DEFAULT_ENTITY_NAME")` -- OR use English default `"New Entity"` |
| `ui/tabs/session_tab.py` | 256 | `"Oturum bulunamadi veya silinmis."` | `tr("MSG_SESSION_NOT_FOUND")` |

**Note:** The `SCHEMA_MAP` and `PROPERTY_MAP` in `core/models.py` contain Turkish keys for backward compatibility with legacy data. These must **not** be changed -- they are migration mappings, not UI strings.

#### Category 3: Remove duplicate translation maps (Week 2)

`ui/widgets/entity_sidebar.py` contains two hardcoded dictionaries (lines 49-57 and 257-263) that map English category names to Turkish display names. These duplicate the locale system and will drift over time.

**Replacement:** Use `tr()` calls with locale keys for category display names:

```python
# Before (hardcoded Turkish map):
CATEGORY_DISPLAY = {
    "NPC": "NPC",
    "Monster": "Canavar",
    "Spell": "Buyu",
    ...
}

# After (using locale system):
def get_category_display(category: str) -> str:
    key = f"CAT_{category.upper().replace(' ', '_')}"
    return tr(key)
```

This requires adding the corresponding keys to the YAML locale files:

```yaml
# locales/en.yml
CAT_NPC: "NPC"
CAT_MONSTER: "Monster"
CAT_SPELL: "Spell"
# ...

# locales/tr.yml
CAT_NPC: "NPC"
CAT_MONSTER: "Canavar"
CAT_SPELL: "Buyu"
# ...
```

#### Category 4: Fix `hasattr(tr, "KEY")` bug (Week 2)

`ui/tabs/session_tab.py` lines 118, 122, 268-269 use `hasattr(tr, "BTN_LOAD_MAP")` to check if a translation key exists. Since `tr` is a function, `hasattr` always returns `False`, causing the code to always use the fallback English string.

**Fix:**

```python
# Before (buggy):
if hasattr(tr, "BTN_LOAD_MAP"):
    btn.setText(tr("BTN_LOAD_MAP"))
else:
    btn.setText("Load Map")

# After (correct):
btn.setText(tr("BTN_LOAD_MAP"))
```

The `tr()` function already returns the key itself as a fallback if the translation is missing, so the `hasattr` check is unnecessary. If you want to detect missing translations during development, add a logging call to `core/locales.py`:

```python
def tr(key: str, **kwargs: Any) -> str:
    result = i18n.t(key, **kwargs)
    if result == key:
        logger.debug("Missing translation for key: %s", key)
    return result
```

**Estimated Effort:** 2-3 days total
**Risk:** Low for comment translation (no behavioral change). Medium for UI string fixes (verify with both EN and TR locale). Low for hasattr fix (removes dead code path).
**Dependencies:** Locale YAML files must be updated with new keys.
**Verification:** Run the application with both English and Turkish locale settings. Verify no Turkish text appears when English is selected. Run `pytest` to confirm all tests pass.

---

### 3.5 Replace Bare `except` with Specific Exception Types (Week 3-4)

**Current State:**

8 files contain bare `except` clauses that catch all exceptions, including `SystemExit`, `KeyboardInterrupt`, and `GeneratorExit`. This masks bugs and makes debugging extremely difficult.

**Bare except inventory (from audit):**

| File | Location | Current Code | Risk |
|------|----------|-------------|------|
| `core/data_manager.py` | `load_settings()` | `except: pass` | High -- silently loses settings load errors |
| `core/data_manager.py` | `_save_reference_cache()` | `except Exception as e: print(...)` | Medium -- logs but catches too broadly |
| `core/api_client.py` | `parse_dispatcher()` | `except:` with JSON fallback | High -- silently swallows parse failures |
| `ui/widgets/combat_tracker.py` | `clean_stat_value()` | `except: return default` | Medium -- masks malformed stat strings |
| `ui/tabs/mind_map_tab.py` | `process_pending_entity_saves()` | `except: pass` | Critical -- silently loses entity saves |
| `ui/dialogs/import_window.py` | Import handling | `except:` | High -- silently loses import errors |
| `ui/dialogs/api_browser.py` | API response parsing | `except:` (multiple) | High -- masks API data issues |
| `ui/dialogs/encounter_selector.py` | Encounter loading | `except:` | Medium -- masks load errors |
| `core/dev/ipc_bridge.py` | Cleanup paths | `except Exception: pass` | Low -- acceptable in cleanup |

**Action Plan:**

For each bare except, determine the specific exceptions that can reasonably occur and replace the bare except with those specific types.

#### `core/data_manager.py` -- `load_settings()`

```python
# Before:
def load_settings(self):
    path = os.path.join(CACHE_DIR, "settings.json")
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f: return json.load(f)
        except: pass
    return {"language": "EN", "theme": "dark"}

# After:
def load_settings(self) -> dict[str, str]:
    path = os.path.join(CACHE_DIR, "settings.json")
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)
        except (OSError, json.JSONDecodeError, ValueError) as e:
            logger.warning("Failed to load settings from %s: %s", path, e)
    return {"language": "EN", "theme": "dark"}
```

#### `core/api_client.py` -- `parse_dispatcher()`

```python
# Before:
def parse_dispatcher(self, category, data):
    if isinstance(data, str):
        try:
            data = json.loads(data)
        except:
            return {"name": "Parse Error", "type": category, "description": str(data)}

# After:
def parse_dispatcher(self, category: str, data: dict[str, Any] | str) -> dict[str, Any]:
    if isinstance(data, str):
        try:
            data = json.loads(data)
        except (json.JSONDecodeError, ValueError) as e:
            logger.warning("Failed to parse API data as JSON: %s", e)
            return {"name": "Parse Error", "type": category, "description": str(data)}
```

#### `ui/widgets/combat_tracker.py` -- `clean_stat_value()`

```python
# Before:
def clean_stat_value(value, default=10):
    if value is None: return default
    s_val = str(value).strip()
    if not s_val: return default
    try:
        first_part = s_val.split(' ')[0]
        digits = ''.join(filter(str.isdigit, first_part))
        return int(digits) if digits else default
    except: return default

# After:
def clean_stat_value(value: Any, default: int = 10) -> int:
    if value is None:
        return default
    s_val = str(value).strip()
    if not s_val:
        return default
    try:
        first_part = s_val.split(" ")[0]
        digits = "".join(filter(str.isdigit, first_part))
        return int(digits) if digits else default
    except (ValueError, IndexError) as e:
        logger.debug("Could not parse stat value '%s': %s", value, e)
        return default
```

#### `ui/tabs/mind_map_tab.py` -- `process_pending_entity_saves()`

```python
# Before:
try:
    # ... entity save logic ...
except: pass

# After:
try:
    # ... entity save logic ...
except (KeyError, TypeError, OSError) as e:
    logger.error("Failed to save pending entity changes: %s", e)
```

#### `ui/dialogs/import_window.py` -- import handling

```python
# Before:
try:
    # ... import logic ...
except:
    # silently fail

# After:
try:
    # ... import logic ...
except (OSError, json.JSONDecodeError, KeyError) as e:
    logger.error("Failed to import entity: %s", e)
```

#### `ui/dialogs/api_browser.py` -- API response parsing

Replace each bare except with `except (KeyError, TypeError, ValueError, json.JSONDecodeError) as e:` and log the error.

#### `ui/dialogs/encounter_selector.py` -- encounter loading

Replace bare except with `except (OSError, json.JSONDecodeError, KeyError, TypeError) as e:` and log the error.

#### `core/dev/ipc_bridge.py` -- cleanup paths

These are acceptable as-is since they are in cleanup/shutdown code paths. However, they should be narrowed to `except (OSError, EOFError, ConnectionError):` instead of `except Exception:`.

**Estimated Effort:** 2-3 hours
**Risk:** Low -- specific exceptions are strictly more restrictive than bare except. If a previously-masked exception type now propagates, that is desirable behavior (it reveals a real bug).
**Dependencies:** Logging framework (Section 3.2) should be in place so that caught exceptions can be logged.
**Verification:** Run `pytest`. Manually trigger error conditions (corrupt settings file, bad API response) and verify appropriate error messages in logs.

---

### 3.6 Phase 1 Checklist

| Task | Files | Effort | Week |
|------|-------|--------|------|
| Add `__init__.py` to all packages | 6 new files | 1 hour | 1 |
| Create logging configuration | 1 new file + `main.py` | 2 hours | 1 |
| Replace `print()` with `logging` | 10 files | 4 hours | 1 |
| Type hints: Tier 1 (core data) | 4 files | 1 day | 1 |
| Type hints: Tier 2 (UI widgets) | 9 files | 1 day | 2 |
| Translate Turkish comments | 28 files | 2 days | 2 |
| Fix hardcoded Turkish UI strings | 3 files | 1 hour | 2 |
| Fix `hasattr(tr)` bug | 1 file | 15 min | 2 |
| Remove duplicate translation maps | 1 file + locale files | 1 hour | 2 |
| Replace bare `except` clauses | 8 files | 3 hours | 3 |
| Type hints: Tier 3 (tabs/dialogs) | 11 files | 1 day | 3 |
| Type hints: Tier 4 (remaining) | 11 files | 1 day | 3-4 |

**Phase 1 Exit Criteria:**

- All packages have `__init__.py` files.
- Zero `print()` calls in production code (dev tooling may retain them if appropriate).
- 100% of public function signatures have type annotations.
- Zero Turkish comments, docstrings, or hardcoded UI strings.
- Zero bare `except` clauses (all use specific exception types).
- `mypy --ignore-missing-imports core/` passes with no errors.
- All existing tests pass.
- The application starts and operates normally.

---

## 4. Phase 2: God Class Decomposition (Weeks 5-10)

Phase 2 addresses the three largest classes in the codebase by splitting them into focused, single-responsibility components. This is the highest-risk phase because it changes the internal architecture while preserving external behavior.

### 4.1 DataManager Decomposition (Weeks 5-7)

**Current State:**

`DataManager` (677 LOC, ~45 methods) is the central data hub that combines at least 6 distinct responsibilities:

1. **Campaign I/O** -- load/save campaigns in MsgPack/JSON format with migration
2. **Entity CRUD** -- create, read, update, delete entities
3. **Session Management** -- create/load/save sessions
4. **Settings Management** -- load/save application settings
5. **Library Catalog** -- scan, search, and manage the offline library cache
6. **API Delegation** -- fetch data from external APIs, cache results, resolve dependencies
7. **Map/Timeline Management** -- CRUD for map pins and timeline entries

**Target Decomposition:**

```
DataManager (current: ~45 methods, 677 LOC)
  |
  +--> CampaignManager       (load/save/create/migrate campaigns: ~10 methods, ~180 LOC)
  +--> EntityRepository       (entity CRUD: ~8 methods, ~100 LOC)
  +--> SessionRepository      (session CRUD: ~6 methods, ~60 LOC)
  +--> SettingsManager        (settings load/save: ~3 methods, ~40 LOC)
  +--> LibraryManager         (library scan/search/cache: ~6 methods, ~80 LOC)
  +--> MapDataManager         (map pin/timeline CRUD: ~12 methods, ~150 LOC)
  +--> DataManager            (orchestrator/facade: ~10 methods, ~80 LOC)
```

**New file structure:**

```
core/
  data_manager.py        # Slim orchestrator (facade)
  campaign_manager.py    # Campaign I/O and migration
  entity_repository.py   # Entity CRUD
  session_repository.py  # Session CRUD
  settings_manager.py    # Application settings
  library_manager.py     # Library cache management
  map_data_manager.py    # Map pin and timeline management
```

#### Step-by-Step Migration Guide

**Step 1: Extract SettingsManager (simplest, fewest dependencies)**

SettingsManager handles `load_settings()` and `save_settings()`. It has no dependencies on other DataManager methods.

```python
# core/settings_manager.py
from __future__ import annotations

import json
import logging
import os
from typing import Any

from core.locales import set_language

logger = logging.getLogger(__name__)


class SettingsManager:
    """Manages application settings persistence."""

    def __init__(self, cache_dir: str) -> None:
        self._cache_dir = cache_dir
        self._path = os.path.join(cache_dir, "settings.json")
        self.settings: dict[str, Any] = self._load()
        self.current_theme: str = self.settings.get("theme", "dark")
        set_language(self.settings.get("language", "EN"))

    def _load(self) -> dict[str, Any]:
        if os.path.exists(self._path):
            try:
                with open(self._path, "r", encoding="utf-8") as f:
                    return json.load(f)
            except (OSError, json.JSONDecodeError, ValueError) as e:
                logger.warning("Failed to load settings: %s", e)
        return {"language": "EN", "theme": "dark"}

    def save(self, updates: dict[str, Any]) -> None:
        os.makedirs(self._cache_dir, exist_ok=True)
        self.settings.update(updates)
        with open(self._path, "w", encoding="utf-8") as f:
            json.dump(self.settings, f, indent=4)
        set_language(self.settings.get("language", "EN"))
        self.current_theme = self.settings.get("theme", "dark")
```

Then in `DataManager.__init__()`:

```python
self._settings_mgr = SettingsManager(CACHE_DIR)
self.settings = self._settings_mgr.settings
self.current_theme = self._settings_mgr.current_theme
```

And add delegation methods:

```python
def load_settings(self) -> dict[str, Any]:
    return self._settings_mgr.settings

def save_settings(self, settings: dict[str, Any]) -> None:
    self._settings_mgr.save(settings)
    self.settings = self._settings_mgr.settings
    self.current_theme = self._settings_mgr.current_theme
```

**Step 2: Extract EntityRepository**

EntityRepository handles `save_entity()`, `delete_entity()`, `prepare_entity_from_external()`, `_resolve_dependencies()`, and `_auto_import_linked_entities()`.

It needs a reference to the campaign data dict and a `save_data()` callback.

```python
# core/entity_repository.py
from __future__ import annotations

import logging
import uuid
from typing import Any, Callable

logger = logging.getLogger(__name__)


class EntityRepository:
    """CRUD operations for entities within a campaign."""

    def __init__(
        self,
        get_data: Callable[[], dict[str, Any]],
        save_callback: Callable[[], None],
        fetch_details: Callable[[str, str], tuple[bool, Any]],
    ) -> None:
        self._get_data = get_data
        self._save = save_callback
        self._fetch_details = fetch_details

    @property
    def entities(self) -> dict[str, dict[str, Any]]:
        return self._get_data().get("entities", {})

    def save(
        self,
        eid: str | None,
        data: dict[str, Any],
        should_save: bool = True,
        auto_source_update: bool = True,
    ) -> str:
        if not eid:
            eid = str(uuid.uuid4())

        if auto_source_update:
            world_name = self._get_data().get("world_name", "")
            current_source = data.get("source", "")
            if world_name:
                if not current_source:
                    data["source"] = world_name
                elif world_name not in current_source:
                    data["source"] = f"{current_source} / {world_name}"

        entities = self._get_data()["entities"]
        if eid in entities:
            entities[eid].update(data)
        else:
            entities[eid] = data

        if should_save:
            self._save()
        return eid

    def delete(self, eid: str) -> None:
        entities = self._get_data()["entities"]
        if eid in entities:
            del entities[eid]
            self._save()

    def get_all_mentions(self) -> list[dict[str, str]]:
        return [
            {"id": eid, "name": ent["name"], "type": ent["type"]}
            for eid, ent in self.entities.items()
        ]
```

**Step 3: Extract SessionRepository**

```python
# core/session_repository.py
from __future__ import annotations

import logging
import uuid
from typing import Any, Callable

from core.locales import tr

logger = logging.getLogger(__name__)


class SessionRepository:
    """CRUD operations for sessions within a campaign."""

    def __init__(
        self,
        get_data: Callable[[], dict[str, Any]],
        save_callback: Callable[[], None],
    ) -> None:
        self._get_data = get_data
        self._save = save_callback

    def create(self, name: str) -> str:
        session_id = str(uuid.uuid4())
        new_session = {
            "id": session_id,
            "name": name,
            "date": tr("MSG_TODAY"),
            "notes": "",
            "logs": "",
            "combatants": [],
        }
        data = self._get_data()
        if "sessions" not in data:
            data["sessions"] = []
        data["sessions"].append(new_session)
        data["last_active_session_id"] = session_id
        self._save()
        return session_id

    def get(self, session_id: str) -> dict[str, Any] | None:
        for s in self._get_data().get("sessions", []):
            if s["id"] == session_id:
                return s
        return None

    def save_data(
        self,
        session_id: str,
        notes: str,
        logs: str,
        combatants: list[dict[str, Any]],
    ) -> None:
        for s in self._get_data().get("sessions", []):
            if s["id"] == session_id:
                s["notes"] = notes
                s["logs"] = logs
                s["combatants"] = combatants
                self._get_data()["last_active_session_id"] = session_id
                self._save()
                break

    def get_last_active_id(self) -> str | None:
        return self._get_data().get("last_active_session_id")

    def set_active(self, session_id: str) -> None:
        self._get_data()["last_active_session_id"] = session_id
```

**Step 4: Extract MapDataManager**

Handles all map pin and timeline CRUD methods (12 methods).

**Step 5: Extract CampaignManager**

Handles `load_campaign()`, `create_campaign()`, `save_data()`, `_fix_absolute_paths()`, and the data migration logic in `load_campaign()`.

**Step 6: Extract LibraryManager**

Handles `reload_library_cache()`, `_save_reference_cache()`, `refresh_library_catalog()`, `search_library_catalog()`, `search_in_library()`, `get_api_index()`, and `fetch_details_from_api()`.

**Step 7: Slim down DataManager to a facade**

After all extractions, DataManager becomes a thin orchestrator that:
- Instantiates all sub-managers in `__init__()`
- Provides delegation methods for backward compatibility
- Coordinates operations that span multiple sub-managers

**Estimated Effort per Step:**

| Step | Effort | Risk |
|------|--------|------|
| Extract SettingsManager | 2 hours | Very Low |
| Extract EntityRepository | 4 hours | Low |
| Extract SessionRepository | 2 hours | Low |
| Extract MapDataManager | 3 hours | Low |
| Extract CampaignManager | 1 day | Medium (migration logic is complex) |
| Extract LibraryManager | 1 day | Medium (API delegation is coupled) |
| Slim DataManager facade | 4 hours | Low |

**Total estimated effort:** 4-5 days

---

### 4.2 NpcSheet Decomposition (Weeks 7-9)

**Current State:**

`NpcSheet` (1,002 LOC, ~46 methods) is a monolithic widget combining:

1. UI layout construction (~200 LOC in `init_ui()`)
2. Data population and collection (~150 LOC in `populate_sheet()`/`collect_data_from_sheet()`)
3. Image gallery management (~150 LOC: add, remove, navigate, download images)
4. PDF management (~100 LOC: add, remove, open PDFs)
5. Linked entity management (~120 LOC: spells, equipment, drag-and-drop)
6. API browser integration (~80 LOC: fetch from API, apply result)
7. Dynamic attribute form generation (~100 LOC: build form from entity schema)
8. Theme refresh (~50 LOC)

**Target Decomposition:**

```
NpcSheet (current: ~46 methods, 1,002 LOC)
  |
  +--> NpcFormLayout        (init_ui decomposition, form construction: ~200 LOC)
  +--> NpcDataBinder        (populate_sheet/collect_data mirror methods: ~150 LOC)
  +--> ImageGalleryWidget   (image management as standalone widget: ~150 LOC)
  +--> PdfManagerWidget     (PDF management as standalone widget: ~100 LOC)
  +--> LinkedEntityWidget   (spell/equipment linking: ~120 LOC)
  +--> NpcSheet             (orchestrator: ~15 methods, ~300 LOC)
```

**New file structure:**

```
ui/widgets/
  npc_sheet.py              # Slim orchestrator
  image_gallery.py          # Image gallery widget
  pdf_manager.py            # PDF management widget
  linked_entity_widget.py   # Linked spell/equipment widget
  npc_form_layout.py        # Form layout builder
  npc_data_binder.py        # Data population/collection
```

#### Step-by-Step Migration Guide

**Step 1: Extract ImageGalleryWidget**

This is the most self-contained subsystem. It manages:
- `self.image_list` -- list of image paths
- `self.current_img_index` -- current display index
- `self.image_worker` -- QThread for async image download
- Methods: `add_image()`, `remove_image()`, `next_image()`, `prev_image()`, `download_api_image()`, `_update_image_display()`

Create `ui/widgets/image_gallery.py` with an `ImageGalleryWidget(QWidget)` class that:
- Emits `image_added(str)` and `image_removed(int)` signals
- Accepts a `data_manager` reference for `import_image()` and `get_full_path()`
- Exposes `set_images(list[str])` and `get_images() -> list[str]` for data binding

In `NpcSheet`, replace the image methods with delegation to the embedded widget:

```python
class NpcSheet(QWidget):
    def __init__(self, data_manager):
        # ...
        self.image_gallery = ImageGalleryWidget(data_manager)
        # ... add to layout ...

    def populate_sheet(self, data):
        # ...
        self.image_gallery.set_images(data.get("images", []))

    def collect_data_from_sheet(self):
        data = {}
        # ...
        data["images"] = self.image_gallery.get_images()
        return data
```

**Step 2: Extract PdfManagerWidget**

Similar to ImageGalleryWidget but for PDFs:
- Methods: `add_pdf_dialog()`, `open_current_pdf()`, `remove_current_pdf()`, `open_pdf_folder()`
- Exposes `set_pdfs(list[str])` and `get_pdfs() -> list[str]`

**Step 3: Extract LinkedEntityWidget**

Manages linked spells and equipment:
- `self.linked_spell_ids` and `self.linked_item_ids`
- Methods for adding/removing spell and equipment links
- Drag-and-drop acceptance for entity drops
- Emits `entity_link_requested(str)` signal

**Step 4: Extract NpcDataBinder**

The `populate_sheet()` and `collect_data_from_sheet()` methods are mirror methods that read/write form fields. Extracting them into a binder class centralizes the field mapping:

```python
class NpcDataBinder:
    """Binds entity data to and from form widgets."""

    def __init__(self, form_widgets: dict[str, QWidget]) -> None:
        self._widgets = form_widgets

    def populate(self, data: dict[str, Any]) -> None:
        """Write entity data into form widgets."""
        ...

    def collect(self) -> dict[str, Any]:
        """Read entity data from form widgets."""
        ...
```

**Step 5: Slim NpcSheet to orchestrator**

NpcSheet becomes a coordinator that:
- Creates and lays out sub-widgets
- Connects signals between sub-widgets
- Manages the overall dirty state
- Handles theme refresh by delegating to sub-widgets

**Estimated Effort:** 5-7 days

---

### 4.3 CombatTracker Decomposition (Weeks 9-10)

**Current State:**

`CombatTracker` (912 LOC, ~41 methods) contains:

1. `DraggableCombatTable` inline class -- QTableWidget subclass with drag-and-drop
2. `CombatTracker` main class with responsibilities:
   - UI layout construction
   - Combatant management (add, remove, update HP, conditions)
   - Initiative tracking (roll, sort, next turn)
   - Encounter management (save, load, new)
   - Battle map integration (load map, sync tokens, sync fog)
   - Session state serialization (get/load full state)

**Target Decomposition:**

```
CombatTracker (current: ~41 methods, 912 LOC)
  |
  +--> DraggableCombatTable  (move to separate file: ~50 LOC)
  +--> CombatModel           (combatant state management: ~15 methods, ~200 LOC)
  +--> CombatView            (UI layout and display: ~10 methods, ~250 LOC)
  +--> EncounterManager      (encounter save/load: ~5 methods, ~100 LOC)
  +--> BattleMapBridge       (map integration: ~6 methods, ~100 LOC)
  +--> CombatTracker         (orchestrator: ~10 methods, ~200 LOC)
```

**New file structure:**

```
ui/widgets/
  combat_tracker.py         # Slim orchestrator
  combat_model.py           # Pure data: combatant state management
  combat_table.py           # DraggableCombatTable widget
  encounter_manager.py      # Encounter persistence
  battle_map_bridge.py      # Bridge between combat and battle map
```

#### Step-by-Step Migration Guide

**Step 1: Extract DraggableCombatTable to its own file**

This is a standalone QTableWidget subclass. Move it to `ui/widgets/combat_table.py`. Update the import in `combat_tracker.py`.

**Step 2: Extract CombatModel**

Create a pure data class that manages combatant state without any UI dependencies:

```python
# ui/widgets/combat_model.py
from __future__ import annotations

import random
import uuid
from typing import Any

from core.locales import tr


class Combatant:
    """Represents a single combatant in an encounter."""

    def __init__(
        self,
        eid: str,
        name: str,
        initiative: int = 0,
        hp: int = 0,
        max_hp: int = 0,
        ac: int = 10,
        entity_type: str = "NPC",
        attitude: str = "Neutral",
    ) -> None:
        self.id = str(uuid.uuid4())
        self.eid = eid
        self.name = name
        self.initiative = initiative
        self.hp = hp
        self.max_hp = max_hp
        self.ac = ac
        self.entity_type = entity_type
        self.attitude = attitude
        self.conditions: list[str] = []
        self.map_x: float = 0.0
        self.map_y: float = 0.0
        self.token_size: int = 1


class CombatModel:
    """Manages the state of all combatants in an encounter."""

    def __init__(self) -> None:
        self.combatants: list[Combatant] = []
        self.turn_index: int = 0
        self.round_number: int = 1

    def add_combatant(self, combatant: Combatant) -> None: ...
    def remove_combatant(self, combatant_id: str) -> None: ...
    def sort_by_initiative(self) -> None: ...
    def next_turn(self) -> Combatant | None: ...
    def previous_turn(self) -> Combatant | None: ...
    def update_hp(self, combatant_id: str, delta: int) -> None: ...
    def toggle_condition(self, combatant_id: str, condition: str) -> None: ...
    def to_dict(self) -> dict[str, Any]: ...
    def from_dict(self, data: dict[str, Any]) -> None: ...
```

**Step 3: Extract EncounterManager**

Move encounter save/load/new logic to a dedicated class.

**Step 4: Extract BattleMapBridge**

Move map integration methods to a bridge class that coordinates between CombatModel and BattleMapWidget.

**Step 5: Slim CombatTracker to orchestrator**

CombatTracker becomes a view-controller that coordinates the model, table widget, encounter manager, and map bridge.

**Estimated Effort:** 4-5 days

---

### 4.4 Phase 2 Checklist

| Task | Files | Effort | Week |
|------|-------|--------|------|
| Write characterization tests for DataManager | 1 test file | 1 day | 5 |
| Extract SettingsManager | 2 files | 2 hours | 5 |
| Extract EntityRepository | 2 files | 4 hours | 5 |
| Extract SessionRepository | 2 files | 2 hours | 5 |
| Extract MapDataManager | 2 files | 3 hours | 6 |
| Extract CampaignManager | 2 files | 1 day | 6 |
| Extract LibraryManager | 2 files | 1 day | 6 |
| Slim DataManager facade | 1 file | 4 hours | 7 |
| Write characterization tests for NpcSheet | 1 test file | 1 day | 7 |
| Extract ImageGalleryWidget | 2 files | 1 day | 7 |
| Extract PdfManagerWidget | 2 files | 4 hours | 8 |
| Extract LinkedEntityWidget | 2 files | 4 hours | 8 |
| Extract NpcDataBinder | 2 files | 1 day | 8 |
| Slim NpcSheet orchestrator | 1 file | 4 hours | 9 |
| Write characterization tests for CombatTracker | 1 test file | 1 day | 9 |
| Extract DraggableCombatTable | 2 files | 1 hour | 9 |
| Extract CombatModel | 2 files | 1 day | 9 |
| Extract EncounterManager | 2 files | 4 hours | 10 |
| Extract BattleMapBridge | 2 files | 4 hours | 10 |
| Slim CombatTracker orchestrator | 1 file | 4 hours | 10 |

**Phase 2 Exit Criteria:**

- No class exceeds 400 LOC.
- No class has more than 20 public methods.
- All extracted classes have characterization tests.
- All existing tests continue to pass.
- DataManager facade delegates to sub-managers.
- NpcSheet orchestrator delegates to sub-widgets.
- CombatTracker orchestrator delegates to model and sub-components.
- The application starts and operates normally.

---

## 5. Phase 3: UI Consistency (Weeks 11-13)

### 5.1 Catalog All Inline Styles

**Current State:**

Seven files contain hardcoded CSS that bypasses the theme system. When users switch themes, these elements retain their hardcoded appearance, creating visual inconsistencies.

**Complete catalog of inline styles:**

#### `ui/tabs/database_tab.py` (lines 38-43)

```python
# EntityTabWidget hardcoded tab styling
self.setStyleSheet("""
    QTabWidget::pane { border: 1px solid #444; }
    QTabBar::tab { background: #2b2b2b; color: #ccc; padding: 6px 16px; }
    QTabBar::tab:selected { background: #3c3f41; color: #fff; }
    QTabBar::tab:hover { background: #4a4a4a; }
""")
```

**Issue:** Hardcoded dark theme colors (#444, #2b2b2b, #3c3f41) will clash with light themes.
**Replacement:** Remove the `setStyleSheet()` call entirely. Add to external QSS:

```css
EntityTabWidget QTabWidget::pane { border: 1px solid palette(mid); }
EntityTabWidget QTabBar::tab { padding: 6px 16px; }
```

Or use ThemeManager palette:

```python
palette = ThemeManager.get_palette(theme_name)
self.setStyleSheet(f"""
    QTabWidget::pane {{ border: 1px solid {palette['border']}; }}
    QTabBar::tab {{ background: {palette['tab_bg']}; color: {palette['text']}; padding: 6px 16px; }}
    QTabBar::tab:selected {{ background: {palette['tab_active_bg']}; color: {palette['text_bright']}; }}
    QTabBar::tab:hover {{ background: {palette['tab_hover_bg']}; }}
""")
```

#### `ui/widgets/entity_sidebar.py` (lines 25, 33, 113-116)

```python
# Search input styling
self.search_input.setStyleSheet("padding: 6px; border-radius: 4px; ...")

# List widget styling
self.entity_list.setStyleSheet("QListWidget { border: none; ... }")

# Category filter button styling
btn.setStyleSheet("QPushButton { background: #333; color: #bbb; ... }")
```

**Issue:** Multiple hardcoded color values throughout the sidebar.
**Replacement:** Migrate to `refresh_theme()` method pattern (like `projection_manager.py`):

```python
def refresh_theme(self, palette: dict[str, str]) -> None:
    self.search_input.setStyleSheet(f"""
        padding: 6px;
        border-radius: 4px;
        background: {palette['input_bg']};
        color: {palette['text']};
        border: 1px solid {palette['border']};
    """)
    # ... similar for other widgets
```

#### `ui/widgets/markdown_editor.py` (lines 18-27)

```python
# MentionPopup hardcoded styling
self.setStyleSheet("""
    QListWidget {
        background-color: #2b2b2b;
        border: 1px solid #555;
        color: #eee;
        font-size: 13px;
        ...
    }
""")
```

**Replacement:** Add a `refresh_theme()` method that accepts a palette dict.

#### `ui/dialogs/bulk_downloader.py` (~lines 200-250)

```python
# Progress bar and status display styling
self.progress_bar.setStyleSheet("QProgressBar { ... }")
self.status_label.setStyleSheet("color: #aaa; ...")
```

**Replacement:** Use external QSS classes:

```css
BulkDownloaderDialog QProgressBar { /* theme-aware styles */ }
BulkDownloaderDialog QLabel#status { /* theme-aware styles */ }
```

#### `ui/dialogs/entity_selector.py` (~lines 50-80)

```python
# Table widget styling
self.table.setStyleSheet("QTableWidget { ... }")
```

**Replacement:** External QSS or palette-based styling.

#### `ui/dialogs/api_browser.py` (multiple locations)

Various elements have hardcoded CSS for backgrounds, borders, and text colors.

**Replacement:** External QSS or palette-based styling.

#### `ui/windows/battle_map_window.py` (multiple locations)

Sidebar condition icons and toolbar elements have hardcoded styling.

**Replacement:** Palette-based styling in a `refresh_theme()` method.

### 5.2 Migration Strategy

**Approach: Theme-Palette-Based Styling**

Use the pattern from `ui/widgets/projection_manager.py` as the reference implementation. Every widget that needs custom styling should:

1. Accept a theme name or palette dict in its constructor or via a `refresh_theme()` method.
2. Build CSS strings using palette values.
3. Call `self.setStyleSheet()` with the dynamically generated CSS.
4. Be called from `MainWindow.change_theme()` when the theme changes.

**New QSS class additions for external theme files:**

For elements that can be styled purely through QSS (without needing Python-side palette access), add class selectors to the theme files:

```css
/* themes/dark.qss -- additions */

/* Entity sidebar */
EntitySidebar QLineEdit#search {
    padding: 6px;
    border-radius: 4px;
}

/* Database tab */
EntityTabWidget QTabBar::tab {
    padding: 6px 16px;
}

/* Bulk downloader */
BulkDownloaderDialog QProgressBar {
    text-align: center;
    border-radius: 3px;
}

/* Entity selector */
EntitySelector QTableWidget {
    gridline-color: palette(mid);
}
```

### 5.3 Widget Sizing and Spacing Standards

Establish consistent sizing and spacing values across all widgets:

| Element | Standard Value | Current State |
|---------|---------------|---------------|
| Button padding | `6px 16px` | Varies: 4-12px vertical, 8-20px horizontal |
| Input field padding | `6px` | Varies: 4-8px |
| Group box margin | `8px` | Varies: 0-12px |
| Section spacing | `12px` | Varies: 4-20px |
| Border radius | `4px` (buttons), `3px` (inputs) | Varies: 0-8px |
| Font size (body) | `13px` | Varies: 12-14px |
| Font size (headers) | `15px` | Varies: 14-18px |
| Icon size (toolbar) | `24x24` | Varies: 16-32px |
| Icon size (sidebar) | `16x16` | Varies: 14-20px |

Define these as constants in the theme system:

```python
# core/theme_constants.py
BUTTON_PADDING = "6px 16px"
INPUT_PADDING = "6px"
GROUP_MARGIN = "8px"
SECTION_SPACING = 12
BORDER_RADIUS_BUTTON = "4px"
BORDER_RADIUS_INPUT = "3px"
FONT_SIZE_BODY = 13
FONT_SIZE_HEADER = 15
ICON_SIZE_TOOLBAR = 24
ICON_SIZE_SIDEBAR = 16
```

### 5.4 Button Layout Standards

Standardize button placement across all dialogs and panels:

| Context | Standard |
|---------|----------|
| Dialog action buttons | Right-aligned, OK/Cancel order, 8px spacing |
| Toolbar buttons | Left-aligned, icon-only with tooltips, 4px spacing |
| Form action buttons | Below the form, right-aligned |
| List management buttons | Vertical stack to the right of the list, or horizontal below |

### 5.5 Phase 3 Checklist

| Task | Files | Effort | Week |
|------|-------|--------|------|
| Add `refresh_theme()` to EntitySidebar | 1 file | 2 hours | 11 |
| Add `refresh_theme()` to MentionPopup | 1 file | 1 hour | 11 |
| Remove hardcoded CSS from database_tab.py | 1 file | 1 hour | 11 |
| Remove hardcoded CSS from entity_selector.py | 1 file | 1 hour | 11 |
| Remove hardcoded CSS from bulk_downloader.py | 1 file | 1 hour | 11 |
| Remove hardcoded CSS from api_browser.py | 1 file | 2 hours | 12 |
| Remove hardcoded CSS from battle_map_window.py | 1 file | 2 hours | 12 |
| Define theme constants | 1 new file | 1 hour | 12 |
| Update all QSS theme files with new classes | 11 theme files | 1 day | 12 |
| Standardize button layouts | 10+ files | 1 day | 13 |
| Standardize widget sizing and spacing | 15+ files | 1 day | 13 |
| Visual QA testing across all themes | Manual testing | 1 day | 13 |

**Phase 3 Exit Criteria:**

- Zero `setStyleSheet("...")` calls with hardcoded color values in production code.
- All styled widgets have a `refresh_theme()` method or use external QSS.
- Theme switching produces consistent results across all panels and dialogs.
- Sizing and spacing are uniform across the application.

---

## 6. Phase 4: Architecture Patterns (Weeks 14-17)

### 6.1 Introduce MVC/MVP Separation (Weeks 14-15)

**Current State:**

The application mixes view logic (UI construction, widget manipulation) with model logic (data management, business rules) within the same classes. There is no formal separation between data, presentation, and user interaction.

**Target Pattern: Model-View-Presenter (MVP)**

MVP is the best fit for desktop Qt applications because:

- The **Model** holds data and business rules (already partially exists in DataManager).
- The **View** is the Qt widget tree (handles display and user input).
- The **Presenter** mediates between Model and View, handling user actions and updating the view.

**Implementation Strategy:**

For each major UI component, separate the presenter logic from the view construction:

```
Current: CombatTracker (view + presenter + model in one class)

Target:
  CombatModel       -- Data: combatant list, turn state, encounter state
  CombatView        -- Display: table widget, buttons, labels
  CombatPresenter   -- Logic: handles button clicks, updates model, refreshes view
```

**Presenter interface pattern:**

```python
class CombatPresenter:
    """Mediates between CombatModel and CombatView."""

    def __init__(self, model: CombatModel, view: CombatView) -> None:
        self._model = model
        self._view = view
        self._connect_signals()

    def _connect_signals(self) -> None:
        self._view.add_clicked.connect(self._on_add_combatant)
        self._view.remove_clicked.connect(self._on_remove_combatant)
        self._view.next_turn_clicked.connect(self._on_next_turn)
        self._model.data_changed.connect(self._refresh_view)

    def _on_add_combatant(self, entity_data: dict) -> None:
        combatant = Combatant.from_entity(entity_data)
        self._model.add_combatant(combatant)

    def _refresh_view(self) -> None:
        self._view.update_table(self._model.combatants)
        self._view.update_turn_indicator(self._model.turn_index)
```

**Priority order for MVP conversion:**

| Component | Priority | Reason |
|-----------|----------|--------|
| CombatTracker | High | Already decomposed in Phase 2; model exists |
| NpcSheet | High | Already decomposed in Phase 2; binder exists |
| MindMapTab | Medium | Complex interaction model benefits from separation |
| SessionTab | Medium | Session data management is distinct from UI |
| MapTab | Low | Relatively simple interaction model |
| DatabaseTab | Low | Mostly tab management, less business logic |

### 6.2 Event Bus Formalization (Week 15)

**Current State:**

The application uses PyQt6 signals for cross-component communication. This works well for direct parent-child relationships, but cross-cutting concerns (like entity deletion that must update the sidebar, all open tabs, and the mind map) require chains of signal forwarding.

**Current signal forwarding chain for entity deletion:**

```
NpcSheet.delete_clicked
  --> DatabaseTab.delete_entity_from_tab()
    --> DatabaseTab.entity_deleted signal
      --> MainWindow receives
        --> EntitySidebar.refresh_entity_list()
        --> MindMapTab.refresh() (if visible)
```

This chain is fragile -- any break in the forwarding causes silent failure.

**Proposed Event Bus:**

A lightweight publish-subscribe event bus that allows any component to publish events and any other component to subscribe:

```python
# core/event_bus.py
from __future__ import annotations

import logging
from collections import defaultdict
from typing import Any, Callable

logger = logging.getLogger(__name__)


class EventBus:
    """Application-wide publish-subscribe event bus.

    Usage:
        bus = EventBus()
        bus.subscribe("entity.deleted", sidebar.on_entity_deleted)
        bus.subscribe("entity.deleted", mind_map.on_entity_deleted)
        bus.publish("entity.deleted", entity_id="abc123")
    """

    def __init__(self) -> None:
        self._subscribers: dict[str, list[Callable[..., Any]]] = defaultdict(list)

    def subscribe(self, event: str, handler: Callable[..., Any]) -> None:
        self._subscribers[event].append(handler)

    def unsubscribe(self, event: str, handler: Callable[..., Any]) -> None:
        if handler in self._subscribers[event]:
            self._subscribers[event].remove(handler)

    def publish(self, event: str, **kwargs: Any) -> None:
        for handler in self._subscribers[event]:
            try:
                handler(**kwargs)
            except Exception as e:
                logger.error(
                    "Event handler %s failed for event '%s': %s",
                    handler.__qualname__,
                    event,
                    e,
                )
```

**Event naming convention:**

```
{domain}.{action}

entity.created      -- New entity added to campaign
entity.updated      -- Entity data modified
entity.deleted      -- Entity removed from campaign
session.changed     -- Active session changed
session.saved       -- Session data saved
combat.started      -- Combat encounter started
combat.ended        -- Combat encounter ended
combat.turn_changed -- Turn advanced in combat
theme.changed       -- Application theme changed
language.changed    -- Application language changed
map.pin_added       -- Map pin created
map.pin_removed     -- Map pin deleted
```

**Migration strategy:**

1. Create the EventBus class.
2. Instantiate a single global bus in `main.py` and pass it to components via constructor.
3. Gradually migrate signal chains to bus events, starting with entity lifecycle events.
4. Keep PyQt signals for direct parent-child communication (they are the right tool for that).
5. Use the event bus only for cross-cutting concerns that span unrelated components.

### 6.3 Dependency Injection Patterns (Week 16)

**Current State:**

Most classes import their dependencies directly and instantiate them internally. This makes testing difficult because dependencies cannot be replaced with mocks.

**Example of current coupling:**

```python
# core/data_manager.py
from core.api_client import DndApiClient

class DataManager:
    def __init__(self):
        self.api_client = DndApiClient()  # Hardcoded dependency
```

**Target Pattern: Constructor Injection**

```python
class DataManager:
    def __init__(
        self,
        api_client: DndApiClient | None = None,
        cache_dir: str = CACHE_DIR,
        worlds_dir: str = WORLDS_DIR,
    ) -> None:
        self.api_client = api_client or DndApiClient()
        self._cache_dir = cache_dir
        self._worlds_dir = worlds_dir
```

This allows tests to inject mock dependencies:

```python
def test_data_manager_load(tmp_path):
    mock_api = MockApiClient()
    dm = DataManager(
        api_client=mock_api,
        cache_dir=str(tmp_path / "cache"),
        worlds_dir=str(tmp_path / "worlds"),
    )
    # ... test without hitting real API or filesystem
```

**Priority order for DI conversion:**

| Class | Dependencies to Inject | Priority |
|-------|----------------------|----------|
| `DataManager` | `DndApiClient`, directory paths | High |
| `NpcSheet` | `DataManager` (already injected) | Done |
| `CombatTracker` | `DataManager` (already injected) | Done |
| `MainWindow` | `DataManager`, `PlayerWindow` | Medium |
| `SessionTab` | `DataManager` | Medium |
| `MapTab` | `DataManager` | Medium |
| `DatabaseTab` | `DataManager` | Medium |
| `MindMapTab` | `DataManager` | Medium |
| `EntitySidebar` | `DataManager` | Medium |
| `SoundpadPanel` | Audio engine | Low |

**Note:** Most UI widgets already receive `data_manager` in their constructor, which is a form of dependency injection. The improvement here is making the injection explicit and consistent, and adding the ability to inject secondary dependencies (API client, event bus, etc.).

### 6.4 API Client Consolidation (Weeks 16-17)

**Current State:**

`core/api_client.py` (705 LOC) contains 4 classes with significant code duplication:

- `Dnd5eApiSource.parse_monster()` (~150 LOC) and `Open5eApiSource.parse_monster()` (~100 LOC) share ~80% logic.
- `Dnd5eApiSource.parse_spell()` and `Open5eApiSource.parse_spell()` share ~70% logic.
- Both sources have independent `parse_dispatcher()` methods with the same structure.

**Target State:**

A shared parsing framework with source-specific field mappers:

```
core/api/
  __init__.py
  client.py              # DndApiClient orchestrator
  base_source.py         # ApiSource base class
  dnd5e_source.py        # Dnd5eApiSource
  open5e_source.py       # Open5eApiSource
  field_mappers.py       # Shared field mapping configuration
  entity_parser.py       # Shared parsing logic with mapper injection
```

**Shared parsing approach:**

```python
# core/api/entity_parser.py
from __future__ import annotations
from typing import Any


class FieldMapper:
    """Maps raw API field names to internal entity field names."""

    def __init__(self, mapping: dict[str, str]) -> None:
        self._mapping = mapping

    def get(self, raw_key: str, default: str = "") -> str:
        return self._mapping.get(raw_key, default)


class MonsterParser:
    """Parses monster data from any API source using a field mapper."""

    def __init__(self, mapper: FieldMapper, source_label: str) -> None:
        self._mapper = mapper
        self._source = source_label

    def parse(self, data: dict[str, Any]) -> dict[str, Any]:
        return {
            "name": data.get("name"),
            "type": "Monster",
            "description": self._build_description(data),
            "source": self._source,
            "stats": self._parse_stats(data),
            "combat_stats": self._parse_combat_stats(data),
            "traits": self._parse_action_list(data, self._mapper.get("traits_key")),
            "actions": self._parse_action_list(data, self._mapper.get("actions_key")),
            # ... etc.
        }

    def _parse_stats(self, data: dict[str, Any]) -> dict[str, int]:
        return {
            "STR": data.get("strength", 10),
            "DEX": data.get("dexterity", 10),
            "CON": data.get("constitution", 10),
            "INT": data.get("intelligence", 10),
            "WIS": data.get("wisdom", 10),
            "CHA": data.get("charisma", 10),
        }
```

**Dnd5e-specific mapper:**

```python
DND5E_MONSTER_MAPPER = FieldMapper({
    "traits_key": "special_abilities",
    "actions_key": "actions",
    "ac_key": "armor_class",
    "speed_key": "speed",
    "image_key": "image",
    "image_base_url": "https://www.dnd5eapi.co",
})
```

**Open5e-specific mapper:**

```python
OPEN5E_MONSTER_MAPPER = FieldMapper({
    "traits_key": "special_abilities",
    "actions_key": "actions",
    "ac_key": "armor_class",
    "speed_key": "speed",
    "image_key": "img_main",
    "image_base_url": "",
})
```

This eliminates the duplicated parsing logic while still supporting source-specific field variations.

### 6.5 Phase 4 Checklist

| Task | Files | Effort | Week |
|------|-------|--------|------|
| Create EventBus class | 1 new file | 2 hours | 14 |
| Migrate entity lifecycle events to bus | 5 files | 1 day | 14 |
| Migrate theme/language events to bus | 3 files | 4 hours | 14 |
| Create CombatPresenter (MVP for combat) | 1 new file | 1 day | 15 |
| Create NpcPresenter (MVP for NPC sheet) | 1 new file | 1 day | 15 |
| Add DI to DataManager | 1 file | 2 hours | 16 |
| Add DI to all tab constructors | 4 files | 4 hours | 16 |
| Split api_client.py into package | 6 new files | 1 day | 16 |
| Create shared field mappers | 1 new file | 4 hours | 17 |
| Create shared entity parser | 1 new file | 1 day | 17 |
| Migrate Dnd5eSource to shared parser | 1 file | 4 hours | 17 |
| Migrate Open5eSource to shared parser | 1 file | 4 hours | 17 |

**Phase 4 Exit Criteria:**

- EventBus handles all cross-cutting concerns (entity lifecycle, theme changes).
- Direct signal forwarding chains are replaced with bus subscriptions.
- CombatTracker and NpcSheet follow MVP pattern.
- DataManager accepts injected dependencies.
- API parsing duplication is eliminated through shared parsers.
- All existing tests pass.

---

## 7. Phase 5: Testing & Documentation (Weeks 18-20)

### 7.1 Test Coverage Targets

**Current State:**

| Category | Coverage |
|----------|----------|
| Core modules | ~25% (3 of 12 modules partially tested) |
| UI modules | ~10% (3 of 23 modules partially tested) |
| Dev modules | ~90% (all modules well tested) |
| Overall | ~6.2% test-to-production LOC ratio |

**Target State:**

| Category | Target Coverage | Priority Tests |
|----------|----------------|----------------|
| Core data (DataManager, repositories) | >80% line coverage | Entity CRUD, session management, campaign I/O |
| Core API (client, parsers) | >70% line coverage | Parse logic, error handling, source switching |
| Core models | >90% line coverage | Schema validation, default structures |
| UI widgets (data logic only) | >60% line coverage | Data roundtrip, state serialization |
| UI tabs (integration) | >40% line coverage | Tab lifecycle, signal propagation |
| UI dialogs | >30% line coverage | Dialog result values, input validation |
| **Overall** | **>60% line coverage** | |

#### Per-module test plan:

**Priority 1: Core data modules (Week 18)**

| Module | New Tests Needed | Test Focus |
|--------|-----------------|------------|
| `core/entity_repository.py` | 8 tests | Create, read, update, delete, auto-source, mentions |
| `core/session_repository.py` | 5 tests | Create, get, save, active session |
| `core/campaign_manager.py` | 6 tests | Load MsgPack, load JSON, create, migrate, path fixing |
| `core/settings_manager.py` | 4 tests | Load, save, corrupt file handling |
| `core/library_manager.py` | 4 tests | Cache load, save, search, catalog refresh |
| `core/map_data_manager.py` | 6 tests | Pin CRUD, timeline CRUD, chain color update |
| `core/models.py` | 3 tests | Default structure, schema completeness |

**Priority 2: API parsing (Week 18)**

| Module | New Tests Needed | Test Focus |
|--------|-----------------|------------|
| `core/api/entity_parser.py` | 6 tests | Monster, spell, equipment parsing with mock data |
| `core/api/dnd5e_source.py` | 4 tests | List fetching, detail fetching, error handling |
| `core/api/open5e_source.py` | 4 tests | List fetching, detail fetching, error handling |

**Priority 3: UI data logic (Week 19)**

| Module | New Tests Needed | Test Focus |
|--------|-----------------|------------|
| `ui/widgets/npc_data_binder.py` | 5 tests | Data roundtrip (populate then collect preserves data) |
| `ui/widgets/combat_model.py` | 8 tests | Add/remove combatants, initiative sort, turn advancement, HP changes, conditions |
| `ui/widgets/encounter_manager.py` | 4 tests | Save/load encounter state |
| `core/theme_manager.py` | 3 tests | Palette retrieval, unknown theme fallback |

**Priority 4: Integration tests (Week 19-20)**

| Scenario | Test Focus |
|----------|------------|
| Entity lifecycle | Create entity -> display in sidebar -> open in NpcSheet -> edit -> save -> verify persistence |
| Combat flow | Add combatants -> roll initiative -> advance turns -> apply damage -> serialize state |
| Theme switching | Switch theme -> verify palette applied -> verify no visual errors |
| Campaign load | Load MsgPack -> verify all data sections populated -> verify migration |

### 7.2 Docstring Standards and Templates

**Required docstrings for:**

- Every module (at the top of each `.py` file)
- Every public class
- Every public method with non-trivial logic
- Every function

**Template for module docstrings:**

```python
"""Brief one-line description of the module's purpose.

Longer description if needed, explaining the module's role
in the application architecture and its key classes/functions.

Example usage:
    from core.entity_repository import EntityRepository
    repo = EntityRepository(get_data, save_callback, fetch_details)
    eid = repo.save(None, {"name": "Goblin", "type": "Monster"})
"""
```

**Template for class docstrings:**

```python
class EntityRepository:
    """CRUD operations for entities within a campaign.

    This class manages the lifecycle of entity records, including
    creation with auto-generated IDs, updates, deletion, and
    source attribution.

    Attributes:
        entities: Read-only view of the current entity dictionary.
    """
```

**Template for method docstrings:**

```python
def save(
    self,
    eid: str | None,
    data: dict[str, Any],
    should_save: bool = True,
    auto_source_update: bool = True,
) -> str:
    """Save an entity to the campaign data store.

    If eid is None, a new UUID is generated. If the entity already
    exists, its data is merged with the provided data dict.

    Args:
        eid: Entity ID. If None, a new ID is generated.
        data: Entity data dictionary matching the EntityData schema.
        should_save: If True, persist to disk immediately.
        auto_source_update: If True, append the world name to the source field.

    Returns:
        The entity ID (new or existing).

    Raises:
        OSError: If should_save is True and disk write fails.
    """
```

**Template for signal docstrings (in class docstring):**

```python
class NpcSheet(QWidget):
    """Entity detail sheet widget.

    Signals:
        request_open_entity(str): Emitted when user clicks a linked entity.
            The argument is the entity ID to navigate to.
        data_changed(): Emitted when any form field is modified.
        save_requested(): Emitted when user presses Ctrl+S or clicks Save.
    """
```

### 7.3 Automated Quality Gates

**Tool Configuration:**

#### mypy (static type checking)

```ini
# mypy.ini
[mypy]
python_version = 3.10
warn_return_any = True
warn_unused_configs = True
disallow_untyped_defs = True
disallow_incomplete_defs = True
ignore_missing_imports = True

[mypy-PyQt6.*]
ignore_missing_imports = True

[mypy-msgpack.*]
ignore_missing_imports = True
```

#### ruff (linting and formatting)

```toml
# ruff.toml
target-version = "py310"
line-length = 100

[lint]
select = [
    "E",    # pycodestyle errors
    "W",    # pycodestyle warnings
    "F",    # pyflakes
    "I",    # isort
    "N",    # pep8-naming
    "UP",   # pyupgrade
    "B",    # flake8-bugbear
    "S",    # flake8-bandit (security)
    "C4",   # flake8-comprehensions
    "DTZ",  # flake8-datetimez
    "T20",  # flake8-print (catch stray print statements)
    "RUF",  # ruff-specific rules
]
ignore = [
    "S101",  # assert used (ok in tests)
    "S603",  # subprocess call (ok in dev_run.py)
]

[lint.per-file-ignores]
"tests/**" = ["S101"]
```

#### pytest-cov (coverage measurement)

```ini
# pytest.ini or pyproject.toml
[tool.pytest.ini_options]
addopts = "--cov=core --cov=ui --cov-report=term-missing --cov-report=html"
```

#### pre-commit hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.4.0
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.9.0
    hooks:
      - id: mypy
        additional_dependencies: [types-requests]
        args: [--ignore-missing-imports]

  - repo: local
    hooks:
      - id: pytest-fast
        name: pytest (fast)
        entry: python -m pytest tests/ -x -q --no-header
        language: system
        pass_filenames: false
        always_run: true
```

#### GitHub Actions CI pipeline

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.10'
      - run: pip install -r requirements.txt -r requirements-dev.txt
      - run: python -m ruff check .
      - run: python -m mypy core/ --ignore-missing-imports
      - run: python -m pytest tests/ --cov=core --cov=ui --cov-fail-under=60
```

### 7.4 Phase 5 Checklist

| Task | Files | Effort | Week |
|------|-------|--------|------|
| Write tests for core data modules | 7 test files | 2 days | 18 |
| Write tests for API parsing | 3 test files | 1 day | 18 |
| Write tests for UI data logic | 4 test files | 2 days | 19 |
| Write integration tests | 2 test files | 1 day | 19 |
| Add docstrings to all core modules | 12 files | 1 day | 19 |
| Add docstrings to all UI modules | 23 files | 2 days | 20 |
| Configure mypy | 1 config file | 1 hour | 20 |
| Configure ruff | 1 config file | 1 hour | 20 |
| Configure pre-commit hooks | 1 config file | 1 hour | 20 |
| Set up GitHub Actions CI | 1 workflow file | 2 hours | 20 |
| Fix all mypy and ruff errors | All files | 1 day | 20 |

**Phase 5 Exit Criteria:**

- Test coverage >60% overall, >80% on core business logic.
- Every public class and method has a docstring.
- mypy passes on all core modules.
- ruff passes with zero errors.
- Pre-commit hooks configured and working.
- GitHub Actions CI pipeline runs on every push.

---

## 8. Per-File Improvement Matrix

This matrix lists every production file with specific improvements needed, estimated effort, priority level, and dependencies on other tasks.

**Priority levels:**

- **P0** -- Blocking: Must be done before other improvements
- **P1** -- Critical: Should be done in the first two phases
- **P2** -- Important: Should be done in phases 3-4
- **P3** -- Nice-to-have: Can be done in phase 5 or later

**Effort scale:**

- **XS** -- Less than 1 hour
- **S** -- 1-4 hours
- **M** -- 1 day
- **L** -- 2-3 days
- **XL** -- 1 week+

### 8.1 Root Module Files

#### `main.py` (387 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Replace Turkish fallback `"Bilinmiyor"` (line 46) with `tr("NAME_UNKNOWN")` | 1 | P1 | XS | None |
| 2 | Add `from __future__ import annotations` | 1 | P1 | XS | None |
| 3 | Initialize logging framework in `run_application()` | 1 | P0 | S | log_config.py |
| 4 | Replace `print()` calls (lines 346, 349) with `logger.info()` | 1 | P1 | XS | #3 |
| 5 | Add docstrings to all methods | 5 | P3 | S | None |
| 6 | Inject EventBus into MainWindow constructor | 4 | P2 | S | EventBus |

#### `config.py` (147 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add return type annotations to all functions | 1 | P1 | XS | None |
| 2 | Add `from __future__ import annotations` | 1 | P1 | XS | None |
| 3 | No Turkish comments (already clean) | - | - | - | - |

#### `dev_run.py` (436 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Already well-typed and documented | - | - | - | - |
| 2 | Extract shared `EXCLUDED_DIRS` to config constant (shared with `dump.py`) | 5 | P3 | XS | None |

### 8.2 Core Module Files

#### `core/data_manager.py` (677 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add type hints to all 45 methods | 1 | P0 | M | TypedDict definitions |
| 2 | Replace all `print()` calls (~10) with `logger` | 1 | P1 | S | log_config.py |
| 3 | Replace bare `except` in `load_settings()` | 1 | P1 | XS | None |
| 4 | Translate all Turkish comments (~8) | 1 | P1 | S | None |
| 5 | Extract SettingsManager | 2 | P1 | S | Type hints done |
| 6 | Extract EntityRepository | 2 | P1 | S | Type hints done |
| 7 | Extract SessionRepository | 2 | P1 | S | Type hints done |
| 8 | Extract MapDataManager | 2 | P1 | S | Type hints done |
| 9 | Extract CampaignManager | 2 | P1 | M | Type hints done |
| 10 | Extract LibraryManager | 2 | P1 | M | Type hints done |
| 11 | Slim to facade | 2 | P1 | S | #5-#10 |
| 12 | Add DI for api_client and paths | 4 | P2 | S | #11 |
| 13 | Add docstrings to all methods | 5 | P3 | M | #11 |
| 14 | Write comprehensive tests (>80% coverage) | 5 | P1 | L | #11 |

#### `core/api_client.py` (705 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add type hints to all methods | 1 | P1 | M | None |
| 2 | Replace `print()` calls (~5) with `logger` | 1 | P1 | XS | log_config.py |
| 3 | Replace bare `except` in `parse_dispatcher()` | 1 | P1 | XS | None |
| 4 | Translate all Turkish comments (~15) | 1 | P1 | S | None |
| 5 | Split into `core/api/` package | 4 | P2 | M | None |
| 6 | Create shared field mappers | 4 | P2 | S | #5 |
| 7 | Create shared entity parser | 4 | P2 | M | #5, #6 |
| 8 | Eliminate duplicated parse_monster logic | 4 | P2 | M | #7 |
| 9 | Add docstrings to all methods | 5 | P3 | M | #5 |
| 10 | Write parse logic tests (>70% coverage) | 5 | P1 | M | #7, #8 |

#### `core/models.py` (197 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Replace Turkish default `"Yeni Kayit"` with English or `tr()` | 1 | P1 | XS | None |
| 2 | Add type hints to `get_default_entity_structure()` | 1 | P1 | XS | None |
| 3 | Convert to TypedDict or dataclass definitions | 4 | P2 | M | None |
| 4 | Add schema validation function | 4 | P2 | S | #3 |
| 5 | Write tests for schema completeness | 5 | P1 | S | None |

#### `core/library_fs.py` (250 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add type hints to all functions | 1 | P1 | S | None |
| 2 | No Turkish comments (already clean) | - | - | - | - |
| 3 | Add `from __future__ import annotations` | 1 | P1 | XS | None |

#### `core/locales.py` (26 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add type hints to `tr()` function | 1 | P1 | XS | None |
| 2 | Add logging for missing translation keys in debug mode | 1 | P2 | XS | log_config.py |

#### `core/theme_manager.py` (284 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Translate Turkish docstrings and comments (~20) | 1 | P1 | S | None |
| 2 | Add return type to `get_palette()` | 1 | P1 | XS | None |
| 3 | Convert class to module-level dict + function | 3 | P3 | S | None |
| 4 | Implement base palette with theme-specific overrides | 3 | P2 | M | None |
| 5 | Write tests for palette retrieval | 5 | P2 | S | None |

### 8.3 Core Audio Files

#### `core/audio/engine.py` (327 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Translate Turkish docstrings (~10) | 1 | P1 | S | None |
| 2 | Complete type hints (partially done) | 1 | P1 | S | None |
| 3 | Fix QPropertyAnimation cleanup in `crossfade_to()` | 2 | P2 | S | None |
| 4 | Add error handling for missing audio files | 2 | P2 | S | None |
| 5 | Add docstrings to all methods | 5 | P3 | S | None |

#### `core/audio/loader.py` (286 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Translate Turkish comments (~10) | 1 | P1 | S | None |
| 2 | Add type hints to all methods | 1 | P1 | S | None |
| 3 | Move `import time` to module level | 1 | P3 | XS | None |
| 4 | Extract recursive helpers for deep YAML parsing | 2 | P3 | S | None |

#### `core/audio/models.py` (36 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Translate Turkish docstrings (~2) | 1 | P1 | XS | None |
| 2 | Already uses dataclasses with type hints (good) | - | - | - | - |

### 8.4 Core Dev Files

#### `core/dev/hot_reload_manager.py` (348 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Replace `print()` with `logger` (~5) | 1 | P2 | XS | log_config.py |
| 2 | Already excellent: type hints, tests, docstrings | - | - | - | - |

#### `core/dev/ipc_bridge.py` (164 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Narrow `except Exception` to specific types in cleanup | 1 | P2 | XS | None |
| 2 | Replace `print()` with `logger` (~3) | 1 | P2 | XS | log_config.py |

### 8.5 UI Tab Files

#### `ui/tabs/database_tab.py` (296 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add type hints to all methods | 1 | P1 | S | None |
| 2 | Translate Turkish comments (~5) | 1 | P1 | XS | None |
| 3 | Remove hardcoded CSS (lines 38-43) | 3 | P1 | S | QSS theme updates |
| 4 | Extract API ID parsing logic from `open_entity_tab()` | 2 | P2 | S | None |
| 5 | Add docstrings | 5 | P3 | S | None |

#### `ui/tabs/session_tab.py` (272 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Fix `hasattr(tr, "KEY")` bug (lines 118, 122, 268-269) | 1 | P0 | XS | None |
| 2 | Replace hardcoded Turkish string (line 256) | 1 | P1 | XS | Locale file update |
| 3 | Add type hints to all methods | 1 | P1 | S | None |
| 4 | Translate Turkish comments (~1) | 1 | P1 | XS | None |
| 5 | Split `init_ui()` into `_build_left_panel()` and `_build_right_panel()` | 2 | P2 | S | None |
| 6 | Move combatant format migration to persistence layer | 2 | P2 | S | DataManager decomposition |
| 7 | Write tests for session load/save | 5 | P2 | S | None |

#### `ui/tabs/map_tab.py` (271 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add type hints to all methods | 1 | P1 | S | None |
| 2 | Translate Turkish comments (~5) | 1 | P1 | XS | None |
| 3 | Break up long one-liner statements (lines 120, 182, 190, 245) | 1 | P2 | S | None |
| 4 | Extract timeline manager from map rendering | 4 | P3 | M | None |

#### `ui/tabs/mind_map_tab.py` (617 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Replace bare `except: pass` in `process_pending_entity_saves()` (line 470) | 1 | P0 | XS | None |
| 2 | Add type hints to all methods across 4 classes | 1 | P1 | M | None |
| 3 | Translate Turkish comments (~10) | 1 | P1 | S | None |
| 4 | Extract `MindMapScene` and `CustomGraphicsView` to separate files | 2 | P2 | M | None |
| 5 | Reduce `MindMapScene` responsibilities (separate serialization from interaction) | 4 | P2 | M | #4 |
| 6 | Add docstrings to all classes | 5 | P3 | S | None |

### 8.6 UI Widget Files

#### `ui/widgets/npc_sheet.py` (1,002 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Remove redundant `ThemeManager` import (line 40) | 1 | P3 | XS | None |
| 2 | Add type hints to all 46 methods | 1 | P0 | M | TypedDict defs |
| 3 | Translate Turkish comments (~5) | 1 | P1 | XS | None |
| 4 | Write characterization tests (data roundtrip) | 2 | P0 | M | None |
| 5 | Extract ImageGalleryWidget | 2 | P1 | M | #4 |
| 6 | Extract PdfManagerWidget | 2 | P1 | S | #4 |
| 7 | Extract LinkedEntityWidget | 2 | P1 | S | #4 |
| 8 | Extract NpcDataBinder | 2 | P1 | M | #4 |
| 9 | Decompose `init_ui()` into helper methods | 2 | P1 | S | #5-#8 |
| 10 | Slim to orchestrator (~300 LOC) | 2 | P1 | S | #5-#9 |
| 11 | Create NpcPresenter for MVP | 4 | P2 | M | #10 |
| 12 | Add comprehensive docstrings | 5 | P3 | M | #10 |

#### `ui/widgets/combat_tracker.py` (912 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Replace bare `except` in `clean_stat_value()` (line 26) | 1 | P1 | XS | None |
| 2 | Add type hints to all methods | 1 | P1 | M | None |
| 3 | Translate Turkish comments (~5) | 1 | P1 | XS | None |
| 4 | Write characterization tests (state serialization) | 2 | P0 | M | None |
| 5 | Extract DraggableCombatTable to own file | 2 | P1 | XS | None |
| 6 | Extract CombatModel | 2 | P1 | M | #4 |
| 7 | Extract EncounterManager | 2 | P1 | S | #4 |
| 8 | Extract BattleMapBridge | 2 | P2 | S | #4 |
| 9 | Slim to orchestrator (~200 LOC) | 2 | P1 | S | #5-#8 |
| 10 | Create CombatPresenter for MVP | 4 | P2 | M | #9 |
| 11 | Add comprehensive docstrings | 5 | P3 | M | #9 |

#### `ui/widgets/entity_sidebar.py` (332 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Remove duplicate Turkish translation maps (lines 49-57, 257-263) | 1 | P1 | S | Locale file update |
| 2 | Add type hints to all methods | 1 | P1 | S | None |
| 3 | Translate Turkish comments (~5) | 1 | P1 | XS | None |
| 4 | Remove hardcoded CSS (lines 25, 33, 113-116) | 3 | P1 | S | QSS updates |
| 5 | Add `refresh_theme()` method | 3 | P1 | S | #4 |
| 6 | Add docstrings | 5 | P3 | S | None |

#### `ui/widgets/mind_map_items.py` (455 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add type hints to all methods | 1 | P1 | S | None |
| 2 | Translate Turkish comments (~5) | 1 | P1 | XS | None |
| 3 | Extract rendering constants from `paint()` methods | 2 | P3 | S | None |
| 4 | Document bezier curve math in `ConnectionLine` | 5 | P3 | XS | None |

#### `ui/widgets/markdown_editor.py` (415 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add type hints to all methods | 1 | P1 | S | None |
| 2 | Translate Turkish comments (~3) | 1 | P1 | XS | None |
| 3 | Remove hardcoded CSS from MentionPopup (lines 18-27) | 3 | P1 | S | QSS updates |
| 4 | Document entity link format (`entity://eid`) | 5 | P3 | XS | None |

#### `ui/widgets/map_viewer.py` (232 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add type hints to all methods | 1 | P1 | S | None |
| 2 | Translate Turkish comments (~5) | 1 | P1 | XS | None |
| 3 | Make text truncation length configurable (currently hardcoded to 10) | 3 | P3 | XS | None |

#### `ui/widgets/projection_manager.py` (231 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add type hints to all methods | 1 | P1 | S | None |
| 2 | Translate Turkish comments (~2) | 1 | P1 | XS | None |
| 3 | This file is the reference implementation for theme-aware widgets | - | - | - | - |

#### `ui/widgets/image_viewer.py` (55 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add type hints to all methods | 1 | P2 | XS | None |
| 2 | Translate Turkish comments (~2) | 1 | P1 | XS | None |

#### `ui/widgets/aspect_ratio_label.py` (68 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add type hints to all methods | 1 | P2 | XS | None |
| 2 | Clean and well-structured (no Turkish comments) | - | - | - | - |

### 8.7 UI Dialog Files

#### `ui/dialogs/import_window.py` (422 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Replace bare `except` in import handling (line 162) | 1 | P1 | XS | None |
| 2 | Add type hints to all methods | 1 | P1 | S | None |
| 3 | Translate Turkish comments (~5) | 1 | P1 | XS | None |
| 4 | Move `LibraryScanWorker` to `ui/workers.py` | 2 | P2 | S | None |
| 5 | Reduce UI pattern duplication with `api_browser.py` | 4 | P3 | M | None |

#### `ui/dialogs/api_browser.py` (490 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Replace bare `except` clauses (multiple) | 1 | P1 | S | None |
| 2 | Add type hints to all methods | 1 | P1 | S | None |
| 3 | Translate Turkish comments (~5) | 1 | P1 | XS | None |
| 4 | Remove hardcoded CSS (various elements) | 3 | P1 | S | QSS updates |
| 5 | Decompose `init_ui()` (129 lines) | 2 | P2 | S | None |

#### `ui/dialogs/bulk_downloader.py` (290 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add type hints to all methods | 1 | P1 | S | None |
| 2 | Translate Turkish comments (~5) | 1 | P1 | XS | None |
| 3 | Remove hardcoded CSS for progress bar | 3 | P2 | S | QSS updates |
| 4 | Reduce nesting in `DownloadWorker.run()` | 2 | P2 | S | None |

#### `ui/dialogs/encounter_selector.py` (211 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Replace bare `except` in encounter loading (line 92) | 1 | P1 | XS | None |
| 2 | Add type hints to all methods | 1 | P1 | S | None |
| 3 | Translate Turkish comments (~3) | 1 | P1 | XS | None |

#### `ui/dialogs/entity_selector.py` (121 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Remove duplicate `self.table = QTableWidget()` line (line 35-36) | 1 | P3 | XS | None |
| 2 | Add type hints to all methods | 1 | P2 | XS | None |
| 3 | Translate Turkish comments (~2) | 1 | P1 | XS | None |
| 4 | Remove hardcoded CSS for table styling | 3 | P2 | S | QSS updates |

#### `ui/dialogs/timeline_entry.py` (134 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add type hints to all methods | 1 | P2 | XS | None |
| 2 | Translate Turkish comments (~2) | 1 | P1 | XS | None |

#### `ui/dialogs/theme_builder.py` (187 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add type hints to all methods | 1 | P2 | S | None |
| 2 | Translate Turkish comments (~2) | 1 | P1 | XS | None |

### 8.8 UI Window and Panel Files

#### `ui/windows/battle_map_window.py` (762 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add type hints to all methods across 6 classes | 1 | P1 | M | None |
| 2 | Translate Turkish comments (~5) | 1 | P1 | XS | None |
| 3 | Remove hardcoded CSS for sidebar and toolbar | 3 | P1 | S | QSS updates |
| 4 | Extract `FogItem` and `BattleTokenItem` to `ui/widgets/battle_map/` | 2 | P2 | M | None |
| 5 | Implement strategy pattern for fog painting vs token dragging | 4 | P3 | M | #4 |
| 6 | Add docstrings to all 6 classes | 5 | P3 | M | None |
| 7 | Write tests for fog state serialization | 5 | P2 | S | None |

#### `ui/soundpad_panel.py` (439 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add type hints to all methods | 1 | P1 | S | None |
| 2 | Translate Turkish comments (~10) | 1 | P1 | S | None |
| 3 | Decompose `init_ui()` (~100 lines) into helper methods | 2 | P2 | S | None |
| 4 | Add docstrings | 5 | P3 | S | None |

### 8.9 UI Infrastructure Files

#### `ui/main_root.py` (162 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add type hints, especially return type of `create_root_widget()` | 1 | P1 | S | None |
| 2 | Translate Turkish comments (~2) | 1 | P1 | XS | None |
| 3 | Return NamedTuple instead of dict | 4 | P2 | S | None |
| 4 | Decompose into helper functions | 2 | P3 | S | None |

#### `ui/campaign_selector.py` (123 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Translate Turkish comment (line 1) | 1 | P1 | XS | None |
| 2 | Add type hints to all methods | 1 | P2 | XS | None |
| 3 | Add guard for missing WORLDS_DIR | 1 | P2 | XS | None |

#### `ui/player_window.py` (147 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add type hints to all methods | 1 | P2 | XS | None |
| 2 | Translate Turkish comments (~2) | 1 | P1 | XS | None |
| 3 | Add bounds checking for multi-image navigation | 1 | P2 | XS | None |

#### `ui/workers.py` (71 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Add type hints to all worker `run()` methods | 1 | P2 | XS | None |
| 2 | Add docstrings | 5 | P3 | XS | None |

### 8.10 Build and Utility Files

#### `dump.py` (113 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Share `EXCLUDED_DIRS` with `dev_run.py` | 5 | P3 | XS | None |
| 2 | Already well-documented | - | - | - | - |

#### `installer/build.py` (101 LOC)

| # | Improvement | Phase | Priority | Effort | Dependencies |
|---|-------------|-------|----------|--------|--------------|
| 1 | Translate Turkish comments (~2) | 1 | P1 | XS | None |
| 2 | Add type hints to all functions | 1 | P2 | XS | None |

---

## 9. Risk Assessment

### 9.1 Risk Matrix

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| R1 | Regression in data persistence during DataManager decomposition | Medium | Critical | Write characterization tests before extraction; verify data roundtrip after each step |
| R2 | Signal/slot connections break when classes are split | Medium | High | Map all signal connections before splitting; use delegation pattern to preserve connections |
| R3 | Theme migration introduces visual regressions across themes | High | Medium | Test every theme after each CSS change; use screenshot comparison |
| R4 | Type hint annotations are incorrect, causing IDE/developer confusion | Low | Medium | Run mypy after every batch of annotations; review annotated files |
| R5 | Large refactoring PRs cause merge conflicts with feature work | Medium | High | Keep PRs small (<300 lines); coordinate with feature development schedule |
| R6 | Performance regression from added indirection layers (facades, presenters) | Low | Medium | Profile before/after for hot paths (save, load, render); indirection cost is negligible for I/O-bound code |
| R7 | Loss of working features during god class decomposition | Medium | Critical | Keep original class as facade; never remove a public method from the facade until all callers are migrated |
| R8 | Test infrastructure setup delays (CI, pre-commit, coverage) | Low | Low | Set up tooling early (Week 1); iterate on configuration |
| R9 | Developer fatigue from sustained refactoring effort | Medium | High | Celebrate milestones; alternate refactoring with feature work; track metrics to show progress |
| R10 | MsgPack/JSON data format compatibility during migration changes | Low | Critical | Never change the serialized data format; refactoring is code-only |

### 9.2 Detailed Mitigation Strategies

#### R1: Data Persistence Regression

**Scenario:** During DataManager decomposition, a method is moved incorrectly and data is not saved or loaded properly.

**Mitigation:**

1. **Before extraction:** Create a reference campaign data file and write a test that:
   - Loads the campaign
   - Verifies all data sections are present
   - Modifies an entity, session, and map pin
   - Saves the campaign
   - Reloads and verifies all changes persisted

2. **During extraction:** Run this test after each extraction step. If it fails, revert the last step.

3. **After extraction:** Keep the test permanently as a regression guard.

**Example test:**

```python
def test_data_roundtrip(tmp_path):
    """Verify that all data survives a save/load cycle."""
    dm = DataManager(cache_dir=str(tmp_path / "cache"), worlds_dir=str(tmp_path / "worlds"))
    dm.create_campaign("TestWorld")

    # Create entities of each type
    eid = dm.save_entity(None, {"name": "Goblin", "type": "Monster", "combat_stats": {"hp": "10"}})

    # Create sessions
    sid = dm.create_session("Session 1")

    # Save and reload
    dm.save_data()
    dm2 = DataManager(cache_dir=str(tmp_path / "cache"), worlds_dir=str(tmp_path / "worlds"))
    dm2.load_campaign(dm.current_campaign_path)

    # Verify everything survived
    assert dm2.data["entities"][eid]["name"] == "Goblin"
    assert dm2.data["entities"][eid]["combat_stats"]["hp"] == "10"
    assert any(s["id"] == sid for s in dm2.data["sessions"])
```

#### R2: Signal/Slot Connection Breakage

**Scenario:** A signal is defined in a class that gets extracted. The parent widget no longer has direct access to the signal.

**Mitigation:**

1. **Before splitting:** Create a signal connection inventory for the class being split:
   - List every signal defined on the class
   - List every slot connected to external signals
   - List every external widget that connects to this class's signals

2. **During splitting:** Use signal forwarding in the facade:

```python
class NpcSheet(QWidget):
    # Preserve the original signal at the facade level
    data_changed = pyqtSignal()

    def __init__(self, data_manager):
        self.image_gallery = ImageGalleryWidget(data_manager)
        # Forward sub-widget signals through the facade
        self.image_gallery.image_changed.connect(self.data_changed.emit)
```

3. **After splitting:** Verify all signal connections by manually triggering each action in the UI and confirming the expected response occurs.

#### R7: Loss of Working Features

**Scenario:** A method is extracted but a caller that was not identified continues to call the original (now-removed) method.

**Mitigation:**

1. **Never remove methods from the facade.** Add deprecation warnings instead:

```python
import warnings

class DataManager:
    def save_entity(self, eid, data, should_save=True, auto_source_update=True):
        """Deprecated: Use self.entities.save() directly."""
        warnings.warn(
            "DataManager.save_entity() is deprecated. Use DataManager.entities.save().",
            DeprecationWarning,
            stacklevel=2,
        )
        return self._entity_repo.save(eid, data, should_save, auto_source_update)
```

2. **Search for all callers** before removing any method:

```bash
grep -rn "\.save_entity(" --include="*.py" .
```

3. **Remove deprecated methods only after all callers are migrated** and no warnings appear during a full application run.

### 9.3 Rollback Strategy

Every phase should be developed on a feature branch. If a phase introduces unacceptable regressions:

1. **Revert the branch** to the last known-good state.
2. **Identify the specific step** that introduced the regression.
3. **Fix the step** in isolation and re-apply.

Never merge a phase branch that has failing tests or broken application startup.

---

## 10. Success Metrics

### 10.1 Quantitative Metrics

Track these metrics before, during, and after each phase:

| Metric | Current | Phase 1 Target | Phase 2 Target | Phase 3 Target | Phase 4 Target | Phase 5 Target |
|--------|---------|---------------|---------------|---------------|---------------|---------------|
| **Production LOC** | 13,818 | ~13,900 (slight increase from `__init__.py` and log config) | ~14,500 (new files from splits, but each smaller) | ~14,200 (CSS removal offsets additions) | ~15,000 (new pattern files) | ~15,500 (test files) |
| **Max file LOC** | 1,002 | 1,002 | <400 | <400 | <400 | <400 |
| **Max class methods** | 46 | 46 | <20 | <20 | <20 | <20 |
| **Files with type hints** | 4/35 | 35/35 | 45/45 (new files) | 45/45 | 55/55 | 55/55 |
| **Type hint coverage (functions)** | ~5% | >95% | >95% | >95% | >95% | 100% |
| **Files with bare `except`** | 8 | 0 | 0 | 0 | 0 | 0 |
| **Files with Turkish comments** | 28 | 0 | 0 | 0 | 0 | 0 |
| **Files with hardcoded CSS** | 7 | 7 | 7 | 0 | 0 | 0 |
| **`print()` calls** | ~30 | 0 | 0 | 0 | 0 | 0 |
| **Test files** | 12 | 12 | 15 | 15 | 15 | 25+ |
| **Test functions** | ~45 | ~45 | ~75 | ~75 | ~80 | ~130 |
| **Test LOC** | 858 | ~900 | ~1,600 | ~1,700 | ~1,800 | ~3,000 |
| **Test coverage (line)** | ~6% | ~8% | ~30% | ~35% | ~45% | >60% |
| **Docstring coverage** | <15% | <15% | ~30% | ~35% | ~40% | >80% |
| **mypy errors** | Not measurable | 0 on core/ | 0 on all | 0 on all | 0 on all | 0 on all |
| **ruff errors** | Not measured | - | - | - | - | 0 |

### 10.2 Qualitative Metrics

These are assessed through manual review:

| Metric | Current | Target |
|--------|---------|--------|
| **New developer onboarding time** | ~1 week to understand codebase | <2 days with documentation |
| **Time to add a new entity type** | Modify 3-4 files with implicit contracts | Modify 1 model file + auto-generated UI |
| **Time to fix a data persistence bug** | Search through 677 LOC DataManager | Look at <100 LOC in the relevant repository |
| **Theme switching quality** | Inconsistent (7 files with hardcoded CSS) | Consistent across all themes |
| **Confidence in refactoring** | Low (no type safety, minimal tests) | High (type errors caught at edit time, tests catch regressions) |

### 10.3 Measurement Cadence

| When | What | Tool |
|------|------|------|
| Every PR | Test pass rate, mypy errors | CI pipeline |
| Every PR | Lines changed, files touched | Git stats |
| Weekly | Test coverage percentage | `pytest-cov` |
| Per phase | Full metrics table update | Manual review |
| Per phase | Qualitative assessment | Code review |

### 10.4 Phase Completion Criteria Summary

| Phase | Duration | Key Exit Criteria |
|-------|----------|------------------|
| Phase 1 | Weeks 1-4 | 0 bare excepts, 0 print(), 0 Turkish comments, >95% type hint coverage |
| Phase 2 | Weeks 5-10 | No class >400 LOC or >20 methods, characterization tests for all splits |
| Phase 3 | Weeks 11-13 | 0 hardcoded CSS, consistent theme switching |
| Phase 4 | Weeks 14-17 | EventBus operational, MVP for 2+ components, API parsing deduplicated |
| Phase 5 | Weeks 18-20 | >60% test coverage, >80% docstring coverage, CI pipeline green |

### 10.5 Long-Term Vision (Post-Roadmap)

After completing all five phases, the codebase will be in a strong position for:

1. **Plugin architecture** -- With DI and event bus in place, external plugins can subscribe to events and inject custom behavior.
2. **Online multiplayer** -- With clean MVC separation, the model layer can be synchronized across network connections.
3. **Mobile companion app** -- With the model layer separated from Qt, it can be reused with a different UI framework.
4. **Automated testing CI/CD** -- With comprehensive tests and quality gates, continuous deployment becomes feasible.
5. **Community contributions** -- With English documentation, type safety, and clear architecture, external contributors can work confidently.

---

## Appendix A: New Files Created by This Roadmap

| Phase | New File | Purpose |
|-------|---------|---------|
| 1 | `core/__init__.py` | Package marker |
| 1 | `ui/__init__.py` | Package marker |
| 1 | `ui/tabs/__init__.py` | Package marker |
| 1 | `ui/widgets/__init__.py` | Package marker |
| 1 | `ui/dialogs/__init__.py` | Package marker |
| 1 | `ui/windows/__init__.py` | Package marker |
| 1 | `core/log_config.py` | Logging framework configuration |
| 2 | `core/settings_manager.py` | Settings persistence |
| 2 | `core/entity_repository.py` | Entity CRUD |
| 2 | `core/session_repository.py` | Session CRUD |
| 2 | `core/map_data_manager.py` | Map pin/timeline CRUD |
| 2 | `core/campaign_manager.py` | Campaign I/O and migration |
| 2 | `core/library_manager.py` | Library cache management |
| 2 | `ui/widgets/image_gallery.py` | Image gallery widget |
| 2 | `ui/widgets/pdf_manager.py` | PDF management widget |
| 2 | `ui/widgets/linked_entity_widget.py` | Linked entity widget |
| 2 | `ui/widgets/npc_form_layout.py` | NPC form builder |
| 2 | `ui/widgets/npc_data_binder.py` | NPC data binding |
| 2 | `ui/widgets/combat_model.py` | Combat state management |
| 2 | `ui/widgets/combat_table.py` | Draggable combat table |
| 2 | `ui/widgets/encounter_manager.py` | Encounter persistence |
| 2 | `ui/widgets/battle_map_bridge.py` | Combat-map integration |
| 3 | `core/theme_constants.py` | Theme sizing/spacing constants |
| 4 | `core/event_bus.py` | Publish-subscribe event bus |
| 4 | `core/api/__init__.py` | API package marker |
| 4 | `core/api/client.py` | API client orchestrator |
| 4 | `core/api/base_source.py` | API source base class |
| 4 | `core/api/dnd5e_source.py` | D&D 5e API source |
| 4 | `core/api/open5e_source.py` | Open5e API source |
| 4 | `core/api/field_mappers.py` | Shared field mapping config |
| 4 | `core/api/entity_parser.py` | Shared entity parsing logic |
| 4 | `ui/widgets/combat_presenter.py` | Combat MVP presenter |
| 4 | `ui/widgets/npc_presenter.py` | NPC MVP presenter |
| 5 | `.pre-commit-config.yaml` | Pre-commit hook configuration |
| 5 | `.github/workflows/ci.yml` | GitHub Actions CI pipeline |
| 5 | `mypy.ini` | mypy configuration |
| 5 | `ruff.toml` | ruff configuration |
| 5 | Multiple test files | Test coverage expansion |

**Total new files:** ~40 (including test files)

---

## Appendix B: Glossary

| Term | Definition |
|------|-----------|
| **God class** | A class with too many responsibilities, making it hard to understand, test, and modify |
| **Characterization test** | A test that captures the current behavior of existing code, used as a safety net during refactoring |
| **MVP (Model-View-Presenter)** | Architecture pattern separating data (Model), display (View), and interaction logic (Presenter) |
| **DI (Dependency Injection)** | Passing dependencies to a class via its constructor rather than creating them internally |
| **Facade** | A class that provides a simplified interface to a complex subsystem |
| **QSS** | Qt Style Sheets -- CSS-like styling language for Qt widgets |
| **TypedDict** | Python type annotation for dictionaries with known key-value types |
| **Event bus** | A publish-subscribe messaging system for decoupled component communication |
| **Field mapper** | A configuration object that maps raw API field names to internal field names |
| **Pre-commit hook** | A script that runs automatically before each git commit to enforce code quality |

---

## Appendix C: Reference Files

These existing files demonstrate the target code quality and should be used as templates:

| File | What It Demonstrates |
|------|---------------------|
| `core/library_fs.py` | Small focused functions, clear docstrings, structured error reporting |
| `core/dev/hot_reload_manager.py` | Comprehensive type hints, excellent test coverage, clean architecture |
| `core/audio/models.py` | Proper dataclass usage with type annotations |
| `config.py` | Dependency injection for testability, clear documentation |
| `ui/widgets/projection_manager.py` | Theme-aware widget pattern (correct way to handle styling) |
| `dev_run.py` | Full type hints, proper argparse usage, clean state management |
| `core/dev/ipc_bridge.py` | Factory method pattern, proper cleanup, normalized response format |

---

*End of Improvement Roadmap*
