# UI Tabs Module Documentation

## Module Overview

The UI Tabs module contains the four primary content panels that populate the main application's tab widget. Each tab represents a distinct functional area of the Dungeon Master Tool: entity database management, mind map visualization, world map exploration, and active session management. These tabs are instantiated by the `create_root_widget` function in `ui/main_root.py` and are the primary surfaces through which users interact with their campaign data.

The module is responsible for:

- Providing a dual-panel entity browsing and editing interface for the database tab
- Implementing an interactive mind map canvas with node creation, connection drawing, and workspace grouping
- Presenting a world map viewer with timeline pins, entity pins, and region management
- Managing active game sessions including combat tracking, dice rolling, event logging, and embedded battle map viewing

---

## File Inventory

| File | Lines of Code | Classes | Key Responsibility |
|------|--------------|---------|-------------------|
| `ui/tabs/database_tab.py` | 297 | 2 | Dual-panel entity card management with tab widgets |
| `ui/tabs/session_tab.py` | 273 | 1 | Session management with combat, dice, log, and embedded map |
| `ui/tabs/mind_map_tab.py` | 618 | 4 | Interactive mind map canvas with nodes and connections |
| `ui/tabs/map_tab.py` | 272 | 1 | World map viewer with timeline and entity pins |

**Total: 1,460 lines of code, 8 classes**

---

## Architecture and Data Flow

```
    +-------------------+
    |   main_root.py    |
    | create_root_widget|
    +---+---+---+---+---+
        |   |   |   |
        v   v   v   v
  +-----+ +---+ +-+ +-------+
  | DB  | |Map| |MM| |Session|
  | Tab | |Tab| |Tab|| Tab   |
  +--+--+ +-+-+ ++-+ +---+---+
     |       |    |       |
     v       v    v       v
  NpcSheet MapViewer MindMapItems CombatTracker
  EntitySidebar      MindMapScene BattleMapWidget
                                  MarkdownEditor
```

### Signal Flow Between Tabs and Main Window

The tabs communicate with the main window and each other primarily through Qt signals:

- `DatabaseTab.entity_deleted` connects to `EntitySidebar.refresh_list` to update the sidebar when an entity is removed
- `SessionTab.txt_log.entity_link_clicked` and `SessionTab.txt_notes.entity_link_clicked` connect to `DatabaseTab.open_entity_tab` for navigating from markdown mentions to entity sheets
- `MindMapTab` receives a `main_window_ref` to access the player window for image projection
- `MapTab` receives both `player_window` and `main_window` references for map projection and entity navigation

---

## Per-File Detailed Analysis

### ui/tabs/database_tab.py (297 lines)

**Purpose:** Provides a dual-panel interface for browsing and editing entity data. Each panel is a tab widget that can hold multiple `NpcSheet` instances simultaneously, allowing side-by-side comparison and editing of different entities.

**Classes:**

*EntityTabWidget (QTabWidget):*
- A specialized tab widget that manages multiple `NpcSheet` tabs
- Supports opening entities by ID, checking for duplicates (avoids opening the same entity twice), and closing tabs
- Connects each sheet's `save_requested` signal to the tab's save handler
- Connects each sheet's `request_open_entity` signal to enable cross-entity navigation (clicking a linked spell opens that spell's sheet)
- Contains `open_entity_tab(eid)` which is the primary entry point for opening an entity in a panel

*DatabaseTab (QWidget):*
- Contains two `EntityTabWidget` panels arranged horizontally in a splitter
- Provides a session control layout at the top with buttons for creating, importing, and deleting entities
- Signal: `entity_deleted` (pyqtSignal) - emitted when an entity is deleted to notify the sidebar
- Methods include `new_entity()`, `import_entity_dialog()`, `delete_current_entity()`, `open_entity_tab(eid)`

**Dependencies:** `core.data_manager.DataManager`, `core.locales.tr`, `ui.widgets.npc_sheet.NpcSheet`, `ui.dialogs.api_browser.ApiBrowser`, `ui.dialogs.import_window.ImportWindow`, `core.theme_manager.ThemeManager`

