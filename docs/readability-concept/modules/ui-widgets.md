# UI Widgets Module Documentation

## Module Overview

The UI Widgets module contains the reusable visual components that compose the application's user interface. These widgets range from complex multi-tab entity editing sheets to specialized graphics items for mind map visualization. They are instantiated by the tab modules and the main window to provide the interactive elements that users directly manipulate.

The module is responsible for:

- Providing the comprehensive entity editing sheet (NpcSheet) with dynamic form generation based on entity type
- Implementing the combat tracker with initiative management, HP tracking, condition icons, and encounter switching
- Presenting an entity sidebar with drag-and-drop support and library search integration
- Delivering a markdown editor with entity mention autocomplete and theme-aware HTML rendering
- Supplying map viewing components with timeline pins, entity pins, and context menus
- Offering graphics items for mind map nodes, Bezier curve connections, and workspace regions
- Managing image projection to a secondary display through a thumbnail-based interface
- Providing helper widgets for image viewing with zoom and aspect-ratio-preserving labels

---

## File Inventory

| File | Lines of Code | Classes | Key Responsibility |
|------|--------------|---------|-------------------|
| `ui/widgets/npc_sheet.py` | 1,003 | 1 | Entity editing sheet with dynamic forms |
| `ui/widgets/combat_tracker.py` | 912 | 7 | Combat initiative tracking and encounter management |
| `ui/widgets/entity_sidebar.py` | 333 | 3 | Sidebar entity list with drag-and-drop |
| `ui/widgets/markdown_editor.py` | 416 | 4 | Markdown editor with entity mention autocomplete |
| `ui/widgets/map_viewer.py` | 233 | 4 | Map viewer with pin items and context menus |
| `ui/widgets/image_viewer.py` | 56 | 1 | Image display with mouse wheel zoom |
| `ui/widgets/aspect_ratio_label.py` | 69 | 1 | Aspect-ratio-preserving image label |
| `ui/widgets/mind_map_items.py` | 456 | 4 | Mind map node, connection, workspace graphics items |
| `ui/widgets/projection_manager.py` | 232 | 2 | Image projection to player window |

**Total: 3,710 lines of code, 27 classes**

---

## Architecture and Data Flow

```
+----------------+     +------------------+     +------------------+
|  database_tab  |---->|    NpcSheet      |---->| DataManager      |
|                |     | (entity editing) |     | (persistence)    |
+----------------+     +------------------+     +------------------+
                              |
                              v
+----------------+     +------------------+
|  session_tab   |---->| CombatTracker    |---->BattleMapWidget
|                |     | (initiative mgmt)|     (token rendering)
+----------------+     +------------------+
                              |
+----------------+     +------+----------+
|  mind_map_tab  |---->| MindMapItems    |
|                |     | (nodes, conns)  |
+----------------+     +------------------+

+----------------+     +------------------+
|   map_tab      |---->|   MapViewer      |
|                |     | (pins, regions)  |
+----------------+     +------------------+

+----------------+     +------------------+
|  main_root     |---->| EntitySidebar    |
|                |     | (entity list)    |
|                |---->| ProjectionMgr    |
|                |     | (image project)  |
+----------------+     +------------------+

Shared by multiple:    +------------------+
                       | MarkdownEditor   |
                       | (rich text edit) |
                       +------------------+
```

---

## Per-File Detailed Analysis

### ui/widgets/npc_sheet.py (1,003 lines)

**Purpose:** The most complex widget in the application. Provides a comprehensive entity editing interface with dynamically generated forms that adapt based on entity type (NPC, Monster, Player, Spell, Equipment, Location, Lore, Status Effect). Includes tabs for combat stats, spells, actions/features, inventory, documents, and battle maps.

**Class: NpcSheet (QWidget)**

**Signals:**
- `request_open_entity(str)` - Emitted when a user double-clicks a linked entity, requesting navigation to that entity's sheet
- `data_changed()` - Emitted whenever any field in the sheet is modified
- `save_requested()` - Emitted when the user explicitly triggers a save action

