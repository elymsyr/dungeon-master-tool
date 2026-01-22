import uuid
from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QGraphicsView, 
                             QGraphicsScene, QPushButton, QSplitter, QFrame, 
                             QGraphicsItem, QMessageBox, QGridLayout, QMenu, QGraphicsProxyWidget)
from PyQt6.QtGui import QBrush, QColor, QPainter, QCursor, QPen, QPixmap, QAction
from PyQt6.QtCore import Qt, QRectF, QPointF, QTimer

from ui.widgets.markdown_editor import MarkdownEditor
from ui.widgets.npc_sheet import NpcSheet
from ui.widgets.aspect_ratio_label import AspectRatioLabel
from ui.widgets.mind_map_items import MindMapNode, ConnectionLine
from core.locales import tr
from core.theme_manager import ThemeManager

class MindMapScene(QGraphicsScene):
    def __init__(self, parent=None):
        super().__init__(parent)
        # Başlangıçta varsayılan palet (Dark)
        self.current_palette = ThemeManager.get_palette("dark")
        self.apply_palette_bg()
        self.grid_mode = True

    def set_palette(self, palette):
        """Temayı günceller."""
        self.current_palette = palette
        self.apply_palette_bg()
        self.update() # Redraw trigger

    def apply_palette_bg(self):
        bg_color = self.current_palette.get("canvas_bg", "#181818")
        self.setBackgroundBrush(QBrush(QColor(bg_color)))

    def drawBackground(self, painter, rect):
        super().drawBackground(painter, rect)
        if not self.grid_mode: return
        
        # Grid rengini paletten al
        grid_rgba = self.current_palette.get("grid_color", "rgba(255, 255, 255, 10)")
        # Eğer string "rgba(...)" formatındaysa QColor bunu direkt anlamayabilir, 
        # ancak QColor("#hex") formatı kesin çalışır. 
        # ThemeManager'da renkleri QColor'ın anlayacağı formatta (Hex veya isim) tutmak en iyisidir.
        # Eğer rgba fonksiyonu string olarak geliyorsa burada manuel parse gerekebilir 
        # ama QColor kurucusu genellikle CSS formatlarını destekler.
        # Güvenlik için ThemeManager'da renkleri Hex ve Alpha kanalı olarak tutmak daha iyidir.
        # Şimdilik QColor(string) deniyoruz.
        
        grid_color = QColor(grid_rgba)
        if not grid_color.isValid():
            grid_color = QColor(255, 255, 255, 10) # Fallback

        grid_size = 40
        left = int(rect.left()) - (int(rect.left()) % grid_size)
        top = int(rect.top()) - (int(rect.top()) % grid_size)
        points = []
        for x in range(left, int(rect.right()), grid_size):
            for y in range(top, int(rect.bottom()), grid_size):
                points.append(QPointF(x, y))
        
        painter.setPen(QPen(grid_color, 2)) 
        painter.drawPoints(points)

class CustomGraphicsView(QGraphicsView):
    def __init__(self, scene, parent_tab):
        super().__init__(scene)
        self.parent_tab = parent_tab
        self.setRenderHint(QPainter.RenderHint.Antialiasing)
        self.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)
        self.setDragMode(QGraphicsView.DragMode.ScrollHandDrag)
        self.setTransformationAnchor(QGraphicsView.ViewportAnchor.AnchorUnderMouse)
        self.setResizeAnchor(QGraphicsView.ViewportAnchor.AnchorUnderMouse)
        self.setAcceptDrops(True)
        self.setStyleSheet("border: none; background: transparent;")
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)

    def contextMenuEvent(self, event):
        item = self.itemAt(event.pos())
        if not item:
            self.parent_tab.show_canvas_context_menu(event.globalPos(), self.mapToScene(event.pos()))
        else:
            super().contextMenuEvent(event)

    def wheelEvent(self, event):
        item = self.itemAt(event.position().toPoint())
        if isinstance(item, QGraphicsProxyWidget):
            event.ignore()
            return 
        
        zoom_in = 1.15
        zoom_out = 1 / 1.15
        if event.angleDelta().y() > 0: self.scale(zoom_in, zoom_in)
        else: self.scale(zoom_out, zoom_out)

    def dragEnterEvent(self, event):
        if event.mimeData().hasText(): event.accept()
        else: event.ignore()

    def dragMoveEvent(self, event): event.accept()

    def dropEvent(self, event):
        eid = event.mimeData().text()
        pos = self.mapToScene(event.position().toPoint())
        self.parent_tab.create_entity_node(eid, pos.x(), pos.y())
        event.accept()

