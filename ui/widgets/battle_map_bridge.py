"""BattleMapBridge — routes combat state to the unified PlayerWindow.

Replaces the old BattleMapWindow lifecycle manager. Instead of opening a
separate floating window, it switches the shared PlayerWindow to its
battle-map page and pushes data updates to it.

Classes:
    BattleMapBridge  -- QObject that wraps PlayerWindow battle-map access
                        and re-emits token_moved / token_size_changed signals.
"""

import logging

from PyQt6.QtCore import QObject, pyqtSignal

logger = logging.getLogger(__name__)


class BattleMapBridge(QObject):
    """Routes combat state to PlayerWindow's embedded battle map page.

    CombatTracker creates one BattleMapBridge, connects to its signals,
    and calls its methods instead of driving the player window directly.
    """

    # Re-emitted from PlayerWindow / BattleMapWidget signals
    token_moved = pyqtSignal(str, float, float)   # (tid, x, y)
    token_size_changed = pyqtSignal(int)           # new slider value
    token_size_override_changed = pyqtSignal(str, int)  # (tid, size)

    def __init__(self, dm, player_window, parent=None) -> None:
        super().__init__(parent)
        self._dm = dm
        self._pw = player_window
        if player_window is not None:
            self._pw.battle_token_moved.connect(self.token_moved)
            self._pw.battle_token_size_changed.connect(self.token_size_changed)
            if hasattr(self._pw, "battle_token_size_override_changed"):
                self._pw.battle_token_size_override_changed.connect(self.token_size_override_changed)

    # ------------------------------------------------------------------
    # Window lifecycle (now: player window visibility)
    # ------------------------------------------------------------------

    def is_open(self) -> bool:
        """Return True if the player window is currently visible."""
        if self._pw is None:
            return False
        return self._pw.isVisible()

    def open(self) -> bool:
        """Switch player window to battle map view and show it.

        Returns True if the window was not already visible.
        """
        if self._pw is None:
            return False
        was_visible = self._pw.isVisible()
        self._pw.set_active_view("battlemap")
        self._pw.show()
        return not was_visible

    # ------------------------------------------------------------------
    # Data push
    # ------------------------------------------------------------------

    def update_combat_data(
        self,
        combatants: list,
        turn_index: int,
        map_path: str | None,
        token_size: int,
        fog_data=None,
        token_size_overrides=None,
        grid_size=None,
        grid_visible=None,
        grid_snap=None,
        feet_per_cell=None,
        annotation_data=None,
    ) -> None:
        """Push current combat state to the battle map page.

        Skips the update when the player window is not visible to avoid
        loading video/media assets (and potential VA-API crashes) at startup.
        """
        if self._pw is None or not self._pw.isVisible():
            return
        self._pw.update_battle_map(
            combatants, turn_index, self._dm, map_path, token_size,
            fog_data=fog_data,
            token_size_overrides=token_size_overrides or {},
            grid_size=grid_size,
            grid_visible=grid_visible,
            grid_snap=grid_snap,
            feet_per_cell=feet_per_cell,
            annotation_data=annotation_data,
        )

    # ------------------------------------------------------------------
    # Sync passthrough
    # ------------------------------------------------------------------

    def sync_view(self, rect) -> None:
        if self._pw is not None and hasattr(self._pw, "battle_widget"):
            self._pw.battle_widget.apply_view_state(rect)

    def sync_fog(self, qimage) -> None:
        if self._pw is not None and hasattr(self._pw, "battle_widget"):
            self._pw.battle_widget.apply_external_fog(qimage)

    # ------------------------------------------------------------------
    # Retranslation
    # ------------------------------------------------------------------

    def retranslate(self) -> None:
        pass  # PlayerWindow handles its own retranslation

    # ------------------------------------------------------------------
    # Backward-compat property (was: direct window reference)
    # ------------------------------------------------------------------

    @property
    def battle_map_window(self):
        """Deprecated: always returns None. Use BattleMapBridge methods instead."""
        return None