**Layout Structure:**
- Top header: Entity type selector (combo box), entity name input, description text area, image gallery with navigation, tag input
- Location selector: Combo box for assigning entities to locations, with a resident list for Location-type entities
- Tab widget with up to 6 tabs depending on entity type:
  - Stats Tab: Base ability scores (STR, DEX, CON, INT, WIS, CHA) with automatic modifier calculation, combat stats (HP, AC, Speed, etc.), defense details
  - Spells Tab: Linked spell list from database, manual spell entries
  - Features Tab: Traits, Actions, Reactions, Legendary Actions sections with dynamic card creation
  - Inventory Tab: Linked item list from database, manual inventory entries
  - Documents Tab: PDF file management with add, open, remove, and project capabilities
  - Battle Maps Tab: Media gallery for Location-type entities supporting images and videos

**Key Methods:**

- `init_ui()` - Approximately 200 lines of layout construction, building the entire sheet structure
- `populate_sheet(entity_data)` - Fills all form fields from an entity data dictionary. This is the inverse of `collect_data_from_sheet`.
- `collect_data_from_sheet()` - Reads all form fields and assembles them into an entity data dictionary. This is the inverse of `populate_sheet`.
- `build_dynamic_form(category_name)` - Generates form fields based on the `ENTITY_SCHEMAS` definition for the given category. Supports text inputs, combo boxes, and entity-select combo boxes.
- `update_ui_by_type(category_name)` - Shows or hides tabs and form sections based on the entity type. Contains complex logic for reparenting the combat stats group box between the stats tab and the main content area.
- `_populate_unified_combo(category, widget)` - Populates an entity-select combo box with both local entities and API results. Makes synchronous API calls with `QApplication.processEvents()` to keep the UI responsive during loading.
- `_on_unified_selection(index, widget)` - Handles selection of an API entity in a unified combo box, triggering an import and updating the UI with loading indicators.
- `_start_lazy_image_download(url, name)` - Initiates a background download for entity images using the `ImageDownloadWorker` thread.
- `add_feature_card(container)` - Adds a dynamic name/description card to a features section

**Dependencies:** `core.data_manager.DataManager`, `core.models.ENTITY_SCHEMAS`, `core.locales.tr`, `core.theme_manager.ThemeManager`, `config.CACHE_DIR`, `ui.workers.ImageDownloadWorker`

**Quality Assessment:**

This class is the most severe God Class in the codebase at 1,003 lines with approximately 46 methods. It combines at least six distinct responsibilities:

1. UI layout construction (init_ui and setup methods)
2. Data collection from form fields (collect_data_from_sheet)
3. Data population into form fields (populate_sheet)
4. Dynamic form generation (build_dynamic_form)
5. Image gallery management (add_image, remove_image, navigation)
6. PDF document management (add_pdf, open_pdf, remove_pdf)

The `populate_sheet` and `collect_data_from_sheet` methods are mirror images of each other, both approximately 80 lines long, that must be kept perfectly synchronized. Any field added to one must be added to the other, which is a maintenance hazard.

- **Lines 541-547:** The `_update_modifier` method packs multiple statements on single lines using semicolons, reducing readability
- **Line 850:** `QApplication.processEvents()` is called inside a pagination loop in `_populate_unified_combo`, which can cause re-entrant event processing and subtle bugs
- **Lines 932-956:** Extremely compressed code style with multiple statements per line, some single lines containing three or four operations separated by semicolons
- No type hints or docstrings on any methods
- Turkish comments appear in several locations

---

### ui/widgets/combat_tracker.py (912 lines)

**Purpose:** Manages combat encounters with initiative tracking, HP management, condition effects, turn ordering, and integration with the battle map system. Supports multiple encounters per session with switching between them.

**Classes:**

*DraggableCombatTable (QTableWidget):*
- Extends QTableWidget to accept drag-and-drop from the entity sidebar
- Emits `entity_dropped(str)` signal when an entity is dropped onto the table
- Implements `dragEnterEvent`, `dragMoveEvent`, and `dropEvent` for drag-and-drop handling

*ConditionIcon (QWidget):*
- A 24x24 pixel widget that renders a condition icon (from image file or text abbreviation)
- Displays a duration counter overlay when the condition has a limited duration
- Uses custom `paintEvent` for rendering with anti-aliased circles and centered text

