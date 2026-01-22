import uuid
from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QHBoxLayout, QGraphicsView, 
                             QGraphicsScene, QPushButton, QSplitter, QMenu, 
                             QGraphicsItem, QInputDialog, QMessageBox)
from PyQt6.QtGui import QBrush, QColor, QPainter, QCursor, QAction, QTransform
from PyQt6.QtCore import Qt, QPointF

from ui.tabs.database_tab import DraggableListWidget, EntityListItemWidget
from ui.widgets.markdown_editor import MarkdownEditor
from ui.widgets.npc_sheet import NpcSheet
from ui.widgets.aspect_ratio_label import AspectRatioLabel
from ui.widgets.mind_map_items import MindMapNode, ConnectionLine
from core.locales import tr

class MindMapScene(QGraphicsScene):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setBackgroundBrush(QBrush(QColor("#1e1e1e")))
        self.grid_size = 50

    def drawBackground(self, painter, rect):
        super().drawBackground(painter, rect)
        # Izgara Çizimi
        painter.setPen(QColor(60, 60, 60))
        left = int(rect.left()) - (int(rect.left()) % self.grid_size)
        top = int(rect.top()) - (int(rect.top()) % self.grid_size)
        
        x = left
        while x < rect.right():
            painter.drawPoint(x, int(rect.top())) # Nokta yerine çizgi de olabilir
            # Basit nokta grid
            y = top
            while y < rect.bottom():
                painter.drawPoint(x, y)
                y += self.grid_size
            x += self.grid_size

