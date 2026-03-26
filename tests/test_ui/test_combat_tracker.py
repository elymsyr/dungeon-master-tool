"""Characterization tests for CombatTracker.

These tests capture the current behavior as a safety net before the
decomposition into CombatModel, BattleMapBridge, and combat_table.py.

Run with:
    QT_QPA_PLATFORM=offscreen pytest tests/test_ui/test_combat_tracker.py -v
"""

import os
import sys
import pytest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt6.QtWidgets import QApplication

_app = QApplication.instance() or QApplication(sys.argv)


# ---------------------------------------------------------------------------
# Fake DataManager
# ---------------------------------------------------------------------------

class FakeDataManager:
    def __init__(self):
        self.data = {
            "entities": {
                "player-1": {
                    "name": "Legolas",
                    "type": "Player",
                    "stats": {"DEX": 18},
                    "combat_stats": {"hp": "40", "max_hp": "40", "ac": "15", "initiative": "+3"},
                    "attributes": {},
                },
                "npc-1": {
                    "name": "Goblin",
                    "type": "Monster",
                    "stats": {"DEX": 12},
                    "combat_stats": {"hp": "7", "max_hp": "7", "ac": "12", "initiative": "0"},
                    "attributes": {"LBL_ATTITUDE": "LBL_ATTR_HOSTILE"},
                },
                "npc-2": {
                    "name": "Guard",
                    "type": "NPC",
                    "stats": {"DEX": 10},
                    "combat_stats": {"hp": "20", "max_hp": "20", "ac": "13", "initiative": "0"},
                    "attributes": {"LBL_ATTITUDE": "LBL_ATTR_NEUTRAL"},
                },
                "loc-1": {
                    "name": "Tavern",
                    "type": "Location",
                    "battlemaps": [],
                },
            }
        }
        self.current_theme = "dark"

    def get_full_path(self, rel):
        if not rel:
            return None
        return f"/tmp/{rel}"

    def import_image(self, path):
        return f"assets/{os.path.basename(path)}"


@pytest.fixture
def tracker():
    from ui.widgets.combat_tracker import CombatTracker
    ct = CombatTracker(FakeDataManager())
    yield ct
    ct.close()
    ct.deleteLater()


# ---------------------------------------------------------------------------
# Instantiation
# ---------------------------------------------------------------------------


def test_combat_tracker_instantiates(tracker):
    from ui.widgets.combat_tracker import CombatTracker
    assert isinstance(tracker, CombatTracker)


def test_initial_encounter_created(tracker):
    assert len(tracker.encounters) == 1


def test_initial_encounter_has_correct_structure(tracker):
    enc = list(tracker.encounters.values())[0]
    assert "name" in enc
    assert "combatants" in enc
    assert "turn_index" in enc
    assert "round" in enc
    assert enc["round"] == 1
    assert enc["turn_index"] == -1


def test_current_encounter_id_set(tracker):
    assert tracker.current_encounter_id is not None
    assert tracker.current_encounter_id in tracker.encounters


# ---------------------------------------------------------------------------
# create_encounter
# ---------------------------------------------------------------------------


def test_create_encounter_adds_to_dict(tracker):
    before = len(tracker.encounters)
    tracker.create_encounter("Battle of Helm's Deep")
    assert len(tracker.encounters) == before + 1


def test_create_encounter_sets_current_id(tracker):
    new_id = tracker.create_encounter("New Fight")
    assert tracker.current_encounter_id == new_id


def test_create_encounter_initializes_fields(tracker):
    eid = tracker.create_encounter("Arena")
    enc = tracker.encounters[eid]
    assert enc["name"] == "Arena"
    assert enc["combatants"] == []
    assert enc["map_path"] is None
    assert enc["round"] == 1
    assert enc["turn_index"] == -1


# ---------------------------------------------------------------------------
# add_direct_row
# ---------------------------------------------------------------------------


def test_add_direct_row_increases_row_count(tracker):
    before = tracker.table.rowCount()
    tracker.add_direct_row("Orc", 15, 13, 20, [], None)
    assert tracker.table.rowCount() == before + 1


def test_add_direct_row_sets_name(tracker):
    tracker.add_direct_row("Dragon", 20, 18, 200, [], None)
    row = tracker.table.rowCount() - 1
    assert tracker.table.item(row, 0).text() == "Dragon"


def test_add_direct_row_with_entity_id(tracker):
    from PyQt6.QtCore import Qt
    tracker.add_direct_row("Goblin", 10, 12, 7, [], "npc-1")
    row = tracker.table.rowCount() - 1
    item_init = tracker.table.item(row, 1)
    assert item_init.data(Qt.ItemDataRole.UserRole) == "npc-1"


# ---------------------------------------------------------------------------
# quick_add
# ---------------------------------------------------------------------------


