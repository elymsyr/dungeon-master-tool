import os
import traceback
from multiprocessing.connection import Client

from PyQt6.QtCore import QObject, QTimer

from core.dev.hot_reload_manager import HotReloadManager


class DevIpcBridge(QObject):
    """Child-process IPC bridge for dev hot reload commands."""

    POLL_INTERVAL_MS = 100

    def __init__(self, connection):
        super().__init__()
        self.connection = connection
        self.window = None
        self.hot_reload_manager = None
        self._poll_timer = None

    @classmethod
    def from_env(cls):
        host = os.getenv("DM_DEV_IPC_HOST")
        port = os.getenv("DM_DEV_IPC_PORT")
        auth = os.getenv("DM_DEV_IPC_AUTH")

        if not host or not port or not auth:
            print("[dev] IPC bridge disabled: missing connection environment variables")
            return None

        try:
            conn = Client((host, int(port)), authkey=auth.encode("utf-8"))
        except Exception as exc:
            print(f"[dev] IPC connection failed: {exc}")
            return None

        return cls(conn)

    def attach(self, window):
        self.window = window
        self.hot_reload_manager = HotReloadManager(window)

    def start(self):
        """
        Starts IPC polling after QApplication is created.
        Creating/starting QTimer before Qt app initialization causes
        "QObject::startTimer" warnings and drops IPC polling.
        """
        if self._poll_timer is None:
            self._poll_timer = QTimer(self)
            self._poll_timer.setInterval(self.POLL_INTERVAL_MS)
            self._poll_timer.timeout.connect(self._poll_once)

        if not self._poll_timer.isActive():
            self._poll_timer.start()

    def _handle_hot_reload(self, changed_paths):
        if self.window is None or self.hot_reload_manager is None:
            return {
                "ok": False,
                "error": "No active window attached.",
                "details": "Dev bridge has not attached to a main window yet.",
                "last_world": None,
            }

        result = self.hot_reload_manager.attempt_hot_reload(changed_paths)
        result["last_world"] = self.window.data_manager.data.get("world_name")
        return result

    def _poll_once(self):
        if self.connection is None:
            return

        try:
            if not self.connection.poll():
                return

            payload = self.connection.recv()
            if not isinstance(payload, dict):
                self.connection.send(
                    {
                        "ok": False,
                        "error": "Invalid IPC payload",
                        "details": repr(payload),
                        "last_world": None,
                    }
                )
                return

            cmd = payload.get("cmd")
            if cmd == "hot_reload":
                response = self._handle_hot_reload(payload.get("changed_paths", []))
            else:
                response = {
                    "ok": False,
                    "error": f"Unknown IPC command: {cmd}",
                    "details": "Supported commands: hot_reload",
                    "last_world": self.window.data_manager.data.get("world_name")
                    if self.window
                    else None,
                }

            self.connection.send(response)
        except Exception as exc:
            print(f"[dev] IPC bridge error: {exc}")
            if self.connection is not None:
                try:
                    self.connection.send(
                        {
                            "ok": False,
                            "error": str(exc),
                            "details": traceback.format_exc(),
                            "last_world": self.window.data_manager.data.get("world_name")
                            if self.window
                            else None,
                        }
                    )
                except Exception:
                    pass

    def close(self):
        if self._poll_timer is not None and self._poll_timer.isActive():
            self._poll_timer.stop()

        if self.connection is not None:
            try:
                self.connection.close()
            except Exception:
                pass
            finally:
                self.connection = None
