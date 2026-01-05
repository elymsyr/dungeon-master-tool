from os import environ
environ["QTWEBENGINE_DISABLE_SANDBOX"] = "1"
import sys
from PyQt6.QtWidgets import (QApplication, QMainWindow, QTabWidget, QVBoxLayout, 
                             QWidget, QMessageBox, QFileDialog, QHBoxLayout, 
                             QPushButton, QLabel, QComboBox)
from config import STYLESHEET, load_theme
from core.data_manager import DataManager
from ui.player_window import PlayerWindow
from ui.tabs.database_tab import DatabaseTab
from ui.tabs.map_tab import MapTab
from ui.tabs.session_tab import SessionTab # <--- YENİ EKLENEN IMPORT
from ui.campaign_selector import CampaignSelector
from core.locales import tr

class MainWindow(QMainWindow):
    def __init__(self, data_manager):
        super().__init__()
        self.data_manager = data_manager
        self.player_window = PlayerWindow()
        
        self.setWindowTitle(f"DM Tool - {self.data_manager.data.get('world_name', 'Bilinmiyor')}")
        self.setGeometry(100, 100, 1400, 900)
        
        # Apply initial theme
        self.current_stylesheet = load_theme(self.data_manager.current_theme)
        self.setStyleSheet(self.current_stylesheet)
        
        self.init_ui()

    def init_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        main_layout = QVBoxLayout(central)
        
        # --- ÜST BAR (TOOLBAR) ---
        toolbar = QHBoxLayout()
        
        
        # Oyuncu Ekranı Butonu
        self.btn_toggle_player = QPushButton(tr("BTN_PLAYER_SCREEN"))
        self.btn_toggle_player.setCheckable(True)
        self.btn_toggle_player.setStyleSheet("""
            QPushButton { background-color: #6a1b9a; color: white; font-weight: bold; padding: 8px; }
            QPushButton:checked { background-color: #4a148c; border: 2px solid #ea80fc; }
        """)
        self.btn_toggle_player.clicked.connect(self.toggle_player_window)
        
        # Dışa Aktar Butonu
        self.btn_export_txt = QPushButton(tr("BTN_EXPORT"))
        self.btn_export_txt.setStyleSheet("background-color: #00796b; color: white; font-weight: bold; padding: 8px;")
        self.btn_export_txt.clicked.connect(self.export_entities_to_txt)
        
        # Dünya Bilgisi
        self.lbl_campaign = QLabel(f"{tr('LBL_CAMPAIGN')} {self.data_manager.data.get('world_name')}")
        self.lbl_campaign.setStyleSheet("color: #888; font-style: italic; margin-left: 10px;")

        # Dil Seçimi
        self.combo_lang = QComboBox()
        self.combo_lang.addItems(["English", "Türkçe"])
        self.combo_lang.setStyleSheet("background-color: #333; color: white; padding: 5px;")
        
        # Mevcut dili seç
        current_lang = self.data_manager.settings.get("language", "EN")
        self.combo_lang.setCurrentIndex(1 if current_lang == "TR" else 0)
        self.combo_lang.currentIndexChanged.connect(self.change_language)
        
        # Tema Seçimi
        self.lbl_theme = QLabel(tr("LBL_THEME"))
        self.lbl_theme.setStyleSheet("color: #888; margin-left: 20px;")
        self.combo_theme = QComboBox()
        self.combo_theme.addItems(["Dark", "Midnight", "Light", "Emerald"])
        self.combo_theme.setStyleSheet("background-color: #333; color: white; padding: 5px; margin-left: 10px;")
        
        # Mevcut temayı seç
        theme_map = {"dark": 0, "midnight": 1, "light": 2, "emerald": 3}
        self.combo_theme.setCurrentIndex(theme_map.get(self.data_manager.current_theme, 0))
        self.combo_theme.currentIndexChanged.connect(self.change_theme)
        
        toolbar.addWidget(self.btn_toggle_player)
        toolbar.addWidget(self.btn_export_txt)
        toolbar.addWidget(self.lbl_campaign)
        toolbar.addStretch()
        toolbar.addWidget(self.combo_lang)
        toolbar.addWidget(self.lbl_theme)
        toolbar.addWidget(self.combo_theme)
        
        main_layout.addLayout(toolbar)
        
        # --- SEKMELER (TABS) ---
        self.tabs = QTabWidget()
        
        # Tab 1: Veritabanı
        self.db_tab = DatabaseTab(self.data_manager, self.player_window)
        self.tabs.addTab(self.db_tab, tr("TAB_DB"))
        
        # Tab 2: Harita
        # self'i (MainWindow) gönderiyoruz ki pinlere tıklayınca db_tab'a geçebilsin
        self.map_tab = MapTab(self.data_manager, self.player_window, self) 
        self.tabs.addTab(self.map_tab, tr("TAB_MAP")) 
        
        # Tab 3: Session (Oyun Yönetimi)
        self.session_tab = SessionTab(self.data_manager)
        self.tabs.addTab(self.session_tab, tr("TAB_SESSION"))
        
        main_layout.addWidget(self.tabs)
        
        self.map_tab.render_map()
        self.retranslate_ui()

    def change_language(self, index):
        code = "TR" if index == 1 else "EN"
        self.data_manager.save_settings({"language": code})
        self.retranslate_ui()

    def change_theme(self, index):
        themes = ["dark", "midnight", "light", "emerald"]
        theme_name = themes[index]
        self.data_manager.save_settings({"theme": theme_name})
        
        # Apply theme
        self.current_stylesheet = load_theme(theme_name)
        self.setStyleSheet(self.current_stylesheet)
        
        # Propagate to player window
        if hasattr(self.player_window, "update_theme"):
            self.player_window.update_theme(self.current_stylesheet)

    def retranslate_ui(self):
        self.btn_toggle_player.setText(tr("BTN_PLAYER_SCREEN"))
        self.btn_export_txt.setText(tr("BTN_EXPORT"))
        self.lbl_campaign.setText(f"{tr('LBL_CAMPAIGN')} {self.data_manager.data.get('world_name')}")
        
        self.tabs.setTabText(0, tr("TAB_DB"))
        self.tabs.setTabText(1, tr("TAB_MAP"))
        self.tabs.setTabText(2, tr("TAB_SESSION"))
        
        # Sekmelere de haber ver
        if hasattr(self.db_tab, "retranslate_ui"): self.db_tab.retranslate_ui()
        if hasattr(self.map_tab, "retranslate_ui"): self.map_tab.retranslate_ui()
        if hasattr(self.session_tab, "retranslate_ui"): self.session_tab.retranslate_ui()
        
        self.lbl_theme.setText(tr("LBL_THEME"))
        # Tema isimlerini güncelle
        self.combo_theme.setItemText(0, tr("THEME_DARK"))
        self.combo_theme.setItemText(1, tr("THEME_MIDNIGHT"))
        self.combo_theme.setItemText(2, tr("THEME_LIGHT"))
        self.combo_theme.setItemText(3, tr("THEME_EMERALD"))

    def toggle_player_window(self):
        if self.player_window.isVisible():
            self.player_window.hide()
            self.btn_toggle_player.setChecked(False)
        else:
            self.player_window.show()
            self.btn_toggle_player.setChecked(True)

    def export_entities_to_txt(self):
        # Kayıt yeri sor
        path, _ = QFileDialog.getSaveFileName(self, "Listeyi Kaydet", "export.txt", "Text Files (*.txt)")
        if not path: return
        
        try:
            with open(path, "w", encoding="utf-8") as f:
                f.write(f"ZINDAN EFENDISI - VARLIK LISTESI\n")
                f.write(f"Dünya: {self.data_manager.data.get('world_name')}\n")
                f.write("="*50 + "\n\n")
                
                entities = self.data_manager.data.get("entities", {})
                if not entities:
                    f.write("Henüz kaydedilmiş varlık yok.\n")
                
                # Sıralayarak yazalım
                sorted_keys = sorted(entities.keys(), key=lambda k: entities[k].get("name", ""))
                
                for i, eid in enumerate(sorted_keys, 1):
                    ent = entities[eid]
                    name = ent.get("name", "İsimsiz")
                    type_ = ent.get("type", "Bilinmiyor")
                    tags = ", ".join(ent.get("tags", []))
                    desc = ent.get("description", "").replace("\n", " ")
                    if len(desc) > 100: desc = desc[:97] + "..."
                    
                    f.write(f"{i}. {name} ({type_})\n")
                    if tags: f.write(f"   Etiketler: {tags}\n")
                    f.write(f"   Açıklama: {desc}\n")
                    
                    # Statları da ekleyelim (Sadece savaşçı varlıklar için)
                    c = ent.get("combat_stats", {})
                    # Sadece belirli tiplerde statları gösterelim
                    if type_ in ["NPC", "Monster", "Player"] and c:
                        hp = c.get("hp", "-")
                        ac = c.get("ac", "-")
                        cr = c.get("cr", "-")
                        f.write(f"   HP: {hp} | AC: {ac} | CR: {cr}\n")
                        
                    f.write("-" * 30 + "\n")
            
            QMessageBox.information(self, "Başarılı", "Liste başarıyla dışa aktarıldı.")
        except Exception as e:
            QMessageBox.critical(self, "Hata", f"Dosya yazılamadı:\n{e}")


if __name__ == "__main__":
    app = QApplication(sys.argv)
    
    # 1. Veri Yöneticisi Başlat
    dm = DataManager()
    
    # 2. Seçim Ekranı
    selector = CampaignSelector(dm)
    if selector.exec():
        # 3. Ana Pencere
        window = MainWindow(dm)
        window.show()
        sys.exit(app.exec())
    else:
        sys.exit()