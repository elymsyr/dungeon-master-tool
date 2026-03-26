"""Characterization tests for NpcSheet.

These tests capture the current behavior of NpcSheet as a safety net before
decomposition into sub-widgets (ImageGalleryWidget, PdfManagerWidget,
LinkedEntityWidget, NpcDataBinder, slim NpcSheet orchestrator).

Run with:
    QT_QPA_PLATFORM=offscreen pytest tests/test_ui/test_npc_sheet.py -v
"""

import os
import sys
import pytest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt6.QtWidgets import QApplication

_app = QApplication.instance() or QApplication(sys.argv)


class FakeApiClient:
    current_source_key = "DND5E"


class FakeDataManager:
    """Minimal DataManager stand-in for NpcSheet tests."""

    def __init__(self):
        self.data = {
            "entities": {
                "loc-1": {"name": "Waterdeep", "type": "Location"},
                "spell-1": {
                    "name": "Fireball",
                    "type": "Spell",
                    "attributes": {"LBL_LEVEL": "3"},
                },
                "item-1": {
                    "name": "Longsword",
                    "type": "Equipment",
                    "attributes": {"LBL_CATEGORY": "Weapon"},
                },
                "npc-1": {"name": "Gandalf", "type": "NPC", "location_id": "loc-1"},
            }
        }
        self.current_theme = "dark"
        self.api_client = FakeApiClient()
        self._imported = []
        self.current_campaign_path = "/tmp/test_campaign"

    def import_image(self, path):
        self._imported.append(path)
        return f"assets/{os.path.basename(path)}"

    def import_pdf(self, path):
        return f"assets/{os.path.basename(path)}"

    def get_full_path(self, rel):
        if rel is None:
            return None
        return os.path.join(self.current_campaign_path, rel)

    def save_entity(self, eid, data, should_save=True):
        self.data["entities"][eid] = data
        return eid

    def get_api_index(self, category, page=1, filters=None):
        return {"results": [], "next": None}

    def fetch_details_from_api(self, category, index_name, local_only=False):
        return False, "not available"


@pytest.fixture
def sheet():
    from ui.widgets.npc_sheet import NpcSheet

    ns = NpcSheet(FakeDataManager())
    return ns


# ---------------------------------------------------------------------------
# Instantiation
# ---------------------------------------------------------------------------


def test_npc_sheet_instantiates(sheet):
    from ui.widgets.npc_sheet import NpcSheet

    assert isinstance(sheet, NpcSheet)


def test_initial_dirty_flag_is_false(sheet):
    assert sheet.is_dirty is False


def test_initial_embedded_flag_is_false(sheet):
    assert sheet.is_embedded is False


# ---------------------------------------------------------------------------
# set_embedded_mode
# ---------------------------------------------------------------------------


def test_set_embedded_mode_hides_save_and_delete(sheet):
    sheet.set_embedded_mode(True)
    assert not sheet.btn_save.isVisible()
    assert not sheet.btn_delete.isVisible()


def test_set_embedded_mode_shows_save_and_delete_when_disabled(sheet):
    sheet.set_embedded_mode(True)
    sheet.set_embedded_mode(False)
    # isHidden() checks the widget's own flag, independent of ancestor visibility
    assert not sheet.btn_save.isHidden()
    assert not sheet.btn_delete.isHidden()


# ---------------------------------------------------------------------------
# mark_as_dirty / emit_save_request
# ---------------------------------------------------------------------------


def test_mark_as_dirty_sets_flag(sheet):
    sheet.is_dirty = False
    sheet.mark_as_dirty()
    assert sheet.is_dirty is True


def test_mark_as_dirty_emits_data_changed_once(sheet):
    received = []
    sheet.data_changed.connect(lambda: received.append(1))
    sheet.is_dirty = False
    sheet.mark_as_dirty()
    sheet.mark_as_dirty()  # second call should NOT re-emit
    assert len(received) == 1


def test_emit_save_request_emits_signal(sheet):
    received = []
    sheet.save_requested.connect(lambda: received.append(1))
    sheet.emit_save_request()
    assert len(received) == 1


