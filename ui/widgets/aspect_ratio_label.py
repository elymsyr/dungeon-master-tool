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
        self._image_path = None  # Resim yolunu saklamak için
        self._placeholder_text = tr("LBL_NO_IMAGE")
        
        # Sürükleme için değişkenler
        self.drag_start_position = None

    def setPixmap(self, pixmap, path=None):
        self._pixmap = pixmap
        self._image_path = path # Yolu kaydet
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

    # --- DRAG & DROP BAŞLATMA ---
    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.drag_start_position = event.pos()
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if not (event.buttons() & Qt.MouseButton.LeftButton):
            return
        if not self.drag_start_position:
            return
        if (event.pos() - self.drag_start_position).manhattanLength() < QApplication.startDragDistance():
            return
        
        # Eğer resim yolu varsa sürüklemeyi başlat
        if self._image_path:
            drag = QDrag(self)
            mime_data = QMimeData()
            
            # Dosya yolunu URL olarak ekle (Standart dosya sürükleme formatı)
            mime_data.setUrls([QUrl.fromLocalFile(self._image_path)])
            # Ayrıca text olarak da ekle (Yedek)
            mime_data.setText(self._image_path)
            
            drag.setMimeData(mime_data)
            
            # Sürüklerken görünen hayalet resim
            if self._pixmap:
                drag.setPixmap(self._pixmap.scaled(64, 64, Qt.AspectRatioMode.KeepAspectRatio))
                
            drag.exec(Qt.DropAction.CopyAction)