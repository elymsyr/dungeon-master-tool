import uuid
from PyQt6.QtWidgets import (QGraphicsObject, QGraphicsProxyWidget, QGraphicsPathItem, 
                             QMenu, QGraphicsItem, QGraphicsDropShadowEffect, QGraphicsRectItem)
from PyQt6.QtGui import (QBrush, QColor, QPen, QPainter, QPainterPath, 
                         QCursor, QAction, QFont)
from PyQt6.QtCore import Qt, QRectF, pyqtSignal, QPointF
from core.theme_manager import ThemeManager
from core.locales import tr

class ResizeHandle(QGraphicsRectItem):
    """
    Node'un sağ alt köşesinde duran, boyutlandırma işlemini yöneten özel item.
    """
    def __init__(self, parent):
        super().__init__(0, 0, 20, 20, parent)
        self.parent_node = parent
        self.setCursor(Qt.CursorShape.SizeFDiagCursor)
        self.setZValue(999)
        self.setAcceptHoverEvents(True)
        
        self.setBrush(QBrush(Qt.GlobalColor.transparent))
        self.setPen(QPen(Qt.PenStyle.NoPen))
        self.is_hovered = False
        
        # Başlangıç paleti (Render sırasında güncel paleti parent'tan alacak)
        self.handle_color = QColor(66, 165, 245, 180) # Default fallback

    def hoverEnterEvent(self, event):
        self.is_hovered = True
        self.update()
        super().hoverEnterEvent(event)

    def hoverLeaveEvent(self, event):
        self.is_hovered = False
        self.update()
        super().hoverLeaveEvent(event)

    def paint(self, painter, option, widget=None):
        painter.setPen(Qt.PenStyle.NoPen)
        
        # Rengi parent node'un paletinden çekmeye çalış, yoksa ThemeManager'dan al
        if hasattr(self.parent_node, 'current_palette'):
            color_str = self.parent_node.current_palette.get("ui_resize_handle", "rgba(66, 165, 245, 180)")
            color = QColor(color_str)
        else:
            color = self.handle_color

        if self.is_hovered:
            painter.setBrush(QBrush(color)) 
        else:
            # Fallback for inactive state from palette
            inactive_str = "rgba(128, 128, 128, 100)"
            if hasattr(self.parent_node, 'current_palette'):
                inactive_str = self.parent_node.current_palette.get("ui_resize_handle_inactive", "rgba(128, 128, 128, 100)")
            painter.setBrush(QBrush(QColor(inactive_str)))
        
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
        self.setFlags(QGraphicsItem.GraphicsItemFlag.ItemIsSelectable)
        
        # Varsayılan paleti yükle (Dark)
        self.current_palette = ThemeManager.get_palette("dark")
        self.apply_theme_colors()
        
        self.update_position()

    def update_theme(self, palette):
        """Dışarıdan tema güncellendiğinde çağrılır."""
        self.current_palette = palette
        self.apply_theme_colors()
        self.update()

    def apply_theme_colors(self):
        """Paletteki renkleri kalemlere uygular."""
        c_normal = QColor(self.current_palette.get("line_color", "#787878"))
        c_select = QColor(self.current_palette.get("line_selected", "#42a5f5"))
        
        # Opaklık ayarı (biraz transparan kalsın)
        c_normal.setAlpha(180)
        
        self.default_pen = QPen(c_normal)
        self.default_pen.setWidth(2)
        self.default_pen.setCapStyle(Qt.PenCapStyle.RoundCap)
        
        self.selected_pen = QPen(c_select)
        self.selected_pen.setWidth(3)
        self.selected_pen.setCapStyle(Qt.PenCapStyle.RoundCap)
        self.selected_pen.setStyle(Qt.PenStyle.DashLine)
        
        # Mevcut duruma göre kalemi ayarla
        self.setPen(self.default_pen)

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
        
        action_delete = QAction(tr("MENU_DELETE_LINK"), menu)
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
        
        # Varsayılan paleti yükle
        self.current_palette = ThemeManager.get_palette("dark")
        
        # Kenarlık ve Padding Ayarları
        if self.node_type == "note":
            self.padding = 0
            self.border_radius = 0
        elif self.node_type == "entity":
            self.padding = 0
            self.border_radius = 6
        else: 
            self.padding = 0
            self.border_radius = 0

        self.setFlags(QGraphicsItem.GraphicsItemFlag.ItemIsMovable | 
                      QGraphicsItem.GraphicsItemFlag.ItemIsSelectable | 
                      QGraphicsItem.GraphicsItemFlag.ItemSendsGeometryChanges)
        
        self.proxy = QGraphicsProxyWidget(self)
        self.proxy.setWidget(widget)
        
        self.resize_handle = ResizeHandle(self)
        self.update_layout()

        # Gölge Efekti
        self.shadow = QGraphicsDropShadowEffect()
        self.shadow.setBlurRadius(20)
        self.shadow.setColor(QColor(0, 0, 0, 100))
        self.shadow.setOffset(5, 5)
        self.setGraphicsEffect(self.shadow)
        
        # Temayı ilk kez uygula (Widget'a da ilet)
        self.update_theme(self.current_palette)

    def update_theme(self, palette):
        """Temayı günceller ve içindeki Widget'a da bildirir."""
        self.current_palette = palette
        
        # İçindeki widget bir MarkdownEditor veya NpcSheet ise onun temasını güncelle
        widget = self.proxy.widget()
        if hasattr(widget, "refresh_theme"):
            widget.refresh_theme(palette)
            
        self.update() # Kendini yeniden çiz (paint)

    def get_bg_color(self):
        """Aktif temaya ve node tipine göre arka plan rengini döndürür."""
        if self.node_type == "note":
            return QColor(self.current_palette.get("node_bg_note", "#fff9c4"))
        elif self.node_type == "entity":
            return QColor(self.current_palette.get("node_bg_entity", "#2b2b2b"))
        elif self.node_type == "image":
            return Qt.GlobalColor.transparent
        else:
            return QColor(self.current_palette.get("node_bg_note", "#fff9c4"))

    def update_layout(self):
        self.proxy.setPos(self.padding, self.padding)
        self.proxy.resize(self.width - (self.padding * 2), self.height - (self.padding * 2))
        h_size = 20
        self.resize_handle.setRect(0, 0, h_size, h_size)
        self.resize_handle.setPos(self.width - h_size, self.height - h_size)

    def boundingRect(self):
        return QRectF(0, 0, self.width, self.height)

    def paint(self, painter, option, widget=None):
        rect = self.boundingRect()
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        
        bg_color = self.get_bg_color()
        
        if bg_color != Qt.GlobalColor.transparent:
            painter.setBrush(QBrush(bg_color))
            painter.setPen(Qt.PenStyle.NoPen)
            if self.border_radius > 0: 
                painter.drawRoundedRect(rect, self.border_radius, self.border_radius)
            else: 
                painter.drawRect(rect)

        # Seçili olma durumu (Mavi çerçeve)
        if self.isSelected():
            # Seçim rengini de paletten alabiliriz (line_selected)
            sel_color = self.current_palette.get("line_selected", "#42a5f5")
            pen = QPen(QColor(sel_color), 2)
            pen.setJoinStyle(Qt.PenJoinStyle.MiterJoin)
            painter.setPen(pen)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            if self.border_radius > 0: 
                painter.drawRoundedRect(rect, self.border_radius, self.border_radius)
            else: 
                painter.drawRect(rect)

    def itemChange(self, change, value):
        if change == QGraphicsItem.GraphicsItemChange.ItemPositionHasChanged:
            self.positionChanged.emit()
            if self.scene() and self.isSelected():
                self.nodeMoved.emit(self)
        return super().itemChange(change, value)

    def start_resizing(self):
        self.is_resizing = True
    
    def do_resize(self, scene_pos):
        local_pos = self.mapFromScene(scene_pos)
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
            action_project = QAction(tr('MENU_PROJECT'), menu)
            action_project.triggered.connect(lambda: self.requestProjection.emit(self))
            menu.addAction(action_project)
            menu.addSeparator()

        action_connect = QAction(tr('MENU_CONNECT'), menu)
        action_connect.triggered.connect(lambda: self.requestConnection.emit(self))
        menu.addAction(action_connect)
        
        menu.addSeparator()
        
        action_delete = QAction(tr('BTN_DELETE'), menu)
        action_delete.triggered.connect(lambda: self.nodeDeleted.emit(self.node_id))
        menu.addAction(action_delete)
        
        menu.exec(event.screenPos())


