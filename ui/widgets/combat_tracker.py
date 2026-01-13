from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QTableWidget, QTableWidgetItem, 
                             QHBoxLayout, QPushButton, QHeaderView, QInputDialog, 
                             QMenu, QMessageBox, QFrame, QLineEdit, QFileDialog, 
                             QDialog, QListWidget, QListWidgetItem, QLabel, 
                             QAbstractItemView, QProgressBar, QSlider, QComboBox, QScrollArea)
from PyQt6.QtGui import QAction, QColor, QBrush, QCursor, QIcon, QPixmap, QPainter, QPainterPath
from PyQt6.QtCore import Qt, pyqtSignal, QSize, QUrl, QRect
from core.locales import tr
from ui.windows.battle_map_window import BattleMapWindow
from ui.dialogs.encounter_selector import EncounterSelectionDialog
import random
import os
import uuid

# --- YARDIMCILAR ---
def clean_stat_value(value, default=10):
    if value is None: return default
    s_val = str(value).strip()
    if not s_val: return default
    try:
        first_part = s_val.split(' ')[0]
        digits = ''.join(filter(str.isdigit, first_part))
        return int(digits) if digits else default
    except: return default

class ConditionIcon(QWidget):
    removed = pyqtSignal(str) 

    def __init__(self, name, icon_path, duration=0, max_duration=0):
        super().__init__()
        self.name = name; self.icon_path = icon_path; self.duration = int(duration); self.max_duration = int(max_duration)
        self.setFixedSize(24, 24); self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setToolTip(f"{name} ({self.duration}/{self.max_duration} Turns)")

    def paintEvent(self, event):
        painter = QPainter(self); painter.setRenderHint(QPainter.RenderHint.Antialiasing); path = QPainterPath(); path.addEllipse(1, 1, 22, 22); painter.setClipPath(path)
        if self.icon_path and os.path.exists(self.icon_path): painter.drawPixmap(0, 0, 24, 24, QPixmap(self.icon_path))
        else:
            painter.setBrush(QBrush(QColor("#5c6bc0"))); painter.drawRect(0, 0, 24, 24); painter.setPen(Qt.GlobalColor.white)
            font = painter.font(); font.setPixelSize(10); font.setBold(True); painter.setFont(font); painter.drawText(QRect(0, 0, 24, 24), Qt.AlignmentFlag.AlignCenter, self.name[:2].upper())
        if self.max_duration > 0:
            painter.setClipping(False); painter.setBrush(QBrush(QColor(0, 0, 0, 200))); painter.setPen(Qt.PenStyle.NoPen); painter.drawRoundedRect(0, 14, 24, 10, 2, 2)
            painter.setPen(Qt.GlobalColor.white); font = painter.font(); font.setPixelSize(8); font.setBold(True); painter.setFont(font); painter.drawText(QRect(0, 14, 24, 10), Qt.AlignmentFlag.AlignCenter, f"{self.duration}")

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.RightButton:
            menu = QMenu(self); del_act = QAction("❌ Kaldır", self); del_act.triggered.connect(lambda: self.removed.emit(self.name)); menu.addAction(del_act); menu.exec(event.globalPos())

class ConditionsWidget(QWidget):
    conditionsChanged = pyqtSignal(); clicked = pyqtSignal()
    def __init__(self, parent=None):
        super().__init__(parent); self.layout = QHBoxLayout(self); self.layout.setContentsMargins(2, 2, 2, 2); self.layout.setSpacing(2); self.layout.addStretch(); self.active_conditions = []; self.setCursor(Qt.CursorShape.PointingHandCursor)
    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            if not isinstance(self.childAt(event.pos()), ConditionIcon): self.clicked.emit()
        super().mousePressEvent(event)
    def set_conditions(self, conditions_list):
        while self.layout.count() > 1: 
            item = self.layout.takeAt(0)
            if item.widget(): item.widget().deleteLater()
        self.active_conditions = conditions_list
        for cond in conditions_list:
            icon_widget = ConditionIcon(cond["name"], cond.get("icon"), cond.get("duration"), cond.get("max_duration"))
            icon_widget.removed.connect(self.remove_condition)
            self.layout.insertWidget(self.layout.count() - 1, icon_widget)
    def add_condition(self, name, icon_path, max_turns):
        for c in self.active_conditions:
            if c["name"] == name: c["duration"] = max_turns; c["max_duration"] = max_turns; self.set_conditions(self.active_conditions); self.conditionsChanged.emit(); return
        self.active_conditions.append({"name": name, "icon": icon_path, "duration": max_turns, "max_duration": max_turns}); self.set_conditions(self.active_conditions); self.conditionsChanged.emit()
    def remove_condition(self, name):
        self.active_conditions = [c for c in self.active_conditions if c["name"] != name]; self.set_conditions(self.active_conditions); self.conditionsChanged.emit()
    def tick_conditions(self):
        remaining = []
        for c in self.active_conditions:
            if c["max_duration"] > 0:
                c["duration"] -= 1; 
                if c["duration"] > 0: remaining.append(c)
            else: remaining.append(c)
        self.active_conditions = remaining; self.set_conditions(self.active_conditions); self.conditionsChanged.emit()

