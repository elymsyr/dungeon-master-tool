from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QTextEdit, QTextBrowser, 
                             QPushButton, QStackedWidget, QHBoxLayout, QApplication)
from PyQt6.QtCore import Qt, pyqtSignal
from PyQt6.QtGui import QIcon, QFont, QPalette, QColor
import markdown

class MarkdownEditor(QWidget):
    textChanged = pyqtSignal()

    def __init__(self, text="", placeholder="", parent=None):
        super().__init__(parent)
        
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(0, 0, 0, 0)
        self.layout.setSpacing(0)
        
        # --- ORTAK STİL (YAPISAL) ---
        self.shared_style = """
            border: 1px solid rgba(128, 128, 128, 0.4);
            border-radius: 4px;
            padding: 8px;
            font-family: 'Segoe UI', sans-serif;
            font-size: 13px;
        """
        
        # Üst Bar (Toggle Butonu)
        top_bar_layout = QHBoxLayout()
        top_bar_layout.setContentsMargins(0, 5, 5, 0)
        top_bar_layout.addStretch()
        
        self.btn_toggle = QPushButton("✏️") # Kalem ikonu (Düzenle)
        self.btn_toggle.setFixedSize(30, 25)
        self.btn_toggle.setCheckable(True)
        self.btn_toggle.setChecked(False) # Varsayılan: Kapalı (Görüntüleme Modu)
        self.btn_toggle.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_toggle.setToolTip("Düzenle / Önizle")
        
        # --- DİNAMİK TEMA BUTON STİLİ ---
        # palette(highlight) -> Temanın vurgu rengini alır (Mavi, Yeşil, Kırmızı vb.)
        # palette(highlighted-text) -> Vurgu üzerindeki yazı rengini alır (Genelde Beyaz)
        self.btn_toggle.setStyleSheet("""
            QPushButton { 
                background-color: rgba(128, 128, 128, 0.2); 
                border: 1px solid rgba(128, 128, 128, 0.5); 
                border-radius: 3px;
                color: palette(text);
            }
            QPushButton:checked { 
                background-color: palette(highlight); 
                color: palette(highlighted-text);
                border: 1px solid palette(highlight);
            }
            QPushButton:hover { 
                background-color: rgba(128, 128, 128, 0.4); 
            }
            QPushButton:checked:hover {
                opacity: 0.9;
            }
        """)
        self.btn_toggle.clicked.connect(self.toggle_mode)
        top_bar_layout.addWidget(self.btn_toggle)
        
        self.stack = QStackedWidget()
        
        # 1. Editör (Düzenleme Modu - Index 0)
        self.editor = QTextEdit()
        self.editor.setPlaceholderText(placeholder)
        self.editor.setText(text)
        self.editor.setStyleSheet(self.shared_style)
        self.editor.document().setDocumentMargin(4)
        self.editor.textChanged.connect(self.textChanged.emit)
        
        # 2. Görüntüleyici (Okuma Modu - Index 1)
        self.viewer = QTextBrowser()
        self.viewer.setOpenExternalLinks(True)
        self.viewer.setStyleSheet(self.shared_style)
        self.viewer.document().setDocumentMargin(4)
        
        self.stack.addWidget(self.editor)
        self.stack.addWidget(self.viewer)
        
        self.layout.addLayout(top_bar_layout)
        self.layout.addWidget(self.stack)
        
        # Başlangıç durumunu ayarla (Görüntüleme Modu)
        self.toggle_mode()

    def toggle_mode(self):
        if self.btn_toggle.isChecked():
            # --- DÜZENLEME MODU (Edit) ---
            self.stack.setCurrentIndex(0)
            # Editöre geçince odağı oraya ver
            self.editor.setFocus()
        else:
            # --- GÖRÜNTÜLEME MODU (Preview) ---
            raw_text = self.editor.toPlainText()
            
            # Boşsa placeholder'ı andıran bir yazı veya boşluk göster
            if not raw_text.strip():
                html_content = f"<span style='color:gray; font-style:italic;'>{self.editor.placeholderText()}</span>"
            else:
                html_content = markdown.markdown(raw_text, extensions=['extra', 'nl2br'])
            
            # --- DİNAMİK RENK SEÇİMİ ---
            pal = self.palette()
            
            c_text = pal.text().color().name()       
            c_link = pal.link().color().name()       
            c_high = pal.highlight().color().name()  
            c_mid  = pal.mid().color().name()        
            
            styled_html = f"""
            <style>
                body {{ 
                    font-family: 'Segoe UI', sans-serif; 
                    font-size: 13px; 
                    color: {c_text}; 
                }}
                a {{ color: {c_link}; text-decoration: none; font-weight: bold; }}
                
                h1, h2, h3, h4 {{ 
                    color: {c_high}; 
                    margin-top: 10px; margin-bottom: 5px; 
                    font-weight: bold; 
                }}
                h1 {{ font-size: 18px; border-bottom: 1px solid {c_mid}; padding-bottom: 3px; }}
                h2 {{ font-size: 16px; }}
                h3 {{ font-size: 14px; font-style: italic; }}
                
                strong {{ color: {c_high}; opacity: 0.9; }}
                em {{ opacity: 0.8; font-style: italic; }}
                
                ul, ol {{ margin-left: -15px; margin-bottom: 10px; }}
                li {{ margin-bottom: 2px; }}
                
                code {{ 
                    background-color: rgba(128, 128, 128, 0.2); 
                    padding: 2px 4px; 
                    border-radius: 3px; 
                    font-family: 'Consolas', monospace; 
                }}
                pre {{ 
                    background-color: rgba(128, 128, 128, 0.1); 
                    padding: 10px; 
                    border-radius: 4px; 
                    border: 1px solid {c_mid};
                }}
                
                blockquote {{ 
                    border-left: 4px solid {c_mid}; 
                    padding-left: 10px; 
                    color: {c_text}; 
                    opacity: 0.7;
                    margin: 5px 0; 
                }}
            </style>
            {html_content}
            """
            self.viewer.setHtml(styled_html)
            self.stack.setCurrentIndex(1)

    # --- QTextEdit Uyumluluk Metodları ---
    
    def toPlainText(self):
        return self.editor.toPlainText()

    def setText(self, text):
        self.editor.setText(text if text else "")
        # Metin dışarıdan değişirse ve şu an görüntüleme modundaysak, görüntüyü güncelle
        if not self.btn_toggle.isChecked():
            self.toggle_mode()

    def setPlaceholderText(self, text):
        self.editor.setPlaceholderText(text)
        # Görüntüleme modundaysak ve içerik boşsa placeholder'ı güncellemek için refresh
        if not self.btn_toggle.isChecked() and not self.editor.toPlainText().strip():
            self.toggle_mode()
        
    def setMinimumHeight(self, h):
        self.stack.setMinimumHeight(h)
        self.editor.setMinimumHeight(h)
        self.viewer.setMinimumHeight(h)
        
    def setMaximumHeight(self, h):
        self.stack.setMaximumHeight(h)
        self.editor.setMaximumHeight(h)
        self.viewer.setMaximumHeight(h)