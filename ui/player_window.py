from PyQt6.QtWidgets import QMainWindow, QWidget, QVBoxLayout, QStackedWidget, QTextBrowser, QHBoxLayout
from PyQt6.QtCore import Qt, QUrl
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
        
        self.stack = QStackedWidget()
        
        # PAGE 0: MULTI-IMAGE VIEWER
        self.multi_image_widget = QWidget()
        self.multi_image_layout = QHBoxLayout(self.multi_image_widget)
        self.multi_image_layout.setContentsMargins(0, 0, 0, 0)
        self.multi_image_layout.setSpacing(2)
        self.stack.addWidget(self.multi_image_widget)
        
        # PAGE 1: CHARACTER SHEET
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

        # PAGE 2: PDF VIEWER
        self.pdf_viewer = None
        self.pdf_viewer_index = None
        
        layout.addWidget(self.stack)
        self.active_image_paths = []

    def add_image_to_view(self, image_path, pixmap=None):
        """Adds a new image to the screen. UPDATES if exists (Zoom persists)."""
        self.stack.setCurrentIndex(0)
        
        # --- UPDATE EXISTING LOGIC ---
        if image_path in self.active_image_paths:
            # Find the existing widget
            try:
                index = self.active_image_paths.index(image_path)
                item = self.multi_image_layout.itemAt(index)
                if item and item.widget():
                    viewer = item.widget()
                    if isinstance(viewer, ImageViewer) and pixmap:
                        viewer.update_pixmap(pixmap)
                        return # Updated successfully, exit
            except Exception as e:
                print(f"Error updating existing image view: {e}")
            # If update failed (e.g., wrong widget type), fall through to create new
            if image_path in self.active_image_paths:
                return # Should usually return here if it was just a duplicate add call without pixmap update

        # --- CREATE NEW LOGIC ---
        viewer = ImageViewer()
        
        if pixmap:
            # From memory (Map etc.)
            viewer.set_image(pixmap)
        else:
            # Read from file (Drag & Drop)
            loaded_pix = QPixmap(image_path)
            viewer.set_image(loaded_pix)
        
        self.multi_image_layout.addWidget(viewer)
        self.active_image_paths.append(image_path)

    def remove_image_from_view(self, image_path):
        if image_path not in self.active_image_paths:
            return
            
        index = self.active_image_paths.index(image_path)
        item = self.multi_image_layout.itemAt(index)
        if item:
            widget = item.widget()
            self.multi_image_layout.removeWidget(widget)
            widget.deleteLater()
            
        self.active_image_paths.pop(index)

    def clear_images(self):
        while self.multi_image_layout.count():
            item = self.multi_image_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        self.active_image_paths.clear()

    # Legacy compatibility methods
    def show_image(self, pixmap):
        self.clear_images()
        self.stack.setCurrentIndex(0)
        viewer = ImageViewer()
        viewer.set_image(pixmap)
        self.multi_image_layout.addWidget(viewer)

    def show_stat_block(self, html_content):
        self.stack.setCurrentIndex(1)
        self.stat_viewer.setHtml(html_content)

    def show_pdf(self, pdf_path):
        if self.pdf_viewer is None:
            from PyQt6.QtWebEngineWidgets import QWebEngineView
            self.pdf_viewer = QWebEngineView()
            self.pdf_viewer.setStyleSheet("background-color: #333;")
            self.stack.addWidget(self.pdf_viewer)
            self.pdf_viewer_index = self.stack.count() - 1
            self.pdf_viewer.settings().setAttribute(self.pdf_viewer.settings().WebAttribute.PluginsEnabled, True)
            self.pdf_viewer.settings().setAttribute(self.pdf_viewer.settings().WebAttribute.PdfViewerEnabled, True)
        
        self.stack.setCurrentIndex(self.pdf_viewer_index)
        local_url = QUrl.fromLocalFile(pdf_path)
        self.pdf_viewer.setUrl(local_url)

    def update_theme(self, qss):
        self.setStyleSheet(qss)