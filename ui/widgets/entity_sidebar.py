import os
from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QListWidget, 
                             QPushButton, QLineEdit, QComboBox, QCheckBox, 
                             QLabel, QStyle, QToolButton, QMenu, QWidgetAction, 
                             QFrame, QMessageBox, QListWidgetItem)
from PyQt6.QtCore import Qt, pyqtSignal, QMimeData, QEvent
from PyQt6.QtGui import QDrag, QAction

from core.models import ENTITY_SCHEMAS
from core.locales import tr
from ui.dialogs.api_browser import ApiBrowser

# --- YARDIMCI SINIFLAR ---

class EntityListItemWidget(QWidget):
    """
    Listede her bir entity'nin nasıl görüneceğini belirleyen widget.
    (İsim, Kategori, Kaynak bilgisi gösterir)
    """
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
    """
    Sürüklenebilir öğeleri destekleyen liste.
    """
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
    item_double_clicked = pyqtSignal(str) # entity_id

    def __init__(self, data_manager, parent=None):
        super().__init__(parent)
        self.dm = data_manager
        self.active_categories = set()
        self.active_sources = set()
        self.available_sources = set()
        
        self.setMinimumWidth(250)
        self.setMaximumWidth(400)
        
        self.init_ui()
        self.refresh_list()

    def init_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(5, 5, 5, 5)
        
        # Arama
        self.inp_search = QLineEdit()
        self.inp_search.setPlaceholderText(tr("LBL_SEARCH"))
        self.inp_search.textChanged.connect(self.refresh_list)
        
        # Filtre Butonu ve Checkbox
        filter_layout = QHBoxLayout()
        self.btn_filter = QToolButton()
        self.btn_filter.setText(f" {tr('LBL_FILTER')}")
        self.btn_filter.setIcon(self.style().standardIcon(QStyle.StandardPixmap.SP_FileDialogListView))
        self.btn_filter.setPopupMode(QToolButton.ToolButtonPopupMode.InstantPopup)
        self.btn_filter.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextBesideIcon)
        self.btn_filter.setFixedHeight(32)
        # Menüyü hazırla
        self.filter_menu = QMenu(self.btn_filter)
        self.filter_menu.setStyleSheet("QMenu { border: 1px solid rgba(100, 100, 100, 0.5); border-radius: 6px; padding: 5px; }")
        self.btn_filter.setMenu(self.filter_menu)
        self.filter_menu.aboutToShow.connect(self.update_filter_menu)
        
        self.refresh_filter_button_style()
        
        self.check_show_library = QCheckBox(tr("LBL_CHECK_LIBRARY"))
        self.check_show_library.setChecked(True)
        self.check_show_library.stateChanged.connect(self.refresh_list)
        
        filter_layout.addWidget(self.btn_filter)
        filter_layout.addWidget(self.check_show_library)
        
        # API Butonu
        self.btn_browser = QPushButton(tr("BTN_API_BROWSER"))
        self.btn_browser.clicked.connect(self.open_api_browser)
        
        # Liste
        self.list_widget = DraggableListWidget()
        self.list_widget.itemDoubleClicked.connect(self.on_item_double_clicked)
        
        # Yeni Ekle Butonu
        self.btn_add = QPushButton(tr("BTN_NEW_ENTITY"))
        self.btn_add.setObjectName("successBtn")
        self.btn_add.clicked.connect(self.create_new_entity)
        
        # Layout Yerleşimi
        layout.addWidget(self.inp_search)
        layout.addLayout(filter_layout)
        layout.addWidget(self.btn_browser)
        layout.addWidget(self.list_widget)
        layout.addWidget(self.btn_add)

    def update_filter_menu(self):
        self.filter_menu.clear()
        
        container = QWidget()
        container.setObjectName("filterMenuContainer")
        container.setStyleSheet("""
            QWidget { background: transparent; outline: none; border: none; }
            QCheckBox { padding: 6px; spacing: 8px; border-radius: 4px; }
            QCheckBox:hover { background-color: rgba(255, 255, 255, 0.1); }
        """)
        
        layout = QVBoxLayout(container)
        layout.setContentsMargins(10, 10, 10, 10)
        layout.setSpacing(2)
        
        # Kategori Başlığı
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
            chk.setCursor(Qt.CursorShape.PointingHandCursor)
            chk.toggled.connect(lambda checked, c=cat: self.toggle_category_filter(c, checked))
            layout.addWidget(chk)
            
        # Kaynaklar (Source)
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
        
        # 1. Yerel Varlıklar
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
            
        # 2. Kütüphane Sonuçları (API Cache)
        if self.check_show_library.isChecked() and not self.active_sources:
            if len(text) > 2 or self.active_categories:
                lib_results = self.dm.search_in_library(None, text)
                for res in lib_results:
                    if "index" not in res: continue
                    res_cat = res["type"]
                    norm_res_cat = self.normalize_type(res_cat)
                    
                    if norm_active_cats and norm_res_cat not in norm_active_cats: continue
                    
                    item = QListWidgetItem(self.list_widget)
                    # Güvenli kategori dönüşümü
                    safe_cat = res_cat.lower()
                    if safe_cat == "monster": safe_cat = "monsters"
                    elif safe_cat == "spell": safe_cat = "spells"
                    elif safe_cat == "class": safe_cat = "classes"
                    elif safe_cat == "race": safe_cat = "races"
                    
                    safe_id = f"lib_{safe_cat}_{res['index']}"
                    item.setData(Qt.ItemDataRole.UserRole, safe_id)
                    
                    widget = EntityListItemWidget("📚 " + res["name"], res_cat, "SRD 5e")
                    item.setSizeHint(widget.sizeHint())
                    self.list_widget.setItemWidget(item, widget)

    def on_item_double_clicked(self, item):
        eid = item.data(Qt.ItemDataRole.UserRole)
        self.item_double_clicked.emit(eid)

    def create_new_entity(self):
        # --- FIX #47: Filtreleri temizle ki yeni öğe görünsün ---
        self.clear_filters() 
        # --------------------------------------------------------
        
        default_data = {"name": "Yeni Varlık", "type": "NPC"}
        new_id = self.dm.save_entity(None, default_data)
        self.refresh_list()
        self.item_double_clicked.emit(new_id)

    def open_api_browser(self):
        # Varsayılan olarak Monster veya ilk aktif kategoriyle aç
        target_cat = "Monster"
        if self.active_categories:
            first = list(self.active_categories)[0]
            # Basit eşleştirme
            if first in ["NPC", "Monster"]: target_cat = "Monster"
            elif first in ["Spell", "Equipment", "Class", "Race"]: target_cat = first
            
        if ApiBrowser(self.dm, target_cat, self).exec():
            self.refresh_list()

    def retranslate_ui(self):
        self.inp_search.setPlaceholderText(tr("LBL_SEARCH"))
        self.refresh_filter_button_style() 
        self.check_show_library.setText(tr("LBL_CHECK_LIBRARY"))
        self.btn_browser.setText(tr("BTN_API_BROWSER"))
        self.btn_add.setText(tr("BTN_NEW_ENTITY"))