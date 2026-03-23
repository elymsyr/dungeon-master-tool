# Audio Subsystem Module Documentation

## Module Overview

The audio subsystem provides a multi-track music engine, ambient sound management, and sound effect playback for the Dungeon Master Tool. It enables DMs to create immersive audio landscapes during game sessions with theme-based music states, layered ambient soundscapes, and instant sound effects. The subsystem is built on top of PyQt6's multimedia framework and uses YAML-based configuration for themes and libraries.

The module is responsible for:

- Providing a multi-track music engine with crossfading between tracks using QPropertyAnimation
- Managing four simultaneous ambient sound slots with individual volume control
- Delivering an eight-slot sound effect pool for instant playback
- Supporting theme-based music organization with states (e.g., calm, battle, exploration) and intensity levels (0-3)
- Loading and managing a YAML-based global audio library
- Creating and parsing YAML theme definition files
- Defining dataclass models for tracks, states, and themes

---

## File Inventory

| File | Lines of Code | Classes | Functions | Key Responsibility |
|------|--------------|---------|-----------|-------------------|
| `core/audio/engine.py` | 328 | 3 | 0 | Multi-track audio engine with crossfading |
| `core/audio/loader.py` | 287 | 0 | 6 | YAML-based library and theme loading |
| `core/audio/models.py` | 37 | 4 | 0 | Dataclass definitions for audio entities |
| `core/audio/__init__.py` | 1 | 0 | 0 | Empty package initializer |

**Total: 653 lines of code, 7 classes, 6 functions**

---

## Architecture and Data Flow

```
                    +------------------+
                    | SoundpadPanel    |
                    | (UI controller)  |
                    +--------+---------+
                             |
                    +--------v---------+
                    |    MusicBrain    |
                    | (orchestrator)   |
                    +--+-----+-----+--+
                       |     |     |
              +--------+     |     +--------+
              v              v              v
     +--------+----+ +------+------+ +-----+------+
     | MultiTrack  | | TrackPlayer | | TrackPlayer|
     |    Deck     | | (Ambience   | | (SFX Pool) |
     | (Music)     | |  x4 slots)  | | (x8 pool)  |
     +-------------+ +-------------+ +------------+
                                          |
    +------------------+          +-------v--------+
    |    loader.py     |          |   models.py    |
    | (YAML parsing)   |<-------->| (dataclasses)  |
    +------------------+          +----------------+
         |
    +----v---------+
    | library.yaml |
    | themes/*.yaml|
    +--------------+
```

### Audio Playback Flow

1. The `SoundpadPanel` creates a `MusicBrain` instance with the global library on initialization.
2. When a music theme is loaded, `MusicBrain.set_theme(theme)` stores the theme's state and intensity track mappings.
3. When a state button is clicked, `MusicBrain.queue_state(state_name)` looks up the current intensity level, finds the matching track, and initiates crossfade playback on the `MultiTrackDeck`.
4. When the intensity slider changes, `MusicBrain.set_intensity(level)` transitions the currently playing music to the track matching the new intensity level.
5. Ambient sounds play independently through dedicated `TrackPlayer` instances, each with individual volume control.
6. Sound effects play through a pool of `TrackPlayer` instances, cycling through the pool to allow overlapping effects.

### Library and Theme Loading Flow

1. On startup, `load_global_library()` reads `library.yaml` from the audio directory, returning a dictionary of ambience tracks, SFX entries, and keyboard shortcuts.
2. `load_all_themes()` scans the themes directory for YAML files, parsing each into a `Theme` dataclass instance.
3. When a new theme is created through the theme builder dialog, `create_theme()` writes a new YAML file to the themes directory.
4. Library modifications (add/remove tracks) directly update `library.yaml` through `add_to_library()` and `remove_from_library()`.

---

## Per-File Detailed Analysis

### core/audio/engine.py (328 lines)

**Purpose:** The core audio playback engine providing multi-track music with crossfading, multi-slot ambient sound playback, and a sound effect pool. Built on PyQt6's `QMediaPlayer` and `QAudioOutput` classes.

**Classes:**

