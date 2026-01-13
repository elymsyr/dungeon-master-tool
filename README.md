# 🐉 Dungeon Master Tool

![Status](https://img.shields.io/badge/Status-Alpha-blue)
![License](https://img.shields.io/badge/License-MIT-blue)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux-lightgrey)

**A portable, offline-first DM tool designed for dual-monitor setups.**  
Manage combat, track branching timelines, and project a rich campaign wiki to your players seamlessly.

[📥 Download Latest Release](https://github.com/elymsyr/dungeon-master-tool/releases)

> ✨ **v0.6.0 Update:** Now featuring Multi-Image Projection, Drag & Drop workflow, Video Maps, and a fully integrated Fog of War system!

---

## ✨ Key Features

*   **Dynamic Player Screen:** Drag & drop multiple images (NPCs, Maps, Items) to the projection bar to create an instant **second split-screen view** for players.
*   **Fog of War:** Interactive masking on the Battle Map. Draw fog to hide secrets and erase it to reveal rooms as players explore. **Persists per encounter.**
*   **Animated Battle Maps:** Support for local video files (`.mp4`, `.webm`) to create immersive, moving battlegrounds.
*   **Embedded Battle Map:** Move tokens, manage combat, and sync views without leaving the session log. Control the second battlemap screen for players with a single click.
*   **Adaptive Soundpad:** Layered music system with intensity sliders (Base -> Low -> High) with ambiences and instant SFX.
*   **Story Timeline:** Map-based tracker with **branching paths**, travel lines, and session-linked events. Implement NPC or Monster stories using timeline pins and hide them from players.
*   **System Agnostic:** While optimized for 5e, you can play **any TTRPG** (Pathfinder, OSR, Homebrew) by creating custom entity cards or using "Handwritten" notes without code. Please create an issue if you want more sources :)
*   **Multi-Source Database:** Integrated browser with **SRD 5e** and **Open5e** support. Instantly fetch Monsters, Spells, Feats, Backgrounds and more.
*   **Portable & Offline:** No installation or internet required.

## 🗺️ Roadmap

### ✅ Completed
- [x] **Dynamic Projection:** Drag & drop images to header to project. Support for multi-image split view.
- [x] **Fog of War:** Drawing tools (Lasso), global fill/clear, and per-encounter persistence.
- [x] **Animated Maps:** Support for local video files as battle maps.
- [x] **Embedded Map:** Seamless synchronization between DM view and Player view.
- [x] **Soundpad:** Support for custom music, ambience layers, and sound effects.
- [x] **Story Timeline 2.0:** Branching map paths and parent-child event linking.
- [x] **Dynamic Linking:** Personal wiki experience using `@mentions` in any text area.
- [x] **Markdown Integration:** Rich text editing for descriptions, logs, and DM notes.
- [x] **Binary Storage:** Migration from JSON to high-speed MsgPack (`.dat`).
- [x] **Advanced Linking and Mentioning:** Support linking entities on any text in the app.
- [x] **Multi-Window:** Advanced support for projecting to specific/multiple player screens.
- [x] **Campaign Notes:** Rich text editor, linking, and better folder organization for DM notes.
- [x] **More Sources:** Open5E API is connected.
- [x] **Battlemap View Lock and Toggle:** Toggle player view and lock map movement for player's battlemap screen.


### 🚧 In Progress / Planned
- [ ] **Random Creator:** Random creator for NPCs, NPC names, battles and more...
- [ ] **Prebuild Worlds:** We're planning to add more entities from other sources and custom design prebuild worlds to help newbies.
- [ ] **Soundpad:** Better soundpad and songs. Currently, the songs are uploaded only for test purposes.
- [ ] **Integrations:** Support for D&D Beyond, Obsidian, and other tools.
- [ ] **Custom World Pre-build:** Creating custom pre-build worlds and creating fast worlds.

## 🎮 Feature Guide

### 📺 Using the Player Screen (Projection)
1.  Click the **"📺 Toggle Player Screen"** button in the top toolbar to open the second window.
2.  A **"Drop to Project"** area will appear next to the World Name in the main toolbar.
3.  **Drag & Drop:** Click and drag any image (from an NPC sheet, Item card, or Map list) and drop it into this area.
4.  **Multi-View:** Drop a second image to automatically split the player screen and show both side-by-side.
5.  **Remove:** Click the small thumbnail in the toolbar to remove that specific image from the projection.
6.  **Project Map:** Inside the Map Tab or Session Tab, click "Project Map" to instantly send the current battle map state (including fog) to the screen.

### 🌫️ Using Fog of War
1.  Go to the **Session Tab** (or open the Battle Map Window).
2.  Click the **"☁️ Fog"** button on the map toolbar to enable editing mode.
3.  **Hide Area:** Hold **Left Click** and draw a shape to cover an area with fog.
4.  **Reveal Area:** Hold **Right Click** and draw a shape to clear the fog.
5.  **Persistence:** Fog state is saved automatically for each unique encounter ID in the Combat Tracker.
6.  **Fill/Clear:** Use the toolbar buttons to instantly fill the whole map with fog or clear it.

## 🎵 Customizing Soundpad

You can easily add your own music tracks and themes by adding folders to the `assets/soundpad` directory.

### Directory Structure
```text
assets/
  soundpad/
    soundpad_library.yaml  <-- Global SFX and Ambience definitions
    MyCustomTheme/         <-- Your new theme folder
      theme.yaml           <-- Theme definition
      combat_base.wav
      combat_high.wav
      explore_base.wav
```

### How to Create a Theme (`theme.yaml`)
Create a `theme.yaml` file inside your theme folder. Use the structure below. The **Intensity Slider** in the app controls which track plays (Base, Level 1, Level 2).

```yaml
id: "my_custom_theme"
name: "Epic Boss Battle"
states:
  normal:
    tracks:
      base: 
        - file: "explore_base.wav"
          repeat: 0  # 0 = Infinite Loop
      level1: 
        - file: "explore_tension.wav"
          repeat: 0
  combat:
    tracks:
      base: 
        - file: "combat_drums.wav"
          repeat: 0
      level1: 
        - file: "combat_strings.wav"
          repeat: 0
      level2: 
        - file: "combat_choir.wav"
          repeat: 0
```

### Adding SFX or Ambience
Edit `assets/soundpad/soundpad_library.yaml` to register global sounds that are available in every theme.

```yaml
sfx:
  - id: "fireball"
    name: "Fireball"
    file: "sfx/fire_explosion.wav"
```

## 🚀 Installation

### Option 1: Executable (Recommended)
1.  Go to the **Releases** page.
2.  Download the latest `.zip` (Windows) or `.tar.gz` (Linux).
3.  Run it! Your campaign data saves locally in the application folder.

### Option 2: From Source
```bash
git clone https://github.com/elymsyr/dungeon-master-tool.git
cd dungeon-master-tool
pip install -r requirements.txt
python main.py
```

## 📸 Screenshots
<p align="center">
  <img src="media/main_0.png" width="100%" alt="Player Map View" />
  <img src="media/main_1.png" width="100%" alt="Entity Stat Block" />
  <img src="media/main_2.png" width="100%" alt="Entity Stat Block" />
  <img src="media/map_0.png" width="100%" alt="Entity Stat Block" />
  <img src="media/map_1.png" width="100%" alt="Entity Stat Block" />
  <img src="media/session_0.png" width="100%" alt="Entity Stat Block" />
  <img src="media/session_1.png" width="100%" alt="Entity Stat Block" />
  <img src="media/battlemap.png" width="100%" alt="Entity Stat Block" />
  <img src="media/bulk.png" width="100%" alt="Entity Stat Block" />
  <img src="media/api.png" width="100%" alt="Entity Stat Block" />
</p>

## ⚠️ Disclaimer
This project is currently in **Alpha**. Expect frequent updates and occasional bugs. Backup your world data regularly!

## ✏️ Credits

- [DND 5E SRD API](https://www.dnd5eapi.co/)
- [Open5E](https://open5e.com/)