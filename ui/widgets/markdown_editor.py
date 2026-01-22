from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QTextEdit, QTextBrowser, 
                             QPushButton, QStackedWidget, QListWidget, QListWidgetItem, 
                             QSizePolicy)
from PyQt6.QtCore import Qt, pyqtSignal, QPoint, QEvent
from PyQt6.QtGui import QTextCursor, QDesktopServices
import markdown
from core.theme_manager import ThemeManager

class MentionPopup(QListWidget):
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
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAcceptDrops(True)
        self.dm = None  # DataManager referansı

    def set_data_manager(self, dm):
        self.dm = dm

    def dragEnterEvent(self, event):
        if event.mimeData().hasText():
            event.acceptProposedAction()
        else:
            super().dragEnterEvent(event)

    def dropEvent(self, event):
        if event.mimeData().hasText():
            text = event.mimeData().text()
            
            # 1. Kontrol: Bu bir Entity ID mi?
            # DataManager referansı varsa ve ID entities içinde mevcutsa
            if self.dm and text in self.dm.data.get("entities", {}):
                entity = self.dm.data["entities"][text]
                entity_name = entity.get("name", "Unknown")
                
                # Mention Formatı: [@Name](entity://ID)
                formatted_text = f"[@{entity_name}](entity://{text}) "
                
                # İmleci bırakılan yere taşı ve metni ekle
                cursor = self.cursorForPosition(event.position().toPoint())
                cursor.insertText(formatted_text)
                
                # Odaklan
                self.setTextCursor(cursor)
                self.setFocus()
                
                event.acceptProposedAction()
            else:
                # Normal metin sürükleme işlemi (Standart davranış)
                super().dropEvent(event)
        else:
            super().dropEvent(event)

