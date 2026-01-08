from PyQt6.QtWidgets import (QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, 
                             QLabel, QScrollArea, QFrame, QGraphicsView, 
                             QGraphicsScene, QGraphicsEllipseItem, QSlider, QGraphicsPixmapItem)
from PyQt6.QtGui import QPixmap, QColor, QFont, QBrush, QPen, QPainter, QPainterPath

from PyQt6.QtCore import Qt, QRectF, pyqtSignal, QPointF, QTimer, QRect
from core.locales import tr
import os

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
            # --- DÜZELTME: setPointSize yerine setPixelSize ---
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
            # --- DÜZELTME: setPointSize yerine setPixelSize ---
            font.setPixelSize(5)
            painter.setFont(font)
            painter.drawText(QRect(0, 12, 20, 8), Qt.AlignmentFlag.AlignCenter, str(self.duration))

# --- TOKEN (PUL) SINIFI ---
class BattleTokenItem(QGraphicsEllipseItem):
    def __init__(self, size, pixmap, border_color, name, tid, eid, on_move_callback):
        super().__init__(0, 0, size, size)
        
        self.tid = tid 
        self.eid = eid 
        self.name = name
        self.on_move_callback = on_move_callback 
        self.original_pixmap = pixmap 
        self.border_color = border_color
        
        self.setFlag(QGraphicsEllipseItem.GraphicsItemFlag.ItemIsMovable)
        self.setFlag(QGraphicsEllipseItem.GraphicsItemFlag.ItemIsSelectable)
        self.setFlag(QGraphicsEllipseItem.GraphicsItemFlag.ItemSendsGeometryChanges)
        
        self.setToolTip(name)
        self.update_appearance(size)

    def update_appearance(self, size):
        self.setRect(0, 0, size, size)
        pen = QPen(QColor(self.border_color))
        pen.setWidth(3)
        self.setPen(pen)
        
        if self.original_pixmap and not self.original_pixmap.isNull():
            scaled = self.original_pixmap.scaled(int(size), int(size), 
                                               Qt.AspectRatioMode.KeepAspectRatioByExpanding, 
                                               Qt.TransformationMode.SmoothTransformation)
            brush = QBrush(scaled)
            self.setBrush(brush)
        else:
            self.setBrush(QBrush(QColor("#444")))

    def mouseReleaseEvent(self, event):
        super().mouseReleaseEvent(event)
        if self.on_move_callback:
            self.on_move_callback(self.tid, self.pos().x(), self.pos().y())

