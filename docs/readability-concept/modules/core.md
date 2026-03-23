# Core Module Documentation

## Module Overview

The core module serves as the foundational backbone of the Dungeon Master Tool application. It contains the primary data management layer, entity schema definitions, external API integration for D&D 5e content, filesystem-based library management, internationalization support, visual theme management, and application-wide configuration. Every UI component in the application depends on at least one file in this module, making it the most architecturally significant and highest-risk area of the codebase.

The module is responsible for:

- Persisting and loading campaign data using MsgPack binary serialization with JSON fallback
- Defining entity schemas for all supported D&D entity types (NPC, Monster, Player, Spell, Equipment, Location, Lore, Status Effect)
- Integrating with two external D&D content APIs (dnd5eapi.co and open5e.com)
- Managing a local filesystem-based content library with migration support
- Providing internationalization through a thin wrapper around the python-i18n library
- Managing visual themes with a palette-based color system supporting eleven distinct themes
- Resolving application paths and loading configuration with a three-tier priority system

---

## File Inventory

| File | Lines of Code | Classes | Functions | Key Responsibility |
|------|--------------|---------|-----------|-------------------|
| `config.py` | 147 | 0 | 2 | Path resolution, theme loading, application constants |
| `core/data_manager.py` | 678 | 1 | ~45 methods | Central data persistence, CRUD operations, campaign management |
| `core/models.py` | 198 | 0 | 1 | Entity schemas, legacy mapping tables, default entity structure |
| `core/api_client.py` | 706 | 4 | ~30 methods | D&D 5e API integration with two source backends |
| `core/library_fs.py` | 251 | 0 | 3 | Filesystem library scanning, migration, and search |
| `core/locales.py` | 27 | 0 | 2 | Internationalization wrapper for python-i18n |
| `core/theme_manager.py` | 285 | 1 | 1 static method | Theme palette management with eleven visual themes |

**Total: 2,292 lines of code, 6 classes, approximately 84 methods and functions**

---

## Architecture and Data Flow

```
                    +------------------+
                    |    config.py     |
                    | (paths, consts)  |
                    +--------+---------+
                             |
                             v
                    +------------------+
                    |  DataManager     |
                    | (data_manager.py)|
                    +--+----+----+----++
                       |    |    |    |
              +--------+    |    |    +--------+
              v             v    v             v
      +-------+----+ +-----+--+ +------+  +---+--------+
      | api_client  | | models | |locale|  | library_fs |
      | (DndApi     | | (schema| |(i18n)|  | (scan,     |
      |  Client)    | |  defs) | +------+  |  search)   |
      +-------------+ +--------+           +------------+
              |
              v
      +-------+------+
      | ThemeManager  |
      | (palettes)    |
      +--------------+
```

### Data Persistence Flow

1. The application creates a `DataManager` instance during startup.
2. `DataManager` loads campaign data from a MsgPack binary file (`campaign.dat`), falling back to JSON (`data.json`) for legacy compatibility.
3. All entity CRUD operations pass through `DataManager`, which modifies an in-memory dictionary and persists changes on save.
4. Session data (combat state, notes, logs) is stored within the same campaign data structure.
5. Settings (language, theme) are stored in a separate `settings.json` file at the data root level.

### API Integration Flow

1. `DndApiClient` acts as an orchestrator, delegating to either `Dnd5eApiSource` or `Open5eApiSource`.
2. API responses are cached locally in JSON files under the cache directory.
3. Parsed API data is transformed into the application's internal entity format defined in `models.py`.
4. The `DataManager` provides high-level methods (`fetch_from_api`, `get_api_index`, `fetch_details_from_api`) that delegate to `DndApiClient`.

---

## Per-File Detailed Analysis

### config.py (147 lines)

**Purpose:** Application-wide configuration, path resolution, and theme stylesheet loading. This is the best-documented file in the entire codebase, with clear docstrings and consistent style.

**Key Constants:**
- `APP_NAME` - Application identifier string
- `WORLDS_DIR` - Path to the directory containing campaign worlds
- `CACHE_DIR` - Path to the API response cache directory
- `API_BASE_URL` - Base URL for the primary D&D 5e API
- `DATA_ROOT` - Resolved root path for all persistent data
- `DATA_ROOT_MODE` - Indicates which priority tier was used ("env", "portable", or "fallback")

