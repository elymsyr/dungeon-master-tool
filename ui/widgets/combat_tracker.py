from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QTableWidget, QTableWidgetItem, 
                             QHBoxLayout, QPushButton, QHeaderView, QInputDialog, 
                             QMenu, QMessageBox, QFrame, QLineEdit, QFileDialog, 
                             QDialog, QListWidget, QListWidgetItem, QLabel, 
                             QAbstractItemView, QProgressBar, QSlider)
from PyQt6.QtGui import QAction, QColor, QBrush, QCursor, QIcon, QPixmap
from PyQt6.QtCore import Qt, pyqtSignal, QSize, QUrl
from core.locales import tr
from ui.windows.battle_map_window import BattleMapWindow
from ui.dialogs.encounter_selector import EncounterSelectionDialog
import random
import os
import uuid

# --- HP BAR WIDGET (Tablo İçin) ---
class HpBarWidget(QWidget):
    def __init__(self, current_hp, max_hp):
        super().__init__()
        self.current = int(current_hp) if str(current_hp).isdigit() else 10
        self.max_val = int(max_hp) if str(max_hp).isdigit() else 10
        if self.max_val == 0: self.max_val = 1 
        
        layout = QHBoxLayout(self)
        layout.setContentsMargins(2, 2, 2, 2)
        
        self.bar = QProgressBar()
        self.bar.setRange(0, self.max_val)
        self.bar.setValue(self.current)
        self.bar.setTextVisible(True)
        self.bar.setFormat(f"%v / {self.max_val}") 
        self.bar.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        self.update_color()
        layout.addWidget(self.bar)

    def update_color(self):
        ratio = self.current / self.max_val
        if ratio > 0.5:
            color = "#2e7d32" # Yeşil
        elif ratio > 0.2:
            color = "#fbc02d" # Sarı
        else:
            color = "#c62828" # Kırmızı
            
        # Chunk rengi mecburen stil ile verilir, ancak arka plan QSS'den gelebilir.
        # Background-color'ı transparent yaparak temanın tablo rengini almasını sağlıyoruz.
        self.bar.setStyleSheet(f"""
            QProgressBar::chunk {{ background-color: {color}; }}
            QProgressBar {{ color: white; border: 1px solid #555; border-radius: 3px; background: rgba(0,0,0,0.3); }}
        """)

    def update_hp(self, new_hp):
        self.current = int(new_hp)
        self.bar.setValue(self.current)
        self.bar.setFormat(f"{self.current} / {self.max_val}")
        self.update_color()

# D&D 5e Standart Durumlar
CONDITIONS = [
    "Blinded", "Charmed", "Deafened", "Frightened", "Grappled", "Incapacitated", 
    "Invisible", "Paralyzed", "Petrified", "Poisoned", "Prone", "Restrained", 
    "Stunned", "Unconscious", "Exhaustion"
]

class NumericTableWidgetItem(QTableWidgetItem):
    def __lt__(self, other):
        try:
            d1 = self.data(Qt.ItemDataRole.DisplayRole)
            d2 = other.data(Qt.ItemDataRole.DisplayRole)
            return float(d1) < float(d2)
        except (ValueError, TypeError, AttributeError):
            return super().__lt__(other)

