# Mobile Readiness Analysis — Dungeon Master Tool

**Date:** 2026-04-01
**Current Version:** alpha-v0.8.4
**Author:** Analysis based on codebase audit
**Purpose:** Evaluate feasibility and plan migration to support Android (APK) alongside desktop (Linux/Windows/Mac)

---

## 1. Executive Summary

The Dungeon Master Tool is a **PyQt6 Widgets desktop application** with 22,881 LOC across 107 Python files. **53 files (49.5%)** directly import PyQt6, making the UI layer tightly coupled to the desktop widget toolkit.

**Verdict:** A direct port to Android is **not feasible** — PyQt6 Widgets does not run on Android. However, the codebase has strong architectural foundations (repository pattern, event bus, presenter layer, network bridge) that make a **shared-core strategy viable**.

**Recommended Strategy:** Extract core logic into a UI-free Python package, then build a mobile-specific UI using **PySide6/QML** (Option A) or a **web frontend** (Option B) while keeping the existing PyQt6 desktop UI intact.

**Estimated preparation effort:** 2-3 weeks to decouple core from UI.
**Estimated mobile UI effort:** 3-6 months for a production-quality Android app.

---

## 2. Current Architecture Snapshot

### 2.1 Codebase Size

| Layer | Files | LOC (approx.) | PyQt6 Dependent? |
|-------|-------|---------------|-------------------|
| Core logic | 20+ | ~7,000 | Mostly NO (1 exception) |
| UI layer | 53 | ~15,000 | YES |
| Tests | 13 | ~900 | Partially (test_ui/) |
| Config/Build | 5 | ~500 | NO |
| **Total** | **107** | **~22,881** | **53 files (49.5%)** |

### 2.2 UI Architecture

- **Multi-window:** MainWindow (1400×900) + PlayerWindow (800×600) + BattleMapWindow (standalone)
- **Layout:** Horizontal QSplitter with 4 panels (sidebar, tabs, soundpad, PDF panel)
- **Fixed sizes:** 70+ `setFixedSize`/`setFixedWidth`/`setFixedHeight` calls across 24 files
- **Splitters:** 19 QSplitter instances across 8 files
- **File dialogs:** 11 files use `QFileDialog`
- **Platform icons:** 7 files use `QApplication.style().standardIcon()`
- **Desktop services:** 3 files use `QDesktopServices.openUrl()`

### 2.3 Core Architecture (Portable)

```
core/
├── data_manager.py         — Facade orchestrator (delegates to repos)
├── entity_repository.py    — Entity CRUD (type-hinted, tested)
├── session_repository.py   — Session CRUD (type-hinted)
├── campaign_manager.py     — Campaign lifecycle
├── library_manager.py      — Reference library cache
├── settings_manager.py     — User preferences
├── event_bus.py            — Pub/sub event system
├── models.py               — Entity schemas & defaults
├── locales.py              — i18n via python-i18n
├── theme_manager.py        — Theme palette definitions
├── library_fs.py           — Library filesystem operations
├── api/
│   ├── client.py           — Unified API client
│   ├── base_source.py      — Abstract API source
│   ├── dnd5e_source.py     — D&D 5e SRD implementation
│   ├── open5e_source.py    — Open5e implementation
│   ├── field_mappers.py    — Field mapping logic
│   └── entity_parser.py    — Entity parsing
├── network/
│   ├── bridge.py           — Network bridge (offline-queue, event forwarding)
│   └── events.py           — Network event envelopes
└── audio/
    ├── engine.py           — ⚠️ Uses QMediaPlayer (PyQt6 dependency!)
    ├── loader.py           — YAML theme loading (portable)
    └── models.py           — Dataclasses (portable)
```

### 2.4 Existing Infrastructure Hints

Empty directories already exist from prior planning:
- `build/android/` — empty, no implementation
- `deployment/recipes/PySide6/` — empty
- `deployment/recipes/shiboken6/` — empty

---

## 3. Portability Assessment by Layer