**Quality Assessment:**

- **Lines 38-43:** Hardcoded CSS styles that should be managed through the QSS theme system instead of inline stylesheets. These styles set background colors and border properties directly on widgets.
- The `open_entity_tab` method handles both local entities and library entities (those with `lib_` prefix IDs) differently. Library entities trigger an import dialog before opening, which is a clean design choice.
- `retranslate_ui()` is implemented for dynamic language switching support.
- No type hints or docstrings are present on any methods.
- The dual-panel approach is a strong UX design that allows side-by-side entity comparison.

---

### ui/tabs/session_tab.py (273 lines)

**Purpose:** Manages active game sessions, providing combat tracking, dice rolling, event logging with timestamps, DM notes, and an embedded battle map viewer. This tab is the primary interface used during live play.

**Class: SessionTab (QWidget)**

**Layout Structure:**
- A horizontal splitter divides the tab into left and right panels
- Left panel: `CombatTracker` widget and dice roller buttons (d4, d6, d8, d10, d12, d20, d100)
- Right panel: Session selector combo box with New/Save/Load buttons, event log (`MarkdownEditor`), quick log entry input, and a bottom tab widget containing DM Notes (`MarkdownEditor`) and an embedded `BattleMapWidget`

**Key Methods:**

- `init_ui()` - Builds the entire layout, approximately 120 lines of widget construction
- `save_session(show_msg)` - Persists session state including log text, notes, and combat tracker state. Saves fog data for the current encounter before persisting.
- `load_session()` - Restores session state from the data manager, handling both legacy (flat combatant list) and modern (encounters dictionary) data formats
- `roll_dice(sides)` - Generates a random integer and logs the result with a timestamp
- `log_message(message)` - Appends a timestamped markdown-formatted message to the event log
- `auto_save()` - Triggered by `textChanged` signals on both text editors, automatically saves session state without showing a confirmation message
- `refresh_embedded_map()` - Synchronizes the embedded battle map with the current encounter state, resolving entity types and attitudes for token coloring
- `save_fog_for_encounter(encounter_id)` - Captures the current fog of war state as a base64-encoded PNG and stores it in the encounter data

**Signal Connections:**
- `combat_tracker.data_changed_signal` connects to both `refresh_embedded_map` and `auto_save`
- `embedded_map.token_moved_signal` connects to `combat_tracker.on_token_moved_in_map`
- `embedded_map.token_size_changed_signal` connects to `combat_tracker.on_token_size_changed`
- `embedded_map.view_sync_signal` connects to `combat_tracker.sync_map_view_to_external`
- `embedded_map.fog_update_signal` connects to both `combat_tracker.sync_fog_to_external` and a lambda that triggers session save

**Dependencies:** `core.data_manager.DataManager`, `core.locales.tr`, `ui.widgets.combat_tracker.CombatTracker`, `ui.widgets.markdown_editor.MarkdownEditor`, `ui.windows.battle_map_window.BattleMapWidget`

**Quality Assessment:**

- **Lines 118, 122, 268:** Use `hasattr(tr, "BTN_LOAD_MAP")` to check for translation key existence. The `tr` function is a callable, not a dictionary, so `hasattr` checks whether the function object has an attribute with that name. This always returns False, causing the code to fall back to hardcoded English strings. The correct approach would be to simply call `tr("BTN_LOAD_MAP")` and let the i18n system handle missing keys with its fallback mechanism.
- **Line 256:** Contains a hardcoded Turkish string `"Oturum bulunamadi veya silinmis."` (meaning "Session not found or deleted") that should use the `tr()` function.
- **Lines 89-90:** Uses `hasattr(self.parent(), "db_tab")` which is fragile because the parent widget depends on the UI construction order and may not have a `db_tab` attribute at the time `init_ui()` runs.
- The auto-save mechanism is triggered by every text change event, which could cause performance issues during rapid typing. A debounce timer (similar to the search timer in `ApiBrowser`) would be more appropriate.
- No type hints or docstrings are present.

