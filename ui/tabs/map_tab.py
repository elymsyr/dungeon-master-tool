import os
import uuid
from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton, 
                             QFileDialog, QFrame, QMessageBox, QInputDialog)
from PyQt6.QtGui import QPixmap
from ui.widgets.map_viewer import MapViewer, MapPinItem
from core.locales import tr

class MapTab(QWidget):
    def __init__(self, data_manager, player_window, main_window_ref):
        super().__init__()
        self.dm = data_manager
        self.player_window = player_window
        self.main_window_ref = main_window_ref # Veritabanı sekmesine geçiş için ref
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout(self)
        
        # --- Toolbar (Butonlar Burada) ---
        toolbar = QHBoxLayout()
        self.btn_load_map = QPushButton(tr("BTN_LOAD_MAP"))
        self.btn_load_map.clicked.connect(self.upload_map_image)
        
        self.btn_show_map_pl = QPushButton(tr("BTN_PROJECT_MAP"))
        self.btn_show_map_pl.setObjectName("primaryBtn")
        self.btn_show_map_pl.clicked.connect(self.push_map_to_player)
        
        toolbar.addWidget(self.btn_load_map)
        toolbar.addStretch()
        toolbar.addWidget(self.btn_show_map_pl)
        
        # --- Viewer ---
        viewer_frame = QFrame()
        viewer_frame.setStyleSheet("background-color: #111; border: 1px solid #444;")
        v_layout = QVBoxLayout(viewer_frame)
        v_layout.setContentsMargins(0,0,0,0)
        
        self.map_viewer = MapViewer()
        self.map_viewer.setStyleSheet("border: none;")
        self.map_viewer.pin_created_signal.connect(self.handle_new_pin)
        self.map_viewer.pin_moved_signal.connect(self.handle_pin_moved)
        
        v_layout.addWidget(self.map_viewer)
        
        layout.addLayout(toolbar)
        layout.addWidget(viewer_frame)

    def retranslate_ui(self):
        self.btn_load_map.setText(tr("BTN_LOAD_MAP"))
        self.btn_show_map_pl.setText(tr("BTN_PROJECT_MAP"))

    def upload_map_image(self):
        fname, _ = QFileDialog.getOpenFileName(self, tr("MSG_SELECT_MAP"), "", "Images (*.png *.jpg *.jpeg)")
        if fname:
            rel = self.dm.import_image(fname)
            self.dm.set_map_image(rel)
            self.render_map()

    def render_map(self):
        path = self.dm.get_full_path(self.dm.data["map_data"].get("image_path"))
        if not path or not os.path.exists(path): return
        
        self.map_viewer.load_map(QPixmap(path))
        
        pins = self.dm.data["map_data"].get("pins", [])
        entities = self.dm.data["entities"]
        
        for pin in pins:
            if pin["entity_id"] in entities:
                ent = entities[pin["entity_id"]]
                color = "#007acc"
                if ent["type"] == "NPC": color = "#ff9800"
                elif ent["type"] == "Mekan": color = "#2e7d32"
                elif ent["type"] == "Canavar": color = "#d32f2f"
                elif ent["type"] == "Oyuncu": color = "#4caf50"
                
                pin_id = pin.get("id")
                if not pin_id: pin_id = str(uuid.uuid4())
                
                pin_item = MapPinItem(pin["x"], pin["y"], 24, color, pin_id, pin["entity_id"], ent["name"], self.on_pin_action)
                self.map_viewer.add_pin_object(pin_item)

    def push_map_to_player(self):
        if self.player_window.isVisible():
            path = self.dm.get_full_path(self.dm.data["map_data"].get("image_path"))
            self.player_window.show_image(QPixmap(path) if path else None)
        else:
            QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_NO_PLAYER_SCREEN"))

    def handle_new_pin(self, x, y):
        entities = self.dm.data["entities"]
        if not entities: 
            QMessageBox.warning(self, tr("MSG_ERROR"), tr("MSG_ADD_ENTITY_FIRST"))
            return
            
        items, ids = [], []
        
        # --- FİLTRELEME MANTIĞI ---
        # Haritaya sadece fiziksel olarak bulunabilen şeyler eklensin
        allowed_types = ["NPC", "Canavar", "Oyuncu", "Mekan", "Eşya", "Eşya (Equipment)"]
        
        for eid, data in entities.items():
            # Eğer varlığın tipi izin verilenler listesindeyse listeye ekle
            if data.get("type") in allowed_types:
                items.append(f"{data['name']} ({data['type']})")
                ids.append(eid)
        
        if not items:
            QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_NO_ENTITY_FOR_PIN"))
            return
            
        item, ok = QInputDialog.getItem(self, tr("MSG_ADD_PIN"), tr("MSG_SELECT_ENTITY"), items, 0, False)
        if ok and item:
            self.dm.add_pin(x, y, ids[items.index(item)])
            self.render_map()

    def on_pin_action(self, action_type, pin_obj):
        if action_type == "inspect":
            # Ana penceredeki Database tabına geç ve karakteri yükle
            # Bunun için main_window referansına veya signal'e ihtiyacımız var.
            # Şimdilik main_window_ref üzerinden gidelim.
            if self.main_window_ref:
                self.main_window_ref.tabs.setCurrentIndex(0) # Database tab
                self.main_window_ref.db_tab.load_entity_by_id(pin_obj.entity_id)
                
        elif action_type == "move":
            self.map_viewer.start_move_mode(pin_obj.pin_id)
            
        elif action_type == "delete":
            if QMessageBox.question(self, tr("BTN_DELETE"), tr("MSG_DELETE_PIN")) == QMessageBox.StandardButton.Yes:
                self.dm.remove_specific_pin(pin_obj.pin_id)
                self.render_map()

    def handle_pin_moved(self, pin_id, new_x, new_y):
        self.dm.move_pin(pin_id, new_x, new_y)
        self.render_map()