### 3.1 Core Logic — GREEN (Portable)

| Module | Status | Notes |
|--------|--------|-------|
| `core/data_manager.py` | ✅ | Facade, no PyQt6 imports |
| `core/entity_repository.py` | ✅ | Full type hints, pure Python |
| `core/session_repository.py` | ✅ | Pure Python |
| `core/campaign_manager.py` | ✅ | Pure Python |
| `core/library_manager.py` | ✅ | Pure Python |
| `core/settings_manager.py` | ✅ | Pure Python |
| `core/models.py` | ✅ | Pure Python |
| `core/locales.py` | ✅ | Uses python-i18n (portable) |
| `core/library_fs.py` | ✅ | Pure Python file ops |
| `core/api/*.py` | ✅ | Uses requests (portable) |

### 3.2 Network Layer — GREEN (Portable)

| Module | Status | Notes |
|--------|--------|-------|
| `core/event_bus.py` | ✅ | Pure Python pub/sub |
| `core/network/bridge.py` | ✅ | Uses python-socketio (portable) |
| `core/network/events.py` | ✅ | Pydantic models (portable) |

### 3.3 Audio — YELLOW (Needs Abstraction)

| Module | Status | Notes |
|--------|--------|-------|
| `core/audio/engine.py` | ⚠️ | Uses `QMediaPlayer`, `QAudioOutput` — **only PyQt6 dependency in core** |
| `core/audio/loader.py` | ✅ | YAML loading, pure Python |
| `core/audio/models.py` | ✅ | Dataclasses, pure Python |

**Action needed:** Extract an `AudioBackend` protocol/ABC. Desktop implementation uses QMediaPlayer; mobile implementation would use platform-specific audio (Android MediaPlayer via JNI, or a cross-platform library like `miniaudio`).

### 3.4 Config/Paths — YELLOW (Needs Android Paths)

| Module | Status | Notes |
|--------|--------|-------|
| `config.py` | ⚠️ | Has Windows/Mac/Linux paths; **no Android path support** |

**Current path resolution:**
```
Priority: DM_DATA_ROOT env → portable root → OS user-data
  Windows: %LOCALAPPDATA%/DungeonMasterTool
  macOS:   ~/Library/Application Support/DungeonMasterTool
  Linux:   ~/.local/share/dungeon-master-tool
  Android: ??? (NOT IMPLEMENTED)
```

**Action needed:** Add Android scoped storage path:
```python
if platform_name == "android":
    # Context.getFilesDir() equivalent
    from android.storage import app_storage_path  # or jnius bridge
    return os.path.join(app_storage_path(), APP_NAME)
```

### 3.5 UI Layer — RED (Not Portable)

**53 files** depend on PyQt6 Widgets. These cannot run on Android.

| Category | Files | Key Widgets Used |
|----------|-------|-----------------|
| Main windows | 3 | QMainWindow, QSplitter, QTabWidget |
| Tabs | 5 | QWidget, QVBoxLayout, QHBoxLayout |
| Widgets | 23 | QTableWidget, QGraphicsView, QListWidget, QTreeWidget |
| Dialogs | 8 | QDialog, QFileDialog, QMessageBox |
| Panels | 2 | QWidget (soundpad, PDF) |
| Presenters | 2 | QObject (signals/slots) |
| Workers | 1 | QThread |

### 3.6 Build System — RED (Desktop Only)

| Component | Status | Notes |
|-----------|--------|-------|
| `installer/build.py` | 🔴 | PyInstaller — desktop only |
| `installer/install.sh` | 🔴 | Linux system packages |
| `installer/install-arch.sh` | 🔴 | Arch Linux packages |

---

## 4. Critical Blockers

### Blocker 1: PyQt6 Widgets on Android
PyQt6 Widgets (QWidget-based) do **not** support Android. Qt for Android only supports QML-based interfaces. This affects all 53 UI files.

