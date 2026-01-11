from PyQt6.QtWidgets import (QGraphicsView, QGraphicsScene, QGraphicsPixmapItem, 
                             QGraphicsEllipseItem, QMenu, QGraphicsItem, 
                             QGraphicsRectItem, QGraphicsPathItem)
from PyQt6.QtGui import (QPixmap, QBrush, QColor, QPen, QAction, QPainter, 
                         QWheelEvent, QCursor, QPainterPath, QFont)
from PyQt6.QtCore import Qt, pyqtSignal, QPointF, QRectF
from core.locales import tr

class TimelinePinItem(QGraphicsRectItem):
    def __init__(self, x, y, day, note, pin_id, entity_name, color, session_id, callback_action):
        super().__init__(x - 12, y - 12, 24, 24)
        self.pin_id = pin_id
        self.day = day
        self.note = note
        self.entity_name = entity_name
        self.session_id = session_id
        self.callback_action = callback_action
        final_color = color if color else ("#42a5f5" if entity_name else "#ffb300")
        self.setBrush(QBrush(QColor(final_color)))
        pen = QPen(Qt.GlobalColor.white if self.session_id else Qt.GlobalColor.black, 2)
        self.setPen(pen)
        tooltip = f"Gün {day}: {note}"
        if entity_name: tooltip = f"[{entity_name}]\n{tooltip}"
        if session_id: tooltip += "\n(🔗 Oturum Bağlantısı)"
        self.setToolTip(tooltip)
        self.setZValue(20) 
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setFlags(QGraphicsItem.GraphicsItemFlag.ItemIsSelectable)

    def paint(self, painter, option, widget=None):
        super().paint(painter, option, widget)
        painter.setPen(Qt.GlobalColor.white if self.session_id else Qt.GlobalColor.black)
        font = QFont(); font.setBold(True); font.setPixelSize(10); painter.setFont(font)
        painter.drawText(self.rect(), Qt.AlignmentFlag.AlignCenter, str(self.day))

    def contextMenuEvent(self, event):
        menu = QMenu()
        menu.setStyleSheet("QMenu { background-color: #333; color: white; border: 1px solid #555; }")
        if self.session_id:
            act_go = QAction("📜 " + tr("MENU_GOTO_SESSION"), menu)
            act_go.triggered.connect(lambda: self.callback_action("goto_session", self))
            menu.addAction(act_go); menu.addSeparator()
        
        act_link = QAction(tr("MENU_LINK_NEW"), menu)
        act_edit = QAction(tr("MENU_EDIT_TIMELINE"), menu)
        act_color = QAction(tr("MENU_CHANGE_COLOR"), menu)
        act_move = QAction(tr("MENU_CTX_MOVE"), menu)
        act_delete = QAction(tr("MENU_CTX_DELETE"), menu)
        
        for a in [act_link, act_edit, act_color, act_move]: menu.addAction(a)
        menu.addSeparator(); menu.addAction(act_delete)
        selected = menu.exec(event.screenPos())
        if selected:
            if selected == act_link: self.callback_action("link_new", self)
            elif selected == act_edit: self.callback_action("edit_timeline", self)
            elif selected == act_color: self.callback_action("color_timeline", self)
            elif selected == act_move: self.callback_action("move_timeline", self)
            elif selected == act_delete: self.callback_action("delete_timeline", self)

class MapPinItem(QGraphicsEllipseItem):
    def __init__(self, x, y, radius, color, pin_id, entity_id, name, note, callback_action):
        super().__init__(x - radius/2, y - radius/2, radius, radius)
        self.pin_id = pin_id; self.entity_id = entity_id; self.name = name; self.note = note; self.callback_action = callback_action 
        self.setBrush(QBrush(QColor(color)))
        self.setPen(QPen(Qt.GlobalColor.white, 2))
        tooltip = name + (f"\n📝 {note}" if note else "")
        self.setToolTip(tooltip); self.setZValue(10); self.setCursor(Qt.CursorShape.PointingHandCursor); self.setFlags(QGraphicsItem.GraphicsItemFlag.ItemIsSelectable)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton: self._show_menu(event.screenPos()); event.accept()
        else: super().mousePressEvent(event)

    def contextMenuEvent(self, event): self._show_menu(event.screenPos())

    def _show_menu(self, pos):
        menu = QMenu()
        menu.setStyleSheet("QMenu { background-color: #333; color: white; border: 1px solid #555; }")
        act_inspect = QAction(tr("MENU_CTX_INSPECT"), menu)
        act_note = QAction(tr("MENU_EDIT_NOTE"), menu)
        act_color = QAction(tr("MENU_CHANGE_COLOR"), menu)
        act_move = QAction(tr("MENU_CTX_MOVE"), menu)
        act_delete = QAction(tr("MENU_CTX_DELETE"), menu)
        for a in [act_inspect, act_note, act_color, act_move]: menu.addAction(a)
        menu.addSeparator(); menu.addAction(act_delete)
        selected = menu.exec(pos)
        if selected:
            if selected == act_inspect: self.callback_action("inspect", self)
            elif selected == act_note: self.callback_action("edit_note", self)
            elif selected == act_color: self.callback_action("change_color", self)
            elif selected == act_move: self.callback_action("move", self)
            elif selected == act_delete: self.callback_action("delete", self)

