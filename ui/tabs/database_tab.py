import os
from PyQt6.QtWidgets import (QWidget, QHBoxLayout, QVBoxLayout, QListWidget, 
                             QPushButton, QLineEdit, QComboBox, QSplitter, 
                             QMessageBox, QListWidgetItem, QFileDialog, QApplication, QCheckBox)
from PyQt6.QtGui import QPixmap, QColor, QBrush
from PyQt6.QtCore import Qt
from ui.widgets.npc_sheet import NpcSheet
from ui.dialogs.api_browser import ApiBrowser
from ui.dialogs.bulk_downloader import BulkDownloadDialog
from ui.workers import ApiSearchWorker
from core.models import ENTITY_SCHEMAS
from core.locales import tr

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
        left_widget = QWidget(); l_layout = QVBoxLayout(left_widget); l_layout.setContentsMargins(0,0,0,0)
        
        search_layout = QHBoxLayout()
        self.inp_search = QLineEdit()
        self.inp_search.setPlaceholderText(tr("LBL_SEARCH"))
        self.inp_search.textChanged.connect(self.refresh_list)
        
        self.combo_filter = QComboBox()
        self.combo_filter.addItems([tr("CAT_ALL")] + list(ENTITY_SCHEMAS.keys()))
        self.combo_filter.currentTextChanged.connect(self.refresh_list)
        
        search_layout.addWidget(self.inp_search)
        search_layout.addWidget(self.combo_filter)

        # Seçenek: Kütüphane sonuçlarını göster/gizle
        # Seçenek: Kütüphane sonuçlarını göster/gizle
        self.check_show_library = QCheckBox(tr("LBL_CHECK_LIBRARY"))
        self.check_show_library.setChecked(True)
        self.check_show_library.stateChanged.connect(self.refresh_list)
        
        self.btn_download_all = QPushButton(tr("BTN_DOWNLOAD_ALL"))
        self.btn_download_all.clicked.connect(self.open_bulk_downloader)
        self.btn_download_all.setStyleSheet("background-color: #424242; color: #aaa; font-size: 11px;")

        self.btn_browser = QPushButton(tr("BTN_API_BROWSER"))
        self.btn_browser.clicked.connect(self.open_api_browser)
        self.btn_browser.setStyleSheet("background-color: #6a1b9a; color: white; font-weight: bold;")

        self.list_widget = QListWidget()
        self.list_widget.itemClicked.connect(self.on_item_clicked)
        
        self.btn_add = QPushButton(tr("BTN_NEW_ENTITY"))
        self.btn_add.setObjectName("successBtn")
        self.btn_add.clicked.connect(self.prepare_new)
        
        l_layout.addLayout(search_layout)
        l_layout.addWidget(self.check_show_library)
        l_layout.addWidget(self.btn_download_all)
        l_layout.addWidget(self.btn_browser)
        l_layout.addWidget(self.list_widget)
        l_layout.addWidget(self.btn_add)

        # --- SAĞ PANEL ---
        self.sheet = NpcSheet()
        self.sheet.btn_save.clicked.connect(self.save_entity)
        self.sheet.btn_delete.clicked.connect(self.delete_entity)
        # Galeri Bağlantıları
        self.sheet.btn_add_img.clicked.connect(self.add_image)
        self.sheet.btn_remove_img.clicked.connect(self.remove_image)
        self.sheet.btn_prev_img.clicked.connect(self.prev_image)
        self.sheet.btn_next_img.clicked.connect(self.next_image)
        
        self.sheet.btn_show_player.clicked.connect(self.show_image_to_player)
        self.btn_show_stats = QPushButton(tr("BTN_SHOW_STATS"))
        self.btn_show_stats.setObjectName("primaryBtn")
        self.btn_show_stats.clicked.connect(self.show_stats_to_player)
        self.sheet.content_layout.itemAt(0).layout().itemAt(0).layout().insertWidget(3, self.btn_show_stats)

        # Büyü/Eşya Bağlantıları
        self.sheet.btn_add_spell.clicked.connect(self.add_spell_to_list)
        self.sheet.btn_remove_spell.clicked.connect(self.remove_spell_from_list)
        self.sheet.list_assigned_spells.itemDoubleClicked.connect(self.view_spell_details)
        self.sheet.btn_add_item_link.clicked.connect(self.add_item_to_list)
        self.sheet.btn_remove_item_link.clicked.connect(self.remove_item_from_list)
        self.sheet.list_assigned_items.itemDoubleClicked.connect(self.view_item_details)

        splitter.addWidget(left_widget); splitter.addWidget(self.sheet); splitter.setSizes([350, 950])
        layout.addWidget(splitter)
        self.refresh_list()

    def refresh_list(self):
        self.list_widget.clear()
        text = self.inp_search.text().lower()
        flt = self.combo_filter.currentText()
        
        # 1. YEREL VARLIKLAR (Dünyandakiler)
        for eid, data in self.dm.data["entities"].items():
            name = data.get("name", "").lower()
            etype = data.get("type", "")
            if flt != tr("CAT_ALL") and etype != flt: continue
            
            if text in name or any(text in t.lower() for t in data.get("tags", [])):
                item = QListWidgetItem(f"👤 {data['name']} ({etype})")
                item.setData(Qt.ItemDataRole.UserRole, eid)
                self.list_widget.addItem(item)

        # 2. KÜTÜPHANE VERİLERİ (İndirilenler)
        if self.check_show_library.isChecked() and (len(text) > 2 or flt != "Tümü"):
            lib_results = self.dm.search_in_library(flt, text)
            for res in lib_results:
                # Eğer zaten dünyada varsa kütüphanede tekrar gösterme (isteğe bağlı)
                item = QListWidgetItem(f"📚 {res['name']} ({res['type']})")
                item.setForeground(QBrush(QColor("#aaa"))) # Hafif sönük renk
                item.setData(Qt.ItemDataRole.UserRole, res['id'])
                self.list_widget.addItem(item)

    def on_item_clicked(self, item):
        eid = item.data(Qt.ItemDataRole.UserRole)
        
        # Eğer bu bir kütüphane öğesi ise (ID 'lib_' ile başlıyorsa)
        if str(eid).startswith("lib_"):
            parts = eid.split("_") # lib, category, index
            cat = parts[1]
            idx = parts[2]
            
            # Yükleniyor...
            self.sheet.inp_name.setText(tr("MSG_LOADING"))
            self.sheet.setEnabled(False)
            
            # Kütüphaneden detayları arkada çek
            # Kategori ismini düzeltmek gerekebilir, ancak fetch_details_from_api zaten harita kullanıyor
            # Fakat burada cat direkt "Canavar", "Büyü (Spell)" gibi ham string
            
            self.worker = ApiSearchWorker(self.dm, cat, idx)
            self.worker.finished.connect(self.on_api_search_finished)
            self.worker.start()

        else:
            # Normal yerel varlık
            self.sheet.inp_name.setStyleSheet("") 
            self.load_entity(item)

    def on_api_search_finished(self, success, data_or_id, msg):
        self.sheet.setEnabled(True)
        if success and isinstance(data_or_id, dict):
            # data_or_id burada 'data' (parsed dict) döner çünkü detay çekiyoruz
            self.current_entity_id = None # Henüz dünyada değil
            self.load_data_into_sheet(data_or_id)
            # Kullanıcıya bilgi ver
            self.sheet.inp_name.setStyleSheet("border: 2px solid #2e7d32;") # Yeşil çerçeve
        else:
            QMessageBox.warning(self, tr("MSG_ERROR"), f"{tr('MSG_ERROR')}: {msg}")

    def load_entity(self, item):
        eid = item.data(Qt.ItemDataRole.UserRole)
        data = self.dm.data["entities"].get(eid)
        if not data: return
        self.current_entity_id = eid
        self.load_data_into_sheet(data)

    def load_data_into_sheet(self, data):
        """Detayları forma dolduran genel fonksiyon"""
        s = self.sheet
        s.inp_name.setText(data.get("name", ""))
        curr_type = data.get("type", "NPC")
        idx = s.inp_type.findText(curr_type)
        s.inp_type.setCurrentIndex(idx if idx >= 0 else 0)
        s.inp_tags.setText(", ".join(data.get("tags", [])))
        s.inp_desc.setText(data.get("description", ""))
        
        # Statlar
        stats = data.get("stats", {})
        for k, v in s.stats_inputs.items(): v.setText(str(stats.get(k, 10)))
        c = data.get("combat_stats", {})
        s.inp_hp.setText(str(c.get("hp", ""))); s.inp_ac.setText(str(c.get("ac", ""))); s.inp_speed.setText(str(c.get("speed", ""))); s.inp_cr.setText(str(c.get("cr", "")))
        
        # Dinamik
        attrs = data.get("attributes", {})
        for l, w in s.dynamic_inputs.items():
            val = attrs.get(l, "")
            if isinstance(w, QComboBox): 
                ix = w.findText(val); w.setCurrentIndex(ix) if ix>=0 else w.setCurrentText(val)
            else: w.setText(val)

        s.clear_all_cards()
        self._fill_cards(s.trait_container, data.get("traits", []))
        self._fill_cards(s.action_container, data.get("actions", []))
        self._fill_cards(s.reaction_container, data.get("reactions", []))
        self._fill_cards(s.legendary_container, data.get("legendary_actions", []))
        self._fill_cards(s.inventory_container, data.get("inventory", []))
        self._fill_cards(s.custom_spell_container, data.get("custom_spells", []))

        # Resim
        # Resimler (Galeri)
        s.image_list = data.get("images", [])
        if not s.image_list and data.get("image_path"): # Migration fallback
            s.image_list = [data.get("image_path")]
        
        s.current_img_index = 0
        self.update_sheet_image()

    # --- DİĞER METODLAR (Save, Delete, API, Spell vb. önceki kodun aynısı) ---
    def save_entity(self):
        s = self.sheet
        if not s.inp_name.text(): return
        def get_cards(container):
            res = []; layout = container.dynamic_area
            for i in range(layout.count()):
                w = layout.itemAt(i).widget()
                if w: res.append({"name": w.inp_title.text(), "desc": w.inp_desc.toPlainText()})
            return res
        current_data = self.dm.data["entities"].get(self.current_entity_id, {})
        data = {
            "name": s.inp_name.text(), "type": s.inp_type.currentText(),
            "tags": [t.strip() for t in s.inp_tags.text().split(",") if t.strip()],
            "tags": [t.strip() for t in s.inp_tags.text().split(",") if t.strip()],
            "description": s.inp_desc.toPlainText(),
            "images": s.image_list, # YENİ: Liste olarak kaydet
            # "image_path" artık kullanılmıyor ama uyumluluk için ilk resmi tutabiliriz
            "image_path": s.image_list[0] if s.image_list else "",
            "stats": {k: int(v.text() or 10) for k, v in s.stats_inputs.items()},
            "combat_stats": {"hp": s.inp_hp.text(), "ac": s.inp_ac.text(), "speed": s.inp_speed.text(), "cr": s.inp_cr.text()},
            "attributes": {l: (w.currentText() if isinstance(w, QComboBox) else w.text()) for l, w in s.dynamic_inputs.items()},
            "location_id": s.combo_location.currentData() if s.combo_location.isVisible() else None,
            "spells": [s.list_assigned_spells.item(i).data(Qt.ItemDataRole.UserRole) for i in range(s.list_assigned_spells.count())],
            "equipment_ids": [s.list_assigned_items.item(i).data(Qt.ItemDataRole.UserRole) for i in range(s.list_assigned_items.count())],
            "traits": get_cards(s.trait_container), "actions": get_cards(s.action_container),
            "reactions": get_cards(s.reaction_container), "legendary_actions": get_cards(s.legendary_container),
            "inventory": get_cards(s.inventory_container), "custom_spells": get_cards(s.custom_spell_container)
        }
        new_id = self.dm.save_entity(self.current_entity_id, data)
        self.current_entity_id = new_id; self.refresh_list()
        s.inp_name.setStyleSheet("") # Normal hale getir
        QMessageBox.information(self, tr("MSG_SUCCESS"), tr("MSG_SUCCESS"))

    def _fill_cards(self, container, data_list):
        for item in data_list: self.sheet.add_feature_card(container, item.get("name"), item.get("desc"))
    def prepare_new(self): self.current_entity_id = None; self.sheet.prepare_new_entity()
    def delete_entity(self): 
        if self.current_entity_id: self.dm.delete_entity(self.current_entity_id); self.refresh_list(); self.prepare_new()
    def delete_entity(self): 
        if self.current_entity_id: self.dm.delete_entity(self.current_entity_id); self.refresh_list(); self.prepare_new()

    # --- GALERİ YÖNETİMİ ---
    def add_image(self):
        fname, _ = QFileDialog.getOpenFileName(self, "Resim Seç", "", "Images (*.png *.jpg *.jpeg *.bmp)")
        if fname:
            rel = self.dm.import_image(fname)
            if self.current_entity_id:
                # Hemen kaydet (Opsiyonel, kullanıcı kaydet'e basana kadar beklemek daha iyi olabilir ama
                # resim kopyalandığı için path elimizde)
                self.sheet.image_list.append(rel)
                self.sheet.current_img_index = len(self.sheet.image_list) - 1
                self.update_sheet_image()
            else:
                QMessageBox.information(self, tr("MSG_WARNING"), tr("BTN_NEW_ENTITY"))

    def remove_image(self):
        if not self.sheet.image_list: return
        del self.sheet.image_list[self.sheet.current_img_index]
        if self.sheet.current_img_index >= len(self.sheet.image_list):
            self.sheet.current_img_index = max(0, len(self.sheet.image_list) - 1)
        self.update_sheet_image()

    def prev_image(self):
        if not self.sheet.image_list: return
        self.sheet.current_img_index = (self.sheet.current_img_index - 1) % len(self.sheet.image_list)
        self.update_sheet_image()

    def next_image(self):
        if not self.sheet.image_list: return
        self.sheet.current_img_index = (self.sheet.current_img_index + 1) % len(self.sheet.image_list)
        self.update_sheet_image()

    def update_sheet_image(self):
        s = self.sheet
        if not s.image_list:
            s.lbl_image.setPixmap(None)
            s.lbl_img_counter.setText("0/0")
            return
        
        # Sınır kontrol
        if s.current_img_index < 0: s.current_img_index = 0
        if s.current_img_index >= len(s.image_list): s.current_img_index = len(s.image_list) - 1
        
        rel = s.image_list[s.current_img_index]
        p = self.dm.get_full_path(rel)
        s.lbl_image.setPixmap(QPixmap(p) if p and os.path.exists(p) else None)
        s.lbl_img_counter.setText(f"{s.current_img_index + 1}/{len(s.image_list)}")

    def select_image(self): pass # Eski metod (artık kullanılmıyor)
    def open_api_browser(self):
        cat = self.combo_filter.currentText()
        if cat == "Tümü": return QMessageBox.warning(self, "Uyarı", "Kategori seç.")
        if ApiBrowser(self.dm, cat, self).exec(): self.refresh_list()
    def open_bulk_downloader(self): BulkDownloadDialog(self).exec()
    def add_spell_to_list(self):
        sid = self.sheet.combo_all_spells.currentData(); txt = self.sheet.combo_all_spells.currentText()
        if not sid: return
        li = QListWidgetItem(txt); li.setData(Qt.ItemDataRole.UserRole, sid); self.sheet.list_assigned_spells.addItem(li)
    def remove_spell_from_list(self): r = self.sheet.list_assigned_spells.currentRow(); self.sheet.list_assigned_spells.takeItem(r) if r>=0 else None
    def view_spell_details(self, item): self.load_entity_by_id(item.data(Qt.ItemDataRole.UserRole))
    def add_item_to_list(self):
        iid = self.sheet.combo_all_items.currentData(); txt = self.sheet.combo_all_items.currentText()
        if not iid: return
        li = QListWidgetItem(txt); li.setData(Qt.ItemDataRole.UserRole, iid); self.sheet.list_assigned_items.addItem(li)
    def remove_item_from_list(self): r = self.sheet.list_assigned_items.currentRow(); self.sheet.list_assigned_items.takeItem(r) if r>=0 else None
    def view_item_details(self, item): self.load_entity_by_id(item.data(Qt.ItemDataRole.UserRole))
    def load_entity_by_id(self, eid):
        for i in range(self.list_widget.count()):
            if self.list_widget.item(i).data(Qt.ItemDataRole.UserRole) == eid:
                self.list_widget.setCurrentRow(i); self.load_entity(self.list_widget.item(i)); return
    def show_image_to_player(self):
        if not self.player_window.isVisible(): return
        # Şu an ekranda görünen resmi göster
        if self.sheet.image_list:
            rel = self.sheet.image_list[self.sheet.current_img_index]
            p = self.dm.get_full_path(rel)
            self.player_window.show_image(QPixmap(p) if p and os.path.exists(p) else None)

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

        # KOŞULLU STAT GÖSTERİMİ
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