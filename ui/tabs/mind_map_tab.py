import logging
import uuid
import copy

from PyQt6.QtCore import QPointF, QRectF, Qt, QTimer
from PyQt6.QtGui import QAction, QBrush, QColor, QCursor, QKeySequence, QPainter, QPen, QPixmap, QShortcut
from PyQt6.QtWidgets import (
    QFrame,
    QGraphicsItem,
    QGraphicsProxyWidget,
    QGraphicsScene,
    QGraphicsView,
    QGridLayout,
    QHBoxLayout,
    QMenu,
    QMessageBox,
    QLineEdit,
    QPlainTextEdit,
    QPushButton,
    QSplitter,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from core.locales import tr
from core.theme_manager import ThemeManager
from ui.widgets.aspect_ratio_label import AspectRatioLabel
from ui.widgets.markdown_editor import MarkdownEditor
from ui.widgets.mind_map_items import ConnectionLine, MindMapNode
from ui.widgets.npc_sheet import NpcSheet

logger = logging.getLogger(__name__)

class MindMapScene(QGraphicsScene):
    def __init__(self, parent=None):
        super().__init__(parent)
        # Initial palette (Dark)
        self.current_palette = ThemeManager.get_palette("dark")
        self.apply_palette_bg()
        self.grid_mode = True

    def set_palette(self, palette):
        """Updates the theme."""
        self.current_palette = palette
        self.apply_palette_bg()
        self.update() # Redraw trigger

    def apply_palette_bg(self):
        bg_color = self.current_palette.get("canvas_bg", "#181818")
        self.setBackgroundBrush(QBrush(QColor(bg_color)))

    def drawBackground(self, painter, rect):
        super().drawBackground(painter, rect)
        if not self.grid_mode:
            return

        # Skip grid at very low zoom — too many dots, too expensive
        views = self.views()
        if views:
            zoom = views[0].transform().m11()
            if zoom < 0.15:
                return
            # At low zoom, increase grid spacing to reduce dot count
            grid_size = 40 if zoom >= 0.4 else int(40 / zoom * 0.4)
        else:
            grid_size = 40

        # Get grid color from palette
        grid_rgba = self.current_palette.get("grid_color", "rgba(255, 255, 255, 10)")
        grid_color = QColor(grid_rgba)
        if not grid_color.isValid():
            grid_color = QColor(255, 255, 255, 10)  # Fallback

        left = int(rect.left()) - (int(rect.left()) % grid_size)
        top = int(rect.top()) - (int(rect.top()) % grid_size)
        points = []
        for x in range(left, int(rect.right()), grid_size):
            for y in range(top, int(rect.bottom()), grid_size):
                points.append(QPointF(x, y))

        painter.setPen(QPen(grid_color, 2))
        painter.drawPoints(points)

_LOD_THRESHOLD = 0.2  # below this zoom level, switch nodes to template rendering


class CustomGraphicsView(QGraphicsView):
    def __init__(self, scene, parent_tab):
        super().__init__(scene)
        self.parent_tab = parent_tab
        self.setRenderHint(QPainter.RenderHint.Antialiasing)
        self.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)
        self.setDragMode(QGraphicsView.DragMode.ScrollHandDrag)
        self.setTransformationAnchor(QGraphicsView.ViewportAnchor.AnchorUnderMouse)
        self.setResizeAnchor(QGraphicsView.ViewportAnchor.AnchorUnderMouse)
        self.setAcceptDrops(True)
        self.setStyleSheet("border: none; background: transparent;")
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)

    def contextMenuEvent(self, event):
        item = self.itemAt(event.pos())
        if not item:
            self.parent_tab.show_canvas_context_menu(event.globalPos(), self.mapToScene(event.pos()))
        else:
            super().contextMenuEvent(event)

    def zoom_in(self):
        self.scale(1.2, 1.2)
        self._update_node_lod()

    def zoom_out(self):
        self.scale(1 / 1.2, 1 / 1.2)
        self._update_node_lod()

    def _update_node_lod(self):
        zoom = self.transform().m11()
        for node in self.parent_tab.nodes.values():
            node.set_detail_level(zoom)

    def wheelEvent(self, event):
        item = self.itemAt(event.position().toPoint())
        if isinstance(item, QGraphicsProxyWidget):
            event.ignore()
            return

        zoom_in = 1.15
        zoom_out = 1 / 1.15
        if event.angleDelta().y() > 0:
            self.scale(zoom_in, zoom_in)
        else:
            self.scale(zoom_out, zoom_out)
        self._update_node_lod()
        self.parent_tab.trigger_autosave()

    def dragEnterEvent(self, event):
        if event.mimeData().hasText(): event.accept()
        else: event.ignore()

    def dragMoveEvent(self, event): event.accept()

    def dropEvent(self, event):
        eid = event.mimeData().text()
        pos = self.mapToScene(event.position().toPoint())
        self.parent_tab.create_entity_node(eid, pos.x(), pos.y())
        event.accept()