# --- HARİTA SEÇİM DİYALOĞU ---
class MapSelectorDialog(QDialog):
    def __init__(self, assets_path, parent=None):
        super().__init__(parent)
        self.assets_path = assets_path
        self.selected_file = None 
        self.is_new_import = False 
        
        self.setWindowTitle(tr("TITLE_MAP_SELECTOR"))
        self.setFixedSize(600, 500)
        # QSS'den stil alacak, hardcoded stil kaldırıldı.
        
        self.init_ui()
        self.load_maps()

    def init_ui(self):
        layout = QVBoxLayout(self)
        
        lbl = QLabel(tr("LBL_SAVED_MAPS"))
        lbl.setObjectName("toolbarLabel") # Başlık stili
        layout.addWidget(lbl)
        
        # Resim Listesi
        self.list_widget = QListWidget()
        self.list_widget.setViewMode(QListWidget.ViewMode.IconMode)
        self.list_widget.setIconSize(QSize(150, 150))
        self.list_widget.setResizeMode(QListWidget.ResizeMode.Adjust)
        self.list_widget.setSpacing(10)
        # "iconList" sınıfı ile tema dosyasından stil alabilir
        self.list_widget.setProperty("class", "iconList")
        
        self.list_widget.itemDoubleClicked.connect(self.select_existing)
        layout.addWidget(self.list_widget)
        
        # Butonlar
        btn_layout = QHBoxLayout()
        
        self.btn_import = QPushButton(tr("BTN_IMPORT_NEW_MAP"))
        self.btn_import.setObjectName("successBtn")
        self.btn_import.clicked.connect(self.select_new)
        
        self.btn_select = QPushButton(tr("BTN_OPEN_SELECTED_MAP"))
        self.btn_select.setObjectName("primaryBtn")
        self.btn_select.clicked.connect(self.select_existing)
        
        btn_layout.addWidget(self.btn_import)
        btn_layout.addStretch()
        btn_layout.addWidget(self.btn_select)
        
        layout.addLayout(btn_layout)

    def retranslate_ui(self):
        self.setWindowTitle(tr("TITLE_MAP_SELECTOR"))
        self.btn_import.setText(tr("BTN_IMPORT_NEW_MAP"))
        self.btn_select.setText(tr("BTN_OPEN_SELECTED_MAP"))

    def load_maps(self):
        if not os.path.exists(self.assets_path):
            return
            
        valid_extensions = {".png", ".jpg", ".jpeg", ".bmp"}
        files = [f for f in os.listdir(self.assets_path) 
                 if os.path.splitext(f)[1].lower() in valid_extensions]
        
        for f in files:
            full_path = os.path.join(self.assets_path, f)
            icon = QIcon(full_path)
            item = QListWidgetItem(icon, f)
            item.setData(Qt.ItemDataRole.UserRole, f)
            self.list_widget.addItem(item)

    def select_existing(self):
        current_item = self.list_widget.currentItem()
        if current_item:
            self.selected_file = current_item.data(Qt.ItemDataRole.UserRole)
            self.accept()
        else:
            QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_SELECT_MAP_FROM_LIST"))

    def select_new(self):
        self.is_new_import = True
        self.accept()


