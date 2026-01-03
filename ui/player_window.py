from PyQt6.QtWidgets import QMainWindow, QWidget, QVBoxLayout, QStackedWidget, QTextBrowser
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QPixmap
from ui.widgets.image_viewer import ImageViewer

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
        
        # STACKED WIDGET (Sayfalar arası geçiş için)
        self.stack = QStackedWidget()
        
        # SAYFA 1: RESİM GÖRÜNTÜLEYİCİ (Zoom/Pan özellikli)
        self.image_viewer = ImageViewer()
        self.stack.addWidget(self.image_viewer)
        
        # SAYFA 2: KARAKTER KARTI (HTML Stat Block)
        self.stat_viewer = QTextBrowser()
        self.stat_viewer.setStyleSheet("""
            QTextBrowser {
                background-color: #1a1a1a;
                color: #e0e0e0;
                border: none;
                padding: 20px;
                font-family: 'Segoe UI', serif;
            }
        """)
        self.stack.addWidget(self.stat_viewer)
        
        layout.addWidget(self.stack)

    def show_image(self, pixmap):
        """Sadece resmi gösterir"""
        self.stack.setCurrentIndex(0)
        self.image_viewer.set_image(pixmap)

    def show_stat_block(self, html_content):
        """Karakter kartını (HTML) gösterir"""
        self.stack.setCurrentIndex(1)
        self.stat_viewer.setHtml(html_content)