import os
import json
from PyQt6.QtWidgets import (QDialog, QVBoxLayout, QHBoxLayout, QListWidget, 
                             QLineEdit, QPushButton, QLabel, QTextEdit, 
                             QMessageBox, QSplitter, QWidget, QComboBox, 
                             QTabWidget, QTreeWidget, QTreeWidgetItem, QHeaderView, QStyle,
                             QListWidgetItem)
from PyQt6.QtCore import Qt, QTimer, QThread, pyqtSignal
from config import CACHE_DIR
from core.locales import tr
from ui.workers import ApiListWorker, ApiSearchWorker
from ui.dialogs.bulk_downloader import BulkDownloadDialog

# --- WORKER: Cache Tarayıcı ---
class LibraryScanWorker(QThread):
    """Diskteki cache/library klasörünü tarayıp ağaç yapısı çıkarır."""
    finished = pyqtSignal(dict) # { 'dnd5e': {'monsters': [file1, file2...]} }

    def run(self):
        library_root = os.path.join(CACHE_DIR, "library")
        tree_data = {}
        
        if os.path.exists(library_root):
            # 1. Kaynaklar (dnd5e, open5e, custom...)
            sources = [d for d in os.listdir(library_root) if os.path.isdir(os.path.join(library_root, d)) and d != "images"]
            
            for source in sources:
                tree_data[source] = {}
                source_path = os.path.join(library_root, source)
                
                # 2. Kategoriler (monsters, spells...)
                categories = [d for d in os.listdir(source_path) if os.path.isdir(os.path.join(source_path, d))]
                
                for cat in categories:
                    tree_data[source][cat] = []
                    cat_path = os.path.join(source_path, cat)
                    
                    # 3. Dosyalar (JSON)
                    try:
                        files = [f for f in os.listdir(cat_path) if f.endswith(".json")]
                        # Dosya isminden okunabilir isim türet
                        for f in files:
                            display_name = f.replace(".json", "").replace("-", " ").title()
                            # (Path, DisplayName, ID/Slug)
                            tree_data[source][cat].append((os.path.join(cat_path, f), display_name, f.replace(".json", "")))
                    except: pass
                    
        self.finished.emit(tree_data)

