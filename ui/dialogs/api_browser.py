from PyQt6.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QListWidget, 
                             QLineEdit, QPushButton, QLabel, QTextEdit, 
                             QMessageBox, QListWidgetItem, QSplitter, QWidget, 
                             QApplication, QComboBox)
from PyQt6.QtCore import Qt
from ui.workers import ApiListWorker, ApiSearchWorker
from core.locales import tr

class ApiBrowser(QDialog):
    # API İstemcisinin (ApiClient) tanıdığı kesin anahtarlar
    CATEGORY_KEYS = [
        "Monster", 
        "Spell", 
        "Equipment", 
        "Magic Item", 
        "Class", 
        "Race"
    ]

    def __init__(self, data_manager, initial_category, parent=None):
        super().__init__(parent)
        self.dm = data_manager
        
        # Başlangıç kategorisini doğrula ve ayarla
        self.current_category = "Monster" 
        norm_init = str(initial_category).lower()
        
        for key in self.CATEGORY_KEYS:
            if key.lower() == norm_init:
                self.current_category = key
                break
        
        self.selected_data = None
        self.full_list = [] 
        
        self.setWindowTitle(tr("TITLE_API"))
        self.resize(1000, 650)
        
        self.init_ui()
        self.load_list()

    def init_ui(self):
        main_layout = QVBoxLayout(self)
        
        # --- ÜST BAR: Kategori ve Arama ---
        top_layout = QHBoxLayout()
        
        # 1. Kategori Seçici
        self.combo_cat = QComboBox()
        self.combo_cat.setFixedWidth(180)
        
        for cat_key in self.CATEGORY_KEYS:
            # Dil dosyasından çeviri anahtarını oluştur (Örn: CAT_MAGIC_ITEM)
            trans_key = f"CAT_{cat_key.upper().replace(' ', '_')}"
            display_text = tr(trans_key)
            
            # Eğer çeviri yoksa (anahtarın kendisi döndüyse), orijinali kullan
            if display_text == trans_key:
                display_text = cat_key
                
            self.combo_cat.addItem(display_text, cat_key)
        
        # Başlangıç kategorisini seçili yap
        index = self.combo_cat.findData(self.current_category)
        if index >= 0:
            self.combo_cat.setCurrentIndex(index)
            
        self.combo_cat.currentIndexChanged.connect(self.on_category_changed)
        
        # 2. Arama Kutusu
        self.inp_filter = QLineEdit()
        self.inp_filter.setPlaceholderText(tr("LBL_SEARCH_API"))
        self.inp_filter.textChanged.connect(self.filter_list)
        
        top_layout.addWidget(QLabel(tr("LBL_CATEGORY")))
        top_layout.addWidget(self.combo_cat)
        top_layout.addWidget(self.inp_filter, 1)
        
        main_layout.addLayout(top_layout)
        
        # --- ORTA: Bölücü (Liste | Önizleme) ---
        splitter = QSplitter(Qt.Orientation.Horizontal)
        
        # Sol: Liste
        self.list_widget = QListWidget()
        self.list_widget.setAlternatingRowColors(True)
        self.list_widget.itemClicked.connect(self.on_item_clicked)
        splitter.addWidget(self.list_widget)
        
        # Sağ: Önizleme
        preview_widget = QWidget()
        prev_layout = QVBoxLayout(preview_widget)
        prev_layout.setContentsMargins(10, 0, 0, 0)
        
        self.lbl_name = QLabel(tr("MSG_NO_SELECTION"))
        self.lbl_name.setObjectName("headerLabel")
        self.lbl_name.setStyleSheet("font-size: 18px; font-weight: bold; margin-bottom: 5px;")
        
        self.txt_desc = QTextEdit()
        self.txt_desc.setReadOnly(True)
        
        btn_layout = QHBoxLayout()
        self.btn_import = QPushButton(tr("BTN_IMPORT"))
        self.btn_import.setObjectName("successBtn")
        self.btn_import.setEnabled(False)
        self.btn_import.clicked.connect(self.import_selected)
        
        self.btn_import_npc = QPushButton(tr("BTN_IMPORT_NPC"))
        self.btn_import_npc.setObjectName("primaryBtn")
        self.btn_import_npc.setVisible(False)
        self.btn_import_npc.clicked.connect(lambda: self.import_selected(target_type="NPC"))
        
        btn_layout.addWidget(self.btn_import)
        btn_layout.addWidget(self.btn_import_npc)
        
        prev_layout.addWidget(self.lbl_name)
        prev_layout.addWidget(self.txt_desc)
        prev_layout.addLayout(btn_layout)
        
        splitter.addWidget(preview_widget)
        splitter.setSizes([350, 650])
        
        main_layout.addWidget(splitter)

    def on_category_changed(self):
        """Kategori değiştiğinde listeyi yenile."""
        self.current_category = self.combo_cat.currentData()
        self.load_list()

    def load_list(self):
        self.list_widget.clear()
        self.full_list = []
        self.txt_desc.clear()
        self.lbl_name.setText(tr("MSG_LOADING"))
        self.btn_import.setEnabled(False)
        self.btn_import_npc.setVisible(False)
        self.setEnabled(False)
        
        # [DÜZELTME] Endpoint değil, Kategori Adını gönderiyoruz (ApiClient bunu endpoint'e çevirecek)
        self.list_worker = ApiListWorker(self.dm.api_client, self.current_category)
        self.list_worker.finished.connect(self.on_list_loaded)
        self.list_worker.start()

    def on_list_loaded(self, data):
        self.setEnabled(True)
        self.lbl_name.setText(tr("MSG_NO_SELECTION"))
        self.full_list = data
        
        if not self.full_list:
            # Boş liste veya hata durumu
            item = QListWidgetItem(tr("MSG_LIST_EMPTY"))
            item.setFlags(Qt.ItemFlag.NoItemFlags) # Tıklanamaz
            self.list_widget.addItem(item)
            return

        self.filter_list()

    def filter_list(self):
        query = self.inp_filter.text().lower()
        self.list_widget.clear()
        
        if not self.full_list: return

        for item in self.full_list:
            if query in item["name"].lower():
                list_item = QListWidgetItem(item["name"])
                list_item.setData(Qt.ItemDataRole.UserRole, item["index"])
                self.list_widget.addItem(list_item)

    def on_item_clicked(self, item):
        index_name = item.data(Qt.ItemDataRole.UserRole)
        if not index_name: return 
        
        self.lbl_name.setText(item.text() + f" ({tr('MSG_LOADING')})")
        self.txt_desc.clear()
        self.btn_import.setEnabled(False)
        self.list_widget.setEnabled(False)
        
        # Seçili kategori ve indeks ile arama yap
        self.detail_worker = ApiSearchWorker(self.dm, self.current_category, index_name)
        self.detail_worker.finished.connect(self.on_details_loaded)
        self.detail_worker.start()

    def on_details_loaded(self, success, data_or_id, msg):
        self.list_widget.setEnabled(True)
        
        if success:
            if isinstance(data_or_id, str):
                # Veritabanında zaten var (ID döndü)
                data = self.dm.data["entities"].get(data_or_id)
                self.btn_import.setEnabled(False)
                self.btn_import.setText(tr("MSG_EXISTS"))
                self.btn_import_npc.setVisible(False)
            else:
                # Yeni Veri
                data = data_or_id
                self.btn_import.setEnabled(True)
                self.btn_import.setText(tr("BTN_IMPORT"))
                
            if not data:
                self.lbl_name.setText(tr("MSG_ERROR"))
                self.txt_desc.setText(tr("MSG_NOT_FOUND"))
                return

            self.selected_data = data
            self.lbl_name.setText(data.get("name"))
            
            # Kategoriye göre Import Butonları
            try: self.btn_import.clicked.disconnect()
            except: pass
            
            if self.current_category == "NPC":
                self.btn_import.setText(tr("BTN_IMPORT_NPC"))
                self.btn_import.clicked.connect(lambda: self.import_selected(target_type="NPC"))
                self.btn_import_npc.setVisible(False)
            
            elif self.current_category == "Monster":
                self.btn_import.setText(tr("BTN_IMPORT"))
                self.btn_import.clicked.connect(lambda: self.import_selected(target_type=None))
                
                # Sadece yeni veriyse "NPC Olarak Al" seçeneği göster
                if not isinstance(data_or_id, str):
                    self.btn_import_npc.setVisible(True)
                    self.btn_import_npc.setEnabled(True)
                else:
                    self.btn_import_npc.setVisible(False)
            else:
                # Diğerleri (Spell, Equipment vb.)
                self.btn_import.setText(tr("BTN_IMPORT"))
                self.btn_import.clicked.connect(lambda: self.import_selected(target_type=None))
                self.btn_import_npc.setVisible(False)

            # Açıklama Metni Oluştur
            desc = f"{tr('LBL_TYPE')}: {tr('CAT_' + data.get('type', '').upper())}\n\n"
            desc += data.get("description", "")
            
            if "attributes" in data:
                desc += f"\n\n--- {tr('LBL_PROPERTIES')} ---\n"
                for k, v in data["attributes"].items():
                    val = tr(v) if str(v).startswith("LBL_") else v
                    desc += f"{tr(k)}: {val}\n"
            
            self.txt_desc.setText(desc)
        else:
            self.lbl_name.setText(tr("MSG_ERROR"))
            self.txt_desc.setText(msg)
            self.btn_import.setEnabled(False)

    def import_selected(self, target_type=None):
        if self.selected_data:
            self.btn_import.setEnabled(False)
            self.btn_import_npc.setEnabled(False)
            self.btn_import.setText(tr("MSG_IMPORTING"))
            QApplication.processEvents()
            
            try:
                self.dm.import_entity_with_dependencies(self.selected_data, type_override=target_type)
                QMessageBox.information(self, tr("MSG_SUCCESS"), tr("MSG_IMPORT_SUCCESS_DETAIL", name=self.selected_data['name']))
                self.load_list() # Buton durumunu güncellemek için listeyi yenile
            except Exception as e:
                self.btn_import.setEnabled(True)
                self.btn_import.setText(tr("BTN_IMPORT"))
                QMessageBox.critical(self, tr("MSG_ERROR"), f"Error: {str(e)}")