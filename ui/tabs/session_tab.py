from PyQt6.QtWidgets import (QWidget, QHBoxLayout, QVBoxLayout, QTextEdit, 
                             QLabel, QPushButton, QGroupBox, QInputDialog, 
                             QComboBox, QMessageBox)
from PyQt6.QtCore import QDateTime
from core.locales import tr
from ui.widgets.combat_tracker import CombatTracker
from ui.widgets.markdown_editor import MarkdownEditor # Yeni Markdown Bileşeni
import random

class SessionTab(QWidget):
    def __init__(self, data_manager):
        super().__init__()
        self.dm = data_manager
        self.current_session_id = None
        self.init_ui()
        
        # Son aktif oturumu yükle
        last_sid = self.dm.get_last_active_session_id()
        
        if last_sid:
            idx = self.combo_sessions.findData(last_sid)
            if idx >= 0:
                self.combo_sessions.setCurrentIndex(idx)
                self.load_session()
        elif self.combo_sessions.count() > 0:
            # ID yok ama listede session varsa ilkini seç
            self.combo_sessions.setCurrentIndex(0)
            self.load_session()

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
        
        # Session Seçici ve Kontroller
        session_control = QHBoxLayout()
        self.combo_sessions = QComboBox()
        self.refresh_session_list()
        
        self.btn_new_session = QPushButton(tr("BTN_NEW_SESSION"))
        self.btn_new_session.clicked.connect(self.new_session)
        
        self.btn_save_session = QPushButton(tr("BTN_SAVE"))
        self.btn_save_session.clicked.connect(lambda: self.save_session(show_msg=True))
        
        self.btn_load_session = QPushButton(tr("BTN_LOAD_SESSION"))
        self.btn_load_session.clicked.connect(self.load_session)
        
        session_control.addWidget(self.combo_sessions, 2)
        session_control.addWidget(self.btn_new_session, 1)
        session_control.addWidget(self.btn_save_session, 1)
        session_control.addWidget(self.btn_load_session, 1)

        # --- LOG ALANI (MARKDOWN EDITOR) ---
        self.txt_log = MarkdownEditor()
        self.txt_log.setPlaceholderText(tr("LBL_EVENT_LOG_PH"))
        # Değişiklik olduğunda otomatik kaydet
        self.txt_log.textChanged.connect(self.auto_save)
        
        # Hızlı Log Girişi (Standart TextEdit kalabilir, sadece ekleme yapıyor)
        log_input_layout = QHBoxLayout()
        self.inp_log_entry = QTextEdit()
        self.inp_log_entry.setMaximumHeight(50)
        self.inp_log_entry.setPlaceholderText("Hızlı log ekle...")
        
        self.btn_add_log = QPushButton(tr("BTN_ADD_LOG"))
        self.btn_add_log.clicked.connect(self.add_log)
        
        log_input_layout.addWidget(self.inp_log_entry)
        log_input_layout.addWidget(self.btn_add_log)

        # --- NOTLAR ALANI (MARKDOWN EDITOR) ---
        self.txt_notes = MarkdownEditor()
        self.txt_notes.setPlaceholderText(tr("LBL_NOTES"))
        self.txt_notes.textChanged.connect(self.auto_save)

        self.txt_log.set_data_manager(self.dm)
        if hasattr(self.parent(), "db_tab"):
             self.txt_log.entity_link_clicked.connect(self.parent().db_tab.open_entity_tab)

        # Yerleşim
        right_layout.addLayout(session_control)
        right_layout.addWidget(QLabel(tr("LBL_LOG")))
        right_layout.addWidget(self.txt_log)
        right_layout.addLayout(log_input_layout)
        right_layout.addWidget(QLabel(tr("LBL_NOTES")))
        right_layout.addWidget(self.txt_notes)

        layout.addLayout(left_layout, 1)
        layout.addLayout(right_layout, 1)

    def retranslate_ui(self):
        self.btn_new_session.setText(tr("BTN_NEW_SESSION"))
        self.btn_save_session.setText(tr("BTN_SAVE"))
        self.btn_load_session.setText(tr("BTN_LOAD_SESSION"))
        self.txt_log.setPlaceholderText(tr("LBL_EVENT_LOG_PH"))
        self.btn_add_log.setText(tr("BTN_ADD_LOG"))
        self.txt_notes.setPlaceholderText(tr("LBL_NOTES"))
        
        if hasattr(self.combat_tracker, "retranslate_ui"):
            self.combat_tracker.retranslate_ui()

    # --- FONKSİYONLAR ---
    def roll_dice(self, sides):
        result = random.randint(1, sides)
        self.log_message(tr("MSG_ROLLED_DICE", sides=sides, result=result))

    def log_message(self, message):
        """Loga zaman damgalı mesaj ekler."""
        timestamp = QDateTime.currentDateTime().toString("HH:mm")
        # MarkdownEditor'e ekleme yapmak için mevcut metni alıp sonuna ekliyoruz
        current_text = self.txt_log.toPlainText()
        new_line = f"**[{timestamp}]** {message}"
        
        if current_text:
            self.txt_log.setText(current_text + "\n" + new_line)
        else:
            self.txt_log.setText(new_line)
            
        # Değişiklik sinyali otomatik gideceği için auto_save çalışır

    def add_log(self):
        text = self.inp_log_entry.toPlainText().strip()
        if text:
            self.log_message(text)
            self.inp_log_entry.clear()

    def new_session(self):
        name, ok = QInputDialog.getText(self, tr("TITLE_NEW_SESSION"), tr("LBL_SESSION_NAME"))
        if ok and name:
            sid = self.dm.create_session(name)
            self.refresh_session_list()
            idx = self.combo_sessions.findData(sid)
            if idx >= 0: self.combo_sessions.setCurrentIndex(idx)
            
            self.current_session_id = sid
            self.txt_log.setText("")
            self.txt_notes.setText("")
            self.combat_tracker.clear_tracker()
            self.log_message(tr("MSG_SESSION_STARTED", name=name))
            self.save_session(show_msg=False)

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
            self.dm.set_active_session(sid) 
            
            # Markdown Editörlerini Doldur
            # Sinyalleri geçici olarak durduruyoruz ki yüklerken auto_save tetiklenmesin
            self.txt_log.blockSignals(True)
            self.txt_notes.blockSignals(True)
            
            self.txt_log.setText(session_data.get("logs", ""))
            self.txt_notes.setText(session_data.get("notes", ""))
            
            self.txt_log.blockSignals(False)
            self.txt_notes.blockSignals(False)
            
            # Combat State
            combatants_data = session_data.get("combatants", [])
            if isinstance(combatants_data, dict):
                 self.combat_tracker.load_session_state(combatants_data)
            else:
                 self.combat_tracker.load_combat_data(combatants_data)

    def load_session_by_id(self, session_id):
        """Timeline'dan veya dışarıdan çağrıldığında spesifik bir oturumu yükler."""
        idx = self.combo_sessions.findData(session_id)
        if idx >= 0:
            self.combo_sessions.setCurrentIndex(idx)
            self.load_session()
        else:
            QMessageBox.warning(self, tr("MSG_WARNING"), "Oturum bulunamadı veya silinmiş.")

    def auto_save(self):
        """Kullanıcıya mesaj göstermeden sessizce kaydeder."""
        if self.current_session_id:
            self.save_session(show_msg=False)

    def save_session(self, show_msg=False):
        if not self.current_session_id:
            if show_msg: QMessageBox.warning(self, tr("MSG_ERROR"), tr("MSG_CREATE_SESSION_FIRST"))
            return
            
        # MarkdownEditor'den ham metni (Markdown) alıyoruz
        logs = self.txt_log.toPlainText()
        notes = self.txt_notes.toPlainText()
        combat_state = self.combat_tracker.get_session_state()
        
        self.dm.save_session_data(self.current_session_id, notes, logs, combat_state)