from PyQt6.QtWidgets import (QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, 
                             QLabel, QScrollArea, QFrame, QGraphicsView, 
                             QGraphicsScene, QGraphicsEllipseItem, QSlider, 
                             QGraphicsPixmapItem, QPushButton)
from PyQt6.QtGui import (QPixmap, QColor, QFont, QBrush, QPen, QPainter, 
                         QPainterPath, QCursor, QWheelEvent, QMouseEvent)
from PyQt6.QtCore import Qt, QRectF, pyqtSignal, QPointF, QTimer, QRect, QPoint
from core.locales import tr
import os

# --- ÖZELLEŞTİRİLMİŞ GRAFİK GÖRÜNÜMÜ ---
class BattleMapView(QGraphicsView):
    # Sinyal: Görünen Alan Dikdörtgeni (Rect)
    view_changed_signal = pyqtSignal(QRectF)

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

    def _emit_view_state(self):
        """Ekranda görünen harita alanını hesaplar ve gönderir."""
        if self._programmatic_change: return
        
        # Viewport (Ekran) karesini Sahne (Harita) koordinatlarına çevir
        viewport_rect = self.viewport().rect()
        scene_rect = self.mapToScene(viewport_rect).boundingRect()
        
        self.view_changed_signal.emit(scene_rect)

    def wheelEvent(self, event: QWheelEvent):
        zoom_in_factor = 1.15
        zoom_out_factor = 1 / zoom_in_factor
        if event.angleDelta().y() > 0:
            self.scale(zoom_in_factor, zoom_in_factor)
        else:
            self.scale(zoom_out_factor, zoom_out_factor)
        
        self._emit_view_state()

    def mousePressEvent(self, event: QMouseEvent):
        if event.button() == Qt.MouseButton.MiddleButton:
            self._is_panning = True
            self._pan_start_pos = event.pos()
            self.setCursor(Qt.CursorShape.ClosedHandCursor)
            event.accept()
        else:
            super().mousePressEvent(event)

    def mouseReleaseEvent(self, event: QMouseEvent):
        if event.button() == Qt.MouseButton.MiddleButton:
            self._is_panning = False
            self.setCursor(Qt.CursorShape.ArrowCursor)
            event.accept()
        else:
            super().mouseReleaseEvent(event)

    def mouseMoveEvent(self, event: QMouseEvent):
        if self._is_panning:
            delta = event.pos() - self._pan_start_pos
            self._pan_start_pos = event.pos()
            self.horizontalScrollBar().setValue(self.horizontalScrollBar().value() - delta.x())
            self.verticalScrollBar().setValue(self.verticalScrollBar().value() - delta.y())
            event.accept()
            self._emit_view_state()
        else:
            super().mouseMoveEvent(event)

    def set_view_state(self, rect):
        """Dışarıdan gelen dikdörtgeni ekrana sığdırır (Fit)."""
        self._programmatic_change = True
        # KeepAspectRatio: En/Boy oranını koruyarak sığdır (Tam görünüm)
        self.fitInView(rect, Qt.AspectRatioMode.KeepAspectRatio)
        self._programmatic_change = False

# --- YARDIMCI SINIFLAR ---
class SidebarConditionIcon(QWidget):
    def __init__(self, name, icon_path, duration):
        super().__init__()
        self.name = name; self.icon_path = icon_path; self.duration = duration; self.setFixedSize(20, 20) 
        self.setToolTip(f"{name} ({duration} Turns)" if duration > 0 else name)
    def paintEvent(self, event):
        painter = QPainter(self); painter.setRenderHint(QPainter.RenderHint.Antialiasing); path = QPainterPath(); path.addEllipse(1, 1, 18, 18); painter.setClipPath(path)
        if self.icon_path and os.path.exists(self.icon_path): painter.drawPixmap(0, 0, 20, 20, QPixmap(self.icon_path))
        else:
            painter.setBrush(QBrush(QColor("#5c6bc0"))); painter.drawRect(0, 0, 20, 20); painter.setPen(Qt.GlobalColor.white)
            font = painter.font(); font.setPixelSize(7); font.setBold(True); painter.setFont(font)
            painter.drawText(QRect(0, 0, 20, 20), Qt.AlignmentFlag.AlignCenter, self.name[:2].upper())
        if self.duration > 0:
            painter.setClipping(False); painter.setBrush(QBrush(QColor(0, 0, 0, 200))); painter.setPen(Qt.PenStyle.NoPen); painter.drawRoundedRect(0, 12, 20, 8, 2, 2)
            painter.setPen(Qt.GlobalColor.white); font = painter.font(); font.setPixelSize(5); painter.setFont(font)
            painter.drawText(QRect(0, 12, 20, 8), Qt.AlignmentFlag.AlignCenter, str(self.duration))

