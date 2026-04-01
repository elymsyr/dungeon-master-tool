"""Embedded PDF viewer widget using PyMuPDF (fitz).

Replaces the QWebEngineView-based PDF display in PlayerWindow with a proper
page-rendering widget that works without a browser plugin and supports
sending individual pages to the player window.
"""
from __future__ import annotations

import logging
import os
import tempfile

from PyQt6.QtCore import QPoint, Qt, QThread, QTimer, pyqtSignal
from PyQt6.QtGui import QCursor, QImage, QPixmap
from PyQt6.QtWidgets import (
    QApplication,
    QFileDialog,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QPushButton,
    QScrollArea,
    QSizePolicy,
    QSpinBox,
    QStyle,
    QToolButton,
    QVBoxLayout,
    QWidget,
)

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Background downloader thread for remote URLs
# ---------------------------------------------------------------------------

class _PdfDownloadThread(QThread):
    """Downloads a PDF from a URL to a temp file on a background thread."""

    finished = pyqtSignal(str)   # temp file path
    failed = pyqtSignal(str)     # error message

    def __init__(self, url: str, parent=None):
        super().__init__(parent)
        self._url = url
        self._tmp_path: str | None = None

    def run(self) -> None:
        try:
            import requests  # already in requirements.txt

            with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
                self._tmp_path = tmp.name
                with requests.get(self._url, stream=True, timeout=30) as r:
                    r.raise_for_status()
                    for chunk in r.iter_content(chunk_size=65536):
                        tmp.write(chunk)
            self.finished.emit(self._tmp_path)
        except Exception as exc:
            logger.error("PDF download failed for %s: %s", self._url, exc)
            if self._tmp_path and os.path.exists(self._tmp_path):
                os.unlink(self._tmp_path)
            self.failed.emit(str(exc))


# ---------------------------------------------------------------------------
# Main widget
# ---------------------------------------------------------------------------

