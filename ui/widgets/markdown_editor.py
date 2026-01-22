from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QTextEdit, QTextBrowser, 
                             QPushButton, QStackedWidget, QListWidget, QListWidgetItem, 
                             QSizePolicy)
from PyQt6.QtCore import Qt, pyqtSignal, QPoint, QEvent
from PyQt6.QtGui import QTextCursor, QDesktopServices
import markdown

class MentionPopup(QListWidget):
    selected = pyqtSignal(str, str)
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowFlags(Qt.WindowType.ToolTip | Qt.WindowType.FramelessWindowHint)
        self.setFixedWidth(250); self.setMaximumHeight(200)
        self.itemClicked.connect(self.on_item_clicked)
        self.setStyleSheet("QListWidget { border: 1px solid #444; background-color: #252526; color: #ccc; outline: none; } QListWidget::item { padding: 5px; } QListWidget::item:selected { background-color: #094771; color: white; }")
        self.all_mentions = []
    def set_items(self, mentions): self.all_mentions = mentions; self.update_filter("")
    def update_filter(self, query):
        self.clear(); query = query.lower()
        for m in self.all_mentions:
            if not query or query in m['name'].lower():
                item = QListWidgetItem(f"{m['name']}"); item.setData(Qt.ItemDataRole.UserRole, m['id']); self.addItem(item)
        if self.count() > 0: self.setCurrentRow(0)
    def on_item_clicked(self, item):
        if item: self.selected.emit(item.text(), item.data(Qt.ItemDataRole.UserRole))
        self.hide()

class ClickableTextBrowser(QTextBrowser):
    doubleClicked = pyqtSignal()
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.embedded_mode = False # Mind Map modu için bayrak

    def mouseDoubleClickEvent(self, event):
        if self.embedded_mode:
            # Mind Map'te Node işlemi yapması için olayı yoksay
            event.ignore()
        else:
            # Normal modda sinyali gönder
            self.doubleClicked.emit()
            event.accept()

    def mousePressEvent(self, event):
        anchor = self.anchorAt(event.pos())
        if anchor:
            super().mousePressEvent(event)
            return

        if self.embedded_mode:
            # Mind Map'te sürükleme yapabilmek için olayı yoksay
            event.ignore()
        else:
            # Normal modda metin seçimi için kabul et
            super().mousePressEvent(event)

    def contextMenuEvent(self, event):
        # Sağ tık her zaman yoksayılır (Mind Map menüsü veya Standart menü engeli)
        event.ignore() 

class PropagatingTextEdit(QTextEdit):
    pass