class BattleTokenItem(QGraphicsEllipseItem):
    def __init__(self, size, pixmap, border_color, name, tid, eid, on_move_callback):
        super().__init__(0, 0, size, size)
        self.tid = tid; self.eid = eid; self.name = name; self.on_move_callback = on_move_callback; self.original_pixmap = pixmap; self.border_color = border_color; self.current_size = size
        self.setFlag(QGraphicsEllipseItem.GraphicsItemFlag.ItemIsMovable); self.setFlag(QGraphicsEllipseItem.GraphicsItemFlag.ItemIsSelectable); self.setFlag(QGraphicsEllipseItem.GraphicsItemFlag.ItemSendsGeometryChanges)
        self.setToolTip(name); self.update_appearance(size, border_color)
    def update_appearance(self, size, border_color=None):
        self.current_size = size; self.setRect(0, 0, size, size)
        if border_color: self.border_color = border_color
        pen = QPen(QColor(self.border_color)); pen.setWidth(3); self.setPen(pen)
        if self.original_pixmap and not self.original_pixmap.isNull():
            scaled = self.original_pixmap.scaled(int(size), int(size), Qt.AspectRatioMode.KeepAspectRatioByExpanding, Qt.TransformationMode.SmoothTransformation)
            brush = QBrush(scaled); self.setBrush(brush)
        else: self.setBrush(QBrush(QColor("#444")))
    def mouseReleaseEvent(self, event):
        super().mouseReleaseEvent(event)
        if self.on_move_callback: self.on_move_callback(self.tid, self.pos().x(), self.pos().y())

# --- ORTAK HARİTA WIDGET'I ---
class BattleMapWidget(QWidget):
    token_moved_signal = pyqtSignal(str, float, float)
    token_size_changed_signal = pyqtSignal(int)
    view_sync_signal = pyqtSignal(QRectF)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.tokens = {} 
        self.token_size = 50 
        self.map_item = None
        self.current_map_path = None
        
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        
        toolbar = QHBoxLayout(); toolbar.setContentsMargins(5, 5, 5, 5)
        self.btn_reset_view = QPushButton("🏠"); self.btn_reset_view.setToolTip("Fit Map to View"); self.btn_reset_view.setFixedSize(30, 25); self.btn_reset_view.clicked.connect(self.fit_map_in_view)
        self.lbl_size = QLabel(tr("LBL_TOKEN_SIZE")); self.lbl_size.setObjectName("toolbarLabel")
        self.slider_size = QSlider(Qt.Orientation.Horizontal); self.slider_size.setMinimum(20); self.slider_size.setMaximum(300); self.slider_size.setValue(self.token_size); self.slider_size.valueChanged.connect(self.change_token_size); self.slider_size.setFixedWidth(150)
        toolbar.addWidget(self.btn_reset_view); toolbar.addWidget(self.lbl_size); toolbar.addWidget(self.slider_size); toolbar.addStretch(); layout.addLayout(toolbar)
        
        self.scene = QGraphicsScene(); self.scene.setBackgroundBrush(QBrush(QColor("#111")))
        
        self.view = BattleMapView(self.scene) 
        self.view.setStyleSheet("border: none;") 
        self.view.view_changed_signal.connect(self.view_sync_signal.emit)
        
        layout.addWidget(self.view)

    def fit_map_in_view(self):
        if self.map_item: self.view.fitInView(self.map_item, Qt.AspectRatioMode.KeepAspectRatio)

    def apply_view_state(self, rect):
        self.view.set_view_state(rect)

    def set_map_image(self, pixmap, path_ref=None):
        if path_ref and path_ref == self.current_map_path and self.map_item: return
        self.current_map_path = path_ref
        if pixmap:
            if self.map_item: self.scene.removeItem(self.map_item)
            self.map_item = QGraphicsPixmapItem(pixmap); self.map_item.setZValue(-100); self.map_item.setTransformationMode(Qt.TransformationMode.SmoothTransformation); self.scene.addItem(self.map_item); self.scene.setSceneRect(self.map_item.boundingRect())
            QTimer.singleShot(50, self.fit_map_in_view)
        else:
            if self.map_item: self.scene.removeItem(self.map_item)
            self.map_item = None; self.current_map_path = None

    def change_token_size(self, val):
        self.token_size = val
        for token in self.tokens.values(): token.update_appearance(self.token_size)
        self.token_size_changed_signal.emit(val)

    def on_token_moved(self, tid, x, y): self.token_moved_signal.emit(tid, x, y)
    def retranslate_ui(self): self.lbl_size.setText(tr("LBL_TOKEN_SIZE"))

    def update_tokens(self, combatants, current_index, dm_manager, map_path=None, saved_token_size=None):
        if saved_token_size and saved_token_size != self.token_size:
            self.token_size = saved_token_size; self.slider_size.blockSignals(True); self.slider_size.setValue(saved_token_size); self.slider_size.blockSignals(False)
        if map_path: pix = QPixmap(map_path) if os.path.exists(map_path) else None; self.set_map_image(pix, map_path)
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