---

### ui/tabs/mind_map_tab.py (618 lines)

**Purpose:** Implements an interactive mind map canvas where users can create note nodes, entity reference nodes, and image nodes, connect them with Bezier curves, and organize them into named workspaces. The mind map supports autosaving and theme-aware rendering.

**Classes:**

*MindMapScene (QGraphicsScene):*
- Custom scene that handles background rendering for workspaces
- Overrides `drawBackground()` to paint workspace regions with their custom colors
- Contains a reference to the workspace items list for rendering

*CustomGraphicsView (QGraphicsView):*
- Handles scroll-hand-drag panning, mouse wheel zooming, rubber band selection, and keyboard shortcuts
- Implements middle-button panning as an alternative to the scroll hand drag mode
- Manages node connection mode: when active, clicking a node starts a connection, clicking a second node completes it
- Contains `connect_mode`, `connect_source`, and visual feedback items for the connection workflow

*FloatingControls (QWidget):*
- A floating button panel positioned at the top-right corner of the canvas
- Contains buttons for: Add Note, Add Entity (opens entity selector dialog), Add Image (file dialog), Add Workspace, Toggle Grid, Zoom In, Zoom Out, Fit All
- Repositions itself when the parent widget resizes via an event filter

*MindMapTab (QWidget):*
- The main tab widget that orchestrates the mind map functionality
- Manages the node registry (`self.nodes`), connection list (`self.connections`), and workspace list (`self.workspaces`)
- Implements autosave using a `QTimer` with a configurable interval (default: triggered on data changes)
- Provides `save_mind_map()` and `load_mind_map()` methods for persistence through `DataManager`
- Handles node creation, deletion, connection management, workspace management, and projection to the player window

**Key Methods:**
- `add_note_node(pos)` - Creates a new note node with a `MarkdownEditor` widget embedded via `QGraphicsProxyWidget`
- `add_entity_node(eid, pos)` - Creates a node that displays an entity's `NpcSheet` in read-only mode
- `add_image_node(path, pos)` - Creates a node displaying an image with aspect ratio preservation
- `add_connection(source_id, target_id)` - Creates a Bezier curve connection between two nodes
- `save_mind_map()` - Serializes all nodes, connections, and workspaces to the data manager
- `load_mind_map()` - Deserializes and reconstructs the mind map from saved data
- `apply_theme(theme_name)` - Updates all nodes and connections with the new theme palette

**Dependencies:** `core.data_manager.DataManager`, `core.locales.tr`, `core.theme_manager.ThemeManager`, `ui.widgets.mind_map_items.MindMapNode`, `ui.widgets.mind_map_items.ConnectionLine`, `ui.widgets.mind_map_items.WorkspaceItem`, `ui.widgets.mind_map_items.ResizeHandle`, `ui.widgets.npc_sheet.NpcSheet`, `ui.widgets.markdown_editor.MarkdownEditor`, `ui.dialogs.entity_selector.EntitySelectorDialog`

**Quality Assessment:**

- **Line 470:** Bare `except` clause in the mind map loading logic. If deserialization of any node fails, the error is silently caught and that node is skipped. This could lead to data loss without any user notification.
- The file is 618 lines, which is on the upper edge of acceptable size. The `MindMapTab` class alone handles node management, connection management, workspace management, persistence, and projection. This could benefit from extracting the persistence logic into a separate class.
- The autosave mechanism uses signal connections rather than a debounce timer, meaning every position change of every node triggers a save. For large mind maps, this could impact performance.
- Turkish comments are present in several locations.
- No type hints are present on any method.
- The `CustomGraphicsView` correctly handles the complexity of multiple mouse modes (pan, select, connect) but would benefit from a state machine pattern to make the mode transitions more explicit.

---

### ui/tabs/map_tab.py (272 lines)

**Purpose:** Provides a world map viewer where users can place timeline pins, entity pins, and region markers on an uploaded map image. Timeline pins link to specific days and sessions, while entity pins provide quick access to entities associated with map locations.

