# 🐉 Dungeon Master Tool

**Dungeon Master Tool** is a powerful, offline-first desktop application designed to assist Dungeon Masters in running D&D 5e campaigns seamlessly. Built with Python and PyQt6, it combines campaign management, API integration, combat tracking, and a **virtual tabletop (VTT)** experience into a single, portable executable.

![Status](https://img.shields.io/badge/Status-Stable-green) ![License](https://img.shields.io/badge/License-MIT-blue) ![Python](https://img.shields.io/badge/Python-3.x-yellow)

## ✨ Key Features

### 🗺️ Battle Map & Virtual Tabletop (New!)
- **Interactive Battle Map Window**: Open a dedicated map window that syncs with the Combat Tracker.
- **Token System**: 
    - Automatically generates tokens for every combatant (Players, NPCs, Monsters).
    - **Drag & Drop**: Move tokens freely around the map.
    - **visual Styles**: Tokens indicate allegiance (Green for Players, Red for Enemies) and highlight the current turn.
    - **Resizable Tokens**: Adjust token sizes dynamically using a slider (Tiny to Gargantuan).
- **Map Selector**: Visual gallery to quickly select previously imported maps or load new ones.
- **State Persistence**: The app remembers the exact position of every token and the active map even after closing and reopening the application.

### ⚔️ Advanced Combat Tracker & Session
- **Auto-Save & Resume**: Never lose progress. Sessions, combat states, HP, initiative orders, and map positions are saved automatically. Close the app and resume exactly where you left off.
- **Initiative System**: 
    - Auto-roll initiative with DEX modifiers.
    - Support for manual entry and custom bonuses.
    - Visual indicators for the current turn.
- **Quick Add**: Rapidly add ad-hoc combatants (e.g., "Goblin #3") without clogging your database.
- **Condition Manager**: Right-click to apply status effects (Blinded, Stunned, etc.) with visual cues.
- **Event Logging**: Chronological log of events and dice rolls.

### 📚 Database & Campaign Management
- **Smart API Import**: 
    - Browse and import Monsters, Spells, and Items from the D&D 5e SRD API.
    - **Deep Import**: When importing a monster (e.g., *Lich*), the tool automatically detects and downloads all its linked spells into your database.
- **Navigation History**: "Back" and "Forward" buttons to navigate between entity cards like a web browser.
- **Offline Storage**: Create and manage multiple worlds/campaigns locally.
- **Entity Management**: Create NPCs, Monsters, Locations, Quests, and Lore.
- **Extended Stats**: Support for Saving Throws, Skills, Resistances, Immunities, and Legendary Actions.
- **Lore & Docs**: Attach and view **PDF** files directly within the app.
- **Export**: Export your entire database to a readable `.txt` file.

### 📺 Player Facing View (Second Screen)
- **Second Screen Support**: Open a dedicated "Player Window" on a secondary monitor/projector.
- **Map Projection**: Project the Battle Map to players. They see the map and tokens, but **Monster HP is hidden** (shown as `???`).
- **Stat Block Projection**: Show formatted stat blocks or images of NPCs/Monsters to players with a single click.
- **PDF & Image Sharing**: Instantly project handouts, letters, or scene visuals.

---

## 🚀 Installation & Usage

### Option 1: Portable Executable (Recommended)
This tool is fully portable.
1. Download or locate `DungeonMasterTool.exe`.
2. Place it on your PC or a **USB Drive**.
3. Run it!
   - **Data Storage**: All your worlds, images, PDFs, and logs are saved in the **same directory** (or parent directory) of the executable.

### Option 2: Running from Source
1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/dungeon-master-tool.git
   cd dungeon-master-tool
   ```

2. **Install Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```
   *Dependencies: `PyQt6`, `requests`, `PyQt6-WebEngine`*

3. **Run the App**:
   ```bash
   python main.py
   ```

---

## 🎮 How to Use

### 1. Creating a World
On first launch, select "Yeni Dünya Oluştur" (Create New World).

### 2. Database & API
- Go to the **Veritabanı** (Database) tab.
- Click **"API Tarayıcı"**, search for "Adult Red Dragon", and click **Import**.
- The tool will download the dragon AND its specific actions/traits automatically.
- Double-click spells in the monster's sheet to view their details.

### 3. Running Combat & Maps
- Switch to the **Oturum** (Session) tab.
- Add combatants (Players or Monsters from DB).
- Click **"🗺️ Battle Map"**.
- Select a map image.
- A new window opens with tokens for all combatants.
- **Drag tokens** to position them.
- Use **"Next Turn"** in the main window; the Battle Map updates automatically to highlight the active character.

### 4. Player Screen
- Click **"📺 Oyuncu Ekranını Aç/Kapat"** in the top toolbar.
- Drag the black window to your second monitor.
- Use **"👁️ Oyuncuya Göster"** buttons on images or the "Project Map" button to share visuals.

---

## 📂 Project Structure

```
dungeon-master-tool/
├── core/               # Business logic (API, DataManager, Models)
├── ui/                 # UI Components
│   ├── dialogs/        # Popups (API Browser, Map Selector)
│   ├── tabs/           # Main Tabs (Database, Map, Session)
│   ├── widgets/        # Reusable widgets (Combat Tracker, Sheet)
│   └── windows/        # Separate windows (Player View, Battle Map)
├── assets/             # Static assets
├── main.py             # Entry Point
├── config.py           # Configuration
└── README.md           # This file
```

## 🤝 Credits
- **Framework**: [PyQt6](https://pypi.org/project/PyQt6/)
- **Data Source**: [D&D 5e API](https://www.dnd5eapi.co/)