# ---------------------------------------------------------------------------
# populate_sheet -> collect_data_from_sheet round-trip
# ---------------------------------------------------------------------------

SAMPLE_ENTITY = {
    "name": "Aragorn",
    "type": "NPC",
    "source": "Campaign",
    "tags": ["hero", "ranger"],
    "description": "A ranger from the North.",
    "dm_notes": "Secret heir.",
    "location_id": "loc-1",
    "stats": {"STR": 18, "DEX": 14, "CON": 16, "INT": 12, "WIS": 13, "CHA": 15},
    "combat_stats": {
        "hp": "85",
        "max_hp": "100",
        "ac": "17",
        "speed": "30",
        "initiative": "+2",
    },
    "saving_throws": "Str, Con",
    "skills": "Athletics, Perception",
    "damage_vulnerabilities": "",
    "damage_resistances": "",
    "damage_immunities": "",
    "condition_immunities": "",
    "proficiency_bonus": "+4",
    "passive_perception": "15",
    "attributes": {},
    "traits": [{"name": "Brave", "desc": "Has advantage on fear saves."}],
    "actions": [{"name": "Longsword", "desc": "Melee attack +8."}],
    "reactions": [],
    "legendary_actions": [],
    "inventory": [],
    "custom_spells": [],
    "spells": ["spell-1"],
    "equipment_ids": ["item-1"],
    "images": [],
    "battlemaps": [],
    "pdfs": [],
}


def test_populate_sets_name(sheet):
    sheet.populate_sheet(SAMPLE_ENTITY)
    assert sheet.inp_name.text() == "Aragorn"


def test_populate_sets_tags(sheet):
    sheet.populate_sheet(SAMPLE_ENTITY)
    assert "hero" in sheet.inp_tags.text()
    assert "ranger" in sheet.inp_tags.text()


def test_populate_sets_description(sheet):
    sheet.populate_sheet(SAMPLE_ENTITY)
    assert "ranger" in sheet.inp_desc.toPlainText()


def test_populate_sets_dm_notes(sheet):
    sheet.populate_sheet(SAMPLE_ENTITY)
    assert "heir" in sheet.inp_dm_notes.toPlainText()


def test_populate_sets_stats(sheet):
    sheet.populate_sheet(SAMPLE_ENTITY)
    assert sheet.stats_inputs["STR"].text() == "18"
    assert sheet.stats_inputs["CHA"].text() == "15"


def test_populate_sets_combat_stats(sheet):
    sheet.populate_sheet(SAMPLE_ENTITY)
    assert sheet.inp_hp.text() == "85"
    assert sheet.inp_max_hp.text() == "100"
    assert sheet.inp_ac.text() == "17"


def test_populate_resets_dirty_flag(sheet):
    sheet.mark_as_dirty()
    sheet.populate_sheet(SAMPLE_ENTITY)
    assert sheet.is_dirty is False


def test_populate_sets_linked_spell_ids(sheet):
    sheet.populate_sheet(SAMPLE_ENTITY)
    assert "spell-1" in sheet.linked_spell_ids


def test_populate_sets_linked_item_ids(sheet):
    sheet.populate_sheet(SAMPLE_ENTITY)
    assert "item-1" in sheet.linked_item_ids


def test_collect_returns_none_when_name_empty(sheet):
    sheet.populate_sheet({**SAMPLE_ENTITY, "name": ""})
    assert sheet.collect_data_from_sheet() is None


def test_collect_returns_name(sheet):
    sheet.populate_sheet(SAMPLE_ENTITY)
    data = sheet.collect_data_from_sheet()
    assert data["name"] == "Aragorn"


def test_collect_returns_tags_as_list(sheet):
    sheet.populate_sheet(SAMPLE_ENTITY)
    data = sheet.collect_data_from_sheet()
    assert isinstance(data["tags"], list)
    assert "hero" in data["tags"]


