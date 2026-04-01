from PyQt6.QtWidgets import (QWidget, QHBoxLayout, QVBoxLayout, QTextEdit, 
                             QLabel, QPushButton, QGroupBox, QInputDialog, 
                             QComboBox, QMessageBox, QTabWidget, QSplitter, QStackedWidget)
from PyQt6.QtCore import QDateTime, Qt, QTimer
from PyQt6.QtGui import QTextCursor
from core.locales import tr
from ui.widgets.combat_tracker import CombatTracker
from ui.widgets.markdown_editor import MarkdownEditor
from ui.widgets.npc_sheet import NpcSheet
from ui.widgets.player_screen_widget import PlayerScreenWidget
from ui.windows.battle_map_window import BattleMapWidget
import random

class SessionTab(QWidget):
    def __init__(self, data_manager, player_window=None, event_bus=None):
        super().__init__()
        self.dm = data_manager
        self._player_window = player_window
        self.current_session_id = None
        self.fog_dirty_ids = set()
        self.annotation_dirty_ids = set()
        self._autosave_timer = QTimer(self)
        self._autosave_timer.setSingleShot(True)
        self._autosave_timer.setInterval(400)
        self._autosave_timer.timeout.connect(self._perform_debounced_save)
        self.init_ui()
        self._apply_edit_mode(False)  # Start in read-only mode
        if event_bus:
            event_bus.subscribe("edit_mode.changed", self._apply_edit_mode)
        
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
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)
        
        self.main_splitter = QSplitter(Qt.Orientation.Horizontal)
        self.main_splitter.setHandleWidth(4)

        # --- LEFT PANEL (Combat Tracker) ---
        left_widget = QWidget()
        left_layout = QVBoxLayout(left_widget)
        left_layout.setContentsMargins(5, 5, 5, 5)
        
        # CHANGED: Allow resizing small
        left_widget.setMinimumWidth(100)
        
        self.combat_tracker = CombatTracker(self.dm, self._player_window)
        self.combat_tracker.set_fog_save_handler(self.save_fog_for_encounter)
        self.combat_tracker.data_changed_signal.connect(self.refresh_embedded_map)
        self.combat_tracker.data_changed_signal.connect(self.auto_save)
        self.combat_tracker.combat_log.connect(self.log_message)
        self.combat_tracker.combatant_selected.connect(self._on_combatant_selected)
        self.combat_tracker.view_entity_requested.connect(
            lambda: self.bottom_tabs.setCurrentWidget(self._entity_stack)
        )
        
        left_layout.addWidget(QLabel(tr("TITLE_COMBAT")))
        left_layout.addWidget(self.combat_tracker)
        
        dice_group = QGroupBox(tr("GRP_DICE"))
        dice_layout = QHBoxLayout(dice_group)
        for d in [4, 6, 8, 10, 12, 20, 100]:
            btn = QPushButton(f"d{d}")
            btn.clicked.connect(lambda checked, x=d: self.roll_dice(x))
            dice_layout.addWidget(btn)
        left_layout.addWidget(dice_group)
        
        # --- RIGHT PANEL (Session Controls + Map) ---
        right_widget = QWidget()
        right_layout = QVBoxLayout(right_widget)
        right_layout.setContentsMargins(5, 5, 5, 5)
        
        # CHANGED: Allow resizing small
        right_widget.setMinimumWidth(100)
        
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

        self.txt_log = MarkdownEditor()
        self.txt_log.set_toggle_button_visible(False)
        self.txt_log.setPlaceholderText(tr("LBL_EVENT_LOG_PH"))
        self.txt_log.textChanged.connect(self.auto_save)
        self.txt_log.set_data_manager(self.dm)
        if hasattr(self.parent(), "db_tab"):
             self.txt_log.entity_link_clicked.connect(self.parent().db_tab.open_entity_tab)
        
        log_input_layout = QHBoxLayout()
        self.inp_log_entry = QTextEdit()
        self.inp_log_entry.setMaximumHeight(50)
        self.inp_log_entry.setPlaceholderText(tr("PH_QUICK_LOG"))
        self.btn_add_log = QPushButton(tr("BTN_ADD_LOG"))
        self.btn_add_log.clicked.connect(self.add_log)
        log_input_layout.addWidget(self.inp_log_entry)
        log_input_layout.addWidget(self.btn_add_log)

        self.bottom_tabs = QTabWidget()
        # Entity stats panel (read-only NpcSheet)
        self._entity_stack = QStackedWidget()
        self._entity_placeholder = QLabel(tr("LBL_SELECT_COMBATANT"))
        self._entity_placeholder.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._entity_npc_sheet = NpcSheet(self.dm)
        self._entity_npc_sheet.set_edit_mode(False)
        self._entity_stack.addWidget(self._entity_placeholder)      # index 0
        self._entity_stack.addWidget(self._entity_npc_sheet)        # index 1

        self.tab_dm_notes = QWidget()
        notes_layout = QVBoxLayout(self.tab_dm_notes)
        notes_layout.setContentsMargins(0, 0, 0, 0)
        self.txt_notes = MarkdownEditor()
        self.txt_notes.set_toggle_button_visible(False)
        self.txt_notes.setPlaceholderText(tr("LBL_NOTES"))
        self.txt_notes.textChanged.connect(self.auto_save)
        notes_layout.addWidget(self.txt_notes)
        
        self.embedded_map = BattleMapWidget(is_dm_view=True)
        self.embedded_map.token_moved_signal.connect(self.combat_tracker.on_token_moved_in_map)
        self.embedded_map.token_size_changed_signal.connect(self.combat_tracker.on_token_size_changed)
        self.embedded_map.grid_settings_changed.connect(self.combat_tracker.on_grid_settings_changed)
        self.embedded_map.view_sync_signal.connect(self.combat_tracker.sync_map_view_to_external)
        self.embedded_map.fog_update_signal.connect(self.combat_tracker.sync_fog_to_external)
        self.embedded_map.annotation_update_signal.connect(self.combat_tracker.sync_annotation_to_external)
        self.embedded_map.measurement_update_signal.connect(self.combat_tracker.sync_measurement_to_external)
        self.embedded_map.fog_update_signal.connect(self._on_embedded_fog_changed)
        self.embedded_map.annotation_update_signal.connect(self._on_embedded_annotation_changed)
        
        self.btn_load_map = QPushButton(tr("BTN_LOAD_MAP") if hasattr(tr, "BTN_LOAD_MAP") else "Load Map")
        self.btn_load_map.setObjectName("primaryBtn")
        self.btn_load_map.clicked.connect(self.combat_tracker.load_map_dialog)
        
        self.btn_open_external = QPushButton(tr("BTN_SHOW_BATTLE_MAP"))
        self.btn_open_external.setObjectName("actionBtn")
        self.btn_open_external.clicked.connect(self.combat_tracker.open_battle_map)
        
        self.embedded_map.add_toolbar_widget(self.btn_load_map)
        self.embedded_map.add_toolbar_widget(self.btn_open_external)
        
        self.player_screen_widget = PlayerScreenWidget(self._player_window)

        self.bottom_tabs.addTab(self.tab_dm_notes, tr('LBL_NOTES'))
        self.bottom_tabs.addTab(self.embedded_map, tr('TITLE_BATTLE_MAP'))
        self.bottom_tabs.addTab(self.player_screen_widget, tr("TAB_PLAYER_SCREEN"))
        self.bottom_tabs.addTab(self._entity_stack, tr("TAB_ENTITY_STATS"))
        self.bottom_tabs.currentChanged.connect(self._on_bottom_tab_changed)

        # Wrap log area in a widget so it can be a splitter child
        log_widget = QWidget()
        log_layout = QVBoxLayout(log_widget)
        log_layout.setContentsMargins(0, 0, 0, 0)
        log_layout.setSpacing(4)
        log_layout.addWidget(QLabel(tr("LBL_LOG")))
        log_layout.addWidget(self.txt_log)
        log_input_widget = QWidget()
        log_input_widget_layout = QHBoxLayout(log_input_widget)
        log_input_widget_layout.setContentsMargins(0, 0, 0, 0)
        log_input_widget_layout.addWidget(self.inp_log_entry)
        log_input_widget_layout.addWidget(self.btn_add_log)
        log_layout.addWidget(log_input_widget)

        self.right_splitter = QSplitter(Qt.Orientation.Vertical)
        self.right_splitter.setHandleWidth(4)
        self.right_splitter.addWidget(log_widget)
        self.right_splitter.addWidget(self.bottom_tabs)
        self.right_splitter.setSizes([300, 400])

        right_layout.addLayout(session_control)
        right_layout.addWidget(self.right_splitter, 1)

        self.main_splitter.addWidget(left_widget)
        self.main_splitter.addWidget(right_widget)
        
        self.main_splitter.setSizes([400, 800])
        self.main_splitter.setCollapsible(0, False)
        
        main_layout.addWidget(self.main_splitter)

    def _on_embedded_fog_changed(self, _qimage):
        encounter_id = self.combat_tracker.current_encounter_id
        if not encounter_id:
            return
        self.fog_dirty_ids.add(encounter_id)
        self.auto_save()

    def _on_embedded_annotation_changed(self, _qimage):
        encounter_id = self.combat_tracker.current_encounter_id
        if not encounter_id:
            return
        self.annotation_dirty_ids.add(encounter_id)
        self.auto_save()

    def save_fog_for_encounter(self, encounter_id, force=False):
        if encounter_id not in self.combat_tracker.encounters:
            return
        # Embedded map only holds the currently active encounter layers.
        if encounter_id != self.combat_tracker.current_encounter_id:
            return

        should_save_fog = force or encounter_id in self.fog_dirty_ids
        should_save_annotation = force or encounter_id in self.annotation_dirty_ids
        if not should_save_fog and not should_save_annotation:
            return

        if should_save_fog:
            fog_b64 = self.embedded_map.get_fog_data_base64()
            if fog_b64:
                self.combat_tracker.encounters[encounter_id]["fog_data"] = fog_b64
            self.fog_dirty_ids.discard(encounter_id)

        if should_save_annotation:
            annot_b64 = self.embedded_map.get_annotation_data_base64()
            if annot_b64:
                self.combat_tracker.encounters[encounter_id]["annotation_data"] = annot_b64
            self.annotation_dirty_ids.discard(encounter_id)

    def _on_bottom_tab_changed(self, index: int) -> None:
        if index == 1:  # Battle Map tab
            self.refresh_embedded_map()

    def _on_combatant_selected(self, eid: str):
        if eid and eid in self.dm.data["entities"]:
            self._entity_npc_sheet.populate_sheet(self.dm.data["entities"][eid])
            self._entity_npc_sheet.set_edit_mode(False)
            self._entity_stack.setCurrentIndex(1)
        else:
            self._entity_stack.setCurrentIndex(0)

    def refresh_embedded_map(self):
        if not self.combat_tracker.current_encounter_id: return
        enc = self.combat_tracker.encounters.get(self.combat_tracker.current_encounter_id)
        if not enc: return
        
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
        fog_data = enc.get("fog_data")
        
        self.embedded_map.update_tokens(
            combatants,
            enc.get("turn_index", -1),
            self.dm,
            map_path,
            enc.get("token_size", 50),
            fog_data=fog_data,
            token_size_overrides=enc.get("token_size_overrides", {}),
            grid_size=enc.get("grid_size", 50),
            grid_visible=enc.get("grid_visible", False),
            grid_snap=enc.get("grid_snap", False),
            feet_per_cell=enc.get("feet_per_cell", 5),
            annotation_data=enc.get("annotation_data"),
        )

    def save_session(self, show_msg=False):
        if not self.current_session_id:
            if show_msg: QMessageBox.warning(self, tr("MSG_ERROR"), tr("MSG_CREATE_SESSION_FIRST"))
            return
        if self._autosave_timer.isActive():
            self._autosave_timer.stop()
        
        if self.combat_tracker.current_encounter_id:
            self.save_fog_for_encounter(self.combat_tracker.current_encounter_id, force=show_msg)
        
        logs = self.txt_log.toPlainText()
        notes = self.txt_notes.toPlainText()
        combat_state = self.combat_tracker.get_session_state()
        self.dm.save_session_data(self.current_session_id, notes, logs, combat_state)

    def load_session(self):
        sid = self.combo_sessions.currentData()
        if not sid: return
        session_data = self.dm.get_session(sid)
        if session_data:
            self._autosave_timer.stop()
            self.fog_dirty_ids.clear()
            self.annotation_dirty_ids.clear()
            self.current_session_id = sid
            self.dm.set_active_session(sid) 
            self.txt_log.blockSignals(True)
            self.txt_notes.blockSignals(True)
            self.txt_log.setText(session_data.get("logs", ""))
            self.txt_notes.setText(session_data.get("notes", ""))
            self.txt_log.blockSignals(False)
            self.txt_notes.blockSignals(False)
            
            combatants_data = session_data.get("combatants", [])
            if isinstance(combatants_data, dict): 
                self.combat_tracker.load_session_state(combatants_data)
            else: 
                self.combat_tracker.load_combat_data(combatants_data)
            
            self.refresh_embedded_map()

    def roll_dice(self, sides):
        result = random.randint(1, sides)
        self.log_message(tr("MSG_ROLLED_DICE", sides=sides, result=result))

    def _append_log_line(self, line: str):
        editor = self.txt_log.editor
        cursor = editor.textCursor()
        cursor.movePosition(QTextCursor.MoveOperation.End)
        if editor.document().characterCount() > 1:
            cursor.insertText("\n")
        cursor.insertText(line)
        editor.setTextCursor(cursor)
        if self.txt_log.stack.currentIndex() == 1:
            self.txt_log.update_view_content()

    def log_message(self, message):
        timestamp = QDateTime.currentDateTime().toString("HH:mm")
        new_line = f"**[{timestamp}]** {message}"
        self._append_log_line(new_line)

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
            self._autosave_timer.stop()
            self.fog_dirty_ids.clear()
            self.annotation_dirty_ids.clear()
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
    def load_session_by_id(self, session_id):
        idx = self.combo_sessions.findData(session_id)
        if idx >= 0: 
            self.combo_sessions.setCurrentIndex(idx)
            self.load_session()
        else: 
            QMessageBox.warning(self, tr("MSG_WARNING"), "Session not found or has been deleted.")
    def _apply_edit_mode(self, enabled: bool = False, **_):
        """Apply global edit mode to session text fields."""
        if enabled:
            self.txt_log.switch_to_edit_mode()
            self.txt_notes.switch_to_edit_mode()
        else:
            self.txt_log.switch_to_view_mode()
            self.txt_notes.switch_to_view_mode()
        self.inp_log_entry.setReadOnly(not enabled)

    def retranslate_ui(self):
        self.btn_new_session.setText(tr("BTN_NEW_SESSION"))
        self.btn_save_session.setText(tr("BTN_SAVE"))
        self.btn_load_session.setText(tr("BTN_LOAD_SESSION"))
        self.txt_log.setPlaceholderText(tr("LBL_EVENT_LOG_PH"))
        self.btn_add_log.setText(tr("BTN_ADD_LOG"))
        self.txt_notes.setPlaceholderText(tr("LBL_NOTES"))
        self.bottom_tabs.setTabText(0, tr('LBL_NOTES'))
        self.bottom_tabs.setTabText(1, tr('TITLE_BATTLE_MAP'))
        self.bottom_tabs.setTabText(2, tr("TAB_PLAYER_SCREEN"))
        self.bottom_tabs.setTabText(3, tr("TAB_ENTITY_STATS"))
        self._entity_placeholder.setText(tr("LBL_SELECT_COMBATANT"))
        self.embedded_map.retranslate_ui()
        if hasattr(self.player_screen_widget, "retranslate_ui"):
            self.player_screen_widget.retranslate_ui()
        if hasattr(self.combat_tracker, "retranslate_ui"): self.combat_tracker.retranslate_ui()
        self.btn_load_map.setText(tr("BTN_LOAD_MAP") if hasattr(tr, "BTN_LOAD_MAP") else "Load Map")
        self.btn_open_external.setText(tr("BTN_SHOW_BATTLE_MAP"))

    def _perform_debounced_save(self):
        self.save_session(show_msg=False)

    def auto_save(self):
        if self.current_session_id: 
            self._autosave_timer.start()
