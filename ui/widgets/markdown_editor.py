from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QTextEdit, QTextBrowser, 
                             QPushButton, QStackedWidget, QListWidget, QListWidgetItem, 
                             QApplication, QSizePolicy)
from PyQt6.QtCore import Qt, pyqtSignal, QPoint, QEvent
from PyQt6.QtGui import QPalette, QTextCursor, QKeyEvent
import markdown

class MentionPopup(QListWidget):
    """Gelişmiş @ menüsü: Filtreleme ve Klavye desteği."""
    selected = pyqtSignal(str, str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowFlags(Qt.WindowType.ToolTip | Qt.WindowType.FramelessWindowHint)
        self.setFixedWidth(250)
        self.setMaximumHeight(200)
        self.itemClicked.connect(self.on_item_clicked)
        self.setStyleSheet("""
            QListWidget {
                border: 1px solid #444;
                background-color: #252526;
                color: #ccc;
                outline: none;
            }
            QListWidget::item { padding: 5px; }
            QListWidget::item:selected { background-color: #094771; color: white; }
        """)
        self.all_mentions = []

    def set_items(self, mentions):
        self.all_mentions = mentions
        self.update_filter("")

    def update_filter(self, query):
        self.clear()
        query = query.lower()
        for m in self.all_mentions:
            if not query or query in m['name'].lower():
                item = QListWidgetItem(f"{m['name']}")
                item.setData(Qt.ItemDataRole.UserRole, m['id'])
                self.addItem(item)
        
        if self.count() > 0:
            self.setCurrentRow(0)

    def on_item_clicked(self, item):
        if item:
            self.selected.emit(item.text(), item.data(Qt.ItemDataRole.UserRole))
        self.hide()

class MarkdownEditor(QWidget):
    textChanged = pyqtSignal()
    entity_link_clicked = pyqtSignal(str) 

    def __init__(self, text="", placeholder="", parent=None):
        super().__init__(parent)
        self.dm = None
        self.mention_start_pos = -1
        
        # UI Bileşenlerini oluştur (Event filter'dan önce tanımlanmalı)
        self.popup = MentionPopup(self)
        self.popup.selected.connect(self.insert_mention)
        
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.MinimumExpanding)
        self.main_layout = QVBoxLayout(self)
        self.main_layout.setContentsMargins(0, 0, 0, 0)
        
        self.shared_style = """
            border: 1px solid rgba(128, 128, 128, 0.3);
            border-radius: 4px;
            padding: 5px; padding-right: 35px; 
            font-family: 'Segoe UI', sans-serif; font-size: 13px;
            background-color: rgba(0, 0, 0, 0.05);
        """
        
        self.stack = QStackedWidget(self)
        self.editor = QTextEdit()
        self.editor.setPlaceholderText(placeholder)
        self.editor.setText(text)
        self.editor.setStyleSheet(self.shared_style)
        
        # Popup tanımlandıktan sonra filter'ı yükle
        self.editor.installEventFilter(self)
        self.editor.textChanged.connect(self._on_text_changed)
        
        self.viewer = QTextBrowser()
        self.viewer.setOpenExternalLinks(False)
        self.viewer.anchorClicked.connect(self._on_link_clicked)
        self.viewer.setStyleSheet(self.shared_style)
        
        self.stack.addWidget(self.editor)
        self.stack.addWidget(self.viewer)
        self.main_layout.addWidget(self.stack)
        
        self.btn_toggle = QPushButton("✏️", self)
        self.btn_toggle.setFixedSize(28, 24)
        self.btn_toggle.setCheckable(True)
        self.btn_toggle.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_toggle.setStyleSheet("QPushButton { background-color: rgba(128,128,128,0.2); border-radius: 3px; }")
        self.btn_toggle.clicked.connect(self.toggle_mode)
        
        self.toggle_mode()

    def set_data_manager(self, dm):
        self.dm = dm

    def eventFilter(self, obj, event):
        # Attribute check ekleyerek popup oluşmadan işlem yapılmasını engelliyoruz
        if hasattr(self, 'popup') and obj is self.editor and self.popup.isVisible():
            if event.type() == QEvent.Type.KeyPress:
                # PyQt6'da eventKeyPress içindeki event zaten QKeyEvent'tir
                key = event.key()
                
                if key == Qt.Key.Key_Up:
                    self.popup.setCurrentRow(max(0, self.popup.currentRow() - 1))
                    return True
                elif key == Qt.Key.Key_Down:
                    self.popup.setCurrentRow(min(self.popup.count() - 1, self.popup.currentRow() + 1))
                    return True
                elif key in [Qt.Key.Key_Enter, Qt.Key.Key_Return, Qt.Key.Key_Tab]:
                    if self.popup.currentItem():
                        self.popup.on_item_clicked(self.popup.currentItem())
                    return True
                elif key == Qt.Key.Key_Escape:
                    self.popup.hide()
                    return True
        return super().eventFilter(obj, event)

    def _on_text_changed(self):
        self.textChanged.emit()
        if not self.dm: return

        cursor = self.editor.textCursor()
        pos = cursor.position()
        text = self.editor.toPlainText()

        # İmlecin olduğu satırı kontrol et
        cursor.select(QTextCursor.SelectionType.LineUnderCursor)
        line_text = cursor.selectedText()
        
        # Satırdaki son @ işaretini bul
        idx = line_text.rfind("@")
        if idx != -1:
            query = line_text[idx+1:]
            if " " in query:
                self.popup.hide()
                return

            self.mention_start_pos = cursor.selectionStart() + idx
            
            if not self.popup.isVisible():
                self.popup.set_items(self.dm.get_all_entity_mentions())
                self._show_mention_popup()
            
            self.popup.update_filter(query)
        else:
            self.popup.hide()

    def _show_mention_popup(self):
        cursor_rect = self.editor.cursorRect()
        global_pos = self.editor.mapToGlobal(cursor_rect.bottomLeft())
        self.popup.move(global_pos + QPoint(0, 5))
        self.popup.show()

    def insert_mention(self, name, eid):
        cursor = self.editor.textCursor()
        # Yazılan geçici @sorgu metnini sil
        cursor.setPosition(self.mention_start_pos, QTextCursor.MoveMode.KeepAnchor)
        cursor.removeSelectedText()
        
        # Markdown linkini ekle
        link = f"[@{name}](entity://{eid})"
        cursor.insertText(link)
        self.editor.setFocus()

    def _on_link_clicked(self, url):
        if url.scheme() == "entity":
            self.entity_link_clicked.emit(url.host())
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
            html_content = markdown.markdown(raw_text, extensions=['extra', 'nl2br'])
            pal = self.palette()
            c_text = pal.text().color().name()
            c_link = pal.link().color().name()
            c_high = pal.highlight().color().name()
            
            styled_html = f"""
            <style>
                body {{ font-family: 'Segoe UI', sans-serif; font-size: 13px; color: {c_text}; margin: 0; }}
                a {{ color: {c_link}; text-decoration: none; font-weight: bold; }}
                h1, h2, h3 {{ color: {c_high}; margin-top: 10px; margin-bottom: 5px; font-weight: bold; }}
                strong {{ color: {c_high}; }}
                code {{ background-color: rgba(128,128,128,0.2); padding: 2px; border-radius: 3px; }}
            </style>
            {html_content}
            """
            self.viewer.setHtml(styled_html)
            self.stack.setCurrentIndex(1)
        self.btn_toggle.raise_()

    def toPlainText(self): return self.editor.toPlainText()
    def setText(self, text):
        self.editor.setText(text if text else "")
        if not self.btn_toggle.isChecked(): self.toggle_mode()
    def setPlaceholderText(self, text): self.editor.setPlaceholderText(text)
    def setMinimumHeight(self, h): self.stack.setMinimumHeight(h); return super().setMinimumHeight(h)
    def setMaximumHeight(self, h): self.stack.setMaximumHeight(h); return super().setMaximumHeight(h)