class MarkdownEditor(QWidget):
    textChanged = pyqtSignal()
    entity_link_clicked = pyqtSignal(str) 

    def __init__(self, text="", placeholder="", parent=None):
        super().__init__(parent)
        self.dm = None
        self.mention_start_pos = -1
        self.is_transparent_mode = False
        
        self.popup = MentionPopup(self)
        self.popup.selected.connect(self.insert_mention)
        
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.MinimumExpanding)
        self.main_layout = QVBoxLayout(self)
        self.main_layout.setContentsMargins(0, 0, 0, 0)
        self.setObjectName("mdContainer")
        
        self.stack = QStackedWidget(self)
        self.stack.setObjectName("mdStack")
        
        # EDIT MODE
        self.editor = PropagatingTextEdit()
        self.editor.setObjectName("mdEditor") 
        self.editor.setPlaceholderText(placeholder)
        self.editor.setText(text)
        self.editor.installEventFilter(self)
        self.editor.textChanged.connect(self._on_text_changed)
        
        # VIEW MODE
        self.viewer = ClickableTextBrowser()
        self.viewer.setObjectName("mdViewer") 
        self.viewer.setOpenExternalLinks(False)
        self.viewer.anchorClicked.connect(self._on_link_clicked)
        self.viewer.doubleClicked.connect(self.switch_to_edit_mode) 
        
        self.stack.addWidget(self.editor)
        self.stack.addWidget(self.viewer)
        self.main_layout.addWidget(self.stack)
        
        self.btn_toggle = QPushButton("✏️", self)
        self.btn_toggle.setFixedSize(24, 24)
        self.btn_toggle.setCheckable(True)
        self.btn_toggle.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_toggle.clicked.connect(self.toggle_mode)
        
        self.apply_default_style()

        if text.strip():
            self.btn_toggle.setChecked(False)
            self.toggle_mode()
        else:
            self.btn_toggle.setChecked(True)
            self.toggle_mode()

    def set_embedded_mode(self, enabled):
        """Mind Map içinde kullanılıyorsa True yap."""
        self.viewer.embedded_mode = enabled

    def apply_default_style(self):
        self.is_transparent_mode = False
        style = """
            QTextEdit#mdEditor, QTextBrowser#mdViewer {
                border: 1px solid rgba(128, 128, 128, 0.3);
                border-radius: 4px;
                padding: 10px;
                background-color: rgba(0, 0, 0, 0.2);
                color: #e0e0e0;
                font-family: 'Segoe UI', sans-serif;
                font-size: 14px;
            }
            QPushButton {
                background-color: rgba(60,60,60,0.8);
                border: none;
                border-radius: 3px;
            }
        """
        self.setStyleSheet(style)
        self.update_view_content()

    def set_mind_map_style(self):
        self.is_transparent_mode = True
        self.set_embedded_mode(True) # Önemli: Tıklama davranışını değiştir
        style = """
            QTextEdit#mdEditor, QTextBrowser#mdViewer {
                background-color: transparent;
                border: none;
                padding: 15px;
                color: #212121;
                font-family: 'Segoe UI', sans-serif;
                font-size: 14px;
            }
            QPushButton {
                background-color: rgba(0,0,0,0.1); 
                border: none; 
                border-radius: 3px;
                color: #212121;
            }
            QPushButton:hover { background-color: rgba(0,0,0,0.2); }
        """
        self.setStyleSheet(style)
        self.update_view_content()

    def set_data_manager(self, dm): self.dm = dm

    def switch_to_edit_mode(self):
        self.btn_toggle.setChecked(True)
        self.toggle_mode()

    def switch_to_view_mode(self):
        self.btn_toggle.setChecked(False)
        self.toggle_mode()

    def eventFilter(self, obj, event):
        if hasattr(self, 'popup') and obj is self.editor and self.popup.isVisible():
            if event.type() == QEvent.Type.KeyPress:
                key = event.key()
                if key == Qt.Key.Key_Up:
                    self.popup.setCurrentRow(max(0, self.popup.currentRow() - 1)); return True
                elif key == Qt.Key.Key_Down:
                    self.popup.setCurrentRow(min(self.popup.count() - 1, self.popup.currentRow() + 1)); return True
                elif key in [Qt.Key.Key_Enter, Qt.Key.Key_Return, Qt.Key.Key_Tab]:
                    if self.popup.currentItem(): self.popup.on_item_clicked(self.popup.currentItem()); return True
                elif key == Qt.Key.Key_Escape:
                    self.popup.hide(); return True
        
        # Shift+Enter ile Kaydetme ve Çıkma
        if obj is self.editor and event.type() == QEvent.Type.KeyPress:
            if event.key() == Qt.Key.Key_Return and (event.modifiers() & Qt.KeyboardModifier.ShiftModifier):
                self.switch_to_view_mode()
                return True

        return super().eventFilter(obj, event)

    def _on_text_changed(self):
        self.textChanged.emit()
        if not self.dm: return
        cursor = self.editor.textCursor(); pos = cursor.position(); cursor.select(QTextCursor.SelectionType.LineUnderCursor); line_text = cursor.selectedText()
        idx = line_text.rfind("@")
        if idx != -1:
            query = line_text[idx+1:]
            if " " in query: self.popup.hide(); return
            self.mention_start_pos = cursor.selectionStart() + idx
            if not self.popup.isVisible(): self.popup.set_items(self.dm.get_all_entity_mentions()); self._show_mention_popup()
            self.popup.update_filter(query)
        else: self.popup.hide()

    def _show_mention_popup(self):
        cursor_rect = self.editor.cursorRect(); global_pos = self.editor.mapToGlobal(cursor_rect.bottomLeft()); self.popup.move(global_pos + QPoint(0, 5)); self.popup.show()

    def insert_mention(self, name, eid):
        cursor = self.editor.textCursor(); cursor.setPosition(self.mention_start_pos, QTextCursor.MoveMode.KeepAnchor); cursor.removeSelectedText()
        link = f"[@{name}](entity://{eid})"; cursor.insertText(link); self.editor.setFocus()

    def _on_link_clicked(self, url):
        if url.scheme() == "entity": self.entity_link_clicked.emit(url.host())
        else: QDesktopServices.openUrl(url)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self.btn_toggle.move(self.width() - self.btn_toggle.width() - 6, 6)
        self.btn_toggle.raise_()

    def toggle_mode(self):
        if self.btn_toggle.isChecked():
            self.stack.setCurrentIndex(0)
            self.editor.setFocus()
        else:
            self.update_view_content()
            self.stack.setCurrentIndex(1)
        self.btn_toggle.raise_()

    def update_view_content(self):
        raw_text = self.editor.toPlainText()
        html_content = markdown.markdown(raw_text, extensions=['extra', 'nl2br'])
        
        # Renk Kontrolü
        c_text = "#212121" if self.is_transparent_mode else "#e0e0e0"
        c_link = "#1565c0" if self.is_transparent_mode else "#42a5f5"
        c_high = "#d84315" if self.is_transparent_mode else "#ffb74d"
        
        styled_html = f"""
        <style>
            body {{ font-family: 'Segoe UI'; font-size: 14px; color: {c_text}; margin: 0; padding: 0; }} 
            a {{ color: {c_link}; text-decoration: none; font-weight: bold; }} 
            h1, h2, h3 {{ color: {c_high}; margin: 5px 0; font-weight: bold; }} 
            p {{ margin: 5px 0; }} 
            ul {{ margin: 0; padding-left: 20px; }} 
        </style>
        {html_content}
        """
        self.viewer.setHtml(styled_html)

    def toPlainText(self): return self.editor.toPlainText()
    def setText(self, text):
        self.editor.setText(text if text else "")
        self.btn_toggle.setChecked(False)
        self.toggle_mode()
    def setPlaceholderText(self, text): self.editor.setPlaceholderText(text)
    def setMinimumHeight(self, h): self.stack.setMinimumHeight(h); return super().setMinimumHeight(h)
    def setMaximumHeight(self, h): self.stack.setMaximumHeight(h); return super().setMaximumHeight(h)