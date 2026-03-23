"""Session CRUD operations for the Dungeon Master Tool."""

from __future__ import annotations

import logging
import uuid
from typing import Any, Callable

from core.locales import tr

logger = logging.getLogger(__name__)


class SessionRepository:
    """CRUD operations for sessions within a campaign.

    Receives the live campaign data dict via a callable so it always
    operates on the current state without holding a stale reference.
    """

    def __init__(
        self,
        get_data: Callable[[], dict[str, Any]],
        save_callback: Callable[[], None],
    ) -> None:
        self._get_data = get_data
        self._save = save_callback

    def create(self, name: str) -> str:
        """Create a new session, append it, and return its ID."""
        session_id = str(uuid.uuid4())
        new_session = {
            "id": session_id,
            "name": name,
            "date": tr("MSG_TODAY"),
            "notes": "",
            "logs": "",
            "combatants": [],
        }
        data = self._get_data()
        if "sessions" not in data:
            data["sessions"] = []
        data["sessions"].append(new_session)
        self.set_active(session_id)
        self._save()
        return session_id

    def get(self, session_id: str) -> dict[str, Any] | None:
        """Return the session dict with the given ID, or None."""
        if "sessions" not in self._get_data():
            return None
        for s in self._get_data()["sessions"]:
            if s["id"] == session_id:
                return s
        return None

    def save_data(
        self,
        session_id: str,
        notes: str,
        logs: str,
        combatants: list[dict[str, Any]],
    ) -> None:
        """Persist notes, logs, and combatants for the given session."""
        if "sessions" not in self._get_data():
            return
        for s in self._get_data()["sessions"]:
            if s["id"] == session_id:
                s["notes"] = notes
                s["logs"] = logs
                s["combatants"] = combatants
                self.set_active(session_id)
                self._save()
                break

    def set_active(self, session_id: str) -> None:
        """Set *session_id* as the last-active session in the campaign data."""
        self._get_data()["last_active_session_id"] = session_id

    def get_last_active_id(self) -> str | None:
        """Return the ID of the last-active session, or None."""
        return self._get_data().get("last_active_session_id")
