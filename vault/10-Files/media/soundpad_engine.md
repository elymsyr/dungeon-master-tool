---
type: file-note
domain: media
path: flutter_app/lib/data/services/soundpad_engine.dart
layer: data
language: dart
status: stable
updated: 2026-06-09
tags: [file]
---

# `soundpad_engine.dart`

> [!abstract] Primary Purpose
> The runtime audio playback engine for the DM soundpad, built on `flutter_soloud` (SoLoud). It plays layered, crossfading music themes (per-state, multi-intensity stems), up to 4 looping ambience slots, and cached one-shot SFX. All volume animation uses SoLoud hardware fades — no Dart `Timer`-driven volume ticking — so it is smooth and CPU-cheap.

## Inputs / Outputs
**Inputs**
- Providers watched / constructor deps: none — plain class, no Riverpod. Methods take `SoundpadTheme`, `SoundpadLibrary`, and `soundpadRoot` (resolved file paths) from the caller. Audio models from `domain/entities/audio/audio_models.dart`.
- Reads (DAOs / Drift tables): none — operates entirely on already-loaded file paths.
- Supabase / CDC subscribed: none.
- Events consumed: none — driven by direct method calls from the soundpad UI/controller.
- Triggers (timers, connectivity, lifecycle): one internal `Timer` (`_crossfadeCleanup`) to stop the outgoing deck after a crossfade completes.

**Outputs**
- Providers / public API exposed: `setMasterVolume`, `setTheme`, `setState`, `queueState`, `setIntensity`, `playAmbience`, `setAmbienceVolume`, `stopAmbience`, `getAmbienceId`, `getAmbienceVolume`, `playSfx`, `stopAll`, `dispose`; getters `currentStateId`, `currentIntensityLevel`.
- Writes (Drift tables): none.
- Supabase pushed / RPC called: none.
- Events emitted: none — actual sound output via `SoLoud.instance`.

## Dependencies & Links
- Depends on: `flutter_soloud` (SoLoud), `domain/entities/audio/audio_models.dart` (`SoundpadTheme`, `MusicState`, `MusicTrack`, `LoopNode`, `SoundpadLibrary`, `AmbienceEntry`, `SfxEntry`)
- Used by: soundpad UI/controller layer; library/theme data supplied by [[soundpad_loader]]
- Domain map: [[Media-and-Assets]]
- System flow: [[Media-Storage-Tiers]]
- Spec / reference: [[Audio-SoLoud]]

## Key Logic / Variables
- **Dual-deck crossfade music.** Two `_MultiTrackDeck`s (`_deckA`/`_deckB`) alternate as `_activeDeck`/`_inactiveDeck`. `setState(name)`: load new state into inactive deck, `playSilent()` (all stems vol 0), swap decks, then `fadeIn` new + `fadeOut` old over a hardcoded **3 s** crossfade. A `_crossfadeCleanup` Timer (`3 s + 100 ms`) stops the outgoing deck and applies any `_pendingStateId` (set via `queueState`). First load uses `_hardSwitch` (no crossfade).
- **Intensity layering.** Each music state holds named tracks `base`, `level1`, `level2`, `level3`. `setIntensity(level)` (clamped 0–3) computes a mask `['base', 'level1', ... 'level{level}']` via `_getMaskForLevel`; active stems fade to 1.0, inactive to 0.0. All stems always play in sync looping; only volumes change.
- **Ambience.** `ambienceSlotCount = 4` independent `_AmbienceSlot`s, each a single looping source with per-slot volume. `playAmbience(slot, id, volumePercent, library, root)` picks a random file from the matching `AmbienceEntry.files` (gapless loop handled by SoLoud).
- **SFX cache (LRU).** `playSfx` looks up the entry, picks a random file, caches the loaded `AudioSource` in `_sfxCache` (LRU order tracked in `_sfxCacheOrder`); evicts oldest when over `_maxSfxCacheSize = 30`. Played `looping: false` at volume 1.0; SoLoud auto-releases the voice handle, source stays cached.
- **Master volume** maps directly to `SoLoud.instance.setGlobalVolume` (clamped 0–1).
- `dispose()` tears down both decks, all ambience slots, and disposes every cached SFX source.

## Notes
- Comments are Turkish. This is a Python `core/audio` port (see [[soundpad_loader]] which ports `loader.py`).
- Gotcha: `setTheme(null)` or empty-states theme stops both decks and clears `_currentStateId`. `setState` is a no-op if theme null, state unknown, or already current.
