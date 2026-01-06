from PyQt6.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QTableWidget, 
                             QTableWidgetItem, QHeaderView, QPushButton, QLineEdit, 
                             QComboBox, QLabel, QSpinBox, QAbstractItemView, QFrame)
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QColor, QBrush
from core.locales import tr

class EncounterSelectionDialog(QDialog):
    def __init__(self, data_manager, parent=None):
        super().__init__(parent)
        self.dm = data_manager
        self.selected_entities = [] # [(entity_id, count), ...]
        
        self.setWindowTitle("Savaşa Varlık Ekle")
        self.resize(800, 600)
        self.setStyleSheet("""
            QDialog { background-color: #1e1e1e; color: #e0e0e0; }
            QLineEdit, QComboBox, QSpinBox { 
                background-color: #333; color: white; border: 1px solid #555; padding: 5px; 
            }
            QTableWidget { 
                background-color: #252526; gridline-color: #444; color: white; border: none;
            }
            QTableWidget::item:selected { background-color: #007acc; }
            QHeaderView::section { background-color: #333; color: white; padding: 4px; }
            QPushButton { 
                background-color: #0d47a1; color: white; padding: 10px; font-weight: bold; border-radius: 4px; 
            }
            QPushButton:hover { background-color: #1565c0; }
        """)
        
        self.init_ui()
        self.load_data()

    def init_ui(self):
        layout = QVBoxLayout(self)
        
        # --- ÜST FİLTRE ALANI ---
        filter_layout = QHBoxLayout()
        
        self.inp_search = QLineEdit()
        self.inp_search.setPlaceholderText("İsim veya Etiket Ara...")
        self.inp_search.textChanged.connect(self.filter_table)
        
        self.combo_type = QComboBox()
        self.combo_type.addItems(["Tümü", "NPC", "Canavar", "Oyuncu"])
        self.combo_type.currentTextChanged.connect(self.filter_table)
        
        filter_layout.addWidget(QLabel("🔍"))
        filter_layout.addWidget(self.inp_search, 3)
        filter_layout.addWidget(QLabel("Tip:"))
        filter_layout.addWidget(self.combo_type, 1)
        
        layout.addLayout(filter_layout)
        
        # --- ORTA TABLO ALANI ---
        self.table = QTableWidget()
        self.table.setColumnCount(6)
        # Sütunlar: İsim, Tip, HP, AC, Init Bonus, ID(Gizli)
        self.table.setHorizontalHeaderLabels(["İsim", "Tip", "HP", "AC", "Init Bonus", "ID"])
        self.table.hideColumn(5) # ID sütununu gizle
        
        # Tablo Ayarları
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        self.table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.table.setSelectionMode(QAbstractItemView.SelectionMode.ExtendedSelection) # Çoklu Seçim
        self.table.setSortingEnabled(True)
        self.table.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers) # Düzenlenemez
        self.table.doubleClicked.connect(self.add_and_close) # Çift tıklayınca ekle ve kapat
        
        layout.addWidget(self.table)
        
        # --- ALT AKSİYON ALANI ---
        action_layout = QHBoxLayout()
        self.lbl_count = QLabel("Seçilenlerden Kaçar Adet Eklensin:")
        self.spin_count = QSpinBox()
        self.spin_count.setRange(1, 20)
        self.spin_count.setValue(1)
        self.spin_count.setFixedWidth(60)
        
        self.btn_add = QPushButton("✅ Seçilenleri Savaşa Ekle")
        self.btn_add.clicked.connect(self.accept_selection)
        
        action_layout.addStretch()
        action_layout.addWidget(self.lbl_count)
        action_layout.addWidget(self.spin_count)
        action_layout.addWidget(self.btn_add)
        
        layout.addLayout(action_layout)

    def load_data(self):
        self.table.setRowCount(0)
        entities = self.dm.data["entities"]
        
        for eid, data in entities.items():
            etype = data.get("type", "NPC")
            
            # Sadece savaşçı tipleri listele
            if etype not in ["NPC", "Monster", "Canavar", "Player", "Oyuncu"]:
                continue
                
            name = data.get("name", "İsimsiz")
            tags = " ".join(data.get("tags", [])).lower()
            
            # Statları Çek
            c_stats = data.get("combat_stats", {})
            hp = str(c_stats.get("hp", "10"))
            ac = str(c_stats.get("ac", "10"))
            
            # İnisiyatif Bonusu Hesapla
            stats = data.get("stats", {})
            dex = int(stats.get("DEX", 10))
            dex_mod = (dex - 10) // 2
            
            extra_init = int(c_stats.get("initiative") or c_stats.get("init_bonus") or 0)
            total_init_bonus = dex_mod + extra_init
            
            sign = "+" if total_init_bonus >= 0 else ""
            init_str = f"{sign}{total_init_bonus}"
            
            # Tabloya Ekle
            row = self.table.rowCount()
            self.table.insertRow(row)
            
            self.table.setItem(row, 0, QTableWidgetItem(name))
            self.table.setItem(row, 1, QTableWidgetItem(etype))
            
            # Sayısal sıralama için özel item kullanmıyoruz şimdilik, string yeterli
            hp_item = QTableWidgetItem(hp)
            hp_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            self.table.setItem(row, 2, hp_item)
            
            ac_item = QTableWidgetItem(ac)
            ac_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            self.table.setItem(row, 3, ac_item)
            
            init_item = QTableWidgetItem(init_str)
            init_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            # Renklendirme (Yüksek inisiyatif yeşil)
            if total_init_bonus > 0:
                init_item.setForeground(QBrush(QColor("#66bb6a")))
            elif total_init_bonus < 0:
                init_item.setForeground(QBrush(QColor("#ef5350")))
            self.table.setItem(row, 4, init_item)
            
            self.table.setItem(row, 5, QTableWidgetItem(eid))
            
            # Arama için gizli veri sakla (isim + tagler)
            self.table.item(row, 0).setData(Qt.ItemDataRole.UserRole, f"{name.lower()} {tags} {etype.lower()}")

    def filter_table(self):
        search_text = self.inp_search.text().lower()
        filter_type = self.combo_type.currentText()
        
        mapping = {"NPC": ["NPC"], "Canavar": ["Monster", "Canavar"], "Oyuncu": ["Player", "Oyuncu"]}
        allowed_types = mapping.get(filter_type, [])
        
        for row in range(self.table.rowCount()):
            # Gizli veriden (UserRole) arama yap
            row_data = self.table.item(row, 0).data(Qt.ItemDataRole.UserRole)
            row_type = self.table.item(row, 1).text()
            
            match_text = search_text in row_data
            match_type = (filter_type == "Tümü") or (row_type in allowed_types)
            
            self.table.setRowHidden(row, not (match_text and match_type))

    def accept_selection(self):
        """Seçilen satırları topla ve dialogu onayla"""
        selected_rows = self.table.selectionModel().selectedRows()
        
        if not selected_rows:
            return
            
        count = self.spin_count.value()
        
        for index in selected_rows:
            row = index.row()
            eid = self.table.item(row, 5).text()
            # Her bir varlık için "count" kadar ekle
            for _ in range(count):
                self.selected_entities.append(eid)
                
        self.accept()

    def add_and_close(self):
        """Çift tıklayınca sadece o satırdan 1 adet ekle ve kapat"""
        row = self.table.currentRow()
        if row >= 0:
            eid = self.table.item(row, 5).text()
            self.selected_entities.append(eid)
            self.accept()