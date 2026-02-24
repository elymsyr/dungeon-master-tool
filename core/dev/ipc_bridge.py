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

    def _failed_payload(self, error, details, *, changed_paths=None, last_world=None):
        return {
            "ok": False,
            "status": HotReloadManager.OUTCOME_FAILED,
            "error": str(error),
            "details": details,
            "last_world": last_world,
            "changed_paths": list(changed_paths or []),
            "duration_ms": 0,
        }

    def _normalize_payload(self, payload):
        if not isinstance(payload, dict):
            return self._failed_payload("Invalid hot reload result payload.", repr(payload))

        if "status" not in payload:
            payload["status"] = (
                HotReloadManager.OUTCOME_APPLIED
                if payload.get("ok")
                else HotReloadManager.OUTCOME_FAILED
            )

        payload.setdefault("ok", payload["status"] in {
            HotReloadManager.OUTCOME_APPLIED,
            HotReloadManager.OUTCOME_NO_OP,
        })
        payload.setdefault("error", None)
        payload.setdefault("details", "")
        payload.setdefault("last_world", self.window.data_manager.data.get("world_name") if self.window else None)
        payload.setdefault("changed_paths", [])
        payload.setdefault("duration_ms", 0)
        return payload

    def _handle_hot_reload(self, changed_paths):
        if self.window is None or self.hot_reload_manager is None:
            return self._failed_payload(
                "No active window attached.",
                "Dev bridge has not attached to a main window yet.",
                changed_paths=changed_paths,
            )

        result = self.hot_reload_manager.attempt_hot_reload(changed_paths)
        return self._normalize_payload(result)

    def _poll_once(self):
        if self.connection is None:
            return

        try:
            if not self.connection.poll():
                return

            payload = self.connection.recv()
            if not isinstance(payload, dict):
                self.connection.send(
                    self._failed_payload(
                        "Invalid IPC payload",
                        repr(payload),
                    )
                )
                return

            cmd = payload.get("cmd")
            if cmd == "hot_reload":
                response = self._handle_hot_reload(payload.get("changed_paths", []))
            else:
                response = self._failed_payload(
                    f"Unknown IPC command: {cmd}",
                    "Supported commands: hot_reload",
                    changed_paths=payload.get("changed_paths", []),
                    last_world=(
                        self.window.data_manager.data.get("world_name")
                        if self.window
                        else None
                    ),
                )

            self.connection.send(response)
        except Exception as exc:
            print(f"[dev] IPC bridge error: {exc}")
            if self.connection is not None:
                try:
                    self.connection.send(
                        self._failed_payload(
                            str(exc),
                            traceback.format_exc(),
                            last_world=(
                                self.window.data_manager.data.get("world_name")
                                if self.window
                                else None
                            ),
                        )
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
