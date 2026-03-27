"""PlayerScreenWidget — DM live preview and control panel for the player screen.

Sits in the Session tab's bottom area. The DM sees a live preview of what is
projected to players. Layout is automatic (1=single, 2-3=row, 4+=2 rows).
Zooming or panning a preview viewer is mirrored live to the second screen.
Images are managed via the projection bar (drag-and-drop); no extra controls here.
"""

import math

from PyQt6.QtCore import Qt
from PyQt6.QtGui import QPixmap
from PyQt6.QtWidgets import (
    QGridLayout,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QSplitter,
    QVBoxLayout,
    QWidget,
)

from core.locales import tr
from ui.widgets.image_viewer import ImageViewer


class PlayerScreenWidget(QWidget):
    """DM live preview for the PlayerWindow image page.

    Shows a live thumbnail of what's on the second screen. Zoom/pan is
    mirrored to the actual player window. No image management here —
    images are added/removed via the projection bar.
    """

    def __init__(self, player_window, parent=None):
        super().__init__(parent)
        self._pw = player_window
        self._viewers: list[ImageViewer] = []
        self._container: QWidget | None = None

        if player_window is not None:
            player_window.projection_changed.connect(self._rebuild_preview)

        self._init_ui()
        self._rebuild_preview()

    # ------------------------------------------------------------------
    # UI construction
    # ------------------------------------------------------------------

    def _init_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(4, 4, 4, 4)
        layout.setSpacing(4)

        ctrl_row = QHBoxLayout()
        ctrl_row.setSpacing(4)
        ctrl_row.addStretch()

        self.btn_show_screen = QPushButton(tr("BTN_SHOW_SCREEN"))
        self.btn_show_screen.setObjectName("primaryBtn")
        self.btn_show_screen.clicked.connect(self._on_show_screen)
        ctrl_row.addWidget(self.btn_show_screen)

        self.btn_empty = QPushButton(tr("BTN_EMPTY_SCREEN"))
        self.btn_empty.setCheckable(True)
        self.btn_empty.setObjectName("dangerBtn")
        self.btn_empty.toggled.connect(self._on_empty_screen)
        ctrl_row.addWidget(self.btn_empty)

        layout.addLayout(ctrl_row)

        self._preview_host = QWidget()
        self._preview_vbox = QVBoxLayout(self._preview_host)
        self._preview_vbox.setContentsMargins(0, 0, 0, 0)
        layout.addWidget(self._preview_host, 1)

    # ------------------------------------------------------------------
    # Preview rebuild
    # ------------------------------------------------------------------

    def _rebuild_preview(self):
        """Recreate the preview area from the current player window state."""
        if self._container is not None:
            self._container.setParent(None)
            self._container.deleteLater()
            self._container = None

        for v in self._viewers:
            v.setParent(None)
            v.deleteLater()
        self._viewers.clear()

        paths = self._pw.active_image_paths if self._pw is not None else []
        n = len(paths)

        if n == 0:
            placeholder = QLabel(tr("LBL_NO_IMAGE"))
            placeholder.setAlignment(Qt.AlignmentFlag.AlignCenter)
            placeholder.setStyleSheet("color: #666; font-style: italic;")
            self._preview_vbox.addWidget(placeholder)
            self._container = placeholder
            return

        if n == 1:
            container = QWidget()
            vl = QVBoxLayout(container)
            vl.setContentsMargins(0, 0, 0, 0)
            v = self._make_viewer(0)
            vl.addWidget(v)
        elif n <= 3:
            container = QSplitter(Qt.Orientation.Horizontal)
            container.setHandleWidth(4)
            for i in range(n):
                container.addWidget(self._make_viewer(i))
        else:
            cols = math.ceil(n / 2)
            container = QWidget()
            gl = QGridLayout(container)
            gl.setContentsMargins(0, 0, 0, 0)
            gl.setSpacing(2)
            for i in range(n):
                gl.addWidget(self._make_viewer(i), i // cols, i % cols)

        self._preview_vbox.addWidget(container)
        self._container = container

    def _make_viewer(self, index: int) -> ImageViewer:
        """Create a preview ImageViewer for the given index and wire sync."""
        v = ImageViewer()
        v.set_image(self._get_pixmap(index))
        v.view_changed.connect(
            lambda t, h, vs, idx=index: self._sync_to_player(idx, t, h, vs)
        )
        self._viewers.append(v)
        return v

    def _get_pixmap(self, index: int) -> QPixmap:
        """Get pixmap from PlayerWindow viewer (handles in-memory images like map)."""
        if self._pw is not None and index < len(self._pw.active_viewers):
            viewer = self._pw.active_viewers[index]
            if viewer.pixmap_item is not None:
                return viewer.pixmap_item.pixmap()
        paths = self._pw.active_image_paths if self._pw is not None else []
        if index < len(paths):
            return QPixmap(paths[index])
        return QPixmap()

    def _sync_to_player(self, index: int, transform, h_scroll: int, v_scroll: int):
        """Mirror a preview viewer's zoom/pan to the corresponding player window viewer."""
        if self._pw is not None and index < len(self._pw.active_viewers):
            self._pw.active_viewers[index].apply_view_state(transform, h_scroll, v_scroll)

    # ------------------------------------------------------------------
    # Show / Empty screen
    # ------------------------------------------------------------------

    def _on_show_screen(self):
        if self._pw is None:
            return
        self._pw.set_active_view("images")
        self._pw.show()

    def _on_empty_screen(self, checked: bool):
        if self._pw is not None:
            self._pw.set_black_screen(checked)

    # ------------------------------------------------------------------
    # Retranslation
    # ------------------------------------------------------------------

    def retranslate_ui(self):
        self.btn_show_screen.setText(tr("BTN_SHOW_SCREEN"))
        self.btn_empty.setText(tr("BTN_EMPTY_SCREEN"))
