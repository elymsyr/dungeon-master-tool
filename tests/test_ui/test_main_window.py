import pytest
from PyQt6.QtWidgets import QApplication
from main import MainWindow
from core.data_manager import DataManager
import os

@pytest.fixture
def initialized_data_manager(temp_campaign_dir):
    """Provides a DataManager with a campaign already created/loaded."""
    dm = DataManager()
    dm.create_campaign("UI Test World")
    # create_campaign creates it in WORLDS_DIR. 
    # For UI tests, we might want to ensure it's fully isolated.
    # But since DataManager.create_campaign is hardcoded to WORLDS_DIR, 
    # we'll just use it and rely on cleanup if needed.
    return dm

def test_main_window_init(qtbot, initialized_data_manager):
    """Test if MainWindow initializes and shows tabs."""
    window = MainWindow(initialized_data_manager)
    qtbot.addWidget(window)
    
    assert window.windowTitle().startswith("DM Tool - UI Test World")
    assert window.tabs.count() >= 3
    assert window.db_tab is not None
    assert window.map_tab is not None
    assert window.session_tab is not None

def test_tab_switching(qtbot, initialized_data_manager):
    """Test switching between tabs."""
    window = MainWindow(initialized_data_manager)
    qtbot.addWidget(window)
    
    # Switch to Map Tab (index 1)
    window.tabs.setCurrentIndex(1)
    assert window.tabs.currentIndex() == 1
    
    # Switch to Session Tab (index 2)
    window.tabs.setCurrentIndex(2)
    assert window.tabs.currentIndex() == 2

def test_language_switch_ui(qtbot, initialized_data_manager):
    """Test if language switch Updates UI text (Smoke Test)."""
    window = MainWindow(initialized_data_manager)
    qtbot.addWidget(window)
    
    # Switch to Turkish
    # combo_lang index 1 is Türkçe
    qtbot.keyClicks(window.combo_lang, "T") # Simple way to trigger or just set index
    window.combo_lang.setCurrentIndex(1)
    
    # Check if a tab text changed (Smoke)
    # TAB_DB in TR is "Veritabanı ve Karakterler"
    assert "Veritabanı" in window.tabs.tabText(0)
