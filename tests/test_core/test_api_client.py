import pytest
from core.api_client import DndApiClient

@pytest.fixture
def api_client():
    return DndApiClient()

def test_api_endpoint_map(api_client):
    """Test if Endpoint Map uses standardized English keys."""
    assert api_client.ENDPOINT_MAP["Monster"] == "monsters"
    assert api_client.ENDPOINT_MAP["Spell"] == "spells"

def test_parse_monster(api_client, mocker):
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
        "languages": "Deep Speech, telepathy 120 ft."
    }
    
    parsed = api_client.parse_monster(mock_data)
    
    assert parsed["name"] == "Aboleth"
    assert parsed["type"] == "Monster"
    assert parsed["combat_stats"]["ac"] == "17 (natural armor)"
    assert parsed["combat_stats"]["cr"] == "10"
    assert parsed["attributes"]["LBL_SENSES"] == "darkvision: 120 ft."
    assert parsed["attributes"]["LBL_LANGUAGE"] == "Deep Speech, telepathy 120 ft."

def test_parse_spell(api_client):
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
        "desc": ["A bright streak flashes from your pointing finger..."]
    }
    
    parsed = api_client.parse_spell(mock_data)
    
    assert parsed["name"] == "Fireball"
    assert parsed["type"] == "Spell"
    assert parsed["attributes"]["LBL_LEVEL"] == "3"
    assert parsed["attributes"]["LBL_SCHOOL"] == "Evocation"
    assert parsed["attributes"]["LBL_COMPONENTS"] == "V, S, M"
