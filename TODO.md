# 📝 To-Do List & Roadmap

## 🚨 Critical Bugs & Fixes
- [x] **Fix Mindmap Note Visibility (#50):** Fixed text visibility issue in mindmap notes by setting the MarkdownEditor background to transparent, ensuring proper contrast in both light and dark modes.
- [x] **Fix API Downloads on USB (#51):** Added write permission checks and error handling for read-only environments (e.g., USB drives), ensuring the app warns users instead of crashing or failing silently.
- [x] **Fix Battle Map Sync (#52):** Annotations (draw), fog, rulers, and circles now sync correctly to the second screen (player window). Clear Draw also propagates.
- [x] **Fix Battle Map Erase:** Erase tool now correctly removes drawings; Navigate mode click deletes persistent rulers/circles.
- [x] **Fix Player Screen Splitter Sync:** Splitter position in the Player Screen tab now reflects on the second screen in real time.


## ⚡ Immediate Improvements & UI
- [x] **Auto Event Log:** On the Session View Tab, combat damage, healing, conditions, and round changes are automatically printed to the event log.
- [x] **Single Player Screen:** The battle map view and player view are now unified into a single player window.
- [x] **Battle Map – Persistent Rulers & Circles:** Rulers and circles remain on the map until explicitly deleted. Multiple measurements can coexist. Navigate mode click removes them.
- [x] **Battle Map – Fog System Unification:** Left click adds fog, right click erases fog. Separate "Erase Fog" button removed.
- [x] **Battle Map – Active Tool Highlight:** The active tool button is highlighted in blue. Buttons are grouped by function with visual separators.
- [x] **Battle Map – Measurement Sync:** Rulers and circles are rendered and synced to the second screen (player window).
- [x] **Battle Map – Large Image Support:** Images up to 1 GB (decoded) can now be loaded as battle maps via `QImageReader.setAllocationLimit`.
- [x] **Mind Map – Level of Detail (LOD):** Three-zone LOD system reduces GPU/CPU load when zoomed out: full quality (≥0.4), cached/no-shadow (0.1–0.4), and template mode (<0.1). Grid dots are also skipped or sparsified at low zoom.
- [x] **Mind Map – Readable Template Labels:** In template mode, node labels (entity name / note first line / image filename) are inverse-scaled so they remain readable at any zoom level and overflow the node bounds.
- [ ] **GM Player Screen Control:** Add a specific edit/control view for the GM to manage the Player Window more effectively.
- [ ] **Free Single Import:** Users should be able to import an entity from import data sources (spells, items, etc.) directly into any other entity without needing to import them to the card entity database first.
- [ ] **Embedded PDF Viewer:** Implement a native PDF viewer within the application (Session/Docs tab).
- [x] **Standardize UI (#30):** Battle map toolbar buttons and spinboxes are now uniform height. Palette-based theming applied across all UI components (sidebar, tabs, action buttons, bulk downloader, etc.).
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
