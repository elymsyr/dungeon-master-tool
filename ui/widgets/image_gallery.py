"""ImageGalleryWidget — standalone image carousel widget.

Manages a list of relative image paths (stored in campaign assets).
Delegates file I/O to the DataManager via dependency injection.
"""

import logging
import os

from PyQt6.QtCore import Qt
from PyQt6.QtGui import QPixmap
from PyQt6.QtWidgets import (
    QHBoxLayout,
    QLabel,
    QPushButton,
    QStyle,
    QVBoxLayout,
    QWidget,
    QFileDialog,
)

from config import CACHE_DIR
from core.locales import tr
from ui.widgets.aspect_ratio_label import AspectRatioLabel
from ui.workers import ImageDownloadWorker

logger = logging.getLogger(__name__)


class ImageGalleryWidget(QWidget):
    """Carousel widget that displays and manages a list of images.

    Responsibilities:
    - Show the current image with prev/next navigation.
    - Add images via file dialog (delegates import to DataManager).
    - Remove the current image.
    - Lazy-download a remote image URL in the background.
    """

    def __init__(self, data_manager, parent=None):
        super().__init__(parent)
        self._dm = data_manager
        self.image_list: list[str] = []
        self.current_img_index: int = 0
        self._image_worker = None
        self._build_ui()

    # ------------------------------------------------------------------
    # UI construction
    # ------------------------------------------------------------------

    def _build_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        self.lbl_image = AspectRatioLabel()
        self.lbl_image.setFixedSize(200, 200)
        layout.addWidget(self.lbl_image)

        gallery_controls = QHBoxLayout()
        self.btn_prev = QPushButton()
        self.btn_prev.setIcon(
            self.style().standardIcon(QStyle.StandardPixmap.SP_ArrowBack)
        )
        self.btn_prev.setMaximumWidth(30)
        self.btn_prev.clicked.connect(self.show_prev)

        self.btn_next = QPushButton()
        self.btn_next.setIcon(
            self.style().standardIcon(QStyle.StandardPixmap.SP_ArrowForward)
        )
        self.btn_next.setMaximumWidth(30)
        self.btn_next.clicked.connect(self.show_next)

        self.lbl_counter = QLabel("0/0")
        self.lbl_counter.setAlignment(Qt.AlignmentFlag.AlignCenter)

        gallery_controls.addWidget(self.btn_prev)
        gallery_controls.addWidget(self.lbl_counter)
        gallery_controls.addWidget(self.btn_next)
        layout.addLayout(gallery_controls)

        btn_row = QHBoxLayout()
        self.btn_add = QPushButton(tr("BTN_ADD"))
        self.btn_add.setObjectName("successBtn")
        self.btn_add.clicked.connect(self.add_image_dialog)

        self.btn_remove = QPushButton()
        self.btn_remove.setIcon(
            self.style().standardIcon(QStyle.StandardPixmap.SP_TrashIcon)
        )
        self.btn_remove.setObjectName("dangerBtn")
        self.btn_remove.clicked.connect(self.remove_current)

        btn_row.addWidget(self.btn_add)
        btn_row.addWidget(self.btn_remove)
        layout.addLayout(btn_row)
        layout.addStretch()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def set_images(self, images: list[str]) -> None:
        """Load a list of relative image paths and refresh the display."""
        self.image_list = list(images)
        self.current_img_index = 0
        self.refresh_display()

    def get_images(self) -> list[str]:
        """Return the current list of relative image paths."""
        return list(self.image_list)

    def refresh_display(self) -> None:
        """Re-render the current image and update the counter label."""
        if not self.image_list:
            self.lbl_image.setPixmap(None, path=None)
            self.lbl_image.setPlaceholderText(tr("LBL_NO_IMAGE"))
            self.lbl_counter.setText("0/0")
            return

        rel = self.image_list[self.current_img_index]
        full = self._dm.get_full_path(rel)
        if full and os.path.exists(full):
            self.lbl_image.setPixmap(QPixmap(full), path=full)
        else:
            self.lbl_image.setPixmap(None, path=None)
            self.lbl_image.setPlaceholderText(tr("LBL_NO_IMAGE"))

        self.lbl_counter.setText(
            f"{self.current_img_index + 1}/{len(self.image_list)}"
        )

    def show_prev(self) -> None:
        if self.image_list:
            self.current_img_index = (
                self.current_img_index - 1
            ) % len(self.image_list)
            self.refresh_display()

    def show_next(self) -> None:
        if self.image_list:
            self.current_img_index = (
                self.current_img_index + 1
            ) % len(self.image_list)
            self.refresh_display()

    def add_image_dialog(self) -> str | None:
        """Open a file dialog to import a new image. Returns the relative path
        if successful, or None. Emits no signal — caller should detect via
        ``get_images()`` change."""
        f, _ = QFileDialog.getOpenFileName(
            self,
            tr("BTN_SELECT_IMG"),
            "",
            "Images (*.png *.jpg *.jpeg *.webp *.bmp)",
        )
        if f:
            rel = self._dm.import_image(f)
            if rel:
                self.image_list.append(rel)
                self.current_img_index = len(self.image_list) - 1
                self.refresh_display()
                return rel
        return None

    def remove_current(self) -> None:
        """Remove the currently displayed image from the list."""
        if self.image_list:
            del self.image_list[self.current_img_index]
            self.current_img_index = max(0, self.current_img_index - 1)
            self.refresh_display()

    def start_lazy_download(self, url: str, name: str) -> None:
        """Start a background download for a remote image URL."""
        safe_name = "".join(c for c in name if c.isalnum()).lower()
        ext = ".jpg" if ".jpg" in url.lower() else ".png"
        filename = f"{safe_name}{ext}"
        save_dir = os.path.join(CACHE_DIR, "library", "images")
        self.lbl_image.setPlaceholderText(tr("MSG_DOWNLOADING_IMAGE"))
        self.lbl_image.setPixmap(None)
        self.lbl_counter.setText("-")
        self._image_worker = ImageDownloadWorker(url, save_dir, filename)
        self._image_worker.finished.connect(self._on_downloaded)
        self._image_worker.start()

    # ------------------------------------------------------------------
    # Private
    # ------------------------------------------------------------------

    def _on_downloaded(self, success: bool, local_abs_path: str) -> None:
        if success and local_abs_path:
            rel = self._dm.import_image(local_abs_path)
            if rel:
                self.image_list = [rel]
                self.current_img_index = 0
                self.refresh_display()
        else:
            self.lbl_image.setPlaceholderText(tr("LBL_NO_IMAGE"))
            self.lbl_image.setPixmap(None)