class PdfViewerWidget(QWidget):
    """Renders a PDF using PyMuPDF and provides basic navigation controls.

    Usage::

        viewer = PdfViewerWidget()
        viewer.load_file("/path/to/file.pdf")
        viewer.go_to_page(3)
    """

    page_changed = pyqtSignal(int)  # emitted whenever the displayed page changes

    def __init__(self, parent=None):
        super().__init__(parent)
        self._doc = None        # fitz.Document
        self._current_page = 0
        self._zoom = 1.5        # default render zoom (150 dpi equivalent)
        self._fit_mode = "width"  # "width" | "page" | "free"
        self._tmp_files: list[str] = []   # temp files to clean up on close
        self._download_thread: _PdfDownloadThread | None = None

        self._build_ui()

    # ------------------------------------------------------------------
    # UI construction
    # ------------------------------------------------------------------

    def _build_ui(self) -> None:
        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        # --- Toolbar ---
        toolbar = QWidget()
        toolbar.setObjectName("pdfToolbar")
        tb_layout = QHBoxLayout(toolbar)
        tb_layout.setContentsMargins(4, 2, 4, 2)
        tb_layout.setSpacing(4)

        self.btn_open = QPushButton("Open…")
        self.btn_open.setFixedWidth(60)
        self.btn_open.clicked.connect(self._open_file_dialog)

        _style = QApplication.style()
        self.btn_prev = QPushButton()
        self.btn_prev.setIcon(_style.standardIcon(QStyle.StandardPixmap.SP_ArrowBack))
        self.btn_prev.setObjectName("compactBtn")
        self.btn_prev.setFixedSize(28, 28)
        self.btn_prev.clicked.connect(self._prev_page)

        self.inp_page = QLineEdit()
        self.inp_page.setFixedWidth(40)
        self.inp_page.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.inp_page.returnPressed.connect(self._on_page_input)

        self.lbl_total = QLabel("/ 0")

        self.btn_next = QPushButton()
        self.btn_next.setIcon(_style.standardIcon(QStyle.StandardPixmap.SP_ArrowForward))
        self.btn_next.setObjectName("compactBtn")
        self.btn_next.setFixedSize(28, 28)
        self.btn_next.clicked.connect(self._next_page)

        self.btn_fit_width = QToolButton()
        self.btn_fit_width.setText("Fit W")
        self.btn_fit_width.setCheckable(True)
        self.btn_fit_width.setChecked(True)
        self.btn_fit_width.clicked.connect(self._fit_width_clicked)

        self.btn_fit_page = QToolButton()
        self.btn_fit_page.setText("Fit P")
        self.btn_fit_page.setCheckable(True)
        self.btn_fit_page.clicked.connect(self._fit_page_clicked)

        self.spn_zoom = QSpinBox()
        self.spn_zoom.setRange(50, 400)
        self.spn_zoom.setValue(int(self._zoom * 100))
        self.spn_zoom.setSuffix("%")
        self.spn_zoom.setFixedWidth(70)
        self.spn_zoom.valueChanged.connect(self._on_zoom_changed)

        self.lbl_status = QLabel("")
        self.lbl_status.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred)

        tb_layout.addWidget(self.btn_open)
        tb_layout.addSpacing(4)
        tb_layout.addWidget(self.btn_prev)
        tb_layout.addWidget(self.inp_page)
        tb_layout.addWidget(self.lbl_total)
        tb_layout.addWidget(self.btn_next)
        tb_layout.addSpacing(8)
        tb_layout.addWidget(self.btn_fit_width)
        tb_layout.addWidget(self.btn_fit_page)
        tb_layout.addWidget(self.spn_zoom)
        tb_layout.addWidget(self.lbl_status)

        root.addWidget(toolbar)

        # --- Scroll area with page label ---
        self.scroll = QScrollArea()
        self.scroll.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.scroll.setWidgetResizable(False)

        self.page_label = QLabel()
        self.page_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.page_label.setStyleSheet("background: #1a1a1a;")
        self.scroll.setWidget(self.page_label)

        # Middle-mouse drag state
        self._dragging = False
        self._drag_start = QPoint()
        self.scroll.viewport().installEventFilter(self)

        root.addWidget(self.scroll, 1)

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def load_file(self, path: str) -> None:
        """Open a local PDF file."""
        try:
            import fitz  # PyMuPDF
        except ImportError:
            self.lbl_status.setText("PyMuPDF not installed — run: pip install PyMuPDF")
            logger.error("PyMuPDF (fitz) is not installed")
            return

        try:
            self._close_document()
            self._doc = fitz.open(path)
            self._current_page = 0
            self._update_controls()
            self._render_page()
            logger.info("PDF opened: %s (%d pages)", path, self._doc.page_count)
        except Exception as exc:
            logger.error("Failed to open PDF %s: %s", path, exc)
            self.lbl_status.setText(f"Error: {exc}")

    def load_url(self, url: str) -> None:
        """Download and open a remote PDF URL (non-blocking)."""
        self.lbl_status.setText("Downloading…")
        self._download_thread = _PdfDownloadThread(url, parent=self)
        self._download_thread.finished.connect(self._on_download_finished)
        self._download_thread.failed.connect(lambda msg: self.lbl_status.setText(f"Download failed: {msg}"))
        self._download_thread.start()

    def go_to_page(self, n: int) -> None:
        """Jump to page n (0-based)."""
        if self._doc is None:
            return
        n = max(0, min(n, self._doc.page_count - 1))
        self._current_page = n
        self._update_controls()
        self._render_page()

    @property
    def current_page(self) -> int:
        return self._current_page

    @property
    def page_count(self) -> int:
        return self._doc.page_count if self._doc else 0

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _on_download_finished(self, path: str) -> None:
        self._tmp_files.append(path)
        self.lbl_status.setText("")
        self.load_file(path)

    def _open_file_dialog(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Open PDF", "", "PDF Files (*.pdf)")
        if path:
            self.load_file(path)

    def _open_folder_dialog(self) -> None:
        folder = QFileDialog.getExistingDirectory(self, "Open Folder")
        if not folder:
            return
        # Pick first PDF found in folder (sorted alphabetically)
        pdfs = sorted(
            f for f in os.listdir(folder) if f.lower().endswith(".pdf")
        )
        if pdfs:
            self.load_file(os.path.join(folder, pdfs[0]))
        else:
            self.lbl_status.setText("No PDF files found in folder")

    def _fit_width_clicked(self) -> None:
        self._set_fit_mode("width")

    def _fit_page_clicked(self) -> None:
        self._set_fit_mode("page")

    def _prev_page(self) -> None:
        if self._doc and self._current_page > 0:
            self.go_to_page(self._current_page - 1)

    def _next_page(self) -> None:
        if self._doc and self._current_page < self._doc.page_count - 1:
            self.go_to_page(self._current_page + 1)

    def _on_page_input(self) -> None:
        try:
            n = int(self.inp_page.text()) - 1  # UI is 1-based
            self.go_to_page(n)
        except ValueError:
            pass

    def _on_zoom_changed(self, value: int) -> None:
        self._zoom = value / 100.0
        self._fit_mode = "free"
        # Block signals so setChecked doesn't re-trigger valueChanged
        self.btn_fit_width.blockSignals(True)
        self.btn_fit_page.blockSignals(True)
        self.btn_fit_width.setChecked(False)
        self.btn_fit_page.setChecked(False)
        self.btn_fit_width.blockSignals(False)
        self.btn_fit_page.blockSignals(False)
        self._render_page()

    def _set_fit_mode(self, mode: str) -> None:
        self._fit_mode = mode
        # Block signals so setChecked doesn't re-trigger clicked
        self.btn_fit_width.blockSignals(True)
        self.btn_fit_page.blockSignals(True)
        self.btn_fit_width.setChecked(mode == "width")
        self.btn_fit_page.setChecked(mode == "page")
        self.btn_fit_width.blockSignals(False)
        self.btn_fit_page.blockSignals(False)
        self._render_page()

    def _render_page(self) -> None:
        if self._doc is None:
            return
        try:
            import fitz

            page = self._doc[self._current_page]
            rect = page.rect

            if self._fit_mode == "width":
                available_w = max(self.scroll.viewport().width() - 20, 100)
                self._zoom = available_w / rect.width
            elif self._fit_mode == "page":
                available_w = max(self.scroll.viewport().width() - 20, 100)
                available_h = max(self.scroll.viewport().height() - 20, 100)
                zoom_w = available_w / rect.width
                zoom_h = available_h / rect.height
                self._zoom = min(zoom_w, zoom_h)

            mat = fitz.Matrix(self._zoom, self._zoom)
            pix = page.get_pixmap(matrix=mat, alpha=False)

            img = QImage(pix.samples, pix.width, pix.height, pix.stride, QImage.Format.Format_RGB888)
            pixmap = QPixmap.fromImage(img)
            self.page_label.setPixmap(pixmap)
            self.page_label.resize(pixmap.size())

            self.page_changed.emit(self._current_page)
        except Exception as exc:
            logger.error("PDF render error on page %d: %s", self._current_page, exc)

    def _update_controls(self) -> None:
        count = self._doc.page_count if self._doc else 0
        self.lbl_total.setText(f"/ {count}")
        self.inp_page.setText(str(self._current_page + 1))
        self.btn_prev.setEnabled(self._current_page > 0)
        self.btn_next.setEnabled(self._current_page < count - 1)

    def _close_document(self) -> None:
        if self._doc is not None:
            self._doc.close()
            self._doc = None

    def eventFilter(self, obj, event) -> bool:
        if obj is self.scroll.viewport():
            from PyQt6.QtCore import QEvent
            if event.type() == QEvent.Type.MouseButtonPress and event.button() == Qt.MouseButton.MiddleButton:
                self._dragging = True
                self._drag_start = event.globalPosition().toPoint()
                self.scroll.viewport().setCursor(QCursor(Qt.CursorShape.ClosedHandCursor))
                return True
            if event.type() == QEvent.Type.MouseMove and self._dragging:
                delta = event.globalPosition().toPoint() - self._drag_start
                self._drag_start = event.globalPosition().toPoint()
                self.scroll.horizontalScrollBar().setValue(
                    self.scroll.horizontalScrollBar().value() - delta.x()
                )
                self.scroll.verticalScrollBar().setValue(
                    self.scroll.verticalScrollBar().value() - delta.y()
                )
                return True
            if event.type() == QEvent.Type.MouseButtonRelease and event.button() == Qt.MouseButton.MiddleButton:
                self._dragging = False
                self.scroll.viewport().setCursor(QCursor(Qt.CursorShape.ArrowCursor))
                return True
        return super().eventFilter(obj, event)

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        if self._doc is not None and self._fit_mode in ("width", "page"):
            self._render_page()

    def closeEvent(self, event) -> None:
        self._close_document()
        for path in self._tmp_files:
            try:
                os.unlink(path)
            except OSError:
                pass
        super().closeEvent(event)