class HpBarWidget(QWidget):
    hpChanged = pyqtSignal(int)
    def __init__(self, current_hp, max_hp):
        super().__init__(); self.current = int(current_hp); self.max_val = int(max_hp) if int(max_hp) > 0 else 1
        l = QHBoxLayout(self); l.setContentsMargins(0, 2, 0, 2); l.setSpacing(2)
        b_m = QPushButton("-"); b_m.setFixedSize(20, 20); b_m.setCursor(Qt.CursorShape.PointingHandCursor); b_m.setStyleSheet("QPushButton { background-color: #c62828; color: white; border: none; border-radius: 3px; font-weight: bold; } QPushButton:hover { background-color: #d32f2f; }"); b_m.clicked.connect(self.decrease_hp)
        self.bar = QProgressBar(); self.bar.setRange(0, self.max_val); self.bar.setValue(self.current); self.bar.setTextVisible(True); self.bar.setFormat(f"%v / {self.max_val}"); self.bar.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.update_color()
        b_p = QPushButton("+"); b_p.setFixedSize(20, 20); b_p.setCursor(Qt.CursorShape.PointingHandCursor); b_p.setStyleSheet("QPushButton { background-color: #2e7d32; color: white; border: none; border-radius: 3px; font-weight: bold; } QPushButton:hover { background-color: #388e3c; }"); b_p.clicked.connect(self.increase_hp)
        l.addWidget(b_m); l.addWidget(self.bar, 1); l.addWidget(b_p)
    def update_color(self):
        r = self.current / self.max_val if self.max_val > 0 else 0
        c = "#2e7d32" if r > 0.5 else "#fbc02d" if r > 0.2 else "#c62828"
        self.bar.setStyleSheet(f"QProgressBar::chunk {{ background-color: {c}; }} QProgressBar {{ color: white; border: 1px solid #555; border-radius: 3px; background: rgba(0,0,0,0.3); }}")
    def update_hp(self, new_hp): self.current = int(new_hp); self.bar.setValue(self.current); self.bar.setFormat(f"{self.current} / {self.max_val}"); self.update_color(); self.hpChanged.emit(self.current)
    def decrease_hp(self): self.update_hp(self.current - 1)
    def increase_hp(self): self.update_hp(self.current + 1)

CONDITIONS = ["Blinded", "Charmed", "Deafened", "Frightened", "Grappled", "Incapacitated", "Invisible", "Paralyzed", "Petrified", "Poisoned", "Prone", "Restrained", "Stunned", "Unconscious", "Exhaustion"]

class NumericTableWidgetItem(QTableWidgetItem):
    def __lt__(self, other):
        try: return float(self.data(Qt.ItemDataRole.DisplayRole)) < float(other.data(Qt.ItemDataRole.DisplayRole))
        except: return super().__lt__(other)

