# Dungeon Master Tool

### Developer Note

Hi, I'm a D&D player and decided to become a Dungeon Master. I created this application to help me during sessions. While doing this, my priority was to meet these requirements:

1. I have my own screen and use a second screen to show things to the players. I should be able to show players what I want and hide what I want on this second screen, and do it easily.
2. I should be able to easily track all the NPCs and monsters I create. Notes, weapons, spells, etc., I should be able to easily add and remove them, either custom made by myself or pulled from D&D 5e.
3. I should be able to track encounters, but I want the players to roll the dice. That's why I'm not leaving everything to the application. The app exists only for tracking turn order, health, and status effects. Even though dice can be rolled within the app, I want to leave all the dice work to real dice.
4. I should be able to keep all the information about my world in this application.
5. I should be able to carry my world with me with a USB Flash Drive... well I am not sure about that :)

If these situations are suitable for you as well, I think you will enjoy this application. There are also new features I plan to add in the future. I know the application doesn't look very good right now :) If I find time, I will look into developing it myself instead of using AI. If you enjoy the application, leaving a star on the repo would be great.

---

### 🛠️ Packaging & Distribution (Developer Info)

To facilitate cross-platform distribution, the project includes specialized build scripts and a CI/CD pipeline:

- **`build_linux.py` & `build_windows.py`**: Python scripts using `pyinstaller` to create standalone binaries. They automatically bundle `locales/` and `themes/` into the executable while keeping `worlds/` and `cache/` external for data persistence.
- **GitHub Actions (`package.yml`)**: Every push to the `main` branch triggers an automated build for both Linux and Windows. The resulting binaries are uploaded as **Artifacts** on the GitHub Actions page, allowing Linux developers to provide Windows `.exe` files effortlessly.

---

### Geliştirici Notu

Selam, bir dnd oyuncusuyum ve dungeon master olmaya karar verdim. Bu uygulamayı bana sessionlarda yardımcı olması için hazırladım. Bunu yaparken önceliğim şu gereksinimlerimi karşılamaktı:

1. Hem kendi ekranım var, hem de oyunculara gösterebileceğim ikinci bir ekran kullanıyorum. Bu ikinci ekranda oyunculara istediğim şeyleri gösterebilmeli, istediğim şeyleri ise gizleyebilmeliyim ve bunu kolayca yapabilmeliyim.
2. Yarattığım tüm npc ve canavarları kolayca takip edebilmeliyim. Notlar, silahlar, büyüler vs. ister kendim custom istersem de dnd 5e den çekerek kolayca ekleyebilmeli ve çıkartabilmeliyim.
3. Encounter takibini yapabilmeliyim ancak oyuncuların zar atmasını istiyorum. O yüzden tüm işi uygulamaya bırakmıyorum. Uygulama sadece sıra, can ve durum efekti takibi yapmam için var. Zar atılabilse de tüm zar işini gerçek zarlara bırakmak istiyorum.
4. Dünyayla ilgili tüm bilgilerimi bu uygulamada tutabilmeliyim.
5. Dünyamı bir USB Flash Disk ile yanımda taşıyabilmeliyim... Bundan çok emin değilim tabi.

Evet, bu tarz durumlar sizin için de uygunsa, bu uygulamadan keyif alacağınızı düşünüyorum. Ayrıca ileride getirmeyi planladığım yeni özellikler de var. Şuan uygulama çok da iyi görünmüyor biliyorum :) Zaman bulursam AI yerine kendim de geliştirmeye bakacağım. Uygulamadan keyif alırsanız, repoya yıldız bırakmanız harika olur.

### 🛠️ Paketleme ve Dağıtım (Geliştirici Notu)

Projenin farklı platformlarda kolayca dağıtılabilmesi için özel derleme sistemleri eklenmiştir:

- **`build_linux.py` ve `build_windows.py`**: `pyinstaller` kullanarak tek bir çalıştırılabilir dosya (binary/exe) oluşturur. Dil dosyaları (`locales/`) ve temalar (`themes/`) dosya içine gömülürken, kullanıcı verileri (`worlds/` ve `cache/`) taşınabilirlik için dışarıda tutulur.
- **GitHub Actions (`package.yml`)**: `main` dalına yapılan her yüklemede (push), GitHub sunucuları hem Linux hem de Windows sürümlerini otomatik olarak derler. Üretilen dosyalar GitHub Actions sayfasında **Artifacts** olarak sunulur.

---

**Dungeon Master Tool** is a powerful, offline-first desktop application designed to assist Dungeon Masters in running D&D 5e campaigns seamlessly. Built with Python and PyQt6, it combines campaign management, API integration, combat tracking, and a **virtual tabletop (VTT)** experience into a single, portable executable.

