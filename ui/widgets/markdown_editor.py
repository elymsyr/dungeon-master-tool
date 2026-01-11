from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QTextEdit, QTextBrowser, 
                             QPushButton, QStackedWidget, QListWidget, QListWidgetItem, 
                             QApplication, QFrame)
from PyQt6.QtCore import Qt, pyqtSignal, QPoint, QRect, QUrl
from PyQt6.QtGui import QPalette, QTextCursor
import markdown

class MentionPopup(QListWidget):
    """@ yazıldığında çıkan küçük liste."""
    selected = pyqtSignal(str, str) # name, id

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowFlags(Qt.WindowType.ToolTip | Qt.WindowType.FramelessWindowHint)
        self.setFixedWidth(200)
        self.setMaximumHeight(150)
        self.itemClicked.connect(self.on_item_clicked)
        self.setStyleSheet("border: 1px solid #444; background-color: #252526; color: white;")

    def on_item_clicked(self, item):
        self.selected.emit(item.text(), item.data(Qt.ItemDataRole.UserRole))
        self.hide()

class MarkdownEditor(QWidget):
    textChanged = pyqtSignal()
    # Linke tıklandığında (View modunda) tetiklenir
    entity_link_clicked = pyqtSignal(str) 

    def __init__(self, text="", placeholder="", parent=None):
        super().__init__(parent)
        self.dm = None # DataManager referansı sonra atanacak
        
        self.main_layout = QVBoxLayout(self)
        self.main_layout.setContentsMargins(0, 0, 0, 0)
        
        self.shared_style = """
            border: 1px solid rgba(128, 128, 128, 0.3);
            border-radius: 4px;
            padding-top: 5px; padding-left: 8px; padding-bottom: 5px; padding-right: 35px; 
            font-family: 'Segoe UI', sans-serif; font-size: 13px;
            background-color: rgba(0, 0, 0, 0.05);
        """
        
        self.stack = QStackedWidget(self)
        
        # 1. Editor
        self.editor = QTextEdit()
        self.editor.setPlaceholderText(placeholder)
        self.editor.setText(text)
        self.editor.setStyleSheet(self.shared_style)
        self.editor.textChanged.connect(self._on_text_changed)
        
        # 2. Viewer
        self.viewer = QTextBrowser()
        self.viewer.setOpenExternalLinks(False) # entity:// linklerini biz yakalayacağız
        self.viewer.anchorClicked.connect(self._on_link_clicked)
        self.viewer.setStyleSheet(self.shared_style)
        
        self.stack.addWidget(self.editor)
        self.stack.addWidget(self.viewer)
        self.main_layout.addWidget(self.stack)
        
        # Edit Butonu
        self.btn_toggle = QPushButton("✏️", self)
        self.btn_toggle.setFixedSize(28, 24)
        self.btn_toggle.setCheckable(True)
        self.btn_toggle.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_toggle.setStyleSheet("""
            QPushButton { background-color: rgba(128, 128, 128, 0.2); border-radius: 3px; color: palette(text); }
            QPushButton:checked { background-color: palette(highlight); color: palette(highlighted-text); }
        """)
        self.btn_toggle.clicked.connect(self.toggle_mode)
        
        # Mention Popup
        self.popup = MentionPopup(self)
        self.popup.selected.connect(self.insert_mention)
        self.popup.hide()

        self.toggle_mode()

    def set_data_manager(self, dm):
        self.dm = dm

    def _on_text_changed(self):
        self.textChanged.emit()
        
        # @ Algılama
        text = self.editor.toPlainText()
        cursor = self.editor.textCursor()
        pos = cursor.position()
        
        if pos > 0 and text[pos-1] == "@" and self.dm:
            self._show_mention_popup()

    def _show_mention_popup(self):
        self.popup.clear()
        mentions = self.dm.get_all_entity_mentions()
        
        if not mentions: return

        for m in mentions:
            item = QListWidgetItem(f"{m['name']}")
            item.setData(Qt.ItemDataRole.UserRole, m['id'])
            self.popup.addItem(item)
        
        # Popup'ı imlecin yanına taşı
        cursor_rect = self.editor.cursorRect()
        global_pos = self.editor.mapToGlobal(cursor_rect.bottomRight())
        self.popup.move(global_pos + QPoint(5, 5))
        self.popup.show()
        self.popup.setFocus()

    def insert_mention(self, name, eid):
        cursor = self.editor.textCursor()
        # Son @ karakterini sil
        cursor.deletePreviousChar()
        # Markdown Linki Ekle: [İsim](entity://id)
        link = f"[@{name}](entity://{eid})"
        cursor.insertText(link)
        self.editor.setFocus()

    def _on_link_clicked(self, url: QUrl):
        if url.scheme() == "entity":
            entity_id = url.host()
            self.entity_link_clicked.emit(entity_id)
        else:
            import webbrowser
            webbrowser.open(url.toString())

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self.btn_toggle.move(self.width() - self.btn_toggle.width() - 6, 6)
        self.btn_toggle.raise_()

    def toggle_mode(self):
        if self.btn_toggle.isChecked():
            self.stack.setCurrentIndex(0)
            self.editor.setFocus()
        else:
            raw_text = self.editor.toPlainText()
            # Markdown'ı HTML'e çevirirken bizim entity şemasını linke dönüştürür
            html_content = markdown.markdown(raw_text, extensions=['extra', 'nl2br'])
            
            pal = self.palette()
            c_text = pal.text().color().name()       
            c_link = pal.link().color().name()       
            c_high = pal.highlight().color().name()  
            
            styled_html = f"""
            <style>
                body {{ font-family: 'Segoe UI', sans-serif; font-size: 13px; color: {c_text}; margin: 0; }}
                a {{ color: {c_link}; text-decoration: none; font-weight: bold; }}
                h1, h2, h3 {{ color: {c_high}; margin-top: 10px; margin-bottom: 4px; font-weight: bold; }}
                strong {{ color: {c_high}; }}
                code {{ background-color: rgba(128,128,128,0.2); padding: 2px; border-radius: 3px; }}
            </style>
            {html_content}
            """
            self.viewer.setHtml(styled_html)
            self.stack.setCurrentIndex(1)
        self.btn_toggle.raise_()

    # Uyumluluk metodları
    def toPlainText(self): return self.editor.toPlainText()
    def setText(self, text):
        self.editor.setText(text if text else "")
        if not self.btn_toggle.isChecked(): self.toggle_mode()
    def setPlaceholderText(self, text): self.editor.setPlaceholderText(text)
    def setMinimumHeight(self, h): self.stack.setMinimumHeight(h); return super().setMinimumHeight(h)