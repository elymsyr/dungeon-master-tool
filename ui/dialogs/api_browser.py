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
        self.setStyleSheet("""
            QDialog { background-color: #1e1e1e; color: white; }
            QLineEdit { padding: 8px; background-color: #333; color: white; border: 1px solid #555; }
            QListWidget { background-color: #252526; border: 1px solid #444; }
            QListWidget::item { padding: 5px; }
            QListWidget::item:selected { background-color: #007acc; }
            QTextEdit { background-color: #2b2b2b; border: 1px solid #444; }
            QPushButton { padding: 10px; background-color: #444; color: white; font-weight: bold; border: none; }
            QPushButton:hover { background-color: #555; }
            QPushButton#importBtn { background-color: #2e7d32; }
            QPushButton#importBtn:hover { background-color: #1b5e20; }
        """)
        
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
        prev_layout.setContentsMargins(0,0,0,0)
        
        self.lbl_name = QLabel(tr("MSG_NO_SELECTION"))
        self.lbl_name.setStyleSheet("font-size: 18px; font-weight: bold; color: #ffa500; margin-bottom: 5px;")
        
        self.txt_desc = QTextEdit()
        self.txt_desc.setReadOnly(True)
        
        self.btn_import = QPushButton(tr("BTN_IMPORT"))
        self.btn_import.setObjectName("importBtn")
        self.btn_import.setEnabled(False)
        self.btn_import.clicked.connect(self.import_selected)
        
        prev_layout.addWidget(self.lbl_name)
        prev_layout.addWidget(self.txt_desc)
        prev_layout.addWidget(self.btn_import)
        
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
            data = data_or_id
            self.selected_data = data
            self.lbl_name.setText(data.get("name"))
            
            # Açıklamayı oluştur
            desc = f"Tip: {data.get('type')}\n\n"
            desc += data.get("description", "")
            
            # Statlar vs varsa ekle
            if "attributes" in data:
                desc += "\n\n--- Özellikler ---\n"
                for k, v in data["attributes"].items():
                    desc += f"{k}: {v}\n"
            
            self.txt_desc.setText(desc)
            self.btn_import.setEnabled(True)
        else:
            self.lbl_name.setText(tr("MSG_ERROR"))
            self.txt_desc.setText(msg)

    def import_selected(self):
        if self.selected_data:
            # Kullanıcıya geri bildirim ver
            self.btn_import.setEnabled(False)
            self.btn_import.setText("Veriler ve Büyüler İndiriliyor...")
            QApplication.processEvents() # Arayüzün donmaması için
            
            try:
                # Yeni "dependency-aware" import metodunu çağır
                # Bu metod detected_spells'i işleyip temizleyecek ve kaydecek
                QMessageBox.information(self, tr("MSG_SUCCESS"), tr("MSG_IMPORT_SUCCESS_DETAIL", name=self.selected_data['name']))
                self.accept()
            except Exception as e:
                self.btn_import.setEnabled(True)
                self.btn_import.setText(tr("BTN_IMPORT"))
                QMessageBox.critical(self, tr("MSG_ERROR"), f"Hata oluştu: {str(e)}")