### Blocker 2: Multi-Window Architecture
Android uses a single-Activity model. The current MainWindow + PlayerWindow + BattleMapWindow pattern cannot be directly ported. The "second screen for players" concept needs rethinking for mobile (screen sharing? separate device?).

### Blocker 3: Fixed Pixel Sizes
70+ hardcoded pixel sizes (24px buttons, 200px galleries, 1400×900 window) designed for desktop displays. Mobile screens range from 360×640 to 1440×3200 with varying DPI.

### Blocker 4: Mouse/Keyboard Input Model
- Keyboard shortcuts (Ctrl+E, Ctrl+S, Ctrl+Z)
- Right-click context menus
- Middle-mouse drag (PDF viewer, mind map)
- Drag-and-drop (entity sidebar → combat table)
- Hover effects

### Blocker 5: File System Access
11 files use `QFileDialog` for opening/saving files. Android requires content providers and the Storage Access Framework (SAF).

### Blocker 6: Audio Backend
`core/audio/engine.py` directly uses `QMediaPlayer`/`QAudioOutput`. These work with Qt for Android but only via QML integration, not Widgets.

### Blocker 7: Complex Layouts
Splitter-based panels, dual-panel database workspace, 4-tab navigation with sidebars — all designed for large screens (1400px+ width).

### Blocker 8: Build Toolchain
PyInstaller produces desktop executables. Android requires Gradle + APK packaging. No Gradle project, AndroidManifest.xml, or build.gradle exists.

---

## 5. Migration Strategy Options

### Option A: Shared Core + PySide6/QML Mobile UI

**Approach:** Keep core logic as-is. Write a new QML-based UI for mobile using PySide6 (which supports Android via Qt for Android). Keep existing PyQt6 desktop UI unchanged.

```
dungeon-master-tool/
├── core/                    ← Shared (no UI imports)
├── ui/                      ← Desktop UI (PyQt6 Widgets, unchanged)
├── ui_mobile/               ← NEW: Mobile UI (QML + PySide6)
│   ├── main.qml
│   ├── pages/
│   │   ├── CombatPage.qml
│   │   ├── EntityPage.qml
│   │   ├── MapPage.qml
│   │   └── SessionPage.qml
│   ├── components/
│   └── bridge.py            ← Python↔QML bridge
├── main.py                  ← Desktop entry point
└── main_mobile.py           ← Mobile entry point
```

| Pros | Cons |
|------|------|
| Python codebase stays unified | QML is a different paradigm (declarative vs imperative) |
| Qt for Android is mature | PySide6 Android support is experimental |
| Shared data/network layer | Two UI codebases to maintain |
| Audio via Qt Multimedia works | Build toolchain complexity (Briefcase/buildozer) |
| Strong typing with QML | Limited QML ecosystem for complex widgets |

**Effort:** 3-4 months for basic mobile app, 6+ months for feature parity
**Risk:** Medium — PySide6 Android support maturity

### Option B: Shared Core + Web Frontend (Flask/FastAPI + React/Vue)

**Approach:** Wrap core logic in a REST API server. Build a web frontend (React/Vue) that runs in any browser or as a PWA/WebView app on mobile.

```
dungeon-master-tool/
├── core/                    ← Shared business logic
├── server/                  ← NEW: FastAPI REST server
│   ├── main.py
│   ├── routes/
│   │   ├── entities.py
│   │   ├── combat.py
│   │   └── sessions.py
│   └── websocket.py         ← Real-time updates
├── web/                     ← NEW: React/Vue SPA
│   ├── src/
│   │   ├── pages/
│   │   ├── components/
│   │   └── stores/
│   └── package.json
├── ui/                      ← Desktop UI (kept for desktop builds)
├── main.py                  ← Desktop entry point
└── main_server.py           ← Server entry point
```

| Pros | Cons |
|------|------|
| Universal: any device with a browser | Requires running a server (complexity) |
| Modern web ecosystem (React, Tailwind) | Offline-first is harder |
| No platform-specific builds | Audio playback limited in browser |
| Hot-reload development | Two languages (Python + JS/TS) |
| Already have socket.io skeleton | Battle map/mind map needs canvas reimplementation |

