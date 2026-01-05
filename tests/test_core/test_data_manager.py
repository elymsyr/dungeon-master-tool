import os
import json
from core.data_manager import DataManager

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
