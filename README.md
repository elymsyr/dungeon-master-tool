# 🐉 Dungeon Master Tool

<p align="center">
  <img src="assets/icon.png" width="128" height="128" alt="Icon" />
  <br>
  <b>A portable, offline-first DM tool designed for dual-monitor setups.</b>
  <br>
  <i>Manage combat, track timelines, and project a rich campaign wiki seamlessly.</i>
  <br><br>
  ✨  <a href="https://elymsyr.github.io/">Check out our over-engineered amazing website here!</a> ✨
  <br><br>
  <a href="https://github.com/elymsyr/dungeon-master-tool/releases/download/alpha-v0.7.5/DungeonMasterTool-Windows.zip">
    <img src="https://img.shields.io/badge/Download-Windows_x64-blue?style=for-the-badge&logo=windows" alt="Download Windows" />
  </a>
  <a href="https://github.com/elymsyr/dungeon-master-tool/releases/download/alpha-v0.7.5/DungeonMasterTool-Linux.zip">
    <img src="https://img.shields.io/badge/Download-Linux-orange?style=for-the-badge&logo=linux" alt="Download Linux" />
  </a>
  <a href="#macos-installation">
    <img src="https://img.shields.io/badge/Download-MacOS-orange?style=for-the-badge&logo=apple" alt="Download MacOS" />
  </a>
  <br>
  <br>
  <img src="https://img.shields.io/badge/Status-Alpha-blue" />
  <img src="https://img.shields.io/badge/License-MIT-green" />
  <img src="https://img.shields.io/badge/Python-3.10+-yellow" />
  <br>
  <b>Supported Languages:</b>
  <br>
  🇺🇸 English | 🇹🇷 Türkçe | 🇩🇪 Deutsch | 🇫🇷 Français
</p>

---

> 📢 **Developer Note:**
> You can find current priorities and known bugs in **[TODO.md](TODO.md)**.
>
> *Due to personal time constraints, updates might be slower recently. However, I am doing my best to stick to the roadmap and implement planned features. Thank you for your support!*

---

## ✨ Highlights

| 📺 **Dynamic Projection** | 🌫️ **Fog of War** | 🧠 **Mind Map** |
|:---:|:---:|:---:|
| Drag & drop images to project instantly to a second screen. | Draw fog to hide secrets on the battle map. Persists per encounter. | Infinite canvas to link notes, NPCs, and create story workspaces. |

| 🎵 **Adaptive Audio** | ⚔️ **Combat Tracker** | 🌍 **System Agnostic** |
|:---:|:---:|:---:|
| Layered music with intensity sliders. Create custom themes easily. | Manage initiative, HP, and conditions integrated with the map. | Built-in 5e SRD/Open5e browser, but adaptable to any system. |

---

## 🚀 Core Features Guide
*   **📺 Project to Players:** Click **"Toggle Player Screen"**. Drag any image (NPC/Map) to the "Drop to Project" bar at the top.
*   **🌫️ Fog of War:** In the **Session Tab**, click **"Fog"**. Left-click to hide, Right-click to reveal.
*   **🧠 Mind Map:** Right-click on the canvas to add Nodes or Workspaces. Middle-click to pan.
*   **🎵 Soundpad:** Open the panel, select a theme (e.g., "Forest"), and use the **Intensity Slider** to shift music dynamically.

---

## 🗺️ Roadmap & Status

### ✅ Ready to Use
- [x] **Projector:** Multi-image split view & Battle Map sync.
- [x] **Maps:** Video map support (`.mp4`), Fog of War, Grid.
- [x] **Campaign:** Rich text notes, binary storage (`.dat`), Timeline tracker.
- [x] **Customization:** Theme Engine (10+ themes), English/Turkish localization.
- [x] **Audio:** Custom Soundpad with Theme Builder.

### 🚧 Coming Soon
- [ ] **Generators:** Random NPC & Encounter creators.
- [ ] **Tools:** Image-to-Note (OCR) transformer.
- [ ] **Content:** Pre-built worlds & "One-Click" campaign setups.
- [ ] **Online:** Hosted servers for remote play.

