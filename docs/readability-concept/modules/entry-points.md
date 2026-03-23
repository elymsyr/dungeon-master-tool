# Entry Points and Build Module Documentation

## Module Overview

The entry points and build module encompasses the files that serve as execution entry points for the application and the build system for creating distributable packages. These files are the outermost shell of the application, responsible for bootstrapping the Qt application, coordinating the development mode lifecycle, creating PyInstaller packages, and providing a utility for dumping the project source tree for analysis.

The module is responsible for:

- Bootstrapping the PyQt6 application with development mode detection and IPC bridge setup
- Running the development supervisor with file watching and hot-reload coordination
- Building distributable packages using PyInstaller with proper hidden import resolution
- Providing a project source tree dumping utility for code analysis

---

## File Inventory

| File | Lines of Code | Classes | Functions | Key Responsibility |
|------|--------------|---------|-----------|-------------------|
| `main.py` | 388 | 1 | 1 | Application entry point, main window, app lifecycle |
| `dev_run.py` | 437 | 1 | 6 | Development supervisor with file watching |
| `installer/build.py` | 102 | 0 | 3 | PyInstaller build configuration and packaging |
| `dump.py` | 114 | 0 | 5 | Project source tree and content dumper |

**Total: 1,041 lines of code, 2 classes, 15 functions**

**Note:** `main.py` and `dev_run.py` are documented in detail in the `ui-windows.md` and `dev-tooling.md` modules respectively. This document focuses on their role as entry points and covers `installer/build.py` and `dump.py` in detail.

---

## Architecture and Data Flow

```
Production Entry Point:
  python main.py
    |
    v
  run_application()
    |
    +---> CampaignSelector.exec()
    |
    +---> MainWindow(data_manager)
    |       |
    |       +---> create_root_widget(main_window)
    |       |       |
    |       |       +---> All tabs, sidebar, soundpad
    |       |
    |       +---> app.exec() [Qt event loop]
    |
    +---> (world switch?) ---> loop back to CampaignSelector
    |
    +---> exit

Development Entry Point:
  python dev_run.py
    |
    v
  DevSupervisor.watch_loop()
    |
    +---> Open IPC Listener
    +---> Start child: python main.py (with DM_DEV_CHILD=1)
    |       |
    |       +---> DevIpcBridge.from_env()
    |       +---> run_application(dev_bridge, dev_last_world)
    |
    +---> Watch for file changes
    +---> Send hot_reload commands via IPC
    +---> Handle results (applied, failed, restart)

Build Entry Point:
  python installer/build.py
    |
    v
  clean() ---> Remove dist/ and build/
    |
    v
  build()
    |
    +---> resolve_hidden_imports()
    |       |
    |       +---> Base imports (PyQt6, msgpack, markdown, etc.)
    |       +---> collect_submodules("ui") for dynamic imports
    |
    +---> PyInstaller.__main__.run(params)
    |
    +---> Copy resources (assets, themes, locales) to dist/

Utility:
  python dump.py
    |
    v
  build_tree() ---> Directory tree text
  collect_files() ---> List of source files
  write_output() ---> output.txt with tree + file contents
```

---

## Per-File Detailed Analysis

### main.py (388 lines) - Application Entry Point

**Role as Entry Point:**

The `main.py` file serves dual roles: it defines the `MainWindow` class (documented in `ui-windows.md`) and contains the `run_application()` function which is the primary entry point for the application lifecycle.

**Entry Point Logic (lines 324-387):**

The `if __name__ == "__main__"` block at the bottom of the file:

1. Checks the `DM_DEV_CHILD` environment variable to detect development mode
2. In development mode: reads `DM_DEV_LAST_WORLD` for auto-loading the last world, creates a `DevIpcBridge` from environment variables
3. Calls `run_application(dev_bridge, dev_last_world)` to start the main loop
4. Closes the dev bridge on exit

**run_application(dev_bridge, dev_last_world) Function:**

This function implements the application lifecycle loop:

