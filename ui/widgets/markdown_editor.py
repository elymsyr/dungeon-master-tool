from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QTextEdit, QTextBrowser, 
                             QPushButton, QStackedWidget, QHBoxLayout, QSizePolicy)
from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtGui import QPalette
import markdown

class MarkdownEditor(QWidget):
    textChanged = pyqtSignal()

    def __init__(self, text="", placeholder="", parent=None):
        super().__init__(parent)
        
        # Ensure the widget respects the parent layout's width constraints
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.MinimumExpanding)
        
        self.main_layout = QVBoxLayout(self)
        self.main_layout.setContentsMargins(0, 0, 0, 0)
        self.main_layout.setSpacing(0)
        
        # --- SHARED STYLE ---
        # Removed hardcoded background to let the Card theme take over
        # Added large padding-right so text clears the floating button
        self.shared_style = """
            border: 1px solid rgba(128, 128, 128, 0.3);
            border-radius: 4px;
            padding-top: 5px;
            padding-left: 8px;
            padding-bottom: 5px;
            padding-right: 32px; 
            font-family: 'Segoe UI', sans-serif;
            font-size: 13px;
            background-color: rgba(0, 0, 0, 0.05);
        """
        
        # Floating Container
        self.container = QWidget()
        self.container_layout = QVBoxLayout(self.container)
        self.container_layout.setContentsMargins(0, 0, 0, 0)
        
        self.stack = QStackedWidget()
        
        # 1. Editor
        self.editor = QTextEdit()
        self.editor.setPlaceholderText(placeholder)
        self.editor.setText(text)
        self.editor.setStyleSheet(self.shared_style)
        self.editor.document().setDocumentMargin(4)
        self.editor.textChanged.connect(self.textChanged.emit)
        
        # 2. Viewer
        self.viewer = QTextBrowser()
        self.viewer.setOpenExternalLinks(True)
        self.viewer.setStyleSheet(self.shared_style)
        self.viewer.document().setDocumentMargin(4)
        
        self.stack.addWidget(self.editor)
        self.stack.addWidget(self.viewer)
        self.container_layout.addWidget(self.stack)
        
        # --- THE FLOATING EDIT BUTTON ---
        self.btn_toggle = QPushButton("✏️", self.container)
        self.btn_toggle.setFixedSize(26, 22)
        self.btn_toggle.setCheckable(True)
        self.btn_toggle.setCursor(Qt.CursorShape.PointingHandCursor)
        
        self.btn_toggle.setStyleSheet("""
            QPushButton { 
                background-color: rgba(128, 128, 128, 0.1); 
                border: 1px solid rgba(128, 128, 128, 0.2); 
                border-radius: 3px;
            }
            QPushButton:checked { 
                background-color: palette(highlight); 
                color: palette(highlighted-text);
            }
            QPushButton:hover { background-color: rgba(128, 128, 128, 0.3); }
        """)
        
        self.btn_toggle.clicked.connect(self.toggle_mode)
        self.main_layout.addWidget(self.container)
        
        self.toggle_mode()

    def resizeEvent(self, event):
        """Keep the button locked to the top-right corner."""
        super().resizeEvent(event)
        # Position 5px from top and 5px from right
        self.btn_toggle.move(self.width() - self.btn_toggle.width() - 5, 5)

    def toggle_mode(self):
        if self.btn_toggle.isChecked():
            self.stack.setCurrentIndex(0)
            self.editor.setFocus()
        else:
            raw_text = self.editor.toPlainText()
            if not raw_text.strip():
                html_content = f"<span style='color:gray; font-style:italic;'>{self.editor.placeholderText()}</span>"
            else:
                html_content = markdown.markdown(raw_text, extensions=['extra', 'nl2br'])
            
            pal = self.palette()
            c_text = pal.text().color().name()       
            c_link = pal.link().color().name()       
            c_high = pal.highlight().color().name()  
            c_mid  = pal.mid().color().name()        
            
            styled_html = f"""
            <style>
                body {{ font-family: 'Segoe UI', sans-serif; font-size: 13px; color: {c_text}; margin: 0; }}
                a {{ color: {c_link}; text-decoration: none; }}
                h1, h2, h3 {{ color: {c_high}; margin-top: 10px; margin-bottom: 4px; font-weight: bold; }}
                h1 {{ font-size: 16px; border-bottom: 1px solid {c_mid}; }}
                h2 {{ font-size: 14px; }}
                strong {{ color: {c_high}; }}
                ul, ol {{ margin-left: -15px; }}
            </style>
            {html_content}
            """
            self.viewer.setHtml(styled_html)
            self.stack.setCurrentIndex(1)

    # --- Fixed Height Methods (Only affects height, allows layout to handle width) ---
    def setMinimumHeight(self, h):
        self.editor.setMinimumHeight(h)
        self.viewer.setMinimumHeight(h)
        self.stack.setMinimumHeight(h)

    def setMaximumHeight(self, h):
        self.editor.setMaximumHeight(h)
        self.viewer.setMaximumHeight(h)
        self.stack.setMaximumHeight(h)

    # QTextEdit Compatibility
    def toPlainText(self): return self.editor.toPlainText()
    def setText(self, text):
        self.editor.setText(text if text else "")
        if not self.btn_toggle.isChecked(): self.toggle_mode()
    def setPlaceholderText(self, text):
        self.editor.setPlaceholderText(text)
        if not self.btn_toggle.isChecked() and not self.editor.toPlainText().strip():
            self.toggle_mode()