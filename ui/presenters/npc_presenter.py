"""NpcPresenter — mediates between NpcSheet (view) and DataManager (model).

Owns the populate / collect / save / discard lifecycle for the entity
detail sheet, keeping state-management logic out of both the view widget
and the host tab.

Typical usage in a host widget (e.g. DatabaseTab)::

    self._npc_presenter = NpcPresenter(self.npc_sheet, self.dm, parent=self)
    self._npc_presenter.save_completed.connect(self._on_entity_saved)
    self._npc_presenter.entity_deleted.connect(self._on_entity_deleted)
    ...
    self._npc_presenter.load_entity(entity_id)
"""

import logging

from PyQt6.QtCore import QObject, pyqtSignal

logger = logging.getLogger(__name__)


class NpcPresenter(QObject):
    """Presenter for the entity detail sheet (NpcSheet)."""

    save_completed = pyqtSignal(str)       # entity_id
    entity_deleted = pyqtSignal(str)       # entity_id
    open_entity_requested = pyqtSignal(str)  # entity_id

    def __init__(self, view, dm, parent=None):
        super().__init__(parent)
        self._view = view
        self._dm = dm
        self._current_entity_id: str | None = None
        self._connect()

    # ------------------------------------------------------------------
    # Internal wiring
    # ------------------------------------------------------------------

    def _connect(self) -> None:
        self._view.save_requested.connect(self._on_save_requested)
        self._view.request_open_entity.connect(self.open_entity_requested.emit)

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    @property
    def current_entity_id(self) -> str | None:
        return self._current_entity_id

    @property
    def is_dirty(self) -> bool:
        return self._view.is_dirty

    def load_entity(self, entity_id: str) -> None:
        """Populate the view with entity data from DataManager."""
        self._current_entity_id = entity_id
        data = self._dm.data["entities"].get(entity_id, {})
        self._view.setProperty("entity_id", entity_id)
        self._view.populate_sheet(data)

    def save(self) -> bool:
        """Collect view data and persist via DataManager. Returns True on success."""
        if not self._current_entity_id:
            return False
        data = self._view.collect_data_from_sheet()
        if not data:
            return False
        self._dm.save_entity(self._current_entity_id, data, should_save=True)
        self._view.is_dirty = False
        self.save_completed.emit(self._current_entity_id)
        return True

    def discard(self) -> None:
        """Reload entity data from DataManager, discarding unsaved changes."""
        if self._current_entity_id:
            self.load_entity(self._current_entity_id)

    def delete(self) -> bool:
        """Delete the current entity from DataManager. Returns True on success."""
        if not self._current_entity_id:
            return False
        eid = self._current_entity_id
        self._dm.delete_entity(eid)
        self._current_entity_id = None
        self.entity_deleted.emit(eid)
        return True

    # ------------------------------------------------------------------
    # Private signal handlers
    # ------------------------------------------------------------------

    def _on_save_requested(self) -> None:
        self.save()
