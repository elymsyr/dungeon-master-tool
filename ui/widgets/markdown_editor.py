from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QTextEdit, QTextBrowser, 
                             QPushButton, QStackedWidget, QSizePolicy)
from PyQt6.QtCore import Qt, pyqtSignal, QEvent
from PyQt6.QtGui import QPalette
import markdown

class MarkdownEditor(QWidget):
    textChanged = pyqtSignal()

    def __init__(self, text="", placeholder="", parent=None):
        super().__init__(parent)
        
        # Genişlik ve yükseklik politikası: Yatayda genişle, dikeyde içeriğe uy
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.MinimumExpanding)
        
        # Ana layout
        self.main_layout = QVBoxLayout(self)
        self.main_layout.setContentsMargins(0, 0, 0, 0)
        
        # --- STİL TANIMI ---
        # Padding-right: 35px vererek metnin ve kaydırma çubuğunun butonun altında kalmasını engelliyoruz
        self.shared_style = """
            border: 1px solid rgba(128, 128, 128, 0.3);
            border-radius: 4px;
            padding-top: 5px;
            padding-left: 8px;
            padding-bottom: 5px;
            padding-right: 35px; 
            font-family: 'Segoe UI', sans-serif;
            font-size: 13px;
            background-color: rgba(0, 0, 0, 0.05);
        """
        
        # Stacked Widget (Editor ve Viewer için)
        self.stack = QStackedWidget(self)
        
        # 1. Editör (Düzenleme Modu)
        self.editor = QTextEdit()
        self.editor.setPlaceholderText(placeholder)
        self.editor.setText(text)
        self.editor.setStyleSheet(self.shared_style)
        self.editor.document().setDocumentMargin(4)
        self.editor.textChanged.connect(self.textChanged.emit)
        
        # 2. Görüntüleyici (Markdown Modu)
        self.viewer = QTextBrowser()
        self.viewer.setOpenExternalLinks(True)
        self.viewer.setStyleSheet(self.shared_style)
        self.viewer.document().setDocumentMargin(4)
        
        self.stack.addWidget(self.editor)
        self.stack.addWidget(self.viewer)
        self.main_layout.addWidget(self.stack)
        
        # --- FLOATING BUTON (Ebeveyni doğrudan SELF yapıyoruz) ---
        self.btn_toggle = QPushButton("✏️", self)
        self.btn_toggle.setFixedSize(28, 24)
        self.btn_toggle.setCheckable(True)
        self.btn_toggle.setCursor(Qt.CursorShape.PointingHandCursor)
        
        self.btn_toggle.setStyleSheet("""
            QPushButton { 
                background-color: rgba(128, 128, 128, 0.2); 
                border: 1px solid rgba(128, 128, 128, 0.3); 
                border-radius: 3px;
                color: palette(text);
            }
            QPushButton:checked { 
                background-color: palette(highlight); 
                color: palette(highlighted-text);
                border: 1px solid palette(highlight);
            }
            QPushButton:hover { background-color: rgba(128, 128, 128, 0.4); }
        """)
        
        self.btn_toggle.clicked.connect(self.toggle_mode)
        
        # Başlangıç modu
        self.btn_toggle.setChecked(False)
        self.toggle_mode()

    def resizeEvent(self, event):
        """Butonu her zaman sağ üst köşede, border'ın içinde tutar."""
        super().resizeEvent(event)
        # Sağdan 6px, Üstten 6px boşluk bırak
        self.btn_toggle.move(self.width() - self.btn_toggle.width() - 6, 6)
        # Butonu her zaman katman olarak en üste çıkar
        self.btn_toggle.raise_()

    def toggle_mode(self):
        """Markdown ve Düzenleme modları arası geçiş yapar."""
        if self.btn_toggle.isChecked():
            # DÜZENLEME MODU
            self.stack.setCurrentIndex(0)
            self.editor.setFocus()
        else:
            # GÖRÜNTÜLEME MODU
            raw_text = self.editor.toPlainText()
            if not raw_text.strip():
                # Boşsa placeholder göster
                html_content = f"<span style='color:gray; font-style:italic;'>{self.editor.placeholderText()}</span>"
            else:
                html_content = markdown.markdown(raw_text, extensions=['extra', 'nl2br'])
            
            # Tema Renklerini Al
            pal = self.palette()
            c_text = pal.text().color().name()       
            c_link = pal.link().color().name()       
            c_high = pal.highlight().color().name()  
            c_mid  = pal.mid().color().name()        
            
            styled_html = f"""
            <style>
                body {{ font-family: 'Segoe UI', sans-serif; font-size: 13px; color: {c_text}; margin: 0; padding: 0; }}
                a {{ color: {c_link}; text-decoration: none; }}
                h1, h2, h3 {{ color: {c_high}; margin-top: 10px; margin-bottom: 4px; font-weight: bold; }}
                h1 {{ font-size: 16px; border-bottom: 1px solid {c_mid}; }}
                h2 {{ font-size: 14px; }}
                strong {{ color: {c_high}; }}
                ul, ol {{ margin-left: -15px; }}
                li {{ margin-bottom: 2px; }}
                code {{ background-color: rgba(128,128,128,0.2); padding: 2px; border-radius: 3px; }}
            </style>
            {html_content}
            """
            self.viewer.setHtml(styled_html)
            self.stack.setCurrentIndex(1)
        
        # Her mod değişiminde butonu tekrar en üste çıkar (Lost Emoji Fix)
        self.btn_toggle.raise_()

    # --- BOYUT AYARLARI (Yatayda serbest, dikeyde kısıtlı) ---
    def setMinimumHeight(self, h):
        self.stack.setMinimumHeight(h)
        return super().setMinimumHeight(h)

    def setMaximumHeight(self, h):
        self.stack.setMaximumHeight(h)
        return super().setMaximumHeight(h)

    # --- QT TEXTEDIT UYUMLULUĞU ---
    def toPlainText(self): return self.editor.toPlainText()
    
    def setText(self, text):
        self.editor.setText(text if text else "")
        if not self.btn_toggle.isChecked():
            self.toggle_mode()

    def setPlaceholderText(self, text):
        self.editor.setPlaceholderText(text)
        if not self.btn_toggle.isChecked() and not self.editor.toPlainText().strip():
            self.toggle_mode()