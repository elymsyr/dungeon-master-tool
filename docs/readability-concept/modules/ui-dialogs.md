# UI Dialogs Module Documentation

## Module Overview

The UI Dialogs module contains modal and semi-modal dialog windows that handle specific user interactions requiring focused input or selection. These dialogs are invoked from tabs, widgets, and the main window to perform operations such as browsing the D&D 5e API, bulk downloading content, selecting entities for encounters, importing local and online content, building audio themes, and creating timeline entries.

The module is responsible for:

- Providing a browsable, searchable interface to two D&D 5e API backends with preview and import capabilities
- Offering bulk download of all SRD content from the dnd5e API with progress tracking
- Presenting entity selection dialogs for encounter building and general multi-select operations
- Delivering a two-tab import window for both local library browsing and online API access
- Supplying an audio theme builder for creating music themes with states and intensity levels
- Creating timeline entries with day, session, and entity associations for the world map

---

## File Inventory

| File | Lines of Code | Classes | Key Responsibility |
|------|--------------|---------|-------------------|
| `ui/dialogs/api_browser.py` | 491 | 1 | D&D 5e API browsing with search, preview, and import |
| `ui/dialogs/bulk_downloader.py` | 291 | 2 | Bulk SRD content download with progress tracking |
| `ui/dialogs/encounter_selector.py` | 212 | 1 | Entity selection for combat encounter building |
| `ui/dialogs/entity_selector.py` | 122 | 1 | General-purpose multi-select entity picker |
| `ui/dialogs/import_window.py` | 423 | 3 | Two-tab import dialog for local and online content |
| `ui/dialogs/theme_builder.py` | 188 | 1 | Audio theme creation with states and intensity tracks |
| `ui/dialogs/timeline_entry.py` | 135 | 1 | Timeline pin creation with day, session, and entity data |

**Total: 1,862 lines of code, 10 classes**

---

## Architecture and Data Flow

```
+------------------+     +-------------------+
|  database_tab.py |---->| ApiBrowser        |---> DndApiClient
|                  |---->| ImportWindow       |---> library_fs
+------------------+     +-------------------+
                                |
                                v
                          DataManager.add_entity()

+------------------+     +-------------------+
| combat_tracker   |---->| EncounterSelector |---> DataManager entities
+------------------+     +-------------------+

+------------------+     +-------------------+
| mind_map_tab     |---->| EntitySelector    |---> DataManager entities
| map_tab          |---->|                   |
+------------------+     +-------------------+

+------------------+     +-------------------+
| soundpad_panel   |---->| ThemeBuilder      |---> audio/loader
+------------------+     +-------------------+

+------------------+     +-------------------+
| map_tab          |---->| TimelineEntry     |---> DataManager sessions
+------------------+     +-------------------+

+------------------+     +-------------------+
| ApiBrowser       |---->| BulkDownloader    |---> DndApiClient
+------------------+     +-------------------+
```

---

## Per-File Detailed Analysis

### ui/dialogs/api_browser.py (491 lines)

**Purpose:** A comprehensive dialog for browsing, searching, previewing, and importing content from D&D 5e APIs. Supports two source backends (dnd5eapi.co and open5e.com) with source-specific UI adaptations, server-side and client-side search, pagination, and a selection mode for use as an entity picker.

**Class: ApiBrowser (QDialog)**

**Layout Structure:**
- Top bar: Source selector combo box, category selector combo box, document filter combo box (Open5e only), bulk download button (dnd5e only)
- Left panel: Search input with 600ms debounce timer, paginated entity list, pagination controls (prev/next/page label)
- Right panel: Entity name label, description text area, import button, "Import as NPC" button (for monsters)

**Key Methods:**

- `__init__(dm, parent, category, selection_mode)` - Accepts a `selection_mode` parameter that changes the dialog behavior from import-and-close to select-and-return, used when other dialogs need to pick an entity from the API
- `refresh_categories()` - Repopulates the category combo box based on the active API source's supported categories
- `load_list()` - Initiates an asynchronous API index request using `ApiListWorker`. Handles debounce timer cancellation, worker thread management, and filter assembly.
- `on_list_loaded(data)` - Processes the API response, updating the entity list and pagination state
- `filter_list()` - Performs client-side filtering of the loaded list based on the search input. Skips local filtering when the server has already applied a search query.
- `on_item_clicked(item)` - Triggers an asynchronous detail fetch using `ApiSearchWorker`
- `on_details_loaded(success, data_or_id, msg)` - Handles the detail response, distinguishing between already-imported entities (returns ID string) and new entities (returns data dict). Adapts the import button text and behavior based on entity state and category.
- `import_selected(target_type)` - Performs the actual import through `DataManager.import_entity_with_dependencies()`. Supports type override for importing monsters as NPCs.
- `on_source_changed()` - Switches the active API source and refreshes the UI
- `update_source_ui()` - Shows/hides source-specific UI elements (document filter for Open5e, bulk download for dnd5e)
- `on_search_submit()` - Called on Enter keypress, triggers immediate server search
- `on_text_changed(text)` - Called on every keystroke, starts the debounce timer and applies local filtering

