import os
from PyQt6.QtWidgets import (QWidget, QHBoxLayout, QVBoxLayout, QListWidget, 
                             QPushButton, QLineEdit, QComboBox, QSplitter, 
                             QMessageBox, QListWidgetItem, QCheckBox, QLabel, 
                             QStyle, QTabWidget, QMenu, QTabBar, QToolButton, 
                             QWidgetAction, QFrame)
from PyQt6.QtGui import (QColor, QBrush, QDrag, QAction, QIcon, QPixmap, 
                         QDesktopServices, QKeySequence, QShortcut)
from PyQt6.QtCore import Qt, QMimeData, QUrl, QEvent

from ui.widgets.npc_sheet import NpcSheet
from ui.dialogs.api_browser import ApiBrowser
from ui.dialogs.bulk_downloader import BulkDownloadDialog
from ui.workers import ApiSearchWorker
from core.models import ENTITY_SCHEMAS
from core.locales import tr

class EntityListItemWidget(QWidget):
    def __init__(self, name, raw_category, source=None, parent=None):
        super().__init__(parent)
        self.setObjectName("entityItem") 
        layout = QVBoxLayout(self)
        layout.setContentsMargins(5, 5, 5, 5)
        layout.setSpacing(2)
        
        lbl_name = QLabel(name)
        lbl_name.setObjectName("entityName")
        lbl_name.setStyleSheet("font-size: 14px; font-weight: bold; background-color: transparent;")
        
        meta_layout = QHBoxLayout()
        meta_layout.setContentsMargins(0, 0, 0, 0)
        
        display_cat = self.translate_category(raw_category)
        lbl_cat = QLabel(display_cat)
        lbl_cat.setObjectName("entityCat")
        lbl_cat.setStyleSheet("font-size: 11px; font-style: italic; background-color: transparent; color: #888;")
        
        meta_layout.addWidget(lbl_cat)
        
        if source:
            lbl_source = QLabel(f"[{source}]")
            lbl_source.setStyleSheet("font-size: 10px; color: #666; background-color: transparent;")
            lbl_source.setAlignment(Qt.AlignmentFlag.AlignRight)
            meta_layout.addWidget(lbl_source)
        else:
            meta_layout.addStretch()

        layout.addWidget(lbl_name)
        layout.addLayout(meta_layout)

    def translate_category(self, raw_cat):
        key_map = {
            "monster": "CAT_MONSTER", "monsters": "CAT_MONSTER", "canavar": "CAT_MONSTER",
            "spell": "CAT_SPELL", "spells": "CAT_SPELL", "büyü (spell)": "CAT_SPELL",
            "npc": "CAT_NPC",
            "equipment": "CAT_EQUIPMENT", "eşya (equipment)": "CAT_EQUIPMENT",
            "magic-items": "CAT_EQUIPMENT",
            "class": "CAT_CLASS", "classes": "CAT_CLASS", "sınıf (class)": "CAT_CLASS",
            "race": "CAT_RACE", "races": "CAT_RACE", "irk (race)": "CAT_RACE",
            "location": "CAT_LOCATION", "mekan": "CAT_LOCATION",
            "player": "CAT_PLAYER", "oyuncu": "CAT_PLAYER"
        }
        raw_lower = str(raw_cat).lower()
        if raw_lower in key_map:
            return tr(key_map[raw_lower])
        
        for schema_key in ENTITY_SCHEMAS.keys():
            if schema_key.lower() == raw_lower:
                return tr(f"CAT_{schema_key.upper().replace(' ', '_')}")
                
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
        self.dm = data_manager
        self.parent_db_tab = parent_db_tab
        self.panel_id = panel_id
        self.setTabsClosable(True)
        self.setMovable(True)
        self.setAcceptDrops(True)
        self.tabCloseRequested.connect(self.close_tab)
        
        # --- SHORTCUT: Ctrl + W ---
        self.close_shortcut = QShortcut(QKeySequence("Ctrl+W"), self)
        self.close_shortcut.activated.connect(self.close_current_tab)

        # --- MOUSE MIDDLE CLICK TRACKING ---
        self.tabBar().installEventFilter(self)

        self.setStyleSheet("""
            QTabWidget::pane { border: 1px solid #444; background-color: #1e1e1e; }
            QTabBar::tab { background: #2d2d2d; color: #aaa; padding: 8px 15px; margin-right: 2px; }
            QTabBar::tab:selected { background: #1e1e1e; color: white; border-top: 2px solid #007acc; font-weight: bold; }
            QTabBar::tab:hover { background: #3e3e3e; }
        """)

    def close_current_tab(self):
        """Closes the active tab."""
        idx = self.currentIndex()
        if idx != -1:
            self.close_tab(idx)

    def eventFilter(self, obj, event):
        """Closes the tab when middle-clicked on the tab bar."""
        if obj is self.tabBar() and event.type() == QEvent.Type.MouseButtonRelease:
            if event.button() == Qt.MouseButton.MiddleButton:
                idx = self.tabBar().tabAt(event.pos())
                if idx != -1:
                    self.close_tab(idx)
                    return True
        return super().eventFilter(obj, event)

    def dragEnterEvent(self, event):
        if event.mimeData().hasText(): 
            event.acceptProposedAction()
        
    def dropEvent(self, event):
        eid = event.mimeData().text()
        self.parent_db_tab.open_entity_tab(eid, target_panel=self.panel_id)
        event.acceptProposedAction()
        
    def close_tab(self, index):
        widget = self.widget(index)
        if widget: 
            widget.deleteLater()
        self.removeTab(index)

