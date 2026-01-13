import os
import uuid
import time
from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton, 
                             QFileDialog, QFrame, QMessageBox, QInputDialog, QLabel,
                             QColorDialog, QCheckBox)
from PyQt6.QtGui import QPixmap, QColor, QPainter
from PyQt6.QtCore import Qt, QRectF
from ui.widgets.map_viewer import MapViewer, MapPinItem, TimelinePinItem
from ui.dialogs.timeline_entry import TimelineEntryDialog
from core.locales import tr
from config import CACHE_DIR

class MapTab(QWidget):
    def __init__(self, data_manager, player_window, main_window_ref):
        super().__init__()
        self.dm = data_manager
        self.player_window = player_window
        self.main_window_ref = main_window_ref
        self.show_timeline = False
        self.pending_parent_id = None
        
        self.last_projected_path = None
        
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout(self); toolbar = QHBoxLayout()
        self.btn_load_map = QPushButton(tr("BTN_LOAD_MAP")); self.btn_load_map.clicked.connect(self.upload_map_image)
        self.btn_toggle_timeline = QPushButton(tr("BTN_TOGGLE_TIMELINE", state="OFF")); self.btn_toggle_timeline.setCheckable(True)
        self.btn_toggle_timeline.clicked.connect(self.toggle_timeline_mode)
        
        # --- FILTER 1: TIMELINE (Show Non-Player) ---
        self.check_timeline_filter = QCheckBox(tr("LBL_SHOW_NON_PLAYER") if hasattr(tr, "LBL_SHOW_NON_PLAYER") else "Show Non-Player Timeline")
        self.check_timeline_filter.setToolTip("If checked, reveals timeline events that do not involve players.")
        self.check_timeline_filter.setChecked(False) 
        self.check_timeline_filter.stateChanged.connect(self.apply_filters)

        # --- FILTER 2: MAP PINS (Show Locations) ---
        self.check_show_locations = QCheckBox(tr("LBL_SHOW_LOCATIONS") if hasattr(tr, "LBL_SHOW_LOCATIONS") else "Show Map Pins")
        self.check_show_locations.setToolTip("Show/Hide entity icons (Locations, NPCs) on the map.")
        self.check_show_locations.setChecked(True) 
        self.check_show_locations.stateChanged.connect(self.apply_filters)
        
        self.btn_show_map_pl = QPushButton(tr("BTN_PROJECT_MAP")); self.btn_show_map_pl.setObjectName("primaryBtn")
        self.btn_show_map_pl.clicked.connect(self.push_map_to_player)
        
        for w in [self.btn_load_map, self.btn_toggle_timeline, self.check_timeline_filter, self.check_show_locations]: 
            toolbar.addWidget(w)
        
        toolbar.addStretch(); toolbar.addWidget(self.btn_show_map_pl); layout.addLayout(toolbar)
        viewer_frame = QFrame(); viewer_frame.setStyleSheet("background-color: #111; border: 1px solid #444;")
        v_layout = QVBoxLayout(viewer_frame); v_layout.setContentsMargins(0,0,0,0)
        self.map_viewer = MapViewer(); self.map_viewer.setStyleSheet("border: none;")
        self.map_viewer.pin_created_signal.connect(self.handle_canvas_click) 
        self.map_viewer.pin_moved_signal.connect(self.handle_pin_moved)
        self.map_viewer.timeline_moved_signal.connect(self.handle_timeline_moved)
        self.map_viewer.link_placed_signal.connect(self.handle_quick_link_placement) 
        v_layout.addWidget(self.map_viewer); layout.addWidget(viewer_frame)

    def retranslate_ui(self):
        self.btn_load_map.setText(tr("BTN_LOAD_MAP")); self.btn_show_map_pl.setText(tr("BTN_PROJECT_MAP"))
        st = "ON" if self.show_timeline else "OFF"; self.btn_toggle_timeline.setText(tr("BTN_TOGGLE_TIMELINE", state=st))
        self.check_timeline_filter.setText(tr("LBL_SHOW_NON_PLAYER") if hasattr(tr, "LBL_SHOW_NON_PLAYER") else "Show Non-Player Timeline")
        self.check_show_locations.setText(tr("LBL_SHOW_LOCATIONS") if hasattr(tr, "LBL_SHOW_LOCATIONS") else "Show Map Pins")

    def apply_filters(self):
        """
        Applies visibility logic and auto-updates the projection if active.
        """
        show_non_player_timeline = self.check_timeline_filter.isChecked()
        show_map_pins = self.check_show_locations.isChecked()
        
        entities = self.dm.data["entities"]
        
        def has_player(id_list):
            if not id_list: return False
            for eid in id_list:
                if eid in entities and entities[eid].get("type") == "Player":
                    return True
            return False

        for item in self.map_viewer.scene.items():
            # 1. Timeline Pins
            if isinstance(item, TimelinePinItem):
                pin_data = self.dm.get_timeline_pin(item.pin_id)
                if pin_data:
                    ids = pin_data.get("entity_ids", [])
                    if not ids and pin_data.get("entity_id"): ids = [pin_data["entity_id"]]
                    is_player_related = has_player(ids)
                    if is_player_related:
                        item.setVisible(True)
                    else:
                        item.setVisible(show_non_player_timeline)
            
            # 2. Map Pins
            elif isinstance(item, MapPinItem):
                item.setVisible(show_map_pins)

        # --- AUTO UPDATE PROJECTION ---
        # If we have a previously projected map, and it is still in the Projection Manager, update it.
        if self.main_window_ref and hasattr(self.main_window_ref, "projection_manager"):
            pm = self.main_window_ref.projection_manager
            if self.last_projected_path and self.last_projected_path in pm.thumbnails:
                self.push_map_to_player()

    def toggle_timeline_mode(self):
        self.show_timeline = self.btn_toggle_timeline.isChecked(); st = "ON" if self.show_timeline else "OFF"
        self.btn_toggle_timeline.setText(tr("BTN_TOGGLE_TIMELINE", state=st))
        self.btn_toggle_timeline.setStyleSheet("background-color: #ffb300; color: black; font-weight: bold;" if self.show_timeline else "")
        self.pending_parent_id = None; self.render_map()

    def upload_map_image(self):
        fname, _ = QFileDialog.getOpenFileName(self, tr("MSG_SELECT_MAP"), "", "Images (*.png *.jpg *.jpeg)")
        if fname: self.dm.set_map_image(self.dm.import_image(fname)); self.render_map()

    def render_map(self):
        path = self.dm.get_full_path(self.dm.data["map_data"].get("image_path"))
        if not path or not os.path.exists(path): return
        self.map_viewer.load_map(QPixmap(path))
        
        pins = self.dm.data["map_data"].get("pins", []); entities = self.dm.data["entities"]
        
        for pin in pins:
            if pin["entity_id"] in entities:
                ent = entities[pin["entity_id"]]; default_color = "#007acc"
                if ent["type"] == "NPC": default_color = "#ff9800"
                elif ent["type"] == "Location": default_color = "#2e7d32"
                elif ent["type"] == "Monster": default_color = "#d32f2f"
                elif ent["type"] == "Player": default_color = "#4caf50"
                col = pin.get("color") if pin.get("color") else default_color
                
                pin_item = MapPinItem(pin["x"], pin["y"], 24, col, pin.get("id", str(uuid.uuid4())), pin["entity_id"], ent["name"], pin.get("note", ""), self.on_pin_action)
                self.map_viewer.add_pin_object(pin_item)
                
        if self.show_timeline:
            timeline_data = self.dm.data["map_data"].get("timeline", [])
            self.map_viewer.draw_timeline_connections(timeline_data)
            for t in timeline_data:
                names = [entities[eid]["name"] for eid in t.get("entity_ids", []) if eid in entities]
                if not names and t.get("entity_id") in entities: names = [entities[t["entity_id"]]["name"]]
                self.map_viewer.add_timeline_object(TimelinePinItem(t["x"], t["y"], t["day"], t["note"], t["id"], ", ".join(names) if names else None, t.get("color"), t.get("session_id"), self.on_timeline_action))

        # Apply current filter state (and auto-update projection)
        self.apply_filters()

    def handle_canvas_click(self, x, y):
        if self.show_timeline:
            dlg = TimelineEntryDialog(self.dm, default_day=1, default_note="", parent=self)
            if dlg.exec():
                d = dlg.get_data(); self.dm.add_timeline_pin(x, y, d["day"], d["note"], entity_ids=d["entity_ids"], session_id=d["session_id"]); self.render_map()
        else: self.handle_new_entity_pin(x, y)

    def handle_quick_link_placement(self, x, y):
        if not self.pending_parent_id: return
        parent = self.dm.get_timeline_pin(self.pending_parent_id)
        day = parent['day'] if parent else 1; color = parent.get('color') if parent else None
        self.dm.add_timeline_pin(x, y, day=day, note=tr("LBL_NEW_EVENT"), parent_id=self.pending_parent_id, color=color)
        self.pending_parent_id = None; self.render_map()

    def handle_new_entity_pin(self, x, y):
        entities = self.dm.data["entities"]
        if not entities: QMessageBox.warning(self, tr("MSG_ERROR"), tr("MSG_ADD_ENTITY_FIRST")); return
        items, ids = [], []
        for eid, data in entities.items():
            if data.get("type") in ["NPC", "Monster", "Player", "Location", "Equipment"]: items.append(f"{data['name']} ({data['type']})"); ids.append(eid)
        if not items: QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_NO_ENTITY_FOR_PIN")); return
        item, ok = QInputDialog.getItem(self, tr("MSG_ADD_PIN"), tr("MSG_SELECT_ENTITY"), items, 0, False)
        if ok and item: self.dm.add_pin(x, y, ids[items.index(item)]); self.render_map()

    def on_pin_action(self, action_type, pin_obj):
        if action_type == "inspect":
            if self.main_window_ref: self.main_window_ref.tabs.setCurrentIndex(0); self.main_window_ref.db_tab.open_entity_tab(pin_obj.entity_id)
        elif action_type == "edit_note":
            text, ok = QInputDialog.getMultiLineText(self, tr("MENU_EDIT_NOTE"), tr("LBL_NOTE_TITLE"), text=pin_obj.note)
            if ok: self.dm.update_map_pin(pin_obj.pin_id, note=text); self.render_map()
        elif action_type == "change_color":
            col = QColorDialog.getColor()
            if col.isValid(): self.dm.update_map_pin(pin_obj.pin_id, color=col.name()); self.render_map()
        elif action_type == "move": self.map_viewer.start_move_mode(pin_obj.pin_id, "entity")
        elif action_type == "delete":
            if QMessageBox.question(self, tr("BTN_DELETE"), tr("MSG_DELETE_PIN")) == QMessageBox.StandardButton.Yes: self.dm.remove_specific_pin(pin_obj.pin_id); self.render_map()

    def on_timeline_action(self, action_type, pin_obj):
        if action_type == "goto_session":
            if self.main_window_ref and pin_obj.session_id: self.main_window_ref.tabs.setCurrentIndex(2); self.main_window_ref.session_tab.load_session_by_id(pin_obj.session_id)
        elif action_type == "link_new":
            self.pending_parent_id = pin_obj.pin_id
            self.map_viewer.start_link_mode() 
        elif action_type == "edit_timeline":
            t = self.dm.get_timeline_pin(pin_obj.pin_id)
            if not t: return
            ids = t.get("entity_ids", []); 
            if not ids and t.get("entity_id"): ids = [t["entity_id"]]
            dlg = TimelineEntryDialog(self.dm, default_day=t["day"], default_note=t["note"], selected_ids=ids, selected_session_id=t.get("session_id"), parent=self)
            if dlg.exec():
                d = dlg.get_data(); self.dm.update_timeline_pin(pin_obj.pin_id, d["day"], d["note"], d["entity_ids"], d["session_id"]); self.render_map()
        elif action_type == "color_timeline":
            col = QColorDialog.getColor()
            if col.isValid(): self.dm.update_timeline_chain_color(pin_obj.pin_id, color=col.name()); self.render_map()
        elif action_type == "move_timeline": self.map_viewer.start_move_mode(pin_obj.pin_id, "timeline")
        elif action_type == "delete_timeline":
            if QMessageBox.question(self, tr("BTN_DELETE"), tr("MSG_DELETE_TIMELINE")) == QMessageBox.StandardButton.Yes: self.dm.remove_timeline_pin(pin_obj.pin_id); self.render_map()

    def handle_pin_moved(self, pin_id, new_x, new_y): self.dm.move_pin(pin_id, new_x, new_y); self.render_map()
    def handle_timeline_moved(self, pin_id, new_x, new_y): self.dm.move_timeline_pin(pin_id, new_x, new_y); self.render_map()

    def push_map_to_player(self):
        """
        Projects map to player screen. Uses UUID to avoid filename collisions during rapid auto-updates.
        """
        if not self.player_window.isVisible():
            QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_NO_PLAYER_SCREEN"))
            return
            
        rect = self.map_viewer.scene.itemsBoundingRect()
        if rect.isEmpty(): return
        
        # Haritayı bir resim (QPixmap) olarak oluştur
        img = QPixmap(rect.size().toSize())
        img.fill(Qt.GlobalColor.transparent)
        painter = QPainter(img)
        self.map_viewer.scene.render(painter, target=QRectF(img.rect()), source=rect)
        painter.end()
        
        # Sanal bir ID (UUID)
        fake_path = f"map_snapshot_{uuid.uuid4().hex}.png"
        
        if self.main_window_ref and hasattr(self.main_window_ref, "projection_manager"):
            # Eğer daha önce bir harita yansıtılmışsa, ekranı kalabalıklaştırmamak için eskisini kaldırıyoruz
            if self.last_projected_path:
                self.main_window_ref.projection_manager.remove_image(self.last_projected_path)
            
            # Yeni haritayı ekliyoruz
            self.main_window_ref.projection_manager.add_image(fake_path, pixmap=img)
            self.last_projected_path = fake_path
        else:
            self.player_window.add_image_to_view(fake_path, pixmap=img)