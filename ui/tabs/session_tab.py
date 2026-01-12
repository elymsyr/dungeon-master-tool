from PyQt6.QtWidgets import (QWidget, QHBoxLayout, QVBoxLayout, QTextEdit, 
                             QLabel, QPushButton, QGroupBox, QInputDialog, 
                             QComboBox, QMessageBox, QTabWidget)
from PyQt6.QtCore import QDateTime
from core.locales import tr
from ui.widgets.combat_tracker import CombatTracker
from ui.widgets.markdown_editor import MarkdownEditor
from ui.windows.battle_map_window import BattleMapWidget # Yeni Widget
import random

class SessionTab(QWidget):
    def __init__(self, data_manager):
        super().__init__()
        self.dm = data_manager
        self.current_session_id = None
        self.init_ui()
        
        last_sid = self.dm.get_last_active_session_id()
        if last_sid:
            idx = self.combo_sessions.findData(last_sid)
            if idx >= 0:
                self.combo_sessions.setCurrentIndex(idx)
                self.load_session()
        elif self.combo_sessions.count() > 0:
            self.combo_sessions.setCurrentIndex(0)
            self.load_session()

    def init_ui(self):
        layout = QHBoxLayout(self)

        # --- SOL: SAVAŞ TAKİPÇİSİ ---
        left_layout = QVBoxLayout()
        self.combat_tracker = CombatTracker(self.dm)
        
        # Bağlantılar
        self.combat_tracker.data_changed_signal.connect(self.auto_save)
        # CombatTracker değiştiğinde gömülü haritayı güncelle
        self.combat_tracker.data_changed_signal.connect(self.refresh_embedded_map)
        
        left_layout.addWidget(QLabel(tr("TITLE_COMBAT")))
        left_layout.addWidget(self.combat_tracker)
        
        dice_group = QGroupBox(tr("GRP_DICE"))
        dice_layout = QHBoxLayout(dice_group)
        for d in [4, 6, 8, 10, 12, 20, 100]:
            btn = QPushButton(f"d{d}")
            btn.clicked.connect(lambda checked, x=d: self.roll_dice(x))
            dice_layout.addWidget(btn)
        left_layout.addWidget(dice_group)
        
        # --- SAĞ: KONTROLLER VE TABLAR ---
        right_layout = QVBoxLayout()
        
        # Session Kontrolleri
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

        # Log
        self.txt_log = MarkdownEditor()
        self.txt_log.setPlaceholderText(tr("LBL_EVENT_LOG_PH"))
        self.txt_log.textChanged.connect(self.auto_save)
        self.txt_log.set_data_manager(self.dm)
        if hasattr(self.parent(), "db_tab"):
             self.txt_log.entity_link_clicked.connect(self.parent().db_tab.open_entity_tab)
        
        log_input_layout = QHBoxLayout()
        self.inp_log_entry = QTextEdit()
        self.inp_log_entry.setMaximumHeight(50)
        self.inp_log_entry.setPlaceholderText("Hızlı log ekle...")
        self.btn_add_log = QPushButton(tr("BTN_ADD_LOG"))
        self.btn_add_log.clicked.connect(self.add_log)
        log_input_layout.addWidget(self.inp_log_entry)
        log_input_layout.addWidget(self.btn_add_log)

        # --- ALT KISIM: TABLAR (DM Notes | Battle Map) ---
        self.bottom_tabs = QTabWidget()
        
        # TAB 1: DM Notes
        self.tab_dm_notes = QWidget()
        notes_layout = QVBoxLayout(self.tab_dm_notes)
        notes_layout.setContentsMargins(0, 0, 0, 0)
        self.txt_notes = MarkdownEditor()
        self.txt_notes.setPlaceholderText(tr("LBL_NOTES"))
        self.txt_notes.textChanged.connect(self.auto_save)
        notes_layout.addWidget(self.txt_notes)
        
        # TAB 2: Battle Map (Embedded)
        self.embedded_map = BattleMapWidget()
        
        # Gömülü haritadan gelen hareket sinyalleri CombatTracker'a gidiyor
        self.embedded_map.token_moved_signal.connect(self.combat_tracker.on_token_moved_in_map)
        self.embedded_map.token_size_changed_signal.connect(self.combat_tracker.on_token_size_changed)
        
        # YENİ: Gömülü haritadaki zoom/pan hareketini dış pencereye aktar
        self.embedded_map.view_sync_signal.connect(self.combat_tracker.sync_map_view_to_external)
        
        self.bottom_tabs.addTab(self.tab_dm_notes, "📝 " + tr("LBL_NOTES"))
        self.bottom_tabs.addTab(self.embedded_map, "🗺️ " + tr("TITLE_BATTLE_MAP"))

        right_layout.addLayout(session_control)
        right_layout.addWidget(QLabel(tr("LBL_LOG")))
        right_layout.addWidget(self.txt_log, 1) 
        right_layout.addLayout(log_input_layout)
        right_layout.addWidget(self.bottom_tabs, 2) 

        layout.addLayout(left_layout, 2)
        layout.addLayout(right_layout, 3)

    # ... (roll_dice, log_message, add_log, new_session vb. aynı kalıyor) ...
    # Sadece yeni eklenen fonksiyonları buraya yazıyorum:

    def refresh_embedded_map(self):
        """
        Combat Tracker'daki değişiklikleri gömülü haritaya yansıtır.
        """
        # Eğer aktif bir encounter yoksa çık
        if not self.combat_tracker.current_encounter_id: 
            return
        
        enc = self.combat_tracker.encounters.get(self.combat_tracker.current_encounter_id)
        if not enc: return
        
        # Eğer gömülü harita görünür değilse güncelleme yapma (Performans)
        # Ama verilerin güncel kalması için yapmak daha güvenli olabilir.
        
        combatants = []
        for c in enc.get("combatants", []):
             t = "NPC"; a = "LBL_ATTR_NEUTRAL"
             if c["eid"] in self.dm.data["entities"]:
                  e = self.dm.data["entities"][c["eid"]]
                  t = e.get("type", "NPC")
                  a = e.get("attributes", {}).get("LBL_ATTITUDE", "LBL_ATTR_NEUTRAL")
                  if t == "Monster": a = "LBL_ATTR_HOSTILE"
             c["type"] = t
             c["attitude"] = a
             combatants.append(c)
             
        map_path = self.dm.get_full_path(enc.get("map_path"))
        
        # BattleMapWidget'ın yeni akıllı update fonksiyonunu çağır
        self.embedded_map.update_tokens(
            combatants, 
            enc.get("turn_index", -1), 
            self.dm, 
            map_path, 
            enc.get("token_size", 50)
        )

    def load_session(self):
        # ... Mevcut load_session kodunun sonuna ekle:
        # Session yüklendiğinde haritayı da tetikle
        self.refresh_embedded_map() 
    
    # ... (Diğer fonksiyonlar: save_session, auto_save vb. aynı) ...
    def roll_dice(self, sides):
        result = random.randint(1, sides)
        self.log_message(tr("MSG_ROLLED_DICE", sides=sides, result=result))

    def log_message(self, message):
        timestamp = QDateTime.currentDateTime().toString("HH:mm")
        current_text = self.txt_log.toPlainText()
        new_line = f"**[{timestamp}]** {message}"
        if current_text: self.txt_log.setText(current_text + "\n" + new_line)
        else: self.txt_log.setText(new_line)

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
            self.txt_log.blockSignals(True)
            self.txt_notes.blockSignals(True)
            self.txt_log.setText(session_data.get("logs", ""))
            self.txt_notes.setText(session_data.get("notes", ""))
            self.txt_log.blockSignals(False)
            self.txt_notes.blockSignals(False)
            combatants_data = session_data.get("combatants", [])
            if isinstance(combatants_data, dict): self.combat_tracker.load_session_state(combatants_data)
            else: self.combat_tracker.load_combat_data(combatants_data)
            self.refresh_embedded_map() # EKLENDİ

    def load_session_by_id(self, session_id):
        idx = self.combo_sessions.findData(session_id)
        if idx >= 0:
            self.combo_sessions.setCurrentIndex(idx)
            self.load_session()
        else:
            QMessageBox.warning(self, tr("MSG_WARNING"), "Oturum bulunamadı veya silinmiş.")

    def auto_save(self):
        if self.current_session_id: self.save_session(show_msg=False)

    def save_session(self, show_msg=False):
        if not self.current_session_id:
            if show_msg: QMessageBox.warning(self, tr("MSG_ERROR"), tr("MSG_CREATE_SESSION_FIRST"))
            return
        logs = self.txt_log.toPlainText()
        notes = self.txt_notes.toPlainText()
        combat_state = self.combat_tracker.get_session_state()
        self.dm.save_session_data(self.current_session_id, notes, logs, combat_state)