# --- TAB 1: LOCAL LIBRARY (OFFLINE) ---
class LocalLibraryTab(QWidget):
    def __init__(self, data_manager, parent_window):
        super().__init__()
        self.dm = data_manager
        self.parent_window = parent_window
        self.selected_file_path = None
        self.selected_file_data = None
        
        self.init_ui()
        self.refresh_library()

    def init_ui(self):
        layout = QHBoxLayout(self)
        
        # LEFT: Tree View
        left_layout = QVBoxLayout()
        self.inp_search = QLineEdit()
        self.inp_search.setPlaceholderText(tr("LBL_SEARCH"))
        self.inp_search.textChanged.connect(self.filter_tree)
        
        self.tree = QTreeWidget()
        self.tree.setHeaderHidden(True)
        self.tree.itemClicked.connect(self.on_item_clicked)
        
        btn_refresh = QPushButton(tr("BTN_REFRESH") if hasattr(tr, "BTN_REFRESH") else "Refresh")
        btn_refresh.clicked.connect(self.refresh_library)
        
        left_layout.addWidget(self.inp_search)
        left_layout.addWidget(self.tree)
        left_layout.addWidget(btn_refresh)
        
        # RIGHT: Preview
        right_layout = QVBoxLayout()
        self.lbl_name = QLabel(tr("MSG_NO_SELECTION"))
        self.lbl_name.setStyleSheet("font-size: 16px; font-weight: bold;")
        
        self.txt_preview = QTextEdit()
        self.txt_preview.setReadOnly(True)
        
        self.btn_import = QPushButton(tr("BTN_IMPORT"))
        self.btn_import.setObjectName("successBtn")
        self.btn_import.setEnabled(False)
        self.btn_import.clicked.connect(self.import_selected)
        
        right_layout.addWidget(self.lbl_name)
        right_layout.addWidget(self.txt_preview)
        right_layout.addWidget(self.btn_import)
        
        splitter = QSplitter(Qt.Orientation.Horizontal)
        w_left = QWidget(); w_left.setLayout(left_layout)
        w_right = QWidget(); w_right.setLayout(right_layout)
        splitter.addWidget(w_left)
        splitter.addWidget(w_right)
        splitter.setSizes([300, 500])
        
        layout.addWidget(splitter)

    def refresh_library(self):
        self.tree.clear()
        self.tree.setEnabled(False)
        self.worker = LibraryScanWorker()
        self.worker.finished.connect(self.on_scan_finished)
        self.worker.start()

    def on_scan_finished(self, data):
        self.tree.setEnabled(True)
        self.tree.clear()
        
        for source, categories in data.items():
            source_item = QTreeWidgetItem(self.tree)
            source_item.setText(0, source.upper())
            source_item.setFlags(source_item.flags() & ~Qt.ItemFlag.ItemIsSelectable)
            
            for cat, files in categories.items():
                cat_item = QTreeWidgetItem(source_item)
                # Basit çeviri mapping
                cat_map_tr = {
                    "monsters": "Canavarlar", "spells": "Büyüler", 
                    "equipment": "Ekipman", "classes": "Sınıflar", "races": "Irklar",
                    "magic-items": "Büyülü Eşyalar"
                }
                cat_text = cat_map_tr.get(cat, cat.title())
                
                cat_item.setText(0, f"{cat_text} ({len(files)})")
                cat_item.setFlags(cat_item.flags() & ~Qt.ItemFlag.ItemIsSelectable)
                
                for f_path, f_name, f_slug in files:
                    file_item = QTreeWidgetItem(cat_item)
                    file_item.setText(0, f_name)
                    file_item.setData(0, Qt.ItemDataRole.UserRole, {"path": f_path, "slug": f_slug, "cat": cat})
            
        self.tree.expandAll()

    def filter_tree(self, text):
        search = text.lower()
        root = self.tree.invisibleRootItem()
        for i in range(root.childCount()):
            source_item = root.child(i)
            source_visible = False
            for j in range(source_item.childCount()):
                cat_item = source_item.child(j)
                cat_visible = False
                for k in range(cat_item.childCount()):
                    file_item = cat_item.child(k)
                    if search in file_item.text(0).lower():
                        file_item.setHidden(False)
                        cat_visible = True
                        source_visible = True
                    else:
                        file_item.setHidden(True)
                cat_item.setHidden(not cat_visible)
            source_item.setHidden(not source_visible)

    def on_item_clicked(self, item, col):
        data = item.data(0, Qt.ItemDataRole.UserRole)
        if not data:
            self.selected_file_path = None
            self.btn_import.setEnabled(False)
            return
            
        self.selected_file_path = data["path"]
        self.lbl_name.setText(item.text(0))
        
        try:
            with open(self.selected_file_path, "r", encoding="utf-8") as f:
                content = json.load(f)
                self.selected_file_data = content
                
                # API Client mantığıyla parse et
                cat_map = {"monsters": "Monster", "spells": "Spell", "equipment": "Equipment", "classes": "Class", "races": "Race", "magic-items": "Magic Item"}
                api_cat = cat_map.get(data["cat"], data["cat"].title())
                
                # Parse dispatcher'ı kullan (formatlı veri için)
                parsed = self.dm.api_client.parse_dispatcher(api_cat, content)
                
                preview_txt = f"Source: {parsed.get('source', 'Unknown')}\n"
                preview_txt += f"Type: {parsed.get('type')}\n\n"
                preview_txt += parsed.get('description', 'No description available.')
                
                self.txt_preview.setText(preview_txt)
                self.btn_import.setEnabled(True)
                
        except Exception as e:
            self.txt_preview.setText(f"Error reading file: {e}")
            self.btn_import.setEnabled(False)

    def import_selected(self):
        if self.selected_file_data:
            try:
                type_override = None 
                self.dm.import_entity_with_dependencies(self.selected_file_data, type_override)
                QMessageBox.information(self, tr("MSG_SUCCESS"), tr("MSG_IMPORTED"))
                if self.parent_window.selection_mode:
                    self.parent_window.accept()
            except Exception as e:
                QMessageBox.critical(self, tr("MSG_ERROR"), str(e))


