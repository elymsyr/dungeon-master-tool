# 📝 To-Do List & Roadmap

## 🚨 Critical Bugs & Fixes
- [x] **Fix Mindmap Note Visibility (#50):** Fixed text visibility issue in mindmap notes by setting the MarkdownEditor background to transparent, ensuring proper contrast in both light and dark modes.
- [x] **Fix API Downloads on USB (#51):** Added write permission checks and error handling for read-only environments (e.g., USB drives), ensuring the app warns users instead of crashing or failing silently.
- [x] **Fix Battle Map Sync (#52):** Annotations (draw), fog, rulers, and circles now sync correctly to the second screen (player window). Clear Draw also propagates.
- [x] **Fix Battle Map Erase:** Erase tool now correctly removes drawings; Navigate mode click deletes persistent rulers/circles.
- [x] **Fix Player Screen Splitter Sync:** Splitter position in the Player Screen tab now reflects on the second screen in real time.
- [x] **Fix Battle Map Grid/Snap State Reset:** Grid visibility, snap, cell size, and feet-per-cell now persist per encounter and no longer reset after token movement or turn changes.
- [x] **Fix Second Screen Grid Visibility:** Player/second-screen battle map now initializes and renders the same grid visibility and cell size state as DM view.
- [x] **Fix Next Turn Slowdown:** Reduced save-time stalls using smart fog/annotation dirty tracking, autosave debounce, and incremental combat log appends.


## ⚡ Immediate Improvements & UI
- [x] **Auto Event Log:** On the Session View Tab, combat damage, healing, conditions, and round changes are automatically printed to the event log.
- [x] **Single Player Screen:** The battle map view and player view are now unified into a single player window.
- [x] **Battle Map – Persistent Rulers & Circles:** Rulers and circles remain on the map until explicitly deleted. Multiple measurements can coexist. Navigate mode click removes them.
- [x] **Battle Map – Fog System Unification:** Left click adds fog, right click erases fog. Separate "Erase Fog" button removed.
- [x] **Battle Map – Active Tool Highlight:** The active tool button is highlighted in blue. Buttons are grouped by function with visual separators.
- [x] **Battle Map – Measurement Sync:** Rulers and circles are rendered and synced to the second screen (player window).
- [x] **Battle Map – Large Image Support:** Images up to 1 GB (decoded) can now be loaded as battle maps via `QImageReader.setAllocationLimit`.
- [x] **Mind Map – Level of Detail (LOD):** Three-zone LOD system reduces GPU/CPU load when zoomed out: full quality (≥0.4), cached/no-shadow (0.1–0.4), and template mode (<0.1). Grid dots are also skipped or sparsified at low zoom.
- [x] **Mind Map – Readable Template Labels:** In template mode, node labels (entity name / note first line / image filename) are inverse-scaled so they remain readable at any zoom level and overflow the node bounds.
- [x] **Mind Map – Undo/Redo Shortcuts:** Added `Ctrl+Z` and `Ctrl+Shift+Z` support for mind map undo/redo, while preserving native text undo/redo behavior inside focused editors.
- [x] **GM Player Screen Control:** ScreenTab with mode switching for GM to manage the Player Window.
- [x] **Free Single Import:** Manual Add dialog with "Save to database" checkbox — import spells/items directly into any entity without importing to the database first.
- [x] **Embedded PDF Viewer:** Native PDF viewer with right-side collapsible panel, middle-mouse drag, zoom controls, and "Project PDF" button on entity cards.
- [x] **Standardize UI (#30):** Battle map toolbar buttons and spinboxes are now uniform height. Palette-based theming applied across all UI components (sidebar, tabs, action buttons, bulk downloader, etc.).
- [ ] **Soundpad Transitions (#29):**
    - [ ] Make loop switching smoother to avoid audio glitches.
    - [ ] Add support for "mid-length" transition sounds between loops.


## 🌍 Localization
- [x] **French Support:** Add `fr.yml` locale file (AI-translated initially).
- [x] **German Support:** Add `de.yml` locale file.
- [ ] **Source Integration:** Plan for importing French/German SRD sources provided by the community.


## 🛠️ System Agnostic & Customization (Major Overhaul)
- [ ] **Dynamic Entity System:** Refactor `models.py` to allow users to define custom stat entry fields (e.g., GURPS stats like ST, DX, IQ vs D&D 5e STR, DEX, INT).
- [ ] **World Templates:** Create a system to define "World Templates" (XML/JSON) that determine the structure of Entity Cards.
- [ ] **Custom Import:** Allow importing data from CSV/XML directly into these custom world structures.


## 🎵 Soundpad Advanced Features
- [ ] **Folder-based Randomization:** Instead of defining a single file per intensity level, allow pointing to a folder. The app should pick a random track from that folder to vary the music.


## 🔮 Future / Long Term Roadmap
- [ ] **Random Generators:**
    - [ ] NPC Generator (Names, stats, traits).
    - [ ] Battle/Encounter Generator.
- [ ] **Image to Note:** Implement a transformer to convert images (handouts/text) into editable notes (OCR).
- [ ] **Integrations:**
    - [ ] D&D Beyond.
    - [ ] Obsidian MD.
- [ ] **Online Experience:**
    - [ ] Develop a sync system for online play.
    - [ ] Hosted servers (Subscription model) vs Local hosting (Free).

---

## 📋 Changelog

### v0.8.4 — Architecture & UI Polish

- **God Class Decomposition (Phase 2):** NpcSheet (1497→530 LOC) split into 5 sub-widgets (stats, actions, inventory, spells, helpers). CombatTracker split into combatant list, controls, and table widgets.
- **API Client Consolidation (Phase 4):** `core/api/` package with abstract source pattern (`base_source.py`, `dnd5e_source.py`, `open5e_source.py`).
- **MVP/Presenter Layer (Phase 4):** `ui/presenters/` with combat and NPC presenters.
- **Right-Side PDF Panel:** Collapsible panel for viewing entity PDFs, mutually exclusive with soundpad. "Project PDF" button on entity Docs tab.
- **Spells Tab Refactoring:** Manual spells section replaced with ManualSpellDialog + "Save to database" checkbox. Custom and linked spells unified in a single list.
- **Theme Background Fix:** QComboBox/QSpinBox transparency in featureCards, QLabel/QListWidget transparency in sheetContainer across all 11 themes.
- **Button Standardization:** HP buttons themed via QSS, emoji→icon replacement (↑↓◀▶<>), `compactBtn` class, combat controls objectNames added.
- **Combat Table:** Init/AC fit-to-content, HP/Conditions stretch, cells center-aligned, HP bar flat styling.
- **Height/Width Auto-Sizing:** Removed hard height limits, all containers use `Expanding` + auto-fit patterns.
- **Battle Map Toolbar:** DM tools split into 2 rows (tools+actions / grid controls).
- **PDF Viewer:** Middle-mouse drag, Folder button removed, arrow icons standardized.
- **Inline CSS Cleanup:** `common.qss` expanded to 15+ objectName-based rules, HP button colors per-theme.

### v0.8.3 — Architecture & UX

- **Global Edit Mode:** A single ✏️ toolbar toggle now locks or unlocks all text inputs app-wide (NpcSheet cards, session log, DM notes, mind map notes/entities). All components start read-only; turning edit off auto-saves dirty sheets.
- **EventBus (Phase 4):** Introduced `core/event_bus.py` — a lightweight pub-sub bus for cross-cutting events (`entity.deleted`, `theme.changed`, `language.changed`, `edit_mode.changed`). Replaces fragile direct signal chains.
- **Soundpad crossfade fix:** Fixed abrupt music-state transitions caused by per-player fade animations being reset every frame. Crossfade is now driven directly by `fade_ratio` animation (3s, InOutCubic).
- **Active music state button:** Soundpad state buttons now correctly highlight the currently playing state on initial theme load.

### v0.8.2 — Battle Map & Performance

- **Battle Map Grid/Snap persistence** — grid visibility, snap toggle, cell size, and feet-per-cell now persist per encounter and no longer reset after token movement.
- **Second Screen grid parity** — player view now renders the same grid visibility and sizing as DM view, and follows current snap settings.
- **Faster Next Turn** — session autosave now uses smart dirty-checks for fog/annotation (save only when changed) plus a short debounce window to reduce save churn.
- **Event log performance** — combat log writes are appended incrementally instead of rewriting the full text each turn.
- **Mind Map shortcuts** — `Ctrl+Z` and `Ctrl+Shift+Z` added for undo/redo.

### v0.8.1 — Session Entity Stats

- **Entity Stats tab in Session** — new bottom-panel tab shows a full read-only NpcSheet for the currently selected combatant.
- **Live combatant card sync** — selecting any row in the encounter table silently updates the Entity Stats panel.
- **Right-click "View Stats"** — combat table context menu shortcut to the Entity Stats tab.
- **Localization** — new strings added in EN/TR/DE/FR.
