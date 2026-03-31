"""NpcSheetInventoryTab — linked items + manual inventory cards."""

from PyQt6.QtWidgets import QGroupBox, QVBoxLayout, QWidget

from core.locales import tr
from ui.widgets.npc_sheet_helpers import (
    add_section_button,
    clear_section,
    create_feature_card,
    make_section,
)


class NpcSheetInventoryTab(QWidget):
    """Inventory tab: linked item widget + manual inventory cards."""

    def __init__(self, item_widget, dm, dirty_callback, open_entity_cb, parent=None):
        super().__init__(parent)
        self.item_widget = item_widget
        self.dm = dm
        self._dirty = dirty_callback
        self._open_entity = open_entity_cb
        self._add_btns: list = []
        self.is_embedded = False
        self._init_ui()

    # ------------------------------------------------------------------
    # UI setup
    # ------------------------------------------------------------------

    def _init_ui(self) -> None:
        layout = QVBoxLayout(self)
        layout.addWidget(self.item_widget)
        self.inventory_container = make_section(tr("GRP_INVENTORY"))
        add_section_button(
            self.inventory_container, tr("BTN_ADD"),
            lambda: self._add_card(self.inventory_container),
            self._add_btns,
        )
        layout.addWidget(self.inventory_container)
        layout.addStretch()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def populate(self, data: dict) -> None:
        for item in (data.get("inventory") or []):
            create_feature_card(
                self.inventory_container, self.dm, self._dirty, self._open_entity,
                is_embedded=self.is_embedded,
                name=str(item.get("name", "")),
                desc=str(item.get("desc", "")),
            )

    def collect(self) -> dict:
        result = []
        for i in range(self.inventory_container.dynamic_area.count()):
            w = self.inventory_container.dynamic_area.itemAt(i).widget()
            if w:
                result.append({
                    "name": w.inp_title.text(),
                    "desc": w.inp_desc.toPlainText(),
                })
        return {"inventory": result}

    def clear_cards(self) -> None:
        clear_section(self.inventory_container)

    def set_edit_mode(self, enabled: bool) -> None:
        ro = not enabled
        self.item_widget.set_edit_mode(enabled)
        for i in range(self.inventory_container.dynamic_area.count()):
            card = self.inventory_container.dynamic_area.itemAt(i).widget()
            if card is None:
                continue
            if hasattr(card, "inp_title"):
                card.inp_title.setReadOnly(ro)
            if hasattr(card, "inp_desc"):
                if ro:
                    card.inp_desc.switch_to_view_mode()
                else:
                    card.inp_desc.switch_to_edit_mode()
            if hasattr(card, "btn_del"):
                card.btn_del.setVisible(enabled)
        for btn in self._add_btns:
            btn.setVisible(enabled)

    def refresh_theme(self, palette: dict) -> None:
        for i in range(self.inventory_container.dynamic_area.count()):
            w = self.inventory_container.dynamic_area.itemAt(i).widget()
            if w and hasattr(w, "inp_desc"):
                w.inp_desc.refresh_theme(palette)

    # ------------------------------------------------------------------
    # Internal
    # ------------------------------------------------------------------

    def _add_card(self, container: QGroupBox):
        create_feature_card(
            container, self.dm, self._dirty, self._open_entity,
            is_embedded=self.is_embedded,
        )
