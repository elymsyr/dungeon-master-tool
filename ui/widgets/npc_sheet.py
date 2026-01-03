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

        # --- ÜST BÖLÜM: TEMEL BİLGİ ---
        top_layout = QHBoxLayout()
        
        # Sol: Resim
        img_layout = QVBoxLayout()
        self.lbl_image = AspectRatioLabel()
        self.lbl_image.setFixedSize(200, 200)
        self.btn_select_img = QPushButton("Resim Seç")
        self.btn_show_player = QPushButton("👁️ Oyuncuya Göster")
        self.btn_show_player.setObjectName("primaryBtn")
        
        img_layout.addWidget(self.lbl_image)
        img_layout.addWidget(self.btn_select_img)
        img_layout.addWidget(self.btn_show_player)
        img_layout.addStretch()

        # Sağ: İsim, Tip, İlişkiler
        info_layout = QFormLayout()
        self.inp_name = QLineEdit()
        
        self.inp_type = QComboBox()
        self.inp_type.addItems(list(ENTITY_SCHEMAS.keys()))
        self.inp_type.currentTextChanged.connect(self.update_ui_by_type)

        self.inp_tags = QLineEdit()
        self.inp_tags.setPlaceholderText("boss, ölü, tüccar...")
        
        # --- İLİŞKİLER (YENİ) ---
        # 1. NPC için: Konum Seçici
        self.combo_location = QComboBox()
        self.combo_location.setPlaceholderText("Bir mekan seçin...")
        self.lbl_location = QLabel("Konum:")
        
        # 2. Mekan için: Sakinler Listesi
        self.list_residents = QListWidget()
        self.list_residents.setMaximumHeight(100)
        self.lbl_residents = QLabel("Buradaki Karakterler:")

        self.inp_desc = QTextEdit()
        self.inp_desc.setMaximumHeight(80)
        self.inp_desc.setPlaceholderText("Kısa tanım / DM Notları...")

        info_layout.addRow("İsim:", self.inp_name)
        info_layout.addRow("Tip:", self.inp_type)
        info_layout.addRow("Tagler:", self.inp_tags)
        
        # İlişki widgetlarını forma ekle (Görünürlükleri kodla ayarlanacak)
        info_layout.addRow(self.lbl_location, self.combo_location)
        info_layout.addRow(self.lbl_residents, self.list_residents)
        
        info_layout.addRow("Not:", self.inp_desc)

        top_layout.addLayout(img_layout)
        top_layout.addLayout(info_layout)
        self.content_layout.addLayout(top_layout)

        # --- DİNAMİK ALANLAR ---
        self.grp_dynamic = QGroupBox("Kategori Özellikleri")
        self.layout_dynamic = QFormLayout(self.grp_dynamic)
        self.content_layout.addWidget(self.grp_dynamic)

        # --- SEKMELER ---
        self.tabs = QTabWidget()
        self.tab_stats = QWidget()
        self.setup_stats_tab()
        self.tabs.addTab(self.tab_stats, "📊 Statlar & Savaş")

        self.tab_features = QWidget()
        self.setup_features_tab()
        self.tabs.addTab(self.tab_features, "⚔️ Yetenekler & Kartlar")

        self.content_layout.addWidget(self.tabs)
        scroll.setWidget(self.content_widget)
        main_layout.addWidget(scroll)

        # --- BUTONLAR ---
        btn_layout = QHBoxLayout()
        btn_layout.setContentsMargins(10, 10, 10, 10)
        self.btn_delete = QPushButton("Sil")
        self.btn_delete.setObjectName("dangerBtn")
        self.btn_save = QPushButton("Kaydet")
        self.btn_save.setObjectName("primaryBtn")
        btn_layout.addStretch()
        btn_layout.addWidget(self.btn_delete)
        btn_layout.addWidget(self.btn_save)
        main_layout.addLayout(btn_layout)
        
        # Başlangıç ayarı
        self.update_ui_by_type(self.inp_type.currentText())

    def update_ui_by_type(self, category_name):
        """Tip değişince hem dinamik formu hem de ilişki araçlarını ayarlar"""
        self.build_dynamic_form(category_name)
        
        # İlişki Görünürlüğü
        is_npc = category_name in ["NPC", "Canavar", "Oyuncu"]
        is_location = category_name == "Mekan"
        
        # NPC ise Konum seçebilsin
        self.lbl_location.setVisible(is_npc)
        self.combo_location.setVisible(is_npc)
        
        # Mekan ise Sakinleri görsün
        self.lbl_residents.setVisible(is_location)
        self.list_residents.setVisible(is_location)

    def build_dynamic_form(self, category_name):
        while self.layout_dynamic.rowCount() > 0:
            self.layout_dynamic.removeRow(0)
        self.dynamic_inputs = {} 

        schema = ENTITY_SCHEMAS.get(category_name, [])
        self.grp_dynamic.setTitle(f"{category_name} Özellikleri")
        
        for label, dtype, options in schema:
            if dtype == "combo":
                widget = QComboBox()
                if options: widget.addItems(options)
                widget.setEditable(True)
            else:
                widget = QLineEdit()
            
            self.layout_dynamic.addRow(f"{label}:", widget)
            self.dynamic_inputs[label] = widget

        has_stats = category_name in ["NPC", "Canavar"]
        self.tabs.setTabVisible(0, has_stats)
        if not has_stats:
            self.tabs.setCurrentIndex(1)
        else:
            self.tabs.setTabVisible(0, True)

    def setup_stats_tab(self):
        layout = QVBoxLayout(self.tab_stats)
        grp_scores = QGroupBox("Ability Scores")
        score_layout = QHBoxLayout(grp_scores)
        self.stats_inputs = {}
        for stat in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
            vbox = QVBoxLayout()
            lbl = QLabel(stat); lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
            inp = QLineEdit("10"); inp.setAlignment(Qt.AlignmentFlag.AlignCenter); inp.setMaximumWidth(50)
            self.stats_inputs[stat] = inp
            vbox.addWidget(lbl); vbox.addWidget(inp)
            score_layout.addLayout(vbox)
        layout.addWidget(grp_scores)

        grp_combat = QGroupBox("Savaş Bilgileri")
        combat_layout = QHBoxLayout(grp_combat)
        self.inp_hp = QLineEdit(); self.inp_hp.setPlaceholderText("Örn: 24 (4d8+4)")
        self.inp_ac = QLineEdit(); self.inp_ac.setPlaceholderText("15")
        self.inp_speed = QLineEdit(); self.inp_speed.setPlaceholderText("30 ft")
        self.inp_cr = QLineEdit(); self.inp_cr.setPlaceholderText("1/4")

        self._add_form_vbox(combat_layout, "HP:", self.inp_hp)
        self._add_form_vbox(combat_layout, "AC:", self.inp_ac)
        self._add_form_vbox(combat_layout, "Hız:", self.inp_speed)
        self._add_form_vbox(combat_layout, "CR:", self.inp_cr)
        layout.addWidget(grp_combat)
        layout.addStretch()

    def setup_features_tab(self):
        layout = QVBoxLayout(self.tab_features)
        
        # TRAITS SECTION
        self.trait_container = self._create_section("Özellikler (Traits)")
        # Manuel Ekleme Butonu
        self.btn_add_trait = QPushButton("➕ Yeni Özellik Ekle")
        self.btn_add_trait.clicked.connect(lambda: self.add_feature_card(self.trait_container))
        self.trait_container.layout().addWidget(self.btn_add_trait) # Gruba ekle
        
        # ACTIONS SECTION
        self.action_container = self._create_section("Aksiyonlar (Actions)")
        # Manuel Ekleme Butonu
        self.btn_add_action = QPushButton("➕ Yeni Aksiyon Ekle")
        self.btn_add_action.clicked.connect(lambda: self.add_feature_card(self.action_container))
        self.action_container.layout().addWidget(self.btn_add_action)

        layout.addWidget(self.trait_container)
        layout.addWidget(self.action_container)
        layout.addStretch()

    def _create_section(self, title):
        group = QGroupBox(title)
        vbox = QVBoxLayout(group)
        group.dynamic_area = QVBoxLayout()
        vbox.addLayout(group.dynamic_area)
        return group
    
    def add_feature_card(self, section_group, name="", desc=""):
        card = QFrame()
        card.setStyleSheet("background-color: #2b2b2b; border: 1px solid #444; border-radius: 4px; margin-bottom: 5px;")
        card_layout = QVBoxLayout(card)
        
        inp_title = QLineEdit(name)
        inp_title.setPlaceholderText("Başlık (Örn: Ateş Topu)")
        inp_title.setStyleSheet("font-weight: bold; color: #ffa500; border: none; background: transparent;")
        
        inp_desc = QTextEdit(desc)
        inp_desc.setPlaceholderText("Detayları buraya yazın...")
        inp_desc.setMaximumHeight(60)
        inp_desc.setStyleSheet("border: none; background: transparent;")
        
        # Silme butonu (Küçük bir X)
        btn_remove = QPushButton("❌")
        btn_remove.setFixedSize(20, 20)
        btn_remove.setStyleSheet("background: transparent; color: #888; border: none;")
        btn_remove.clicked.connect(lambda: self._remove_card(section_group, card))
        
        # Başlık ve silme butonunu yan yana koy
        header = QHBoxLayout()
        header.setContentsMargins(0,0,0,0)
        header.addWidget(inp_title)
        header.addWidget(btn_remove)
        
        card_layout.addLayout(header)
        card_layout.addWidget(inp_desc)
        
        section_group.dynamic_area.addWidget(card)
        
        card.inp_title = inp_title
        card.inp_desc = inp_desc

    def _remove_card(self, section_group, card):
        section_group.dynamic_area.removeWidget(card)
        card.deleteLater()

    def clear_features(self):
        for group in [self.trait_container, self.action_container]:
            layout = group.dynamic_area
            while layout.count():
                child = layout.takeAt(0)
                if child.widget():
                    child.widget().deleteLater()

    def _add_form_vbox(self, parent_layout, label_text, widget):
        vbox = QVBoxLayout()
        lbl = QLabel(label_text); vbox.addWidget(lbl); vbox.addWidget(widget)
        parent_layout.addLayout(vbox)

    def prepare_new_entity(self):
        self.inp_name.clear()
        self.inp_desc.clear()
        self.inp_tags.clear()
        self.lbl_image.setPixmap(None)
        self.clear_features()
        self.inp_type.setCurrentIndex(0) 
        for inp in self.stats_inputs.values(): inp.setText("10")
        self.inp_hp.clear(); self.inp_ac.clear(); self.inp_speed.clear(); self.inp_cr.clear()
        self.combo_location.clear()
        self.list_residents.clear()