# --- MAP SEÇİCİ (GÜNCELLENDİ: BATTLEMAP DESTEĞİ) ---
class MapSelectorDialog(QDialog):
    def __init__(self, data_manager, parent=None):
        super().__init__(parent)
        self.dm = data_manager
        self.selected_file = None
        self.is_new_import = False
        
        self.setWindowTitle(tr("TITLE_MAP_SELECTOR"))
        self.setFixedSize(650, 550)
        
        self.init_ui()
        self.load_locations()

    def init_ui(self):
        l = QVBoxLayout(self)
        
        lbl = QLabel(tr("LBL_SAVED_MAPS")) # "Kayıtlı Haritalar (Locations)"
        lbl.setObjectName("toolbarLabel")
        l.addWidget(lbl)
        
        self.lw = QListWidget()
        self.lw.setViewMode(QListWidget.ViewMode.IconMode)
        self.lw.setIconSize(QSize(160, 160))
        self.lw.setResizeMode(QListWidget.ResizeMode.Adjust)
        self.lw.setSpacing(10)
        self.lw.setProperty("class", "iconList")
        self.lw.itemDoubleClicked.connect(self.select_existing)
        l.addWidget(self.lw)
        
        h = QHBoxLayout()
        # "Import New Map" seçeneği (Manuel dosya seçimi için)
        b1 = QPushButton(tr("BTN_IMPORT_NEW_MAP"))
        b1.setObjectName("successBtn")
        b1.clicked.connect(self.select_new)
        
        b2 = QPushButton(tr("BTN_OPEN_SELECTED_MAP"))
        b2.setObjectName("primaryBtn")
        b2.clicked.connect(self.select_existing)
        
        h.addWidget(b1)
        h.addStretch()
        h.addWidget(b2)
        l.addLayout(h)

    def load_locations(self):
        """Veritabanındaki 'Location' türündeki varlıkların BATTLEMAP resimlerini listeler."""
        self.lw.clear()
        
        for eid, ent in self.dm.data["entities"].items():
            if ent.get("type") == "Location":
                loc_name = ent.get("name", "Unknown Location")
                
                # Sadece 'battlemaps' listesini al
                battlemaps = ent.get("battlemaps", [])
                
                # Eğer battlemap yoksa, ana resmi fallback olarak kullanabiliriz (opsiyonel)
                # Ama istenen "battlemap part" olduğu için sadece onları listeleyelim.
                # Kullanıcı kolaylığı için, eğer hiç battlemap yoksa ve ana resim varsa onu ekleyelim.
                if not battlemaps and ent.get("image_path"):
                    battlemaps = [ent["image_path"]]
                elif not battlemaps and ent.get("images"):
                    battlemaps = [ent["images"][0]]

                if not battlemaps:
                    continue

                for i, img_path in enumerate(battlemaps):
                    if not img_path: continue
                    
                    full_path = self.dm.get_full_path(img_path)
                    if not full_path or not os.path.exists(full_path): continue
                    
                    # İsimlendirme
                    display_name = loc_name
                    if len(battlemaps) > 1:
                        display_name = f"{loc_name} ({i+1})"
                    
                    pix = QPixmap(full_path).scaled(160, 160, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
                    icon = QIcon(pix)
                    
                    item = QListWidgetItem(icon, display_name)
                    item.setData(Qt.ItemDataRole.UserRole, img_path)
                    item.setToolTip(f"{loc_name} - Battlemap {i+1}")
                    self.lw.addItem(item)

    def select_existing(self):
        current = self.lw.currentItem()
        if not current:
            QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_SELECT_MAP_FROM_LIST"))
            return
            
        img_path = current.data(Qt.ItemDataRole.UserRole)
        
        if not img_path:
            QMessageBox.warning(self, tr("MSG_WARNING"), "Dosya yolu hatası.")
            return
            
        self.selected_file = img_path
        self.accept()

    def select_new(self):
        self.is_new_import = True
        self.accept()

# --- COMBAT TRACKER ---
class CombatTracker(QWidget):
    data_changed_signal = pyqtSignal()

    def __init__(self, data_manager):
        super().__init__()
        self.dm = data_manager; self.battle_map_window = None; self.loading = False; self.encounters = {}; self.current_encounter_id = None
        self.fog_save_handler = None 
        self.create_encounter("Default Encounter"); self.init_ui()

    def set_fog_save_handler(self, handler):
        self.fog_save_handler = handler

    def init_ui(self):
        layout = QVBoxLayout(self)
        enc_layout = QHBoxLayout()
        self.combo_encounters = QComboBox(); self.combo_encounters.currentIndexChanged.connect(self.switch_encounter); self.combo_encounters.setMinimumWidth(200)
        self.btn_new_enc = QPushButton("➕"); self.btn_new_enc.setFixedWidth(40); self.btn_new_enc.setToolTip(tr("TIP_NEW_ENC")); self.btn_new_enc.clicked.connect(self.prompt_new_encounter)
        self.btn_rename_enc = QPushButton("✏️"); self.btn_rename_enc.setFixedWidth(40); self.btn_rename_enc.setToolTip(tr("TIP_RENAME_ENC")); self.btn_rename_enc.clicked.connect(self.rename_encounter)
        self.btn_del_enc = QPushButton("🗑️"); self.btn_del_enc.setFixedWidth(40); self.btn_del_enc.setToolTip(tr("TIP_DEL_ENC")); self.btn_del_enc.clicked.connect(self.delete_encounter); self.btn_del_enc.setObjectName("dangerBtn")
        enc_layout.addWidget(QLabel(tr("LBL_ENCOUNTER_PREFIX"))); enc_layout.addWidget(self.combo_encounters); enc_layout.addWidget(self.btn_new_enc); enc_layout.addWidget(self.btn_rename_enc); enc_layout.addWidget(self.btn_del_enc)
        layout.addLayout(enc_layout)

        self.table = QTableWidget(); self.table.setColumnCount(5); self.table.setHorizontalHeaderLabels([tr("HEADER_NAME"), tr("HEADER_INIT"), tr("HEADER_AC"), tr("HEADER_HP"), tr("HEADER_COND")])
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch); self.table.horizontalHeader().setSectionResizeMode(4, QHeaderView.ResizeMode.Stretch)
        self.table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows); self.table.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.table.customContextMenuRequested.connect(self.open_context_menu); self.table.itemChanged.connect(self.on_data_changed); self.table.cellDoubleClicked.connect(self.on_cell_double_clicked); self.table.setSortingEnabled(False)
        layout.addWidget(self.table)

        q_lo = QHBoxLayout()
        self.inp_quick_name = QLineEdit(); self.inp_quick_name.setPlaceholderText(tr("HEADER_NAME"))
        self.inp_quick_init = QLineEdit(); self.inp_quick_init.setPlaceholderText(tr("LBL_INIT")); self.inp_quick_init.setMaximumWidth(50)
        self.inp_quick_hp = QLineEdit(); self.inp_quick_hp.setPlaceholderText(tr("LBL_HP")); self.inp_quick_hp.setMaximumWidth(50)
        self.btn_quick_add = QPushButton(tr("BTN_QUICK_ADD")); self.btn_quick_add.clicked.connect(self.quick_add)
        q_lo.addWidget(self.inp_quick_name, 3); q_lo.addWidget(self.inp_quick_init, 1); q_lo.addWidget(self.inp_quick_hp, 1); q_lo.addWidget(self.btn_quick_add, 1)
        layout.addLayout(q_lo)

        btn_layout = QHBoxLayout()
        self.lbl_round = QLabel(f"{tr('LBL_ROUND_PREFIX')}1"); self.lbl_round.setObjectName("headerLabel"); self.lbl_round.setStyleSheet("font-size: 16px; font-weight: bold; margin-right: 10px;")
        self.btn_next_turn = QPushButton(tr("BTN_NEXT_TURN")); self.btn_next_turn.setObjectName("actionBtn"); self.btn_next_turn.clicked.connect(self.next_turn)
        self.btn_battle_map = QPushButton(tr("BTN_BATTLE_MAP")); self.btn_battle_map.setObjectName("primaryBtn"); self.btn_battle_map.clicked.connect(self.open_battle_map)
        btn_layout.addWidget(self.lbl_round); btn_layout.addWidget(self.btn_next_turn); btn_layout.addWidget(self.btn_battle_map)
        layout.addLayout(btn_layout)
        
        btn_layout2 = QHBoxLayout()
        self.btn_add = QPushButton(tr("BTN_ADD")); self.btn_add.clicked.connect(self.add_combatant_dialog)
        self.btn_add_players = QPushButton(tr("BTN_ADD_PLAYERS")); self.btn_add_players.clicked.connect(self.add_all_players)
        self.btn_roll = QPushButton(tr("BTN_ROLL_INIT")); self.btn_roll.clicked.connect(self.roll_initiatives)
        self.btn_clear_all = QPushButton(tr("BTN_CLEAR_ALL")); self.btn_clear_all.clicked.connect(self.clear_tracker); self.btn_clear_all.setObjectName("dangerBtn")
        btn_layout2.addWidget(self.btn_add); btn_layout2.addWidget(self.btn_add_players); btn_layout2.addWidget(self.btn_roll); btn_layout2.addWidget(self.btn_clear_all)
        layout.addLayout(btn_layout2)
        self.refresh_encounter_combo()

    def create_encounter(self, name):
        eid = str(uuid.uuid4()); self.encounters[eid] = {"id":eid, "name":name, "combatants":[], "map_path":None, "token_size":50, "turn_index":-1, "round":1, "token_positions":{}}; self.current_encounter_id = eid; return eid
    
    def prompt_new_encounter(self): 
        n,ok = QInputDialog.getText(self, tr("TITLE_NEW_ENC"), tr("LBL_ENC_NAME")); 
        if ok and n: self.create_encounter(n); self.refresh_encounter_combo()
    
    def rename_encounter(self):
        if not self.current_encounter_id or self.current_encounter_id not in self.encounters: return
        n,ok = QInputDialog.getText(self, tr("TITLE_RENAME_ENC"), tr("LBL_NEW_NAME"), text=self.encounters[self.current_encounter_id]["name"])
        if ok and n: self.encounters[self.current_encounter_id]["name"] = n; self.refresh_encounter_combo()
    
    def delete_encounter(self):
        if len(self.encounters) <= 1: QMessageBox.warning(self, tr("MSG_ERROR"), tr("MSG_LAST_ENC_DELETE")); return
        if QMessageBox.question(self, tr("TITLE_DELETE"), tr("MSG_CONFIRM_ENC_DELETE"), QMessageBox.StandardButton.Yes|QMessageBox.StandardButton.No)==QMessageBox.StandardButton.Yes: 
            del self.encounters[self.current_encounter_id]
            self.refresh_encounter_combo()
    
    def switch_encounter(self, idx): 
        eid = self.combo_encounters.itemData(idx)
        if eid and eid in self.encounters: 
            if self.current_encounter_id and self.fog_save_handler:
                self.fog_save_handler(self.current_encounter_id)
            if self.current_encounter_id in self.encounters:
                self._save_current_state_to_memory()
            self.current_encounter_id = eid
            self.refresh_ui_from_current_encounter()
            if self.battle_map_window and self.battle_map_window.isVisible():
                self.refresh_battle_map(force_map_reload=True)
            
    def refresh_encounter_combo(self):
        self.combo_encounters.blockSignals(True)
        self.combo_encounters.clear()
        if not self.encounters: self.create_encounter("Default Encounter")
        for eid, e in self.encounters.items(): self.combo_encounters.addItem(e["name"], eid)
        idx = self.combo_encounters.findData(self.current_encounter_id)
        if idx >= 0: self.combo_encounters.setCurrentIndex(idx)
        else: self.combo_encounters.setCurrentIndex(0); self.current_encounter_id = self.combo_encounters.itemData(0)
        self.combo_encounters.blockSignals(False)
        self.refresh_ui_from_current_encounter()

    def add_direct_row(self, name, init, ac, hp, conditions_data, eid, init_bonus=0, tid=None):
        if not tid: tid = str(uuid.uuid4())
        self.table.blockSignals(True); row = self.table.rowCount(); self.table.insertRow(row)
        self.table.setItem(row, 0, QTableWidgetItem(name))
        it_init = NumericTableWidgetItem(str(init)); it_init.setData(Qt.ItemDataRole.UserRole, eid); it_init.setData(Qt.ItemDataRole.UserRole+1, tid); self.table.setItem(row, 1, it_init)
        self.table.setItem(row, 2, NumericTableWidgetItem(str(clean_stat_value(ac))))
        cur = clean_stat_value(hp); mx = cur
        if eid and eid in self.dm.data["entities"]:
             try: db_max = clean_stat_value(self.dm.data["entities"][eid]["combat_stats"]["max_hp"]); mx = db_max if db_max >= cur else cur
             except: pass
        hp_w = HpBarWidget(cur, mx); hp_w.hpChanged.connect(lambda v, w=hp_w: self.on_widget_hp_changed(w, v)); self.table.setCellWidget(row, 3, hp_w); self.table.setItem(row, 3, NumericTableWidgetItem(str(cur))) 
        cond_w = ConditionsWidget(); cond_w.clicked.connect(lambda w=cond_w: self.open_condition_menu_for_widget(w))
        if isinstance(conditions_data, str) and conditions_data: conditions_data = [{"name": c.strip(), "icon": None, "duration": 0, "max_duration": 0} for c in conditions_data.split(",")]
        elif not isinstance(conditions_data, list): conditions_data = []
        cond_w.set_conditions(conditions_data); cond_w.conditionsChanged.connect(self.data_changed_signal.emit); self.table.setCellWidget(row, 4, cond_w)
        self.table.blockSignals(False); self.data_changed_signal.emit()

    def open_condition_menu_for_widget(self, widget):
        index = self.table.indexAt(widget.pos())
        if not index.isValid(): return
        row = index.row(); menu = QMenu(self); menu.setStyleSheet("QMenu { background-color: #333; color: white; border: 1px solid #555; } QMenu::item:selected { background-color: #007acc; }")
        std_menu = menu.addMenu(tr("MENU_STD_CONDITIONS"))
        for cond in CONDITIONS: action = QAction(cond, self); action.triggered.connect(lambda checked, r=row, n=cond: self.add_condition_to_row(r, n, None, 0)); std_menu.addAction(action)
        menu.addSeparator()
        custom_effects = [e for e in self.dm.data["entities"].values() if e.get("type") == "Status Effect"]
        if custom_effects:
            lbl = menu.addAction(tr("MENU_SAVED_EFFECTS")); lbl.setEnabled(False)
            for eff in custom_effects:
                eff_name = eff.get("name", "Bilinmeyen"); icon_path = None
                if eff.get("images"):
                    full_path = self.dm.get_full_path(eff["images"][0])
                    if full_path and os.path.exists(full_path): icon_path = full_path
                try: duration = int(eff.get("attributes", {}).get("LBL_DURATION_TURNS", 0))
                except: duration = 0
                action = QAction(eff_name, self); 
                if icon_path: action.setIcon(QIcon(icon_path))
                action.triggered.connect(lambda checked, r=row, n=eff_name, p=icon_path, d=duration: self.add_condition_to_row(r, n, p, d)); menu.addAction(action)
        else: no_act = menu.addAction(tr("MSG_NO_SAVED_EFFECTS")); no_act.setEnabled(False)
        menu.exec(QCursor.pos())

    def refresh_ui_from_current_encounter(self):
        if not self.current_encounter_id or self.current_encounter_id not in self.encounters: self.table.setRowCount(0); return
        self.loading = True; self.table.blockSignals(True); self.table.setRowCount(0); enc = self.encounters[self.current_encounter_id]
        self.lbl_round.setText(f"{tr('LBL_ROUND_PREFIX')}{enc.get('round', 1)}")
        for c in enc.get("combatants", []):
            tid = c.get("tid") or str(uuid.uuid4())
            if c.get("x") is not None: enc["token_positions"][tid] = (float(c["x"]), float(c["y"]))
            self.add_direct_row(c["name"], c["init"], c["ac"], c["hp"], c.get("conditions", []), c["eid"], c.get("bonus", 0), tid)
        self._sort_and_refresh(); self.table.blockSignals(False); self.loading = False

    def _save_current_state_to_memory(self):
        if not self.current_encounter_id or self.current_encounter_id not in self.encounters: return
        enc = self.encounters[self.current_encounter_id]; combatants = []
        for r in range(self.table.rowCount()):
            if not self.table.item(r, 0): continue
            def get_text_safe(col_index, default_val=""): item = self.table.item(r, col_index); return item.text() if item else default_val
            hp_w = self.table.cellWidget(r, 3); cond_w = self.table.cellWidget(r, 4); tid = None; eid = None
            item_init = self.table.item(r, 1)
            if item_init: tid = item_init.data(Qt.ItemDataRole.UserRole + 1); eid = item_init.data(Qt.ItemDataRole.UserRole)
            if not tid: tid = str(uuid.uuid4())
            combatants.append({"tid": str(tid), "eid": str(eid) if eid else None, "name": get_text_safe(0, "???"), "init": get_text_safe(1, "0"), "ac": get_text_safe(2, "10"), "hp": str(hp_w.current) if hp_w else "0", "conditions": cond_w.active_conditions if cond_w else [], "bonus": 0, "x": enc["token_positions"].get(tid, (None,None))[0], "y": enc["token_positions"].get(tid, (None,None))[1]})
        enc["combatants"] = combatants

    def next_turn(self):
        if not self.current_encounter_id or self.current_encounter_id not in self.encounters: return
        enc = self.encounters[self.current_encounter_id]; count = self.table.rowCount()
        if count == 0: return
        self.loading = True; enc["turn_index"] += 1
        if enc["turn_index"] >= count: enc["turn_index"] = 0; enc["round"] += 1; self.lbl_round.setText(f"{tr('LBL_ROUND_PREFIX')}{enc['round']}")
        w = self.table.cellWidget(enc["turn_index"], 4)
        if w: w.tick_conditions()
        self.update_highlights(); self.refresh_battle_map(); self.loading = False; self.data_changed_signal.emit()

    def update_highlights(self):
        if not self.current_encounter_id or self.current_encounter_id not in self.encounters: return
        idx = self.encounters[self.current_encounter_id]["turn_index"]
        self.table.blockSignals(True)
        for r in range(self.table.rowCount()):
             for c in range(self.table.columnCount()):
                  if self.table.item(r, c): self.table.item(r, c).setBackground(QBrush(Qt.BrushStyle.NoBrush))
        if 0 <= idx < self.table.rowCount():
             for c in range(self.table.columnCount()):
                  if self.table.item(idx, c): self.table.item(idx, c).setBackground(QBrush(QColor(100, 149, 237, 100)))
        self.table.blockSignals(False)

    def _sort_and_refresh(self):
        if not self.current_encounter_id: return
        enc = self.encounters[self.current_encounter_id]; cur_tid = None
        if 0 <= enc["turn_index"] < self.table.rowCount(): cur_tid = self.table.item(enc["turn_index"], 1).data(Qt.ItemDataRole.UserRole+1)
        self.table.blockSignals(True); self.table.sortItems(1, Qt.SortOrder.DescendingOrder); self.table.blockSignals(False)
        if cur_tid:
             for r in range(self.table.rowCount()):
                  if self.table.item(r, 1).data(Qt.ItemDataRole.UserRole+1) == cur_tid: enc["turn_index"] = r; break
        self.update_highlights(); self.refresh_battle_map(); 
        if not self.loading: self.data_changed_signal.emit()

    def on_widget_hp_changed(self, widget, val):
        idx = self.table.indexAt(widget.pos())
        if idx.isValid(): self.table.item(idx.row(), 3).setText(str(val)); self._save_current_state_to_memory(); self.refresh_battle_map(); self.data_changed_signal.emit()

    def open_context_menu(self, pos):
        row = self.table.rowAt(pos.y()); 
        if row == -1: return
        menu = QMenu()
        add_cond_menu = menu.addMenu("🩸 " + tr("MENU_ADD_COND"))
        for c in CONDITIONS: a = QAction(c, self); a.triggered.connect(lambda ch, n=c: self.add_condition_to_row(row, n, None, 0)); add_cond_menu.addAction(a)
        add_cond_menu.addSeparator()
        custom_effects = [e for e in self.dm.data["entities"].values() if e.get("type") == "Status Effect"]
        for eff in custom_effects:
            p = self.dm.get_full_path(eff["images"][0]) if eff.get("images") else None
            try: d = int(eff.get("attributes", {}).get("LBL_DURATION_TURNS", 0))
            except: d = 0
            a = QAction(eff["name"], self); 
            if p: a.setIcon(QIcon(p))
            a.triggered.connect(lambda ch, n=eff["name"], p=p, d=d: self.add_condition_to_row(row, n, p, d)); add_cond_menu.addAction(a)
        menu.addSeparator()
        del_act = QAction("❌ " + tr("MENU_REMOVE_COMBAT"), self); del_act.triggered.connect(lambda: self.delete_row(row)); menu.addAction(del_act)
        menu.exec(self.table.viewport().mapToGlobal(pos))

    def add_condition_to_row(self, row, name, icon_path, duration):
        if duration == 0:
            d, ok = QInputDialog.getInt(self, tr("LBL_DURATION_PROMPT_TITLE"), tr("LBL_DURATION_PROMPT_MSG", name=name), 0, 0, 100)
            if ok: duration = d
        w = self.table.cellWidget(row, 4)
        if w: w.add_condition(name, icon_path, duration)
    
    def clear_tracker(self):
        if not self.current_encounter_id or self.current_encounter_id not in self.encounters: return
        enc = self.encounters[self.current_encounter_id]
        self.table.setRowCount(0); enc["combatants"] = []; enc["token_positions"] = {}; enc["turn_index"] = -1; enc["round"] = 1; enc["map_path"] = None 
        self.lbl_round.setText(f"{tr('LBL_ROUND_PREFIX')}1")
        self.refresh_battle_map(force_map_reload=True) 
        if not self.loading: self.data_changed_signal.emit()

    def on_cell_double_clicked(self, r, c): 
        if c==3: 
            w=self.table.cellWidget(r,3); 
            if w: 
                v,ok=QInputDialog.getInt(self, tr("TITLE_EDIT_HP"), tr("LBL_NEW_HP"), w.current, 0, 9999)
                if ok: w.update_hp(v)
    def on_data_changed(self, i): 
        if self.loading: return
        if i.column()==1: self._sort_and_refresh()
        else: self._save_current_state_to_memory(); self.data_changed_signal.emit()
    def quick_add(self):
        n=self.inp_quick_name.text().strip(); 
        if n: self.add_direct_row(n, self.inp_quick_init.text() or str(random.randint(1,20)), "10", self.inp_quick_hp.text() or "10", [], None); self.inp_quick_name.clear(); self._sort_and_refresh()
    def add_combatant_dialog(self):
        d=EncounterSelectionDialog(self.dm, self)
        if d.exec(): 
            for eid in d.selected_entities: self.add_row_from_entity(eid)
            self._sort_and_refresh()
    def add_row_from_entity(self, eid):
        d=self.dm.data["entities"].get(eid)
        if d:
            try: m=(int(d["stats"]["DEX"])-10)//2
            except: m=0
            try: m+=clean_stat_value(d["combat_stats"].get("initiative"), 0)
            except: pass
            self.add_direct_row(d["name"], random.randint(1,20)+m, d["combat_stats"].get("ac","10"), d["combat_stats"].get("hp","10"), [], eid, m)
    def add_all_players(self):
        ex=[self.table.item(r,1).data(Qt.ItemDataRole.UserRole) for r in range(self.table.rowCount())]
        for k,v in self.dm.data["entities"].items(): 
            if v["type"]=="Player" and k not in ex: self.add_row_from_entity(k)
        self._sort_and_refresh()
    def roll_initiatives(self):
        self.table.blockSignals(True)
        for r in range(self.table.rowCount()):
             b = self.table.item(r,0).data(Qt.ItemDataRole.UserRole) or 0
             self.table.item(r,1).setText(str(random.randint(1,20)+b))
        self.table.blockSignals(False); self._sort_and_refresh()
    def delete_row(self, r): 
        self.table.removeRow(r)
        if self.current_encounter_id and self.current_encounter_id in self.encounters:
             enc = self.encounters[self.current_encounter_id]
             if enc["turn_index"] >= r: enc["turn_index"] = max(0, enc["turn_index"]-1)
        self.update_highlights(); self.refresh_battle_map(); self.data_changed_signal.emit()
    def get_session_state(self): self._save_current_state_to_memory(); return {"encounters": self.encounters, "current_encounter_id": self.current_encounter_id}
    def load_session_state(self, d):
        self.loading=True; self.combo_encounters.blockSignals(True); self.combo_encounters.clear()
        if "encounters" in d: self.encounters=d["encounters"]; tid=d.get("current_encounter_id")
        else: eid=str(uuid.uuid4()); self.encounters={eid:{"id":eid,"name":"Legacy","combatants":d.get("combatants",[]),"round":1,"turn_index":-1,"token_positions":{},"token_size":50}}; tid=eid
        for k,v in self.encounters.items(): self.combo_encounters.addItem(v["name"], k)
        if tid and tid in self.encounters: self.combo_encounters.setCurrentIndex(self.combo_encounters.findData(tid)); self.current_encounter_id=tid
        else: self.combo_encounters.setCurrentIndex(0); self.current_encounter_id=self.combo_encounters.itemData(0)
        self.refresh_ui_from_current_encounter(); self.combo_encounters.blockSignals(False); self.loading=False
    
    def load_combat_data(self, data):
        """Compatibility method for legacy session data (list of combatants)."""
        self.load_session_state({"combatants": data})

    def open_battle_map(self):
        if self.battle_map_window and self.battle_map_window.isVisible(): self.battle_map_window.raise_(); self.battle_map_window.activateWindow(); return
        enc = self.encounters.get(self.current_encounter_id)
        if not enc: return
        if not enc.get("map_path"):
             # --- DEĞİŞİKLİK BURADA: DataManager'ı gönderiyoruz ---
             d = MapSelectorDialog(self.dm, self)
             if d.exec():
                  if d.is_new_import: 
                       f,_=QFileDialog.getOpenFileName(self,"Select","", "Img (*.png *.jpg)"); 
                       if f: enc["map_path"]=self.dm.import_image(f)
                  elif d.selected_file: 
                       enc["map_path"] = d.selected_file
                  self.data_changed_signal.emit()
             else: return
        self.battle_map_window = BattleMapWindow(self.dm)
        self.battle_map_window.token_moved_signal.connect(self.on_token_moved_in_map)
        self.battle_map_window.slider_size.valueChanged.connect(self.on_token_size_changed)
        self.battle_map_window.show(); self.refresh_battle_map(True)
    
    def on_token_moved_in_map(self, tid, x, y): 
        if self.current_encounter_id: 
            self.encounters[self.current_encounter_id]["token_positions"][tid]=(x,y); self.data_changed_signal.emit()
            if self.battle_map_window and self.battle_map_window.isVisible(): self.refresh_battle_map(force_map_reload=False)
            
    def on_token_size_changed(self, v): 
        if self.current_encounter_id: 
            self.encounters[self.current_encounter_id]["token_size"]=v; self.data_changed_signal.emit()
            if self.battle_map_window and self.battle_map_window.isVisible(): self.refresh_battle_map(force_map_reload=False)
            
    def refresh_battle_map(self, force_map_reload=False):
        if not self.current_encounter_id or self.current_encounter_id not in self.encounters: return
        enc=self.encounters[self.current_encounter_id]; self._save_current_state_to_memory()
        mp=self.dm.get_full_path(enc.get("map_path"))
        cd=[]
        for c in enc["combatants"]:
             t="NPC"; a="LBL_ATTR_NEUTRAL"
             if c["eid"] in self.dm.data["entities"]:
                  e=self.dm.data["entities"][c["eid"]]; t=e.get("type","NPC"); a=e.get("attributes",{}).get("LBL_ATTITUDE","LBL_ATTR_NEUTRAL"); 
                  if t=="Monster": a="LBL_ATTR_HOSTILE"
             c["type"]=t; c["attitude"]=a; cd.append(c)
        if self.battle_map_window and self.battle_map_window.isVisible(): self.battle_map_window.update_combat_data(cd, enc["turn_index"], mp, enc["token_size"])
    
    def sync_map_view_to_external(self, rect):
        if self.battle_map_window and self.battle_map_window.isVisible(): self.battle_map_window.sync_view(rect)
    
    def sync_fog_to_external(self, qimage):
        if self.battle_map_window and self.battle_map_window.isVisible(): self.battle_map_window.sync_fog(qimage)

    def retranslate_ui(self):
        self.table.setHorizontalHeaderLabels([tr("HEADER_NAME"), tr("HEADER_INIT"), tr("HEADER_AC"), tr("HEADER_HP"), tr("HEADER_COND")])
        self.inp_quick_name.setPlaceholderText(tr("HEADER_NAME")); self.btn_quick_add.setText(tr("BTN_QUICK_ADD")); self.btn_next_turn.setText(tr("BTN_NEXT_TURN")); self.btn_add.setText(tr("BTN_ADD")); self.btn_add_players.setText(tr("BTN_ADD_PLAYERS")); self.btn_roll.setText(tr("BTN_ROLL_INIT")); self.btn_clear_all.setText(tr("BTN_CLEAR_ALL"))
        if self.current_encounter_id and self.current_encounter_id in self.encounters: self.lbl_round.setText(f"{tr('LBL_ROUND_PREFIX')}{self.encounters[self.current_encounter_id].get('round', 1)}")
        if self.battle_map_window and self.battle_map_window.isVisible(): self.battle_map_window.retranslate_ui(); self.refresh_battle_map()