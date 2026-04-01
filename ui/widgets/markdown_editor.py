from PyQt6.QtWidgets import (QApplication, QWidget, QVBoxLayout, QTextEdit, QTextBrowser,
                             QPushButton, QStackedWidget, QListWidget, QListWidgetItem,
                             QSizePolicy, QStyle)
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
        self.refresh_theme(ThemeManager.get_palette("dark"))
        self.all_mentions = []

    def refresh_theme(self, palette: dict) -> None:
        bg = palette.get("ui_popup_bg", "#252526")
        border = palette.get("ui_popup_border", "#444")
        text = palette.get("ui_popup_text", "#ccc")
        sel = palette.get("ui_popup_selected", "#094771")
        self.setStyleSheet(f"""
            QListWidget {{
                border: 1px solid {border};
                background-color: {bg};
                color: {text};
                outline: none;
            }}
            QListWidget::item {{ padding: 5px; }}
            QListWidget::item:selected {{ background-color: {sel}; color: white; }}
        """)


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
        self.embedded_mode = False  # Flag for Mind Map embedded mode

    def mouseDoubleClickEvent(self, event):
        if self.embedded_mode:
            # In Mind Map mode: ignore so node handles the event
            event.ignore()
        else:
            # Normal mode: emit signal
            self.doubleClicked.emit()
            event.accept()

    def mousePressEvent(self, event):
        anchor = self.anchorAt(event.pos())
        if anchor:
            super().mousePressEvent(event)
            return

        if self.embedded_mode:
            # In Mind Map mode: ignore so drag works on the canvas
            event.ignore()
        else:
            # Normal mode: accept for text selection
            super().mousePressEvent(event)

    def contextMenuEvent(self, event):
        # Right-click is always ignored (suppresses both Mind Map menu and default context menu)
        event.ignore() 

class PropagatingTextEdit(QTextEdit):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAcceptDrops(True)
        self.dm = None  # DataManager reference

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
            
            # 1. Check: is this an Entity ID?
            # Only process if DataManager is set and the ID exists in entities
            if self.dm and text in self.dm.data.get("entities", {}):
                entity = self.dm.data["entities"][text]
                entity_name = entity.get("name", "Unknown")
                
                # Mention format: [@Name](entity://ID)
                formatted_text = f"[@{entity_name}](entity://{text}) "

                # Move cursor to drop position and insert text
                cursor = self.cursorForPosition(event.position().toPoint())
                cursor.insertText(formatted_text)
                
                # Odaklan
                self.setTextCursor(cursor)
                self.setFocus()
                
                event.acceptProposedAction()
            else:
                # Plain text drop: standard behavior
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
        self._toggle_visible = True
        self._inline_switch_enabled = True
        
        # Load the default (dark) palette
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
        self.viewer.doubleClicked.connect(self._on_viewer_double_clicked)
        
        self.stack.addWidget(self.editor)
        self.stack.addWidget(self.viewer)
        self.main_layout.addWidget(self.stack)
        
        self.btn_toggle = QPushButton(self)
        self.btn_toggle.setIcon(QApplication.style().standardIcon(QStyle.StandardPixmap.SP_FileDialogDetailedView))
        self.btn_toggle.setFixedSize(24, 24)
        self.btn_toggle.setCheckable(True)
        self.btn_toggle.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_toggle.clicked.connect(self.toggle_mode)
        
        # Initial style application
        self.apply_styles()

        if text.strip():
            self.switch_to_view_mode()
        else:
            self.switch_to_edit_mode()

    def set_embedded_mode(self, enabled):
        """Set to True when used inside a Mind Map node."""
        self.viewer.embedded_mode = enabled

    def set_transparent_mode(self, enabled):
        """Enables a transparent background, e.g. for Mind Map nodes."""
        self.is_transparent_mode = enabled
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, enabled)
        self.apply_styles()

    def set_mind_map_style(self):
        """Legacy compatibility wrapper."""
        self.set_embedded_mode(True)
        self.set_transparent_mode(True)

    def refresh_theme(self, palette):
        """Called when the theme changes externally (from MindMapNode or Main Window)."""
        self.current_palette = palette
        self.apply_styles()

    def apply_styles(self):
        """Applies styles based on the active palette and mode (transparent / normal)."""
        p = self.current_palette

        container_bg = "transparent"  # Default container bg

        if self.is_transparent_mode:
            # Mind Map mode: transparent background
            bg_color = "transparent"
            border = "none"
            # Text color for note card comes from palette
            text_color = p.get("node_text", "#000000")
            # Button background inside editor
            btn_bg = "rgba(0,0,0,0.1)"
        else:
            # Standard mode (inside a sheet): transparent text backgrounds
            bg_color = "transparent"
            border = "1px solid rgba(128, 128, 128, 0.3)"
            text_color = p.get("html_text", "#e0e0e0")
            btn_bg = "rgba(60,60,60,0.8)"

        style = f"""
            QWidget#mdContainer {{
                background: {container_bg};
            }}
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
        self.popup.refresh_theme(p)
        self.update_view_content()

    def update_view_content(self):
        raw_text = self.editor.toPlainText()
        html_content = markdown.markdown(raw_text, extensions=['extra', 'nl2br'])
        
        p = self.current_palette
        
        # Get colors from palette
        if self.is_transparent_mode:
            c_text = p.get("node_text", "#000000")
            c_link = p.get("html_link", "#1565c0")  # Links on Mind Map
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
        if self._toggle_visible:
            self.btn_toggle.setChecked(True)
            self.toggle_mode()
            return
        self.stack.setCurrentIndex(0)
        self.editor.setFocus()

    def switch_to_view_mode(self):
        if self._toggle_visible:
            self.btn_toggle.setChecked(False)
            self.toggle_mode()
            return
        self.update_view_content()
        self.stack.setCurrentIndex(1)

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
        
        # Shift+Enter: save and exit edit mode
        if obj is self.editor and event.type() == QEvent.Type.KeyPress:
            if event.key() == Qt.Key.Key_Return and (event.modifiers() & Qt.KeyboardModifier.ShiftModifier):
                if not self._inline_switch_enabled:
                    return False
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

    def _on_viewer_double_clicked(self):
        if not self._inline_switch_enabled:
            return
        self.switch_to_edit_mode()

    def resizeEvent(self, event):
        super().resizeEvent(event)
        if not self._toggle_visible:
            return
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
        self.switch_to_view_mode()
        
    def setPlaceholderText(self, text): self.editor.setPlaceholderText(text)
    def setMinimumHeight(self, h): self.stack.setMinimumHeight(h); return super().setMinimumHeight(h)
    def setMaximumHeight(self, h): self.stack.setMaximumHeight(h); return super().setMaximumHeight(h)

    def set_toggle_button_visible(self, visible: bool) -> None:
        self._toggle_visible = visible
        self.btn_toggle.setVisible(visible)
        if not visible:
            self._inline_switch_enabled = False

    def set_inline_switch_enabled(self, enabled: bool) -> None:
        self._inline_switch_enabled = enabled
