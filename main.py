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
        self.btn_toggle_player = QPushButton("📺 Oyuncu Ekranını Aç/Kapat")
        self.btn_toggle_player.setCheckable(True)
        self.btn_toggle_player.setStyleSheet("""
            QPushButton { background-color: #6a1b9a; color: white; font-weight: bold; padding: 8px; }
            QPushButton:checked { background-color: #4a148c; border: 2px solid #ea80fc; }
        """)
        self.btn_toggle_player.clicked.connect(self.toggle_player_window)
        
        # Dünya Bilgisi
        self.lbl_campaign = QLabel(f"Dünya: {self.data_manager.data.get('world_name')}")
        self.lbl_campaign.setStyleSheet("color: #888; font-style: italic; margin-left: 10px;")

        toolbar.addWidget(self.btn_toggle_player)
        toolbar.addWidget(self.lbl_campaign)
        toolbar.addStretch()
        
        main_layout.addLayout(toolbar)
        
        # --- SEKMELER (TABS) ---
        self.tabs = QTabWidget()
        
        # Tab 1: Veritabanı
        self.db_tab = DatabaseTab(self.data_manager, self.player_window)
        self.tabs.addTab(self.db_tab, "Veritabanı & Karakterler")
        
        # Tab 2: Harita
        # self'i (MainWindow) gönderiyoruz ki pinlere tıklayınca db_tab'a geçebilsin
        self.map_tab = MapTab(self.data_manager, self.player_window, self) 
        self.tabs.addTab(self.map_tab, "Harita") 
        
        # Tab 3: Session (Oyun Yönetimi)
        self.session_tab = SessionTab(self.data_manager)
        self.tabs.addTab(self.session_tab, "Oyun Yönetimi (Session)")
        
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