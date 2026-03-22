# Readability Concept — Dungeon Master Tool

> **Document Status:** Active
> **Last Updated:** 2026-03-22
> **Scope:** Full codebase readability audit, coding standards, and incremental improvement roadmap
> **Principle:** All refactoring must be system-safe — no behavioral changes, no public API renames between sessions

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Codebase Audit](#2-codebase-audit)
3. [Coding Standards Guide](#3-coding-standards-guide)
4. [Priority Refactoring Targets](#4-priority-refactoring-targets)
5. [Module Explanation Files](#5-module-explanation-files)
6. [Incremental Migration Rules](#6-incremental-migration-rules)
7. [Type Hint Rollout Plan](#7-type-hint-rollout-plan)
8. [Test Coverage Goals](#8-test-coverage-goals)
9. [Tooling Recommendations](#9-tooling-recommendations)

---

## 1. Executive Summary

### Why Readability Matters Now

The Dungeon Master Tool is entering its most critical architectural phase: the transition from a mature offline desktop application to a hybrid online/offline platform. This means new contributors, new modules, and increased complexity. Code that is already difficult to follow will become a significant bottleneck as the EventManager abstraction, server backend, and real-time sync layers are introduced.

Readability improvements are not cosmetic. They directly reduce:
- **Onboarding time** for new contributors
- **Bug surface** from misunderstood logic
- **Refactoring risk** when methods are undocumented and monolithic
- **Review time** in pull requests

### Current State Assessment

| Metric | Current | Target |
|---|---|---|
| Docstring coverage (core/) | ~20% | ≥90% |
| Type hint coverage (public methods) | ~15% | ≥95% |
| Methods >60 lines | 12+ identified | 0 |
| Mixed-language comments (TR/EN) | ~30% of comment lines | 0% |
| Consistent logging (vs. raw print) | 0% | 100% |
| Import organization compliance | ~20% of files | 100% |
| Linting tool (ruff) | Not configured | Enforced in CI |

### Goal State

A codebase where:
- Any method can be understood in isolation by reading its docstring and type signature
- Every module has a module-level docstring explaining its purpose and relationships
- All internal comments are in English
- Errors are logged uniformly, never silently swallowed
- New files automatically match the project standard through tooling enforcement
- Refactoring confidence is high because test coverage supports it

---

## 2. Codebase Audit

### 2.1 File Inventory with Severity Ratings

#### Core Directory

| File | LOC | Severity | Primary Issues |
|---|---|---|---|
| `core/data_manager.py` | 677 | HIGH | 20% docstring coverage, no type hints, raw `print()` errors, large state dict |
| `core/api_client.py` | 705 | HIGH | No type hints, `parse_monster()` is 94-line monolith, Turkish comments, silent failure |
| `core/models.py` | 197 | MEDIUM | Missing docstrings on schema fields, no type aliases |
| `core/audio/engine.py` | 327 | MEDIUM | Missing docstrings, some magic numbers |
| `core/audio/loader.py` | 286 | MEDIUM | Missing docstrings |
| `core/theme_manager.py` | 284 | LOW | Mostly clean, missing module docstring |
| `core/library_fs.py` | 250 | MEDIUM | Undocumented path logic |
| `core/dev/hot_reload_manager.py` | 348 | LOW | Already well-documented |
| `core/dev/ipc_bridge.py` | 164 | LOW | Small and clear |
| `core/locales.py` | 26 | LOW | Tiny, fine as-is |

#### UI Directory

| File | LOC | Severity | Primary Issues |
|---|---|---|---|
| `ui/widgets/npc_sheet.py` | 1002 | CRITICAL | Monolithic `populate_sheet()`, no docstrings, duplicate imports, 48 undocumented methods |
| `ui/widgets/combat_tracker.py` | 912 | CRITICAL | God-class pattern, compact one-liner logic, semicolons, no docstrings |
| `ui/windows/battle_map_window.py` | 762 | HIGH | Large methods, minimal documentation |
| `ui/tabs/mind_map_tab.py` | 617 | HIGH | Magic numbers, undocumented state |
| `ui/dialogs/api_browser.py` | 490 | MEDIUM | Mixed import order, missing docstrings |
| `ui/soundpad_panel.py` | 439 | MEDIUM | Magic volume default, no docstrings |
| `ui/dialogs/import_window.py` | 422 | MEDIUM | Missing docstrings |
| `ui/widgets/mind_map_items.py` | 455 | MEDIUM | Missing docstrings, tight coupling |
| `ui/widgets/markdown_editor.py` | 415 | LOW | Relatively clean structure |

---

### 2.2 Issue Category Breakdown

#### A. Missing Docstrings

**Severity: HIGH across all core files**

`core/data_manager.py` has 45 methods with approximately 9 docstrings. Many existing docstrings are in Turkish.

*Examples of undocumented methods:*
```python
# data_manager.py — no docstring
def _fix_absolute_paths(self):
    if not self.current_campaign_path: return
    changed = False
    # ... complex path-rewriting logic with no explanation

# data_manager.py — Turkish docstring
def _save_reference_cache(self):
    """Kütüphane indeksini MsgPack (.dat) olarak kaydeder."""
```

*Target pattern:*
```python
def _fix_absolute_paths(self) -> None:
    """Rewrite any absolute image/asset paths stored in campaign data.

    When a campaign folder is moved or copied, stored paths may point to the
    old location. This method scans all entity image references and updates
    them to be relative to the current campaign folder.

    Modifies ``self.data`` in-place and sets the campaign dirty flag.
    """
```

---

#### B. No Type Hints

**Severity: HIGH in core/, MEDIUM in UI**

`core/api_client.py` has zero return type annotations on its public interface:

```python
# Current — no types
def get_list(self, category, page=1, filters=None):
def get_details(self, category, index):
def parse_monster(self, data):
def search(self, category, query):

# Target
def get_list(
    self,
    category: str,
    page: int = 1,
    filters: dict[str, str] | None = None,
) -> dict[str, Any]:
def get_details(self, category: str, index: str) -> dict[str, Any] | None:
def parse_monster(self, data: dict[str, Any]) -> dict[str, Any]:
def search(self, category: str, query: str) -> list[dict[str, str]]:
```

---

#### C. Overly Long Methods

**Severity: CRITICAL in `npc_sheet.py` and `combat_tracker.py`**

`api_client.py::parse_monster()` is 94 lines handling AC parsing, speed parsing, saves/skills extraction, action formatting, dependency detection, and image URL detection — all as one function. This should be decomposed:

```python
# Current (94 lines, one method)
def parse_monster(self, data: dict) -> dict:
    # 2. Hız Parse (Speed Parse)          ← Turkish comment
    speed_dict = data.get("speed", {})
    # 3. Saves & Skills Parse
    saves, skills = [], []
    for prof in data.get("proficiencies", []):
        name = prof.get("proficiency", {}).get("name", "")
        val = prof.get("value", 0)
        sign = "+" if val >= 0 else ""
        # ... 20 more lines of mixed logic

# Target (decomposed)
def parse_monster(self, data: dict[str, Any]) -> dict[str, Any]:
    """Parse a raw Open5e monster payload into internal entity format."""
    return {
        "speed": self._parse_speed(data),
        "saves_skills": self._parse_saves_and_skills(data),
        "actions": self._parse_actions(data),
        "ac": self._parse_armor_class(data),
        "image_url": self._detect_image_url(data),
    }

def _parse_speed(self, data: dict[str, Any]) -> str: ...
def _parse_saves_and_skills(self, data: dict[str, Any]) -> dict[str, list[str]]: ...
def _parse_actions(self, data: dict[str, Any]) -> list[dict[str, str]]: ...
def _parse_armor_class(self, data: dict[str, Any]) -> str: ...
def _detect_image_url(self, data: dict[str, Any]) -> str | None: ...
```

`ui/widgets/npc_sheet.py` has a `populate_sheet()` method that renders an entire NPC card in one pass. It should be split by section:

```python
# Target structure
def populate_sheet(self, entity: dict[str, Any]) -> None:
    """Populate all sections of the sheet from entity data."""
    self._populate_header(entity)
    self._populate_stats(entity)
    self._populate_traits(entity)
    self._populate_actions(entity)
    self._populate_spells(entity)
    self._populate_images(entity)
    self._populate_links(entity)
```

`ui/widgets/combat_tracker.py` — the `update_combatant_row()` and `handle_drop_import()` methods should each be decomposed into validation, transformation, and display sub-steps.

---

#### D. Mixed Turkish/English Comments

**Severity: MEDIUM** — affects all core files and many UI files

All inline comments and docstrings must be in English. Turkish section markers are common:

```python
# Before (Turkish markers)
# 2. Hız Parse (Speed Parse)
# YENİ: Bu kısım yeni eklendi
# Başlangıçta varsayılan palet (Dark)

# After (English only)
# Speed parsing — converts dict {"walk": "30 ft"} to display string
# NEW: Added in v0.7.5 to support multi-speed creatures
# Default palette on startup: always Dark theme
```

---

#### E. Inconsistent Import Organization

**Severity: MEDIUM** — widespread

`ui/widgets/npc_sheet.py` lines 1–17 demonstrate the anti-pattern:
- PyQt6 imports split across line 1 and line 16 (duplicate import block)
- Standard library `os` placed after third-party imports
- No blank-line separators between import groups

*Required order (PEP 8 + project standard):*
```python
# 1. Standard library
import os
from pathlib import Path
from typing import Any

# 2. Third-party
import msgpack

# 3. Qt (third-party but grouped separately for clarity)
from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtGui import QPixmap
from PyQt6.QtWidgets import (
    QDialog,
    QHBoxLayout,
    QLabel,
    QVBoxLayout,
    QWidget,
)

# 4. Local application
from config import CACHE_DIR
from core.locales import tr
from core.models import ENTITY_SCHEMAS
from core.theme_manager import ThemeManager
from ui.dialogs.api_browser import ApiBrowser
from ui.workers import ImageDownloadWorker
from ui.widgets.aspect_ratio_label import AspectRatioLabel
from ui.widgets.markdown_editor import MarkdownEditor
```

---

#### F. Inconsistent Error Handling

**Severity: MEDIUM** — core files

Three incompatible patterns currently coexist:

```python
# Pattern 1 — print with context (data_manager.py)
except Exception as e:
    print(f"Cache DAT load error: {e}")
    self.reference_cache = {}

# Pattern 2 — print with Turkish prefix (api_client.py)
except Exception as e:
    print(f"Dnd5e Details Error: {e}")
    return None

# Pattern 3 — silent failure (api_client.py)
except Exception:
    return []
```

*Target: structured logging (see Section 3.5)*

```python
import logging
logger = logging.getLogger(__name__)

# All files
except Exception:
    logger.exception("Failed to load cache from %s", CACHE_FILE_DAT)
    self.reference_cache = {}
```

---

#### G. Magic Numbers and Hardcoded Values

**Severity: LOW** — cosmetic but confusing

```python
# mind_map_tab.py
grid_size = 40          # What is 40? pixels? grid units?

# combat_tracker.py
zoom_in = 1.15          # Arbitrary zoom step
zoom_out = 1 / 1.15    # Why not just 0.87?

# projection_manager.py
self.setFixedSize(50, 36)   # Undocumented magic dimensions

# soundpad_panel.py
self.audio_brain.set_master_volume(0.5)  # No explanation for default
```

*Target:*
```python
# mind_map_tab.py
GRID_CELL_PX = 40  # Width/height of a single grid cell in pixels

# combat_tracker.py
ZOOM_STEP_FACTOR = 1.15  # 15% zoom per scroll step — matches common VTT conventions

# projection_manager.py
PROJECTION_BUTTON_W = 50  # px — compact to fit sidebar
PROJECTION_BUTTON_H = 36  # px — matches standard icon button height

# soundpad_panel.py
DEFAULT_MASTER_VOLUME = 0.5  # 50% — safe default, avoids loud startup surprise
```

---

#### H. Tight Coupling in DataManager

**Severity: MEDIUM** — architectural, affects online transition

`DataManager.__init__` owns a large mutable state dict, an API client instance, a library cache, and campaign path tracking — all in one object. This violates the Single Responsibility Principle and makes testing individual concerns hard.

```python
# Current — one __init__ with everything
self.data = {"world_name": "", "entities": {}, "map_data": {...}, ...}
self.api_client = DndApiClient()
self.reference_cache = {}
self.library_tree = {}
self.current_campaign_path = None
```

*Recommended refactoring direction (phased, non-breaking):*
- Extract `CampaignState` dataclass to own the `self.data` dict and dirty-flag logic
- Extract `LibraryCache` to own `reference_cache` and `library_tree`
- Keep `DataManager` as the coordinator that delegates to these objects
- `DndApiClient` is already a separate class — preserve this boundary

This decomposition aligns with the EventManager abstraction planned for online integration.

---

## 3. Coding Standards Guide

This section defines the mandatory conventions for all new and refactored code in this project. Existing code should be migrated to these standards incrementally following the priority order in Section 4.

### 3.1 Import Organization

All files must organize imports in exactly this order with blank-line separators:

```
1. Standard library (os, sys, pathlib, typing, logging, json, ...)
2. Third-party packages (requests, msgpack, pydantic, ...)
3. Qt (PyQt6) — grouped separately despite being third-party
4. Local application imports (config, core.*, ui.*)
```

Rules:
- Never split a single import group across multiple import blocks
- Use `from X import Y` for specific names; use `import X` for modules used as namespaces
- Alphabetize within each group
- Never use wildcard imports (`from X import *`)

### 3.2 Type Hints

All **public** methods and functions must have complete type annotations:

```python
# Required: parameter types + return type
def load_campaign(self, folder: str | Path) -> bool: ...

# Required even for None returns
def clear_session(self) -> None: ...

# Use built-in generics (Python 3.10+)
def get_entities(self, entity_type: str) -> list[dict[str, Any]]: ...
def find_entity(self, entity_id: str) -> dict[str, Any] | None: ...

# Use TypeAlias for recurring types
EntityDict = dict[str, Any]
def get_all(self) -> list[EntityDict]: ...
```

Rules:
- Private methods (leading underscore) should also have type hints where practical
- Use `from __future__ import annotations` only if needed for forward references
- Prefer `X | Y` union syntax over `Optional[X]` or `Union[X, Y]`
- Use `from typing import Any` for untyped external data (JSON payloads, etc.)

### 3.3 Docstrings

All public modules, classes, and methods must have docstrings. Use **Google style**:

```python
"""Module-level docstring.

One-paragraph description of what this module does, what problem it solves,
and how it relates to other modules.

Typical usage:
    manager = DataManager()
    manager.load_campaign("/path/to/campaign")
"""

class DataManager:
    """Central data access and persistence layer for campaign data.

    Manages campaign loading/saving, entity CRUD operations, and coordinates
    with DndApiClient for external data. Acts as the single source of truth
    for all in-memory campaign state.

    The manager emits no signals directly — state changes propagate through
    the EventManager abstraction layer.

    Attributes:
        data: The complete in-memory campaign state dictionary.
        current_campaign_path: Absolute path to the active campaign folder,
            or None if no campaign is loaded.
    """

    def load_campaign(self, folder: str) -> bool:
        """Load a campaign from the given folder path.

        Reads the campaign JSON file, populates self.data, and triggers
        path-fix logic for relocated campaigns.

        Args:
            folder: Absolute path to the campaign directory. Must contain
                a valid campaign JSON file.

        Returns:
            True if the campaign loaded successfully, False otherwise.

        Raises:
            FileNotFoundError: If the folder does not exist.
        """
```

Rules:
- Module docstrings go at the very top of the file, before imports
- Single-line docstrings are acceptable for trivial private methods
- Always document `Args`, `Returns`, and `Raises` for public methods with non-obvious behavior
- Never duplicate the function signature in the docstring body

### 3.4 Naming Conventions

| Context | Convention | Examples |
|---|---|---|
| Variables | `snake_case` | `entity_id`, `campaign_path` |
| Functions/methods | `snake_case` | `load_campaign()`, `_parse_speed()` |
| Classes | `PascalCase` | `DataManager`, `NpcSheet` |
| Constants (module-level) | `UPPER_SNAKE_CASE` | `GRID_CELL_PX`, `DEFAULT_VOLUME` |
| Qt signals | `snake_case` (PyQt6 convention) | `data_changed`, `save_requested` |
| Private methods | `_snake_case` | `_fix_absolute_paths()` |
| Type aliases | `PascalCase` | `EntityDict`, `CampaignData` |

**Prohibited patterns:**
- Abbreviated names: `btn_add_img` → `add_image_button`; `lbl_name` → `name_label`
- Turkish identifiers or comments anywhere in the codebase
- Single-letter variables outside of list comprehensions and short loops
- Hungarian notation: `strName`, `intCount`

**Exception:** PyQt6 widget naming in `__init__` may use short forms (`self.name_edit`, `self.save_button`) as long as they are in English and unambiguous.

### 3.5 Error Handling and Logging

Replace all `print()` statements with structured logging. Configure the logger at the module level:

```python
import logging
logger = logging.getLogger(__name__)
```

**Logging levels:**
- `logger.debug(...)` — detailed state for developers (disabled in production)
- `logger.info(...)` — significant events (campaign loaded, session started)
- `logger.warning(...)` — recoverable issues (cache miss, API timeout, fallback used)
- `logger.error(...)` — failures that affect user experience but don't crash the app
- `logger.exception(...)` — use inside `except` blocks; automatically includes the traceback

```python
# WRONG — bare print
except Exception as e:
    print(f"Cache DAT load error: {e}")
    self.reference_cache = {}

# WRONG — silent swallow
except Exception:
    return []

# CORRECT
except OSError:
    logger.warning("Cache file missing or unreadable, starting empty: %s", CACHE_FILE_DAT)
    self.reference_cache = {}

# CORRECT — unexpected errors
except Exception:
    logger.exception("Unexpected error loading campaign from %s", folder)
    return False
```

**Rules:**
- Never catch `Exception` silently without at least a `logger.warning`
- Prefer catching specific exception types (`OSError`, `ValueError`, `KeyError`) over `Exception`
- Always log the affected resource (file path, entity ID, URL) as a structured argument, not in the message string
- Use `%s` formatting in log messages, not f-strings (lazy evaluation)

### 3.6 Constants

Magic numbers must be extracted into named constants with explanatory comments:

```python
# WRONG
self.audio_brain.set_master_volume(0.5)
zoom_in = 1.15

# CORRECT (module-level or class-level)
DEFAULT_MASTER_VOLUME = 0.5   # 50% — avoids loud startup surprise for new users
ZOOM_STEP_FACTOR = 1.15       # 15% per scroll step — matches standard VTT convention
```

### 3.7 Method Length

Methods exceeding 40 lines are candidates for decomposition. Methods exceeding 60 lines **must** be decomposed before the file is considered refactored.

Decomposition strategy:
1. Identify logical phases within the method (parsing, validation, transformation, rendering)
2. Extract each phase into a private helper method with a clear name
3. The parent method becomes a high-level coordinator that reads like a summary

---

## 4. Priority Refactoring Targets

### Tier 1 — CRITICAL (Do First)

These files are the most-read, most-modified, and have the highest complexity. Refactoring them yields the greatest return and unblocks the EventManager integration.

#### 4.1 `ui/widgets/npc_sheet.py` (1002 lines)

**Goal:** Decompose `populate_sheet()` into section-specific methods; add docstrings to all 48 methods; fix duplicate import block; rename abbreviated widget variables.

**Decomposition plan:**
```
NpcSheet
├── _populate_header(entity)       # Name, category, tags
├── _populate_stats(entity)        # STR/DEX/CON/INT/WIS/CHA + derived stats
├── _populate_traits(entity)       # Traits, languages, proficiencies
├── _populate_actions(entity)      # Actions, bonus actions, reactions, legendary
├── _populate_spells(entity)       # Spell list with slot tracking
├── _populate_images(entity)       # Image carousel
└── _populate_links(entity)        # Linked spells, items, battlemaps
```

**Import fix:** Merge the two PyQt6 import blocks; move `import os` to top; sort alphabetically.

**Estimated effort:** 4–6 hours

---

#### 4.2 `ui/widgets/combat_tracker.py` (912 lines)

**Goal:** Decompose `update_combatant_row()` and `handle_drop_import()`, add docstrings, eliminate semicolons and compact one-liner logic.

**Decomposition plan:**
```
CombatTracker
├── _build_combatant_widget(combatant)     # Creates the row widget
├── _update_hp_display(row, combatant)     # HP bar + label
├── _update_conditions_display(row, combatant)  # Condition chips
├── _validate_drop_data(mime_data)         # Returns parsed entity or None
├── _import_entity_to_tracker(entity)     # Adds validated entity to rows
└── _tick_conditions_for(combatant)       # Duration decrement logic
```

**Estimated effort:** 4–5 hours

---

#### 4.3 `core/api_client.py` (705 lines)

**Goal:** Decompose `parse_monster()` into private helper methods; add type hints to all public methods; replace all Turkish comments; add module docstring.

**Decomposition plan:**
```
DndApiClient
├── parse_monster(data) → calls:
│   ├── _parse_armor_class(data) → str
│   ├── _parse_speed(data) → str
│   ├── _parse_saves_and_skills(data) → dict
│   ├── _parse_actions(data) → list
│   ├── _detect_dependencies(data) → list[str]
│   └── _detect_image_url(data) → str | None
├── _parse_weapon_subcategories(data) → list[str]  # Replaces 6 repetitive if-blocks
└── _build_display_name(data, category) → str
```

**Estimated effort:** 3–4 hours

---

### Tier 2 — HIGH (Do Second)

#### 4.4 `core/data_manager.py` (677 lines)

**Goal:** Add docstrings to all 45 methods, replace `print()` with `logger`, extract `CampaignState` concern, add type hints to the public API.

**Estimated effort:** 3–4 hours

---

#### 4.5 `ui/tabs/mind_map_tab.py` (617 lines)

**Goal:** Extract `GRID_CELL_PX` constant, document node state management, add docstrings.

**Estimated effort:** 2–3 hours

---

#### 4.6 `ui/soundpad_panel.py` (439 lines)

**Goal:** Extract volume/timing constants, add docstrings, fix import order.

**Estimated effort:** 1–2 hours

---

### Tier 3 — MEDIUM (Do Third)

These files need import cleanup, constant extraction, and docstring addition but have no critical structural issues.

| File | Primary Task | Estimated Effort |
|---|---|---|
| `ui/windows/battle_map_window.py` | Docstrings + method extraction | 2–3 hours |
| `ui/dialogs/api_browser.py` | Import sort + docstrings | 1–2 hours |
| `ui/dialogs/import_window.py` | Docstrings + constant extraction | 1–2 hours |
| `ui/widgets/mind_map_items.py` | Docstrings + coupling reduction | 2 hours |
| `core/audio/engine.py` | Docstrings + constant extraction | 1–2 hours |
| `core/audio/loader.py` | Docstrings | 1 hour |
| `core/library_fs.py` | Docstrings + type hints | 1–2 hours |
| `core/models.py` | Type aliases + field docstrings | 1 hour |

---

## 5. Module Explanation Files

Every Python module must have a **module-level docstring** as the very first string in the file (before all imports). This provides an in-editor summary visible on hover in IDEs and serves as the entry point for understanding a file.

### Required Module Docstring Format

```python
"""<module_name> — <one-line summary>.

<2-4 sentence expanded description of what this module does, what problem
it solves, and where it fits in the overall architecture.>

Key classes/functions:
    ClassName: Brief description of its role.
    function_name: Brief description.

Relationships:
    - Depends on: list key dependencies (e.g., core.models, config)
    - Used by: list key consumers (e.g., ui.tabs.database_tab, main.py)
    - Communicates via: signals, callbacks, or direct method calls
"""
```

### Module Docstring Backlog

All files listed below require a module docstring added as the first step of any refactoring pass:

**Core:**
- `core/data_manager.py` — Central campaign state and persistence coordinator
- `core/api_client.py` — Open5e API client and D&D 5e entity parser
- `core/models.py` — Entity schema definitions and data model constants
- `core/audio/engine.py` — MusicBrain layered audio state engine
- `core/audio/loader.py` — Audio file discovery and loading utilities
- `core/theme_manager.py` — Qt palette and QSS theme application
- `core/library_fs.py` — Local filesystem library indexing and cache management

**UI:**
- `ui/widgets/npc_sheet.py` — Full-featured entity card editor widget
- `ui/widgets/combat_tracker.py` — Initiative-based combat management widget
- `ui/windows/battle_map_window.py` — Fog-of-war battle map canvas and projection
- `ui/tabs/mind_map_tab.py` — Infinite canvas mind map with node editing
- `ui/soundpad_panel.py` — Soundpad trigger grid and audio control surface
- `ui/dialogs/api_browser.py` — Open5e API search and entity import dialog
- `ui/dialogs/import_window.py` — Campaign and entity import wizard

---

## 6. Incremental Migration Rules

Readability refactoring must never introduce behavioral regressions. Follow these rules strictly:

### Rule 1: Coverage Before Refactoring

Before refactoring any method that is not currently unit-tested, write a characterization test first. The test does not need to be comprehensive — it only needs to capture the current input/output contract so that a regression is detectable.

```python
# Characterization test example (test_api_client.py)
def test_parse_monster_speed_output_unchanged():
    """Ensure parse_monster produces the same speed string as before refactoring."""
    raw = {"speed": {"walk": "30 ft", "fly": "60 ft"}}
    result = client.parse_monster(raw)
    assert result["speed"] == "Walk 30 ft, Fly 60 ft"
```

### Rule 2: One Method Per Commit

Extract one method at a time. Each commit should be a single, complete extraction: the helper exists, the parent calls it, all tests pass. This minimizes the blast radius of errors and makes reverting trivial.

### Rule 3: No Public API Renames Between Sessions

When a method is part of the public interface (called from outside the class), it must not be renamed without updating all call sites in the same commit. Never leave a renamed public method undefined even temporarily.

### Rule 4: Preserve Signal Contracts

Qt signals (`pyqtSignal`) must not change their signature (parameter types) during refactoring. Any signal emitted in the original code must still be emitted with the same data after refactoring. Removing a signal emission is a behavioral change and requires explicit approval.

### Rule 5: Docstrings and Type Hints Are Additive

Adding docstrings and type hints is always safe — these are never behavioral changes. Prioritize these in early passes because they help validate that you understand the code correctly before restructuring it.

### Rule 6: Linting Must Pass Before Merging

Once `ruff` is configured (see Section 9), all modified files must pass linting before the PR is merged. Do not grandfather in new violations.

### Rule 7: Separate Formatting from Logic

Never mix reformatting (import sorting, line breaks, docstring addition) with logic changes in the same commit. One commit per concern — reviewers can then focus on the right diff.

---

## 7. Type Hint Rollout Plan

Type hints should be added in order of impact (most-used → least-used) and from lowest risk (no behavioral change) to highest risk (complex generics).

### Phase 1: Data Models (Week 1)

`core/models.py` — Add `TypeAlias` definitions for recurring types:

```python
from typing import TypeAlias, Any
EntityDict: TypeAlias = dict[str, Any]
EntitySchema: TypeAlias = dict[str, dict[str, Any]]
```

Add type hints to all schema definition functions (if any) and constants.

### Phase 2: API Client (Week 1–2)

`core/api_client.py` — Full type annotation pass:
- All public methods: `get_list`, `get_details`, `parse_monster`, `search`
- All private parser helpers once extracted (see Section 4.3)
- Return types for all `_parse_*` helpers

### Phase 3: Data Manager (Week 2–3)

`core/data_manager.py` — Full type annotation pass:
- Public CRUD methods: `get_entity`, `save_entity`, `delete_entity`
- Campaign lifecycle: `load_campaign`, `save_campaign`, `get_available_campaigns`
- Type the `self.data` dict with a `CampaignData` TypedDict

```python
from typing import TypedDict

class CampaignData(TypedDict):
    world_name: str
    entities: dict[str, EntityDict]
    map_data: MapData
    sessions: list[SessionData]
    last_active_session_id: str | None
    mind_maps: dict[str, Any]
```

### Phase 4: Audio Modules (Week 3)

`core/audio/engine.py` and `core/audio/loader.py` — Type hint all public methods.

### Phase 5: UI Widgets (Week 4+)

UI files are more complex due to Qt's dynamic type system. Prioritize:
1. `ui/widgets/npc_sheet.py` — public signals and `populate_sheet()`
2. `ui/widgets/combat_tracker.py` — public methods called from tabs
3. Remaining UI files — add hints incrementally during feature work

---

## 8. Test Coverage Goals

### Current State

- `tests/test_core/` — 5 test files (coverage unknown, assumed low)
- `tests/test_dev/` — 3 test files (hot reload infrastructure)
- `tests/test_ui/` — 3 test files (likely smoke tests only)

### Targets

| Layer | Current (est.) | Short-term Target | Long-term Target |
|---|---|---|---|
| `core/` | ~25% | ≥60% | ≥80% |
| `ui/` | ~10% | ≥30% | ≥50% |
| Overall | ~20% | ≥50% | ≥70% |

### Testing Strategy

#### Core Layer Tests (Unit)

Core modules (`data_manager`, `api_client`, `models`, `audio/`) should be fully unit-testable without a running Qt application. Use `pytest` with fixtures.

Priority test cases:
1. `DataManager` — campaign load/save round-trip, entity CRUD, path-fix logic
2. `DndApiClient` — `parse_monster()` with fixture payloads, all parser sub-methods
3. `LibraryFs` — index building, cache read/write round-trip
4. `AudioEngine` — state serialization/deserialization (critical for online sync)

#### UI Layer Tests (Integration)

PyQt6 widgets require a `QApplication` instance. Use `pytest-qt`:

```python
# tests/test_ui/test_npc_sheet.py
def test_populate_sheet_does_not_crash(qtbot):
    widget = NpcSheet()
    qtbot.addWidget(widget)
    entity = {"name": "Goblin", "entity_type": "npc", "stats": {}}
    widget.populate_sheet(entity)  # Must not raise
```

Focus UI tests on:
- Widget construction without crash
- Signal emission for key interactions
- `populate_sheet()` / `populate()` with edge-case data (empty, None fields)

#### Regression Tests (Before Refactoring)

Before any Tier 1 refactoring, add characterization tests capturing current behavior:
- `parse_monster()` output for 3–5 different monster types (spell caster, beast, legendary)
- `DataManager.load_campaign()` with a fixture campaign folder
- `CombatTracker` row state after adding/removing combatants

---

## 9. Tooling Recommendations

### 9.1 Ruff — Linting and Formatting

`ruff` is the recommended linter/formatter. It replaces `flake8`, `isort`, `pyupgrade`, and `black` in a single fast tool.

**Installation:**
```bash
pip install ruff
```

**Configuration** (`pyproject.toml` at project root):
```toml
[tool.ruff]
target-version = "py310"
line-length = 100

[tool.ruff.lint]
select = [
    "E",    # pycodestyle errors
    "F",    # pyflakes
    "I",    # isort
    "N",    # pep8-naming
    "UP",   # pyupgrade
    "B",    # flake8-bugbear
    "C4",   # flake8-comprehensions
    "SIM",  # flake8-simplify
]
ignore = [
    "E501",  # Line too long — ruff formatter handles this
]

[tool.ruff.lint.isort]
known-first-party = ["config", "core", "ui"]
section-order = ["future", "standard-library", "third-party", "first-party", "local-folder"]
```

**Usage:**
```bash
ruff check .          # Lint all files
ruff check --fix .    # Auto-fix safe violations
ruff format .         # Format all files
```

### 9.2 Mypy — Static Type Checking

Once type hints reach Phase 3 of the rollout plan, add `mypy` for static analysis:

```bash
pip install mypy
```

**Configuration** (`pyproject.toml`):
```toml
[tool.mypy]
python_version = "3.10"
warn_return_any = true
warn_unused_configs = true
ignore_missing_imports = true   # Qt stubs are incomplete

[[tool.mypy.overrides]]
module = "PyQt6.*"
ignore_missing_imports = true
```

Start with `--ignore-missing-imports` and a strict allowlist, then tighten progressively.

### 9.3 Pytest Configuration

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
python_functions = ["test_*"]
addopts = "--tb=short -q"
```

**Coverage reporting:**
```bash
pip install pytest-cov
pytest --cov=core --cov-report=term-missing
```

### 9.4 Pre-commit Hooks

Add a `.pre-commit-config.yaml` to enforce standards automatically on every commit:

```yaml
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
```

**Installation:**
```bash
pip install pre-commit
pre-commit install
```

Once installed, `ruff` and `mypy` run automatically on every `git commit`. This prevents standard violations from accumulating.

### 9.5 IDE Configuration

**VS Code** (`.vscode/settings.json`):
```json
{
    "[python]": {
        "editor.defaultFormatter": "charliermarsh.ruff",
        "editor.formatOnSave": true,
        "editor.codeActionsOnSave": {
            "source.fixAll.ruff": "explicit",
            "source.organizeImports.ruff": "explicit"
        }
    },
    "python.analysis.typeCheckingMode": "basic",
    "python.testing.pytestEnabled": true
}
```

---

## Appendix A: Refactoring Session Checklist

Use this checklist before marking any file as "refactored":

- [ ] Module-level docstring added
- [ ] All public methods have Google-style docstrings
- [ ] All public methods have complete type hints (parameters + return)
- [ ] All private methods have at minimum a single-line docstring
- [ ] No Turkish text anywhere in the file (comments, strings, docstrings)
- [ ] Import blocks organized: stdlib → third-party → Qt → local
- [ ] No duplicate import blocks
- [ ] No magic numbers (all extracted to named constants)
- [ ] No `print()` calls (replaced with `logger.*`)
- [ ] No silent `except Exception: pass` patterns
- [ ] All methods ≤60 lines
- [ ] `ruff check` passes with zero violations
- [ ] `ruff format` applied
- [ ] All pre-existing tests still pass
- [ ] New characterization tests added for any previously untested methods

---

## Appendix B: Quick Reference — Prohibited Patterns

```python
# ❌ Turkish comments
# Bu fonksiyon YENİ: varlık tipini ayarlar

# ❌ Silent failure
except Exception:
    pass

# ❌ Bare print for errors
print(f"Error loading cache: {e}")

# ❌ No type hints on public method
def load_campaign(self, folder):
    return True

# ❌ Magic number
grid_size = 40

# ❌ Method over 60 lines without decomposition
def populate_sheet(self):
    # 150 lines of mixed rendering logic
    ...

# ❌ Duplicate import block
from PyQt6.QtWidgets import QLabel
# ... 50 lines ...
from PyQt6.QtWidgets import QToolButton

# ❌ Disorganized import order
import os
from PyQt6.QtWidgets import QWidget
import requests
from config import CACHE_DIR
import json
```

```python
# ✅ English comments with context
# NEW in v0.7.5: entity type is now set at creation time and cannot be changed

# ✅ Specific exception with logging
except OSError:
    logger.warning("Cache file unreadable, starting fresh: %s", CACHE_FILE_DAT)

# ✅ Structured logging
logger.exception("Unexpected error loading campaign from %s", folder)

# ✅ Full type hint on public method
def load_campaign(self, folder: str) -> bool:

# ✅ Named constant
GRID_CELL_PX = 40  # Width/height of one grid cell in pixels

# ✅ Decomposed method
def populate_sheet(self, entity: EntityDict) -> None:
    self._populate_header(entity)
    self._populate_stats(entity)
    self._populate_actions(entity)

# ✅ Single, organized import block
import os
from PyQt6.QtWidgets import QLabel, QToolButton, QWidget
```