**Effort:** 4-6 months for basic web app, 8+ months for feature parity
**Risk:** Medium — offline support, audio, canvas-heavy features

### Option C: Shared Core + Kivy Mobile UI

**Approach:** Build a Kivy-based mobile UI in Python. Kivy has mature Android support via Buildozer.

```
dungeon-master-tool/
├── core/                    ← Shared business logic
├── ui/                      ← Desktop UI (PyQt6, unchanged)
├── ui_kivy/                 ← NEW: Kivy mobile UI
│   ├── main.py
│   ├── screens/
│   │   ├── combat.py
│   │   ├── entity.py
│   │   └── map.py
│   └── widgets/
└── buildozer.spec           ← Android build config
```

| Pros | Cons |
|------|------|
| Pure Python — no new language | Kivy looks non-native on mobile |
| Buildozer produces APK directly | Limited widget library |
| Mature Android support | Performance issues with complex UIs |
| Good touch input support | Small ecosystem compared to Qt/React |
| OpenGL-accelerated rendering | PDF rendering needs external library |

**Effort:** 3-5 months for basic mobile app
**Risk:** Low-Medium — Kivy is proven on Android but UI quality ceiling is lower

---

## 6. Recommended Strategy

### Primary Recommendation: Option B (Web Frontend)

**Rationale:**

1. **Already has socket.io skeleton** — `core/network/bridge.py` is designed for client-server architecture
2. **Universal reach** — works on Android, iOS, tablets, any browser, without separate builds
3. **Modern ecosystem** — React/Vue have mature mobile-responsive component libraries
4. **Online play synergy** — the PRE_ONLINE roadmap already requires a server; the web frontend reuses it
5. **Offline support** — PWA (Progressive Web App) can work offline with service workers
6. **No Python-on-Android complexity** — avoids Buildozer/Briefcase packaging issues

### Secondary Recommendation: Option A (PySide6/QML)

If staying pure-Python is important and the online server is not a priority, PySide6/QML is the next best choice. It shares the Qt ecosystem knowledge and keeps a single language.

---

## 7. Preparation Roadmap

### Phase 0: Core Decoupling (2-3 weeks) — DO THIS NOW

**Goal:** Ensure `core/` has zero PyQt6 imports and a clean public API.

#### Step 1: Extract audio backend protocol

```python
# core/audio/backend.py (NEW)
from abc import ABC, abstractmethod

class AudioBackend(ABC):
    @abstractmethod
    def play(self, path: str, volume: float = 1.0, loop: bool = False) -> str: ...
    @abstractmethod
    def stop(self, track_id: str) -> None: ...
    @abstractmethod
    def set_volume(self, track_id: str, volume: float) -> None: ...
    @abstractmethod
    def fade_to(self, track_id: str, target: float, duration_ms: int) -> None: ...
```

Move `QMediaPlayer` usage into `core/audio/qt_backend.py` implementing this protocol. The `engine.py` orchestrator uses the ABC, not Qt directly.

#### Step 2: Ensure config.py handles Android

Add to `get_user_data_root()`:
```python
if platform_name == "android":
    # Will be resolved at runtime via android.storage or jnius
    return os.path.join(os.environ.get("ANDROID_DATA", "/data"), APP_NAME)
```

#### Step 3: Document core public API

Create `core/API.md` listing all public methods on DataManager, EntityRepository, SessionRepository, EventBus with their signatures and return types.

#### Step 4: Verify core isolation

Run: `grep -r "from PyQt6\|import PyQt6" core/ --include="*.py"` — must return ONLY `core/audio/engine.py` and `core/dev/ipc_bridge.py`.

### Phase 1: Server Layer (4-6 weeks)

Build `server/` with FastAPI wrapping core logic:
- REST endpoints for entities, sessions, combat, maps
- WebSocket for real-time combat updates
- Authentication (JWT or session-based)
- File upload/download for images, PDFs, audio