---

## 🚀 Installation

### 🪟 Windows
1. Download `DungeonMasterTool-Windows.zip` [here](https://github.com/elymsyr/dungeon-master-tool/releases/download/alpha-v0.7.5/DungeonMasterTool-Windows.zip).
2. Extract the folder and run `DungeonMasterTool.exe`.

### 🐧 Linux

#### Preferred

1. Download `DungeonMasterTool-Linux.zip` [here](https://github.com/elymsyr/dungeon-master-tool/releases/download/alpha-v0.7.5/DungeonMasterTool-Linux.zip).
2. Extract the folder and run `DungeonMasterTool`.

#### Manual

```bash
git clone https://github.com/elymsyr/dungeon-master-tool.git
cd dungeon-master-tool
bash installer/install.sh  # (Use install-arch.sh for Arch Linux)
./run.sh
```

<div id="macos-installation"></div>

### 🍎 MacOS Installation & Security Note
Since this is an open-source project and not signed with an official Apple Developer account, you need to manually bypass the "unverified developer" warning.

**[Click here to download DungeonMasterTool-MacOS.zip](https://github.com/elymsyr/dungeon-master-tool/releases/download/alpha-v0.7.5/DungeonMasterTool-MacOS.zip)**

**Steps to run the app:**

1. **Extract** the downloaded `.zip` file.
2. Drag `DungeonMasterTool.app` to your **Applications** folder.
3. Open **Terminal** (Cmd + Space, type 'Terminal') and run the following command to remove the quarantine flag:
   ```bash
   sudo xattr -rd com.apple.quarantine /Applications/DungeonMasterTool.app
   ```
4. **Launch:** You can now open the app from your Applications or Launchpad.

---

## 🛠️ Developer Hot Reload

### Install (Dev)

```bash
pip install -r requirements-dev.txt
```

### Run

```bash
python dev_run.py
```

Optional flags:

- `--path <dir>`: watch/run from a specific root (default is repo root)
- `--patterns "*.py,*.ui,*.qss,*.json,*.yaml,*.yml"`: override watched patterns
- `--debounce-ms 300`: debounce window for change bursts
- `--no-restart`: disable fallback auto-restart when hot reload fails
- `--restart-only`: disable in-process hot reload, restart on every change

### What Reloads Live

- `.py`: changed modules are reloaded with `importlib.reload()`, then root UI is rebuilt in-process
- `.qss`: active stylesheet is reapplied live (no restart)
- `.ui`, `.json`, `.yaml`, `.yml`: root UI is rebuilt in-process
- `locales/*.yml` / `locales/*.yaml`: UI is retranslated after rebuild

### Fallback Behavior

- Hot reload is attempted first.
- If it fails and `--no-restart` is not set, dev runner gracefully restarts the app.
- In dev mode, restart tries to reopen the last active world automatically.

### Known Limitations

- State preservation is best-effort (tab index/splitter/soundpad visibility). Deep widget state may reset.
- If startup fails (for example syntax error), supervisor waits for the next file change before retry.
- Production startup is unchanged (`python main.py` does not enable dev hot reload).

### Manual Test Plan

1. Run `python dev_run.py`.
2. Modify a `.qss` file in `themes/` and save.
3. Confirm styling updates in the running app without closing it.
4. Modify a UI python file such as `ui/tabs/map_tab.py`.
5. Confirm UI rebuild happens while the app process stays alive.
6. Introduce a syntax error in a loaded python module and save.
7. Confirm hot reload fails and the app auto-restarts.
8. Confirm app reopens the last world in dev mode after restart.
9. Fix the syntax error and save.
10. Confirm hot reload succeeds again.

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

---

## ✏️ Credits
*   [DND 5E SRD API](https://www.dnd5eapi.co/)
*   [Open5E](https://open5e.com/)
*   <a href="https://www.flaticon.com/free-icons/sorcery" title="sorcery icons">Sorcery icons created by David Carapinha - Flaticon</a>
