"""LinkedEntityWidget — widget for attaching linked entities (spells, items).

Manages a list of entity IDs linked to the current entity.
Displays entity names from the DataManager's entity dict.
"""

import logging

from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import (
    QComboBox,
    QGroupBox,
    QHBoxLayout,
    QListWidget,
    QListWidgetItem,
    QPushButton,
    QStyle,
    QVBoxLayout,
    QWidget,
)

from core.locales import tr

logger = logging.getLogger(__name__)


class LinkedEntityWidget(QWidget):
    """Widget for linking entities of a given type (e.g. Spell, Equipment).

    Responsibilities:
    - Show a searchable combo of available entities.
    - Append selected entity IDs to the linked list (no duplicates).
    - Remove selected entry from the list.
    - Emit double-click to open a linked entity.
    """

    def __init__(
        self,
        data_manager,
        entity_type: str,
        group_title: str,
        search_placeholder: str,
        open_entity_callback=None,
        parent=None,
    ):
        """
        Args:
            data_manager: DataManager instance.
            entity_type: The entity type to filter ('Spell', 'Equipment', …).
            group_title: Title shown on the QGroupBox.
            search_placeholder: Placeholder text for the search combo.
            open_entity_callback: Callable(eid: str) invoked on double-click.
        """
        super().__init__(parent)
        self._dm = data_manager
        self._entity_type = entity_type
        self._open_cb = open_entity_callback
        self._linked_ids: list[str] = []
        self._group_title = group_title
        self._search_placeholder = search_placeholder
        self._build_ui()

    # ------------------------------------------------------------------
    # UI construction
    # ------------------------------------------------------------------

    def _build_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        grp = QGroupBox(self._group_title)
        v = QVBoxLayout(grp)

        h = QHBoxLayout()
        self.combo_all = QComboBox()
        self.combo_all.setEditable(True)
        self.combo_all.setPlaceholderText(self._search_placeholder)

        self.btn_add = QPushButton(tr("BTN_ADD"))
        self.btn_add.setObjectName("successBtn")
        self.btn_add.clicked.connect(self._on_add)

        h.addWidget(self.combo_all, 3)
        h.addWidget(self.btn_add, 1)
        v.addLayout(h)

        self.list_assigned = QListWidget()
        self.list_assigned.setAlternatingRowColors(True)
        self.list_assigned.setMinimumHeight(200)
        self.list_assigned.itemDoubleClicked.connect(self._on_dbl_click)
        v.addWidget(self.list_assigned)

        self.btn_remove = QPushButton(tr("BTN_REMOVE"))
        self.btn_remove.setIcon(
            self.style().standardIcon(QStyle.StandardPixmap.SP_TrashIcon)
        )
        self.btn_remove.setObjectName("dangerBtn")
        self.btn_remove.clicked.connect(self._on_remove)
        v.addWidget(self.btn_remove)

        layout.addWidget(grp)

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def populate_available(self) -> None:
        """Populate the combo box with entities matching ``_entity_type``."""
        self.combo_all.clear()
        for eid, ent in self._dm.data["entities"].items():
            if ent.get("type") != self._entity_type:
                continue
            name = ent.get("name", tr("NAME_UNNAMED"))
            extra = self._format_extra(ent)
            self.combo_all.addItem(f"{name}{extra}", eid)

    def set_linked_ids(self, ids: list[str]) -> None:
        """Load the linked IDs and refresh the list widget."""
        self._linked_ids = list(ids)
        self._render_list()

    def get_linked_ids(self) -> list[str]:
        """Return the current list of linked entity IDs."""
        return list(self._linked_ids)

    # ------------------------------------------------------------------
    # Slots
    # ------------------------------------------------------------------

    def _on_add(self) -> None:
        eid = self.combo_all.currentData()
        if not eid:
            return
        if eid not in self._linked_ids:
            self._linked_ids.append(eid)
            self._render_list()

    def _on_remove(self) -> None:
        row = self.list_assigned.currentRow()
        if row >= 0:
            del self._linked_ids[row]
            self.list_assigned.takeItem(row)

    def _on_dbl_click(self, item: QListWidgetItem) -> None:
        eid = item.data(Qt.ItemDataRole.UserRole)
        if eid and self._open_cb:
            self._open_cb(eid)

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _format_extra(self, ent: dict) -> str:
        if self._entity_type == "Spell":
            level = ent.get("attributes", {}).get("LBL_LEVEL", "?")
            return f" (Lv {level})"
        if self._entity_type == "Equipment":
            cat = ent.get("attributes", {}).get(
                "LBL_CATEGORY", tr("CAT_EQUIPMENT")
            )
            return f" ({cat})"
        return ""

    def _render_list(self) -> None:
        self.list_assigned.clear()
        for eid in self._linked_ids:
            ent = self._dm.data["entities"].get(eid)
            name = (
                ent.get("name", tr("NAME_UNKNOWN")) if ent else tr("LBL_REMOVED_ITEM")
            )
            extra = self._format_extra(ent) if ent else ""
            item = QListWidgetItem(f"{name}{extra}")
            item.setData(Qt.ItemDataRole.UserRole, eid)
            self.list_assigned.addItem(item)