class MindMapTab(QWidget):
    def __init__(self, data_manager):
        super().__init__()
        self.dm = data_manager
        self.nodes = {} # {node_id: MindMapNode}
        self.connections = [] # [ConnectionLine]
        self.pending_connection_source = None
        
        self.current_map_id = "default" # Gelecekte birden fazla harita desteklenebilir
        
        self.init_ui()
        self.load_map_data()

    def init_ui(self):
        main_layout = QHBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)
        
        splitter = QSplitter(Qt.Orientation.Horizontal)
        
        # --- SOL PANEL (Entity List) ---
        sidebar = QWidget()
        sidebar_layout = QVBoxLayout(sidebar)
        sidebar_layout.setContentsMargins(0, 0, 0, 0)
        
        # DatabaseTab'daki liste mantığını kopyalıyoruz (Basitleştirilmiş)
        self.list_widget = DraggableListWidget()
        self.refresh_entity_list()
        
        # Manuel Yenile butonu (Database değişince burası otomatik güncellenmiyor şimdilik)
        btn_refresh = QPushButton("🔄 " + tr("BTN_LOAD"))
        btn_refresh.clicked.connect(self.refresh_entity_list)
        
        sidebar_layout.addWidget(btn_refresh)
        sidebar_layout.addWidget(self.list_widget)
        
        # --- SAĞ PANEL (Canvas) ---
        canvas_widget = QWidget()
        canvas_layout = QVBoxLayout(canvas_widget)
        canvas_layout.setContentsMargins(0, 0, 0, 0)
        
        # Toolbar
        toolbar = QHBoxLayout()
        btn_add_note = QPushButton("📝 Not Ekle")
        btn_add_note.clicked.connect(self.add_note_node)
        btn_add_image = QPushButton("🖼️ Resim Ekle")
        btn_add_image.clicked.connect(self.add_image_node)
        btn_save = QPushButton(tr("BTN_SAVE"))
        btn_save.setObjectName("primaryBtn")
        btn_save.clicked.connect(self.save_map_data)
        
        toolbar.addWidget(btn_add_note)
        toolbar.addWidget(btn_add_image)
        toolbar.addStretch()
        toolbar.addWidget(btn_save)
        canvas_layout.addLayout(toolbar)
        
        # Graphics View
        self.scene = MindMapScene()
        self.scene.setSceneRect(-5000, -5000, 10000, 10000)
        
        self.view = QGraphicsView(self.scene)
        self.view.setRenderHint(QPainter.RenderHint.Antialiasing)
        self.view.setDragMode(QGraphicsView.DragMode.ScrollHandDrag)
        self.view.setTransformationAnchor(QGraphicsView.ViewportAnchor.AnchorUnderMouse)
        self.view.setAcceptDrops(True)
        self.view.dragEnterEvent = self.view_dragEnterEvent
        self.view.dragMoveEvent = self.view_dragMoveEvent
        self.view.dropEvent = self.view_dropEvent
        self.view.wheelEvent = self.view_wheelEvent # Zoom için
        
        canvas_layout.addWidget(self.view)
        
        splitter.addWidget(sidebar)
        splitter.addWidget(canvas_widget)
        splitter.setSizes([250, 800])
        
        main_layout.addWidget(splitter)

    def refresh_entity_list(self):
        self.list_widget.clear()
        for eid, data in self.dm.data["entities"].items():
            name = data.get("name", "Unknown")
            cat = data.get("type", "NPC")
            item = EntityListItemWidget(name, cat)
            
            # Draggable list için item oluştur
            from PyQt6.QtWidgets import QListWidgetItem
            l_item = QListWidgetItem()
            l_item.setSizeHint(item.sizeHint())
            l_item.setData(Qt.ItemDataRole.UserRole, eid)
            self.list_widget.addItem(l_item)
            self.list_widget.setItemWidget(l_item, item)

    # --- DRAG & DROP EVENTS ---
    def view_dragEnterEvent(self, event):
        if event.mimeData().hasText(): event.accept()
        else: event.ignore()

    def view_dragMoveEvent(self, event):
        event.accept()

    def view_dropEvent(self, event):
        eid = event.mimeData().text()
        pos = self.view.mapToScene(event.position().toPoint())
        self.create_entity_node(eid, pos.x(), pos.y())
        event.accept()

    def view_wheelEvent(self, event):
        zoom_in = 1.15
        zoom_out = 1 / 1.15
        if event.angleDelta().y() > 0:
            self.view.scale(zoom_in, zoom_in)
        else:
            self.view.scale(zoom_out, zoom_out)

    # --- NODE CREATION ---
    def create_node_base(self, node_id, widget, x, y, w, h, title, type_code, extra_data=None):
        node = MindMapNode(node_id, widget, w, h, title)
        node.setPos(x, y)
        node.type_code = type_code
        node.extra_data = extra_data if extra_data else {}
        
        node.requestConnection.connect(self.handle_connection_request)
        node.nodeDeleted.connect(self.delete_node)
        node.positionChanged.connect(self.update_connections)
        
        self.scene.addItem(node)
        self.nodes[node.node_id] = node
        return node

    def add_note_node(self):
        self.create_note_node(None, 0, 0, 300, 200, "")

    def create_note_node(self, node_id, x, y, w, h, content):
        editor = MarkdownEditor(text=content)
        editor.set_data_manager(self.dm)
        # Note: NpcSheet'ten farklı olarak burada direkt editör var.
        # Save yaparken içeriğini alacağız.
        node = self.create_node_base(node_id, editor, x, y, w, h, "📝 Not", "note")
        return node

    def add_image_node(self):
        from PyQt6.QtWidgets import QFileDialog
        from PyQt6.QtGui import QPixmap
        f, _ = QFileDialog.getOpenFileName(self, "Resim Seç", "", "Images (*.png *.jpg *.jpeg)")
        if f:
            path = self.dm.import_image(f)
            self.create_image_node(None, 0, 0, 300, 300, path)

    def create_image_node(self, node_id, x, y, w, h, path):
        lbl = AspectRatioLabel()
        full_path = self.dm.get_full_path(path)
        if full_path:
            lbl.setPixmap(QPixmap(full_path))
        
        node = self.create_node_base(node_id, lbl, x, y, w, h, "🖼️ Resim", "image", {"path": path})
        return node

    def create_entity_node(self, eid, x, y, w=500, h=600):
        # Entity var mı kontrol et
        if eid not in self.dm.data["entities"]: return
        
        ent_data = self.dm.data["entities"][eid]
        title = f"{ent_data.get('name')} ({ent_data.get('type')})"
        
        # NpcSheet oluştur
        sheet = NpcSheet(self.dm)
        sheet.setProperty("entity_id", eid)
        sheet.populate_sheet(ent_data)
        
        # Save sinyalini bağla
        sheet.save_requested.connect(lambda: self.save_sheet_data(sheet))
        
        node = self.create_node_base(None, sheet, x, y, w, h, title, "entity", {"eid": eid})
        return node

    def save_sheet_data(self, sheet):
        # NpcSheet içindeki mevcut kaydetme mantığını çağırır
        # DatabaseTab'daki mantığın aynısı
        eid = sheet.property("entity_id")
        data = sheet.collect_data_from_sheet()
        if data:
            self.dm.save_entity(eid, data)
            # Başlığı güncelle (isim değişmiş olabilir)
            # (Bu biraz karmaşık çünkü node referansına erişmek lazım, şimdilik es geçelim)

    # --- CONNECTIONS ---
    def handle_connection_request(self, node):
        if not self.pending_connection_source:
            self.pending_connection_source = node
            # İmleci değiştir veya kullanıcıya bilgi ver
            self.view.setCursor(Qt.CursorShape.CrossCursor)
        else:
            if self.pending_connection_source != node:
                self.create_connection(self.pending_connection_source, node)
            
            self.pending_connection_source = None
            self.view.setCursor(Qt.CursorShape.ArrowCursor)

    def create_connection(self, node1, node2):
        # Zaten var mı kontrol et
        for conn in self.connections:
            if (conn.start_node == node1 and conn.end_node == node2) or \
               (conn.start_node == node2 and conn.end_node == node1):
               return

        line = ConnectionLine(node1, node2)
        self.scene.addItem(line)
        self.connections.append(line)

    def update_connections(self):
        for conn in self.connections:
            conn.update_position()

    def delete_node(self, node_id):
        if node_id in self.nodes:
            node = self.nodes[node_id]
            
            # Bağlantıları temizle
            to_remove = []
            for conn in self.connections:
                if conn.start_node == node or conn.end_node == node:
                    self.scene.removeItem(conn)
                    to_remove.append(conn)
            for c in to_remove: self.connections.remove(c)
            
            # Node'u temizle
            self.scene.removeItem(node)
            del self.nodes[node_id]

    # --- SAVE / LOAD ---
    def save_map_data(self):
        map_data = {
            "nodes": [],
            "connections": []
        }
        
        # Nodes
        for nid, node in self.nodes.items():
            node_data = {
                "id": nid,
                "type": node.type_code,
                "x": node.pos().x(),
                "y": node.pos().y(),
                "w": node.width,
                "h": node.height,
                "extra": node.extra_data
            }
            
            # Özel veri kaydı
            if node.type_code == "note":
                # Widget markdown editörü
                editor = node.proxy.widget()
                if isinstance(editor, MarkdownEditor):
                    node_data["content"] = editor.toPlainText()
            
            map_data["nodes"].append(node_data)
            
        # Connections
        for conn in self.connections:
            map_data["connections"].append({
                "from": conn.start_node.node_id,
                "to": conn.end_node.node_id
            })
            
        # DataManager'a kaydet
        if "mind_maps" not in self.dm.data: self.dm.data["mind_maps"] = {}
        self.dm.data["mind_maps"][self.current_map_id] = map_data
        self.dm.save_data()
        
        QMessageBox.information(self, tr("MSG_SUCCESS"), "Zihin haritası kaydedildi.")

    def load_map_data(self):
        # Önce temizle
        self.scene.clear()
        self.nodes = {}
        self.connections = []
        
        if "mind_maps" not in self.dm.data: return
        map_data = self.dm.data["mind_maps"].get(self.current_map_id)
        if not map_data: return
        
        # Nodes
        for n_data in map_data.get("nodes", []):
            try:
                nid = n_data["id"]
                ntype = n_data["type"]
                x, y = n_data["x"], n_data["y"]
                w, h = n_data["w"], n_data["h"]
                
                if ntype == "note":
                    self.create_note_node(nid, x, y, w, h, n_data.get("content", ""))
                elif ntype == "image":
                    path = n_data["extra"].get("path")
                    self.create_image_node(nid, x, y, w, h, path)
                elif ntype == "entity":
                    eid = n_data["extra"].get("eid")
                    # Entity artık yoksa hata vermemesi için
                    if eid in self.dm.data["entities"]:
                        self.create_entity_node(eid, x, y, w, h)
                        # ID override (create_entity_node yeni id üretir normalde, onu düzeltelim)
                        # create_node_base içinde None yolladığımız için yeni ID üretiliyor.
                        # Ancak MindMapNode id'sini elle set etmemiz lazım.
                        # Düzeltme: create_node_base'e id parametresi ekledim.
                        # Ama create_entity_node içinde hala None gidiyor.
                        # Şimdilik son eklenen node'un ID'sini güncelleyelim.
                        last_node = self.nodes[list(self.nodes.keys())[-1]]
                        # Dictionary key'ini değiştir
                        del self.nodes[last_node.node_id]
                        last_node.node_id = nid
                        self.nodes[nid] = last_node
                        
            except Exception as e:
                print(f"Error loading node: {e}")

        # Connections
        for c_data in map_data.get("connections", []):
            n1 = self.nodes.get(c_data["from"])
            n2 = self.nodes.get(c_data["to"])
            if n1 and n2:
                self.create_connection(n1, n2)