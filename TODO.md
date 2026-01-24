# 📝 To-Do List & Roadmap

## 🚨 Critical Bugs & Fixes
- [x] **Fix API File Access (#48):** Resolve "file not found" error when accessing downloaded monsters/spells from the API Browser.
- [x] **Fix UI Refresh Issue (#47):** Filtered menus in the sidebar do not update immediately after adding an entity; requires switching filters to refresh.
- [x] **Fix Soundpad Master Volume (#47):** The master volume slider in the Soundpad panel is currently non-functional.
- [x] **Fix Arch Linux Installer (#46):**
    - [x] Remove `xcb-util-xinerama` from `install-arch.sh` (package not in AUR).
    - [x] Update script to handle `requirements.txt` path correctly (script needs to run from root or detect path).
    - [x] Investigate and fix map image loading issues (PNG/WEBP/JPG) on Arch (likely missing `qt6-imageformats` or similar dependency).

## ⚡ Immediate Improvements & UI
- [ ] **GM Player Screen Control:** Add a specific edit/control view for the GM to manage the Player Window more effectively.
- [ ] **Embedded PDF Viewer:** Implement a native PDF viewer within the application (Session/Docs tab).
- [ ] **Video Map Volume (#32):** Add a volume slider specifically for animated video maps (`.mp4`, `.webm`) in the Battle Map.
- [ ] **Standardize UI (#30):** Fix inconsistent button sizes and layouts across the application.
- [ ] **Soundpad Transitions (#29):**
    - [ ] Make loop switching smoother to avoid audio glitches.
    - [ ] Add support for "mid-length" transition sounds between loops.

## 🌍 Localization
- [ ] **French Support:** Add `fr.yml` locale file (AI-translated initially).
- [ ] **German Support:** Add `de.yml` locale file.
- [ ] **Source Integration:** Plan for importing French/German SRD sources provided by the community.

## 🛠️ System Agnostic & Customization (Major Overhaul)
- [ ] **Dynamic Entity System:** Refactor `models.py` to allow users to define custom stat entry fields (e.g., GURPS stats like ST, DX, IQ vs D&D 5e STR, DEX, INT).
- [ ] **World Templates:** Create a system to define "World Templates" (XML/JSON) that determine the structure of Entity Cards.
- [ ] **Custom Import:** Allow importing data from CSV/XML directly into these custom world structures.

## 🎵 Soundpad Advanced Features
- [ ] **Folder-based Randomization:** Instead of defining a single file per intensity level, allow pointing to a folder. The app should pick a random track from that folder to vary the music.

## 🔮 Future / Long Term Roadmap
- [ ] **Random Generators:**
    - [ ] NPC Generator (Names, stats, traits).
    - [ ] Battle/Encounter Generator.
- [ ] **Image to Note:** Implement a transformer to convert images (handouts/text) into editable notes (OCR).
- [ ] **Integrations:**
    - [ ] D&D Beyond.
    - [ ] Obsidian MD.
- [ ] **Online Experience:**
    - [ ] Develop a sync system for online play.
    - [ ] Hosted servers (Subscription model) vs Local hosting (Free).