from PyQt6.QtWidgets import (QWidget, QHBoxLayout, QVBoxLayout, QTextEdit, 
                             QLabel, QPushButton, QGroupBox, QInputDialog, 
                             QComboBox, QMessageBox)
from PyQt6.QtCore import QDateTime
from core.locales import tr
from ui.widgets.combat_tracker import CombatTracker
import random

class SessionTab(QWidget):
    def __init__(self, data_manager):
        super().__init__()
        self.dm = data_manager
        self.current_session_id = None
        self.init_ui()

    def init_ui(self):
        layout = QHBoxLayout(self)

        # --- SOL: SAVAŞ TAKİPÇİSİ ---
        left_layout = QVBoxLayout()
        self.combat_tracker = CombatTracker(self.dm)
        left_layout.addWidget(QLabel(tr("TITLE_COMBAT")))
        left_layout.addWidget(self.combat_tracker)
        
        # Zar Atma Paneli (Alt Sol)
        dice_group = QGroupBox(tr("GRP_DICE"))
        dice_layout = QHBoxLayout(dice_group)
        for d in [4, 6, 8, 10, 12, 20, 100]:
            btn = QPushButton(f"d{d}")
            btn.clicked.connect(lambda checked, x=d: self.roll_dice(x))
            dice_layout.addWidget(btn)
        left_layout.addWidget(dice_group)
        
        # --- SAĞ: NOTLAR & LOG ---
        right_layout = QVBoxLayout()
        
        # Session Seçici
        session_control = QHBoxLayout()
        self.combo_sessions = QComboBox()
        self.refresh_session_list()
        self.btn_new_session = QPushButton(tr("BTN_NEW_SESSION"))
        self.btn_new_session.clicked.connect(self.new_session)
        self.btn_save_session = QPushButton(tr("BTN_SAVE"))
        self.btn_save_session.clicked.connect(self.save_session)
        
        session_control.addWidget(self.combo_sessions, 2)
        session_control.addWidget(self.btn_new_session, 1)
        session_control.addWidget(self.btn_save_session, 1)
        
        self.btn_load_session = QPushButton(tr("BTN_LOAD_SESSION"))
        self.btn_load_session.clicked.connect(self.load_session)
        session_control.addWidget(self.btn_load_session)

        # Log Alanı
        self.txt_log = QTextEdit()
        self.txt_log.setPlaceholderText("Olay günlüğü (Otomatik zaman damgası)...")
        
        # Manuel Log Ekleme
        # Manuel Log Ekleme
        log_input_layout = QHBoxLayout()
        self.inp_log_entry = QTextEdit()
        self.inp_log_entry.setMaximumHeight(50)
        self.inp_log_entry.setPlaceholderText("...")
        self.btn_add_log = QPushButton(tr("BTN_ADD_LOG"))
        self.btn_add_log.clicked.connect(self.add_log)
        log_input_layout.addWidget(self.inp_log_entry)
        log_input_layout.addWidget(self.btn_add_log)

        # DM Notları
        self.txt_notes = QTextEdit()
        self.txt_notes.setPlaceholderText(tr("LBL_NOTES"))

        right_layout.addLayout(session_control)
        right_layout.addWidget(QLabel(tr("LBL_LOG")))
        right_layout.addWidget(self.txt_log)
        right_layout.addLayout(log_input_layout)
        right_layout.addWidget(QLabel(tr("LBL_NOTES")))
        right_layout.addWidget(self.txt_notes)

        layout.addLayout(left_layout, 1)
        layout.addLayout(right_layout, 1)

    def roll_dice(self, sides):
        result = random.randint(1, sides)
        self.log_message(f"🎲 Rolled d{sides}: {result}")

    def log_message(self, message):
        timestamp = QDateTime.currentDateTime().toString("HH:mm")
        self.txt_log.append(f"[{timestamp}] {message}")

    def add_log(self):
        text = self.inp_log_entry.toPlainText().strip()
        if text:
            self.log_message(text)
            self.inp_log_entry.clear()

    def new_session(self):
        name, ok = QInputDialog.getText(self, "Yeni Oturum", "Oturum Adı:")
        if ok and name:
            sid = self.dm.create_session(name)
            self.refresh_session_list()
            # Yeni session'ı seç
            index = self.combo_sessions.findData(sid)
            if index >= 0: self.combo_sessions.setCurrentIndex(index)
            self.current_session_id = sid
            self.txt_log.clear()
            self.txt_notes.clear()
            self.combat_tracker.clear_tracker()
            self.log_message(f"Oturum Başladı: {name}")

    def refresh_session_list(self):
        self.combo_sessions.clear()
        sessions = self.dm.data.get("sessions", [])
        for s in sessions:
            self.combo_sessions.addItem(s["name"], s["id"])

    def load_session(self):
        sid = self.combo_sessions.currentData()
        if not sid: return
        
        session_data = self.dm.get_session(sid)
        if session_data:
            self.current_session_id = sid
            self.txt_log.setHtml(session_data.get("logs", "")) # HTML formatında tutabiliriz
            self.txt_notes.setText(session_data.get("notes", ""))
            
            combatants = session_data.get("combatants", [])
            self.combat_tracker.load_combat_data(combatants)
            self.log_message("Oturum Yüklendi.")

    def save_session(self):
        if not self.current_session_id:
            QMessageBox.warning(self, "Hata", "Önce bir oturum oluşturun veya seçin.")
            return
            
        logs = self.txt_log.toHtml()
        notes = self.txt_notes.toPlainText()
        combatants = self.combat_tracker.get_combat_data()
        
        self.dm.save_session_data(self.current_session_id, notes, logs, combatants)
        QMessageBox.information(self, tr("MSG_SUCCESS"), tr("MSG_SUCCESS"))