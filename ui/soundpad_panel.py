import os
import copy
from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QLabel, QFrame, QPushButton, 
                             QHBoxLayout, QSlider, QComboBox, QGroupBox, QTabWidget,
                             QGridLayout, QScrollArea)
from PyQt6.QtCore import Qt, pyqtSignal
from core.locales import tr
from core.audio.engine import MusicBrain
from core.audio.loader import load_all_themes, load_global_library

class SoundpadPanel(QWidget):
    theme_loaded_with_shortcuts = pyqtSignal(dict)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedWidth(350)
        self.setObjectName("soundpadContainer")
        
        # Global kütüphaneyi yükle ve bunu kullanarak ses motorunu başlat
        self.global_library = load_global_library()
        self.audio_brain = MusicBrain(self.global_library)
        
        # Müzik temalarını yükle
        self.themes = load_all_themes()
        
        self.current_theme = None
        self.ambience_slots = []
        self.sfx_buttons = {}

        self.init_ui()
        
        # Arayüzü global kütüphane verileriyle doldur
        self._build_ambience_slots()
        self._build_sfx_grid()
        
        # Uygulama açıldığında varsayılan (global) kısayolları yükle
        self.theme_loaded_with_shortcuts.emit(self.global_library.get('shortcuts', {}))

    def init_ui(self):
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(10, 10, 10, 10)
        
        self.lbl_title = QLabel("🔊 " + tr("TITLE_SOUNDPAD"))
        self.lbl_title.setObjectName("headerLabel"); self.lbl_title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        main_layout.addWidget(self.lbl_title)
        
        self.tabs = QTabWidget(); main_layout.addWidget(self.tabs, 1)
        self.music_tab = QWidget(); self.ambience_tab = QWidget(); self.sfx_tab = QWidget()
        self.tabs.addTab(self.music_tab, "🎵 " + tr("Müzik"))
        self.tabs.addTab(self.ambience_tab, "🌿 " + tr("Ambiyans"))
        self.tabs.addTab(self.sfx_tab, "💥 " + tr("SFX"))

        self._setup_music_tab(); self._setup_ambience_tab(); self._setup_sfx_tab()
        
        global_controls_group = QGroupBox(tr("Genel Kontroller"))
        global_layout = QVBoxLayout(global_controls_group)
        
        vol_layout = QHBoxLayout(); vol_layout.addWidget(QLabel(tr("Ana Müzik Sesi")))
        self.slider_vol = QSlider(Qt.Orientation.Horizontal)
        self.slider_vol.setRange(0, 100); self.slider_vol.setValue(50)
        self.slider_vol.valueChanged.connect(self.change_master_volume)
        vol_layout.addWidget(self.slider_vol); global_layout.addLayout(vol_layout)
        
        stop_buttons_layout = QHBoxLayout()
        self.btn_stop_ambience = QPushButton(tr("Ambiyansı Durdur"))
        self.btn_stop_ambience.clicked.connect(self.stop_ambience)
        self.btn_stop_all = QPushButton(tr("Tümünü Durdur")); self.btn_stop_all.setObjectName("dangerBtn")
        self.btn_stop_all.clicked.connect(self.stop_all)
        stop_buttons_layout.addWidget(self.btn_stop_ambience); stop_buttons_layout.addWidget(self.btn_stop_all)
        global_layout.addLayout(stop_buttons_layout)
        
        main_layout.addWidget(global_controls_group)

    def _setup_music_tab(self):
        layout = QVBoxLayout(self.music_tab)
        if not self.themes:
            layout.addWidget(QLabel(tr("Hiç müzik teması bulunamadı.")))
            return

        theme_layout = QHBoxLayout()
        self.combo_themes = QComboBox(); self.combo_themes.addItem(tr("Müzik Teması Seç..."), None)
        for tid, theme in self.themes.items(): self.combo_themes.addItem(theme.name, tid)
        
        self.btn_load_theme = QPushButton("📂 " + tr("Yükle")); self.btn_load_theme.setObjectName("primaryBtn")
        self.btn_load_theme.clicked.connect(self.load_selected_theme)
        theme_layout.addWidget(self.combo_themes, 1); theme_layout.addWidget(self.btn_load_theme)
        layout.addLayout(theme_layout)

        self.grp_states = QGroupBox(tr("Müzik Durumu")); self.layout_states = QVBoxLayout(self.grp_states)
        self.grp_states.setVisible(False); layout.addWidget(self.grp_states)

        self.grp_intensity = QGroupBox(tr("Yoğunluk")); v_int = QVBoxLayout(self.grp_intensity)
        self.slider_intensity = QSlider(Qt.Orientation.Horizontal); self.slider_intensity.setRange(0, 3)
        self.slider_intensity.setTickPosition(QSlider.TickPosition.TicksBelow); self.slider_intensity.setTickInterval(1)
        self.slider_intensity.valueChanged.connect(self.change_intensity)
        self.lbl_intensity_val = QLabel("Base"); self.lbl_intensity_val.setAlignment(Qt.AlignmentFlag.AlignCenter)
        v_int.addWidget(self.slider_intensity); v_int.addWidget(self.lbl_intensity_val)
        self.grp_intensity.setVisible(False); layout.addWidget(self.grp_intensity)
        layout.addStretch()

    def _setup_ambience_tab(self):
        layout = QVBoxLayout(self.ambience_tab)
        scroll = QScrollArea(); scroll.setWidgetResizable(True); scroll.setFrameShape(QFrame.Shape.NoFrame)
        content_widget = QWidget()
        self.ambience_layout = QVBoxLayout(content_widget)
        self.ambience_layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        scroll.setWidget(content_widget); layout.addWidget(scroll)

    def _setup_sfx_tab(self):
        layout = QVBoxLayout(self.sfx_tab)
        scroll = QScrollArea(); scroll.setWidgetResizable(True); scroll.setFrameShape(QFrame.Shape.NoFrame)
        content_widget = QWidget()
        self.sfx_grid_layout = QGridLayout(content_widget)
        self.sfx_grid_layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        scroll.setWidget(content_widget); layout.addWidget(scroll)

    def _build_ambience_slots(self):
        ambience_list = self.global_library.get('ambience', [])
        for i in range(4):
            slot_box = QGroupBox(f"Ambiyans Slot {i+1}"); slot_layout = QVBoxLayout(slot_box)
            combo = QComboBox(); combo.addItem(tr("Sessizlik"), None)
            for ambience in ambience_list: combo.addItem(ambience['name'], ambience['id'])
            slider = QSlider(Qt.Orientation.Horizontal); slider.setRange(0, 100); slider.setValue(70)
            self.ambience_slots.append({'group': slot_box, 'combo': combo, 'slider': slider})
            slot_layout.addWidget(combo); slot_layout.addWidget(slider)
            self.ambience_layout.addWidget(slot_box)
            combo.currentIndexChanged.connect(lambda _, s_idx=i: self._on_ambience_change(s_idx))
            slider.valueChanged.connect(lambda value, s_idx=i: self._on_ambience_volume_change(s_idx, value))

    def _build_sfx_grid(self):
        sfx_list = self.global_library.get('sfx', [])
        row, col = 0, 0
        for sfx in sfx_list:
            btn = QPushButton(sfx['name']); btn.setMinimumHeight(40)
            btn.clicked.connect(lambda _, s_id=sfx['id']: self.play_sfx(s_id))
            self.sfx_grid_layout.addWidget(btn, row, col)
            self.sfx_buttons[sfx['id']] = btn
            col += 1
            if col > 1: col = 0; row += 1

    def _rebuild_state_buttons(self):
        while self.layout_states.count(): self.layout_states.takeAt(0).widget().deleteLater()
        if not self.current_theme: return
        self.state_buttons = {} 
        for state_name in self.current_theme.states.keys():
            btn = QPushButton(state_name.title()); btn.setCheckable(True)
            btn.clicked.connect(lambda _, s=state_name: self.on_state_clicked(s))
            self.layout_states.addWidget(btn); self.state_buttons[state_name] = btn

    def load_selected_theme(self):
        tid = self.combo_themes.currentData()
        if tid is None:
            self.current_theme = None
            self.grp_states.setVisible(False); self.grp_intensity.setVisible(False)
            self.theme_loaded_with_shortcuts.emit(self.global_library.get('shortcuts', {}))
            self.audio_brain.set_theme(None)
            return
        
        self.current_theme = self.themes[tid]
        self.audio_brain.set_theme(self.current_theme)
        self._rebuild_state_buttons()
        self.grp_states.setVisible(True); self.slider_intensity.setValue(0); self.grp_intensity.setVisible(True)
        final_shortcuts = self._merge_shortcuts()
        self.theme_loaded_with_shortcuts.emit(final_shortcuts)

    def _merge_shortcuts(self):
        final_shortcuts = copy.deepcopy(self.global_library.get('shortcuts', {}))
        if not self.current_theme: return final_shortcuts
        theme_shortcuts = getattr(self.current_theme, 'shortcuts', {})
        for key, value in theme_shortcuts.items():
            if isinstance(value, dict):
                if key not in final_shortcuts: final_shortcuts[key] = {}
                for sub_key, sub_value in value.items(): final_shortcuts[key][sub_key] = sub_value
            else: final_shortcuts[key] = value
        return final_shortcuts

    def on_state_clicked(self, state_name):
        self.audio_brain.queue_state(state_name)
        for name, btn in self.state_buttons.items(): btn.setChecked(name == state_name)

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
            slot['combo'].blockSignals(True); slot['combo'].setCurrentIndex(0); slot['combo'].blockSignals(False)

    def stop_all(self):
        self.audio_brain.stop_all()
        self.stop_ambience()
        if self.combo_themes.currentIndex() > 0:
            self.combo_themes.setCurrentIndex(0); self.load_selected_theme()

    def change_master_volume(self, value):
        self.audio_brain.set_master_volume(value / 100.0)

    def change_intensity(self, value):
        labels = ["Base", "Low", "Medium", "High"]
        self.lbl_intensity_val.setText(labels[value] if value < len(labels) else str(value))
        self.audio_brain.set_intensity(value)

    def retranslate_ui(self):
        self.lbl_title.setText("🔊 " + tr("TITLE_SOUNDPAD"))
        self.tabs.setTabText(0, "🎵 " + tr("Müzik"))
        self.tabs.setTabText(1, "🌿 " + tr("Ambiyans"))
        self.tabs.setTabText(2, "💥 " + tr("SFX"))
        # Diğer UI elemanları için çeviri güncellemeleri de buraya eklenebilir.