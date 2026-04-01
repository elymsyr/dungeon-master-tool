"""Connection status badge widget for the MainWindow status bar.

Polls NetworkBridge.state every 2 seconds and updates a small coloured dot
with a label. Sprint 3 will replace the polling with a proper signal from
NetworkBridge once the socket client emits state changes.
"""
from __future__ import annotations

from PyQt6.QtCore import QTimer
from PyQt6.QtWidgets import QHBoxLayout, QLabel, QWidget

from core.network.bridge import ConnectionState, NetworkBridge

_STATE_STYLE: dict[ConnectionState, tuple[str, str]] = {
    ConnectionState.DISCONNECTED: ("#888888", "Offline"),
    ConnectionState.CONNECTING:   ("#f5a623", "Connecting…"),
    ConnectionState.CONNECTED:    ("#4caf50", "Online"),
    ConnectionState.ERROR:        ("#ef5350", "Error"),
}


class ConnectionStatusBadge(QWidget):
    """Small status indicator showing the NetworkBridge connection state."""

    def __init__(self, bridge: NetworkBridge, parent=None):
        super().__init__(parent)
        self._bridge = bridge
        self._last_state: ConnectionState | None = None

        layout = QHBoxLayout(self)
        layout.setContentsMargins(6, 0, 6, 0)
        layout.setSpacing(4)

        self._dot = QLabel("●")
        self._dot.setFixedWidth(14)

        self._lbl = QLabel("Offline")
        self._lbl.setFixedWidth(80)

        layout.addWidget(self._dot)
        layout.addWidget(self._lbl)

        self._timer = QTimer(self)
        self._timer.setInterval(2000)
        self._timer.timeout.connect(self._poll)
        self._timer.start()

        self._poll()  # immediate first update

    def _poll(self) -> None:
        state = self._bridge.state
        if state is self._last_state:
            return
        self._last_state = state
        color, text = _STATE_STYLE.get(state, ("#888", "Unknown"))
        self._dot.setStyleSheet(f"color: {color};")
        self._lbl.setText(text)
        self._lbl.setStyleSheet(f"color: {color};")