class DatabaseTab(QWidget):
    def __init__(self, data_manager, player_window):
        super().__init__()
        self.dm = data_manager
        self.player_window = player_window
        
        self.active_categories = set() 
        self.active_sources = set()    
        self.available_sources = set() 
        
        self.init_ui()

    def init_ui(self):
        main_layout = QHBoxLayout(self)
        sidebar_widget = QWidget()
        sidebar_layout = QVBoxLayout(sidebar_widget)
        sidebar_layout.setContentsMargins(0, 0, 0, 0)
        
        self.inp_search = QLineEdit()
        self.inp_search.setPlaceholderText(tr("LBL_SEARCH"))
        self.inp_search.textChanged.connect(self.refresh_list)
        
        filter_layout = QHBoxLayout()
        self.btn_filter = QToolButton()
        self.btn_filter.setText(f" {tr('LBL_FILTER')}")
        self.btn_filter.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_FileDialogListView))
        self.btn_filter.setPopupMode(QToolButton.ToolButtonPopupMode.InstantPopup)
        self.btn_filter.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextBesideIcon)
        self.btn_filter.setFixedWidth(120)
        self.btn_filter.setFixedHeight(32)
        self.btn_filter.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.refresh_filter_button_style()
        
        self.filter_menu = QMenu(self.btn_filter)
        self.filter_menu.setStyleSheet("QMenu { border: 1px solid rgba(100, 100, 100, 0.5); border-radius: 6px; padding: 5px; }")
        self.btn_filter.setMenu(self.filter_menu)
        self.filter_menu.aboutToShow.connect(self.update_filter_menu) 
        
        self.check_show_library = QCheckBox(tr("LBL_CHECK_LIBRARY"))
        self.check_show_library.setChecked(True)
        self.check_show_library.stateChanged.connect(self.refresh_list)
        
        filter_layout.addWidget(self.btn_filter)
        filter_layout.addWidget(self.check_show_library)
        
        self.btn_browser = QPushButton(tr("BTN_API_BROWSER"))
        self.btn_browser.clicked.connect(self.open_api_browser)
        self.list_widget = DraggableListWidget()
        self.list_widget.itemDoubleClicked.connect(self.on_item_double_clicked)
        self.btn_add = QPushButton(tr("BTN_NEW_ENTITY"))
        self.btn_add.setObjectName("successBtn")
        self.btn_add.clicked.connect(self.create_new_entity)
        
        sidebar_layout.addWidget(self.inp_search)
        sidebar_layout.addLayout(filter_layout)
        sidebar_layout.addWidget(self.btn_browser)
        sidebar_layout.addWidget(self.list_widget)
        sidebar_layout.addWidget(self.btn_add)

        self.workspace_splitter = QSplitter(Qt.Orientation.Horizontal)
        self.tab_manager_left = EntityTabWidget(self.dm, self, "left")
        self.tab_manager_right = EntityTabWidget(self.dm, self, "right")
        self.workspace_splitter.addWidget(self.tab_manager_left)
        self.workspace_splitter.addWidget(self.tab_manager_right)
        self.workspace_splitter.setSizes([800, 800])
        self.workspace_splitter.setCollapsible(0, False)

        main_splitter = QSplitter(Qt.Orientation.Horizontal)
        main_splitter.addWidget(sidebar_widget)
        main_splitter.addWidget(self.workspace_splitter)
        main_splitter.setSizes([350, 1150]) 
        
        main_layout.addWidget(main_splitter)
        self.refresh_list()

    def update_filter_menu(self):
        self.filter_menu.clear()
        container = QWidget(); container.setObjectName("filterMenuContainer")
        container.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        container.setStyleSheet("""
            QWidget { background: transparent; outline: none; border: none; }
            QCheckBox { padding: 6px; spacing: 8px; border-radius: 4px; }
            QCheckBox:hover { background-color: rgba(255, 255, 255, 0.1); }
            QCheckBox:focus { border: none; outline: none; }
        """)
        layout = QVBoxLayout(container)
        layout.setContentsMargins(10, 10, 10, 10)
        layout.setSpacing(2)
        lbl_cat = QLabel(tr("LBL_TYPE"))
        lbl_cat.setStyleSheet("font-weight: bold; margin-bottom: 4px; border: none;")
        layout.addWidget(lbl_cat)
        categories = sorted(list(ENTITY_SCHEMAS.keys()) + ["NPC", "Monster"])
        categories = sorted(list(set(categories)))
        for cat in categories:
            display_text = cat
            trans_key = f"CAT_{cat.upper().replace(' ', '_')}"
            translated = tr(trans_key)
            if translated != trans_key: display_text = translated
            chk = QCheckBox(display_text)
            chk.setChecked(cat in self.active_categories)
            chk.setFocusPolicy(Qt.FocusPolicy.NoFocus)
            chk.setCursor(Qt.CursorShape.PointingHandCursor)
            chk.toggled.connect(lambda checked, c=cat: self.toggle_category_filter(c, checked))
            layout.addWidget(chk)
        self.available_sources.clear()
        for ent in self.dm.data["entities"].values():
            src = ent.get("source")
            if src: self.available_sources.add(src)
        if self.available_sources:
            line = QFrame()
            line.setFrameShape(QFrame.Shape.HLine)
            line.setFrameShadow(QFrame.Shadow.Sunken)
            line.setStyleSheet("background-color: rgba(128, 128, 128, 0.5); border: none; margin-top: 8px; margin-bottom: 8px;")
            layout.addWidget(line)
            lbl_src = QLabel(tr("LBL_SOURCE"))
            lbl_src.setStyleSheet("font-weight: bold; margin-bottom: 4px; border: none;")
            layout.addWidget(lbl_src)
            for src in sorted(self.available_sources):
                chk = QCheckBox(src)
                chk.setChecked(src in self.active_sources)
                chk.setFocusPolicy(Qt.FocusPolicy.NoFocus)
                chk.setCursor(Qt.CursorShape.PointingHandCursor)
                chk.toggled.connect(lambda checked, s=src: self.toggle_source_filter(s, checked))
                layout.addWidget(chk)
        action_widget = QWidgetAction(self.filter_menu)
        action_widget.setDefaultWidget(container)
        self.filter_menu.addAction(action_widget)
        self.filter_menu.addSeparator()
        clear_action = QAction("❌ " + tr("BTN_CLEAR"), self.filter_menu)
        clear_action.triggered.connect(self.clear_filters)
        self.filter_menu.addAction(clear_action)

    def toggle_category_filter(self, category, checked):
        if checked: 
            self.active_categories.add(category)
        else: 
            self.active_categories.discard(category)
        self.refresh_filter_button_style()
        self.refresh_list()

    def toggle_source_filter(self, source, checked):
        if checked: 
            self.active_sources.add(source)
        else: 
            self.active_sources.discard(source)
        self.refresh_filter_button_style()
        self.refresh_list()

    def clear_filters(self):
        self.active_categories.clear()
        self.active_sources.clear()
        self.refresh_filter_button_style()
        self.refresh_list()

    def refresh_filter_button_style(self):
        count = len(self.active_categories) + len(self.active_sources)
        base_style = "QToolButton { border: none; border-radius: 4px; padding: 0px 5px; background-color: transparent; min-height: 20px; max-height: 20px; margin: 0px; } QToolButton::menu-indicator { image: none; width: 0px; } QToolButton:hover { background-color: rgba(255, 255, 255, 0.1); } QToolButton:pressed { background-color: rgba(0, 0, 0, 0.2); }"
        if count > 0:
            self.btn_filter.setText(f" {tr('LBL_FILTER')} ({count})")
            self.btn_filter.setStyleSheet(base_style + " QToolButton { font-weight: bold; color: palette(highlight); }")
        else:
            self.btn_filter.setText(f" {tr('LBL_FILTER')}")
            self.btn_filter.setStyleSheet(base_style + " QToolButton { font-weight: normal; color: palette(text); }")

    def normalize_type(self, t):
        t = str(t).lower()
        if t in ["canavar", "monster", "monsters"]: return "monster"
        if "spell" in t or "büyü" in t: return "spell"
        if "equipment" in t or "eşya" in t: return "equipment"
        if "class" in t or "sınıf" in t: return "class"
        if "race" in t or "irk" in t: return "race"
        if "location" in t or "mekan" in t: return "location"
        if "player" in t or "oyuncu" in t: return "player"
        return t

    def refresh_list(self):
        self.list_widget.clear()
        text = self.inp_search.text().lower()
        norm_active_cats = {self.normalize_type(c) for c in self.active_categories}
        for eid, data in self.dm.data["entities"].items():
            name = data.get("name", "")
            raw_type = data.get("type", "NPC")
            norm_type = self.normalize_type(raw_type)
            source = data.get("source", "")
            if norm_active_cats and norm_type not in norm_active_cats: continue
            if self.active_sources and source not in self.active_sources: continue
            search_content = f"{name} {data.get('tags', [])} {raw_type}".lower()
            if text and text not in search_content: continue
            item = QListWidgetItem(self.list_widget)
            item.setData(Qt.ItemDataRole.UserRole, eid)
            widget = EntityListItemWidget(name, raw_type, source)
            item.setSizeHint(widget.sizeHint())
            self.list_widget.setItemWidget(item, widget)
        if self.check_show_library.isChecked() and not self.active_sources:
            if len(text) > 2 or self.active_categories:
                lib_results = self.dm.search_in_library(None, text)
                for res in lib_results:
                    if "index" not in res: continue
                    res_cat = res["type"]
                    norm_res_cat = self.normalize_type(res_cat)
                    if norm_active_cats and norm_res_cat not in norm_active_cats: continue
                    item = QListWidgetItem(self.list_widget)
                    api_safe_cat = "monsters" if norm_res_cat == "monster" else "spells" if norm_res_cat == "spell" else "equipment" if norm_res_cat == "equipment" else "classes" if norm_res_cat == "class" else "races" if norm_res_cat == "race" else res_cat.lower()
                    safe_id = f"lib_{api_safe_cat}_{res['index']}"
                    item.setData(Qt.ItemDataRole.UserRole, safe_id)
                    widget = EntityListItemWidget("📚 " + res["name"], res_cat, "SRD 5e")
                    item.setSizeHint(widget.sizeHint())
                    self.list_widget.setItemWidget(item, widget)

    def on_item_double_clicked(self, item):
        eid = item.data(Qt.ItemDataRole.UserRole)
        self.open_entity_tab(eid, target_panel="left")

    def open_entity_tab(self, eid, target_panel="left", data=None):
        if eid and str(eid).startswith("lib_"):
            parts = eid.split("_")
            raw_cat = parts[1]
            category_map = {"monsters": "Monster", "spells": "Spell", "equipment": "Equipment", "magic-items": "Equipment", "classes": "Class", "races": "Race", "npc": "NPC"}
            target_cat = category_map.get(raw_cat, raw_cat.capitalize())
            self._fetch_and_open_api_entity(target_cat, parts[2], target_panel)
            return
        target_manager = self.tab_manager_left if target_panel == "left" else self.tab_manager_right
        if eid:
            for i in range(target_manager.count()):
                sheet = target_manager.widget(i)
                if sheet.property("entity_id") == eid: 
                    target_manager.setCurrentIndex(i)
                    return
            data = self.dm.data["entities"].get(eid)
        if not data: return
        new_sheet = NpcSheet(self.dm); new_sheet.setProperty("entity_id", eid); new_sheet.request_open_entity.connect(lambda id: self.open_entity_tab(id, target_panel))
        new_sheet.save_requested.connect(lambda: self.save_sheet_data(new_sheet))
        new_sheet.data_changed.connect(lambda: self.mark_tab_unsaved(new_sheet, target_manager))
        self.populate_sheet(new_sheet, data)
        new_sheet.btn_delete.clicked.connect(lambda: self.delete_entity_from_tab(new_sheet))
        
        # --- BUTON BAĞLANTILARI ---
        new_sheet.btn_project_pdf.clicked.connect(lambda: self.project_entity_pdf(new_sheet))
        
        new_sheet.btn_add_pdf.clicked.connect(new_sheet.add_pdf_dialog)
        new_sheet.btn_open_pdf.clicked.connect(new_sheet.open_current_pdf)
        new_sheet.btn_remove_pdf.clicked.connect(new_sheet.remove_current_pdf)
        new_sheet.btn_open_pdf_folder.clicked.connect(new_sheet.open_pdf_folder)
        icon_char = "👤" if data.get("type") == "NPC" else "🐉" if data.get("type") == "Monster" else "📜"
        tab_title = f"{icon_char} {data.get('name')}"
        if not eid: tab_title = f"⚠️ {tab_title}"
        tab_index = target_manager.addTab(new_sheet, tab_title); target_manager.setCurrentIndex(tab_index)

    # --- EKLENEN METODLAR (HATA DÜZELTMESİ) ---
    def project_entity_image(self, sheet):
        if not sheet.image_list:
            QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_NO_IMAGE_IN_ENTITY"))
            return
        
        # Geçerli resim yolunu al
        rel_path = sheet.image_list[sheet.current_img_index]
        full_path = self.dm.get_full_path(rel_path)
        
        if full_path and os.path.exists(full_path):
            # Player Window'a çoklu resim desteğiyle ekle
            self.player_window.add_image_to_view(full_path)
            if not self.player_window.isVisible():
                self.player_window.show()
        else:
            QMessageBox.warning(self, tr("MSG_ERROR"), tr("MSG_FILE_NOT_FOUND_DISK"))

    def project_entity_pdf(self, sheet):
        current_item = sheet.list_pdfs.currentItem()
        if not current_item:
            QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_SELECT_PDF_FIRST"))
            return
            
        rel_path = current_item.text()
        full_path = self.dm.get_full_path(rel_path)
        
        if full_path and os.path.exists(full_path):
            self.player_window.show_pdf(full_path)
            if not self.player_window.isVisible():
                self.player_window.show()
        else:
            QMessageBox.warning(self, tr("MSG_ERROR"), tr("MSG_FILE_NOT_FOUND_DISK"))
    # ------------------------------------------

    def mark_tab_unsaved(self, sheet, manager):
        idx = manager.indexOf(sheet)
        if idx != -1:
            current_title = manager.tabText(idx)
            if not current_title.startswith("*") and not current_title.startswith("⚠️"):
                manager.setTabText(idx, f"* {current_title}")

    def _fetch_and_open_api_entity(self, cat, idx, target_panel):
        self.api_worker = ApiSearchWorker(self.dm, cat, idx)
        self.api_worker.finished.connect(lambda s, d, m: self._on_api_fetched(s, d, m, target_panel))
        self.api_worker.finished.connect(lambda: setattr(self, 'api_worker', None))
        self.api_worker.start()

    def _on_api_fetched(self, success, data_or_id, msg, target_panel):
        if success:
            if isinstance(data_or_id, dict):
                processed_data = self.dm.prepare_entity_from_external(data_or_id)
                self.open_entity_tab(eid=None, target_panel=target_panel, data=processed_data)
            elif isinstance(data_or_id, str):
                self.open_entity_tab(data_or_id, target_panel)
        else: QMessageBox.warning(self, tr("MSG_ERROR"), msg)

    def create_new_entity(self):
        default_data = {"name": "Yeni Varlık", "type": "NPC"}
        new_id = self.dm.save_entity(None, default_data)
        self.refresh_list()
        self.open_entity_tab(new_id, "left")

    def save_sheet_data(self, sheet):
        eid = sheet.property("entity_id"); data = self.collect_data_from_sheet(sheet)
        if not data: return
        new_eid = self.dm.save_entity(eid, data); sheet.setProperty("entity_id", new_eid); sheet.is_dirty = False
        updated_data = self.dm.data["entities"][new_eid]; sheet.inp_source.setText(updated_data.get("source", ""))
        for manager in [self.tab_manager_left, self.tab_manager_right]:
            idx = manager.indexOf(sheet)
            if idx != -1:
                icon_char = "👤" if data.get("type") == "NPC" else "🐉"
                manager.setTabText(idx, f"{icon_char} {data.get('name')}")
        self.refresh_list()

    def delete_entity_from_tab(self, sheet):
        eid = sheet.property("entity_id")
        if not eid:
            for manager in [self.tab_manager_left, self.tab_manager_right]:
                idx = manager.indexOf(sheet) 
                if idx != -1: 
                    manager.removeTab(idx)
            return
        if QMessageBox.question(self, tr("BTN_DELETE"), tr("MSG_CONFIRM_DELETE")) == QMessageBox.StandardButton.Yes:
            self.dm.delete_entity(eid)
            self.refresh_list()
            for manager in [self.tab_manager_left, self.tab_manager_right]:
                idx = manager.indexOf(sheet)
                if idx != -1: 
                    manager.removeTab(idx)

    def populate_sheet(self, s, data): 
        s.populate_sheet(data) 
    def collect_data_from_sheet(self, s): 
        return s.collect_data_from_sheet()
    def open_api_browser(self):
        target_cat = "Monster"
        if self.active_categories:
            first_cat = list(self.active_categories)[0]
            if first_cat in ["NPC", "Monster"]: target_cat = "Monster"
            elif first_cat == "Spell": target_cat = "Spell"
            elif first_cat == "Equipment": target_cat = "Equipment"
            elif first_cat == "Class": target_cat = "Class"
            elif first_cat == "Race": target_cat = "Race"
        if ApiBrowser(self.dm, target_cat, self).exec(): 
            self.refresh_list()
    def retranslate_ui(self):
        self.inp_search.setPlaceholderText(tr("LBL_SEARCH"))
        self.btn_filter.setText(f" {tr('LBL_FILTER')}")
        self.refresh_filter_button_style() 
        self.check_show_library.setText(tr("LBL_CHECK_LIBRARY"))
        self.btn_browser.setText(tr("BTN_API_BROWSER"))
        self.btn_add.setText(tr("BTN_NEW_ENTITY"))
        for manager in [self.tab_manager_left, self.tab_manager_right]:
            for i in range(manager.count()):
                widget = manager.widget(i)
                if hasattr(widget, "retranslate_ui"): widget.retranslate_ui()