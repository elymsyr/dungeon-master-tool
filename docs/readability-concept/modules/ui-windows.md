# UI Windows and Panels Module Documentation

## Module Overview

The UI Windows and Panels module contains the top-level window classes, the main application shell, panel widgets that serve as major UI sections, the campaign selection dialog, and background worker threads. These components form the outermost layer of the application's UI architecture, orchestrating the assembly of tabs, widgets, and dialogs into a cohesive desktop application.

The module is responsible for:

- Providing the main application window with toolbar, tab management, theme switching, language switching, and world switching
- Implementing the root widget factory that assembles the primary UI tree for hot-reload support
- Delivering the battle map system with fog of war, token rendering, video playback, and a sidebar turn order display
- Presenting a secondary player-facing window for projecting images, character sheets, and PDFs to a second screen
- Offering an audio control panel with music themes, ambient sound slots, and sound effect buttons
- Supplying the campaign selector dialog for creating and loading campaign worlds
- Providing background worker threads for API requests and image downloads

---

## File Inventory

| File | Lines of Code | Classes | Key Responsibility |
|------|--------------|---------|-------------------|
| `main.py` | 388 | 1 | Main application window, theme/language management, app lifecycle |
| `ui/main_root.py` | 163 | 0 (1 function) | Root widget factory for hot-reload-safe UI construction |
| `ui/windows/battle_map_window.py` | 763 | 5 | Battle map with fog of war, tokens, and video support |
| `ui/player_window.py` | 148 | 1 | Player-facing second screen window |
| `ui/soundpad_panel.py` | 440 | 1 | Audio control panel with themes, ambience, and SFX |
| `ui/campaign_selector.py` | 124 | 1 | Campaign world selection and creation dialog |
| `ui/workers.py` | 72 | 3 | Background worker threads for API and image operations |

**Total: 2,098 lines of code, 12 classes, 1 module-level factory function**

---

## Architecture and Data Flow

```
                    +------------------+
                    |    main.py       |
                    |  MainWindow      |
                    |  run_application |
                    +--------+---------+
                             |
                    +--------v---------+
                    |  main_root.py    |
                    | create_root_     |
                    | widget()         |
                    +--+---+---+---+--+
                       |   |   |   |
              +--------+   |   |   +--------+
              v            v   v            v
         EntitySidebar  Tabs  SoundpadPanel
              |         /||\
              |        / || \
              v       v  vv  v
           DatabaseTab  MapTab  SessionTab
                MindMapTab

    +------------------+     +------------------+
    | PlayerWindow     |<--->| ProjectionMgr    |
    | (2nd screen)     |     | (thumbnail bar)  |
    +------------------+     +------------------+

    +------------------+
    | BattleMapWindow  |<--- CombatTracker
    | (fog, tokens)    |
    +------------------+

    +------------------+
    | CampaignSelector |---> DataManager
    | (world picker)   |     (load/create)
    +------------------+
```

### Application Lifecycle

1. `main.py` is the entry point. It creates a `QApplication` and optionally sets up the development IPC bridge.
2. A `DataManager` instance is created for the application lifetime.
3. The `CampaignSelector` dialog opens for world selection or creation.
4. After a campaign is loaded, `MainWindow` is constructed, which calls `create_root_widget` from `main_root.py`.
5. `create_root_widget` instantiates all tabs, the sidebar, the soundpad panel, and wires up all signal connections.
6. The application enters the Qt event loop via `app.exec()`.
7. If the user requests a world switch, the main window closes and the loop returns to step 3.

### Hot Reload Architecture

The `main_root.py` factory pattern enables hot-reload by allowing the entire widget tree to be rebuilt without restarting the application:

1. `HotReloadManager` detects file changes and calls `MainWindow.rebuild_root_widget()`
2. `rebuild_root_widget()` captures the current UI state (tab index, splitter sizes, soundpad visibility)
3. The `main_root` module is reloaded via `importlib.reload()`
4. `create_root_widget()` is called again, building a fresh widget tree
5. The old central widget is replaced and scheduled for deletion
6. The captured state is restored onto the new widget tree

---

## Per-File Detailed Analysis

### main.py (388 lines)

**Purpose:** The main application entry point and primary window class. Manages the application lifecycle, toolbar actions, theme switching, language switching, player window toggling, entity export, and world switching. Also coordinates the development mode IPC bridge.

