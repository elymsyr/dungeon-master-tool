from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QTableWidget, QTableWidgetItem, 
                             QHBoxLayout, QPushButton, QHeaderView, QInputDialog, 
                             QMenu, QMessageBox, QFrame, QLineEdit)
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
        self.current_turn_index = -1 # Sıra kimde
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout(self)
        
        # TABLO
        self.table = QTableWidget()
        self.table.setColumnCount(5)
        self.table.setHorizontalHeaderLabels([tr("HEADER_NAME"), tr("HEADER_INIT"), tr("HEADER_AC"), tr("HEADER_HP"), tr("HEADER_COND")])
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        self.table.horizontalHeader().setSectionResizeMode(4, QHeaderView.ResizeMode.Stretch)
        self.table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self.table.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.table.customContextMenuRequested.connect(self.open_context_menu)
        layout.addWidget(self.table)

        # --- KONTROLLER ---
        
        # Hızlı Ekleme Paneli
        quick_layout = QHBoxLayout()
        self.inp_quick_name = QLineEdit(); self.inp_quick_name.setPlaceholderText(tr("HEADER_NAME"))
        self.inp_quick_init = QLineEdit(); self.inp_quick_init.setPlaceholderText(tr("LBL_INIT")); self.inp_quick_init.setMaximumWidth(50)
        self.inp_quick_hp = QLineEdit(); self.inp_quick_hp.setPlaceholderText(tr("LBL_HP")); self.inp_quick_hp.setMaximumWidth(50)
        self.btn_quick_add = QPushButton(tr("BTN_QUICK_ADD")); self.btn_quick_add.clicked.connect(self.quick_add)
        
        quick_layout.addWidget(self.inp_quick_name, 3)
        quick_layout.addWidget(self.inp_quick_init, 1)
        quick_layout.addWidget(self.inp_quick_hp, 1)
        quick_layout.addWidget(self.btn_quick_add, 1)
        layout.addLayout(quick_layout)

        # Butonlar
        btn_layout = QHBoxLayout()
        
        self.btn_next_turn = QPushButton(tr("BTN_NEXT_TURN"))
        self.btn_next_turn.setStyleSheet("background-color: #fbc02d; color: black; font-weight: bold;")
        self.btn_next_turn.clicked.connect(self.next_turn)
        
        self.btn_add = QPushButton(tr("BTN_ADD"))
        self.btn_add.clicked.connect(self.add_combatant_dialog)
        
        self.btn_roll = QPushButton(tr("BTN_ROLL_INIT"))
        self.btn_roll.clicked.connect(self.roll_initiatives)
        
        self.btn_clear = QPushButton(tr("BTN_CLEAR_COMBAT"))
        self.btn_clear.clicked.connect(self.clear_tracker)
        
        btn_layout.addWidget(self.btn_next_turn)
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

    def quick_add(self):
        name = self.inp_quick_name.text().strip()
        if not name: return
        
        init = self.inp_quick_init.text().strip() or str(random.randint(1,20))
        hp = self.inp_quick_hp.text().strip() or "10"
        
        self.add_direct_row(name, init, "10", hp, "", None)
        self.inp_quick_name.clear(); self.inp_quick_init.clear(); self.inp_quick_hp.clear()
        self._sort_and_refresh()

    def next_turn(self):
        count = self.table.rowCount()
        if count == 0: return
        
        self.current_turn_index += 1
        if self.current_turn_index >= count:
            self.current_turn_index = 0
            
        self.update_highlights()

    def update_highlights(self):
        for r in range(self.table.rowCount()):
            # Temizle
            for c in range(self.table.columnCount()):
                item = self.table.item(r, c)
                if item: item.setBackground(QBrush(QColor(0,0,0,0))) # Transparent
        
        # Aktif satırı boya
        if 0 <= self.current_turn_index < self.table.rowCount():
            for c in range(self.table.columnCount()):
                item = self.table.item(self.current_turn_index, c)
                if item: item.setBackground(QBrush(QColor(40, 80, 40))) # Koyu Yeşil

    def _sort_and_refresh(self):
        # Init'e göre sırala (Text olduğu için int'e çevirip sıralamak lazım ama basitçe şimdilik TableWidget sort kullanalım)
        # Doğru sıralama için Init sütunu dolu olmalı.
        self.table.sortItems(1, Qt.SortOrder.DescendingOrder)
        self.current_turn_index = -1 
        self.update_highlights()

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
            self._sort_and_refresh()

    def add_row_from_entity(self, entity_id):
        data = self.dm.data["entities"].get(entity_id)
        if not data: return
        
        name = data.get("name", "Bilinmeyen")
        try:
            hp_str = data.get("combat_stats", {}).get("hp", "10")
            hp = hp_str.split(' ')[0] 
        except: hp = "10"
            
        try: ac = str(data.get("combat_stats", {}).get("ac", "10"))
        except: ac = "10"
            
        try:
            dex = int(data.get("stats", {}).get("DEX", 10))
            dex_mod = (dex - 10) // 2
        except: dex_mod = 0
        
        # YENİ: Varsa özel initiative bonusunu kullan, yoksa DEX mod kullan
        custom_init_str = data.get("combat_stats", {}).get("initiative", "")
        if custom_init_str and (custom_init_str.lstrip("-").isdigit()):
            init_bonus = int(custom_init_str)
        else:
            init_bonus = dex_mod
        
        # Otomatik zar at
        roll = random.randint(1, 20) + init_bonus
        
        self.add_direct_row(name, roll, ac, hp, "", entity_id, init_bonus)

    def add_direct_row(self, name, init, ac, hp, condition, eid, init_bonus=0):
        row = self.table.rowCount()
        self.table.insertRow(row)
        
        # İsim
        item_name = QTableWidgetItem(name)
        item_name.setData(Qt.ItemDataRole.UserRole, init_bonus) # Bonus sakla
        self.table.setItem(row, 0, item_name)
        
        # Init (Sıralama için 0-pad gerekebilir ama şimdilik düz yazı)
        # Doğru sorting için: setData(DisplayRole, str), setData(EditRole, int) yapılabilir mi?
        # Basitçe:
        item_init = QTableWidgetItem()
        item_init.setData(Qt.ItemDataRole.DisplayRole, str(init))
        item_init.setData(Qt.ItemDataRole.EditRole, int(init) if str(init).isdigit() else 0)
        item_init.setData(Qt.ItemDataRole.UserRole, eid) # EID sakla
        self.table.setItem(row, 1, item_init)
        
        self.table.setItem(row, 2, QTableWidgetItem(str(ac)))
        self.table.setItem(row, 3, QTableWidgetItem(str(hp)))
        
        cond_item = QTableWidgetItem(condition)
        if condition: cond_item.setForeground(QBrush(QColor("#ff5252")))
        self.table.setItem(row, 4, cond_item)

    def roll_initiatives(self):
        for row in range(self.table.rowCount()):
            item = self.table.item(row, 1)
            # Bonus'u isim satırından alıyorduk
            bonus = self.table.item(row, 0).data(Qt.ItemDataRole.UserRole) or 0
            
            roll = random.randint(1, 20) + bonus
            
            item.setData(Qt.ItemDataRole.DisplayRole, str(roll))
            item.setData(Qt.ItemDataRole.EditRole, roll)
            
        self._sort_and_refresh()

    def clear_tracker(self):
        self.table.setRowCount(0)
        self.current_turn_index = -1

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
        self._sort_and_refresh()