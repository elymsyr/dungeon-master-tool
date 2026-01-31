from PyQt6.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QListWidget, 
                             QLineEdit, QPushButton, QLabel, QTextEdit, 
                             QMessageBox, QListWidgetItem, QSplitter, QWidget, 
                             QApplication, QComboBox, QStyle)
from PyQt6.QtCore import Qt, QTimer
from ui.workers import ApiListWorker, ApiSearchWorker
from ui.dialogs.bulk_downloader import BulkDownloadDialog
from core.locales import tr

class ApiBrowser(QDialog):
    # Keys recognized by the ApiClient
    CATEGORY_KEYS = [
        "Monster", 
        "Spell", 
        "Equipment", 
        "Magic Item", 
        "Class", 
        "Race"
    ]

    def __init__(self, data_manager, initial_category, parent=None, selection_mode=False):
        super().__init__(parent)
        self.dm = data_manager
        self.selection_mode = selection_mode
        self.selected_entity_id = None # Return value
        
        # Verify and set initial category
        self.current_category = "Monster" 
        norm_init = str(initial_category).lower()
        
        for key in self.CATEGORY_KEYS:
            if key.lower() == norm_init:
                self.current_category = key
                break
        
        self.selected_data = None
        self.full_list = [] 
        
        # Pagination State
        self.current_page = 1
        self.total_count = 0
        self.next_page_url = None
        self.prev_page_url = None 
        
        self.last_server_search = ""
        self.search_timer = QTimer()
        self.search_timer.setSingleShot(True)
        self.search_timer.setInterval(600) # 600ms debounce
        self.search_timer.timeout.connect(self.on_search_timer_timeout)

        self.setWindowTitle(tr("TITLE_API"))
        self.resize(1000, 650)
        
        self.init_ui()
        self.load_list()

    def init_ui(self):
        main_layout = QVBoxLayout(self)
        
        # --- TOP BAR: Category and Search ---
        top_layout = QHBoxLayout()
        
        # 0. Source and Document Selector
        self.combo_source = QComboBox()
        self.combo_source.setFixedWidth(200)
        sources = self.dm.api_client.get_available_sources()
        for key, name in sources:
            self.combo_source.addItem(name, key)
            
        curr = self.dm.api_client.current_source_key
        idx = self.combo_source.findData(curr)
        if idx >= 0: 
            self.combo_source.setCurrentIndex(idx)
        self.combo_source.currentIndexChanged.connect(self.on_source_changed)

        # Document Filter (Open5e only)
        self.combo_doc = QComboBox()
        self.combo_doc.setFixedWidth(150)
        self.combo_doc.addItem(tr("LBL_ALL_DOCS"), None)
        self.combo_doc.setVisible(False) # Hidden initially
        self.combo_doc.currentIndexChanged.connect(self.on_doc_filter_changed)

        # 1. Category Selector
        self.combo_cat = QComboBox()
        self.combo_cat.setFixedWidth(180)
        self.combo_cat.currentIndexChanged.connect(self.on_category_changed)
        
        # 2. Search Box
        self.inp_filter = QLineEdit()
        self.inp_filter.setPlaceholderText(tr("LBL_SEARCH_API"))
        self.inp_filter.setPlaceholderText(tr("LBL_SEARCH_API"))
        self.inp_filter.textChanged.connect(self.on_text_changed)
        self.inp_filter.returnPressed.connect(self.on_search_submit)
        
        # 3. Bulk Download Button (Active only for D&D 5e)
        self.btn_bulk = QPushButton()
        self.btn_bulk.setToolTip(tr("BTN_DOWNLOAD_ALL"))
        self.btn_bulk.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_ArrowDown))
        self.btn_bulk.setFixedSize(30, 30)
        self.btn_bulk.clicked.connect(self.open_bulk_downloader)

        top_layout.addWidget(QLabel(tr("LBL_SOURCE")))
        top_layout.addWidget(self.combo_source)
        top_layout.addWidget(self.combo_doc)
        top_layout.addWidget(QLabel(tr("LBL_CATEGORY")))
        top_layout.addWidget(self.combo_cat)
        top_layout.addWidget(self.inp_filter, 1)
        top_layout.addWidget(self.btn_bulk)
        
        main_layout.addLayout(top_layout)
        
        # --- MIDDLE: Splitter (List | Preview) ---
        splitter = QSplitter(Qt.Orientation.Horizontal)
        
        # Left: List and Pagination
        left_widget = QWidget()
        left_layout = QVBoxLayout(left_widget)
        left_layout.setContentsMargins(0,0,0,0)
        
        self.list_widget = QListWidget()
        self.list_widget.setAlternatingRowColors(True)
        self.list_widget.itemClicked.connect(self.on_item_clicked)
        left_layout.addWidget(self.list_widget)
        
        # Pagination Controls
        self.pagination_widget = QWidget()
        pag_layout = QHBoxLayout(self.pagination_widget)
        pag_layout.setContentsMargins(0, 5, 0, 0)
        
        self.btn_prev = QPushButton("<")
        self.btn_prev.setFixedWidth(30)
        self.btn_prev.clicked.connect(self.prev_page)
        
        self.lbl_page = QLabel("Page 1")
        self.lbl_page.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        self.btn_next = QPushButton(">")
        self.btn_next.setFixedWidth(30)
        self.btn_next.clicked.connect(self.next_page)
        
        pag_layout.addWidget(self.btn_prev)
        pag_layout.addWidget(self.lbl_page)
        pag_layout.addWidget(self.btn_next)
        
        left_layout.addWidget(self.pagination_widget)
        splitter.addWidget(left_widget)
        
        # Right: Preview
        preview_widget = QWidget()
        prev_layout = QVBoxLayout(preview_widget)
        prev_layout.setContentsMargins(10, 0, 0, 0)
        
        self.lbl_name = QLabel(tr("MSG_NO_SELECTION"))
        self.lbl_name.setObjectName("headerLabel")
        self.lbl_name.setStyleSheet("font-size: 18px; font-weight: bold; margin-bottom: 5px;")
        
        self.txt_desc = QTextEdit()
        self.txt_desc.setReadOnly(True)
        
        btn_layout = QHBoxLayout()
        self.btn_import = QPushButton(tr("BTN_IMPORT"))
        self.btn_import.setObjectName("successBtn")
        self.btn_import.setEnabled(False)
        self.btn_import.clicked.connect(self.import_selected)
        
        self.btn_import_npc = QPushButton(tr("BTN_IMPORT_NPC"))
        self.btn_import_npc.setObjectName("primaryBtn")
        self.btn_import_npc.setVisible(False)
        self.btn_import_npc.clicked.connect(lambda: self.import_selected(target_type="NPC"))
        
        btn_layout.addWidget(self.btn_import)
        btn_layout.addWidget(self.btn_import_npc)
        
        prev_layout.addWidget(self.lbl_name)
        prev_layout.addWidget(self.txt_desc)
        prev_layout.addLayout(btn_layout)
        
        splitter.addWidget(preview_widget)
        splitter.setSizes([350, 650])
        
        main_layout.addWidget(splitter)
        
        # Load categories and list
        self.update_source_ui()
        self.refresh_categories()

    def on_category_changed(self):
        """Refreshes the list when category changes."""
        self.current_category = self.combo_cat.currentData()
        self.load_list()

    def load_list(self):
        self.list_widget.clear()
        self.full_list = []
        self.txt_desc.clear()
        self.lbl_name.setText(tr("MSG_LOADING"))
        self.btn_import.setEnabled(False)
        self.btn_import_npc.setVisible(False)
        self.setEnabled(False)
        
        if hasattr(self, 'list_worker') and self.list_worker is not None:
            if self.list_worker.isRunning():
                try: 
                    self.list_worker.finished.disconnect()
                except: 
                    pass
                self.list_worker.quit()
                self.list_worker.deleteLater()

        filters = {}
        if self.combo_doc.isVisible():
            doc_slug = self.combo_doc.currentData()
            if doc_slug: filters["document__slug"] = doc_slug
        
        # Search logic
        query = self.inp_filter.text().strip()
        # If triggered by timer or Enter, OR if we have a query and are just paging, use it.
        # But we must distinguish between "User typed" (wait for timer) and "User changed page" (keep search).
        # Simply: if text box has text, we should search with it, UNLESS we want to allow local filtering only.
        # With auto-search, text box always implies search intent.
        if query:
            filters["search"] = query
            self.last_server_search = query.lower()
        else:
            self.last_server_search = ""
            
        self.list_worker = ApiListWorker(self.dm, self.current_category, page=self.current_page, filters=filters, parent=self)
        self.list_worker.finished.connect(self.on_list_loaded)
        self.list_worker.start()

    def on_list_loaded(self, data):
        self.setEnabled(True)
        self.lbl_name.setText(tr("MSG_NO_SELECTION"))
        
        if isinstance(data, dict):
             self.full_list = data.get("results", [])
             self.total_count = data.get("count", 0)
             self.next_page_url = data.get("next")
             self.prev_page_url = data.get("previous")
        else:
             self.full_list = data
             self.total_count = len(data)
             self.next_page_url = None
             self.prev_page_url = None

        self.update_pagination_ui()

        if not self.full_list:
            self.list_widget.clear()
            item = QListWidgetItem(tr("MSG_LIST_EMPTY"))
            item.setFlags(Qt.ItemFlag.NoItemFlags)
            self.list_widget.addItem(item)
            return

        self.filter_list()

    def on_source_changed(self):
        new_source = self.combo_source.currentData()
        self.dm.api_client.set_source(new_source)
        self.update_source_ui()
        self.current_page = 1 
        self.refresh_categories()

    def update_source_ui(self):
        current_key = self.dm.api_client.current_source_key
        is_open5e = (current_key == "open5e")
        is_dnd5e = (current_key == "dnd5e")

        self.combo_doc.setVisible(is_open5e)
        self.pagination_widget.setVisible(is_open5e)
        self.btn_bulk.setVisible(is_dnd5e)
        
        if is_open5e:
            self.combo_doc.blockSignals(True)
            self.combo_doc.clear()
            self.combo_doc.addItem(tr("LBL_ALL_DOCS"), None)
            
            docs = self.dm.api_client.get_documents()
            for slug, title in docs:
                self.combo_doc.addItem(title, slug)
            self.combo_doc.blockSignals(False)

    def on_doc_filter_changed(self):
        self.current_page = 1
        self.load_list()

    def next_page(self):
        if self.next_page_url:
            self.current_page += 1
            self.load_list()

    def prev_page(self):
        if self.prev_page_url:
            self.current_page -= 1
            self.load_list()
    
    def update_pagination_ui(self):
        self.lbl_page.setText(f"Page {self.current_page}")
        self.btn_prev.setEnabled(bool(self.prev_page_url))
        self.btn_next.setEnabled(bool(self.next_page_url))
        
    def on_search_submit(self):
        """Called when Enter is pressed."""
        self.search_timer.stop()
        self.current_page = 1
        self.load_list()

    def on_search_timer_timeout(self):
        """Called when debounce timer expires."""
        self.current_page = 1
        self.load_list()

    def on_text_changed(self, text):
        """Handle user typing: start debounce timer and local filter."""
        self.search_timer.start()
        self.filter_list()

    def filter_list(self):
        query = self.inp_filter.text().lower()
        
        # NOTE: Do NOT start timer here, as this function is called by on_list_loaded too.
        
        self.list_widget.clear()
        
        if not self.full_list: return

        # If the current list exactly matches the last server search, show all (bypass local name filter)
        # This allows "Bone Swarm" to show up for "skel"
        if self.last_server_search and query == self.last_server_search:
             for item in self.full_list:
                list_item = QListWidgetItem(item["name"])
                list_item.setData(Qt.ItemDataRole.UserRole, item["index"])
                self.list_widget.addItem(list_item)
             return

        for item in self.full_list:
            if query in item["name"].lower():
                list_item = QListWidgetItem(item["name"])
                list_item.setData(Qt.ItemDataRole.UserRole, item["index"])
                self.list_widget.addItem(list_item)

    def on_item_clicked(self, item):
        index_name = item.data(Qt.ItemDataRole.UserRole)
        if not index_name: return 
        
        self.lbl_name.setText(item.text() + f" ({tr('MSG_LOADING')})")
        self.txt_desc.clear()
        self.btn_import.setEnabled(False)
        self.list_widget.setEnabled(False)
        
        if hasattr(self, 'detail_worker') and self.detail_worker is not None:
             if self.detail_worker.isRunning():
                 try: self.detail_worker.finished.disconnect()
                 except: pass
                 self.detail_worker.quit()
                 self.detail_worker.deleteLater()
        
        self.detail_worker = ApiSearchWorker(self.dm, self.current_category, index_name, parent=self)
        self.detail_worker.finished.connect(self.on_details_loaded)
        self.detail_worker.start()

    def on_details_loaded(self, success, data_or_id, msg):
        self.list_widget.setEnabled(True)
        
        if success:
            # Show Cache Warning if present (Append to status or toast)
            if msg and tr("MSG_CACHE_WRITE_ERROR") in msg:
                 # Non-blocking visual cue. For now, simple QMessageBox or modify label
                 # Using MessageBox might be too intrusive every time, but necessary for "USB Read Only" feedback.
                 # Let's check if it's strictly the error key
                 self.lbl_name.setText(self.lbl_name.text() + " ⚠️ Offline Cache Failed")
                 # Optional: Status bar showing msg

            if isinstance(data_or_id, str):
                if self.selection_mode:
                    self.selected_entity_id = data_or_id
                    self.selected_data = self.dm.data["entities"].get(data_or_id)
                    self.btn_import.setEnabled(True)
                    self.btn_import.setText(tr("BTN_SELECT"))
                    try: 
                        self.btn_import.clicked.disconnect()
                    except: 
                        pass
                    self.btn_import.clicked.connect(self.accept)
                else:
                    data = self.dm.data["entities"].get(data_or_id)
                    self.btn_import.setEnabled(False)
                    self.btn_import.setText(tr("MSG_EXISTS"))
                self.btn_import_npc.setVisible(False)
            else:
                data = data_or_id
                self.btn_import.setEnabled(True)
                self.btn_import.setText(tr("BTN_IMPORT"))
                
            if not data:
                self.lbl_name.setText(tr("MSG_ERROR"))
                self.txt_desc.setText(tr("MSG_NOT_FOUND"))
                return

            self.selected_data = data
            self.lbl_name.setText(data.get("name"))
            
            # --- SHOW WARNING IN DESCRIPTION IF AVAILABLE ---
            if isinstance(data, dict) and "_warning" in data:
                 QMessageBox.warning(self, tr("MSG_WARNING"), data["_warning"])

            try: 
                self.btn_import.clicked.disconnect()
            except: 
                pass
            
            if self.current_category == "NPC":
                self.btn_import.setText(tr("BTN_SELECT") if self.selection_mode else tr("BTN_IMPORT_NPC"))
                self.btn_import.clicked.connect(lambda: self.import_selected(target_type="NPC"))
                self.btn_import_npc.setVisible(False)
            
            elif self.current_category == "Monster":
                self.btn_import.setText(tr("BTN_SELECT") if self.selection_mode else tr("BTN_IMPORT"))
                self.btn_import.clicked.connect(lambda: self.import_selected(target_type=None))
                
                if not isinstance(data_or_id, str) and not self.selection_mode:
                    self.btn_import_npc.setVisible(True)
                    self.btn_import_npc.setEnabled(True)
                else:
                    self.btn_import_npc.setVisible(False)
            else:
                self.btn_import.setText(tr("BTN_SELECT") if self.selection_mode else tr("BTN_IMPORT"))
                self.btn_import.clicked.connect(lambda: self.import_selected(target_type=None))
                self.btn_import_npc.setVisible(False)

            desc = f"{tr('LBL_TYPE')}: {tr('CAT_' + data.get('type', '').upper())}\n\n"
            desc += data.get("description", "")
            
            if "attributes" in data:
                desc += f"\n\n--- {tr('LBL_PROPERTIES')} ---\n"
                for k, v in data["attributes"].items():
                    val = tr(v) if str(v).startswith("LBL_") else v
                    desc += f"{tr(k)}: {val}\n"
            
            self.txt_desc.setText(desc)
        else:
            self.lbl_name.setText(tr("MSG_ERROR"))
            self.txt_desc.setText(msg)
            self.btn_import.setEnabled(False)

    def import_selected(self, target_type=None):
        if self.selected_data:
            self.btn_import.setEnabled(False)
            self.btn_import_npc.setEnabled(False)
            self.btn_import.setText(tr("MSG_IMPORTING"))
            QApplication.processEvents()
            
            try:
                new_id = self.dm.import_entity_with_dependencies(self.selected_data, type_override=target_type)
                
                if self.selection_mode:
                    self.selected_entity_id = new_id
                    self.accept()
                    return

                QMessageBox.information(self, tr("MSG_SUCCESS"), tr("MSG_IMPORT_SUCCESS_DETAIL", name=self.selected_data['name']))
                self.load_list() 
            except Exception as e:
                self.btn_import.setEnabled(True)
                self.btn_import.setText(tr("BTN_SELECT") if self.selection_mode else tr("BTN_IMPORT"))
                QMessageBox.critical(self, tr("MSG_ERROR"), f"Error: {str(e)}")

    def refresh_categories(self):
        self.combo_cat.blockSignals(True)
        self.combo_cat.clear()
        
        cats = self.dm.api_client.get_supported_categories()
        
        for cat_key in cats:
            trans_key = f"CAT_{cat_key.upper().replace(' ', '_')}"
            display_text = tr(trans_key)
            if display_text == trans_key: display_text = cat_key
            self.combo_cat.addItem(display_text, cat_key)
            
        idx = self.combo_cat.findData(self.current_category)
        if idx < 0:
            idx = 0
            if cats:
                self.current_category = cats[0]

        self.combo_cat.setCurrentIndex(idx)
        self.combo_cat.blockSignals(False)
        self.on_category_changed()
    
    def open_bulk_downloader(self):
        BulkDownloadDialog(self).exec()