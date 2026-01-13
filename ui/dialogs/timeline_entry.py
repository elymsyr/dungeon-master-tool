from PyQt6.QtWidgets import (QDialog, QVBoxLayout, QFormLayout, QSpinBox, 
                             QDialogButtonBox, QListWidget, QListWidgetItem, 
                             QLabel, QGroupBox, QHBoxLayout, QPushButton, QComboBox)
from PyQt6.QtCore import Qt
from core.locales import tr
from ui.widgets.markdown_editor import MarkdownEditor

class TimelineEntryDialog(QDialog):
    def __init__(self, data_manager, default_day=1, default_note="", selected_ids=None, selected_session_id=None, parent=None):
        super().__init__(parent)
        self.dm = data_manager
        self.selected_session_id = selected_session_id
        
        self.setWindowTitle(tr("TITLE_TIMELINE_ENTRY"))
        self.resize(500, 700)
        
        self.is_new_entry = (selected_ids is None or len(selected_ids) == 0)
        
        if selected_ids is None:
            self.selected_ids = []
        elif isinstance(selected_ids, (str, int)):
            self.selected_ids = [str(selected_ids)]
        else:
            self.selected_ids = [str(i) for i in selected_ids]
        
        self.init_ui(default_day, default_note)

    def init_ui(self, day, note):
        layout = QVBoxLayout(self)
        
        form = QFormLayout()
        self.spin_day = QSpinBox()
        self.spin_day.setRange(1, 99999)
        self.spin_day.setValue(day)
        form.addRow(f"{tr('LBL_DAY')}:", self.spin_day)
        
        self.combo_session = QComboBox()
        self.combo_session.addItem(tr("OPT_NO_SESSION"), None)
        
        sessions = self.dm.data.get("sessions", [])
        for sess in sessions:
            self.combo_session.addItem(f"📜 {sess['name']}", sess['id'])
            
        if self.selected_session_id:
            idx = self.combo_session.findData(self.selected_session_id)
            if idx >= 0: 
                self.combo_session.setCurrentIndex(idx)
            
        form.addRow(f"{tr('LBL_SESSION_LINK')}:", self.combo_session)
        layout.addLayout(form)
        
        # --- PLAYERS ---
        grp_players = QGroupBox(tr("GRP_PLAYERS"))
        layout_players = QVBoxLayout(grp_players)
        
        h_player_header = QHBoxLayout()
        h_player_header.addWidget(QLabel(tr("LBL_PARTY_MEMBERS")))
        h_player_header.addStretch()
        btn_all_players = QPushButton(tr("BTN_SELECT_ALL"))
        btn_all_players.setFixedSize(90, 22)
        btn_all_players.setStyleSheet("font-size: 11px;")
        btn_all_players.clicked.connect(lambda: self.select_all_in_list(self.list_players, True))
        h_player_header.addWidget(btn_all_players)
        layout_players.addLayout(h_player_header)

        self.list_players = QListWidget()
        self.list_players.setMaximumHeight(120)
        layout_players.addWidget(self.list_players)
        layout.addWidget(grp_players)

        # --- OTHERS ---
        grp_others = QGroupBox(tr("GRP_OTHERS"))
        layout_others = QVBoxLayout(grp_others)
        h_other_header = QHBoxLayout()
        h_other_header.addWidget(QLabel(tr("LBL_NPC_MONSTERS")))
        h_other_header.addStretch()
        btn_all_others = QPushButton(tr("BTN_SELECT_ALL"))
        btn_all_others.setFixedSize(90, 22)
        btn_all_others.setStyleSheet("font-size: 11px;")
        btn_all_others.clicked.connect(lambda: self.select_all_in_list(self.list_others, True))
        h_other_header.addWidget(btn_all_others)
        layout_others.addLayout(h_other_header)

        self.list_others = QListWidget()
        self.list_others.setMaximumHeight(150)
        layout_others.addWidget(self.list_others)
        layout.addWidget(grp_others)

        self.populate_lists()

        layout.addWidget(QLabel(tr("LBL_NOTES_MD")))
        self.txt_note = MarkdownEditor(text=note)
        self.txt_note.setPlaceholderText(tr("PH_TIMELINE_NOTES"))
        layout.addWidget(self.txt_note)
        
        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def populate_lists(self):
        for eid, ent in self.dm.data["entities"].items():
            etype = ent.get("type")
            if etype not in ["Player", "NPC", "Monster"]: continue
            icon = "👤" if etype == "Player" else "💀" if etype == "Monster" else "😐"
            item = QListWidgetItem(f"{icon} {ent['name']}")
            item.setData(Qt.ItemDataRole.UserRole, eid)
            item.setFlags(item.flags() | Qt.ItemFlag.ItemIsUserCheckable)
            target_list = self.list_players if etype == "Player" else self.list_others
            target_list.addItem(item)
            should_check = False
            if self.is_new_entry:
                if etype == "Player": should_check = True
            else:
                if eid in self.selected_ids: should_check = True
            item.setCheckState(Qt.CheckState.Checked if should_check else Qt.CheckState.Unchecked)

    def select_all_in_list(self, list_widget, state):
        check_state = Qt.CheckState.Checked if state else Qt.CheckState.Unchecked
        for i in range(list_widget.count()):
            list_widget.item(i).setCheckState(check_state)

    def get_data(self):
        ids = []
        for lw in [self.list_players, self.list_others]:
            for i in range(lw.count()):
                item = lw.item(i)
                if item.checkState() == Qt.CheckState.Checked:
                    ids.append(item.data(Qt.ItemDataRole.UserRole))
        return {
            "day": self.spin_day.value(),
            "entity_ids": ids,
            "session_id": self.combo_session.currentData(),
            "note": self.txt_note.toPlainText()
        }