from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QFormLayout, 
                             QLineEdit, QTextEdit, QComboBox, QTabWidget, 
                             QLabel, QGroupBox, QPushButton, QScrollArea, QFrame, 
                             QListWidget, QFileDialog, QMessageBox, QStyle)
from PyQt6.QtCore import Qt, QUrl
from PyQt6.QtGui import QDesktopServices, QPixmap
from ui.widgets.aspect_ratio_label import AspectRatioLabel
from core.models import ENTITY_SCHEMAS
from core.locales import tr
import os

class NpcSheet(QWidget):
    def __init__(self):
        super().__init__()
        self.dynamic_inputs = {}
        self.image_list = []
        self.current_img_index = 0
        self.init_ui()

    def init_ui(self):
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)

        # Scroll Area Ayarları
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setObjectName("mainScroll") 
        
        # İçerik Widget'ı (Tema rengini alması için ayarlar)
        self.content_widget = QWidget()
        self.content_widget.setObjectName("sheetContainer")
        self.content_widget.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)

        self.content_layout = QVBoxLayout(self.content_widget)
        
        # --- ÜST BÖLÜM (RESİM & TEMEL BİLGİ) ---
        top_layout = QHBoxLayout()
        img_layout = QVBoxLayout()
        
        # Resim Gösterici
        self.lbl_image = AspectRatioLabel()
        self.lbl_image.setFixedSize(200, 200)
        
        # Galeri Kontrolleri
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
        
        # Resim Ekle/Sil Butonları
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

        # Oyuncuya Göster Butonu
        self.btn_show_player = QPushButton(tr("BTN_SHOW_PLAYER"))
        self.btn_show_player.setObjectName("primaryBtn")
        
        img_layout.addWidget(self.lbl_image)
        img_layout.addLayout(gallery_controls)
        img_layout.addLayout(btn_img_actions)
        img_layout.addWidget(self.btn_show_player)
        img_layout.addStretch()

        # Bilgi Formu
        info_layout = QFormLayout()
        self.inp_name = QLineEdit()
        self.inp_type = QComboBox()
        
        for cat in ENTITY_SCHEMAS.keys():
            self.inp_type.addItem(tr(f"CAT_{cat.upper().replace(' ', '_').replace('(', '').replace(')', '')}"), cat)
        self.inp_type.currentIndexChanged.connect(self._on_type_index_changed)
        
        self.inp_tags = QLineEdit(); self.inp_tags.setPlaceholderText(tr("LBL_TAGS_PH"))
        
        self.combo_location = QComboBox()
        self.lbl_location = QLabel(tr("LBL_LOCATION"))
        self.list_residents = QListWidget(); self.list_residents.setMaximumHeight(80)
        self.lbl_residents = QLabel(tr("LBL_RESIDENTS"))
        
        self.inp_desc = QTextEdit()
        self.inp_desc.setMinimumHeight(80)
        self.inp_desc.setMaximumHeight(150)
        self.inp_desc.setPlaceholderText(tr("LBL_DESC"))

        info_layout.addRow(tr("LBL_NAME"), self.inp_name)
        info_layout.addRow(tr("LBL_TYPE"), self.inp_type)
        info_layout.addRow(tr("LBL_TAGS"), self.inp_tags)
        info_layout.addRow(self.lbl_location, self.combo_location)
        info_layout.addRow(self.lbl_residents, self.list_residents)
        info_layout.addRow(tr("LBL_DESC"), self.inp_desc)

        top_layout.addLayout(img_layout); top_layout.addLayout(info_layout)
        self.content_layout.addLayout(top_layout)

        # --- DİNAMİK ALANLAR ---
        self.grp_dynamic = QGroupBox(tr("LBL_PROPERTIES"))
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

        # --- ALT BUTONLAR ---
        btn_layout = QHBoxLayout(); btn_layout.setContentsMargins(10, 10, 10, 10)
        self.btn_delete = QPushButton(tr("BTN_DELETE")); self.btn_delete.setObjectName("dangerBtn")
        self.btn_save = QPushButton(tr("BTN_SAVE")); self.btn_save.setObjectName("primaryBtn")
        btn_layout.addStretch(); btn_layout.addWidget(self.btn_delete); btn_layout.addWidget(self.btn_save)
        main_layout.addLayout(btn_layout)
        
        self.update_ui_by_type(self.inp_type.currentData())

    def retranslate_ui(self):
        """
        Dil değiştiğinde arayüzdeki tüm metinleri günceller.
        Dinamik alanlar (etiketler ve combobox seçenekleri) dahildir.
        """
        # 1. Statik Combobox (Varlık Tipi) Güncellemesi
        for i in range(self.inp_type.count()):
            cat = self.inp_type.itemData(i)
            if cat:
                # CAT_NPC, CAT_MONSTER gibi anahtarları çevir
                self.inp_type.setItemText(i, tr(f"CAT_{cat.upper().replace(' ', '_').replace('(', '').replace(')', '')}"))

        # 2. Buton ve Etiket Metinleri
        self.btn_show_player.setText(tr("BTN_SHOW_PLAYER"))
        self.btn_add_img.setText(tr("BTN_ADD"))
        self.btn_remove_img.setToolTip(tr("BTN_REMOVE"))
        self.lbl_location.setText(tr("LBL_LOCATION"))
        self.lbl_residents.setText(tr("LBL_RESIDENTS"))
        self.inp_desc.setPlaceholderText(tr("LBL_DESC"))
        
        # 3. Dinamik Özellikler Alanı (Grup Başlığı ve İçerik)
        cat_key = self.inp_type.currentData()
        if cat_key: 
            cat_trans = tr(f"CAT_{cat_key.upper()}") if cat_key in ENTITY_SCHEMAS else cat_key
            self.grp_dynamic.setTitle(f"{cat_trans} {tr('LBL_PROPERTIES')}")
        else: 
            self.grp_dynamic.setTitle(tr("LBL_PROPERTIES"))

        # --- KRİTİK KISIM: Dinamik Form Elemanlarını Güncelleme ---
        # self.dynamic_inputs sözlüğü { "LBL_RACE": widget_objesi } şeklindedir.
        for label_key, widget in self.dynamic_inputs.items():
            # A) Sol taraftaki Etiketi (Label) Güncelle
            # QFormLayout, bir widget'a bağlı olan etiketi bulmamızı sağlar.
            label_widget = self.layout_dynamic.labelForField(widget)
            if label_widget:
                label_widget.setText(f"{tr(label_key)}:")
            
            # B) Eğer Widget bir ComboBox ise, seçenekleri (Items) Güncelle
            if isinstance(widget, QComboBox):
                for i in range(widget.count()):
                    # build_dynamic_form fonksiyonunda kaydettiğimiz orijinal anahtarı (key) alıyoruz.
                    original_key = widget.itemData(i)
                    if original_key:
                        # Eğer anahtar "LBL_" ile başlıyorsa çevirisini al, yoksa olduğu gibi bırak
                        new_text = tr(original_key) if str(original_key).startswith("LBL_") else original_key
                        widget.setItemText(i, new_text)

        # 4. Sekme Başlıkları
        self.tabs.setTabText(0, tr("TAB_STATS"))
        self.tabs.setTabText(1, tr("TAB_SPELLS"))
        self.tabs.setTabText(2, tr("TAB_ACTIONS"))
        self.tabs.setTabText(3, tr("TAB_INV"))
        self.tabs.setTabText(4, tr("TAB_DOCS"))
        
        # 5. Alt Butonlar
        self.btn_delete.setText(tr("BTN_DELETE"))
        self.btn_save.setText(tr("BTN_SAVE"))
        
        # 6. Alt Grup Başlıkları (Varsa)
        if hasattr(self, "grp_base_stats"): self.grp_base_stats.setTitle(tr("GRP_STATS"))
        if hasattr(self, "grp_combat_stats"): self.grp_combat_stats.setTitle(tr("GRP_COMBAT"))
        if hasattr(self, "grp_defense"): self.grp_defense.setTitle(tr("GRP_DEFENSE"))
        if hasattr(self, "grp_spells"): self.grp_spells.setTitle(tr("GRP_SPELLS"))
        if hasattr(self, "grp_inventory"): self.grp_inventory.setTitle(tr("GRP_INVENTORY"))
        if hasattr(self, "grp_pdf"): self.grp_pdf.setTitle(tr("GRP_PDF"))
        if hasattr(self, "grp_db_items"): self.grp_db_items.setTitle(tr("LBL_DB_ITEMS"))
        
        # 7. Kart Alanı Başlıkları
        self.trait_container.setTitle(tr("LBL_TRAITS"))
        self.action_container.setTitle(tr("LBL_ACTIONS"))
        self.reaction_container.setTitle(tr("LBL_REACTIONS"))
        self.legendary_container.setTitle(tr("LBL_LEGENDARY_ACTIONS"))
        self.custom_spell_container.setTitle(tr("LBL_MANUAL_SPELLS"))
        self.inventory_container.setTitle(tr("GRP_INVENTORY"))

        # 8. Statik Placeholder Güncellemeleri
        self.inp_tags.setPlaceholderText(tr("LBL_TAGS_PH"))
        self.inp_hp.setPlaceholderText(tr("LBL_HP"))
        self.inp_max_hp.setPlaceholderText(tr("LBL_MAX_HP"))
        self.inp_ac.setPlaceholderText(tr("HEADER_AC"))
        self.inp_init.setPlaceholderText(tr("LBL_INIT"))
        self.combo_all_spells.setPlaceholderText(tr("LBL_SEARCH"))

    def build_dynamic_form(self, category_name):
        """
        Entity tipine göre (NPC, Monster vs.) dinamik form alanlarını oluşturur.
        Önemli: ComboBox'larda itemData olarak çeviri anahtarını saklarız.
        Böylece dil değiştiğinde orijinal anahtarı bulup tekrar çevirebiliriz.
        """
        # 1. Mevcut satırları temizle
        while self.layout_dynamic.rowCount() > 0: 
            self.layout_dynamic.removeRow(0)
        
        # Referans sözlüğünü sıfırla
        self.dynamic_inputs = {} 
        
        # İlgili şemayı al
        schema = ENTITY_SCHEMAS.get(category_name, [])
        
        # Grup başlığını ayarla (Örn: NPC Özellikler)
        cat_trans = tr(f"CAT_{category_name.upper()}") if category_name in ENTITY_SCHEMAS else category_name
        self.grp_dynamic.setTitle(f"{cat_trans} {tr('LBL_PROPERTIES')}")
        
        # 2. Şemadaki her alan için widget oluştur
        for label_key, dtype, options in schema:
            if dtype == "combo":
                widget = QComboBox()
                widget.setEditable(True) # Kullanıcı manuel de yazabilsin
                if options:
                    for opt in options:
                        # Görünen Metin: tr(opt) -> "Dost"
                        # Arka Plan Verisi: opt -> "LBL_ATTR_FRIENDLY"
                        display_text = tr(opt) if str(opt).startswith("LBL_") else opt
                        widget.addItem(display_text, opt) 
            else:
                widget = QLineEdit()
            
            # 3. Form satırını ekle
            # label_key (Örn: "LBL_RACE") kullanarak çeviriyi alıyoruz
            self.layout_dynamic.addRow(f"{tr(label_key)}:", widget)
            
            # 4. Widget'ı sözlüğe kaydet
            # Anahtar olarak label_key kullanıyoruz ki retranslate sırasında etiketi bulabilelim.
            self.dynamic_inputs[label_key] = widget

    # --- RESİM YÖNETİMİ ---
    def add_image_dialog(self):
        fname, _ = QFileDialog.getOpenFileName(self, tr("BTN_SELECT_IMG"), "", "Images (*.png *.jpg *.jpeg *.bmp)")
        if fname:
            self.image_list.append(fname)
            self.current_img_index = len(self.image_list) - 1
            self.update_image_display()

    def remove_current_image(self):
        if not self.image_list: return
        del self.image_list[self.current_img_index]
        if self.current_img_index >= len(self.image_list):
            self.current_img_index = max(0, len(self.image_list) - 1)
        self.update_image_display()

    def show_prev_image(self):
        if not self.image_list: return
        self.current_img_index = (self.current_img_index - 1) % len(self.image_list)
        self.update_image_display()

    def show_next_image(self):
        if not self.image_list: return
        self.current_img_index = (self.current_img_index + 1) % len(self.image_list)
        self.update_image_display()

    def update_image_display(self):
        if not self.image_list:
            self.lbl_image.setPixmap(None)
            self.lbl_img_counter.setText("0/0")
            return
        
        path = self.image_list[self.current_img_index]
        if os.path.exists(path):
            self.lbl_image.setPixmap(QPixmap(path))
        else:
            self.lbl_image.setPixmap(None)
            
        self.lbl_img_counter.setText(f"{self.current_img_index + 1}/{len(self.image_list)}")

    # --- TAB KURULUMLARI ---
    def setup_stats_tab(self):
        layout = QVBoxLayout(self.tab_stats)
        self.grp_base_stats = QGroupBox(tr("GRP_STATS")); l = QHBoxLayout(self.grp_base_stats)
        self.stats_inputs = {}; self.stats_modifiers = {}
        for s in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
            v = QVBoxLayout()
            lbl_title = QLabel(s); lbl_title.setAlignment(Qt.AlignmentFlag.AlignCenter); lbl_title.setStyleSheet("font-weight: bold;")
            inp = QLineEdit("10"); inp.setAlignment(Qt.AlignmentFlag.AlignCenter); inp.setMaximumWidth(50)
            inp.textChanged.connect(lambda text, key=s: self._update_modifier(key, text))
            lbl_mod = QLabel("+0"); lbl_mod.setAlignment(Qt.AlignmentFlag.AlignCenter); lbl_mod.setProperty("class", "statModifier")
            self.stats_inputs[s] = inp; self.stats_modifiers[s] = lbl_mod
            v.addWidget(lbl_title); v.addWidget(inp); v.addWidget(lbl_mod); l.addLayout(v)
        layout.addWidget(self.grp_base_stats)
        self.grp_combat_stats = self._create_combat_stats_group()
        layout.addWidget(self.grp_combat_stats)
        self.grp_defense = QGroupBox(tr("GRP_DEFENSE")); form3 = QFormLayout(self.grp_defense)
        self.inp_saves = QLineEdit(); self.inp_skills = QLineEdit()
        self.inp_vuln = QLineEdit(); self.inp_resist = QLineEdit()
        self.inp_dmg_immune = QLineEdit(); self.inp_cond_immune = QLineEdit()
        form3.addRow(tr("LBL_SAVES"), self.inp_saves); form3.addRow(tr("LBL_SKILLS"), self.inp_skills)
        form3.addRow(tr("LBL_VULN"), self.inp_vuln); form3.addRow(tr("LBL_RESIST"), self.inp_resist)
        form3.addRow(tr("LBL_DMG_IMMUNE"), self.inp_dmg_immune); form3.addRow(tr("LBL_COND_IMMUNE"), self.inp_cond_immune)
        layout.addWidget(self.grp_defense); layout.addStretch()
        
    def _create_combat_stats_group(self):
        grp = QGroupBox(tr("GRP_COMBAT"))
        v_comb = QVBoxLayout(grp)
        self.inp_hp = QLineEdit(); self.inp_hp.setPlaceholderText(tr("LBL_HP"))
        self.inp_max_hp = QLineEdit(); self.inp_max_hp.setPlaceholderText(tr("LBL_MAX_HP"))
        self.inp_ac = QLineEdit(); self.inp_ac.setPlaceholderText(tr("HEADER_AC"))
        self.inp_speed = QLineEdit(); self.inp_prof = QLineEdit(); self.inp_pp = QLineEdit()
        self.inp_init = QLineEdit(); self.inp_init.setPlaceholderText(tr("LBL_INIT"))
        row1 = QHBoxLayout()
        for t, w in [(tr("LBL_MAX_HP"), self.inp_max_hp), (tr("LBL_HP"), self.inp_hp), (tr("HEADER_AC"), self.inp_ac), (tr("LBL_SPEED"), self.inp_speed)]:
             v = QVBoxLayout(); v.addWidget(QLabel(t)); v.addWidget(w); row1.addLayout(v)
        row2 = QHBoxLayout()
        for t, w in [(tr("LBL_PROF_BONUS"), self.inp_prof), (tr("LBL_PASSIVE_PERC"), self.inp_pp), (tr("LBL_INIT_BONUS"), self.inp_init)]:
             v = QVBoxLayout(); v.addWidget(QLabel(t)); v.addWidget(w); row2.addLayout(v)
        v_comb.addLayout(row1); v_comb.addLayout(row2)
        return grp

    def _update_modifier(self, stat_key, text_value):
        try:
            val = int(text_value); mod = (val - 10) // 2; sign = "+" if mod >= 0 else ""
            self.stats_modifiers[stat_key].setText(f"{sign}{mod}")
            state = "positive" if mod > 0 else "neutral"
            self.stats_modifiers[stat_key].setProperty("state", state)
            self.stats_modifiers[stat_key].style().unpolish(self.stats_modifiers[stat_key])
            self.stats_modifiers[stat_key].style().polish(self.stats_modifiers[stat_key])
            if mod > 0: self.stats_modifiers[stat_key].setStyleSheet("color: #4caf50; font-weight: bold;")
            else: self.stats_modifiers[stat_key].setStyleSheet("color: #aaa; font-weight: normal;")
        except ValueError:
            self.stats_modifiers[stat_key].setText("-")

    def setup_spells_tab(self):
        layout = QVBoxLayout(self.tab_spells)
        self.grp_spells = QGroupBox(tr("GRP_SPELLS"))
        l_linked = QVBoxLayout(self.grp_spells)
        h = QHBoxLayout()
        self.combo_all_spells = QComboBox(); self.combo_all_spells.setEditable(True); self.combo_all_spells.setPlaceholderText(tr("LBL_SEARCH"))
        self.btn_add_spell = QPushButton(tr("BTN_ADD")); self.btn_add_spell.setObjectName("successBtn")
        h.addWidget(self.combo_all_spells, 3); h.addWidget(self.btn_add_spell, 1)
        self.list_assigned_spells = QListWidget(); self.list_assigned_spells.setAlternatingRowColors(True); self.list_assigned_spells.setMinimumHeight(300)
        self.btn_remove_spell = QPushButton(tr("BTN_REMOVE")); self.btn_remove_spell.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_TrashIcon)); self.btn_remove_spell.setObjectName("dangerBtn")
        l_linked.addLayout(h); l_linked.addWidget(self.list_assigned_spells); l_linked.addWidget(self.btn_remove_spell)
        layout.addWidget(self.grp_spells)
        self.custom_spell_container = self._create_section(tr("LBL_MANUAL_SPELLS"))
        self.add_btn_to_section(self.custom_spell_container, tr("BTN_ADD"))
        layout.addWidget(self.custom_spell_container); layout.addStretch()

    def setup_features_tab(self):
        layout = QVBoxLayout(self.tab_features)
        self.trait_container = self._create_section(tr("LBL_TRAITS")); self.add_btn_to_section(self.trait_container, tr("BTN_ADD"))
        self.action_container = self._create_section(tr("LBL_ACTIONS")); self.add_btn_to_section(self.action_container, tr("BTN_ADD"))
        self.reaction_container = self._create_section(tr("LBL_REACTIONS")); self.add_btn_to_section(self.reaction_container, tr("BTN_ADD"))
        self.legendary_container = self._create_section(tr("LBL_LEGENDARY_ACTIONS")); self.add_btn_to_section(self.legendary_container, tr("BTN_ADD"))
        layout.addWidget(self.trait_container); layout.addWidget(self.action_container); layout.addWidget(self.reaction_container); layout.addWidget(self.legendary_container); layout.addStretch()

    def setup_inventory_tab(self):
        layout = QVBoxLayout(self.tab_inventory)
        self.grp_db_items = QGroupBox(tr("LBL_DB_ITEMS")); l_linked = QVBoxLayout(self.grp_db_items); h = QHBoxLayout()
        self.combo_all_items = QComboBox(); self.combo_all_items.setEditable(True)
        self.btn_add_item_link = QPushButton(tr("BTN_ADD")); self.btn_add_item_link.setObjectName("successBtn")
        h.addWidget(self.combo_all_items, 3); h.addWidget(self.btn_add_item_link, 1)
        self.list_assigned_items = QListWidget(); self.list_assigned_items.setAlternatingRowColors(True)
        self.btn_remove_item_link = QPushButton(tr("BTN_REMOVE")); self.btn_remove_item_link.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_TrashIcon)); self.btn_remove_item_link.setObjectName("dangerBtn")
        l_linked.addLayout(h); l_linked.addWidget(self.list_assigned_items); l_linked.addWidget(self.btn_remove_item_link)
        layout.addWidget(self.grp_db_items)
        self.inventory_container = self._create_section(tr("GRP_INVENTORY"))
        self.add_btn_to_section(self.inventory_container, tr("BTN_ADD"))
        layout.addWidget(self.inventory_container); layout.addStretch()

    def setup_docs_tab(self):
        layout = QVBoxLayout(self.tab_docs)
        self.grp_pdf = QGroupBox(tr("GRP_PDF")); v = QVBoxLayout(self.grp_pdf)
        h_btn = QHBoxLayout()
        self.btn_add_pdf = QPushButton(tr("BTN_ADD")); self.btn_add_pdf.setObjectName("successBtn")
        self.btn_open_pdf_folder = QPushButton(); self.btn_open_pdf_folder.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_DirIcon))
        h_btn.addWidget(self.btn_add_pdf, 3); h_btn.addWidget(self.btn_open_pdf_folder, 1)
        v.addLayout(h_btn)
        self.list_pdfs = QListWidget(); self.list_pdfs.setAlternatingRowColors(True)
        v.addWidget(self.list_pdfs)
        h_action = QHBoxLayout()
        self.btn_open_pdf = QPushButton(tr("BTN_OPEN_PDF")); self.btn_open_pdf.setObjectName("primaryBtn")
        self.btn_project_pdf = QPushButton(tr("BTN_PROJECT_PDF")); self.btn_project_pdf.setObjectName("actionBtn")
        self.btn_remove_pdf = QPushButton(tr("BTN_REMOVE")); self.btn_remove_pdf.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_TrashIcon)); self.btn_remove_pdf.setObjectName("dangerBtn")
        h_action.addWidget(self.btn_open_pdf); h_action.addWidget(self.btn_project_pdf); h_action.addWidget(self.btn_remove_pdf)
        v.addLayout(h_action); layout.addWidget(self.grp_pdf); layout.addStretch()

    # --- YARDIMCILAR ---
    def _create_section(self, title):
        group = QGroupBox(title); v = QVBoxLayout(group); group.dynamic_area = QVBoxLayout(); v.addLayout(group.dynamic_area); return group

    def add_btn_to_section(self, container, label):
        btn = QPushButton(label); btn.clicked.connect(lambda: self.add_feature_card(container)); btn.setObjectName("successBtn")
        container.layout().insertWidget(0, btn)

    def add_feature_card(self, group, name="", desc="", ph_title=None, ph_desc=None):
        if ph_title is None: ph_title = tr("LBL_TITLE_PH")
        if ph_desc is None: ph_desc = tr("LBL_DETAILS_PH")
        card = QFrame(); card.setProperty("class", "featureCard")
        l = QVBoxLayout(card); h = QHBoxLayout()
        t = QLineEdit(name); t.setPlaceholderText(ph_title); t.setStyleSheet("font-weight: bold; border:none; font-size: 14px; background: transparent;")
        btn = QPushButton(); btn.setFixedSize(24,24); btn.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_TitleBarCloseButton)); btn.setCursor(Qt.CursorShape.PointingHandCursor); btn.setToolTip(tr("BTN_REMOVE")); btn.setStyleSheet("background: transparent; border: none;")
        btn.clicked.connect(lambda: [group.dynamic_area.removeWidget(card), card.deleteLater()])
        h.addWidget(t); h.addWidget(btn); l.addLayout(h)
        d = QTextEdit(desc); d.setPlaceholderText(ph_desc); d.setMinimumHeight(80); d.setMaximumHeight(300); d.setStyleSheet("border:none; background: transparent;")
        l.addWidget(d); group.dynamic_area.addWidget(card); card.inp_title = t; card.inp_desc = d

    # --- DÜZELTİLMİŞ FONKSİYON ---
    def clear_all_cards(self):
        containers = [self.trait_container, self.action_container, self.reaction_container, self.legendary_container, self.inventory_container, self.custom_spell_container]
        for g in containers:
            while g.dynamic_area.count(): 
                c = g.dynamic_area.takeAt(0)
                if c.widget(): c.widget().deleteLater()
    
    def _on_type_index_changed(self, index):
        cat_key = self.inp_type.itemData(index)
        if cat_key: self.update_ui_by_type(cat_key)

    def update_ui_by_type(self, category_name):
        self.build_dynamic_form(category_name)
        is_npc_like = category_name in ["NPC", "Monster"]
        is_player = category_name == "Player"
        is_lore = category_name == "Lore"
        is_status = category_name == "Status Effect"
        
        self.lbl_location.setVisible(is_npc_like or is_player); self.combo_location.setVisible(is_npc_like or is_player)
        self.lbl_residents.setVisible(category_name == "Location"); self.list_residents.setVisible(category_name == "Location")
        
        self.tabs.setTabVisible(0, is_npc_like) # Stats
        self.tabs.setTabVisible(1, is_npc_like) # Spells
        self.tabs.setTabVisible(2, is_npc_like) # Actions
        self.tabs.setTabVisible(3, is_npc_like) # Inv
        self.tabs.setTabVisible(4, is_lore or is_player or is_status)
        
        if is_player:
            if self.grp_combat_stats.parent() == self.tab_stats:
                self.tab_stats.layout().removeWidget(self.grp_combat_stats); idx = self.content_layout.indexOf(self.tabs); self.content_layout.insertWidget(idx, self.grp_combat_stats)
            self.grp_combat_stats.setVisible(True)
        elif is_status:
            self.grp_combat_stats.setVisible(False)
        else:
            if self.grp_combat_stats.parent() != self.tab_stats:
                self.content_layout.removeWidget(self.grp_combat_stats); self.tab_stats.layout().insertWidget(1, self.grp_combat_stats)
            self.grp_combat_stats.setVisible(is_npc_like)
        
        if is_status: self.lbl_image.setText("Icon")

    def prepare_new_entity(self):
        self.inp_name.clear(); self.inp_desc.clear(); self.inp_tags.clear(); self.lbl_image.setPixmap(None)
        self.image_list = []; self.current_img_index = 0; self.lbl_img_counter.setText("0/0") 
        self.clear_all_cards(); self.inp_type.setCurrentIndex(0)
        for i in self.stats_inputs.values(): i.setText("10")
        self.inp_hp.clear(); self.inp_max_hp.clear(); self.inp_ac.clear(); self.list_assigned_spells.clear(); self.list_assigned_items.clear()
        self.inp_prof.clear(); self.inp_pp.clear(); self.inp_skills.clear(); self.inp_init.clear()
        self.inp_saves.clear(); self.inp_vuln.clear(); self.inp_resist.clear(); self.inp_dmg_immune.clear(); self.inp_cond_immune.clear()
        self.combo_location.clear(); self.list_residents.clear(); self.list_pdfs.clear()