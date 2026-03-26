from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QTableWidget, QTableWidgetItem, 
                             QHBoxLayout, QPushButton, QHeaderView, QInputDialog, 
                             QMenu, QMessageBox, QFrame, QLineEdit, QFileDialog, 
                             QDialog, QListWidget, QListWidgetItem, QLabel, 
                             QAbstractItemView, QProgressBar, QSlider, QComboBox, 
                             QScrollArea, QStyle, QApplication)
from PyQt6.QtGui import QAction, QColor, QBrush, QCursor, QIcon, QPixmap, QPainter, QPainterPath
from PyQt6.QtCore import Qt, pyqtSignal, QSize, QUrl, QRect
from core.locales import tr
from core.theme_manager import ThemeManager
from ui.dialogs.encounter_selector import EncounterSelectionDialog
from ui.widgets.combat_model import CombatModel
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
    except (ValueError, AttributeError): return default

# Standard Conditions List (keys must stay in English; UI displays translated labels)
CONDITIONS_MAP = {
    "Blinded": "COND_BLINDED",
    "Charmed": "COND_CHARMED",
    "Deafened": "COND_DEAFENED",
    "Frightened": "COND_FRIGHTENED",
    "Grappled": "COND_GRAPPLED",
    "Incapacitated": "COND_INCAPACITATED",
    "Invisible": "COND_INVISIBLE",
    "Paralyzed": "COND_PARALYZED",
    "Petrified": "COND_PETRIFIED",
    "Poisoned": "COND_POISONED",
    "Prone": "COND_PRONE",
    "Restrained": "COND_RESTRAINED",
    "Stunned": "COND_STUNNED",
    "Unconscious": "COND_UNCONSCIOUS",
    "Exhaustion": "COND_EXHAUSTION"
}

from ui.widgets.combat_table import (
    DraggableCombatTable,
    ConditionIcon,
    ConditionsWidget,
    HpBarWidget,
    NumericTableWidgetItem,
    MapSelectorDialog,
)

