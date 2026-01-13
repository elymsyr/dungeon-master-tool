# ui/campaign_selector.py tamamını güncelleyelim:

from PyQt6.QtWidgets import (QDialog, QVBoxLayout, QListWidget, QPushButton, 
                             QLineEdit, QHBoxLayout, QLabel, QMessageBox, QWidget, QComboBox)
from core.locales import tr, set_language
from PyQt6.QtCore import Qt

class CampaignSelector(QDialog):
    def __init__(self, data_manager):
        super().__init__()
        self.dm = data_manager
        self.selected_campaign = None
        
        self.setWindowTitle("Select World") # Temporary, update_texts will fix
        self.setFixedSize(400, 500)
        # Style will come from QSS or basic
        
        self.init_ui()
        self.refresh_list()

    def init_ui(self):
        layout = QVBoxLayout(self)
        
        # Title
        self.lbl_title = QLabel()
        self.lbl_title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.lbl_title.setObjectName("headerLabel") # QSS ID
        self.lbl_title.setStyleSheet("font-size: 20px; font-weight: bold; margin-bottom: 10px;")
        layout.addWidget(self.lbl_title)
        
        # List
        self.list_widget = QListWidget()
        self.list_widget.itemDoubleClicked.connect(self.load_campaign)
        layout.addWidget(self.list_widget)
        
        # Load Button
        self.btn_load = QPushButton()
        self.btn_load.setObjectName("primaryBtn")
        self.btn_load.clicked.connect(self.load_campaign)
        layout.addWidget(self.btn_load)
        
        layout.addSpacing(20)
        
        # New Creation Area
        create_layout = QHBoxLayout()
        self.inp_new_name = QLineEdit()
        
        self.btn_create = QPushButton()
        self.btn_create.setObjectName("successBtn")
        self.btn_create.clicked.connect(self.create_campaign)
        
        create_layout.addWidget(self.inp_new_name)
        create_layout.addWidget(self.btn_create)
        
        layout.addLayout(create_layout)

        # Language Selection
        lang_layout = QHBoxLayout()
        self.lbl_lang = QLabel(tr("LBL_LANGUAGE"))
        self.combo_lang = QComboBox()
        self.combo_lang.addItems(["English", "Türkçe"])
        
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
        self.lbl_title.setText(tr("LBL_SELECT_WORLD_TITLE"))
        self.btn_load.setText(tr("BTN_LOAD"))
        self.inp_new_name.setPlaceholderText(tr("PH_NEW_WORLD_NAME"))
        self.btn_create.setText(tr("BTN_CREATE"))
        self.lbl_lang.setText(tr("LBL_LANGUAGE"))

    def refresh_list(self):
        self.list_widget.clear()
        campaigns = self.dm.get_available_campaigns()
        self.list_widget.addItems(campaigns)

    def load_campaign(self):
        current_item = self.list_widget.currentItem()
        if not current_item:
            QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_SELECT_WORLD_WARN"))
            return
            
        world_name = current_item.text()
        success, msg = self.dm.load_campaign_by_name(world_name)
        
        if success:
            self.selected_campaign = world_name
            self.accept()
        else:
            QMessageBox.critical(self, tr("MSG_ERROR"), msg)

    def create_campaign(self):
        name = self.inp_new_name.text().strip()
        if not name:
            QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_NAME_EMPTY"))
            return
            
        if name in self.dm.get_available_campaigns():
             QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_WORLD_EXISTS"))
             return

        success, msg = self.dm.create_campaign(name)
        if success:
            self.selected_campaign = name
            self.accept()
        else:
            QMessageBox.critical(self, tr("MSG_ERROR"), msg)