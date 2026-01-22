from PyQt6.QtWidgets import QLabel, QApplication
from PyQt6.QtGui import QPixmap, QDrag
from PyQt6.QtCore import Qt, QMimeData, QPoint, QUrl
from core.locales import tr

class AspectRatioLabel(QLabel):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.setMinimumSize(100, 100)
        self.setStyleSheet("border: 2px dashed #444; background-color: #222; border-radius: 8px; color: #888;")
        self._pixmap = None
        self._image_path = None 
        self._placeholder_text = tr("LBL_NO_IMAGE")
        self._drag_start_pos = None

    def setPixmap(self, pixmap, path=None):
        self._pixmap = pixmap
        self._image_path = path 
        self.update_image()

    def setPlaceholderText(self, text):
        self._placeholder_text = text
        self.update_image()

    def resizeEvent(self, event):
        self.update_image()
        super().resizeEvent(event)

    def update_image(self):
        if self._pixmap and not self._pixmap.isNull():
            scaled = self._pixmap.scaled(self.size(), Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
            super().setPixmap(scaled)
        else:
            super().setPixmap(QPixmap())
            self.setText(self._placeholder_text)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton and self._image_path:
            self._drag_start_pos = event.pos()
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if not (event.buttons() & Qt.MouseButton.LeftButton) or not self._drag_start_pos or not self._image_path:
            super().mouseMoveEvent(event)
            return

        if (event.pos() - self._drag_start_pos).manhattanLength() < QApplication.startDragDistance():
            super().mouseMoveEvent(event)
            return

        drag = QDrag(self)
        mime_data = QMimeData()
        
        # Path as text for ProjectionManager
        mime_data.setText(self._image_path)
        # Path as URL for general compatibility
        mime_data.setUrls([QUrl.fromLocalFile(self._image_path)])
        
        drag.setMimeData(mime_data)
        
        # Drag preview
        if self._pixmap:
            preview = self._pixmap.scaled(100, 100, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
            drag.setPixmap(preview)
            drag.setHotSpot(QPoint(preview.width() // 2, preview.height() // 2))

        drag.exec(Qt.DropAction.CopyAction)
        self._drag_start_pos = None