# --- COMBAT TRACKER ANA SINIF ---
class CombatTracker(QWidget):
    data_changed_signal = pyqtSignal()

    def __init__(self, data_manager):
        super().__init__()
        self.dm = data_manager
        self.current_turn_index = -1
        self.battle_map_window = None 
        
        # Session State Verileri
        self.current_map_path = None
        self.current_token_size = 50
        self.token_positions = {} 
        self.loading = False
        
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
        self.table.cellDoubleClicked.connect(self.on_cell_double_clicked)
        self.table.setSortingEnabled(False)
        
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
        # Sıradaki butonu için özel stil ID'si veya QSS
        self.btn_next_turn.setObjectName("actionBtn") 
        self.btn_next_turn.clicked.connect(self.next_turn)
        
        self.btn_battle_map = QPushButton("🗺️ Battle Map")
        self.btn_battle_map.setObjectName("primaryBtn")
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
        self.btn_clear_all.setObjectName("dangerBtn")
        
        btn_layout2.addWidget(self.btn_add)
        btn_layout2.addWidget(self.btn_add_players)
        btn_layout2.addWidget(self.btn_roll)
        btn_layout2.addWidget(self.btn_clear_all)
        layout.addLayout(btn_layout2)

    def retranslate_ui(self):
        self.table.setHorizontalHeaderLabels([tr("HEADER_NAME"), tr("HEADER_INIT"), tr("HEADER_AC"), tr("HEADER_HP"), tr("HEADER_COND")])
        self.inp_quick_name.setPlaceholderText(tr("HEADER_NAME"))
        self.inp_quick_init.setPlaceholderText(tr("LBL_INIT"))
        self.inp_quick_hp.setPlaceholderText(tr("LBL_HP"))
        self.btn_quick_add.setText(tr("BTN_QUICK_ADD"))
        self.btn_next_turn.setText(tr("BTN_NEXT_TURN"))
        self.btn_add.setText(tr("BTN_ADD"))
        self.btn_add_players.setText(tr("BTN_ADD_PLAYERS"))
        self.btn_roll.setText(tr("BTN_ROLL_INIT"))
        self.btn_clear_all.setText(tr("BTN_CLEAR_ALL"))
        
        if self.battle_map_window and self.battle_map_window.isVisible():
            self.battle_map_window.retranslate_ui()
            self.refresh_battle_map()

    # --- BATTLE MAP ENTEGRASYONU ---
    def open_battle_map(self):
        if self.battle_map_window and self.battle_map_window.isVisible():
            self.battle_map_window.raise_()
            self.battle_map_window.activateWindow()
            return

        force_reload = False
        
        if not self.current_map_path:
            assets_path = os.path.join(self.dm.current_campaign_path, "assets")
            if not os.path.exists(assets_path):
                os.makedirs(assets_path)
            
            selector = MapSelectorDialog(assets_path, self)
            
            if selector.exec():
                if selector.is_new_import:
                    fname, _ = QFileDialog.getOpenFileName(self, tr("MSG_SELECT_MAP"), "", "Images (*.png *.jpg *.jpeg)")
                    if fname:
                        rel_path = self.dm.import_image(fname)
                        if rel_path:
                            self.current_map_path = rel_path
                            force_reload = True
                            self.data_changed_signal.emit()
                    else:
                        return 
                elif selector.selected_file:
                    self.current_map_path = os.path.join("assets", selector.selected_file)
                    force_reload = True
                    self.data_changed_signal.emit()
            else:
                return 

        self.battle_map_window = BattleMapWindow(self.dm)
        self.battle_map_window.token_moved_signal.connect(self.on_token_moved_in_map)
        self.battle_map_window.slider_size.valueChanged.connect(self.on_token_size_changed)
        
        self.battle_map_window.show()
        self.refresh_battle_map(force_map_reload=force_reload)

    def on_token_moved_in_map(self, tid, x, y):
        self.token_positions[tid] = (x, y)
        self.data_changed_signal.emit()

    def on_token_size_changed(self, val):
        self.current_token_size = val
        self.data_changed_signal.emit()

    def refresh_battle_map(self, force_map_reload=False):
        if not self.battle_map_window: return
        
        data = self.get_combat_data_for_map()
        
        map_full_path = None
        if (force_map_reload or self.battle_map_window.map_item is None) and self.current_map_path:
            map_full_path = self.dm.get_full_path(self.current_map_path)
        
        self.battle_map_window.update_combat_data(data, self.current_turn_index, map_full_path, self.current_token_size)

    def get_combat_data_for_map(self):
        data = []
        for row in range(self.table.rowCount()):
            item_name = self.table.item(row, 0)
            item_init = self.table.item(row, 1)
            item_ac = self.table.item(row, 2)
            item_hp = self.table.item(row, 3)
            
            if not all([item_name, item_init, item_ac, item_hp]):
                continue
            
            tid = item_init.data(Qt.ItemDataRole.UserRole + 1)
            eid = item_init.data(Qt.ItemDataRole.UserRole)
            
            x, y = None, None
            if tid and tid in self.token_positions:
                x, y = self.token_positions[tid]
            elif eid and eid in self.token_positions:
                x, y = self.token_positions.pop(eid)
                self.token_positions[tid] = (x, y)
            
            ent_type = "NPC"
            attitude = "LBL_ATTR_NEUTRAL"
            if eid and eid in self.dm.data["entities"]:
                ent = self.dm.data["entities"][eid]
                ent_type = ent.get("type", "NPC")
                attitude = ent.get("attributes", {}).get("LBL_ATTITUDE", "LBL_ATTR_NEUTRAL")
                if ent_type == "Monster":
                    attitude = "LBL_ATTR_HOSTILE"
            
            data.append({
                "tid": tid,
                "eid": eid,
                "name": item_name.text(),
                "hp": item_hp.text(),
                "type": ent_type,
                "attitude": attitude,
                "x": x, "y": y
            })
        
        return data

    def on_data_changed(self, item): 
        if self.loading: return
        if item.column() == 1: 
            self._sort_and_refresh()
        else:
            self.refresh_battle_map()
            self.data_changed_signal.emit()

    # --- SAVAŞ AKIŞI ---
    def next_turn(self):
        count = self.table.rowCount()
        if count == 0: return
        self.loading = True
        self.current_turn_index = (self.current_turn_index + 1) % count
        self.update_highlights()
        self.refresh_battle_map()
        self.loading = False
        self.data_changed_signal.emit()

    def update_highlights(self):
        # QTableWidget arka planlarını temizle veya ayarla
        # Burada sadece aktif satırı vurguluyoruz.
        # Temalar için bu kısmı minimumda tutuyoruz veya özel Property ekleyebiliriz.
        self.table.blockSignals(True)
        for r in range(self.table.rowCount()):
            for c in range(self.table.columnCount()):
                item = self.table.item(r, c)
                if item: 
                    # Varsayılan (transparent)
                    item.setBackground(QBrush(Qt.BrushStyle.NoBrush))
        
        if 0 <= self.current_turn_index < self.table.rowCount():
            for c in range(self.table.columnCount()):
                item = self.table.item(self.current_turn_index, c)
                if item: 
                    # Aktif satır rengi - Bunu da QSS'e taşımak zor olduğu için 
                    # (Hücre bazlı style yok) hafif bir renk veriyoruz.
                    # Ancak ideal olan QSS selection-color kullanmaktır.
                    # Görünürlük için hafif bir yeşil/mavi tint veriyoruz.
                    item.setBackground(QBrush(QColor(40, 90, 120, 100)))
        
        self.table.blockSignals(False)

    def _sort_and_refresh(self):
        current_tid = None
        if 0 <= self.current_turn_index < self.table.rowCount():
            item_init = self.table.item(self.current_turn_index, 1)
            if item_init: current_tid = item_init.data(Qt.ItemDataRole.UserRole + 1)
            if not current_tid:
                item_name = self.table.item(self.current_turn_index, 0)
                if item_name: current_tid = item_name.text()

        self.table.blockSignals(True)
        self.table.sortItems(1, Qt.SortOrder.DescendingOrder)
        self.table.blockSignals(False)

        if current_tid is not None:
            for row in range(self.table.rowCount()):
                item_init = self.table.item(row, 1)
                item_name = self.table.item(row, 0)
                if (item_init and item_init.data(Qt.ItemDataRole.UserRole + 1) == current_tid) or \
                   (item_name and item_name.text() == current_tid):
                    self.current_turn_index = row
                    break
        
        self.update_highlights()
        self.refresh_battle_map()
        if not self.loading:
            self.data_changed_signal.emit()

    def clear_tracker(self):
        self.table.setRowCount(0)
        self.current_turn_index = -1
        self.token_positions.clear()
        self.current_map_path = None
        self.refresh_battle_map()
        if self.battle_map_window: self.battle_map_window.set_map_image(None)
        if not self.loading:
            self.data_changed_signal.emit()

    # --- SAVE / LOAD SİSTEMİ ---
    def get_session_state(self):
        combatants = []
        for row in range(self.table.rowCount()):
            item_name = self.table.item(row, 0)
            item_init = self.table.item(row, 1)
            item_ac = self.table.item(row, 2)
            item_hp = self.table.item(row, 3)
            item_cond = self.table.item(row, 4)

            if item_name is None or item_init is None: continue

            tid = item_init.data(Qt.ItemDataRole.UserRole + 1)
            eid = item_init.data(Qt.ItemDataRole.UserRole)
            
            x, y = self.token_positions.get(tid, (None, None))
            if x is None and eid in self.token_positions: x, y = self.token_positions[eid]

            combatants.append({
                "tid": str(tid) if tid else None,
                "eid": str(eid) if eid else None,
                "name": str(item_name.text()),
                "init": str(item_init.text()),
                "ac": str(item_ac.text() if item_ac else ""),
                "hp": str(item_hp.text() if item_hp else ""),
                "cond": str(item_cond.text() if item_cond else ""),
                "bonus": int(item_name.data(Qt.ItemDataRole.UserRole) or 0),
                "x": float(x) if x is not None else None,
                "y": float(y) if y is not None else None
            })
            
        return {
            "combatants": combatants,
            "map_path": str(self.current_map_path) if self.current_map_path else None, 
            "token_size": int(self.current_token_size),
            "turn_index": int(self.current_turn_index)
        }

    def load_combat_data(self, combatants_list):
        self.load_session_state({"combatants": combatants_list})

    def load_session_state(self, state_data):
        if not state_data: return
        self.loading = True
        self.table.blockSignals(True)
        self.table.setRowCount(0)
        self.token_positions.clear()
        
        combatants = state_data.get("combatants", [])
        self.current_map_path = state_data.get("map_path")
        self.current_token_size = int(state_data.get("token_size", 50))
        self.current_turn_index = int(state_data.get("turn_index", -1))
        
        for c in combatants:
            tid = c.get("tid")
            eid = c.get("eid")
            if not tid: tid = str(uuid.uuid4())
            
            if c.get("x") is not None:
                self.token_positions[tid] = (float(c["x"]), float(c["y"]))
            
            self.add_direct_row(
                str(c["name"]), 
                str(c["init"]), 
                str(c["ac"]), 
                str(c["hp"]), 
                str(c["cond"]), 
                str(eid) if eid else None, 
                int(c.get("bonus", 0)),
                tid
            )
            
        self.table.blockSignals(False)
        self._sort_and_refresh()
        
        if self.current_map_path:
             self.open_battle_map()
             
        self.loading = False

    def on_cell_double_clicked(self, row, column):
        if column == 3:
            widget = self.table.cellWidget(row, 3)
            if isinstance(widget, HpBarWidget):
                current = widget.current
                val, ok = QInputDialog.getInt(self, "HP Düzenle", "Yeni HP:", current, 0, 9999)
                if ok:
                    widget.update_hp(val)
                    self.table.item(row, 3).setText(str(val))
                    self.refresh_battle_map()
                    self.data_changed_signal.emit()

    # --- HELPER METHODS ---
    def add_direct_row(self, name, init, ac, hp, condition, eid, init_bonus=0, tid=None):
        if not tid:
            tid = str(uuid.uuid4())
        
        row = self.table.rowCount()
        self.table.insertRow(row)
        
        item_name = QTableWidgetItem(name)
        item_name.setData(Qt.ItemDataRole.UserRole, init_bonus)
        self.table.setItem(row, 0, item_name)
        
        item_init = NumericTableWidgetItem(str(init))
        item_init.setData(Qt.ItemDataRole.UserRole, eid)
        item_init.setData(Qt.ItemDataRole.UserRole + 1, tid)
        self.table.setItem(row, 1, item_init)
        
        self.table.setItem(row, 2, NumericTableWidgetItem(str(ac)))
        
        try:
            current_hp_int = int(str(hp).strip())
        except ValueError:
            current_hp_int = 10
            
        max_hp_int = current_hp_int
        
        if eid and self.dm and eid in self.dm.data["entities"]:
            try:
                ent_data = self.dm.data["entities"][eid]
                c_stats = ent_data.get("combat_stats", {})
                raw_max = str(c_stats.get("max_hp", ""))
                
                parts = raw_max.split(" ")
                if parts and parts[0].isdigit():
                    db_max = int(parts[0])
                    if db_max >= current_hp_int:
                        max_hp_int = db_max
            except Exception:
                pass 

        hp_widget = HpBarWidget(current_hp_int, max_hp_int)
        self.table.setCellWidget(row, 3, hp_widget)
        
        dummy_hp_item = NumericTableWidgetItem(str(current_hp_int))
        self.table.setItem(row, 3, dummy_hp_item)
        
        cond_item = QTableWidgetItem(condition)
        # Durum varsa kırmızı renk ver (veya tema sınıfı ata)
        if condition:
            cond_item.setForeground(QBrush(QColor("#ef5350")))
        self.table.setItem(row, 4, cond_item)

    def quick_add(self):
        name = self.inp_quick_name.text().strip(); 
        if not name: return
        self.add_direct_row(name, self.inp_quick_init.text() or str(random.randint(1,20)), "10", self.inp_quick_hp.text() or "10", "", None)
        self.inp_quick_name.clear(); self.inp_quick_init.clear(); self.inp_quick_hp.clear()
        self._sort_and_refresh()

    def add_combatant_dialog(self):
        dialog = EncounterSelectionDialog(self.dm, self)
        if dialog.exec():
            for eid in dialog.selected_entities:
                self.add_row_from_entity(eid)
            self._sort_and_refresh()

    def add_row_from_entity(self, entity_id):
        data = self.dm.data["entities"].get(entity_id)
        if not data: return
        name = data.get("name", "Bilinmeyen")
        hp = data.get("combat_stats", {}).get("hp", "10")
        ac = data.get("combat_stats", {}).get("ac", "10")
        
        bonus_data = self.calculate_entity_initiative_bonus(data)
        total_bonus = bonus_data["total"]
        
        die_roll = random.randint(1, 20)
        total_init = die_roll + total_bonus
        
        self.add_direct_row(name, total_init, ac, hp, "", entity_id, total_bonus)
    
    def calculate_entity_initiative_bonus(self, data):
        try:
            dex = int(data.get("stats", {}).get("DEX", 10))
            dex_mod = (dex - 10) // 2
        except:
            dex_mod = 0
            
        try:
            c_stats = data.get("combat_stats", {})
            extra_init = c_stats.get("initiative") or c_stats.get("init_bonus") or 0
            extra_init = int(extra_init)
        except:
            extra_init = 0
            
        return {
            "dex_mod": dex_mod,
            "extra": extra_init,
            "total": dex_mod + extra_init
        }

    def add_all_players(self):
        entities = self.dm.data["entities"]
        existing_eids = [self.table.item(row, 1).data(Qt.ItemDataRole.UserRole) for row in range(self.table.rowCount())]
        for eid, data in entities.items():
            if data.get("type") == "Player" and eid not in existing_eids: self.add_row_from_entity(eid)
        self._sort_and_refresh()

    def roll_initiatives(self):
        self.table.blockSignals(True)
        rolls = []
        for row in range(self.table.rowCount()):
            item_name = self.table.item(row, 0)
            item_init = self.table.item(row, 1)
            if not item_name or not item_init: continue
            
            name = item_name.text()
            eid = item_init.data(Qt.ItemDataRole.UserRole)
            
            bonus = item_name.data(Qt.ItemDataRole.UserRole) or 0
            if eid and eid in self.dm.data["entities"]:
                ent_data = self.dm.data["entities"][eid]
                bonus_data = self.calculate_entity_initiative_bonus(ent_data)
                bonus = bonus_data["total"]
                item_name.setData(Qt.ItemDataRole.UserRole, bonus)
            
            die_roll = random.randint(1, 20)
            total = die_roll + bonus
            
            item_init.setText(str(total))
            rolls.append(f"{name}: {total}")
            
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
        item.setForeground(QBrush(QColor("#ef5350"))) if new_text else item.setForeground(QBrush(Qt.BrushStyle.NoBrush))
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