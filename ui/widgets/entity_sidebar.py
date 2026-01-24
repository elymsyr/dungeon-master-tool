import os
from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QListWidget, 
                             QPushButton, QLineEdit, QComboBox, QCheckBox, 
                             QLabel, QStyle, QToolButton, QMenu, QWidgetAction, 
                             QFrame, QMessageBox, QListWidgetItem)
from PyQt6.QtCore import Qt, pyqtSignal, QMimeData, QEvent
from PyQt6.QtGui import QDrag, QAction

from core.models import ENTITY_SCHEMAS
from core.locales import tr
from ui.dialogs.import_window import ImportWindow

# --- YARDIMCI SINIFLAR ---

class EntityListItemWidget(QWidget):
    def __init__(self, name, raw_category, source=None, parent=None):
        super().__init__(parent)
        self.setObjectName("entityItem") 
        layout = QVBoxLayout(self)
        layout.setContentsMargins(5, 2, 5, 2) # Daha sıkışık liste görünümü
        layout.setSpacing(0)
        
        lbl_name = QLabel(name)
        lbl_name.setObjectName("entityName")
        lbl_name.setStyleSheet("font-size: 13px; font-weight: bold; background-color: transparent;")
        
        meta_layout = QHBoxLayout()
        meta_layout.setContentsMargins(0, 0, 0, 0)
        
        display_cat = self.translate_category(raw_category)
        lbl_cat = QLabel(display_cat)
        lbl_cat.setObjectName("entityCat")
        lbl_cat.setStyleSheet("font-size: 10px; font-style: italic; background-color: transparent; color: #888;")
        
        meta_layout.addWidget(lbl_cat)
        
        if source:
            lbl_source = QLabel(f"[{source}]")
            lbl_source.setStyleSheet("font-size: 9px; color: #666; background-color: transparent;")
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
            "npc": "CAT_NPC", "equipment": "CAT_EQUIPMENT", "magic-items": "CAT_EQUIPMENT",
            "class": "CAT_CLASS", "race": "CAT_RACE", "location": "CAT_LOCATION", "player": "CAT_PLAYER"
        }
        raw_lower = str(raw_cat).lower()
        if raw_lower in key_map: return tr(key_map[raw_lower])
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
        mime = QMimeData()
        mime.setText(str(eid))
        drag = QDrag(self)
        drag.setMimeData(mime)
        drag.exec(Qt.DropAction.CopyAction)

# --- ANA SIDEBAR CLASS ---