**Functions:**
- `resolve_data_root()` - Implements a three-tier priority system for determining the data storage root: (1) `DM_DATA_ROOT` environment variable, (2) a `portable_data` directory adjacent to the application, (3) a fallback to the user's home directory under `.dm_tool`. Returns a tuple of the resolved path and the mode string.
- `load_theme(theme_name)` - Loads a QSS stylesheet file from the themes directory. Falls back to the `dark.qss` theme if the requested theme file does not exist. Returns an empty string if no theme files are found at all.

**Dependencies:** `os`, `pathlib.Path`

**Quality Assessment:** This file demonstrates exemplary code quality. It uses dependency injection patterns (the `resolve_data_root` function accepts no mutable global state), has comprehensive docstrings, and follows clean naming conventions. The three-tier path resolution strategy is well-documented and handles edge cases gracefully.

---

### core/data_manager.py (678 lines)

**Purpose:** Central data management class that handles all persistence, entity CRUD operations, campaign lifecycle management, session management, and API delegation. This is the largest and most critical class in the application.

**Class: DataManager**
- **Approximately 45 methods** spanning CRUD, file I/O, API delegation, library management, migration logic, and session management
- Uses MsgPack as the primary serialization format with JSON as a fallback
- Maintains an in-memory dictionary (`self.data`) that mirrors the persisted campaign state

**Key Method Groups:**

*Campaign Lifecycle:*
- `load_campaign_by_name(name)` - Loads a campaign from disk by world name
- `create_campaign(name)` - Creates a new campaign directory and initializes default data
- `get_available_campaigns()` - Lists all available campaign directories
- `save_data()` - Persists the in-memory data to disk using MsgPack

*Entity CRUD:*
- `add_entity(data)` - Creates a new entity with a UUID and adds it to the data store
- `save_entity(eid, data)` - Updates an existing entity
- `delete_entity(eid)` - Removes an entity from the data store
- `get_entity(eid)` - Retrieves an entity by its identifier

*Session Management:*
- `create_session(name)` - Creates a new session entry
- `save_session_data(sid, notes, logs, combat_state)` - Persists session state
- `get_session(sid)` - Retrieves session data by identifier
- `get_last_active_session_id()` - Returns the most recently active session
- `set_active_session(sid)` - Marks a session as the currently active one

*API Delegation:*
- `fetch_from_api(category, query)` - Delegates to `DndApiClient` for fetching entity data
- `get_api_index(category, page, filters)` - Retrieves paginated API index data
- `fetch_details_from_api(category, identifier)` - Fetches detailed entity data from the API
- `import_entity_with_dependencies(data, type_override)` - Imports an API entity and resolves cross-references

*File Management:*
- `import_image(source_path)` - Copies an image file into the campaign's assets directory
- `import_pdf(source_path)` - Copies a PDF file into the campaign's assets directory
- `get_full_path(relative_path)` - Resolves a relative asset path to an absolute filesystem path

**Signals:** None (this is a plain Python class, not a QObject)

**Dependencies:** `config` (DATA_ROOT, WORLDS_DIR, CACHE_DIR), `core.models`, `core.api_client`, `core.library_fs`, `msgpack`, `json`, `uuid`, `os`, `shutil`, `pathlib`

**Quality Assessment:**

This class is the most significant architectural concern in the codebase. It exhibits the God Class anti-pattern, combining at least five distinct responsibilities into a single 678-line class:

1. *Data persistence and serialization* - Should be extracted into a dedicated persistence layer
2. *Entity CRUD operations* - Could be a separate repository pattern class
3. *Campaign lifecycle management* - Warrants its own manager class
4. *API delegation* - Should be handled by a service layer
5. *File management (images, PDFs)* - Should be an asset manager

Specific issues:
- **Line 113:** Bare `except` clause that silently catches all exceptions during data loading, potentially masking corruption or permission errors
- **Turkish comments throughout** the file reduce readability for international contributors
- **No type hints** on any method signatures
- **No docstrings** on any methods
- **Mixed abstraction levels** - some methods handle raw file I/O while others orchestrate business logic

---

### core/models.py (198 lines)

**Purpose:** Defines entity schemas as nested dictionaries, provides legacy Turkish-to-English field mapping tables, and offers a factory function for creating default entity structures.

**Key Data Structures:**

- `ENTITY_SCHEMAS` - A dictionary mapping entity type names to lists of field definitions. Each field is a tuple of `(label_key, data_type, options)`. Supported types include `"text"`, `"combo"`, and `"entity_select"`. This structure drives the dynamic form generation in the `NpcSheet` widget.