*TrackPlayer:*
- Wraps a `QMediaPlayer` and `QAudioOutput` pair for a single audio track
- Provides `play(path)`, `stop()`, `set_volume(value)`, and `fade_to(target_volume, duration_ms)` methods
- The `fade_to` method uses `QPropertyAnimation` on the `QAudioOutput.volume` property for smooth volume transitions
- Supports looping playback via `QMediaPlayer.Loops.Infinite`
- Volume values are normalized to 0.0-1.0 range

*MultiTrackDeck:*
- Manages two `TrackPlayer` instances (deck A and deck B) for crossfade transitions
- The `crossfade_to(path, duration_ms)` method fades out the current deck while fading in the other deck with the new track
- Alternates between deck A and deck B on each crossfade
- Provides `stop()` to halt both decks and `set_volume(value)` to adjust the active deck's volume

*MusicBrain:*
- The top-level audio orchestrator that integrates music, ambience, and SFX
- Contains one `MultiTrackDeck` for music, four `TrackPlayer` instances for ambient sound slots, and eight `TrackPlayer` instances for the SFX pool
- Maintains a master volume multiplier that is applied to all playback channels

**Key Methods on MusicBrain:**

- `set_theme(theme)` - Stores the active theme and prepares state/intensity mappings. Pass `None` to deactivate theming.
- `queue_state(state_name)` - Resolves the track for the given state at the current intensity and crossfades to it. If the resolved track is the same as what is currently playing, the call is a no-op.
- `set_intensity(level)` - Updates the intensity level and, if a state is active, transitions to the track for the new intensity. This enables smooth musical transitions as combat intensity escalates.
- `play_ambience(slot_index, ambience_id, volume)` - Starts playback of an ambient track in the specified slot (0-3). If `ambience_id` is None, stops the slot.
- `set_ambience_volume(slot_index, volume)` - Adjusts the volume of a specific ambience slot, factoring in the master volume.
- `play_sfx(sfx_id)` - Plays a sound effect through the next available slot in the SFX pool, cycling through 8 slots to allow overlapping effects.
- `set_master_volume(value)` - Sets the master volume (0.0-1.0) and propagates it to the music deck and all active ambience slots. SFX volume is set at play time.
- `stop_ambience()` - Stops all four ambience slots.
- `stop_all()` - Stops music, all ambience, and all SFX slots.

**Track Resolution:**
- When `queue_state` is called, it looks up the state name in the theme's `states` dictionary, which returns a `MusicState` containing a list of `Track` objects for each intensity level.
- The track at the current intensity index is selected. If the intensity level exceeds the available tracks, the last track in the list is used (ceiling behavior).
- The track's file path is resolved from the global library.

**Dependencies:** `PyQt6.QtMultimedia` (QMediaPlayer, QAudioOutput), `PyQt6.QtCore` (QPropertyAnimation, QUrl)

**Quality Assessment:**

- The crossfade implementation using `QPropertyAnimation` on `QAudioOutput.volume` is technically elegant and leverages the Qt animation framework effectively.
- The dual-deck (A/B) crossfade pattern in `MultiTrackDeck` is a standard audio engineering approach that ensures gapless transitions.
- The SFX pool with round-robin slot assignment is a simple and effective approach for overlapping sound effects.
- The master volume system correctly multiplies against individual channel volumes.
- **Line 328 region:** The `_resolve_track_path` helper method is not explicitly defined; track path resolution is inline within `queue_state`. Extracting this into a named method would improve readability.
- No type hints on method signatures, though the class and method names are sufficiently descriptive.
- No docstrings on any methods.
- The engine does not handle media playback errors. If a file path is invalid or the audio format is unsupported, the error is silently ignored by `QMediaPlayer`.

---

### core/audio/loader.py (287 lines)

**Purpose:** Handles loading and writing of the YAML-based audio library and theme configuration files. Provides functions for scanning audio files, loading the global library, loading all themes, adding and removing library entries, and creating new themes.

**Functions:**

*_find_audio_files(directory):*
- Scans a directory for audio files with supported extensions (.mp3, .wav, .ogg, .flac, .m4a)
- Returns a list of file paths
- Used internally by the library loading process

*load_global_library():*
- Reads `library.yaml` from the audio configuration directory
- Returns a dictionary containing: `ambience` (list of ambient track entries), `sfx` (list of sound effect entries), and `shortcuts` (keyboard shortcut mappings)
- If the file does not exist, returns an empty library structure
- Each track entry contains `id`, `name`, and `path` fields

