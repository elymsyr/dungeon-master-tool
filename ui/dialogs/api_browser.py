from PyQt6.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QListWidget, 
                             QLineEdit, QPushButton, QLabel, QTextEdit, 
                             QMessageBox, QListWidgetItem, QSplitter, QWidget, QApplication)
from PyQt6.QtCore import Qt
from ui.workers import ApiListWorker, ApiSearchWorker
from core.locales import tr

class ApiBrowser(QDialog):
    def __init__(self, data_manager, category, parent=None):
        super().__init__(parent)
        self.dm = data_manager
        self.category = category
        self.selected_data = None
        
        self.setWindowTitle(f"{tr('TITLE_API')}: {category}")
        self.resize(900, 600)
        
        # Hardcoded stil bloğu KALDIRILDI. 
        # Tüm renkler ve şekiller artık QSS dosyalarından (dark.qss vb.) yüklenecek.
        
        self.full_list = [] # API'den gelen ham liste
        self.init_ui()
        self.load_list()

    def init_ui(self):
        main_layout = QVBoxLayout(self)
        
        # Üst: Arama
        self.inp_filter = QLineEdit()
        self.inp_filter.setPlaceholderText(f"{tr('LBL_SEARCH_API')} ({self.category})")
        self.inp_filter.textChanged.connect(self.filter_list)
        main_layout.addWidget(self.inp_filter)
        
        # Orta: Splitter (Liste | Önizleme)
        splitter = QSplitter(Qt.Orientation.Horizontal)
        
        # Sol: Liste
        self.list_widget = QListWidget()
        self.list_widget.itemClicked.connect(self.on_item_clicked)
        splitter.addWidget(self.list_widget)
        
        # Sağ: Önizleme
        preview_widget = QWidget()
        prev_layout = QVBoxLayout(preview_widget)
        prev_layout.setContentsMargins(10, 0, 0, 0) # Sol taraftan biraz boşluk bırak
        
        self.lbl_name = QLabel(tr("MSG_NO_SELECTION"))
        # Başlık için ID atıyoruz (Temalarda özelleştirilebilir)
        self.lbl_name.setObjectName("headerLabel")
        # Sadece font büyüklüğünü ve kalınlığını burada belirtiyoruz, rengi temaya bırakıyoruz.
        self.lbl_name.setStyleSheet("font-size: 18px; font-weight: bold; margin-bottom: 5px;")
        
        self.txt_desc = QTextEdit()
        self.txt_desc.setReadOnly(True)
        
        btn_layout = QHBoxLayout()
        self.btn_import = QPushButton(tr("BTN_IMPORT"))
        # Temadan "Yeşil Buton" stilini alması için ID:
        self.btn_import.setObjectName("successBtn")
        self.btn_import.setEnabled(False)
        self.btn_import.clicked.connect(self.import_selected)
        
        self.btn_import_npc = QPushButton(tr("BTN_IMPORT_NPC"))
        # Temadan "Mavi/Ana Buton" stilini alması için ID:
        self.btn_import_npc.setObjectName("primaryBtn")
        self.btn_import_npc.setVisible(False)
        self.btn_import_npc.clicked.connect(lambda: self.import_selected(target_type="NPC"))
        
        btn_layout.addWidget(self.btn_import)
        btn_layout.addWidget(self.btn_import_npc)
        
        prev_layout.addWidget(self.lbl_name)
        prev_layout.addWidget(self.txt_desc)
        prev_layout.addLayout(btn_layout)
        
        splitter.addWidget(preview_widget)
        splitter.setSizes([300, 600])
        
        main_layout.addWidget(splitter)

    def load_list(self):
        self.list_widget.clear()
        self.lbl_name.setText(tr("MSG_LOADING"))
        self.setEnabled(False)
        
        # Worker ile listeyi çek
        self.list_worker = ApiListWorker(self.dm.api_client, self.category)
        self.list_worker.finished.connect(self.on_list_loaded)
        self.list_worker.start()

    def on_list_loaded(self, data):
        self.setEnabled(True)
        self.lbl_name.setText(tr("MSG_NO_SELECTION"))
        self.full_list = data
        
        if not self.full_list:
            QMessageBox.information(self, tr("MSG_WARNING"), tr("MSG_LIST_EMPTY"))
            return

        # Listeyi doldur
        for item in self.full_list:
            list_item = QListWidgetItem(item["name"])
            list_item.setData(Qt.ItemDataRole.UserRole, item["index"])
            self.list_widget.addItem(list_item)

    def filter_list(self):
        query = self.inp_filter.text().lower()
        self.list_widget.clear()
        for item in self.full_list:
            if query in item["name"].lower():
                list_item = QListWidgetItem(item["name"])
                list_item.setData(Qt.ItemDataRole.UserRole, item["index"])
                self.list_widget.addItem(list_item)

    def on_item_clicked(self, item):
        index_name = item.data(Qt.ItemDataRole.UserRole)
        
        # Kullanıcıya "Yükleniyor..." hissi ver
        self.lbl_name.setText(item.text() + f" ({tr('MSG_LOADING')})")
        self.txt_desc.clear()
        self.btn_import.setEnabled(False)
        self.list_widget.setEnabled(False)
        
        # Worker ile detayları çek
        self.detail_worker = ApiSearchWorker(self.dm, self.category, index_name)
        self.detail_worker.finished.connect(self.on_details_loaded)
        self.detail_worker.start()

    def on_details_loaded(self, success, data_or_id, msg):
        self.list_widget.setEnabled(True)
        
        if success:
            if isinstance(data_or_id, str):
                # Zaten veritabanında var, ID gelmiş
                data = self.dm.data["entities"].get(data_or_id)
                self.btn_import.setEnabled(False)
                self.btn_import.setText(tr("MSG_EXISTS"))
                self.btn_import_npc.setVisible(False)
            else:
                # Yeni veri
                data = data_or_id
                self.btn_import.setEnabled(True)
                
            if not data:
                self.lbl_name.setText(tr("MSG_ERROR"))
                self.txt_desc.setText(tr("Bulunamadı."))
                return

            self.selected_data = data
            self.lbl_name.setText(data.get("name"))
            
            # Monster ise butonları kategoriye göre ayarla
            try: self.btn_import.clicked.disconnect()
            except: pass
            
            if self.category == "NPC":
                # NPC kategorisinden açıldıysa direkt NPC olarak aktar
                self.btn_import.setText(tr("BTN_IMPORT_NPC"))
                self.btn_import.clicked.connect(lambda: self.import_selected(target_type="NPC"))
                self.btn_import_npc.setVisible(False)
            elif self.category == "Monster":
                # Monster kategorisinden açıldıysa varsayılan Monster (ama NPC seçeneği de var)
                self.btn_import.setText(tr("BTN_IMPORT"))
                self.btn_import.clicked.connect(lambda: self.import_selected(target_type=None))
                
                if not isinstance(data_or_id, str):
                    self.btn_import_npc.setVisible(True)
                    self.btn_import_npc.setEnabled(True)
                else:
                    self.btn_import_npc.setVisible(False)
            else:
                # Diğer kategoriler (Büyü, Eşya vb.)
                self.btn_import.setText(tr("BTN_IMPORT"))
                self.btn_import.clicked.connect(lambda: self.import_selected(target_type=None))
                self.btn_import_npc.setVisible(False)

            # Açıklamayı oluştur
            desc = f"{tr('LBL_TYPE')}: {tr('CAT_' + data.get('type', '').upper())}\n\n"
            desc += data.get("description", "")
            
            # Statlar vs varsa ekle
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
            # Kullanıcıya geri bildirim ver
            self.btn_import.setEnabled(False)
            self.btn_import_npc.setEnabled(False)
            self.btn_import.setText(tr("MSG_IMPORTING"))
            QApplication.processEvents() # Arayüzün donmaması için
            
            try:
                # Asıl kaydetme işlemini yap (büyülerle birlikte)
                self.dm.import_entity_with_dependencies(self.selected_data, type_override=target_type)
                
                QMessageBox.information(self, tr("MSG_SUCCESS"), tr("MSG_IMPORT_SUCCESS_DETAIL", name=self.selected_data['name']))
                self.accept()
            except Exception as e:
                self.btn_import.setEnabled(True)
                self.btn_import.setText(tr("BTN_IMPORT"))
                QMessageBox.critical(self, tr("MSG_ERROR"), f"Hata oluştu: {str(e)}")