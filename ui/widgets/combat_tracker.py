"""CombatTracker — encounter management widget for the Session tab.

This widget is now a thin orchestrator:
  - Creates CombatModel, BattleMapBridge, view sub-widgets, and CombatPresenter
  - Delegates all business logic to CombatPresenter
  - Preserves the same public API for backward compatibility
"""

import logging

from PyQt6.QtCore import pyqtSignal
from PyQt6.QtWidgets import QVBoxLayout, QWidget

from core.theme_manager import ThemeManager
from ui.presenters.combat_presenter import CombatPresenter
from ui.widgets.battle_map_bridge import BattleMapBridge
from ui.widgets.combat_combatant_list import CombatantListWidget
from ui.widgets.combat_controls import CombatControlsWidget
from ui.widgets.combat_model import CombatModel

logger = logging.getLogger(__name__)


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
        self.current_palette = ThemeManager.get_palette(self.dm.current_theme)
        self._model.create_encounter("Default Encounter")
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

    @property
    def table(self):
        return self._combatant_list.table

    # ------------------------------------------------------------------
    # UI setup
    # ------------------------------------------------------------------

    def init_ui(self) -> None:
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(4)

        self._controls = CombatControlsWidget()
        self._combatant_list = CombatantListWidget(self.dm)

        layout.addWidget(self._controls)
        layout.addWidget(self._combatant_list, stretch=1)

        self._presenter = CombatPresenter(
            self._model, self._controls, self._combatant_list,
            self.dm, self._bridge, parent=self,
        )

        # Bridge → presenter
        self._bridge.token_moved.connect(self._presenter.on_token_moved_in_map)
        self._bridge.token_size_changed.connect(self._presenter.on_token_size_changed)
        self._bridge.token_size_override_changed.connect(
            self._presenter.on_token_size_override_changed
        )

        # Presenter → our own signals (forward)
        self._presenter.data_changed.connect(self.data_changed_signal)
        self._presenter.combat_log.connect(self.combat_log)
        self._presenter.combatant_selected.connect(self.combatant_selected)
        self._presenter.view_entity_requested.connect(self.view_entity_requested)

        self._presenter.refresh_encounter_combo()

    # ------------------------------------------------------------------
    # Theme & retranslation
    # ------------------------------------------------------------------

    def refresh_theme(self, palette) -> None:
        self.current_palette = palette
        self._combatant_list.refresh_theme(palette)
        self._combatant_list.update_highlights(
            self.encounters.get(self.current_encounter_id, {}).get("turn_index", -1)
            if self.current_encounter_id else -1
        )

    def retranslate_ui(self) -> None:
        self._controls.retranslate_ui()
        self._combatant_list.retranslate_ui()
        if self.current_encounter_id and self.current_encounter_id in self.encounters:
            self._controls.update_round(
                self.encounters[self.current_encounter_id].get("round", 1)
            )
        self._bridge.retranslate()
        if self._bridge.is_open():
            self._presenter.refresh_battle_map()

    # ------------------------------------------------------------------
    # Public API — all delegate to presenter
    # ------------------------------------------------------------------

    def set_fog_save_handler(self, handler) -> None:
        self._presenter.set_fog_save_handler(handler)

    def create_encounter(self, name: str) -> str:
        return self._model.create_encounter(name)

    def refresh_encounter_combo(self) -> None:
        self._presenter.refresh_encounter_combo()

    def add_direct_row(self, name, init, ac, hp, conditions_data, eid, init_bonus=0, tid=None) -> None:
        self._presenter.add_direct_row(name, init, ac, hp, conditions_data, eid, init_bonus, tid)

    def add_combatant_dialog(self) -> None:
        self._presenter.add_combatant_dialog()

    def add_row_from_entity(self, eid: str) -> None:
        self._presenter.add_row_from_entity(eid)

    def add_all_players(self) -> None:
        self._presenter.add_all_players()

    def delete_row(self, row: int) -> None:
        self._presenter.delete_row(row)

    def quick_add(self) -> None:
        self._presenter.quick_add()

    def next_turn(self) -> None:
        self._presenter.next_turn()

    def roll_initiatives(self) -> None:
        self._presenter.roll_initiatives()

    def update_highlights(self) -> None:
        self._presenter.update_highlights()

    def get_session_state(self) -> dict:
        return self._presenter.get_session_state()

    def load_session_state(self, d: dict) -> None:
        self._presenter.load_session_state(d)

    def load_combat_data(self, data) -> None:
        self._presenter.load_combat_data(data)

    def clear_tracker(self) -> None:
        self._presenter.clear_tracker()

    def refresh_ui_from_current_encounter(self) -> None:
        self._presenter.refresh_ui_from_current_encounter()

    def refresh_battle_map(self, force_map_reload=False) -> None:
        self._presenter.refresh_battle_map(force_map_reload=force_map_reload)

    def load_map_dialog(self) -> None:
        self._presenter.load_map_dialog()

    def open_battle_map(self) -> None:
        self._presenter.open_battle_map()

    def on_token_moved_in_map(self, tid, x, y) -> None:
        self._presenter.on_token_moved_in_map(tid, x, y)

    def on_token_size_changed(self, v) -> None:
        self._presenter.on_token_size_changed(v)

    def on_grid_settings_changed(
        self, grid_size: int, grid_visible: bool, grid_snap: bool, feet_per_cell: int
    ) -> None:
        self._presenter.on_grid_settings_changed(grid_size, grid_visible, grid_snap, feet_per_cell)

    def sync_map_view_to_external(self, rect) -> None:
        self._presenter.sync_map_view_to_external(rect)

    def sync_fog_to_external(self, qimage) -> None:
        self._presenter.sync_fog_to_external(qimage)

    def sync_annotation_to_external(self, qimage) -> None:
        self._presenter.sync_annotation_to_external(qimage)

    def sync_measurement_to_external(self, qimage) -> None:
        self._presenter.sync_measurement_to_external(qimage)

    def add_condition_to_row(self, row, name, icon_path, duration) -> None:
        self._presenter.add_condition_to_row(row, name, icon_path, duration)

    def open_condition_menu_for_widget(self, widget) -> None:
        self._presenter.open_condition_menu_for_widget(widget)

    def open_context_menu(self, pos) -> None:
        self._presenter.open_context_menu(pos)

    def switch_encounter(self, idx: int) -> None:
        self._presenter.switch_encounter(idx)

    def rename_encounter(self) -> None:
        self._presenter.rename_encounter()

    def delete_encounter(self) -> None:
        self._presenter.delete_encounter()

    def prompt_new_encounter(self) -> None:
        self._presenter.prompt_new_encounter()

    # ------------------------------------------------------------------
    # Compat: expose sub-widget attributes directly
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
