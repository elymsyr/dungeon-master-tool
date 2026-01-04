from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QTableWidget, QTableWidgetItem, 
                             QHBoxLayout, QPushButton, QHeaderView, QInputDialog, 
                             QMenu, QMessageBox, QFrame, QLineEdit, QFileDialog)
from PyQt6.QtGui import QAction, QColor, QBrush, QCursor
from PyQt6.QtCore import Qt, pyqtSignal
from core.locales import tr
from ui.windows.battle_map_window import BattleMapWindow
import random
import os

# D&D 5e Standart Durumlar
CONDITIONS = [
    "Blinded", "Charmed", "Deafened", "Frightened", "Grappled", "Incapacitated", 
    "Invisible", "Paralyzed", "Petrified", "Poisoned", "Prone", "Restrained", 
    "Stunned", "Unconscious", "Exhaustion"
]

class CombatTracker(QWidget):
    # Veri değiştiğinde (auto-save için) tetiklenen sinyal
    data_changed_signal = pyqtSignal()

    def __init__(self, data_manager):
        super().__init__()
        self.dm = data_manager
        self.current_turn_index = -1
        self.battle_map_window = None 
        
        # Session State Verileri
        self.current_map_path = None # Relative path (assets/...)
        self.current_token_size = 50
        self.token_positions = {} # {eid: (x, y)}
        
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
        self.table.itemChanged.connect(self.on_data_changed)
        layout.addWidget(self.table)

        # KONTROLLER
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

        # Butonlar 1
        btn_layout = QHBoxLayout()
        self.btn_next_turn = QPushButton(tr("BTN_NEXT_TURN"))
        self.btn_next_turn.setStyleSheet("background-color: #fbc02d; color: black; font-weight: bold;")
        self.btn_next_turn.clicked.connect(self.next_turn)
        
        self.btn_battle_map = QPushButton("🗺️ Battle Map")
        self.btn_battle_map.setStyleSheet("background-color: #0277bd; color: white; font-weight: bold;")
        self.btn_battle_map.clicked.connect(self.open_battle_map)

        btn_layout.addWidget(self.btn_next_turn)
        btn_layout.addWidget(self.btn_battle_map)
        layout.addLayout(btn_layout)
        
        # Butonlar 2
        btn_layout2 = QHBoxLayout()
        self.btn_add = QPushButton(tr("BTN_ADD")); self.btn_add.clicked.connect(self.add_combatant_dialog)
        self.btn_add_players = QPushButton(tr("BTN_ADD_PLAYERS")); self.btn_add_players.clicked.connect(self.add_all_players)
        self.btn_roll = QPushButton(tr("BTN_ROLL_INIT")); self.btn_roll.clicked.connect(self.roll_initiatives)
        self.btn_clear_all = QPushButton(tr("BTN_CLEAR_ALL"))
        self.btn_clear_all.clicked.connect(self.clear_tracker)
        self.btn_clear_all.setStyleSheet("color: #ff5252;")
        
        btn_layout2.addWidget(self.btn_add)
        btn_layout2.addWidget(self.btn_add_players)
        btn_layout2.addWidget(self.btn_roll)
        btn_layout2.addWidget(self.btn_clear_all)
        layout.addLayout(btn_layout2)

    # --- BATTLE MAP ENTEGRASYONU ---
    def open_battle_map(self):
        if self.battle_map_window and self.battle_map_window.isVisible():
            self.battle_map_window.raise_()
            self.battle_map_window.activateWindow()
            return

        # Harita Yükleme (Sadece yoksa sor)
        if not self.current_map_path:
            fname, _ = QFileDialog.getOpenFileName(self, "Battle Map Seç", "", "Images (*.png *.jpg *.jpeg)")
            if not fname: return
            
            # --- ÖNEMLİ: Assets klasörüne kopyala ---
            rel_path = self.dm.import_image(fname)
            if rel_path:
                self.current_map_path = rel_path
                self.data_changed_signal.emit()

        self.battle_map_window = BattleMapWindow(self.dm)
        # Sinyalleri Bağla
        self.battle_map_window.token_moved_signal.connect(self.on_token_moved_in_map)
        self.battle_map_window.slider_size.valueChanged.connect(self.on_token_size_changed)
        
        self.battle_map_window.show()
        # force_map_reload=True diyerek resmi yüklemesini sağla
        self.refresh_battle_map(force_map_reload=True)

    def on_token_moved_in_map(self, eid, x, y):
        self.token_positions[eid] = (x, y)
        self.data_changed_signal.emit() # Pozisyon değişince kaydet

    def on_token_size_changed(self, val):
        self.current_token_size = val
        self.data_changed_signal.emit() # Boyut değişince kaydet

    def refresh_battle_map(self, force_map_reload=False):
        if not self.battle_map_window or not self.battle_map_window.isVisible(): return
        
        data = self.get_combat_data_for_map()
        
        # Harita yolu (relative -> full)
        map_full_path = None
        if force_map_reload and self.current_map_path:
            map_full_path = self.dm.get_full_path(self.current_map_path)
        
        self.battle_map_window.update_combat_data(data, self.current_turn_index, map_full_path, self.current_token_size)

    def get_combat_data_for_map(self):
        """Harita penceresine gidecek veriyi hazırlar (Koordinatlarla)"""
        data = []
        for row in range(self.table.rowCount()):
            eid = self.table.item(row, 1).data(Qt.ItemDataRole.UserRole)
            x, y = None, None
            if eid and eid in self.token_positions:
                x, y = self.token_positions[eid]
            
            data.append({
                "name": self.table.item(row, 0).text(),
                "hp": self.table.item(row, 3).text(),
                "eid": eid,
                "x": x, "y": y
            })
        return data

    def on_data_changed(self, item): 
        self.refresh_battle_map()
        self.data_changed_signal.emit()

    # --- SAVAŞ AKIŞI ---
    def next_turn(self):
        count = self.table.rowCount()
        if count == 0: return
        
        self.current_turn_index = (self.current_turn_index + 1) % count
        self.update_highlights()
        self.refresh_battle_map()
        self.data_changed_signal.emit()

    def update_highlights(self):
        for r in range(self.table.rowCount()):
            for c in range(self.table.columnCount()):
                item = self.table.item(r, c)
                if item: item.setBackground(QBrush(QColor(0,0,0,0)))
        
        if 0 <= self.current_turn_index < self.table.rowCount():
            for c in range(self.table.columnCount()):
                item = self.table.item(self.current_turn_index, c)
                if item: item.setBackground(QBrush(QColor(40, 80, 40)))

    def _sort_and_refresh(self):
        self.table.sortItems(1, Qt.SortOrder.DescendingOrder)
        self.current_turn_index = -1 
        self.update_highlights()
        self.refresh_battle_map()
        self.data_changed_signal.emit()

    def clear_tracker(self):
        self.table.setRowCount(0)
        self.current_turn_index = -1
        self.token_positions.clear()
        self.current_map_path = None
        self.refresh_battle_map()
        if self.battle_map_window: self.battle_map_window.set_map_image(None)
        self.data_changed_signal.emit()

    def get_session_state(self):
        """Oturum kaydedilirken çağrılır. Tüm durumu paketler."""
        combatants = []
        for row in range(self.table.rowCount()):
            # HÜCRELERİ GÜVENLİ AL (None Kontrolü)
            item_name = self.table.item(row, 0)
            item_init = self.table.item(row, 1)
            item_ac = self.table.item(row, 2)
            item_hp = self.table.item(row, 3)
            item_cond = self.table.item(row, 4)

            # Eğer kritik hücreler (İsim veya İnisiyatif) henüz oluşmamışsa bu satırı atla
            if item_name is None or item_init is None:
                continue

            eid = item_init.data(Qt.ItemDataRole.UserRole)
            
            # Koordinatları al
            x, y = None, None
            if eid and eid in self.token_positions: 
                x, y = self.token_positions[eid]

            # Veriyi güvenli şekilde oluştur
            combatants.append({
                "name": item_name.text(),
                "init": item_init.text(),
                "ac": item_ac.text() if item_ac else "",
                "hp": item_hp.text() if item_hp else "",
                "cond": item_cond.text() if item_cond else "",
                "eid": eid,
                "bonus": item_name.data(Qt.ItemDataRole.UserRole),
                "x": x, "y": y
            })
            
        return {
            "combatants": combatants,
            "map_path": self.current_map_path, # Relative path kaydedilir
            "token_size": self.current_token_size,
            "turn_index": self.current_turn_index
        }

    def load_session_state(self, state_data):
        self.table.blockSignals(True)
        self.table.setRowCount(0)
        self.token_positions.clear()
        
        combatants = state_data.get("combatants", [])
        self.current_map_path = state_data.get("map_path")
        self.current_token_size = state_data.get("token_size", 50)
        self.current_turn_index = state_data.get("turn_index", -1)
        
        for c in combatants:
            eid = c.get("eid")
            if eid and "x" in c and c["x"] is not None:
                self.token_positions[eid] = (c["x"], c["y"])
            self.add_direct_row(c["name"], c["init"], c["ac"], c["hp"], c["cond"], eid, c.get("bonus", 0))
            
        self.table.blockSignals(False)
        self._sort_and_refresh()
        
        # Harita varsa ve yükleme yapılıyorsa (otomatik)
        if self.current_map_path:
             # Pencereyi açmak kullanıcı deneyimi için iyi olabilir, veya sadece veri hazırda bekler.
             # Kullanıcı 'Devam Et' dediği için açmak mantıklı.
             self.open_battle_map()

    # --- EKLEME VE DİĞER ---
    def add_direct_row(self, name, init, ac, hp, condition, eid, init_bonus=0):
        # Bu metod toplu işlemlerde kullanıldığı için tek başına sinyal yaymaz.
        row = self.table.rowCount(); self.table.insertRow(row)
        item_name = QTableWidgetItem(name); item_name.setData(Qt.ItemDataRole.UserRole, init_bonus); self.table.setItem(row, 0, item_name)
        item_init = QTableWidgetItem(); item_init.setData(Qt.ItemDataRole.DisplayRole, str(init)); item_init.setData(Qt.ItemDataRole.EditRole, int(init) if str(init).isdigit() else 0); item_init.setData(Qt.ItemDataRole.UserRole, eid); self.table.setItem(row, 1, item_init)
        self.table.setItem(row, 2, QTableWidgetItem(str(ac))); self.table.setItem(row, 3, QTableWidgetItem(str(hp)))
        cond_item = QTableWidgetItem(condition); cond_item.setForeground(QBrush(QColor("#ff5252"))) if condition else None; self.table.setItem(row, 4, cond_item)

    def quick_add(self):
        name = self.inp_quick_name.text().strip()
        if not name: return
        self.add_direct_row(name, self.inp_quick_init.text() or str(random.randint(1,20)), "10", self.inp_quick_hp.text() or "10", "", None)
        self.inp_quick_name.clear(); self.inp_quick_init.clear(); self.inp_quick_hp.clear()
        self._sort_and_refresh()

    def add_combatant_dialog(self):
        entities = self.dm.data["entities"]
        items = []; ids = []
        for eid, data in entities.items():
            if data.get("type") in ["NPC", "Canavar", "Oyuncu"]:
                items.append(f"{data['name']} ({data['type']})"); ids.append(eid)
        item, ok = QInputDialog.getItem(self, tr("BTN_ADD"), tr("LBL_NAME"), items, 0, False)
        if ok and item: self.add_row_from_entity(ids[items.index(item)]); self._sort_and_refresh()

    def add_row_from_entity(self, entity_id):
        data = self.dm.data["entities"].get(entity_id)
        if not data: return
        name = data.get("name", "Bilinmeyen")
        hp = data.get("combat_stats", {}).get("hp", "10")
        ac = data.get("combat_stats", {}).get("ac", "10")
        try: dex = int(data.get("stats", {}).get("DEX", 10)); dex_mod = (dex - 10) // 2
        except: dex_mod = 0
        roll = random.randint(1, 20) + dex_mod
        self.add_direct_row(name, roll, ac, hp, "", entity_id, dex_mod)

    def add_all_players(self):
        existing_eids = [self.table.item(row, 1).data(Qt.ItemDataRole.UserRole) for row in range(self.table.rowCount())]
        for eid, data in self.dm.data["entities"].items():
            if data.get("type") == "Oyuncu" and eid not in existing_eids: self.add_row_from_entity(eid)
        self._sort_and_refresh()

    def roll_initiatives(self):
        self.table.blockSignals(True)
        for row in range(self.table.rowCount()):
            item = self.table.item(row, 1); bonus = self.table.item(row, 0).data(Qt.ItemDataRole.UserRole) or 0
            roll = random.randint(1, 20) + bonus
            item.setData(Qt.ItemDataRole.DisplayRole, str(roll)); item.setData(Qt.ItemDataRole.EditRole, roll)
        self.table.blockSignals(False)
        self._sort_and_refresh()

    def open_context_menu(self, position):
        row = self.table.rowAt(position.y()); 
        if row == -1: return
        menu = QMenu()
        cond_menu = menu.addMenu(tr("MENU_ADD_COND"))
        current_cond_text = self.table.item(row, 4).text()
        current_conditions = [c.strip() for c in current_cond_text.split(",") if c.strip()]
        for cond in CONDITIONS:
            action = QAction(cond, self); action.setCheckable(True)
            if any(cond.split(" ")[0] in c for c in current_conditions): action.setChecked(True)
            action.triggered.connect(lambda checked, c=cond, r=row: self.toggle_condition(r, c))
            cond_menu.addAction(action)
        menu.addSeparator()
        del_action = QAction(tr("MENU_REMOVE_COMBAT"), self)
        del_action.triggered.connect(lambda: self.delete_row(row))
        menu.addAction(del_action)
        menu.exec(self.table.viewport().mapToGlobal(position))
        self.refresh_battle_map()

    def toggle_condition(self, row, condition):
        item = self.table.item(row, 4)
        current_list = [c.strip() for c in item.text().split(",") if c.strip()]
        if condition in current_list: current_list.remove(condition)
        else: current_list.append(condition)
        new_text = ", ".join(current_list)
        item.setText(new_text)
        item.setForeground(QBrush(QColor("#ff5252"))) if new_text else item.setForeground(QBrush(QColor("#e0e0e0")))
        self.refresh_battle_map()
        self.data_changed_signal.emit()

    def delete_row(self, row):
        self.table.removeRow(row)
        if self.table.rowCount() > 0:
            if self.current_turn_index >= row:
                self.current_turn_index = max(0, self.current_turn_index - 1)
        else:
            self.current_turn_index = -1
        self.update_highlights()
        self.refresh_battle_map()
        self.data_changed_signal.emit()