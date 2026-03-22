# Pre-Online Sprint Plan — Dungeon Master Tool

> **Document Status:** Active
> **Last Updated:** 2026-03-22
> **Supersedes:** Portions of `docs/archive/SPRINT_MAP.md` (Sprint 1–2)
> **Companion Document:** `docs/PRE_ONLINE.md` (requirements reference)
> **Scope:** Sprint 1 retrospective + Sprint 2 detailed plan + remaining pre-online backlog

---

## Table of Contents

1. [Sprint Overview](#1-sprint-overview)
2. [Sprint 1 Retrospective — Mar 9–20](#2-sprint-1-retrospective--mar-9-20)
3. [Sprint 2 Plan — Mar 23–Apr 3](#3-sprint-2-plan--mar-23-apr-3)
4. [Pre-Online Backlog Roadmap](#4-pre-online-backlog-roadmap)
5. [Definition of Done](#5-definition-of-done)

---

## 1. Sprint Overview

### Timeline

| Sprint | Dates | Phase | Status |
|---|---|---|---|
| Sprint 1 | Mar 9–20, 2026 | Phase 0 — UI Foundation | **Completed** |
| Sprint 2 | Mar 23–Apr 3, 2026 | Phase 0 — Infrastructure | **Active** |
| Sprint 3 | Apr 6–17, 2026 | Phase 1 — Online begins | Planned |

### Sprint 1–2 Goals (Phase 0)

The pre-online phase has two sprints:

- **Sprint 1:** UI consolidation, EventManager skeleton, button standardization, GM Screen Control Panel
- **Sprint 2:** Embedded PDF viewer, Socket.io client skeleton, Event schema v1, Single Player Window

Both sprints must satisfy the **Stability Gate** defined in `docs/PRE_ONLINE.md §2` before Sprint 3 begins.

---

## 2. Sprint 1 Retrospective — Mar 9–20

*Sprint 1 ended March 20, 2026. This section records what was delivered, what was missed, and what carries over to Sprint 2.*

### 2.1 Planned vs. Delivered

#### Delivered ✅

*No Sprint 1 tasks were fully delivered. All planned work carries over to Sprint 2.*

#### Not Started / Dropped ❌

| Task | Reason | Decision |
|---|---|---|
| EventManager class | Sprint 1 capacity overestimated | Move to Sprint 2 — first priority |
| EventManager wired to DataManager | Depends on EventManager | Move to Sprint 2 |
| GM Screen Control Panel — skeleton | Sprint 1 capacity overestimated | Move to Sprint 2 |
| GM Screen Control Panel — functional | Depends on skeleton | Move to Sprint 2 |
| Button size standardization | Not implemented in QSS or widget code | Move to Sprint 2 |
| Module docstrings — core files | Not added to data_manager, api_client, or models | Move to Sprint 2 (readability track) |
| Import organization — core files | Import order not corrected | Move to Sprint 2 (readability track) |
| Single Player Window merge | Underestimated scope — requires architectural changes | Move to Sprint 2 |
| Soundpad transition smoothing | Deprioritized | Backlog (Post-Sprint 2) |
| Localization pass for new UI strings | No new UI strings to localize (no UI changes completed) | Move to Sprint 2 |

### 2.2 Sprint 1 Velocity

| Metric | Value |
|---|---|
| Story points planned | 34 |
| Story points completed | 0 |
| Completion rate | 0% |
| Carryover points | 34 |

> **Note:** Sprint 1 was spent on project planning, documentation, and architecture design rather than code implementation. All implementation work carries over to Sprint 2. Sprint 2's scope must be realistically adjusted to account for this full carryover.

### 2.3 Lessons Learned

1. **Planning and documentation take significant time.** The architecture design, documentation creation, and readability audit consumed Sprint 1 entirely — this investment is valuable but must be accounted for in velocity projections.
2. **Single Player Window is architectural, not cosmetic.** It cannot be done as a UI polish task; it needs dedicated sprint capacity.
3. **EventManager is a prerequisite for everything online.** It must be the first implementation priority in Sprint 2.
4. **Sprint 2 is overloaded.** With full Sprint 1 carryover plus Sprint 2's original scope, realistic prioritization is critical. Consider extending Sprint 2 or deferring non-essential items.

---

## 3. Sprint 2 Plan — Mar 23–Apr 3

Sprint 2 runs 10 business days (March 23 to April 3, 2026). This sprint completes the pre-online foundation and delivers the socket infrastructure skeleton needed for Phase 1.

### 3.1 Sprint 2 Goals

> **⚠️ Scope Warning:** Sprint 2 carries over ALL Sprint 1 tasks (34 points) plus its own planned scope. Realistic completion requires strict prioritization. Items marked with ★ are critical-path blockers for Sprint 3.

**Carryover from Sprint 1 (must-do first):**
1. ★ Create EventManager class (`core/event_manager.py`) — emit, subscribe, unsubscribe
2. ★ Wire EventManager to DataManager — all entity + session + combat events
3. Create GM Screen Control Panel skeleton (`ui/components/gm_control_panel.py`)

**Original Sprint 2 scope:**
4. Complete GM Screen Control Panel (functional quick-switch)
5. Merge Battle Map and Projection into a unified Single Player Window
6. Implement embedded PDF viewer
7. ★ Create Socket.io client with connection state machine
8. ★ Draft and validate Event schema v1
9. Complete DE/FR localization for all new UI strings

**Readability track (parallel, lower priority):**
10. Button size standardization in QSS themes
11. Module docstrings on core files
12. Import organization on core files

### 3.2 Day-by-Day Schedule

#### Week 1 (Mar 23–27)

---

**Monday, Mar 23 — Sprint kickoff + EventManager creation**

| # | Task | Files | Estimate |
|---|---|---|---|
| 1 | Create EventManager class with emit(), subscribe(), unsubscribe(), subscribe_all() | `core/event_manager.py` (CREATE) | 3h |
| 2 | Wire EventManager to DataManager — entity events (created, updated, deleted) | `core/data_manager.py` | 2h |
| 3 | Wire EventManager to DataManager — session events (created, activated) | `core/data_manager.py` | 1h |

**Acceptance:** `EventManager` class exists with full interface. Entity events emit correctly. Unit tests pass for EventManager dispatch and DataManager entity event emission.

---

**Tuesday, Mar 24 — GM Screen Control Panel completion**

| # | Task | Files | Estimate |
|---|---|---|---|
| 4 | Implement quick-switch buttons (Map / Card / Image / Blank) | `ui/components/gm_control_panel.py` | 3h |
| 5 | Add live preview thumbnail to control panel | `ui/components/gm_control_panel.py` | 2h |
| 6 | Add Lock toggle with visual indicator | `ui/components/gm_control_panel.py` | 1h |
| 7 | Connect control panel to EventManager projection events | `ui/components/gm_control_panel.py` | 1h |

**Acceptance:** DM can switch player window content using the control panel. Lock state persists across session save/load.

---

**Wednesday, Mar 25 — Single Player Window (Part 1)**

| # | Task | Files | Estimate |
|---|---|---|---|
| 8 | Create `PlayerWindow` class skeleton | `ui/player_window.py` | 2h |
| 9 | Implement Map Mode in PlayerWindow (migrate from battle_map_window) | `ui/player_window.py`, `ui/windows/battle_map_window.py` | 4h |

**Acceptance:** PlayerWindow in Map Mode renders the battle map correctly including fog-of-war. All existing map tests pass.

---

**Thursday, Mar 26 — Single Player Window (Part 2)**

| # | Task | Files | Estimate |
|---|---|---|---|
| 10 | Implement Content Mode in PlayerWindow (entity card, image, PDF placeholder) | `ui/player_window.py` | 3h |
| 11 | Window persistence (position/size/monitor saved in preferences) | `ui/player_window.py`, `config.py` | 2h |
| 12 | Full-screen toggle (F11 or configurable shortcut) | `ui/player_window.py` | 1h |

**Acceptance:** PlayerWindow Content Mode displays entity stat blocks and images. Window position is restored on next launch.

---

**Friday, Mar 27 — Single Player Window cleanup + tests**

| # | Task | Files | Estimate |
|---|---|---|---|
| 13 | Deprecate old projection window; update all references | `ui/widgets/projection_manager.py`, `main.py` | 2h |
| 14 | Add regression tests for PlayerWindow | `tests/test_ui/test_player_window.py` | 3h  |
| 15 | Week 1 integration smoke test | All modified files | 1h |

**Acceptance:** Old projection window is removed or marked deprecated. All 14 regression tests pass. No regressions in map or projection tests.

---

#### Week 2 (Mar 30–Apr 3)

---

**Monday, Mar 30 — Embedded PDF Viewer (Part 1)**

| # | Task | Files | Estimate |
|---|---|---|---|
| 16 | Add PyMuPDF dependency | `requirements.txt`, `installer/` | 30m |
| 17 | Create `PdfViewerWidget` — page rendering from local file | `ui/widgets/pdf_viewer.py` | 4h |
| 18 | Navigation controls (prev/next, page number input, fit-width/page) | `ui/widgets/pdf_viewer.py` | 2h |

**Acceptance:** A local `.pdf` file opens in the viewer. Navigation works without errors. A 50-page PDF opens within 2 seconds.

---

**Tuesday, Apr 1 — Embedded PDF Viewer (Part 2)**

| # | Task | Files | Estimate |
|---|---|---|---|
| 19 | Remote URL support — download to temp cache, stream large files | `ui/widgets/pdf_viewer.py`, `core/cache_utils.py` | 3h |
| 20 | Drag-and-drop `.pdf` onto viewer area | `ui/widgets/pdf_viewer.py` | 1h |
| 21 | Send current page to PlayerWindow | `ui/widgets/pdf_viewer.py`, `ui/windows/player_window.py` | 2h |

**Acceptance:** A remote PDF URL opens within 5 seconds (on 10 Mbps connection). "Send to Player" button shows the current page in PlayerWindow within 500ms.

---

**Wednesday, Apr 2 — Socket.io Client Skeleton**

| # | Task | Files | Estimate |
|---|---|---|---|
| 22 | Add `python-socketio[client]` dependency | `requirements.txt` | 15m |
| 23 | Create `NetworkBridge` class with connection state machine | `core/network/bridge.py` | 4h |
| 24 | Connection states: DISCONNECTED → CONNECTING → CONNECTED → ERROR | `core/network/bridge.py` | included |
| 25 | Subscribe to all EventManager events; log (don't send) in skeleton mode | `core/network/bridge.py` | 1h |
| 26 | UI status indicator — connection state badge in status bar | `ui/components/connection_status.py` | 2h |

**Acceptance:** NetworkBridge transitions through all 4 states. Attempting to connect to a non-existent server reaches ERROR state within 5 seconds. Status badge updates in real time.

---

**Thursday, Apr 3 — Event Schema v1 + Localization**

| # | Task | Files | Estimate |
|---|---|---|---|
| 27 | Draft Event schema v1 as Pydantic models | `core/network/events.py` | 3h |
| 28 | Event envelope: `event_id`, `event_type`, `session_id`, `sender_role`, `timestamp`, `payload` | `core/network/events.py` | included |
| 29 | DE/FR locale pass for all Sprint 1 + Sprint 2 new strings | `locales/de.yml`, `locales/fr.yml` | 2h |
| 30 | Sprint 2 review — all acceptance criteria checked | All files | 1h |

**Acceptance:** All Pydantic event models validate correctly with `pytest`. DE/FR locales have no missing translation keys.

---

### 3.3 Sprint 2 Acceptance Criteria Summary

| Deliverable | Acceptance Test |
|---|---|
| EventManager — all 20 events wired | Unit tests for each emit call in DataManager |
| GM Screen Control Panel | DM switches content in <2s; Lock persists |
| Single Player Window | Map mode + Content mode functional; old window deprecated |
| PDF Viewer — local | 50-page PDF opens <2s, navigation works |
| PDF Viewer — remote | URL loads <5s, send-to-player works |
| NetworkBridge skeleton | State machine transitions verified; status badge updates |
| Event schema v1 | Pydantic models validate all 20 event types |
| Localization complete | DE/FR pass: zero missing keys |

### 3.4 Sprint 2 Risk Items

| Risk | Mitigation |
|---|---|
| PyMuPDF installer size impact (binary wheel ~15MB) | Check final installer size; consider lazy-load or optional install |
| Single Player Window merge creates fog-of-war regressions | Add regression tests on Mar 25 before removing old window |
| Socket.io async vs. Qt event loop conflict | Use `socketio.SimpleClient` (sync) in worker thread; bridge to Qt via `QMetaObject.invokeMethod` |

---

## 4. Pre-Online Backlog Roadmap

These items did not fit into Sprint 1–2. They should be completed before Sprint 3 if the velocity allows, or in dedicated mini-sprints between Phase 0 and Phase 1.

### 4.1 Auto Event Log During Combat

**Effort estimate:** 3–4 days
**Dependency:** EventManager combat events (Sprint 2, Task 2)
**Files:** `ui/widgets/combat_tracker.py`, new `ui/widgets/event_log_panel.py`, `core/data_manager.py`

**Implementation:**
1. Create `EventLogPanel` widget — scrollable, append-only list
2. Subscribe to `session.combatant_updated`, `session.turn_advanced`, `session.combatant_added`
3. Format each event as a human-readable log entry with timestamp
4. Add freeform note input at bottom of panel
5. Persist log entries in `session["event_log"]` field
6. Plain-text export button

---

### 4.2 Free Single Import (Quick Link)

**Effort estimate:** 2–3 days
**Dependency:** API browser dialog, NPC sheet, DataManager
**Files:** `ui/widgets/npc_sheet.py`, `ui/dialogs/api_browser.py`, `core/data_manager.py`

**Implementation:**
1. Add "Quick Link" button to NPC/PC sheet action bar
2. Open API browser in single-select, quick-link mode
3. Persist quick-linked entity in `session["quick_links"]` (not in `entities` dict)
4. Render quick-linked entities with a "temporary" badge
5. "Promote to Library" button saves entity to `entities` dict

---

### 4.3 Soundpad Transition Smoothing

**Effort estimate:** 2 days
**Files:** `core/audio/engine.py`, `ui/soundpad_panel.py`

**Implementation:**
1. Add `crossfade_ms` parameter to `MusicBrain.switch_track()`
2. Implement constant-power fade: fade-out track uses `cos(t * π/2)`, fade-in uses `sin(t * π/2)`
3. Use a `QTimer` with 20ms ticks for the crossfade loop
4. Add crossfade duration setting to preferences dialog
5. Persist setting in user preferences JSON

---

### 4.4 Readability Sprint (Parallel Track)

While Sprint 2 runs, a parallel readability track can process Tier 1 files (see `docs/READABILITY_CONCEPT.md §4`):

| Week | File | Tasks |
|---|---|---|
| Week 1 | `core/api_client.py` | Decompose `parse_monster()`, add type hints, replace Turkish comments |
| Week 1 | `core/data_manager.py` | Add remaining docstrings, replace `print()` with logging |
| Week 2 | `ui/widgets/npc_sheet.py` | Fix duplicate imports, decompose `populate_sheet()` |
| Week 2 | `ui/widgets/combat_tracker.py` | Decompose long methods, add docstrings |

---

## 5. Definition of Done

A sprint is **Done** when all of the following are true:

### Code Quality
- [ ] All planned tasks merged to the `main` branch (or `pre-online` branch if feature-flagged)
- [ ] `ruff check .` passes with zero violations on all modified files
- [ ] No new `print()` calls added (all errors use `logger.*`)
- [ ] No new hardcoded strings without `tr()` wrapper
- [ ] All new UI strings present in EN, TR, DE, FR locale files

### Testing
- [ ] All pre-existing tests pass (zero regressions)
- [ ] New unit tests added for all new `core/` functions
- [ ] New UI smoke tests added for all new widgets
- [ ] Coverage on `core/` is at or above the target for this sprint

| Sprint | Core Coverage Target |
|---|---|
| After Sprint 1 | ≥ 40% |
| After Sprint 2 | ≥ 60% |

### Review
- [ ] Peer review completed for all files >100 LOC changed
- [ ] Acceptance criteria verified for every task (tested by a second person or via automated test)
- [ ] Retrospective notes written (delivered/missed/lessons)

### Release
- [ ] Application launches without errors on Windows 11 and one Linux distro
- [ ] Application launches with `python dev_run.py` (hot reload mode)
- [ ] Installer build succeeds via PyInstaller pipeline
- [ ] `CHANGELOG.md` updated with Sprint deliverables

---

## Appendix A: Sprint 2 File Manifest

Files that will be created or significantly modified in Sprint 2:

| Action | File | Description |
|---|---|---|
| CREATE | `core/event_manager.py` | EventManager class — central event bus (Sprint 1 carryover) |
| CREATE | `ui/components/gm_control_panel.py` | GM Screen Control Panel (Sprint 1 carryover) |
| MODIFY | `ui/player_window.py` | Unified Player Window (Map + Content modes) — file exists, needs extension |
| CREATE | `ui/widgets/pdf_viewer.py` | Embedded PDF viewer widget |
| CREATE | `core/network/bridge.py` | NetworkBridge with connection state machine |
| CREATE | `core/network/events.py` | Event schema v1 Pydantic models |
| CREATE | `ui/components/connection_status.py` | Connection state badge widget |
| CREATE | `tests/test_ui/test_player_window.py` | Regression tests for PlayerWindow |
| MODIFY | `core/data_manager.py` | Wire EventManager event types (all 20 events) |
| MODIFY | `ui/windows/battle_map_window.py` | Deprecate; migrate functionality to PlayerWindow |
| MODIFY | `requirements.txt` | Add PyMuPDF, python-socketio[client] |
| MODIFY | `locales/de.yml`, `locales/fr.yml` | Sprint 1+2 new string translations |

---

## Appendix B: Event Schema v1 Draft

The full event envelope that all online events must conform to:

```python
# core/network/events.py

from pydantic import BaseModel, Field
from datetime import datetime
from typing import Any, Literal
import uuid

class EventEnvelope(BaseModel):
    """Standard wrapper for all DM Tool online events."""
    event_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    event_type: str              # e.g. "entity.updated"
    session_id: str              # Active session UUID
    sender_role: Literal["dm", "player", "observer", "server"]
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    payload: dict[str, Any]     # Event-specific data

class EntityUpdatedPayload(BaseModel):
    entity_id: str
    changed_fields: list[str]
    patch: dict[str, Any]       # Only the changed field values

class CombatantUpdatedPayload(BaseModel):
    session_id: str
    combatant_id: str
    changes: dict[str, Any]     # HP delta, conditions added/removed

class MapFogUpdatedPayload(BaseModel):
    fog_data: str               # Base64-encoded serialized fog mask
    revision: int               # Monotonically increasing for conflict detection

class AudioStatePayload(BaseModel):
    theme: str
    intensity: str
    master_volume: float
    is_playing: bool

class ProjectionContentPayload(BaseModel):
    content_type: Literal["map", "entity", "image", "pdf", "blank"]
    content_ref: str | None     # File path, entity ID, or URL — None for "blank"
    page: int | None = None     # For PDF content type
```

---

## Appendix C: Stability Gate Checklist (Sprint 2 Exit)

This checklist must be completed before Sprint 3 (online phase) begins:

**Functional:**
- [ ] GM Screen Control Panel: quick-switch works for all 4 content types
- [ ] Single PlayerWindow: Map Mode and Content Mode both functional
- [ ] Embedded PDF Viewer: local files open <2s; "send to player" works
- [ ] NetworkBridge: state machine operational; skeleton logs events without crashing
- [ ] Event schema v1: all 20+ event types have Pydantic models
- [ ] EventManager: all events from `PRE_ONLINE.md §4.3` are emitting

**Quality:**
- [ ] `ruff check .` passes on all files modified in Sprint 1+2
- [ ] `core/` test coverage ≥ 60%
- [ ] Zero known P1 (crash / data loss) bugs
- [ ] All 4 locales (EN/TR/DE/FR) have no missing translation keys

**Infrastructure:**
- [ ] `requirements.txt` updated and tested: `pip install -r requirements.txt` succeeds cleanly
- [ ] PyInstaller build produces working installer
- [ ] `dev_run.py` hot reload continues to work with all new files