1. Sets `Qt.ApplicationAttribute.AA_ShareOpenGLContexts` for WebEngine compatibility
2. Creates a `QApplication` instance
3. If a dev bridge is provided, starts it and connects its `close()` to `app.aboutToQuit`
4. Creates a single `DataManager` instance for the entire application lifetime
5. Enters a `while True` loop that:
   - In dev mode: attempts to auto-load the last active world
   - Otherwise: opens the `CampaignSelector` dialog
   - Creates and shows the `MainWindow`
   - Runs `app.exec()` for the Qt event loop
   - On window close: checks `switch_world_requested` to decide whether to loop back or exit
6. Returns 0 on normal exit

**Dependencies:** `importlib`, `os`, `sys`, `PyQt6.QtCore`, `PyQt6.QtGui`, `PyQt6.QtWidgets`, `config`, `core.data_manager`, `core.locales`, `core.theme_manager`, `ui.campaign_selector`, `ui.player_window`, `core.dev.ipc_bridge` (conditional import)

**Quality Assessment:**

- The conditional import of `DevIpcBridge` inside the `if __name__ == "__main__"` block is a good pattern that avoids loading development dependencies in production
- The world-switching loop via `switch_world_requested` flag is a clean approach that avoids complex state management
- The `DataManager` is created once and shared across world switches, which is the correct lifecycle management
- The `AA_ShareOpenGLContexts` attribute is necessary for `QWebEngineView` but the reason is not documented in a comment
- Type hints are present on the `run_application` function signature

---

### dev_run.py (437 lines) - Development Entry Point

**Role as Entry Point:**

The `dev_run.py` script is the entry point for development mode. It is designed to be run directly (`python dev_run.py`) and manages the application as a child process.

This file is documented in detail in `dev-tooling.md`. As an entry point, the key aspects are:

**Command-Line Interface:**
```
python dev_run.py [--path PATH] [--patterns PATTERNS] [--debounce-ms MS]
                  [--no-restart] [--restart-only]
```

- `--path` - Project root directory to watch (default: directory containing dev_run.py)
- `--patterns` - Comma-separated file patterns (default: `*.py,*.ui,*.qss,*.json,*.yaml,*.yml`)
- `--debounce-ms` - Change detection debounce window (default: 300ms)
- `--no-restart` - Disable fallback process restart when hot-reload fails
- `--restart-only` - Disable in-process hot-reload, always restart on file change

**Environment Variables Set for Child Process:**
- `DM_DEV_CHILD=1` - Signals to main.py that it is running as a dev child process
- `DM_DEV_IPC_HOST` - IPC listener hostname (127.0.0.1)
- `DM_DEV_IPC_PORT` - IPC listener port (random)
- `DM_DEV_IPC_AUTH` - IPC authentication token (random 16-byte hex)
- `DM_DEV_LAST_WORLD` - Name of the last active world for auto-loading

**Dependencies:** `watchfiles` (external, validated at runtime with helpful error message if missing)

---

### installer/build.py (102 lines)

**Purpose:** PyInstaller build configuration that packages the application into a distributable format. Handles hidden import resolution for dynamically imported modules, platform-specific build settings, and post-build resource copying.

**Functions:**

*resolve_hidden_imports():*
- Assembles the list of hidden imports that PyInstaller cannot detect through static analysis
- Base hidden imports include: `PyQt6.QtWebEngineWidgets`, `PyQt6.QtWebEngineCore`, `PyQt6.QtPrintSupport`, `PyQt6.QtNetwork`, `PyQt6.QtMultimedia`, `PyQt6.QtMultimediaWidgets`, `PyQt6.sip`, `msgpack`, `markdown`, `markdown.extensions.extra`, `markdown.extensions.nl2br`, `requests`, `i18n`, `yaml`, `json`
- Uses `PyInstaller.utils.hooks.collect_submodules("ui")` to discover all UI submodules. This is necessary because `main.py` loads `ui.main_root` via `importlib.import_module()`, which PyInstaller's static analysis cannot trace.
- Falls back to just `["ui.main_root"]` if `collect_submodules` fails
- Returns a sorted, deduplicated list of all hidden imports

*clean():*
- Removes the `dist/` and `build/` directories if they exist
- Uses `shutil.rmtree` with `ignore_errors=True` for robustness

