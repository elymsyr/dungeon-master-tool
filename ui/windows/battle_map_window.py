from PyQt6.QtWidgets import (QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, 
                             QLabel, QScrollArea, QFrame, QGraphicsView, 
                             QGraphicsScene, QGraphicsEllipseItem, QSlider, QGraphicsPixmapItem)
from PyQt6.QtGui import QPixmap, QColor, QFont, QBrush, QPen, QPainter
from PyQt6.QtCore import Qt, QRectF, pyqtSignal, QPointF
from core.locales import tr

# --- TOKEN (PUL) SINIFI ---
class BattleTokenItem(QGraphicsEllipseItem):
    def __init__(self, size, pixmap, border_color, name, eid, on_move_callback):
        super().__init__(0, 0, size, size)
        
        self.eid = eid
        self.name = name
        self.on_move_callback = on_move_callback 
        self.original_pixmap = pixmap 
        self.border_color = border_color
        
        # Hareket ve Seçim Bayrakları
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
            self.on_move_callback(self.eid, self.pos().x(), self.pos().y())

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
        self.setStyleSheet("background-color: #121212; color: #e0e0e0;")
        
        central = QWidget()
        self.setCentralWidget(central)
        main_layout = QHBoxLayout(central)
        main_layout.setContentsMargins(0, 0, 0, 0)
        
        # --- SOL: HARİTA ALANI ---
        map_layout = QVBoxLayout()
        
        # Toolbar
        toolbar = QHBoxLayout()
        toolbar.setContentsMargins(10, 5, 10, 5)
        self.lbl_size = QLabel(tr("LBL_TOKEN_SIZE"))
        self.slider_size = QSlider(Qt.Orientation.Horizontal)
        self.slider_size.setMinimum(20); self.slider_size.setMaximum(300)
        self.slider_size.setValue(self.token_size)
        self.slider_size.valueChanged.connect(self.change_token_size)
        self.slider_size.setFixedWidth(200)
        toolbar.addWidget(self.lbl_size); toolbar.addWidget(self.slider_size); toolbar.addStretch()
        map_layout.addLayout(toolbar)
        
        # Grafik Sahnesi ve Görünümü
        self.scene = QGraphicsScene()
        self.scene.setBackgroundBrush(QBrush(QColor("#111")))
        
        self.view = QGraphicsView(self.scene)
        self.view.setRenderHint(QPainter.RenderHint.Antialiasing)
        self.view.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)
        self.view.setDragMode(QGraphicsView.DragMode.ScrollHandDrag)
        self.view.setStyleSheet("border: none;")
        
        # Scroll barları kapat (Tam sığdıracağımız için gerek yok)
        self.view.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.view.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        
        map_layout.addWidget(self.view)
        
        # --- SAĞ: SIDEBAR ---
        self.sidebar = QWidget()
        self.sidebar.setFixedWidth(300)
        self.sidebar.setStyleSheet("background-color: #1e1e1e; border-left: 1px solid #333;")
        sidebar_layout = QVBoxLayout(self.sidebar)
        
        self.lbl_title = QLabel(tr("TITLE_TURN_ORDER"))
        self.lbl_title.setStyleSheet("font-size: 16px; font-weight: bold; color: #ffb74d; padding: 10px; border-bottom: 1px solid #444;")
        self.lbl_title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        sidebar_layout.addWidget(self.lbl_title)
        
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        self.list_container = QWidget()
        self.list_layout = QVBoxLayout(self.list_container)
        self.list_layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        self.list_layout.setSpacing(5)
        scroll.setWidget(self.list_container)
        sidebar_layout.addWidget(scroll)
        
        main_layout.addWidget(self.sidebar, 0)

    def retranslate_ui(self):
        self.setWindowTitle(tr("TITLE_BATTLE_MAP"))
        self.lbl_size.setText(tr("LBL_TOKEN_SIZE"))
        self.lbl_title.setText(tr("TITLE_TURN_ORDER"))

    # --- EKRAN BOYUTLANDIRMA OLAYI ---
    def resizeEvent(self, event):
        """Pencere boyutu değiştiğinde haritayı tekrar sığdır"""
        if self.map_item:
            self.fit_map_in_view()
        super().resizeEvent(event)

    def showEvent(self, event):
        """Pencere ilk açıldığında haritayı sığdır"""
        if self.map_item:
            self.fit_map_in_view()
        super().showEvent(event)

    def fit_map_in_view(self):
        """Haritayı görüntü alanına (bozulmadan) sığdırır"""
        if self.map_item:
            self.view.fitInView(self.map_item, Qt.AspectRatioMode.KeepAspectRatio)

    def set_map_image(self, pixmap):
        if pixmap:
            if self.map_item: self.scene.removeItem(self.map_item)
            
            self.map_item = QGraphicsPixmapItem(pixmap)
            self.map_item.setZValue(-100)
            self.map_item.setTransformationMode(Qt.TransformationMode.SmoothTransformation)
            self.scene.addItem(self.map_item)
            self.scene.setSceneRect(self.map_item.boundingRect())
            
            # Resmi yükler yüklemez sığdır
            self.fit_map_in_view()
        else:
            if self.map_item: self.scene.removeItem(self.map_item)
            self.map_item = None

    def change_token_size(self, val):
        self.token_size = val
        for token in self.tokens.values():
            token.update_appearance(self.token_size)

    def on_token_moved(self, eid, x, y):
        self.token_moved_signal.emit(eid, x, y)

    def update_combat_data(self, combatants, current_index, map_path=None, saved_token_size=None):
        if saved_token_size:
            self.token_size = saved_token_size
            self.slider_size.blockSignals(True)
            self.slider_size.setValue(saved_token_size)
            self.slider_size.blockSignals(False)

        if map_path:
            self.set_map_image(QPixmap(map_path))

        # Sidebar Temizle
        while self.list_layout.count():
            item = self.list_layout.takeAt(0)
            if item.widget(): item.widget().deleteLater()
            
        active_ids = [c.get("eid") for c in combatants if c.get("eid")]
        
        # Token Temizle
        to_remove = [eid for eid in self.tokens if eid not in active_ids]
        for eid in to_remove:
            self.scene.removeItem(self.tokens[eid])
            del self.tokens[eid]

        # Listeyi Güncelle
        for i, c in enumerate(combatants):
            eid = c.get("eid")
            name = c.get("name", "???")
            hp = c.get("hp", "?")
            x, y = c.get("x"), c.get("y")
            
            is_player = False
            img_path = None
            if eid and eid in self.dm.data["entities"]:
                ent = self.dm.data["entities"][eid]
                if ent.get("type") == "Oyuncu": is_player = True
                
                rel_path = ent.get("image_path")
                if not rel_path and ent.get("images"): rel_path = ent.get("images")[0]
                if rel_path: img_path = self.dm.get_full_path(rel_path)

            # Sidebar Kartı
            card = QFrame()
            card_layout = QHBoxLayout(card); card_layout.setContentsMargins(5,5,5,5)
            style = "border: 2px solid #66bb6a;" if i == current_index else "border: 1px solid #444;"
            bg = "#2e7d32" if i == current_index else "#2b2b2b"
            card.setStyleSheet(f"background-color: {bg}; {style} border-radius: 5px;")
            
            lbl_name = QLabel(name); lbl_name.setStyleSheet("font-weight: bold;")
            hp_txt = tr("LBL_HP_SIDEBAR", hp=hp) if is_player else tr("LBL_HP_UNKNOWN")
            lbl_hp = QLabel(hp_txt); lbl_hp.setStyleSheet("color: #ef5350;" if is_player else "color: #888; font-style: italic;")
            card_layout.addWidget(lbl_name, 1); card_layout.addWidget(lbl_hp, 0)
            self.list_layout.addWidget(card)

            # Token Güncelleme
            if eid:
                border = "#ffb74d" if i == current_index else ("#4caf50" if is_player else "#d32f2f")
                
                if eid in self.tokens:
                    token = self.tokens[eid]
                    token.border_color = border
                    token.update_appearance(self.token_size)
                    token.setZValue(100 if i == current_index else 10)
                    
                    if x is not None and y is not None:
                         # Sürüklerken titremesin diye tolerans
                         if abs(token.x() - x) > 1 or abs(token.y() - y) > 1:
                             token.setPos(x, y)
                else:
                    pixmap = QPixmap(img_path) if img_path else None
                    token = BattleTokenItem(self.token_size, pixmap, border, name, eid, self.on_token_moved)
                    
                    if x is not None and y is not None:
                        token.setPos(x, y)
                    else:
                        offset = len(self.tokens) * (self.token_size + 10)
                        token.setPos(50 + offset, 50)
                    
                    self.scene.addItem(token)
                    self.tokens[eid] = token