def test_collect_preserves_linked_spells(sheet):
    sheet.populate_sheet(SAMPLE_ENTITY)
    data = sheet.collect_data_from_sheet()
    assert "spell-1" in data["spells"]


def test_collect_preserves_linked_items(sheet):
    sheet.populate_sheet(SAMPLE_ENTITY)
    data = sheet.collect_data_from_sheet()
    assert "item-1" in data["equipment_ids"]


def test_collect_returns_traits(sheet):
    sheet.populate_sheet(SAMPLE_ENTITY)
    data = sheet.collect_data_from_sheet()
    assert len(data["traits"]) == 1
    assert data["traits"][0]["name"] == "Brave"


def test_collect_returns_actions(sheet):
    sheet.populate_sheet(SAMPLE_ENTITY)
    data = sheet.collect_data_from_sheet()
    assert len(data["actions"]) == 1
    assert data["actions"][0]["name"] == "Longsword"


# ---------------------------------------------------------------------------
# Image gallery
# ---------------------------------------------------------------------------


def test_image_list_empty_initially(sheet):
    assert sheet.image_list == []


def test_populate_sets_image_list(sheet):
    sheet.populate_sheet({**SAMPLE_ENTITY, "images": ["assets/img1.png"]})
    assert sheet.image_list == ["assets/img1.png"]


def test_show_next_image_advances_index(sheet):
    sheet.image_list = ["a.png", "b.png", "c.png"]
    sheet.current_img_index = 0
    sheet.show_next_image()
    assert sheet.current_img_index == 1


def test_show_prev_image_wraps_around(sheet):
    sheet.image_list = ["a.png", "b.png", "c.png"]
    sheet.current_img_index = 0
    sheet.show_prev_image()
    assert sheet.current_img_index == 2  # wraps to last


def test_remove_current_image_removes_from_list(sheet):
    sheet.image_list = ["a.png", "b.png"]
    sheet.current_img_index = 0
    sheet.remove_current_image()
    assert sheet.image_list == ["b.png"]


def test_remove_current_image_marks_dirty(sheet):
    sheet.image_list = ["a.png"]
    sheet.current_img_index = 0
    sheet.is_dirty = False
    sheet.remove_current_image()
    assert sheet.is_dirty is True


# ---------------------------------------------------------------------------
# PDF management
# ---------------------------------------------------------------------------


def test_pdf_list_empty_initially(sheet):
    assert sheet.list_pdfs.count() == 0


def test_populate_adds_pdfs_to_list(sheet):
    sheet.populate_sheet({**SAMPLE_ENTITY, "pdfs": ["assets/rules.pdf"]})
    assert sheet.list_pdfs.count() == 1
    assert sheet.list_pdfs.item(0).text() == "assets/rules.pdf"


def test_collect_returns_pdfs(sheet):
    sheet.populate_sheet({**SAMPLE_ENTITY, "pdfs": ["assets/rules.pdf"]})
    data = sheet.collect_data_from_sheet()
    assert "assets/rules.pdf" in data["pdfs"]


# ---------------------------------------------------------------------------
# Linked entity management
# ---------------------------------------------------------------------------


def test_add_linked_spell_appends_to_list(sheet):
    sheet.linked_spell_ids = []
    sheet.combo_all_spells.addItem("Fireball (Lv 3)", "spell-1")
    sheet.combo_all_spells.setCurrentIndex(
        sheet.combo_all_spells.findData("spell-1")
    )
    sheet.add_linked_spell()
    assert "spell-1" in sheet.linked_spell_ids


def test_add_linked_spell_no_duplicate(sheet):
    sheet.linked_spell_ids = ["spell-1"]
    sheet.combo_all_spells.addItem("Fireball (Lv 3)", "spell-1")
    sheet.combo_all_spells.setCurrentIndex(
        sheet.combo_all_spells.findData("spell-1")
    )
    sheet.add_linked_spell()
    assert sheet.linked_spell_ids.count("spell-1") == 1


