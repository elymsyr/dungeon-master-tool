# 🐉 Dungeon Master Tool

<p align="center">
  <img src="assets/icon.png" width="128" height="128" alt="Icon" />
  <br>
  <b>A portable, offline-first DM tool built with Flutter.</b>
  <br>
  <i>Manage combat, track timelines, and project a rich campaign wiki seamlessly.</i>
  <br><br>
  ✨  <a href="https://elymsyr.github.io/">Check out our over-engineered amazing website here!</a> ✨
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
  <br>
  <br>
  <img src="https://img.shields.io/badge/Status-Beta-blue" />
  <img src="https://img.shields.io/badge/Version-v2.0.0-blueviolet" />
  <img src="https://img.shields.io/badge/License-MIT-green" />
  <img src="https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter" />
  <img src="https://img.shields.io/badge/Dart-3.11-0175C2?logo=dart" />
  <br>
  <b>Supported Platforms:</b> Android | iOS | Windows | Linux | macOS
  <br>
  <b>Supported Languages:</b>
  <br>
  🇺🇸 English | 🇹🇷 Türkçe | 🇩🇪 Deutsch | 🇫🇷 Français
</p>

---

> 📢 **Developer Note:**
> Current priorities, known bugs, and full changelog are in **[TODO.md](TODO.md)**.

---

## ✨ Highlights

| 📺 **Dynamic Projection** | 🌫️ **Fog of War** | 🧠 **Mind Map** |
|:---:|:---:|:---:|
| Drag & drop images to project instantly to a second screen. | Draw fog to hide secrets on the battle map. Left-click adds, right-click erases. | Infinite canvas with Level-of-Detail rendering — stays smooth even with dozens of nodes. |

| 🎵 **Adaptive Audio** | ⚔️ **Combat Tracker** | 🌍 **System Agnostic** |
|:---:|:---:|:---:|
| Layered music with intensity sliders. Create custom themes easily. | Manage initiative, HP, and conditions. Combat events auto-log to the session event log. | Built-in 5e SRD/Open5e browser, but adaptable to any system. |

---

## 🚀 Core Features Guide

- **📺 Project to Players:** Click **"Toggle Player Screen"**. Drag any image (NPC/Map) to the "Drop to Project" bar at the top.
- **🗺️ Battle Map:** Load a map image. The toolbar is split into four groups:
  - **Navigate** — pan the map; click any ruler or circle to delete it
  - **Ruler / Circle** — draw persistent distance/area measurements displayed in feet; stack as many as you want; **Clear Rulers** removes all at once
  - **Draw** — free-hand annotation brush; **Clear Draw** erases all drawings
  - **Fog** — left-click to add fog, right-click to erase; **Fill Fog** / **Clear Fog** for quick resets
- **📡 Player Screen Sync:** Every tool — fog, drawings, rulers, circles — renders on the player screen (second monitor) in real time.
- **🧠 Mind Map:** Right-click on the canvas to add Notes, Images, or Workspaces. Middle-click to pan. Zoom out freely — the LOD system keeps it smooth.
- **🎵 Soundpad:** Open the panel, select a theme (e.g., "Forest"), and use the **Intensity Slider** to shift music dynamically.

---

## 🗺️ Roadmap & Status

### ✅ Ready to Use
- [x] **Projector:** Multi-image split view & Battle Map sync to player screen.
- [x] **Battle Map:** Fog of War, Grid, persistent Rulers & Circles, Draw tool — all synced to the second screen.
- [x] **Combat Tracker:** Initiative, HP, conditions, and auto event logging.
- [x] **Mind Map:** Infinite canvas with LOD rendering, workspaces, entity nodes, and image nodes.
- [x] **Campaign:** Rich text notes, binary storage (`.dat`), Timeline tracker.
- [x] **Customization:** Theme Engine, 4-language localization (EN/TR/DE/FR).
- [x] **Audio:** Custom Soundpad with Theme Builder.

### 🚧 Coming Soon
- [ ] **Generators:** Random NPC & Encounter creators.
- [ ] **Tools:** Image-to-Note (OCR) transformer.
- [ ] **Content:** Pre-built worlds & "One-Click" campaign setups.
- [ ] **Online:** Hosted servers for remote play.

---

## 🚀 Installation

### 📱 Android
1. Download `DungeonMasterTool-Android.apk` from the [latest release](https://github.com/elymsyr/dungeon-master-tool/releases/latest).
2. Enable "Install from unknown sources" in your device settings if prompted.
3. Open the APK to install and launch.

### 🪟 Windows
1. Download `DungeonMasterTool-Windows.zip` from the [latest release](https://github.com/elymsyr/dungeon-master-tool/releases/latest).
2. Extract the folder and run `dungeon_master_tool.exe`.

### 🐧 Linux
1. Download `DungeonMasterTool-Linux.zip` from the [latest release](https://github.com/elymsyr/dungeon-master-tool/releases/latest).
2. Extract and run:
   ```bash
   unzip DungeonMasterTool-Linux.zip
   cd bundle
   ./dungeon_master_tool
   ```

<div id="macos-installation"></div>

### 🍎 macOS
1. Download `DungeonMasterTool-MacOS.zip` from the [latest release](https://github.com/elymsyr/dungeon-master-tool/releases/latest).
2. Extract and drag `dungeon_master_tool.app` to your **Applications** folder.
3. Remove the quarantine flag:
   ```bash
   sudo xattr -rd com.apple.quarantine /Applications/dungeon_master_tool.app
   ```
4. Launch from Applications or Launchpad.

### 📱 iOS
> **Note:** iOS builds are currently unsigned. You will need to sideload via Xcode or a signing service.

1. Download `DungeonMasterTool-iOS.zip` from the [latest release](https://github.com/elymsyr/dungeon-master-tool/releases/latest).
2. Sideload using Xcode, AltStore, or similar tool.

---

## 🛠️ Development Setup

See [flutter_app/README.md](flutter_app/README.md) for full developer documentation including:
- Flutter SDK setup
- Code generation (Freezed, Riverpod, Drift)
- Localization workflow
- Project architecture

### Quick Start

```bash
cd flutter_app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

---

## 📸 Gallery

<p align="center">
  <img src="media/main_0.png" width="48%" alt="Main Interface" />
  <img src="media/battlemap.png" width="48%" alt="Battle Map" />
</p>
<p align="center">
  <img src="media/mind_0.png" width="48%" alt="Mind Map" />
  <img src="media/session_0.png" width="48%" alt="Session Log" />
</p>

---

## 📣 Feedback / İletişim

**I read every piece of feedback.** Whether it's a bug report or a feature request, please reach out!
*Her geri bildirimi okuyorum. Hata bildirimi veya özellik isteği için lütfen ulaşın!*

| Platform | Link / Contact |
| :--- | :--- |
| 🐛 **GitHub Issues** | [Report a Bug](https://github.com/elymsyr/dungeon-master-tool/issues) |
| 📸 **Instagram** | [@erenorhun](https://www.instagram.com/erenorhun) |
| 💼 **LinkedIn** | [Orhun Eren Yalçınkaya](https://www.linkedin.com/in/orhuneren) |
| 📩 **Email** | *orhunerenyalcinkaya@gmail.com* |