- `SCHEMA_MAP` - A dictionary mapping legacy Turkish schema keys to their English equivalents. Used during data migration to normalize old campaign files.

- `PROPERTY_MAP` - A dictionary mapping legacy Turkish property names to English. Works in conjunction with `SCHEMA_MAP` for full migration support.

**Functions:**
- `get_default_entity_structure()` - Returns a dictionary with all default fields for a new entity, including empty combat stats, empty ability scores, empty images list, and placeholder values.

**Quality Assessment:**

- **Line 155:** Contains a hardcoded Turkish default value `"Yeni Kayit"` (meaning "New Record") that should use the localization system instead
- The schema definition approach using nested tuples is fragile and lacks type safety. This is a prime candidate for conversion to dataclasses or TypedDict definitions
- The legacy mapping tables (`SCHEMA_MAP`, `PROPERTY_MAP`) represent technical debt from the application's Turkish-language origins and should eventually be removed once all existing campaign data has been migrated
- No type hints or docstrings are present

---

### core/api_client.py (706 lines)

**Purpose:** Provides integration with two external D&D 5e content APIs, handling HTTP requests, response parsing, caching, and data transformation into the application's internal entity format.

**Classes:**

*ApiSource (Abstract Base):*
- Defines the interface for API source implementations
- Methods: `get_supported_categories()`, `get_index()`, `get_details()`, `parse_monster()`, `parse_spell()`, `parse_equipment()`, and other parse methods

*Dnd5eApiSource:*
- Implements `ApiSource` for the dnd5eapi.co API
- Handles pagination, caching to local JSON files, and parsing of all supported entity types
- Contains parse methods for: monsters, spells, equipment, races, classes, conditions, features, traits, backgrounds, feats, magic items, and rule sections

*Open5eApiSource:*
- Implements `ApiSource` for the open5e.com API
- Supports document-level filtering (SRD, third-party content)
- Provides `get_documents()` for retrieving available source documents
- Contains its own set of parse methods for monsters, spells, and equipment

*DndApiClient (Orchestrator):*
- Maintains a reference to the currently active source
- Provides `set_source(key)` to switch between `"dnd5e"` and `"open5e"` backends
- Delegates all operations to the active source implementation
- Manages the cache directory path

**Quality Assessment:**

- **Approximately 80% logic duplication** between `Dnd5eApiSource.parse_monster()` and `Open5eApiSource.parse_monster()`. Both methods construct the same internal entity structure but from slightly different JSON schemas. This duplication should be refactored into a shared transformation layer with source-specific adapters.
- **Line 689:** Bare `except` clause in the cache writing logic that silently swallows write failures. This is particularly problematic for read-only media scenarios (USB drives, network shares) where the user receives no indication that caching is not working.
- **No type hints** on method signatures
- **No docstrings** on classes or methods
- The caching strategy writes individual JSON files per API response. There is no cache invalidation, size limiting, or TTL mechanism.

---

### core/library_fs.py (251 lines)

**Purpose:** Manages a filesystem-based content library, providing functions for scanning directory trees, searching for content, and migrating from legacy flat file layouts to a structured hierarchy.

**Functions:**

- `migrate_legacy_layout(library_root)` - Detects and converts old flat-file library structures into a categorized directory hierarchy. Returns a report dictionary with counts of migrated files, errors encountered, and directories created. This function is idempotent and safe to run multiple times.

- `scan_library_tree(library_root)` - Recursively scans the library directory and returns a structured dictionary representing the content hierarchy. Each entry includes the file name, relative path, category (inferred from directory structure), and file size.

- `search_library_tree(tree, query)` - Performs case-insensitive substring matching across the library tree, returning all entries whose names contain the query string.

**Quality Assessment:**

This is the highest-quality file in the entire codebase. Notable positive attributes:

- Clean, descriptive docstrings on all functions
- Proper error handling with the report dictionary pattern (collecting errors rather than raising or silently swallowing them)
- No Turkish comments or hardcoded strings
- Clear separation of concerns with each function having a single, well-defined responsibility
- The migration function demonstrates defensive programming by checking preconditions before modifying the filesystem

This file should serve as the quality benchmark for the rest of the codebase.

---

### core/locales.py (27 lines)

**Purpose:** Thin wrapper around the `python-i18n` library that configures the localization system and exports convenience functions.

