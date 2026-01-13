### 📜 Release Notes (v0.6.0)

**Title:** v0.6.0 - The Visual Immersion Update: Fog of War, Video Maps & Drag-and-Drop

**Summary:**
This major update focuses on the visual aspect of your campaign. We have completely overhauled the Player Screen projection system, added a robust Fog of War tool for battle maps, and introduced support for animated local video maps.

#### ⚔️ Battle Map & Fog of War
*   **Interactive Fog:** You can now draw fog directly on the map to hide areas. Hold **Left Click** to hide, **Right Click** to reveal.
*   **Persistent State:** Fog data is now saved **per encounter**. Switching between a goblin ambush and a boss room will instantly restore the correct fog reveal state for each battle.
*   **Animated Maps:** Added support for local video files (`.mp4`, `.webm`, `.mkv`). Bring your world to life with animated rivers, rain, or flickering torches.
*   **Smart Rendering:** Fixed the "black flash" issue when moving tokens. The map engine now only reloads media when the file actually changes, making token movement buttery smooth.
*   **Stability:** Removed unstable URL/Web stream support to ensure the application never freezes during a session.

#### 📺 Player Screen Projection 2.0
*   **Drag & Drop Workflow:** A new **Projection Bar** has been added to the main toolbar. You can now drag images from your entity sheets or map list and simply drop them into the header to project them.
*   **Multi-View:** Drop two images to automatically create a split-screen view for your players.
*   **Live Map Push:** Added a "Project Map" button in the Map Tab. This instantly sends exactly what you see (including tokens and fog) to the player screen.

#### 🛠️ UI & Quality of Life
*   **Session Tab:** Reorganized the layout. Map control buttons (Load, Open Window) are now integrated directly into the map toolbar for easier access.
*   **Fill/Clear Tools:** Added buttons to instantly fill the entire map with fog or clear it completely.
*   **Token Resizing:** Fixed issues where token sizes wouldn't persist correctly between map reloads.