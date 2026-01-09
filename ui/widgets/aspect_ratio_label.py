from PyQt6.QtWidgets import QLabel
from PyQt6.QtGui import QPixmap
from PyQt6.QtCore import Qt
from core.locales import tr

class AspectRatioLabel(QLabel):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.setMinimumSize(100, 100)
        self.setStyleSheet("border: 2px dashed #444; background-color: #222; border-radius: 8px; color: #888;")
        self._pixmap = None
        # Varsayılan metni değişkende tutuyoruz
        self._placeholder_text = tr("LBL_NO_IMAGE")

    def setPixmap(self, pixmap):
        self._pixmap = pixmap
        self.update_image()

    def setPlaceholderText(self, text):
        """Resim yokken görünecek metni değiştirir."""
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
            # Sabit metin yerine değişkendeki metni kullanıyoruz
            self.setText(self._placeholder_text)