**Worker Threads:**
- Uses `ApiListWorker` (from `ui.workers`) for asynchronous index loading
- Uses `ApiSearchWorker` (from `ui.workers`) for asynchronous detail fetching
- Properly manages worker lifecycle: disconnects old signals, quits running workers, and deletes them before creating new ones

**Dependencies:** `core.data_manager.DataManager`, `core.locales.tr`, `ui.workers.ApiSearchWorker`, `ui.workers.ApiListWorker`, `ui.dialogs.bulk_downloader.BulkDownloadDialog`

**Quality Assessment:**

- The 600ms debounce timer for search is a well-implemented UX pattern that prevents excessive API calls during rapid typing
- The dual-mode (browse/select) design through the `selection_mode` parameter is a clean approach that avoids code duplication
- **Lines 203-206, 353, 381-383, 407-410:** Multiple bare `except` clauses that silently catch exceptions during worker disconnection and signal handling
- The cache write error detection at line 367-371 is an interesting approach but appends hardcoded English text rather than using the localization system
- The method `on_details_loaded` is approximately 80 lines long and handles multiple code paths based on entity state, category, and mode. It would benefit from decomposition.
- No type hints or docstrings on any methods
- The pagination UI properly enables/disables prev/next buttons based on API response metadata

---

### ui/dialogs/bulk_downloader.py (291 lines)

**Purpose:** Provides a dialog for downloading all SRD content from the dnd5e API with progress tracking. Uses a worker thread for background downloading and displays real-time progress.

**Classes:**

*DownloadWorker (QThread):*
- Performs the actual HTTP requests in a background thread
- Iterates through all supported categories, fetching the index and then each individual item
- Signal: `progress(int, str)` - emits progress percentage and current item name
- Signal: `finished(bool, str)` - emits completion status and summary message
- Signal: `error(str)` - emits error messages for individual item failures (non-fatal)
- Supports cancellation through a `cancelled` flag checked in the download loop

*BulkDownloadDialog (QDialog):*
- Creates and manages the `DownloadWorker`
- Displays a progress bar and status label
- Provides start and cancel buttons
- **Hardcoded CSS throughout** the dialog for styling the progress bar and buttons

**Dependencies:** `core.data_manager.DataManager`, `core.locales.tr`

**Quality Assessment:**

- The worker thread pattern is correctly implemented with proper signal/slot communication
- The cancellation mechanism is clean and checks the flag at each iteration
- **Hardcoded CSS** is extensive, covering the progress bar, buttons, and dialog background. These should use the QSS theme system.
- Error handling for individual download failures is well-designed: errors are collected and reported without stopping the entire download process
- No type hints or docstrings
- The dialog width is hardcoded to 500 pixels rather than using a responsive layout

---

### ui/dialogs/encounter_selector.py (212 lines)

**Purpose:** A dialog for selecting entities to add to a combat encounter. Displays a table of all combat-capable entities (NPCs, Monsters, Players) with filtering and multi-select support.

**Class: EncounterSelectionDialog (QDialog)**

**Features:**
- Table display with columns: Name, Type, HP, AC, Initiative Bonus
- Category filter combo box (All, NPC, Monster, Player)
- Text search filter
- Multi-select support via checkboxes or Ctrl-click
- Calculates initiative bonus from DEX modifier and initiative stat
- Returns list of selected entity IDs via `self.selected_entities`

**Key Methods:**
- `populate_list()` - Fills the table with all combat-capable entities, computing initiative bonuses
- `filter_list()` - Applies text search and category filter to show/hide table rows
- `accept()` - Collects selected entity IDs and closes the dialog

**Dependencies:** `core.data_manager.DataManager`, `core.locales.tr`

**Quality Assessment:**

