import os
from PyQt6.QtWidgets import (QWidget, QHBoxLayout, QSplitter, QMessageBox,
                             QTabWidget)
from PyQt6.QtCore import Qt, QEvent, pyqtSignal
from PyQt6.QtGui import QKeySequence, QShortcut

from ui.widgets.npc_sheet import NpcSheet
from ui.workers import ApiSearchWorker
from core.locales import tr
from core.theme_manager import ThemeManager

# Sidebar classes are no longer imported here as they are unused in this file.
# EntityTabWidget is managed in this file.

class EntityTabWidget(QTabWidget):
    """
    Tabbed card management widget on the right panel.
    Supports opening and closing cards via drag-and-drop.
    """
    def __init__(self, data_manager, parent_db_tab, panel_id):
        super().__init__()
        self.dm = data_manager
        self.parent_db_tab = parent_db_tab
        self.panel_id = panel_id
        
        self.setTabsClosable(True)
        self.setMovable(True)
        self.setAcceptDrops(True)  # Accept drag-and-drop
        
        self.tabCloseRequested.connect(self.close_tab)
        
        # --- SHORTCUT: Ctrl + W ---
        self.close_shortcut = QShortcut(QKeySequence("Ctrl+W"), self)
        self.close_shortcut.activated.connect(self.close_current_tab)

        # --- MOUSE MIDDLE CLICK TRACKING ---
        self.tabBar().installEventFilter(self)

        self.refresh_theme(ThemeManager.get_palette("dark"))

    def refresh_theme(self, palette: dict) -> None:
        """Reapply tab styling using the given palette."""
        border = palette.get("sidebar_divider", "#444")
        tab_bg = palette.get("tab_bg", "#2d2d2d")
        tab_active = palette.get("tab_active_bg", "#1e1e1e")
        tab_hover = palette.get("tab_hover_bg", "#3e3e3e")
        tab_text = palette.get("tab_text", "#aaa")
        tab_active_text = palette.get("tab_active_text", "white")
        indicator = palette.get("tab_indicator", "#007acc")
        self.setStyleSheet(
            f"QTabWidget::pane {{ border: 1px solid {border}; background-color: {tab_active}; }}"
            f"QTabBar::tab {{ background: {tab_bg}; color: {tab_text}; padding: 8px 15px; margin-right: 2px; }}"
            f"QTabBar::tab:selected {{ background: {tab_active}; color: {tab_active_text};"
            f" border-top: 2px solid {indicator}; font-weight: bold; }}"
            f"QTabBar::tab:hover {{ background: {tab_hover}; }}"
        )

    def close_current_tab(self):
        """Closes the active tab."""
        idx = self.currentIndex()
        if idx != -1:
            self.close_tab(idx)

    def eventFilter(self, obj, event):
        """Closes the tab when middle-clicked on the tab bar."""
        if obj is self.tabBar() and event.type() == QEvent.Type.MouseButtonRelease:
            if event.button() == Qt.MouseButton.MiddleButton:
                idx = self.tabBar().tabAt(event.pos())
                if idx != -1:
                    self.close_tab(idx)
                    return True
        return super().eventFilter(obj, event)

    def dragEnterEvent(self, event):
        if event.mimeData().hasText(): 
            event.acceptProposedAction()
        else:
            event.ignore()
        
    def dropEvent(self, event):
        # Get the ID dragged from the Sidebar
        eid = event.mimeData().text()
        self.parent_db_tab.open_entity_tab(eid, target_panel=self.panel_id)
        event.acceptProposedAction()
        
    def close_tab(self, index):
        widget = self.widget(index)
        if widget: 
            widget.deleteLater()
        self.removeTab(index)


