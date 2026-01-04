from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QTableWidget, QTableWidgetItem, 
                             QHBoxLayout, QPushButton, QHeaderView, QInputDialog, 
                             QMenu, QMessageBox, QFrame)
from PyQt6.QtGui import QAction, QColor, QBrush, QCursor
from PyQt6.QtCore import Qt
from core.locales import tr
import random

# D&D 5e Standart Durumlar
CONDITIONS = [
    "Blinded (Kör)", "Charmed (Büyülenmiş)", "Deafened (Sağır)", 
    "Frightened (Korkmuş)", "Grappled (Tutulmuş)", "Incapacitated (Etkisiz)", 
    "Invisible (Görünmez)", "Paralyzed (Felç)", "Petrified (Taşlaşmış)", 
    "Poisoned (Zehirlenmiş)", "Prone (Yatmış)", "Restrained (Bağlı)", 
    "Stunned (Sersemlemiş)", "Unconscious (Baygın)", "Exhaustion (Yorgunluk)"
]

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
        self.table.setHorizontalHeaderLabels([tr("HEADER_NAME"), tr("HEADER_INIT"), tr("HEADER_AC"), tr("HEADER_HP"), tr("HEADER_COND")])
        
        # Sütun ayarları
        header = self.table.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch) # İsim geniş
        header.setSectionResizeMode(1, QHeaderView.ResizeMode.ResizeToContents) # Init dar
        header.setSectionResizeMode(2, QHeaderView.ResizeMode.ResizeToContents) # AC dar
        header.setSectionResizeMode(3, QHeaderView.ResizeMode.ResizeToContents) # HP dar
        header.setSectionResizeMode(4, QHeaderView.ResizeMode.Stretch) # Durum geniş
        
        self.table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        
        # Sağ Tık Menüsü Etkinleştirme
        self.table.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.table.customContextMenuRequested.connect(self.open_context_menu)
        
        layout.addWidget(self.table)

        # KONTROLLER
        btn_layout = QHBoxLayout()
        
        self.btn_add = QPushButton(tr("BTN_ADD"))
        self.btn_add.clicked.connect(self.add_combatant_dialog)
        
        self.btn_roll = QPushButton(tr("BTN_ROLL_INIT"))
        self.btn_roll.clicked.connect(self.roll_initiatives)
        
        self.btn_clear = QPushButton(tr("BTN_CLEAR"))
        self.btn_clear.clicked.connect(self.clear_tracker)
        
        btn_layout.addWidget(self.btn_add)
        btn_layout.addWidget(self.btn_roll)
        btn_layout.addWidget(self.btn_clear)
        
        layout.addLayout(btn_layout)

    def open_context_menu(self, position):
        """Satıra sağ tıklayınca açılan menü"""
        row = self.table.rowAt(position.y())
        if row == -1: return # Boşluğa tıkladıysa çık

        menu = QMenu()
        menu.setStyleSheet("QMenu { background-color: #333; color: white; border: 1px solid #555; } QMenu::item:selected { background-color: #007acc; }")
        
        # Durum Ekleme Alt Menüsü
        cond_menu = menu.addMenu(tr("MENU_ADD_COND"))
        
        # Mevcut durumları al
        current_cond_text = self.table.item(row, 4).text()
        current_conditions = [c.strip() for c in current_cond_text.split(",") if c.strip()]
        
        for cond in CONDITIONS:
            action = QAction(cond, self)
            action.setCheckable(True)
            # Eğer zaten varsa işaretle
            if any(cond.split(" ")[0] in c for c in current_conditions): 
                action.setChecked(True)
                
            action.triggered.connect(lambda checked, c=cond, r=row: self.toggle_condition(r, c))
            cond_menu.addAction(action)

        menu.addSeparator()
        
        # Silme Aksiyonu
        del_action = QAction(tr("MENU_REMOVE_COMBAT"), self)
        del_action.triggered.connect(lambda: self.table.removeRow(row))
        menu.addAction(del_action)
        
        menu.exec(self.table.viewport().mapToGlobal(position))

    def toggle_condition(self, row, condition):
        """Durumu ekler veya varsa siler"""
        item = self.table.item(row, 4)
        current_text = item.text()
        current_list = [c.strip() for c in current_text.split(",") if c.strip()]
        
        cond_short = condition.split(" ")[0] # Sadece İngilizce ismini kontrol için kullanabiliriz ama tam isim daha iyi
        
        # Basit kontrol: Tam metin listede var mı?
        if condition in current_list:
            current_list.remove(condition)
        else:
            current_list.append(condition)
            
        new_text = ", ".join(current_list)
        item.setText(new_text)
        
        # Görsel İpucu: Eğer durum varsa satırı hafif kırmızı yap
        if new_text:
            item.setForeground(QBrush(QColor("#ff5252")))
        else:
            item.setForeground(QBrush(QColor("#e0e0e0")))

    def add_combatant_dialog(self):
        entities = self.dm.data["entities"]
        items = []
        ids = []
        
        for eid, data in entities.items():
            if data.get("type") in ["NPC", "Canavar", "Oyuncu"]:
                items.append(f"{data['name']} ({data['type']})")
                ids.append(eid)
        
        item, ok = QInputDialog.getItem(self, tr("BTN_ADD"), tr("LBL_NAME"), items, 0, False)
        if ok and item:
            eid = ids[items.index(item)]
            self.add_row_from_entity(eid)

    def add_row_from_entity(self, entity_id):
        data = self.dm.data["entities"].get(entity_id)
        if not data: return
        
        name = data.get("name", "Bilinmeyen")
        try:
            hp_str = data.get("combat_stats", {}).get("hp", "10")
            hp = hp_str.split(' ')[0] # Sadece sayıyı al
        except: hp = "10"
            
        try: ac = str(data.get("combat_stats", {}).get("ac", "10"))
        except: ac = "10"
            
        try:
            dex = int(data.get("stats", {}).get("DEX", 10))
            init_bonus = (dex - 10) // 2
        except: init_bonus = 0
        
        self.add_direct_row(name, 0, ac, hp, "", entity_id, init_bonus)

    def add_direct_row(self, name, init, ac, hp, condition, eid, init_bonus=0):
        row = self.table.rowCount()
        self.table.insertRow(row)
        
        self.table.setItem(row, 0, QTableWidgetItem(name))
        self.table.setItem(row, 1, QTableWidgetItem(str(init)))
        self.table.setItem(row, 2, QTableWidgetItem(str(ac)))
        self.table.setItem(row, 3, QTableWidgetItem(str(hp)))
        
        cond_item = QTableWidgetItem(condition)
        if condition: cond_item.setForeground(QBrush(QColor("#ff5252")))
        self.table.setItem(row, 4, cond_item)
        
        # Gizli veriler
        self.table.item(row, 0).setData(Qt.ItemDataRole.UserRole, init_bonus)
        self.table.item(row, 1).setData(Qt.ItemDataRole.UserRole, eid)

    def roll_initiatives(self):
        for row in range(self.table.rowCount()):
            item = self.table.item(row, 1)
            bonus = self.table.item(row, 0).data(Qt.ItemDataRole.UserRole) or 0
            roll = random.randint(1, 20) + bonus
            item.setText(str(roll))
        self.table.sortItems(1, Qt.SortOrder.DescendingOrder)

    def clear_tracker(self):
        self.table.setRowCount(0)

    def get_combat_data(self):
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