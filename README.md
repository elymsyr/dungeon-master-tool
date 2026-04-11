# Dungeon Master Tool

<p align="center">
  <img src="flutter_app/assets/app_icon.png" width="128" height="128" alt="Dungeon Master Tool" />
  <br>
  <b>A portable, offline-first DM tool built with Flutter.</b>
  <br>
  <i>Manage combat, track timelines, and project a rich campaign wiki seamlessly.</i>
  <br><br>
  <a href="https://elymsyr.github.io/">Project Website</a>
  <br><br>
  <a href="https://github.com/elymsyr/dungeon-master-tool/releases/latest">
    <img src="https://img.shields.io/badge/Download-Android_APK-34A853?style=for-the-badge&logo=android" alt="Download Android" />
  </a>
  <a href="https://github.com/elymsyr/dungeon-master-tool/releases/latest">
    <img src="https://img.shields.io/badge/Download-Windows_x64-blue?style=for-the-badge&logo=windows" alt="Download Windows" />
  </a>
  <a href="https://github.com/elymsyr/dungeon-master-tool/releases/latest">
    <img src="https://img.shields.io/badge/Download-Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black" alt="Download Linux" />
  </a>
  <a href="https://github.com/elymsyr/dungeon-master-tool/releases/latest">
    <img src="https://img.shields.io/badge/Download-macOS-000000?style=for-the-badge&logo=apple" alt="Download macOS" />
  </a>
  <br><br>
  <img src="https://img.shields.io/badge/Status-Beta-blue" />
  <img src="https://img.shields.io/badge/Version-v2.0.3-blueviolet" />
  <img src="https://img.shields.io/badge/License-CC%20BY--NC%204.0-lightgrey" />
  <img src="https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter" />
  <img src="https://img.shields.io/badge/Dart-3.11-0175C2?logo=dart" />
  <br>
  <b>Platforms:</b> Android | iOS | Windows | Linux | macOS
  <br>
  <b>Languages:</b> English | Turkish | German | French
</p>

---

> **Developer Note:**
> Current priorities, known bugs, and full changelog are in [TODO.md](TODO.md).

---

## Features

- **Combat Tracker** -- Initiative, HP tracking, conditions, turn management, and auto event logging.
- **Battle Map** -- 6-layer canvas (grid, token, annotation, fog, terrain, decal) with fog of war, persistent rulers, circles, and a draw tool. All synced to the player screen.
- **Mind Map** -- Infinite canvas with Bezier connections, level-of-detail rendering, workspaces, undo/redo.
- **World Map** -- Pin system with location and timeline data, fog of war, epoch timeline.
- **Entity System** -- Schema-driven entity cards with 16 field widget types (text, markdown, image, stat block, dice roller, and more).
- **Soundpad** -- Layered audio engine with gapless loops, volume fade, and custom themes.
- **Player Window** -- Second-screen projection for battle maps, entity cards, and images.
- **Session and Campaign Management** -- Create, load, and manage campaigns with rich text notes, timeline tracking, and encounter setup.
- **Templates and Packages** -- Built-in D&D 5e schema, user-defined templates, and package import/export.
- **PDF Viewer** -- Integrated viewer with page navigation and zoom.
- **Dice Roller** -- d4, d6, d8, d10, d12, d20, d100.
- **Customization** -- 11 themes (dark and light variants) and 4-language localization.

---

## Installation

### Android
1. Download `DungeonMasterTool-Android.apk` from the [latest release](https://github.com/elymsyr/dungeon-master-tool/releases/latest).
2. Enable "Install from unknown sources" in your device settings if prompted.
3. Open the APK to install and launch.

### Windows
1. Download `DungeonMasterTool-Windows.zip` from the [latest release](https://github.com/elymsyr/dungeon-master-tool/releases/latest).
2. Extract the folder and run `dungeon_master_tool.exe`.

### Linux
1. Download `DungeonMasterTool-Linux.zip` from the [latest release](https://github.com/elymsyr/dungeon-master-tool/releases/latest).
2. Extract and run:
   ```bash
   unzip DungeonMasterTool-Linux.zip
   cd bundle
   ./dungeon_master_tool
   ```

<div id="macos-installation"></div>

### macOS
1. Download `DungeonMasterTool-MacOS.zip` from the [latest release](https://github.com/elymsyr/dungeon-master-tool/releases/latest).
2. Extract and drag `dungeon_master_tool.app` to your **Applications** folder.
3. Remove the quarantine flag:
   ```bash
   sudo xattr -rd com.apple.quarantine /Applications/dungeon_master_tool.app
   ```
4. Launch from Applications or Launchpad.

### iOS
> **Note:** iOS builds are currently unsigned. You will need to sideload via Xcode or a signing service.

1. Download `DungeonMasterTool-iOS.zip` from the [latest release](https://github.com/elymsyr/dungeon-master-tool/releases/latest).
2. Sideload using Xcode, AltStore, or a similar tool.

---

## Development

```bash
cd flutter_app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

See [flutter_app/README.md](flutter_app/README.md) for full developer documentation and [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

---

## Gallery

*Images are from PyQT version, will be updated soon...*

<p align="center">
  <img src="media/main_0.png" width="48%" alt="Main Interface" />
  <img src="media/battlemap.png" width="48%" alt="Battle Map" />
</p>
<p align="center">
  <img src="media/mind_0.png" width="48%" alt="Mind Map" />
  <img src="media/session_0.png" width="48%" alt="Session Log" />
</p>

---

## License

This project is licensed under [CC BY-NC 4.0](LICENSE). See the LICENSE file for details.

---

## Contact

| Platform | Link |
| :--- | :--- |
| **GitHub Issues** | [Report a Bug](https://github.com/elymsyr/dungeon-master-tool/issues) |
| **Instagram** | [@erenorhun](https://www.instagram.com/erenorhun) |
| **LinkedIn** | [Orhun Eren Yalcinkaya](https://www.linkedin.com/in/orhuneren) |
| **Email** | orhunerenyalcinkaya@gmail.com |
