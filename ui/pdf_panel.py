"""PdfPanel — right-side collapsible PDF viewer panel.

Opens from the right side of the main window (like the soundpad panel).
Displays PDFs projected from entity card Docs tabs.
"""

import logging

from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import QLabel, QVBoxLayout, QWidget

from core.locales import tr

logger = logging.getLogger(__name__)


class PdfPanel(QWidget):
    """Collapsible right-side panel for viewing PDFs."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("pdfPanelContainer")
        self.setMinimumWidth(300)
        self.setMaximumWidth(800)
        self._viewer = None
        self._build_ui()

    def _build_ui(self) -> None:
        self._layout = QVBoxLayout(self)
        self._layout.setContentsMargins(0, 0, 0, 0)
        self._layout.setSpacing(0)

        self._placeholder = QLabel(tr("LBL_PDF_PANEL_EMPTY"))
        self._placeholder.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._placeholder.setStyleSheet("color: #888; font-style: italic;")
        self._layout.addWidget(self._placeholder)

    def _ensure_viewer(self):
        if self._viewer is not None:
            return self._viewer
        from ui.widgets.pdf_viewer import PdfViewerWidget

        self._viewer = PdfViewerWidget()
        self._layout.addWidget(self._viewer)
        self._placeholder.setVisible(False)
        return self._viewer

    def show_pdf(self, path: str) -> None:
        """Load and display a PDF file in the panel."""
        viewer = self._ensure_viewer()
        viewer.load_file(path)
        self._placeholder.setVisible(False)
        self._viewer.setVisible(True)
        logger.info("PDF panel showing: %s", path)

    def show_pdf_url(self, url: str) -> None:
        """Download and display a remote PDF."""
        viewer = self._ensure_viewer()
        viewer.load_url(url)
        self._placeholder.setVisible(False)
        self._viewer.setVisible(True)
