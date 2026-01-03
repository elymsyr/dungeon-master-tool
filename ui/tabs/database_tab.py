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

        # --- SOL PANEL (Arama ve Liste) ---
        left_widget = QWidget()
        l_layout = QVBoxLayout(left_widget)
        l_layout.setContentsMargins(0,0,0,0)
        
        # Arama ve Filtre
        search_layout = QHBoxLayout()
        self.inp_search = QLineEdit()
        self.inp_search.setPlaceholderText("🔍 Ara (İsim/Tag)...")
        self.inp_search.textChanged.connect(self.refresh_list)
        
        self.combo_filter = QComboBox()
        self.combo_filter.addItems(["Tümü"] + list(ENTITY_SCHEMAS.keys()))
        self.combo_filter.currentTextChanged.connect(self.refresh_list)
        
        search_layout.addWidget(self.inp_search)
        search_layout.addWidget(self.combo_filter)
        
        # API Butonu
        self.btn_browser = QPushButton("📚 Kütüphaneyi Tara (API)")
        self.btn_browser.clicked.connect(self.open_api_browser)
        self.btn_browser.setStyleSheet("background-color: #6a1b9a; color: white; font-weight: bold;")

        # Liste
        self.list_widget = QListWidget()
        self.list_widget.itemClicked.connect(self.load_entity)
        
        # Ekle Butonu
        self.btn_add = QPushButton("+ Yeni Varlık")
        self.btn_add.setObjectName("successBtn")
        self.btn_add.clicked.connect(self.prepare_new)
        
        l_layout.addLayout(search_layout)
        l_layout.addWidget(self.btn_browser)
        l_layout.addWidget(self.list_widget)
        l_layout.addWidget(self.btn_add)

        # --- SAĞ PANEL (Karakter Kağıdı) ---
        self.sheet = NpcSheet()
        self.sheet.btn_save.clicked.connect(self.save_entity)
        self.sheet.btn_delete.clicked.connect(self.delete_entity)
        self.sheet.btn_select_img.clicked.connect(self.select_image)
        
        # Oyuncu Ekranı Butonları (Özelleştirme)
        self.sheet.btn_show_player.setText("👁️ Resmi Yansıt")
        self.sheet.btn_show_player.clicked.connect(self.show_image_to_player)
        
        # "Kartı Yansıt" Butonunu Elle Ekliyoruz (Resim altına)
        self.btn_show_stats = QPushButton("📄 Kartı Yansıt")
        self.btn_show_stats.setObjectName("primaryBtn")
        self.btn_show_stats.clicked.connect(self.show_stats_to_player)
        # NpcSheet -> content -> top -> img_layout içine ekle
        self.sheet.content_layout.itemAt(0).layout().itemAt(0).layout().insertWidget(3, self.btn_show_stats)

        # Büyü Butonları
        self.sheet.btn_add_spell.clicked.connect(self.add_spell_to_list)
        self.sheet.btn_remove_spell.clicked.connect(self.remove_spell_from_list)
        self.sheet.list_assigned_spells.itemDoubleClicked.connect(self.view_spell_details)
        
        # Eşya Butonları
        self.sheet.btn_add_item_link.clicked.connect(self.add_item_to_list)
        self.sheet.btn_remove_item_link.clicked.connect(self.remove_item_from_list)
        self.sheet.list_assigned_items.itemDoubleClicked.connect(self.view_item_details)

        splitter.addWidget(left_widget)
        splitter.addWidget(self.sheet)
        splitter.setSizes([350, 950])
        layout.addWidget(splitter)

    # --- LİSTELEME VE YÜKLEME ---
    def refresh_list(self):
        self.list_widget.clear()
        text = self.inp_search.text().lower()
        flt = self.combo_filter.currentText()
        
        for eid, data in self.dm.data["entities"].items():
            name = data.get("name", "").lower()
            etype = data.get("type", "")
            tags = [t.lower() for t in data.get("tags", [])]
            
            # Filtreleme
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
        
        # 1. Temel Bilgiler
        s.inp_name.setText(data.get("name", ""))
        curr_type = data.get("type", "NPC")
        idx = s.inp_type.findText(curr_type)
        s.inp_type.setCurrentIndex(idx if idx >= 0 else 0)
        s.inp_tags.setText(", ".join(data.get("tags", [])))
        s.inp_desc.setText(data.get("description", ""))
        
        # 2. İlişkiler (Konum / Sakinler)
        if s.combo_location.isVisible():
            s.combo_location.clear()
            s.combo_location.addItem("Seç...", None)
            for lid, ldata in self.dm.data["entities"].items():
                if ldata.get("type") == "Mekan":
                    s.combo_location.addItem(ldata["name"], lid)
            if data.get("location_id"): 
                ix = s.combo_location.findData(data.get("location_id"))
                if ix >= 0: s.combo_location.setCurrentIndex(ix)
        
        if s.list_residents.isVisible():
            s.list_residents.clear()
            for rid, rdata in self.dm.data["entities"].items():
                if rdata.get("location_id") == eid:
                    s.list_residents.addItem(f"{rdata['name']} ({rdata['type']})")

        # 3. Statlar & Combat
        stats = data.get("stats", {})
        for k, v in s.stats_inputs.items(): v.setText(str(stats.get(k, 10)))
        
        c = data.get("combat_stats", {})
        s.inp_hp.setText(str(c.get("hp", "")))
        s.inp_ac.setText(str(c.get("ac", "")))
        s.inp_speed.setText(str(c.get("speed", "")))
        s.inp_cr.setText(str(c.get("cr", "")))
        
        # 4. Dinamik Alanlar
        attrs = data.get("attributes", {})
        for l, w in s.dynamic_inputs.items():
            val = attrs.get(l, "")
            if isinstance(w, QComboBox): 
                ix = w.findText(val)
                if ix >= 0: w.setCurrentIndex(ix)
                else: w.setCurrentText(val)
            else: w.setText(val)

        # 5. Tüm Kart Listeleri
        s.clear_all_cards()
        self._fill_cards(s.trait_container, data.get("traits", []))
        self._fill_cards(s.action_container, data.get("actions", []))
        self._fill_cards(s.reaction_container, data.get("reactions", []))
        self._fill_cards(s.legendary_container, data.get("legendary_actions", []))
        self._fill_cards(s.inventory_container, data.get("inventory", []))
        self._fill_cards(s.custom_spell_container, data.get("custom_spells", []))

        # 6. Bağlı Büyüler ve Eşyalar
        s.combo_all_spells.clear()
        s.combo_all_items.clear()
        
        for id_, d_ in self.dm.data["entities"].items():
            t_ = d_.get("type", "")
            if "Büyü" in t_: s.combo_all_spells.addItem(d_["name"], id_)
            elif "Eşya" in t_: s.combo_all_items.addItem(d_["name"], id_)

        s.list_assigned_spells.clear()
        for sid in data.get("spells", []):
            sd = self.dm.data["entities"].get(sid)
            if sd: 
                li = QListWidgetItem(f"{sd['name']} (Lv {sd['attributes'].get('Seviye','?')})")
                li.setData(Qt.ItemDataRole.UserRole, sid)
                s.list_assigned_spells.addItem(li)

        s.list_assigned_items.clear()
        for iid in data.get("equipment_ids", []):
            ed = self.dm.data["entities"].get(iid)
            if ed:
                li = QListWidgetItem(f"{ed['name']}")
                li.setData(Qt.ItemDataRole.UserRole, iid)
                s.list_assigned_items.addItem(li)

        # 7. Resim
        img_rel = data.get("image_path", "")
        p = self.dm.get_full_path(img_rel)
        if p and os.path.exists(p):
            s.lbl_image.setPixmap(QPixmap(p))
        else:
            s.lbl_image.setPixmap(None)

    def _fill_cards(self, container, data_list):
        for item in data_list:
            self.sheet.add_feature_card(container, item.get("name"), item.get("desc"))

    # --- KAYDETME ---
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

        # ID Listeleri
        spell_ids = [s.list_assigned_spells.item(i).data(Qt.ItemDataRole.UserRole) for i in range(s.list_assigned_spells.count())]
        item_ids = [s.list_assigned_items.item(i).data(Qt.ItemDataRole.UserRole) for i in range(s.list_assigned_items.count())]
        
        loc_id = None
        if s.combo_location.isVisible():
            loc_id = s.combo_location.currentData()
        
        attr_data = {}
        for l, w in s.dynamic_inputs.items():
            if isinstance(w, QComboBox): attr_data[l] = w.currentText()
            else: attr_data[l] = w.text()

        # Mevcut veriyi koru (özellikle image path)
        current_data = self.dm.data["entities"].get(self.current_entity_id, {})
        
        data = {
            "name": s.inp_name.text(),
            "type": s.inp_type.currentText(),
            "tags": [t.strip() for t in s.inp_tags.text().split(",") if t.strip()],
            "description": s.inp_desc.toPlainText(),
            "image_path": current_data.get("image_path", ""),
            "stats": {k: int(v.text() or 10) for k, v in s.stats_inputs.items()},
            "combat_stats": {
                "hp": s.inp_hp.text(), "ac": s.inp_ac.text(),
                "speed": s.inp_speed.text(), "cr": s.inp_cr.text()
            },
            "attributes": attr_data,
            "location_id": loc_id,
            "spells": spell_ids,
            "equipment_ids": item_ids,
            
            # Listeler
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

    # --- YARDIMCI İŞLEVLER ---
    def prepare_new(self):
        self.current_entity_id = None
        self.sheet.prepare_new_entity()

    def delete_entity(self):
        if self.current_entity_id:
             self.dm.delete_entity(self.current_entity_id)
             self.refresh_list()
             self.prepare_new()

    def select_image(self):
        fname, _ = QFileDialog.getOpenFileName(self, "Resim", "", "Images (*.png *.jpg)")
        if fname:
            rel = self.dm.import_image(fname)
            if self.current_entity_id: 
                self.dm.save_entity(self.current_entity_id, {"image_path": rel})
                full_path = self.dm.get_full_path(rel)
                self.sheet.lbl_image.setPixmap(QPixmap(full_path))
            else:
                QMessageBox.information(self, "Bilgi", "Lütfen önce kaydedin.")

    def open_api_browser(self):
        cat = self.combo_filter.currentText()
        if cat == "Tümü": 
            QMessageBox.warning(self, "Uyarı", "Lütfen önce taranacak kategoriyi seçin (Örn: Büyü).")
            return
        browser = ApiBrowser(self.dm, cat, self)
        if browser.exec(): self.refresh_list()

    # --- BÜYÜ & EŞYA YÖNETİMİ ---
    def add_spell_to_list(self):
        sid = self.sheet.combo_all_spells.currentData()
        txt = self.sheet.combo_all_spells.currentText()
        if not sid: return
        for i in range(self.sheet.list_assigned_spells.count()):
            if self.sheet.list_assigned_spells.item(i).data(Qt.ItemDataRole.UserRole) == sid: return
        li = QListWidgetItem(txt); li.setData(Qt.ItemDataRole.UserRole, sid)
        self.sheet.list_assigned_spells.addItem(li)

    def remove_spell_from_list(self): 
        r = self.sheet.list_assigned_spells.currentRow()
        if r>=0: self.sheet.list_assigned_spells.takeItem(r)

    def view_spell_details(self, item): 
        self.load_entity_by_id(item.data(Qt.ItemDataRole.UserRole))

    def add_item_to_list(self):
        iid = self.sheet.combo_all_items.currentData()
        txt = self.sheet.combo_all_items.currentText()
        if not iid: return
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
                self.list_widget.setCurrentRow(i)
                self.load_entity(self.list_widget.item(i))
                return

    # --- OYUNCU EKRANI GÖSTERİMİ ---
    def show_image_to_player(self):
        if not self.player_window.isVisible():
            QMessageBox.warning(self, "Uyarı", "Oyuncu ekranı kapalı.")
            return
        if self.current_entity_id:
            data = self.dm.data["entities"].get(self.current_entity_id, {})
            path = self.dm.get_full_path(data.get("image_path", ""))
            if path and os.path.exists(path):
                self.player_window.show_image(QPixmap(path))
            else:
                self.player_window.show_image(None)

    def show_stats_to_player(self):
        if not self.player_window.isVisible():
            QMessageBox.warning(self, "Uyarı", "Oyuncu ekranı kapalı.")
            return
        if not self.current_entity_id: return

        data = self.dm.data["entities"].get(self.current_entity_id, {})
        
        name = data.get("name", "Bilinmeyen")
        desc = data.get("description", "")
        type_ = data.get("type", "NPC")
        tags = ", ".join(data.get("tags", []))
        
        # HTML Kart Tasarımı
        html = f"""
        <div style='font-family: Georgia, serif; color: #e0e0e0; padding: 10px;'>
            <h1 style='color: #ffb74d; border-bottom: 2px solid #ffb74d; margin-bottom: 5px;'>{name}</h1>
            <p style='color: #bbb; font-style: italic; margin-top: 0;'>{type_} <span style='font-size:0.8em;'>({tags})</span></p>
        """

        # KOŞULLU STAT GÖSTERİMİ (Sadece canlılar için)
        if type_ in ["NPC", "Canavar", "Oyuncu"]:
            c = data.get("combat_stats", {})
            hp = c.get("hp", "-"); ac = c.get("ac", "-"); speed = c.get("speed", "-")
            stats = data.get("stats", {})
            
            html += f"""
            <hr style='border: 0; border-top: 1px solid #444;'>
            <div style='display: flex; justify-content: space-around; font-weight: bold; font-size: 1.1em; color: #fff;'>
                <span>🛡️ AC: {ac}</span>
                <span>❤️ HP: {hp}</span>
                <span>🦶 Hız: {speed}</span>
            </div>
            <hr style='border: 0; border-top: 1px solid #444;'>
            
            <table style='width:100%; text-align:center; color: #ccc; font-size: 0.9em;'>
                <tr style='color: #ffb74d;'><th>STR</th><th>DEX</th><th>CON</th><th>INT</th><th>WIS</th><th>CHA</th></tr>
                <tr>
                    <td>{stats.get("STR",10)}</td><td>{stats.get("DEX",10)}</td><td>{stats.get("CON",10)}</td>
                    <td>{stats.get("INT",10)}</td><td>{stats.get("WIS",10)}</td><td>{stats.get("CHA",10)}</td>
                </tr>
            </table>
            <hr style='border: 0; border-top: 1px solid #444;'>
            """
        
        # DİNAMİK ÖZELLİKLER (Attributes)
        attributes = data.get("attributes", {})
        if attributes:
            html += "<div style='background-color: #222; padding: 10px; border-radius: 5px; margin-bottom: 15px; border-left: 3px solid #7c4dff;'>"
            for key, val in attributes.items():
                if val: html += f"<p style='margin: 2px 0;'><b>{key}:</b> {val}</p>"
            html += "</div>"

        # AÇIKLAMA
        if desc:
            formatted_desc = desc.replace("\n", "<br>")
            html += f"<p style='line-height: 1.5;'>{formatted_desc}</p>"

        # LİSTELER
        if data.get("traits"):
            html += "<h3 style='color: #ffb74d; border-bottom: 1px solid #444; padding-bottom: 5px;'>Özellikler</h3>"
            for t in data.get("traits", []):
                html += f"<p style='margin-bottom: 10px;'><strong style='color: #fff;'>{t['name']}.</strong> {t['desc']}</p>"
            
        if data.get("actions"):
            html += "<h3 style='color: #d32f2f; border-bottom: 1px solid #444; padding-bottom: 5px;'>Aksiyonlar</h3>"
            for a in data.get("actions", []):
                html += f"<p style='margin-bottom: 10px;'><strong style='color: #fff;'>{a['name']}.</strong> {a['desc']}</p>"
        
        if data.get("reactions"):
            html += "<h3 style='color: #ffca28; border-bottom: 1px solid #444; padding-bottom: 5px;'>Reaksiyonlar</h3>"
            for r in data.get("reactions", []):
                html += f"<p style='margin-bottom: 10px;'><strong style='color: #fff;'>{r['name']}.</strong> {r['desc']}</p>"

        if data.get("legendary_actions"):
            html += "<h3 style='color: #7c4dff; border-bottom: 1px solid #444; padding-bottom: 5px;'>Efsanevi Aksiyonlar</h3>"
            for l in data.get("legendary_actions", []):
                html += f"<p style='margin-bottom: 10px;'><strong style='color: #fff;'>{l['name']}.</strong> {l['desc']}</p>"

        html += "</div>"
        
        self.player_window.show_stat_block(html)