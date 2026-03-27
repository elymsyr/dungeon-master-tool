import logging

from PyQt6.QtCore import Qt, QUrl, pyqtSignal
from PyQt6.QtGui import QImageReader, QPixmap
from PyQt6.QtWidgets import (
    QFrame,
    QGridLayout,
    QHBoxLayout,
    QLabel,
    QListWidget,
    QMainWindow,
    QScrollArea,
    QSplitter,
    QStackedWidget,
    QTextBrowser,
    QVBoxLayout,
    QWidget,
)

from core.locales import tr
from core.theme_manager import ThemeManager
from ui.widgets.image_viewer import ImageViewer

logger = logging.getLogger(__name__)


class PlayerWindow(QMainWindow):
    # Forwarded from embedded BattleMapWidget
    battle_token_moved = pyqtSignal(str, float, float)
    battle_token_size_changed = pyqtSignal(int)
    # Emitted whenever an image is added or removed
    projection_changed = pyqtSignal()

    def __init__(self, dev_mode=False):
        super().__init__()
        title = "Player View - Second Screen"
        if dev_mode:
            title = f"[DEV] {title}"
        self.setWindowTitle(title)
        self.resize(800, 600)
        self.setStyleSheet("background-color: #000;")

        central = QWidget()
        self.setCentralWidget(central)
        layout = QVBoxLayout(central)
        layout.setContentsMargins(0, 0, 0, 0)

        self.stack = QStackedWidget()

        # --- PAGE 0: MULTI-IMAGE VIEWER ---
        self.multi_image_widget = QWidget()
        self._multi_image_vbox = QVBoxLayout(self.multi_image_widget)
        self._multi_image_vbox.setContentsMargins(0, 0, 0, 0)
        self._multi_image_vbox.setSpacing(0)
        self._image_layout_mode = "side_by_side"
        self._image_layout_container = None
        self.active_viewers: list[ImageViewer] = []
        self.active_image_paths: list[str] = []
        self.stack.addWidget(self.multi_image_widget)  # index 0

        # --- PAGE 1: BATTLE MAP PLAYER VIEW ---
        self.battle_page = self._build_battle_page()
        self.stack.addWidget(self.battle_page)  # index 1

        # --- PAGE 2: BLACK SCREEN ---
        self.black_screen_widget = QWidget()
        self.black_screen_widget.setStyleSheet("background-color: #000000;")
        self.stack.addWidget(self.black_screen_widget)  # index 2

        # --- PAGE 3: CHARACTER SHEET ---
        self.stat_viewer = QTextBrowser()
        p = ThemeManager.get_palette("dark")
        self.stat_viewer.setStyleSheet(f"""
            QTextBrowser {{
                background-color: {p.get('markdown_bg', '#1a1a1a')};
                color: {p.get('markdown_text', '#e0e0e0')};
                border: none;
                padding: 20px;
                font-family: 'Segoe UI', serif;
            }}
        """)
        self.stack.addWidget(self.stat_viewer)  # index 3

        # --- PAGE 4+: PDF VIEWER (lazy) ---
        self.pdf_viewer = None
        self.pdf_viewer_index = None

        self._active_view = "images"
        self._black_screen = False

        layout.addWidget(self.stack)

    # ------------------------------------------------------------------
    # Battle page construction
    # ------------------------------------------------------------------

    def _build_battle_page(self) -> QWidget:
        """Build the battle map player view (equivalent of BattleMapWindow content)."""
        from ui.windows.battle_map_window import BattleMapWidget

        page = QWidget()
        layout = QHBoxLayout(page)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        self.battle_widget = BattleMapWidget(is_dm_view=False)
        self.battle_widget.token_moved_signal.connect(
            lambda tid, x, y: self.battle_token_moved.emit(tid, x, y)
        )
        self.battle_widget.token_size_changed_signal.connect(
            self.battle_token_size_changed.emit
        )
        layout.addWidget(self.battle_widget, 3)

        # Sidebar (turn order)
        self.battle_sidebar = QWidget()
        self.battle_sidebar.setFixedWidth(260)
        self.battle_sidebar.setObjectName("sidebarFrame")
        sidebar_layout = QVBoxLayout(self.battle_sidebar)
        sidebar_layout.setContentsMargins(0, 0, 0, 0)

        lbl_title = QLabel(tr("TITLE_TURN_ORDER"))
        lbl_title.setObjectName("headerLabel")
        lbl_title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        sidebar_layout.addWidget(lbl_title)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setObjectName("sidebarScroll")

        self.battle_list_container = QWidget()
        self.battle_list_container.setObjectName("sheetContainer")
        self.battle_list_container.setAttribute(
            Qt.WidgetAttribute.WA_StyledBackground, True
        )
        self.battle_list_layout = QVBoxLayout(self.battle_list_container)
        self.battle_list_layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        self.battle_list_layout.setSpacing(5)

        scroll.setWidget(self.battle_list_container)
        sidebar_layout.addWidget(scroll)

        layout.addWidget(self.battle_sidebar, 0)
        return page

    # ------------------------------------------------------------------
    # View control
    # ------------------------------------------------------------------

    def set_active_view(self, mode: str) -> None:
        """Switch visible page: 'images' or 'battlemap'."""
        self._active_view = mode
        if not self._black_screen:
            self.stack.setCurrentIndex(0 if mode == "images" else 1)

    def set_black_screen(self, on: bool) -> None:
        """Toggle a solid black overlay over the player window."""
        self._black_screen = on
        if on:
            self.stack.setCurrentIndex(2)
        else:
            self.stack.setCurrentIndex(0 if self._active_view == "images" else 1)

    # ------------------------------------------------------------------
    # Battle map control
    # ------------------------------------------------------------------

    def update_battle_map(
        self,
        combatants: list,
        turn_index: int,
        dm,
        map_path: str | None,
        token_size: int,
        fog_data=None,
    ) -> None:
        """Push combat state to the embedded battle map widget and sidebar."""
        self.battle_widget.update_tokens(
            combatants, turn_index, dm, map_path, token_size, fog_data=fog_data
        )
        self._update_battle_sidebar(combatants, turn_index)

    def _update_battle_sidebar(self, combatants: list, current_index: int) -> None:
        """Rebuild the turn order sidebar cards (mirrors BattleMapWindow._update_sidebar)."""
        while self.battle_list_layout.count():
            item = self.battle_list_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        for i, c in enumerate(combatants):
            name = c.get("name", "???")
            hp = c.get("hp", "?")
            conditions = c.get("conditions", [])
            ent_type = c.get("type", "NPC")
            attitude = c.get("attitude", "LBL_ATTR_NEUTRAL")
            is_player = ent_type == "Player"
            is_active = i == current_index

            attitude_clean = "neutral"
            if attitude == "LBL_ATTR_HOSTILE":
                attitude_clean = "hostile"
            elif attitude == "LBL_ATTR_FRIENDLY":
                attitude_clean = "friendly"

            card = QFrame()
            card.setProperty("class", "combatCard")
            card.setProperty("active", str(is_active).lower())
            card.setProperty("type", ent_type)
            card.setProperty("attitude", attitude_clean)

            card_layout = QVBoxLayout(card)
            card_layout.setContentsMargins(5, 5, 5, 5)
            card_layout.setSpacing(2)

            row_header = QWidget()
            row_header_layout = QHBoxLayout(row_header)
            row_header_layout.setContentsMargins(0, 0, 0, 0)
            row_header_layout.setSpacing(5)

            lbl_name = QLabel(name)
            lbl_name.setStyleSheet(
                "font-weight: bold; border: none; background: transparent;"
            )
            hp_txt = (
                tr("LBL_HP_SIDEBAR", hp=hp) if is_player else tr("LBL_HP_UNKNOWN")
            )
            lbl_hp = QLabel(hp_txt)
            lbl_hp.setStyleSheet(
                "border: none; background: transparent; font-style: italic;"
            )
            row_header_layout.addWidget(lbl_name, 1)
            row_header_layout.addWidget(lbl_hp, 0)
            card_layout.addWidget(row_header)

            if conditions:
                row_cond = QWidget()
                row_cond_layout = QHBoxLayout(row_cond)
                row_cond_layout.setContentsMargins(0, 2, 0, 0)
                row_cond_layout.setSpacing(3)
                for cond in conditions:
                    cond_lbl = QLabel(f"[{cond}]")
                    cond_lbl.setStyleSheet(
                        "color: #e57373; font-size: 10px; border: none; background: transparent;"
                    )
                    row_cond_layout.addWidget(cond_lbl)
                row_cond_layout.addStretch()
                card_layout.addWidget(row_cond)

            self.battle_list_layout.addWidget(card)

    # ------------------------------------------------------------------
    # Image layout control
    # ------------------------------------------------------------------

    def set_image_layout(self, mode: str) -> None:
        """Switch image page layout: 'single', 'side_by_side', or 'grid'."""
        self._image_layout_mode = mode
        self._rebuild_image_page()

    def _rebuild_image_page(self) -> None:
        """Rebuild the image layout container without destroying ImageViewers."""
        # Un-parent all viewers so they survive container deletion
        for v in self.active_viewers:
            v.setParent(None)

        # Remove and delete the old layout container
        while self._multi_image_vbox.count():
            item = self._multi_image_vbox.takeAt(0)
            if item and item.widget():
                item.widget().deleteLater()
        self._image_layout_container = None

        mode = self._image_layout_mode
        viewers = self.active_viewers

        if not viewers:
            container = QWidget(self.multi_image_widget)
        elif len(viewers) == 1 or mode == "single":
            container = QWidget(self.multi_image_widget)
            vlayout = QVBoxLayout(container)
            vlayout.setContentsMargins(0, 0, 0, 0)
            vlayout.addWidget(viewers[0])
            viewers[0].show()
            for v in viewers[1:]:
                v.setParent(container)
                v.hide()
        elif mode == "grid":
            container = QWidget(self.multi_image_widget)
            gl = QGridLayout(container)
            gl.setContentsMargins(0, 0, 0, 0)
            gl.setSpacing(2)
            for i, v in enumerate(viewers):
                v.show()
                if i < 4:
                    gl.addWidget(v, i // 2, i % 2)
                else:
                    v.setParent(container)
                    v.hide()
        else:  # "side_by_side" (default)
            container = QSplitter(Qt.Orientation.Horizontal, self.multi_image_widget)
            container.setHandleWidth(4)
            for v in viewers:
                v.show()
                container.addWidget(v)

        self._image_layout_container = container
        self._multi_image_vbox.addWidget(container)

    # ------------------------------------------------------------------
    # Image add / remove
    # ------------------------------------------------------------------

    def add_image_to_view(self, image_path: str, pixmap=None) -> None:
        """Add a new image. If already present, update it (zoom preserved)."""
        self.stack.setCurrentIndex(0)
        self._active_view = "images"

        if image_path in self.active_image_paths:
            try:
                index = self.active_image_paths.index(image_path)
                viewer = self.active_viewers[index]
                if pixmap:
                    viewer.update_pixmap(pixmap)
                return
            except Exception as e:
                logger.error("Error updating existing image view: %s", e)
            return

        viewer = ImageViewer()

        if pixmap:
            viewer.set_image(pixmap)
        else:
            reader = QImageReader(image_path)
            if reader.canRead():
                image = reader.read()
                if not image.isNull():
                    loaded_pix = QPixmap.fromImage(image)
                else:
                    loaded_pix = QPixmap(image_path)
            else:
                loaded_pix = QPixmap(image_path)
            viewer.set_image(loaded_pix)

        self.active_viewers.append(viewer)
        self.active_image_paths.append(image_path)
        self._rebuild_image_page()
        self.projection_changed.emit()

    def remove_image_from_view(self, image_path: str) -> None:
        if image_path not in self.active_image_paths:
            return

        index = self.active_image_paths.index(image_path)
        viewer = self.active_viewers[index]
        self.active_viewers.pop(index)
        self.active_image_paths.pop(index)

        # Un-parent viewer before rebuild to prevent it being caught in deletion
        viewer.setParent(None)
        viewer.deleteLater()

        self._rebuild_image_page()
        self.projection_changed.emit()

    def clear_images(self) -> None:
        """Remove all projected images."""
        for viewer in self.active_viewers:
            viewer.setParent(None)
            viewer.deleteLater()
        self.active_viewers.clear()
        self.active_image_paths.clear()
        self._rebuild_image_page()
        self.projection_changed.emit()

    # ------------------------------------------------------------------
    # Legacy / compatibility methods
    # ------------------------------------------------------------------

    def show_image(self, pixmap) -> None:
        self.clear_images()
        self.stack.setCurrentIndex(0)
        self._active_view = "images"
        viewer = ImageViewer()
        viewer.set_image(pixmap)
        self.active_viewers.append(viewer)
        self.active_image_paths.append("__legacy__")
        self._rebuild_image_page()

    def show_stat_block(self, html_content: str) -> None:
        self.stack.setCurrentWidget(self.stat_viewer)
        self.stat_viewer.setHtml(html_content)

    def show_pdf(self, pdf_path: str) -> None:
        if self.pdf_viewer is None:
            from PyQt6.QtWebEngineWidgets import QWebEngineView

            self.pdf_viewer = QWebEngineView()
            p = ThemeManager.get_palette("dark")
            self.pdf_viewer.setStyleSheet(
                f"background-color: {p.get('ui_bg_dark', '#333')};"
            )
            self.stack.addWidget(self.pdf_viewer)
            self.pdf_viewer_index = self.stack.count() - 1
            self.pdf_viewer.settings().setAttribute(
                self.pdf_viewer.settings().WebAttribute.PluginsEnabled, True
            )
            self.pdf_viewer.settings().setAttribute(
                self.pdf_viewer.settings().WebAttribute.PdfViewerEnabled, True
            )

        self.stack.setCurrentWidget(self.pdf_viewer)
        local_url = QUrl.fromLocalFile(pdf_path)
        self.pdf_viewer.setUrl(local_url)

    def update_theme(self, qss: str) -> None:
        self.setStyleSheet(qss)
