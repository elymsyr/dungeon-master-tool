import os
import uuid
from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton, 
                             QFileDialog, QFrame, QMessageBox, QInputDialog, QLabel,
                             QColorDialog)
from PyQt6.QtGui import QPixmap, QColor, QPainter, QImage
from PyQt6.QtCore import Qt, QRectF
from ui.widgets.map_viewer import MapViewer, MapPinItem, TimelinePinItem
from ui.dialogs.timeline_entry import TimelineEntryDialog
from core.locales import tr

class MapTab(QWidget):
    def __init__(self, data_manager, player_window, main_window_ref):
        super().__init__()
        self.dm = data_manager
        self.player_window = player_window
        self.main_window_ref = main_window_ref
        
        self.show_timeline = False
        self.pending_parent_id = None
        
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout(self)
        toolbar = QHBoxLayout()
        
        self.btn_load_map = QPushButton(tr("BTN_LOAD_MAP"))
        self.btn_load_map.clicked.connect(self.upload_map_image)
        
        self.btn_toggle_timeline = QPushButton("⏳ Timeline: OFF")
        self.btn_toggle_timeline.setCheckable(True)
        self.btn_toggle_timeline.clicked.connect(self.toggle_timeline_mode)
        
        self.btn_show_map_pl = QPushButton(tr("BTN_PROJECT_MAP"))
        self.btn_show_map_pl.setObjectName("primaryBtn")
        self.btn_show_map_pl.clicked.connect(self.push_map_to_player)
        
        toolbar.addWidget(self.btn_load_map)
        toolbar.addWidget(self.btn_toggle_timeline)
        toolbar.addStretch()
        toolbar.addWidget(self.btn_show_map_pl)
        
        viewer_frame = QFrame()
        viewer_frame.setStyleSheet("background-color: #111; border: 1px solid #444;")
        v_layout = QVBoxLayout(viewer_frame)
        v_layout.setContentsMargins(0,0,0,0)
        
        self.map_viewer = MapViewer()
        self.map_viewer.setStyleSheet("border: none;")
        self.map_viewer.pin_created_signal.connect(self.handle_canvas_click) 
        self.map_viewer.pin_moved_signal.connect(self.handle_pin_moved)
        self.map_viewer.timeline_moved_signal.connect(self.handle_timeline_moved)
        
        v_layout.addWidget(self.map_viewer)
        layout.addLayout(toolbar)
        layout.addWidget(viewer_frame)

    def retranslate_ui(self):
        self.btn_load_map.setText(tr("BTN_LOAD_MAP"))
        self.btn_show_map_pl.setText(tr("BTN_PROJECT_MAP"))
        state = "ON" if self.show_timeline else "OFF"
        self.btn_toggle_timeline.setText(tr("BTN_TOGGLE_TIMELINE", state=state))

    def toggle_timeline_mode(self):
        self.show_timeline = self.btn_toggle_timeline.isChecked()
        state = "ON" if self.show_timeline else "OFF"
        self.btn_toggle_timeline.setText(tr("BTN_TOGGLE_TIMELINE", state=state))
        
        if self.show_timeline:
            self.btn_toggle_timeline.setStyleSheet("background-color: #ffb300; color: black; font-weight: bold;")
        else:
            self.btn_toggle_timeline.setStyleSheet("")
            
        self.pending_parent_id = None
        self.render_map()

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
        
        # 1. Normal Pinler
        for pin in pins:
            if pin["entity_id"] in entities:
                ent = entities[pin["entity_id"]]
                
                default_color = "#007acc"
                if ent["type"] == "NPC": default_color = "#ff9800"
                elif ent["type"] == "Location": default_color = "#2e7d32"
                elif ent["type"] == "Monster": default_color = "#d32f2f"
                elif ent["type"] == "Player": default_color = "#4caf50"
                
                final_color = pin.get("color") if pin.get("color") else default_color
                
                pin_id = pin.get("id")
                if not pin_id: pin_id = str(uuid.uuid4())
                
                pin_item = MapPinItem(
                    pin["x"], pin["y"], 24, final_color, 
                    pin_id, pin["entity_id"], ent["name"], 
                    pin.get("note", ""), 
                    self.on_pin_action
                )
                self.map_viewer.add_pin_object(pin_item)

        # 2. Timeline Pinleri
        if self.show_timeline:
            timeline_data = self.dm.data["map_data"].get("timeline", [])
            self.map_viewer.draw_timeline_connections(timeline_data)
            
            for t_pin in timeline_data:
                # Çoklu Karakter İsimlerini Birleştir
                ent_names = []
                if t_pin.get("entity_ids"):
                    for eid in t_pin["entity_ids"]:
                        if eid in entities: ent_names.append(entities[eid]["name"])
                elif t_pin.get("entity_id") and t_pin["entity_id"] in entities:
                    ent_names.append(entities[t_pin["entity_id"]]["name"])
                
                display_name_str = ", ".join(ent_names) if ent_names else None

                item = TimelinePinItem(
                    t_pin["x"], t_pin["y"], 
                    t_pin["day"], t_pin["note"], 
                    t_pin["id"], 
                    display_name_str,
                    t_pin.get("color"),
                    t_pin.get("session_id"), # Oturum ID'si burada gönderiliyor
                    self.on_timeline_action
                )
                self.map_viewer.add_timeline_object(item)

    def handle_canvas_click(self, x, y):
        if self.show_timeline:
            parent_id = self.pending_parent_id
            
            if parent_id:
                # Hızlı Bağlantılı Ekleme
                parent_pin = self.dm.get_timeline_pin(parent_id)
                new_day = parent_pin['day'] if parent_pin else 1
                parent_color = parent_pin.get('color') if parent_pin else None
                
                self.dm.add_timeline_pin(
                    x, y, 
                    day=new_day, 
                    note=tr("LBL_NEW_EVENT"), 
                    parent_id=parent_id,
                    entity_ids=[],
                    color=parent_color,
                    session_id=None
                )
                self.pending_parent_id = None
                self.render_map()
            else:
                # Yeni Ekleme (Dialog ile)
                dlg = TimelineEntryDialog(self.dm, default_day=1, default_note="", parent=self)
                if dlg.exec():
                    data = dlg.get_data()
                    self.dm.add_timeline_pin(
                        x, y, 
                        data["day"], 
                        data["note"], 
                        parent_id=None, 
                        entity_ids=data["entity_ids"],
                        session_id=data["session_id"]
                    )
                    self.render_map()
        else:
            self.handle_new_entity_pin(x, y)

    def handle_new_entity_pin(self, x, y):
        entities = self.dm.data["entities"]
        if not entities: 
            QMessageBox.warning(self, tr("MSG_ERROR"), tr("MSG_ADD_ENTITY_FIRST"))
            return
        items, ids = [], []
        allowed_types = ["NPC", "Monster", "Player", "Location", "Equipment"]
        for eid, data in entities.items():
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

    # --- AKSİYON HANDLERLARI ---

    def on_pin_action(self, action_type, pin_obj):
        if action_type == "inspect":
            if self.main_window_ref:
                self.main_window_ref.tabs.setCurrentIndex(0)
                self.main_window_ref.db_tab.open_entity_tab(pin_obj.entity_id)
        
        elif action_type == "edit_note":
            current_note = pin_obj.note
            text, ok = QInputDialog.getMultiLineText(self, tr("MENU_EDIT_NOTE"), tr("LBL_NOTE_TITLE"), text=current_note)
            if ok:
                self.dm.update_map_pin(pin_obj.pin_id, note=text)
                self.render_map()

        elif action_type == "change_color":
            col = QColorDialog.getColor()
            if col.isValid():
                self.dm.update_map_pin(pin_obj.pin_id, color=col.name())
                self.render_map()

        elif action_type == "move":
            self.map_viewer.start_move_mode(pin_obj.pin_id, "entity")
            
        elif action_type == "delete":
            if QMessageBox.question(self, tr("BTN_DELETE"), tr("MSG_DELETE_PIN")) == QMessageBox.StandardButton.Yes:
                self.dm.remove_specific_pin(pin_obj.pin_id)
                self.render_map()

    def on_timeline_action(self, action_type, pin_obj):
        if action_type == "goto_session":
            # Oturuma Git
            if self.main_window_ref and pin_obj.session_id:
                # Session Tab (Index 2)
                self.main_window_ref.tabs.setCurrentIndex(2) 
                # Oturumu Yükle
                self.main_window_ref.session_tab.load_session_by_id(pin_obj.session_id)

        elif action_type == "link_new":
            self.pending_parent_id = pin_obj.pin_id
            QMessageBox.information(self, tr("MSG_LINK_MODE_TITLE"), tr("MSG_LINK_MODE_DESC"))
            
        elif action_type == "edit_timeline":
            t_data = self.dm.get_timeline_pin(pin_obj.pin_id)
            if not t_data: return
            
            # Veri Hazırla
            current_ids = t_data.get("entity_ids", [])
            if not current_ids and t_data.get("entity_id"): current_ids = [t_data.get("entity_id")]

            dlg = TimelineEntryDialog(
                self.dm, 
                default_day=t_data["day"], 
                default_note=t_data["note"], 
                selected_ids=current_ids, 
                selected_session_id=t_data.get("session_id"), # Oturum bilgisini geçir
                parent=self
            )
            
            if dlg.exec():
                new_data = dlg.get_data()
                self.dm.update_timeline_pin(
                    pin_obj.pin_id, 
                    new_data["day"], 
                    new_data["note"], 
                    new_data["entity_ids"],
                    new_data["session_id"] # Oturumu güncelle
                )
                self.render_map()
        
        elif action_type == "color_timeline":
            col = QColorDialog.getColor()
            if col.isValid():
                # Tüm zinciri güncelle
                self.dm.update_timeline_chain_color(pin_obj.pin_id, color=col.name())
                self.render_map()

        elif action_type == "move_timeline":
            self.map_viewer.start_move_mode(pin_obj.pin_id, "timeline")
            
        elif action_type == "delete_timeline":
            if QMessageBox.question(self, tr("BTN_DELETE"), tr("MSG_DELETE_TIMELINE")) == QMessageBox.StandardButton.Yes:
                self.dm.remove_timeline_pin(pin_obj.pin_id)
                self.render_map()

    def handle_pin_moved(self, pin_id, new_x, new_y):
        self.dm.move_pin(pin_id, new_x, new_y)
        self.render_map()

    def handle_timeline_moved(self, pin_id, new_x, new_y):
        self.dm.move_timeline_pin(pin_id, new_x, new_y)
        self.render_map()

    def push_map_to_player(self):
        if not self.player_window.isVisible():
            QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_NO_PLAYER_SCREEN"))
            return
        scene_rect = self.map_viewer.scene.itemsBoundingRect()
        if scene_rect.isEmpty(): return
        image = QPixmap(scene_rect.size().toSize())
        image.fill(Qt.GlobalColor.transparent)
        painter = QPainter(image)
        self.map_viewer.scene.render(painter, target=QRectF(image.rect()), source=scene_rect)
        painter.end()
        self.player_window.show_image(image)