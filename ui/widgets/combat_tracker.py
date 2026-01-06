from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QTableWidget, QTableWidgetItem, 
                             QHBoxLayout, QPushButton, QHeaderView, QInputDialog, 
                             QMenu, QMessageBox, QFrame, QLineEdit, QFileDialog, 
                             QDialog, QListWidget, QListWidgetItem, QLabel, 
                             QAbstractItemView, QProgressBar, QSlider, QComboBox)
from PyQt6.QtGui import QAction, QColor, QBrush, QCursor, QIcon, QPixmap
from PyQt6.QtCore import Qt, pyqtSignal, QSize, QUrl
from core.locales import tr
from ui.windows.battle_map_window import BattleMapWindow
from ui.dialogs.encounter_selector import EncounterSelectionDialog
import random
import os
import uuid

# --- YARDIMCI FONKSİYONLAR VE SINIFLAR ---
def clean_stat_value(value, default=10):
    if value is None: return default
    s_val = str(value).strip()
    if not s_val: return default
    try:
        first_part = s_val.split(' ')[0]
        digits = ''.join(filter(str.isdigit, first_part))
        return int(digits) if digits else default
    except: return default

class HpBarWidget(QWidget):
    hpChanged = pyqtSignal(int)
    def __init__(self, current_hp, max_hp):
        super().__init__()
        self.current = int(current_hp)
        self.max_val = int(max_hp) if int(max_hp) > 0 else 1
        
        layout = QHBoxLayout(self); layout.setContentsMargins(0, 2, 0, 2); layout.setSpacing(2)
        
        self.btn_minus = QPushButton("-"); self.btn_minus.setFixedSize(20, 20); self.btn_minus.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_minus.setStyleSheet("QPushButton { background-color: #c62828; color: white; border: none; border-radius: 3px; font-weight: bold; } QPushButton:hover { background-color: #d32f2f; }")
        self.btn_minus.clicked.connect(self.decrease_hp)
        
        self.bar = QProgressBar(); self.bar.setRange(0, self.max_val); self.bar.setValue(self.current); self.bar.setTextVisible(True); self.bar.setFormat(f"%v / {self.max_val}"); self.bar.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.update_color()
        
        self.btn_plus = QPushButton("+"); self.btn_plus.setFixedSize(20, 20); self.btn_plus.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_plus.setStyleSheet("QPushButton { background-color: #2e7d32; color: white; border: none; border-radius: 3px; font-weight: bold; } QPushButton:hover { background-color: #388e3c; }")
        self.btn_plus.clicked.connect(self.increase_hp)
        
        layout.addWidget(self.btn_minus); layout.addWidget(self.bar, 1); layout.addWidget(self.btn_plus)

    def update_color(self):
        ratio = self.current / self.max_val
        if ratio > 0.5: color = "#2e7d32"
        elif ratio > 0.2: color = "#fbc02d"
        else: color = "#c62828"
        self.bar.setStyleSheet(f"QProgressBar::chunk {{ background-color: {color}; }} QProgressBar {{ color: white; border: 1px solid #555; border-radius: 3px; background: rgba(0,0,0,0.3); }}")

    def update_hp(self, new_hp):
        self.current = int(new_hp)
        self.bar.setValue(self.current)
        self.bar.setFormat(f"{self.current} / {self.max_val}")
        self.update_color()
        self.hpChanged.emit(self.current)

    def decrease_hp(self): self.update_hp(self.current - 1)
    def increase_hp(self): self.update_hp(self.current + 1)

CONDITIONS = ["Blinded", "Charmed", "Deafened", "Frightened", "Grappled", "Incapacitated", "Invisible", "Paralyzed", "Petrified", "Poisoned", "Prone", "Restrained", "Stunned", "Unconscious", "Exhaustion"]

class NumericTableWidgetItem(QTableWidgetItem):
    def __lt__(self, other):
        try: return float(self.data(Qt.ItemDataRole.DisplayRole)) < float(other.data(Qt.ItemDataRole.DisplayRole))
        except: return super().__lt__(other)

