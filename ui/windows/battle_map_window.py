import base64
import logging
import math
import os

from PyQt6.QtCore import (
    QBuffer,
    QByteArray,
    QIODevice,
    QPoint,
    QPointF,
    QRect,
    QRectF,
    Qt,
    QTimer,
    QUrl,
    pyqtSignal,
)
from PyQt6.QtGui import (
    QBrush,
    QColor,
    QCursor,
    QFont,
    QImage,
    QMouseEvent,
    QPainter,
    QPainterPath,
    QPen,
    QPixmap,
    QPolygonF,
    QWheelEvent,
)
from PyQt6.QtMultimedia import QAudioOutput, QMediaPlayer
from PyQt6.QtMultimediaWidgets import QGraphicsVideoItem
from PyQt6.QtWidgets import (
    QApplication,
    QButtonGroup,
    QCheckBox,
    QFrame,
    QGraphicsEllipseItem,
    QGraphicsItem,
    QGraphicsPathItem,
    QGraphicsPixmapItem,
    QGraphicsProxyWidget,
    QGraphicsScene,
    QGraphicsView,
    QHBoxLayout,
    QInputDialog,
    QLabel,
    QMainWindow,
    QMenu,
    QPushButton,
    QScrollArea,
    QSlider,
    QSpinBox,
    QStyle,
    QVBoxLayout,
    QWidget,
)

from core.locales import tr
from core.theme_manager import ThemeManager

logger = logging.getLogger(__name__)

# --- TOOL MODE CONSTANTS ---
TOOL_NAVIGATE  = "navigate"
TOOL_RULER     = "ruler"
TOOL_CIRCLE    = "circle"
TOOL_DRAW      = "draw"
TOOL_FOG_ADD   = "fog_add"
TOOL_FOG_ERASE = "fog_erase"

# --- FOG OF WAR LAYER ---
class FogItem(QGraphicsPixmapItem):
    def __init__(self, width, height):
        super().__init__()
        self.setZValue(200) # Above tokens (100) and Map (-100)
        # Start completely black (filled)
        self.image = QImage(int(width), int(height), QImage.Format.Format_ARGB32)
        self.image.fill(QColor(0, 0, 0, 255)) 
        self.update_pixmap()
        
    def update_pixmap(self):
        self.setPixmap(QPixmap.fromImage(self.image))

    def paint_polygon(self, points, is_adding):
        if not points or len(points) < 2: return
        painter = QPainter(self.image)
        try:
            painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
            painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
            
            if is_adding:
                brush_color = QColor(0, 0, 0, 255)
                mode = QPainter.CompositionMode.CompositionMode_SourceOver
            else:
                brush_color = Qt.GlobalColor.transparent
                mode = QPainter.CompositionMode.CompositionMode_Clear

            painter.setCompositionMode(mode)
            painter.setBrush(QBrush(brush_color))
            
            pen = QPen(brush_color)
            pen.setWidthF(2.0) 
            pen.setJoinStyle(Qt.PenJoinStyle.RoundJoin)
            pen.setCapStyle(Qt.PenCapStyle.RoundCap)
            painter.setPen(pen)
            
            path = QPainterPath()
            path.moveTo(points[0])
            for p in points[1:]:
                path.lineTo(p)
            
            path.closeSubpath()
            painter.drawPath(path)
            
        finally:
            painter.end()
            
        self.update_pixmap()

    def set_fog_image(self, qimage):
        self.image = qimage
        self.update_pixmap()

# --- GRID LAYER ---
class GridItem(QGraphicsItem):
    def __init__(self, width, height, cell_size=50):
        super().__init__()
        self._width = width
        self._height = height
        self._cell_size = cell_size
        self.setZValue(50)
        self.setFlag(QGraphicsItem.GraphicsItemFlag.ItemIsSelectable, False)
        self.setFlag(QGraphicsItem.GraphicsItemFlag.ItemIsMovable, False)
        self.setAcceptedMouseButtons(Qt.MouseButton.NoButton)

    def boundingRect(self):
        return QRectF(0, 0, self._width, self._height)

    def paint(self, painter, option, widget=None):
        pen = QPen(QColor(255, 255, 255, 55))
        pen.setCosmetic(True)
        painter.setPen(pen)
        cs = max(1, self._cell_size)
        x = 0.0
        while x <= self._width:
            painter.drawLine(QPointF(x, 0), QPointF(x, self._height))
            x += cs
        y = 0.0
        while y <= self._height:
            painter.drawLine(QPointF(0, y), QPointF(self._width, y))
            y += cs

    def set_dimensions(self, width, height):
        self.prepareGeometryChange()
        self._width = width
        self._height = height
        self.update()

    def set_cell_size(self, cell_size):
        self._cell_size = max(1, cell_size)
        self.update()


# --- MEASUREMENT OVERLAY ---
class MeasurementOverlayItem(QGraphicsItem):
    def __init__(self):
        super().__init__()
        self.setZValue(150)
        self._mode = TOOL_RULER   # "ruler" or "circle"
        self._start = QPointF()
        self._end = QPointF()
        self._cell_size = 50
        self._feet_per_cell = 5
        self._visible = False
        self.setFlag(QGraphicsItem.GraphicsItemFlag.ItemIsSelectable, False)
        self.setAcceptedMouseButtons(Qt.MouseButton.NoButton)
        self.setFlag(QGraphicsItem.GraphicsItemFlag.ItemIsMovable, False)

    def boundingRect(self):
        if not self._visible:
            return QRectF()
        if self._mode == TOOL_RULER:
            x1, y1 = self._start.x(), self._start.y()
            x2, y2 = self._end.x(), self._end.y()
            return QRectF(
                min(x1, x2) - 60, min(y1, y2) - 60,
                abs(x2 - x1) + 120, abs(y2 - y1) + 120
            )
        else:  # circle
            r = math.hypot(self._end.x() - self._start.x(), self._end.y() - self._start.y())
            return QRectF(self._start.x() - r - 60, self._start.y() - r - 60, r * 2 + 120, r * 2 + 120)

    def set_measurement(self, mode, start, end, cell_size, feet_per_cell):
        self.prepareGeometryChange()
        self._mode = mode
        self._start = start
        self._end = end
        self._cell_size = max(1, cell_size)
        self._feet_per_cell = feet_per_cell
        self._visible = True
        self.update()

    def clear(self):
        self.prepareGeometryChange()
        self._visible = False
        self.update()

    def paint(self, painter, option, widget=None):
        if not self._visible:
            return
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        if self._mode == TOOL_RULER:
            # Draw line
            pen = QPen(QColor(255, 220, 50), 2, Qt.PenStyle.SolidLine)
            pen.setCosmetic(True)
            painter.setPen(pen)
            painter.drawLine(self._start, self._end)
            # Endpoint dots
            painter.setBrush(QBrush(QColor(255, 220, 50)))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawEllipse(self._start, 4, 4)
            painter.drawEllipse(self._end, 4, 4)
            # Distance label
            dist_px = math.hypot(self._end.x() - self._start.x(), self._end.y() - self._start.y())
            if self._cell_size > 0:
                squares = dist_px / self._cell_size
                feet = squares * self._feet_per_cell
                label = f"{feet:.0f} ft ({squares:.1f} sq)"
            else:
                label = ""
            mid = QPointF((self._start.x() + self._end.x()) / 2, (self._start.y() + self._end.y()) / 2)
            self._draw_label(painter, mid, label)

        else:  # circle
            r = math.hypot(self._end.x() - self._start.x(), self._end.y() - self._start.y())
            # Draw circle
            pen = QPen(QColor(80, 200, 255), 2, Qt.PenStyle.SolidLine)
            pen.setCosmetic(True)
            painter.setPen(pen)
            painter.setBrush(QBrush(QColor(80, 200, 255, 25)))
            painter.drawEllipse(self._start, r, r)
            # Center dot
            painter.setBrush(QBrush(QColor(80, 200, 255)))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawEllipse(self._start, 4, 4)
            # Radius label
            if self._cell_size > 0:
                feet = (r / self._cell_size) * self._feet_per_cell
                label = f"r = {feet:.0f} ft"
            else:
                label = ""
            label_pos = QPointF(self._start.x(), self._start.y() - r - 8)
            self._draw_label(painter, label_pos, label)

    def _draw_label(self, painter, pos, text):
        if not text:
            return
        font = QFont()
        font.setPixelSize(13)
        font.setBold(True)
        painter.setFont(font)
        fm = painter.fontMetrics()
        tw = fm.horizontalAdvance(text)
        th = fm.height()
        # Shadow
        painter.setPen(QPen(QColor(0, 0, 0, 180)))
        for dx, dy in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
            painter.drawText(QPointF(pos.x() - tw / 2 + dx, pos.y() + dy), text)
        # Main text
        painter.setPen(QPen(QColor(255, 255, 255)))
        painter.drawText(QPointF(pos.x() - tw / 2, pos.y()), text)