class WorkspaceItem(QGraphicsObject):
    positionChanged = pyqtSignal()
    sizeChanged = pyqtSignal()
    workspaceDeleted = pyqtSignal(str)
    workspaceRenamed = pyqtSignal(str, str)
    workspaceColorChanged = pyqtSignal(str, str)

    def __init__(self, ws_id, name, w=800, h=600, color="#42a5f5"):
        super().__init__()
        self.ws_id = ws_id if ws_id else str(uuid.uuid4())
        self.name = name
        self.width = float(w)
        self.height = float(h)
        self.color = QColor(color)
        self.is_resizing = False
        self.is_moving = False
        self.last_mouse_pos = QPointF()
        
        self.setFlags(QGraphicsItem.GraphicsItemFlag.ItemIsSelectable | 
                      QGraphicsItem.GraphicsItemFlag.ItemSendsGeometryChanges)
        
        self.resize_handle = ResizeHandle(self)
        self.update_layout()
        self.setZValue(-5) # Background layer

    def update_layout(self):
        h_size = 20
        self.resize_handle.setRect(0, 0, h_size, h_size)
        self.resize_handle.setPos(self.width - h_size, self.height - h_size)

    def boundingRect(self):
        return QRectF(0, 0, self.width, self.height)

    def paint(self, painter, option, widget=None):
        rect = self.boundingRect()
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        
        # Dashed Border
        pen = QPen(self.color, 3)
        pen.setStyle(Qt.PenStyle.DashLine)
        if self.isSelected():
            pen.setWidth(5)
        painter.setPen(pen)
        painter.setBrush(QBrush(QColor(self.color.red(), self.color.green(), self.color.blue(), 20)))
        painter.drawRect(rect)
        
        # Label
        painter.setPen(self.color)
        font = QFont("Segoe UI", 12, QFont.Weight.Bold)
        painter.setFont(font)
        painter.drawText(QRectF(5, 5, self.width - 10, 30), Qt.AlignmentFlag.AlignLeft, self.name)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.MiddleButton:
            self.is_moving = True
            self.last_mouse_pos = event.scenePos()
            self.setCursor(Qt.CursorShape.ClosedHandCursor)
            event.accept()
        elif event.button() == Qt.MouseButton.LeftButton:
            # Sol tıkı kabul etme ki canvas (ScrollHandDrag) çalışsın
            event.ignore()
        else:
            super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self.is_moving:
            delta = event.scenePos() - self.last_mouse_pos
            self.setPos(self.pos() + delta)
            self.last_mouse_pos = event.scenePos()
            self.positionChanged.emit()
            event.accept()
        else:
            super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.MouseButton.MiddleButton:
            self.is_moving = False
            self.setCursor(Qt.CursorShape.ArrowCursor)
            event.accept()
        else:
            super().mouseReleaseEvent(event)

    def itemChange(self, change, value):
        if change == QGraphicsItem.GraphicsItemChange.ItemPositionHasChanged:
            self.positionChanged.emit()
        return super().itemChange(change, value)

    def start_resizing(self):
        self.is_resizing = True
    
    def do_resize(self, scene_pos):
        local_pos = self.mapFromScene(scene_pos)
        self.prepareGeometryChange()
        self.width = max(200.0, local_pos.x())
        self.height = max(150.0, local_pos.y())
        self.update_layout()
        self.sizeChanged.emit()

    def stop_resizing(self):
        self.is_resizing = False
        self.sizeChanged.emit()

    def contextMenuEvent(self, event):
        from PyQt6.QtWidgets import QInputDialog, QColorDialog
        menu = QMenu()
        menu.setStyleSheet("QMenu { background-color: #333; color: white; border: 1px solid #555; } QMenu::item:selected { background-color: #555; }")
        
        action_rename = QAction(tr('MENU_RENAME_WORKSPACE'), menu)
        action_rename.triggered.connect(self._on_rename)
        
        action_color = QAction(tr('MENU_PICK_COLOR'), menu)
        action_color.triggered.connect(self._on_color_pick)
        
        action_delete = QAction(tr('BTN_DELETE'), menu)
        action_delete.triggered.connect(lambda: self.workspaceDeleted.emit(self.ws_id))
        
        menu.addAction(action_rename)
        menu.addAction(action_color)
        menu.addSeparator()
        menu.addAction(action_delete)
        menu.exec(event.screenPos())

    def _on_rename(self):
        from PyQt6.QtWidgets import QInputDialog
        name, ok = QInputDialog.getText(None, tr("MSG_WORKSPACE_NAME"), tr("MSG_ENTER_WS_NAME"), text=self.name)
        if ok and name:
            self.workspaceRenamed.emit(self.ws_id, name)

    def _on_color_pick(self):
        from PyQt6.QtWidgets import QColorDialog
        color = QColorDialog.getColor(self.color, None, tr("MENU_PICK_COLOR"))
        if color.isValid():
            self.workspaceColorChanged.emit(self.ws_id, color.name())