- **`_parse_int` helper** contains a bare `except` clause that returns a default value on any parsing failure. This should specifically catch `ValueError` and `TypeError`.
- The initiative bonus calculation duplicates logic from `CombatTracker.add_row_from_entity`, which computes the same value. This should be centralized in a utility function or the entity model.
- Clean dialog design with appropriate use of table widgets for tabular data
- No type hints or docstrings

---

### ui/dialogs/entity_selector.py (122 lines)

**Purpose:** A general-purpose entity selection dialog that displays all entities (or a filtered subset) with multi-select support. Used by the mind map tab and map tab for entity-related operations.

**Class: EntitySelectorDialog (QDialog)**

**Features:**
- Filterable entity list with text search
- Optional type filter (can restrict to specific entity types)
- Multi-select support
- Returns list of selected entity IDs

**Dependencies:** `core.data_manager.DataManager`, `core.locales.tr`, `core.theme_manager.ThemeManager`

**Quality Assessment:**

- **Hardcoded inline CSS** with `ThemeManager` palette calls mixed into the widget construction. While this is technically theme-aware, it bypasses the QSS system and creates hard-to-maintain style strings.
- At 122 lines, this is appropriately compact for a simple selection dialog
- No type hints or docstrings
- The filtering mechanism is straightforward and effective

---

### ui/dialogs/import_window.py (423 lines)

**Purpose:** A two-tab import dialog that provides both local filesystem library browsing and online API search capabilities in a single interface.

**Classes:**

*LibraryScanWorker (QThread):*
- Scans the local library directory tree in a background thread
- Signal: `finished(dict)` - emits the scanned library tree structure
- Delegates to `library_fs.scan_library_tree()` for the actual scanning

*LocalLibraryTab (QWidget):*
- Displays the local library as a searchable tree widget
- Supports category browsing, text search, and entity preview
- Import action converts library entries into campaign entities via `DataManager`

*OnlineApiTab (QWidget):*
- Wraps the `ApiBrowser` dialog functionality in a tab-friendly widget
- Provides source selection (dnd5e/open5e), category browsing, and search
- Delegates actual import to `DataManager` through the API client

*ImportWindow (QDialog):*
- Contains a `QTabWidget` with the two tabs described above
- Signal: `entity_imported(str)` - emitted after a successful import with the new entity ID
- Handles the coordination between local and online import workflows

**Dependencies:** `core.data_manager.DataManager`, `core.locales.tr`, `core.library_fs.scan_library_tree`, `core.library_fs.search_library_tree`

**Quality Assessment:**

- The two-tab design is a thoughtful UX choice that consolidates import functionality in one place
- The `LibraryScanWorker` properly uses a background thread for filesystem scanning
- The local library tab provides a good browsing experience with tree navigation
- No type hints or docstrings
- The interaction between `OnlineApiTab` and the existing `ApiBrowser` could benefit from code sharing rather than reimplementation

---

### ui/dialogs/theme_builder.py (188 lines)

**Purpose:** A dialog for creating audio themes that define music states and intensity levels. Each theme maps musical states (e.g., "calm", "battle", "exploration") to audio tracks at different intensity levels.

**Class: ThemeBuilderDialog (QDialog)**

**Features:**
- Theme name and ID input fields
- Dynamic state/intensity grid: each state has up to 4 intensity levels, each pointing to an audio file
- File browser buttons for selecting audio files for each slot
- Slug generation from the theme name for the ID field
- Returns the theme definition as a dictionary via `get_data()`

**Key Methods:**
- `add_state_row(name)` - Adds a new row to the state grid with file selectors for each intensity level
- `get_data()` - Collects all input values and returns a structured theme definition dictionary
- `_slugify(name)` - Converts a theme name to a URL-safe slug for use as the theme ID

**Dependencies:** `core.locales.tr`

**Quality Assessment:**

- Clean, focused dialog at 188 lines
- The dynamic grid generation for states and intensity levels is well-implemented
- No type hints or docstrings
- The slug generation is simple but adequate for the use case
- The dialog does not validate that audio files exist at the specified paths before returning

---

### ui/dialogs/timeline_entry.py (135 lines)

**Purpose:** A dialog for creating and editing timeline pin entries on the world map. Associates a map location with a specific day, session, and set of entities.

**Class: TimelineEntryDialog (QDialog)**

**Features:**
- Day number input (spin box)
- Session selector combo box populated from `DataManager`
- Entity selection with checkable lists for Players, NPCs, and Monsters
- Notes field using `MarkdownEditor` for rich text
- Returns the timeline entry data via `get_data()`