**Class: MapTab (QWidget)**

**Layout Structure:**
- Top toolbar with buttons for: Upload Map, Set Map, Project Map, Fit View
- A `MapViewer` widget (from `ui.widgets.map_viewer`) as the central canvas
- Right sidebar with timeline and entity pin management controls

**Key Methods:**

- `upload_map()` - Opens a file dialog to select a map image, imports it via `DataManager`, and renders it
- `render_map()` - Loads the current world map from the data manager and populates all pins
- `add_timeline_pin(x, y)` - Opens a `TimelineEntryDialog` to create a new timeline pin at the specified coordinates
- `add_entity_pin(x, y)` - Opens an entity selector to place an entity pin on the map
- `on_pin_clicked(pin_id)` - Navigates to the entity associated with the clicked pin
- `project_map()` - Sends the current map view to the player window for display on a second screen

**Signal Connections:**
- `MapViewer.pin_created_signal` connects to `add_entity_pin`
- `MapViewer.timeline_created_signal` connects to `add_timeline_pin`
- `MapViewer.entity_pin_clicked_signal` connects to entity navigation
- `MapViewer.timeline_pin_clicked_signal` connects to timeline pin editing

**Dependencies:** `core.data_manager.DataManager`, `core.locales.tr`, `core.theme_manager.ThemeManager`, `ui.widgets.map_viewer.MapViewer`, `ui.dialogs.timeline_entry.TimelineEntryDialog`, `ui.dialogs.entity_selector.EntitySelectorDialog`

**Quality Assessment:**

- The code style is highly compressed with many one-liner compound statements using semicolons, which significantly reduces readability. For example, multiple assignments and method calls are chained on single lines.
- **`ThemeManager.get_active_theme()` calls** appear in several locations, but this method does not exist on the `ThemeManager` class. These calls are guarded by `hasattr()` checks that always evaluate to False, causing the code to fall back to the `"dark"` theme hardcoded default.
- The file is 272 lines, which is a reasonable size, but the compressed style makes it feel denser than it is.
- No type hints or docstrings are present.
- The tab properly implements `retranslate_ui()` for dynamic language switching.
- Timeline pin data is stored directly in the `DataManager.data` dictionary rather than through a dedicated timeline model, which couples the UI logic tightly to the data structure.

---

## Code Quality Assessment

### Type Hints

None of the four files contain any type annotations. All method signatures use untyped parameters, and no return types are specified.

### Docstrings

No public methods in any of the four files have docstrings. The only documentation is occasional inline comments, some of which are in Turkish.

### Error Handling

- `mind_map_tab.py` line 470 contains a bare `except` that silently swallows node deserialization failures
- `session_tab.py` does not validate session data structure before accessing nested keys, relying on `.get()` with defaults
- `database_tab.py` does not handle the case where an entity has been deleted between being listed and being opened

### Naming Conventions

- Class names follow PascalCase correctly throughout all files
- Method names follow snake_case correctly throughout all files
- Variable names are generally descriptive, except in `map_tab.py` where compressed one-liners use abbreviated names
- Some method names are overly generic (e.g., `load_session` does not indicate it loads from the combo box selection)

### Internationalization

- `session_tab.py` line 256 contains a hardcoded Turkish string
- `session_tab.py` lines 118, 122, 268 incorrectly use `hasattr(tr, ...)` instead of calling `tr()` directly
- All four files properly use `tr()` for the majority of user-visible strings
- All four files implement `retranslate_ui()` for dynamic language switching

---

## Specific Issues with Line References

