from os import environ
import sys
from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import (QApplication, QMainWindow, QTabWidget, QVBoxLayout, 
                             QWidget, QMessageBox, QFileDialog, QHBoxLayout, 
                             QPushButton, QLabel, QComboBox, QSplitter, QStyle)
from PyQt6.QtGui import QShortcut, QKeySequence 
from config import STYLESHEET, load_theme
from core.data_manager import DataManager
from ui.player_window import PlayerWindow
from ui.tabs.database_tab import DatabaseTab
from ui.tabs.map_tab import MapTab
from ui.tabs.session_tab import SessionTab
from ui.campaign_selector import CampaignSelector
from core.locales import tr
from ui.soundpad_panel import SoundpadPanel
from ui.widgets.projection_manager import ProjectionManager
from ui.tabs.mind_map_tab import MindMapTab
from ui.widgets.entity_sidebar import EntitySidebar
# YENİ IMPORT
from core.theme_manager import ThemeManager 

class MainWindow(QMainWindow):
    def __init__(self, data_manager):
        super().__init__()
        self.data_manager = data_manager
        self.player_window = PlayerWindow()
        
        self.theme_list = [
            ("dark", "THEME_DARK"), ("light", "THEME_LIGHT"), ("baldur", "Baldur's Gate"),
            ("discord", "Discord"), ("grim", "Grim (Dark)"), ("midnight", "THEME_MIDNIGHT"),
            ("emerald", "THEME_EMERALD"), ("parchment", "THEME_PARCHMENT"), ("ocean", "THEME_OCEAN"),
            ("frost", "THEME_FROST"), ("amethyst", "THEME_AMETHYST")
        ]
        
        self.setWindowTitle(f"DM Tool - {self.data_manager.data.get('world_name', 'Bilinmiyor')}")
        self.setGeometry(100, 100, 1400, 900)
        
        # Başlangıç teması (QSS)
        self.current_stylesheet = load_theme(self.data_manager.current_theme)
        self.setStyleSheet(self.current_stylesheet)
        
        self.active_shortcuts = []
        
        self.init_ui()

    def init_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        main_layout = QVBoxLayout(central)
        
        # --- TOOLBAR SETUP ---
        toolbar = QHBoxLayout()
        toolbar.setContentsMargins(5, 5, 5, 5) 
        
        self.btn_toggle_player = QPushButton(tr("BTN_PLAYER_SCREEN"))
        self.btn_toggle_player.setCheckable(True)
        self.btn_toggle_player.setObjectName("primaryBtn")
        self.btn_toggle_player.clicked.connect(self.toggle_player_window)
        self.btn_export_txt = QPushButton(tr("BTN_EXPORT"))
        self.btn_export_txt.setObjectName("successBtn")
        self.btn_export_txt.clicked.connect(self.export_entities_to_txt)
        self.btn_toggle_sound = QPushButton("🔊")
        self.btn_toggle_sound.setCheckable(True)
        self.btn_toggle_sound.setToolTip(tr("BTN_TOGGLE_SOUNDPAD"))
        self.btn_toggle_sound.clicked.connect(self.toggle_soundpad)
        
        self.lbl_campaign = QLabel(f"{tr('LBL_CAMPAIGN')} {self.data_manager.data.get('world_name')}")
        self.lbl_campaign.setObjectName("toolbarLabel")
        self.lbl_campaign.setStyleSheet("font-weight: bold; margin-right: 10px;")

        self.btn_switch_world = QPushButton(tr("BTN_SWITCH_WORLD"))
        self.btn_switch_world.setToolTip(tr("BTN_SWITCH_WORLD"))
        self.btn_switch_world.clicked.connect(self.switch_world)

        # --- PROJECTION MANAGER (HEADER INTEGRATION) ---
        self.projection_manager = ProjectionManager()
        self.projection_manager.setVisible(False) 
        self.projection_manager.image_added.connect(self.player_window.add_image_to_view)
        self.projection_manager.image_removed.connect(self.player_window.remove_image_from_view)

        # Right side controls
        self.combo_lang = QComboBox()
        self.combo_lang.addItems(["English", "Türkçe"])
        current_lang = self.data_manager.settings.get("language", "EN")
        self.combo_lang.setCurrentIndex(1 if current_lang == "TR" else 0)
        self.combo_lang.currentIndexChanged.connect(self.change_language)
        
        self.lbl_theme = QLabel(tr("LBL_THEME"))
        self.lbl_theme.setObjectName("toolbarLabel")
        self.combo_theme = QComboBox()
        for _, display_name in self.theme_list:
            self.combo_theme.addItem(tr(display_name) if display_name.startswith("THEME_") else display_name)
        
        current_theme_code = self.data_manager.current_theme
        index_to_select = next((i for i, (code, _) in enumerate(self.theme_list) if code == current_theme_code), 0)
        self.combo_theme.setCurrentIndex(index_to_select)
        self.combo_theme.currentIndexChanged.connect(self.change_theme)
        
        # Adding widgets to toolbar
        toolbar.addWidget(self.btn_toggle_player)
        toolbar.addWidget(self.btn_export_txt)
        toolbar.addWidget(self.btn_toggle_sound)
        toolbar.addSpacing(10)
        toolbar.addWidget(self.lbl_campaign)
        toolbar.addWidget(self.projection_manager)
        toolbar.addStretch() 
        toolbar.addWidget(self.combo_lang)
        toolbar.addWidget(self.lbl_theme)
        toolbar.addWidget(self.combo_theme)
        toolbar.addWidget(self.btn_switch_world)
        
        main_layout.addLayout(toolbar)

        # --- ANA İÇERİK YAPISI (SPLITTER) ---
        self.content_splitter = QSplitter(Qt.Orientation.Horizontal)
        self.content_splitter.setHandleWidth(4)
        
        # 1. SOL PANEL: Global Entity Sidebar
        self.entity_sidebar = EntitySidebar(self.data_manager)
        self.entity_sidebar.item_double_clicked.connect(self.on_entity_selected)
        self.content_splitter.addWidget(self.entity_sidebar)
        
        # 2. ORTA PANEL: Sekmeler
        self.tabs = QTabWidget()
        
        self.db_tab = DatabaseTab(self.data_manager, self.player_window)
        self.tabs.addTab(self.db_tab, tr("TAB_DB"))
        
        self.mind_map_tab = MindMapTab(self.data_manager, main_window_ref=self)
        self.tabs.addTab(self.mind_map_tab, tr("TAB_MIND_MAP"))
        
        self.map_tab = MapTab(self.data_manager, self.player_window, self) 
        self.tabs.addTab(self.map_tab, tr("TAB_MAP")) 
        
        self.session_tab = SessionTab(self.data_manager)
        self.tabs.addTab(self.session_tab, tr("TAB_SESSION"))
        
        self.content_splitter.addWidget(self.tabs)
        
        # 3. SAĞ PANEL: Soundpad
        self.soundpad_panel = SoundpadPanel()
        self.soundpad_panel.setVisible(False)
        self.soundpad_panel.theme_loaded_with_shortcuts.connect(self.setup_soundpad_shortcuts)
        self.content_splitter.addWidget(self.soundpad_panel)
        
        self.content_splitter.setStretchFactor(0, 0)
        self.content_splitter.setStretchFactor(1, 1)
        self.content_splitter.setStretchFactor(2, 0)
        self.content_splitter.setCollapsible(0, True)
        self.content_splitter.setCollapsible(2, True)
        self.content_splitter.setSizes([300, 1000, 0])
        
        main_layout.addWidget(self.content_splitter)

        # Database sekmesinde bir şey silinirse sidebar listesini yenile
        self.db_tab.entity_deleted.connect(self.entity_sidebar.refresh_list)

        self.session_tab.txt_log.entity_link_clicked.connect(self.db_tab.open_entity_tab)
        self.session_tab.txt_notes.entity_link_clicked.connect(self.db_tab.open_entity_tab)
        
        self.map_tab.render_map()
        self.retranslate_ui()

    def setup_soundpad_shortcuts(self, shortcuts_map):
        for shortcut in self.active_shortcuts:
            shortcut.setEnabled(False)
            shortcut.deleteLater()
        self.active_shortcuts.clear()

        if stop_all_key := shortcuts_map.get("stop_all"):
            sc = QShortcut(QKeySequence(stop_all_key), self)
            sc.activated.connect(self.soundpad_panel.stop_all)
            self.active_shortcuts.append(sc)

        if stop_ambience_key := shortcuts_map.get("stop_ambience"):
            sc = QShortcut(QKeySequence(stop_ambience_key), self)
            sc.activated.connect(self.soundpad_panel.stop_ambience)
            self.active_shortcuts.append(sc)
            
        if sfx_shortcuts := shortcuts_map.get("play_sfx", {}):
            for sfx_id, key_sequence in sfx_shortcuts.items():
                if key_sequence and sfx_id in self.soundpad_panel.sfx_buttons:
                    sc = QShortcut(QKeySequence(key_sequence), self)
                    sc.activated.connect(lambda s_id=sfx_id: self.soundpad_panel.play_sfx(s_id))
                    self.active_shortcuts.append(sc)
    
    def retranslate_ui(self):
        self.btn_toggle_player.setText(tr("BTN_PLAYER_SCREEN"))
        self.btn_export_txt.setText(tr("BTN_EXPORT"))
        self.btn_toggle_sound.setToolTip(tr("BTN_TOGGLE_SOUNDPAD"))
        self.lbl_campaign.setText(f"{tr('LBL_CAMPAIGN')} {self.data_manager.data.get('world_name')}")
        self.tabs.setTabText(0, tr("TAB_DB"))
        self.tabs.setTabText(1, tr("TAB_MIND_MAP")) 
        self.tabs.setTabText(2, tr("TAB_MAP"))
        self.tabs.setTabText(3, tr("TAB_SESSION"))
        
        if hasattr(self.db_tab, "retranslate_ui"): self.db_tab.retranslate_ui()
        if hasattr(self.map_tab, "retranslate_ui"): self.map_tab.retranslate_ui()
        if hasattr(self.session_tab, "retranslate_ui"): self.session_tab.retranslate_ui()
        if hasattr(self.soundpad_panel, "retranslate_ui"): self.soundpad_panel.retranslate_ui()
        if hasattr(self.entity_sidebar, "retranslate_ui"): self.entity_sidebar.retranslate_ui()
        
        self.lbl_theme.setText(tr("LBL_THEME"))
        for i, (_, display_name) in enumerate(self.theme_list):
            self.combo_theme.setItemText(i, tr(display_name) if display_name.startswith("THEME_") else display_name)

    def change_language(self, index):
        self.data_manager.save_settings({"language": "TR" if index == 1 else "EN"})
        self.retranslate_ui()
    
    def toggle_soundpad(self):
        is_visible = self.soundpad_panel.isVisible()
        self.soundpad_panel.setVisible(not is_visible)
        self.btn_toggle_sound.setChecked(not is_visible)
        if not is_visible:
            sizes = self.content_splitter.sizes()
            if sizes[-1] == 0:
                new_size = 300
                sizes[1] -= new_size
                sizes[-1] = new_size
                self.content_splitter.setSizes(sizes)
    
    def change_theme(self, index):
        """
        Themes now update both QSS and Graphics View Palettes.
        """
        if 0 <= index < len(self.theme_list):
            theme_name = self.theme_list[index][0]
            self.data_manager.save_settings({"theme": theme_name})
            
            # 1. Update QSS (Widgets)
            self.current_stylesheet = load_theme(theme_name)
            self.setStyleSheet(self.current_stylesheet)
            if hasattr(self.player_window, "update_theme"): 
                self.player_window.update_theme(self.current_stylesheet)
            
            # 2. Update Graphics Views (Mind Map, Markdown)
            # Mind Map sekmesi
            if hasattr(self.mind_map_tab, "apply_theme"):
                self.mind_map_tab.apply_theme(theme_name)
                
            # Database sekmesindeki açık kartlar (NpcSheet -> MarkdownEditor)
            self.refresh_database_tab_themes(theme_name)

    def refresh_database_tab_themes(self, theme_name):
        """Helper to propagate theme changes to Database Tab contents."""
        palette = ThemeManager.get_palette(theme_name)
        
        # Left Panel Tabs
        for i in range(self.db_tab.tab_manager_left.count()):
            sheet = self.db_tab.tab_manager_left.widget(i)
            if hasattr(sheet, "refresh_theme"):
                sheet.refresh_theme(palette)
        
        # Right Panel Tabs
        for i in range(self.db_tab.tab_manager_right.count()):
            sheet = self.db_tab.tab_manager_right.widget(i)
            if hasattr(sheet, "refresh_theme"):
                sheet.refresh_theme(palette)

    def toggle_player_window(self):
        if self.player_window.isVisible(): 
            self.player_window.hide()
            self.btn_toggle_player.setChecked(False)
            self.projection_manager.setVisible(False)
        else: 
            self.player_window.show()
            self.btn_toggle_player.setChecked(True)
            self.player_window.update_theme(self.current_stylesheet)
            self.projection_manager.setVisible(True)

    def export_entities_to_txt(self):
        path, _ = QFileDialog.getSaveFileName(self, tr("TITLE_EXPORT"), "export.txt", tr("FILE_FILTER_TXT"))
        if not path: return
        try:
            with open(path, "w", encoding="utf-8") as f:
                f.write(f"{tr('TXT_EXPORT_HEADER')}\n")
                f.write(f"{tr('TXT_EXPORT_WORLD')}{self.data_manager.data.get('world_name')}\n")
                f.write("="*50 + "\n\n")
                entities = self.data_manager.data.get("entities", {})
                if not entities: f.write(f"{tr('TXT_EXPORT_NO_DATA')}\n")
                sorted_keys = sorted(entities.keys(), key=lambda k: entities[k].get("name", ""))
                for i, eid in enumerate(sorted_keys, 1):
                    ent = entities[eid]
                    name = ent.get("name", tr("NAME_UNNAMED"))
                    type_ = ent.get("type", tr("NAME_UNKNOWN"))
                    tags = ", ".join(ent.get("tags", []))
                    desc = ent.get("description", "").replace("\n", " ")
                    if len(desc) > 100: desc = desc[:97] + "..."
                    f.write(f"{i}. {name} ({type_})\n")
                    if tags: f.write(f"{tr('TXT_EXPORT_TAGS')}{tags}\n")
                    f.write(f"{tr('TXT_EXPORT_DESC')}{desc}\n")
                    c = ent.get("combat_stats", {})
                    if type_ in ["NPC", "Monster", "Player"] and c:
                        hp = c.get("hp", "-"); ac = c.get("ac", "-"); cr = c.get("cr", "-")
                        f.write(f"   HP: {hp} | AC: {ac} | CR: {cr}\n")
                    f.write("-" * 30 + "\n")
            QMessageBox.information(self, tr("MSG_SUCCESS"), tr("MSG_EXPORT_SUCCESS"))
        except Exception as e:
            QMessageBox.critical(self, tr("MSG_ERROR"), tr("MSG_FILE_WRITE_ERROR", error=str(e)))

    def switch_world(self):
        self.switch_world_requested = True
        self.close()

    def on_entity_selected(self, eid):
        current_idx = self.tabs.currentIndex()
        current_widget = self.tabs.widget(current_idx)
        if current_widget == self.db_tab:
            self.db_tab.open_entity_tab(eid)
        else:
            self.tabs.setCurrentWidget(self.db_tab)
            self.db_tab.open_entity_tab(eid)

if __name__ == "__main__":
    QApplication.setAttribute(Qt.ApplicationAttribute.AA_ShareOpenGLContexts)
    app = QApplication(sys.argv)
    dm = DataManager()
    while True:
        selector = CampaignSelector(dm)
        if selector.exec():
            window = MainWindow(dm)
            window.show()
            app.exec()
            if getattr(window, "switch_world_requested", False): continue
            else: break
        else: break
    sys.exit()