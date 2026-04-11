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

## Technical Details

- **Framework:** Flutter 3.41 / Dart 3.11
- **Architecture:** Clean Architecture (Domain / Data / Application / Presentation)
- **State Management:** Riverpod (14 providers)
- **Database:** Drift SQLite (14 tables, 6 DAOs, v5 migration system)
- **Test Coverage:** 223 tests across 13 test files

---

## What's Next

See [TODO.md](https://github.com/elymsyr/dungeon-master-tool/blob/main/TODO.md) for the roadmap.

---

## License

[CC BY-NC 4.0](https://github.com/elymsyr/dungeon-master-tool/blob/main/LICENSE)
