import os
import re
from PyQt6.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QLabel, 
                             QLineEdit, QPushButton, QListWidget, QGroupBox, 
                             QFormLayout, QFileDialog, QMessageBox, QWidget, QScrollArea)
from PyQt6.QtCore import Qt
from core.locales import tr

class ThemeBuilderDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle(tr("TITLE_THEME_BUILDER"))
        self.resize(800, 600)
        
        self.state_map = {} # { 'state_name': { 'base': path, 'level1': path ... } }
        self.current_state = "normal"
        
        self.init_ui()
        self.init_defaults()

    def init_ui(self):
        main_layout = QVBoxLayout(self)
        
        # --- TOP: Metadata ---
        form_meta = QFormLayout()
        self.txt_name = QLineEdit()
        self.txt_name.setPlaceholderText(tr("PH_THEME_NAME"))
        self.txt_name.textChanged.connect(self._generate_id)
        
        self.txt_id = QLineEdit()
        self.txt_id.setPlaceholderText(tr("PH_THEME_ID"))
        
        form_meta.addRow(tr("LBL_THEME_NAME"), self.txt_name)
        form_meta.addRow(tr("LBL_THEME_ID"), self.txt_id)
        main_layout.addLayout(form_meta)
        
        # --- MIDDLE: States & Tracks ---
        mid_layout = QHBoxLayout()
        
        # LEFT: State List
        left_layout = QVBoxLayout()
        left_layout.addWidget(QLabel(tr("LBL_STATES")))
        self.list_states = QListWidget()
        self.list_states.currentItemChanged.connect(self._on_state_selected)
        left_layout.addWidget(self.list_states)
        
        btn_layout = QHBoxLayout()
        self.btn_add_state = QPushButton(tr("LBL_ICON_ADD"))
        self.btn_add_state.clicked.connect(self._add_state)
        self.btn_del_state = QPushButton(tr("LBL_ICON_REMOVE"))
        self.btn_del_state.clicked.connect(self._del_state)
        btn_layout.addWidget(self.btn_add_state)
        btn_layout.addWidget(self.btn_del_state)
        left_layout.addLayout(btn_layout)
        
        mid_layout.addLayout(left_layout, 1)
        
        # RIGHT: Tracks for Selected State
        right_group = QGroupBox(tr("LBL_TRACKS"))
        self.track_layout = QFormLayout(right_group)
        
        self.track_inputs = {} # 'base': QLineEdit, 'level1': QLineEdit...
        
        tracks = [
            ("base", tr("INTENSITY_BASE")),
            ("level1", tr("INTENSITY_LOW")),
            ("level2", tr("INTENSITY_MEDIUM")),
            ("level3", tr("INTENSITY_HIGH"))
        ]
        
        for key, label in tracks:
            row_widget = QWidget()
            row_layout = QHBoxLayout(row_widget)
            row_layout.setContentsMargins(0, 0, 0, 0)
            
            txt = QLineEdit()
            txt.setReadOnly(True)
            txt.setPlaceholderText(tr("MSG_NO_FILE"))
            
            btn = QPushButton(tr("LBL_ICON_SEARCH")) # Folder icon placeholder
            btn.setFixedSize(30, 25)
            # Use default arg to capture key
            btn.clicked.connect(lambda _, k=key: self._browse_file(k))
            
            btn_clear = QPushButton(tr("LBL_ICON_REMOVE"))
            btn_clear.setFixedSize(30, 25)
            btn_clear.clicked.connect(lambda _, k=key: self._clear_file(k))
            
            row_layout.addWidget(txt)
            row_layout.addWidget(btn)
            row_layout.addWidget(btn_clear)
            
            self.track_layout.addRow(label, row_widget)
            self.track_inputs[key] = txt
            
        mid_layout.addWidget(right_group, 2)
        main_layout.addLayout(mid_layout)
        
        # --- BOTTOM: Actions ---
        btn_box = QHBoxLayout()
        btn_box.addStretch()
        
        self.btn_create = QPushButton(tr("BTN_CREATE_THEME"))
        self.btn_create.setObjectName("primaryBtn")
        self.btn_create.clicked.connect(self.accept)
        
        self.btn_cancel = QPushButton(tr("BTN_CANCEL"))
        self.btn_cancel.clicked.connect(self.reject)
        
        btn_box.addWidget(self.btn_create)
        btn_box.addWidget(self.btn_cancel)
        main_layout.addLayout(btn_box)

    def init_defaults(self):
        # Add default states
        self.state_map["normal"] = {}
        self.state_map["combat"] = {}
        self.list_states.addItem("normal")
        self.list_states.addItem("combat")
        self.list_states.setCurrentRow(0)

    def _generate_id(self, text):
        # Simple slugify
        slug = text.lower().strip()
        slug = re.sub(r'[^a-z0-9]+', '_', slug)
        slug = slug.strip('_')
        self.txt_id.setText(slug)

    def _on_state_selected(self, current, previous):
        if not current: 
            return
            
        # Save previous state data if we were editing one
        # Actually data is saved immediately on file pick, 
        # so just load the new state's data into UI
        
        state_name = current.text()
        self.current_state = state_name
        self._load_tracks_to_ui(state_name)

    def _load_tracks_to_ui(self, state_name):
        tracks = self.state_map.get(state_name, {})
        for key, txt_widget in self.track_inputs.items():
            path = tracks.get(key, "")
            txt_widget.setText(path)
            txt_widget.setToolTip(path)

    def _browse_file(self, track_key):
        if not self.current_state: return
        file_path, _ = QFileDialog.getOpenFileName(self, tr("TITLE_SELECT_AUDIO"), "", "Audio Files (*.mp3 *.wav *.ogg *.flac *.m4a)")
        if file_path:
            self.state_map[self.current_state][track_key] = file_path
            self.track_inputs[track_key].setText(file_path)

    def _clear_file(self, track_key):
        if not self.current_state: return
        if track_key in self.state_map[self.current_state]:
            del self.state_map[self.current_state][track_key]
        self.track_inputs[track_key].clear()

    def _add_state(self):
        from PyQt6.QtWidgets import QInputDialog
        name, ok = QInputDialog.getText(self, tr("TITLE_ADD_STATE"), tr("LBL_STATE_NAME"))
        if ok and name:
            slug = name.lower().strip().replace(" ", "_")
            if slug in self.state_map:
                QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_EXISTS"))
                return
            self.state_map[slug] = {}
            self.list_states.addItem(slug)
            self.list_states.setCurrentRow(self.list_states.count() - 1)

    def _del_state(self):
        row = self.list_states.currentRow()
        if row < 0: return
        
        item = self.list_states.takeItem(row)
        state_name = item.text()
        if state_name in self.state_map:
            del self.state_map[state_name]

    def get_data(self):
        return {
            'name': self.txt_name.text(),
            'id': self.txt_id.text(),
            'map': self.state_map
        }
