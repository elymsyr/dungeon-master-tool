"""LinkedEntityWidget — widget for attaching linked entities (spells, items).

Manages a list of entity IDs linked to the current entity.
Displays entity names from the DataManager's entity dict.
"""

import logging

from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtWidgets import (
    QAbstractScrollArea,
    QComboBox,
    QFrame,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QListWidget,
    QListWidgetItem,
    QPushButton,
    QSizePolicy,
    QStyle,
    QVBoxLayout,
    QWidget,
)

from core.locales import tr
from core.models import ENTITY_SCHEMAS
from core.theme_manager import ThemeManager

logger = logging.getLogger(__name__)


class LinkedEntityWidget(QWidget):
    """Widget for linking entities of a given type (e.g. Spell, Equipment).

    Responsibilities:
    - Show a searchable combo of available entities.
    - Append selected entity IDs to the linked list (no duplicates).
    - Remove selected entry from the list.
    - Emit double-click to open a linked entity.
    - Optionally support inline custom entries (not in DB).
    """

    linked_ids_changed = pyqtSignal()
    manual_add_requested = pyqtSignal()
    _SPELL_PROPERTY_KEYS = [key for key, _, _ in ENTITY_SCHEMAS.get("Spell", [])]

    @staticmethod
    def _short_preview_text(text: str, max_len: int = 260) -> str:
        cleaned = " ".join(str(text or "").split())
        if not cleaned:
            return "-"
        if len(cleaned) <= max_len:
            return cleaned
        return f"{cleaned[: max_len - 3]}..."

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
        self._custom_entries: list[dict] = []
        self._group_title = group_title
        self._search_placeholder = search_placeholder
        self._palette = ThemeManager.get_palette("dark")
        self._build_ui()

    # ------------------------------------------------------------------
    # UI construction
    # ------------------------------------------------------------------

    def _build_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        grp = QGroupBox(self._group_title)
        grp.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Maximum)
        v = QVBoxLayout(grp)

        h = QHBoxLayout()
        self.btn_manual_add = QPushButton(tr("BTN_MANUAL_ADD"))
        self.btn_manual_add.setObjectName("actionBtn")
        self.btn_manual_add.clicked.connect(self.manual_add_requested.emit)

        self.combo_all = QComboBox()
        self.combo_all.setEditable(True)
        self.combo_all.setPlaceholderText(self._search_placeholder)

        self.btn_add = QPushButton(tr("BTN_ADD"))
        self.btn_add.setObjectName("successBtn")
        self.btn_add.clicked.connect(self._on_add)

        self.btn_import = QPushButton(f"{tr('BTN_IMPORT')}...")
        self.btn_import.setObjectName("primaryBtn")
        self.btn_import.clicked.connect(self._on_import)

        h.addWidget(self.btn_manual_add, 1)
        h.addWidget(self.combo_all, 3)
        h.addWidget(self.btn_add, 1)
        h.addWidget(self.btn_import, 1)
        v.addLayout(h)

        self.list_assigned = QListWidget()
        self.list_assigned.setObjectName("linkedEntityList")
        self.list_assigned.setAlternatingRowColors(False)
        self.list_assigned.setSpacing(6)
        self.list_assigned.setSizeAdjustPolicy(
            QAbstractScrollArea.SizeAdjustPolicy.AdjustToContents
        )
        self.list_assigned.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Maximum
        )
        self.list_assigned.setHorizontalScrollBarPolicy(
            Qt.ScrollBarPolicy.ScrollBarAlwaysOff
        )
        self.list_assigned.setWordWrap(True)
        self.list_assigned.setResizeMode(QListWidget.ResizeMode.Adjust)
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

    def refresh_theme(self, palette: dict) -> None:
        self._palette = palette
        self._render_list()

    def set_edit_mode(self, enabled: bool) -> None:
        """Show/hide add and remove buttons; enable/disable combo in edit mode."""
        self.btn_manual_add.setVisible(enabled)
        self.btn_add.setVisible(enabled)
        self.btn_import.setVisible(enabled)
        self.btn_remove.setVisible(enabled)
        self.combo_all.setEnabled(enabled)

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

    # --- Custom entry API (inline spells not saved to DB) ---

    def add_custom_entry(self, data: dict) -> None:
        """Add an inline custom entry and refresh the list."""
        self._custom_entries.append(data)
        self._render_list()
        self.linked_ids_changed.emit()

    def get_custom_entries(self) -> list[dict]:
        return list(self._custom_entries)

    def set_custom_entries(self, entries: list[dict]) -> None:
        self._custom_entries = list(entries)
        self._render_list()

    def clear_custom_entries(self) -> None:
        self._custom_entries.clear()

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
            self.linked_ids_changed.emit()

    def _on_remove(self) -> None:
        row = self.list_assigned.currentRow()
        if row < 0:
            return
        item = self.list_assigned.item(row)
        data = item.data(Qt.ItemDataRole.UserRole) if item else None
        if isinstance(data, str) and data.startswith("custom:"):
            idx = int(data.split(":", 1)[1])
            if 0 <= idx < len(self._custom_entries):
                del self._custom_entries[idx]
        elif row < len(self._linked_ids):
            del self._linked_ids[row]
        self._render_list()
        self.linked_ids_changed.emit()

    def _on_import(self) -> None:
        # Local import avoids circular module import during startup.
        from ui.dialogs.import_window import ImportWindow

        dlg = ImportWindow(
            self._dm,
            parent=self,
            selection_mode=True,
            default_category=self._entity_type,
            expected_type=self._entity_type,
        )
        if dlg.exec():
            self.merge_linked_ids(dlg.imported_entity_ids)

    def _on_dbl_click(self, item: QListWidgetItem) -> None:
        eid = item.data(Qt.ItemDataRole.UserRole)
        if eid and not str(eid).startswith("custom:") and self._open_cb:
            self._open_cb(eid)

    def merge_linked_ids(self, incoming_ids: list[str]) -> None:
        changed = False
        for eid in incoming_ids:
            if eid and eid not in self._linked_ids:
                self._linked_ids.append(eid)
                changed = True
        if changed:
            self._render_list()
            self.linked_ids_changed.emit()

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
            extra = (
                ""
                if self._entity_type == "Spell"
                else (self._format_extra(ent) if ent else "")
            )
            item = QListWidgetItem()
            item.setData(Qt.ItemDataRole.UserRole, eid)
            self.list_assigned.addItem(item)
            card = self._build_card_widget(name=name, extra=extra, ent=ent)
            item.setSizeHint(card.sizeHint())
            self.list_assigned.setItemWidget(item, card)

        # Render custom (inline) entries after DB-linked ones
        for idx, entry in enumerate(self._custom_entries):
            fake_ent = {
                "name": entry.get("name", ""),
                "description": entry.get("desc", ""),
                "attributes": entry.get("attributes", {}),
            }
            item = QListWidgetItem()
            item.setData(Qt.ItemDataRole.UserRole, f"custom:{idx}")
            self.list_assigned.addItem(item)
            card = self._build_card_widget(
                name=fake_ent["name"] or tr("NAME_UNNAMED"),
                extra="",
                ent=fake_ent,
            )
            item.setSizeHint(card.sizeHint())
            self.list_assigned.setItemWidget(item, card)

        self._fit_list_height()

    def _fit_list_height(self) -> None:
        """Set list height to exactly fit its content rows."""
        count = self.list_assigned.count()
        if count == 0:
            self.list_assigned.setFixedHeight(0)
            return
        total = 0
        spacing = self.list_assigned.spacing()
        for i in range(count):
            total += self.list_assigned.sizeHintForRow(i) + spacing
        total += 2 * self.list_assigned.frameWidth()
        self.list_assigned.setFixedHeight(total)

    def _build_card_widget(self, name: str, extra: str, ent: dict | None = None) -> QWidget:
        dim = self._palette.get("html_dim", "#aaa")
        card = QFrame()
        card.setObjectName("linkedEntityCard")
        card.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents, True)

        layout = QVBoxLayout(card)
        layout.setContentsMargins(10, 8, 10, 8)
        layout.setSpacing(2)

        lbl_name = QLabel(name)
        lbl_name.setObjectName("linkedEntityName")
        layout.addWidget(lbl_name)

        if extra:
            lbl_extra = QLabel(extra.strip())
            lbl_extra.setStyleSheet(f"font-size: 11px; color: {dim};")
            layout.addWidget(lbl_extra)

        if self._entity_type == "Spell":
            attrs = ent.get("attributes", {}) if ent else {}
            for key in self._SPELL_PROPERTY_KEYS:
                val = str(attrs.get(key, "")).strip()
                if not val:
                    val = "-"
                detail = QLabel(f"{tr(key)}: {val}")
                detail.setWordWrap(True)
                detail.setStyleSheet(f"font-size: 11px; color: {dim};")
                layout.addWidget(detail)

            desc = self._short_preview_text((ent or {}).get("description", ""))
            lbl_desc = QLabel(f"{tr('LBL_DESC')}: {desc}")
            lbl_desc.setWordWrap(True)
            lbl_desc.setStyleSheet(f"font-size: 11px; color: {dim};")
            layout.addWidget(lbl_desc)

        return card
