import os
import uuid
import time
from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QPushButton, 
                             QFileDialog, QFrame, QMessageBox, QInputDialog, QLabel,
                             QColorDialog, QCheckBox)
from PyQt6.QtGui import QPixmap, QColor, QPainter
from PyQt6.QtCore import Qt, QRectF
from ui.widgets.map_viewer import MapViewer, MapPinItem, TimelinePinItem, TimelineConnectionItem
from ui.dialogs.timeline_entry import TimelineEntryDialog
from ui.dialogs.entity_selector import EntitySelectorDialog
from core.locales import tr
from core.theme_manager import ThemeManager
from config import CACHE_DIR

class MapTab(QWidget):
    def __init__(self, data_manager, player_window, main_window_ref):
        super().__init__()
        self.dm = data_manager
        self.player_window = player_window
        self.main_window_ref = main_window_ref
        self.show_timeline = False
        self.pending_parent_id = None
        
        self.live_map_id = "Live_Map_Projection"
        self.last_projected_path = None
        
        self.active_entity_filters = set()
        
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout(self)
        toolbar = QHBoxLayout()
        
        self.btn_load_map = QPushButton(tr("BTN_LOAD_MAP"))
        self.btn_load_map.clicked.connect(self.upload_map_image)
        
        self.btn_toggle_timeline = QPushButton(tr("BTN_TOGGLE_TIMELINE", state="OFF"))
        self.btn_toggle_timeline.setCheckable(True)
        self.btn_toggle_timeline.clicked.connect(self.toggle_timeline_mode)
        
        self.btn_filter_entities = QPushButton(f"{tr('LBL_ICON_FILTER')} {tr('LBL_FILTER')}")
        self.btn_filter_entities.setToolTip(tr("TIP_FILTER_ENTITY"))
        self.btn_filter_entities.clicked.connect(self.open_entity_filter_dialog)
        
        self.btn_clear_filter = QPushButton(tr("BTN_CLEAR"))
        self.btn_clear_filter.setToolTip(tr("TIP_CLEAR_FILTER"))
        self.btn_clear_filter.setVisible(False)
        p = ThemeManager.get_palette(ThemeManager.get_active_theme() if hasattr(ThemeManager, 'get_active_theme') else "dark")
        self.btn_clear_filter.setStyleSheet(f"color: {p.get('hp_bar_low', '#ef5350')}; font-weight: bold;")
        self.btn_clear_filter.clicked.connect(self.clear_entity_filter)
        
        self.check_timeline_filter = QCheckBox(tr("LBL_SHOW_NON_PLAYER") if hasattr(tr, "LBL_SHOW_NON_PLAYER") else "Show Non-Player Timeline")
        self.check_timeline_filter.setChecked(False) 
        self.check_timeline_filter.stateChanged.connect(self.apply_filters)

        self.check_show_locations = QCheckBox(tr("LBL_SHOW_LOCATIONS") if hasattr(tr, "LBL_SHOW_LOCATIONS") else "Show Map Pins")
        self.check_show_locations.setChecked(True) 
        self.check_show_locations.stateChanged.connect(self.apply_filters)
        
        self.btn_show_map_pl = QPushButton(tr("BTN_PROJECT_MAP"))
        self.btn_show_map_pl.setObjectName("primaryBtn")
        self.btn_show_map_pl.clicked.connect(self.push_map_to_player)
        
        widgets = [self.btn_load_map, self.btn_toggle_timeline, self.btn_filter_entities, self.btn_clear_filter, self.check_timeline_filter, self.check_show_locations]
        for w in widgets: toolbar.addWidget(w)
        toolbar.addStretch(); toolbar.addWidget(self.btn_show_map_pl); layout.addLayout(toolbar)
        
        viewer_frame = QFrame()
        viewer_frame.setStyleSheet("background-color: #111; border: 1px solid #444;")
        v_layout = QVBoxLayout(viewer_frame); v_layout.setContentsMargins(0,0,0,0)
        
        self.map_viewer = MapViewer()
        self.map_viewer.setStyleSheet("border: none;")
        self.map_viewer.pin_created_signal.connect(self.handle_canvas_click) 
        self.map_viewer.pin_moved_signal.connect(self.handle_pin_moved)
        self.map_viewer.timeline_moved_signal.connect(self.handle_timeline_moved)
        self.map_viewer.link_placed_signal.connect(self.handle_quick_link_placement) 
        self.map_viewer.existing_pin_linked_signal.connect(self.handle_existing_pin_link)
        
        # --- SÜRÜKLE BIRAK BAĞLANTISI ---
        self.map_viewer.entity_id_dropped_signal.connect(self.handle_external_drop)
        
        v_layout.addWidget(self.map_viewer)
        layout.addWidget(viewer_frame)

    def handle_external_drop(self, eid, x, y):
        """Dışarıdan sürüklenen varlığı doğrudan haritaya Pin olarak ekler."""
        if eid.startswith("lib_"):
            QMessageBox.information(self, tr("MSG_INFO"), "Please import this item to your world first.")
            return

        if eid in self.dm.data["entities"]:
            # DataManager üzerinden pin ekle
            self.dm.add_pin(x, y, eid)
            self.render_map() # Haritayı yenile

    def retranslate_ui(self):
        self.btn_load_map.setText(tr("BTN_LOAD_MAP"))
        self.btn_show_map_pl.setText(tr("BTN_PROJECT_MAP"))
        self.btn_toggle_timeline.setText(tr("BTN_TOGGLE_TIMELINE"))
        self.check_timeline_filter.setText(tr("LBL_SHOW_NON_PLAYER") if hasattr(tr, "LBL_SHOW_NON_PLAYER") else "Show Non-Player Timeline")
        self.check_show_locations.setText(tr("LBL_SHOW_LOCATIONS") if hasattr(tr, "LBL_SHOW_LOCATIONS") else "Show Map Pins")

    def open_entity_filter_dialog(self):
        dlg = EntitySelectorDialog(self.dm, self)
        dlg.setWindowTitle("Filter Timeline by Entities"); dlg.btn_add.setText("🔍 Filter")
        if dlg.exec():
            if dlg.selected_entities:
                self.active_entity_filters = set(dlg.selected_entities)
                self.btn_filter_entities.setText(f"{tr('LBL_ICON_FILTER')} {tr('LBL_FILTER')} ({len(self.active_entity_filters)})")
                p = ThemeManager.get_palette(ThemeManager.get_active_theme() if hasattr(ThemeManager, 'get_active_theme') else "dark")
                self.btn_filter_entities.setStyleSheet(f"background-color: {p.get('hp_bar_low', '#d32f2f')}; color: white;") 
                self.btn_clear_filter.setVisible(True)
            else: self.clear_entity_filter(); return
            self.apply_filters()

    def clear_entity_filter(self):
        self.active_entity_filters = set(); self.btn_filter_entities.setText(f"{tr('LBL_ICON_FILTER')} {tr('LBL_FILTER')}"); self.btn_filter_entities.setStyleSheet(""); self.btn_clear_filter.setVisible(False); self.apply_filters()

    def apply_filters(self):
        show_non_player_timeline = self.check_timeline_filter.isChecked()
        show_map_pins = self.check_show_locations.isChecked()
        entities = self.dm.data["entities"]; visible_pin_ids = set() 
        def has_player(id_list):
            if not id_list: return False
            for eid in id_list:
                if eid in entities and entities[eid].get("type") == "Player": return True
            return False
        def passes_entity_filter(id_list):
            if not self.active_entity_filters: return True
            if not id_list: return False
            return not set(id_list).isdisjoint(self.active_entity_filters)
        for item in self.map_viewer.scene.items():
            if isinstance(item, TimelinePinItem):
                pin_data = self.dm.get_timeline_pin(item.pin_id)
                if pin_data:
                    ids = pin_data.get("entity_ids", [])
                    if not ids and pin_data.get("entity_id"): ids = [pin_data["entity_id"]]
                    if not passes_entity_filter(ids): item.setVisible(False); continue
                    is_player_related = has_player(ids)
                    if is_player_related: item.setVisible(True); visible_pin_ids.add(item.pin_id)
                    else:
                        item.setVisible(show_non_player_timeline)
                        if show_non_player_timeline: visible_pin_ids.add(item.pin_id)
            elif isinstance(item, MapPinItem): item.setVisible(show_map_pins)
        for item in self.map_viewer.scene.items():
            if isinstance(item, TimelineConnectionItem):
                item.setVisible(item.start_id in visible_pin_ids and item.end_id in visible_pin_ids)
        if self.main_window_ref and hasattr(self.main_window_ref, "projection_manager"):
            pm = self.main_window_ref.projection_manager
            if self.live_map_id in pm.thumbnails: self.push_map_to_player()

    def toggle_timeline_mode(self):
        self.show_timeline = self.btn_toggle_timeline.isChecked()
        self.btn_toggle_timeline.setText(tr("BTN_TOGGLE_TIMELINE"))
        p = ThemeManager.get_palette(ThemeManager.get_active_theme() if hasattr(ThemeManager, 'get_active_theme') else "dark")
        self.btn_toggle_timeline.setStyleSheet(f"background-color: {p.get('hp_bar_med', '#ffb300')}; color: black; font-weight: bold;" if self.show_timeline else "")
        self.pending_parent_id = None; self.render_map()

    def upload_map_image(self):
        fname, _ = QFileDialog.getOpenFileName(self, tr("MSG_SELECT_MAP"), "", "Images (*.png *.jpg *.jpeg *.webp)")
        if fname: self.dm.set_map_image(self.dm.import_image(fname)); self.render_map()

    def render_map(self):
        path = self.dm.get_full_path(self.dm.data["map_data"].get("image_path"))
        if not path or not os.path.exists(path): return
        self.map_viewer.load_map(QPixmap(path))
        pins = self.dm.data["map_data"].get("pins", []); entities = self.dm.data["entities"]
        for pin in pins:
            if pin["entity_id"] in entities:
                ent = entities[pin["entity_id"]]
                col = pin.get("color")
                if not col:
                    p = ThemeManager.get_palette(ThemeManager.get_active_theme() if hasattr(ThemeManager, 'get_active_theme') else "dark")
                    col = p.get("condition_default_bg", "#007acc")
                    if ent["type"] == "NPC": col = p.get("hp_bar_med", "#ff9800")
                    elif ent["type"] == "Location": col = p.get("hp_bar_full", "#2e7d32")
                    elif ent["type"] == "Monster": col = p.get("hp_bar_low", "#d32f2f")
                    elif ent["type"] == "Player": col = p.get("token_border_player", "#4caf50")
                pin_item = MapPinItem(pin["x"], pin["y"], 24, col, pin.get("id", str(uuid.uuid4())), pin["entity_id"], ent["name"], pin.get("note", ""), self.on_pin_action)
                self.map_viewer.add_pin_object(pin_item)
        if self.show_timeline:
            timeline_data = self.dm.data["map_data"].get("timeline", [])
            self.map_viewer.draw_timeline_connections(timeline_data)
            for t in timeline_data:
                names = [entities[eid]["name"] for eid in t.get("entity_ids", []) if eid in entities]
                if not names and t.get("entity_id") in entities: names = [entities[t["entity_id"]]["name"]]
                self.map_viewer.add_timeline_object(TimelinePinItem(t["x"], t["y"], t["day"], t["note"], t["id"], ", ".join(names) if names else None, t.get("color"), t.get("session_id"), self.on_timeline_action))
        self.apply_filters()

    def handle_canvas_click(self, x, y):
        if self.show_timeline:
            dlg = TimelineEntryDialog(self.dm, default_day=1, default_note="", parent=self)
            if dlg.exec():
                d = dlg.get_data(); self.dm.add_timeline_pin(x, y, d["day"], d["note"], entity_ids=d["entity_ids"], session_id=d["session_id"])
                self.render_map()
        else: self.handle_new_entity_pin(x, y)

    def handle_quick_link_placement(self, x, y):
        if not self.pending_parent_id: return
        parent = self.dm.get_timeline_pin(self.pending_parent_id); day = parent['day'] if parent else 1; color = parent.get('color') if parent else None
        self.dm.add_timeline_pin(x, y, day=day, note=tr("LBL_NEW_EVENT"), parent_id=self.pending_parent_id, color=color)
        self.pending_parent_id = None; self.render_map()

    def handle_existing_pin_link(self, target_id):
        if not self.pending_parent_id: return
        if target_id == self.pending_parent_id: 
            QMessageBox.warning(self, tr("MSG_WARNING"), "Cannot link a pin to itself."); self.pending_parent_id = None; return
        timeline = self.dm.data["map_data"]["timeline"]; found = False
        for p in timeline:
            if p["id"] == target_id:
                if "parent_ids" not in p: p["parent_ids"] = []
                if p.get("parent_id") and p["parent_id"] not in p["parent_ids"]: p["parent_ids"].append(p["parent_id"])
                if self.pending_parent_id not in p["parent_ids"]: p["parent_ids"].append(self.pending_parent_id); found = True
                p["parent_id"] = self.pending_parent_id; break
        if found: self.dm.save_data(); self.pending_parent_id = None; self.render_map()

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
        elif action_type == "link_new": self.pending_parent_id = pin_obj.pin_id; self.map_viewer.start_link_mode() 
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
        if not self.player_window.isVisible(): QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_NO_PLAYER_SCREEN")); return
        rect = self.map_viewer.scene.itemsBoundingRect()
        if rect.isEmpty(): return
        img = QPixmap(rect.size().toSize()); img.fill(Qt.GlobalColor.transparent); painter = QPainter(img); self.map_viewer.scene.render(painter, target=QRectF(img.rect()), source=rect); painter.end()
        fake_path = self.live_map_id
        if self.main_window_ref and hasattr(self.main_window_ref, "projection_manager"): self.main_window_ref.projection_manager.add_image(fake_path, pixmap=img)
        else: self.player_window.add_image_to_view(fake_path, pixmap=img)