### Phase 2: Web Frontend (8-12 weeks)

Build `web/` with React/Vue:
- Responsive layout (mobile-first, works on desktop too)
- Entity browser and editor
- Combat tracker with touch-friendly controls
- Map viewer (Leaflet.js or canvas-based)
- PDF viewer (pdf.js)
- Audio player (Web Audio API)

### Phase 3: Mobile Packaging (2-4 weeks)

- PWA manifest for "Add to Home Screen" install
- Optional: Capacitor/Cordova wrapper for native APK with file access
- Push notifications for online play

### Phase 4: Desktop Integration (2 weeks)

- Optionally serve the web UI from the desktop app (embedded webview)
- Or keep PyQt6 desktop UI as the "pro" version

---

## 8. Immediate Actions (Current Sprint)

These changes prepare the codebase for mobile without breaking any existing functionality:

| # | Action | Files | Effort |
|---|--------|-------|--------|
| 1 | Extract `AudioBackend` ABC from `core/audio/engine.py` | 2 new files, 1 modified | 2-3 hours |
| 2 | Add Android path to `config.py` | 1 file | 30 min |
| 3 | Verify zero PyQt6 in core (except audio) | grep check | 10 min |
| 4 | Document core public API (`core/API.md`) | 1 new file | 2-3 hours |
| 5 | Add `server/` placeholder with FastAPI hello-world | 2 new files | 1 hour |
| 6 | Keep `custom_spells` and entity data format stable | No changes | — |
| 7 | Ensure all data operations go through DataManager (no direct dict access from UI) | Audit | 1-2 hours |

---

## 9. File Impact Summary

### Files That Need NO Changes (Portable Core)

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
core/api/client.py
core/api/base_source.py
core/api/dnd5e_source.py
core/api/open5e_source.py
core/api/field_mappers.py
core/api/entity_parser.py
core/network/bridge.py
core/network/events.py
core/audio/loader.py
core/audio/models.py
```

### Files That Need Abstraction (1 file)

```
core/audio/engine.py        → Extract AudioBackend ABC
```

### Files That Need Extension (1 file)

```
config.py                   → Add Android/iOS path resolution
```

### Files That Stay Desktop-Only (53 files)

All `ui/`, `ui/tabs/`, `ui/widgets/`, `ui/dialogs/`, `ui/windows/`, `ui/presenters/` files remain the PyQt6 desktop UI. They are NOT modified for mobile — a separate UI layer is built instead.

---

## 10. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| PySide6 Android support is immature | High | Medium | Option B (web) as fallback |
| Core has hidden PyQt6 coupling | Medium | Low | Grep audit + CI check |
| Data format changes break compatibility | High | Low | Freeze msgpack schema |
| Mobile battle map performance | Medium | Medium | Simplify: view-only map on mobile |
| Audio on mobile browsers | Medium | High | Web Audio API; accept limitations |
| Two UIs diverge over time | Medium | High | Shared core ensures data consistency |

---

## 11. Conclusion

The Dungeon Master Tool's architecture is **surprisingly well-prepared** for mobile migration thanks to the Phase 2-4 refactoring work:

- **Repository pattern** cleanly separates data from UI
- **EventBus** enables loose coupling between components
- **Presenter layer** already extracts business logic from widgets
- **Network bridge** is designed for client-server architecture

The main gap is the **tight coupling of `core/audio/engine.py` to QMediaPlayer** and the **lack of Android paths in `config.py`**. Fixing these two issues (estimated 3-4 hours) would make the entire `core/` package UI-framework-agnostic.

The recommended path is **Option B (web frontend)** because it aligns with the existing online play roadmap, provides universal device support, and avoids the complexity of Python-on-Android packaging. The desktop PyQt6 UI remains the primary "DM workstation" interface, while the web/mobile version serves as a lightweight companion for players and on-the-go DMs.
