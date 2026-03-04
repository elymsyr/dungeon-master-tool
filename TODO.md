# 📝 To-Do List & Roadmap

## 🚨 Critical Bugs & Fixes
- [x] **Fix Mindmap Note Visibility (#50):** Fixed text visibility issue in mindmap notes by setting the MarkdownEditor background to transparent, ensuring proper contrast in both light and dark modes.
- [x] **Fix API Downloads on USB (#51):** Added write permission checks and error handling for read-only environments (e.g., USB drives), ensuring the app warns users instead of crashing or failing silently.


## ⚡ Immediate Improvements & UI
- [ ] **GM Player Screen Control:** Add a specific edit/control view for the GM to manage the Player Window more effectively.
- [ ] **Single Player Screen:** The battle map view and player view will be on a single window.
- [ ] **Auto Event Log:** On the Session View Tab, for each combat round, damages and everything should be printed to the event log automatically.
- [ ] **Free Single Import:** Users should be able to import an entitiy from the import data sources such as spells, items and else, directly into any other entitiy like characters or npcs without needing to import them to the card entity database first.
- [ ] **Embedded PDF Viewer:** Implement a native PDF viewer within the application (Session/Docs tab).
- [ ] **Standardize UI (#30):** Fix inconsistent button sizes and layouts across the application.
- [ ] **Soundpad Transitions (#29):**
    - [ ] Make loop switching smoother to avoid audio glitches.
    - [ ] Add support for "mid-length" transition sounds between loops.

## 🌍 Localization
- [x] **French Support:** Add `fr.yml` locale file (AI-translated initially).
- [x] **German Support:** Add `de.yml` locale file.
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