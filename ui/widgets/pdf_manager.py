"""PdfManagerWidget — standalone PDF attachment manager.

Manages a list of relative PDF paths attached to an entity.
Delegates file I/O to the DataManager via dependency injection.
"""

import logging
import os

from PyQt6.QtCore import QUrl
from PyQt6.QtGui import QDesktopServices
from PyQt6.QtWidgets import (
    QAbstractScrollArea,
    QFileDialog,
    QGroupBox,
    QHBoxLayout,
    QListWidget,
    QMessageBox,
    QPushButton,
    QSizePolicy,
    QStyle,
    QVBoxLayout,
    QWidget,
)

from core.locales import tr

logger = logging.getLogger(__name__)


class PdfManagerWidget(QWidget):
    """Widget for attaching, opening, and removing PDF files from an entity.

    Responsibilities:
    - Show the list of attached PDFs.
    - Add PDFs via file dialog (delegates import to DataManager).
    - Open the selected PDF with the system viewer.
    - Open the campaign assets folder in the file manager.
    - Remove the selected PDF from the list.
    """

    def __init__(self, data_manager, parent=None):
        super().__init__(parent)
        self._dm = data_manager
        self._entity_id: str | None = None
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Maximum)
        self._build_ui()

    # ------------------------------------------------------------------
    # UI construction
    # ------------------------------------------------------------------

    def _build_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        grp = QGroupBox(tr("GRP_PDF"))
        grp.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Maximum)
        v = QVBoxLayout(grp)
        v.setSpacing(4)

        h_btn = QHBoxLayout()
        self.btn_add = QPushButton(tr("BTN_ADD"))
        self.btn_add.setObjectName("successBtn")
        self.btn_add.clicked.connect(self.add_pdf_dialog)

        self.btn_remove = QPushButton(tr("BTN_REMOVE"))
        self.btn_remove.setIcon(
            self.style().standardIcon(QStyle.StandardPixmap.SP_TrashIcon)
        )
        self.btn_remove.setObjectName("dangerBtn")
        self.btn_remove.clicked.connect(self.remove_current_pdf)

        h_btn.addWidget(self.btn_add, 3)
        h_btn.addWidget(self.btn_remove, 1)
        v.addLayout(h_btn)

        self.list_pdfs = QListWidget()
        self.list_pdfs.setAlternatingRowColors(True)
        self.list_pdfs.setSizeAdjustPolicy(
            QAbstractScrollArea.SizeAdjustPolicy.AdjustToContents
        )
        self.list_pdfs.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Maximum
        )
        v.addWidget(self.list_pdfs)

        layout.addWidget(grp)

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def set_edit_mode(self, enabled: bool) -> None:
        """Show/hide add and remove buttons based on edit mode."""
        self.btn_add.setVisible(enabled)
        self.btn_remove.setVisible(enabled)

    def set_entity_id(self, eid: str | None) -> None:
        """Bind the widget to an entity so save-on-add/remove works."""
        self._entity_id = eid

    def set_pdfs(self, pdfs: list[str]) -> None:
        """Populate the list widget from a list of relative paths."""
        self.list_pdfs.clear()
        for pdf in pdfs:
            self.list_pdfs.addItem(pdf)
        self._fit_list_height()

    def get_pdfs(self) -> list[str]:
        """Return the current list of relative PDF paths."""
        return [
            self.list_pdfs.item(i).text()
            for i in range(self.list_pdfs.count())
        ]

    # ------------------------------------------------------------------
    # Slots
    # ------------------------------------------------------------------

    def _fit_list_height(self) -> None:
        count = self.list_pdfs.count()
        if count == 0:
            self.list_pdfs.setFixedHeight(0)
            return
        total = sum(
            self.list_pdfs.sizeHintForRow(i) for i in range(count)
        )
        total += 2 * self.list_pdfs.frameWidth()
        self.list_pdfs.setFixedHeight(total)

    def add_pdf_dialog(self) -> None:
        f, _ = QFileDialog.getOpenFileName(
            self, tr("BTN_SELECT_PDF"), "", "PDF (*.pdf)"
        )
        if not f:
            return
        rel = self._dm.import_pdf(f)
        if not rel:
            return
        self.list_pdfs.addItem(rel)
        self._fit_list_height()
        if self._entity_id:
            entity = self._dm.data["entities"].get(self._entity_id)
            if entity:
                pdfs = entity.get("pdfs", [])
                if rel not in pdfs:
                    pdfs.append(rel)
                    entity["pdfs"] = pdfs
                    self._dm.save_entity(self._entity_id, entity)

    def open_current_pdf(self) -> None:
        item = self.list_pdfs.currentItem()
        if not item:
            return
        full = self._dm.get_full_path(item.text())
        if full and os.path.exists(full):
            QDesktopServices.openUrl(QUrl.fromLocalFile(full))

    def remove_current_pdf(self) -> None:
        item = self.list_pdfs.currentItem()
        if not item:
            return
        if (
            QMessageBox.question(
                self,
                tr("BTN_REMOVE"),
                tr("MSG_REMOVE_PDF_CONFIRM"),
            )
            != QMessageBox.StandardButton.Yes
        ):
            return
        txt = item.text()
        self.list_pdfs.takeItem(self.list_pdfs.row(item))
        self._fit_list_height()
        if self._entity_id:
            entity = self._dm.data["entities"].get(self._entity_id)
            if entity and txt in entity.get("pdfs", []):
                entity["pdfs"].remove(txt)
                self._dm.save_entity(self._entity_id, entity)

    def open_pdf_folder(self) -> None:
        folder = os.path.join(self._dm.current_campaign_path, "assets")
        os.makedirs(folder, exist_ok=True)
        QDesktopServices.openUrl(QUrl.fromLocalFile(folder))