class MapSelectorDialog(QDialog):
    def __init__(self, assets_path, parent=None):
        super().__init__(parent)
        self.assets_path = assets_path; self.selected_file = None; self.is_new_import = False
        self.setWindowTitle(tr("TITLE_MAP_SELECTOR")); self.setFixedSize(600, 500)
        self.init_ui(); self.load_maps()
    def init_ui(self):
        l = QVBoxLayout(self); lbl = QLabel(tr("LBL_SAVED_MAPS")); lbl.setObjectName("toolbarLabel"); l.addWidget(lbl)
        self.lw = QListWidget(); self.lw.setViewMode(QListWidget.ViewMode.IconMode); self.lw.setIconSize(QSize(150, 150)); self.lw.setResizeMode(QListWidget.ResizeMode.Adjust); self.lw.setSpacing(10); self.lw.setProperty("class", "iconList"); self.lw.itemDoubleClicked.connect(self.select_existing); l.addWidget(self.lw)
        h = QHBoxLayout(); b1 = QPushButton(tr("BTN_IMPORT_NEW_MAP")); b1.setObjectName("successBtn"); b1.clicked.connect(self.select_new)
        b2 = QPushButton(tr("BTN_OPEN_SELECTED_MAP")); b2.setObjectName("primaryBtn"); b2.clicked.connect(self.select_existing)
        h.addWidget(b1); h.addStretch(); h.addWidget(b2); l.addLayout(h)
    def load_maps(self):
        if not os.path.exists(self.assets_path): return
        for f in os.listdir(self.assets_path):
            if f.lower().endswith(('.png', '.jpg', '.jpeg')): self.lw.addItem(QListWidgetItem(QIcon(os.path.join(self.assets_path, f)), f))
    def select_existing(self):
        if self.lw.currentItem(): self.selected_file = self.lw.currentItem().text(); self.accept()
        else: QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_SELECT_MAP_FROM_LIST"))
    def select_new(self): self.is_new_import = True; self.accept()