*load_all_themes():*
- Scans the themes directory for YAML files
- Parses each file into a `Theme` dataclass using `_parse_theme_file()`
- Returns a dictionary mapping theme IDs to `Theme` instances
- Skips malformed theme files with a warning printed to console

*_parse_theme_file(path):*
- Reads a single theme YAML file and constructs a `Theme` dataclass
- Parses the state-intensity-track hierarchy into nested `MusicState` and `Track` objects
- Handles optional fields like `loop_start`, `loop_end`, and `crossfade_ms`

*add_to_library(category, name, file_path):*
- Adds a new track to the global library under the specified category ("ambience" or "sfx")
- Copies the audio file to the library's audio directory
- Generates a unique ID for the new entry
- Writes the updated library to `library.yaml`
- Returns `(True, entry_dict)` on success or `(False, error_message)` on failure

*remove_from_library(category, item_id):*
- Removes a track from the global library by its ID
- Does not delete the audio file from disk (preserves the file for potential recovery)
- Writes the updated library to `library.yaml`
- Returns `(True, "success")` on success or `(False, error_message)` on failure

*create_theme(name, theme_id, state_map):*
- Creates a new theme YAML file from the provided state-to-intensity mapping
- Validates that the theme ID does not already exist
- Writes the YAML file to the themes directory
- Returns `(True, "success")` on success or `(False, error_message)` on failure

**Dependencies:** `yaml`, `os`, `shutil`, `uuid`, `pathlib`

**Quality Assessment:**

- The function-based API is clean and straightforward.
- The `add_to_library` function properly copies audio files to the library directory, avoiding path dependency issues.
- The `remove_from_library` function intentionally does not delete audio files, which is a safe design choice.
- Error handling uses the `(success, message)` tuple return pattern, which is consistent with other parts of the codebase.
- The YAML parsing in `_parse_theme_file` handles optional fields gracefully with `.get()` defaults.
- No type hints on function signatures.
- No docstrings on functions.
- The file scanning in `_find_audio_files` uses hardcoded extension lists that should be defined as a module-level constant for maintainability.

---

### core/audio/models.py (37 lines)

**Purpose:** Defines the data model classes for the audio subsystem using Python's `dataclasses` module. This is the best example of modern Python data modeling in the entire codebase.

**Dataclasses:**

*LoopNode:*
- Fields: `start` (float, default 0.0), `end` (float, default 0.0)
- Represents loop points within an audio track for seamless looping

*Track:*
- Fields: `path` (str), `loop` (optional LoopNode, default None), `crossfade_ms` (int, default 2000)
- Represents a single audio file with optional loop configuration and crossfade duration
- Factory default: `field(default=None)` for the loop field

*MusicState:*
- Fields: `name` (str), `tracks` (list of Track, default empty list)
- Represents a musical state (e.g., "calm", "battle") with a list of tracks for different intensity levels
- The track at index 0 is the base intensity, index 1 is low, index 2 is medium, index 3 is high

*Theme:*
- Fields: `id` (str), `name` (str), `states` (dict mapping state name to MusicState, default empty dict), `shortcuts` (dict, default empty dict)
- Represents a complete music theme with multiple states and optional keyboard shortcuts

**Dependencies:** `dataclasses`

**Quality Assessment:**

This file is exemplary and should serve as a template for data modeling throughout the codebase:

- Proper use of `@dataclass` decorators with `field(default_factory=...)` for mutable defaults
- Clear, descriptive field names with appropriate default values
- Appropriate use of optional types (LoopNode is optional on Track)
- At 37 lines, it is concise and focused
- This is one of only a few files in the codebase that uses modern Python data modeling features
- The only improvement would be adding type annotations for the `states` and `shortcuts` dictionary value types (they use plain `dict` without specifying key/value types)

---

### core/audio/__init__.py (1 line)

**Purpose:** Package initializer with a descriptive docstring.

**Content:** `"""Development-only runtime utilities (hot reload, IPC bridge)."""`

**Note:** The docstring content appears to be copied from the `core/dev/__init__.py` file and does not accurately describe the audio package. It should read something like `"""Multi-track audio engine with theme-based music, ambience, and sound effects."""`