**Class: MainWindow (QMainWindow)**

**Constructor Parameters:**
- `data_manager` - The `DataManager` instance for campaign data access
- `dev_mode` - Boolean flag that enables development mode features (title prefix, IPC bridge)

**Key Attributes:**
- `self.player_window` - The `PlayerWindow` instance for second-screen display
- `self.theme_list` - List of tuples mapping theme code names to display names
- `self.current_stylesheet` - The currently active QSS stylesheet string
- `self.active_shortcuts` - List of `QShortcut` instances for soundpad keyboard bindings

**Key Methods:**

- `init_ui()` - Delegates to `create_root_widget()` from `main_root.py` and applies the returned widget bundle
- `rebuild_root_widget(reload_main_root_module)` - Hot-reload entry point that captures state, rebuilds the widget tree, and restores state
- `_capture_reload_state()` - Saves current tab index, splitter sizes, and soundpad visibility for restoration after rebuild
- `_restore_reload_state(state)` - Restores captured state onto the rebuilt widget tree
- `retranslate_ui()` - Updates all toolbar labels and delegates to each tab's `retranslate_ui()` method
- `change_language(index)` - Persists the language selection and triggers UI retranslation
- `change_theme(index)` - Loads the new QSS stylesheet, applies it to the main window and player window, and refreshes palette-dependent widgets
- `refresh_database_tab_themes(theme_name)` - Iterates through all open NpcSheet tabs and calls `refresh_theme()` on each
- `toggle_player_window()` - Shows or hides the player window and projection manager
- `toggle_soundpad()` - Shows or hides the soundpad panel, adjusting splitter sizes to accommodate it
- `export_entities_to_txt()` - Exports all entities to a plain text file with formatted output
- `switch_world()` - Sets a flag and closes the window, which the application loop detects to reopen the campaign selector
- `setup_soundpad_shortcuts(shortcuts_map)` - Creates keyboard shortcuts for soundpad controls
- `on_entity_selected(eid)` - Navigates to an entity in the database tab when selected from the sidebar

**Module-Level Function:**
- `run_application(dev_bridge, dev_last_world)` - The main application loop that handles campaign selection, window creation, and world switching. In development mode, it automatically loads the last active world.

**Dependencies:** `config` (DATA_ROOT, DATA_ROOT_MODE, load_theme), `core.data_manager.DataManager`, `core.locales.tr`, `core.theme_manager.ThemeManager`, `ui.campaign_selector.CampaignSelector`, `ui.player_window.PlayerWindow`

**Quality Assessment:**

- **Line 46:** Contains a hardcoded Turkish fallback string `"Bilinmiyor"` (meaning "Unknown") in the window title that should use `tr()`.
- The `_apply_root_bundle` method dynamically sets attributes on the `MainWindow` instance using `setattr`, which means the window's attribute set is determined by the return value of `create_root_widget`. This is flexible but makes static analysis impossible.
- The `export_entities_to_txt` method at lines 268-308 is a self-contained feature implementation that could be extracted into a utility module.
- The development mode integration (IPC bridge, auto-world-loading) is cleanly implemented with minimal impact on the production code path.
- `_DATA_ROOT_FALLBACK_NOTICE_SHOWN` is a module-level mutable global, which is not ideal but acceptable for a one-time notification flag.
- The `change_theme` method properly propagates theme changes to the player window, mind map, and all open entity sheets, demonstrating good awareness of the theme propagation requirements.

---

### ui/main_root.py (163 lines)

**Purpose:** A module-level factory function that constructs the main window's widget tree and returns all key widget references as a dictionary. This design enables the hot-reload system to rebuild the entire UI without recreating the `MainWindow` instance.

**Function: create_root_widget(main_window)**

**Parameters:**
- `main_window` - The `MainWindow` instance that serves as the parent for all created widgets

