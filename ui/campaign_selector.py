from PyQt6.QtWidgets import (QDialog, QVBoxLayout, QListWidget, QPushButton, 
                             QLineEdit, QHBoxLayout, QLabel, QMessageBox, QWidget, QComboBox) # QComboBox eklendi
from core.locales import tr, set_language
from PyQt6.QtCore import Qt

class CampaignSelector(QDialog):
    def __init__(self, data_manager):
        super().__init__()
        self.dm = data_manager
        self.selected_campaign = None
        
        self.selected_campaign = None
        
        self.setWindowTitle("Select World")
        self.setFixedSize(400, 500)
        self.setStyleSheet("""
            QDialog { background-color: #1e1e1e; color: white; }
            QListWidget { background-color: #252526; border: 1px solid #333; font-size: 16px; }
            QListWidget::item { padding: 10px; }
            QListWidget::item:selected { background-color: #007acc; }
            QLineEdit { padding: 8px; background-color: #333; color: white; border: 1px solid #555; }
            QPushButton { padding: 10px; background-color: #444; color: white; border: none; font-weight: bold; }
            QPushButton:hover { background-color: #555; }
            QPushButton#createBtn { background-color: #2e7d32; }
            QPushButton#loadBtn { background-color: #007acc; }
        """)
        
        self.init_ui()
        self.refresh_list()

    def init_ui(self):
        layout = QVBoxLayout(self)
        
        # Başlık
        # Başlık
        self.lbl_title = QLabel("🔮 Select World")
        self.lbl_title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.lbl_title.setStyleSheet("font-size: 20px; font-weight: bold; margin-bottom: 10px; color: #ffa500;")
        layout.addWidget(self.lbl_title)
        
        # Liste
        self.list_widget = QListWidget()
        self.list_widget.itemDoubleClicked.connect(self.load_campaign) # Çift tıklama ile aç
        layout.addWidget(self.list_widget)
        
        # Yükle Butonu
        # Yükle Butonu
        self.btn_load = QPushButton("Load")
        self.btn_load.setObjectName("loadBtn")
        self.btn_load.clicked.connect(self.load_campaign)
        layout.addWidget(self.btn_load)
        
        layout.addSpacing(20)
        
        # Yeni Oluşturma Alanı
        create_layout = QHBoxLayout()
        self.inp_new_name = QLineEdit()
        self.inp_new_name.setPlaceholderText("Yeni Dünya Adı...")
        
        self.btn_create = QPushButton("Create")
        self.btn_create.setObjectName("createBtn")
        self.btn_create.clicked.connect(self.create_campaign)
        
        create_layout.addWidget(self.inp_new_name)
        create_layout.addWidget(self.btn_create)
        
        layout.addLayout(create_layout)

        # Dil Seçimi (Alt Kısım)
        lang_layout = QHBoxLayout()
        self.lbl_lang = QLabel(tr("LBL_LANGUAGE")) # "Language / Dil:"
        self.combo_lang = QComboBox()
        self.combo_lang.addItems(["English", "Türkçe"])
        
        # Mevcut dili seç
        current_lang = self.dm.settings.get("language", "EN")
        self.combo_lang.setCurrentIndex(1 if current_lang == "TR" else 0)
        
        self.combo_lang.currentIndexChanged.connect(self.change_language)
        
        lang_layout.addStretch()
        lang_layout.addWidget(self.lbl_lang)
        lang_layout.addWidget(self.combo_lang)
        layout.addLayout(lang_layout)

        self.update_texts()

    def change_language(self, index):
        code = "TR" if index == 1 else "EN"
        self.dm.save_settings({"language": code})
        self.update_texts()

    def update_texts(self):
        self.setWindowTitle(tr("TITLE_SELECT_WORLD"))
        self.lbl_title.setText(tr("TITLE_SELECT_WORLD"))
        self.btn_load.setText(tr("BTN_LOAD_SESSION")) # "Load" / "Yükle"
        self.inp_new_name.setPlaceholderText(tr("MSG_ENTER_WORLD_NAME"))
        self.btn_create.setText(tr("BTN_CREATE_WORLD"))
        self.lbl_lang.setText(tr("LBL_LANGUAGE"))

    def refresh_list(self):
        self.list_widget.clear()
        campaigns = self.dm.get_available_campaigns()
        self.list_widget.addItems(campaigns)

    def load_campaign(self):
        # Seçili item var mı?
        current_item = self.list_widget.currentItem()
        if not current_item:
            QMessageBox.warning(self, "Uyarı", "Lütfen bir dünya seçin.")
            return
            
        world_name = current_item.text()
        success, msg = self.dm.load_campaign_by_name(world_name)
        
        if success:
            self.selected_campaign = world_name
            self.accept() # Diyaloğu kapat ve "Başarılı" kodu dön
        else:
            QMessageBox.critical(self, "Hata", msg)

    def create_campaign(self):
        name = self.inp_new_name.text().strip()
        if not name:
            QMessageBox.warning(self, "Uyarı", "İsim boş olamaz.")
            return
            
        # Zaten var mı kontrolü (basit)
        if name in self.dm.get_available_campaigns():
             QMessageBox.warning(self, "Uyarı", "Bu isimde bir dünya zaten var.")
             return

        success, msg = self.dm.create_campaign(name)
        if success:
            self.selected_campaign = name
            self.accept()
        else:
            QMessageBox.critical(self, "Hata", msg)