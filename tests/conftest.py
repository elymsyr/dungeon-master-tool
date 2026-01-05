import os
import pytest
from core.data_manager import DataManager

@pytest.fixture
def temp_campaign_dir(tmp_path):
    """Provides a temporary campaign directory."""
    d = tmp_path / "test_campaign"
    d.mkdir()
    return str(d)

@pytest.fixture
def data_manager(temp_campaign_dir):
    """Provides a DataManager instance with a temp directory."""
    dm = DataManager()
    dm.current_campaign_path = temp_campaign_dir
    # Ensure folders exist
    os.makedirs(os.path.join(temp_campaign_dir, "assets"), exist_ok=True)
    os.makedirs(os.path.join(temp_campaign_dir, "entities"), exist_ok=True)
    os.makedirs(os.path.join(temp_campaign_dir, "maps"), exist_ok=True)
    return dm
