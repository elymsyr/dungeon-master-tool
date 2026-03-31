"""CombatantListWidget — table view for combat combatants.

Manages the DraggableCombatTable and all per-row interactions:
adding/removing rows, HP bar changes, condition widgets, context menu,
drop import, row highlighting, and theme propagation.

CombatTracker wires this widget's signals into model/bridge logic.
"""

import logging
import os
import uuid

from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtGui import QAction, QBrush, QColor, QCursor, QIcon
from PyQt6.QtWidgets import (
    QInputDialog,
    QMenu,
    QMessageBox,
    QWidget,
    QVBoxLayout,
)

from core.locales import tr
from core.theme_manager import ThemeManager
from ui.widgets.combat_table import (
    ConditionsWidget,
    DraggableCombatTable,
    HpBarWidget,
    NumericTableWidgetItem,
)

logger = logging.getLogger(__name__)

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
    "Exhaustion": "COND_EXHAUSTION",
}


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


class CombatantListWidget(QWidget):
    """Table-centric widget for the combat combatant list.

    Signals
    -------
    row_selected(str)       — eid or "" when selection changes
    data_modified()         — any non-sort table change (triggers autosave)
    sort_needed()           — initiative column changed; caller should sort
    hp_log(str)             — formatted HP-change log message
    condition_log(str)      — formatted condition log message
    drop_accepted(str)      — entity eid dropped from sidebar
    view_entity_requested() — "View Stats" context menu action
    """

    row_selected = pyqtSignal(str)
    data_modified = pyqtSignal()
    sort_needed = pyqtSignal()
    hp_log = pyqtSignal(str)
    condition_log = pyqtSignal(str)
    drop_accepted = pyqtSignal(str)
    view_entity_requested = pyqtSignal()

    def __init__(self, data_manager, parent=None):
        super().__init__(parent)
        self.dm = data_manager
        self._loading = False
        self.current_palette = ThemeManager.get_palette(self.dm.current_theme)
        self._init_ui()

    # ------------------------------------------------------------------
    # UI setup
    # ------------------------------------------------------------------

    def _init_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        self.table = DraggableCombatTable()
        self.table.setColumnCount(5)
        self.table.setHorizontalHeaderLabels([
            tr("HEADER_NAME"), tr("HEADER_INIT"), tr("HEADER_AC"),
            tr("HEADER_HP"), tr("HEADER_COND"),
        ])
        from PyQt6.QtWidgets import QHeaderView, QTableWidget
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        self.table.horizontalHeader().setSectionResizeMode(4, QHeaderView.ResizeMode.Stretch)
        self.table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self.table.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.table.customContextMenuRequested.connect(self.open_context_menu)
        self.table.itemChanged.connect(self._on_item_changed)
        self.table.cellDoubleClicked.connect(self._on_cell_double_clicked)
        self.table.setSortingEnabled(False)
        self.table.entity_dropped.connect(self.handle_drop_import)
        self.table.itemSelectionChanged.connect(self._on_row_selection_changed)

        layout.addWidget(self.table)

    # ------------------------------------------------------------------
    # Public API (called by CombatTracker)
    # ------------------------------------------------------------------

    def set_loading(self, value: bool) -> None:
        self._loading = value

    def row_count(self) -> int:
        return self.table.rowCount()

    def add_direct_row(self, name, init, ac, hp, conditions_data, eid, init_bonus=0, tid=None):
        """Insert one combatant row with HP bar and conditions widget."""
        if not tid:
            tid = str(uuid.uuid4())
        from PyQt6.QtWidgets import QTableWidgetItem
        self.table.blockSignals(True)
        row = self.table.rowCount()
        self.table.insertRow(row)

        self.table.setItem(row, 0, QTableWidgetItem(name))

        it_init = NumericTableWidgetItem(str(init))
        it_init.setData(Qt.ItemDataRole.UserRole, eid)
        it_init.setData(Qt.ItemDataRole.UserRole + 1, tid)
        self.table.setItem(row, 1, it_init)

        self.table.setItem(row, 2, NumericTableWidgetItem(str(_clean_stat_value(ac))))

        cur = _clean_stat_value(hp)
        mx = cur
        if eid and eid in self.dm.data["entities"]:
            try:
                db_max = _clean_stat_value(
                    self.dm.data["entities"][eid]["combat_stats"]["max_hp"]
                )
                mx = db_max if db_max >= cur else cur
            except (KeyError, ValueError, TypeError):
                pass

        hp_w = HpBarWidget(cur, mx, self.current_palette)
        hp_w.hpChanged.connect(lambda v, w=hp_w: self._on_widget_hp_changed(w, v))
        self.table.setCellWidget(row, 3, hp_w)
        self.table.setItem(row, 3, NumericTableWidgetItem(str(cur)))

        cond_w = ConditionsWidget()
        cond_w.update_theme(self.current_palette)
        cond_w.clicked.connect(lambda w=cond_w: self.open_condition_menu_for_widget(w))

        if isinstance(conditions_data, str) and conditions_data:
            conditions_data = [
                {"name": c.strip(), "icon": None, "duration": 0, "max_duration": 0}
                for c in conditions_data.split(",")
            ]
        elif not isinstance(conditions_data, list):
            conditions_data = []

        cond_w.set_conditions(conditions_data)
        cond_w.conditionsChanged.connect(self.data_modified.emit)
        cond_w.conditionRemoved.connect(lambda n, w=cond_w: self._on_condition_removed(w, n))
        self.table.setCellWidget(row, 4, cond_w)

        self.table.blockSignals(False)
        self.data_modified.emit()

    def delete_row(self, row: int) -> None:
        self.table.removeRow(row)

    def clear_rows(self) -> None:
        self.table.setRowCount(0)

    def sort_by_initiative(self) -> None:
        self.table.blockSignals(True)
        self.table.sortItems(1, Qt.SortOrder.DescendingOrder)
        self.table.blockSignals(False)

    def get_tid_at_turn_index(self, turn_index: int):
        """Return the tid stored in the initiative cell at *turn_index*."""
        item = self.table.item(turn_index, 1)
        return item.data(Qt.ItemDataRole.UserRole + 1) if item else None

    def find_row_for_tid(self, tid) -> int:
        """Return the row index that holds *tid*, or -1 if not found."""
        for r in range(self.table.rowCount()):
            item = self.table.item(r, 1)
            if item and item.data(Qt.ItemDataRole.UserRole + 1) == tid:
                return r
        return -1

    def tick_conditions_at(self, row: int) -> None:
        w = self.table.cellWidget(row, 4)
        if w:
            w.tick_conditions()

    def update_highlights(self, turn_index: int) -> None:
        """Highlight the active turn row; clear all other rows."""
        active_color = QColor(self.current_palette.get("token_border_active", "#ffb74d"))
        active_color.setAlpha(100)
        brush = QBrush(active_color)

        self.table.blockSignals(True)
        for r in range(self.table.rowCount()):
            for c in range(self.table.columnCount()):
                item = self.table.item(r, c)
                if item:
                    item.setBackground(QBrush(Qt.BrushStyle.NoBrush))
        if 0 <= turn_index < self.table.rowCount():
            for c in range(self.table.columnCount()):
                item = self.table.item(turn_index, c)
                if item:
                    item.setBackground(brush)
        self.table.blockSignals(False)

    def get_rows_data(self) -> list[dict]:
        """Extract all row data for state persistence."""
        rows = []
        for r in range(self.table.rowCount()):
            if not self.table.item(r, 0):
                continue

            def _text(col, default=""):
                item = self.table.item(r, col)
                return item.text() if item else default

            hp_w = self.table.cellWidget(r, 3)
            cond_w = self.table.cellWidget(r, 4)
            item_init = self.table.item(r, 1)
            tid = item_init.data(Qt.ItemDataRole.UserRole + 1) if item_init else None
            eid = item_init.data(Qt.ItemDataRole.UserRole) if item_init else None
            if not tid:
                tid = str(uuid.uuid4())

            rows.append({
                "tid": str(tid),
                "eid": str(eid) if eid else None,
                "name": _text(0, "???"),
                "init": _text(1, "0"),
                "ac": _text(2, "10"),
                "hp": str(hp_w.current) if hp_w else "0",
                "conditions": cond_w.active_conditions if cond_w else [],
                "bonus": 0,
            })
        return rows

    def refresh_theme(self, palette: dict) -> None:
        self.current_palette = palette
        for row in range(self.table.rowCount()):
            hp_w = self.table.cellWidget(row, 3)
            if hp_w and isinstance(hp_w, HpBarWidget):
                hp_w.update_theme(palette)
            cond_w = self.table.cellWidget(row, 4)
            if cond_w and isinstance(cond_w, ConditionsWidget):
                cond_w.update_theme(palette)

    def retranslate_ui(self) -> None:
        self.table.setHorizontalHeaderLabels([
            tr("HEADER_NAME"), tr("HEADER_INIT"), tr("HEADER_AC"),
            tr("HEADER_HP"), tr("HEADER_COND"),
        ])

    # ------------------------------------------------------------------
    # Table event handlers
    # ------------------------------------------------------------------

    def _on_row_selection_changed(self):
        row = self.table.currentRow()
        if row < 0:
            self.row_selected.emit("")
            return
        init_item = self.table.item(row, 1)
        eid = init_item.data(Qt.ItemDataRole.UserRole) if init_item else ""
        self.row_selected.emit(eid or "")

    def _on_item_changed(self, item):
        if self._loading:
            return
        if item.column() == 1:
            self.sort_needed.emit()
        else:
            self.data_modified.emit()

    def _on_cell_double_clicked(self, r, c):
        if c == 3:
            w = self.table.cellWidget(r, 3)
            if w:
                v, ok = QInputDialog.getInt(
                    self, tr("TITLE_EDIT_HP"), tr("LBL_NEW_HP"), w.current, 0, 9999
                )
                if ok:
                    w.update_hp(v)

    def _on_widget_hp_changed(self, widget, val):
        idx = self.table.indexAt(widget.pos())
        if not idx.isValid():
            return
        row = idx.row()
        name_item = self.table.item(row, 0)
        name = name_item.text() if name_item else ""
        old_hp_item = self.table.item(row, 3)
        try:
            old_hp = int(old_hp_item.text()) if old_hp_item else val
        except (ValueError, TypeError):
            old_hp = val
        self.table.item(row, 3).setText(str(val))
        self.data_modified.emit()
        if name and old_hp != val:
            delta = val - old_hp
            if delta < 0:
                self.hp_log.emit(f"💔 {name}: {old_hp} → {val} HP ({delta})")
            else:
                self.hp_log.emit(f"💚 {name}: {old_hp} → {val} HP (+{delta})")
            if val <= 0:
                self.hp_log.emit(f"💀 {name} is defeated!")

    # ------------------------------------------------------------------
    # Context menus
    # ------------------------------------------------------------------

    def open_condition_menu_for_widget(self, widget):
        index = self.table.indexAt(widget.pos())
        if not index.isValid():
            return
        row = index.row()
        menu = QMenu(self)
        p = self.current_palette
        menu.setStyleSheet(
            f"QMenu {{ background-color: {p.get('ui_floating_bg', '#333')}; "
            f"color: {p.get('ui_floating_text', '#eee')}; "
            f"border: 1px solid {p.get('ui_floating_border', '#555')}; }} "
            f"QMenu::item:selected {{ background-color: {p.get('line_selected', '#007acc')}; }}"
        )
        std_menu = menu.addMenu(tr("MENU_STD_CONDITIONS"))
        for en_key, trans_key in CONDITIONS_MAP.items():
            action = QAction(tr(trans_key), self)
            action.triggered.connect(
                lambda checked, r=row, n=en_key: self.add_condition_to_row(r, n, None, 0)
            )
            std_menu.addAction(action)

        menu.addSeparator()
        custom_effects = [
            e for e in self.dm.data["entities"].values() if e.get("type") == "Status Effect"
        ]
        if custom_effects:
            lbl = menu.addAction(tr("MENU_SAVED_EFFECTS"))
            lbl.setEnabled(False)
            for eff in custom_effects:
                eff_name = eff.get("name", "Unknown")
                icon_path = None
                if eff.get("images"):
                    full_path = self.dm.get_full_path(eff["images"][0])
                    if full_path and os.path.exists(full_path):
                        icon_path = full_path
                try:
                    duration = int(eff.get("attributes", {}).get("LBL_DURATION_TURNS", 0))
                except (ValueError, TypeError):
                    duration = 0
                action = QAction(eff_name, self)
                if icon_path:
                    action.setIcon(QIcon(icon_path))
                action.triggered.connect(
                    lambda checked, r=row, n=eff_name, ip=icon_path, d=duration:
                    self.add_condition_to_row(r, n, ip, d)
                )
                menu.addAction(action)
        else:
            no_act = menu.addAction(tr("MSG_NO_SAVED_EFFECTS"))
            no_act.setEnabled(False)

        menu.exec(QCursor.pos())

    def open_context_menu(self, pos):
        row = self.table.rowAt(pos.y())
        if row == -1:
            return
        self.table.selectRow(row)
        menu = QMenu()
        init_item = self.table.item(row, 1)
        eid = init_item.data(Qt.ItemDataRole.UserRole) if init_item else None
        p = self.current_palette
        menu.setStyleSheet(
            f"QMenu {{ background-color: {p.get('ui_floating_bg', '#333')}; "
            f"color: {p.get('ui_floating_text', '#eee')}; "
            f"border: 1px solid {p.get('ui_floating_border', '#555')}; }}"
        )
        if eid and eid in self.dm.data["entities"]:
            view_act = QAction("👁 " + tr("MENU_VIEW_STATS"), self)
            view_act.triggered.connect(self.view_entity_requested.emit)
            menu.addAction(view_act)
            menu.addSeparator()

        add_cond_menu = menu.addMenu("🩸 " + tr("MENU_ADD_COND"))
        for en_key, trans_key in CONDITIONS_MAP.items():
            a = QAction(tr(trans_key), self)
            a.triggered.connect(
                lambda ch, n=en_key: self.add_condition_to_row(row, n, None, 0)
            )
            add_cond_menu.addAction(a)

        add_cond_menu.addSeparator()
        custom_effects = [
            e for e in self.dm.data["entities"].values() if e.get("type") == "Status Effect"
        ]
        for eff in custom_effects:
            icon_path = (
                self.dm.get_full_path(eff["images"][0]) if eff.get("images") else None
            )
            try:
                d = int(eff.get("attributes", {}).get("LBL_DURATION_TURNS", 0))
            except (ValueError, TypeError):
                d = 0
            a = QAction(eff["name"], self)
            if icon_path:
                a.setIcon(QIcon(icon_path))
            a.triggered.connect(
                lambda ch, n=eff["name"], ip=icon_path, dv=d:
                self.add_condition_to_row(row, n, ip, dv)
            )
            add_cond_menu.addAction(a)

        menu.addSeparator()
        del_act = QAction("❌ " + tr("MENU_REMOVE_COMBAT"), self)
        del_act.triggered.connect(lambda: self.delete_row(row))
        del_act.triggered.connect(self.data_modified.emit)
        menu.addAction(del_act)
        menu.exec(self.table.viewport().mapToGlobal(pos))

    def add_condition_to_row(self, row, name, icon_path, duration):
        if duration == 0:
            d, ok = QInputDialog.getInt(
                self, tr("LBL_DURATION_PROMPT_TITLE"),
                tr("LBL_DURATION_PROMPT_MSG", name=name), 0, 0, 100
            )
            if ok:
                duration = d
        w = self.table.cellWidget(row, 4)
        if w:
            w.add_condition(name, icon_path, duration)
            name_item = self.table.item(row, 0)
            combatant_name = name_item.text() if name_item else "?"
            self.condition_log.emit(f"🔵 {combatant_name}: {name} applied")

    def _on_condition_removed(self, cond_widget, condition_name):
        idx = self.table.indexAt(cond_widget.pos())
        if idx.isValid():
            name_item = self.table.item(idx.row(), 0)
            combatant_name = name_item.text() if name_item else "?"
            self.condition_log.emit(f"🟢 {combatant_name}: {condition_name} removed")

    # ------------------------------------------------------------------
    # Drop import
    # ------------------------------------------------------------------

    def handle_drop_import(self, eid: str):
        if eid.startswith("lib_"):
            QMessageBox.information(self, tr("MSG_INFO"), tr("MSG_DROP_IMPORT_FIRST"))
            return
        if eid in self.dm.data["entities"]:
            ent = self.dm.data["entities"][eid]
            if ent.get("type") in ["NPC", "Monster", "Player"]:
                self.drop_accepted.emit(eid)
