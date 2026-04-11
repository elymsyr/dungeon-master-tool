# v2.0.3 - Flutter Rewrite

The entire application has been rewritten from scratch. The original PyQt codebase has been replaced with a Flutter implementation, bringing full cross-platform support and a modern architecture.

This is a **beta** release. Feedback and bug reports are welcome through [GitHub Issues](https://github.com/elymsyr/dungeon-master-tool/issues).

---

## Downloads

| Platform | File | Notes |
| :--- | :--- | :--- |
| Android | `DungeonMasterTool-Android.apk` | Enable "Install from unknown sources" if prompted |
| Windows | `DungeonMasterTool-Windows.zip` | Extract and run `dungeon_master_tool.exe` |
| Linux | `DungeonMasterTool-Linux.zip` | Extract and run `./bundle/dungeon_master_tool` |
| macOS | `DungeonMasterTool-MacOS.zip` | See [macOS installation guide](https://github.com/elymsyr/dungeon-master-tool#macos-installation) |

> iOS builds are currently unsigned and require sideloading via Xcode or AltStore.

---

## What's New

### Combat Tracker
- Initiative order, HP bar, turn tracking, and condition management.
- Combat events are automatically logged to the session event log.

### Battle Map
- 6-layer canvas: grid, token, annotation, fog, terrain, and decal.
- Fog of war with left-click to add and right-click to erase.
- Persistent rulers, circles, and a free-hand draw tool.
- All layers sync to the player screen in real time.

### Mind Map
- Infinite canvas with Bezier node connections.
- Level-of-detail rendering for smooth performance at any zoom level.
- Workspace containers, entity nodes, image nodes, and full undo/redo.

### World Map
- Interactive map with a pin system for locations and timeline events.
- Fog of war overlay and epoch-based timeline navigation.

### Entity System
- Schema-driven entity cards with 16 field widget types: text, textarea, integer, boolean, enum, markdown, image, file, tag, date, stat block, dice roller, and more.
- Dual-panel entity database with filtering.

### Session and Campaign Management
- Create, load, save, and delete campaigns.
- Session creation, encounter setup, turn management, and event logging.
- Rich text notes with binary storage.
- World schema management and entity templates.

### Templates and Packages
- Built-in D&D 5e schema (SRD / Open5e) with compatibility checks.
- User-defined templates with sync support.
- Package import/export for sharing schemas and entities.

### Audio
- Soundpad powered by flutter_soloud with gapless loops and volume fade.
- Track queuing and custom theme support.

### Player Window
- Second-screen projection via desktop_multi_window.
- Projection views: battle map, entity card, image, and black screen.

### Additional Features
- **PDF Viewer** -- pdfrx integration with page navigation and zoom.
- **Dice Roller** -- d4, d6, d8, d10, d12, d20, d100.
- **Customization** -- 11 themes (dark and light variants).
- **Localization** -- English, Turkish, German, and French.

---

## Technical Details

- **Framework:** Flutter 3.41 / Dart 3.11
- **Architecture:** Clean Architecture (Domain / Data / Application / Presentation)
- **State Management:** Riverpod (14 providers)
- **Database:** Drift SQLite (14 tables, 6 DAOs, v5 migration system)
- **Audio Engine:** flutter_soloud
- **Test Coverage:** 223 tests across 13 test files

---

## Known Limitations

- **Mind Map / World Map:** State is stored as a JSON blob (`state_json`). Drift schema normalization is planned for a future release.
- **Soundpad:** The audio engine is functional but the standalone UI panel is not yet complete.
- **Player Window:** Infrastructure is in place but the full control panel and state sync are still in development.
- **iOS:** Builds are unsigned. Sideloading is required.

---

## What's Next

See [TODO.md](https://github.com/elymsyr/dungeon-master-tool/blob/main/TODO.md) for the full roadmap. Near-term priorities include:

- Drift schema normalization (v6 migration)
- Soundpad standalone panel with YAML theme loading
- Player Window UI and DM-to-player state sync
- D&D 5e API client for spell/class/equipment browsing

---

## License

This project is licensed under [CC BY-NC 4.0](https://github.com/elymsyr/dungeon-master-tool/blob/main/LICENSE).