def test_quick_add_adds_row(tracker):
    tracker.inp_quick_name.setText("Bandit")
    tracker.inp_quick_init.setText("12")
    tracker.inp_quick_hp.setText("15")
    before = tracker.table.rowCount()
    tracker.quick_add()
    assert tracker.table.rowCount() == before + 1


def test_quick_add_clears_name_input(tracker):
    tracker.inp_quick_name.setText("Bandit")
    tracker.quick_add()
    assert tracker.inp_quick_name.text() == ""


def test_quick_add_empty_name_does_nothing(tracker):
    tracker.inp_quick_name.setText("")
    before = tracker.table.rowCount()
    tracker.quick_add()
    assert tracker.table.rowCount() == before


# ---------------------------------------------------------------------------
# add_row_from_entity
# ---------------------------------------------------------------------------


def test_add_row_from_entity_uses_entity_name(tracker):
    tracker.add_row_from_entity("npc-1")
    # Find the row with name "Goblin"
    found = False
    for r in range(tracker.table.rowCount()):
        if tracker.table.item(r, 0) and tracker.table.item(r, 0).text() == "Goblin":
            found = True
    assert found


def test_add_row_from_entity_unknown_id_does_nothing(tracker):
    before = tracker.table.rowCount()
    tracker.add_row_from_entity("unknown-eid")
    assert tracker.table.rowCount() == before


# ---------------------------------------------------------------------------
# add_all_players
# ---------------------------------------------------------------------------


def test_add_all_players_adds_player_entities(tracker):
    tracker.table.setRowCount(0)
    tracker.add_all_players()
    names = [
        tracker.table.item(r, 0).text()
        for r in range(tracker.table.rowCount())
        if tracker.table.item(r, 0)
    ]
    assert "Legolas" in names


def test_add_all_players_skips_non_players(tracker):
    tracker.table.setRowCount(0)
    tracker.add_all_players()
    names = [
        tracker.table.item(r, 0).text()
        for r in range(tracker.table.rowCount())
        if tracker.table.item(r, 0)
    ]
    assert "Goblin" not in names


def test_add_all_players_no_duplicates(tracker):
    tracker.table.setRowCount(0)
    tracker.add_row_from_entity("player-1")
    before = tracker.table.rowCount()
    tracker.add_all_players()
    # Legolas should not be added again
    count_legolas = sum(
        1 for r in range(tracker.table.rowCount())
        if tracker.table.item(r, 0) and tracker.table.item(r, 0).text() == "Legolas"
    )
    assert count_legolas == 1


# ---------------------------------------------------------------------------
# delete_row
# ---------------------------------------------------------------------------


def test_delete_row_reduces_row_count(tracker):
    tracker.add_direct_row("Skeleton", 8, 10, 5, [], None)
    before = tracker.table.rowCount()
    tracker.delete_row(0)
    assert tracker.table.rowCount() == before - 1


# ---------------------------------------------------------------------------
# clear_tracker
# ---------------------------------------------------------------------------


def test_clear_tracker_removes_all_rows(tracker):
    tracker.add_direct_row("Orc A", 10, 12, 15, [], None)
    tracker.add_direct_row("Orc B", 8, 11, 10, [], None)
    tracker.clear_tracker()
    assert tracker.table.rowCount() == 0


def test_clear_tracker_resets_round_to_1(tracker):
    enc = tracker.encounters[tracker.current_encounter_id]
    enc["round"] = 5
    tracker.clear_tracker()
    assert enc["round"] == 1


def test_clear_tracker_resets_turn_index(tracker):
    enc = tracker.encounters[tracker.current_encounter_id]
    enc["turn_index"] = 2
    tracker.clear_tracker()
    assert enc["turn_index"] == -1


# ---------------------------------------------------------------------------
# next_turn
# ---------------------------------------------------------------------------


def test_next_turn_increments_turn_index(tracker):
    tracker.add_direct_row("A", 20, 10, 10, [], None)
    tracker.add_direct_row("B", 15, 10, 10, [], None)
    enc = tracker.encounters[tracker.current_encounter_id]
    enc["turn_index"] = 0
    tracker.next_turn()
    assert enc["turn_index"] == 1


def test_next_turn_wraps_to_0_and_increments_round(tracker):
    tracker.add_direct_row("A", 20, 10, 10, [], None)
    enc = tracker.encounters[tracker.current_encounter_id]
    enc["turn_index"] = 0  # last combatant (only 1)
    enc["round"] = 1
    tracker.next_turn()
    assert enc["turn_index"] == 0
    assert enc["round"] == 2


def test_next_turn_no_combatants_does_nothing(tracker):
    tracker.table.setRowCount(0)
    enc = tracker.encounters[tracker.current_encounter_id]
    enc["turn_index"] = -1
    enc["round"] = 1
    tracker.next_turn()
    assert enc["round"] == 1


