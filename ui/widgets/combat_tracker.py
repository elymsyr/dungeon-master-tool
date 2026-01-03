from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QTableWidget, QTableWidgetItem, 
                             QHBoxLayout, QPushButton, QHeaderView, QInputDialog, 
                             QMenu, QMessageBox)
from PyQt6.QtCore import Qt
import random

class CombatTracker(QWidget):
    def __init__(self, data_manager):
        super().__init__()
        self.dm = data_manager
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout(self)
        
        # TABLO
        self.table = QTableWidget()
        self.table.setColumnCount(5)
        self.table.setHorizontalHeaderLabels(["İsim", "Init", "AC", "HP", "Durum"])
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        self.table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        layout.addWidget(self.table)

        # KONTROLLER
        btn_layout = QHBoxLayout()
        
        self.btn_add = QPushButton("➕ Ekle")
        self.btn_add.clicked.connect(self.add_combatant_dialog)
        
        self.btn_roll = QPushButton("🎲 İnisiyatif At")
        self.btn_roll.clicked.connect(self.roll_initiatives)
        
        self.btn_clear = QPushButton("🗑️ Temizle")
        self.btn_clear.clicked.connect(self.clear_tracker)
        
        btn_layout.addWidget(self.btn_add)
        btn_layout.addWidget(self.btn_roll)
        btn_layout.addWidget(self.btn_clear)
        
        layout.addLayout(btn_layout)

    def add_combatant_dialog(self):
        # Veritabanından varlık seç
        entities = self.dm.data["entities"]
        items = []
        ids = []
        
        # Sadece canlılar
        for eid, data in entities.items():
            if data.get("type") in ["NPC", "Canavar", "Oyuncu"]:
                items.append(f"{data['name']} ({data['type']})")
                ids.append(eid)
        
        item, ok = QInputDialog.getItem(self, "Savaşa Ekle", "Varlık Seç:", items, 0, False)
        if ok and item:
            eid = ids[items.index(item)]
            self.add_row_from_entity(eid)

    def add_row_from_entity(self, entity_id):
        data = self.dm.data["entities"].get(entity_id)
        if not data: return
        
        name = data.get("name", "Bilinmeyen")
        
        # Combat statlarını çek (String gelebilir, temizle)
        try:
            hp_str = data.get("combat_stats", {}).get("hp", "10")
            hp = int(hp_str.split(' ')[0]) # "24 (4d8)" -> 24
        except: hp = 10
            
        try:
            ac_str = data.get("combat_stats", {}).get("ac", "10")
            ac = int(ac_str)
        except: ac = 10
            
        dex_score = int(data.get("stats", {}).get("DEX", 10))
        init_bonus = (dex_score - 10) // 2
        
        self.add_direct_row(name, 0, ac, hp, "", entity_id, init_bonus)

    def add_direct_row(self, name, init, ac, hp, condition, eid, init_bonus=0):
        row = self.table.rowCount()
        self.table.insertRow(row)
        
        self.table.setItem(row, 0, QTableWidgetItem(name))
        self.table.setItem(row, 1, QTableWidgetItem(str(init)))
        self.table.setItem(row, 2, QTableWidgetItem(str(ac)))
        self.table.setItem(row, 3, QTableWidgetItem(str(hp)))
        self.table.setItem(row, 4, QTableWidgetItem(condition))
        
        # Gizli veri olarak bonusu sakla
        self.table.item(row, 0).setData(Qt.ItemDataRole.UserRole, init_bonus)
        self.table.item(row, 1).setData(Qt.ItemDataRole.UserRole, eid) # ID'yi sakla

    def roll_initiatives(self):
        for row in range(self.table.rowCount()):
            # İnisiyatif hücresi
            init_item = self.table.item(row, 1)
            # İsim hücresinde bonus saklı
            bonus = self.table.item(row, 0).data(Qt.ItemDataRole.UserRole) or 0
            
            roll = random.randint(1, 20) + bonus
            init_item.setText(str(roll))
            
        self.sort_by_initiative()

    def sort_by_initiative(self):
        self.table.sortItems(1, Qt.SortOrder.DescendingOrder)

    def clear_tracker(self):
        self.table.setRowCount(0)

    def get_combat_data(self):
        """Kaydetmek için verileri JSON formatında döndürür"""
        data = []
        for row in range(self.table.rowCount()):
            data.append({
                "name": self.table.item(row, 0).text(),
                "init": self.table.item(row, 1).text(),
                "ac": self.table.item(row, 2).text(),
                "hp": self.table.item(row, 3).text(),
                "cond": self.table.item(row, 4).text(),
                "eid": self.table.item(row, 1).data(Qt.ItemDataRole.UserRole),
                "bonus": self.table.item(row, 0).data(Qt.ItemDataRole.UserRole)
            })
        return data

    def load_combat_data(self, combat_list):
        self.table.setRowCount(0)
        for c in combat_list:
            self.add_direct_row(c["name"], c["init"], c["ac"], c["hp"], c["cond"], c.get("eid"), c.get("bonus", 0))