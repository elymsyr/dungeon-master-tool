import os
from PyQt6.QtWidgets import (QWidget, QHBoxLayout, QVBoxLayout, QListWidget, 
                             QPushButton, QLineEdit, QComboBox, QSplitter, 
                             QMessageBox, QListWidgetItem, QCheckBox, QLabel, 
                             QStyle, QTabWidget, QMenu, QTabBar)
from PyQt6.QtGui import QColor, QBrush, QDrag, QAction, QIcon
from PyQt6.QtCore import Qt, QMimeData

from ui.widgets.npc_sheet import NpcSheet
from ui.dialogs.api_browser import ApiBrowser
from ui.dialogs.bulk_downloader import BulkDownloadDialog
from ui.workers import ApiSearchWorker
from core.models import ENTITY_SCHEMAS
from core.locales import tr

# --- 1. SÜRÜKLENEBİLİR LİSTE ---
class DraggableListWidget(QListWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setDragEnabled(True) # Sürüklemeyi aktif et

    def startDrag(self, supportedActions):
        item = self.currentItem()
        if not item: return

        eid = item.data(Qt.ItemDataRole.UserRole)
        if not eid: return

        # MIME verisi oluştur (Sadece Entity ID taşıyacak)
        mime = QMimeData()
        mime.setText(str(eid))
        
        drag = QDrag(self)
        drag.setMimeData(mime)
        # Sürüklerken bir önizleme resmi koyabiliriz (opsiyonel)
        # drag.setPixmap(...) 
        drag.exec(Qt.DropAction.CopyAction)

# --- 2. VARLIK SEKME YÖNETİCİSİ (SOL VEYA SAĞ PANEL) ---
class EntityTabWidget(QTabWidget):
    """
    İçine varlık kartlarının (NpcSheet) eklendiği sekme yapısı.
    Sürükle-bırak kabul eder.
    """
    def __init__(self, data_manager, parent_db_tab, panel_id):
        super().__init__()
        self.dm = data_manager
        self.parent_db_tab = parent_db_tab
        self.panel_id = panel_id # "left" veya "right"
        
        self.setTabsClosable(True)
        self.setMovable(True)
        self.setAcceptDrops(True) # Üzerine bırakılmayı kabul et
        self.tabCloseRequested.connect(self.close_tab)
        
        # Stil: Modern sekme görünümü
        self.setStyleSheet("""
            QTabWidget::pane { border: 1px solid #444; background-color: #1e1e1e; }
            QTabBar::tab { background: #2d2d2d; color: #aaa; padding: 8px 15px; margin-right: 2px; }
            QTabBar::tab:selected { background: #1e1e1e; color: white; border-top: 2px solid #007acc; font-weight: bold; }
            QTabBar::tab:hover { background: #3e3e3e; }
        """)

    def dragEnterEvent(self, event):
        if event.mimeData().hasText():
            event.acceptProposedAction()

    def dropEvent(self, event):
        eid = event.mimeData().text()
        # Bu ID'yi bu panele ekle
        self.parent_db_tab.open_entity_tab(eid, target_panel=self.panel_id)
        event.acceptProposedAction()

    def close_tab(self, index):
        # Sekmeyi kapat
        widget = self.widget(index)
        if widget:
            widget.deleteLater()
        self.removeTab(index)

# --- 3. ANA VERİTABANI SEKMESİ ---
class DatabaseTab(QWidget):
    def __init__(self, data_manager, player_window):
        super().__init__()
        self.dm = data_manager
        self.player_window = player_window
        self.init_ui()

    def init_ui(self):
        main_layout = QHBoxLayout(self)
        
        # --- SOL KENAR ÇUBUĞU (LİSTE & FİLTRELER) ---
        sidebar_widget = QWidget()
        sidebar_layout = QVBoxLayout(sidebar_widget)
        sidebar_layout.setContentsMargins(0, 0, 0, 0)
        
        # Arama ve Filtreler
        self.inp_search = QLineEdit()
        self.inp_search.setPlaceholderText(tr("LBL_SEARCH"))
        self.inp_search.textChanged.connect(self.refresh_list)
        
        filter_layout = QHBoxLayout()
        self.combo_filter = QComboBox()
        self.combo_filter.addItem(tr("CAT_ALL"), None)
        for cat in ENTITY_SCHEMAS.keys():
            self.combo_filter.addItem(tr(f"CAT_{cat.upper().replace(' ', '_').replace('(', '').replace(')', '')}"), cat)
        self.combo_filter.currentTextChanged.connect(self.refresh_list)
        
        self.check_show_library = QCheckBox(tr("LBL_CHECK_LIBRARY"))
        self.check_show_library.setChecked(True)
        self.check_show_library.stateChanged.connect(self.refresh_list)
        
        filter_layout.addWidget(self.combo_filter)
        filter_layout.addWidget(self.check_show_library)
        
        # Butonlar
        self.btn_download_all = QPushButton(tr("BTN_DOWNLOAD_ALL"))
        self.btn_download_all.clicked.connect(self.open_bulk_downloader)
        
        self.btn_browser = QPushButton(tr("BTN_API_BROWSER"))
        self.btn_browser.clicked.connect(self.open_api_browser)

        # Liste (Sürüklenebilir)
        self.list_widget = DraggableListWidget()
        self.list_widget.itemDoubleClicked.connect(self.on_item_double_clicked)
        
        # Yeni Ekle Butonu
        self.btn_add = QPushButton(tr("BTN_NEW_ENTITY"))
        self.btn_add.setObjectName("successBtn")
        self.btn_add.clicked.connect(self.create_new_entity)
        
        sidebar_layout.addWidget(self.inp_search)
        sidebar_layout.addLayout(filter_layout)
        sidebar_layout.addWidget(self.btn_download_all)
        sidebar_layout.addWidget(self.btn_browser)
        sidebar_layout.addWidget(self.list_widget)
        sidebar_layout.addWidget(self.btn_add)

        # --- ORTA ALAN (ÇİFT SEKME PANELİ) ---
        self.workspace_splitter = QSplitter(Qt.Orientation.Horizontal)
        
        # Sol Panel (Varsayılan Panel)
        self.tab_manager_left = EntityTabWidget(self.dm, self, "left")
        
        # Sağ Panel (İkincil Panel)
        self.tab_manager_right = EntityTabWidget(self.dm, self, "right")
        
        # Başlangıçta sağ panel boş olduğu için genişliğini küçük tutabiliriz veya eşit bölebiliriz
        self.workspace_splitter.addWidget(self.tab_manager_left)
        self.workspace_splitter.addWidget(self.tab_manager_right)
        self.workspace_splitter.setSizes([800, 800]) # Eşit başlat
        self.workspace_splitter.setCollapsible(0, False) # Sol taraf tamamen kapanmasın

        # Ana Splitter (Sidebar | Workspace)
        main_splitter = QSplitter(Qt.Orientation.Horizontal)
        main_splitter.addWidget(sidebar_widget)
        main_splitter.addWidget(self.workspace_splitter)
        main_splitter.setSizes([300, 1200])

        main_layout.addWidget(main_splitter)
        
        self.refresh_list()

    def retranslate_ui(self):
        self.inp_search.setPlaceholderText(tr("LBL_SEARCH"))
        self.combo_filter.setItemText(0, tr("CAT_ALL"))
        for i in range(1, self.combo_filter.count()):
            cat = self.combo_filter.itemData(i)
            if cat: self.combo_filter.setItemText(i, tr(f"CAT_{cat.upper().replace(' ', '_').replace('(', '').replace(')', '')}"))
        self.check_show_library.setText(tr("LBL_CHECK_LIBRARY"))
        self.btn_download_all.setText(tr("BTN_DOWNLOAD_ALL"))
        self.btn_browser.setText(tr("BTN_API_BROWSER"))
        self.btn_add.setText(tr("BTN_NEW_ENTITY"))

    # --- LİSTELEME ---
    def refresh_list(self):
        self.list_widget.clear()
        text = self.inp_search.text().lower()
        flt = self.combo_filter.currentText()
        
        # Yerel Varlıklar
        for eid, data in self.dm.data["entities"].items():
            name = data.get("name", "").lower()
            etype = data.get("type", "")
            if flt != tr("CAT_ALL") and etype != flt: continue
            
            if text in name or any(text in t.lower() for t in data.get("tags", [])):
                item = QListWidgetItem(f"👤 {data['name']} ({etype})")
                item.setData(Qt.ItemDataRole.UserRole, eid)
                self.list_widget.addItem(item)

        # Kütüphane
        if self.check_show_library.isChecked() and (len(text) > 2 or flt != tr("CAT_ALL")):
            lib_results = self.dm.search_in_library(flt, text)
            for res in lib_results:
                item = QListWidgetItem(f"📚 {res['name']} ({res['type']})")
                item.setForeground(QBrush(QColor("#888")))
                item.setData(Qt.ItemDataRole.UserRole, res['id'])
                self.list_widget.addItem(item)

    # --- SEKME AÇMA MANTIĞI ---
    def on_item_double_clicked(self, item):
        eid = item.data(Qt.ItemDataRole.UserRole)
        # Çift tık varsayılan olarak SOL panele açar
        self.open_entity_tab(eid, target_panel="left")

    def open_entity_tab(self, eid, target_panel="left"):
        """
        Belirtilen entity ID'sini hedef panelde (left/right) açar.
        Eğer zaten açıksa o sekmeye odaklanır.
        """
        # 1. Kütüphane öğesi mi kontrol et (lib_...)
        if str(eid).startswith("lib_"):
            parts = eid.split("_")
            self._fetch_and_open_api_entity(parts[1], parts[2], target_panel)
            return

        # 2. Hangi TabManager kullanılacak?
        target_manager = self.tab_manager_left if target_panel == "left" else self.tab_manager_right
        other_manager = self.tab_manager_right if target_panel == "left" else self.tab_manager_left

        # 3. Bu entity ZATEN bu panelde açık mı?
        for i in range(target_manager.count()):
            sheet = target_manager.widget(i)
            if sheet.property("entity_id") == eid:
                target_manager.setCurrentIndex(i)
                return

        # 4. Bu entity DİĞER panelde açık mı? (Opsiyonel: İki tarafta aynı anda açılmasını engelleyebiliriz veya izin verebiliriz)
        # Şimdilik izin verelim, DM karşılaştırma yapmak isteyebilir.
        
        # 5. Yeni Sekme Oluştur
        data = self.dm.data["entities"].get(eid)
        if not data: return
        
        new_sheet = NpcSheet()
        new_sheet.setProperty("entity_id", eid) # ID'yi widget üzerinde sakla
        
        # Veriyi doldur
        self.populate_sheet(new_sheet, data)
        
        # Buton Bağlantıları
        new_sheet.btn_save.clicked.connect(lambda: self.save_sheet_data(new_sheet))
        new_sheet.btn_delete.clicked.connect(lambda: self.delete_entity_from_tab(new_sheet))
        
        # Sekmeye Ekle
        icon_char = "👤" if data.get("type") == "NPC" else "🐉" if data.get("type") == "Monster" else "📜"
        tab_index = target_manager.addTab(new_sheet, f"{icon_char} {data.get('name')}")
        target_manager.setCurrentIndex(tab_index)

    def _fetch_and_open_api_entity(self, cat, idx, target_panel):
        # API'den veri çekme işlemi
        worker = ApiSearchWorker(self.dm, cat, idx)
        worker.finished.connect(lambda s, d, m: self._on_api_fetched(s, d, m, target_panel))
        worker.start()

    def _on_api_fetched(self, success, data_or_id, msg, target_panel):
        if success:
            if isinstance(data_or_id, dict):
                # Yeni veri, kaydet ve aç
                new_id = self.dm.import_entity_with_dependencies(data_or_id)
                self.refresh_list()
                self.open_entity_tab(new_id, target_panel)
            elif isinstance(data_or_id, str):
                # Zaten var, ID ile aç
                self.open_entity_tab(data_or_id, target_panel)
        else:
            QMessageBox.warning(self, tr("MSG_ERROR"), msg)

    def create_new_entity(self):
        # Yeni boş varlık oluştur ve sol panele ekle
        default_data = {"name": "Yeni Varlık", "type": "NPC"}
        new_id = self.dm.save_entity(None, default_data)
        self.refresh_list()
        self.open_entity_tab(new_id, "left")

    def save_sheet_data(self, sheet):
        eid = sheet.property("entity_id")
        data = self.collect_data_from_sheet(sheet)
        if not data: return

        self.dm.save_entity(eid, data)
        QMessageBox.information(self, tr("MSG_SUCCESS"), tr("MSG_SAVED"))
        
        # Sekme başlığını güncelle
        # Hangi panelde olduğunu bul
        for manager in [self.tab_manager_left, self.tab_manager_right]:
            idx = manager.indexOf(sheet)
            if idx != -1:
                icon_char = "👤" if data.get("type") == "NPC" else "🐉"
                manager.setTabText(idx, f"{icon_char} {data.get('name')}")
        
        self.refresh_list()

    def delete_entity_from_tab(self, sheet):
        eid = sheet.property("entity_id")
        if QMessageBox.question(self, tr("BTN_DELETE"), tr("MSG_CONFIRM_DELETE")) == QMessageBox.StandardButton.Yes:
            self.dm.delete_entity(eid)
            self.refresh_list()
            # Açık olan tüm sekmeleri bul ve kapat
            for manager in [self.tab_manager_left, self.tab_manager_right]:
                idx = manager.indexOf(sheet)
                if idx != -1: manager.removeTab(idx)

    # --- VERİ DOLDURMA / TOPLAMA (ESKİ KODDAN UYARLANDI) ---
    def populate_sheet(self, s, data):
        s.inp_name.setText(data.get("name", ""))
        curr_type = data.get("type", "NPC")
        idx = s.inp_type.findText(curr_type)
        s.inp_type.setCurrentIndex(idx if idx >= 0 else 0)
        s.inp_tags.setText(", ".join(data.get("tags", [])))
        s.inp_desc.setText(data.get("description", ""))
        
        stats = data.get("stats", {})
        for k, v in s.stats_inputs.items(): v.setText(str(stats.get(k, 10)))
        
        c = data.get("combat_stats", {})
        s.inp_hp.setText(str(c.get("hp", "")))
        s.inp_max_hp.setText(str(c.get("max_hp", "")))
        s.inp_ac.setText(str(c.get("ac", ""))) 
        s.inp_speed.setText(str(c.get("speed", "")))
        s.inp_init.setText(str(c.get("initiative", "")))

        s.inp_saves.setText(data.get("saving_throws", ""))
        s.inp_skills.setText(data.get("skills", ""))
        s.inp_vuln.setText(data.get("damage_vulnerabilities", ""))
        s.inp_resist.setText(data.get("damage_resistances", ""))
        s.inp_dmg_immune.setText(data.get("damage_immunities", ""))
        s.inp_cond_immune.setText(data.get("condition_immunities", ""))
        s.inp_prof.setText(str(data.get("proficiency_bonus", "")))
        s.inp_pp.setText(str(data.get("passive_perception", "")))

        s.update_ui_by_type(curr_type)
        attrs = data.get("attributes", {})
        for l, w in s.dynamic_inputs.items():
            val = attrs.get(l, "")
            if isinstance(w, QComboBox): 
                ix = w.findText(val); w.setCurrentIndex(ix) if ix>=0 else w.setCurrentText(val)
            else: w.setText(str(val))

        s.clear_all_cards()
        self._fill_cards(s, s.trait_container, data.get("traits", []))
        self._fill_cards(s, s.action_container, data.get("actions", []))
        self._fill_cards(s, s.reaction_container, data.get("reactions", []))
        self._fill_cards(s, s.legendary_container, data.get("legendary_actions", []))
        self._fill_cards(s, s.inventory_container, data.get("inventory", []))
        self._fill_cards(s, s.custom_spell_container, data.get("custom_spells", []))
        
        s.image_list = data.get("images", [])
        if not s.image_list and data.get("image_path"): s.image_list = [data.get("image_path")]
        s.current_img_index = 0
        if s.image_list:
             path = self.dm.get_full_path(s.image_list[0])
             if path and os.path.exists(path): s.lbl_image.setPixmap(QPixmap(path))
        
        # Bağlı Büyüler Listesi (Basitleştirilmiş)
        s.list_assigned_spells.clear()
        for spell_id in data.get("spells", []):
            spell = self.dm.data["entities"].get(spell_id)
            if spell: s.list_assigned_spells.addItem(f"{spell['name']} (Lv {spell.get('attributes',{}).get('LBL_LEVEL','?')})")

    def collect_data_from_sheet(self, s):
        if not s.inp_name.text(): return None
        
        def get_cards(container):
            res = []; layout = container.dynamic_area
            for i in range(layout.count()):
                w = layout.itemAt(i).widget()
                if w: res.append({"name": w.inp_title.text(), "desc": w.inp_desc.toPlainText()})
            return res
            
        data = {
            "name": s.inp_name.text(), 
            "type": s.inp_type.currentText(),
            "tags": [t.strip() for t in s.inp_tags.text().split(",") if t.strip()],
            "description": s.inp_desc.toPlainText(),
            "images": s.image_list,
            "stats": {k: int(v.text() or 10) for k, v in s.stats_inputs.items()},
            "combat_stats": {
                "hp": s.inp_hp.text(), "max_hp": s.inp_max_hp.text(), "ac": s.inp_ac.text(),
                "speed": s.inp_speed.text(), "initiative": s.inp_init.text()
            },
            "saving_throws": s.inp_saves.text(), "skills": s.inp_skills.text(),
            "damage_vulnerabilities": s.inp_vuln.text(), "damage_resistances": s.inp_resist.text(),
            "damage_immunities": s.inp_dmg_immune.text(), "condition_immunities": s.inp_cond_immune.text(),
            "proficiency_bonus": s.inp_prof.text(), "passive_perception": s.inp_pp.text(),
            "attributes": {l: (w.currentText() if isinstance(w, QComboBox) else w.text()) for l, w in s.dynamic_inputs.items()},
            "traits": get_cards(s.trait_container), "actions": get_cards(s.action_container),
            "reactions": get_cards(s.reaction_container), "legendary_actions": get_cards(s.legendary_container),
            "inventory": get_cards(s.inventory_container), "custom_spells": get_cards(s.custom_spell_container)
        }
        return data

    def _fill_cards(self, sheet, container, data_list):
        for item in data_list: sheet.add_feature_card(container, item.get("name"), item.get("desc"))

    # Dialogs
    def open_api_browser(self):
        cat = self.combo_filter.currentData()
        if not cat: return QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_SELECT_CATEGORY"))
        if ApiBrowser(self.dm, cat, self).exec(): self.refresh_list()
        
    def open_bulk_downloader(self): 
        BulkDownloadDialog(self).exec()