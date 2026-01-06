from PyQt6.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QTableWidget, 
                             QTableWidgetItem, QPushButton, QLineEdit, QHeaderView,
                             QAbstractItemView)
from PyQt6.QtCore import Qt
from core.locales import tr

class EntitySelectorDialog(QDialog):
    def __init__(self, data_manager, parent=None):
        super().__init__(parent)
        self.dm = data_manager
        self.selected_entities = [] # Seçilenlerin ID listesi
        
        self.setWindowTitle("Savaşa Varlık Ekle")
        self.resize(700, 500)
        self.setStyleSheet("background-color: #1e1e1e; color: white;")
        
        self.init_ui()
        self.load_data()

    def init_ui(self):
        layout = QVBoxLayout(self)
        
        # Arama
        self.inp_search = QLineEdit()
        self.inp_search.setPlaceholderText(tr("LBL_SEARCH"))
        self.inp_search.setStyleSheet("padding: 8px; background-color: #333; border: 1px solid #555;")
        self.inp_search.textChanged.connect(self.filter_list)
        layout.addWidget(self.inp_search)
        
        # Tablo
        self.table = QTableWidget()
        self.table.setColumnCount(5)
        self.table.setHorizontalHeaderLabels([tr("HEADER_NAME"), tr("LBL_TYPE"), "HP", "AC", "Init Bonus"])
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        self.table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.table.setSelectionMode(QAbstractItemView.SelectionMode.MultiSelection) # ÇOKLU SEÇİM
        self.table.setStyleSheet("""
            QTableWidget { background-color: #252526; border: 1px solid #444; gridline-color: #444; }
            QTableWidget::item:selected { background-color: #2e7d32; color: white; }
            QHeaderView::section { background-color: #333; padding: 4px; border: 1px solid #444; }
        """)
        layout.addWidget(self.table)
        
        # Butonlar
        btn_layout = QHBoxLayout()
        self.btn_cancel = QPushButton(tr("BTN_CANCEL"))
        self.btn_cancel.clicked.connect(self.reject)
        self.btn_cancel.setStyleSheet("padding: 10px; background-color: #d32f2f; color: white;")
        
        self.btn_add = QPushButton(tr("BTN_ADD"))
        self.btn_add.clicked.connect(self.add_selected)
        self.btn_add.setStyleSheet("padding: 10px; background-color: #388e3c; color: white; font-weight: bold;")
        
        btn_layout.addStretch()
        btn_layout.addWidget(self.btn_cancel)
        btn_layout.addWidget(self.btn_add)
        layout.addLayout(btn_layout)

    def load_data(self):
        self.table.setRowCount(0)
        entities = self.dm.data["entities"]
        
        row = 0
        for eid, data in entities.items():
            etype = data.get("type", "NPC")
            # Sadece savaşa girebilecekleri listele
            if etype not in ["NPC", "Monster", "Player"]:
                continue
                
            self.table.insertRow(row)
            
            # Verileri çek
            name = data.get("name", "Unknown")
            c_stats = data.get("combat_stats", {})
            hp = str(c_stats.get("hp", "-"))
            ac = str(c_stats.get("ac", "-"))
            
            # İnisiyatif Bonusu Hesapla (DEX mod + manuel bonus)
            dex = int(data.get("stats", {}).get("DEX", 10))
            dex_mod = (dex - 10) // 2
            extra = int(c_stats.get("initiative") or 0)
            total_bonus = dex_mod + extra
            bonus_str = f"+{total_bonus}" if total_bonus >= 0 else str(total_bonus)
            
            # Tabloya yaz
            item_name = QTableWidgetItem(name)
            item_name.setData(Qt.ItemDataRole.UserRole, eid) # ID sakla
            
            self.table.setItem(row, 0, item_name)
            self.table.setItem(row, 1, QTableWidgetItem(etype))
            self.table.setItem(row, 2, QTableWidgetItem(hp))
            self.table.setItem(row, 3, QTableWidgetItem(ac))
            self.table.setItem(row, 4, QTableWidgetItem(bonus_str))
            
            row += 1

    def filter_list(self):
        query = self.inp_search.text().lower()
        for i in range(self.table.rowCount()):
            name = self.table.item(i, 0).text().lower()
            if query in name:
                self.table.setRowHidden(i, False)
            else:
                self.table.setRowHidden(i, True)

    def add_selected(self):
        selected_rows = self.table.selectionModel().selectedRows()
        if not selected_rows:
            return
            
        for index in selected_rows:
            row = index.row()
            eid = self.table.item(row, 0).data(Qt.ItemDataRole.UserRole)
            self.selected_entities.append(eid)
            
        self.accept()