**Returns:** A dictionary containing all key widget references:
- `central_widget` - The root `QWidget` that becomes the central widget
- `btn_toggle_player`, `btn_export_txt`, `btn_toggle_sound` - Toolbar buttons
- `lbl_campaign`, `btn_switch_world` - Campaign info and world switch button
- `projection_manager` - The `ProjectionManager` instance
- `combo_lang`, `lbl_theme`, `combo_theme` - Language and theme selectors
- `content_splitter` - The main horizontal splitter containing sidebar, tabs, and soundpad
- `entity_sidebar` - The `EntitySidebar` instance
- `tabs` - The `QTabWidget` containing all four main tabs
- `db_tab`, `mind_map_tab`, `map_tab`, `session_tab` - Individual tab instances
- `soundpad_panel` - The `SoundpadPanel` instance

**Widget Tree Structure:**
```
central_widget (QWidget)
  +-- toolbar (QHBoxLayout)
  |     +-- btn_toggle_player
  |     +-- btn_export_txt
  |     +-- btn_toggle_sound
  |     +-- lbl_campaign
  |     +-- projection_manager
  |     +-- combo_lang
  |     +-- lbl_theme, combo_theme
  |     +-- btn_switch_world
  +-- content_splitter (QSplitter, Horizontal)
        +-- entity_sidebar (stretch: 0, collapsible: true)
        +-- tabs (QTabWidget, stretch: 1)
        |     +-- db_tab (DatabaseTab)
        |     +-- mind_map_tab (MindMapTab)
        |     +-- map_tab (MapTab)
        |     +-- session_tab (SessionTab)
        +-- soundpad_panel (stretch: 0, collapsible: true, initially hidden)
```

**Signal Wiring:**
- `entity_sidebar.item_double_clicked` connects to `main_window.on_entity_selected`
- `db_tab.entity_deleted` connects to `entity_sidebar.refresh_list`
- `session_tab.txt_log.entity_link_clicked` connects to `db_tab.open_entity_tab`
- `session_tab.txt_notes.entity_link_clicked` connects to `db_tab.open_entity_tab`
- `projection_manager.image_added` connects to `player_window.add_image_to_view`
- `projection_manager.image_removed` connects to `player_window.remove_image_from_view`
- `soundpad_panel.theme_loaded_with_shortcuts` connects to `main_window.setup_soundpad_shortcuts`
- `combo_lang.currentIndexChanged` connects to `main_window.change_language`
- `combo_theme.currentIndexChanged` connects to `main_window.change_theme`

**Dependencies:** `config.DATA_ROOT`, `core.locales.tr`, `ui.soundpad_panel.SoundpadPanel`, `ui.tabs.database_tab.DatabaseTab`, `ui.tabs.map_tab.MapTab`, `ui.tabs.mind_map_tab.MindMapTab`, `ui.tabs.session_tab.SessionTab`, `ui.widgets.entity_sidebar.EntitySidebar`, `ui.widgets.projection_manager.ProjectionManager`

**Quality Assessment:**

- This file is an excellent example of the factory pattern adapted for Qt hot-reload requirements
- The dictionary-based return value is flexible but loses type safety. A dataclass or NamedTuple would be more robust.
- **Line 51:** Hardcoded inline CSS for the campaign label styling that should be in the QSS theme system
- The function is 135 lines of widget construction, which is long but necessarily so given the number of widgets and connections
- `map_tab.render_map()` is called at the end of the function, which means the map renders during widget construction rather than lazily. This could slow down initial window display.

---

### ui/windows/battle_map_window.py (763 lines)

**Purpose:** The battle map system, consisting of a fog of war layer, a battle map view with token rendering and panning, token items, a shared map widget, and a standalone window wrapper with a sidebar turn order display.

**Classes:**

*FogItem (QGraphicsPixmapItem):*
- Renders a fog of war overlay using a QImage with alpha composition
- Implements `paint_polygon` which uses `QPainter.CompositionMode_Clear` to reveal areas or `QPainter.CompositionMode_SourceOver` to conceal them
- The fog image is a full-resolution QImage that is converted to QPixmap for display
- Methods: `paint_polygon(points, mode)`, `set_fog_image(image)`, `update_pixmap()`

*BattleMapView (QGraphicsView):*
- Extends QGraphicsView with fog editing capabilities, middle-button panning, and mouse wheel zooming
- In fog edit mode, left-click starts drawing a polygon, right-click closes it and applies the fog change
- Emits `view_changed_signal(QRectF)` when the view transform changes for syncing between embedded and external maps
- Emits `fog_changed_signal(QImage)` when the fog layer is modified
- Tracks the current fog editing state: `_current_fog_points`, `_last_paint_mode`

