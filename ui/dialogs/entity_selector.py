from PyQt6.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QTableWidget, 
                             QTableWidgetItem, QPushButton, QLineEdit, QHeaderView,
                             QAbstractItemView)
from PyQt6.QtCore import Qt
from core.locales import tr

from core.theme_manager import ThemeManager

class EntitySelectorDialog(QDialog):
    def __init__(self, data_manager, parent=None):
        super().__init__(parent)
        self.dm = data_manager
        self.selected_entities = [] # Selected ID list
        
        self.setWindowTitle(tr("TITLE_ADD_COMBAT"))
        self.resize(700, 500)
        p = ThemeManager.get_palette(ThemeManager.get_active_theme() if hasattr(ThemeManager, 'get_active_theme') else "dark")
        self.setStyleSheet(f"background-color: {p.get('ui_bg', '#1e1e1e')}; color: {p.get('ui_text', 'white')};")
        
        self.init_ui()
        self.load_data()

    def init_ui(self):
        layout = QVBoxLayout(self)
        
        # Search
        self.inp_search = QLineEdit()
        self.inp_search.setPlaceholderText(tr("LBL_SEARCH"))
        p = ThemeManager.get_palette(ThemeManager.get_active_theme() if hasattr(ThemeManager, 'get_active_theme') else "dark")
        self.inp_search.setStyleSheet(f"padding: 8px; background-color: {p.get('ui_bg_dark', '#333')}; border: 1px solid {p.get('ui_border', '#555')};")
        self.inp_search.textChanged.connect(self.filter_list)
        layout.addWidget(self.inp_search)
        
        # Table
        self.table = QTableWidget()
        self.table = QTableWidget()
        self.table.setColumnCount(5)
        self.table.setHorizontalHeaderLabels([tr("HEADER_NAME"), tr("LBL_TYPE"), "HP", "AC", tr("HEADER_INIT_BONUS")])
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        self.table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.table.setSelectionMode(QAbstractItemView.SelectionMode.MultiSelection) # MULTI SELECT
        p = ThemeManager.get_palette(ThemeManager.get_active_theme() if hasattr(ThemeManager, 'get_active_theme') else "dark")
        self.table.setStyleSheet(f"""
            QTableWidget {{ background-color: {p.get('ui_bg', '#252526')}; border: 1px solid {p.get('ui_border', '#444')}; gridline-color: {p.get('ui_border', '#444')}; }}
            QTableWidget::item:selected {{ background-color: {p.get('hp_bar_full', '#2e7d32')}; color: white; }}
            QHeaderView::section {{ background-color: {p.get('ui_bg_dark', '#333')}; padding: 4px; border: 1px solid {p.get('ui_border', '#444')}; }}
        """)
        layout.addWidget(self.table)
        
        # Buttons
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
            # List only those who can enter combat
            if etype not in ["NPC", "Monster", "Player"]:
                continue
                
            self.table.insertRow(row)
            
            # Fetch Data
            name = data.get("name", "Unknown")
            c_stats = data.get("combat_stats", {})
            hp = str(c_stats.get("hp", "-"))
            ac = str(c_stats.get("ac", "-"))
            
            # Calculate Initiative Bonus (DEX mod + manual bonus)
            dex = int(data.get("stats", {}).get("DEX", 10))
            dex_mod = (dex - 10) // 2
            extra = int(c_stats.get("initiative") or 0)
            total_bonus = dex_mod + extra
            bonus_str = f"+{total_bonus}" if total_bonus >= 0 else str(total_bonus)
            
            # Write to Table
            item_name = QTableWidgetItem(name)
            item_name.setData(Qt.ItemDataRole.UserRole, eid) # Store ID
            
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