# Development Tooling Module Documentation

## Module Overview

The development tooling module provides a hot-reload system that enables rapid development iteration without restarting the application. It consists of a supervisor process that watches for file changes, an IPC bridge that communicates between the supervisor and the application process, and a hot-reload manager that performs in-process module reloading and widget tree reconstruction.

The module is responsible for:

- Watching the project directory for file changes using the `watchfiles` library
- Classifying changed files by type (Python, QSS, UI, data, locales) to determine the appropriate reload strategy
- Performing in-process Python module reloading via `importlib.reload()` for modified source files
- Rebuilding the application's widget tree after code changes without losing session state
- Providing IPC communication between the supervisor and child application processes
- Detecting changes that require a full process restart rather than in-process reload
- Validating window health after hot-reload to detect broken state

---

## File Inventory

| File | Lines of Code | Classes | Functions | Key Responsibility |
|------|--------------|---------|-----------|-------------------|
| `dev_run.py` | 437 | 1 | 6 | Supervisor process with file watching and child management |
| `core/dev/hot_reload_manager.py` | 349 | 1 | 0 | In-process module reloading and widget rebuilding |
| `core/dev/ipc_bridge.py` | 165 | 1 | 0 | IPC communication bridge for the child process |
| `core/dev/__init__.py` | 1 | 0 | 0 | Package initializer with docstring |

**Total: 952 lines of code, 3 classes, 6 module-level functions**

---

## Architecture and Data Flow

```
Developer saves file
        |
        v
+------------------+
|   dev_run.py     |
| DevSupervisor    |
| (watchfiles)     |
+--------+---------+
         |
    IPC (multiprocessing.connection)
         |
         v
+------------------+     +------------------+
| ipc_bridge.py    |---->| hot_reload_      |
| DevIpcBridge     |     | manager.py       |
| (QTimer polling) |     | HotReloadManager |
+------------------+     +--------+---------+
                                  |
                         +--------v---------+
                         | MainWindow       |
                         | .rebuild_root_   |
                         |  widget()        |
                         +------------------+
```

### Hot Reload Workflow

