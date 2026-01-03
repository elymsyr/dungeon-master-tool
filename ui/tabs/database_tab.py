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

        # SOL PANEL
        left_widget = QWidget(); l_layout = QVBoxLayout(left_widget); l_layout.setContentsMargins(0,0,0,0)
        s_layout = QHBoxLayout()
        self.inp_search = QLineEdit(); self.inp_search.setPlaceholderText("🔍 Ara...")
        self.inp_search.textChanged.connect(self.refresh_list)
        self.combo_filter = QComboBox(); self.combo_filter.addItems(["Tümü"] + list(ENTITY_SCHEMAS.keys()))
        self.combo_filter.currentTextChanged.connect(self.refresh_list)
        s_layout.addWidget(self.inp_search); s_layout.addWidget(self.combo_filter)
        self.btn_browser = QPushButton("📚 Kütüphane (API)"); self.btn_browser.clicked.connect(self.open_api_browser)
        self.list_widget = QListWidget(); self.list_widget.itemClicked.connect(self.load_entity)
        self.btn_add = QPushButton("+ Yeni Varlık"); self.btn_add.setObjectName("successBtn"); self.btn_add.clicked.connect(self.prepare_new)
        l_layout.addLayout(s_layout); l_layout.addWidget(self.btn_browser); l_layout.addWidget(self.list_widget); l_layout.addWidget(self.btn_add)

        # SAĞ PANEL
        self.sheet = NpcSheet()
        self.sheet.btn_save.clicked.connect(self.save_entity)
        self.sheet.btn_delete.clicked.connect(self.delete_entity)
        self.sheet.btn_select_img.clicked.connect(self.select_image)
        self.sheet.btn_show_player.clicked.connect(self.show_to_player)
        
        # Büyü Butonları
        self.sheet.btn_add_spell.clicked.connect(self.add_spell_to_list)
        self.sheet.btn_remove_spell.clicked.connect(self.remove_spell_from_list)
        self.sheet.list_assigned_spells.itemDoubleClicked.connect(self.view_spell_details)
        
        # Eşya Butonları (YENİ)
        self.sheet.btn_add_item_link.clicked.connect(self.add_item_to_list)
        self.sheet.btn_remove_item_link.clicked.connect(self.remove_item_from_list)
        self.sheet.list_assigned_items.itemDoubleClicked.connect(self.view_item_details)

        splitter.addWidget(left_widget); splitter.addWidget(self.sheet); splitter.setSizes([350, 950])
        layout.addWidget(splitter)

    # ... (refresh_list aynen) ...
    def refresh_list(self):
        self.list_widget.clear()
        text = self.inp_search.text().lower(); flt = self.combo_filter.currentText()
        for eid, data in self.dm.data["entities"].items():
            name = data.get("name", "").lower(); etype = data.get("type", "")
            if flt != "Tümü" and etype != flt: continue
            if text in name or any(text in t.lower() for t in data.get("tags", [])):
                item = QListWidgetItem(f"{data['name']} ({etype})")
                item.setData(Qt.ItemDataRole.UserRole, eid)
                self.list_widget.addItem(item)

    def load_entity(self, item):
        eid = item.data(Qt.ItemDataRole.UserRole)
        data = self.dm.data["entities"].get(eid)
        if not data: return
        self.current_entity_id = eid
        s = self.sheet
        
        # Temel
        s.inp_name.setText(data.get("name", ""))
        curr_type = data.get("type", "NPC")
        idx = s.inp_type.findText(curr_type)
        s.inp_type.setCurrentIndex(idx if idx >= 0 else 0)
        s.inp_tags.setText(", ".join(data.get("tags", [])))
        s.inp_desc.setText(data.get("description", ""))
        
        # İlişkiler
        if s.combo_location.isVisible():
            s.combo_location.clear(); s.combo_location.addItem("Seç...", None)
            for lid, ldata in self.dm.data["entities"].items():
                if ldata.get("type") == "Mekan": s.combo_location.addItem(ldata["name"], lid)
            if data.get("location_id"): 
                ix = s.combo_location.findData(data.get("location_id"))
                if ix >= 0: s.combo_location.setCurrentIndex(ix)
        if s.list_residents.isVisible():
            s.list_residents.clear()
            for rid, rdata in self.dm.data["entities"].items():
                if rdata.get("location_id") == eid: s.list_residents.addItem(f"{rdata['name']} ({rdata['type']})")

        # Statlar & Attributes
        stats = data.get("stats", {})
        for k, v in s.stats_inputs.items(): v.setText(str(stats.get(k, 10)))
        c = data.get("combat_stats", {})
        s.inp_hp.setText(str(c.get("hp", ""))); s.inp_ac.setText(str(c.get("ac", "")))
        s.inp_speed.setText(str(c.get("speed", ""))); s.inp_cr.setText(str(c.get("cr", "")))
        
        attrs = data.get("attributes", {})
        for l, w in s.dynamic_inputs.items():
            if isinstance(w, QComboBox): 
                ix = w.findText(attrs.get(l,"")); w.setCurrentIndex(ix) if ix>=0 else w.setCurrentText(attrs.get(l,""))
            else: w.setText(attrs.get(l,""))

        # --- TÜM KARTLARI YÜKLE ---
        s.clear_all_cards()
        self._fill_cards(s.trait_container, data.get("traits", []))
        self._fill_cards(s.action_container, data.get("actions", []))
        self._fill_cards(s.reaction_container, data.get("reactions", []))
        self._fill_cards(s.legendary_container, data.get("legendary_actions", []))
        self._fill_cards(s.inventory_container, data.get("inventory", [])) # Manuel Eşyalar
        self._fill_cards(s.custom_spell_container, data.get("custom_spells", []))

        # --- LINKED SPELLS & ITEMS ---
        s.combo_all_spells.clear()
        s.combo_all_items.clear()
        
        for entity_id, entity_data in self.dm.data["entities"].items():
            e_type = entity_data.get("type", "")
            # Büyüleri Doldur
            if "Büyü" in e_type: 
                s.combo_all_spells.addItem(entity_data["name"], entity_id)
            # Eşyaları Doldur
            elif "Eşya" in e_type:
                s.combo_all_items.addItem(entity_data["name"], entity_id)

        # Atanmış Büyüleri Listele
        s.list_assigned_spells.clear()
        for sid in data.get("spells", []):
            sd = self.dm.data["entities"].get(sid)
            if sd: 
                li = QListWidgetItem(f"{sd['name']} (Lv {sd['attributes'].get('Seviye','?')})")
                li.setData(Qt.ItemDataRole.UserRole, sid)
                s.list_assigned_spells.addItem(li)

        # Atanmış Eşyaları Listele (YENİ)
        s.list_assigned_items.clear()
        for iid in data.get("equipment_ids", []):
            ed = self.dm.data["entities"].get(iid)
            if ed:
                li = QListWidgetItem(f"{ed['name']} ({ed['attributes'].get('Eşya Tipi', 'Item')})")
                li.setData(Qt.ItemDataRole.UserRole, iid)
                s.list_assigned_items.addItem(li)

        # Resim
        img_rel = data.get("image_path", "")
        p = self.dm.get_full_path(img_rel)
        if p and os.path.exists(p): s.lbl_image.setPixmap(QPixmap(p))
        else: s.lbl_image.setPixmap(None)

    def _fill_cards(self, container, data_list):
        for item in data_list:
            self.sheet.add_feature_card(container, item.get("name"), item.get("desc"))

    def save_entity(self):
        s = self.sheet
        if not s.inp_name.text(): return
        
        # Kartları Geri Oku
        def get_cards(container):
            res = []
            layout = container.dynamic_area
            for i in range(layout.count()):
                w = layout.itemAt(i).widget()
                if w: res.append({"name": w.inp_title.text(), "desc": w.inp_desc.toPlainText()})
            return res

        spell_ids = [s.list_assigned_spells.item(i).data(Qt.ItemDataRole.UserRole) for i in range(s.list_assigned_spells.count())]
        item_ids = [s.list_assigned_items.item(i).data(Qt.ItemDataRole.UserRole) for i in range(s.list_assigned_items.count())] # YENİ
        loc_id = s.combo_location.currentData() if s.combo_location.isVisible() else None
        
        attr_data = {}
        for l, w in s.dynamic_inputs.items(): attr_data[l] = w.currentText() if isinstance(w, QComboBox) else w.text()

        current_data = self.dm.data["entities"].get(self.current_entity_id, {})
        data = {
            "name": s.inp_name.text(), "type": s.inp_type.currentText(),
            "tags": [t.strip() for t in s.inp_tags.text().split(",") if t.strip()],
            "description": s.inp_desc.toPlainText(),
            "image_path": current_data.get("image_path", ""),
            "stats": {k: int(v.text() or 10) for k, v in s.stats_inputs.items()},
            "combat_stats": {"hp": s.inp_hp.text(), "ac": s.inp_ac.text(), "speed": s.inp_speed.text(), "cr": s.inp_cr.text()},
            "attributes": attr_data,
            "location_id": loc_id,
            "spells": spell_ids,
            "equipment_ids": item_ids, # YENİ
            
            # LİSTELER
            "traits": get_cards(s.trait_container),
            "actions": get_cards(s.action_container),
            "reactions": get_cards(s.reaction_container),
            "legendary_actions": get_cards(s.legendary_container),
            "inventory": get_cards(s.inventory_container),
            "custom_spells": get_cards(s.custom_spell_container)
        }
        
        new_id = self.dm.save_entity(self.current_entity_id, data)
        self.current_entity_id = new_id
        self.refresh_list()
        QMessageBox.information(self, "Bilgi", "Kaydedildi.")

    # --- BÜYÜ İŞLEMLERİ ---
    def add_spell_to_list(self):
        sid = self.sheet.combo_all_spells.currentData(); txt = self.sheet.combo_all_spells.currentText()
        if not sid: return
        for i in range(self.sheet.list_assigned_spells.count()):
            if self.sheet.list_assigned_spells.item(i).data(Qt.ItemDataRole.UserRole) == sid: return
        li = QListWidgetItem(txt); li.setData(Qt.ItemDataRole.UserRole, sid)
        self.sheet.list_assigned_spells.addItem(li)
    def remove_spell_from_list(self): 
        r = self.sheet.list_assigned_spells.currentRow()
        if r>=0: self.sheet.list_assigned_spells.takeItem(r)
    def view_spell_details(self, item): self.load_entity_by_id(item.data(Qt.ItemDataRole.UserRole))

    # --- EŞYA İŞLEMLERİ (YENİ) ---
    def add_item_to_list(self):
        iid = self.sheet.combo_all_items.currentData(); txt = self.sheet.combo_all_items.currentText()
        if not iid: return
        # Zaten ekli mi kontrolü
        for i in range(self.sheet.list_assigned_items.count()):
            if self.sheet.list_assigned_items.item(i).data(Qt.ItemDataRole.UserRole) == iid: return
        li = QListWidgetItem(txt); li.setData(Qt.ItemDataRole.UserRole, iid)
        self.sheet.list_assigned_items.addItem(li)

    def remove_item_from_list(self): 
        r = self.sheet.list_assigned_items.currentRow()
        if r>=0: self.sheet.list_assigned_items.takeItem(r)

    def view_item_details(self, item): 
        self.load_entity_by_id(item.data(Qt.ItemDataRole.UserRole))

    def load_entity_by_id(self, eid):
        for i in range(self.list_widget.count()):
            if self.list_widget.item(i).data(Qt.ItemDataRole.UserRole) == eid:
                self.list_widget.setCurrentRow(i); self.load_entity(self.list_widget.item(i)); return

    # ... (prepare_new, delete, select_image, show_to_player, open_api_browser aynen) ...
    def prepare_new(self): self.current_entity_id = None; self.sheet.prepare_new_entity()
    def delete_entity(self): 
        if self.current_entity_id: self.dm.delete_entity(self.current_entity_id); self.refresh_list(); self.prepare_new()
    def select_image(self):
        fname, _ = QFileDialog.getOpenFileName(self, "Resim", "", "Images (*.png *.jpg)")
        if fname:
            rel = self.dm.import_image(fname)
            if self.current_entity_id: 
                self.dm.save_entity(self.current_entity_id, {"image_path": rel})
                self.sheet.lbl_image.setPixmap(QPixmap(self.dm.get_full_path(rel)))
            else: QMessageBox.information(self, "Bilgi", "Kaydetmeden resim eklenemez.")
    def show_to_player(self):
        if self.current_entity_id:
            d = self.dm.data["entities"].get(self.current_entity_id, {})
            p = self.dm.get_full_path(d.get("image_path", ""))
            self.player_window.show_image(QPixmap(p) if p else None)
    def open_api_browser(self):
        cat = self.combo_filter.currentText()
        if cat == "Tümü": return QMessageBox.warning(self, "Uyarı", "Kategori seç.")
        if ApiBrowser(self.dm, cat, self).exec(): self.refresh_list()