class FloatingControls(QWidget):
    def __init__(self, view_ref, parent_tab, parent=None):
        super().__init__(parent)
        self.view = view_ref
        self.parent_tab = parent_tab
        self.current_palette = ThemeManager.get_palette("dark")
        
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(8)
        
        self.btn_in = self._create_btn(tr("BTN_ZOOM_IN"), self.view.zoom_in, tr("TIP_ZOOM_IN"))
        self.btn_out = self._create_btn(tr("BTN_ZOOM_OUT"), self.view.zoom_out, tr("TIP_ZOOM_OUT"))
        self.btn_center = self._create_btn(tr("BTN_CENTER"), lambda: self.view.centerOn(0, 0), tr("TIP_CENTER"))
        self.btn_see_all = self._create_btn(tr("BTN_SEE_ALL"), self.parent_tab.see_all_workspaces, tr("TIP_SEE_ALL"))
        self.btn_ws_list = self._create_btn(tr("BTN_WORKSPACES"), self.show_workspace_menu, tr("BTN_WORKSPACES"))
        
        layout.addWidget(self.btn_in)
        layout.addWidget(self.btn_out)
        layout.addWidget(self.btn_center)
        layout.addWidget(self.btn_see_all)
        layout.addWidget(self.btn_ws_list)
        
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.update_style()

    def update_theme(self, palette):
        self.current_palette = palette
        # Refresh button labels in case the language changed
        self.btn_in.setText(tr("BTN_ZOOM_IN")); self.btn_in.setToolTip(tr("TIP_ZOOM_IN"))
        self.btn_out.setText(tr("BTN_ZOOM_OUT")); self.btn_out.setToolTip(tr("TIP_ZOOM_OUT"))
        self.btn_center.setText(tr("BTN_CENTER")); self.btn_center.setToolTip(tr("TIP_CENTER"))
        self.btn_see_all.setText(tr("BTN_SEE_ALL")); self.btn_see_all.setToolTip(tr("TIP_SEE_ALL"))
        self.btn_ws_list.setText(tr("BTN_WORKSPACES")); self.btn_ws_list.setToolTip(tr("BTN_WORKSPACES"))
        self.update_style()

    def update_style(self):
        p = self.current_palette
        bg = p.get("ui_floating_bg", "rgba(40, 40, 40, 230)")
        border = p.get("ui_floating_border", "#555")
        text = p.get("ui_floating_text", "#eee")
        hover_bg = p.get("ui_floating_hover_bg", "#42a5f5")
        
        style = f"""
            QPushButton {{ 
                background-color: {bg}; 
                color: {text}; 
                border: 1px solid {border}; 
                border-radius: 6px; 
                font-size: 11px; 
                font-weight: bold;
                font-family: 'Segoe UI', sans-serif;
            }} 
            QPushButton:hover {{ 
                background-color: {hover_bg}; 
                border-color: {hover_bg}; 
                color: white; 
            }}
        """
        for btn in [self.btn_in, self.btn_out, self.btn_center, self.btn_see_all, self.btn_ws_list]:
            btn.setStyleSheet(style)

    def show_workspace_menu(self):
        menu = QMenu(self)
        p = self.current_palette
        menu.setStyleSheet(f"QMenu {{ background-color: {p.get('ui_floating_bg', '#333')}; color: {p.get('ui_floating_text', '#eee')}; border: 1px solid {p.get('ui_floating_border', '#555')}; font-size: 14px; padding: 5px; }} QMenu::item {{ padding: 5px 20px; }} QMenu::item:selected {{ background-color: {p.get('ui_floating_hover_bg', '#42a5f5')}; }}")
        
        if not self.parent_tab.workspaces:
            act = QAction(tr("LBL_NO_ITEMS"), menu)
            act.setEnabled(False)
            menu.addAction(act)
        else:
            for ws in self.parent_tab.workspaces.values():
                act = QAction(f"🔲 {ws.name}", menu)
                act.triggered.connect(lambda checked, w=ws: self.parent_tab.zoom_to_workspace(w))
                menu.addAction(act)
        
        menu.exec(self.btn_ws_list.mapToGlobal(self.btn_ws_list.rect().bottomLeft()))

    def _create_btn(self, text, func, tip):
        btn = QPushButton(text)
        btn.setFixedSize(100, 30)
        btn.setToolTip(tip)
        btn.clicked.connect(func)
        btn.setCursor(Qt.CursorShape.PointingHandCursor)
        return btn

