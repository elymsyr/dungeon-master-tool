import os
from PyQt6.QtWidgets import (QWidget, QHBoxLayout, QVBoxLayout, QListWidget, 
                             QPushButton, QLineEdit, QComboBox, QSplitter, 
                             QMessageBox, QListWidgetItem, QCheckBox, QLabel, 
                             QStyle, QTabWidget, QMenu, QTabBar)
from PyQt6.QtGui import QColor, QBrush, QDrag, QAction, QIcon, QPixmap, QDesktopServices
from PyQt6.QtCore import Qt, QMimeData, QUrl

from ui.widgets.npc_sheet import NpcSheet
from ui.dialogs.api_browser import ApiBrowser
from ui.dialogs.bulk_downloader import BulkDownloadDialog
from ui.workers import ApiSearchWorker
from core.models import ENTITY_SCHEMAS
from core.locales import tr

class EntityListItemWidget(QWidget):
    def __init__(self, name, raw_category, parent=None):
        super().__init__(parent)
        self.setObjectName("entityItem") 
        layout = QVBoxLayout(self)
        layout.setContentsMargins(5, 5, 5, 5)
        layout.setSpacing(2)
        lbl_name = QLabel(name)
        lbl_name.setObjectName("entityName")
        lbl_name.setStyleSheet("font-size: 14px; font-weight: bold; background-color: transparent;")
        display_cat = self.translate_category(raw_category)
        lbl_cat = QLabel(display_cat)
        lbl_cat.setObjectName("entityCat")
        lbl_cat.setStyleSheet("font-size: 11px; font-style: italic; background-color: transparent;")
        layout.addWidget(lbl_name); layout.addWidget(lbl_cat)

    def translate_category(self, raw_cat):
        key_map = {
            "monster": "CAT_MONSTER", "monsters": "CAT_MONSTER", "canavar": "CAT_MONSTER",
            "spell": "CAT_SPELL", "spells": "CAT_SPELL", "büyü (spell)": "CAT_SPELL",
            "npc": "CAT_NPC",
            "equipment": "CAT_EQUIPMENT", "eşya (equipment)": "CAT_EQUIPMENT",
            "magic-items": "CAT_EQUIPMENT",
            "class": "CAT_CLASS", "classes": "CAT_CLASS", "sınıf (class)": "CAT_CLASS",
            "race": "CAT_RACE", "races": "CAT_RACE", "irk (race)": "CAT_RACE"
        }
        translation_key = key_map.get(str(raw_cat).lower())
        if translation_key: return tr(translation_key)
        return str(raw_cat).title()

