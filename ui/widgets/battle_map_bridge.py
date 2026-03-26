"""BattleMapBridge — manages the external BattleMapWindow lifecycle.

Handles creating, showing, and refreshing the floating BattleMapWindow
so that CombatTracker does not need to hold the window reference directly.

Classes:
    BattleMapBridge  -- QObject that wraps BattleMapWindow and re-emits
                        token_moved / token_size_changed signals.
"""

import logging

from PyQt6.QtCore import QObject, pyqtSignal

logger = logging.getLogger(__name__)


class BattleMapBridge(QObject):
    """Thin lifecycle manager for the external BattleMapWindow.

    CombatTracker creates one BattleMapBridge, connects to its signals, and
    calls its methods instead of driving BattleMapWindow directly.
    """

    # Re-emitted from BattleMapWindow signals
    token_moved = pyqtSignal(str, float, float)   # (tid, x, y)
    token_size_changed = pyqtSignal(int)           # new slider value

    def __init__(self, dm, parent=None) -> None:
        super().__init__(parent)
        self._dm = dm
        self._window = None

    # ------------------------------------------------------------------
    # Window lifecycle
    # ------------------------------------------------------------------

    def is_open(self) -> bool:
        """Return True if the window exists and is currently visible."""
        return bool(self._window and self._window.isVisible())

    def open(self) -> bool:
        """Open the BattleMapWindow, or bring it to front if already open.

        Returns True if a new window was created, False if an existing one
        was just raised.
        """
        if self.is_open():
            self._window.raise_()
            self._window.activateWindow()
            return False

        from ui.windows.battle_map_window import BattleMapWindow  # lazy import
        self._window = BattleMapWindow(self._dm)
        self._window.token_moved_signal.connect(
            lambda tid, x, y: self.token_moved.emit(tid, x, y)
        )
        self._window.slider_size.valueChanged.connect(self.token_size_changed)
        self._window.show()
        return True

    # ------------------------------------------------------------------
    # Data push
    # ------------------------------------------------------------------

    def update_combat_data(
        self,
        combatants: list[dict],
        turn_index: int,
        map_path: str | None,
        token_size: int,
        fog_data=None,
    ) -> None:
        """Push current combat state to the window (no-op if window is closed)."""
        if not self.is_open():
            return
        self._window.update_combat_data(
            combatants, turn_index, map_path, token_size, fog_data=fog_data
        )

    # ------------------------------------------------------------------
    # Sync passthrough
    # ------------------------------------------------------------------

    def sync_view(self, rect) -> None:
        if self.is_open():
            self._window.sync_view(rect)

    def sync_fog(self, qimage) -> None:
        if self.is_open():
            self._window.sync_fog(qimage)

    # ------------------------------------------------------------------
    # Retranslation
    # ------------------------------------------------------------------

    def retranslate(self) -> None:
        if self.is_open():
            self._window.retranslate_ui()