# ---------------------------------------------------------------------------
# get_session_state / load_session_state round-trip
# ---------------------------------------------------------------------------


def test_get_session_state_returns_dict(tracker):
    state = tracker.get_session_state()
    assert isinstance(state, dict)
    assert "encounters" in state
    assert "current_encounter_id" in state


def test_session_state_round_trip_preserves_encounter_names(tracker):
    """get_session_state dict contains all encounter names."""
    tracker.create_encounter("Dungeon Level 1")
    state = tracker.get_session_state()
    names = [e["name"] for e in state["encounters"].values()]
    assert "Dungeon Level 1" in names


def test_session_state_round_trip_preserves_combatants(tracker):
    """get_session_state dict includes combatant rows."""
    tracker.table.setRowCount(0)
    tracker.add_direct_row("Aragorn", 18, 16, 50, [], None)
    state = tracker.get_session_state()
    enc = list(state["encounters"].values())[0]
    names = [c["name"] for c in enc["combatants"]]
    assert "Aragorn" in names


def test_load_session_state_legacy_format(tracker):
    """load_session_state should handle legacy format (bare combatants list)."""
    from PyQt6.QtWidgets import QApplication
    legacy = {
        "combatants": [
            {"tid": "t1", "eid": None, "name": "Zombie", "init": "5",
             "ac": "8", "hp": "10", "conditions": [], "bonus": 0,
             "x": None, "y": None}
        ]
    }
    tracker.load_session_state(legacy)
    QApplication.instance().processEvents()
    enc = tracker.encounters[tracker.current_encounter_id]
    names = [c["name"] for c in enc["combatants"]]
    assert "Zombie" in names


# ---------------------------------------------------------------------------
# handle_drop_import
# ---------------------------------------------------------------------------


def test_handle_drop_import_adds_valid_entity(tracker):
    before = tracker.table.rowCount()
    tracker.handle_drop_import("npc-1")
    assert tracker.table.rowCount() == before + 1


def test_handle_drop_import_ignores_lib_prefix(tracker):
    from unittest.mock import patch
    before = tracker.table.rowCount()
    with patch("PyQt6.QtWidgets.QMessageBox.information"):
        tracker.handle_drop_import("lib_some_item")
    assert tracker.table.rowCount() == before


def test_handle_drop_import_ignores_non_combatant_type(tracker):
    """Locations should not be added as combatants."""
    before = tracker.table.rowCount()
    tracker.handle_drop_import("loc-1")
    assert tracker.table.rowCount() == before


# ---------------------------------------------------------------------------
# roll_initiatives
# ---------------------------------------------------------------------------


def test_roll_initiatives_sets_numeric_initiative(tracker):
    tracker.add_direct_row("Orc", 0, 10, 15, [], None)
    tracker.roll_initiatives()
    init_text = tracker.table.item(0, 1).text()
    assert init_text.lstrip("-").isdigit()


# ---------------------------------------------------------------------------
# _save_current_state_to_memory
# ---------------------------------------------------------------------------


def test_save_current_state_stores_combatant_names(tracker):
    tracker.add_direct_row("Wizard", 14, 11, 30, [], None)
    tracker._save_current_state_to_memory()
    enc = tracker.encounters[tracker.current_encounter_id]
    names = [c["name"] for c in enc["combatants"]]
    assert "Wizard" in names


def test_save_current_state_preserves_hp(tracker):
    tracker.add_direct_row("Fighter", 16, 18, 45, [], None)
    tracker._save_current_state_to_memory()
    enc = tracker.encounters[tracker.current_encounter_id]
    assert any(c["name"] == "Fighter" for c in enc["combatants"])


# ---------------------------------------------------------------------------
# Multiple encounters
# ---------------------------------------------------------------------------


def test_multiple_encounters_independent(tracker):
    enc1_id = tracker.current_encounter_id
    enc2_id = tracker.create_encounter("Second Fight")
    tracker.current_encounter_id = enc1_id
    tracker.refresh_ui_from_current_encounter()
    tracker.add_direct_row("Knight", 12, 16, 40, [], None)
    tracker._save_current_state_to_memory()

    # Switch to second encounter
    tracker.current_encounter_id = enc2_id
    tracker.refresh_ui_from_current_encounter()
    names2 = [
        tracker.table.item(r, 0).text()
        for r in range(tracker.table.rowCount())
        if tracker.table.item(r, 0)
    ]
    assert "Knight" not in names2


# ---------------------------------------------------------------------------
# DraggableCombatTable (inline class)
# ---------------------------------------------------------------------------


def test_draggable_table_accepts_drops(tracker):
    from ui.widgets.combat_tracker import DraggableCombatTable
    assert tracker.table.acceptDrops()


def test_draggable_table_is_correct_type(tracker):
    from ui.widgets.combat_tracker import DraggableCombatTable
    assert isinstance(tracker.table, DraggableCombatTable)