# --- COMBAT TRACKER (MULTI-ENCOUNTER) ---
class CombatTracker(QWidget):
    data_changed_signal = pyqtSignal()

    def __init__(self, data_manager):
        super().__init__()
        self.dm = data_manager
        self.battle_map_window = None 
        self.loading = False
        
        # Encounter Verileri (Dict of Dicts)
        # { "enc_id": { "name": "...", "combatants": [], "map_path": "...", "round": 1, "turn_index": -1, ... } }
        self.encounters = {}
        self.current_encounter_id = None
        
        # Varsayılan bir encounter oluştur
        self.create_encounter("Default Encounter")
        
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout(self)
        
        # --- ENCOUNTER YÖNETİMİ ---
        enc_layout = QHBoxLayout()
        self.combo_encounters = QComboBox()
        self.combo_encounters.currentIndexChanged.connect(self.switch_encounter)
        self.combo_encounters.setMinimumWidth(200)
        
        # BUTON GENİŞLİKLERİ ARTIRILDI (30 -> 40)
        self.btn_new_enc = QPushButton("➕")
        self.btn_new_enc.setToolTip(tr("TIP_NEW_ENC"))
        self.btn_new_enc.clicked.connect(self.prompt_new_encounter)
        self.btn_new_enc.setFixedWidth(40) 
        
        self.btn_rename_enc = QPushButton("✏️")
        self.btn_rename_enc.setToolTip(tr("TIP_RENAME_ENC"))
        self.btn_rename_enc.clicked.connect(self.rename_encounter)
        self.btn_rename_enc.setFixedWidth(40)
        
        self.btn_del_enc = QPushButton("🗑️")
        self.btn_del_enc.setToolTip(tr("TIP_DEL_ENC"))
        self.btn_del_enc.clicked.connect(self.delete_encounter)
        self.btn_del_enc.setFixedWidth(40)
        self.btn_del_enc.setObjectName("dangerBtn")
        
        enc_layout.addWidget(QLabel(f"{tr('LBL_ENCOUNTER_PREFIX')}"))
        enc_layout.addWidget(self.combo_encounters)
        enc_layout.addWidget(self.btn_new_enc)
        enc_layout.addWidget(self.btn_rename_enc)
        enc_layout.addWidget(self.btn_del_enc)
        layout.addLayout(enc_layout)

        # --- TABLO ---
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

        # --- KONTROLLER ---
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

        # Tur Kontrol ve Harita
        btn_layout = QHBoxLayout()
        self.lbl_round = QLabel(f"{tr('LBL_ROUND_PREFIX')}1")
        self.lbl_round.setObjectName("headerLabel")
        self.lbl_round.setStyleSheet("font-size: 16px; font-weight: bold; margin-right: 10px;")
        
        self.btn_next_turn = QPushButton(tr("BTN_NEXT_TURN"))
        self.btn_next_turn.setObjectName("actionBtn") 
        self.btn_next_turn.clicked.connect(self.next_turn)
        
        self.btn_battle_map = QPushButton(tr("BTN_BATTLE_MAP"))
        self.btn_battle_map.setObjectName("primaryBtn")
        self.btn_battle_map.clicked.connect(self.open_battle_map)

        btn_layout.addWidget(self.lbl_round)
        btn_layout.addWidget(self.btn_next_turn)
        btn_layout.addWidget(self.btn_battle_map)
        layout.addLayout(btn_layout)
        
        # Alt Butonlar
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
        
        self.refresh_ui_from_current_encounter()

    def retranslate_ui(self):
        self.table.setHorizontalHeaderLabels([tr("HEADER_NAME"), tr("HEADER_INIT"), tr("HEADER_AC"), tr("HEADER_HP"), tr("HEADER_COND")])
        self.inp_quick_name.setPlaceholderText(tr("HEADER_NAME"))
        self.btn_quick_add.setText(tr("BTN_QUICK_ADD"))
        self.btn_next_turn.setText(tr("BTN_NEXT_TURN"))
        self.btn_add.setText(tr("BTN_ADD"))
        self.btn_add_players.setText(tr("BTN_ADD_PLAYERS"))
        self.btn_roll.setText(tr("BTN_ROLL_INIT"))
        self.btn_clear_all.setText(tr("BTN_CLEAR_ALL"))
        
        if self.battle_map_window and self.battle_map_window.isVisible():
            self.battle_map_window.retranslate_ui()
            self.refresh_battle_map()

    # --- ENCOUNTER YÖNETİMİ ---
    def create_encounter(self, name):
        eid = str(uuid.uuid4())
        self.encounters[eid] = {
            "id": eid,
            "name": name,
            "combatants": [],
            "map_path": None,
            "token_size": 50,
            "turn_index": -1,
            "round": 1,
            "token_positions": {} # {tid: (x, y)}
        }
        self.current_encounter_id = eid
        return eid

    def prompt_new_encounter(self):
        name, ok = QInputDialog.getText(self, "Yeni Encounter", "Encounter Adı:")
        if ok and name:
            eid = self.create_encounter(name)
            self.combo_encounters.addItem(name, eid)
            self.combo_encounters.setCurrentIndex(self.combo_encounters.count() - 1)

    def rename_encounter(self):
        if not self.current_encounter_id: return
        current_name = self.encounters[self.current_encounter_id]["name"]
        name, ok = QInputDialog.getText(self, tr("TITLE_RENAME_ENC"), tr("LBL_NEW_NAME"), text=current_name)
        if ok and name:
            self.encounters[self.current_encounter_id]["name"] = name
            idx = self.combo_encounters.findData(self.current_encounter_id)
            self.combo_encounters.setItemText(idx, name)
            self.data_changed_signal.emit()

    def delete_encounter(self):
        if len(self.encounters) <= 1:
            QMessageBox.warning(self, tr("MSG_ERROR"), tr("MSG_LAST_ENC_DELETE"))
            return
        
        reply = QMessageBox.question(self, tr("TITLE_DELETE"), tr("MSG_CONFIRM_ENC_DELETE"), QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No)
        if reply == QMessageBox.StandardButton.Yes:
            old_id = self.current_encounter_id
            del self.encounters[old_id]
            
            # Combo'dan sil
            idx = self.combo_encounters.findData(old_id)
            self.combo_encounters.removeItem(idx)
            
            # İlkine geç
            self.switch_encounter(0)
            self.data_changed_signal.emit()

    def switch_encounter(self, index):
        eid = self.combo_encounters.itemData(index)
        if eid and eid in self.encounters:
            # Önce mevcut olanı kaydet (State'i güncelle)
            self._save_current_state_to_memory()
            
            self.current_encounter_id = eid
            self.refresh_ui_from_current_encounter()
            
            # Harita varsa yükle
            if self.battle_map_window:
                self.refresh_battle_map(force_map_reload=True)

    def _save_current_state_to_memory(self):
        """Mevcut tabloyu hafızadaki dict'e yazar"""
        if not self.current_encounter_id: return
        enc = self.encounters[self.current_encounter_id]
        
        # Combatants
        combatants = []
        for row in range(self.table.rowCount()):
            # Hücreleri al
            item_name = self.table.item(row, 0)
            item_init = self.table.item(row, 1)
            item_ac = self.table.item(row, 2)
            item_cond = self.table.item(row, 4)
            
            # --- KRİTİK KONTROL ---
            # Eğer hücrelerden herhangi biri henüz oluşturulmadıysa (None ise), bu satırı atla.
            if not item_name or not item_init: 
                continue

            # Verileri güvenli şekilde al
            tid = item_init.data(Qt.ItemDataRole.UserRole + 1)
            eid = item_init.data(Qt.ItemDataRole.UserRole)
            
            # HP Widget'tan al (Hücre boşsa 0 kabul et)
            hp_widget = self.table.cellWidget(row, 3)
            current_hp_val = hp_widget.current if isinstance(hp_widget, HpBarWidget) else 0
            
            # Pozisyon verisini enc["token_positions"] dan alıyoruz
            x, y = enc["token_positions"].get(tid, (None, None))

            combatants.append({
                "tid": str(tid) if tid else None,
                "eid": str(eid) if eid else None,
                "name": str(item_name.text()),
                "init": str(item_init.text()),
                "ac": str(item_ac.text() if item_ac else ""),
                "hp": str(current_hp_val),
                "cond": str(item_cond.text() if item_cond else ""),
                "bonus": int(item_name.data(Qt.ItemDataRole.UserRole) or 0),
                "x": float(x) if x is not None else None,
                "y": float(y) if y is not None else None
            })
        
        enc["combatants"] = combatants

    def refresh_ui_from_current_encounter(self):
        self.loading = True
        self.table.blockSignals(True)
        self.table.setRowCount(0)
        
        if not self.current_encounter_id: return
        enc = self.encounters[self.current_encounter_id]
        
        self.lbl_round.setText(f"{tr('LBL_ROUND_PREFIX')}{enc.get('round', 1)}")
        
        for c in enc.get("combatants", []):
            tid = c.get("tid")
            if not tid: tid = str(uuid.uuid4())
            # Pozisyonları hafızaya yükle
            if c.get("x") is not None:
                enc["token_positions"][tid] = (float(c["x"]), float(c["y"]))
            
            self.add_direct_row(
                str(c["name"]), str(c["init"]), str(c["ac"]), str(c["hp"]), str(c["cond"]), 
                str(c.get("eid")) if c.get("eid") else None, int(c.get("bonus", 0)), tid
            )
            
        self._sort_and_refresh() # Sıralama ve renkler
        self.table.blockSignals(False)
        self.loading = False

    # --- BATTLE MAP ENTEGRASYONU ---
    def open_battle_map(self):
        if self.battle_map_window and self.battle_map_window.isVisible():
            self.battle_map_window.raise_(); self.battle_map_window.activateWindow(); return
        
        # Harita Seçimi (Eğer yoksa)
        enc = self.encounters[self.current_encounter_id]
        if not enc.get("map_path"):
            assets_path = os.path.join(self.dm.current_campaign_path, "assets")
            if not os.path.exists(assets_path): os.makedirs(assets_path)
            selector = MapSelectorDialog(assets_path, self)
            if selector.exec():
                if selector.is_new_import:
                    fname, _ = QFileDialog.getOpenFileName(self, tr("MSG_SELECT_MAP"), "", "Images (*.png *.jpg *.jpeg)")
                    if fname:
                        rel_path = self.dm.import_image(fname)
                        if rel_path: enc["map_path"] = rel_path; self.data_changed_signal.emit()
                    else: return 
                elif selector.selected_file:
                    enc["map_path"] = os.path.join("assets", selector.selected_file); self.data_changed_signal.emit()
            else: return 

        self.battle_map_window = BattleMapWindow(self.dm)
        self.battle_map_window.token_moved_signal.connect(self.on_token_moved_in_map)
        self.battle_map_window.slider_size.valueChanged.connect(self.on_token_size_changed)
        self.battle_map_window.show()
        self.refresh_battle_map(force_map_reload=True)

    def on_token_moved_in_map(self, tid, x, y):
        # Sadece o anki encounter'ın pozisyonunu güncelle
        if self.current_encounter_id:
            self.encounters[self.current_encounter_id]["token_positions"][tid] = (x, y)
            self.data_changed_signal.emit()

    def on_token_size_changed(self, val):
        if self.current_encounter_id:
            self.encounters[self.current_encounter_id]["token_size"] = val
            self.data_changed_signal.emit()

    def refresh_battle_map(self, force_map_reload=False):
        if not self.battle_map_window or not self.current_encounter_id: return
        
        enc = self.encounters[self.current_encounter_id]
        
        # Hafızayı güncelle (tablodan) ki haritaya doğru gitsin
        self._save_current_state_to_memory()
        
        map_full_path = None
        if (force_map_reload or self.battle_map_window.map_item is None) and enc.get("map_path"):
            map_full_path = self.dm.get_full_path(enc["map_path"])
            
        # Veriyi hazırla
        combatants_data = []
        for c in enc["combatants"]:
            # Type/Attitude hesapla (Entity'den)
            ent_type = "NPC"; attitude = "LBL_ATTR_NEUTRAL"
            if c["eid"] and c["eid"] in self.dm.data["entities"]:
                ent = self.dm.data["entities"][c["eid"]]
                ent_type = ent.get("type", "NPC")
                attitude = ent.get("attributes", {}).get("LBL_ATTITUDE", "LBL_ATTR_NEUTRAL")
                if ent_type == "Monster": attitude = "LBL_ATTR_HOSTILE"
            
            c["type"] = ent_type; c["attitude"] = attitude # Geçici ekle
            combatants_data.append(c)

        self.battle_map_window.update_combat_data(combatants_data, enc["turn_index"], map_full_path, enc["token_size"])

    # --- TABLO İŞLEMLERİ ---
    def add_direct_row(self, name, init, ac, hp, condition, eid, init_bonus=0, tid=None):
        if not tid: tid = str(uuid.uuid4())
        row = self.table.rowCount(); self.table.insertRow(row)
        
        item_name = QTableWidgetItem(name); item_name.setData(Qt.ItemDataRole.UserRole, init_bonus); self.table.setItem(row, 0, item_name)
        
        item_init = NumericTableWidgetItem(str(init)); item_init.setData(Qt.ItemDataRole.UserRole, eid); item_init.setData(Qt.ItemDataRole.UserRole + 1, tid); self.table.setItem(row, 1, item_init)
        
        self.table.setItem(row, 2, NumericTableWidgetItem(str(clean_stat_value(ac))))
        
        cur_hp = clean_stat_value(hp); max_hp = cur_hp
        if eid and self.dm and eid in self.dm.data["entities"]:
            try:
                db_max = clean_stat_value(self.dm.data["entities"][eid].get("combat_stats", {}).get("max_hp"))
                if db_max >= cur_hp: max_hp = db_max
            except: pass
            
        hp_w = HpBarWidget(cur_hp, max_hp)
        hp_w.hpChanged.connect(lambda val, w=hp_w: self.on_widget_hp_changed(w, val))
        self.table.setCellWidget(row, 3, hp_w)
        self.table.setItem(row, 3, NumericTableWidgetItem(str(cur_hp)))
        
        cond_item = QTableWidgetItem(condition)
        if condition: cond_item.setForeground(QBrush(QColor("#ef5350")))
        self.table.setItem(row, 4, cond_item)

    def on_widget_hp_changed(self, widget, new_val):
        index = self.table.indexAt(widget.pos())
        if index.isValid():
            self.table.item(index.row(), 3).setText(str(new_val))
            self._save_current_state_to_memory()
            self.refresh_battle_map()
            self.data_changed_signal.emit()

    def on_cell_double_clicked(self, row, column):
        if column == 3:
            w = self.table.cellWidget(row, 3)
            if isinstance(w, HpBarWidget):
                val, ok = QInputDialog.getInt(self, tr("TITLE_EDIT_HP"), tr("LBL_NEW_HP"), w.current, 0, 9999)
                if ok: w.update_hp(val)

    def on_data_changed(self, item):
        if self.loading: return
        if item.column() == 1: self._sort_and_refresh()
        else: 
            self._save_current_state_to_memory()
            self.refresh_battle_map()
            self.data_changed_signal.emit()

    # --- OYUN AKIŞI ---
    def next_turn(self):
        if not self.current_encounter_id: return
        enc = self.encounters[self.current_encounter_id]
        count = self.table.rowCount()
        if count == 0: return
        
        self.loading = True
        enc["turn_index"] += 1
        if enc["turn_index"] >= count:
            enc["turn_index"] = 0
            enc["round"] += 1
            self.lbl_round.setText(f"{tr('LBL_ROUND_PREFIX')}{enc['round']}")
            
        self.update_highlights()
        self.refresh_battle_map()
        self.loading = False
        self.data_changed_signal.emit()

    def update_highlights(self):
        if not self.current_encounter_id: return
        idx = self.encounters[self.current_encounter_id]["turn_index"]
        
        self.table.blockSignals(True)
        for r in range(self.table.rowCount()):
            for c in range(self.table.columnCount()):
                it = self.table.item(r, c)
                if it: it.setBackground(QBrush(Qt.BrushStyle.NoBrush))
        
        if 0 <= idx < self.table.rowCount():
            for c in range(self.table.columnCount()):
                it = self.table.item(idx, c)
                if it: it.setBackground(QBrush(QColor(100, 149, 237, 100)))
        self.table.blockSignals(False)

    def _sort_and_refresh(self):
        # Aktif sıradaki kişiyi kaybetmemek için ID ile takip et
        if not self.current_encounter_id: return
        enc = self.encounters[self.current_encounter_id]
        
        current_tid = None
        if 0 <= enc["turn_index"] < self.table.rowCount():
            it = self.table.item(enc["turn_index"], 1)
            if it: current_tid = it.data(Qt.ItemDataRole.UserRole + 1)

        self.table.blockSignals(True)
        self.table.sortItems(1, Qt.SortOrder.DescendingOrder)
        self.table.blockSignals(False)

        if current_tid:
            for r in range(self.table.rowCount()):
                it = self.table.item(r, 1)
                if it and it.data(Qt.ItemDataRole.UserRole + 1) == current_tid:
                    enc["turn_index"] = r
                    break
        
        self.update_highlights()
        self.refresh_battle_map()
        if not self.loading: self.data_changed_signal.emit()

    def clear_tracker(self):
        if not self.current_encounter_id: return
        enc = self.encounters[self.current_encounter_id]
        
        self.table.setRowCount(0)
        enc["combatants"] = []
        enc["token_positions"] = {}
        enc["turn_index"] = -1
        enc["round"] = 1
        enc["map_path"] = None # Haritayı da silmek ister mi? Genelde hayır ama clear all dediği için silebiliriz.
        
        self.lbl_round.setText(f"{tr('LBL_ROUND_PREFIX')}1")
        self.refresh_battle_map(force_map_reload=True) # Harita silinsin
        if not self.loading: self.data_changed_signal.emit()

    # --- SAVE / LOAD SİSTEMİ (SESSION TAB İÇİN) ---
    def get_session_state(self):
        """Tüm encounterları paketler ve SessionTab'a gönderir"""
        self._save_current_state_to_memory() # Son hali kaydet
        
        # JSON'a uygun hale getir (basit tipler)
        return {
            "encounters": self.encounters,
            "current_encounter_id": self.current_encounter_id
        }

    def load_session_state(self, state_data):
        """SessionTab'dan gelen veriyi yükler"""
        self.loading = True
        self.combo_encounters.blockSignals(True)
        self.combo_encounters.clear()
        
        # Yeni yapı mı eski yapı mı?
        if "encounters" in state_data:
            # Yeni yapı (Multi-Encounter)
            self.encounters = state_data["encounters"]
            target_id = state_data.get("current_encounter_id")
        else:
            # Eski yapı (Tek Encounter) -> Dönüştür
            # Eski veriyi "Default Encounter" olarak içeri al
            combatants = state_data.get("combatants", [])
            eid = str(uuid.uuid4())
            self.encounters = {
                eid: {
                    "id": eid,
                    "name": "Encounter",
                    "combatants": combatants,
                    "map_path": state_data.get("map_path"),
                    "token_size": state_data.get("token_size", 50),
                    "turn_index": state_data.get("turn_index", -1),
                    "round": state_data.get("round", 1),
                    "token_positions": {} # Eski yapıda bu veriyi combatants içinden ayıklamak gerekirdi, şimdilik boş
                }
            }
            # Eski combatantlarda x,y varsa token_positions'a taşı
            for c in combatants:
                tid = c.get("tid") or str(uuid.uuid4())
                if c.get("x") is not None:
                    self.encounters[eid]["token_positions"][tid] = (c["x"], c["y"])
            target_id = eid

        # Combo'yu doldur
        for eid, enc in self.encounters.items():
            self.combo_encounters.addItem(enc["name"], eid)
        
        # Seçimi yap
        if target_id and target_id in self.encounters:
            idx = self.combo_encounters.findData(target_id)
            self.combo_encounters.setCurrentIndex(idx)
            self.current_encounter_id = target_id
        elif len(self.encounters) > 0:
            self.combo_encounters.setCurrentIndex(0)
            self.current_encounter_id = self.combo_encounters.itemData(0)
            
        self.refresh_ui_from_current_encounter()
        self.combo_encounters.blockSignals(False)
        self.loading = False

    def load_combat_data(self, combatants_list):
        """Eski (çok eski) liste formatı desteği"""
        self.load_session_state({"combatants": combatants_list})

    # ... (Diğer: quick_add, add_combatant_dialog, add_row_from_entity vb. aynı) ...
    def quick_add(self):
        name = self.inp_quick_name.text().strip(); 
        if not name: return
        self.add_direct_row(name, self.inp_quick_init.text() or str(random.randint(1,20)), "10", self.inp_quick_hp.text() or "10", "", None)
        self.inp_quick_name.clear(); self.inp_quick_init.clear(); self.inp_quick_hp.clear()
        self._sort_and_refresh()

    def add_combatant_dialog(self):
        dialog = EncounterSelectionDialog(self.dm, self)
        if dialog.exec():
            for eid in dialog.selected_entities: self.add_row_from_entity(eid)
            self._sort_and_refresh()

    def add_row_from_entity(self, entity_id):
        data = self.dm.data["entities"].get(entity_id)
        if not data: return
        name = data.get("name", tr("NAME_UNKNOWN"))
        hp = data.get("combat_stats", {}).get("hp", "10")
        ac = data.get("combat_stats", {}).get("ac", "10")
        bonus_data = self.calculate_entity_initiative_bonus(data)
        total_bonus = bonus_data["total"]
        die_roll = random.randint(1, 20)
        self.add_direct_row(name, die_roll + total_bonus, ac, hp, "", entity_id, total_bonus)
    
    def calculate_entity_initiative_bonus(self, data):
        try: dex = int(data.get("stats", {}).get("DEX", 10)); dex_mod = (dex - 10) // 2
        except: dex_mod = 0
        try: c_stats = data.get("combat_stats", {}); extra = clean_stat_value(c_stats.get("initiative") or c_stats.get("init_bonus"), 0)
        except: extra = 0
        return {"dex_mod": dex_mod, "extra": extra, "total": dex_mod + extra}

    def add_all_players(self):
        entities = self.dm.data["entities"]
        existing_eids = [self.table.item(row, 1).data(Qt.ItemDataRole.UserRole) for row in range(self.table.rowCount())]
        for eid, data in entities.items():
            if data.get("type") == "Player" and eid not in existing_eids: self.add_row_from_entity(eid)
        self._sort_and_refresh()

    def roll_initiatives(self):
        self.table.blockSignals(True)
        for row in range(self.table.rowCount()):
            item_name = self.table.item(row, 0); item_init = self.table.item(row, 1)
            if not item_name or not item_init: continue
            eid = item_init.data(Qt.ItemDataRole.UserRole)
            bonus = item_name.data(Qt.ItemDataRole.UserRole) or 0
            if eid and eid in self.dm.data["entities"]:
                ent_data = self.dm.data["entities"][eid]
                bonus = self.calculate_entity_initiative_bonus(ent_data)["total"]
                item_name.setData(Qt.ItemDataRole.UserRole, bonus)
            item_init.setText(str(random.randint(1, 20) + bonus))
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
        # Turn index güncellemesi
        if self.current_encounter_id:
            enc = self.encounters[self.current_encounter_id]
            if self.table.rowCount() > 0:
                if enc["turn_index"] >= row: enc["turn_index"] = max(0, enc["turn_index"] - 1)
            else: enc["turn_index"] = -1
        
        self.update_highlights()
        self.refresh_battle_map()
        self.data_changed_signal.emit()