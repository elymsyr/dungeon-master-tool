"""CombatTracker — encounter management widget for the Session tab.

Orchestrates:
  - CombatantListWidget  (table + row interactions)
  - CombatControlsWidget (encounter selector + turn/action buttons)
  - CombatModel          (encounter state)
  - BattleMapBridge      (external battle-map window)
"""

import logging
import os
import random
import uuid

from PyQt6.QtWidgets import (
    QFileDialog,
    QInputDialog,
    QMessageBox,
    QVBoxLayout,
    QWidget,
)

from core.locales import tr
from core.theme_manager import ThemeManager
from ui.dialogs.encounter_selector import EncounterSelectionDialog
from ui.widgets.battle_map_bridge import BattleMapBridge
from ui.widgets.combat_combatant_list import CombatantListWidget
from ui.widgets.combat_controls import CombatControlsWidget
from ui.widgets.combat_model import CombatModel
from ui.widgets.combat_table import MapSelectorDialog
from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtWidgets import QShortcut
from PyQt6.QtGui import QKeySequence

logger = logging.getLogger(__name__)


def _clean_stat_value(value, default=10):
    if value is None:
        return default
    s_val = str(value).strip()
    if not s_val:
        return default
    try:
        first_part = s_val.split(" ")[0]
        digits = "".join(filter(str.isdigit, first_part))
        return int(digits) if digits else default
    except (ValueError, AttributeError):
        return default


