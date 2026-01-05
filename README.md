<div align="center">

# 🐉 Dungeon Master Tool

![Version](https://img.shields.io/badge/version-stable-green?style=for-the-badge&logo=github)
![License](https://img.shields.io/badge/license-GPL-blue?style=for-the-badge)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-lightgrey?style=for-the-badge&logo=linux)
![Python](https://img.shields.io/badge/Made%20with-Python-EFD05B?style=for-the-badge&logo=python&logoColor=white)

</div>

---

### 🧙‍♂️ Developer Note

> Hi, I'm a D&D player and decided to become a Dungeon Master. I created this application to help me during sessions. While doing this, my priority was to meet these requirements:
>
> 1.  **Two Screens:** I have my own screen and use a second screen to show things to the players. I should be able to show players what I want and hide what I want on this second screen, and do it easily.
> 2.  **NPC Tracking:** I should be able to easily track all the NPCs and monsters I create. Notes, weapons, spells, etc., I should be able to easily add and remove them, either custom made by myself or pulled from D&D 5e.
> 3.  **Real Dice:** I should be able to track encounters, but I want the players to roll the dice. That's why I'm not leaving everything to the application. The app exists only for tracking turn order, health, and status effects. Even though dice can be rolled within the app, I want to leave all the dice work to real dice.
> 4.  **World Building:** I should be able to keep all the information about my world in this application.
> 5.  **Portability:** I should be able to carry my world with me with a USB Flash Drive... well I am not sure about that :)
>
> If these situations are suitable for you as well, I think you will enjoy this application. There are also new features I plan to add in the future. I know the application doesn't look very good right now :) If I find time, I will look into developing it myself instead of using AI. If you enjoy the application, leaving a star on the repo would be great.

---

### 🇹🇷 Geliştirici Notu

> Selam, bir dnd oyuncusuyum ve dungeon master olmaya karar verdim. Bu uygulamayı bana sessionlarda yardımcı olması için hazırladım. Bunu yaparken önceliğim şu gereksinimlerimi karşılamaktı:
>
> 1.  Hem kendi ekranım var, hem de oyunculara gösterebileceğim ikinci bir ekran kullanıyorum. Bu ikinci ekranda oyunculara istediğim şeyleri gösterebilmeli, istediğim şeyleri ise gizleyebilmeliyim ve bunu kolayca yapabilmeliyim.
> 2.  Yarattığım tüm npc ve canavarları kolayca takip edebilmeliyim. Notlar, silahlar, büyüler vs. ister kendim custom istersem de dnd 5e den çekerek kolayca ekleyebilmeli ve çıkartabilmeliyim.
> 3.  Encounter takibini yapabilmeliyim ancak oyuncuların zar atmasını istiyorum. O yüzden tüm işi uygulamaya bırakmıyorum. Uygulama sadece sıra, can ve durum efekti takibi yapmam için var. Zar atılabilse de tüm zar işini gerçek zarlara bırakmak istiyorum.
> 4.  Dünyayla ilgili tüm bilgilerimi bu uygulamada tutabilmeliyim.
> 5.  Dünyamı bir USB Flash Disk ile yanımda taşıyabilmeliyim... Bundan çok emin değilim tabi.
>
> Evet, bu tarz durumlar sizin için de uygunsa, bu uygulamadan keyif alacağınızı düşünüyorum. Ayrıca ileride getirmeyi planladığım yeni özellikler de var. Şuan uygulama çok da iyi görünmüyor biliyorum :) Zaman bulursam AI yerine kendim de geliştirmeye bakacağım. Uygulamadan keyif alırsanız, repoya yıldız bırakmanız harika olur.

<br>

---

<div align="center">
  <img src="https://media1.tenor.com/m/lcrQBLljnNcAAAAd/dark-souls-knight.gif" width="1000" style="border-radius: 10px; box-shadow: 0px 0px 20px rgba(0,0,0,0.5);"/>
</div>

<br>

## 💎 Key Features

### 🖥️ Immersive "Second Screen"
*Designed for DMs who use a secondary monitor, TV, or projector.*
*   🔹 **Player View:** Project a dedicated window for your players while keeping your DM screen private.
*   🔹 **Selective Secrecy:** Show monster tokens on the map but hide their stats (HP displays as `???`).
*   🔹 **Instant Sharing:** Project formatted stat blocks, item descriptions, or images to the players with a single click.

### ⚔️ Streamlined Combat Tracking
*Focus on the battle, not the bookkeeping.*
*   🔸 **Manual Dice Philosophy:** The app tracks Turn Order, Initiative, HP, and AC, but **does not roll for you**. The thrill of rolling physical dice remains with the table. Well it has a simple dice roller but we do not recommend using it.
*   🔸 **Condition Manager:** Easily apply and track status effects (blinded, stunned, etc.) with writing it :)
*   🔸 **Auto-Save:** Combat states are saved automatically. If you close the app, you can resume exactly where you left off but remembder the create a session first.

### 🗺️ Integrated Virtual Tabletop (VTT)
*   🟢 **Interactive Battle Map:** Load any map image and use the built-in token system.
*   🟢 **Drag & Drop:** Simply drag monsters from your list onto the map.
*   🟢 **Smart Tokens:** Tokens automatically resize (Tiny to Gargantuan) and color-code based on allegiance (Enemy vs. Player).

### 📚 Comprehensive Database & Customization
*   🟣 **SRD Integration:** Built-in API browser to import Monsters, Spells, and Items directly from D&D 5e.
*   🟣 **Custom Content:** Create your own homebrew NPCs, weapons, and spells easily.
*   🟣 **Campaign Notebook:** Keep all your world notes, lore, and PDFs within the application.

### 💾 Portable & Offline-First
*   🟤 **USB Ready:** The application is designed to run entirely from a USB flash drive.
*   🟤 **Zero Dependency:** No internet connection required after initial database download. Take your world anywhere.

### 🎨 Themes & Localization
*   🤢 **Bad UI:** Well I suggest you to improve the visual aspect of the application with your own themes and rebuild the application, since my themes and the current visual aspect of the application are not very good.
*   🖌️ **Visual Customization:** Choose from 8 professional themes (Dark, Light, Parchment, etc.).
*   🌍 **Multi-Language:** Fully localized support for **English** and **Turkish**.

---

## 🚀 Installation & Usage

### Option 1: Portable (Recommended) ***(COMING SOON)***
*No installation required. Perfect for carrying on a USB stick.*
1.  Download the latest release.
2.  Unzip and run `dist/DungeonMasterTool.exe` for windows or `DungeonMasterTool` for linux.
3.  Run it! All your data (worlds, custom items) saves to that folder.

### Option 2: Run from Source
*If you are a developer or prefer Python:*

```bash
# Clone the repository
git clone https://github.com/yourusername/dungeon-master-tool.git
cd dungeon-master-tool

# Install dependencies
pip install -r requirements.txt

# Run the app
python main.py
```

---

## 📜 Credits

*   **Core:** 🐍 Python & PyQt6
*   **Data:** 🐉 [D&D 5e API](https://www.dnd5eapi.co/)
*   **Localization:** 🌐 python-i18n

If this tool helps you run smoother sessions, please consider leaving a ⭐ on the repository! Happy rolling!