class FloatingControls(QWidget):
    def __init__(self, view_ref, parent_tab, parent=None):
        super().__init__(parent)
        self.view = view_ref
        self.parent_tab = parent_tab
        
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(8)
        
        self.btn_in = self._create_btn("Zoom In", lambda: self.view.scale(1.2, 1.2), "Yakınlaş")
        self.btn_out = self._create_btn("Zoom Out", lambda: self.view.scale(1/1.2, 1/1.2), "Uzaklaş")
        self.btn_center = self._create_btn("Center", lambda: self.view.centerOn(0, 0), "Merkeze Git (0,0)")
        self.btn_fit = self._create_btn("See All", self.parent_tab.fit_all_content, "Tümünü Ekrana Sığdır")
        
        layout.addWidget(self.btn_in)
        layout.addWidget(self.btn_out)
        layout.addWidget(self.btn_center)
        layout.addWidget(self.btn_fit)
        
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)

    def _create_btn(self, text, func, tip):
        btn = QPushButton(text)
        btn.setFixedSize(80, 30)
        btn.setToolTip(tip)
        btn.clicked.connect(func)
        btn.setCursor(Qt.CursorShape.PointingHandCursor)
        btn.setStyleSheet("""
            QPushButton { 
                background-color: rgba(40, 40, 40, 230); 
                color: #eee; 
                border: 1px solid #555; 
                border-radius: 6px; 
                font-size: 11px; 
                font-weight: bold;
                font-family: 'Segoe UI', sans-serif;
            } 
            QPushButton:hover { 
                background-color: #42a5f5; 
                border-color: #42a5f5; 
                color: white; 
            }
        """)
        return btn

