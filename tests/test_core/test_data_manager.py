import os
import json
import pytest
from core.data_manager import DataManager


# ---------------------------------------------------------------------------
# Existing tests
# ---------------------------------------------------------------------------

def test_campaign_initialization(temp_campaign_dir):
    """Test if a new campaign is correctly initialized."""
    dm = DataManager()
    # It was create_campaign, not new_campaign
    success, msg = dm.create_campaign("Test World") 
    # Wait, create_campaign uses WORLDS_DIR from config. 
    # My data_manager fixture manually sets current_campaign_path.
    # Let's use a more controlled approach for testing initialization.
    assert success is True
    assert dm.data["world_name"] == "Test World"

def test_data_persistence(data_manager):
    """Test saving and loading campaign data."""
    data_manager.data["notes"] = "Some test notes"
    data_manager.save_data() # It was save_data, not save_campaign
    
    # Reload
    dm2 = DataManager()
    success, msg = dm2.load_campaign(data_manager.current_campaign_path)
    assert success is True
    assert dm2.data["notes"] == "Some test notes"

def test_migration_logic(temp_campaign_dir):
    """Test migration of legacy Turkish keys to standardized English keys."""
    # Create legacy data using 'data.json'
    os.makedirs(temp_campaign_dir, exist_ok=True)
    legacy_data = {
        "world_name": "Legacy World",
        "entities": {
            "e1": {
                "name": "Legacy Monster",
                "type": "Canavar",
                "attributes": {
                    "Irk": "Orc",
                    "Sınıf": "Warrior"
                }
            }
        }
    }
    with open(os.path.join(temp_campaign_dir, "data.json"), "w", encoding="utf-8") as f:
        json.dump(legacy_data, f)
        
    dm = DataManager()
    success, msg = dm.load_campaign(temp_campaign_dir)
    assert success is True
    
    entity = dm.data["entities"]["e1"]
    assert entity["type"] == "Monster"
    assert "LBL_RACE" in entity["attributes"]
    assert "LBL_CLASS" in entity["attributes"]
    assert entity["attributes"]["LBL_RACE"] == "Orc"


# ---------------------------------------------------------------------------
# Characterization tests — entity CRUD
# ---------------------------------------------------------------------------

def test_save_entity_with_none_eid_creates_uuid(data_manager):
    """save_entity(None, ...) must return a new UUID string and store the entity."""
    data_manager.data["world_name"] = "TestWorld"
    eid = data_manager.save_entity(None, {"name": "Goblin", "type": "Monster"})
    assert eid
    assert len(eid) == 36  # standard UUID length
    assert eid in data_manager.data["entities"]


def test_save_entity_with_existing_eid_updates_in_place(data_manager):
    """Re-saving with the same eid must update the record, not duplicate it."""
    data_manager.data["world_name"] = "TestWorld"
    eid = data_manager.save_entity(None, {"name": "Goblin", "type": "Monster"})
    data_manager.save_entity(eid, {"name": "Orc", "type": "Monster"})
    assert data_manager.data["entities"][eid]["name"] == "Orc"
    assert len(data_manager.data["entities"]) == 1


def test_save_entity_auto_sets_source_when_empty(data_manager):
    """When source is empty, save_entity should set it to the world name."""
    data_manager.data["world_name"] = "MyWorld"
    eid = data_manager.save_entity(None, {"name": "Mage", "type": "NPC", "source": ""})
    assert data_manager.data["entities"][eid]["source"] == "MyWorld"


def test_delete_entity_removes_from_data(data_manager):
    """delete_entity must remove the entity from data['entities']."""
    data_manager.data["world_name"] = "TestWorld"
    eid = data_manager.save_entity(None, {"name": "Goblin", "type": "Monster"})
    data_manager.delete_entity(eid)
    assert eid not in data_manager.data["entities"]


def test_delete_entity_nonexistent_does_not_raise(data_manager):
    """Deleting an entity that does not exist should not raise an exception."""
    data_manager.delete_entity("no-such-id")  # must not raise


def test_get_all_entity_mentions_structure(data_manager):
    """get_all_entity_mentions must return id/name/type dicts for every entity."""
    data_manager.data["world_name"] = "W"
    data_manager.save_entity(None, {"name": "Alice", "type": "Player"})
    data_manager.save_entity(None, {"name": "Goblin", "type": "Monster"})
    mentions = data_manager.get_all_entity_mentions()
    assert len(mentions) == 2
    names = {m["name"] for m in mentions}
    assert names == {"Alice", "Goblin"}
    for m in mentions:
        assert "id" in m
        assert "name" in m
        assert "type" in m


# ---------------------------------------------------------------------------
# Characterization tests — session CRUD
# ---------------------------------------------------------------------------

def test_create_session_adds_to_data(data_manager):
    """create_session must append a session and return its ID."""
    sid = data_manager.create_session("Session Alpha")
    ids = [s["id"] for s in data_manager.data["sessions"]]
    assert sid in ids
    session = data_manager.get_session(sid)
    assert session is not None
    assert session["name"] == "Session Alpha"


def test_get_session_returns_none_for_unknown_id(data_manager):
    """get_session with an unknown ID must return None."""
    assert data_manager.get_session("no-such-id") is None


def test_save_session_data_updates_fields(data_manager):
    """save_session_data must write notes, logs, and combatants into the session."""
    sid = data_manager.create_session("Combat 1")
    data_manager.save_session_data(sid, "Notes here", "Log here", [{"name": "Fighter"}])
    s = data_manager.get_session(sid)
    assert s["notes"] == "Notes here"
    assert s["logs"] == "Log here"
    assert s["combatants"] == [{"name": "Fighter"}]


