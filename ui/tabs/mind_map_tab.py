import uuid
from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QGraphicsView, 
                             QGraphicsScene, QPushButton, QSplitter, QFrame, 
                             QGraphicsItem, QMessageBox, QGridLayout, QMenu, QGraphicsProxyWidget)
from PyQt6.QtGui import QBrush, QColor, QPainter, QCursor, QPen, QPixmap, QAction
from PyQt6.QtCore import Qt, QRectF, QPointF, QTimer

from ui.tabs.database_tab import DraggableListWidget, EntityListItemWidget
from ui.widgets.markdown_editor import MarkdownEditor
from ui.widgets.npc_sheet import NpcSheet
from ui.widgets.aspect_ratio_label import AspectRatioLabel
from ui.widgets.mind_map_items import MindMapNode, ConnectionLine
from core.locales import tr

class MindMapScene(QGraphicsScene):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setBackgroundBrush(QBrush(QColor("#181818")))
        self.grid_mode = True

    def drawBackground(self, painter, rect):
        super().drawBackground(painter, rect)
        if not self.grid_mode: return
        grid_size = 40
        left = int(rect.left()) - (int(rect.left()) % grid_size)
        top = int(rect.top()) - (int(rect.top()) % grid_size)
        points = []
        for x in range(left, int(rect.right()), grid_size):
            for y in range(top, int(rect.bottom()), grid_size):
                points.append(QPointF(x, y))
        painter.setPen(QPen(QColor(255, 255, 255, 10), 2)) 
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
        # Eğer bir proxy widget üzerindeyse (örn: NpcSheet scrollbar) zoom yapma
        item = self.itemAt(event.position().toPoint())
        if isinstance(item, QGraphicsProxyWidget):
            # Widget'ın scroll'unu kullanması için olayı yoksay
            # Ancak ProxyWidget, NpcSheet'in tamamını kapladığı için,
            # sadece scroll area üzerindeyken mi yoksaymalıyız?
            # En temizi: Proxy widget event'i kullanırsa zoom çalışmaz.
            # Şimdilik direkt ignore edelim, böylece alttaki widget'a gider.
            event.ignore()
            # Scroll eventini manuel olarak widget'a göndermek gerekebilir
            # Ama ignore edince Qt otomatik olarak parent'a (View) değil, child'a iletir mi?
            # QGraphicsView'de ignore, event'in parent widget'a gitmesini sağlar.
            # Burada amacımız event'i Scene'deki item'a göndermek.
            return super().wheelEvent(event) 
        
        # Boşluktaysa Zoom
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
    """(Değişiklik yok)"""
    def __init__(self, view_ref, parent=None):
        super().__init__(parent)
        self.view = view_ref
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0); layout.setSpacing(5)
        self.btn_in = self._create_btn("➕", lambda: self.view.scale(1.2, 1.2), "Yakınlaş")
        self.btn_out = self._create_btn("➖", lambda: self.view.scale(1/1.2, 1/1.2), "Uzaklaş")
        self.btn_center = self._create_btn("🎯", lambda: self.view.centerOn(0, 0), "Merkeze Git")
        layout.addWidget(self.btn_in); layout.addWidget(self.btn_out); layout.addWidget(self.btn_center)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)

    def _create_btn(self, text, func, tip):
        btn = QPushButton(text)
        btn.setFixedSize(36, 36)
        btn.setToolTip(tip)
        btn.clicked.connect(func)
        btn.setCursor(Qt.CursorShape.PointingHandCursor)
        btn.setStyleSheet("QPushButton { background-color: rgba(40, 40, 40, 220); color: #ddd; border: 1px solid #555; border-radius: 18px; font-weight: bold; font-size: 16px; } QPushButton:hover { background-color: #42a5f5; border-color: #42a5f5; color: white; }")
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
        
        self.init_ui()
        self.load_map_data()

    def init_ui(self):
        main_layout = QHBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0); main_layout.setSpacing(0)
        
        splitter = QSplitter(Qt.Orientation.Horizontal)
        
        sidebar = QWidget()
        sidebar_layout = QVBoxLayout(sidebar)
        sidebar_layout.setContentsMargins(0, 0, 0, 0)
        self.list_widget = DraggableListWidget()
        self.list_widget.setStyleSheet("QListWidget { border: none; border-right: 1px solid #333; background-color: #222; }")
        sidebar_header = QFrame()
        sidebar_header.setStyleSheet("background-color: #2b2b2b; border-bottom: 1px solid #333;")
        sh_layout = QHBoxLayout(sidebar_header)
        btn_refresh = QPushButton("🔄 Load")
        btn_refresh.clicked.connect(self.refresh_entity_list)
        sh_layout.addWidget(btn_refresh)
        sidebar_layout.addWidget(sidebar_header)
        sidebar_layout.addWidget(self.list_widget)
        self.refresh_entity_list()
        
        canvas_container = QWidget()
        canvas_layout = QVBoxLayout(canvas_container)
        canvas_layout.setContentsMargins(0, 0, 0, 0); canvas_layout.setSpacing(0)
        self.scene = MindMapScene()
        self.scene.setSceneRect(-100000, -100000, 200000, 200000)
        self.view = CustomGraphicsView(self.scene, self)
        canvas_layout.addWidget(self.view)
        
        self.floating_controls = FloatingControls(self.view, self.view)
        overlay_layout = QGridLayout(self.view)
        overlay_layout.setContentsMargins(0, 0, 20, 20)
        overlay_layout.addWidget(self.floating_controls, 1, 1, Qt.AlignmentFlag.AlignBottom | Qt.AlignmentFlag.AlignRight)
        
        self.lbl_save_status = QPushButton("💾 Saved", self.view)
        self.lbl_save_status.setFixedSize(80, 25)
        self.lbl_save_status.setStyleSheet("background: rgba(0, 0, 0, 100); color: #81c784; border-radius: 4px; border: none; font-size: 11px;")
        self.lbl_save_status.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        overlay_layout.addWidget(self.lbl_save_status, 0, 1, Qt.AlignmentFlag.AlignTop | Qt.AlignmentFlag.AlignRight)

        # Drop Hint (Her zaman yazsın, ama gizli başlasın)
        self.proj_hint = QPushButton("📤 Drop to Project", self.view)
        self.proj_hint.setStyleSheet("background-color: rgba(66, 165, 245, 0.9); color: white; font-weight: bold; border-radius: 0 0 10px 10px; border: 1px solid #1e88e5;")
        self.proj_hint.setFixedSize(200, 40)
        self.proj_hint.hide()
        overlay_layout.addWidget(self.proj_hint, 0, 1, Qt.AlignmentFlag.AlignTop | Qt.AlignmentFlag.AlignHCenter)

        splitter.addWidget(sidebar)
        splitter.addWidget(canvas_container)
        splitter.setSizes([220, 800])
        splitter.setCollapsible(0, True)
        
        main_layout.addWidget(splitter)

    # --- PROJECTION LOGIC ---
    def handle_node_move(self, node):
        """Node sürüklenirken çalışır (Drop zone görseli)."""
        view_pos = self.view.mapFromScene(node.scenePos())
        threshold = 100 # Üstten 100px
        if view_pos.y() < threshold:
            self.proj_hint.show()
            self.proj_hint.setStyleSheet("background-color: rgba(239, 83, 80, 0.9); color: white; font-weight: bold; border-radius: 0 0 10px 10px;") # Kırmızılaşsın (Active)
        else:
            self.proj_hint.hide()

    def handle_node_release(self, node):
        """Node serbest bırakıldığında çalışır."""
        self.proj_hint.hide()
        view_pos = self.view.mapFromScene(node.scenePos())
        threshold = 100
        
        if view_pos.y() < threshold:
            self.project_node_content(node)

    def project_node_content(self, node):
        # Player Window açık değilse aç
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
            # ProjectionManager'a ekle (Üst bara)
            self.main_window_ref.projection_manager.add_image(full_path)

    # --- REFRESH & CREATE ---
    def refresh_entity_list(self):
        self.list_widget.clear()
        for eid, data in self.dm.data["entities"].items():
            name = data.get("name", "Unknown")
            cat = data.get("type", "NPC")
            item = EntityListItemWidget(name, cat)
            from PyQt6.QtWidgets import QListWidgetItem
            l_item = QListWidgetItem()
            l_item.setSizeHint(item.sizeHint())
            l_item.setData(Qt.ItemDataRole.UserRole, eid)
            self.list_widget.addItem(l_item)
            self.list_widget.setItemWidget(l_item, item)

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

    # --- NODE CREATION ---
    def create_node_base(self, node_id, widget, x, y, w, h, node_type, extra_data=None):
        node = MindMapNode(node_id, widget, w, h, node_type, extra_data)
        node.setPos(x, y)
        node.requestConnection.connect(self.handle_connection_request)
        node.nodeDeleted.connect(self.delete_node)
        
        node.positionChanged.connect(self.update_connections)
        node.positionChanged.connect(self.trigger_autosave)
        node.sizeChanged.connect(self.trigger_autosave)
        
        # Canlı takip ve Bırakma
        node.nodeMoved.connect(self.handle_node_move)
        node.nodeReleased.connect(self.handle_node_release)
        node.requestProjection.connect(self.handle_projection_request) # Sağ tık menüsü için
        
        self.scene.addItem(node)
        self.nodes[node.node_id] = node
        
        self.trigger_autosave()
        return node

    def handle_projection_request(self, node):
        # Sağ tık menüsünden tetiklenirse direkt yansıt
        self.project_node_content(node)

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

    def create_entity_node(self, eid, x, y, w=500, h=600):
        if eid not in self.dm.data["entities"]: return
        ent_data = self.dm.data["entities"][eid]
        sheet = NpcSheet(self.dm)
        sheet.setProperty("entity_id", eid)
        sheet.populate_sheet(ent_data)
        def inner_save():
            d = sheet.collect_data_from_sheet()
            if d: self.dm.save_entity(eid, d)
        sheet.save_requested.connect(inner_save)
        sheet.setStyleSheet("""
            QWidget#sheetContainer { background-color: #2b2b2b; }
            QLineEdit, QTextEdit, QPlainTextEdit { background-color: #1e1e1e; border: 1px solid #444; color: #eee; }
            QLabel { color: #eee; }
        """)
        node = self.create_node_base(None, sheet, x, y, w, h, "entity", {"eid": eid})
        return node

    # ... (Geri kalan connection, delete, save, load metodları aynı) ...
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
        line = ConnectionLine(node1, node2)
        self.scene.addItem(line)
        self.connections.append(line)

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