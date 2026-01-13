from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QFormLayout, 
                             QLineEdit, QTextEdit, QComboBox, QTabWidget, 
                             QLabel, QGroupBox, QPushButton, QScrollArea, QFrame, 
                             QListWidget, QFileDialog, QMessageBox, QStyle, QListWidgetItem, 
                             QApplication, QInputDialog)
from PyQt6.QtCore import Qt, QUrl, pyqtSignal, QSize
from PyQt6.QtGui import QDesktopServices, QPixmap, QKeySequence, QShortcut, QIcon
from ui.widgets.aspect_ratio_label import AspectRatioLabel
from ui.widgets.markdown_editor import MarkdownEditor 
from ui.workers import ImageDownloadWorker
from core.models import ENTITY_SCHEMAS
from core.locales import tr
from config import CACHE_DIR
import os
from PyQt6.QtWidgets import QToolButton 
from ui.dialogs.api_browser import ApiBrowser

class NpcSheet(QWidget):
    # --- SIGNALS ---
    request_open_entity = pyqtSignal(str)   # Navigate to linked card
    data_changed = pyqtSignal()             # Data modified (for unsaved changes indicator)
    save_requested = pyqtSignal()           # Save triggered (Ctrl+S or Button)

    def __init__(self, data_manager):
        super().__init__()
        self.dm = data_manager
        self.dynamic_inputs = {}
        
        # --- DATA LISTS ---
        self.image_list = []
        self.current_img_index = 0
        self.linked_spell_ids = []     
        self.linked_item_ids = []
        self.battlemap_list = [] 
        self.image_worker = None       
        
        self.is_dirty = False
        
        self.init_ui()
        
        # Ctrl+S Shortcut
        self.shortcut_save = QShortcut(QKeySequence("Ctrl+S"), self)
        self.shortcut_save.activated.connect(self.emit_save_request)

    def init_ui(self):
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setObjectName("mainScroll") 
        
        self.content_widget = QWidget()
        self.content_widget.setObjectName("sheetContainer")
        self.content_widget.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)
        
        self.content_widget.setStyleSheet("""
            QLineEdit, QPlainTextEdit {
                background-color: transparent;
            }
        """)

        self.content_layout = QVBoxLayout(self.content_widget)
        
        # --- TOP SECTION (Image & Metadata Side-by-Side) ---
        top_layout = QHBoxLayout()
        
        # Image Column (Left)
        img_layout = QVBoxLayout()
        self.lbl_image = AspectRatioLabel()
        self.lbl_image.setFixedSize(200, 200)
        
        gallery_controls = QHBoxLayout()
        self.btn_prev_img = QPushButton()
        self.btn_prev_img.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_ArrowBack))
        self.btn_prev_img.setMaximumWidth(30)
        self.btn_prev_img.clicked.connect(self.show_prev_image)
        
        self.btn_next_img = QPushButton()
        self.btn_next_img.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_ArrowForward))
        self.btn_next_img.setMaximumWidth(30)
        self.btn_next_img.clicked.connect(self.show_next_image)
        
        self.lbl_img_counter = QLabel("0/0")
        self.lbl_img_counter.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        gallery_controls.addWidget(self.btn_prev_img)
        gallery_controls.addWidget(self.lbl_img_counter)
        gallery_controls.addWidget(self.btn_next_img)
        
        btn_img_actions = QHBoxLayout()
        self.btn_add_img = QPushButton(tr("BTN_ADD"))
        self.btn_add_img.setObjectName("successBtn")
        self.btn_add_img.clicked.connect(self.add_image_dialog)
        
        self.btn_remove_img = QPushButton()
        self.btn_remove_img.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_TrashIcon))
        self.btn_remove_img.setObjectName("dangerBtn")
        self.btn_remove_img.clicked.connect(self.remove_current_image)
        
        btn_img_actions.addWidget(self.btn_add_img)
        btn_img_actions.addWidget(self.btn_remove_img)

        img_layout.addWidget(self.lbl_image)
        img_layout.addLayout(gallery_controls)
        img_layout.addLayout(btn_img_actions)
        img_layout.addStretch()

        # Metadata Column (Right)
        info_layout = QFormLayout()
        self.inp_name = QLineEdit()
        self.inp_type = QComboBox()
        for cat in ENTITY_SCHEMAS.keys():
            self.inp_type.addItem(tr(f"CAT_{cat.upper().replace(' ', '_').replace('(', '').replace(')', '')}"), cat)
        self.inp_type.currentIndexChanged.connect(self._on_type_index_changed)
        
        self.inp_source = QLineEdit()
        self.inp_source.setPlaceholderText("SRD 5e, Custom, etc.")
        self.inp_source.setReadOnly(True)
        
        self.inp_tags = QLineEdit()
        self.inp_tags.setPlaceholderText(tr("LBL_TAGS_PH"))
        
        self.combo_location = QComboBox()
        self.combo_location.setEditable(True) 
        self.combo_location.setPlaceholderText("Select or Write...")
        self.lbl_location = QLabel(tr("LBL_LOCATION"))
        
        self.list_residents = QListWidget()
        self.list_residents.setMaximumHeight(80)
        self.list_residents.itemDoubleClicked.connect(self._on_linked_item_dbl_click)
        self.lbl_residents = QLabel(tr("LBL_RESIDENTS"))

        info_layout.addRow(tr("LBL_NAME"), self.inp_name)
        info_layout.addRow(tr("LBL_TYPE"), self.inp_type)
        info_layout.addRow(tr("LBL_SOURCE"), self.inp_source)
        info_layout.addRow(tr("LBL_TAGS"), self.inp_tags)
        info_layout.addRow(self.lbl_location, self.combo_location)
        info_layout.addRow(self.lbl_residents, self.list_residents)

        top_layout.addLayout(img_layout)
        top_layout.addLayout(info_layout, 1) 
        self.content_layout.addLayout(top_layout)

        # --- FULL WIDTH DESCRIPTION ---
        self.content_layout.addWidget(QLabel(f"<b>{tr('LBL_DESC')} (Public Info)</b>"))
        self.inp_desc = MarkdownEditor()
        self.inp_desc.set_data_manager(self.dm) 
        self.inp_desc.entity_link_clicked.connect(self.request_open_entity.emit) 
        self.inp_desc.setMinimumHeight(180)
        self.inp_desc.setPlaceholderText(tr("LBL_DESC"))
        self.content_layout.addWidget(self.inp_desc)

        # Dynamic Attributes
        self.grp_dynamic = QGroupBox(tr("LBL_PROPERTIES"))
        self.layout_dynamic = QFormLayout(self.grp_dynamic)
        self.content_layout.addWidget(self.grp_dynamic)

        # Tabs
        # Tabs
        self.tabs = QTabWidget()
        self.tab_stats = QWidget()
        self.setup_stats_tab()
        self.tabs.addTab(self.tab_stats, tr("TAB_STATS"))
        
        self.tab_spells = QWidget()
        self.setup_spells_tab()
        self.tabs.addTab(self.tab_spells, tr("TAB_SPELLS"))
        
        self.tab_features = QWidget()
        self.setup_features_tab()
        self.tabs.addTab(self.tab_features, tr("TAB_ACTIONS"))
        
        self.tab_inventory = QWidget()
        self.setup_inventory_tab()
        self.tabs.addTab(self.tab_inventory, tr("TAB_INV"))
        
        self.tab_docs = QWidget()
        self.setup_docs_tab()
        self.tabs.addTab(self.tab_docs, tr("TAB_DOCS"))
        
        # --- NEW BATTLEMAP TAB ---
        # --- NEW BATTLEMAP TAB ---
        self.tab_battlemaps = QWidget()
        self.setup_battlemap_tab()
        self.tabs.addTab(self.tab_battlemaps, "Battlemaps")
        
        self.content_layout.addWidget(self.tabs)
        
        # DM Notes
        self.grp_dm_notes = QGroupBox("🕵️ DM Notes (Private)")
        self.grp_dm_notes.setStyleSheet("QGroupBox { border: 1px solid #d32f2f; color: #e57373; font-weight: bold; }")
        dm_notes_layout = QVBoxLayout(self.grp_dm_notes)
        self.inp_dm_notes = MarkdownEditor()
        self.inp_dm_notes.set_data_manager(self.dm) 
        self.inp_dm_notes.entity_link_clicked.connect(self.request_open_entity.emit) 
        self.inp_dm_notes.setPlaceholderText("Hidden from players... (Markdown supported)")
        self.inp_dm_notes.setMinimumHeight(120)
        dm_notes_layout.addWidget(self.inp_dm_notes)
        self.content_layout.addWidget(self.grp_dm_notes)

        scroll.setWidget(self.content_widget)
        main_layout.addWidget(scroll)

        # Footer Buttons
        btn_layout = QHBoxLayout()
        btn_layout.setContentsMargins(10, 10, 10, 10)
        self.btn_delete = QPushButton(tr("BTN_DELETE"))
        self.btn_delete.setObjectName("dangerBtn")
        self.btn_save = QPushButton(tr("BTN_SAVE"))
        self.btn_save.setObjectName("primaryBtn")
        self.btn_save.clicked.connect(self.emit_save_request)
        
        btn_layout.addStretch()
        btn_layout.addWidget(self.btn_delete)
        btn_layout.addWidget(self.btn_save)
        main_layout.addLayout(btn_layout)
        
        self.update_ui_by_type(self.inp_type.currentData())
        self._connect_change_signals()

    def setup_battlemap_tab(self):
        layout = QVBoxLayout(self.tab_battlemaps)
        
        lbl_info = QLabel("Add images or videos for Combat Tracker.")
        lbl_info.setStyleSheet("color: #888; font-style: italic;")
        layout.addWidget(lbl_info)
        
        # Buttons
        h_btn = QHBoxLayout()
        self.btn_add_map = QPushButton("Add Media")
        self.btn_add_map.clicked.connect(self.add_battlemap_dialog)
        
        self.btn_remove_map = QPushButton(tr("BTN_REMOVE"))
        self.btn_remove_map.clicked.connect(self.remove_selected_battlemap)
        
        h_btn.addWidget(self.btn_add_map)
        h_btn.addWidget(self.btn_remove_map)
        h_btn.addStretch()
        layout.addLayout(h_btn)
        
        # List
        self.list_battlemaps = QListWidget()
        self.list_battlemaps.setViewMode(QListWidget.ViewMode.IconMode)
        self.list_battlemaps.setIconSize(QSize(120, 120))
        self.list_battlemaps.setResizeMode(QListWidget.ResizeMode.Adjust)
        self.list_battlemaps.setSpacing(10)
        layout.addWidget(self.list_battlemaps)

    def add_battlemap_dialog(self):
        # Allow multiple files AND VIDEO FORMATS
        files, _ = QFileDialog.getOpenFileNames(
            self, 
            "Select Battlemaps", 
            "", 
            "Media (*.png *.jpg *.jpeg *.bmp *.mp4 *.webm *.mkv *.m4v *.avi)"
        )
        if files:
            for f in files:
                rel_path = self.dm.import_image(f)
                if rel_path:
                    self.battlemap_list.append(rel_path)
            self._render_battlemap_list()
            self.mark_as_dirty()

    def remove_selected_battlemap(self):
        row = self.list_battlemaps.currentRow()
        if row >= 0:
            del self.battlemap_list[row]
            self._render_battlemap_list()
            self.mark_as_dirty()

    def _render_battlemap_list(self):
        self.list_battlemaps.clear()
        
        video_exts = {'.mp4', '.webm', '.mkv', '.m4v', '.avi', '.mov'}
        
        for path in self.battlemap_list:
            # Skip HTTP links completely as requested
            if path.startswith("http"): continue
                
            display_name = os.path.basename(path)
            icon = None
            
            full_path = self.dm.get_full_path(path)
            if not full_path or not os.path.exists(full_path): continue
            
            # Check extension for Video vs Image
            ext = os.path.splitext(full_path)[1].lower()
            
            if ext in video_exts:
                # Use a Play Icon for videos
                icon = self.style().standardIcon(QStyle.StandardPixmap.SP_MediaPlay)
                display_name = f"{display_name} (Video)"
            else:
                # It's an image, create thumbnail
                pix = QPixmap(full_path).scaled(120, 120, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
                icon = QIcon(pix)
            
            # Create Item
            if icon:
                item = QListWidgetItem(icon, display_name)
                item.setData(Qt.ItemDataRole.UserRole, path)
                item.setToolTip(path)
                self.list_battlemaps.addItem(item)

    # ... (Rest of existing methods: add_feature_card, _connect_change_signals, etc.) ...

    def update_ui_by_type(self, category_name):
        self.build_dynamic_form(category_name)
        is_npc_like = category_name in ["NPC", "Monster"]
        is_player = category_name == "Player"
        is_lore = category_name == "Lore"
        is_status = category_name == "Status Effect"
        is_location = category_name == "Location"
        
        # Location Residents Logic
        if category_name == "Location":
            self.list_residents.clear()
            my_id = self.property("entity_id")
            if my_id:
                for eid, ent in self.dm.data["entities"].items():
                    loc_ref = ent.get("location_id") or ent.get("attributes", {}).get("LBL_ATTR_LOCATION")
                    if loc_ref == my_id:
                        item = QListWidgetItem(f"{ent['name']} ({ent['type']})")
                        item.setData(Qt.ItemDataRole.UserRole, eid)
                        self.list_residents.addItem(item)

        self.lbl_location.setVisible(is_npc_like or is_player)
        self.combo_location.setVisible(is_npc_like or is_player)
        self.lbl_residents.setVisible(category_name == "Location")
        self.list_residents.setVisible(category_name == "Location")
        
        # Tabs Visibility
        self.tabs.setTabVisible(0, is_npc_like) # Stats
        self.tabs.setTabVisible(1, is_npc_like) # Spells
        self.tabs.setTabVisible(2, is_npc_like) # Actions
        self.tabs.setTabVisible(3, is_npc_like) # Inventory
        self.tabs.setTabVisible(4, is_lore or is_player or is_status or is_location) # Docs
        
        # Battlemap Tab Visibility
        idx_battlemap = self.tabs.indexOf(self.tab_battlemaps)
        if idx_battlemap != -1:
            self.tabs.setTabVisible(idx_battlemap, is_location)

        if is_player: 
             if self.grp_combat_stats.parent() == self.tab_stats: 
                 self.tab_stats.layout().removeWidget(self.grp_combat_stats)
                 self.content_layout.insertWidget(self.content_layout.indexOf(self.tabs), self.grp_combat_stats)
             self.grp_combat_stats.setVisible(True)
        elif is_status: self.grp_combat_stats.setVisible(False)
        else:
             if self.grp_combat_stats.parent() != self.tab_stats: 
                 self.content_layout.removeWidget(self.grp_combat_stats)
                 self.tab_stats.layout().insertWidget(1, self.grp_combat_stats)
             self.grp_combat_stats.setVisible(is_npc_like)

    # ... (Other methods) ...

    def populate_sheet(self, data):
        # ... (Existing populate logic) ...
        self.refresh_reference_combos()
        self.inp_name.setText(data.get("name", ""))
        self.inp_source.setText(data.get("source", "")) 
        curr_type = data.get("type", "NPC")
        idx = self.inp_type.findData(curr_type)
        self.inp_type.setCurrentIndex(idx if idx >= 0 else 0)
        self.inp_tags.setText(", ".join(data.get("tags", [])))
        self.inp_desc.setText(data.get("description", ""))
        self.inp_dm_notes.setText(data.get("dm_notes", ""))
        
        loc_val = data.get("location_id") or data.get("attributes", {}).get("LBL_ATTR_LOCATION")
        if loc_val:
            idx = self.combo_location.findData(loc_val)
            if idx >= 0: 
                self.combo_location.setCurrentIndex(idx)
            else: 
                self.combo_location.setCurrentText(str(loc_val))
        else:
            self.combo_location.setCurrentIndex(0)

        stats = data.get("stats", {})
        for k, v in self.stats_inputs.items(): 
            v.setText(str(stats.get(k, 10)))
            self._update_modifier(k, v.text())
        
        c = data.get("combat_stats", {})
        self.inp_hp.setText(str(c.get("hp", "")))
        self.inp_max_hp.setText(str(c.get("max_hp", "")))
        self.inp_ac.setText(str(c.get("ac", "")))
        self.inp_speed.setText(str(c.get("speed", "")))
        self.inp_init.setText(str(c.get("initiative", "")))
        
        self.inp_saves.setText(data.get("saving_throws", ""))
        self.inp_skills.setText(data.get("skills", ""))
        self.inp_vuln.setText(data.get("damage_vulnerabilities", ""))
        self.inp_resist.setText(data.get("damage_resistances", ""))
        self.inp_dmg_immune.setText(data.get("damage_immunities", ""))
        self.inp_cond_immune.setText(data.get("condition_immunities", ""))
        self.inp_prof.setText(str(data.get("proficiency_bonus", "")))
        self.inp_pp.setText(str(data.get("passive_perception", "")))

        self.update_ui_by_type(curr_type)
        attrs = data.get("attributes", {})
        for label_key, widget in self.dynamic_inputs.items():
            val = attrs.get(label_key, "")
            if isinstance(widget, QComboBox):
                ix = widget.findData(val)
                if ix >= 0: 
                    widget.setCurrentIndex(ix)
                else: 
                    widget.setCurrentText(str(val))
            else: 
                widget.setText(str(val))

        self.clear_all_cards()
        for k, container in [("traits", self.trait_container), ("actions", self.action_container), ("reactions", self.reaction_container), ("legendary_actions", self.legendary_container), ("custom_spells", self.custom_spell_container), ("inventory", self.inventory_container)]:
            for item in data.get(k, []): self.add_feature_card(container, item.get("name"), item.get("desc"))

        self.linked_spell_ids = data.get("spells", [])
        self._render_linked_list(self.list_assigned_spells, self.linked_spell_ids)
        self.linked_item_ids = data.get("equipment_ids", [])
        self._render_linked_list(self.list_assigned_items, self.linked_item_ids)

        self.image_list = data.get("images", [])
        if not self.image_list and data.get("image_path"): self.image_list = [data.get("image_path")]
        
        # --- POPULATE BATTLEMAPS ---
        self.battlemap_list = data.get("battlemaps", [])
        self._render_battlemap_list()
        # ---------------------------

        remote_url = data.get("_remote_image_url")
        if not self.image_list and remote_url:
            self.lbl_image.setPlaceholderText(tr("MSG_DOWNLOADING_IMAGE"))
            self.lbl_image.setPixmap(None)
            self.lbl_img_counter.setText("-")
            self._start_lazy_image_download(remote_url, data.get("name", "entity"))
        else:
            self.current_img_index = 0
            self.update_image_display()

        self.list_pdfs.clear()
        for pdf in data.get("pdfs", []): self.list_pdfs.addItem(pdf)
        self.is_dirty = False

    def collect_data_from_sheet(self):
        if not self.inp_name.text(): return None
        # ... (Nested helpers same as before) ...
        def get_cards(container):
            res = []
            for i in range(container.dynamic_area.count()):
                w = container.dynamic_area.itemAt(i).widget()
                if w: 
                    res.append({"name": w.inp_title.text(), "desc": w.inp_desc.toPlainText()})
            return res
        
        loc_id = self.combo_location.currentData()
        loc_text = self.combo_location.currentText()
        final_loc = loc_id if (loc_id and self.combo_location.currentIndex() > 0) else loc_text.strip()

        data = {
            "name": self.inp_name.text(), 
            "type": self.inp_type.currentText(),
            "source": self.inp_source.text(),
            "tags": [t.strip() for t in self.inp_tags.text().split(",") if t.strip()],
            "description": self.inp_desc.toPlainText(), 
            "dm_notes": self.inp_dm_notes.toPlainText(),
            "images": self.image_list,
            
            # --- SAVE BATTLEMAPS ---
            "battlemaps": self.battlemap_list,
            # -----------------------
            
            "location_id": final_loc,
            "stats": {k: int(v.text() or 10) for k, v in self.stats_inputs.items()},
            "combat_stats": {"hp": self.inp_hp.text(), "max_hp": self.inp_max_hp.text(), "ac": self.inp_ac.text(), "speed": self.inp_speed.text(), "initiative": self.inp_init.text()},
            "saving_throws": self.inp_saves.text(), "skills": self.inp_skills.text(),
            "damage_vulnerabilities": self.inp_vuln.text(), "damage_resistances": self.inp_resist.text(),
            "damage_immunities": self.inp_dmg_immune.text(), "condition_immunities": self.inp_cond_immune.text(),
            "proficiency_bonus": self.inp_prof.text(), "passive_perception": self.inp_pp.text(),
            "attributes": {l: (w.currentText() if isinstance(w, QComboBox) else w.text()) for l, w in self.dynamic_inputs.items()},
            "traits": get_cards(self.trait_container), "actions": get_cards(self.action_container),
            "reactions": get_cards(self.reaction_container), "legendary_actions": get_cards(self.legendary_container),
            "inventory": get_cards(self.inventory_container), "custom_spells": get_cards(self.custom_spell_container),
            "spells": self.linked_spell_ids, "equipment_ids": self.linked_item_ids,
            "pdfs": [self.list_pdfs.item(i).text() for i in range(self.list_pdfs.count())]
        }
        return data

    def add_feature_card(self, group, name="", desc="", ph_title=None, ph_desc=None):
        self.mark_as_dirty()
        if ph_title is None: ph_title = tr("LBL_TITLE_PH")
        if ph_desc is None: ph_desc = tr("LBL_DETAILS_PH")
        
        card = QFrame()
        card.setProperty("class", "featureCard")
        l = QVBoxLayout(card)
        
        h_header = QHBoxLayout()
        t = QLineEdit(name)
        t.setPlaceholderText(ph_title)
        t.setStyleSheet("font-weight: bold; border:none; font-size: 14px;")
        t.textChanged.connect(self.mark_as_dirty)
        
        btn_del = QPushButton()
        btn_del.setFixedSize(24,24)
        btn_del.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_TitleBarCloseButton))
        btn_del.setStyleSheet("background: transparent; border: none;")
        btn_del.clicked.connect(lambda: [group.dynamic_area.removeWidget(card), card.deleteLater(), self.mark_as_dirty()])
        
        h_header.addWidget(t)
        h_header.addWidget(btn_del)
        l.addLayout(h_header)
        
        d = MarkdownEditor(text=desc)
        d.set_data_manager(self.dm) 
        d.entity_link_clicked.connect(self.request_open_entity.emit)
        d.setPlaceholderText(ph_desc)
        d.setMinimumHeight(120) 
        d.textChanged.connect(self.mark_as_dirty)
        l.addWidget(d)
        
        group.dynamic_area.addWidget(card)
        card.inp_title = t
        card.inp_desc = d

    def _connect_change_signals(self):
        inputs = [
            self.inp_name, self.inp_tags, self.inp_hp, self.inp_max_hp, 
            self.inp_ac, self.inp_speed, self.inp_prof, self.inp_pp, self.inp_init,
            self.inp_saves, self.inp_skills, self.inp_vuln, self.inp_resist, 
            self.inp_dmg_immune, self.inp_cond_immune
        ]
        inputs.extend(self.stats_inputs.values())
        for w in inputs:
            if isinstance(w, QLineEdit): w.textChanged.connect(self.mark_as_dirty)
            elif isinstance(w, QTextEdit): w.textChanged.connect(self.mark_as_dirty)
        
        self.inp_desc.textChanged.connect(self.mark_as_dirty)
        self.inp_dm_notes.textChanged.connect(self.mark_as_dirty)
        self.inp_type.currentIndexChanged.connect(self.mark_as_dirty)
        self.combo_location.editTextChanged.connect(self.mark_as_dirty)
        self.combo_location.currentIndexChanged.connect(self.mark_as_dirty)

    def mark_as_dirty(self):
        if not self.is_dirty:
            self.is_dirty = True
            self.data_changed.emit()

    def emit_save_request(self):
        self.save_requested.emit()

    def refresh_reference_combos(self):
        self.combo_location.clear()
        self.combo_all_spells.clear()
        self.combo_all_items.clear()
        self.combo_location.addItem("-", None) 
        for eid, ent in self.dm.data["entities"].items():
            etype = ent.get("type")
            name = ent.get("name", "Unnamed")
            if etype == "Location": self.combo_location.addItem(f"📍 {name}", eid)
            elif etype == "Spell":
                level = ent.get("attributes", {}).get("LBL_LEVEL", "?")
                self.combo_all_spells.addItem(f"{name} (Lv {level})", eid)
            elif etype == "Equipment":
                cat = ent.get("attributes", {}).get("LBL_CATEGORY", "Item")
                self.combo_all_items.addItem(f"{name} ({cat})", eid)

    def setup_stats_tab(self):
        layout = QVBoxLayout(self.tab_stats)
        self.grp_base_stats = QGroupBox(tr("GRP_STATS"))
        l = QHBoxLayout(self.grp_base_stats)
        self.stats_inputs = {}
        self.stats_modifiers = {}
        for s in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
            v = QVBoxLayout()
            lbl_title = QLabel(s)
            lbl_title.setAlignment(Qt.AlignmentFlag.AlignCenter)
            lbl_title.setStyleSheet("font-weight: bold;")
            inp = QLineEdit("10")
            inp.setAlignment(Qt.AlignmentFlag.AlignCenter)
            inp.setMaximumWidth(50)
            inp.textChanged.connect(lambda text, key=s: self._update_modifier(key, text))
            lbl_mod = QLabel("+0")
            lbl_mod.setAlignment(Qt.AlignmentFlag.AlignCenter)
            lbl_mod.setProperty("class", "statModifier")
            self.stats_inputs[s] = inp
            self.stats_modifiers[s] = lbl_mod
            v.addWidget(lbl_title)
            v.addWidget(inp)
            v.addWidget(lbl_mod)
            l.addLayout(v)
        layout.addWidget(self.grp_base_stats)
        
        self.grp_combat_stats = QGroupBox(tr("GRP_COMBAT"))
        v_comb = QVBoxLayout(self.grp_combat_stats)
        self.inp_hp = QLineEdit()
        self.inp_hp.setPlaceholderText(tr("LBL_HP"))
        self.inp_max_hp = QLineEdit()
        self.inp_max_hp.setPlaceholderText(tr("LBL_MAX_HP"))
        self.inp_ac = QLineEdit()
        self.inp_ac.setPlaceholderText(tr("HEADER_AC"))
        self.inp_speed = QLineEdit()
        self.inp_prof = QLineEdit()
        self.inp_pp = QLineEdit()
        self.inp_init = QLineEdit()
        self.inp_init.setPlaceholderText(tr("LBL_INIT"))
        r1 = QHBoxLayout()
        for t, w in [(tr("LBL_MAX_HP"), self.inp_max_hp), (tr("LBL_HP"), self.inp_hp), (tr("HEADER_AC"), self.inp_ac), (tr("LBL_SPEED"), self.inp_speed)]:
             v = QVBoxLayout()
             v.addWidget(QLabel(t))
             v.addWidget(w)
             r1.addLayout(v)
        r2 = QHBoxLayout()
        for t, w in [(tr("LBL_PROF_BONUS"), self.inp_prof), (tr("LBL_PASSIVE_PERC"), self.inp_pp), (tr("LBL_INIT_BONUS"), self.inp_init)]:
             v = QVBoxLayout()
             v.addWidget(QLabel(t))
             v.addWidget(w)
             r2.addLayout(v)
        v_comb.addLayout(r1)
        v_comb.addLayout(r2)
        layout.addWidget(self.grp_combat_stats)

        self.grp_defense = QGroupBox(tr("GRP_DEFENSE")); form3 = QFormLayout(self.grp_defense)
        self.inp_saves = QLineEdit(); self.inp_skills = QLineEdit()
        self.inp_vuln = QLineEdit(); self.inp_resist = QLineEdit()
        self.inp_dmg_immune = QLineEdit(); self.inp_cond_immune = QLineEdit()
        form3.addRow(tr("LBL_SAVES"), self.inp_saves); form3.addRow(tr("LBL_SKILLS"), self.inp_skills)
        form3.addRow(tr("LBL_VULN"), self.inp_vuln); form3.addRow(tr("LBL_RESIST"), self.inp_resist)
        form3.addRow(tr("LBL_DMG_IMMUNE"), self.inp_dmg_immune); form3.addRow(tr("LBL_COND_IMMUNE"), self.inp_cond_immune)
        layout.addWidget(self.grp_defense); layout.addStretch()

    def _update_modifier(self, stat_key, text_value):
        try:
            val = int(text_value); mod = (val - 10) // 2; sign = "+" if mod >= 0 else ""
            self.stats_modifiers[stat_key].setText(f"{sign}{mod}")
            if mod > 0: self.stats_modifiers[stat_key].setStyleSheet("color: #4caf50; font-weight: bold;")
            else: self.stats_modifiers[stat_key].setStyleSheet("color: #aaa; font-weight: normal;")
        except ValueError: self.stats_modifiers[stat_key].setText("-")

    def setup_spells_tab(self):
        layout = QVBoxLayout(self.tab_spells)
        self.grp_spells = QGroupBox(tr("GRP_SPELLS"))
        l_linked = QVBoxLayout(self.grp_spells)
        h = QHBoxLayout()
        self.combo_all_spells = QComboBox()
        self.combo_all_spells.setEditable(True)
        self.combo_all_spells.setPlaceholderText("Search spells...")
        self.btn_add_spell_link = QPushButton(tr("BTN_ADD"))
        self.btn_add_spell_link.setObjectName("successBtn")
        self.btn_add_spell_link.clicked.connect(self.add_linked_spell)
        h.addWidget(self.combo_all_spells, 3)
        h.addWidget(self.btn_add_spell_link, 1)
        self.list_assigned_spells = QListWidget()
        self.list_assigned_spells.setAlternatingRowColors(True)
        self.list_assigned_spells.setMinimumHeight(200)
        self.list_assigned_spells.itemDoubleClicked.connect(self._on_linked_item_dbl_click)
        self.btn_remove_spell_link = QPushButton(tr("BTN_REMOVE"))
        self.btn_remove_spell_link.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_TrashIcon))
        self.btn_remove_spell_link.setObjectName("dangerBtn")
        self.btn_remove_spell_link.clicked.connect(self.remove_linked_spell)
        l_linked.addLayout(h)
        l_linked.addWidget(self.list_assigned_spells)
        l_linked.addWidget(self.btn_remove_spell_link)
        layout.addWidget(self.grp_spells)
        self.custom_spell_container = self._create_section(tr("LBL_MANUAL_SPELLS"))
        self.add_btn_to_section(self.custom_spell_container, tr("BTN_ADD"))
        layout.addWidget(self.custom_spell_container); layout.addStretch()

    def setup_inventory_tab(self):
        layout = QVBoxLayout(self.tab_inventory)
        self.grp_db_items = QGroupBox(tr("LBL_DB_ITEMS"))
        l_linked = QVBoxLayout(self.grp_db_items)
        h = QHBoxLayout()
        self.combo_all_items = QComboBox()
        self.combo_all_items.setEditable(True)
        self.combo_all_items.setPlaceholderText("Search items...")
        self.btn_add_item_link = QPushButton(tr("BTN_ADD"))
        self.btn_add_item_link.setObjectName("successBtn")
        self.btn_add_item_link.clicked.connect(self.add_linked_item)
        h.addWidget(self.combo_all_items, 3)
        h.addWidget(self.btn_add_item_link, 1)
        self.list_assigned_items = QListWidget()
        self.list_assigned_items.setAlternatingRowColors(True)
        self.list_assigned_items.itemDoubleClicked.connect(self._on_linked_item_dbl_click)
        self.btn_remove_item_link = QPushButton(tr("BTN_REMOVE"))
        self.btn_remove_item_link.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_TrashIcon))
        self.btn_remove_item_link.setObjectName("dangerBtn")
        self.btn_remove_item_link.clicked.connect(self.remove_linked_item)
        l_linked.addLayout(h)
        l_linked.addWidget(self.list_assigned_items)
        l_linked.addWidget(self.btn_remove_item_link)
        layout.addWidget(self.grp_db_items)
        self.inventory_container = self._create_section(tr("GRP_INVENTORY"))
        self.add_btn_to_section(self.inventory_container, tr("BTN_ADD"))
        layout.addWidget(self.inventory_container); layout.addStretch()

    def setup_features_tab(self):
        layout = QVBoxLayout(self.tab_features)
        self.trait_container = self._create_section(tr("LBL_TRAITS"))
        self.add_btn_to_section(self.trait_container, tr("BTN_ADD"))
        self.action_container = self._create_section(tr("LBL_ACTIONS"))
        self.add_btn_to_section(self.action_container, tr("BTN_ADD"))
        self.reaction_container = self._create_section(tr("LBL_REACTIONS"))
        self.add_btn_to_section(self.reaction_container, tr("BTN_ADD"))
        self.legendary_container = self._create_section(tr("LBL_LEGENDARY_ACTIONS"))
        self.add_btn_to_section(self.legendary_container, tr("BTN_ADD"))
        layout.addWidget(self.trait_container)
        layout.addWidget(self.action_container)
        layout.addWidget(self.reaction_container)
        layout.addWidget(self.legendary_container)
        layout.addStretch()

    def setup_docs_tab(self):
        layout = QVBoxLayout(self.tab_docs)
        self.grp_pdf = QGroupBox(tr("GRP_PDF"))
        v = QVBoxLayout(self.grp_pdf)
        h_btn = QHBoxLayout()
        self.btn_add_pdf = QPushButton(tr("BTN_ADD"))
        self.btn_add_pdf.setObjectName("successBtn")
        self.btn_open_pdf_folder = QPushButton()
        self.btn_open_pdf_folder.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DirIcon))
        h_btn.addWidget(self.btn_add_pdf, 3)
        h_btn.addWidget(self.btn_open_pdf_folder, 1)
        v.addLayout(h_btn)
        self.list_pdfs = QListWidget()
        self.list_pdfs.setAlternatingRowColors(True)
        v.addWidget(self.list_pdfs)
        h_action = QHBoxLayout()
        self.btn_open_pdf = QPushButton(tr("BTN_OPEN_PDF"))
        self.btn_open_pdf.setObjectName("primaryBtn")
        self.btn_project_pdf = QPushButton(tr("BTN_PROJECT_PDF"))
        self.btn_project_pdf.setObjectName("actionBtn")
        self.btn_remove_pdf = QPushButton(tr("BTN_REMOVE"))
        self.btn_remove_pdf.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_TrashIcon))
        self.btn_remove_pdf.setObjectName("dangerBtn")
        h_action.addWidget(self.btn_open_pdf)
        h_action.addWidget(self.btn_project_pdf)
        h_action.addWidget(self.btn_remove_pdf)
        v.addLayout(h_action)
        layout.addWidget(self.grp_pdf)
        layout.addStretch()

    def _on_linked_item_dbl_click(self, item):
        eid = item.data(Qt.ItemDataRole.UserRole)
        if eid: self.request_open_entity.emit(eid)

    def add_linked_spell(self):
        eid = self.combo_all_spells.currentData()
        if not eid: return
        self.mark_as_dirty()
        if eid not in self.linked_spell_ids:
            self.linked_spell_ids.append(eid)
            self._render_linked_list(self.list_assigned_spells, self.linked_spell_ids)

    def remove_linked_spell(self):
        row = self.list_assigned_spells.currentRow()
        if row >= 0:
            self.mark_as_dirty()
            del self.linked_spell_ids[row]
            self.list_assigned_spells.takeItem(row)

    def add_linked_item(self):
        eid = self.combo_all_items.currentData()
        if not eid: return
        self.mark_as_dirty()
        if eid not in self.linked_item_ids:
            self.linked_item_ids.append(eid)
            self._render_linked_list(self.list_assigned_items, self.linked_item_ids)

    def remove_linked_item(self):
        row = self.list_assigned_items.currentRow()
        if row >= 0:
            self.mark_as_dirty()
            del self.linked_item_ids[row]
            self.list_assigned_items.takeItem(row)

    def _render_linked_list(self, list_widget, id_list):
        list_widget.clear()
        for eid in id_list:
            ent = self.dm.data["entities"].get(eid)
            name = ent.get("name", "Unknown") if ent else "Removed Item"
            extra = ""
            if ent:
                if ent.get("type") == "Spell": extra = f" (Lv {ent.get('attributes',{}).get('LBL_LEVEL','?')})"
                elif ent.get("type") == "Equipment": extra = f" ({ent.get('attributes',{}).get('LBL_CATEGORY','')})"
            item = QListWidgetItem(f"{name}{extra}")
            item.setData(Qt.ItemDataRole.UserRole, eid)
            list_widget.addItem(item)

    def _create_section(self, title):
        group = QGroupBox(title)
        v = QVBoxLayout(group)
        group.dynamic_area = QVBoxLayout()
        v.addLayout(group.dynamic_area)
        return group

    def add_btn_to_section(self, container, label):
        btn = QPushButton(label)
        btn.clicked.connect(lambda: self.add_feature_card(container))
        btn.setObjectName("successBtn")
        container.layout().insertWidget(0, btn)

    def clear_all_cards(self):
        containers = [self.trait_container, self.action_container, self.reaction_container, self.legendary_container, self.inventory_container, self.custom_spell_container]
        for g in containers:
            while g.dynamic_area.count(): 
                item = g.dynamic_area.takeAt(0)
                if item.widget(): item.widget().deleteLater()

    def _on_type_index_changed(self, index):
        cat_key = self.inp_type.itemData(index)
        if cat_key: self.update_ui_by_type(cat_key)

    def build_dynamic_form(self, category_name):
        while self.layout_dynamic.rowCount() > 0: self.layout_dynamic.removeRow(0)
        self.dynamic_inputs = {} 
        schema = ENTITY_SCHEMAS.get(category_name, [])
        cat_trans = tr(f"CAT_{category_name.upper()}") if category_name in ENTITY_SCHEMAS else category_name
        self.grp_dynamic.setTitle(f"{cat_trans} {tr('LBL_PROPERTIES')}")
        
        for label_key, dtype, options in schema:
            if dtype == "combo":
                widget = QComboBox(); widget.setEditable(True)
                if options:
                    for opt in options: widget.addItem(tr(opt) if str(opt).startswith("LBL_") else opt, opt)
                widget.editTextChanged.connect(self.mark_as_dirty) 
                widget.currentIndexChanged.connect(self.mark_as_dirty)
            
            elif dtype == "entity_select":
                widget = QComboBox(); widget.setEditable(True)
                widget.addItem("-", "") 
                widget.setProperty("target_type", options)
                self._populate_unified_combo(options, widget)
                widget.activated.connect(lambda idx, w=widget: self._on_unified_selection(idx, w))
                widget.editTextChanged.connect(self.mark_as_dirty)
                self.layout_dynamic.addRow(f"{tr(label_key)}:", widget); self.dynamic_inputs[label_key] = widget

            else: 
                widget = QLineEdit()
                widget.textChanged.connect(self.mark_as_dirty)
                self.layout_dynamic.addRow(f"{tr(label_key)}:", widget); self.dynamic_inputs[label_key] = widget

    def _populate_unified_combo(self, category, widget):
        widget.clear()
        widget.addItem("-", "")
        candidates = []
        for eid, ent in self.dm.data["entities"].items():
            if ent.get("type") == category:
                candidates.append({"name": ent.get("name", "Unnamed"), "id": eid, "is_local": True, "source": "Local"})
        remote_cat = category
        if category == "Condition": remote_cat = "Condition" 
        elif category == "Location": remote_cat = None 
        if remote_cat:
            try:
                page = 1; max_pages = 10 
                while page <= max_pages:
                    cache_data = self.dm.get_api_index(remote_cat, page=page)
                    results = cache_data.get("results", []) if isinstance(cache_data, dict) else []
                    if not results: break
                    source_label = self.dm.api_client.current_source_key.upper()
                    if source_label == "DND5E": source_label = "SRD 5e"
                    for item in results:
                        candidates.append({"name": item.get("name", "Unknown"), "id": item.get("index") or item.get("slug"), "is_local": False, "source": source_label, "raw_data": item})
                    if isinstance(cache_data, dict) and not cache_data.get("next"): break
                    page += 1
                    QApplication.processEvents() 
            except Exception as e: print(f"Unified Pop Error: {e}")
        candidates.sort(key=lambda x: x["name"])
        for cand in candidates:
            display = cand["name"]
            if not cand["is_local"]: display = f"☁️ {cand['name']} [{cand['source']}]"
            widget.addItem(display, cand["name"]) 
            idx = widget.count() - 1
            widget.setItemData(idx, cand, Qt.ItemDataRole.UserRole)

    def _on_unified_selection(self, index, widget):
        data = widget.itemData(index, Qt.ItemDataRole.UserRole)
        if not data: return
        if not data["is_local"]:
            original_text = widget.itemText(index)
            widget.setItemText(index, f"⏳ {tr('MSG_LOADING')}...")
            QApplication.processEvents()
            target_type = widget.property("target_type")
            try:
                success, parsed_or_msg = self.dm.fetch_details_from_api(target_type, data["id"])
                if success:
                    widget.setItemText(index, data["name"])
                    self.mark_as_dirty()
                else:
                    widget.setItemText(index, original_text)
                    QMessageBox.warning(self, tr("MSG_ERROR"), parsed_or_msg)
            except Exception as e:
                widget.setItemText(index, original_text)
                QMessageBox.critical(self, tr("MSG_ERROR"), f"Error: {e}")
        else: self.mark_as_dirty()

    def _start_lazy_image_download(self, url, name):
        safe_name = "".join([c for c in name if c.isalnum()]).lower()
        ext = ".jpg" if ".jpg" in url.lower() else ".png"
        filename = f"{safe_name}{ext}"
        save_dir = os.path.join(CACHE_DIR, "library", "images")
        self.image_worker = ImageDownloadWorker(url, save_dir, filename)
        self.image_worker.finished.connect(self._on_image_downloaded)
        self.image_worker.start()

    def _on_image_downloaded(self, success, local_abs_path):
        if success and local_abs_path:
            rel_path = self.dm.import_image(local_abs_path)
            if rel_path:
                self.image_list = [rel_path]
                self.current_img_index = 0
                self.update_image_display()
        else:
            self.lbl_image.setPlaceholderText(tr("LBL_NO_IMAGE"))
            self.lbl_image.setPixmap(None)

    def add_image_dialog(self):
        f, _ = QFileDialog.getOpenFileName(self, tr("BTN_SELECT_IMG"), "", "Images (*.png *.jpg)")
        if f: 
            p = self.dm.import_image(f)
            if p: 
                self.image_list.append(p); self.current_img_index = len(self.image_list)-1; self.update_image_display()
                self.mark_as_dirty()
    def remove_current_image(self):
        if self.image_list: 
            del self.image_list[self.current_img_index]; self.current_img_index=max(0, self.current_img_index-1); self.update_image_display()
            self.mark_as_dirty()
    def show_prev_image(self):
        if self.image_list: self.current_img_index=(self.current_img_index-1)%len(self.image_list); self.update_image_display()
    def show_next_image(self):
        if self.image_list: self.current_img_index=(self.current_img_index+1)%len(self.image_list); self.update_image_display()
    def update_image_display(self):
        if not self.image_list: 
            self.lbl_image.setPixmap(None, path=None) # Path None
            self.lbl_image.setPlaceholderText(tr("LBL_NO_IMAGE"))
            self.lbl_img_counter.setText("0/0")
            return
            
        p = self.dm.get_full_path(self.image_list[self.current_img_index])
        
        if p and os.path.exists(p): 
            self.lbl_image.setPixmap(QPixmap(p), path=p) 
        else: 
            self.lbl_image.setPixmap(None, path=None)
            self.lbl_image.setPlaceholderText(tr("LBL_NO_IMAGE"))
            
        self.lbl_img_counter.setText(f"{self.current_img_index+1}/{len(self.image_list)}")
    
    def add_pdf_dialog(self):
        f, _ = QFileDialog.getOpenFileName(self, tr("BTN_SELECT_PDF"), "", "PDF (*.pdf)")
        if f:
            p = self.dm.import_pdf(f); eid = self.property("entity_id")
            if p: 
                self.list_pdfs.addItem(p); self.mark_as_dirty()
                if eid:
                    d = self.dm.data["entities"].get(eid); 
                    if d: 
                        l = d.get("pdfs",[]); 
                        if p not in l: l.append(p); d["pdfs"]=l; self.dm.save_entity(eid, d)
    def open_current_pdf(self):
        i = self.list_pdfs.currentItem()
        if i: 
            p = self.dm.get_full_path(i.text())
            if p and os.path.exists(p): QDesktopServices.openUrl(QUrl.fromLocalFile(p))
    def remove_current_pdf(self):
        i = self.list_pdfs.currentItem()
        if i and QMessageBox.question(self, tr("BTN_REMOVE"), tr("MSG_REMOVE_PDF_CONFIRM"))==QMessageBox.StandardButton.Yes:
            eid = self.property("entity_id"); txt=i.text(); self.list_pdfs.takeItem(self.list_pdfs.row(i)); self.mark_as_dirty()
            if eid:
                d = self.dm.data["entities"].get(eid)
                if d and txt in d.get("pdfs",[]): d["pdfs"].remove(txt); self.dm.save_entity(eid, d)
    def open_pdf_folder(self):
        d = os.path.join(self.dm.current_campaign_path, "assets"); os.makedirs(d, exist_ok=True); QDesktopServices.openUrl(QUrl.fromLocalFile(d))