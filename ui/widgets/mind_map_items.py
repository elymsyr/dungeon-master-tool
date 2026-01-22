import uuid
from PyQt6.QtWidgets import (QGraphicsObject, QGraphicsProxyWidget, QGraphicsPathItem, 
                             QMenu, QGraphicsItem, QWidget, QVBoxLayout, QLabel, QFrame)
from PyQt6.QtGui import (QBrush, QColor, QPen, QPainter, QPainterPath, 
                         QCursor, QAction, QFont)
from PyQt6.QtCore import Qt, QRectF, pyqtSignal, QPointF

class ConnectionLine(QGraphicsPathItem):
    """İki düğüm arasındaki bağlantı çizgisi."""
    def __init__(self, start_node, end_node):
        super().__init__()
        self.start_node = start_node
        self.end_node = end_node
        self.setZValue(-1) # Düğümlerin altında kalsın
        
        pen = QPen(QColor(200, 200, 200, 150))
        pen.setWidth(2)
        pen.setStyle(Qt.PenStyle.DashLine)
        self.setPen(pen)
        self.update_position()

    def update_position(self):
        if not self.start_node or not self.end_node: return
        
        # Merkezden merkeze çiz
        start_pos = self.start_node.scenePos() + self.start_node.rect().center()
        end_pos = self.end_node.scenePos() + self.end_node.rect().center()
        
        path = QPainterPath()
        path.moveTo(start_pos)
        
        # Bezier eğrisi ile daha yumuşak bir çizgi
        ctrl1 = QPointF(start_pos.x() + (end_pos.x() - start_pos.x()) / 2, start_pos.y())
        ctrl2 = QPointF(start_pos.x() + (end_pos.x() - start_pos.x()) / 2, end_pos.y())
        path.cubicTo(ctrl1, ctrl2, end_pos)
        
        self.setPath(path)

class MindMapNode(QGraphicsObject):
    """
    Sahnedeki temel kutu yapısı. İçine herhangi bir QWidget alabilir.
    Boyutlandırma, taşıma ve bağlantı özelliklerine sahiptir.
    """
    positionChanged = pyqtSignal()
    requestConnection = pyqtSignal(object) # self gönderir
    nodeDeleted = pyqtSignal(str) # node_id gönderir

    def __init__(self, node_id, widget, w=300, h=200, title="Node"):
        super().__init__()
        self.node_id = node_id if node_id else str(uuid.uuid4())
        self.width = w
        self.height = h
        self.title = title
        self.color = QColor(40, 40, 40, 220)
        self.border_color = QColor(100, 100, 100)
        
        self.setFlags(QGraphicsItem.GraphicsItemFlag.ItemIsMovable | 
                      QGraphicsItem.GraphicsItemFlag.ItemIsSelectable | 
                      QGraphicsItem.GraphicsItemFlag.ItemSendsGeometryChanges)
        
        # Widget'ı göm
        self.proxy = QGraphicsProxyWidget(self)
        self.proxy.setWidget(widget)
        self.proxy.setPos(10, 30) # Başlık çubuğu için pay bırak
        self.resize_content()

        # Durumlar
        self.is_resizing = False
        self.resize_handle_size = 15

    def resize_content(self):
        """İçerikteki widget'ı kutu boyutuna uydur."""
        self.proxy.resize(self.width - 20, self.height - 40)

    def boundingRect(self):
        return QRectF(0, 0, self.width, self.height)

    def paint(self, painter, option, widget=None):
        # Kutu
        painter.setBrush(QBrush(self.color))
        pen = QPen(self.border_color)
        pen.setWidth(2 if self.isSelected() else 1)
        if self.isSelected(): pen.setColor(QColor("#42a5f5"))
        painter.setPen(pen)
        painter.drawRoundedRect(0, 0, self.width, self.height, 5, 5)
        
        # Başlık Çubuğu
        painter.setBrush(QBrush(QColor(0, 0, 0, 50)))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawRoundedRect(0, 0, self.width, 25, 5, 5) # Üst kısım
        # Köşeleri düzeltmek için altını kes
        painter.drawRect(0, 20, self.width, 5)
        
        # Başlık Metni
        painter.setPen(QColor(220, 220, 220))
        font = QFont()
        font.setBold(True)
        painter.setFont(font)
        painter.drawText(QRectF(10, 0, self.width - 20, 25), Qt.AlignmentFlag.AlignVCenter | Qt.AlignmentFlag.AlignLeft, self.title)

        # Resize Handle (Sağ Alt)
        painter.setBrush(QBrush(QColor(100, 100, 100, 150)))
        painter.drawConvexPolygon([
            QPointF(self.width, self.height),
            QPointF(self.width - self.resize_handle_size, self.height),
            QPointF(self.width, self.height - self.resize_handle_size)
        ])

    def itemChange(self, change, value):
        if change == QGraphicsItem.GraphicsItemChange.ItemPositionHasChanged:
            self.positionChanged.emit()
        return super().itemChange(change, value)

    def mousePressEvent(self, event):
        # Resize Handle kontrolü
        if (event.pos().x() > self.width - self.resize_handle_size and 
            event.pos().y() > self.height - self.resize_handle_size):
            self.is_resizing = True
            self.setCursor(Qt.CursorShape.SizeFDiagCursor)
            event.accept()
        else:
            super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self.is_resizing:
            new_w = max(150, event.pos().x())
            new_h = max(100, event.pos().y())
            self.prepareGeometryChange()
            self.width = new_w
            self.height = new_h
            self.resize_content()
            self.positionChanged.emit() # Bağlantıları güncelle
            event.accept()
        else:
            super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        self.is_resizing = False
        self.setCursor(Qt.CursorShape.ArrowCursor)
        super().mouseReleaseEvent(event)

    def contextMenuEvent(self, event):
        menu = QMenu()
        menu.setStyleSheet("QMenu { background-color: #333; color: white; border: 1px solid #555; }")
        
        action_connect = QAction("🔗 Bağlantı Başlat", menu)
        action_connect.triggered.connect(lambda: self.requestConnection.emit(self))
        menu.addAction(action_connect)
        
        menu.addSeparator()
        
        action_delete = QAction("🗑️ Sil", menu)
        action_delete.triggered.connect(lambda: self.nodeDeleted.emit(self.node_id))
        menu.addAction(action_delete)
        
        menu.exec(event.screenPos())