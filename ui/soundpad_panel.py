import os
import copy
from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QLabel, QFrame, QPushButton, 
                             QHBoxLayout, QSlider, QComboBox, QGroupBox, QTabWidget,
                             QGridLayout, QScrollArea, QFileDialog, QInputDialog, QMessageBox)
from PyQt6.QtCore import Qt, pyqtSignal
from core.locales import tr
from core.audio.engine import MusicBrain
from core.audio.loader import load_all_themes, load_global_library, add_to_library

class SoundpadPanel(QWidget):
    theme_loaded_with_shortcuts = pyqtSignal(dict)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedWidth(350)
        self.setObjectName("soundpadContainer")
        
        # Load global library and start audio engine
        self.global_library = load_global_library()
        self.audio_brain = MusicBrain(self.global_library)
        
        # Load music themes
        self.themes = load_all_themes()
        
        self.current_theme = None
        self.ambience_slots = []
        self.sfx_buttons = {}

        self.init_ui()
        
        # Populate UI
        self._build_ambience_slots()
        self._build_sfx_grid()
        
        # Emit default shortcuts
        self.theme_loaded_with_shortcuts.emit(self.global_library.get('shortcuts', {}))

    def init_ui(self):
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(10, 10, 10, 10)
        
        # Title
        # Title
        self.lbl_title = QLabel(tr("TITLE_SOUNDPAD"))
        self.lbl_title.setObjectName("headerLabel")
        self.lbl_title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        main_layout.addWidget(self.lbl_title)
        
        # Tabs
        self.tabs = QTabWidget()
        main_layout.addWidget(self.tabs, 1)
        
        
        self.music_tab = QWidget()
        self.ambience_tab = QWidget()
        self.sfx_tab = QWidget()
        
        self.tabs.addTab(self.music_tab, tr("TAB_MUSIC"))
        self.tabs.addTab(self.ambience_tab, tr("TAB_AMBIENCE"))
        self.tabs.addTab(self.sfx_tab, tr("TAB_SFX"))

        self._setup_music_tab()
        self._setup_ambience_tab()
        self._setup_sfx_tab()
        
        # Global Controls
        self.grp_global = QGroupBox(tr("GRP_GLOBAL_CONTROLS"))
        global_layout = QVBoxLayout(self.grp_global)
        
        vol_layout = QHBoxLayout()
        self.lbl_master_vol = QLabel(tr("LBL_MASTER_VOLUME"))
        vol_layout.addWidget(self.lbl_master_vol)
        
        self.slider_vol = QSlider(Qt.Orientation.Horizontal)
        self.slider_vol.setRange(0, 100)
        self.slider_vol.setValue(50)
        self.slider_vol.valueChanged.connect(self.change_master_volume)
        vol_layout.addWidget(self.slider_vol)
        global_layout.addLayout(vol_layout)
        
        stop_buttons_layout = QHBoxLayout()
        self.btn_stop_ambience = QPushButton(tr("BTN_STOP_AMBIENCE"))
        self.btn_stop_ambience.clicked.connect(self.stop_ambience)
        
        self.btn_stop_all = QPushButton(tr("BTN_STOP_ALL"))
        self.btn_stop_all.setObjectName("dangerBtn")
        self.btn_stop_all.clicked.connect(self.stop_all)
        
        stop_buttons_layout.addWidget(self.btn_stop_ambience)
        stop_buttons_layout.addWidget(self.btn_stop_all)
        global_layout.addLayout(stop_buttons_layout)
        
        main_layout.addWidget(self.grp_global)

    def _setup_music_tab(self):
        layout = QVBoxLayout(self.music_tab)
        if not self.themes:
            self.lbl_no_themes = QLabel(tr("MSG_NO_THEMES"))
            layout.addWidget(self.lbl_no_themes)
            return

        theme_layout = QHBoxLayout()
        self.combo_themes = QComboBox()
        self.combo_themes.addItem(tr("COMBO_SELECT_THEME"), None)
        for tid, theme in self.themes.items():
            self.combo_themes.addItem(theme.name, tid)
        
        self.btn_load_theme = QPushButton("📂 " + tr("BTN_LOAD_THEME"))
        self.btn_load_theme.setObjectName("primaryBtn")
        self.btn_load_theme.clicked.connect(self.load_selected_theme)
        
        theme_layout.addWidget(self.combo_themes, 1)
        theme_layout.addWidget(self.btn_load_theme)
        layout.addLayout(theme_layout)

        self.grp_states = QGroupBox(tr("GRP_MUSIC_STATE"))
        self.layout_states = QVBoxLayout(self.grp_states)
        self.grp_states.setVisible(False)
        layout.addWidget(self.grp_states)

        self.grp_intensity = QGroupBox(tr("GRP_INTENSITY"))
        v_int = QVBoxLayout(self.grp_intensity)
        self.slider_intensity = QSlider(Qt.Orientation.Horizontal)
        self.slider_intensity.setRange(0, 3)
        self.slider_intensity.setTickPosition(QSlider.TickPosition.TicksBelow)
        self.slider_intensity.setTickInterval(1)
        self.slider_intensity.valueChanged.connect(self.change_intensity)
        
        self.lbl_intensity_val = QLabel(tr("INTENSITY_BASE"))
        self.lbl_intensity_val.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        v_int.addWidget(self.slider_intensity)
        v_int.addWidget(self.lbl_intensity_val)
        self.grp_intensity.setVisible(False)
        layout.addWidget(self.grp_intensity)
        layout.addStretch()

    def _setup_ambience_tab(self):
        layout = QVBoxLayout(self.ambience_tab)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        content_widget = QWidget()
        self.ambience_layout = QVBoxLayout(content_widget)
        self.ambience_layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        scroll.setWidget(content_widget)
        scroll.setWidget(content_widget)
        layout.addWidget(scroll)
        
        # Add Button
        self.btn_add_ambience = QPushButton("➕ " + tr("BTN_ADD_AMBIENCE"))
        self.btn_add_ambience.clicked.connect(self.add_new_ambience)
        layout.addWidget(self.btn_add_ambience)

    def _setup_sfx_tab(self):
        layout = QVBoxLayout(self.sfx_tab)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        content_widget = QWidget()
        self.sfx_grid_layout = QGridLayout(content_widget)
        self.sfx_grid_layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        scroll.setWidget(content_widget)
        scroll.setWidget(content_widget)
        layout.addWidget(scroll)
        
        # Add Button
        self.btn_add_sfx = QPushButton("➕ " + tr("BTN_ADD_SFX"))
        self.btn_add_sfx.clicked.connect(self.add_new_sfx)
        layout.addWidget(self.btn_add_sfx)

    def _build_ambience_slots(self):
        ambience_list = self.global_library.get('ambience', [])
        for i in range(4):
            slot_box = QGroupBox(tr("LBL_AMBIENCE_SLOT") + f" {i+1}")
            slot_layout = QVBoxLayout(slot_box)
            
            combo = QComboBox()
            combo.addItem(tr("OPT_SILENCE"), None)
            for ambience in ambience_list:
                combo.addItem(ambience['name'], ambience['id'])
            
            slider = QSlider(Qt.Orientation.Horizontal)
            slider.setRange(0, 100)
            slider.setValue(70)
            
            self.ambience_slots.append({'group': slot_box, 'combo': combo, 'slider': slider})
            slot_layout.addWidget(combo)
            slot_layout.addWidget(slider)
            self.ambience_layout.addWidget(slot_box)
            
            combo.currentIndexChanged.connect(lambda _, s_idx=i: self._on_ambience_change(s_idx))
            slider.valueChanged.connect(lambda value, s_idx=i: self._on_ambience_volume_change(s_idx, value))

    def _build_sfx_grid(self):
        sfx_list = self.global_library.get('sfx', [])
        row, col = 0, 0
        for sfx in sfx_list:
            btn = QPushButton(sfx['name'])
            btn.setMinimumHeight(40)
            btn.clicked.connect(lambda _, s_id=sfx['id']: self.play_sfx(s_id))
            self.sfx_grid_layout.addWidget(btn, row, col)
            self.sfx_buttons[sfx['id']] = btn
            col += 1
            if col > 1: 
                col = 0
                row += 1

    def _rebuild_state_buttons(self):
        while self.layout_states.count():
            self.layout_states.takeAt(0).widget().deleteLater()
            
        if not self.current_theme: 
            return
            
        self.state_buttons = {} 
        for state_name in self.current_theme.states.keys():
            # State names usually stay as they are (data identifiers), 
            # but you could title() them.
            btn = QPushButton(state_name.title())
            btn.setCheckable(True)
            btn.clicked.connect(lambda _, s=state_name: self.on_state_clicked(s))
            self.layout_states.addWidget(btn)
            self.state_buttons[state_name] = btn

    def load_selected_theme(self):
        tid = self.combo_themes.currentData()
        if tid is None:
            self.current_theme = None
            self.grp_states.setVisible(False)
            self.grp_intensity.setVisible(False)
            self.theme_loaded_with_shortcuts.emit(self.global_library.get('shortcuts', {}))
            self.audio_brain.set_theme(None)
            return
        
        self.current_theme = self.themes[tid]
        self.audio_brain.set_theme(self.current_theme)
        self._rebuild_state_buttons()
        self.grp_states.setVisible(True)
        self.slider_intensity.setValue(0)
        self.grp_intensity.setVisible(True)
        
        final_shortcuts = self._merge_shortcuts()
        self.theme_loaded_with_shortcuts.emit(final_shortcuts)

    def _merge_shortcuts(self):
        final_shortcuts = copy.deepcopy(self.global_library.get('shortcuts', {}))
        if not self.current_theme:
            return final_shortcuts
        
        theme_shortcuts = getattr(self.current_theme, 'shortcuts', {})
        for key, value in theme_shortcuts.items():
            if isinstance(value, dict):
                if key not in final_shortcuts:
                    final_shortcuts[key] = {}
                for sub_key, sub_value in value.items():
                    final_shortcuts[key][sub_key] = sub_value
            else:
                final_shortcuts[key] = value
        return final_shortcuts

    def on_state_clicked(self, state_name):
        self.audio_brain.queue_state(state_name)
        for name, btn in self.state_buttons.items():
            btn.setChecked(name == state_name)

    def _on_ambience_change(self, slot_index):
        slot = self.ambience_slots[slot_index]
        ambience_id = slot['combo'].currentData()
        volume = slot['slider'].value()
        self.audio_brain.play_ambience(slot_index, ambience_id, volume)

    def _on_ambience_volume_change(self, slot_index, volume):
        self.audio_brain.set_ambience_volume(slot_index, volume)

    def play_sfx(self, sfx_id):
        self.audio_brain.play_sfx(sfx_id)

    def stop_ambience(self):
        self.audio_brain.stop_ambience()
        for slot in self.ambience_slots:
            slot['combo'].blockSignals(True)
            slot['combo'].setCurrentIndex(0)
            slot['combo'].blockSignals(False)

    def stop_all(self):
        self.audio_brain.stop_all()
        self.stop_ambience()
        if self.combo_themes.currentIndex() > 0:
            self.combo_themes.setCurrentIndex(0)
            self.load_selected_theme()

    def change_master_volume(self, value):
        self.audio_brain.set_master_volume(value / 100.0)

    def change_intensity(self, value):
        labels = [
            tr("INTENSITY_BASE"), 
            tr("INTENSITY_LOW"), 
            tr("INTENSITY_MEDIUM"), 
            tr("INTENSITY_HIGH")
        ]
        text = labels[value] if value < len(labels) else str(value)
        self.lbl_intensity_val.setText(text)
        self.audio_brain.set_intensity(value)

    def retranslate_ui(self):
        """
        Updates texts when language changes dynamically.
        Note: Ambience Slots and SFX buttons might need a fuller redraw 
        if their 'names' depend on locale, but here we update static UI elements.
        """
        self.lbl_title.setText(tr("TITLE_SOUNDPAD"))
        self.tabs.setTabText(0, tr("TAB_MUSIC"))
        self.tabs.setTabText(1, tr("TAB_AMBIENCE"))
        self.tabs.setTabText(2, tr("TAB_SFX"))
        
        self.grp_global.setTitle(tr("GRP_GLOBAL_CONTROLS"))
        self.lbl_master_vol.setText(tr("LBL_MASTER_VOLUME"))
        self.btn_stop_ambience.setText(tr("BTN_STOP_AMBIENCE"))
        self.btn_stop_all.setText(tr("BTN_STOP_ALL"))
        
        if hasattr(self, 'lbl_no_themes'):
            self.lbl_no_themes.setText(tr("MSG_NO_THEMES"))
        
        # Update combo box placeholder (item 0)
        self.combo_themes.setItemText(0, tr("COMBO_SELECT_THEME"))
        self.btn_load_theme.setText("📂 " + tr("BTN_LOAD_THEME"))
        
        self.grp_states.setTitle(tr("GRP_MUSIC_STATE"))
        self.grp_intensity.setTitle(tr("GRP_INTENSITY"))
        
        # Update current intensity label based on slider value
        self.change_intensity(self.slider_intensity.value())
        
        # Update Ambience Group Titles and Combo placeholder
        for i, slot in enumerate(self.ambience_slots):
            slot['group'].setTitle(tr("LBL_AMBIENCE_SLOT") + f" {i+1}")
            slot['combo'].setItemText(0, tr("OPT_SILENCE"))

    def add_new_ambience(self):
        self._add_new_sound('ambience')

    def add_new_sfx(self):
        self._add_new_sound('sfx')

    def _add_new_sound(self, category):
        file_path, _ = QFileDialog.getOpenFileName(self, tr("TITLE_SELECT_AUDIO"), "", "Audio Files (*.mp3 *.wav *.ogg *.flac *.m4a)")
        if not file_path:
            return

        name, ok = QInputDialog.getText(self, tr("TITLE_ADD_SOUND"), tr("LBL_SOUND_NAME"))
        if not ok or not name:
            return

        success, result_or_msg = add_to_library(category, name, file_path)
        
        if success:
            # Reload library
            self.global_library = load_global_library()
            self.audio_brain.library = self.global_library
            
            if category == 'ambience':
                self._refresh_ambience_combos()
            elif category == 'sfx':
                self._build_sfx_grid() # Rebuild grid
                
            QMessageBox.information(self, tr("MSG_SUCCESS"), tr("MSG_SOUND_ADDED"))
        else:
            QMessageBox.critical(self, tr("MSG_ERROR"), str(result_or_msg))

    def _refresh_ambience_combos(self):
        # Save current selections
        current_selections = []
        for slot in self.ambience_slots:
            current_selections.append(slot['combo'].currentData())
            
        # Clear and refill
        ambience_list = self.global_library.get('ambience', [])
        for slot in self.ambience_slots:
            slot['combo'].blockSignals(True)
            slot['combo'].clear()
            slot['combo'].addItem(tr("OPT_SILENCE"), None)
            for ambience in ambience_list:
                slot['combo'].addItem(ambience['name'], ambience['id'])
            slot['combo'].blockSignals(False)
            
        # Restore selections if possible
        for i, sel_id in enumerate(current_selections):
            if sel_id:
                idx = self.ambience_slots[i]['combo'].findData(sel_id)
                if idx >= 0:
                    self.ambience_slots[i]['combo'].setCurrentIndex(idx)