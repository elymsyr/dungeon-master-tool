# 🐉 Dungeon Master Tool

**Dungeon Master Tool** is a powerful, offline-first desktop application designed to assist Dungeon Masters in running D&D 5e campaigns seamlessly. Built with Python and PyQt6, it combines campaign management, API integration, and session tools into a single, portable executable.

![Status](https://img.shields.io/badge/Status-Stable-green) ![License](https://img.shields.io/badge/License-MIT-blue) ![Python](https://img.shields.io/badge/Python-3.x-yellow)

## ✨ Key Features

### 📚 Database & Campaign Management
- **Offline Storage**: Create and manage multiple names worlds/campaigns.
- **Entity Management**: Create NPCs, Monsters, Locations, and Quest items.
- **D&D 5e API Integration**: Browse and import Spells, Monsters, and Equipment directly from the official SRD API.
- **Customizable Sheets**: Track HP, AC, CR, stats, traits, actions, and inventory for every entity.
- **Multiple Images**: Upload and view multiple reference images for characters and locations.
- **Export**: Export your entire entity database to a readable `.txt` file for backup or printing.

### ⚔️ Combat Tracker & Tools
- **Initiative Tracker**: Add combatants, roll initiative automatically (with DEX bonuses), and track turn order.
- **Condition Manager**: Easily apply and track conditions (Blinded, Stunned, etc.) with visual indicators.
- **Dice Roller**: Quick access to standard dice (d4, d6, d8... d100).

### 📺 Player Facing View
- **Second Screen Support**: Open a dedicated "Player Window" on a secondary monitor/projector.
- **Fog of War Map**: Share maps with adjustable fog of war (pins and locations).
- **Image Sharing**: Instantly project character art or location visuals to your players with a single click.

### 🗺️ Map System
- **Interactive Maps**: Import world maps and add "Pins" to link directly to locations or NPCs in your database.
- **Navigation**: Click a pin to jump instantly to that location's details.

### 📝 Session Logging
- **Journaling**: Keep a chronological log of events with automatic timestamps.
- **DM Notes**: A private scratchpad for your secret plans and plot hooks.

---

## 🚀 Installation & Usage

### Option 1: Portable Executable (Recommended)
This tool is fully portable.
1. Download or locate `DungeonMasterTool.exe`.
2. Place it on your PC or a **USB Drive**.
3. Run it!
   - **Data Storage**: All your worlds, images, and logs are saved in the **same directory** (or parent directory) of the executable.
   - *Example*: If you run it from `E:\DM_Tools\`, your data will be in `E:\DM_Tools\worlds`.

### Option 2: Running from Source
If you are a developer, you can run the Python source directly.

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/dungeon-master-tool.git
   cd dungeon-master-tool
   ```

2. **Install Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```
   *Dependencies: `PyQt6`, `requests`*

3. **Run the App**:
   ```bash
   python main.py
   ```

4. **Build the EXE** (Optional):
   ```bash
   python build_exe.py
   ```

---

## 🎮 How to Use

### 1. Creating a World
On first launch, select "Yeni Dünya Oluştur" (Create New World) and give it a name like "Forgotten Realms".

### 2. Adding Entities
- Go to the **Veritabanı** (Database) tab.
- Click **"Yeni Varlık"** (New Entity).
- Select a Type (NPC, Monster, Location, etc.).
- Fill in the details, upload images, and click **"Kaydet"** (Save).

### 3. Using the API
- Click **"API Tarayıcı"** (API Browser).
- Select a category (e.g., Monsters).
- Search for "Goblin" and click **Import**.
- The Goblin is now in your local database, fully editable!

### 4. Running a Session
- Switch to the **Oturum** (Session) tab.
- Create a new session log.
- Use the **Combat Tracker** on the left to manage encounters.
- Note down events in the log on the right.

### 5. Player Screen
- Click **"📺 Oyuncu Ekranını Aç/Kapat"** in the top toolbar.
- Drag the new window to your second monitor.
- Use **"👁️ Oyuncuya Göster"** buttons on images or maps to send them to the player screen.

---

## 📂 Project Structure

```
dungeon-master-tool/
├── core/               # Core logic (API, DataManager, Models)
├── ui/                 # UI Components (Tabs, Dialogs, Widgets)
├── assets/             # Static assets (icons usually)
├── main.py             # Application Entry Point
├── config.py           # Configuration & Path Management
├── build_exe.py        # PyInstaller Build Script
└── README.md           # This file
```

## 🤝 Credits
- **Framework**: [PyQt6](https://pypi.org/project/PyQt6/)
- **Data Source**: [D&D 5e API](https://www.dnd5eapi.co/)
- **Icons**: Standard system fonts & emojis.

---

*Happy Adventuring!* 🎲