| File | Line | Severity | Description |
|------|------|----------|-------------|
| `session_tab.py` | 118, 122 | Medium | `hasattr(tr, "BTN_LOAD_MAP")` always returns False because `tr` is a function, not a namespace |
| `session_tab.py` | 256 | Medium | Hardcoded Turkish string should use `tr()` localization |
| `session_tab.py` | 268 | Medium | Same `hasattr(tr, ...)` bug as lines 118 and 122 |
| `session_tab.py` | 89-90 | Low | Fragile `hasattr(self.parent(), "db_tab")` check depends on construction order |
| `mind_map_tab.py` | 470 | High | Bare `except` clause silently skips failed node deserialization |
| `map_tab.py` | Multiple | Medium | `ThemeManager.get_active_theme()` calls reference a nonexistent method |
| `database_tab.py` | 38-43 | Low | Hardcoded CSS should be managed through the QSS theme system |

---

## Prioritized Improvement Recommendations

### Priority 1: Critical

1. **Fix the bare `except` in `mind_map_tab.py` line 470** by catching specific exceptions (e.g., `KeyError`, `TypeError`) and logging the error. Consider showing a user notification when nodes fail to load, as silent data loss during mind map loading could cause user frustration.

2. **Fix the `hasattr(tr, ...)` pattern** in `session_tab.py` lines 118, 122, and 268. Replace with direct `tr()` calls, as the i18n system already handles missing keys gracefully with fallback behavior.

### Priority 2: High

3. **Add a debounce timer to the auto-save mechanism** in `session_tab.py`. Currently, every keystroke triggers a full session save. A 500ms to 1000ms debounce timer would dramatically reduce I/O while still providing a responsive auto-save experience.

4. **Decompress the one-liner code style** in `map_tab.py`. Split compound statements into separate lines for readability. This will increase the line count but significantly improve maintainability.

5. **Replace the hardcoded Turkish string** in `session_tab.py` line 256 with a `tr()` call using an appropriate localization key.

### Priority 3: Medium

6. **Add type hints** to all public method signatures across all four files. The tab classes are the primary integration points between the main window and the widget layer, so typed interfaces would improve reliability.

7. **Add docstrings** to all public methods, focusing on the parameters and return values of methods that are called from outside the tab class.

8. **Move hardcoded CSS** from `database_tab.py` lines 38-43 into the QSS theme files to maintain consistency with the theme system.

9. **Fix `ThemeManager.get_active_theme()` calls** in `map_tab.py` by either adding the method to `ThemeManager` or accessing the active theme through the `DataManager` instance.

### Priority 4: Low

10. **Extract mind map persistence logic** from `MindMapTab` into a separate `MindMapSerializer` class to reduce the tab class's responsibility count.

11. **Translate all Turkish comments** to English across all four files.

12. **Add validation to session loading** in `session_tab.py` to gracefully handle corrupted or missing session data fields rather than relying solely on `.get()` defaults.

---

## Dependency Graph

```
ui/tabs/database_tab.py
  -> core.data_manager.DataManager
  -> core.locales.tr
  -> core.theme_manager.ThemeManager
  -> ui.widgets.npc_sheet.NpcSheet
  -> ui.dialogs.api_browser.ApiBrowser
  -> ui.dialogs.import_window.ImportWindow

ui/tabs/session_tab.py
  -> core.data_manager.DataManager
  -> core.locales.tr
  -> ui.widgets.combat_tracker.CombatTracker
  -> ui.widgets.markdown_editor.MarkdownEditor
  -> ui.windows.battle_map_window.BattleMapWidget

ui/tabs/mind_map_tab.py
  -> core.data_manager.DataManager
  -> core.locales.tr
  -> core.theme_manager.ThemeManager
  -> ui.widgets.mind_map_items (MindMapNode, ConnectionLine, WorkspaceItem, ResizeHandle)
  -> ui.widgets.npc_sheet.NpcSheet
  -> ui.widgets.markdown_editor.MarkdownEditor
  -> ui.dialogs.entity_selector.EntitySelectorDialog

ui/tabs/map_tab.py
  -> core.data_manager.DataManager
  -> core.locales.tr
  -> core.theme_manager.ThemeManager
  -> ui.widgets.map_viewer.MapViewer
  -> ui.dialogs.timeline_entry.TimelineEntryDialog
  -> ui.dialogs.entity_selector.EntitySelectorDialog
```