# --- ANA PENCERE (WRAPPER) ---
class BattleMapWindow(QMainWindow):
    token_moved_signal = pyqtSignal(str, float, float)

    def __init__(self, data_manager):
        super().__init__()
        self.dm = data_manager; self.map_item = None; self.setWindowTitle(tr("TITLE_BATTLE_MAP")); self.resize(1200, 800)
        central = QWidget(); self.setCentralWidget(central); main_layout = QHBoxLayout(central); main_layout.setContentsMargins(0, 0, 0, 0)
        self.map_widget = BattleMapWidget(); self.map_widget.token_moved_signal.connect(self.token_moved_signal.emit)
        self.slider_size = self.map_widget.slider_size 
        main_layout.addWidget(self.map_widget, 1)
        self.sidebar = QWidget(); self.sidebar.setFixedWidth(300); self.sidebar.setObjectName("sidebarFrame"); sidebar_layout = QVBoxLayout(self.sidebar)
        self.lbl_title = QLabel(tr("TITLE_TURN_ORDER")); self.lbl_title.setObjectName("headerLabel"); self.lbl_title.setAlignment(Qt.AlignmentFlag.AlignCenter); sidebar_layout.addWidget(self.lbl_title)
        scroll = QScrollArea(); scroll.setWidgetResizable(True); scroll.setFrameShape(QFrame.Shape.NoFrame); scroll.setObjectName("sidebarScroll")
        self.list_container = QWidget(); self.list_container.setObjectName("sheetContainer"); self.list_container.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)
        self.list_layout = QVBoxLayout(self.list_container); self.list_layout.setAlignment(Qt.AlignmentFlag.AlignTop); self.list_layout.setSpacing(5); scroll.setWidget(self.list_container); sidebar_layout.addWidget(scroll)
        main_layout.addWidget(self.sidebar, 0)

    def retranslate_ui(self): self.setWindowTitle(tr("TITLE_BATTLE_MAP")); self.lbl_title.setText(tr("TITLE_TURN_ORDER")); self.map_widget.retranslate_ui()
    def update_combat_data(self, combatants, current_index, map_path=None, saved_token_size=None):
        self.map_widget.update_tokens(combatants, current_index, self.dm, map_path, saved_token_size); self._update_sidebar(combatants, current_index)
    
    def sync_view(self, rect):
        """DM ekranından gelen dikdörtgeni uygular."""
        self.map_widget.apply_view_state(rect)

    def _update_sidebar(self, combatants, current_index):
        # --- HATA DÜZELTMESİ BURADA YAPILDI ---
        # Önceki kodda tek satırlık while döngüsü hatası vardı.
        # Şimdi döngü ve silme işlemi doğru bir şekilde ayrıldı.
        while self.list_layout.count(): 
            item = self.list_layout.takeAt(0)
            if item.widget(): 
                item.widget().deleteLater()
        
        for i, c in enumerate(combatants):
            name = c.get("name", "???"); hp = c.get("hp", "?"); conditions = c.get("conditions", []) 
            ent_type = c.get("type", "NPC"); attitude = c.get("attitude", "LBL_ATTR_NEUTRAL"); is_player = (ent_type == "Player"); is_active = (i == current_index)
            attitude_clean = "neutral"
            if attitude == "LBL_ATTR_HOSTILE": attitude_clean = "hostile"
            elif attitude == "LBL_ATTR_FRIENDLY": attitude_clean = "friendly"
            card = QFrame(); card.setProperty("class", "combatCard"); card.setProperty("active", str(is_active).lower()); card.setProperty("type", ent_type); card.setProperty("attitude", attitude_clean)
            card_main_layout = QVBoxLayout(card); card_main_layout.setContentsMargins(5, 5, 5, 5); card_main_layout.setSpacing(2)
            row_header = QWidget(); row_header_layout = QHBoxLayout(row_header); row_header_layout.setContentsMargins(0, 0, 0, 0); row_header_layout.setSpacing(5)
            lbl_name = QLabel(name); lbl_name.setStyleSheet("font-weight: bold; border: none; background: transparent;")
            hp_txt = tr("LBL_HP_SIDEBAR", hp=hp) if is_player else tr("LBL_HP_UNKNOWN"); lbl_hp = QLabel(hp_txt); lbl_hp.setStyleSheet("border: none; background: transparent; font-style: italic;")
            row_header_layout.addWidget(lbl_name, 1); row_header_layout.addWidget(lbl_hp, 0); card_main_layout.addWidget(row_header)
            if conditions:
                row_conditions = QWidget(); row_cond_layout = QHBoxLayout(row_conditions); row_cond_layout.setContentsMargins(0, 2, 0, 0); row_cond_layout.setSpacing(4); row_cond_layout.addStretch() 
                for cond in conditions: icon_widget = SidebarConditionIcon(cond.get("name", "?"), cond.get("icon"), cond.get("duration", 0)); row_cond_layout.addWidget(icon_widget)
                card_main_layout.addWidget(row_conditions)
            self.list_layout.addWidget(card)