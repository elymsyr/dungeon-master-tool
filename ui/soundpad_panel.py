import os
from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QLabel, QFrame, QPushButton, 
                             QHBoxLayout, QSlider, QComboBox, QGroupBox, QScrollArea)
from PyQt6.QtCore import Qt
from core.locales import tr
from core.audio.engine import MusicBrain
from core.audio.loader import load_all_themes

class SoundpadPanel(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFixedWidth(320)
        self.setObjectName("soundpadContainer")
        
        # Ses Motoru
        self.audio_brain = MusicBrain()
        
        # Temalar
        self.themes = load_all_themes()
        self.current_theme = None
        
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(10, 10, 10, 10)
        
        # Başlık
        self.lbl_title = QLabel("🔊 " + tr("TITLE_SOUNDPAD"))
        self.lbl_title.setObjectName("headerLabel")
        self.lbl_title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.lbl_title.setStyleSheet("font-size: 18px; font-weight: bold; margin-bottom: 10px;")
        layout.addWidget(self.lbl_title)
        
        # --- İÇERİK ---
        self.content_frame = QFrame()
        self.content_frame.setStyleSheet("background-color: rgba(0, 0, 0, 0.2); border-radius: 6px;")
        self.v_box = QVBoxLayout(self.content_frame)
        
        if not self.themes:
            lbl_err = QLabel("No themes found.\nCheck assets/soundpad folder.")
            lbl_err.setStyleSheet("color: #ff5555; font-style: italic;")
            lbl_err.setAlignment(Qt.AlignmentFlag.AlignCenter)
            self.v_box.addWidget(lbl_err)
        else:
            # 1. Tema Seçimi
            lbl_select = QLabel("Select Theme:")
            self.combo_themes = QComboBox()
            for tid, theme in self.themes.items():
                self.combo_themes.addItem(theme.name, tid)
            
            # Tema Yükle Butonu
            self.btn_load_theme = QPushButton("📂 Load Theme")
            self.btn_load_theme.setObjectName("primaryBtn")
            self.btn_load_theme.clicked.connect(self.load_selected_theme)
            
            self.v_box.addWidget(lbl_select)
            self.v_box.addWidget(self.combo_themes)
            self.v_box.addWidget(self.btn_load_theme)
            
            self.v_box.addSpacing(15)
            
            # 2. State (Mod) Butonları Alanı (Dinamik)
            self.grp_states = QGroupBox("Mood / State")
            self.grp_states.setStyleSheet("QGroupBox { font-weight: bold; border: 1px solid #555; margin-top: 5px; }")
            self.layout_states = QVBoxLayout(self.grp_states)
            self.v_box.addWidget(self.grp_states)
            self.grp_states.setVisible(False) # Başlangıçta gizli
            
            self.v_box.addSpacing(15)
            
            # 3. Intensity Slider
            self.grp_intensity = QGroupBox("Intensity")
            self.grp_intensity.setStyleSheet("QGroupBox { font-weight: bold; border: 1px solid #555; margin-top: 5px; }")
            v_int = QVBoxLayout(self.grp_intensity)
            
            self.slider_intensity = QSlider(Qt.Orientation.Horizontal)
            self.slider_intensity.setRange(0, 2) # Base, Lv1, Lv2
            self.slider_intensity.setTickPosition(QSlider.TickPosition.TicksBelow)
            self.slider_intensity.setTickInterval(1)
            self.slider_intensity.setValue(0)
            self.slider_intensity.valueChanged.connect(self.change_intensity)
            
            self.lbl_intensity_val = QLabel("Base")
            self.lbl_intensity_val.setAlignment(Qt.AlignmentFlag.AlignCenter)
            
            v_int.addWidget(self.slider_intensity)
            v_int.addWidget(self.lbl_intensity_val)
            self.v_box.addWidget(self.grp_intensity)
            self.grp_intensity.setVisible(False) # Başlangıçta gizli
            
            self.v_box.addStretch()
            
            # 4. Master Volume & Stop
            lbl_vol = QLabel("Master Volume")
            self.slider_vol = QSlider(Qt.Orientation.Horizontal)
            self.slider_vol.setRange(0, 100)
            self.slider_vol.setValue(50)
            self.slider_vol.valueChanged.connect(self.change_volume)
            
            self.btn_stop = QPushButton("⏹️ Stop All")
            self.btn_stop.setObjectName("dangerBtn")
            self.btn_stop.clicked.connect(self.stop_all)
            
            self.v_box.addWidget(lbl_vol)
            self.v_box.addWidget(self.slider_vol)
            self.v_box.addSpacing(5)
            self.v_box.addWidget(self.btn_stop)

        layout.addWidget(self.content_frame)

    def load_selected_theme(self):
        tid = self.combo_themes.currentData()
        if tid in self.themes:
            self.current_theme = self.themes[tid]
            
            # Motoru güncelle
            self.audio_brain.set_theme(self.current_theme)
            
            # Slider sıfırla
            self.slider_intensity.setValue(0)
            self.lbl_intensity_val.setText("Base")
            self.grp_intensity.setVisible(True)
            
            # State butonlarını oluştur
            self._rebuild_state_buttons()
            self.grp_states.setVisible(True)

    def _rebuild_state_buttons(self):
        # Eski butonları temizle
        while self.layout_states.count():
            child = self.layout_states.takeAt(0)
            if child.widget():
                child.widget().deleteLater()
        
        if not self.current_theme: return

        # Yeni butonları ekle
        for state_name in self.current_theme.states.keys():
            btn = QPushButton(state_name.title()) # 'combat' -> 'Combat'
            
            # Renk kodlaması (Opsiyonel ama şık durur)
            if state_name.lower() == "combat":
                btn.setObjectName("dangerBtn") # Kırmızı
            elif state_name.lower() == "victory":
                btn.setObjectName("successBtn") # Yeşil
            else:
                btn.setObjectName("primaryBtn") # Mavi/Gri
                
            # Lambda'da state_name'i sabitlemek önemli
            btn.clicked.connect(lambda checked, s=state_name: self.audio_brain.set_state(s))
            
            self.layout_states.addWidget(btn)

    def change_intensity(self, val):
        labels = ["Base", "Low", "High", "Epic"]
        text = labels[val] if val < len(labels) else str(val)
        self.lbl_intensity_val.setText(text)
        
        self.audio_brain.set_intensity(val)

    def change_volume(self, val):
        self.audio_brain.set_volume(val / 100.0)

    def stop_all(self):
        self.audio_brain.stop()

    def retranslate_ui(self):
        self.lbl_title.setText("🔊 " + tr("TITLE_SOUNDPAD"))