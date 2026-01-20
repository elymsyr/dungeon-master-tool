import os
from PyQt6.QtWidgets import (QWidget, QHBoxLayout, QLabel, QFrame, QVBoxLayout)
from PyQt6.QtGui import QPixmap
from PyQt6.QtCore import Qt, pyqtSignal

class ProjectionThumbnail(QFrame):
    """Small thumbnail for the header toolbar."""
    remove_requested = pyqtSignal(str)

    def __init__(self, image_path, pixmap=None, parent=None):
        super().__init__(parent)
        self.image_path = image_path
        # Small size to fit in header
        self.setFixedSize(50, 36)
        self.setStyleSheet("""
            QFrame { 
                background-color: #333; 
                border: 1px solid #555; 
                border-radius: 4px; 
            }
            QFrame:hover {
                border-color: #ff5555;
            }
        """)
        
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        
        self.lbl_img = QLabel()
        self.lbl_img.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        self.update_thumbnail(image_path, pixmap)
            
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setToolTip("Click to remove from Player Screen")
        layout.addWidget(self.lbl_img)

    def update_thumbnail(self, image_path, pixmap):
        filename = os.path.basename(image_path)
        
        # Harita kontrolü (İster dosya olsun ister hafıza objesi)
        if "map_snapshot" in filename or "Live_Map" in filename:
            self.lbl_img.setText("MAP")
            self.lbl_img.setStyleSheet("font-weight: bold; color: #ffb74d; font-size: 11px; background: transparent;")
        
        elif pixmap:
            # Hafızadan gelen resim varsa direkt kullan
            scaled = pixmap.scaled(48, 34, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
            self.lbl_img.setPixmap(scaled)
            
        elif os.path.exists(image_path):
            # Dosyadan oku
            pix = QPixmap(image_path).scaled(48, 34, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
            self.lbl_img.setPixmap(pix)
        else:
            self.lbl_img.setText("?")
            self.lbl_img.setStyleSheet("font-size: 10px; color: #aaa;")

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.remove_requested.emit(self.image_path)

class ProjectionManager(QWidget):
    """Drop zone that sits inside the main toolbar."""
    # Sinyal artık (Path, PixmapObject) taşıyor. Pixmap yoksa None gider.
    image_added = pyqtSignal(str, object)
    image_removed = pyqtSignal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAcceptDrops(True)
        self.setFixedHeight(40)
        self.setMinimumWidth(120) 
        self.setObjectName("projectionBar")
        
        self.default_style = """
            QWidget#projectionBar {
                background-color: rgba(0, 0, 0, 0.2);
                border: 1px dashed rgba(255, 255, 255, 0.3);
                border-radius: 4px; 
            }
        """
        self.hover_style = """
            QWidget#projectionBar {
                background-color: rgba(50, 150, 250, 0.2);
                border: 1px solid #42a5f5;
                border-radius: 4px;
            }
        """
        self.setStyleSheet(self.default_style)
        
        self.layout = QHBoxLayout(self)
        self.layout.setContentsMargins(5, 2, 5, 2)
        self.layout.setSpacing(5)
        self.layout.setAlignment(Qt.AlignmentFlag.AlignLeft)
        
        self.lbl_info = QLabel("📥 Drop to Project")
        self.lbl_info.setStyleSheet("color: #888; font-size: 11px; font-style: italic; border: none; background: transparent;")
        self.lbl_info.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.layout.addWidget(self.lbl_info)
        
        self.thumbnails = {} 

    def dragEnterEvent(self, event):
        if event.mimeData().hasUrls() or event.mimeData().hasText():
            event.acceptProposedAction()
            self.setStyleSheet(self.hover_style)

    def dragLeaveEvent(self, event):
        self.setStyleSheet(self.default_style)

    def dropEvent(self, event):
        self.setStyleSheet(self.default_style)
        image_path = None
        
        if event.mimeData().hasUrls():
            urls = event.mimeData().urls()
            if urls:
                image_path = urls[0].toLocalFile()
        elif event.mimeData().hasText():
            image_path = event.mimeData().text()
            
        if image_path and os.path.exists(image_path) and image_path.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp', '.webp')):
            self.add_image(image_path)
            event.acceptProposedAction()

    def add_image(self, path, pixmap=None):
        """
        path: Dosya yolu (ID olarak kullanılır).
        pixmap: (Opsiyonel) Eğer varsa diskten okumak yerine bu kullanılır.
        """
        if path in self.thumbnails: 
            # UPDATE EXISTING
            thumb = self.thumbnails[path]
            thumb.update_thumbnail(path, pixmap)
            # Re-emit signal so PlayerWindow knows to update its view
            self.image_added.emit(path, pixmap)
            return
            
        self.lbl_info.hide()
        
        thumb = ProjectionThumbnail(path, pixmap=pixmap)
        thumb.remove_requested.connect(self.remove_image)
        self.layout.addWidget(thumb)
        
        self.thumbnails[path] = thumb
        
        # Sinyali tetikle: PlayerWindow'a gönder
        self.image_added.emit(path, pixmap)
        
        self.setMinimumWidth(self.minimumWidth() + 55)

    def remove_image(self, path):
        if path in self.thumbnails:
            widget = self.thumbnails.pop(path)
            self.layout.removeWidget(widget)
            widget.deleteLater()
            
            self.image_removed.emit(path)
            self.setMinimumWidth(max(120, self.minimumWidth() - 55))
            
            if not self.thumbnails:
                self.lbl_info.show()