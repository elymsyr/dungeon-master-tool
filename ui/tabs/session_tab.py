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
        
        # --- UYGULAMA AÇILINCA SON OTURUMU YÜKLE ---
        last_sid = self.dm.get_last_active_session_id()
        if last_sid:
            # Combo box'ta bul ve seç
            idx = self.combo_sessions.findData(last_sid)
            if idx >= 0:
                self.combo_sessions.setCurrentIndex(idx)
                self.load_session() # Otomatik yükle

    def init_ui(self):
        layout = QHBoxLayout(self)

        # --- SOL: SAVAŞ TAKİPÇİSİ ---
        left_layout = QVBoxLayout()
        self.combat_tracker = CombatTracker(self.dm)
        
        # OTOMATİK KAYIT BAĞLANTISI
        # CombatTracker'da veri değişince save_session'ı tetikle
        self.combat_tracker.data_changed_signal.connect(self.auto_save)
        
        left_layout.addWidget(QLabel(tr("TITLE_COMBAT")))
        left_layout.addWidget(self.combat_tracker)
        
        # Zar Paneli
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
        
        # Session değişince otomatik yükle (opsiyonel ama kullanışlı)
        # self.combo_sessions.currentIndexChanged.connect(self.load_session) 
        # Ancak kullanıcı yeni oluştururken vs karışabilir, butona bırakalım şimdilik.
        
        self.btn_new_session = QPushButton(tr("BTN_NEW_SESSION"))
        self.btn_new_session.clicked.connect(self.new_session)
        
        # Manuel Kayıt Butonu (Auto-save var ama kullanıcılar basmayı sever)
        self.btn_save_session = QPushButton(tr("BTN_SAVE"))
        self.btn_save_session.clicked.connect(lambda: self.save_session(show_msg=True))
        
        session_control.addWidget(self.combo_sessions, 2)
        session_control.addWidget(self.btn_new_session, 1)
        session_control.addWidget(self.btn_save_session, 1)
        
        self.btn_load_session = QPushButton(tr("BTN_LOAD_SESSION"))
        self.btn_load_session.clicked.connect(self.load_session)
        session_control.addWidget(self.btn_load_session)

        # Log
        self.txt_log = QTextEdit()
        self.txt_log.setPlaceholderText("Olay günlüğü...")
        # Log değişince de kaydet
        self.txt_log.textChanged.connect(self.auto_save)
        
        log_input_layout = QHBoxLayout()
        self.inp_log_entry = QTextEdit()
        self.inp_log_entry.setMaximumHeight(50)
        self.btn_add_log = QPushButton(tr("BTN_ADD_LOG"))
        self.btn_add_log.clicked.connect(self.add_log)
        log_input_layout.addWidget(self.inp_log_entry)
        log_input_layout.addWidget(self.btn_add_log)

        # Notlar
        self.txt_notes = QTextEdit()
        self.txt_notes.setPlaceholderText(tr("LBL_NOTES"))
        # Not değişince de kaydet
        self.txt_notes.textChanged.connect(self.auto_save)

        right_layout.addLayout(session_control)
        right_layout.addWidget(QLabel(tr("LBL_LOG")))
        right_layout.addWidget(self.txt_log)
        right_layout.addLayout(log_input_layout)
        right_layout.addWidget(QLabel(tr("LBL_NOTES")))
        right_layout.addWidget(self.txt_notes)

        layout.addLayout(left_layout, 1)
        layout.addLayout(right_layout, 1)

    # --- FONKSİYONLAR ---
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
            idx = self.combo_sessions.findData(sid)
            if idx >= 0: self.combo_sessions.setCurrentIndex(idx)
            
            self.current_session_id = sid
            self.txt_log.clear()
            self.txt_notes.clear()
            self.combat_tracker.clear_tracker()
            self.log_message(f"Oturum Başladı: {name}")
            self.save_session(show_msg=False) # İlk kaydı yap

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
            self.dm.set_active_session(sid) # Aktif olarak işaretle
            
            # Notlar ve Loglar
            self.txt_log.blockSignals(True)
            self.txt_notes.blockSignals(True)
            self.txt_log.setHtml(session_data.get("logs", ""))
            self.txt_notes.setText(session_data.get("notes", ""))
            self.txt_log.blockSignals(False)
            self.txt_notes.blockSignals(False)
            
            # Combat State
            combatants_data = session_data.get("combatants", [])
            if isinstance(combatants_data, dict):
                 self.combat_tracker.load_session_state(combatants_data)
            else:
                 self.combat_tracker.load_combat_data(combatants_data)
            
            # Loga yazma (Gereksiz kalabalık etmesin)
            # self.log_message("Oturum Yüklendi.")

    def auto_save(self):
        """Kullanıcıya mesaj göstermeden sessizce kaydeder."""
        if self.current_session_id:
            self.save_session(show_msg=False)

    def save_session(self, show_msg=False):
        if not self.current_session_id:
            if show_msg: QMessageBox.warning(self, "Hata", "Önce bir oturum oluşturun.")
            return
            
        logs = self.txt_log.toHtml()
        notes = self.txt_notes.toPlainText()
        combat_state = self.combat_tracker.get_session_state()
        
        self.dm.save_session_data(self.current_session_id, notes, logs, combat_state)
        
        if show_msg:
            QMessageBox.information(self, tr("MSG_SUCCESS"), "Kaydedildi.")