def test_set_active_session_and_get_last(data_manager):
    """set_active_session + get_last_active_session_id must round-trip correctly."""
    s1 = data_manager.create_session("S1")
    s2 = data_manager.create_session("S2")
    data_manager.set_active_session(s1)
    assert data_manager.get_last_active_session_id() == s1
    data_manager.set_active_session(s2)
    assert data_manager.get_last_active_session_id() == s2


# ---------------------------------------------------------------------------
# Characterization tests — map pins
# ---------------------------------------------------------------------------

def test_add_pin_appends_correct_data(data_manager):
    """add_pin must append a pin dict with all expected fields."""
    data_manager.add_pin(100.0, 200.0, "entity-1", color="#ff0000", note="Dragon lair")
    pins = data_manager.data["map_data"]["pins"]
    assert len(pins) == 1
    p = pins[0]
    assert p["x"] == 100.0
    assert p["y"] == 200.0
    assert p["entity_id"] == "entity-1"
    assert p["color"] == "#ff0000"
    assert p["note"] == "Dragon lair"
    assert "id" in p


def test_remove_specific_pin_removes_correct_pin(data_manager):
    """remove_specific_pin must remove only the pin with the matching ID."""
    data_manager.add_pin(10.0, 20.0, "e1")
    data_manager.add_pin(30.0, 40.0, "e2")
    first_id = data_manager.data["map_data"]["pins"][0]["id"]
    data_manager.remove_specific_pin(first_id)
    remaining = data_manager.data["map_data"]["pins"]
    assert len(remaining) == 1
    assert remaining[0]["entity_id"] == "e2"


def test_move_pin_updates_coordinates(data_manager):
    """move_pin must update x and y of the matching pin."""
    data_manager.add_pin(10.0, 20.0, "e1")
    pin_id = data_manager.data["map_data"]["pins"][0]["id"]
    data_manager.move_pin(pin_id, 55.0, 66.0)
    p = data_manager.data["map_data"]["pins"][0]
    assert p["x"] == 55.0
    assert p["y"] == 66.0


def test_update_map_pin_modifies_color_and_note(data_manager):
    """update_map_pin must update color and note fields."""
    data_manager.add_pin(0.0, 0.0, "e1", color="#000000", note="old")
    pin_id = data_manager.data["map_data"]["pins"][0]["id"]
    data_manager.update_map_pin(pin_id, color="#ffffff", note="new")
    p = data_manager.data["map_data"]["pins"][0]
    assert p["color"] == "#ffffff"
    assert p["note"] == "new"


# ---------------------------------------------------------------------------
# Characterization tests — timeline pins
# ---------------------------------------------------------------------------

def test_add_timeline_pin_keeps_sorted_order(data_manager):
    """Timeline pins must be sorted by day after every add_timeline_pin call."""
    data_manager.add_timeline_pin(0.0, 0.0, day=10, note="B")
    data_manager.add_timeline_pin(0.0, 0.0, day=5, note="A")
    data_manager.add_timeline_pin(0.0, 0.0, day=15, note="C")
    days = [p["day"] for p in data_manager.data["map_data"]["timeline"]]
    assert days == sorted(days)


def test_get_timeline_pin_returns_correct_pin(data_manager):
    """get_timeline_pin must return the pin dict matching the given ID."""
    data_manager.add_timeline_pin(1.0, 2.0, day=7, note="Event")
    pin_id = data_manager.data["map_data"]["timeline"][0]["id"]
    p = data_manager.get_timeline_pin(pin_id)
    assert p is not None
    assert p["note"] == "Event"
    assert p["day"] == 7


def test_get_timeline_pin_returns_none_for_unknown(data_manager):
    """get_timeline_pin with an unknown ID must return None."""
    assert data_manager.get_timeline_pin("no-such-id") is None


def test_remove_timeline_pin_removes_correct_pin(data_manager):
    """remove_timeline_pin must remove only the pin with the matching ID."""
    data_manager.add_timeline_pin(0.0, 0.0, day=1, note="A")
    data_manager.add_timeline_pin(0.0, 0.0, day=2, note="B")
    pin_id = data_manager.data["map_data"]["timeline"][0]["id"]
    data_manager.remove_timeline_pin(pin_id)
    assert len(data_manager.data["map_data"]["timeline"]) == 1
    assert data_manager.data["map_data"]["timeline"][0]["note"] == "B"


# ---------------------------------------------------------------------------
# Characterization tests — file utilities
# ---------------------------------------------------------------------------

def test_get_full_path_resolves_relative_to_campaign(data_manager):
    """get_full_path with a relative path must return an absolute path under campaign dir."""
    path = data_manager.get_full_path("assets/image.png")
    assert os.path.isabs(path)
    assert path.endswith(os.path.join("assets", "image.png"))


def test_get_full_path_returns_none_for_none(data_manager):
    """get_full_path(None) must return None."""
    assert data_manager.get_full_path(None) is None


def test_import_image_copies_file_and_returns_relative_path(data_manager, tmp_path):
    """import_image must copy a file into assets/ and return its relative path."""
    src = tmp_path / "test_image.png"
    src.write_bytes(b"PNG_DATA")
    rel = data_manager.import_image(str(src))
    assert rel is not None
    assert rel.startswith("assets")
    full = data_manager.get_full_path(rel)
    assert os.path.exists(full)


def test_import_image_returns_none_without_campaign(tmp_path):
    """import_image must return None when no campaign is loaded."""
    dm = DataManager()
    dm.current_campaign_path = None
    src = tmp_path / "img.png"
    src.write_bytes(b"data")
    assert dm.import_image(str(src)) is None