**Functions:**

- `tr(key, **kwargs)` - Translation function that looks up a localization key and returns the translated string. Accepts keyword arguments for string interpolation. This function is imported and used extensively throughout the entire codebase.

- `set_language(code)` - Sets the active language for all subsequent `tr()` calls. Accepts language codes such as `"EN"`, `"TR"`, `"DE"`, `"FR"`.

**Configuration:**
- Sets the i18n file format to YAML
- Points the locale file path to the `locales/` directory relative to the project root
- Sets the fallback locale to English (`"en"`)

**Dependencies:** `i18n`, `pathlib.Path`

**Quality Assessment:**

This file is appropriately minimal for a wrapper module. The `tr()` function is the single most frequently called function across the entire codebase, appearing in virtually every UI file. There are no issues with this file itself, but several callers misuse the `tr` function by checking `hasattr(tr, "SOME_KEY")`, which tests whether the function object has an attribute with that name (it never does), rather than checking whether the translation key exists in the locale files.

---

### core/theme_manager.py (285 lines)

**Purpose:** Manages visual theme palettes for the application. Contains a static method for retrieving palette dictionaries and defines eleven distinct color themes.

**Class: ThemeManager**

- **Static Method: `get_palette(theme_name)`** - Returns a dictionary of approximately 90 color entries for the specified theme. Falls back to the `"dark"` palette if the requested theme is not found.

**Data Structures:**

- `DEFAULT_PALETTE` - A dictionary containing approximately 90 color key-value pairs covering every visual element in the application: backgrounds, text colors, borders, syntax highlighting colors, HP bar gradients, markdown rendering colors, node colors for mind maps, token borders for battle maps, and floating UI element colors.

- `PALETTES` - A dictionary mapping theme names to palette dictionaries. Each theme palette is created by copying `DEFAULT_PALETTE` and overriding specific color values. The eleven themes are: `dark`, `light`, `parchment`, `ocean`, `emerald`, `midnight`, `discord`, `baldur`, `grim`, `frost`, and `amethyst`.

**Quality Assessment:**

- **Turkish docstring and comments** throughout the file, including the class docstring and inline comments explaining color choices
- The `ThemeManager` class is essentially a namespace for a single static method and a data structure. It does not need to be a class at all; a module-level function and dictionary would suffice.
- Multiple UI files call `ThemeManager.get_active_theme()`, but this method does not exist on the class. This results in `AttributeError` at runtime unless guarded by `hasattr()` checks, which several callers do. The actual active theme name is stored on `DataManager`, not on `ThemeManager`.
- The palette dictionary approach works well for the application's needs but lacks any validation that required keys are present when a new theme is defined.
- No type hints are present.

---

## Code Quality Assessment

### Type Hints

Only `config.py` shows any evidence of type awareness through its function signatures. The remaining six files in this module have zero type annotations. This makes the codebase difficult to analyze with static analysis tools and increases the risk of type-related runtime errors.

### Docstrings

- `config.py` has complete docstrings on both functions
- `library_fs.py` has complete docstrings on all three functions
- `data_manager.py` has no docstrings on any of its approximately 45 methods
- `api_client.py` has no docstrings on any classes or methods
- `models.py` has no docstrings
- `theme_manager.py` has a Turkish docstring on the class but no method docstrings

### Error Handling

- `library_fs.py` demonstrates exemplary error handling with its report dictionary pattern
- `data_manager.py` line 113 uses a bare `except` that silently catches all exceptions during data loading
- `api_client.py` line 689 uses a bare `except` that silently catches cache write failures
- `config.py` handles missing theme files gracefully with fallback behavior

### Naming Conventions

- `config.py` uses clear, descriptive constant and function names
- `data_manager.py` method names are generally clear but some are overly generic (`save_data`, `add_entity`)
- `models.py` uses SCREAMING_SNAKE_CASE appropriately for module-level constants
- Variable names in `api_client.py` are sometimes single-letter or abbreviated (`d`, `e`, `c`)

### Internationalization

- `locales.py` properly configures the i18n system
- `data_manager.py` contains Turkish comments that should be translated to English
- `theme_manager.py` contains Turkish docstrings and comments
- `models.py` line 155 contains a hardcoded Turkish string as a default value

---

## Specific Issues with Line References

