from PyQt6.QtWidgets import (QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, 
                             QLabel, QScrollArea, QFrame, QGraphicsView, 
                             QGraphicsScene, QGraphicsEllipseItem, QSlider, 
                             QGraphicsPixmapItem, QPushButton, QCheckBox, 
                             QGraphicsPathItem, QGraphicsProxyWidget)
from PyQt6.QtGui import (QPixmap, QColor, QFont, QBrush, QPen, QPainter, 
                         QPainterPath, QCursor, QWheelEvent, QMouseEvent, QImage, QPolygonF)
from PyQt6.QtCore import Qt, QRectF, pyqtSignal, QPointF, QTimer, QRect, QPoint, QByteArray, QBuffer, QIODevice, QUrl
from PyQt6.QtMultimedia import QMediaPlayer, QAudioOutput
from PyQt6.QtMultimediaWidgets import QGraphicsVideoItem
from core.locales import tr
import os
import base64

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

# --- CUSTOM GRAPHICS VIEW ---
class BattleMapView(QGraphicsView):
    view_changed_signal = pyqtSignal(QRectF)
    fog_changed_signal = pyqtSignal(object) 

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
        
        # Fog Editing
        self.is_fog_edit_mode = False
        self.fog_item = None
        self._is_drawing_fog = False
        self._current_fog_points = [] 
        self._last_paint_mode = True 
        
        # Visual Feedback Line
        self._temp_path_item = QGraphicsPathItem()
        self._temp_path_item.setZValue(250) 
        pen = QPen(Qt.GlobalColor.yellow, 2, Qt.PenStyle.DashLine)
        self._temp_path_item.setPen(pen)
        scene.addItem(self._temp_path_item)

    def set_fog_item(self, item):
        self.fog_item = item

    def emit_view_state(self):
        """Public method to emit current view rect."""
        if self._programmatic_change: return
        viewport_rect = self.viewport().rect()
        scene_rect = self.mapToScene(viewport_rect).boundingRect()
        self.view_changed_signal.emit(scene_rect)

    def wheelEvent(self, event: QWheelEvent):
        zoom_in = 1.15
        zoom_out = 1/1.15
        if event.angleDelta().y() > 0: 
            self.scale(zoom_in, zoom_in)
        else: 
            self.scale(zoom_out, zoom_out)
        self.emit_view_state()

    def mousePressEvent(self, event: QMouseEvent):
        if event.button() == Qt.MouseButton.MiddleButton:
            self._is_panning = True
            self._pan_start_pos = event.pos()
            self.setCursor(Qt.CursorShape.ClosedHandCursor)
            event.accept()
            return

        if self.is_fog_edit_mode and self.fog_item:
            if event.button() == Qt.MouseButton.LeftButton:
                self._last_paint_mode = True # Add
                self._start_fog_draw(event.pos())
                event.accept()
                return
            elif event.button() == Qt.MouseButton.RightButton:
                self._last_paint_mode = False # Remove
                self._start_fog_draw(event.pos())
                event.accept()
                return

        super().mousePressEvent(event)

    def mouseMoveEvent(self, event: QMouseEvent):
        if self._is_panning:
            delta = event.pos() - self._pan_start_pos
            self._pan_start_pos = event.pos()
            self.horizontalScrollBar().setValue(self.horizontalScrollBar().value() - delta.x())
            self.verticalScrollBar().setValue(self.verticalScrollBar().value() - delta.y())
            event.accept()
            self.emit_view_state()
            return

        if self._is_drawing_fog:
            self._continue_fog_draw(event.pos())
            event.accept()
            return

        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event: QMouseEvent):
        if event.button() == Qt.MouseButton.MiddleButton:
            self._is_panning = False
            self.setCursor(Qt.CursorShape.ArrowCursor if not self.is_fog_edit_mode else Qt.CursorShape.CrossCursor)
            event.accept()
        
        if self._is_drawing_fog:
            self._finish_fog_draw()
            event.accept()
            return

        super().mouseReleaseEvent(event)

    # --- FOG DRAWING LOGIC ---
    def _start_fog_draw(self, view_pos):
        self._is_drawing_fog = True
        self._current_fog_points = [self.mapToScene(view_pos)]
        
        color = Qt.GlobalColor.red if self._last_paint_mode else Qt.GlobalColor.green
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
            self.fog_item.paint_polygon(self._current_fog_points, self._last_paint_mode)
            self.fog_changed_signal.emit(self.fog_item.image)
        
        self._current_fog_points = []

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
            painter.setBrush(QBrush(QColor("#5c6bc0")))
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
    def __init__(self, size, pixmap, border_color, name, tid, eid, on_move_callback):
        super().__init__(0, 0, size, size)
        self.tid = tid
        self.eid = eid
        self.name = name
        self.on_move_callback = on_move_callback
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
            scaled = self.original_pixmap.scaled(int(size), int(size), Qt.AspectRatioMode.KeepAspectRatioByExpanding, Qt.TransformationMode.SmoothTransformation)
            brush = QBrush(scaled)
            self.setBrush(brush)
        else: self.setBrush(QBrush(QColor("#444")))
    def mouseReleaseEvent(self, event):
        super().mouseReleaseEvent(event)
        if self.on_move_callback: self.on_move_callback(self.tid, self.pos().x(), self.pos().y())

