---
type: file-note
domain: media
path: flutter_app/lib/data/services/soundpad_loader.dart
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `soundpad_loader.dart`

> [!abstract] Primary Purpose
> Parses soundpad YAML config files into the in-memory audio model and manages the on-disk soundpad library + themes. A static-method utility (port of Python `core/audio/loader.py`). It loads the global `soundpad_library.yaml`, scans theme directories for `theme.yaml`, and provides add/merge/remove/create/delete mutators that also re-serialize the library YAML by hand (the `yaml` package is read-only).

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: none — all methods `static`, take `soundpadRoot` (path).
- Reads: `{root}/soundpad_library.yaml`; per-theme `{root}/{themeId}/theme.yaml`; scans theme dirs and audio files (`.wav .mp3 .ogg .flac .m4a`).
- Supabase / CDC subscribed: none.
- Events consumed: none.
- Triggers: called at soundpad load and on user import/create/delete; library merge invoked by [[soundpack_catalog_service]].

**Outputs**
- Providers / public API exposed: `loadGlobalLibrary(root)` → `SoundpadLibrary`; `loadAllThemes(root)` → `Map<id, SoundpadTheme>`; `addToLibrary`, `mergeLibraryEntries`, `removeFromLibrary`, `createTheme`, `deleteTheme` (all return `(bool, String)`).
- Writes (Drift tables): none — writes/rewrites YAML + copies audio files on disk.
- Supabase pushed / RPC called: none.
- Events emitted: none.

## Dependencies & Links
- Depends on: `yaml` (read-only parser), `path`, `domain/entities/audio/audio_models.dart` (`SoundpadLibrary`, `AmbienceEntry`, `SfxEntry`, `SoundpadTheme`, `MusicState`, `MusicTrack`, `LoopNode`)
- Used by: [[soundpad_engine]] (consumes loaded library/themes), [[soundpack_catalog_service]] (calls `mergeLibraryEntries` on library-pack install)
- Domain map: [[Media-and-Assets]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[Audio-SoLoud]]

## Key Logic / Variables
- **`loadGlobalLibrary`** parses `ambience:` / `sfx:` lists (each `{id, name, file}`) and a `shortcuts:` map. Each entry's `file` fragment is resolved via `_findAudioFiles` → a list of concrete file paths.
- **`_findAudioFiles(fragment, root)`** resolution order: (1) if `{root}/{fragment}` is a directory → list all audio files inside; (2) if it has an extension and exists → single file; (3) if extension-less → probe each of `_audioExtensions`.
- **`loadAllThemes`** iterates top-level dirs under `root`; any dir containing `theme.yaml` is parsed by `_parseThemeFile` into a `SoundpadTheme` (`id`, `name`, `states{ name → MusicState{ tracks{ trackId → MusicTrack(sequence of LoopNode) } } }`, `shortcuts`). Track values may be a bare string filename or `{file: ...}`; resolved to absolute path under the theme folder. Creates `root` if missing.
- **`createTheme(root, name, id, stateMap)`** writes a new `{id}/` dir, copies each source track file to `{stateName}_{trackKey}.{ext}`, and emits `theme.yaml` (with `repeat: 0`). Fails if id dir already exists.
- **`mergeLibraryEntries`** is idempotent re-install: for each `{category,id,name,file}` it removes any existing same-`id` then re-adds (used by library soundpack downloads).
- **Hand-written YAML serializer (`_writeLibraryYaml`)** because the `yaml` package can't write. `_yamlToMap`/`_yamlToList` deep-convert immutable `YamlMap`/`YamlList` to mutable maps before mutation.

## Notes
- Comments are Turkish. Imported audio files are copied into `{root}/imported/` with collision-suffix `_N`.
- Only `ambience` and `sfx` are valid library categories; others rejected.
