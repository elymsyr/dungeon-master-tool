"""NpcSheetSpellsTab — linked spells + manual spell add via dialog."""

from PyQt6.QtWidgets import QVBoxLayout, QWidget

from core.locales import tr


class NpcSheetSpellsTab(QWidget):
    """Spells tab: linked spell widget with optional manual add dialog."""

    def __init__(self, spell_widget, dm, dirty_callback, open_entity_cb, parent=None):
        super().__init__(parent)
        self.spell_widget = spell_widget
        self.dm = dm
        self._dirty = dirty_callback
        self._open_entity = open_entity_cb
        self.is_embedded = False
        self._init_ui()

    # ------------------------------------------------------------------
    # UI setup
    # ------------------------------------------------------------------

    def _init_ui(self) -> None:
        layout = QVBoxLayout(self)
        layout.addWidget(self.spell_widget)
        layout.addStretch()
        self.spell_widget.manual_add_requested.connect(self._on_manual_add)

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def populate(self, data: dict) -> None:
        self.spell_widget.set_custom_entries(data.get("custom_spells") or [])

    def collect(self) -> dict:
        return {"custom_spells": self.spell_widget.get_custom_entries()}

    def clear_cards(self) -> None:
        self.spell_widget.clear_custom_entries()

    def set_edit_mode(self, enabled: bool) -> None:
        self.spell_widget.set_edit_mode(enabled)

    def refresh_theme(self, palette: dict) -> None:
        self.spell_widget.refresh_theme(palette)

    # ------------------------------------------------------------------
    # Manual add
    # ------------------------------------------------------------------

    def _on_manual_add(self) -> None:
        from ui.dialogs.manual_spell_dialog import ManualSpellDialog

        dlg = ManualSpellDialog(parent=self)
        if not dlg.exec():
            return

        result = dlg.get_data()
        if result["save_to_database"]:
            spell_entity = {
                "name": result["name"],
                "type": "Spell",
                "description": result["description"],
                "attributes": result["attributes"],
            }
            new_eid = self.dm.save_entity(None, spell_entity)
            self.spell_widget.merge_linked_ids([new_eid])
            self.spell_widget.populate_available()
        else:
            self.spell_widget.add_custom_entry({
                "name": result["name"],
                "desc": result["description"],
                "attributes": result["attributes"],
            })
        self._dirty()