![Status](https://img.shields.io/badge/Status-Stable-green) ![License](https://img.shields.io/badge/License-MIT-blue) ![Python](https://img.shields.io/badge/Python-3.x-yellow)

---

## ✨ Key Features

### 🗺️ Battle Map & Virtual Tabletop
- **Interactive Battle Map Window**: Open a dedicated map window that syncs with the Combat Tracker.
- **Token System**: Automatically generates tokens for every combatant with drag-and-drop support.
- **Visual Styles**: Tokens indicate allegiance (Green for Players, Red for Enemies) and highlight the current turn.
- **Resizable Tokens**: Adjust token sizes dynamically from Tiny to Gargantuan.

### ⚔️ Advanced Combat Tracker & Session
- **Auto-Save & Resume**: Sessions, combat states, HP, initiative orders, and map positions are saved automatically.
- **Initiative System**: Auto-roll initiative with DEX modifiers or enter manually.
- **Condition Manager**: Right-click to apply status effects with visual cues.
- **Event Logging**: Chronological log of events and dice rolls.

### 📚 Database & Campaign Management
- **Smart API Import**: Browse and import Monsters, Spells, and Items from the D&D 5e SRD API.
- **Deep Import**: Automatically downloads linked spells when importing a monster.
- **Bulk Downloader**: Option to download the entire SRD database for full offline usage.
- **Lore & Docs**: Attach and view **PDF** files directly within the app.
- **Standardized Data**: All internal data is stored in a language-agnostic English format for compatibility.

### 🌍 Localization & Customization (New!)
- **Multi-language Support**: Seamlessly switch between **English** and **Türkçe**.
- **Premium Theme System**: Choose from **8 professionally designed themes**:
    - **Dark & Midnight**: Sleek dark modes with gray or purple accents.
    - **Light & Frost**: Clean, soft light themes for better day-time readability.
    - **Parchment**: A classic tabletop feel with vintage paper aesthetics.
    - **Emerald, Ocean, Amethyst**: Vibrant, themed color palettes (Green, Blue, Purple).

### 📺 Player Facing View (Second Screen)
- **Second Screen Support**: Open a dedicated "Player Window" on a secondary monitor/projector.
- **Map Projection**: Project the Battle Map to players with hidden monster stats (HP shown as `???`).
- **Stat Block Projection**: Show formatted stat blocks or images to players with a single click.

---

## 🚀 Installation & Usage

### Option 1: Portable Executable (Recommended)
This tool is fully portable.
1. Download `DungeonMasterTool.exe`.
2. Place it on your PC or a **USB Drive**.
3. Run it! All data is saved in the same directory.

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
   *Required: `PyQt6`, `requests`, `PyQt6-WebEngine`, `python-i18n`, `PyYAML`, `pytest`, `pytest-qt`, `pytest-mock`*

3. **Run the App**:
   ```bash
   python main.py
   ```

---

## 🧪 Testing

The project includes a comprehensive suite of unit and UI smoke tests using **pytest**.

To run the tests:
```bash
# Force the correct Qt API for pytest-qt
PYTEST_QT_API=pyqt6 python3 -m pytest --verbose
```

The tests cover:
- **DataManager**: Persistence, campaign initialization, and legacy data migration.
- **ApiClient**: Correct parsing and standardization of API data.
- **Localization**: Verifying `tr()` function accuracy across languages.
- **UI Smoke Tests**: MainWindow initialization, tab switching, and dynamic language updates.

---

## 🎮 How to Use

### 1. Set Your Language & Theme
Use the toolbar at the top right to select your preferred language (English/Turkish) and one of the 8 available themes. The UI will update instantly.

### 2. Database & API
- Go to the **Database and Characters** tab.
- Click **"API Browser"** to search and import from the web.
- Use the **"Bulk Downloader"** if you want to download everything for offline use.

### 3. Running Combat & Maps
- Add combatants to your session.
- Click **"🗺️ Battle Map"**, select an image, and drag-and-drop tokens.
- Use **"Next Turn"** to cycle through initiative; the map highlights the active character automatically.

---

## 📂 Project Structure

```text
dungeon-master-tool/
├── core/               # Business logic (API, DataManager, Models, Locales)
├── ui/                 # UI Components (Tabs, Widgets, Windows, Dialogs)
├── locales/            # Translation files (en.yml, tr.yml)
├── themes/             # QSS Style Sheets (8 premium themes)
├── tests/              # pytest suite (test_core, test_ui)
├── assets/             # Global static assets
└── main.py             # Entry Point
```

## 🤝 Credits
- **Framework**: [PyQt6](https://pypi.org/project/PyQt6/)
- **Data Source**: [D&D 5e API](https://www.dnd5eapi.co/)
- **Localization**: [python-i18n](https://pypi.org/project/python-i18n/)