class EntitySidebar(QWidget):
    item_double_clicked = pyqtSignal(str) 

    def __init__(self, data_manager, parent=None):
        super().__init__(parent)
        self.dm = data_manager
        self.active_categories = set()
        self.active_sources = set()
        
        self.setMinimumWidth(250)
        self.setMaximumWidth(350)
        
        self.init_ui()
        self.refresh_list()

    def init_ui(self):
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(5, 5, 5, 5)
        main_layout.setSpacing(5)
        
        # --- ÜST KISIM: ARAMA VE FİLTRE ---
        header_layout = QHBoxLayout()
        header_layout.setContentsMargins(0, 0, 0, 0)
        header_layout.setSpacing(2)

        self.inp_search = QLineEdit()
        self.inp_search.setPlaceholderText(tr("LBL_SEARCH"))
        self.inp_search.setFixedHeight(28)
        self.inp_search.textChanged.connect(self.refresh_list)
        
        self.btn_filter = QToolButton()
        self.btn_filter.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_FileDialogListView))
        self.btn_filter.setPopupMode(QToolButton.ToolButtonPopupMode.InstantPopup)
        self.btn_filter.setFixedSize(30, 28)
        
        # Filtre Menüsü (Stabilite ayarları eklendi)
        self.filter_menu = QMenu(self.btn_filter)
        self.filter_menu.setStyleSheet("""
            QMenu { border: 1px solid #444; padding: 2px; }
            QMenu::separator { height: 1px; background: #444; margin: 5px 0px; }
        """)
        self.btn_filter.setMenu(self.filter_menu)
        self.filter_menu.aboutToShow.connect(self.update_filter_menu)
        
        header_layout.addWidget(self.inp_search, 1)
        header_layout.addWidget(self.btn_filter)
        main_layout.addLayout(header_layout)
        
        # --- ORTA KISIM: LİSTE ---
        self.list_widget = DraggableListWidget()
        self.list_widget.itemDoubleClicked.connect(self.on_item_double_clicked)
        main_layout.addWidget(self.list_widget)
        
        # --- ALT KISIM: BUTONLAR ---
        btn_layout = QHBoxLayout()
        btn_layout.setContentsMargins(0, 0, 0, 0)
        btn_layout.setSpacing(5)
        
        self.btn_import = QPushButton("📥 " + tr("BTN_IMPORT"))
        self.btn_import.setFixedHeight(30)
        self.btn_import.clicked.connect(self.open_import_window)
        
        self.btn_add = QPushButton("➕ " + tr("BTN_ADD"))
        self.btn_add.setObjectName("successBtn")
        self.btn_add.setFixedHeight(30)
        self.btn_add.clicked.connect(self.create_new_entity)
        
        btn_layout.addWidget(self.btn_import, 1)
        btn_layout.addWidget(self.btn_add, 1)
        main_layout.addLayout(btn_layout)

    def update_filter_menu(self):
        self.filter_menu.clear()
        
        container = QWidget()
        # Margin/Padding zıplamasını engellemek için Layout ayarları
        layout = QVBoxLayout(container)
        layout.setContentsMargins(8, 5, 8, 5) # Sabit padding
        layout.setSpacing(0) # İç elemanlar arası boşluk sıfır
        
        # Stil sabitleme
        container.setStyleSheet("""
            QCheckBox { 
                padding: 4px; 
                margin: 0px; 
                background: transparent;
            }
            QCheckBox:hover { background-color: rgba(255, 255, 255, 0.1); }
            QLabel#menuHeader { 
                font-weight: bold; 
                margin-top: 5px; 
                margin-bottom: 2px; 
                color: #aaa;
                font-size: 10px;
                text-transform: uppercase;
            }
        """)
        
        # Kategoriler Bölümü
        lbl_cat = QLabel(tr("LBL_TYPE"))
        lbl_cat.setObjectName("menuHeader")
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
            # Tıklanınca menünün kapanmasını engellemek ve veriyi tutmak için
            chk.toggled.connect(lambda checked, c=cat: self.toggle_category_filter(c, checked))
            layout.addWidget(chk)
            
        # Kaynaklar Bölümü
        available_sources = set()
        for ent in self.dm.data["entities"].values():
            if ent.get("source"): available_sources.add(ent.get("source"))
            
        if available_sources:
            line = QFrame()
            line.setFrameShape(QFrame.Shape.HLine)
            line.setStyleSheet("background: #444; margin: 5px 0px;")
            layout.addWidget(line)
            
            lbl_src = QLabel(tr("LBL_SOURCE"))
            lbl_src.setObjectName("menuHeader")
            layout.addWidget(lbl_src)
            
            for src in sorted(available_sources):
                chk = QCheckBox(src)
                chk.setChecked(src in self.active_sources)
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
        if checked: self.active_categories.add(category)
        else: self.active_categories.discard(category)
        self.refresh_filter_button_style()
        self.refresh_list()

    def toggle_source_filter(self, source, checked):
        if checked: self.active_sources.add(source)
        else: self.active_sources.discard(source)
        self.refresh_filter_button_style()
        self.refresh_list()

    def clear_filters(self):
        self.active_categories.clear()
        self.active_sources.clear()
        self.refresh_filter_button_style()
        self.refresh_list()

    def refresh_filter_button_style(self):
        count = len(self.active_categories) + len(self.active_sources)
        if count > 0:
            self.btn_filter.setStyleSheet("background-color: palette(highlight); border-radius: 4px;")
        else:
            self.btn_filter.setStyleSheet("")

    def normalize_type(self, t):
        t = str(t).lower()
        if t in ["canavar", "monster"]: return "monster"
        if "spell" in t or "büyü" in t: return "spell"
        if "equipment" in t or "eşya" in t: return "equipment"
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
            if text and text not in f"{name} {raw_type}".lower(): continue
            
            item = QListWidgetItem(self.list_widget)
            item.setData(Qt.ItemDataRole.UserRole, eid)
            widget = EntityListItemWidget(name, raw_type, source)
            item.setSizeHint(widget.sizeHint())
            self.list_widget.setItemWidget(item, widget)

    def on_item_double_clicked(self, item):
        eid = item.data(Qt.ItemDataRole.UserRole)
        self.item_double_clicked.emit(eid)

    def create_new_entity(self):
        self.clear_filters() 
        default_data = {"name": tr("NAME_UNNAMED"), "type": "NPC"}
        new_id = self.dm.save_entity(None, default_data)
        self.refresh_list()
        self.item_double_clicked.emit(new_id)

    def open_import_window(self):
        dlg = ImportWindow(self.dm, self)
        dlg.entity_imported.connect(self.refresh_list)
        if dlg.exec():
            self.refresh_list()

    def retranslate_ui(self):
        self.inp_search.setPlaceholderText(tr("LBL_SEARCH"))
        self.btn_import.setText("📥 " + tr("BTN_IMPORT"))
        self.btn_add.setText("➕ " + tr("BTN_ADD"))