---

## Code Quality Assessment

### Type Hints

- `models.py` uses dataclass type annotations throughout (str, float, int, list, dict, Optional)
- `engine.py` has no type annotations on method signatures
- `loader.py` has no type annotations on function signatures

### Docstrings

None of the files contain docstrings on any classes, methods, or functions. The `__init__.py` has a module-level docstring but with incorrect content.

### Error Handling

- `engine.py` does not handle media playback errors from QMediaPlayer
- `loader.py` uses the `(success, message)` tuple pattern for error reporting, which is consistent and clean
- `loader.py` properly handles missing YAML files by returning empty structures
- Theme parsing in `_parse_theme_file` silently skips malformed entries

### Naming Conventions

- Class names follow PascalCase correctly: `TrackPlayer`, `MultiTrackDeck`, `MusicBrain`
- Method names follow snake_case correctly throughout
- Function names in `loader.py` follow snake_case: `load_global_library`, `load_all_themes`
- The term "Brain" in `MusicBrain` is unconventional; "Engine" or "Controller" would be more standard

---

## Specific Issues with Line References

| File | Line | Severity | Description |
|------|------|----------|-------------|
| `__init__.py` | 1 | Low | Module docstring incorrectly describes the package as development utilities |
| `engine.py` | All | Medium | No error handling for QMediaPlayer failures (invalid paths, unsupported formats) |
| `engine.py` | All | Low | No type hints on any method signatures |
| `loader.py` | All | Low | No type hints on any function signatures |
| `loader.py` | `_find_audio_files` | Low | Hardcoded extension list should be a module-level constant |
| `models.py` | `Theme` | Low | `states` and `shortcuts` dicts lack value type annotations |

---

## Prioritized Improvement Recommendations

### Priority 1: Critical

1. **Add QMediaPlayer error handling** to `engine.py`. Connect to `QMediaPlayer.errorOccurred` signal to detect and report playback failures. At minimum, log errors to console. Consider emitting a signal that the SoundpadPanel can use to show user-facing error messages.

### Priority 2: High

2. **Fix the `__init__.py` docstring** to accurately describe the audio package.

3. **Add error handling for missing audio files** in `MusicBrain.queue_state()` and `play_ambience()`. Currently, if a track's file path is invalid, `QMediaPlayer` silently fails. Validate file existence before attempting playback.

4. **Extract track path resolution** into a named method in `MusicBrain` rather than performing inline lookups in `queue_state` and `play_ambience`.

### Priority 3: Medium

5. **Add type hints** to all method signatures in `engine.py` and function signatures in `loader.py`. The dataclasses in `models.py` already demonstrate good type annotation practices.

6. **Add docstrings** to all classes, methods, and functions. The audio subsystem has clear, well-defined responsibilities that deserve documentation.

7. **Define supported audio extensions** as a module-level constant in `loader.py` rather than hardcoding them in `_find_audio_files`.

8. **Add full type annotations** to the `states` and `shortcuts` fields in the `Theme` dataclass: `states: Dict[str, MusicState]` and `shortcuts: Dict[str, Any]`.

### Priority 4: Low

9. **Consider renaming `MusicBrain`** to `AudioEngine` or `AudioController` for more conventional naming.

10. **Add volume persistence** so that ambience slot volumes and master volume are saved and restored between sessions.

11. **Add a cache or file existence check** to `_find_audio_files` to avoid rescanning the directory on every call.

---

## Dependency Graph

```
core/audio/models.py
  <- core/audio/engine.py (imports Track, MusicState, Theme)
  <- core/audio/loader.py (imports Track, MusicState, Theme, LoopNode)

core/audio/engine.py
  <- ui/soundpad_panel.py (imports MusicBrain)

core/audio/loader.py
  <- ui/soundpad_panel.py (imports load_all_themes, load_global_library,
                           add_to_library, create_theme, remove_from_library)

External Dependencies:
  core/audio/engine.py -> PyQt6.QtMultimedia (QMediaPlayer, QAudioOutput)
  core/audio/engine.py -> PyQt6.QtCore (QPropertyAnimation, QUrl)
  core/audio/loader.py -> yaml, os, shutil, uuid, pathlib
  core/audio/models.py -> dataclasses
```