*ConditionsWidget (QWidget):*
- A horizontal flow layout widget that displays multiple `ConditionIcon` instances
- Manages a list of active conditions with add, remove, and tick (decrement duration) operations
- Signal: `conditionsChanged` - emitted when conditions are modified
- Signal: `clicked` - emitted when the widget area is clicked, used to open the condition picker menu

*HpBarWidget (QWidget):*
- A visual HP bar with current/max display and theme-aware gradient coloring
- Supports click-to-edit interaction that opens an integer input dialog
- Signal: `hpChanged(int)` - emitted when HP value changes
- Colors transition from green (full) through yellow (medium) to red (low) based on the current/max ratio

*NumericTableWidgetItem (QTableWidgetItem):*
- Overrides the less-than operator for proper numeric sorting in table columns
- Used for initiative and AC columns to ensure correct sort order

*MapSelectorDialog (QDialog):*
- A dialog for selecting a battle map from the entity's associated maps or importing a new one
- Lists all maps from Location-type entities that have battle map images associated
- Provides an "Import New" option for uploading a map file directly

*CombatTracker (QWidget):*
- The main combat management widget, approximately 500 lines
- Signal: `data_changed_signal` - emitted on any state change for auto-save and map refresh
- Manages multiple encounters via `self.encounters` dictionary with encounter switching
- Provides encounter lifecycle methods: `create_encounter`, `prompt_new_encounter`, `rename_encounter`, `delete_encounter`, `switch_encounter`
- Maintains token positions for battle map rendering
- Integrates with both the embedded battle map widget and the external battle map window

**Key Methods:**

- `add_direct_row(name, init, ac, hp, conditions_data, eid, init_bonus, tid)` - Adds a row to the combat table with all associated widgets (HP bar, conditions)
- `next_turn()` - Advances the turn index, handles round transitions, ticks condition durations
- `refresh_battle_map(force_map_reload)` - Synchronizes battle map tokens with current combat state
- `get_session_state()` - Serializes all encounter data for session persistence
- `load_session_state(data)` - Deserializes encounter data, handling both modern and legacy formats
- `open_battle_map()` - Creates and shows the external battle map window

**Dependencies:** `core.data_manager.DataManager`, `core.locales.tr`, `core.theme_manager.ThemeManager`, `ui.windows.battle_map_window.BattleMapWindow`, `ui.dialogs.encounter_selector.EncounterSelectionDialog`

**Quality Assessment:**

- The `clean_stat_value` helper function at the module level contains a bare `except` clause that catches all exceptions during integer parsing
- Extremely compressed code style in the lower half of the file, with many methods using semicolons to pack multiple statements per line
- The `CombatTracker` class itself is approximately 500 lines and handles encounter management, table management, battle map integration, and context menus. Extracting encounter management into a separate class would improve maintainability.
- Turkish comments are scattered throughout the file, particularly in the HP bar and condition rendering sections
- The `_save_current_state_to_memory` method at line 675 defines a nested function `get_text_safe` inside a loop iteration, which is recreated on every iteration and adds unnecessary overhead
- Token position data is stored in a flat dictionary within each encounter, mixing presentation state (token positions) with game state (combatant stats)
- No type hints or docstrings on any methods

---

### ui/widgets/entity_sidebar.py (333 lines)

**Purpose:** Provides a collapsible sidebar with a categorized, searchable list of all entities in the current campaign. Supports drag-and-drop of entities to the combat tracker and mind map canvas. Integrates with the library filesystem for local content browsing.

**Classes:**

*EntityListItemWidget (QWidget):*
- A custom list item widget that displays an entity's name, type icon, and optional image thumbnail
- Handles image loading and scaling for the thumbnail display

*DraggableListWidget (QListWidget):*
- Extends QListWidget to support drag initiation with entity ID as MIME data
- Implements `startDrag` to encode the entity ID in the drag payload

*EntitySidebar (QWidget):*
- The main sidebar widget with search input, category filter, and entity list
- Contains a `translate_category` method that maps internal category keys to display names
- Signal: `item_double_clicked(str)` - emitted with entity ID when a list item is double-clicked
- Implements `refresh_list()` which rebuilds the entire list from the data manager
- Supports filtering by entity type and text search simultaneously