class MarkdownEditor(QWidget):
    textChanged = pyqtSignal()
    entity_link_clicked = pyqtSignal(str) 

    def __init__(self, text="", placeholder="", parent=None):
        super().__init__(parent)
        self.dm = None
        self.mention_start_pos = -1
        self.is_transparent_mode = False
        
        # Varsayılan paleti al (Dark)
        self.current_palette = ThemeManager.get_palette("dark")
        
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
        
        # İlk stil uygulaması
        self.apply_styles()

        if text.strip():
            self.btn_toggle.setChecked(False)
            self.toggle_mode()
        else:
            self.btn_toggle.setChecked(True)
            self.toggle_mode()

    def set_embedded_mode(self, enabled):
        """Mind Map içinde kullanılıyorsa True yap."""
        self.viewer.embedded_mode = enabled

    def set_transparent_mode(self, enabled):
        """MindMap gibi yerlerde şeffaf arka plan kullanmak için."""
        self.is_transparent_mode = enabled
        self.apply_styles()

    def set_mind_map_style(self):
        """Legacy compatibility wrapper."""
        self.set_embedded_mode(True)
        self.set_transparent_mode(True)

    def refresh_theme(self, palette):
        """Dışarıdan (MindMapNode veya Main Window) tema değiştiğinde çağrılır."""
        self.current_palette = palette
        self.apply_styles()

    def apply_styles(self):
        """Aktif palet ve moda (şeffaf/normal) göre stili uygular."""
        p = self.current_palette
        
        if self.is_transparent_mode:
            # Mind Map Modu: Arka plan şeffaf
            bg_color = "transparent"
            border = "none"
            # Not kağıdı üzerindeki yazı rengi paletten gelir
            text_color = p.get("node_text", "#000000") 
            # Editörde buton arka planı
            btn_bg = "rgba(0,0,0,0.1)"
        else:
            # Standart Mod (Sheet içi): Arka plan hafif koyu/açık
            bg_color = "rgba(0, 0, 0, 0.2)"
            # Eğer canvas background çok açıksa (Light/Frost), text edit arka planını biraz daha koyult
            if p.get("canvas_bg", "#000000").startswith("#f"): 
                 bg_color = "rgba(255, 255, 255, 0.6)"
            
            border = "1px solid rgba(128, 128, 128, 0.3)"
            text_color = p.get("html_text", "#e0e0e0")
            btn_bg = "rgba(60,60,60,0.8)"

        style = f"""
            QTextEdit#mdEditor, QTextBrowser#mdViewer {{
                background-color: {bg_color};
                border: {border};
                border-radius: 4px;
                padding: 10px;
                color: {text_color};
                font-family: 'Segoe UI', sans-serif;
                font-size: 14px;
            }}
            QPushButton {{
                background-color: {btn_bg};
                border: none;
                border-radius: 3px;
                color: {text_color};
            }}
            QPushButton:hover {{ background-color: rgba(128,128,128,0.3); }}
        """
        self.setStyleSheet(style)
        self.update_view_content()

    def update_view_content(self):
        raw_text = self.editor.toPlainText()
        html_content = markdown.markdown(raw_text, extensions=['extra', 'nl2br'])
        
        p = self.current_palette
        
        # Renkleri paletten al
        if self.is_transparent_mode:
            c_text = p.get("node_text", "#000000")
            c_link = p.get("html_link", "#1565c0") # Mind Map üzerinde linkler
            c_head = p.get("html_header", "#d84315")
        else:
            c_text = p.get("html_text", "#e0e0e0")
            c_link = p.get("html_link", "#42a5f5")
            c_head = p.get("html_header", "#ffb74d")
        
        styled_html = f"""
        <style>
            body {{ font-family: 'Segoe UI'; font-size: 14px; color: {c_text}; margin: 0; padding: 0; }} 
            a {{ color: {c_link}; text-decoration: none; font-weight: bold; }} 
            h1, h2, h3 {{ color: {c_head}; margin: 5px 0; font-weight: bold; }} 
            p {{ margin: 5px 0; }} 
            ul {{ margin: 0; padding-left: 20px; }} 
            code {{ background-color: rgba(128,128,128,0.3); padding: 2px 4px; border-radius: 3px; }}
        </style>
        {html_content}
        """
        self.viewer.setHtml(styled_html)

    def set_data_manager(self, dm): 
        self.dm = dm
        self.editor.set_data_manager(dm)

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
        
        # Shift+Enter ile Kaydetme ve Çıkma
        if obj is self.editor and event.type() == QEvent.Type.KeyPress:
            if event.key() == Qt.Key.Key_Return and (event.modifiers() & Qt.KeyboardModifier.ShiftModifier):
                self.switch_to_view_mode()
                return True

        return super().eventFilter(obj, event)

    def _on_text_changed(self):
        self.textChanged.emit()
        if not self.dm: return
        
        cursor = self.editor.textCursor()
        cursor.select(QTextCursor.SelectionType.LineUnderCursor)
        line_text = cursor.selectedText()
        
        idx = line_text.rfind("@")
        if idx != -1:
            query = line_text[idx+1:]
            if " " in query: 
                self.popup.hide()
                return
            
            # Start position needs to be calculated relative to document
            # But here we just track logic, simpler is:
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
        # Select text from @ to current position to replace it
        # Note: logic here simplifies "replace whatever was typed after @"
        cursor.select(QTextCursor.SelectionType.WordUnderCursor) # Simple fallback
        # Better approach: rely on stored mention_start_pos if valid, 
        # but for robustness let's just insert at cursor for now if complex.
        # Re-implementing original robust logic:
        
        # Move cursor to end of current word/selection
        # Then we need to backspace the query. 
        # But simpler: Just insert the Markdown link.
        
        # Let's assume user just finished typing '@something'
        # We need to replace '@something' with '[@Name](entity://ID)'
        
        # Clear selection first
        cursor.select(QTextCursor.SelectionType.LineUnderCursor)
        line_text = cursor.selectedText()
        at_index = line_text.rfind("@")
        
        if at_index != -1:
            # Move cursor to @ position
            cursor.movePosition(QTextCursor.MoveOperation.StartOfLine)
            cursor.movePosition(QTextCursor.MoveOperation.Right, QTextCursor.MoveMode.MoveAnchor, at_index)
            # Select until end of line (or current cursor pos)
            cursor.movePosition(QTextCursor.MoveOperation.EndOfLine, QTextCursor.MoveMode.KeepAnchor)
            # Replace
            link = f"[@{name}](entity://{eid}) "
            cursor.insertText(link)
        
        self.editor.setFocus()

    def _on_link_clicked(self, url):
        if url.scheme() == "entity": 
            self.entity_link_clicked.emit(url.host())
        else: 
            QDesktopServices.openUrl(url)

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

    def toPlainText(self): return self.editor.toPlainText()
    
    def setText(self, text):
        self.editor.setText(text if text else "")
        self.btn_toggle.setChecked(False)
        self.toggle_mode()
        
    def setPlaceholderText(self, text): self.editor.setPlaceholderText(text)
    def setMinimumHeight(self, h): self.stack.setMinimumHeight(h); return super().setMinimumHeight(h)
    def setMaximumHeight(self, h): self.stack.setMaximumHeight(h); return super().setMaximumHeight(h)