class CombatTracker(QWidget):
    data_changed_signal = pyqtSignal()
    combat_log = pyqtSignal(str)
    combatant_selected = pyqtSignal(str)
    view_entity_requested = pyqtSignal()

    def __init__(self, data_manager, player_window=None):
        super().__init__()
        self.dm = data_manager
        self._model = CombatModel()
        self._bridge = BattleMapBridge(self.dm, player_window, self)
        self._bridge.token_moved.connect(self.on_token_moved_in_map)
        self._bridge.token_size_changed.connect(self.on_token_size_changed)
        self._bridge.token_size_override_changed.connect(self.on_token_size_override_changed)
        self.fog_save_handler = None
        self.current_palette = ThemeManager.get_palette(self.dm.current_theme)

        self.create_encounter("Default Encounter")
        self.init_ui()

    # ------------------------------------------------------------------
    # CombatModel delegation properties
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

    @property
    def battle_map_window(self):
        return self._bridge.battle_map_window

    # Convenience: expose the inner table for any legacy references
    @property
    def table(self):
        return self._combatant_list.table

    def set_fog_save_handler(self, handler):
        self.fog_save_handler = handler

    # ------------------------------------------------------------------
    # UI setup
    # ------------------------------------------------------------------

    def init_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(4)

        self._controls = CombatControlsWidget()
        self._combatant_list = CombatantListWidget(self.dm)

        layout.addWidget(self._controls)
        layout.addWidget(self._combatant_list, stretch=1)

        # Wire CombatControlsWidget signals
        self._controls.turn_requested.connect(self.next_turn)
        self._controls.roll_requested.connect(self.roll_initiatives)
        self._controls.clear_requested.connect(self.clear_tracker)
        self._controls.add_combatant_requested.connect(self.add_combatant_dialog)
        self._controls.add_players_requested.connect(self.add_all_players)
        self._controls.quick_add_requested.connect(self._on_quick_add)
        self._controls.new_encounter_requested.connect(self._on_new_encounter)
        self._controls.rename_encounter_requested.connect(self._on_rename_encounter)
        self._controls.delete_encounter_confirmed.connect(self._on_delete_encounter)
        self._controls.encounter_selected.connect(self._on_encounter_selected)

        # Wire CombatantListWidget signals
        self._combatant_list.row_selected.connect(self.combatant_selected.emit)
        self._combatant_list.data_modified.connect(self._on_list_data_modified)
        self._combatant_list.sort_needed.connect(self._sort_and_refresh)
        self._combatant_list.hp_log.connect(self.combat_log.emit)
        self._combatant_list.condition_log.connect(self.combat_log.emit)
        self._combatant_list.drop_accepted.connect(self._on_drop_accepted)
        self._combatant_list.view_entity_requested.connect(self.view_entity_requested.emit)

        self.refresh_encounter_combo()

    # ------------------------------------------------------------------
    # Theme & retranslation
    # ------------------------------------------------------------------

    def refresh_theme(self, palette):
        self.current_palette = palette
        self._combatant_list.refresh_theme(palette)
        self._combatant_list.update_highlights(
            self.encounters.get(self.current_encounter_id, {}).get("turn_index", -1)
            if self.current_encounter_id else -1
        )

    def retranslate_ui(self):
        self._controls.retranslate_ui()
        self._combatant_list.retranslate_ui()
        if self.current_encounter_id and self.current_encounter_id in self.encounters:
            self._controls.update_round(
                self.encounters[self.current_encounter_id].get("round", 1)
            )
        self._bridge.retranslate()
        if self._bridge.is_open():
            self.refresh_battle_map()

    # ------------------------------------------------------------------
    # Encounter management
    # ------------------------------------------------------------------

    def create_encounter(self, name):
        return self._model.create_encounter(name)

    def refresh_encounter_combo(self):
        if not self.encounters:
            self.create_encounter("Default Encounter")
        self._controls.rebuild_encounter_combo(self.encounters, self.current_encounter_id)
        self.refresh_ui_from_current_encounter()

    def _on_new_encounter(self, name: str):
        self.create_encounter(name)
        self.refresh_encounter_combo()

    def _on_rename_encounter(self, new_name: str):
        if not self.current_encounter_id or self.current_encounter_id not in self.encounters:
            return
        # Re-ask with current name pre-filled (CombatControlsWidget can't do this)
        current_name = self.encounters[self.current_encounter_id]["name"]
        n, ok = QInputDialog.getText(
            self, tr("TITLE_RENAME_ENC"), tr("LBL_NEW_NAME"), text=current_name
        )
        if ok and n:
            self._model.rename(self.current_encounter_id, n)
            self.refresh_encounter_combo()

    def _on_delete_encounter(self):
        if len(self.encounters) <= 1:
            QMessageBox.warning(self, tr("MSG_ERROR"), tr("MSG_LAST_ENC_DELETE"))
            return
        self._model.delete(self.current_encounter_id)
        self.refresh_encounter_combo()

    def _on_encounter_selected(self, eid: str):
        if eid and eid in self.encounters:
            if self.current_encounter_id and self.fog_save_handler:
                self.fog_save_handler(self.current_encounter_id)
            if self.current_encounter_id in self.encounters:
                self._save_current_state_to_memory()
            self.current_encounter_id = eid
            self.refresh_ui_from_current_encounter()
            if self._bridge.is_open():
                self.refresh_battle_map(force_map_reload=True)

    # Backward-compat: kept for any direct callers
    def switch_encounter(self, idx):
        eid = self._controls.combo_encounters.itemData(idx)
        self._on_encounter_selected(eid)

    def rename_encounter(self):
        self._on_rename_encounter("")

    def delete_encounter(self):
        if len(self.encounters) <= 1:
            QMessageBox.warning(self, tr("MSG_ERROR"), tr("MSG_LAST_ENC_DELETE"))
            return
        if QMessageBox.question(
            self, tr("TITLE_DELETE"), tr("MSG_CONFIRM_ENC_DELETE"),
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        ) == QMessageBox.StandardButton.Yes:
            self._on_delete_encounter()

    def prompt_new_encounter(self):
        n, ok = QInputDialog.getText(self, tr("TITLE_NEW_ENC"), tr("LBL_ENC_NAME"))
        if ok and n:
            self._on_new_encounter(n)

    # ------------------------------------------------------------------
    # Combatant row management
    # ------------------------------------------------------------------

    def add_direct_row(self, name, init, ac, hp, conditions_data, eid, init_bonus=0, tid=None):
        self._combatant_list.add_direct_row(name, init, ac, hp, conditions_data, eid, init_bonus, tid)

    def _on_drop_accepted(self, eid: str):
        self.add_row_from_entity(eid)
        self._sort_and_refresh()

    def add_combatant_dialog(self):
        d = EncounterSelectionDialog(self.dm, self)
        if d.exec():
            for eid in d.selected_entities:
                self.add_row_from_entity(eid)
            self._sort_and_refresh()

    def add_row_from_entity(self, eid):
        d = self.dm.data["entities"].get(eid)
        if d:
            try:
                m = (int(d["stats"]["DEX"]) - 10) // 2
            except (KeyError, ValueError, TypeError):
                m = 0
            try:
                m += _clean_stat_value(d["combat_stats"].get("initiative"), 0)
            except (KeyError, ValueError, TypeError):
                pass
            self._combatant_list.add_direct_row(
                d["name"],
                random.randint(1, 20) + m,
                d["combat_stats"].get("ac", "10"),
                d["combat_stats"].get("hp", "10"),
                [],
                eid,
                m,
            )

    def add_all_players(self):
        existing = [
            self.table.item(r, 1).data(Qt.ItemDataRole.UserRole)
            for r in range(self.table.rowCount())
        ]
        for k, v in self.dm.data["entities"].items():
            if v["type"] == "Player" and k not in existing:
                self.add_row_from_entity(k)
        self._sort_and_refresh()

    def delete_row(self, row: int):
        self._combatant_list.delete_row(row)
        if self.current_encounter_id and self.current_encounter_id in self.encounters:
            enc = self.encounters[self.current_encounter_id]
            if enc["turn_index"] >= row:
                enc["turn_index"] = max(0, enc["turn_index"] - 1)
        self._combatant_list.update_highlights(
            self.encounters[self.current_encounter_id]["turn_index"]
            if self.current_encounter_id else -1
        )
        self.refresh_battle_map()
        self.data_changed_signal.emit()

    def _on_quick_add(self, name: str, init_text: str, hp_text: str):
        self._combatant_list.add_direct_row(
            name,
            init_text or str(random.randint(1, 20)),
            "10",
            hp_text or "10",
            [],
            None,
        )
        self._sort_and_refresh()

    # Quick-add forwarded from old call sites
    def quick_add(self):
        name = self._controls.inp_quick_name.text().strip()
        if name:
            self._on_quick_add(
                name,
                self._controls.inp_quick_init.text(),
                self._controls.inp_quick_hp.text(),
            )
            self._controls.inp_quick_name.clear()

    # ------------------------------------------------------------------
    # Turn & round management
    # ------------------------------------------------------------------

    def next_turn(self):
        if not self.current_encounter_id or self.current_encounter_id not in self.encounters:
            return
        count = self._combatant_list.row_count()
        if count == 0:
            return
        self._combatant_list.set_loading(True)
        new_round = self._model.advance_turn(count)
        enc = self.encounters[self.current_encounter_id]
        if new_round:
            self._controls.update_round(enc["round"])
        self._combatant_list.tick_conditions_at(enc["turn_index"])
        self._combatant_list.update_highlights(enc["turn_index"])
        self.refresh_battle_map()
        self._combatant_list.set_loading(False)
        self.data_changed_signal.emit()
        turn_idx = enc["turn_index"]
        name_item = self.table.item(turn_idx, 0)
        name = name_item.text() if name_item else "?"
        if new_round:
            self.combat_log.emit(f"⚔️ Round {enc['round']} — {name}'s turn")
        else:
            self.combat_log.emit(f"→ {name}'s turn")

    def roll_initiatives(self):
        self.table.blockSignals(True)
        for r in range(self.table.rowCount()):
            b = self.table.item(r, 0).data(Qt.ItemDataRole.UserRole) or 0
            self.table.item(r, 1).setText(str(random.randint(1, 20) + b))
        self.table.blockSignals(False)
        self._sort_and_refresh()
        if self.table.rowCount() > 0:
            parts = []
            for r in range(self.table.rowCount()):
                n = self.table.item(r, 0).text() if self.table.item(r, 0) else "?"
                i = self.table.item(r, 1).text() if self.table.item(r, 1) else "?"
                parts.append(f"{n} ({i})")
            self.combat_log.emit("🎲 Initiative rolled: " + ", ".join(parts))

    def _sort_and_refresh(self):
        if not self.current_encounter_id:
            return
        enc = self.encounters[self.current_encounter_id]
        cur_tid = self._combatant_list.get_tid_at_turn_index(enc["turn_index"])
        self._combatant_list.sort_by_initiative()
        if cur_tid:
            new_row = self._combatant_list.find_row_for_tid(cur_tid)
            if new_row >= 0:
                enc["turn_index"] = new_row
        self._combatant_list.update_highlights(enc["turn_index"])
        self.refresh_battle_map()
        if not self._combatant_list._loading:
            self.data_changed_signal.emit()

    def update_highlights(self):
        """Public compat: delegates to the list widget."""
        if self.current_encounter_id and self.current_encounter_id in self.encounters:
            self._combatant_list.update_highlights(
                self.encounters[self.current_encounter_id]["turn_index"]
            )

    # ------------------------------------------------------------------
    # State persistence
    # ------------------------------------------------------------------

    def _save_current_state_to_memory(self):
        if not self.current_encounter_id or self.current_encounter_id not in self.encounters:
            return
        enc = self.encounters[self.current_encounter_id]
        rows = self._combatant_list.get_rows_data()
        for row in rows:
            tid = row.get("tid")
            pos = enc["token_positions"].get(tid, (None, None))
            row["x"] = pos[0]
            row["y"] = pos[1]
        enc["combatants"] = rows

    def refresh_ui_from_current_encounter(self):
        if not self.current_encounter_id or self.current_encounter_id not in self.encounters:
            self._combatant_list.clear_rows()
            return
        self._combatant_list.set_loading(True)
        self.table.blockSignals(True)
        self._combatant_list.clear_rows()
        enc = self.encounters[self.current_encounter_id]
        self._controls.update_round(enc.get("round", 1))
        for c in enc.get("combatants", []):
            tid = c.get("tid") or str(uuid.uuid4())
            if c.get("x") is not None:
                enc["token_positions"][tid] = (float(c["x"]), float(c["y"]))
            self._combatant_list.add_direct_row(
                c["name"], c["init"], c["ac"], c["hp"],
                c.get("conditions", []), c["eid"], c.get("bonus", 0), tid,
            )
        self._sort_and_refresh()
        self.table.blockSignals(False)
        self._combatant_list.set_loading(False)

    def get_session_state(self):
        self._save_current_state_to_memory()
        return self._model.to_dict()

    def load_session_state(self, d):
        self._combatant_list.set_loading(True)
        self._model.load(d)
        self._controls.rebuild_encounter_combo(self.encounters, self.current_encounter_id)
        self.refresh_ui_from_current_encounter()
        self._combatant_list.set_loading(False)

    def load_combat_data(self, data):
        self.load_session_state({"combatants": data})

    def clear_tracker(self):
        if not self.current_encounter_id or self.current_encounter_id not in self.encounters:
            return
        enc = self.encounters[self.current_encounter_id]
        self._combatant_list.clear_rows()
        enc["combatants"] = []
        enc["token_positions"] = {}
        enc["turn_index"] = -1
        enc["round"] = 1
        enc["map_path"] = None
        self._controls.update_round(1)
        self.refresh_battle_map(force_map_reload=True)
        if not self._combatant_list._loading:
            self.data_changed_signal.emit()

    def _on_list_data_modified(self):
        self._save_current_state_to_memory()
        self.refresh_battle_map()
        self.data_changed_signal.emit()

    # Condition menu forwarded from old call sites
    def add_condition_to_row(self, row, name, icon_path, duration):
        self._combatant_list.add_condition_to_row(row, name, icon_path, duration)

    def open_condition_menu_for_widget(self, widget):
        self._combatant_list.open_condition_menu_for_widget(widget)

    def open_context_menu(self, pos):
        self._combatant_list.open_context_menu(pos)

    # ------------------------------------------------------------------
    # Battle map integration
    # ------------------------------------------------------------------

    def load_map_dialog(self):
        if not self.current_encounter_id or self.current_encounter_id not in self.encounters:
            return
        enc = self.encounters[self.current_encounter_id]
        d = MapSelectorDialog(self.dm, self)
        if d.exec():
            if d.is_new_import:
                f, _ = QFileDialog.getOpenFileName(
                    self, "Select", "",
                    "Media (*.png *.jpg *.jpeg *.mp4 *.webm *.mkv *.m4v *.avi)"
                )
                if f:
                    enc["map_path"] = self.dm.import_image(f)
            elif d.selected_file:
                enc["map_path"] = d.selected_file
            self.data_changed_signal.emit()
            if self._bridge.is_open():
                self.refresh_battle_map(force_map_reload=True)

    def open_battle_map(self):
        self._bridge.open()
        self.refresh_battle_map(force_map_reload=True)

    def on_token_moved_in_map(self, tid, x, y):
        if self.current_encounter_id:
            self.encounters[self.current_encounter_id]["token_positions"][tid] = (x, y)
            self.data_changed_signal.emit()
            if self._bridge.is_open():
                self.refresh_battle_map(force_map_reload=False)

    def on_token_size_changed(self, v):
        if self.current_encounter_id:
            self.encounters[self.current_encounter_id]["token_size"] = v
            self.data_changed_signal.emit()
            if self._bridge.is_open():
                self.refresh_battle_map(force_map_reload=False)

    def on_token_size_override_changed(self, tid: str, size: int):
        if self.current_encounter_id:
            enc = self.encounters[self.current_encounter_id]
            enc.setdefault("token_size_overrides", {})[tid] = size
            self.data_changed_signal.emit()

    def on_grid_settings_changed(self, grid_size: int, grid_visible: bool, grid_snap: bool, feet_per_cell: int):
        if not self.current_encounter_id or self.current_encounter_id not in self.encounters:
            return
        enc = self.encounters[self.current_encounter_id]
        changed = False
        for key, val in [
            ("grid_size", grid_size),
            ("grid_visible", grid_visible),
            ("grid_snap", grid_snap),
            ("feet_per_cell", feet_per_cell),
        ]:
            if enc.get(key, {"grid_size": 50, "grid_visible": False, "grid_snap": False, "feet_per_cell": 5}[key]) != val:
                enc[key] = val
                changed = True
        if not changed:
            return
        self.data_changed_signal.emit()
        if self._bridge.is_open():
            self.refresh_battle_map(force_map_reload=False)

    def refresh_battle_map(self, force_map_reload=False):
        if not self.current_encounter_id or self.current_encounter_id not in self.encounters:
            return
        enc = self.encounters[self.current_encounter_id]
        self._save_current_state_to_memory()
        mp = self.dm.get_full_path(enc.get("map_path"))
        cd = []
        for c in enc["combatants"]:
            t = "NPC"
            a = "LBL_ATTR_NEUTRAL"
            if c["eid"] in self.dm.data["entities"]:
                e = self.dm.data["entities"][c["eid"]]
                t = e.get("type", "NPC")
                a = e.get("attributes", {}).get("LBL_ATTITUDE", "LBL_ATTR_NEUTRAL")
                if t == "Monster":
                    a = "LBL_ATTR_HOSTILE"
            c["type"] = t
            c["attitude"] = a
            cd.append(c)
        self._bridge.update_combat_data(
            cd, enc["turn_index"], mp, enc["token_size"],
            fog_data=enc.get("fog_data"),
            token_size_overrides=enc.get("token_size_overrides", {}),
            grid_size=enc.get("grid_size", 50),
            grid_visible=enc.get("grid_visible", False),
            grid_snap=enc.get("grid_snap", False),
            feet_per_cell=enc.get("feet_per_cell", 5),
            annotation_data=enc.get("annotation_data"),
        )

    def sync_map_view_to_external(self, rect):
        self._bridge.sync_view(rect)

    def sync_fog_to_external(self, qimage):
        self._bridge.sync_fog(qimage)

    def sync_annotation_to_external(self, qimage):
        self._bridge.sync_annotation(qimage)

    def sync_measurement_to_external(self, qimage):
        self._bridge.sync_measurement(qimage)

    # ------------------------------------------------------------------
    # Compat: expose combo/label directly used by some callers
    # ------------------------------------------------------------------

    @property
    def combo_encounters(self):
        return self._controls.combo_encounters

    @property
    def lbl_round(self):
        return self._controls.lbl_round

    @property
    def btn_next_turn(self):
        return self._controls.btn_next_turn

    @property
    def btn_add(self):
        return self._controls.btn_add

    @property
    def btn_add_players(self):
        return self._controls.btn_add_players

    @property
    def btn_roll(self):
        return self._controls.btn_roll

    @property
    def btn_clear_all(self):
        return self._controls.btn_clear_all

    @property
    def inp_quick_name(self):
        return self._controls.inp_quick_name

    @property
    def inp_quick_init(self):
        return self._controls.inp_quick_init

    @property
    def inp_quick_hp(self):
        return self._controls.inp_quick_hp

    @property
    def btn_quick_add(self):
        return self._controls.btn_quick_add

    @property
    def btn_new_enc(self):
        return self._controls.btn_new_enc

    @property
    def btn_rename_enc(self):
        return self._controls.btn_rename_enc

    @property
    def btn_del_enc(self):
        return self._controls.btn_del_enc