**Key Methods:**

- `refresh_list()` - Clears and rebuilds the entire entity list, applying current filter and search criteria
- `translate_category(key)` - Maps category keys to translated display names using a `key_map` dictionary
- `on_search()` - Filters the visible entities based on the search input text
- `on_filter_changed()` - Updates the entity list when the category filter combo box changes

**Dependencies:** `core.data_manager.DataManager`, `core.locales.tr`, `core.theme_manager.ThemeManager`

**Quality Assessment:**

- Hardcoded CSS styles are embedded directly in the widget code rather than using the QSS theme system
- The `translate_category` method contains a duplicate `key_map` dictionary that must be kept in sync with category definitions elsewhere in the codebase. This should be centralized.
- The `refresh_list()` method rebuilds the entire list on every call, which could be expensive for large entity collections. An incremental update approach would be more efficient.
- No type hints or docstrings
- The sidebar properly supports the library search integration, showing both local entities and filesystem library entries in a unified list

---

### ui/widgets/markdown_editor.py (416 lines)

**Purpose:** A rich text editor component that supports markdown formatting, entity mention autocomplete (triggered by the `@` character), and theme-aware HTML rendering. Used in session logs, DM notes, and mind map note nodes.

**Classes:**

*MentionPopup (QListWidget):*
- A floating popup that appears when the user types `@` followed by characters
- Displays matching entity names from the data manager
- Implements keyboard navigation (up/down arrows, Enter to select, Escape to dismiss)
- Hardcoded CSS for popup styling

*ClickableTextBrowser (QTextBrowser):*
- Extends QTextBrowser to handle clicks on entity mention links
- Parses anchor URLs with the `entity://` scheme to extract entity IDs
- Signal: `entity_link_clicked(str)` - emitted with entity ID when a mention link is clicked

*PropagatingTextEdit (QTextEdit):*
- A text edit that propagates certain key events to the parent widget
- Used to forward Enter and Escape key presses to the `MentionPopup` handler

*MarkdownEditor (QWidget):*
- The main editor widget that combines a `PropagatingTextEdit` for editing and a `ClickableTextBrowser` for rendering
- Toggles between edit mode and preview mode
- Implements the `@` mention autocomplete workflow:
  1. Detects `@` character in the text input
  2. Opens the `MentionPopup` positioned below the cursor
  3. Filters entities as the user continues typing
  4. On selection, inserts a markdown link in the format `[@EntityName](entity://entity_id)`
- Converts plain text to HTML using the `markdown` library with `extra` and `nl2br` extensions
- Applies theme-aware CSS to the rendered HTML (background color, text color, link color, heading colors)

**Key Methods:**

- `set_data_manager(dm)` - Connects the editor to the data manager for entity mention lookups
- `setText(text)` - Sets the plain text content and renders the HTML preview
- `toPlainText()` - Returns the current plain text content
- `switch_to_edit_mode()` - Shows the text edit and hides the browser
- `switch_to_preview_mode()` - Renders the markdown to HTML and shows the browser

**Signal:** `entity_link_clicked(str)` - forwarded from the `ClickableTextBrowser`, emitted when a user clicks an entity mention in the rendered HTML

**Dependencies:** `core.data_manager.DataManager`, `core.locales.tr`, `core.theme_manager.ThemeManager`, `markdown`

**Quality Assessment:**

- The `MentionPopup` contains hardcoded CSS that does not respect the active theme palette
- The HTML rendering applies theme colors through inline CSS in the `_build_html_css()` method, which works but creates long strings of CSS that are difficult to maintain
- The entity mention system is a well-designed feature that integrates cleanly with the existing entity system
- The toggling between edit and preview mode is implemented cleanly with a stacked widget approach
- No type hints or docstrings
- The `@` detection logic correctly handles edge cases like `@` at the start of a line and `@` preceded by whitespace

---

### ui/widgets/map_viewer.py (233 lines)

**Purpose:** A QGraphicsView-based map viewing component that renders timeline pins, entity pins, and supports context menu interactions for pin creation and management.

**Classes:**

*TimelineConnectionItem (QGraphicsPathItem):*
- Renders a Bezier curve connection between two timeline pins
- Used to visually link sequential timeline entries on the world map

