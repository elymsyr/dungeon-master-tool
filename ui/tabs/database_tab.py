import os
from PyQt6.QtWidgets import (QWidget, QHBoxLayout, QVBoxLayout, QListWidget, 
                             QPushButton, QLineEdit, QComboBox, QSplitter, 
                             QMessageBox, QListWidgetItem, QFileDialog)
from PyQt6.QtGui import QPixmap
from PyQt6.QtCore import Qt
from ui.widgets.npc_sheet import NpcSheet
from ui.dialogs.api_browser import ApiBrowser
from core.models import ENTITY_SCHEMAS

class DatabaseTab(QWidget):
    def __init__(self, data_manager, player_window):
        super().__init__()
        self.dm = data_manager
        self.player_window = player_window
        self.current_entity_id = None
        self.init_ui()

    def init_ui(self):
        layout = QHBoxLayout(self)
        splitter = QSplitter(Qt.Orientation.Horizontal)

        # --- SOL PANEL ---
        left_widget = QWidget()
        l_layout = QVBoxLayout(left_widget)
        l_layout.setContentsMargins(0,0,0,0)
        
        search_layout = QHBoxLayout()
        self.inp_search = QLineEdit()
        self.inp_search.setPlaceholderText("🔍 Yerel Ara...")
        self.inp_search.textChanged.connect(self.refresh_list)
        
        self.combo_filter = QComboBox()
        self.combo_filter.addItems(["Tümü"] + list(ENTITY_SCHEMAS.keys()))
        self.combo_filter.currentTextChanged.connect(self.refresh_list)
        
        search_layout.addWidget(self.inp_search)
        search_layout.addWidget(self.combo_filter)
        
        self.btn_browser = QPushButton("📚 Kütüphaneyi Tara (API)")
        self.btn_browser.clicked.connect(self.open_api_browser)
        self.btn_browser.setStyleSheet("background-color: #6a1b9a; color: white; font-weight: bold;")

        self.list_widget = QListWidget()
        self.list_widget.itemClicked.connect(self.load_entity)
        
        self.btn_add = QPushButton("+ Yeni Varlık")
        self.btn_add.setObjectName("successBtn")
        self.btn_add.clicked.connect(self.prepare_new)
        
        l_layout.addLayout(search_layout)
        l_layout.addWidget(self.btn_browser)
        l_layout.addWidget(self.list_widget)
        l_layout.addWidget(self.btn_add)

        # --- SAĞ PANEL ---
        self.sheet = NpcSheet()
        self.sheet.btn_save.clicked.connect(self.save_entity)
        self.sheet.btn_delete.clicked.connect(self.delete_entity)
        self.sheet.btn_select_img.clicked.connect(self.select_image)
        self.sheet.btn_show_player.clicked.connect(self.show_to_player)

        splitter.addWidget(left_widget)
        splitter.addWidget(self.sheet)
        splitter.setSizes([350, 950])
        layout.addWidget(splitter)

    def refresh_list(self):
        self.list_widget.clear()
        text = self.inp_search.text().lower()
        flt = self.combo_filter.currentText()
        for eid, data in self.dm.data["entities"].items():
            name = data.get("name", "").lower()
            etype = data.get("type", "")
            tags = [t.lower() for t in data.get("tags", [])]
            if flt != "Tümü" and etype != flt: continue
            match = False
            if text in name: match = True
            else:
                for t in tags:
                    if text in t: match = True; break
            if match:
                item = QListWidgetItem(f"{data['name']} ({etype})")
                item.setData(Qt.ItemDataRole.UserRole, eid)
                self.list_widget.addItem(item)

    def load_entity(self, item):
        eid = item.data(Qt.ItemDataRole.UserRole)
        data = self.dm.data["entities"].get(eid)
        if not data: return
        self.current_entity_id = eid
        s = self.sheet
        
        # Temel Bilgiler
        s.inp_name.setText(data.get("name", ""))
        curr_type = data.get("type", "NPC")
        idx = s.inp_type.findText(curr_type)
        if idx >= 0: s.inp_type.setCurrentIndex(idx)
        else: s.inp_type.setCurrentIndex(0)
        
        s.inp_tags.setText(", ".join(data.get("tags", [])))
        s.inp_desc.setText(data.get("description", ""))
        
        # --- İLİŞKİLER MANTIĞI ---
        # 1. Eğer bir NPC/Canavar ise: Konum Listesini Doldur
        if curr_type in ["NPC", "Canavar", "Oyuncu"]:
            s.combo_location.clear()
            s.combo_location.addItem("Bir mekan seçin...", None)
            
            # Tüm mekanları bul
            locations = []
            for loc_id, loc_data in self.dm.data["entities"].items():
                if loc_data.get("type") == "Mekan":
                    locations.append((loc_data["name"], loc_id))
            
            # Combo'ya ekle
            for name, loc_id in locations:
                s.combo_location.addItem(name, loc_id)
            
            # Kayıtlı konumu seç
            saved_loc_id = data.get("location_id")
            if saved_loc_id:
                # ComboBox'ta data ile arama yap
                index = s.combo_location.findData(saved_loc_id)
                if index >= 0:
                    s.combo_location.setCurrentIndex(index)

        # 2. Eğer bir Mekan ise: Sakinleri (Residents) Doldur
        elif curr_type == "Mekan":
            s.list_residents.clear()
            # Tüm varlıkları tara, location_id'si bu mekan olanları bul
            for res_id, res_data in self.dm.data["entities"].items():
                if res_data.get("location_id") == eid:
                    res_item = QListWidgetItem(f"{res_data['name']} ({res_data['type']})")
                    s.list_residents.addItem(res_item)
            
            if s.list_residents.count() == 0:
                s.list_residents.addItem(QListWidgetItem("(Kimse yok)"))

        # Statlar & Combat
        stats = data.get("stats", {})
        for k, v in s.stats_inputs.items(): v.setText(str(stats.get(k, 10)))
        c = data.get("combat_stats", {})
        s.inp_hp.setText(str(c.get("hp", ""))); s.inp_ac.setText(str(c.get("ac", "")))
        s.inp_speed.setText(str(c.get("speed", ""))); s.inp_cr.setText(str(c.get("cr", "")))
        
        # Dinamik Alanlar
        attributes = data.get("attributes", {})
        for label, widget in s.dynamic_inputs.items():
            val = attributes.get(label, "")
            if isinstance(widget, QComboBox):
                idx = widget.findText(val)
                if idx >= 0: widget.setCurrentIndex(idx)
                else: widget.setCurrentText(val)
            else: widget.setText(val)
        
        # Kartlar (Traits / Actions)
        # ÖNEMLİ: Manuel eklenen kartları geri yüklemek için
        s.clear_features()
        for t in data.get("traits", []): s.add_feature_card(s.trait_container, t.get("name"), t.get("desc"))
        for a in data.get("actions", []): s.add_feature_card(s.action_container, a.get("name"), a.get("desc"))
        
        # Resim
        img_rel = data.get("image_path", "")
        if img_rel:
            full_path = self.dm.get_full_path(img_rel)
            if full_path and os.path.exists(full_path): s.lbl_image.setPixmap(QPixmap(full_path))
            else: s.lbl_image.setPixmap(None)
        else: s.lbl_image.setPixmap(None)

    def save_entity(self):
        s = self.sheet
        if not s.inp_name.text(): return

        attr_data = {}
        for label, widget in s.dynamic_inputs.items():
            if isinstance(widget, QComboBox): attr_data[label] = widget.currentText()
            else: attr_data[label] = widget.text()

        stats = {k: int(v.text() or 10) for k, v in s.stats_inputs.items()}
        combat = {"hp": s.inp_hp.text(), "ac": s.inp_ac.text(), "speed": s.inp_speed.text(), "cr": s.inp_cr.text()}
        
        # --- KARTLARI UI'DAN GERİ OKUMA (YENİ) ---
        # Kullanıcının manuel eklediği veya API'den gelip düzenlediği kartları kaydedelim.
        traits_list = []
        layout = s.trait_container.dynamic_area
        for i in range(layout.count()):
            widget = layout.itemAt(i).widget()
            if widget:
                traits_list.append({
                    "name": widget.inp_title.text(),
                    "desc": widget.inp_desc.toPlainText()
                })

        actions_list = []
        layout = s.action_container.dynamic_area
        for i in range(layout.count()):
            widget = layout.itemAt(i).widget()
            if widget:
                actions_list.append({
                    "name": widget.inp_title.text(),
                    "desc": widget.inp_desc.toPlainText()
                })

        # --- KONUM VERİSİNİ AL ---
        location_id = None
        if s.inp_type.currentText() in ["NPC", "Canavar", "Oyuncu"]:
            location_id = s.combo_location.currentData() # ID'yi al

        current_data = self.dm.data["entities"].get(self.current_entity_id, {})
        data = {
            "name": s.inp_name.text(), 
            "type": s.inp_type.currentText(),
            "tags": [t.strip() for t in s.inp_tags.text().split(",") if t.strip()],
            "description": s.inp_desc.toPlainText(),
            "image_path": current_data.get("image_path", ""),
            "stats": stats, 
            "combat_stats": combat, 
            "attributes": attr_data,
            "traits": traits_list,  # UI'dan okunan liste
            "actions": actions_list, # UI'dan okunan liste
            "location_id": location_id # <-- YENİ KAYIT
        }
        
        new_id = self.dm.save_entity(self.current_entity_id, data)
        self.current_entity_id = new_id
        self.refresh_list()
        
        # Eğer bu bir Mekan ise, içerideki NPC'leri güncellemek için load_entity tekrar çağrılabilir
        # Ama şu anlık gerek yok.
        QMessageBox.information(self, "Bilgi", "Kaydedildi.")

    def load_entity_by_id(self, entity_id):
        """Haritadan veya başka yerden çağrıldığında"""
        for i in range(self.list_widget.count()):
            item = self.list_widget.item(i)
            if item.data(Qt.ItemDataRole.UserRole) == entity_id:
                self.list_widget.setCurrentRow(i)
                self.load_entity(item)
                return

    # ... (Diğer fonksiyonlar: prepare_new, delete_entity, select_image, show_to_player, open_api_browser aynen kalıyor) ...
    def prepare_new(self):
        self.current_entity_id = None
        self.sheet.prepare_new_entity()

    def delete_entity(self):
        if self.current_entity_id:
             self.dm.delete_entity(self.current_entity_id)
             self.refresh_list(); self.prepare_new()

    def select_image(self):
        fname, _ = QFileDialog.getOpenFileName(self, "Resim", "", "Images (*.png *.jpg)")
        if fname:
            rel = self.dm.import_image(fname)
            if self.current_entity_id:
                self.dm.save_entity(self.current_entity_id, {"image_path": rel})
                full_path = self.dm.get_full_path(rel)
                self.sheet.lbl_image.setPixmap(QPixmap(full_path))
            else: QMessageBox.information(self, "Bilgi", "Lütfen önce kaydedin.")

    def show_to_player(self):
        if self.current_entity_id:
            data = self.dm.data["entities"].get(self.current_entity_id, {})
            path = self.dm.get_full_path(data.get("image_path", ""))
            if path and os.path.exists(path): self.player_window.show_image(QPixmap(path))
            else: self.player_window.show_image(None)

    def open_api_browser(self):
        category = self.combo_filter.currentText()
        if category == "Tümü":
            QMessageBox.warning(self, "Uyarı", "Lütfen önce taranacak kategoriyi seçin.")
            return
        browser = ApiBrowser(self.dm, category, self)
        if browser.exec(): self.refresh_list()