# --- TAB 2: API BROWSER (ONLINE) ---
class OnlineApiTab(QWidget):
    def __init__(self, data_manager, parent_window):
        super().__init__()
        self.dm = data_manager
        self.parent_window = parent_window
        
        # State
        self.current_category = "Monster"
        self.current_page = 1
        self.next_page_url = None
        self.prev_page_url = None
        self.search_timer = QTimer()
        self.search_timer.setInterval(600); self.search_timer.setSingleShot(True)
        self.search_timer.timeout.connect(self.load_list)
        
        self.init_ui()
        self.refresh_categories()

    def init_ui(self):
        main_layout = QVBoxLayout(self)
        
        # Toolbar
        top = QHBoxLayout()
        self.combo_source = QComboBox()
        self.combo_source.setFixedWidth(150)
        for k, n in self.dm.api_client.get_available_sources(): self.combo_source.addItem(n, k)
        curr = self.dm.api_client.current_source_key
        idx = self.combo_source.findData(curr)
        if idx>=0: self.combo_source.setCurrentIndex(idx)
        self.combo_source.currentIndexChanged.connect(self.on_source_changed)
        
        self.combo_cat = QComboBox()
        self.combo_cat.setFixedWidth(150)
        self.combo_cat.currentIndexChanged.connect(self.on_category_changed)
        
        self.inp_search = QLineEdit()
        self.inp_search.setPlaceholderText(tr("LBL_SEARCH_API"))
        self.inp_search.textChanged.connect(lambda: self.search_timer.start())
        
        self.btn_bulk = QPushButton()
        self.btn_bulk.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_ArrowDown))
        self.btn_bulk.setToolTip(tr("BTN_DOWNLOAD_ALL"))
        self.btn_bulk.clicked.connect(lambda: BulkDownloadDialog(self).exec())
        
        top.addWidget(self.combo_source); top.addWidget(self.combo_cat); top.addWidget(self.inp_search, 1); top.addWidget(self.btn_bulk)
        main_layout.addLayout(top)
        
        # Splitter
        splitter = QSplitter(Qt.Orientation.Horizontal)
        
        # List Side
        left_w = QWidget(); left_l = QVBoxLayout(left_w); left_l.setContentsMargins(0,0,0,0)
        self.list_widget = QListWidget()
        self.list_widget.setAlternatingRowColors(True)
        self.list_widget.itemClicked.connect(self.on_item_clicked)
        
        pag_l = QHBoxLayout()
        self.btn_prev = QPushButton("<"); self.btn_prev.setFixedWidth(30); self.btn_prev.clicked.connect(self.prev_page)
        self.lbl_page = QLabel("1"); self.lbl_page.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.btn_next = QPushButton(">"); self.btn_next.setFixedWidth(30); self.btn_next.clicked.connect(self.next_page)
        pag_l.addWidget(self.btn_prev); pag_l.addWidget(self.lbl_page); pag_l.addWidget(self.btn_next)
        
        left_l.addWidget(self.list_widget); left_l.addLayout(pag_l)
        splitter.addWidget(left_w)
        
        # Preview Side
        right_w = QWidget(); right_l = QVBoxLayout(right_w); right_l.setContentsMargins(5,0,0,0)
        self.lbl_name = QLabel(tr("MSG_NO_SELECTION"))
        self.lbl_name.setStyleSheet("font-size: 16px; font-weight: bold;")
        self.txt_desc = QTextEdit(); self.txt_desc.setReadOnly(True)
        self.btn_import = QPushButton(tr("BTN_IMPORT")); self.btn_import.setObjectName("successBtn"); self.btn_import.setEnabled(False)
        self.btn_import.clicked.connect(self.import_selected)
        
        right_l.addWidget(self.lbl_name); right_l.addWidget(self.txt_desc); right_l.addWidget(self.btn_import)
        splitter.addWidget(right_w)
        splitter.setSizes([300, 500])
        main_layout.addWidget(splitter)

    def refresh_categories(self):
        self.combo_cat.blockSignals(True)
        self.combo_cat.clear()
        cats = self.dm.api_client.get_supported_categories()
        for c in cats: 
            t = tr(f"CAT_{c.upper().replace(' ','_')}")
            self.combo_cat.addItem(t if t!=f"CAT_{c.upper()}" else c, c)
        self.combo_cat.blockSignals(False)
        self.load_list()

    def on_source_changed(self):
        self.dm.api_client.set_source(self.combo_source.currentData())
        self.current_page = 1
        self.refresh_categories()

    def on_category_changed(self):
        self.current_category = self.combo_cat.currentData()
        self.current_page = 1
        self.load_list()

    def load_list(self):
        self.list_widget.clear()
        self.lbl_name.setText(tr("MSG_LOADING"))
        self.setEnabled(False)
        filters = {"search": self.inp_search.text()} if self.inp_search.text() else None
        self.worker = ApiListWorker(self.dm, self.current_category, self.current_page, filters)
        self.worker.finished.connect(self.on_list_loaded)
        self.worker.start()

    def on_list_loaded(self, data):
        self.setEnabled(True)
        self.lbl_name.setText(tr("MSG_NO_SELECTION"))
        items = data.get("results", []) if isinstance(data, dict) else data
        self.next_page_url = data.get("next") if isinstance(data, dict) else None
        self.prev_page_url = data.get("previous") if isinstance(data, dict) else None
        
        self.btn_prev.setEnabled(bool(self.prev_page_url))
        self.btn_next.setEnabled(bool(self.next_page_url))
        self.lbl_page.setText(str(self.current_page))
        
        if not items:
            self.list_widget.addItem("No results.")
            return
            
        for i in items:
            # --- FIX: addItem returns None, so create Item first ---
            list_item = QListWidgetItem(i["name"])
            list_item.setData(Qt.ItemDataRole.UserRole, i["index"])
            self.list_widget.addItem(list_item)
            # -------------------------------------------------------

    def prev_page(self): self.current_page -= 1; self.load_list()
    def next_page(self): self.current_page += 1; self.load_list()

    def on_item_clicked(self, item):
        idx = item.data(Qt.ItemDataRole.UserRole)
        if not idx: return
        self.lbl_name.setText(item.text() + "...")
        self.txt_desc.clear()
        self.btn_import.setEnabled(False)
        
        self.detail_worker = ApiSearchWorker(self.dm, self.current_category, idx)
        self.detail_worker.finished.connect(self.on_detail_loaded)
        self.detail_worker.start()

    def on_detail_loaded(self, success, data, msg):
        if success:
            self.selected_data = data
            self.lbl_name.setText(data["name"])
            src = data.get("source") or data.get("_meta_source", "Unknown")
            desc = f"<b>Source:</b> {src}<br><hr>"
            desc += data.get("description", "")
            self.txt_desc.setHtml(desc)
            self.btn_import.setEnabled(True)
        else:
            self.lbl_name.setText("Error")
            self.txt_desc.setText(msg)

    def import_selected(self):
        if hasattr(self, 'selected_data'):
            try:
                self.dm.import_entity_with_dependencies(self.selected_data)
                QMessageBox.information(self, tr("MSG_SUCCESS"), tr("MSG_IMPORTED"))
                if self.parent_window.selection_mode: self.parent_window.accept()
            except Exception as e:
                QMessageBox.critical(self, tr("MSG_ERROR"), str(e))


# --- MAIN DIALOG ---
class ImportWindow(QDialog):
    def __init__(self, data_manager, parent=None, selection_mode=False):
        super().__init__(parent)
        self.setWindowTitle("Import Center")
        self.resize(1000, 700)
        self.selection_mode = selection_mode
        self.selected_id = None
        
        layout = QVBoxLayout(self)
        self.tabs = QTabWidget()
        
        self.tab_online = OnlineApiTab(data_manager, self)
        self.tab_local = LocalLibraryTab(data_manager, self)
        self.tab_file = QWidget() # Placeholder
        
        self.tabs.addTab(self.tab_online, "☁️ API Search (Online)")
        self.tabs.addTab(self.tab_local, "📚 Local Library (Offline)")
        self.tabs.addTab(self.tab_file, "📂 File Import (Coming Soon)")
        
        layout.addWidget(self.tabs)