class DatabaseTab(QWidget):
    entity_deleted = pyqtSignal()  # Signal emitted when an entity is deleted
    """
    Manages only the right-side workspace (Dual-Panel Card System).
    The left-side entity list lives in the Global Sidebar.
    """
    def __init__(self, data_manager, player_window):
        super().__init__()
        self.dm = data_manager
        self.player_window = player_window
        
        self.init_ui()

    def init_ui(self):
        main_layout = QHBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)
        
        # Workspace area only (Dual-Panel Card System)
        self.workspace_splitter = QSplitter(Qt.Orientation.Horizontal)
        
        self.tab_manager_left = EntityTabWidget(self.dm, self, "left")
        self.tab_manager_right = EntityTabWidget(self.dm, self, "right")
        
        # Minimum width to prevent panels from disappearing when empty
        self.tab_manager_left.setMinimumWidth(50)
        self.tab_manager_right.setMinimumWidth(50)
        
        self.workspace_splitter.addWidget(self.tab_manager_left)
        self.workspace_splitter.addWidget(self.tab_manager_right)
        
        # Equal split on startup
        self.workspace_splitter.setSizes([500, 500])
        self.workspace_splitter.setCollapsible(0, False)
        
        main_layout.addWidget(self.workspace_splitter)

    def open_entity_tab(self, eid, target_panel="left", data=None):
        """
        Opens a new NpcSheet tab for the given entity ID or data dict.
        API fetch logic is also handled here.
        """
        # 1. API ID check (lib_...)
        if eid and str(eid).startswith("lib_"):
            parts = str(eid).split("_", 2)
            if len(parts) < 3:
                return
            raw_cat = parts[1]
            raw_idx = parts[2]
            # Simple category mapping
            category_map = {
                "monsters": "Monster",
                "spells": "Spell",
                "equipment": "Equipment",
                "magic-items": "Equipment",
                "weapons": "Equipment",
                "armor": "Equipment",
                "classes": "Class",
                "races": "Race",
                "feats": "Feat",
                "conditions": "Condition",
                "backgrounds": "Background",
                "npc": "NPC",
            }
            target_cat = category_map.get(raw_cat, raw_cat.capitalize())
            
            # Fetch asynchronously with a Worker
            self._fetch_and_open_api_entity(target_cat, raw_idx, target_panel)
            return

        # 2. Determine the target Tab Manager
        target_manager = self.tab_manager_left if target_panel == "left" else self.tab_manager_right

        # 3. If already open, focus that tab
        if eid:
            for i in range(target_manager.count()):
                sheet = target_manager.widget(i)
                if sheet.property("entity_id") == eid: 
                    target_manager.setCurrentIndex(i)
                    return
            
            # Retrieve data from the database
            if not data:
                data = self.dm.data["entities"].get(eid)

        if not data:
            return  # No data — do not open

        # 4. Create new Sheet
        new_sheet = NpcSheet(self.dm)
        new_sheet.setProperty("entity_id", eid)
        
        # Signal connections
        # Clicking links inside the sheet calls this function again (recursive navigation)
        new_sheet.request_open_entity.connect(lambda id: self.open_entity_tab(id, target_panel))
        new_sheet.save_requested.connect(lambda: self.save_sheet_data(new_sheet))
        new_sheet.data_changed.connect(lambda: self.mark_tab_unsaved(new_sheet, target_manager))
        
        # Populate the sheet
        self.populate_sheet(new_sheet, data)

        # Delete and Projection buttons
        new_sheet.btn_delete.clicked.connect(lambda: self.delete_entity_from_tab(new_sheet))
        new_sheet.btn_project_pdf.clicked.connect(lambda: self.project_entity_pdf(new_sheet))
        
        # PDF buttons
        new_sheet.btn_add_pdf.clicked.connect(new_sheet.add_pdf_dialog)
        new_sheet.btn_open_pdf.clicked.connect(new_sheet.open_current_pdf)
        new_sheet.btn_remove_pdf.clicked.connect(new_sheet.remove_current_pdf)
        new_sheet.btn_open_pdf_folder.clicked.connect(new_sheet.open_pdf_folder)
        
        # Tab title
        icon_char = "👤" if data.get("type") == "NPC" else "🐉" if data.get("type") == "Monster" else "📜"
        tab_title = f"{icon_char} {data.get('name')}"
        if not eid: tab_title = f"⚠️ {tab_title}"  # Unsaved
        
        tab_index = target_manager.addTab(new_sheet, tab_title)
        target_manager.setCurrentIndex(tab_index)

    def _fetch_and_open_api_entity(self, cat, idx, target_panel):
        """Starts an API Worker."""
        self.api_worker = ApiSearchWorker(self.dm, cat, idx)
        self.api_worker.finished.connect(lambda s, d, m: self._on_api_fetched(s, d, m, target_panel))
        # Keep a reference to prevent garbage collection; cleared after the job completes
        self.api_worker.finished.connect(lambda: setattr(self, 'api_worker', None))
        self.api_worker.start()

    def _on_api_fetched(self, success, data_or_id, msg, target_panel):
        if success:
            if isinstance(data_or_id, dict):
                # New data received, prepare in import format
                processed_data = self.dm.prepare_entity_from_external(data_or_id)
                self.open_entity_tab(eid=None, target_panel=target_panel, data=processed_data)
            elif isinstance(data_or_id, str):
                # Already exists, ID returned
                self.open_entity_tab(data_or_id, target_panel)
        else: 
            QMessageBox.warning(self, tr("MSG_ERROR"), msg)

    def save_sheet_data(self, sheet):
        eid = sheet.property("entity_id")
        data = self.collect_data_from_sheet(sheet)
        if not data: return
        
        # Save
        new_eid = self.dm.save_entity(eid, data)
        sheet.setProperty("entity_id", new_eid)
        sheet.is_dirty = False
        
        # Update the tab title
        updated_data = self.dm.data["entities"][new_eid]
        sheet.inp_source.setText(updated_data.get("source", ""))  # Update source field

        # Find and update the tab title
        for manager in [self.tab_manager_left, self.tab_manager_right]:
            idx = manager.indexOf(sheet)
            if idx != -1:
                icon_char = "👤" if data.get("type") == "NPC" else "🐉"
                manager.setTabText(idx, f"{icon_char} {data.get('name')}")

    def delete_entity_from_tab(self, sheet):
        eid = sheet.property("entity_id")
        if not eid:
            # Not yet saved — just close
            self._close_sheet_tab(sheet)
            return

        if QMessageBox.question(self, tr("BTN_DELETE"), tr("MSG_CONFIRM_DELETE")) == QMessageBox.StandardButton.Yes:
            self.dm.delete_entity(eid)
            self._close_sheet_tab(sheet)
            # Emit the signal
            self.entity_deleted.emit()

    def _close_sheet_tab(self, sheet):
        for manager in [self.tab_manager_left, self.tab_manager_right]:
            idx = manager.indexOf(sheet)
            if idx != -1:
                manager.removeTab(idx)

    def get_active_sheet(self):
        """Return the currently focused NpcSheet, or fall back to the active tab."""
        from PyQt6.QtWidgets import QApplication
        w = QApplication.focusWidget()
        while w:
            if isinstance(w, NpcSheet):
                return w
            w = w.parentWidget()
        for manager in [self.tab_manager_left, self.tab_manager_right]:
            sheet = manager.currentWidget()
            if isinstance(sheet, NpcSheet):
                return sheet
        return None

    def mark_tab_unsaved(self, sheet, manager):
        idx = manager.indexOf(sheet)
        if idx != -1:
            current_title = manager.tabText(idx)
            if not current_title.startswith("*") and not current_title.startswith("⚠️"):
                manager.setTabText(idx, f"* {current_title}")

    # --- PROJECTION HELPERS ---
    def project_entity_pdf(self, sheet):
        current_item = sheet.list_pdfs.currentItem()
        if not current_item:
            QMessageBox.warning(self, tr("MSG_WARNING"), tr("MSG_SELECT_PDF_FIRST"))
            return
            
        rel_path = current_item.text()
        full_path = self.dm.get_full_path(rel_path)
        
        if full_path and os.path.exists(full_path):
            self.player_window.show_pdf(full_path)
            if not self.player_window.isVisible():
                self.player_window.show()
        else:
            QMessageBox.warning(self, tr("MSG_ERROR"), tr("MSG_FILE_NOT_FOUND_DISK"))

    # --- WRAPPERS ---
    def populate_sheet(self, s, data): 
        s.populate_sheet(data) 
    
    def collect_data_from_sheet(self, s): 
        return s.collect_data_from_sheet()

    def retranslate_ui(self):
        for manager in [self.tab_manager_left, self.tab_manager_right]:
            for i in range(manager.count()):
                widget = manager.widget(i)
                if hasattr(widget, "retranslate_ui"): widget.retranslate_ui()
