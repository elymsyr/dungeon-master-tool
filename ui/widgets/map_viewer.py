from PyQt6.QtWidgets import (QGraphicsView, QGraphicsScene, QGraphicsPixmapItem, 
                             QGraphicsEllipseItem, QMenu, QGraphicsItem, 
                             QGraphicsRectItem, QGraphicsPathItem)
from PyQt6.QtGui import (QPixmap, QBrush, QColor, QPen, QAction, QPainter, 
                         QWheelEvent, QCursor, QPainterPath, QFont)
from PyQt6.QtCore import Qt, pyqtSignal, QPointF, QRectF
from core.locales import tr

# --- TIMELINE PIN ITEM (KARE + GÜN SAYISI) ---
class TimelinePinItem(QGraphicsRectItem):
    def __init__(self, x, y, day, note, pin_id, entity_name, color, session_id, callback_action):
        # Kare şekli (24x24 piksel), merkezden hizalı
        super().__init__(x - 12, y - 12, 24, 24)
        self.pin_id = pin_id
        self.day = day
        self.note = note
        self.entity_name = entity_name
        self.session_id = session_id # Oturum ID'si
        self.callback_action = callback_action
        
        # Renk Belirleme (Özel > Karakterli > Varsayılan)
        final_color = color
        if not final_color:
            final_color = "#42a5f5" if entity_name else "#ffb300"
        
        self.setBrush(QBrush(QColor(final_color)))
        
        # Çerçeve Rengi: Eğer oturum bağlantısı varsa Beyaz ve Kalın, yoksa Siyah
        if self.session_id:
            pen = QPen(Qt.GlobalColor.white, 2)
            pen.setStyle(Qt.PenStyle.SolidLine)
        else:
            pen = QPen(Qt.GlobalColor.black, 2)
            
        self.setPen(pen)
        
        # Tooltip Hazırlama
        tooltip = f"Gün {day}: {note}"
        if entity_name: tooltip = f"[{entity_name}]\n{tooltip}"
        if session_id: tooltip += "\n(🔗 Oturum Bağlantısı Var)"
        self.setToolTip(tooltip)
        
        self.setZValue(20) 
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setFlags(QGraphicsItem.GraphicsItemFlag.ItemIsSelectable)

    def paint(self, painter, option, widget=None):
        super().paint(painter, option, widget)
        # Yazı rengi: Oturum bağlantısı varsa beyaz (arka plan koyu olabilir varsayımıyla), yoksa siyah
        # Ancak basitlik için siyah, session varsa beyaz yapalım.
        txt_color = Qt.GlobalColor.white if self.session_id else Qt.GlobalColor.black
        
        painter.setPen(txt_color)
        font = QFont()
        font.setBold(True)
        font.setPixelSize(10)
        painter.setFont(font)
        painter.drawText(self.rect(), Qt.AlignmentFlag.AlignCenter, str(self.day))

    def contextMenuEvent(self, event):
        # Timeline Pin Sağ Tık Menüsü
        menu = QMenu()
        menu.setStyleSheet("QMenu { background-color: #333; color: white; border: 1px solid #555; }")
        
        # --- OTURUM BAĞLANTISI VARSA GÖSTER ---
        if self.session_id:
            act_go_session = QAction("📜 Oturuma Git", menu)
            act_go_session.triggered.connect(lambda: self.callback_action("goto_session", self))
            menu.addAction(act_go_session)
            menu.addSeparator()
        # -------------------------------------

        act_link = QAction(tr("MENU_LINK_NEW"), menu)
        act_edit = QAction(tr("MENU_EDIT_TIMELINE"), menu)
        act_color = QAction(tr("MENU_CHANGE_COLOR"), menu)
        act_move = QAction(tr("MENU_CTX_MOVE"), menu)
        act_delete = QAction(tr("MENU_CTX_DELETE"), menu)
        
        menu.addAction(act_link)
        menu.addSeparator()
        menu.addAction(act_edit)
        menu.addAction(act_color)
        menu.addAction(act_move)
        menu.addSeparator()
        menu.addAction(act_delete)
        
        selected = menu.exec(event.screenPos())
        
        if selected == act_link: self.callback_action("link_new", self)
        elif selected == act_edit: self.callback_action("edit_timeline", self)
        elif selected == act_color: self.callback_action("color_timeline", self)
        elif selected == act_move: self.callback_action("move_timeline", self)
        elif selected == act_delete: self.callback_action("delete_timeline", self)