*build():*
- Assembles PyInstaller parameters:
  - Entry point: `main.py`
  - Name: `DungeonMasterTool`
  - Mode: `--onedir` (directory-based distribution, not single file)
  - Window mode: `--windowed` (hides console window on Windows, creates .app bundle on macOS)
  - `--clean` and `--noupx` flags for clean builds without UPX compression
  - All resolved hidden imports as `--hidden-import` flags
  - Optional icon from `assets/icon.png`
  - Optional version info file on Windows from `version_info.txt`
- Runs `PyInstaller.__main__.run(params)` to execute the build
- Post-build: copies resource directories (`assets`, `themes`, `locales`) to the distribution directory
- Handles macOS-specific distribution path (`Contents/MacOS` inside the .app bundle)

**Dependencies:** `PyInstaller`, `os`, `shutil`, `sys`

**Quality Assessment:**

- The `resolve_hidden_imports` function is well-designed, properly handling the dynamic import detection challenge with `collect_submodules`
- The platform-specific resource copying logic at lines 79-82 correctly handles the macOS .app bundle structure
- **Line 55:** Turkish comment about build mode that should be translated to English
- **Line 77:** Turkish comment about resource copying that should be translated to English
- The `--noupx` flag is used, which increases distribution size but avoids UPX-related runtime issues. This is a pragmatic choice.
- Error handling for the build process catches `Exception` and calls `sys.exit(1)`, which is appropriate for a build script
- The fallback for `collect_submodules` failure at lines 33-35 is a good defensive pattern
- No type hints on function signatures
- No docstrings on functions

---

### dump.py (114 lines)

**Purpose:** A utility script that generates a comprehensive dump of the project's directory tree and source file contents into a single text file. Used for code analysis and documentation preparation.

**Module-Level Configuration:**
- `ROOT_DIR` - Directory to scan (default: `"."`)
- `OUTPUT_FILE` - Output file path (default: `"output.txt"`)
- `EXTENSIONS` - Set of file extensions to include: `.py`, `.md`, `.html`, `.css`, `.js`, `.qss`, `.sh`, `.yml`, `.yaml`
- `EXCLUDE_DIRS` - Set of directory names to exclude: `.git`, `.github`, `build`, `cache`, `.vscode`, `__pycache__`, `worlds`, `venv`
- `EXCLUDE_PATTERNS` - Wildcard patterns for files to exclude: `*.mp3`, `*.wav`

**Functions:**

*matches_exclude_pattern(path):*
- Checks if a file path matches any wildcard exclusion pattern using `fnmatch`
- Normalizes paths to forward slashes for cross-platform compatibility

*is_excluded_dir(dirpath):*
- Checks if a directory should be excluded based on exact name matching or wildcard pattern matching
- Splits the path and checks each component against the exclusion set

*build_tree(root):*
- Generates a text-based directory tree representation with indentation
- Respects exclusion rules by filtering `dirnames` in-place during `os.walk`
- Returns a multi-line string

*collect_files(root, extensions):*
- Collects all files matching the specified extensions while respecting exclusion rules
- Returns a list of file paths

*write_output(file_paths, output_file, tree_text):*
- Writes the directory tree followed by the full contents of each collected file to the output file
- Handles file read errors gracefully with inline error messages
- Separates files with horizontal rule dividers

**Dependencies:** `os`, `fnmatch`

**Quality Assessment:**

- Clean, well-structured utility script at 114 lines
- The exclusion system handles both directory names and file patterns
- Cross-platform path normalization at line 23 (backslash to forward slash) ensures consistent behavior
- The `os.walk` directory filtering via `dirnames[:]` is the correct Python idiom for in-place modification during traversal
- **Line 81:** Redundant call to `is_excluded_dir(dirpath)` inside the file collection loop. The directory exclusion is already handled by `dirnames[:]` filtering in the `os.walk` call. This check is unnecessary but harmless.
- The output format is simple and effective for the intended use case
- No type hints or docstrings
- The script is not imported by any other file; it is purely a standalone utility

---

## Code Quality Assessment

### Type Hints

- `main.py` has type hints on `run_application`: `dev_bridge=None, dev_last_world: Optional[str] = None`
- `main.py` has type hints on several private methods
- `dev_run.py` has type hints on most functions (documented in `dev-tooling.md`)
- `installer/build.py` has no type hints
- `dump.py` has no type hints

### Docstrings

