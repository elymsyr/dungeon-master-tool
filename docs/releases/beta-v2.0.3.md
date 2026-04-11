# Beta v2.0.3 - Flutter Rewrite

Full rewrite from PyQt to Flutter with cross-platform support. **Beta** release -- feedback welcome via [GitHub Issues](https://github.com/elymsyr/dungeon-master-tool/issues).

---

## Downloads

| Platform | File | Notes |
| :--- | :--- | :--- |
| Android | `DungeonMasterTool-Android.apk` | Enable "Install from unknown sources" if prompted |
| iOS | `DungeonMasterTool-iOS.ipa` | Unsigned -- sideload via Xcode or AltStore |
| Windows | `DungeonMasterTool-Windows.zip` | Extract and run `dungeon_master_tool.exe` |
| Linux | `DungeonMasterTool-Linux.zip` | Extract and run `./bundle/dungeon_master_tool` |
| macOS | `DungeonMasterTool-MacOS.zip` | See [macOS installation guide](https://github.com/elymsyr/dungeon-master-tool#macos-installation) |

---

## What's New

- **Combat Tracker** -- Initiative order, HP bar, turn tracking, conditions, auto-logged events.
- **Battle Map** -- 6-layer canvas (grid, token, annotation, fog, terrain, decal), fog of war, rulers, free-hand draw, real-time player sync.
- **Mind Map** -- Infinite canvas, Bezier connections, LOD rendering, containers, undo/redo.
- **World Map** -- Pin system, timeline events, fog of war, epoch navigation.
- **Entity System** -- Schema-driven cards with 16 field types, dual-panel database with filtering.
- **Session & Campaign** -- Campaign CRUD, encounter setup, turn management, event log, rich text notes.
- **Templates & Packages** -- D&D 5e SRD schema, user-defined templates, import/export.
- **Audio** -- Soundpad with flutter_soloud, gapless loops, volume fade, track queuing.
- **Player Window** -- Second-screen projection (battle map, entity card, image, black screen).
- **PDF Viewer** -- pdfrx with page navigation and zoom.
- **Dice Roller** -- d4, d6, d8, d10, d12, d20, d100.
- **Customization** -- 11 themes (dark/light), 4 languages (EN, TR, DE, FR).

---

## Technical Details

- **Framework:** Flutter 3.41 / Dart 3.11
- **Architecture:** Clean Architecture (Domain / Data / Application / Presentation)
- **State Management:** Riverpod (14 providers)
- **Database:** Drift SQLite (14 tables, 6 DAOs, v5 migration system)
- **Test Coverage:** 223 tests across 13 test files

---

## Known Limitations

- **Mind Map / World Map:** JSON blob state -- Drift normalization planned.
- **Soundpad:** Engine works, standalone UI panel not yet complete.
- **Player Window:** Infrastructure ready, full control panel in development.

---

## What's Next

See [TODO.md](https://github.com/elymsyr/dungeon-master-tool/blob/main/TODO.md) for the roadmap.

---

## License

[CC BY-NC 4.0](https://github.com/elymsyr/dungeon-master-tool/blob/main/LICENSE)