**Dependencies:** `core.data_manager.DataManager`, `core.locales.tr`, `ui.widgets.markdown_editor.MarkdownEditor`

**Quality Assessment:**

- Compact and focused at 135 lines
- Properly separates entity types into distinct checkable lists for better organization
- Uses `MarkdownEditor` for the notes field, providing consistent rich text editing
- No type hints or docstrings
- Entity lists are populated during initialization, which means the dialog does not reflect entities added after the dialog was opened (acceptable for a modal dialog)

---

## Code Quality Assessment

### Type Hints

None of the seven files contain any type annotations. The `ApiBrowser` class in particular would benefit from typed signatures given the complexity of its data flow between worker threads and UI updates.

### Docstrings

No classes or methods in any of the seven files have docstrings. The only documentation is occasional inline comments, some of which are in Turkish.

### Error Handling

- `api_browser.py` contains multiple bare `except` clauses for worker signal disconnection
- `encounter_selector.py` has a bare `except` in the `_parse_int` helper
- `bulk_downloader.py` properly collects individual download errors without stopping the batch
- `import_window.py` handles filesystem scanning failures through the worker thread pattern

### Naming Conventions

- Class names follow PascalCase correctly throughout
- Method names follow snake_case correctly throughout
- The `ApiBrowser` uses clear naming for its many methods, though some like `on_list_loaded` and `on_details_loaded` could be more specific

---

## Specific Issues with Line References

| File | Line | Severity | Description |
|------|------|----------|-------------|
| `api_browser.py` | 203-206 | Medium | Bare `except` clauses during worker thread disconnection |
| `api_browser.py` | 353, 381-383, 407-410 | Medium | Additional bare `except` clauses in signal handling |
| `api_browser.py` | 367-371 | Low | Hardcoded English text for cache write error feedback |
| `bulk_downloader.py` | Multiple | Medium | Extensive hardcoded CSS that bypasses the QSS theme system |
| `encounter_selector.py` | `_parse_int` | Low | Bare `except` clause should catch `ValueError` and `TypeError` specifically |
| `entity_selector.py` | Multiple | Low | Hardcoded inline CSS with palette calls should use QSS |

---

## Prioritized Improvement Recommendations

### Priority 1: Critical

1. **Replace bare `except` clauses** in `api_browser.py` with specific exception types. For worker disconnection, catch `TypeError` (the exception raised when disconnecting an unconnected signal). For general error handling, catch `Exception` and log appropriately.

### Priority 2: High

2. **Decompose `ApiBrowser.on_details_loaded`** into smaller methods. The current 80-line method handles multiple code paths that should be separate methods: `_handle_existing_entity`, `_handle_new_entity`, `_display_entity_details`.

3. **Centralize initiative bonus calculation** that is duplicated between `encounter_selector.py` and `combat_tracker.py` into a utility function in `core/models.py` or a new `core/combat_utils.py`.

4. **Move hardcoded CSS** from `bulk_downloader.py` and `entity_selector.py` into the QSS theme system.

### Priority 3: Medium

5. **Add type hints** to all dialog class constructors and public methods. The `ApiBrowser` constructor is particularly important given its multiple parameters that affect behavior.

6. **Add docstrings** to all dialog classes describing their purpose, parameters, and return behavior.

7. **Add audio file validation** to `theme_builder.py` before returning theme data, warning the user if referenced files do not exist.

### Priority 4: Low

8. **Translate Turkish comments** to English across all files.

9. **Replace hardcoded English text** in `api_browser.py` line 371 with a `tr()` call.

10. **Add responsive layout** to `bulk_downloader.py` instead of hardcoded 500px width.

---

## Dependency Graph

```
ui/dialogs/api_browser.py
  -> core.data_manager, core.locales
  -> ui.workers (ApiSearchWorker, ApiListWorker)
  -> ui.dialogs.bulk_downloader

ui/dialogs/bulk_downloader.py
  -> core.data_manager, core.locales

ui/dialogs/encounter_selector.py
  -> core.data_manager, core.locales

ui/dialogs/entity_selector.py
  -> core.data_manager, core.locales, core.theme_manager

ui/dialogs/import_window.py
  -> core.data_manager, core.locales
  -> core.library_fs (scan_library_tree, search_library_tree)

ui/dialogs/theme_builder.py
  -> core.locales

ui/dialogs/timeline_entry.py
  -> core.data_manager, core.locales
  -> ui.widgets.markdown_editor
```
