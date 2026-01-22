import uuid
from PyQt6.QtWidgets import (QGraphicsObject, QGraphicsProxyWidget, QGraphicsPathItem, 
                             QMenu, QGraphicsItem, QGraphicsDropShadowEffect)
from PyQt6.QtGui import (QBrush, QColor, QPen, QPainter, QPainterPath, 
                         QCursor, QAction, QFont)
from PyQt6.QtCore import Qt, QRectF, pyqtSignal, QPointF, QTimer

class ConnectionLine(QGraphicsPathItem):
    """(Değişiklik yok)"""
    def __init__(self, start_node, end_node):
        super().__init__()
        self.start_node = start_node
        self.end_node = end_node
        self.setZValue(-2) 
        pen = QPen(QColor(120, 120, 120, 180))
        pen.setWidth(2)
        pen.setCapStyle(Qt.PenCapStyle.RoundCap)
        self.setPen(pen)
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
        self.update_proxy_geometry()

        self.is_resizing = False
        self.resize_handle_size = 20.0
        
        shadow = QGraphicsDropShadowEffect()
        shadow.setBlurRadius(20)
        shadow.setColor(QColor(0, 0, 0, 100))
        shadow.setOffset(5, 5)
        self.setGraphicsEffect(shadow)

    def update_proxy_geometry(self):
        self.proxy.setPos(self.padding, self.padding)
        self.proxy.resize(self.width - (self.padding * 2), self.height - (self.padding * 2))

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

        if self.isSelected() or self.isUnderMouse():
            painter.setPen(Qt.PenStyle.NoPen)
            painter.setBrush(QBrush(QColor(128, 128, 128, 100))) 
            path = QPainterPath()
            path.moveTo(self.width, self.height)
            path.lineTo(self.width - self.resize_handle_size, self.height)
            path.lineTo(self.width, self.height - self.resize_handle_size)
            path.closeSubpath()
            painter.drawPath(path)

    def itemChange(self, change, value):
        if change == QGraphicsItem.GraphicsItemChange.ItemPositionHasChanged:
            self.positionChanged.emit()
            if self.scene() and self.isSelected():
                self.nodeMoved.emit(self)
        return super().itemChange(change, value)

    def mousePressEvent(self, event):
        if (event.pos().x() > self.width - self.resize_handle_size and 
            event.pos().y() > self.height - self.resize_handle_size):
            self.is_resizing = True
            self.setCursor(Qt.CursorShape.SizeFDiagCursor)
            event.accept()
        else:
            super().mousePressEvent(event)
    
    # --- Çift Tıklama Düzeltmesi ---
    def mouseDoubleClickEvent(self, event):
        if self.node_type == "note":
            widget = self.proxy.widget()
            if hasattr(widget, "switch_to_edit_mode"):
                widget.switch_to_edit_mode()
        super().mouseDoubleClickEvent(event)

    def mouseMoveEvent(self, event):
        if self.is_resizing:
            new_w = max(150.0, event.pos().x())
            new_h = max(100.0, event.pos().y())
            self.prepareGeometryChange()
            self.width = new_w
            self.height = new_h
            self.update_proxy_geometry()
            self.positionChanged.emit() 
            self.sizeChanged.emit()     
            event.accept()
        else:
            super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if self.is_resizing:
            self.is_resizing = False
            self.setCursor(Qt.CursorShape.ArrowCursor)
            self.sizeChanged.emit()
        self.nodeReleased.emit(self)
        super().mouseReleaseEvent(event)

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