# --- CUSTOM GRAPHICS VIEW ---
class BattleMapView(QGraphicsView):
    view_changed_signal = pyqtSignal(QRectF)
    fog_changed_signal = pyqtSignal(object)
    annotation_changed_signal = pyqtSignal(object)
    measurement_changed_signal = pyqtSignal()

    def __init__(self, scene, parent=None):
        super().__init__(scene, parent)
        self.setTransformationAnchor(QGraphicsView.ViewportAnchor.AnchorUnderMouse)
        self.setResizeAnchor(QGraphicsView.ViewportAnchor.AnchorUnderMouse)
        self.setRenderHint(QPainter.RenderHint.Antialiasing)
        self.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)

        self._is_panning = False
        self._pan_start_pos = QPoint()
        self._programmatic_change = False

        # Tool state
        self.tool_mode = TOOL_NAVIGATE
        self.grid_cell_size = 50
        self.feet_per_cell = 5

        # Fog items (set from outside)
        self.fog_item = None
        self._is_drawing_fog = False
        self._current_fog_points = []
        self._fog_erase_mode = False

        # Annotation layer (draw mode)
        self.annotation_item: QGraphicsPixmapItem | None = None
        self._annot_img: QImage | None = None   # direct ref, avoids QVariant round-trip
        self._is_drawing_annot = False
        self._annot_erase = False
        self._last_annot_pos: QPointF | None = None

        # Measurement overlay
        self.measure_overlay: MeasurementOverlayItem | None = None
        self._measure_start: QPointF | None = None
        self._measure_end: QPointF | None = None
        self._is_measuring = False
        self._persistent_measurements: list = []  # list[MeasurementOverlayItem]

        # Temp path for fog visual feedback
        self._temp_path_item = QGraphicsPathItem()
        self._temp_path_item.setZValue(250)
        pen = QPen(Qt.GlobalColor.yellow, 2, Qt.PenStyle.DashLine)
        self._temp_path_item.setPen(pen)
        scene.addItem(self._temp_path_item)

    def set_tool_mode(self, mode: str):
        self.tool_mode = mode
        # Update cursor
        cursors = {
            TOOL_NAVIGATE:  Qt.CursorShape.OpenHandCursor,
            TOOL_RULER:     Qt.CursorShape.CrossCursor,
            TOOL_CIRCLE:    Qt.CursorShape.CrossCursor,
            TOOL_DRAW:      Qt.CursorShape.CrossCursor,
            TOOL_FOG_ADD:   Qt.CursorShape.CrossCursor,
            TOOL_FOG_ERASE: Qt.CursorShape.CrossCursor,
        }
        self.setCursor(cursors.get(mode, Qt.CursorShape.OpenHandCursor))
        # Clear measurement when leaving measurement modes
        if mode not in (TOOL_RULER, TOOL_CIRCLE) and self.measure_overlay:
            self.measure_overlay.clear()

    def set_fog_item(self, item):
        self.fog_item = item

    def set_annotation_item(self, item: QGraphicsPixmapItem | None, img: QImage | None = None):
        self.annotation_item = item
        self._annot_img = img

    def set_measure_overlay(self, overlay: MeasurementOverlayItem):
        self.measure_overlay = overlay

    def emit_view_state(self):
        if self._programmatic_change:
            return
        viewport_rect = self.viewport().rect()
        scene_rect = self.mapToScene(viewport_rect).boundingRect()
        self.view_changed_signal.emit(scene_rect)

    def wheelEvent(self, event: QWheelEvent):
        factor = 1.15 if event.angleDelta().y() > 0 else 1 / 1.15
        self.scale(factor, factor)
        self.emit_view_state()

    # ------------------------------------------------------------------
    # Mouse events — dispatch by tool mode
    # ------------------------------------------------------------------

    def mousePressEvent(self, event: QMouseEvent):
        # Middle mouse = pan always
        if event.button() == Qt.MouseButton.MiddleButton:
            self._is_panning = True
            self._pan_start_pos = event.pos()
            self.setCursor(Qt.CursorShape.ClosedHandCursor)
            event.accept()
            return

        scene_pos = self.mapToScene(event.pos())

        if self.tool_mode == TOOL_FOG_ADD:
            if event.button() in (Qt.MouseButton.LeftButton, Qt.MouseButton.RightButton):
                self._fog_erase_mode = (event.button() == Qt.MouseButton.RightButton)
                self._start_fog_draw(event.pos())
                event.accept()
                return

        elif self.tool_mode == TOOL_FOG_ERASE:
            if event.button() in (Qt.MouseButton.LeftButton, Qt.MouseButton.RightButton):
                self._fog_erase_mode = True
                self._start_fog_draw(event.pos())
                event.accept()
                return

        elif self.tool_mode in (TOOL_RULER, TOOL_CIRCLE):
            if event.button() == Qt.MouseButton.LeftButton:
                self._measure_start = scene_pos
                self._is_measuring = True
                event.accept()
                return

        elif self.tool_mode == TOOL_DRAW:
            if event.button() in (Qt.MouseButton.LeftButton, Qt.MouseButton.RightButton):
                self._annot_erase = (event.button() == Qt.MouseButton.RightButton)
                self._is_drawing_annot = True
                self._last_annot_pos = scene_pos
                self._paint_annotation(scene_pos, scene_pos)
                event.accept()
                return

        elif self.tool_mode == TOOL_NAVIGATE and event.button() == Qt.MouseButton.LeftButton:
            # Delete persistent measurement if clicked
            for item in self.scene().items(scene_pos):
                if isinstance(item, MeasurementOverlayItem) and getattr(item, 'is_persistent', False):
                    self.scene().removeItem(item)
                    if item in self._persistent_measurements:
                        self._persistent_measurements.remove(item)
                    self.measurement_changed_signal.emit()
                    event.accept()
                    return
            # Pan when clicking empty space; let super() handle clicks on movable tokens
            has_movable = any(
                item.flags() & QGraphicsItem.GraphicsItemFlag.ItemIsMovable
                for item in self.scene().items(scene_pos)
            )
            if not has_movable:
                self._is_panning = True
                self._pan_start_pos = event.pos()
                self.setCursor(Qt.CursorShape.ClosedHandCursor)
                event.accept()
                return

        super().mousePressEvent(event)

    def mouseMoveEvent(self, event: QMouseEvent):
        if self._is_panning:
            delta = event.pos() - self._pan_start_pos
            self._pan_start_pos = event.pos()
            self.horizontalScrollBar().setValue(self.horizontalScrollBar().value() - delta.x())
            self.verticalScrollBar().setValue(self.verticalScrollBar().value() - delta.y())
            self.emit_view_state()
            event.accept()
            return

        scene_pos = self.mapToScene(event.pos())

        if self._is_drawing_fog:
            self._continue_fog_draw(event.pos())
            event.accept()
            return

        if self._is_measuring and self._measure_start and self.measure_overlay:
            self._measure_end = scene_pos
            self.measure_overlay.set_measurement(
                self.tool_mode, self._measure_start, scene_pos,
                self.grid_cell_size, self.feet_per_cell
            )
            event.accept()
            return

        if self._is_drawing_annot and self.annotation_item:
            self._paint_annotation(self._last_annot_pos or scene_pos, scene_pos)
            self._last_annot_pos = scene_pos
            event.accept()
            return

        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event: QMouseEvent):
        if event.button() == Qt.MouseButton.MiddleButton:
            self._is_panning = False
            self.setCursor(
                Qt.CursorShape.CrossCursor
                if self.tool_mode != TOOL_NAVIGATE
                else Qt.CursorShape.OpenHandCursor
            )
            event.accept()
            return

        if self._is_drawing_fog:
            self._finish_fog_draw()
            event.accept()
            return

        if self._is_panning and event.button() == Qt.MouseButton.LeftButton:
            self._is_panning = False
            self.setCursor(Qt.CursorShape.OpenHandCursor)
            event.accept()
            return

        if self._is_measuring:
            self._is_measuring = False
            if self._measure_start and self._measure_end:
                frozen = MeasurementOverlayItem()
                frozen.is_persistent = True
                frozen.set_measurement(
                    self.tool_mode, self._measure_start, self._measure_end,
                    self.grid_cell_size, self.feet_per_cell,
                )
                self.scene().addItem(frozen)
                self._persistent_measurements.append(frozen)
            self.measure_overlay.clear()
            self._measure_end = None
            self.measurement_changed_signal.emit()
            event.accept()
            return

        if self._is_drawing_annot:
            self._is_drawing_annot = False
            self._last_annot_pos = None
            event.accept()
            return

        super().mouseReleaseEvent(event)

    # ------------------------------------------------------------------
    # Fog drawing
    # ------------------------------------------------------------------

    def _start_fog_draw(self, view_pos):
        self._is_drawing_fog = True
        self._current_fog_points = [self.mapToScene(view_pos)]
        color = Qt.GlobalColor.green if self._fog_erase_mode else Qt.GlobalColor.red
        pen = QPen(color, 2, Qt.PenStyle.SolidLine)
        pen.setCosmetic(True)
        self._temp_path_item.setPen(pen)
        self._temp_path_item.setPath(QPainterPath())
        self._temp_path_item.setVisible(True)

    def _continue_fog_draw(self, view_pos):
        scene_pos = self.mapToScene(view_pos)
        if self._current_fog_points and (scene_pos - self._current_fog_points[-1]).manhattanLength() < 2:
            return
        self._current_fog_points.append(scene_pos)
        path = QPainterPath()
        if self._current_fog_points:
            path.moveTo(self._current_fog_points[0])
            for p in self._current_fog_points[1:]:
                path.lineTo(p)
        self._temp_path_item.setPath(path)

    def _finish_fog_draw(self):
        self._is_drawing_fog = False
        self._temp_path_item.setVisible(False)
        self._temp_path_item.setPath(QPainterPath())
        if self.fog_item and len(self._current_fog_points) > 2:
            is_adding = not self._fog_erase_mode
            self.fog_item.paint_polygon(self._current_fog_points, is_adding)
            self.fog_changed_signal.emit(self.fog_item.image)
        self._current_fog_points = []

    # ------------------------------------------------------------------
    # Annotation drawing
    # ------------------------------------------------------------------

    def _paint_annotation(self, from_pos: QPointF, to_pos: QPointF):
        if not self.annotation_item or self._annot_img is None:
            return
        img = self._annot_img
        if img.isNull():
            return
        painter = QPainter(img)
        try:
            painter.setRenderHint(QPainter.RenderHint.Antialiasing)
            brush_size = max(4, self.grid_cell_size // 8)
            if self._annot_erase:
                painter.setCompositionMode(QPainter.CompositionMode.CompositionMode_Clear)
                painter.setPen(Qt.PenStyle.NoPen)
                painter.setBrush(QBrush(Qt.GlobalColor.transparent))
                erase_r = brush_size * 4
                painter.drawEllipse(to_pos, erase_r, erase_r)
            else:
                painter.setCompositionMode(QPainter.CompositionMode.CompositionMode_SourceOver)
                pen = QPen(QColor(255, 80, 80, 200), brush_size, Qt.PenStyle.SolidLine,
                           Qt.PenCapStyle.RoundCap, Qt.PenJoinStyle.RoundJoin)
                painter.setPen(pen)
                painter.drawLine(from_pos, to_pos)
        finally:
            painter.end()
        # Re-assign after paint to capture any implicit detach in PyQt6
        self._annot_img = img
        self.annotation_item.setPixmap(QPixmap.fromImage(img))
        self.annotation_changed_signal.emit(img)

    def set_view_state(self, rect):
        self._programmatic_change = True
        self.fitInView(rect, Qt.AspectRatioMode.KeepAspectRatio)
        self._programmatic_change = False

# --- HELPERS ---
class SidebarConditionIcon(QWidget):
    def __init__(self, name, icon_path, duration):
        super().__init__()
        self.name = name
        self.icon_path = icon_path
        self.duration = duration
        self.setFixedSize(20, 20) 
        self.setToolTip(f"{name} ({duration} Turns)" if duration > 0 else name)
    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        path = QPainterPath()
        path.addEllipse(1, 1, 18, 18)
        painter.setClipPath(path)
        if self.icon_path and os.path.exists(self.icon_path): 
            painter.drawPixmap(0, 0, 20, 20, QPixmap(self.icon_path))
        else:
            p = ThemeManager.get_palette(self.dm.current_theme if hasattr(self, 'dm') else "dark")
            painter.setBrush(QBrush(QColor(p.get("condition_default_bg", "#5c6bc0"))))
            painter.drawRect(0, 0, 20, 20)
            painter.setPen(Qt.GlobalColor.white)
            font = painter.font()
            font.setPixelSize(7)
            font.setBold(True)
            painter.setFont(font)
            painter.drawText(QRect(0, 0, 20, 20), Qt.AlignmentFlag.AlignCenter, self.name[:2].upper())
        if self.duration > 0:
            painter.setClipping(False)
            painter.setBrush(QBrush(QColor(0, 0, 0, 200)))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawRoundedRect(0, 12, 20, 8, 2, 2)
            painter.setPen(Qt.GlobalColor.white)
            font = painter.font()
            font.setPixelSize(5)
            painter.setFont(font)
            painter.drawText(QRect(0, 12, 20, 8), Qt.AlignmentFlag.AlignCenter, str(self.duration))

class BattleTokenItem(QGraphicsEllipseItem):
    def __init__(self, size, pixmap, border_color, name, tid, eid,
                 on_move_callback, snap_func=None, size_change_callback=None):
        super().__init__(0, 0, size, size)
        self.tid = tid
        self.eid = eid
        self.name = name
        self.on_move_callback = on_move_callback
        self.snap_func = snap_func
        self.size_change_callback = size_change_callback
        self.original_pixmap = pixmap
        self.border_color = border_color
        self.current_size = size
        self.setFlag(QGraphicsEllipseItem.GraphicsItemFlag.ItemIsMovable)
        self.setFlag(QGraphicsEllipseItem.GraphicsItemFlag.ItemIsSelectable)
        self.setFlag(QGraphicsEllipseItem.GraphicsItemFlag.ItemSendsGeometryChanges)
        self.setToolTip(name)
        self.update_appearance(size, border_color)

    def update_appearance(self, size, border_color=None):
        self.current_size = size
        self.setRect(0, 0, size, size)
        if border_color:
            self.border_color = border_color
        pen = QPen(QColor(self.border_color))
        pen.setWidth(3)
        self.setPen(pen)
        if self.original_pixmap and not self.original_pixmap.isNull():
            scaled = self.original_pixmap.scaled(
                int(size), int(size),
                Qt.AspectRatioMode.KeepAspectRatioByExpanding,
                Qt.TransformationMode.SmoothTransformation
            )
            self.setBrush(QBrush(scaled))
        else:
            self.setBrush(QBrush(QColor("#444")))

    def mouseReleaseEvent(self, event):
        super().mouseReleaseEvent(event)
        pos = self.pos()
        if self.snap_func:
            pos = self.snap_func(pos)
            self.setPos(pos)
        if self.on_move_callback:
            self.on_move_callback(self.tid, self.pos().x(), self.pos().y())

    def contextMenuEvent(self, event):
        menu = QMenu()
        act_resize = menu.addAction(tr("MENU_TOKEN_RESIZE"))
        result = menu.exec(event.screenPos().toPoint())
        if result == act_resize:
            val, ok = QInputDialog.getInt(
                None, tr("MENU_TOKEN_RESIZE"), "px:",
                self.current_size, 20, 400
            )
            if ok:
                self.update_appearance(val)
                if self.size_change_callback:
                    self.size_change_callback(self.tid, val)

# --- SHARED MAP WIDGET ---
class BattleMapWidget(QWidget):
    token_moved_signal = pyqtSignal(str, float, float)
    token_size_changed_signal = pyqtSignal(int)
    token_size_override_changed = pyqtSignal(str, int)  # (tid, new_size)
    grid_settings_changed = pyqtSignal(int, bool, bool, int)  # (grid_size, grid_visible, grid_snap, feet_per_cell)
    view_sync_signal = pyqtSignal(QRectF)
    fog_update_signal = pyqtSignal(object)
    annotation_update_signal = pyqtSignal(object)
    measurement_update_signal = pyqtSignal(object)

    def __init__(self, parent=None, is_dm_view=False):
        super().__init__(parent)
        self.tokens = {}
        self.token_size = 50
        self.map_item = None
        self.current_map_path = None
        self.fog_item = None
        self.annotation_item: QGraphicsPixmapItem | None = None
        self.measurement_display_item: QGraphicsPixmapItem | None = None
        self.grid_item: GridItem | None = None
        self.grid_visible = False
        self.grid_snap = False
        self.grid_cell_size = 50
        self.is_dm_view = is_dm_view
        self.is_view_locked = False
        self._suppress_grid_settings_signal = False

        # --- NATIVE VIDEO PLAYER (Local Files) ---
        self.video_player = None
        self.video_item = None
        self.audio_output = None
        self._pending_video_path = None

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        # --- TOOLBAR (2 rows) ---
        toolbar_widget = QWidget()
        toolbar_widget.setObjectName("toolbarWidget")
        toolbar_vbox = QVBoxLayout(toolbar_widget)
        toolbar_vbox.setContentsMargins(0, 0, 0, 0)
        toolbar_vbox.setSpacing(1)

        # Row 1: fit / lock / token size / external widgets
        self.toolbar = QHBoxLayout()
        self.toolbar.setContentsMargins(5, 3, 5, 2)
        self.toolbar.setSpacing(4)

        _style = QApplication.style()
        self.btn_reset_view = QPushButton()
        self.btn_reset_view.setIcon(_style.standardIcon(QStyle.StandardPixmap.SP_BrowserReload))
        self.btn_reset_view.setToolTip(tr("TIP_FIT_VIEW"))
        self.btn_reset_view.setFixedSize(28, 26)
        self.btn_reset_view.clicked.connect(self.fit_map_in_view)
        self.toolbar.addWidget(self.btn_reset_view)

        if self.is_dm_view:
            self.btn_lock_view = QPushButton(tr("BTN_UNLOCK_VIEW"))
            self.btn_lock_view.setFixedSize(54, 26)
            self.btn_lock_view.setCheckable(True)
            self.btn_lock_view.setToolTip(tr("BTN_LOCK_VIEW_TOOLTIP"))
            self.btn_lock_view.clicked.connect(self.toggle_view_lock)
            self.toolbar.addWidget(self.btn_lock_view)

        self.lbl_size = QLabel(tr("LBL_TOKEN_SIZE"))
        self.lbl_size.setObjectName("toolbarLabel")
        self.slider_size = QSlider(Qt.Orientation.Horizontal)
        self.slider_size.setMinimum(20)
        self.slider_size.setMaximum(300)
        self.slider_size.setValue(self.token_size)
        self.slider_size.valueChanged.connect(self.change_token_size)
        self.slider_size.setFixedWidth(100)
        self.toolbar.addWidget(self.lbl_size)
        self.toolbar.addWidget(self.slider_size)
        self.toolbar.addStretch()

        toolbar_vbox.addLayout(self.toolbar)

        # Row 2 (DM only): tool selector + action buttons + grid controls
        if self.is_dm_view:
            self.toolbar2 = QHBoxLayout()
            self.toolbar2.setContentsMargins(5, 2, 5, 3)
            self.toolbar2.setSpacing(4)

            # --- TOOL SELECTOR ---
            self._tool_group = QButtonGroup(self)
            self._tool_group.setExclusive(True)

            def _tool_btn(key, mode):
                b = QPushButton(tr(key))
                b.setCheckable(True)
                b.setFixedHeight(26)
                b.clicked.connect(lambda: self._set_tool(mode))
                self._tool_group.addButton(b)
                self.toolbar2.addWidget(b)
                return b

            def _sep():
                f = QFrame()
                f.setFrameShape(QFrame.Shape.VLine)
                f.setObjectName("bmToolSep")
                self.toolbar2.addWidget(f)

            self.btn_tool_navigate = _tool_btn("TOOL_NAVIGATE", TOOL_NAVIGATE)
            _sep()
            self.btn_tool_ruler    = _tool_btn("TOOL_RULER",    TOOL_RULER)
            self.btn_tool_circle   = _tool_btn("TOOL_CIRCLE",   TOOL_CIRCLE)
            _sep()
            self.btn_tool_draw     = _tool_btn("TOOL_DRAW",     TOOL_DRAW)
            _sep()
            self.btn_tool_fog_add  = _tool_btn("TOOL_FOG_ADD",  TOOL_FOG_ADD)
            self.btn_tool_navigate.setChecked(True)

            _sep()
            self.btn_fog_fill = QPushButton(tr("BTN_FOG_FILL"))
            self.btn_fog_fill.clicked.connect(self.fill_fog)
            self.btn_fog_clear = QPushButton(tr("BTN_FOG_CLEAR"))
            self.btn_fog_clear.clicked.connect(self.clear_fog)
            self.btn_clear_draw = QPushButton(tr("BTN_CLEAR_DRAW"))
            self.btn_clear_draw.clicked.connect(self.clear_annotation)
            self.btn_clear_rulers = QPushButton(tr("BTN_CLEAR_RULERS"))
            self.btn_clear_rulers.clicked.connect(self.clear_measurements)
            self.toolbar2.addWidget(self.btn_fog_fill)
            self.toolbar2.addWidget(self.btn_fog_clear)
            self.toolbar2.addWidget(self.btn_clear_draw)
            self.toolbar2.addWidget(self.btn_clear_rulers)

            # --- GRID CONTROLS ---
            _sep()
            self.btn_grid_toggle = QPushButton(tr("BTN_GRID"))
            self.btn_grid_toggle.setCheckable(True)
            self.btn_grid_toggle.clicked.connect(self._on_grid_toggle)
            self.toolbar2.addWidget(self.btn_grid_toggle)

            self.lbl_grid_cell = QLabel(tr("LBL_GRID_CELL_SIZE"))
            self.lbl_grid_cell.setObjectName("toolbarLabel")
            self.lbl_grid_cell.setFixedHeight(26)
            self.toolbar2.addWidget(self.lbl_grid_cell)

            self.spin_grid_size = QSpinBox()
            self.spin_grid_size.setRange(10, 300)
            self.spin_grid_size.setValue(50)
            self.spin_grid_size.setFixedWidth(56)
            self.spin_grid_size.setFixedHeight(26)
            self.spin_grid_size.valueChanged.connect(self._on_grid_size_changed)
            self.toolbar2.addWidget(self.spin_grid_size)

            self.btn_grid_snap = QPushButton(tr("BTN_GRID_SNAP"))
            self.btn_grid_snap.setCheckable(True)
            self.btn_grid_snap.clicked.connect(self._on_snap_toggle)
            self.toolbar2.addWidget(self.btn_grid_snap)

            self.lbl_feet = QLabel(tr("LBL_FEET_PER_CELL"))
            self.lbl_feet.setObjectName("toolbarLabel")
            self.lbl_feet.setFixedHeight(26)
            self.toolbar2.addWidget(self.lbl_feet)

            self.spin_feet = QSpinBox()
            self.spin_feet.setRange(1, 100)
            self.spin_feet.setValue(5)
            self.spin_feet.setFixedWidth(48)
            self.spin_feet.setFixedHeight(26)
            self.spin_feet.valueChanged.connect(self._on_feet_changed)
            self.toolbar2.addWidget(self.spin_feet)

            self.toolbar2.addStretch()
            toolbar_vbox.addLayout(self.toolbar2)

        layout.addWidget(toolbar_widget)

        self.scene = QGraphicsScene()
        self.scene.setBackgroundBrush(QBrush(QColor("#111")))
        self.view = BattleMapView(self.scene)
        self.view.setStyleSheet("border: none;")

        self.view.view_changed_signal.connect(self.on_view_changed_internal)
        self.view.fog_changed_signal.connect(self.on_local_fog_changed)
        self.view.annotation_changed_signal.connect(self.on_local_annotation_changed)
        self.view.measurement_changed_signal.connect(self._on_measurement_changed)

        # Measurement overlay (shared, always in scene)
        self._measure_overlay = MeasurementOverlayItem()
        self.scene.addItem(self._measure_overlay)
        self.view.set_measure_overlay(self._measure_overlay)

        layout.addWidget(self.view)

    def add_toolbar_widget(self, widget):
        # Insert before the trailing stretch on row 1
        self.toolbar.insertWidget(self.toolbar.count() - 1, widget)

    # ------------------------------------------------------------------
    # Tool mode
    # ------------------------------------------------------------------

    def _set_tool(self, mode: str):
        self.view.set_tool_mode(mode)

    # ------------------------------------------------------------------
    # Grid
    # ------------------------------------------------------------------

    def _on_grid_toggle(self, checked):
        self.grid_visible = checked
        if self.grid_item:
            self.grid_item.setVisible(checked)
        self._emit_grid_settings_changed()

    def _on_grid_size_changed(self, val):
        self.grid_cell_size = val
        self.view.grid_cell_size = val
        if self.grid_item:
            self.grid_item.set_cell_size(val)
        self._emit_grid_settings_changed()

    def _on_snap_toggle(self, checked):
        self.grid_snap = checked
        self._emit_grid_settings_changed()

    def _on_feet_changed(self, val):
        self.view.feet_per_cell = val
        self._emit_grid_settings_changed()

    def _emit_grid_settings_changed(self):
        if not self.is_dm_view or self._suppress_grid_settings_signal:
            return
        self.grid_settings_changed.emit(
            int(self.grid_cell_size),
            bool(self.grid_visible),
            bool(self.grid_snap),
            int(self.view.feet_per_cell),
        )

    def _init_grid(self, w, h):
        if self.grid_item:
            self.scene.removeItem(self.grid_item)
        self.grid_item = GridItem(w, h, self.grid_cell_size)
        self.grid_item.setVisible(self.grid_visible)
        self.scene.addItem(self.grid_item)

    def _snap_pos(self, pos: QPointF) -> QPointF:
        cs = max(1, self.grid_cell_size)
        return QPointF(round(pos.x() / cs) * cs, round(pos.y() / cs) * cs)

    def _get_snap_func(self):
        if self.grid_snap and self.grid_cell_size > 0:
            return self._snap_pos
        return None

    # ------------------------------------------------------------------
    # View lock
    # ------------------------------------------------------------------

    def toggle_view_lock(self, checked):
        self.is_view_locked = checked
        p = ThemeManager.get_palette(self.dm.current_theme if hasattr(self, 'dm') else "dark")
        if checked:
            self.btn_lock_view.setText(tr("BTN_LOCK_VIEW"))
            self.btn_lock_view.setStyleSheet(f"background-color: {p.get('hp_bar_low', '#d32f2f')}; color: white;")
        else:
            self.btn_lock_view.setText(tr("BTN_UNLOCK_VIEW"))
            self.btn_lock_view.setStyleSheet("")

    def on_view_changed_internal(self, rect):
        if not self.is_view_locked:
            self.view_sync_signal.emit(rect)

    # ------------------------------------------------------------------
    # Annotation layer
    # ------------------------------------------------------------------

    def _init_annotation_layer(self, w, h):
        if self.annotation_item:
            self.scene.removeItem(self.annotation_item)
        img = QImage(int(w), int(h), QImage.Format.Format_ARGB32)
        img.fill(Qt.GlobalColor.transparent)
        pix_item = QGraphicsPixmapItem(QPixmap.fromImage(img))
        pix_item.setZValue(75)
        pix_item.setAcceptedMouseButtons(Qt.MouseButton.NoButton)  # don't block clicks
        self.scene.addItem(pix_item)
        self.annotation_item = pix_item
        self.view.set_annotation_item(pix_item, img)

    def clear_annotation(self):
        if self.annotation_item and self.view._annot_img is not None:
            img = self.view._annot_img
            if not img.isNull():
                img.fill(Qt.GlobalColor.transparent)
                self.annotation_item.setPixmap(QPixmap.fromImage(img))
                self.on_local_annotation_changed(img)

    def clear_measurements(self):
        for item in list(self.view._persistent_measurements):
            self.scene.removeItem(item)
        self.view._persistent_measurements.clear()
        if self.view.measure_overlay:
            self.view.measure_overlay.clear()
        self._on_measurement_changed()

    def _on_measurement_changed(self):
        scene_rect = self.scene.sceneRect()
        if scene_rect.isEmpty():
            return
        w = max(1, int(scene_rect.width()))
        h = max(1, int(scene_rect.height()))
        img = QImage(w, h, QImage.Format.Format_ARGB32)
        img.fill(Qt.GlobalColor.transparent)
        if self.view._persistent_measurements:
            painter = QPainter(img)
            painter.translate(-scene_rect.x(), -scene_rect.y())
            for item in self.view._persistent_measurements:
                item.paint(painter, None, None)
            painter.end()
        self.measurement_update_signal.emit(img)

    def apply_external_measurement(self, qimage):
        if qimage is None:
            return
        scene_rect = self.scene.sceneRect()
        if scene_rect.isEmpty():
            return
        if self.measurement_display_item is None:
            pix_item = QGraphicsPixmapItem()
            pix_item.setZValue(145)
            pix_item.setAcceptedMouseButtons(Qt.MouseButton.NoButton)
            self.scene.addItem(pix_item)
            self.measurement_display_item = pix_item
        self.measurement_display_item.setPos(scene_rect.topLeft())
        if not qimage.isNull():
            self.measurement_display_item.setPixmap(QPixmap.fromImage(qimage))
        else:
            self.measurement_display_item.setPixmap(QPixmap())

    def on_local_annotation_changed(self, qimage):
        self.annotation_update_signal.emit(qimage)

    def get_annotation_data_base64(self):
        if not self.annotation_item or self.view._annot_img is None:
            return None
        img = self.view._annot_img
        if img.isNull():
            return None
        buffer = QBuffer()
        buffer.open(QIODevice.OpenModeFlag.WriteOnly)
        img.save(buffer, "PNG")
        return base64.b64encode(buffer.data()).decode('utf-8')

    def load_annotation_from_base64(self, b64_str):
        if not b64_str:
            return
        try:
            data = base64.b64decode(b64_str)
            img = QImage()
            img.loadFromData(data, "PNG")
            if not img.isNull():
                if not self.annotation_item:
                    self._init_annotation_layer(img.width(), img.height())
                if self.annotation_item:
                    self.annotation_item.setPixmap(QPixmap.fromImage(img))
                    self.view.set_annotation_item(self.annotation_item, img)
        except Exception as e:
            logger.error("Annotation load error: %s", e)

    # ------------------------------------------------------------------
    # Fog / map utils
    # ------------------------------------------------------------------

    def get_fog_data_base64(self):
        if not self.fog_item: return None
        buffer = QBuffer()
        buffer.open(QIODevice.OpenModeFlag.WriteOnly)
        self.fog_item.image.save(buffer, "PNG")
        return base64.b64encode(buffer.data()).decode('utf-8')

    def get_current_map_size(self):
        """Helper to determine what the actual content size is."""
        w, h = 1920, 1080
        if self.map_item and self.map_item.isVisible():
            r = self.map_item.boundingRect()
            w, h = r.width(), r.height()
        elif self.video_item and self.video_item.isVisible():
            r = self.video_item.boundingRect() # sometimes nativeSize needed
            if r.width() > 0:
                w, h = r.width(), r.height()
        return int(w), int(h)

    def load_fog_from_base64(self, b64_str):
        if not b64_str: return
        try:
            data = base64.b64decode(b64_str)
            img = QImage(); img.loadFromData(data, "PNG")
            
            target_w, target_h = self.get_current_map_size()
            
            # If no fog exists, initialize with saved size OR map size
            if not self.fog_item:
                self.init_fog_layer(max(img.width(), target_w), max(img.height(), target_h))
            
            # If the loaded fog doesn't match current map, we might need to recreate/resize
            # But usually we just load what we have. 
            # If the user clicks "Fill" later, that function will now fix the size.
            
            if self.fog_item:
                # If sizes differ drastically, resize current item to match image?
                # For now, just set the image.
                if img.size() != self.fog_item.image.size(): 
                    self.init_fog_layer(img.width(), img.height())
                
                self.fog_item.set_fog_image(img)
                self.on_local_fog_changed(img)
                
        except Exception as e:
            logger.error("Fog load error: %s", e)

    def reset_fog(self):
        if self.fog_item:
            self.scene.removeItem(self.fog_item)
            self.fog_item = None

    def init_fog_layer(self, width, height):
        if self.fog_item: 
            self.scene.removeItem(self.fog_item)
        self.fog_item = FogItem(width, height)
        self.fog_item.setOpacity(0.5 if self.is_dm_view else 1.0)
        self.scene.addItem(self.fog_item)
        self.view.set_fog_item(self.fog_item)

    def fill_fog(self):
        # 1. Determine correct size
        target_w, target_h = self.get_current_map_size()
        
        # 2. Check if current fog item exists and matches size
        if not self.fog_item or self.fog_item.image.width() != target_w or self.fog_item.image.height() != target_h:
            self.init_fog_layer(target_w, target_h)
            
        # 3. Fill
        if self.fog_item:
            self.fog_item.image.fill(QColor(0, 0, 0, 255))
            self.fog_item.update_pixmap()
            self.on_local_fog_changed(self.fog_item.image)

    def clear_fog(self):
        # Similar logic: Ensure coverage before clearing (though clearing usually implies transparent)
        target_w, target_h = self.get_current_map_size()
        if not self.fog_item or self.fog_item.image.width() != target_w or self.fog_item.image.height() != target_h:
            self.init_fog_layer(target_w, target_h)

        if self.fog_item:
            self.fog_item.image.fill(Qt.GlobalColor.transparent)
            self.fog_item.update_pixmap()
            self.on_local_fog_changed(self.fog_item.image)

    def on_local_fog_changed(self, qimage):
        self.fog_update_signal.emit(qimage)

    def apply_external_annotation(self, qimage):
        if qimage is None or qimage.isNull():
            return
        img_copy = qimage.copy()
        if not self.annotation_item:
            self._init_annotation_layer(img_copy.width(), img_copy.height())
        if self.annotation_item:
            self.annotation_item.setPixmap(QPixmap.fromImage(img_copy))
            self.view._annot_img = img_copy

    def apply_external_fog(self, qimage):
        if not self.fog_item and qimage:
            self.init_fog_layer(qimage.width(), qimage.height())
        elif not self.fog_item:
            w, h = self.get_current_map_size()
            self.init_fog_layer(w, h)
        
        if self.fog_item and qimage: self.fog_item.set_fog_image(qimage)

    def fit_map_in_view(self):
        if self.map_item and self.map_item.isVisible(): 
            self.view.fitInView(self.map_item, Qt.AspectRatioMode.KeepAspectRatio)
        elif self.video_item and self.video_item.isVisible():
            self.view.fitInView(self.video_item, Qt.AspectRatioMode.KeepAspectRatio)
        
        # Explicitly emit view state to sync linked windows
        self.view.emit_view_state()

    def apply_view_state(self, rect): self.view.set_view_state(rect)

    def _on_video_status_changed(self, status):
        """Handle video resize when metadata is loaded."""
        if status == QMediaPlayer.MediaStatus.BufferedMedia or status == QMediaPlayer.MediaStatus.LoadedMedia:
            sz = self.video_item.nativeSize()
            if not sz.isEmpty():
                self.video_item.setSize(sz)
                self.scene.setSceneRect(0, 0, sz.width(), sz.height())
                # Note: If Fog exists (loaded from saved data), don't overwrite it here
                # But if NO fog, use video size
                if not self.fog_item: self.init_fog_layer(sz.width(), sz.height())
                self._init_grid(sz.width(), sz.height())
                # Use delay to ensure layout settling, similar to image
                QTimer.singleShot(50, self.fit_map_in_view)

    def _on_video_native_size_changed(self, size):
        """Handle video resize when native size signal fires."""
        if not size.isEmpty():
            self.video_item.setSize(size)
            self.scene.setSceneRect(0, 0, size.width(), size.height())
            if not self.fog_item: 
                self.init_fog_layer(size.width(), size.height())
            self._init_grid(size.width(), size.height())
            self.fit_map_in_view()

    def showEvent(self, event):
        """Load any deferred video map now that the widget is visible."""
        super().showEvent(event)
        if self._pending_video_path:
            path = self._pending_video_path
            self._pending_video_path = None
            self.set_map_image(None, path)
            # nativeSizeChanged fires async; if it doesn't fire (e.g. codec
            # issues), this timer ensures fit_map_in_view is still called.
            QTimer.singleShot(400, self.fit_map_in_view)

    def set_map_image(self, pixmap, path_ref=None):
        self.current_map_path = path_ref
        
        # --- CLEANUP PREVIOUS ---
        if self.map_item: self.map_item.hide()
        if self.video_item:
            self.video_item.hide()
            if self.video_player: self.video_player.stop()

        is_local_video = path_ref and path_ref.endswith(('.mp4', '.webm', '.mkv', '.avi', '.m4v'))

        # --- 1. LOCAL VIDEO FILE ---
        if is_local_video:
            if not self.video_player:
                self.video_player = QMediaPlayer()
                self.audio_output = QAudioOutput()
                self.audio_output.setVolume(0) # Mute video by default
                self.video_player.setAudioOutput(self.audio_output)
                self.video_item = QGraphicsVideoItem()
                self.video_item.setZValue(-200)
                self.scene.addItem(self.video_item)
                self.video_player.setVideoOutput(self.video_item)
                self.video_player.setLoops(QMediaPlayer.Loops.Infinite)
                # CONNECT SIGNAL ONCE DURING CREATION
                self.video_player.mediaStatusChanged.connect(self._on_video_status_changed)
                self.video_item.nativeSizeChanged.connect(self._on_video_native_size_changed)
            
            self.video_item.show()
            self.video_player.setSource(QUrl.fromLocalFile(path_ref))
            self.video_player.play()
            return

        # --- 2. STATIC IMAGE ---
        if pixmap:
            if not self.map_item:
                self.map_item = QGraphicsPixmapItem()
                self.map_item.setZValue(-100)
                self.map_item.setTransformationMode(Qt.TransformationMode.SmoothTransformation)
                self.scene.addItem(self.map_item)
            
            self.map_item.setPixmap(pixmap)
            self.map_item.show()
            self.scene.setSceneRect(self.map_item.boundingRect())

            if not self.fog_item:
                self.init_fog_layer(pixmap.width(), pixmap.height())
            self._init_grid(pixmap.width(), pixmap.height())
            if self.is_dm_view:
                if not self.annotation_item:
                    self._init_annotation_layer(pixmap.width(), pixmap.height())
            QTimer.singleShot(50, self.fit_map_in_view)
        else:
            self.current_map_path = None

    def change_token_size(self, val):
        self.token_size = val
        # Only resize tokens that don't have individual size overrides
        for token in self.tokens.values():
            if not hasattr(token, '_has_size_override') or not token._has_size_override:
                token.update_appearance(self.token_size)
        self.token_size_changed_signal.emit(val)

    def on_token_moved(self, tid, x, y):
        self.token_moved_signal.emit(tid, x, y)

    def on_token_size_override(self, tid, new_size):
        if tid in self.tokens:
            token = self.tokens[tid]
            token._has_size_override = True
            token.update_appearance(new_size)
        self.token_size_override_changed.emit(tid, new_size)

    def retranslate_ui(self):
        self.lbl_size.setText(tr("LBL_TOKEN_SIZE"))
        self.btn_reset_view.setToolTip(tr("TIP_FIT_VIEW"))
        if self.is_dm_view:
            self.btn_tool_navigate.setText(tr("TOOL_NAVIGATE"))
            self.btn_tool_ruler.setText(tr("TOOL_RULER"))
            self.btn_tool_circle.setText(tr("TOOL_CIRCLE"))
            self.btn_tool_draw.setText(tr("TOOL_DRAW"))
            self.btn_tool_fog_add.setText(tr("TOOL_FOG_ADD"))
            self.btn_fog_fill.setText(tr("BTN_FOG_FILL"))
            self.btn_fog_clear.setText(tr("BTN_FOG_CLEAR"))
            self.btn_clear_draw.setText(tr("BTN_CLEAR_DRAW"))
            self.btn_clear_rulers.setText(tr("BTN_CLEAR_RULERS"))
            self.btn_grid_toggle.setText(tr("BTN_GRID"))
            self.lbl_grid_cell.setText(tr("LBL_GRID_CELL_SIZE"))
            self.btn_grid_snap.setText(tr("BTN_GRID_SNAP"))
            self.lbl_feet.setText(tr("LBL_FEET_PER_CELL"))

    def update_tokens(self, combatants, current_index, dm_manager, map_path=None,
                      saved_token_size=None, fog_data=None,
                      token_size_overrides=None, grid_size=None, grid_visible=None,
                      grid_snap=None, feet_per_cell=None, annotation_data=None):
        """Push full combat state to the map widget."""
        if token_size_overrides is None:
            token_size_overrides = {}

        if saved_token_size and saved_token_size != self.token_size:
            self.token_size = saved_token_size
            self.slider_size.blockSignals(True)
            self.slider_size.setValue(saved_token_size)
            self.slider_size.blockSignals(False)

        # Grid settings (apply in both DM and player views)
        self._suppress_grid_settings_signal = True
        try:
            if grid_size is not None and grid_size != self.grid_cell_size:
                self.grid_cell_size = grid_size
                self.view.grid_cell_size = grid_size
                if self.is_dm_view:
                    self.spin_grid_size.blockSignals(True)
                    self.spin_grid_size.setValue(grid_size)
                    self.spin_grid_size.blockSignals(False)
                if self.grid_item:
                    self.grid_item.set_cell_size(grid_size)

            if grid_visible is not None:
                self.grid_visible = bool(grid_visible)
                if self.is_dm_view:
                    self.btn_grid_toggle.setChecked(self.grid_visible)
                if self.grid_item:
                    self.grid_item.setVisible(self.grid_visible)

            if grid_snap is not None:
                self.grid_snap = bool(grid_snap)
                if self.is_dm_view:
                    self.btn_grid_snap.setChecked(self.grid_snap)

            if feet_per_cell is not None:
                self.view.feet_per_cell = feet_per_cell
                if self.is_dm_view:
                    self.spin_feet.blockSignals(True)
                    self.spin_feet.setValue(feet_per_cell)
                    self.spin_feet.blockSignals(False)
        finally:
            self._suppress_grid_settings_signal = False

        # 1. Map background
        if map_path != self.current_map_path:
            if map_path:
                is_video = map_path.endswith(('.mp4', '.webm', '.mkv', '.avi', '.m4v'))
                if is_video:
                    if self.isVisible():
                        self.set_map_image(None, map_path)
                    else:
                        self._pending_video_path = map_path
                        self.current_map_path = map_path
                else:
                    pix = QPixmap(map_path) if os.path.exists(map_path) else None
                    self.set_map_image(pix, map_path)
            else:
                self._pending_video_path = None
                self.set_map_image(None, None)

        # 2. Fog
        if fog_data:
            self.load_fog_from_base64(fog_data)
        elif map_path and not self.fog_item:
            self.init_fog_layer(1920, 1080)
            self.fill_fog()

        # 3. Annotation
        if annotation_data:
            self.load_annotation_from_base64(annotation_data)

        # 4. Tokens
        snap_func = self._get_snap_func()
        incoming_tids = set()
        for i, c in enumerate(combatants):
            tid = c.get("tid") or c.get("eid")
            if not tid:
                continue
            incoming_tids.add(tid)
            eid = c.get("eid")
            name = c.get("name", "???")
            x, y = c.get("x"), c.get("y")
            ent_type = c.get("type", "NPC")
            attitude = c.get("attitude", "LBL_ATTR_NEUTRAL")
            is_player = (ent_type == "Player")
            is_active = (i == current_index)
            attitude_clean = "neutral"
            if attitude == "LBL_ATTR_HOSTILE":
                attitude_clean = "hostile"
            elif attitude == "LBL_ATTR_FRIENDLY":
                attitude_clean = "friendly"
            token_border_color = "#bdbdbd"
            if is_active:
                token_border_color = "#ffb74d"
            elif is_player:
                token_border_color = "#4caf50"
            elif attitude_clean == "hostile":
                token_border_color = "#ef5350"
            elif attitude_clean == "friendly":
                token_border_color = "#42a5f5"

            effective_size = token_size_overrides.get(tid, self.token_size)

            if tid in self.tokens:
                token = self.tokens[tid]
                token.snap_func = snap_func
                if token.border_color != token_border_color or token.current_size != effective_size:
                    token.update_appearance(effective_size, token_border_color)
                token._has_size_override = tid in token_size_overrides
                token.setZValue(100 if is_active else 10)
                if x is not None and y is not None:
                    if self.scene.mouseGrabberItem() != token:
                        if abs(token.x() - x) > 1.0 or abs(token.y() - y) > 1.0:
                            token.setPos(x, y)
            else:
                img_path = None
                if eid and eid in dm_manager.data["entities"]:
                    ent = dm_manager.data["entities"][eid]
                    rel_path = ent.get("image_path")
                    if not rel_path and ent.get("images"):
                        rel_path = ent.get("images")[0]
                    if rel_path:
                        img_path = dm_manager.get_full_path(rel_path)
                pixmap = QPixmap(img_path) if img_path and os.path.exists(img_path) else None
                new_token = BattleTokenItem(
                    effective_size, pixmap, token_border_color, name, tid, eid,
                    self.on_token_moved,
                    snap_func=snap_func,
                    size_change_callback=self.on_token_size_override,
                )
                new_token._has_size_override = tid in token_size_overrides
                if x is not None and y is not None:
                    new_token.setPos(x, y)
                else:
                    offset = len(self.tokens) * (effective_size + 10)
                    new_token.setPos(50 + offset, 50)
                new_token.setZValue(100 if is_active else 10)
                self.scene.addItem(new_token)
                self.tokens[tid] = new_token

        to_remove = [tid for tid in self.tokens if tid not in incoming_tids]
        for tid in to_remove:
            self.scene.removeItem(self.tokens[tid])
            del self.tokens[tid]

# --- MAIN WINDOW (WRAPPER) ---
class BattleMapWindow(QMainWindow):
    token_moved_signal = pyqtSignal(str, float, float)

    def __init__(self, data_manager):
        super().__init__()
        self.dm = data_manager
        self.map_item = None
        self.setWindowTitle(tr("TITLE_BATTLE_MAP"))
        self.resize(1200, 800)
        central = QWidget()
        self.setCentralWidget(central)
        main_layout = QHBoxLayout(central)
        main_layout.setContentsMargins(0, 0, 0, 0)
        self.map_widget = BattleMapWidget(is_dm_view=False) 
        self.map_widget.token_moved_signal.connect(self.token_moved_signal.emit)
        self.slider_size = self.map_widget.slider_size 
        main_layout.addWidget(self.map_widget, 1)
        self.sidebar = QWidget()
        self.sidebar.setFixedWidth(300)
        self.sidebar.setObjectName("sidebarFrame")
        sidebar_layout = QVBoxLayout(self.sidebar)
        self.lbl_title = QLabel(tr("TITLE_TURN_ORDER"))
        self.lbl_title.setObjectName("headerLabel")
        self.lbl_title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        sidebar_layout.addWidget(self.lbl_title)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setObjectName("sidebarScroll")
        self.list_container = QWidget()
        self.list_container.setObjectName("sheetContainer")
        self.list_container.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)
        self.list_layout = QVBoxLayout(self.list_container)
        self.list_layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        self.list_layout.setSpacing(5)
        scroll.setWidget(self.list_container)
        sidebar_layout.addWidget(scroll)
        main_layout.addWidget(self.sidebar, 0)

    def retranslate_ui(self): 
        self.setWindowTitle(tr("TITLE_BATTLE_MAP"))
        self.lbl_title.setText(tr("TITLE_TURN_ORDER"))
        self.map_widget.retranslate_ui()
    
    def update_combat_data(self, combatants, current_index, map_path=None, saved_token_size=None, fog_data=None):
        self.map_widget.update_tokens(combatants, current_index, self.dm, map_path, saved_token_size, fog_data)
        self._update_sidebar(combatants, current_index)
    
    def sync_view(self, rect): self.map_widget.apply_view_state(rect)
    
    def sync_fog(self, qimage): self.map_widget.apply_external_fog(qimage)

    def _update_sidebar(self, combatants, current_index):
        while self.list_layout.count():
            item = self.list_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
                
        for i, c in enumerate(combatants):
            name = c.get("name", "???")
            hp = c.get("hp", "?")
            conditions = c.get("conditions", []) 
            ent_type = c.get("type", "NPC")
            attitude = c.get("attitude", "LBL_ATTR_NEUTRAL")
            is_player = (ent_type == "Player")
            is_active = (i == current_index)
            attitude_clean = "neutral"
            if attitude == "LBL_ATTR_HOSTILE": 
                attitude_clean = "hostile"
            elif attitude == "LBL_ATTR_FRIENDLY": 
                attitude_clean = "friendly"
            card = QFrame()
            card.setProperty("class", "combatCard")
            card.setProperty("active", str(is_active).lower())
            card.setProperty("type", ent_type)
            card.setProperty("attitude", attitude_clean)
            card_main_layout = QVBoxLayout(card)
            card_main_layout.setContentsMargins(5, 5, 5, 5)
            card_main_layout.setSpacing(2)
            row_header = QWidget()
            row_header_layout = QHBoxLayout(row_header)
            row_header_layout.setContentsMargins(0, 0, 0, 0)
            row_header_layout.setSpacing(5)
            lbl_name = QLabel(name)
            lbl_name.setObjectName("bmTokenName")
            hp_txt = tr("LBL_HP_SIDEBAR", hp=hp) if is_player else tr("LBL_HP_UNKNOWN")
            lbl_hp = QLabel(hp_txt)
            lbl_hp.setObjectName("bmTokenHp")
            row_header_layout.addWidget(lbl_name, 1)
            row_header_layout.addWidget(lbl_hp, 0)
            card_main_layout.addWidget(row_header)
            if conditions:
                row_conditions = QWidget()
                row_cond_layout = QHBoxLayout(row_conditions)
                row_cond_layout.setContentsMargins(0, 2, 0, 0)
                row_cond_layout.setSpacing(4)
                row_cond_layout.addStretch() 
                for cond in conditions: 
                    icon_widget = SidebarConditionIcon(cond.get("name", "?"), cond.get("icon"), cond.get("duration", 0))
                    row_cond_layout.addWidget(icon_widget)
                card_main_layout.addWidget(row_conditions)
            self.list_layout.addWidget(card)
