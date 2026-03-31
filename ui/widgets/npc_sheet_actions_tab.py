"""NpcSheetActionsTab — traits, actions, reactions, legendary actions."""

from PyQt6.QtWidgets import QGroupBox, QVBoxLayout, QWidget

from core.locales import tr
from ui.widgets.npc_sheet_helpers import (
    add_section_button,
    clear_section,
    create_feature_card,
    make_section,
)


class NpcSheetActionsTab(QWidget):
    """Features tab: traits, actions, reactions, and legendary actions."""

    def __init__(self, dm, dirty_callback, open_entity_cb, parent=None):
        super().__init__(parent)
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
        self.trait_container = make_section(tr("LBL_TRAITS"))
        add_section_button(
            self.trait_container, tr("BTN_ADD"),
            lambda: self._add_card(self.trait_container),
            self._add_btns,
        )
        self.action_container = make_section(tr("LBL_ACTIONS"))
        add_section_button(
            self.action_container, tr("BTN_ADD"),
            lambda: self._add_card(self.action_container),
            self._add_btns,
        )
        self.reaction_container = make_section(tr("LBL_REACTIONS"))
        add_section_button(
            self.reaction_container, tr("BTN_ADD"),
            lambda: self._add_card(self.reaction_container),
            self._add_btns,
        )
        self.legendary_container = make_section(tr("LBL_LEGENDARY_ACTIONS"))
        add_section_button(
            self.legendary_container, tr("BTN_ADD"),
            lambda: self._add_card(self.legendary_container),
            self._add_btns,
        )
        layout.addWidget(self.trait_container)
        layout.addWidget(self.action_container)
        layout.addWidget(self.reaction_container)
        layout.addWidget(self.legendary_container)
        layout.addStretch()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def populate(self, data: dict) -> None:
        for key, container in [
            ("traits", self.trait_container),
            ("actions", self.action_container),
            ("reactions", self.reaction_container),
            ("legendary_actions", self.legendary_container),
        ]:
            for item in (data.get(key) or []):
                create_feature_card(
                    container, self.dm, self._dirty, self._open_entity,
                    is_embedded=self.is_embedded,
                    name=str(item.get("name", "")),
                    desc=str(item.get("desc", "")),
                )

    def collect(self) -> dict:
        def get_cards(container: QGroupBox) -> list[dict]:
            result = []
            for i in range(container.dynamic_area.count()):
                w = container.dynamic_area.itemAt(i).widget()
                if w:
                    result.append({
                        "name": w.inp_title.text(),
                        "desc": w.inp_desc.toPlainText(),
                    })
            return result

        return {
            "traits": get_cards(self.trait_container),
            "actions": get_cards(self.action_container),
            "reactions": get_cards(self.reaction_container),
            "legendary_actions": get_cards(self.legendary_container),
        }

    def clear_cards(self) -> None:
        for container in [
            self.trait_container, self.action_container,
            self.reaction_container, self.legendary_container,
        ]:
            clear_section(container)

    def set_edit_mode(self, enabled: bool) -> None:
        ro = not enabled
        for container in [
            self.trait_container, self.action_container,
            self.reaction_container, self.legendary_container,
        ]:
            for i in range(container.dynamic_area.count()):
                card = container.dynamic_area.itemAt(i).widget()
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
        for container in [
            self.trait_container, self.action_container,
            self.reaction_container, self.legendary_container,
        ]:
            for i in range(container.dynamic_area.count()):
                w = container.dynamic_area.itemAt(i).widget()
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