*TimelinePinItem (QGraphicsEllipseItem):*
- A circular pin marker for timeline entries
- Displays a day number or session label
- Supports context menu for editing and deletion
- Implements hover effects for visual feedback

*MapPinItem (QGraphicsEllipseItem):*
- A circular pin marker for entity locations
- Displays the entity name as a tooltip
- Supports context menu with options to view entity, move pin, or remove pin
- Implements hover effects

*MapViewer (QGraphicsView):*
- The main map canvas that manages pin items and handles user interactions
- Supports three interaction modes: normal, link placement, and pin moving
- Implements mouse wheel zooming and middle-button panning
- Signals:
  - `pin_created_signal(float, float)` - emitted when a new entity pin is placed
  - `timeline_created_signal(float, float)` - emitted when a new timeline pin is placed (from link mode)
  - `link_placed_signal(float, float)` - emitted when a timeline link is placed on the map
  - `entity_pin_clicked_signal(str)` - emitted when an entity pin is clicked
  - `timeline_pin_clicked_signal(str)` - emitted when a timeline pin is clicked
  - `existing_pin_linked_signal(str)` - emitted when an existing pin is selected during link mode
  - `pin_moved_signal(str, float, float)` - emitted when an entity pin is moved to a new position
  - `timeline_moved_signal(str, float, float)` - emitted when a timeline pin is moved

**Dependencies:** `core.locales.tr`, `core.theme_manager.ThemeManager`

**Quality Assessment:**

- Very compressed code style, especially in the `mousePressEvent` and `contextMenuEvent` methods
- The `contextMenuEvent` at line 228-229 contains an f-string formatting error where a nested f-string uses conflicting quote characters, which may cause a syntax error or incorrect CSS generation
- `ThemeManager.get_active_theme()` calls are present, referencing a nonexistent method with `hasattr()` guards
- The file is 233 lines, which is a reasonable size for the complexity
- Multiple signals provide good separation between the view and the tab controller
- No type hints or docstrings

---

### ui/widgets/image_viewer.py (56 lines)

**Purpose:** A simple image viewer based on QGraphicsView that supports mouse wheel zooming and programmatic image setting.

**Class: ImageViewer (QGraphicsView)**

**Methods:**
- `set_image(pixmap)` - Sets the displayed image from a QPixmap, fitting it to the view bounds
- `update_pixmap(pixmap)` - Updates the displayed image while preserving the current zoom level
- `wheelEvent(event)` - Implements mouse wheel zooming with a factor of 1.15x per scroll notch

**Quality Assessment:**

This is a clean, focused widget with appropriate scope. At 56 lines, it does exactly what it needs to without excess complexity. No significant issues. No type hints but the simplicity makes them less critical here.

---

### ui/widgets/aspect_ratio_label.py (69 lines)

**Purpose:** A QLabel subclass that maintains the aspect ratio of its displayed pixmap when the widget is resized. Also supports drag-and-drop for integration with the ProjectionManager.

**Class: AspectRatioLabel (QLabel)**

**Methods:**
- `setPixmap(pixmap, path=None)` - Stores the original pixmap and optional file path, then triggers a scaled display update
- `setPlaceholderText(text)` - Sets text to display when no image is loaded
- `resizeEvent(event)` - Overrides resize to rescale the pixmap maintaining aspect ratio
- `_update_display()` - Internal method that scales the pixmap to fit the current label size
- `mousePressEvent(event)` - Initiates drag operation with the image path as MIME data

**Quality Assessment:**

Clean and focused at 69 lines. The drag-and-drop integration with the projection system is well-implemented. The `setPixmap` override adds a `path` keyword argument that differs from the QLabel signature, which could be confusing but is handled correctly through the custom implementation.

---

### ui/widgets/mind_map_items.py (456 lines)

**Purpose:** Provides the QGraphicsItem subclasses used by the mind map canvas: resizable nodes with embedded widgets, Bezier curve connections, and workspace grouping regions.

**Classes:**

*ResizeHandle (QGraphicsRectItem):*
- A small rectangular handle positioned at the bottom-right corner of nodes and workspaces
- Changes cursor to size-diagonal on hover
- Used by both MindMapNode and WorkspaceItem for interactive resizing

