import uuid
from PyQt6.QtWidgets import (QGraphicsObject, QGraphicsProxyWidget, QGraphicsPathItem, 
                             QMenu, QGraphicsItem, QGraphicsDropShadowEffect, QGraphicsRectItem)
from PyQt6.QtGui import (QBrush, QColor, QPen, QPainter, QPainterPath, 
                         QCursor, QAction, QFont)
from PyQt6.QtCore import Qt, QRectF, pyqtSignal, QPointF, QTimer

class ResizeHandle(QGraphicsRectItem):
    """
    Node'un sağ alt köşesinde duran, boyutlandırma işlemini yöneten özel item.
    En üstte (Z-Value yüksek) olduğu için fare olaylarını ProxyWidget'tan önce yakalar.
    """
    def __init__(self, parent):
        # 20x20'lik bir alan
        super().__init__(0, 0, 20, 20, parent)
        self.parent_node = parent
        self.setCursor(Qt.CursorShape.SizeFDiagCursor)
        # ProxyWidget'ın (genellikle 0 veya 1) üzerinde durması için yüksek Z veriyoruz
        self.setZValue(999)
        self.setAcceptHoverEvents(True)
        
        # Görsel ayarlar (Varsayılan şeffaf)
        self.setBrush(QBrush(Qt.GlobalColor.transparent))
        # HATA DÜZELTİLDİ: Qt.PenStyle.NoPen yerine QPen nesnesi veriliyor
        self.setPen(QPen(Qt.PenStyle.NoPen))
        
        # Üzerine gelindiğinde hafif renk değişimi için bayrak
        self.is_hovered = False

    def hoverEnterEvent(self, event):
        self.is_hovered = True
        self.update() # Repaint tetikle
        super().hoverEnterEvent(event)

    def hoverLeaveEvent(self, event):
        self.is_hovered = False
        self.update()
        super().hoverLeaveEvent(event)

    def paint(self, painter, option, widget=None):
        # Tutamaç üçgenini çiz
        painter.setPen(Qt.PenStyle.NoPen)
        
        if self.is_hovered:
            painter.setBrush(QBrush(QColor(66, 165, 245, 180))) # Mavi (Hover)
        else:
            painter.setBrush(QBrush(QColor(128, 128, 128, 100))) # Gri (Normal)
        
        r = self.rect()
        path = QPainterPath()
        path.moveTo(r.bottomRight())
        path.lineTo(r.right(), r.top())
        path.lineTo(r.left(), r.bottom())
        path.closeSubpath()
        painter.drawPath(path)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.parent_node.start_resizing()
            event.accept()
        else:
            super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self.parent_node.is_resizing:
            # Global sahne pozisyonunu alıp parent'a iletiyoruz
            self.parent_node.do_resize(event.scenePos())
            event.accept()
        else:
            super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.parent_node.stop_resizing()
            event.accept()
        super().mouseReleaseEvent(event)


class ConnectionLine(QGraphicsPathItem):
    def __init__(self, start_node, end_node, on_delete_callback=None):
        super().__init__()
        self.start_node = start_node
        self.end_node = end_node
        self.on_delete_callback = on_delete_callback
        
        self.setZValue(-2) 
        
        # Seçilebilir yap
        self.setFlags(QGraphicsItem.GraphicsItemFlag.ItemIsSelectable)
        
        self.default_pen = QPen(QColor(120, 120, 120, 180))
        self.default_pen.setWidth(2)
        self.default_pen.setCapStyle(Qt.PenCapStyle.RoundCap)
        
        self.selected_pen = QPen(QColor(66, 165, 245, 255)) # Mavi (Seçili)
        self.selected_pen.setWidth(3)
        self.selected_pen.setCapStyle(Qt.PenCapStyle.RoundCap)
        self.selected_pen.setStyle(Qt.PenStyle.DashLine)
        
        self.setPen(self.default_pen)
        self.update_position()

    def update_position(self):
        if not self.start_node or not self.end_node: return
        start_pos = self.start_node.scenePos() + self.start_node.boundingRect().center()
        end_pos = self.end_node.scenePos() + self.end_node.boundingRect().center()
        path = QPainterPath()
        path.moveTo(start_pos)
        ctrl1 = QPointF(start_pos.x() + (end_pos.x() - start_pos.x()) / 2, start_pos.y())
        ctrl2 = QPointF(start_pos.x() + (end_pos.x() - start_pos.x()) / 2, end_pos.y())
        path.cubicTo(ctrl1, ctrl2, end_pos)
        self.setPath(path)

    def paint(self, painter, option, widget=None):
        if self.isSelected():
            painter.setPen(self.selected_pen)
        else:
            painter.setPen(self.default_pen)
        painter.drawPath(self.path())

    def contextMenuEvent(self, event):
        menu = QMenu()
        menu.setStyleSheet("QMenu { background-color: #333; color: white; border: 1px solid #555; } QMenu::item:selected { background-color: #555; }")
        
        action_delete = QAction("❌ Bağı Sil", menu)
        action_delete.triggered.connect(lambda: self.on_delete_callback(self) if self.on_delete_callback else None)
        
        menu.addAction(action_delete)
        menu.exec(event.screenPos())


