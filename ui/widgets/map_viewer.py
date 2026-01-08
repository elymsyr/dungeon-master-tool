from PyQt6.QtWidgets import QGraphicsView, QGraphicsScene, QGraphicsPixmapItem, QGraphicsEllipseItem, QMenu, QGraphicsItem
from PyQt6.QtGui import QPixmap, QBrush, QColor, QPen, QAction, QPainter, QWheelEvent, QCursor
from PyQt6.QtCore import Qt, pyqtSignal
from core.locales import tr

class MapPinItem(QGraphicsEllipseItem):
    def __init__(self, x, y, radius, color, pin_id, entity_id, tooltip_text, callback_action):
        super().__init__(x - radius/2, y - radius/2, radius, radius)
        self.pin_id = pin_id
        self.entity_id = entity_id
        self.callback_action = callback_action # (action_type, pin_obj) -> Fonksiyon
        
        self.setBrush(QBrush(QColor(color)))
        pen = QPen(Qt.GlobalColor.white)
        pen.setWidth(2)
        self.setPen(pen)
        
        self.setToolTip(tooltip_text)
        self.setZValue(10)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setFlags(QGraphicsItem.GraphicsItemFlag.ItemIsSelectable)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            # Sol tık menüsü
            menu = QMenu()
            menu.setStyleSheet("QMenu { background-color: #333; color: white; border: 1px solid #555; } QMenu::item:selected { background-color: #007acc; }")
            
            act_inspect = QAction(tr("MENU_CTX_INSPECT"), menu)
            act_move = QAction(tr("MENU_CTX_MOVE"), menu)
            act_delete = QAction(tr("MENU_CTX_DELETE"), menu)
            
            menu.addAction(act_inspect)
            menu.addAction(act_move)
            menu.addSeparator()
            menu.addAction(act_delete)
            
            selected = menu.exec(QCursor.pos())
            
            if selected == act_inspect: self.callback_action("inspect", self)
            elif selected == act_move: self.callback_action("move", self)
            elif selected == act_delete: self.callback_action("delete", self)
                
            event.accept()
        else:
            super().mousePressEvent(event)

class MapViewer(QGraphicsView):
    pin_created_signal = pyqtSignal(float, float)
    pin_moved_signal = pyqtSignal(str, float, float) # id, new_x, new_y

    def __init__(self, parent=None):
        super().__init__(parent)
        self.scene = QGraphicsScene(self)
        self.setScene(self.scene)
        self.setRenderHint(QPainter.RenderHint.Antialiasing)
        self.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)
        self.setDragMode(QGraphicsView.DragMode.ScrollHandDrag)
        self.setTransformationAnchor(QGraphicsView.ViewportAnchor.AnchorUnderMouse)
        self.setBackgroundBrush(QBrush(QColor("#111")))
        
        self.map_item = None
        self.is_moving_pin = False
        self.moving_pin_id = None

    def load_map(self, pixmap):
        self.scene.clear()
        self.map_item = QGraphicsPixmapItem(pixmap)
        self.map_item.setTransformationMode(Qt.TransformationMode.SmoothTransformation)
        self.map_item.setZValue(0)
        self.scene.addItem(self.map_item)
        self.setSceneRect(self.map_item.boundingRect())
        self.cancel_move_mode()

    def add_pin_object(self, pin_item):
        self.scene.addItem(pin_item)

    def start_move_mode(self, pin_id):
        self.is_moving_pin = True
        self.moving_pin_id = pin_id
        self.viewport().setCursor(Qt.CursorShape.CrossCursor)
        self.setDragMode(QGraphicsView.DragMode.NoDrag)

    def cancel_move_mode(self):
        self.is_moving_pin = False
        self.moving_pin_id = None
        self.viewport().setCursor(Qt.CursorShape.ArrowCursor)
        self.setDragMode(QGraphicsView.DragMode.ScrollHandDrag)

    def mousePressEvent(self, event):
        if self.is_moving_pin and event.button() == Qt.MouseButton.LeftButton:
            scene_pos = self.mapToScene(event.pos())
            if self.map_item and self.map_item.boundingRect().contains(scene_pos):
                self.pin_moved_signal.emit(self.moving_pin_id, scene_pos.x(), scene_pos.y())
                self.cancel_move_mode()
                return
        super().mousePressEvent(event)

    def wheelEvent(self, event: QWheelEvent):
        zoom_in = 1.15
        zoom_out = 1 / zoom_in
        if event.angleDelta().y() > 0: self.scale(zoom_in, zoom_in)
        else: self.scale(zoom_out, zoom_out)

    def contextMenuEvent(self, event):
        if self.is_moving_pin:
            self.cancel_move_mode()
            return

        if not self.map_item: return
        menu = QMenu(self)
        menu.setStyleSheet("QMenu { background-color: #333; color: white; border: 1px solid #555; } QMenu::item:selected { background-color: #007acc; }")
        
        action_add_pin = QAction(tr("MENU_CTX_PIN"), self)
        menu.addAction(action_add_pin)
        
        scene_pos = self.mapToScene(event.pos())
        if not self.map_item.boundingRect().contains(scene_pos): return
        
        action = menu.exec(event.globalPos())
        if action == action_add_pin:
            self.pin_created_signal.emit(scene_pos.x(), scene_pos.y())