"""ManualSpellDialog — dialog for adding a spell manually."""

from PyQt6.QtWidgets import (
    QCheckBox,
    QComboBox,
    QDialog,
    QDialogButtonBox,
    QFormLayout,
    QLineEdit,
    QTextEdit,
    QVBoxLayout,
)

from core.locales import tr
from core.models import ENTITY_SCHEMAS


class ManualSpellDialog(QDialog):
    """Dialog for manually creating a spell entry.

    Provides fields for spell name, attributes (from ENTITY_SCHEMAS["Spell"]),
    description, and a checkbox to optionally save to the database.
    """

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle(tr("TITLE_MANUAL_SPELL"))
        self.resize(500, 500)
        self._attr_inputs: dict = {}
        self._init_ui()

    def _init_ui(self) -> None:
        layout = QVBoxLayout(self)

        form = QFormLayout()

        self.inp_name = QLineEdit()
        self.inp_name.setPlaceholderText(tr("LBL_NAME"))
        form.addRow(f"{tr('LBL_NAME')}:", self.inp_name)

        for label_key, dtype, options in ENTITY_SCHEMAS.get("Spell", []):
            if dtype == "combo":
                widget = QComboBox()
                widget.setEditable(True)
                if options:
                    for opt in options:
                        widget.addItem(
                            tr(opt) if str(opt).startswith("LBL_") else opt, opt
                        )
            else:
                widget = QLineEdit()
            form.addRow(f"{tr(label_key)}:", widget)
            self._attr_inputs[label_key] = widget

        layout.addLayout(form)

        self.inp_desc = QTextEdit()
        self.inp_desc.setPlaceholderText(tr("LBL_DESC"))
        self.inp_desc.setMinimumHeight(100)
        layout.addWidget(self.inp_desc)

        self.chk_save_to_db = QCheckBox(tr("LBL_SAVE_TO_DB"))
        layout.addWidget(self.chk_save_to_db)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def get_data(self) -> dict:
        """Return the collected spell data."""
        attrs = {}
        for label_key, widget in self._attr_inputs.items():
            if isinstance(widget, QComboBox):
                attrs[label_key] = widget.currentText()
            else:
                attrs[label_key] = widget.text()
        return {
            "name": self.inp_name.text(),
            "description": self.inp_desc.toPlainText(),
            "attributes": attrs,
            "save_to_database": self.chk_save_to_db.isChecked(),
        }
