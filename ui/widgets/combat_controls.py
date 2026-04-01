"""CombatControlsWidget — encounter selector, turn controls, and action buttons.

Pure UI component: no model access, no business logic.  All user actions are
exposed as pyqtSignals so CombatTracker can wire them to the appropriate handlers.
"""

from PyQt6.QtCore import pyqtSignal
from PyQt6.QtWidgets import (
    QApplication,
    QComboBox,
    QHBoxLayout,
    QInputDialog,
    QLabel,
    QLineEdit,
    QMessageBox,
    QPushButton,
    QStyle,
    QVBoxLayout,
    QWidget,
)

from core.locales import tr


class CombatControlsWidget(QWidget):
    """Encounter management bar + round/turn controls + combatant action buttons.

    Signals
    -------
    turn_requested()                — "Next Turn" clicked
    roll_requested()                — "Roll Initiative" clicked
    clear_requested()               — "Clear All" clicked
    add_combatant_requested()       — "Add" clicked
    add_players_requested()         — "Add Players" clicked
    quick_add_requested(str,str,str)— quick-add form submitted (name, init, hp)
    new_encounter_requested(str)    — user confirmed new encounter name
    rename_encounter_requested(str) — user confirmed new name for current enc
    delete_encounter_confirmed()    — user confirmed encounter deletion
    encounter_selected(str)         — combo changed; value is encounter_id
    """

    turn_requested = pyqtSignal()
    roll_requested = pyqtSignal()
    clear_requested = pyqtSignal()
    add_combatant_requested = pyqtSignal()
    add_players_requested = pyqtSignal()
    quick_add_requested = pyqtSignal(str, str, str)
    new_encounter_requested = pyqtSignal(str)
    rename_encounter_requested = pyqtSignal(str)
    delete_encounter_confirmed = pyqtSignal()
    encounter_selected = pyqtSignal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._rebuilding_combo = False
        self._init_ui()

    # ------------------------------------------------------------------
    # UI setup
    # ------------------------------------------------------------------

    def _init_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(4)

        # --- Encounter row ---
        enc_layout = QHBoxLayout()
        _style = QApplication.style()

        self.combo_encounters = QComboBox()
        self.combo_encounters.currentIndexChanged.connect(self._on_combo_changed)
        self.combo_encounters.setMinimumWidth(200)

        self.btn_new_enc = QPushButton()
        self.btn_new_enc.setIcon(_style.standardIcon(QStyle.StandardPixmap.SP_FileDialogNewFolder))
        self.btn_new_enc.setFixedSize(28, 26)
        self.btn_new_enc.setToolTip(tr("TIP_NEW_ENC"))
        self.btn_new_enc.clicked.connect(self._prompt_new_encounter)

        self.btn_rename_enc = QPushButton(tr("BTN_EDIT"))
        self.btn_rename_enc.setFixedSize(44, 26)
        self.btn_rename_enc.setToolTip(tr("TIP_RENAME_ENC"))
        self.btn_rename_enc.clicked.connect(self._prompt_rename_encounter)

        self.btn_del_enc = QPushButton()
        self.btn_del_enc.setIcon(_style.standardIcon(QStyle.StandardPixmap.SP_TrashIcon))
        self.btn_del_enc.setFixedSize(28, 26)
        self.btn_del_enc.setToolTip(tr("TIP_DEL_ENC"))
        self.btn_del_enc.setObjectName("dangerBtn")
        self.btn_del_enc.clicked.connect(self._confirm_delete_encounter)

        enc_layout.addWidget(QLabel(tr("LBL_ENCOUNTER_PREFIX")))
        enc_layout.addWidget(self.combo_encounters)
        enc_layout.addWidget(self.btn_new_enc)
        enc_layout.addWidget(self.btn_rename_enc)
        enc_layout.addWidget(self.btn_del_enc)
        layout.addLayout(enc_layout)

        # --- Quick-add row ---
        q_lo = QHBoxLayout()
        self.inp_quick_name = QLineEdit()
        self.inp_quick_name.setPlaceholderText(tr("HEADER_NAME"))
        self.inp_quick_init = QLineEdit()
        self.inp_quick_init.setPlaceholderText(tr("LBL_INIT"))
        self.inp_quick_init.setMaximumWidth(50)
        self.inp_quick_hp = QLineEdit()
        self.inp_quick_hp.setPlaceholderText(tr("LBL_HP"))
        self.inp_quick_hp.setMaximumWidth(50)
        self.btn_quick_add = QPushButton(tr("BTN_QUICK_ADD"))
        self.btn_quick_add.clicked.connect(self._on_quick_add)
        q_lo.addWidget(self.inp_quick_name, 3)
        q_lo.addWidget(self.inp_quick_init, 1)
        q_lo.addWidget(self.inp_quick_hp, 1)
        q_lo.addWidget(self.btn_quick_add, 1)
        layout.addLayout(q_lo)

        # --- Round / Next Turn row ---
        btn_layout = QHBoxLayout()
        self.lbl_round = QLabel(f"{tr('LBL_ROUND_PREFIX')}1")
        self.lbl_round.setObjectName("roundLabel")
        self.btn_next_turn = QPushButton(tr("BTN_NEXT_TURN"))
        self.btn_next_turn.setObjectName("actionBtn")
        self.btn_next_turn.clicked.connect(self.turn_requested.emit)
        btn_layout.addWidget(self.lbl_round)
        btn_layout.addWidget(self.btn_next_turn)
        layout.addLayout(btn_layout)

        # --- Action buttons row ---
        btn_layout2 = QHBoxLayout()
        self.btn_add = QPushButton(tr("BTN_ADD"))
        self.btn_add.clicked.connect(self.add_combatant_requested.emit)
        self.btn_add_players = QPushButton(tr("BTN_ADD_PLAYERS"))
        self.btn_add_players.clicked.connect(self.add_players_requested.emit)
        self.btn_roll = QPushButton(tr("BTN_ROLL_INIT"))
        self.btn_roll.clicked.connect(self.roll_requested.emit)
        self.btn_clear_all = QPushButton(tr("BTN_CLEAR_ALL"))
        self.btn_clear_all.clicked.connect(self.clear_requested.emit)
        self.btn_clear_all.setObjectName("dangerBtn")
        btn_layout2.addWidget(self.btn_add)
        btn_layout2.addWidget(self.btn_add_players)
        btn_layout2.addWidget(self.btn_roll)
        btn_layout2.addWidget(self.btn_clear_all)
        layout.addLayout(btn_layout2)

    # ------------------------------------------------------------------
    # Public update API (called by CombatTracker)
    # ------------------------------------------------------------------

    def rebuild_encounter_combo(self, encounters: dict, current_id: str | None) -> None:
        """Repopulate the encounter dropdown without triggering business logic."""
        self._rebuilding_combo = True
        self.combo_encounters.blockSignals(True)
        self.combo_encounters.clear()
        for eid, enc in encounters.items():
            self.combo_encounters.addItem(enc["name"], eid)
        idx = self.combo_encounters.findData(current_id)
        if idx >= 0:
            self.combo_encounters.setCurrentIndex(idx)
        else:
            self.combo_encounters.setCurrentIndex(0)
        self.combo_encounters.blockSignals(False)
        self._rebuilding_combo = False

    def update_round(self, round_num: int) -> None:
        self.lbl_round.setText(f"{tr('LBL_ROUND_PREFIX')}{round_num}")

    def current_encounter_id(self) -> str | None:
        return self.combo_encounters.currentData()

    # ------------------------------------------------------------------
    # User action handlers — show dialogs, then emit semantic signals
    # ------------------------------------------------------------------

    def _on_combo_changed(self, _idx: int):
        if self._rebuilding_combo:
            return
        eid = self.combo_encounters.currentData()
        if eid:
            self.encounter_selected.emit(eid)

    def _prompt_new_encounter(self):
        n, ok = QInputDialog.getText(self, tr("TITLE_NEW_ENC"), tr("LBL_ENC_NAME"))
        if ok and n:
            self.new_encounter_requested.emit(n)

    def _prompt_rename_encounter(self):
        # We don't have the current name here, so CombatTracker should pre-fill
        # via a rename dialog. We emit rename_encounter_requested with a sentinel
        # so CombatTracker can show the dialog instead.
        # Simpler: show the dialog here with empty default, CombatTracker overrides.
        n, ok = QInputDialog.getText(self, tr("TITLE_RENAME_ENC"), tr("LBL_NEW_NAME"))
        if ok and n:
            self.rename_encounter_requested.emit(n)

    def _confirm_delete_encounter(self):
        if QMessageBox.question(
            self,
            tr("TITLE_DELETE"),
            tr("MSG_CONFIRM_ENC_DELETE"),
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        ) == QMessageBox.StandardButton.Yes:
            self.delete_encounter_confirmed.emit()

    def _on_quick_add(self):
        name = self.inp_quick_name.text().strip()
        if name:
            init_text = self.inp_quick_init.text()
            hp_text = self.inp_quick_hp.text()
            self.inp_quick_name.clear()
            self.quick_add_requested.emit(name, init_text, hp_text)

    # ------------------------------------------------------------------
    # Retranslation
    # ------------------------------------------------------------------

    def retranslate_ui(self) -> None:
        self.inp_quick_name.setPlaceholderText(tr("HEADER_NAME"))
        self.btn_quick_add.setText(tr("BTN_QUICK_ADD"))
        self.btn_next_turn.setText(tr("BTN_NEXT_TURN"))
        self.btn_add.setText(tr("BTN_ADD"))
        self.btn_add_players.setText(tr("BTN_ADD_PLAYERS"))
        self.btn_roll.setText(tr("BTN_ROLL_INIT"))
        self.btn_clear_all.setText(tr("BTN_CLEAR_ALL"))
        self.btn_new_enc.setToolTip(tr("TIP_NEW_ENC"))
        self.btn_rename_enc.setToolTip(tr("TIP_RENAME_ENC"))
        self.btn_del_enc.setToolTip(tr("TIP_DEL_ENC"))
