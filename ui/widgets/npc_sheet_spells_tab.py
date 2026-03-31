"""NpcSheetSpellsTab — linked spells + manual spell cards."""

from PyQt6.QtWidgets import (
    QComboBox,
    QFormLayout,
    QFrame,
    QGroupBox,
    QLabel,
    QLineEdit,
    QVBoxLayout,
    QWidget,
)

from core.locales import tr
from core.models import ENTITY_SCHEMAS
from ui.widgets.npc_sheet_helpers import (
    add_section_button,
    clear_section,
    create_feature_card,
    make_section,
)


class NpcSheetSpellsTab(QWidget):
    """Spells tab: linked spell widget + manual spell cards."""

    def __init__(self, spell_widget, dm, dirty_callback, open_entity_cb, parent=None):
        super().__init__(parent)
        self.spell_widget = spell_widget
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
        layout.addWidget(self.spell_widget)
        self.custom_spell_container = make_section(tr("LBL_MANUAL_SPELLS"))
        add_section_button(
            self.custom_spell_container, tr("BTN_ADD"),
            lambda: self.add_manual_spell_card(self.custom_spell_container),
            self._add_btns,
        )
        layout.addWidget(self.custom_spell_container)
        layout.addStretch()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def populate(self, data: dict) -> None:
        for item in (data.get("custom_spells") or []):
            attrs = item.get("attributes")
            self.add_manual_spell_card(
                self.custom_spell_container,
                name=str(item.get("name", "")),
                desc=str(item.get("desc", "")),
                spell_attrs=attrs if isinstance(attrs, dict) else {},
            )

    def collect(self) -> dict:
        result = []
        for i in range(self.custom_spell_container.dynamic_area.count()):
            w = self.custom_spell_container.dynamic_area.itemAt(i).widget()
            if not w:
                continue
            attrs = {}
            for label_key, widget in getattr(w, "spell_attr_inputs", {}).items():
                if isinstance(widget, QComboBox):
                    attrs[label_key] = widget.currentText()
                else:
                    attrs[label_key] = widget.text()
            result.append({
                "name": w.inp_title.text(),
                "desc": w.inp_desc.toPlainText(),
                "attributes": attrs,
            })
        return {"custom_spells": result}

    def clear_cards(self) -> None:
        clear_section(self.custom_spell_container)

    def set_edit_mode(self, enabled: bool) -> None:
        ro = not enabled
        self.spell_widget.set_edit_mode(enabled)
        for i in range(self.custom_spell_container.dynamic_area.count()):
            card = self.custom_spell_container.dynamic_area.itemAt(i).widget()
            if card is None:
                continue
            if hasattr(card, "inp_title"):
                card.inp_title.setReadOnly(ro)
            if hasattr(card, "inp_desc"):
                if ro:
                    card.inp_desc.switch_to_view_mode()
                else:
                    card.inp_desc.switch_to_edit_mode()
            if hasattr(card, "spell_attr_inputs"):
                for widget in card.spell_attr_inputs.values():
                    if isinstance(widget, QLineEdit):
                        widget.setReadOnly(ro)
                    else:
                        widget.setEnabled(enabled)
            if hasattr(card, "spell_attr_box"):
                card.spell_attr_box.setVisible(enabled)
            if hasattr(card, "spell_preview_box"):
                self._refresh_spell_card_preview(card)
                card.spell_preview_box.setVisible(ro)
                if hasattr(card, "inp_desc"):
                    card.inp_desc.setVisible(enabled)
            if hasattr(card, "btn_del"):
                card.btn_del.setVisible(enabled)
        for btn in self._add_btns:
            btn.setVisible(enabled)

    def refresh_theme(self, palette: dict) -> None:
        for i in range(self.custom_spell_container.dynamic_area.count()):
            w = self.custom_spell_container.dynamic_area.itemAt(i).widget()
            if w and hasattr(w, "inp_desc"):
                w.inp_desc.refresh_theme(palette)

    # ------------------------------------------------------------------
    # Manual spell card
    # ------------------------------------------------------------------

    def add_manual_spell_card(
        self,
        group: QGroupBox,
        name: str = "",
        desc: str = "",
        spell_attrs: dict | None = None,
    ):
        card = create_feature_card(
            group, self.dm, self._dirty, self._open_entity,
            is_embedded=self.is_embedded, name=name, desc=desc,
        )
        attrs = spell_attrs if isinstance(spell_attrs, dict) else {}

        attr_box = QFrame()
        attr_layout = QFormLayout(attr_box)
        attr_layout.setContentsMargins(0, 0, 0, 0)
        attr_layout.setSpacing(4)

        spell_attr_inputs: dict = {}
        for label_key, dtype, options in ENTITY_SCHEMAS.get("Spell", []):
            if dtype == "combo":
                widget = QComboBox()
                widget.setEditable(True)
                if options:
                    for opt in options:
                        widget.addItem(tr(opt) if str(opt).startswith("LBL_") else opt, opt)
                self._set_combo_value(widget, attrs.get(label_key, ""))
                widget.editTextChanged.connect(self._dirty)
                widget.currentIndexChanged.connect(self._dirty)
                widget.editTextChanged.connect(
                    lambda _=None, c=card: self._refresh_spell_card_preview(c)
                )
                widget.currentIndexChanged.connect(
                    lambda _=None, c=card: self._refresh_spell_card_preview(c)
                )
                self._force_transparent_combo(widget)
            else:
                widget = QLineEdit(str(attrs.get(label_key, "") or ""))
                widget.textChanged.connect(self._dirty)
                widget.textChanged.connect(
                    lambda _=None, c=card: self._refresh_spell_card_preview(c)
                )
                self._force_transparent_line_edit(widget)

            spell_attr_inputs[label_key] = widget
            attr_layout.addRow(tr(label_key), widget)

        preview_box = QFrame()
        preview_layout = QVBoxLayout(preview_box)
        preview_layout.setContentsMargins(0, 0, 0, 0)
        preview_layout.setSpacing(2)

        preview_labels: dict = {}
        for label_key, _, _ in ENTITY_SCHEMAS.get("Spell", []):
            lbl = QLabel()
            lbl.setWordWrap(True)
            lbl.setStyleSheet("font-size: 11px; color: #b0b0b0;")
            preview_layout.addWidget(lbl)
            preview_labels[label_key] = lbl

        lbl_desc = QLabel()
        lbl_desc.setWordWrap(True)
        lbl_desc.setStyleSheet("font-size: 11px; color: #b0b0b0;")
        preview_layout.addWidget(lbl_desc)

        card.layout().insertWidget(1, attr_box)
        card.layout().insertWidget(2, preview_box)
        card.spell_attr_inputs = spell_attr_inputs
        card.spell_attr_box = attr_box
        card.spell_preview_box = preview_box
        card.spell_preview_labels = preview_labels
        card.spell_preview_desc = lbl_desc
        card.inp_title.textChanged.connect(
            lambda _=None, c=card: self._refresh_spell_card_preview(c)
        )
        card.inp_desc.textChanged.connect(
            lambda _=None, c=card: self._refresh_spell_card_preview(c)
        )
        self._refresh_spell_card_preview(card)
        return card

    def _refresh_spell_card_preview(self, card) -> None:
        labels = getattr(card, "spell_preview_labels", {})
        inputs = getattr(card, "spell_attr_inputs", {})
        for label_key, lbl in labels.items():
            input_widget = inputs.get(label_key)
            if input_widget is None:
                continue
            raw = (
                input_widget.currentText()
                if isinstance(input_widget, QComboBox)
                else input_widget.text()
            )
            lbl.setText(f"{tr(label_key)}: {self._short_preview(raw, 120)}")
        desc_label = getattr(card, "spell_preview_desc", None)
        if desc_label is not None:
            desc_label.setText(
                f"{tr('LBL_DESC')}: {self._short_preview(card.inp_desc.toPlainText())}"
            )

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _set_combo_value(combo: QComboBox, value) -> None:
        text = str(value or "")
        if not text:
            return
        idx = combo.findData(text)
        if idx >= 0:
            combo.setCurrentIndex(idx)
            return
        idx = combo.findText(text)
        if idx >= 0:
            combo.setCurrentIndex(idx)
            return
        combo.setCurrentText(text)

    @staticmethod
    def _short_preview(text: str, max_len: int = 260) -> str:
        cleaned = " ".join(str(text or "").split())
        if not cleaned:
            return "-"
        if len(cleaned) <= max_len:
            return cleaned
        return f"{cleaned[:max_len - 3]}..."

    @staticmethod
    def _force_transparent_line_edit(widget: QLineEdit) -> None:
        from PyQt6.QtGui import QColor, QPalette
        style = widget.styleSheet().strip()
        token = "background-color: transparent;"
        if token not in style:
            if style and not style.endswith(";"):
                style = f"{style}; "
            widget.setStyleSheet(f"{style}{token}")
        pal = widget.palette()
        pal.setColor(QPalette.ColorRole.Base, QColor(0, 0, 0, 0))
        widget.setPalette(pal)
        widget.setAutoFillBackground(False)

    @staticmethod
    def _force_transparent_combo(widget: QComboBox) -> None:
        from PyQt6.QtGui import QColor, QPalette
        style = widget.styleSheet().strip()
        forced = (
            "QComboBox { background-color: transparent; }"
            "QComboBox:editable { background-color: transparent; }"
            "QComboBox::drop-down { background-color: transparent; border: none; }"
            "QComboBox::down-arrow { background: transparent; }"
        )
        if forced not in style:
            widget.setStyleSheet(f"{style}; {forced}" if style else forced)
        pal = widget.palette()
        pal.setColor(QPalette.ColorRole.Base, QColor(0, 0, 0, 0))
        widget.setPalette(pal)
        widget.setAutoFillBackground(False)
        line_edit = widget.lineEdit()
        if line_edit is not None:
            NpcSheetSpellsTab._force_transparent_line_edit(line_edit)