# --- COMBAT TRACKER ---
class CombatTracker(QWidget):
    data_changed_signal = pyqtSignal()

    def __init__(self, data_manager):
        super().__init__()
        self.dm = data_manager
        self.battle_map_window = None
        self.loading = False
        self._model = CombatModel()
        self.fog_save_handler = None

        # Initial theme palette
        self.current_palette = ThemeManager.get_palette(self.dm.current_theme)

        self.create_encounter("Default Encounter")
        self.init_ui()

    # ------------------------------------------------------------------
    # Encounter state properties — delegate to CombatModel
    # ------------------------------------------------------------------

    @property
    def encounters(self) -> dict:
        return self._model.encounters

    @encounters.setter
    def encounters(self, value: dict) -> None:
        self._model.encounters = value

    @property
    def current_encounter_id(self) -> str | None:
        return self._model.current_encounter_id

    @current_encounter_id.setter
    def current_encounter_id(self, value: str | None) -> None:
        self._model.current_encounter_id = value

    def set_fog_save_handler(self, handler): self.fog_save_handler = handler

    def refresh_theme(self, palette):
        """Propagates theme change from the Main Window to all child widgets."""
        self.current_palette = palette

        # Update widgets inside the table (HpBar and Conditions)
        for row in range(self.table.rowCount()):
            # HP Bar
            hp_w = self.table.cellWidget(row, 3)
            if hp_w and isinstance(hp_w, HpBarWidget):
                hp_w.update_theme(palette)
            
            # Conditions Widget
            cond_w = self.table.cellWidget(row, 4)
            if cond_w and isinstance(cond_w, ConditionsWidget):
                cond_w.update_theme(palette)
                
        # Update row highlight colors
        self.update_highlights()

    def init_ui(self):
        layout = QVBoxLayout(self)
        enc_layout = QHBoxLayout()
        self.combo_encounters = QComboBox()
        self.combo_encounters.currentIndexChanged.connect(self.switch_encounter)
        self.combo_encounters.setMinimumWidth(200)
        self.btn_new_enc = QPushButton("➕")
        self.btn_new_enc.setFixedWidth(40)
        self.btn_new_enc.setToolTip(tr("TIP_NEW_ENC"))
        self.btn_new_enc.clicked.connect(self.prompt_new_encounter)
        self.btn_rename_enc = QPushButton("✏️")
        self.btn_rename_enc.setFixedWidth(40)
        self.btn_rename_enc.setToolTip(tr("TIP_RENAME_ENC"))
        self.btn_rename_enc.clicked.connect(self.rename_encounter)
        self.btn_del_enc = QPushButton("🗑️")
        self.btn_del_enc.setFixedWidth(40)
        self.btn_del_enc.setToolTip(tr("TIP_DEL_ENC"))
        self.btn_del_enc.clicked.connect(self.delete_encounter)
        self.btn_del_enc.setObjectName("dangerBtn")
        enc_layout.addWidget(QLabel(tr("LBL_ENCOUNTER_PREFIX")))
        enc_layout.addWidget(self.combo_encounters)
        enc_layout.addWidget(self.btn_new_enc)
        enc_layout.addWidget(self.btn_rename_enc)
        enc_layout.addWidget(self.btn_del_enc)
        layout.addLayout(enc_layout)

        # Table class: DraggableCombatTable
        self.table = DraggableCombatTable()
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
        
        # Signal: add the dropped entity ID
        self.table.entity_dropped.connect(self.handle_drop_import)
        
        layout.addWidget(self.table)

        q_lo = QHBoxLayout()
        self.inp_quick_name = QLineEdit()
        self.inp_quick_name.setPlaceholderText(tr("HEADER_NAME"))
        self.inp_quick_init = QLineEdit()
        self.inp_quick_init.setPlaceholderText(tr("LBL_INIT"))
        self.inp_quick_init.setMaximumWidth(50)
        self.inp_quick_hp = QLineEdit()
        self.inp_quick_hp.setPlaceholderText(tr("LBL_HP"))
        self.inp_quick_hp.setMaximumWidth(50)
        self.btn_quick_add = QPushButton(tr("BTN_QUICK_ADD"))
        self.btn_quick_add.clicked.connect(self.quick_add)
        q_lo.addWidget(self.inp_quick_name, 3)
        q_lo.addWidget(self.inp_quick_init, 1)
        q_lo.addWidget(self.inp_quick_hp, 1)
        q_lo.addWidget(self.btn_quick_add, 1)
        layout.addLayout(q_lo)

        btn_layout = QHBoxLayout()
        self.lbl_round = QLabel(f"{tr('LBL_ROUND_PREFIX')}1")
        self.lbl_round.setObjectName("headerLabel")
        self.lbl_round.setStyleSheet("font-size: 16px; font-weight: bold; margin-right: 10px;")
        self.btn_next_turn = QPushButton(tr("BTN_NEXT_TURN"))
        self.btn_next_turn.setObjectName("actionBtn")
        self.btn_next_turn.clicked.connect(self.next_turn)
        
        btn_layout.addWidget(self.lbl_round)
        btn_layout.addWidget(self.btn_next_turn)
        layout.addLayout(btn_layout)
        
        btn_layout2 = QHBoxLayout()
        self.btn_add = QPushButton(tr("BTN_ADD"))
        self.btn_add.clicked.connect(self.add_combatant_dialog)
        self.btn_add_players = QPushButton(tr("BTN_ADD_PLAYERS"))
        self.btn_add_players.clicked.connect(self.add_all_players)
        self.btn_roll = QPushButton(tr("BTN_ROLL_INIT"))
        self.btn_roll.clicked.connect(self.roll_initiatives)
        self.btn_clear_all = QPushButton(tr("BTN_CLEAR_ALL"))
        self.btn_clear_all.clicked.connect(self.clear_tracker)
        self.btn_clear_all.setObjectName("dangerBtn")
        btn_layout2.addWidget(self.btn_add)
        btn_layout2.addWidget(self.btn_add_players)
        btn_layout2.addWidget(self.btn_roll)
        btn_layout2.addWidget(self.btn_clear_all)
        layout.addLayout(btn_layout2)
        self.refresh_encounter_combo()

    def handle_drop_import(self, eid):
        """Adds an entity dragged in from the Sidebar."""
        if eid.startswith("lib_"):
            QMessageBox.information(self, tr("MSG_INFO"), tr("MSG_DROP_IMPORT_FIRST"))
            return

        if eid in self.dm.data["entities"]:
            ent = self.dm.data["entities"][eid]
            if ent.get("type") in ["NPC", "Monster", "Player"]:
                self.add_row_from_entity(eid)
                self._sort_and_refresh()

    def create_encounter(self, name):
        return self._model.create_encounter(name)
    
    def prompt_new_encounter(self): 
        n, ok = QInputDialog.getText(self, tr("TITLE_NEW_ENC"), tr("LBL_ENC_NAME"))
        if ok and n: 
            self.create_encounter(n)
            self.refresh_encounter_combo()
    
    def rename_encounter(self):
        if not self.current_encounter_id or self.current_encounter_id not in self.encounters:
            return
        n, ok = QInputDialog.getText(self, tr("TITLE_RENAME_ENC"), tr("LBL_NEW_NAME"), text=self.encounters[self.current_encounter_id]["name"])
        if ok and n:
            self._model.rename(self.current_encounter_id, n)
            self.refresh_encounter_combo()

    def delete_encounter(self):
        if len(self.encounters) <= 1:
            QMessageBox.warning(self, tr("MSG_ERROR"), tr("MSG_LAST_ENC_DELETE"))
            return
        if QMessageBox.question(self, tr("TITLE_DELETE"), tr("MSG_CONFIRM_ENC_DELETE"), QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No) == QMessageBox.StandardButton.Yes:
            self._model.delete(self.current_encounter_id)
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
        
        it_init = NumericTableWidgetItem(str(init))
        it_init.setData(Qt.ItemDataRole.UserRole, eid)
        it_init.setData(Qt.ItemDataRole.UserRole+1, tid)
        self.table.setItem(row, 1, it_init)
        
        self.table.setItem(row, 2, NumericTableWidgetItem(str(clean_stat_value(ac))))
        
        cur = clean_stat_value(hp); mx = cur
        if eid and eid in self.dm.data["entities"]:
             try: db_max = clean_stat_value(self.dm.data["entities"][eid]["combat_stats"]["max_hp"]); mx = db_max if db_max >= cur else cur
             except (KeyError, ValueError, TypeError): pass
        
        # HP Widget (Tema ile)
        hp_w = HpBarWidget(cur, mx, self.current_palette)
        hp_w.hpChanged.connect(lambda v, w=hp_w: self.on_widget_hp_changed(w, v))
        self.table.setCellWidget(row, 3, hp_w)
        self.table.setItem(row, 3, NumericTableWidgetItem(str(cur))) 
        
        # Conditions Widget (Tema ile)
        cond_w = ConditionsWidget()
        cond_w.update_theme(self.current_palette)
        cond_w.clicked.connect(lambda w=cond_w: self.open_condition_menu_for_widget(w))
        
        if isinstance(conditions_data, str) and conditions_data: 
            conditions_data = [{"name": c.strip(), "icon": None, "duration": 0, "max_duration": 0} for c in conditions_data.split(",")]
        elif not isinstance(conditions_data, list): 
            conditions_data = []
            
        cond_w.set_conditions(conditions_data)
        cond_w.conditionsChanged.connect(self.data_changed_signal.emit)
        self.table.setCellWidget(row, 4, cond_w)
        
        self.table.blockSignals(False)
        self.data_changed_signal.emit()

    def open_condition_menu_for_widget(self, widget):
        index = self.table.indexAt(widget.pos())
        if not index.isValid(): return
        row = index.row()
        
        menu = QMenu(self)
        # Menu style
        p = self.current_palette
        menu.setStyleSheet(f"QMenu {{ background-color: {p.get('ui_floating_bg', '#333')}; color: {p.get('ui_floating_text', '#eee')}; border: 1px solid {p.get('ui_floating_border', '#555')}; }} QMenu::item:selected {{ background-color: {p.get('line_selected', '#007acc')}; }}")
        
        std_menu = menu.addMenu(tr("MENU_STD_CONDITIONS"))
        for en_key, trans_key in CONDITIONS_MAP.items(): 
            action = QAction(tr(trans_key), self)
            action.triggered.connect(lambda checked, r=row, n=en_key: self.add_condition_to_row(r, n, None, 0))
            std_menu.addAction(action)
            
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
                except (ValueError, TypeError): duration = 0
                action = QAction(eff_name, self); 
                if icon_path: action.setIcon(QIcon(icon_path))
                action.triggered.connect(lambda checked, r=row, n=eff_name, p=icon_path, d=duration: self.add_condition_to_row(r, n, p, d)); menu.addAction(action)
        else: 
            no_act = menu.addAction(tr("MSG_NO_SAVED_EFFECTS")); no_act.setEnabled(False)
            
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
        if not self.current_encounter_id or self.current_encounter_id not in self.encounters:
            return
        count = self.table.rowCount()
        if count == 0:
            return
        self.loading = True
        new_round = self._model.advance_turn(count)
        enc = self.encounters[self.current_encounter_id]
        if new_round:
            self.lbl_round.setText(f"{tr('LBL_ROUND_PREFIX')}{enc['round']}")
        w = self.table.cellWidget(enc["turn_index"], 4)
        if w:
            w.tick_conditions()
        self.update_highlights()
        self.refresh_battle_map()
        self.loading = False
        self.data_changed_signal.emit()

    def update_highlights(self):
        """Highlights the active turn row. Color is sourced from ThemeManager."""
        if not self.current_encounter_id or self.current_encounter_id not in self.encounters: return
        idx = self.encounters[self.current_encounter_id]["turn_index"]

        # Get color from theme palette, apply transparency
        active_color = QColor(self.current_palette.get("token_border_active", "#ffb74d"))
        active_color.setAlpha(100)  # Transparency
        brush = QBrush(active_color)
        
        self.table.blockSignals(True)
        for r in range(self.table.rowCount()):
             for c in range(self.table.columnCount()):
                  if self.table.item(r, c): self.table.item(r, c).setBackground(QBrush(Qt.BrushStyle.NoBrush))
        if 0 <= idx < self.table.rowCount():
             for c in range(self.table.columnCount()):
                  if self.table.item(idx, c): self.table.item(idx, c).setBackground(brush)
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
        # Menu style
        p = self.current_palette
        menu.setStyleSheet(f"QMenu {{ background-color: {p.get('ui_floating_bg', '#333')}; color: {p.get('ui_floating_text', '#eee')}; border: 1px solid {p.get('ui_floating_border', '#555')}; }}")
        
        add_cond_menu = menu.addMenu("🩸 " + tr("MENU_ADD_COND"))
        for en_key, trans_key in CONDITIONS_MAP.items(): 
            a = QAction(tr(trans_key), self)
            a.triggered.connect(lambda ch, n=en_key: self.add_condition_to_row(row, n, None, 0))
            add_cond_menu.addAction(a)
            
        add_cond_menu.addSeparator()
        custom_effects = [e for e in self.dm.data["entities"].values() if e.get("type") == "Status Effect"]
        for eff in custom_effects:
            p = self.dm.get_full_path(eff["images"][0]) if eff.get("images") else None
            try: d = int(eff.get("attributes", {}).get("LBL_DURATION_TURNS", 0))
            except (ValueError, TypeError): d = 0
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
            except (KeyError, ValueError, TypeError): m=0
            try: m+=clean_stat_value(d["combat_stats"].get("initiative"), 0)
            except (KeyError, ValueError, TypeError): pass
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
    def get_session_state(self):
        self._save_current_state_to_memory()
        return self._model.to_dict()

    def load_session_state(self, d):
        self.loading = True
        self.combo_encounters.blockSignals(True)
        self.combo_encounters.clear()
        self._model.load(d)
        for k, v in self.encounters.items():
            self.combo_encounters.addItem(v["name"], k)
        idx = self.combo_encounters.findData(self.current_encounter_id)
        if idx >= 0:
            self.combo_encounters.setCurrentIndex(idx)
        else:
            self.combo_encounters.setCurrentIndex(0)
            self.current_encounter_id = self.combo_encounters.itemData(0)
        self.refresh_ui_from_current_encounter()
        self.combo_encounters.blockSignals(False)
        self.loading = False
    
    def load_combat_data(self, data):
        self.load_session_state({"combatants": data})

    def load_map_dialog(self):
        if not self.current_encounter_id or self.current_encounter_id not in self.encounters: return
        enc = self.encounters[self.current_encounter_id]
        
        d = MapSelectorDialog(self.dm, self)
        if d.exec():
            if d.is_new_import: 
                f, _ = QFileDialog.getOpenFileName(self, "Select", "", "Media (*.png *.jpg *.jpeg *.mp4 *.webm *.mkv *.m4v *.avi)")
                if f: 
                    enc["map_path"] = self.dm.import_image(f)
            elif d.selected_file: 
                enc["map_path"] = d.selected_file
            
            self.data_changed_signal.emit()
            if self.battle_map_window and self.battle_map_window.isVisible():
                self.refresh_battle_map(force_map_reload=True)

    def open_battle_map(self):
        if self.battle_map_window and self.battle_map_window.isVisible():
            self.battle_map_window.raise_()
            self.battle_map_window.activateWindow()
            return

        from ui.windows.battle_map_window import BattleMapWindow
        self.battle_map_window = BattleMapWindow(self.dm)
        self.battle_map_window.token_moved_signal.connect(self.on_token_moved_in_map)
        self.battle_map_window.slider_size.valueChanged.connect(self.on_token_size_changed)
        self.battle_map_window.show()
        self.refresh_battle_map(True)
    
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
        
        raw_path = enc.get("map_path")
        mp = self.dm.get_full_path(raw_path)
        
        cd=[]
        for c in enc["combatants"]:
             t="NPC"; a="LBL_ATTR_NEUTRAL"
             if c["eid"] in self.dm.data["entities"]:
                  e=self.dm.data["entities"][c["eid"]]; t=e.get("type","NPC"); a=e.get("attributes",{}).get("LBL_ATTITUDE","LBL_ATTR_NEUTRAL"); 
                  if t=="Monster": a="LBL_ATTR_HOSTILE"
             c["type"]=t; c["attitude"]=a; cd.append(c)
             
        fog_data = enc.get("fog_data")
             
        if self.battle_map_window and self.battle_map_window.isVisible(): 
            self.battle_map_window.update_combat_data(
                cd, 
                enc["turn_index"], 
                mp, 
                enc["token_size"],
                fog_data=fog_data
            )
    
    def sync_map_view_to_external(self, rect):
        if self.battle_map_window and self.battle_map_window.isVisible(): self.battle_map_window.sync_view(rect)
    
    def sync_fog_to_external(self, qimage):
        if self.battle_map_window and self.battle_map_window.isVisible(): self.battle_map_window.sync_fog(qimage)

    def retranslate_ui(self):
        self.table.setHorizontalHeaderLabels([tr("HEADER_NAME"), tr("HEADER_INIT"), tr("HEADER_AC"), tr("HEADER_HP"), tr("HEADER_COND")])
        self.inp_quick_name.setPlaceholderText(tr("HEADER_NAME")); self.btn_quick_add.setText(tr("BTN_QUICK_ADD")); self.btn_next_turn.setText(tr("BTN_NEXT_TURN")); self.btn_add.setText(tr("BTN_ADD")); self.btn_add_players.setText(tr("BTN_ADD_PLAYERS")); self.btn_roll.setText(tr("BTN_ROLL_INIT")); self.btn_clear_all.setText(tr("BTN_CLEAR_ALL"))
        
        self.btn_new_enc.setToolTip(tr("TIP_NEW_ENC"))
        self.btn_rename_enc.setToolTip(tr("TIP_RENAME_ENC"))
        self.btn_del_enc.setToolTip(tr("TIP_DEL_ENC"))
        
        if self.current_encounter_id and self.current_encounter_id in self.encounters: self.lbl_round.setText(f"{tr('LBL_ROUND_PREFIX')}{self.encounters[self.current_encounter_id].get('round', 1)}")
        if self.battle_map_window and self.battle_map_window.isVisible(): self.battle_map_window.retranslate_ui(); self.refresh_battle_map()