*SidebarConditionIcon (QWidget):*
- A 20x20 pixel condition icon for the battle map window sidebar, similar to the `ConditionIcon` in `combat_tracker.py`
- Renders with custom `paintEvent` using anti-aliased circles

*BattleTokenItem (QGraphicsEllipseItem):*
- A circular token that represents a combatant on the battle map
- Displays an entity image as a circular brush pattern
- Supports drag-and-drop movement with position callback
- Adapts border color based on attitude (friendly, hostile, neutral) and active turn status

*BattleMapWidget (QWidget):*
- The shared map widget used both as an embedded component in the session tab and in the standalone window
- Contains the QGraphicsScene, BattleMapView, toolbar with controls, and fog management
- Supports both static images and video backgrounds via QMediaPlayer and QGraphicsVideoItem
- Signals: `token_moved_signal(str, float, float)`, `token_size_changed_signal(int)`, `view_sync_signal(QRectF)`, `fog_update_signal(object)`
- Key methods:
  - `update_tokens(combatants, current_index, dm_manager, map_path, saved_token_size, fog_data)` - The main update method that synchronizes the map state
  - `set_map_image(pixmap, path_ref)` - Loads a static image or starts video playback
  - `init_fog_layer(width, height)` - Creates or recreates the fog overlay
  - `fill_fog()` / `clear_fog()` - Fills or clears the entire fog layer
  - `load_fog_from_base64(b64_str)` - Restores fog state from saved data
  - `get_fog_data_base64()` - Serializes the current fog state for persistence
- DM view features (when `is_dm_view=True`): fog toggle button, fog fill/clear buttons, view lock button, fog hint label

*BattleMapWindow (QMainWindow):*
- Standalone window wrapper containing a `BattleMapWidget` and a sidebar
- The sidebar displays a vertical list of combatant cards with name, HP, and condition icons
- Signal: `token_moved_signal(str, float, float)` - forwarded from the embedded map widget
- Provides `sync_view(rect)` and `sync_fog(qimage)` for receiving view and fog updates from the embedded map

**Dependencies:** `core.data_manager.DataManager`, `core.locales.tr`, `core.theme_manager.ThemeManager`, `PyQt6.QtMultimedia` (QMediaPlayer, QAudioOutput), `PyQt6.QtMultimediaWidgets` (QGraphicsVideoItem)

**Quality Assessment:**

- At 763 lines, this is the third-largest file in the codebase. The five classes are reasonably well-separated by responsibility.
- The fog of war implementation using QImage composition modes (`CompositionMode_Clear` for reveal, `CompositionMode_SourceOver` for conceal) is technically sound and performant.
- The video playback integration using QMediaPlayer with QGraphicsVideoItem is well-implemented, handling media status changes and native size signals correctly.
- **Line 310:** `ThemeManager.get_active_theme()` is called with a `hasattr()` guard because the method does not exist, falling back to hardcoded `"dark"` theme.
- **Line 336:** Same `hasattr(tr, "BTN_LOCK_VIEW_TOOLTIP")` pattern that always returns False.
- The `update_tokens` method at line 596 is approximately 65 lines long and handles map loading, fog restoration, and token creation/update in a single method. It would benefit from decomposition.
- The token border color logic (lines 631-638) uses hardcoded color values rather than palette lookups, which means tokens do not adapt to theme changes.
- Turkish comments appear throughout the file.

---

### ui/player_window.py (148 lines)

**Purpose:** A secondary window designed for display on a second screen visible to players. Supports multiple simultaneous image views, character sheet display via HTML, and PDF viewing via the embedded Qt WebEngine.

**Class: PlayerWindow (QMainWindow)**

**Display Modes (via QStackedWidget):**
- **Page 0:** Multi-image viewer with horizontal layout of `ImageViewer` widgets
- **Page 1:** Character sheet viewer using `QTextBrowser` for HTML content
- **Page 2:** PDF viewer using `QWebEngineView` (lazily initialized to avoid loading the WebEngine when not needed)

**Key Methods:**

