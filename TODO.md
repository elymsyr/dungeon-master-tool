# To-Do and Roadmap

> **v2.0 -- Flutter Rewrite**
> The app has been fully rewritten from PyQt to Flutter. Supports Android, iOS, Windows, Linux, and macOS.

---

## In Progress

- **Mind Map (85%)** -- Drift schema normalization remaining (replace `state_json` blob with dedicated columns).
- **World Map (85%)** -- Drift schema normalization remaining (replace `state_json` blob with dedicated columns).
- **Soundpad (40%)** -- Standalone panel UI, YAML theme loader, smoother loop transitions, mid-length transition sounds.
- **Player Window (5%)** -- Full UI and control panel, DM-to-player state sync, mobile/tablet dual-screen support.

---

## Planned

### High Priority

- Drift schema normalization (v6 migration) for mind map, world map, and combat state. Critical for online sync and query performance.
- Repository abstraction -- extract `EntityRepository`, `MapRepository`, `MindMapRepository` interfaces from `campaign_repository_impl`.
- Soundpad panel -- standalone screen with YAML theme loading.

### Medium Priority

- Player Window polish -- full second-screen UI, projector controls, mobile adaptation.
- D&D 5e API client -- spell/class/equipment browser using `dnd5eapi.co` and `open5e.com`.
- Mobile UX -- responsive layouts, gesture handling, platform-specific improvements.
- Soundpad transitions -- smoother loop switching, mid-length transition sounds.

### Long Term

- Online multiplayer via Supabase (auth, RLS policies, realtime sync, asset storage).
- Random generators -- NPC names/stats/traits, encounter generator.
- Image-to-note OCR -- convert handout images to editable notes.
- Integrations -- D&D Beyond, Obsidian MD.
- Web platform via static hosting.
- Pre-built content -- ready-made worlds and one-click campaign setups.

---

## Changelog

### v2.0.0 -- Flutter Rewrite

- Full platform support: Android, iOS, Windows, Linux, macOS.
- Clean Architecture with Domain / Data / Application / Presentation layers.
- Riverpod state management with 14 providers.
- Drift SQLite database with 14 tables, 6 DAOs, and migration system.
- Battle Map: 6-layer canvas (grid, token, annotation, fog, terrain, decal).
- Mind Map: infinite canvas, Bezier connections, LOD rendering, undo/redo.
- World Map: pin system, epoch timeline, fog of war.
- Entity System: schema-driven with 16 field widget types.
- Combat Tracker: initiative, HP, conditions, auto event log.
- Template and Package System: built-in D&D 5e schema, package import/export.
- Audio engine: flutter_soloud with gapless loops and volume fade.
- PDF Viewer: pdfrx integration.
- Localization: 4 languages (EN/TR/DE/FR).
- 11 themes with dark and light variants.