| File | Line | Severity | Description |
|------|------|----------|-------------|
| `data_manager.py` | 113 | High | Bare `except` clause silently catches all exceptions during MsgPack deserialization, potentially masking data corruption |
| `api_client.py` | 689 | Medium | Bare `except` clause silently swallows cache write failures, leaving users unaware of read-only media issues |
| `models.py` | 155 | Low | Hardcoded Turkish default value `"Yeni Kayit"` should use `tr()` localization function |
| `theme_manager.py` | N/A | Medium | `get_active_theme()` method is called by multiple UI files but does not exist on the class, requiring `hasattr()` guards |
| `data_manager.py` | All | Medium | Zero docstrings across approximately 45 methods in the most critical class |
| `api_client.py` | Multiple | Medium | Approximately 80% logic duplication between the two source implementations of `parse_monster()` |

---

## Prioritized Improvement Recommendations

### Priority 1: Critical (Safety and Correctness)

1. **Replace bare `except` clauses** in `data_manager.py` line 113 and `api_client.py` line 689 with specific exception types. At minimum, catch `Exception` and log the error. For the data loading path, consider catching `msgpack.UnpackException` and `json.JSONDecodeError` separately with different recovery strategies.

2. **Add the missing `get_active_theme()` method** to `ThemeManager`, or refactor all callers to obtain the active theme name from `DataManager` instead. The current state causes silent failures guarded by `hasattr()` checks scattered across the codebase.

### Priority 2: High (Maintainability)

3. **Decompose the DataManager God Class** into focused components:
   - `CampaignManager` for campaign lifecycle (create, load, list, save)
   - `EntityRepository` for entity CRUD operations
   - `AssetManager` for image and PDF file management
   - `SessionManager` for session-related operations
   - Keep `DataManager` as a thin facade that delegates to these components

4. **Extract a shared entity transformation layer** from the duplicated `parse_monster()` methods in `Dnd5eApiSource` and `Open5eApiSource`. Define a common intermediate representation and implement source-specific adapters that convert API responses into that representation.

5. **Add type hints** to all method signatures in `data_manager.py` and `api_client.py`. These are the two most complex files and would benefit most from static type checking.

### Priority 3: Medium (Code Quality)

6. **Add docstrings** to all public methods in `DataManager` and all classes in `api_client.py`. Given that these files are the core of the application, documentation is essential for onboarding new contributors.

7. **Translate all Turkish comments** to English across `data_manager.py` and `theme_manager.py`.

8. **Replace the hardcoded Turkish string** in `models.py` line 155 with a call to the `tr()` localization function.

9. **Convert entity schemas** in `models.py` from nested tuples to dataclasses or TypedDict definitions for type safety and better IDE support.

### Priority 4: Low (Nice to Have)

10. **Add cache invalidation** to the API client. Currently, cached responses are stored indefinitely with no TTL or size limits.

11. **Convert `ThemeManager`** from a class with a single static method to a module-level function, which better represents its actual usage pattern.

12. **Remove the legacy mapping tables** (`SCHEMA_MAP`, `PROPERTY_MAP`) from `models.py` once all existing campaigns have been migrated, or add a migration check that removes them automatically after successful conversion.

---

## Dependency Graph

```
config.py
  <- data_manager.py (imports DATA_ROOT, WORLDS_DIR, CACHE_DIR, API_BASE_URL)
  <- main.py (imports load_theme, DATA_ROOT, DATA_ROOT_MODE)
  <- hot_reload_manager.py (imports load_theme)

core/models.py
  <- core/data_manager.py (imports ENTITY_SCHEMAS, get_default_entity_structure)
  <- ui/widgets/npc_sheet.py (imports ENTITY_SCHEMAS)

core/api_client.py
  <- core/data_manager.py (imports DndApiClient)

core/library_fs.py
  <- core/data_manager.py (imports scan_library_tree, search_library_tree, migrate_legacy_layout)

core/locales.py
  <- Nearly every UI file (imports tr)
  <- core/data_manager.py (imports set_language)
  <- ui/campaign_selector.py (imports tr, set_language)

core/theme_manager.py
  <- ui/windows/battle_map_window.py (imports ThemeManager)
  <- ui/widgets/map_viewer.py (imports ThemeManager)
  <- ui/widgets/entity_sidebar.py (imports ThemeManager)
  <- ui/widgets/mind_map_items.py (imports ThemeManager)
  <- ui/player_window.py (imports ThemeManager)
  <- main.py (imports ThemeManager)
  <- Multiple other UI files
```
