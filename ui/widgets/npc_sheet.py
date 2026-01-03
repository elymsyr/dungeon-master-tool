from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QFormLayout, 
                             QLineEdit, QTextEdit, QComboBox, QTabWidget, 
                             QLabel, QGroupBox, QPushButton, QScrollArea, QFrame, QListWidget)
from PyQt6.QtCore import Qt
from ui.widgets.aspect_ratio_label import AspectRatioLabel
from core.models import ENTITY_SCHEMAS

class NpcSheet(QWidget):
    def __init__(self):
        super().__init__()
        self.dynamic_inputs = {} 
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
        self.btn_select_img = QPushButton("Resim Seç")
        self.btn_show_player = QPushButton("👁️ Oyuncuya Göster")
        self.btn_show_player.setObjectName("primaryBtn")
        img_layout.addWidget(self.lbl_image); img_layout.addWidget(self.btn_select_img); img_layout.addWidget(self.btn_show_player); img_layout.addStretch()

        info_layout = QFormLayout()
        self.inp_name = QLineEdit()
        self.inp_type = QComboBox()
        self.inp_type.addItems(list(ENTITY_SCHEMAS.keys()))
        self.inp_type.currentTextChanged.connect(self.update_ui_by_type)
        self.inp_tags = QLineEdit(); self.inp_tags.setPlaceholderText("boss, ölü, tüccar...")
        
        self.combo_location = QComboBox()
        self.lbl_location = QLabel("Konum:")
        self.list_residents = QListWidget(); self.list_residents.setMaximumHeight(80)
        self.lbl_residents = QLabel("Sakinler:")
        self.inp_desc = QTextEdit(); self.inp_desc.setMaximumHeight(60); self.inp_desc.setPlaceholderText("Kısa notlar...")

        info_layout.addRow("İsim:", self.inp_name)
        info_layout.addRow("Tip:", self.inp_type)
        info_layout.addRow("Tagler:", self.inp_tags)
        info_layout.addRow(self.lbl_location, self.combo_location)
        info_layout.addRow(self.lbl_residents, self.list_residents)
        info_layout.addRow("Not:", self.inp_desc)

        top_layout.addLayout(img_layout); top_layout.addLayout(info_layout)
        self.content_layout.addLayout(top_layout)

        # --- DİNAMİK ALANLAR ---
        self.grp_dynamic = QGroupBox("Özellikler")
        self.layout_dynamic = QFormLayout(self.grp_dynamic)
        self.content_layout.addWidget(self.grp_dynamic)

        # --- SEKMELER ---
        self.tabs = QTabWidget()
        self.tab_stats = QWidget(); self.setup_stats_tab(); self.tabs.addTab(self.tab_stats, "📊 Statlar")
        self.tab_spells = QWidget(); self.setup_spells_tab(); self.tabs.addTab(self.tab_spells, "✨ Büyüler")
        self.tab_features = QWidget(); self.setup_features_tab(); self.tabs.addTab(self.tab_features, "⚔️ Aksiyonlar")
        self.tab_inventory = QWidget(); self.setup_inventory_tab(); self.tabs.addTab(self.tab_inventory, "🎒 Envanter") # GÜNCELLENDİ

        self.content_layout.addWidget(self.tabs)
        scroll.setWidget(self.content_widget)
        main_layout.addWidget(scroll)

        # --- BUTONLAR ---
        btn_layout = QHBoxLayout(); btn_layout.setContentsMargins(10, 10, 10, 10)
        self.btn_delete = QPushButton("Sil"); self.btn_delete.setObjectName("dangerBtn")
        self.btn_save = QPushButton("Kaydet"); self.btn_save.setObjectName("primaryBtn")
        btn_layout.addStretch(); btn_layout.addWidget(self.btn_delete); btn_layout.addWidget(self.btn_save)
        main_layout.addLayout(btn_layout)
        
        self.update_ui_by_type(self.inp_type.currentText())

    # --- TAB KURULUMLARI ---
    def setup_stats_tab(self):
        layout = QVBoxLayout(self.tab_stats)
        grp = QGroupBox("Ability Scores"); l = QHBoxLayout(grp)
        self.stats_inputs = {}
        for s in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
            v = QVBoxLayout(); inp = QLineEdit("10"); inp.setAlignment(Qt.AlignmentFlag.AlignCenter); inp.setMaximumWidth(50)
            self.stats_inputs[s] = inp; v.addWidget(QLabel(s)); v.addWidget(inp); l.addLayout(v)
        layout.addWidget(grp)
        grp2 = QGroupBox("Savaş"); l2 = QHBoxLayout(grp2)
        self.inp_hp = QLineEdit(); self.inp_ac = QLineEdit(); self.inp_speed = QLineEdit(); self.inp_cr = QLineEdit()
        for t, w in [("HP", self.inp_hp), ("AC", self.inp_ac), ("Hız", self.inp_speed), ("CR", self.inp_cr)]:
            v = QVBoxLayout(); v.addWidget(QLabel(t)); v.addWidget(w); l2.addLayout(v)
        layout.addWidget(grp2); layout.addStretch()

    def setup_spells_tab(self):
        layout = QVBoxLayout(self.tab_spells)
        # Veritabanı
        grp_linked = QGroupBox("Veritabanı Büyüleri")
        l_linked = QVBoxLayout(grp_linked)
        h = QHBoxLayout()
        self.combo_all_spells = QComboBox(); self.combo_all_spells.setEditable(True); self.combo_all_spells.setPlaceholderText("Ara...")
        self.btn_add_spell = QPushButton("Ekle"); self.btn_add_spell.setObjectName("successBtn")
        h.addWidget(self.combo_all_spells, 3); h.addWidget(self.btn_add_spell, 1)
        self.list_assigned_spells = QListWidget(); self.list_assigned_spells.setMaximumHeight(120); self.list_assigned_spells.setAlternatingRowColors(True)
        self.btn_remove_spell = QPushButton("Seçiliyi Kaldır")
        l_linked.addLayout(h); l_linked.addWidget(self.list_assigned_spells); l_linked.addWidget(self.btn_remove_spell)
        layout.addWidget(grp_linked)
        # Manuel
        self.custom_spell_container = self._create_section("Manuel Büyüler")
        self.add_btn_to_section(self.custom_spell_container, "➕ Manuel Büyü Ekle")
        layout.addWidget(self.custom_spell_container); layout.addStretch()

    def setup_features_tab(self):
        layout = QVBoxLayout(self.tab_features)
        self.trait_container = self._create_section("Traits"); self.add_btn_to_section(self.trait_container, "➕ Trait Ekle")
        self.action_container = self._create_section("Actions"); self.add_btn_to_section(self.action_container, "➕ Action Ekle")
        self.reaction_container = self._create_section("Reactions"); self.add_btn_to_section(self.reaction_container, "➕ Reaction Ekle")
        self.legendary_container = self._create_section("Legendary Actions"); self.add_btn_to_section(self.legendary_container, "➕ Legendary Ekle")
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
        
        self.btn_add_item_link = QPushButton("Ekle")
        self.btn_add_item_link.setObjectName("successBtn")
        
        h.addWidget(self.combo_all_items, 3)
        h.addWidget(self.btn_add_item_link, 1)
        
        self.list_assigned_items = QListWidget()
        self.list_assigned_items.setMaximumHeight(120)
        self.list_assigned_items.setAlternatingRowColors(True)
        
        self.btn_remove_item_link = QPushButton("Seçili Eşyayı Kaldır")
        
        l_linked.addLayout(h)
        l_linked.addWidget(self.list_assigned_items)
        l_linked.addWidget(self.btn_remove_item_link)
        
        layout.addWidget(grp_linked)
        
        # Kısım 2: Manuel Eşyalar (Custom Inventory)
        self.inventory_container = self._create_section("Manuel / Diğer Eşyalar")
        self.add_btn_to_section(self.inventory_container, "➕ Elle Eşya Ekle")
        
        layout.addWidget(self.inventory_container)
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
        is_npc = category_name in ["NPC", "Canavar", "Oyuncu"]
        self.lbl_location.setVisible(is_npc); self.combo_location.setVisible(is_npc)
        self.lbl_residents.setVisible(category_name == "Mekan"); self.list_residents.setVisible(category_name == "Mekan")
        for i in range(self.tabs.count()): self.tabs.setTabVisible(i, is_npc)

    def _add_form_vbox(self, pl, lt, w): v=QVBoxLayout(); v.addWidget(QLabel(lt)); v.addWidget(w); pl.addLayout(v)

    def prepare_new_entity(self):
        self.inp_name.clear(); self.inp_desc.clear(); self.inp_tags.clear(); self.lbl_image.setPixmap(None)
        self.clear_all_cards(); self.inp_type.setCurrentIndex(0)
        for i in self.stats_inputs.values(): i.setText("10")
        self.inp_hp.clear(); self.inp_ac.clear(); self.list_assigned_spells.clear(); self.list_assigned_items.clear()
        self.combo_location.clear(); self.list_residents.clear()