class MindMapNode(QGraphicsObject):
    positionChanged = pyqtSignal()
    sizeChanged = pyqtSignal()
    requestConnection = pyqtSignal(object) 
    nodeDeleted = pyqtSignal(str)
    requestProjection = pyqtSignal(object)
    nodeReleased = pyqtSignal(object) 
    nodeMoved = pyqtSignal(object) 

    def __init__(self, node_id, widget, w=300, h=200, node_type="note", extra_data=None):
        super().__init__()
        self.node_id = node_id if node_id else str(uuid.uuid4())
        self.width = float(w)
        self.height = float(h)
        self.node_type = node_type
        self.extra_data = extra_data if extra_data else {}
        self.is_resizing = False
        
        if self.node_type == "note":
            self.color = QColor("#fff9c4")
            self.padding = 0 
            self.border_radius = 0 
        elif self.node_type == "entity":
            self.color = QColor("#2b2b2b")
            self.padding = 0
            self.border_radius = 6
        else: 
            self.color = Qt.GlobalColor.transparent
            self.padding = 0
            self.border_radius = 0

        self.setFlags(QGraphicsItem.GraphicsItemFlag.ItemIsMovable | 
                      QGraphicsItem.GraphicsItemFlag.ItemIsSelectable | 
                      QGraphicsItem.GraphicsItemFlag.ItemSendsGeometryChanges)
        
        self.proxy = QGraphicsProxyWidget(self)
        self.proxy.setWidget(widget)
        
        # --- RESIZE HANDLE EKLEME ---
        self.resize_handle = ResizeHandle(self)
        
        self.update_layout() # Hem proxy hem handle boyutunu güncelle

        shadow = QGraphicsDropShadowEffect()
        shadow.setBlurRadius(20)
        shadow.setColor(QColor(0, 0, 0, 100))
        shadow.setOffset(5, 5)
        self.setGraphicsEffect(shadow)

    def update_layout(self):
        """Widget ve Resize Handle pozisyonlarını günceller."""
        # Proxy Widget
        self.proxy.setPos(self.padding, self.padding)
        self.proxy.resize(self.width - (self.padding * 2), self.height - (self.padding * 2))
        
        # Resize Handle (Sağ Alt)
        h_size = 20
        self.resize_handle.setRect(0, 0, h_size, h_size)
        self.resize_handle.setPos(self.width - h_size, self.height - h_size)

    def boundingRect(self):
        return QRectF(0, 0, self.width, self.height)

    def paint(self, painter, option, widget=None):
        rect = self.boundingRect()
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        
        if self.color != Qt.GlobalColor.transparent:
            painter.setBrush(QBrush(self.color))
            painter.setPen(Qt.PenStyle.NoPen)
            if self.border_radius > 0: painter.drawRoundedRect(rect, self.border_radius, self.border_radius)
            else: painter.drawRect(rect)

        if self.isSelected():
            pen = QPen(QColor("#42a5f5"), 2)
            pen.setJoinStyle(Qt.PenJoinStyle.MiterJoin)
            painter.setPen(pen)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            if self.border_radius > 0: painter.drawRoundedRect(rect, self.border_radius, self.border_radius)
            else: painter.drawRect(rect)

    def itemChange(self, change, value):
        if change == QGraphicsItem.GraphicsItemChange.ItemPositionHasChanged:
            self.positionChanged.emit()
            if self.scene() and self.isSelected():
                self.nodeMoved.emit(self)
        return super().itemChange(change, value)

    # --- YENİ RESIZE MANTIKLARI (Handle tarafından çağrılır) ---
    def start_resizing(self):
        self.is_resizing = True
    
    def do_resize(self, scene_pos):
        # Mouse'un sahnedeki pozisyonunu, node'un kendi yerel koordinatına çevir
        local_pos = self.mapFromScene(scene_pos)
        
        # Minimum boyut sınırları
        new_w = max(150.0, local_pos.x())
        new_h = max(100.0, local_pos.y())
        
        self.prepareGeometryChange()
        self.width = new_w
        self.height = new_h
        
        self.update_layout()
        
        self.positionChanged.emit() 
        self.sizeChanged.emit()

    def stop_resizing(self):
        self.is_resizing = False
        self.sizeChanged.emit()
        self.nodeReleased.emit(self)

    def mouseDoubleClickEvent(self, event):
        if self.node_type == "note":
            widget = self.proxy.widget()
            if hasattr(widget, "switch_to_edit_mode"):
                widget.switch_to_edit_mode()
        super().mouseDoubleClickEvent(event)

    def contextMenuEvent(self, event):
        menu = QMenu()
        menu.setStyleSheet("QMenu { background-color: #333; color: white; border: 1px solid #555; } QMenu::item:selected { background-color: #555; }")
        
        if self.node_type in ["image", "entity"]:
            action_project = QAction("👁️ Yansıt (Project)", menu)
            action_project.triggered.connect(lambda: self.requestProjection.emit(self))
            menu.addAction(action_project)
            menu.addSeparator()

        action_connect = QAction("🔗 Bağlantı Kur", menu)
        action_connect.triggered.connect(lambda: self.requestConnection.emit(self))
        menu.addAction(action_connect)
        
        menu.addSeparator()
        
        action_delete = QAction("🗑️ Sil", menu)
        action_delete.triggered.connect(lambda: self.nodeDeleted.emit(self.node_id))
        menu.addAction(action_delete)
        
        menu.exec(event.screenPos())