- `add_image_to_view(image_path, pixmap)` - Adds or updates an image in the multi-image display. If the image path already exists, updates the existing viewer's pixmap. Otherwise, creates a new `ImageViewer` widget.
- `remove_image_from_view(image_path)` - Removes an image from the multi-image display by its path
- `clear_images()` - Removes all images from the display
- `show_image(pixmap)` - Legacy method that clears and shows a single image (for backward compatibility)
- `show_stat_block(html_content)` - Displays an HTML-rendered character sheet or stat block
- `show_pdf(pdf_path)` - Loads and displays a PDF file using the WebEngine viewer
- `update_theme(qss)` - Applies a new stylesheet to the window

**Dependencies:** `core.theme_manager.ThemeManager`, `ui.widgets.image_viewer.ImageViewer`, `PyQt6.QtWebEngineWidgets.QWebEngineView` (lazy import)

**Quality Assessment:**

- The lazy initialization of the PDF viewer at line 132 is a good performance optimization, as `QWebEngineView` is a heavy component
- The multi-image viewer with update-in-place logic at line 53-72 is well-designed for the projection use case
- **Line 34:** Hardcoded dark palette for the stat viewer styling rather than using the current theme
- **Line 68:** Bare `except Exception as e` that only prints to console when image view update fails
- The image loading at lines 81-94 uses `QImageReader` as a primary loader with `QPixmap` fallback, which provides better format support (especially for WebP)
- At 148 lines, this is a well-scoped window class

---

### ui/soundpad_panel.py (440 lines)

**Purpose:** An audio control panel that provides music theme selection with state-based playback and intensity control, four ambient sound slots with individual volume control, a sound effects grid, and global volume management. Integrates with the `MusicBrain` audio engine.

**Class: SoundpadPanel (QWidget)**

**Signal:** `theme_loaded_with_shortcuts(dict)` - emitted when a theme is loaded, containing keyboard shortcut mappings for the main window to register

**Layout Structure (3-tab design):**
- **Music Tab:** Theme selector combo box, state buttons (dynamic, based on theme), intensity slider (0-3)
- **Ambience Tab:** Four scrollable ambience slots, each with a combo box for selecting an ambience track and a volume slider
- **SFX Tab:** Grid of sound effect buttons, with add and remove controls
- **Global Controls:** Master volume slider, stop ambience button, stop all button

**Key Methods:**

- `init_ui()` - Builds the entire three-tab layout with global controls
- `_setup_music_tab()` / `_setup_ambience_tab()` / `_setup_sfx_tab()` - Individual tab setup methods
- `_build_ambience_slots()` - Creates four ambient sound slots with combo boxes and volume sliders
- `_build_sfx_grid()` - Populates the SFX tab with buttons from the global library
- `_rebuild_state_buttons()` - Dynamically creates state buttons when a new theme is loaded
- `load_selected_theme()` - Activates the selected music theme, showing state and intensity controls
- `_merge_shortcuts()` - Deep-merges global keyboard shortcuts with theme-specific shortcuts
- `on_state_clicked(state_name)` - Activates a music state and updates button visuals
- `change_intensity(value)` - Updates the intensity level with translated labels
- `change_master_volume(value)` - Propagates master volume changes to the audio engine
- `_add_new_sound(category)` - File dialog workflow for adding new ambience or SFX tracks to the library
- `remove_sfx_dialog()` - Dialog workflow for removing SFX entries from the library
- `open_theme_builder()` - Opens the ThemeBuilderDialog and handles theme creation

**Dependencies:** `core.locales.tr`, `core.audio.engine.MusicBrain`, `core.audio.loader` (load_all_themes, load_global_library, add_to_library, create_theme, remove_from_library), `ui.dialogs.theme_builder.ThemeBuilderDialog`

**Quality Assessment:**

- **Line 38:** Turkish comment about default volume percentage
- **Lines 102, 125, 131, 198, 290, 294-296, 316-317:** Turkish comments throughout the file
- The three-tab design is well-organized and provides good separation between music, ambience, and SFX controls
- The shortcut merging mechanism at `_merge_shortcuts()` is a clean implementation of theme-specific shortcut overrides
- The `retranslate_ui()` method at line 331 is thorough, covering all UI text elements
- The `_refresh_ambience_combos()` method properly preserves current selections when refreshing the combo box contents
- No type hints or docstrings

---

### ui/campaign_selector.py (124 lines)

**Purpose:** A modal dialog for selecting an existing campaign world or creating a new one. Includes language selection that persists across sessions.

