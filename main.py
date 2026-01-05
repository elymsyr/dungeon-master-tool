from os import environ
environ["QTWEBENGINE_DISABLE_SANDBOX"] = "1"
import sys
from PyQt6.QtWidgets import (QApplication, QMainWindow, QTabWidget, QVBoxLayout, 
                             QWidget, QMessageBox, QFileDialog, QHBoxLayout, 
                             QPushButton, QLabel)
from config import STYLESHEET
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
        self.setStyleSheet(STYLESHEET)
        
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

        toolbar.addWidget(self.btn_toggle_player)
        toolbar.addWidget(self.btn_export_txt)
        toolbar.addWidget(self.lbl_campaign)
        toolbar.addStretch()
        
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
        
        # Başlangıçta haritayı yükle (varsa)
        self.map_tab.render_map()

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
                    if type_ in ["NPC", "Canavar", "Oyuncu"] and c:
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