1. The developer runs `python dev_run.py` which starts the `DevSupervisor`.
2. The supervisor opens an IPC listener on localhost with a random port and authentication token.
3. The supervisor starts the main application as a child process with IPC connection details in environment variables.
4. The child application creates a `DevIpcBridge` from the environment variables and connects to the supervisor.
5. The `DevIpcBridge` starts a `QTimer` that polls the IPC connection every 100ms for incoming commands.
6. When the `watchfiles` library detects file changes, the supervisor filters and classifies them.
7. The supervisor sends a `hot_reload` command with the list of changed paths over the IPC connection.
8. The `DevIpcBridge` receives the command and delegates to `HotReloadManager.attempt_hot_reload()`.
9. The `HotReloadManager` classifies the changed files and takes appropriate action:
   - **Python changes:** Reloads modified modules via `importlib.reload()`, then calls `MainWindow.rebuild_root_widget()` to reconstruct the UI
   - **QSS changes:** Reloads the stylesheet and applies it to the main window
   - **Data/locale changes:** Triggers a widget rebuild and retranslation
   - **Restart-required changes** (main.py, dev_run.py, core/dev/*): Returns a status indicating the supervisor should restart the child process
10. The `HotReloadManager` validates window health after the reload by checking for required attributes and tab count.
11. The result is sent back to the supervisor, which logs the outcome and handles restart if needed.

### Fallback Strategy

If in-process hot-reload fails (the widget tree is corrupted or a module cannot be reloaded), the supervisor falls back to killing and restarting the child process. This is controlled by the `--no-restart` flag (disables fallback) and `--restart-only` flag (skips in-process reload entirely).

---

## Per-File Detailed Analysis

### dev_run.py (437 lines)

**Purpose:** The development supervisor script that watches the project directory for file changes and coordinates hot-reload or process restart. This is the entry point for development mode.

**Module-Level Constants:**
- `STATUS_APPLIED`, `STATUS_NO_OP`, `STATUS_RESTART_REQUIRED`, `STATUS_FAILED`, `STATUS_BUSY` - Status codes mirroring `HotReloadManager` outcomes
- `DEFAULT_PATTERNS` - Comma-separated file patterns to watch: `*.py,*.ui,*.qss,*.json,*.yaml,*.yml`
- `DEFAULT_DEBOUNCE_MS` - Default debounce window of 300ms
- `DEFAULT_EXCLUDED_DIRS` - Set of directories to exclude from watching: `.git`, `__pycache__`, `.venv`, `venv`, `dist`, `build`, `.mypy_cache`, `.pytest_cache`, `.ruff_cache`, `node_modules`, `cache`, `worlds`

**Functions:**

*parse_patterns(raw):*
- Splits a comma-separated string into a list of file patterns

*build_parser():*
- Creates an `argparse.ArgumentParser` with options for: `--path` (project root), `--patterns` (file patterns), `--debounce-ms` (debounce window), `--no-restart` (disable restart fallback), `--restart-only` (always restart)

*parse_args(argv):*
- Parses command-line arguments with validation (mutual exclusivity of `--no-restart` and `--restart-only`, non-negative debounce)

*_relative_posix(path, root):*
- Converts an absolute path to a POSIX-style relative path from the project root

*should_watch_file(path, root, patterns, excluded_dirs):*
- Determines whether a file change should trigger a reload based on file extension pattern matching and directory exclusion rules

*main(argv):*
- Entry point that creates a `DevSupervisor` and starts the watch loop

**Class: DevSupervisor**

**Key Methods:**

- `_open_listener()` - Creates an IPC listener on localhost:0 (random port) with a random 16-byte hex authentication token
- `_build_child_env()` - Constructs the child process environment with IPC connection details and the last active world name
- `start_child()` - Launches the application as a subprocess and waits up to 10 seconds for the IPC bridge connection
- `restart_child()` - Terminates the current child process and starts a new one, with a brief delay for cleanup
- `_accept_child_connection(timeout_sec)` - Accepts the IPC connection from the child process with a polling loop that also monitors child process health
- `_terminate_child()` - Gracefully terminates the child process with a 3-second timeout, escalating to kill if needed
- `_send_hot_reload(changed_paths, timeout_sec)` - Sends a hot-reload command over IPC and waits for the response, handling timeouts and process exit
- `_compute_hot_reload_timeout(changed_paths)` - Calculates a dynamic timeout based on the number of changed files: `min(45, 8 + 2 * count)` seconds
- `handle_changes(changed_paths)` - The main change handler that coordinates hot-reload attempts, retry on busy status, and fallback restart
- `_filter_changes(raw_changes)` - Filters raw watchfiles changes through `should_watch_file` and normalizes paths
- `watch_loop()` - The main event loop that watches for file changes and dispatches them to `handle_changes`

**Dependencies:** `watchfiles` (optional, checked at runtime), `multiprocessing.connection.Listener`, `subprocess`, `argparse`, `secrets`, `socket`, `pathlib`

**Quality Assessment:**

- **Type hints are present** on several function signatures: `parse_patterns(raw: str) -> List[str]`, `should_watch_file(path: str | Path, root: str | Path, patterns: Iterable[str]) -> bool`. This is one of the best-typed files in the codebase.
- The supervisor pattern with IPC communication is a robust design that cleanly separates the file watcher from the application process.
- The dynamic timeout calculation based on changed file count is a thoughtful optimization.
- The retry logic for `BUSY` status (one retry with change coalescing) is well-designed.
- **Lines 143-145:** A bare `except` clause when setting socket timeout on the listener, which is acceptable for a defensive setup operation.
- **Line 95:** `_relative_posix` uses a bare `except Exception` for path resolution, which is acceptable for this utility function.
- The `DEFAULT_EXCLUDED_DIRS` set is comprehensive and avoids common false-positive triggers.
- The `watch_loop` method properly handles `KeyboardInterrupt` for clean shutdown and cleans up all resources in the `finally` block.

---

### core/dev/hot_reload_manager.py (349 lines)

**Purpose:** Performs in-process hot-reloading of Python modules and coordinates widget tree reconstruction. This class runs inside the child application process and is responsible for the actual code reloading logic.

**Class: HotReloadManager**

**Class Constants:**
- `OUTCOME_APPLIED`, `OUTCOME_NO_OP`, `OUTCOME_RESTART_REQUIRED`, `OUTCOME_FAILED`, `OUTCOME_BUSY` - Result status codes
- `WATCHED_EXTENSIONS` - Set of file extensions that trigger reloading
- `STABLE_MODULES` - Set of module names that must never be reloaded (includes main.py, dev infrastructure)
- `STABLE_PREFIXES` - Tuple of module name prefixes that are never reloaded (core.dev.*)
- `RESTART_REQUIRED_FILES` - Files that require a full process restart (main.py, dev_run.py)
- `RESTART_REQUIRED_PREFIXES` - Path prefixes that require restart (core/dev/)
- `REQUIRED_WINDOW_ATTRS` - Tuple of attribute names that must exist on the window after reload for health validation

**Constructor Parameters:**
- `window` - The `MainWindow` instance
- `project_root` - Optional path override (defaults to two directories above the manager file)

**Key Methods:**

- `attempt_hot_reload(changed_paths)` - The main entry point. Acquires a thread lock to prevent concurrent reloads, classifies changed files, and executes the appropriate reload strategy. Returns a result dictionary with status, timing, and error information.

- `classify_paths(changed_paths)` - Static method that categorizes changed file paths into buckets: `python`, `qss`, `ui`, `data`, `locales`. Returns a dictionary of lists.

- `_requires_restart(changed_py_paths)` - Checks if any changed Python files are in the restart-required set (main.py, dev_run.py, core/dev/*).

- `_resolve_changed_modules(changed_py_paths)` - Converts file paths to Python module names using dot notation.

- `_collect_reload_targets(changed_modules, changed_py_paths)` - Scans `sys.modules` to find all loaded modules that should be reloaded based on the changed files. Includes modules that are: (a) directly changed, (b) submodules of changed packages, (c) parent packages of changed modules. Imports modules that are not yet loaded but have changed files.

- `_reload_python_modules(changed_py_paths)` - Performs the actual module reloading by calling `importlib.invalidate_caches()` followed by `importlib.reload()` for each target module, sorted by depth (shallowest first).

- `_reload_stylesheet()` - Reloads the current theme's QSS file and applies it to the window and player window.

- `_validate_window_health()` - Checks that the central widget exists, all required attributes are present and non-None, the tab widget has a `count()` method, and there are at least 4 tabs. Raises `RuntimeError` if any check fails.

- `_build_result(ok, status, changed_paths, started_at, error, details)` - Constructs the standardized result dictionary with timing information.

**Thread Safety:**
- Uses `threading.Lock` via `_reload_lock` to prevent concurrent hot-reload attempts. If a reload is already in progress, returns `OUTCOME_BUSY`.

**Dependencies:** `importlib`, `sys`, `threading`, `time`, `traceback`, `pathlib`, `config.load_theme`

**Quality Assessment:**

- **Type hints are present** on several methods: `module_name_from_path(relative_path: str) -> str`, `classify_paths(changed_paths: Iterable[str]) -> Dict[str, List[str]]`, `_normalize_changed_paths(changed_paths: Iterable[str]) -> List[str]`, etc. This is one of the best-typed files in the codebase.
- The class has a well-documented docstring-style comment explaining each outcome constant.
- The reload target collection logic in `_collect_reload_targets` is sophisticated, handling transitive dependencies by scanning `sys.modules` for related modules.
- The depth-based sorting of reload targets (shallowest first) ensures parent packages are reloaded before their children.
- The health validation in `_validate_window_health` is a critical safety net that prevents the application from continuing in a broken state after a failed reload.
- The thread lock prevents race conditions when file changes arrive rapidly.
- The broad `except Exception` in `attempt_hot_reload` is appropriate here because the method must never crash; it must always return a result dictionary.
- The `STABLE_MODULES` and `STABLE_PREFIXES` sets correctly protect the reload infrastructure from being reloaded (which would break the reload system itself).

---

### core/dev/ipc_bridge.py (165 lines)

**Purpose:** The child-process side of the IPC communication channel. Runs inside the application process as a QObject with a QTimer-based polling loop that checks for incoming commands from the supervisor.

**Class: DevIpcBridge (QObject)**

**Class Constants:**
- `POLL_INTERVAL_MS` - 100ms polling interval for IPC message checking

**Constructor Parameters:**
- `connection` - A `multiprocessing.connection.Connection` object for IPC communication

**Key Methods:**

- `from_env()` - Class method that creates a bridge instance from environment variables (`DM_DEV_IPC_HOST`, `DM_DEV_IPC_PORT`, `DM_DEV_IPC_AUTH`). Returns `None` if the environment variables are not set or the connection fails.

- `attach(window)` - Connects the bridge to the main window and creates the `HotReloadManager`. Must be called after the window is constructed.

- `start()` - Creates and starts the QTimer for IPC polling. Must be called after the QApplication is created (creating QTimer before Qt app initialization causes warnings).

- `_poll_once()` - Checks for a pending IPC message. If one is available, processes the command and sends the response. Handles: `hot_reload` command (delegates to `HotReloadManager`), unknown commands (returns error), invalid payloads (returns error).

- `_handle_hot_reload(changed_paths)` - Delegates to `HotReloadManager.attempt_hot_reload()` and normalizes the result payload.

- `_normalize_payload(payload)` - Ensures the result dictionary has all required fields with appropriate defaults.

- `_failed_payload(error, details, changed_paths, last_world)` - Constructs a standardized error response dictionary.

- `close()` - Stops the polling timer and closes the IPC connection.

**Error Handling:**
- The `_poll_once` method wraps the entire polling operation in a try/except block. If polling or response sending fails, it attempts to send an error response back to the supervisor. If even that fails (double exception), it silently passes.
- The `close` method wraps connection closing in try/except to handle already-closed connections.

**Dependencies:** `multiprocessing.connection.Client`, `PyQt6.QtCore.QObject`, `PyQt6.QtCore.QTimer`, `core.dev.hot_reload_manager.HotReloadManager`

**Quality Assessment:**

- The QTimer-based polling approach is the correct way to integrate multiprocessing IPC with a Qt event loop, as direct blocking reads would freeze the UI.
- The `from_env()` class method pattern provides a clean factory for creating bridges from environment variables.
- The `start()` method's documentation about QTimer creation timing is a valuable comment that prevents a common Qt pitfall.
- The error handling in `_poll_once` is robust, with nested try/except to handle communication failures during error reporting.
- The `_normalize_payload` method ensures consistent response structure even when the `HotReloadManager` returns incomplete results.
- No type hints on method signatures (unlike the other dev module files).
- No docstrings except on `start()`.

---

### core/dev/__init__.py (1 line)

**Purpose:** Package initializer with a descriptive docstring.

**Content:** `"""Development-only runtime utilities (hot reload, IPC bridge)."""`

**Quality Assessment:** Accurate and concise module docstring. No issues.

---

## Code Quality Assessment

### Type Hints

- `dev_run.py` has type hints on most function signatures including return types: `List[str]`, `Optional[str]`, `Dict[str, List[str]]`, `bool`
- `hot_reload_manager.py` has type hints on most method signatures: `Dict[str, object]`, `List[str]`, `Set[str]`, `Iterable[str]`
- `ipc_bridge.py` has no type hints
- Overall, this module has the best type annotation coverage in the codebase

### Docstrings

- `hot_reload_manager.py` has a class docstring on `HotReloadManager`
- `ipc_bridge.py` has a class docstring on `DevIpcBridge` and a method docstring on `start()`
- `dev_run.py` has argparse descriptions that serve as documentation
- `__init__.py` has a module docstring
- Most methods lack docstrings but are sufficiently self-documenting through naming

### Error Handling

- All three main files use structured error handling with result dictionaries
- `hot_reload_manager.py` uses a broad `except Exception` in `attempt_hot_reload` which is appropriate for its role
- `ipc_bridge.py` has nested try/except for robust error reporting
- `dev_run.py` has appropriate exception handling for process management and IPC operations

### Naming Conventions

- All class names follow PascalCase: `HotReloadManager`, `DevIpcBridge`, `DevSupervisor`
- All method names follow snake_case consistently
- Constants use SCREAMING_SNAKE_CASE: `OUTCOME_APPLIED`, `DEFAULT_DEBOUNCE_MS`
- Private methods use leading underscore convention consistently

---

## Specific Issues with Line References

| File | Line | Severity | Description |
|------|------|----------|-------------|
| `dev_run.py` | 143-145 | Low | Bare `except` for socket timeout setting (defensive, acceptable) |
| `dev_run.py` | 95 | Low | Bare `except Exception` for path resolution (acceptable utility) |
| `ipc_bridge.py` | 151-152 | Low | Bare `except Exception: pass` for double-exception during error reporting (acceptable for robustness) |
| `ipc_bridge.py` | All | Low | No type hints unlike other dev module files |
| `hot_reload_manager.py` | All | Info | Exemplary code quality with good type hints and structured results |

---

## Prioritized Improvement Recommendations

### Priority 1: Critical

No critical issues. The development tooling module is the highest-quality module in the codebase.

### Priority 2: High

1. **Add type hints to `ipc_bridge.py`** to match the quality standard set by the other two files in this module.

2. **Add error logging** to the hot-reload manager for failed module reloads. Currently, the traceback is captured in the result dictionary but only printed to console in the supervisor. Consider also writing to a log file for post-mortem analysis.

### Priority 3: Medium

3. **Add docstrings** to all public methods in `HotReloadManager` and `DevSupervisor`. The complexity of the reload logic warrants documentation.

4. **Consider adding a file change debounce** within the `DevIpcBridge._poll_once` method to coalesce rapid successive reload commands. Currently, the supervisor handles debouncing, but rapid file saves could still produce bursts.

5. **Add a health check for audio engine state** in `_validate_window_health`. Currently, only visual widget state is validated. If the soundpad panel's audio engine is in a broken state after reload, the user would not be notified.

### Priority 4: Low

6. **Add unit tests** for `should_watch_file`, `classify_paths`, `module_name_from_path`, and `_collect_reload_targets`. These are pure functions with well-defined inputs and outputs that are ideal for testing.

7. **Consider adding a --verbose flag** to `dev_run.py` for more detailed logging of file change detection, module resolution, and reload outcomes.

8. **Document the IPC protocol** format (command dictionary structure, response dictionary structure) in a docstring or comment for maintainability.

---

## Dependency Graph

```
dev_run.py (supervisor process)
  -> watchfiles (external, optional)
  -> multiprocessing.connection.Listener
  -> subprocess, argparse, secrets, socket, pathlib
  (Does NOT import any application code)

core/dev/ipc_bridge.py (child process)
  -> multiprocessing.connection.Client
  -> PyQt6.QtCore (QObject, QTimer)
  -> core/dev/hot_reload_manager.py

core/dev/hot_reload_manager.py (child process)
  -> importlib, sys, threading, time, traceback, pathlib
  -> config.load_theme
  (Accesses MainWindow and its attributes dynamically)

Startup flow:
  dev_run.py --starts--> main.py (child process)
  main.py --creates--> DevIpcBridge.from_env()
  main.py --creates--> MainWindow
  DevIpcBridge --creates--> HotReloadManager(window)
```
