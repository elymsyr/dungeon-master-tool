# 🐉 Dungeon Master Tool

![Status](https://img.shields.io/badge/Status-Alpha-orange)
![License](https://img.shields.io/badge/License-MIT-blue)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux-lightgrey)

**A portable, offline-first DM tool designed for dual-monitor setups.**  
Manage combat, track branching timelines, and project a rich campaign wiki to your players seamlessly.

[📥 Download Latest Release](https://github.com/elymsyr/dungeon-master-tool/releases)

> ✨ UI/UX Status: The interface is continuously evolving to be cleaner and more intuitive. Your feedback and GitHub stars are the best motivation!
---

## ✨ Key Features

*   **Dual-Monitor Support:** Keep DM notes private while projecting maps and stat blocks to players.
*   **Narrative Wiki:** Full **Markdown** support with **dynamic @mentions** to link NPCs, Monsters, and Lore.
*   **Story Timeline:** Map-based tracker with **branching paths**, travel lines, and session-linked events.
*   **Streamlined Combat:** High-speed tracking for Initiative, HP, and Conditions with visual status badges.
*   **High Performance:** Optimized with **MsgPack binary storage** for near-instant loading and saving.
*   **5e Database:** Integrated browser and bulk downloader for Monsters, Spells, and Items.
*   **Portable & Offline:** No installation or internet required. Runs entirely from a USB drive.

## 🗺️ Roadmap

### ✅ Completed
- [x] **Story Timeline 2.0:** Branching map paths and parent-child event linking.
- [x] **Dynamic Linking:** Personal wiki experience using `@mentions` in any text area.
- [x] **Markdown Integration:** Rich text editing for descriptions, logs, and DM notes.
- [x] **Binary Storage:** Migration from JSON to high-speed MsgPack (`.dat`).
- [x] **Soundpad:** Support for custom music, ambience layers, and sound effects.
- [x] **UI/UX Overhaul:** Themes (Baldur, Grim, Discord, etc.) and dual-pane workspace.

### 🚧 In Progress / Planned
- [ ] **More Sources and Prebuild Worlds:** We're planning to add more entities from other sources like 5E 2024, Forgotten Realms and else... Also adding custom design prebuild worlds to help newbies.
- [ ] **Soundpad:** Better soundpad and songs. (Currently, the songs are uploaded only for test purposes.
- [ ] **Fog of War:** Interactive masking/revealing areas on the Battle Map. Splitting DM note area to control the battlemap fog and pawns private.
- [ ] **Campaign Notes:** Rich text editor, linking, and better folder organization for DM notes.
- [ ] **Integrations:** Support for D&D Beyond, Obsidian, and other tools.
- [ ] **Multi-Window:** Advanced support for projecting to specific/multiple player screens.
- [ ] **Advanced Linking and Mentioning:** Support linking entities on any text in the app.
- [ ] **Custom World Pre-build:** Creating custom pre-build worlds and creating fast worlds.
- [ ] **Random Creator:** Random creator for NPCs, NPC names, battles and more...

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

## 📝 Customization
You can easily extend the tool by editing the YAML files in `assets/soundpad` for custom music or adding your own `.qss` files to `themes/` for custom looks.

## ⚠️ Disclaimer
This project is currently in **Alpha**. Expect frequent updates and occasional bugs. Backup your world data regularly!