# --- MAP PIN ITEM (NORMAL DAİRE) ---
class MapPinItem(QGraphicsEllipseItem):
    def __init__(self, x, y, radius, color, pin_id, entity_id, name, note, callback_action):
        super().__init__(x - radius/2, y - radius/2, radius, radius)
        self.pin_id = pin_id
        self.entity_id = entity_id
        self.name = name
        self.note = note
        self.callback_action = callback_action 
        
        self.setBrush(QBrush(QColor(color)))
        pen = QPen(Qt.GlobalColor.white)
        pen.setWidth(2)
        self.setPen(pen)
        
        tooltip = name
        if note: tooltip += f"\n📝 {note}"
        self.setToolTip(tooltip)
        
        self.setZValue(10)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setFlags(QGraphicsItem.GraphicsItemFlag.ItemIsSelectable)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            # Sol tıkla menü açma (Eski alışkanlık)
            self._show_menu(event.screenPos())
            event.accept()
        else:
            super().mousePressEvent(event)

    def contextMenuEvent(self, event):
        self._show_menu(event.screenPos())

    def _show_menu(self, pos):
        menu = QMenu()
        menu.setStyleSheet("QMenu { background-color: #333; color: white; border: 1px solid #555; }")
        
        act_inspect = QAction(tr("MENU_CTX_INSPECT"), menu)
        act_note = QAction(tr("MENU_EDIT_NOTE"), menu)
        act_color = QAction(tr("MENU_CHANGE_COLOR"), menu)
        act_move = QAction(tr("MENU_CTX_MOVE"), menu)
        act_delete = QAction(tr("MENU_CTX_DELETE"), menu)
        
        menu.addAction(act_inspect)
        menu.addAction(act_note)
        menu.addAction(act_color)
        menu.addSeparator()
        menu.addAction(act_move)
        menu.addAction(act_delete)
        
        selected = menu.exec(pos)
        
        if selected == act_inspect: self.callback_action("inspect", self)
        elif selected == act_note: self.callback_action("edit_note", self)
        elif selected == act_color: self.callback_action("change_color", self)
        elif selected == act_move: self.callback_action("move", self)
        elif selected == act_delete: self.callback_action("delete", self)

# --- ANA HARİTA GÖRÜNTÜLEYİCİ ---
class MapViewer(QGraphicsView):
    pin_created_signal = pyqtSignal(float, float)
    pin_moved_signal = pyqtSignal(str, float, float)
    timeline_moved_signal = pyqtSignal(str, float, float)

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
        self.moving_pin_type = None

    def load_map(self, pixmap):
        self.scene.clear()
        self.map_item = QGraphicsPixmapItem(pixmap)
        self.map_item.setTransformationMode(Qt.TransformationMode.SmoothTransformation)
        self.map_item.setZValue(0)
        self.scene.addItem(self.map_item)
        self.setSceneRect(self.map_item.boundingRect())
        self.cancel_move_mode()

    def add_pin_object(self, pin_item): self.scene.addItem(pin_item)
    def add_timeline_object(self, pin_item): self.scene.addItem(pin_item)

    def draw_timeline_connections(self, timeline_data):
        coords = {p["id"]: (p["x"], p["y"]) for p in timeline_data}
        for pin in timeline_data:
            parent_id = pin.get("parent_id")
            if parent_id and parent_id in coords:
                start_pt = coords[parent_id]
                end_pt = (pin["x"], pin["y"])
                path = QPainterPath()
                path.moveTo(start_pt[0], start_pt[1])
                path.lineTo(end_pt[0], end_pt[1])
                path_item = QGraphicsPathItem(path)
                
                # Yol Rengi (Altın Sarısı)
                pen = QPen(QColor("#ffb300")) 
                pen.setWidth(3)
                pen.setStyle(Qt.PenStyle.DashLine)
                path_item.setPen(pen)
                
                # Yol, pinlerin altında kalsın
                path_item.setZValue(15) 
                self.scene.addItem(path_item)

    def start_move_mode(self, pin_id, p_type="entity"):
        self.is_moving_pin = True
        self.moving_pin_id = pin_id
        self.moving_pin_type = p_type
        self.viewport().setCursor(Qt.CursorShape.CrossCursor)
        self.setDragMode(QGraphicsView.DragMode.NoDrag)

    def cancel_move_mode(self):
        self.is_moving_pin = False
        self.moving_pin_id = None
        self.moving_pin_type = None
        self.viewport().setCursor(Qt.CursorShape.ArrowCursor)
        self.setDragMode(QGraphicsView.DragMode.ScrollHandDrag)

    def mousePressEvent(self, event):
        if self.is_moving_pin and event.button() == Qt.MouseButton.LeftButton:
            scene_pos = self.mapToScene(event.pos())
            if self.map_item and self.map_item.boundingRect().contains(scene_pos):
                if self.moving_pin_type == "timeline":
                    self.timeline_moved_signal.emit(self.moving_pin_id, scene_pos.x(), scene_pos.y())
                else:
                    self.pin_moved_signal.emit(self.moving_pin_id, scene_pos.x(), scene_pos.y())
                self.cancel_move_mode()
                return
        super().mousePressEvent(event)

    def wheelEvent(self, event: QWheelEvent):
        zoom_in = 1.15; zoom_out = 1 / zoom_in
        if event.angleDelta().y() > 0: self.scale(zoom_in, zoom_in)
        else: self.scale(zoom_out, zoom_out)

    def contextMenuEvent(self, event):
        if self.is_moving_pin:
            self.cancel_move_mode()
            return

        # Eğer tıklanan yerde bir Pin varsa (Timeline veya Map), olayı ona devret.
        item = self.itemAt(event.pos())
        if item and (isinstance(item, TimelinePinItem) or isinstance(item, MapPinItem)):
            super().contextMenuEvent(event)
            return

        # Sadece boş haritaya tıklandığında View menüsünü aç
        if not self.map_item: return
        
        menu = QMenu(self)
        menu.setStyleSheet("QMenu { background-color: #333; color: white; border: 1px solid #555; }")
        action_add_pin = QAction(tr("MENU_CTX_PIN"), self)
        menu.addAction(action_add_pin)
        
        scene_pos = self.mapToScene(event.pos())
        if not self.map_item.boundingRect().contains(scene_pos): return
        
        # QWidget (MapViewer) event'i 'globalPos()' kullanır.
        if menu.exec(event.globalPos()) == action_add_pin:
            self.pin_created_signal.emit(scene_pos.x(), scene_pos.y())