class DraggableListWidget(QListWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setDragEnabled(True)

    def startDrag(self, supportedActions):
        item = self.currentItem()
        if not item: return
        eid = item.data(Qt.ItemDataRole.UserRole)
        if not eid: return
        mime = QMimeData(); mime.setText(str(eid))
        drag = QDrag(self); drag.setMimeData(mime); drag.exec(Qt.DropAction.CopyAction)

class EntityTabWidget(QTabWidget):
    def __init__(self, data_manager, parent_db_tab, panel_id):
        super().__init__()
        self.dm = data_manager; self.parent_db_tab = parent_db_tab; self.panel_id = panel_id
        self.setTabsClosable(True); self.setMovable(True); self.setAcceptDrops(True)
        self.tabCloseRequested.connect(self.close_tab)
        self.setStyleSheet("""
            QTabWidget::pane { border: 1px solid #444; background-color: #1e1e1e; }
            QTabBar::tab { background: #2d2d2d; color: #aaa; padding: 8px 15px; margin-right: 2px; }
            QTabBar::tab:selected { background: #1e1e1e; color: white; border-top: 2px solid #007acc; font-weight: bold; }
            QTabBar::tab:hover { background: #3e3e3e; }
        """)
    def dragEnterEvent(self, event):
        if event.mimeData().hasText(): event.acceptProposedAction()
    def dropEvent(self, event):
        eid = event.mimeData().text()
        self.parent_db_tab.open_entity_tab(eid, target_panel=self.panel_id)
        event.acceptProposedAction()
    def close_tab(self, index):
        widget = self.widget(index)
        if widget: widget.deleteLater()
        self.removeTab(index)

class DatabaseTab(QWidget):
    def __init__(self, data_manager, player_window):
        super().__init__()
        self.dm = data_manager; self.player_window = player_window; self.init_ui()

    def init_ui(self):
        main_layout = QHBoxLayout(self)
        sidebar_widget = QWidget(); sidebar_layout = QVBoxLayout(sidebar_widget); sidebar_layout.setContentsMargins(0, 0, 0, 0)
        
        self.inp_search = QLineEdit(); self.inp_search.setPlaceholderText(tr("LBL_SEARCH")); self.inp_search.textChanged.connect(self.refresh_list)
        filter_layout = QHBoxLayout()
        self.combo_filter = QComboBox(); self.combo_filter.addItem(tr("CAT_ALL"), None)
        for cat in ENTITY_SCHEMAS.keys(): self.combo_filter.addItem(tr(f"CAT_{cat.upper().replace(' ', '_').replace('(', '').replace(')', '')}"), cat)
        self.combo_filter.currentTextChanged.connect(self.refresh_list)
        self.check_show_library = QCheckBox(tr("LBL_CHECK_LIBRARY")); self.check_show_library.setChecked(True); self.check_show_library.stateChanged.connect(self.refresh_list)
        filter_layout.addWidget(self.combo_filter); filter_layout.addWidget(self.check_show_library)
        
        self.btn_download_all = QPushButton(tr("BTN_DOWNLOAD_ALL")); self.btn_download_all.clicked.connect(self.open_bulk_downloader)
        self.btn_browser = QPushButton(tr("BTN_API_BROWSER")); self.btn_browser.clicked.connect(self.open_api_browser)
        self.list_widget = DraggableListWidget(); self.list_widget.itemDoubleClicked.connect(self.on_item_double_clicked)
        self.btn_add = QPushButton(tr("BTN_NEW_ENTITY")); self.btn_add.setObjectName("successBtn"); self.btn_add.clicked.connect(self.create_new_entity)
        
        sidebar_layout.addWidget(self.inp_search); sidebar_layout.addLayout(filter_layout); sidebar_layout.addWidget(self.btn_download_all); sidebar_layout.addWidget(self.btn_browser); sidebar_layout.addWidget(self.list_widget); sidebar_layout.addWidget(self.btn_add)

        self.workspace_splitter = QSplitter(Qt.Orientation.Horizontal)
        self.tab_manager_left = EntityTabWidget(self.dm, self, "left")
        self.tab_manager_right = EntityTabWidget(self.dm, self, "right")
        self.workspace_splitter.addWidget(self.tab_manager_left); self.workspace_splitter.addWidget(self.tab_manager_right)
        self.workspace_splitter.setSizes([800, 800]); self.workspace_splitter.setCollapsible(0, False)

        main_splitter = QSplitter(Qt.Orientation.Horizontal)
        main_splitter.addWidget(sidebar_widget); main_splitter.addWidget(self.workspace_splitter)
        main_splitter.setSizes([300, 1200])
        main_layout.addWidget(main_splitter)
        self.refresh_list()

    def retranslate_ui(self):
        self.inp_search.setPlaceholderText(tr("LBL_SEARCH"))
        for i in range(self.combo_filter.count()):
            cat = self.combo_filter.itemData(i)
            if cat: self.combo_filter.setItemText(i, tr(f"CAT_{cat.upper().replace(' ', '_').replace('(', '').replace(')', '')}"))
            else: self.combo_filter.setItemText(i, tr("CAT_ALL"))
        self.check_show_library.setText(tr("LBL_CHECK_LIBRARY"))
        self.btn_download_all.setText(tr("BTN_DOWNLOAD_ALL"))
        self.btn_browser.setText(tr("BTN_API_BROWSER"))
        self.btn_add.setText(tr("BTN_NEW_ENTITY"))
        for manager in [self.tab_manager_left, self.tab_manager_right]:
            for i in range(manager.count()):
                widget = manager.widget(i)
                if hasattr(widget, "retranslate_ui"): widget.retranslate_ui()

    def refresh_list(self):
        self.list_widget.clear()
        text = self.inp_search.text().lower()
        flt_data = self.combo_filter.currentData()

        def normalize_type(t):
            t = str(t).lower()
            if t in ["canavar", "monster", "monsters"]: return "monster"
            if "spell" in t or "büyü" in t: return "spell"
            if "equipment" in t or "eşya" in t: return "equipment"
            if "class" in t or "sınıf" in t: return "class"
            if "race" in t or "irk" in t: return "race"
            return t
        target_cat = normalize_type(flt_data) if flt_data else None

        for eid, data in self.dm.data["entities"].items():
            name = data.get("name", "")
            raw_type = data.get("type", "NPC")
            norm_type = normalize_type(raw_type)
            if target_cat and norm_type != target_cat: continue
            if text not in name.lower() and text not in str(data.get("tags", "")).lower(): continue
            item = QListWidgetItem(self.list_widget)
            item.setData(Qt.ItemDataRole.UserRole, eid)
            widget = EntityListItemWidget(name, raw_type)
            item.setSizeHint(widget.sizeHint())
            self.list_widget.setItemWidget(item, widget)

        if self.check_show_library.isChecked() and (len(text) > 2 or target_cat):
            lib_results = self.dm.search_in_library(None, text)
            for res in lib_results:
                if "index" not in res: continue
                res_cat = res["type"]; norm_res_cat = normalize_type(res_cat)
                if target_cat and norm_res_cat != target_cat: continue
                item = QListWidgetItem(self.list_widget)
                api_safe_cat = "monsters" if norm_res_cat == "monster" else "spells" if norm_res_cat == "spell" else "equipment" if norm_res_cat == "equipment" else "classes" if norm_res_cat == "class" else "races" if norm_res_cat == "race" else norm_res_cat
                safe_id = f"lib_{api_safe_cat}_{res['index']}"
                item.setData(Qt.ItemDataRole.UserRole, safe_id)
                widget = EntityListItemWidget("📚 " + res["name"], res_cat)
                item.setSizeHint(widget.sizeHint())
                self.list_widget.setItemWidget(item, widget)

    def on_item_double_clicked(self, item):
        eid = item.data(Qt.ItemDataRole.UserRole)
        self.open_entity_tab(eid, target_panel="left")

    def open_entity_tab(self, eid, target_panel="left"):
        if str(eid).startswith("lib_"):
            parts = eid.split("_")
            self._fetch_and_open_api_entity(parts[1], parts[2], target_panel)
            return
        target_manager = self.tab_manager_left if target_panel == "left" else self.tab_manager_right
        for i in range(target_manager.count()):
            sheet = target_manager.widget(i)
            if sheet.property("entity_id") == eid: target_manager.setCurrentIndex(i); return
        data = self.dm.data["entities"].get(eid)
        if not data: return
        
        new_sheet = NpcSheet(self.dm)
        new_sheet.setProperty("entity_id", eid)
        
        # Populate
        self.populate_sheet(new_sheet, data)
        
        # --- BUTON BAĞLANTILARI ---
        new_sheet.btn_save.clicked.connect(lambda: self.save_sheet_data(new_sheet))
        new_sheet.btn_delete.clicked.connect(lambda: self.delete_entity_from_tab(new_sheet))
        
        # Projeksiyon İşlevleri (DatabaseTab Handle Eder)
        new_sheet.btn_show_player.clicked.connect(lambda: self.project_entity_image(new_sheet))
        new_sheet.btn_project_pdf.clicked.connect(lambda: self.project_entity_pdf(new_sheet))
        
        # Yönetim İşlevleri (NpcSheet Handle Eder)
        new_sheet.btn_add_pdf.clicked.connect(new_sheet.add_pdf_dialog)
        new_sheet.btn_open_pdf.clicked.connect(new_sheet.open_current_pdf)
        new_sheet.btn_remove_pdf.clicked.connect(new_sheet.remove_current_pdf)
        new_sheet.btn_open_pdf_folder.clicked.connect(new_sheet.open_pdf_folder)
        
        icon_char = "👤" if data.get("type") == "NPC" else "🐉" if data.get("type") == "Monster" else "📜"
        tab_index = target_manager.addTab(new_sheet, f"{icon_char} {data.get('name')}")
        target_manager.setCurrentIndex(tab_index)

    def _fetch_and_open_api_entity(self, cat, idx, target_panel):
        self.api_worker = ApiSearchWorker(self.dm, cat, idx)
        self.api_worker.finished.connect(lambda s, d, m: self._on_api_fetched(s, d, m, target_panel))
        self.api_worker.finished.connect(lambda: setattr(self, 'api_worker', None))
        self.api_worker.start()

    def _on_api_fetched(self, success, data_or_id, msg, target_panel):
        if success:
            if isinstance(data_or_id, dict):
                new_id = self.dm.import_entity_with_dependencies(data_or_id)
                self.refresh_list()
                self.open_entity_tab(new_id, target_panel)
            elif isinstance(data_or_id, str):
                self.open_entity_tab(data_or_id, target_panel)
        else: QMessageBox.warning(self, tr("MSG_ERROR"), msg)

    def create_new_entity(self):
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
            for manager in [self.tab_manager_left, self.tab_manager_right]:
                idx = manager.indexOf(sheet)
                if idx != -1: manager.removeTab(idx)

    # NpcSheet'ten yardımcı metodları çağır
    def populate_sheet(self, s, data): s.populate_sheet(s, data)
    def collect_data_from_sheet(self, s): return s.collect_data_from_sheet(s)

    # --- YENİ PROJEKSİYON FONKSİYONLARI ---
    def project_entity_image(self, sheet):
        if not sheet.image_list:
            QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_NO_IMAGE_IN_ENTITY"))
            return
        img_path = sheet.image_list[sheet.current_img_index]
        full_path = self.dm.get_full_path(img_path)
        if full_path and os.path.exists(full_path):
            self.player_window.show_image(QPixmap(full_path))
            self.player_window.show()
        else:
            QMessageBox.warning(self, tr("MSG_ERROR"), tr("MSG_FILE_NOT_FOUND_DISK"))

    def project_entity_pdf(self, sheet):
        selected = sheet.list_pdfs.currentItem()
        if not selected:
            QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_SELECT_PDF_FIRST"))
            return
        pdf_path = self.dm.get_full_path(selected.text())
        if pdf_path and os.path.exists(pdf_path):
            self.player_window.show_pdf(pdf_path)
            self.player_window.show()
        else:
            QMessageBox.warning(self, tr("MSG_ERROR"), tr("MSG_FILE_NOT_FOUND_DISK"))
    
    # Dialoglar
    def open_api_browser(self):
        cat = self.combo_filter.currentData()
        if not cat: return QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_SELECT_CATEGORY"))
        if ApiBrowser(self.dm, cat, self).exec(): self.refresh_list()
    def open_bulk_downloader(self): BulkDownloadDialog(self).exec()