class MapViewer(QGraphicsView):
    pin_created_signal = pyqtSignal(float, float)
    pin_moved_signal = pyqtSignal(str, float, float)
    timeline_moved_signal = pyqtSignal(str, float, float)
    link_placed_signal = pyqtSignal(float, float) # Hızlı bağlantı için yeni sinyal

    def __init__(self, parent=None):
        super().__init__(parent)
        self.scene = QGraphicsScene(self); self.setScene(self.scene)
        self.setRenderHint(QPainter.RenderHint.Antialiasing); self.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)
        self.setDragMode(QGraphicsView.DragMode.ScrollHandDrag); self.setTransformationAnchor(QGraphicsView.ViewportAnchor.AnchorUnderMouse)
        self.setBackgroundBrush(QBrush(QColor("#111")))
        self.map_item = None
        self.is_moving_pin = False; self.moving_pin_id = None; self.moving_pin_type = None
        self.is_link_mode = False # Hızlı bağlantı modu aktif mi?

    def load_map(self, pixmap):
        self.scene.clear(); self.map_item = QGraphicsPixmapItem(pixmap); self.map_item.setZValue(0); self.scene.addItem(self.map_item)
        self.setSceneRect(self.map_item.boundingRect()); self.cancel_move_mode()

    def add_pin_object(self, pin_item): self.scene.addItem(pin_item)
    def add_timeline_object(self, pin_item): self.scene.addItem(pin_item)

    def draw_timeline_connections(self, timeline_data):
        coords = {p["id"]: (p["x"], p["y"]) for p in timeline_data}
        for pin in timeline_data:
            parent_id = pin.get("parent_id")
            if parent_id and parent_id in coords:
                start_pt = coords[parent_id]; end_pt = (pin["x"], pin["y"])
                path = QPainterPath(); path.moveTo(start_pt[0], start_pt[1]); path.lineTo(end_pt[0], end_pt[1])
                path_item = QGraphicsPathItem(path)
                pen = QPen(QColor("#ffb300"), 3, Qt.PenStyle.DashLine); path_item.setPen(pen)
                path_item.setZValue(15); self.scene.addItem(path_item)

    def start_move_mode(self, pin_id, p_type="entity"):
        self.is_moving_pin = True; self.moving_pin_id = pin_id; self.moving_pin_type = p_type
        self.viewport().setCursor(Qt.CursorShape.CrossCursor); self.setDragMode(QGraphicsView.DragMode.NoDrag)

    def start_link_mode(self):
        """Hızlı bağlantı modunu başlatır (Mouse Crosshair olur)."""
        self.is_link_mode = True
        self.viewport().setCursor(Qt.CursorShape.CrossCursor)
        self.setDragMode(QGraphicsView.DragMode.NoDrag)

    def cancel_move_mode(self):
        self.is_moving_pin = False; self.is_link_mode = False; self.moving_pin_id = None
        self.viewport().setCursor(Qt.CursorShape.ArrowCursor); self.setDragMode(QGraphicsView.DragMode.ScrollHandDrag)

    def mousePressEvent(self, event):
        # BAĞLANTI MODUNDA TIKLAMA DENETİMİ
        if self.is_link_mode:
            if event.button() == Qt.MouseButton.LeftButton:
                scene_pos = self.mapToScene(event.pos())
                if self.map_item and self.map_item.boundingRect().contains(scene_pos):
                    self.link_placed_signal.emit(scene_pos.x(), scene_pos.y())
                    self.cancel_move_mode()
                    return
            elif event.button() == Qt.MouseButton.RightButton:
                self.cancel_move_mode()
                return

        # STANDART TAŞIMA MODU
        if self.is_moving_pin and event.button() == Qt.MouseButton.LeftButton:
            scene_pos = self.mapToScene(event.pos())
            if self.map_item and self.map_item.boundingRect().contains(scene_pos):
                if self.moving_pin_type == "timeline": self.timeline_moved_signal.emit(self.moving_pin_id, scene_pos.x(), scene_pos.y())
                else: self.pin_moved_signal.emit(self.moving_pin_id, scene_pos.x(), scene_pos.y())
                self.cancel_move_mode(); return
        super().mousePressEvent(event)

    def wheelEvent(self, event: QWheelEvent):
        z = 1.15 if event.angleDelta().y() > 0 else 1/1.15; self.scale(z, z)

    def contextMenuEvent(self, event):
        if self.is_moving_pin or self.is_link_mode: self.cancel_move_mode(); return
        item = self.itemAt(event.pos())
        if item and (isinstance(item, TimelinePinItem) or isinstance(item, MapPinItem)): super().contextMenuEvent(event); return
        if not self.map_item: return
        menu = QMenu(); menu.setStyleSheet("QMenu { background-color: #333; color: white; border: 1px solid #555; }")
        act_add = QAction(tr("MENU_CTX_PIN"), self); menu.addAction(act_add)
        scene_pos = self.mapToScene(event.pos())
        if self.map_item.boundingRect().contains(scene_pos) and menu.exec(event.globalPos()) == act_add:
            self.pin_created_signal.emit(scene_pos.x(), scene_pos.y())