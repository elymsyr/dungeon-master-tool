from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QFormLayout, 
                             QLineEdit, QTextEdit, QComboBox, QTabWidget, 
                             QLabel, QGroupBox, QPushButton, QScrollArea, QFrame, QListWidget, QFileDialog, QMessageBox)
from PyQt6.QtCore import Qt, QUrl
from PyQt6.QtGui import QDesktopServices
from ui.widgets.aspect_ratio_label import AspectRatioLabel
from core.models import ENTITY_SCHEMAS
from core.locales import tr

class NpcSheet(QWidget):
    def __init__(self):
        super().__init__()
        self.dynamic_inputs = {}
        self.image_list = [] # YENİ: Resim yolları
        self.current_img_index = 0
        self.init_ui()

    def init_ui(self):
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        
        self.content_widget = QWidget()
        self.content_layout = QVBoxLayout(self.content_widget)

        # --- ÜST BÖLÜM ---
        top_layout = QHBoxLayout()
        img_layout = QVBoxLayout()
        self.lbl_image = AspectRatioLabel()
        self.lbl_image.setFixedSize(200, 200)
        
        # Galeri Kontrolleri
        gallery_controls = QHBoxLayout()
        self.btn_prev_img = QPushButton("◀"); self.btn_prev_img.setMaximumWidth(30)
        self.btn_next_img = QPushButton("▶"); self.btn_next_img.setMaximumWidth(30)
        self.lbl_img_counter = QLabel("0/0"); self.lbl_img_counter.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        gallery_controls.addWidget(self.btn_prev_img)
        gallery_controls.addWidget(self.lbl_img_counter)
        gallery_controls.addWidget(self.btn_next_img)
        
        btn_img_actions = QHBoxLayout()
        self.btn_add_img = QPushButton("➕"); self.btn_add_img.setObjectName("successBtn"); self.btn_add_img.setToolTip("Resim Ekle")
        self.btn_remove_img = QPushButton("🗑️"); self.btn_remove_img.setObjectName("dangerBtn"); self.btn_remove_img.setToolTip("Şu anki resmi sil")
        
        btn_img_actions.addWidget(self.btn_add_img)
        btn_img_actions.addWidget(self.btn_remove_img)

        self.btn_show_player = QPushButton(tr("BTN_SHOW_PLAYER"))
        self.btn_show_player.setObjectName("primaryBtn")
        
        img_layout.addWidget(self.lbl_image)
        img_layout.addLayout(gallery_controls)
        img_layout.addLayout(btn_img_actions)
        img_layout.addWidget(self.btn_show_player)
        img_layout.addStretch()

        info_layout = QFormLayout()
        self.inp_name = QLineEdit()
        self.inp_type = QComboBox()
        self.inp_type.addItems(list(ENTITY_SCHEMAS.keys()))
        self.inp_type.currentTextChanged.connect(self.update_ui_by_type)
        self.inp_tags = QLineEdit(); self.inp_tags.setPlaceholderText("boss, ölü, tüccar...")
        
        self.combo_location = QComboBox()
        self.lbl_location = QLabel(tr("LBL_LOCATION"))
        self.list_residents = QListWidget(); self.list_residents.setMaximumHeight(80)
        self.lbl_residents = QLabel(tr("LBL_RESIDENTS"))
        self.inp_desc = QTextEdit(); self.inp_desc.setMaximumHeight(60); self.inp_desc.setPlaceholderText(tr("LBL_DESC"))

        info_layout.addRow(tr("LBL_NAME"), self.inp_name)
        info_layout.addRow(tr("LBL_TYPE"), self.inp_type)
        info_layout.addRow(tr("LBL_TAGS"), self.inp_tags)
        info_layout.addRow(self.lbl_location, self.combo_location)
        info_layout.addRow(self.lbl_residents, self.list_residents)
        info_layout.addRow(tr("LBL_DESC"), self.inp_desc)

        top_layout.addLayout(img_layout); top_layout.addLayout(info_layout)
        self.content_layout.addLayout(top_layout)

        # --- DİNAMİK ALANLAR ---
        self.grp_dynamic = QGroupBox("Özellikler")
        self.layout_dynamic = QFormLayout(self.grp_dynamic)
        self.content_layout.addWidget(self.grp_dynamic)

        # --- SEKMELER ---
        self.tabs = QTabWidget()
        self.tab_stats = QWidget(); self.setup_stats_tab(); self.tabs.addTab(self.tab_stats, tr("TAB_STATS"))
        self.tab_spells = QWidget(); self.setup_spells_tab(); self.tabs.addTab(self.tab_spells, tr("TAB_SPELLS"))
        self.tab_features = QWidget(); self.setup_features_tab(); self.tabs.addTab(self.tab_features, tr("TAB_ACTIONS"))
        self.tab_inventory = QWidget(); self.setup_inventory_tab(); self.tabs.addTab(self.tab_inventory, tr("TAB_INV"))
        self.tab_docs = QWidget(); self.setup_docs_tab(); self.tabs.addTab(self.tab_docs, tr("TAB_DOCS"))

        self.content_layout.addWidget(self.tabs)
        scroll.setWidget(self.content_widget)
        main_layout.addWidget(scroll)

        # --- BUTONLAR ---
        btn_layout = QHBoxLayout(); btn_layout.setContentsMargins(10, 10, 10, 10)
        self.btn_delete = QPushButton(tr("BTN_DELETE")); self.btn_delete.setObjectName("dangerBtn")
        self.btn_save = QPushButton(tr("BTN_SAVE")); self.btn_save.setObjectName("primaryBtn")
        btn_layout.addStretch(); btn_layout.addWidget(self.btn_delete); btn_layout.addWidget(self.btn_save)
        main_layout.addLayout(btn_layout)
        
        self.update_ui_by_type(self.inp_type.currentText())

    # --- TAB KURULUMLARI ---
    def setup_stats_tab(self):
        layout = QVBoxLayout(self.tab_stats)
        
        # Temel Statlar (STR, DEX...)
        grp = QGroupBox(tr("GRP_STATS")); l = QHBoxLayout(grp)
        self.stats_inputs = {}
        self.stats_modifiers = {} # Label'ları tutacağız
        
        for s in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
            v = QVBoxLayout()
            lbl_title = QLabel(s); lbl_title.setAlignment(Qt.AlignmentFlag.AlignCenter); lbl_title.setStyleSheet("font-weight: bold;")
            
            inp = QLineEdit("10"); inp.setAlignment(Qt.AlignmentFlag.AlignCenter); inp.setMaximumWidth(50)
            inp.textChanged.connect(lambda text, key=s: self._update_modifier(key, text))
            
            lbl_mod = QLabel("+0"); lbl_mod.setAlignment(Qt.AlignmentFlag.AlignCenter); lbl_mod.setStyleSheet("color: #aaa; font-size: 11px;")
            
            self.stats_inputs[s] = inp
            self.stats_modifiers[s] = lbl_mod
            
            v.addWidget(lbl_title); v.addWidget(inp); v.addWidget(lbl_mod)
            l.addLayout(v)
        layout.addWidget(grp)
        
        # Combat Stats (HP, AC...)
        grp2 = QGroupBox(tr("GRP_COMBAT")); l2 = QHBoxLayout(grp2) 
        self.inp_hp = QLineEdit(); self.inp_ac = QLineEdit(); self.inp_speed = QLineEdit()
        self.inp_prof = QLineEdit(); self.inp_pp = QLineEdit(); self.inp_init = QLineEdit()
        
        # Üst sıra: HP, AC, Speed
        row1 = QHBoxLayout()
        for t, w in [("HP", self.inp_hp), ("AC", self.inp_ac), ("Hız", self.inp_speed)]:
             v = QVBoxLayout(); v.addWidget(QLabel(t)); v.addWidget(w); row1.addLayout(v)
        
        # Alt sıra: Proficiency, Passive Perception, Initiative
        row2 = QHBoxLayout()
        for t, w in [(tr("LBL_PROF_BONUS"), self.inp_prof), (tr("LBL_PASSIVE_PERC"), self.inp_pp), (tr("LBL_INIT_BONUS"), self.inp_init)]:
             v = QVBoxLayout(); v.addWidget(QLabel(t)); v.addWidget(w); row2.addLayout(v)
             
        v_comb = QVBoxLayout(); v_comb.addLayout(row1); v_comb.addLayout(row2)
        l2.addLayout(v_comb)
        
        layout.addWidget(grp2)

        # Gelişmiş Statlar (Saves, Immunities...)
        grp3 = QGroupBox(tr("GRP_DEFENSE")); form3 = QFormLayout(grp3)
        self.inp_saves = QLineEdit()
        self.inp_skills = QLineEdit() # YENİ
        self.inp_vuln = QLineEdit()
        self.inp_resist = QLineEdit()
        self.inp_dmg_immune = QLineEdit()
        self.inp_cond_immune = QLineEdit()
        
        form3.addRow(tr("LBL_SAVES"), self.inp_saves)
        form3.addRow(tr("LBL_SKILLS"), self.inp_skills)
        form3.addRow(tr("LBL_VULN"), self.inp_vuln)
        form3.addRow(tr("LBL_RESIST"), self.inp_resist)
        form3.addRow(tr("LBL_DMG_IMMUNE"), self.inp_dmg_immune)
        form3.addRow(tr("LBL_COND_IMMUNE"), self.inp_cond_immune)
        
        layout.addWidget(grp3)
        layout.addStretch()
        
    def _update_modifier(self, stat_key, text_value):
        try:
            val = int(text_value)
            mod = (val - 10) // 2
            sign = "+" if mod >= 0 else ""
            self.stats_modifiers[stat_key].setText(f"{sign}{mod}")
            self.stats_modifiers[stat_key].setStyleSheet(f"color: {'#4caf50' if mod > 0 else '#aaa'}; font-size: 11px; font-weight: bold;")
        except ValueError:
            self.stats_modifiers[stat_key].setText("-")

    def setup_spells_tab(self):
        layout = QVBoxLayout(self.tab_spells)
        # Veritabanı
        grp_linked = QGroupBox(tr("GRP_SPELLS"))
        l_linked = QVBoxLayout(grp_linked)
        h = QHBoxLayout()
        self.combo_all_spells = QComboBox(); self.combo_all_spells.setEditable(True); self.combo_all_spells.setPlaceholderText(tr("LBL_SEARCH"))
        self.btn_add_spell = QPushButton(tr("BTN_ADD")); self.btn_add_spell.setObjectName("successBtn")
        h.addWidget(self.combo_all_spells, 3); h.addWidget(self.btn_add_spell, 1)
        self.list_assigned_spells = QListWidget(); self.list_assigned_spells.setMaximumHeight(120); self.list_assigned_spells.setAlternatingRowColors(True)
        self.btn_remove_spell = QPushButton(tr("BTN_REMOVE"))
        l_linked.addLayout(h); l_linked.addWidget(self.list_assigned_spells); l_linked.addWidget(self.btn_remove_spell)
        layout.addWidget(grp_linked)
        # Manuel
        self.custom_spell_container = self._create_section("Manual Spells")
        self.add_btn_to_section(self.custom_spell_container, tr("BTN_ADD"))
        layout.addWidget(self.custom_spell_container); layout.addStretch()

    def setup_features_tab(self):
        layout = QVBoxLayout(self.tab_features)
        self.trait_container = self._create_section("Traits"); self.add_btn_to_section(self.trait_container, tr("BTN_ADD"))
        self.action_container = self._create_section("Actions"); self.add_btn_to_section(self.action_container, tr("BTN_ADD"))
        self.reaction_container = self._create_section("Reactions"); self.add_btn_to_section(self.reaction_container, tr("BTN_ADD"))
        self.legendary_container = self._create_section("Legendary Actions"); self.add_btn_to_section(self.legendary_container, tr("BTN_ADD"))
        layout.addWidget(self.trait_container); layout.addWidget(self.action_container)
        layout.addWidget(self.reaction_container); layout.addWidget(self.legendary_container); layout.addStretch()

    # --- YENİLENEN ENVANTER TABI ---
    def setup_inventory_tab(self):
        layout = QVBoxLayout(self.tab_inventory)
        
        # Kısım 1: Veritabanı Eşyaları (Linked Items)
        grp_linked = QGroupBox("Veritabanı Eşyaları (Ekipman)")
        l_linked = QVBoxLayout(grp_linked)
        h = QHBoxLayout()
        
        self.combo_all_items = QComboBox() # Tüm itemler buraya
        self.combo_all_items.setEditable(True)
        self.combo_all_items.setPlaceholderText("Veritabanından eşya seç...")
        
        self.btn_add_item_link = QPushButton(tr("BTN_ADD"))
        self.btn_add_item_link.setObjectName("successBtn")
        
        h.addWidget(self.combo_all_items, 3)
        h.addWidget(self.btn_add_item_link, 1)
        
        self.list_assigned_items = QListWidget()
        self.list_assigned_items.setMaximumHeight(120)
        self.list_assigned_items.setAlternatingRowColors(True)
        
        self.btn_remove_item_link = QPushButton(tr("BTN_REMOVE"))
        
        l_linked.addLayout(h)
        l_linked.addWidget(self.list_assigned_items)
        l_linked.addWidget(self.btn_remove_item_link)
        
        layout.addWidget(grp_linked)
        
        # Kısım 2: Manuel Eşyalar (Custom Inventory)
        self.inventory_container = self._create_section(tr("GRP_INVENTORY"))
        self.add_btn_to_section(self.inventory_container, tr("BTN_ADD"))
        
        layout.addWidget(self.inventory_container)
        layout.addWidget(self.inventory_container)
        layout.addStretch()

    def setup_docs_tab(self):
        layout = QVBoxLayout(self.tab_docs)
        grp = QGroupBox(tr("GRP_PDF"))
        v_layout = QVBoxLayout(grp)
        
        # Üst butonlar
        h_btn = QHBoxLayout()
        self.btn_add_pdf = QPushButton(tr("BTN_ADD"))
        self.btn_add_pdf.setObjectName("successBtn")
        self.btn_open_pdf_folder = QPushButton("📂") # Ekstra: Klasöre gitmek için
        h_btn.addWidget(self.btn_add_pdf, 3)
        h_btn.addWidget(self.btn_open_pdf_folder, 1)
        
        v_layout.addLayout(h_btn)
        
        # PDF Listesi
        self.list_pdfs = QListWidget()
        self.list_pdfs.setAlternatingRowColors(True)
        v_layout.addWidget(self.list_pdfs)
        
        # Alt butonlar (Aç / Sil)
        h_action = QHBoxLayout()
        self.btn_open_pdf = QPushButton(tr("BTN_OPEN_PDF"))
        self.btn_open_pdf.setObjectName("primaryBtn")
        self.btn_project_pdf = QPushButton(tr("BTN_PROJECT_PDF"))
        self.btn_project_pdf.setStyleSheet("background-color: #6a1b9a; color: white;") # Mor buton
        self.btn_remove_pdf = QPushButton(tr("BTN_REMOVE"))
        
        h_action.addWidget(self.btn_open_pdf)
        h_action.addWidget(self.btn_project_pdf)
        h_action.addWidget(self.btn_remove_pdf)
        v_layout.addLayout(h_action)
        
        layout.addWidget(grp)
        layout.addStretch()

    # --- YARDIMCILAR ---
    def _create_section(self, title):
        group = QGroupBox(title); v = QVBoxLayout(group); group.dynamic_area = QVBoxLayout(); v.addLayout(group.dynamic_area); return group

    def add_btn_to_section(self, container, label):
        btn = QPushButton(label); btn.clicked.connect(lambda: self.add_feature_card(container))
        container.layout().insertWidget(0, btn)

    def add_feature_card(self, group, name="", desc="", ph_title="Başlık", ph_desc="Detaylar..."):
        card = QFrame(); card.setStyleSheet("background-color: #2b2b2b; border: 1px solid #444; border-radius: 4px; margin-bottom: 4px;")
        l = QVBoxLayout(card); h = QHBoxLayout()
        t = QLineEdit(name); t.setPlaceholderText(ph_title); t.setStyleSheet("color: orange; font-weight: bold; border:none; font-size: 14px;")
        d = QTextEdit(desc); d.setPlaceholderText(ph_desc); d.setMaximumHeight(60); d.setStyleSheet("border:none; color: #ccc;")
        btn = QPushButton("❌"); btn.setFixedSize(24,24); btn.setCursor(Qt.CursorShape.PointingHandCursor)
        btn.clicked.connect(lambda: [group.dynamic_area.removeWidget(card), card.deleteLater()])
        h.addWidget(t); h.addWidget(btn); l.addLayout(h); l.addWidget(d)
        group.dynamic_area.addWidget(card)
        card.inp_title = t; card.inp_desc = d

    def clear_all_cards(self):
        containers = [self.trait_container, self.action_container, self.reaction_container, self.legendary_container, self.inventory_container, self.custom_spell_container]
        for g in containers:
            while g.dynamic_area.count(): 
                c = g.dynamic_area.takeAt(0)
                if c.widget(): c.widget().deleteLater()

    def build_dynamic_form(self, category_name):
        while self.layout_dynamic.rowCount() > 0: self.layout_dynamic.removeRow(0)
        self.dynamic_inputs = {} 
        schema = ENTITY_SCHEMAS.get(category_name, [])
        self.grp_dynamic.setTitle(f"{category_name} Özellikleri")
        for label, dtype, options in schema:
            widget = QComboBox() if dtype == "combo" else QLineEdit()
            if dtype == "combo" and options: widget.addItems(options); widget.setEditable(True)
            self.layout_dynamic.addRow(f"{label}:", widget); self.dynamic_inputs[label] = widget

    def update_ui_by_type(self, category_name):
        self.build_dynamic_form(category_name)
        is_npc_like = category_name in ["NPC", "Canavar"]
        is_player = category_name == "Oyuncu"
        is_lore = category_name == "Lore"
        
        # Lokasyon sadece NPC/Canavar/Oyuncu için
        self.lbl_location.setVisible(is_npc_like or is_player); self.combo_location.setVisible(is_npc_like or is_player)
        self.lbl_residents.setVisible(category_name == "Mekan"); self.list_residents.setVisible(category_name == "Mekan")
        
        # Sekme Görünürlükleri
        # 0:Stats, 1:Spells, 2:Actions, 3:Inv, 4:Docs
        
        # Stats: NPC, Canavar için tam. Oyuncu için gizleyebiliriz ama verileri görmek isteyebilir?
        # Kullanıcı "Sadece Notlar, Sınıf, Irk, Level" dedi. Bu 'Dynamic Inputs'da var.
        # Yani 'Stats' sekmesini Oyuncu için gizleyelim mi? Evet.
        
        self.tabs.setTabVisible(0, is_npc_like) # Stats (STR/DEX vs)
        self.tabs.setTabVisible(1, is_npc_like) # Spells
        self.tabs.setTabVisible(2, is_npc_like) # Actions
        self.tabs.setTabVisible(3, is_npc_like) # Inv
        
        # Docs: Lore ve Oyuncu için aktif
        self.tabs.setTabVisible(4, is_lore or is_player)

    def _add_form_vbox(self, pl, lt, w): v=QVBoxLayout(); v.addWidget(QLabel(lt)); v.addWidget(w); pl.addLayout(v)

    def prepare_new_entity(self):
        self.inp_name.clear(); self.inp_desc.clear(); self.inp_tags.clear(); self.lbl_image.setPixmap(None)
        self.image_list = []; self.current_img_index = 0; self.lbl_img_counter.setText("0/0") 
        self.clear_all_cards(); self.inp_type.setCurrentIndex(0)
        for i in self.stats_inputs.values(): i.setText("10")
        self.inp_hp.clear(); self.inp_ac.clear(); self.list_assigned_spells.clear(); self.list_assigned_items.clear()
        self.inp_prof.clear(); self.inp_pp.clear(); self.inp_skills.clear(); self.inp_init.clear()
        self.inp_saves.clear(); self.inp_vuln.clear(); self.inp_resist.clear(); self.inp_dmg_immune.clear(); self.inp_cond_immune.clear()
        self.combo_location.clear(); self.list_residents.clear(); self.list_pdfs.clear()