class MindMapTab(QWidget):
    def __init__(self, data_manager, main_window_ref=None, event_bus=None):
        super().__init__()
        self.dm = data_manager
        self.main_window_ref = main_window_ref
        self._global_edit_mode = False
        if event_bus:
            event_bus.subscribe("edit_mode.changed", self._on_edit_mode_changed)
        self.player_window = main_window_ref.player_window if main_window_ref else None
        
        self.nodes = {} 
        self.connections = [] 
        self.workspaces = {}
        self.pending_connection_source = None
        self.current_map_id = "default"
        self._history = []
        self._history_index = -1
        self._history_limit = 100
        self._suspend_autosave = False
        self._history_restoring = False
        
        self.autosave_timer = QTimer(self)
        self.autosave_timer.setSingleShot(True)
        self.autosave_timer.setInterval(2000) 
        self.autosave_timer.timeout.connect(self.save_map_data_silent)
        
        self.entity_autosave_timer = QTimer(self)
        self.entity_autosave_timer.setSingleShot(True)
        self.entity_autosave_timer.setInterval(1000)
        self.entity_autosave_timer.timeout.connect(self.process_pending_entity_saves)
        self.pending_entity_saves = set()
        
        self.init_ui()
        
        # Theme initialization
        current_theme = self.dm.current_theme  # "dark", "ocean", etc.
        self.apply_theme(current_theme)
        
        self.load_map_data()
        self._record_history_snapshot(force=True)

    def init_ui(self):
        main_layout = QHBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0); main_layout.setSpacing(0)
        
        canvas_container = QWidget()
        canvas_layout = QVBoxLayout(canvas_container)
        canvas_layout.setContentsMargins(0, 0, 0, 0); canvas_layout.setSpacing(0)
        
        self.scene = MindMapScene()
        self.scene.setSceneRect(-100000, -100000, 200000, 200000)
        
        self.view = CustomGraphicsView(self.scene, self)
        self.view.horizontalScrollBar().valueChanged.connect(lambda _: self.trigger_autosave())
        self.view.verticalScrollBar().valueChanged.connect(lambda _: self.trigger_autosave())
        canvas_layout.addWidget(self.view)
        
        self.floating_controls = FloatingControls(self.view, self, self.view)
        
        overlay_layout = QGridLayout(self.view)
        overlay_layout.setContentsMargins(0, 0, 20, 20)
        overlay_layout.addWidget(self.floating_controls, 1, 1, Qt.AlignmentFlag.AlignBottom | Qt.AlignmentFlag.AlignRight)
        
        self.lbl_save_status = QPushButton(tr("LBL_SAVED"), self.view)
        self.lbl_save_status.setFixedSize(120, 25)
        self.lbl_save_status.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        overlay_layout.addWidget(self.lbl_save_status, 0, 1, Qt.AlignmentFlag.AlignTop | Qt.AlignmentFlag.AlignRight)

        main_layout.addWidget(canvas_container)
        self._setup_shortcuts()

    def _setup_shortcuts(self):
        self.shortcut_undo = QShortcut(QKeySequence("Ctrl+Z"), self)
        self.shortcut_undo.setContext(Qt.ShortcutContext.WidgetWithChildrenShortcut)
        self.shortcut_undo.activated.connect(self.handle_undo_shortcut)

        self.shortcut_redo = QShortcut(QKeySequence("Ctrl+Shift+Z"), self)
        self.shortcut_redo.setContext(Qt.ShortcutContext.WidgetWithChildrenShortcut)
        self.shortcut_redo.activated.connect(self.handle_redo_shortcut)

    def _forward_shortcut_to_focused_editor(self, redo=False):
        focused = self.focusWidget()
        if isinstance(focused, (QLineEdit, QTextEdit, QPlainTextEdit)):
            action = focused.redo if redo else focused.undo
            action()
            return True
        return False

    def handle_undo_shortcut(self):
        if self._forward_shortcut_to_focused_editor(redo=False):
            return
        self.undo_mind_map()

    def handle_redo_shortcut(self):
        if self._forward_shortcut_to_focused_editor(redo=True):
            return
        self.redo_mind_map()

    def _serialize_map_data(self):
        map_data = {"nodes": [], "connections": [], "workspaces": []}

        for nid in sorted(self.nodes):
            node = self.nodes[nid]
            node_data = {
                "id": nid,
                "type": node.node_type,
                "x": node.pos().x(),
                "y": node.pos().y(),
                "w": node.width,
                "h": node.height,
                "extra": copy.deepcopy(node.extra_data),
            }
            if node.node_type == "note":
                editor = node.proxy.widget()
                if isinstance(editor, MarkdownEditor):
                    node_data["content"] = editor.toPlainText()
            map_data["nodes"].append(node_data)

        center = self.view.mapToScene(self.view.viewport().rect().center())
        map_data["viewport"] = {
            "x": center.x(),
            "y": center.y(),
            "zoom": self.view.transform().m11(),
        }

        for ws_id in sorted(self.workspaces):
            ws = self.workspaces[ws_id]
            ws_data = {
                "id": ws_id,
                "name": ws.name,
                "x": ws.pos().x(),
                "y": ws.pos().y(),
                "w": ws.width,
                "h": ws.height,
                "color": ws.color.name(),
            }
            map_data["workspaces"].append(ws_data)

        for conn in sorted(self.connections, key=lambda c: (c.start_node.node_id, c.end_node.node_id)):
            map_data["connections"].append({"from": conn.start_node.node_id, "to": conn.end_node.node_id})
        return map_data

    def _persist_map_data(self, map_data):
        if "mind_maps" not in self.dm.data:
            self.dm.data["mind_maps"] = {}
        self.dm.data["mind_maps"][self.current_map_id] = copy.deepcopy(map_data)
        self.dm.save_data()

    def _record_history_snapshot(self, snapshot=None, force=False):
        if self._history_restoring:
            return
        snapshot = copy.deepcopy(snapshot) if snapshot is not None else self._serialize_map_data()
        if self._history and self._history_index >= 0 and not force:
            if snapshot == self._history[self._history_index]:
                return
        if self._history_index < len(self._history) - 1:
            self._history = self._history[: self._history_index + 1]
        self._history.append(snapshot)
        if len(self._history) > self._history_limit:
            self._history = self._history[-self._history_limit :]
        self._history_index = len(self._history) - 1

    def _restore_history_state(self):
        if not (0 <= self._history_index < len(self._history)):
            return
        snapshot = copy.deepcopy(self._history[self._history_index])
        self.autosave_timer.stop()
        self.entity_autosave_timer.stop()
        self.pending_entity_saves.clear()
        self._history_restoring = True
        self._suspend_autosave = True
        try:
            self._load_map_data(snapshot)
        finally:
            self._suspend_autosave = False
            self._history_restoring = False
        self._persist_map_data(snapshot)
        palette = ThemeManager.get_palette(self.dm.current_theme)
        self._update_save_status_style(palette, is_editing=False)

    def undo_mind_map(self):
        if not self._history:
            return
        current = self._serialize_map_data()
        self._record_history_snapshot(current)
        if self._history_index <= 0:
            return
        self._history_index -= 1
        self._restore_history_state()

    def redo_mind_map(self):
        if self._history_index >= len(self._history) - 1:
            return
        self._history_index += 1
        self._restore_history_state()

    def _on_edit_mode_changed(self, enabled: bool, **_):
        """Apply global edit mode to all note and entity nodes in the mind map."""
        self._global_edit_mode = enabled
        for node in self.nodes.values():
            widget = node.proxy.widget()
            if isinstance(widget, MarkdownEditor):
                if enabled:
                    widget.switch_to_edit_mode()
                else:
                    widget.switch_to_view_mode()
            elif isinstance(widget, NpcSheet):
                widget.set_edit_mode(enabled)

    def apply_theme(self, theme_name):
        """
        Called by the Main Window.
        Updates all scene and item colors from the ThemeManager palette.
        """
        palette = ThemeManager.get_palette(theme_name)

        # 1. Scene background
        self.scene.set_palette(palette)

        # 2. Floating controls (Zoom)
        self.floating_controls.update_theme(palette)

        # 3. Save indicator
        self._update_save_status_style(palette, is_editing=False)

        # 4. Existing nodes
        for node in self.nodes.values():
            node.update_theme(palette)

        # 5. Connections
        for conn in self.connections:
            conn.update_theme(palette)

    def _update_save_status_style(self, palette, is_editing):
        bg = palette.get("ui_autosave_bg", "rgba(0, 0, 0, 100)")
        if is_editing:
            color = palette.get("ui_autosave_text_editing", "#ffb74d")
            text = tr('LBL_EDITING')
        else:
            color = palette.get("ui_autosave_text_saved", "#81c784")
            text = tr('LBL_SAVED')
            
        self.lbl_save_status.setText(text)
        self.lbl_save_status.setStyleSheet(f"background: {bg}; color: {color}; border-radius: 4px; border: none; font-size: 11px;")

    def fit_all_content(self):
        items_rect = self.scene.itemsBoundingRect()
        if items_rect.isEmpty():
            return
        self.view.fitInView(items_rect, Qt.AspectRatioMode.KeepAspectRatio)

    def handle_projection_request(self, node):
        self.project_node_content(node)

    def project_node_content(self, node):
        if self.main_window_ref and not self.main_window_ref.player_window.isVisible():
            self.main_window_ref.toggle_player_window()

        full_path = None
        if node.node_type == "image":
            path = node.extra_data.get("path")
            full_path = self.dm.get_full_path(path)
        
        elif node.node_type == "entity":
            eid = node.extra_data.get("eid")
            if eid in self.dm.data["entities"]:
                ent = self.dm.data["entities"][eid]
                img_path = ent.get("image_path") or (ent.get("images")[0] if ent.get("images") else None)
                if img_path:
                    full_path = self.dm.get_full_path(img_path)
                else:
                    QMessageBox.information(self, tr("MSG_WARNING"), tr("MSG_NO_IMAGE_PROJ"))

        if full_path and self.main_window_ref:
            self.main_window_ref.projection_manager.add_image(full_path)

    def show_canvas_context_menu(self, global_pos, scene_pos):
        menu = QMenu()
        p = ThemeManager.get_palette(self.dm.current_theme)
        menu.setStyleSheet(f"QMenu {{ background-color: {p.get('ui_floating_bg', '#333')}; color: {p.get('ui_floating_text', '#eee')}; border: 1px solid {p.get('ui_floating_border', '#555')}; font-size: 14px; padding: 5px; }} QMenu::item {{ padding: 5px 20px; }} QMenu::item:selected {{ background-color: {p.get('ui_floating_hover_bg', '#42a5f5')}; }}")
        
        act_note = QAction(tr('MENU_ADD_NOTE'), self)
        act_note.triggered.connect(lambda: self.create_note_node(None, scene_pos.x(), scene_pos.y(), 250, 200, ""))
        
        act_img = QAction(tr('MENU_ADD_IMAGE'), self)
        act_img.triggered.connect(lambda: self.add_image_at_pos(scene_pos))
        
        act_ws = QAction(tr('MENU_ADD_WORKSPACE'), self)
        act_ws.triggered.connect(lambda: self.create_workspace_node(None, "New Workspace", scene_pos.x(), scene_pos.y()))
        
        menu.addAction(act_note)
        menu.addAction(act_img)
        menu.addAction(act_ws)
        menu.exec(global_pos)

    def add_image_at_pos(self, scene_pos):
        from PyQt6.QtWidgets import QFileDialog
        f, _ = QFileDialog.getOpenFileName(self, tr("BTN_SELECT_IMG"), "", "Images (*.png *.jpg *.jpeg *.webp)")
        if f:
            path = self.dm.import_image(f)
            self.create_image_node(None, scene_pos.x(), scene_pos.y(), 300, 300, path)

    def create_node_base(self, node_id, widget, x, y, w, h, node_type, extra_data=None):
        node = MindMapNode(node_id, widget, w, h, node_type, extra_data)
        node.setPos(x, y)
        
        # Apply the current theme when creating the node
        current_theme_name = self.dm.current_theme
        node.update_theme(ThemeManager.get_palette(current_theme_name))

        node.requestConnection.connect(self.handle_connection_request)
        node.nodeDeleted.connect(self.delete_node)
        
        node.positionChanged.connect(self.update_connections)
        node.positionChanged.connect(self.trigger_autosave)
        node.sizeChanged.connect(self.trigger_autosave)
        
        node.requestProjection.connect(self.handle_projection_request) 
        
        self.scene.addItem(node)
        self.nodes[node.node_id] = node
        
        self.trigger_autosave()
        return node

    def create_workspace_node(self, ws_id, name, x, y, w=800, h=600, color="#42a5f5"):
        from ui.widgets.mind_map_items import WorkspaceItem
        ws = WorkspaceItem(ws_id, name, w, h, color)
        ws.setPos(x, y)
        
        ws.positionChanged.connect(self.trigger_autosave)
        ws.sizeChanged.connect(self.trigger_autosave)
        ws.workspaceDeleted.connect(self.delete_workspace)
        ws.workspaceRenamed.connect(self.rename_workspace)
        ws.workspaceColorChanged.connect(self.change_workspace_color)
        
        self.scene.addItem(ws)
        self.workspaces[ws.ws_id] = ws
        self.trigger_autosave()
        return ws

    def delete_workspace(self, ws_id):
        if ws_id in self.workspaces:
            ws = self.workspaces[ws_id]
            self.scene.removeItem(ws)
            del self.workspaces[ws_id]
            self.trigger_autosave()

    def rename_workspace(self, ws_id, name):
        if ws_id in self.workspaces:
            self.workspaces[ws_id].name = name
            self.workspaces[ws_id].update()
            self.trigger_autosave()

    def change_workspace_color(self, ws_id, color_str):
        if ws_id in self.workspaces:
            self.workspaces[ws_id].color = QColor(color_str)
            self.workspaces[ws_id].update()
            self.trigger_autosave()

    def zoom_to_workspace(self, ws):
        self.view.fitInView(ws.sceneBoundingRect(), Qt.AspectRatioMode.KeepAspectRatio)

    def see_all_workspaces(self):
        if not self.workspaces:
            self.fit_all_content()
            return
        
        rect = QRectF()
        for ws in self.workspaces.values():
            rect = rect.united(ws.sceneBoundingRect())
        
        self.view.fitInView(rect, Qt.AspectRatioMode.KeepAspectRatio)

    def create_note_node(self, node_id, x, y, w, h, content):
        editor = MarkdownEditor(text=content, placeholder="Not al...")
        editor.set_data_manager(self.dm)
        editor.textChanged.connect(self.trigger_autosave)
        editor.set_mind_map_style()

        # Notify the editor of the current theme on first open (MindMapNode handles it, but be safe)
        editor.refresh_theme(ThemeManager.get_palette(self.dm.current_theme))

        # Apply current global edit mode
        editor.set_toggle_button_visible(False)
        if self._global_edit_mode:
            editor.switch_to_edit_mode()
        elif content.strip():
            editor.switch_to_view_mode()

        node = self.create_node_base(node_id, editor, x, y, w, h, "note")
        first_line = content.strip().split("\n")[0][:40] if content and content.strip() else "Note"
        node.display_name = first_line
        return node

    def create_image_node(self, node_id, x, y, w, h, path):
        lbl = AspectRatioLabel()
        lbl.setStyleSheet("background: transparent; border: none;")
        full_path = self.dm.get_full_path(path)
        if full_path:
            lbl.setPixmap(QPixmap(full_path))
        node = self.create_node_base(node_id, lbl, x, y, w, h, "image", {"path": path})
        import os as _os
        node.display_name = _os.path.splitext(_os.path.basename(path or ""))[0] or "Image"
        return node

    def create_entity_node(self, eid, x, y, w=550, h=700): 
        if eid not in self.dm.data["entities"]: return
        ent_data = self.dm.data["entities"][eid]
        
        sheet = NpcSheet(self.dm)
        sheet.setProperty("entity_id", eid)
        sheet.populate_sheet(ent_data)
        sheet.set_embedded_mode(True)
        sheet.set_edit_mode(self._global_edit_mode)
        
        # Entity Sheet must receive the current theme on first open
        sheet.refresh_theme(ThemeManager.get_palette(self.dm.current_theme))
        
        sheet.data_changed.connect(lambda: self.schedule_entity_autosave(sheet))
        
        # NpcSheet outer container should be transparent
        sheet.setStyleSheet("""
            QWidget#sheetContainer { background-color: transparent; }
            QLineEdit, QTextEdit, QPlainTextEdit { background-color: rgba(0,0,0,0.2); border: 1px solid rgba(128,128,128,0.3); }
        """)
        
        node = self.create_node_base(None, sheet, x, y, w, h, "entity", {"eid": eid})
        node.display_name = ent_data.get("name", "Entity")
        return node

    def schedule_entity_autosave(self, sheet):
        self.pending_entity_saves.add(sheet)
        palette = ThemeManager.get_palette(self.dm.current_theme)
        self._update_save_status_style(palette, is_editing=True)
        self.entity_autosave_timer.start()

    def process_pending_entity_saves(self):
        for sheet in list(self.pending_entity_saves):
            try:
                if not sheet.isVisible() and not sheet.parent(): continue
                eid = sheet.property("entity_id")
                data = sheet.collect_data_from_sheet()
                if eid and data:
                    self.dm.save_entity(eid, data)
                    sheet.is_dirty = False
            except Exception: pass
        self.pending_entity_saves.clear()
        
        palette = ThemeManager.get_palette(self.dm.current_theme)
        self._update_save_status_style(palette, is_editing=False)

    def handle_connection_request(self, node):
        if not self.pending_connection_source:
            self.pending_connection_source = node
            self.view.setCursor(Qt.CursorShape.CrossCursor)
        else:
            if self.pending_connection_source != node:
                self.create_connection(self.pending_connection_source, node)
                self.trigger_autosave()
            self.pending_connection_source = None
            self.view.setCursor(Qt.CursorShape.ArrowCursor)

    def create_connection(self, node1, node2):
        for conn in self.connections:
            if (conn.start_node == node1 and conn.end_node == node2) or \
               (conn.start_node == node2 and conn.end_node == node1): return
        
        line = ConnectionLine(node1, node2, on_delete_callback=self.delete_connection)
        
        # Apply theme when creating the connection line
        current_theme_name = self.dm.current_theme
        line.update_theme(ThemeManager.get_palette(current_theme_name))
        
        self.scene.addItem(line)
        self.connections.append(line)

    def delete_connection(self, connection_item):
        if connection_item in self.connections:
            self.scene.removeItem(connection_item)
            self.connections.remove(connection_item)
            self.trigger_autosave()

    def update_connections(self):
        for conn in self.connections: conn.update_position()

    def delete_node(self, node_id):
        if node_id in self.nodes:
            node = self.nodes[node_id]
            to_remove = [c for c in self.connections if c.start_node == node or c.end_node == node]
            for c in to_remove: 
                self.scene.removeItem(c)
                self.connections.remove(c)
            self.scene.removeItem(node)
            del self.nodes[node_id]
            self.trigger_autosave()

    def trigger_autosave(self):
        try:
            if not hasattr(self, 'autosave_timer') or not self.autosave_timer: return
        except RuntimeError: return # Object might be deleted
        if self._suspend_autosave or self._history_restoring:
            return
        
        palette = ThemeManager.get_palette(self.dm.current_theme)
        self._update_save_status_style(palette, is_editing=True)
        self.autosave_timer.start()

    def save_map_data_silent(self):
        if self._suspend_autosave:
            return
        map_data = self._serialize_map_data()
        self._persist_map_data(map_data)
        self._record_history_snapshot(map_data)
        
        palette = ThemeManager.get_palette(self.dm.current_theme)
        self._update_save_status_style(palette, is_editing=False)

    def _load_map_data(self, map_data):
        self.scene.clear()
        self.nodes = {}
        self.connections = []
        self.workspaces = {}
        self.pending_connection_source = None
        self.view.setCursor(Qt.CursorShape.ArrowCursor)
        if not map_data:
            self.view._update_node_lod()
            return
        
        for n_data in map_data.get("nodes", []):
            try:
                nid, ntype = n_data["id"], n_data["type"]
                x, y, w, h = n_data["x"], n_data["y"], n_data["w"], n_data["h"]
                if ntype == "note": self.create_note_node(nid, x, y, w, h, n_data.get("content", ""))
                elif ntype == "image": self.create_image_node(nid, x, y, w, h, n_data["extra"].get("path"))
                elif ntype == "entity":
                    eid = n_data["extra"].get("eid")
                    if eid in self.dm.data["entities"]:
                        node = self.create_entity_node(eid, x, y, w, h)
                        if node:
                            old_id = node.node_id
                            if old_id in self.nodes: del self.nodes[old_id]
                            node.node_id = nid
                            self.nodes[nid] = node
            except Exception as e:
                logger.error("Node load error: %s", e)
            
        for c_data in map_data.get("connections", []):
            n1 = self.nodes.get(c_data["from"]); n2 = self.nodes.get(c_data["to"])
            if n1 and n2: self.create_connection(n1, n2)

        for ws_data in map_data.get("workspaces", []):
            try:
                self.create_workspace_node(
                    ws_data["id"], ws_data["name"],
                    ws_data["x"], ws_data["y"],
                    ws_data["w"], ws_data["h"],
                    ws_data.get("color", "#42a5f5")
                )
            except Exception as e:
                logger.error("Workspace load error: %s", e)

        # Restore viewport state
        vp = map_data.get("viewport")
        if vp:
            # Set zoom
            zoom = vp.get("zoom", 1.0)
            transform = self.view.transform()
            transform.setMatrix(zoom, transform.m12(), transform.m13(),
                                transform.m21(), zoom, transform.m23(),
                                transform.m31(), transform.m32(), transform.m33())
            self.view.setTransform(transform)
            # Center view
            self.view.centerOn(vp.get("x", 0), vp.get("y", 0))

        # Apply LOD based on restored zoom level
        self.view._update_node_lod()

    def load_map_data(self):
        map_data = None
        if "mind_maps" in self.dm.data:
            map_data = self.dm.data["mind_maps"].get(self.current_map_id)
        self._suspend_autosave = True
        try:
            self._load_map_data(map_data)
        finally:
            self._suspend_autosave = False