**Class: CampaignSelector (QDialog)**

**Features:**
- List of available campaigns from the data manager
- Load button and double-click support for opening campaigns
- New world name input with create button
- Language selector combo box (English, Turkish, German, French)
- Validates against duplicate world names
- Updates all UI text via `update_texts()` when language changes

**Key Methods:**

- `init_ui()` - Builds the dialog layout with campaign list, load button, create section, and language selector
- `refresh_list()` - Populates the campaign list from `DataManager.get_available_campaigns()`
- `load_campaign()` - Loads the selected campaign via `DataManager.load_campaign_by_name()`
- `create_campaign()` - Creates a new campaign via `DataManager.create_campaign()`
- `change_language(index)` - Persists language selection and refreshes UI text
- `update_texts()` - Refreshes all label and button text using `tr()` calls

**Dependencies:** `core.data_manager.DataManager`, `core.locales.tr`, `core.locales.set_language`

**Quality Assessment:**

- **Line 1:** Contains a Turkish comment at the top of the file
- **Line 28:** Hardcoded inline CSS for the title label that should be in the QSS system
- **Line 14:** Window title is hardcoded in English as a temporary value, which is then properly updated by `update_texts()`
- Clean and focused at 124 lines
- Duplicate world name validation at line 115-117 is a good UX feature
- No type hints or docstrings

---

### ui/workers.py (72 lines)

**Purpose:** Background worker threads for asynchronous API operations and image downloads. These workers are used by the API browser, import window, and NPC sheet to prevent UI freezing during network operations.

**Classes:**

*ApiSearchWorker (QThread):*
- Performs a single entity fetch from the API in a background thread
- Signal: `finished(bool, object, str)` - emits success flag, result data or entity ID, and message
- Used by `ApiBrowser` for fetching entity details

*ApiListWorker (QThread):*
- Fetches a paginated API index in a background thread
- Signal: `finished(object)` - emits the list or dictionary response
- Supports filter parameters for server-side filtering

*ImageDownloadWorker (QThread):*
- Downloads an image from a URL in a background thread
- Implements cache checking: skips download if the file already exists
- Signal: `finished(bool, str)` - emits success flag and local file path
- Creates the target directory if it does not exist

**Dependencies:** `core.data_manager.DataManager`, `requests`, `os`

**Quality Assessment:**

- All three workers follow the same clean pattern: QThread subclass with signals for result delivery
- The `ImageDownloadWorker` has a good cache-checking mechanism that avoids redundant downloads
- **Line 20-21:** Bare `except Exception as e` that catches all exceptions during API fetch, which is acceptable for a worker thread but could be more specific
- **Line 70-71:** Same pattern for image download errors
- At 72 lines, this is a well-scoped module
- No type hints, but the signal type annotations in the signal declarations partially compensate

---

## Code Quality Assessment

### Type Hints

- `main.py` has type hints on the `run_application` function signature: `dev_bridge=None, dev_last_world: Optional[str] = None`
- `main.py` has type hints on several private methods: `_capture_reload_state() -> Dict[str, Any]`, `_restore_reload_state(state: Dict[str, Any])`
- All other files have no type annotations

### Docstrings

- `ui/main_root.py` has a one-line docstring on `create_root_widget`
- `ui/player_window.py` has a brief docstring on `add_image_to_view`
- `ui/workers.py` has a brief docstring on `ImageDownloadWorker`
- `main.py` has no docstrings on the MainWindow class or its methods
- All other files have no docstrings

### Error Handling

- `main.py` line 305 catches `Exception as e` for file write errors with user notification
- `player_window.py` line 68 catches `Exception as e` for image update errors, printing to console
- `workers.py` uses generic `Exception` catching in worker threads, which is acceptable for background tasks
- `campaign_selector.py` properly shows error messages for failed campaign loading

### Internationalization

- `main.py` line 46 contains a hardcoded Turkish string in the window title
- `campaign_selector.py` line 1 has a Turkish comment
- `soundpad_panel.py` has Turkish comments throughout
- All files properly use `tr()` for user-visible strings (with the exceptions noted above)
- `main.py` and `soundpad_panel.py` implement thorough `retranslate_ui()` methods

---

## Specific Issues with Line References