# --- SHARED MAP WIDGET ---
class BattleMapWidget(QWidget):
    token_moved_signal = pyqtSignal(str, float, float)
    token_size_changed_signal = pyqtSignal(int)
    view_sync_signal = pyqtSignal(QRectF)
    fog_update_signal = pyqtSignal(object) 

    def __init__(self, parent=None, is_dm_view=False):
        super().__init__(parent)
        self.tokens = {} 
        self.token_size = 50 
        self.map_item = None
        self.current_map_path = None
        self.fog_item = None
        self.is_dm_view = is_dm_view 
        self.is_view_locked = False 
        
        # --- NATIVE VIDEO PLAYER (Local Files) ---
        self.video_player = None
        self.video_item = None
        self.audio_output = None
        
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        
        # --- TOOLBAR SETUP ---
        self.toolbar = QHBoxLayout()
        self.toolbar.setContentsMargins(5, 5, 5, 5)
        
        self.btn_reset_view = QPushButton("🏠")
        self.btn_reset_view.setToolTip(tr("TIP_FIT_VIEW"))
        self.btn_reset_view.setFixedSize(30, 25)
        self.btn_reset_view.clicked.connect(self.fit_map_in_view)
        
        self.lbl_size = QLabel(tr("LBL_TOKEN_SIZE"))
        self.lbl_size.setObjectName("toolbarLabel")
        self.slider_size = QSlider(Qt.Orientation.Horizontal)
        self.slider_size.setMinimum(20)
        self.slider_size.setMaximum(300)
        self.slider_size.setValue(self.token_size)
        self.slider_size.valueChanged.connect(self.change_token_size)
        self.slider_size.setFixedWidth(120)
        
        self.toolbar.addWidget(self.btn_reset_view)
        
        if self.is_dm_view:
            self.btn_lock_view = QPushButton("🔓")
            self.btn_lock_view.setFixedSize(30, 25)
            self.btn_lock_view.setCheckable(True)
            self.btn_lock_view.setToolTip(tr("BTN_LOCK_VIEW_TOOLTIP") if hasattr(tr, "BTN_LOCK_VIEW_TOOLTIP") else "Lock Player View")
            self.btn_lock_view.clicked.connect(self.toggle_view_lock)
            self.toolbar.addWidget(self.btn_lock_view)
        
        self.toolbar.addWidget(self.lbl_size)
        self.toolbar.addWidget(self.slider_size)
        
        if self.is_dm_view:
            self.toolbar.addSpacing(15)
            self.btn_fog_toggle = QPushButton(tr("BTN_FOG"))
            self.btn_fog_toggle.setCheckable(True)
            self.btn_fog_toggle.setStyleSheet("QPushButton:checked { background-color: #d32f2f; color: white; font-weight: bold; }")
            self.btn_fog_toggle.clicked.connect(self.toggle_fog_mode)
            self.toolbar.addWidget(self.btn_fog_toggle)
            
            self.lbl_fog_hint = QLabel(tr("LBL_FOG_HINT"))
            self.lbl_fog_hint.setStyleSheet("color: #aaa; font-size: 10px; margin-left: 5px; margin-right: 5px;")
            self.toolbar.addWidget(self.lbl_fog_hint)
            
            self.btn_fog_fill = QPushButton(tr("BTN_FOG_FILL"))
            self.btn_fog_fill.setFixedSize(60, 25)
            self.btn_fog_fill.clicked.connect(self.fill_fog)
            self.btn_fog_clear = QPushButton(tr("BTN_FOG_CLEAR"))
            self.btn_fog_clear.setFixedSize(60, 25)
            self.btn_fog_clear.clicked.connect(self.clear_fog)
            self.toolbar.addWidget(self.btn_fog_fill)
            self.toolbar.addWidget(self.btn_fog_clear)

        self.toolbar.addStretch()
        layout.addLayout(self.toolbar)
        
        self.scene = QGraphicsScene()
        self.scene.setBackgroundBrush(QBrush(QColor("#111")))
        self.view = BattleMapView(self.scene) 
        self.view.setStyleSheet("border: none;") 
        
        self.view.view_changed_signal.connect(self.on_view_changed_internal)
        self.view.fog_changed_signal.connect(self.on_local_fog_changed)
        
        layout.addWidget(self.view)

    def add_toolbar_widget(self, widget):
        """Adds a widget to the far right of the toolbar (after stretch)."""
        self.toolbar.addWidget(widget)

    def toggle_view_lock(self, checked):
        self.is_view_locked = checked
        if checked:
            self.btn_lock_view.setText("🔒")
            self.btn_lock_view.setStyleSheet("background-color: #d32f2f; color: white;")
        else:
            self.btn_lock_view.setText("🔓")
            self.btn_lock_view.setStyleSheet("")

    def on_view_changed_internal(self, rect):
        if not self.is_view_locked: self.view_sync_signal.emit(rect)

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
                
        except Exception as e: print(f"Fog load error: {e}")

    def reset_fog(self):
        if self.fog_item: 
            self.scene.removeItem(self.fog_item)
            self.fog_item = None

    def toggle_fog_mode(self, checked):
        self.view.is_fog_edit_mode = checked
        if checked: 
            self.view.setCursor(Qt.CursorShape.CrossCursor)
        else: 
            self.view.setCursor(Qt.CursorShape.ArrowCursor)

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
                # Use delay to ensure layout settling, similar to image
                QTimer.singleShot(50, self.fit_map_in_view)

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
                self.video_player.setAudioOutput(self.audio_output)
                self.video_item = QGraphicsVideoItem()
                self.video_item.setZValue(-200)
                self.scene.addItem(self.video_item)
                self.video_player.setVideoOutput(self.video_item)
                self.video_player.setLoops(QMediaPlayer.Loops.Infinite)
                # CONNECT SIGNAL ONCE DURING CREATION
                self.video_player.mediaStatusChanged.connect(self._on_video_status_changed)
            
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
            
            if not self.fog_item: self.init_fog_layer(pixmap.width(), pixmap.height())
            QTimer.singleShot(50, self.fit_map_in_view)
        else:
            self.current_map_path = None

    def change_token_size(self, val):
        self.token_size = val
        for token in self.tokens.values(): token.update_appearance(self.token_size)
        self.token_size_changed_signal.emit(val)

    def on_token_moved(self, tid, x, y): self.token_moved_signal.emit(tid, x, y)
    
    def retranslate_ui(self): 
        self.lbl_size.setText(tr("LBL_TOKEN_SIZE"))
        self.btn_reset_view.setToolTip(tr("TIP_FIT_VIEW"))
        if self.is_dm_view:
            self.btn_fog_toggle.setText(tr("BTN_FOG"))
            self.lbl_fog_hint.setText(tr("LBL_FOG_HINT"))
            self.btn_fog_fill.setText(tr("BTN_FOG_FILL"))
            self.btn_fog_clear.setText(tr("BTN_FOG_CLEAR"))

    def update_tokens(self, combatants, current_index, dm_manager, map_path=None, saved_token_size=None, fog_data=None):
        """
        Updates the map. Arguments allow setting everything in one go.
        fog_data: Base64 string of saved fog. If provided, it is applied BEFORE tokens are visible.
        """
        if saved_token_size and saved_token_size != self.token_size:
            self.token_size = saved_token_size; self.slider_size.blockSignals(True); self.slider_size.setValue(saved_token_size); self.slider_size.blockSignals(False)
        
        # 1. Update Map Background
        if map_path != self.current_map_path:
            if map_path:
                is_video = map_path.endswith(('.mp4', '.webm', '.mkv', '.avi', '.m4v'))
                if is_video: self.set_map_image(None, map_path)
                else:
                    pix = QPixmap(map_path) if os.path.exists(map_path) else None
                    self.set_map_image(pix, map_path)
            else:
                self.set_map_image(None, None)

        # 2. Update Fog (Priority over tokens to prevent flashing)
        if fog_data:
            self.load_fog_from_base64(fog_data)
        elif map_path and not self.fog_item:
            # If new map and no fog data, default to full fog (hidden)
            self.init_fog_layer(1920, 1080) 
            self.fill_fog()

        # 3. Update Tokens
        incoming_tids = set()
        for i, c in enumerate(combatants):
            tid = c.get("tid") or c.get("eid")
            if not tid: continue
            incoming_tids.add(tid)
            eid = c.get("eid"); name = c.get("name", "???"); x, y = c.get("x"), c.get("y")
            ent_type = c.get("type", "NPC"); attitude = c.get("attitude", "LBL_ATTR_NEUTRAL"); is_player = (ent_type == "Player"); is_active = (i == current_index)
            attitude_clean = "neutral"
            if attitude == "LBL_ATTR_HOSTILE": attitude_clean = "hostile"
            elif attitude == "LBL_ATTR_FRIENDLY": attitude_clean = "friendly"
            token_border_color = "#bdbdbd" 
            if is_active: token_border_color = "#ffb74d" 
            elif is_player: token_border_color = "#4caf50" 
            elif attitude_clean == "hostile": token_border_color = "#ef5350" 
            elif attitude_clean == "friendly": token_border_color = "#42a5f5" 
            if tid in self.tokens:
                token = self.tokens[tid]
                if token.border_color != token_border_color or token.current_size != self.token_size: token.update_appearance(self.token_size, token_border_color)
                token.setZValue(100 if is_active else 10)
                if x is not None and y is not None:
                    if self.scene.mouseGrabberItem() != token:
                        if abs(token.x() - x) > 1.0 or abs(token.y() - y) > 1.0: token.setPos(x, y)
            else:
                img_path = None
                if eid and eid in dm_manager.data["entities"]:
                    ent = dm_manager.data["entities"][eid]; rel_path = ent.get("image_path")
                    if not rel_path and ent.get("images"): rel_path = ent.get("images")[0]
                    if rel_path: img_path = dm_manager.get_full_path(rel_path)
                pixmap = QPixmap(img_path) if img_path and os.path.exists(img_path) else None
                new_token = BattleTokenItem(self.token_size, pixmap, token_border_color, name, tid, eid, self.on_token_moved)
                if x is not None and y is not None: new_token.setPos(x, y)
                else: offset = len(self.tokens) * (self.token_size + 10); new_token.setPos(50 + offset, 50)
                new_token.setZValue(100 if is_active else 10); self.scene.addItem(new_token); self.tokens[tid] = new_token
        
        to_remove = [tid for tid in self.tokens if tid not in incoming_tids]
        for tid in to_remove: self.scene.removeItem(self.tokens[tid]); del self.tokens[tid]

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
            lbl_name.setStyleSheet("font-weight: bold; border: none; background: transparent;")
            hp_txt = tr("LBL_HP_SIDEBAR", hp=hp) if is_player else tr("LBL_HP_UNKNOWN")
            lbl_hp = QLabel(hp_txt)
            lbl_hp.setStyleSheet("border: none; background: transparent; font-style: italic;")
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