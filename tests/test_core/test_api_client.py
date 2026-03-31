import pytest
from unittest.mock import MagicMock
from core.api_client import DndApiClient, Dnd5eApiSource


@pytest.fixture
def dnd5e_source():
    session = MagicMock()
    return Dnd5eApiSource(session)


@pytest.fixture
def api_client():
    return DndApiClient()


def test_api_endpoint_map(dnd5e_source):
    """Test if Endpoint Map uses standardized English keys."""
    assert dnd5e_source.ENDPOINT_MAP["Monster"] == "monsters"
    assert dnd5e_source.ENDPOINT_MAP["Spell"] == "spells"


def test_parse_monster(dnd5e_source):
    """Test parsing a monster from API response."""
    mock_data = {
        "name": "Aboleth",
        "size": "Large",
        "type": "aberration",
        "alignment": "lawful evil",
        "armor_class": [{"value": 17, "type": "natural armor"}],
        "hit_points": 135,
        "challenge_rating": 10,
        "strength": 21,
        "senses": {"passive_perception": 20, "darkvision": "120 ft."},
        "languages": "Deep Speech, telepathy 120 ft.",
    }

    parsed = dnd5e_source.parse_monster(mock_data)

    assert parsed["name"] == "Aboleth"
    assert parsed["type"] == "Monster"
    assert parsed["combat_stats"]["ac"] == "17 (natural armor)"
    assert parsed["combat_stats"]["cr"] == "10"
    assert parsed["attributes"]["LBL_SENSES"] == "darkvision: 120 ft."
    assert parsed["attributes"]["LBL_LANGUAGE"] == "Deep Speech, telepathy 120 ft."


def test_parse_spell(dnd5e_source):
    """Test parsing a spell from API response."""
    mock_data = {
        "name": "Fireball",
        "level": 3,
        "school": {"name": "Evocation"},
        "casting_time": "1 action",
        "range": "150 feet",
        "components": ["V", "S", "M"],
        "duration": "Instantaneous",
        "concentration": False,
        "desc": ["A bright streak flashes from your pointing finger..."],
    }

    parsed = dnd5e_source.parse_spell(mock_data)

    assert parsed["name"] == "Fireball"
    assert parsed["type"] == "Spell"
    assert parsed["attributes"]["LBL_LEVEL"] == "3"
    assert parsed["attributes"]["LBL_SCHOOL"] == "Evocation"
    assert parsed["attributes"]["LBL_COMPONENTS"] == "V, S, M"


def test_api_client_delegates_to_source(api_client):
    """DndApiClient.parse_dispatcher delegates to the active source."""
    data = {
        "name": "Goblin",
        "size": "Small",
        "type": "humanoid",
        "alignment": "neutral evil",
        "armor_class": [{"value": 15, "type": "leather armor, shield"}],
        "hit_points": 7,
        "challenge_rating": 0.25,
        "strength": 8,
    }
    result = api_client.parse_dispatcher("Monster", data)
    assert result["name"] == "Goblin"
    assert result["type"] == "Monster"
    assert result.get("api_source") == "dnd5e"
