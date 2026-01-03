from PyQt6.QtWidgets import QMainWindow, QWidget, QVBoxLayout, QLabel
from PyQt6.QtCore import Qt

class PlayerWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Player View - Second Screen")
        self.resize(800, 600)
        self.setStyleSheet("background-color: black;")
        
        central = QWidget()
        self.setCentralWidget(central)
        layout = QVBoxLayout(central)
        layout.setContentsMargins(0, 0, 0, 0)
        
        self.viewer = QLabel()
        self.viewer.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.viewer.setStyleSheet("background-color: black;")
        layout.addWidget(self.viewer)
        
        self._current_pixmap = None

    def show_image(self, pixmap):
        self._current_pixmap = pixmap
        self.update_view()

    def resizeEvent(self, event):
        self.update_view()
        super().resizeEvent(event)

    def update_view(self):
        if self._current_pixmap and not self._current_pixmap.isNull():
            scaled = self._current_pixmap.scaled(self.viewer.size(), Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
            self.viewer.setPixmap(scaled)
        else:
            self.viewer.clear()