*ConnectionLine (QGraphicsPathItem):*
- Renders a Bezier curve between two MindMapNode items
- Automatically updates path when either connected node moves
- Uses `cubicTo()` with horizontal control points for smooth S-curves
- Supports context menu for deletion
- Theme-aware: line color is read from the palette

*MindMapNode (QGraphicsObject):*
- The primary node item for the mind map canvas
- Embeds a QWidget (MarkdownEditor, NpcSheet, or ImageViewer) via `QGraphicsProxyWidget`
- Supports three node types: `"note"`, `"entity"`, `"image"` with different background colors
- Implements resizing through the `ResizeHandle`
- Signals: `positionChanged`, `sizeChanged`, `nodeMoved`, `nodeReleased`, `nodeDeleted`, `requestConnection`, `requestProjection`
- Contains `update_theme(palette)` for dynamic theme switching
- Implements context menu with options for projection, connection, and deletion

*WorkspaceItem (QGraphicsObject):*
- A background grouping region with a dashed border and semi-transparent fill
- Uses middle-button for moving to avoid conflicting with the canvas scroll-hand-drag
- Implements resizing through `ResizeHandle`
- Supports context menu with rename, color pick, and delete options
- Signals: `positionChanged`, `sizeChanged`, `workspaceDeleted`, `workspaceRenamed`, `workspaceColorChanged`

**Dependencies:** `core.locales.tr`, `core.theme_manager.ThemeManager`

**Quality Assessment:**

- **Line 303:** Hardcoded CSS in the context menu styling that should use the theme palette. Both `MindMapNode.contextMenuEvent` and `WorkspaceItem.contextMenuEvent` use identical hardcoded dark theme CSS.
- The `MindMapNode` class is well-designed with clean separation between the graphics item behavior and the embedded widget logic.
- `WorkspaceItem` uses middle-button for movement, which is a thoughtful design choice that avoids conflicting with the left-button scroll-hand-drag mode of the parent view.
- **Lines 447-448:** The `_on_rename` and `_on_color_pick` methods import `QInputDialog` and `QColorDialog` inside the method body. While this works, imports should be at the module level.
- Turkish comments are present in several locations
- No type hints or docstrings

---

### ui/widgets/projection_manager.py (232 lines)

**Purpose:** Manages the projection of images to the player window through a thumbnail-based drag-and-drop interface. Appears in the main toolbar when the player window is visible.

**Classes:**

*ProjectionThumbnail (QLabel):*
- A clickable thumbnail that represents a projected image
- Displays a scaled preview of the image with theme-aware border styling
- Click toggles the projection on/off, visually indicated by border color change

*ProjectionManager (QWidget):*
- A horizontal layout of `ProjectionThumbnail` widgets
- Acts as a drop zone that accepts image paths dragged from `AspectRatioLabel` widgets
- Signals: `image_added(str)` - emitted when an image is added to projection, `image_removed(str)` - emitted when an image is removed
- Maintains a list of active projections and synchronizes with the player window

**Dependencies:** `core.locales.tr`, `core.theme_manager.ThemeManager`

**Quality Assessment:**

- Theme-aware styling with palette lookups for border colors and backgrounds
- Clean signal-based communication with the player window
- Reasonable size at 232 lines
- No type hints or docstrings
- The drop zone interaction is well-implemented with visual feedback during drag operations

---

## Code Quality Assessment

### Type Hints

None of the nine files contain any type annotations. This is particularly impactful in `npc_sheet.py` and `combat_tracker.py` where the complex data structures passed between methods would greatly benefit from type definitions.

### Docstrings

- `combat_tracker.py` has one Turkish docstring on `update_highlights()` at line 699
- `npc_sheet.py` has no docstrings despite being 1,003 lines
- All other files have no docstrings
- Several files have occasional inline comments, some in Turkish

### Error Handling

- `combat_tracker.py` contains a bare `except` in the `clean_stat_value` helper function
- `npc_sheet.py` uses try/except blocks in `_populate_unified_combo` but with a generic `except Exception` that only prints to console
- `combat_tracker.py` lines 603, 656, 752, and 800 use bare `except` clauses

