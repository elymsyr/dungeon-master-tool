"""CombatModel — pure encounter state management, no Qt dependencies.

Owns the encounters dict and current_encounter_id, and provides
methods for creating/deleting encounters, advancing turns, and
serialising/deserialising session state.

Classes:
    CombatModel  -- encounter state owner; used by CombatTracker as a delegate.
"""

import uuid


class CombatModel:
    """Manages the collection of encounters and turn/round state.

    Has zero Qt dependencies — all methods operate on plain Python values.
    CombatTracker owns a CombatModel instance and delegates state mutations
    through it while retaining all UI logic.
    """

    def __init__(self) -> None:
        self.encounters: dict = {}
        self.current_encounter_id: str | None = None

    # ------------------------------------------------------------------
    # Encounter CRUD
    # ------------------------------------------------------------------

    def create_encounter(self, name: str) -> str:
        """Create a new encounter, set it as current, and return its id."""
        eid = str(uuid.uuid4())
        self.encounters[eid] = {
            "id": eid,
            "name": name,
            "combatants": [],
            "map_path": None,
            "token_size": 50,
            "turn_index": -1,
            "round": 1,
            "token_positions": {},
        }
        self.current_encounter_id = eid
        return eid

    def get_current(self) -> dict | None:
        """Return the current encounter dict, or None if unset/missing."""
        if self.current_encounter_id and self.current_encounter_id in self.encounters:
            return self.encounters[self.current_encounter_id]
        return None

    def rename(self, eid: str, name: str) -> None:
        if eid in self.encounters:
            self.encounters[eid]["name"] = name

    def delete(self, eid: str) -> str | None:
        """Delete an encounter and return the new current_encounter_id, or None."""
        if eid not in self.encounters:
            return None
        del self.encounters[eid]
        if self.encounters:
            new_id = next(iter(self.encounters))
            self.current_encounter_id = new_id
            return new_id
        self.current_encounter_id = None
        return None

    # ------------------------------------------------------------------
    # Turn management
    # ------------------------------------------------------------------

    def advance_turn(self, combatant_count: int) -> bool:
        """Advance to the next combatant's turn.

        Returns True if the round counter was incremented (i.e. we wrapped
        past the last combatant), False otherwise.
        """
        enc = self.get_current()
        if enc is None or combatant_count == 0:
            return False
        enc["turn_index"] += 1
        if enc["turn_index"] >= combatant_count:
            enc["turn_index"] = 0
            enc["round"] += 1
            return True
        return False

    # ------------------------------------------------------------------
    # Serialisation
    # ------------------------------------------------------------------

    def to_dict(self) -> dict:
        """Return a serialisable snapshot of all encounter state."""
        return {
            "encounters": self.encounters,
            "current_encounter_id": self.current_encounter_id,
        }

    def load(self, data: dict) -> str | None:
        """Load session state from a dict (handles legacy bare-combatants format).

        Returns the resolved current_encounter_id after loading.
        """
        if "encounters" in data:
            self.encounters = data["encounters"]
            tid = data.get("current_encounter_id")
        else:
            # Legacy format: bare combatants list at the top level
            eid = str(uuid.uuid4())
            self.encounters = {
                eid: {
                    "id": eid,
                    "name": "Legacy",
                    "combatants": data.get("combatants", []),
                    "round": 1,
                    "turn_index": -1,
                    "token_positions": {},
                    "token_size": 50,
                    "map_path": None,
                }
            }
            tid = eid

        if tid and tid in self.encounters:
            self.current_encounter_id = tid
        elif self.encounters:
            self.current_encounter_id = next(iter(self.encounters))
        else:
            self.current_encounter_id = None

        return self.current_encounter_id