# --- ANA PENCERE ---
class BattleMapWindow(QMainWindow):
    token_moved_signal = pyqtSignal(str, float, float)

    def __init__(self, data_manager):
        super().__init__()
        self.dm = data_manager
        self.tokens = {} 
        self.token_size = 50 
        self.map_item = None
        self.setWindowTitle(tr("TITLE_BATTLE_MAP"))
        self.resize(1200, 800)
        
        central = QWidget()
        self.setCentralWidget(central)
        main_layout = QHBoxLayout(central)
        main_layout.setContentsMargins(0, 0, 0, 0)
        
        # --- SOL: HARİTA ALANI ---
        map_layout = QVBoxLayout()
        toolbar = QHBoxLayout()
        toolbar.setContentsMargins(10, 5, 10, 5)
        
        self.lbl_size = QLabel(tr("LBL_TOKEN_SIZE"))
        self.lbl_size.setObjectName("toolbarLabel")
        self.slider_size = QSlider(Qt.Orientation.Horizontal)
        self.slider_size.setMinimum(20); self.slider_size.setMaximum(300)
        self.slider_size.setValue(self.token_size)
        self.slider_size.valueChanged.connect(self.change_token_size)
        self.slider_size.setFixedWidth(200)
        
        toolbar.addWidget(self.lbl_size)
        toolbar.addWidget(self.slider_size)
        toolbar.addStretch()
        map_layout.addLayout(toolbar)
        
        self.scene = QGraphicsScene()
        self.scene.setBackgroundBrush(QBrush(QColor("#111")))
        self.view = QGraphicsView(self.scene)
        self.view.setRenderHint(QPainter.RenderHint.Antialiasing)
        self.view.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)
        self.view.setDragMode(QGraphicsView.DragMode.ScrollHandDrag)
        self.view.setStyleSheet("border: none;") 
        self.view.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.view.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        map_layout.addWidget(self.view)
        
        # --- SAĞ: SIDEBAR ---
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
        
        main_layout.addLayout(map_layout, 1)
        main_layout.addWidget(self.sidebar, 0)

    def retranslate_ui(self):
        self.setWindowTitle(tr("TITLE_BATTLE_MAP"))
        self.lbl_size.setText(tr("LBL_TOKEN_SIZE"))
        self.lbl_title.setText(tr("TITLE_TURN_ORDER"))

    def resizeEvent(self, event):
        if self.map_item: self.fit_map_in_view()
        super().resizeEvent(event)

    def showEvent(self, event):
        if self.map_item: self.fit_map_in_view()
        super().showEvent(event)

    def fit_map_in_view(self):
        if self.map_item: self.view.fitInView(self.map_item, Qt.AspectRatioMode.KeepAspectRatio)

    def set_map_image(self, pixmap):
        if pixmap:
            if self.map_item: self.scene.removeItem(self.map_item)
            self.map_item = QGraphicsPixmapItem(pixmap)
            self.map_item.setZValue(-100)
            self.map_item.setTransformationMode(Qt.TransformationMode.SmoothTransformation)
            self.scene.addItem(self.map_item)
            self.scene.setSceneRect(self.map_item.boundingRect())
            QTimer.singleShot(100, self.fit_map_in_view)
        else:
            if self.map_item: self.scene.removeItem(self.map_item)
            self.map_item = None

    def change_token_size(self, val):
        self.token_size = val
        for token in self.tokens.values(): token.update_appearance(self.token_size)

    def on_token_moved(self, tid, x, y):
        self.token_moved_signal.emit(tid, x, y)

    def update_combat_data(self, combatants, current_index, map_path=None, saved_token_size=None):
        if saved_token_size:
            self.token_size = saved_token_size
            self.slider_size.blockSignals(True)
            self.slider_size.setValue(saved_token_size)
            self.slider_size.blockSignals(False)

        if map_path: self.set_map_image(QPixmap(map_path))

        while self.list_layout.count():
            item = self.list_layout.takeAt(0)
            if item.widget(): item.widget().deleteLater()
            
        active_tids = []
        for c in combatants:
            key = c.get("tid") or c.get("eid")
            if key: active_tids.append(key)
            
        to_remove = [tid for tid in self.tokens if tid not in active_tids]
        for tid in to_remove:
            self.scene.removeItem(self.tokens[tid])
            del self.tokens[tid]

        for i, c in enumerate(combatants):
            eid = c.get("eid")
            name = c.get("name", "???")
            hp = c.get("hp", "?")
            x, y = c.get("x"), c.get("y")
            conditions = c.get("conditions", []) 
            
            ent_type = c.get("type", "NPC")
            attitude = c.get("attitude", "LBL_ATTR_NEUTRAL")
            is_player = (ent_type == "Player")
            is_active = (i == current_index)
            
            attitude_clean = "neutral"
            if attitude == "LBL_ATTR_HOSTILE": attitude_clean = "hostile"
            elif attitude == "LBL_ATTR_FRIENDLY": attitude_clean = "friendly"
            
            img_path = None
            if eid and eid in self.dm.data["entities"]:
                ent = self.dm.data["entities"][eid]
                rel_path = ent.get("image_path")
                if not rel_path and ent.get("images"): rel_path = ent.get("images")[0]
                if rel_path: img_path = self.dm.get_full_path(rel_path)

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

            token_border_color = "#bdbdbd" 
            if is_active: token_border_color = "#ffb74d" 
            elif is_player: token_border_color = "#4caf50" 
            elif attitude_clean == "hostile": token_border_color = "#ef5350" 
            elif attitude_clean == "friendly": token_border_color = "#42a5f5" 

            token_key = c.get("tid")
            if not token_key: token_key = c.get("eid")
            
            if token_key:
                if token_key in self.tokens:
                    token = self.tokens[token_key]
                    token.border_color = token_border_color
                    token.update_appearance(self.token_size)
                    token.setZValue(100 if is_active else 10)
                    if x is not None and y is not None:
                         if abs(token.x() - x) > 1 or abs(token.y() - y) > 1: token.setPos(x, y)
                else:
                    pixmap = QPixmap(img_path) if img_path else None
                    token = BattleTokenItem(self.token_size, pixmap, token_border_color, name, token_key, eid, self.on_token_moved)
                    if x is not None and y is not None: token.setPos(x, y)
                    else:
                        offset = len(self.tokens) * (self.token_size + 10)
                        token.setPos(50 + offset, 50)
                    self.scene.addItem(token)
                    self.tokens[token_key] = token