### Naming Conventions

- Class names follow PascalCase correctly
- Method names follow snake_case correctly
- Many variable names in `combat_tracker.py` and `npc_sheet.py` are single characters (`d`, `e`, `c`, `v`, `w`, `r`) due to compressed code style

---

## Specific Issues with Line References

| File | Line | Severity | Description |
|------|------|----------|-------------|
| `npc_sheet.py` | All | High | God Class at 1,003 lines with 46 methods combining 6+ responsibilities |
| `npc_sheet.py` | 850 | Medium | `QApplication.processEvents()` in pagination loop risks re-entrant event processing |
| `combat_tracker.py` | 603, 800 | Medium | Bare `except` clauses during stat value parsing |
| `combat_tracker.py` | 675 | Low | Nested function `get_text_safe` defined inside loop iteration |
| `mind_map_items.py` | 303 | Low | Hardcoded CSS in context menu should use theme palette |
| `mind_map_items.py` | 447-448 | Low | Module-level imports placed inside method bodies |
| `map_viewer.py` | 228-229 | Medium | Potential f-string formatting error with nested quotes in CSS |
| `entity_sidebar.py` | Multiple | Low | Hardcoded CSS should use QSS theme system |
| `markdown_editor.py` | Multiple | Low | Hardcoded CSS in MentionPopup should use theme palette |

---

## Prioritized Improvement Recommendations

### Priority 1: Critical

1. **Decompose NpcSheet** into focused components:
   - `EntityFormBuilder` for dynamic form generation from schemas
   - `ImageGalleryWidget` for the image carousel functionality
   - `DocumentManager` for PDF handling
   - `LinkedEntityManager` for spell and item linking
   - Keep `NpcSheet` as a container that composes these components

2. **Replace bare `except` clauses** in `combat_tracker.py` with specific exception handling. The `clean_stat_value` function should catch `ValueError` and `TypeError` specifically.

### Priority 2: High

3. **Extract encounter management** from `CombatTracker` into a separate `EncounterManager` class. The tracker currently handles both UI rendering and encounter data management.

4. **Replace `QApplication.processEvents()`** in `npc_sheet.py` line 850 with a proper asynchronous approach using QThread workers for API pagination.

5. **Decompress the code style** throughout `combat_tracker.py` and `npc_sheet.py`. Split compound semicolon-separated statements into separate lines.

### Priority 3: Medium

6. **Add type hints** to public method signatures across all files, prioritizing `npc_sheet.py` and `combat_tracker.py`.

7. **Centralize the `translate_category` mapping** from `entity_sidebar.py` to a shared location, possibly in `core/models.py`.

8. **Move hardcoded CSS** from `entity_sidebar.py`, `markdown_editor.py`, and `mind_map_items.py` into the QSS theme system or use palette-based inline styles consistently.

9. **Fix the potential f-string error** in `map_viewer.py` line 228-229 where nested f-strings may produce invalid CSS.

### Priority 4: Low

10. **Add docstrings** to all public methods and classes across all nine files.

11. **Translate Turkish comments** to English throughout all files.

12. **Move method-level imports** in `mind_map_items.py` to the module level.

---

## Dependency Graph

```
ui/widgets/npc_sheet.py
  -> core.data_manager, core.models, core.locales, core.theme_manager, config
  -> ui.workers.ImageDownloadWorker

ui/widgets/combat_tracker.py
  -> core.data_manager, core.locales, core.theme_manager
  -> ui.windows.battle_map_window (BattleMapWindow)
  -> ui.dialogs.encounter_selector

ui/widgets/entity_sidebar.py
  -> core.data_manager, core.locales, core.theme_manager

ui/widgets/markdown_editor.py
  -> core.data_manager, core.locales, core.theme_manager
  -> markdown (external library)

ui/widgets/map_viewer.py
  -> core.locales, core.theme_manager

ui/widgets/image_viewer.py
  -> (no project dependencies, pure PyQt6)

ui/widgets/aspect_ratio_label.py
  -> (no project dependencies, pure PyQt6)

ui/widgets/mind_map_items.py
  -> core.locales, core.theme_manager

ui/widgets/projection_manager.py
  -> core.locales, core.theme_manager
```