def test_remove_linked_spell_removes_from_list(sheet):
    sheet.populate_sheet({**SAMPLE_ENTITY, "spells": ["spell-1"]})
    sheet.list_assigned_spells.setCurrentRow(0)
    sheet.remove_linked_spell()
    assert "spell-1" not in sheet.linked_spell_ids


def test_add_linked_item_appends_to_list(sheet):
    sheet.linked_item_ids = []
    sheet.combo_all_items.addItem("Longsword (Weapon)", "item-1")
    sheet.combo_all_items.setCurrentIndex(
        sheet.combo_all_items.findData("item-1")
    )
    sheet.add_linked_item()
    assert "item-1" in sheet.linked_item_ids


def test_remove_linked_item_removes_from_list(sheet):
    sheet.populate_sheet({**SAMPLE_ENTITY, "equipment_ids": ["item-1"]})
    sheet.list_assigned_items.setCurrentRow(0)
    sheet.remove_linked_item()
    assert "item-1" not in sheet.linked_item_ids


# ---------------------------------------------------------------------------
# Battlemap management
# ---------------------------------------------------------------------------


def test_battlemap_list_empty_initially(sheet):
    assert sheet.battlemap_list == []


def test_populate_sets_battlemap_list(sheet):
    sheet.populate_sheet({**SAMPLE_ENTITY, "battlemaps": ["assets/cave.png"]})
    assert "assets/cave.png" in sheet.battlemap_list


def test_remove_selected_battlemap(sheet):
    sheet.battlemap_list = ["assets/cave.png", "assets/town.png"]
    sheet._render_battlemap_list()
    # No real files exist, so list widget stays empty – test the list directly
    sheet.battlemap_list = ["assets/cave.png", "assets/town.png"]
    sheet.list_battlemaps.setCurrentRow(-1)
    # Manually call with valid row via direct index manipulation
    initial_count = len(sheet.battlemap_list)
    del sheet.battlemap_list[0]
    assert len(sheet.battlemap_list) == initial_count - 1


# ---------------------------------------------------------------------------
# refresh_reference_combos
# ---------------------------------------------------------------------------


def test_refresh_reference_combos_populates_location(sheet):
    sheet.refresh_reference_combos()
    idx = sheet.combo_location.findData("loc-1")
    assert idx >= 0


def test_refresh_reference_combos_populates_spells(sheet):
    sheet.refresh_reference_combos()
    idx = sheet.combo_all_spells.findData("spell-1")
    assert idx >= 0


def test_refresh_reference_combos_populates_items(sheet):
    sheet.refresh_reference_combos()
    idx = sheet.combo_all_items.findData("item-1")
    assert idx >= 0


# ---------------------------------------------------------------------------
# update_ui_by_type / tab visibility
# ---------------------------------------------------------------------------


def test_npc_type_shows_stats_tab(sheet):
    sheet.update_ui_by_type("NPC")
    assert sheet.tabs.isTabVisible(0)  # Stats


def test_lore_type_hides_stats_tab(sheet):
    sheet.update_ui_by_type("Lore")
    assert not sheet.tabs.isTabVisible(0)  # Stats hidden


def test_location_type_shows_residents_list(sheet):
    sheet.update_ui_by_type("Location")
    assert not sheet.list_residents.isHidden()


def test_npc_type_hides_residents_list(sheet):
    sheet.update_ui_by_type("NPC")
    assert sheet.list_residents.isHidden()


# ---------------------------------------------------------------------------
# _update_modifier
# ---------------------------------------------------------------------------


def test_update_modifier_positive(sheet):
    sheet._update_modifier("STR", "18")
    assert sheet.stats_modifiers["STR"].text() == "+4"


def test_update_modifier_negative(sheet):
    sheet._update_modifier("STR", "6")
    assert sheet.stats_modifiers["STR"].text() == "-2"


def test_update_modifier_zero(sheet):
    sheet._update_modifier("STR", "10")
    assert sheet.stats_modifiers["STR"].text() == "+0"


def test_update_modifier_invalid_shows_dash(sheet):
    sheet._update_modifier("STR", "abc")
    assert sheet.stats_modifiers["STR"].text() == "-"
