from core.locales import tr
import i18n
import pytest

def test_tr_basic_translation():
    """Test if tr() returns correct strings for default language (EN)."""
    i18n.set("locale", "en")
    assert tr("CAT_MONSTER") == "Monster"
    assert tr("BTN_SAVE") == "Save"

def test_tr_turkish_translation():
    """Test if tr() returns correct strings for Turkish."""
    i18n.set("locale", "tr")
    assert tr("CAT_MONSTER") == "Canavar"
    assert tr("BTN_SAVE") == "Kaydet"

def test_tr_missing_key():
    """Test behavior when a key is missing."""
    i18n.set("locale", "en")
    # i18n usually returns the key itself if missing
    assert tr("NON_EXISTENT_KEY") == "NON_EXISTENT_KEY"