class MindMapTab(QWidget):
    def __init__(self, data_manager, main_window_ref=None):
        super().__init__()
        self.dm = data_manager
        self.main_window_ref = main_window_ref
        self.player_window = main_window_ref.player_window if main_window_ref else None
        
        self.nodes = {} 
        self.connections = [] 
        self.pending_connection_source = None
        self.current_map_id = "default"
        
        self.autosave_timer = QTimer()
        self.autosave_timer.setSingleShot(True)
        self.autosave_timer.setInterval(2000) 
        self.autosave_timer.timeout.connect(self.save_map_data_silent)
        
        self.entity_autosave_timer = QTimer()
        self.entity_autosave_timer.setSingleShot(True)
        self.entity_autosave_timer.setInterval(1000)
        self.entity_autosave_timer.timeout.connect(self.process_pending_entity_saves)
        self.pending_entity_saves = set()
        
        self.init_ui()
        
        # Tema başlangıcı
        current_theme = self.dm.current_theme # "dark", "ocean" vb.
        self.apply_theme(current_theme)
        
        self.load_map_data()

    def init_ui(self):
        main_layout = QHBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0); main_layout.setSpacing(0)
        
        canvas_container = QWidget()
        canvas_layout = QVBoxLayout(canvas_container)
        canvas_layout.setContentsMargins(0, 0, 0, 0); canvas_layout.setSpacing(0)
        
        self.scene = MindMapScene()
        self.scene.setSceneRect(-100000, -100000, 200000, 200000)
        
        self.view = CustomGraphicsView(self.scene, self)
        canvas_layout.addWidget(self.view)
        
        self.floating_controls = FloatingControls(self.view, self, self.view)
        
        overlay_layout = QGridLayout(self.view)
        overlay_layout.setContentsMargins(0, 0, 20, 20)
        overlay_layout.addWidget(self.floating_controls, 1, 1, Qt.AlignmentFlag.AlignBottom | Qt.AlignmentFlag.AlignRight)
        
        self.lbl_save_status = QPushButton("💾 Saved", self.view)
        self.lbl_save_status.setFixedSize(80, 25)
        self.lbl_save_status.setStyleSheet("background: rgba(0, 0, 0, 100); color: #81c784; border-radius: 4px; border: none; font-size: 11px;")
        self.lbl_save_status.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        overlay_layout.addWidget(self.lbl_save_status, 0, 1, Qt.AlignmentFlag.AlignTop | Qt.AlignmentFlag.AlignRight)

        main_layout.addWidget(canvas_container)

    def apply_theme(self, theme_name):
        """
        Main Window tarafından çağrılır.
        Tüm sahne ve öğelerin rengini ThemeManager'dan çekilen palete göre günceller.
        """
        palette = ThemeManager.get_palette(theme_name)
        
        # 1. Sahne Arka Planı
        self.scene.set_palette(palette)
        
        # 2. Mevcut Node'lar
        for node in self.nodes.values():
            node.update_theme(palette)
            
        # 3. Bağlantılar
        for conn in self.connections:
            conn.update_theme(palette)

    def fit_all_content(self):
        items_rect = self.scene.itemsBoundingRect()
        if items_rect.isEmpty():
            return
        self.view.fitInView(items_rect, Qt.AspectRatioMode.KeepAspectRatio)

    def handle_projection_request(self, node):
        self.project_node_content(node)

    def project_node_content(self, node):
        if self.main_window_ref and not self.main_window_ref.player_window.isVisible():
            self.main_window_ref.toggle_player_window()

        full_path = None
        if node.node_type == "image":
            path = node.extra_data.get("path")
            full_path = self.dm.get_full_path(path)
        
        elif node.node_type == "entity":
            eid = node.extra_data.get("eid")
            if eid in self.dm.data["entities"]:
                ent = self.dm.data["entities"][eid]
                img_path = ent.get("image_path") or (ent.get("images")[0] if ent.get("images") else None)
                if img_path:
                    full_path = self.dm.get_full_path(img_path)
                else:
                    QMessageBox.information(self, "Bilgi", "Bu varlığın gösterilecek bir resmi yok.")

        if full_path and self.main_window_ref:
            self.main_window_ref.projection_manager.add_image(full_path)

    def show_canvas_context_menu(self, global_pos, scene_pos):
        menu = QMenu()
        menu.setStyleSheet("QMenu { background-color: #333; color: white; border: 1px solid #555; font-size: 14px; padding: 5px; } QMenu::item { padding: 5px 20px; } QMenu::item:selected { background-color: #42a5f5; }")
        
        act_note = QAction("📝 Not Ekle", self)
        act_note.triggered.connect(lambda: self.create_note_node(None, scene_pos.x(), scene_pos.y(), 250, 200, ""))
        
        act_img = QAction("🖼️ Resim Ekle", self)
        act_img.triggered.connect(lambda: self.add_image_at_pos(scene_pos))
        
        menu.addAction(act_note)
        menu.addAction(act_img)
        menu.exec(global_pos)

    def add_image_at_pos(self, scene_pos):
        from PyQt6.QtWidgets import QFileDialog
        f, _ = QFileDialog.getOpenFileName(self, "Resim Seç", "", "Images (*.png *.jpg *.jpeg *.webp)")
        if f:
            path = self.dm.import_image(f)
            self.create_image_node(None, scene_pos.x(), scene_pos.y(), 300, 300, path)

    def create_node_base(self, node_id, widget, x, y, w, h, node_type, extra_data=None):
        node = MindMapNode(node_id, widget, w, h, node_type, extra_data)
        node.setPos(x, y)
        
        # Node'u oluştururken mevcut temayı uygula
        current_theme_name = self.dm.current_theme
        node.update_theme(ThemeManager.get_palette(current_theme_name))
        
        node.requestConnection.connect(self.handle_connection_request)
        node.nodeDeleted.connect(self.delete_node)
        
        node.positionChanged.connect(self.update_connections)
        node.positionChanged.connect(self.trigger_autosave)
        node.sizeChanged.connect(self.trigger_autosave)
        
        node.requestProjection.connect(self.handle_projection_request) 
        
        self.scene.addItem(node)
        self.nodes[node.node_id] = node
        
        self.trigger_autosave()
        return node

    def create_note_node(self, node_id, x, y, w, h, content):
        editor = MarkdownEditor(text=content, placeholder="Not al...")
        editor.set_data_manager(self.dm)
        editor.textChanged.connect(self.trigger_autosave)
        editor.set_mind_map_style() 
        
        node = self.create_node_base(node_id, editor, x, y, w, h, "note")
        return node

    def create_image_node(self, node_id, x, y, w, h, path):
        lbl = AspectRatioLabel()
        lbl.setStyleSheet("background: transparent; border: none;") 
        full_path = self.dm.get_full_path(path)
        if full_path: lbl.setPixmap(QPixmap(full_path))
        node = self.create_node_base(node_id, lbl, x, y, w, h, "image", {"path": path})
        return node

    def create_entity_node(self, eid, x, y, w=550, h=700): 
        if eid not in self.dm.data["entities"]: return
        ent_data = self.dm.data["entities"][eid]
        
        sheet = NpcSheet(self.dm)
        sheet.setProperty("entity_id", eid)
        sheet.populate_sheet(ent_data)
        sheet.set_embedded_mode(True)
        
        sheet.data_changed.connect(lambda: self.schedule_entity_autosave(sheet))
        
        # NpcSheet stili: ThemeManager bunu handle edebilir ama QSS de lazım.
        # Burada basitçe sabit renkleri siliyoruz, çünkü MindMapNode artık arka plan rengini çiziyor.
        # Ancak Sheet içindeki inputların şeffaf olması gerekir.
        sheet.setStyleSheet("""
            QWidget#sheetContainer { background-color: transparent; }
            QLineEdit, QTextEdit, QPlainTextEdit { background-color: rgba(0,0,0,0.2); border: 1px solid rgba(128,128,128,0.3); }
        """)
        
        node = self.create_node_base(None, sheet, x, y, w, h, "entity", {"eid": eid})
        return node

    def schedule_entity_autosave(self, sheet):
        self.pending_entity_saves.add(sheet)
        self.lbl_save_status.setText("✏️ Editing...")
        self.lbl_save_status.setStyleSheet("background: rgba(0, 0, 0, 100); color: #ffb74d; border-radius: 4px; border: none; font-size: 11px;")
        self.entity_autosave_timer.start()

    def process_pending_entity_saves(self):
        for sheet in list(self.pending_entity_saves):
            try:
                if not sheet.isVisible() and not sheet.parent(): continue
                eid = sheet.property("entity_id")
                data = sheet.collect_data_from_sheet()
                if eid and data:
                    self.dm.save_entity(eid, data)
                    sheet.is_dirty = False
            except: pass
        self.pending_entity_saves.clear()
        self.lbl_save_status.setText("💾 Saved")
        self.lbl_save_status.setStyleSheet("background: rgba(0, 0, 0, 100); color: #81c784; border-radius: 4px; border: none; font-size: 11px;")

    def handle_connection_request(self, node):
        if not self.pending_connection_source:
            self.pending_connection_source = node
            self.view.setCursor(Qt.CursorShape.CrossCursor)
        else:
            if self.pending_connection_source != node:
                self.create_connection(self.pending_connection_source, node)
                self.trigger_autosave()
            self.pending_connection_source = None
            self.view.setCursor(Qt.CursorShape.ArrowCursor)

    def create_connection(self, node1, node2):
        for conn in self.connections:
            if (conn.start_node == node1 and conn.end_node == node2) or \
               (conn.start_node == node2 and conn.end_node == node1): return
        
        line = ConnectionLine(node1, node2, on_delete_callback=self.delete_connection)
        
        # Bağlantı çizgisi oluştururken temayı uygula
        current_theme_name = self.dm.current_theme
        line.update_theme(ThemeManager.get_palette(current_theme_name))
        
        self.scene.addItem(line)
        self.connections.append(line)

    def delete_connection(self, connection_item):
        if connection_item in self.connections:
            self.scene.removeItem(connection_item)
            self.connections.remove(connection_item)
            self.trigger_autosave()

    def update_connections(self):
        for conn in self.connections: conn.update_position()

    def delete_node(self, node_id):
        if node_id in self.nodes:
            node = self.nodes[node_id]
            to_remove = [c for c in self.connections if c.start_node == node or c.end_node == node]
            for c in to_remove: 
                self.scene.removeItem(c)
                self.connections.remove(c)
            self.scene.removeItem(node)
            del self.nodes[node_id]
            self.trigger_autosave()

    def trigger_autosave(self):
        self.lbl_save_status.setText("✏️ Editing...")
        self.lbl_save_status.setStyleSheet("background: rgba(0, 0, 0, 100); color: #ffb74d; border-radius: 4px; border: none; font-size: 11px;")
        self.autosave_timer.start()

    def save_map_data_silent(self):
        map_data = {"nodes": [], "connections": []}
        for nid, node in self.nodes.items():
            node_data = {
                "id": nid, "type": node.node_type,
                "x": node.pos().x(), "y": node.pos().y(), 
                "w": node.width, "h": node.height, "extra": node.extra_data
            }
            if node.node_type == "note":
                editor = node.proxy.widget()
                if isinstance(editor, MarkdownEditor): node_data["content"] = editor.toPlainText()
            map_data["nodes"].append(node_data)
        
        for conn in self.connections:
            map_data["connections"].append({"from": conn.start_node.node_id, "to": conn.end_node.node_id})
            
        if "mind_maps" not in self.dm.data: self.dm.data["mind_maps"] = {}
        self.dm.data["mind_maps"][self.current_map_id] = map_data
        self.dm.save_data()
        
        self.lbl_save_status.setText("💾 Saved")
        self.lbl_save_status.setStyleSheet("background: rgba(0, 0, 0, 100); color: #81c784; border-radius: 4px; border: none; font-size: 11px;")

    def load_map_data(self):
        self.scene.clear(); self.nodes = {}; self.connections = []
        if "mind_maps" not in self.dm.data: return
        map_data = self.dm.data["mind_maps"].get(self.current_map_id)
        if not map_data: return
        
        for n_data in map_data.get("nodes", []):
            try:
                nid, ntype = n_data["id"], n_data["type"]
                x, y, w, h = n_data["x"], n_data["y"], n_data["w"], n_data["h"]
                if ntype == "note": self.create_note_node(nid, x, y, w, h, n_data.get("content", ""))
                elif ntype == "image": self.create_image_node(nid, x, y, w, h, n_data["extra"].get("path"))
                elif ntype == "entity":
                    eid = n_data["extra"].get("eid")
                    if eid in self.dm.data["entities"]:
                        node = self.create_entity_node(eid, x, y, w, h)
                        if node:
                            old_id = node.node_id
                            if old_id in self.nodes: del self.nodes[old_id]
                            node.node_id = nid
                            self.nodes[nid] = node
            except Exception as e: print(f"Node load error: {e}")
            
        for c_data in map_data.get("connections", []):
            n1 = self.nodes.get(c_data["from"]); n2 = self.nodes.get(c_data["to"])
            if n1 and n2: self.create_connection(n1, n2)