- `main.py` has no docstrings on the `MainWindow` class or `run_application` function
- `dev_run.py` has argparse help strings that serve as documentation
- `installer/build.py` has no docstrings
- `dump.py` has docstrings on `matches_exclude_pattern` and `is_excluded_dir`

### Error Handling

- `main.py` handles the dev bridge lifecycle cleanly with connect/disconnect around the app lifecycle
- `installer/build.py` catches build failures with `Exception` and exits with code 1
- `dump.py` catches file read errors individually and includes them inline in the output
- `dev_run.py` has comprehensive error handling documented in `dev-tooling.md`

### Internationalization

- `main.py` line 46 contains a hardcoded Turkish string in the window title
- `installer/build.py` lines 55 and 77 contain Turkish comments
- `dump.py` has no i18n concerns (it is a developer utility, not user-facing)

---

## Specific Issues with Line References

| File | Line | Severity | Description |
|------|------|----------|-------------|
| `main.py` | 46 | Low | Hardcoded Turkish string `"Bilinmiyor"` in window title |
| `main.py` | 328 | Info | `AA_ShareOpenGLContexts` attribute lacks explanatory comment |
| `installer/build.py` | 55 | Low | Turkish comment about build mode |
| `installer/build.py` | 77 | Low | Turkish comment about resource copying |
| `dump.py` | 81 | Low | Redundant `is_excluded_dir` check already handled by `os.walk` filtering |

---

## Prioritized Improvement Recommendations

### Priority 1: Critical

No critical issues in the entry point files. The application bootstrapping is correctly implemented.

### Priority 2: High

1. **Add a comment explaining `AA_ShareOpenGLContexts`** in `main.py` line 328. This attribute is required for `QWebEngineView` to function correctly and is a non-obvious requirement that future developers might remove, breaking PDF viewing.

2. **Add proper error handling for campaign loading failures** in the `run_application` loop. Currently, if `CampaignSelector` returns a campaign that fails to fully initialize, the `MainWindow` may be constructed with incomplete data.

### Priority 3: Medium

3. **Add type hints** to `installer/build.py` function signatures. While a build script, typed signatures improve maintainability.

4. **Add docstrings** to `resolve_hidden_imports()`, `clean()`, and `build()` in `installer/build.py`.

5. **Translate Turkish comments** in `installer/build.py` lines 55 and 77 to English.

6. **Replace the hardcoded Turkish string** in `main.py` line 46 with a `tr()` call.

7. **Remove the redundant `is_excluded_dir` check** in `dump.py` line 81, or add a comment explaining why it is there if it serves a purpose.

### Priority 4: Low

8. **Add a `--output` argument** to `dump.py` to allow specifying the output file path from the command line instead of editing the script.

9. **Consider adding `--category` filtering** to `installer/build.py` to allow building only specific components for faster iteration during packaging development.

10. **Add a docstring to `run_application()`** explaining the lifecycle loop and the role of `dev_bridge` and `dev_last_world` parameters.

---

## Dependency Graph

```
main.py (production entry point)
  -> config (DATA_ROOT, DATA_ROOT_MODE, load_theme)
  -> core.data_manager.DataManager
  -> core.locales.tr
  -> core.theme_manager.ThemeManager
  -> ui.campaign_selector.CampaignSelector
  -> ui.player_window.PlayerWindow
  -> ui.main_root.create_root_widget (via importlib)
  -> core.dev.ipc_bridge.DevIpcBridge (conditional, dev mode only)

dev_run.py (development entry point)
  -> watchfiles (external)
  -> multiprocessing.connection.Listener
  -> (Does NOT import any application code directly)
  -> Starts main.py as a subprocess

installer/build.py (build entry point)
  -> PyInstaller
  -> PyInstaller.utils.hooks.collect_submodules
  -> os, shutil, sys

dump.py (utility)
  -> os, fnmatch
  -> (Standalone, no project dependencies)
```

### Cross-Entry-Point Relationships

```
dev_run.py ---[subprocess]--> main.py ---[importlib]--> ui/main_root.py
     |                            |
     +---[IPC: multiprocessing]---+

installer/build.py ---[PyInstaller]--> main.py (as build target)
                                          |
                                          +--> All project modules (via hidden imports)
```