| File | Line | Severity | Description |
|------|------|----------|-------------|
| `main.py` | 46 | Low | Hardcoded Turkish string `"Bilinmiyor"` in window title |
| `battle_map_window.py` | 310 | Medium | `ThemeManager.get_active_theme()` references nonexistent method |
| `battle_map_window.py` | 336 | Medium | `hasattr(tr, ...)` pattern always returns False |
| `battle_map_window.py` | 631-638 | Low | Hardcoded token border colors instead of palette lookups |
| `player_window.py` | 34 | Low | Hardcoded dark palette for stat viewer instead of current theme |
| `player_window.py` | 68 | Low | Generic exception handling with console print |
| `soundpad_panel.py` | Multiple | Low | Turkish comments throughout |
| `campaign_selector.py` | 28 | Low | Hardcoded inline CSS for title label |
| `main_root.py` | 51 | Low | Hardcoded inline CSS for campaign label |

---

## Prioritized Improvement Recommendations

### Priority 1: Critical

1. **Fix `ThemeManager.get_active_theme()` references** in `battle_map_window.py`. Either add this method to `ThemeManager` or refactor all callers to obtain the theme name from `DataManager`. This is a recurring issue that affects multiple files.

2. **Fix `hasattr(tr, ...)` pattern** in `battle_map_window.py` line 336. Replace with a direct `tr()` call.

### Priority 2: High

3. **Decompose `BattleMapWidget.update_tokens()`** into smaller methods: one for map background updates, one for fog restoration, and one for token rendering. The current 65-line method handles too many concerns.

4. **Replace hardcoded token border colors** in `battle_map_window.py` lines 631-638 with palette lookups to support theme consistency.

5. **Use the active theme palette** in `player_window.py` line 34 instead of hardcoding the dark palette for the stat viewer.

### Priority 3: Medium

6. **Add type hints** to `MainWindow` constructor and all public methods. The `_apply_root_bundle` method in particular would benefit from a typed bundle parameter.

7. **Consider using a TypedDict or dataclass** for the `create_root_widget` return value instead of a plain dictionary, to provide IDE support and static checking.

8. **Move hardcoded inline CSS** from `campaign_selector.py` and `main_root.py` into the QSS theme system.

9. **Add docstrings** to all classes and public methods, particularly `MainWindow` and `BattleMapWidget`.

### Priority 4: Low

10. **Extract `export_entities_to_txt()`** from `MainWindow` into a utility module, as it is a self-contained feature that does not depend on window state.

11. **Translate all Turkish comments** to English across all files.

12. **Replace the Turkish string** in `main.py` line 46 with a `tr()` call.

---

## Dependency Graph

```
main.py
  -> config (DATA_ROOT, DATA_ROOT_MODE, load_theme)
  -> core.data_manager.DataManager
  -> core.locales.tr
  -> core.theme_manager.ThemeManager
  -> ui.campaign_selector.CampaignSelector
  -> ui.player_window.PlayerWindow
  -> ui.main_root (create_root_widget)
  -> core.dev.ipc_bridge.DevIpcBridge (dev mode only)

ui/main_root.py
  -> config.DATA_ROOT
  -> core.locales.tr
  -> ui.soundpad_panel.SoundpadPanel
  -> ui.tabs.database_tab.DatabaseTab
  -> ui.tabs.map_tab.MapTab
  -> ui.tabs.mind_map_tab.MindMapTab
  -> ui.tabs.session_tab.SessionTab
  -> ui.widgets.entity_sidebar.EntitySidebar
  -> ui.widgets.projection_manager.ProjectionManager

ui/windows/battle_map_window.py
  -> core.locales.tr
  -> core.theme_manager.ThemeManager
  -> PyQt6.QtMultimedia, PyQt6.QtMultimediaWidgets

ui/player_window.py
  -> core.theme_manager.ThemeManager
  -> ui.widgets.image_viewer.ImageViewer
  -> PyQt6.QtWebEngineWidgets (lazy import)

ui/soundpad_panel.py
  -> core.locales.tr
  -> core.audio.engine.MusicBrain
  -> core.audio.loader
  -> ui.dialogs.theme_builder.ThemeBuilderDialog

ui/campaign_selector.py
  -> core.data_manager.DataManager
  -> core.locales (tr, set_language)

ui/workers.py
  -> core.data_manager.DataManager
  -> requests
```
