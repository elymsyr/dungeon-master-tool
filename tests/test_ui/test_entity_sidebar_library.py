from PyQt6.QtCore import Qt

from ui.widgets.entity_sidebar import EntitySidebar


class FakeDataManager:
    def __init__(self):
        self.data = {
            "entities": {
                "ent-local": {
                    "name": "Aboleth Local",
                    "type": "Monster",
                    "source": "Campaign",
                }
            }
        }
        self.search_calls = []

    def search_library_catalog(self, query, normalized_categories=None, source=None):
        self.search_calls.append((query, normalized_categories, source))
        if "abo" in (query or "").lower() or normalized_categories:
            return [
                {
                    "category": "monsters",
                    "index": "aboleth",
                    "display_name": "Aboleth",
                    "source": "dnd5e",
                    "path": "/tmp/aboleth.json",
                }
            ]
        return []

    def save_entity(self, eid, data):
        self.data["entities"]["generated"] = data
        return "generated"


def _list_ids(sidebar):
    ids = []
    for idx in range(sidebar.list_widget.count()):
        item = sidebar.list_widget.item(idx)
        ids.append(item.data(Qt.ItemDataRole.UserRole))
    return ids


def test_sidebar_shows_local_and_library_rows_with_search(qtbot):
    dm = FakeDataManager()
    sidebar = EntitySidebar(dm)
    qtbot.addWidget(sidebar)

    sidebar.inp_search.setText("abo")
    sidebar.refresh_list()
    ids = _list_ids(sidebar)

    assert "ent-local" in ids
    assert "lib_monsters_aboleth" in ids


def test_sidebar_shows_library_rows_when_category_filter_is_active(qtbot):
    dm = FakeDataManager()
    sidebar = EntitySidebar(dm)
    qtbot.addWidget(sidebar)

    sidebar.inp_search.setText("")
    sidebar.toggle_category_filter("Monster", True)
    ids = _list_ids(sidebar)

    assert "lib_monsters_aboleth" in ids
    assert dm.search_calls


def test_sidebar_hides_library_rows_without_search_or_category_filter(qtbot):
    dm = FakeDataManager()
    sidebar = EntitySidebar(dm)
    qtbot.addWidget(sidebar)

    sidebar.inp_search.setText("")
    sidebar.clear_filters()
    sidebar.refresh_list()
    ids = _list_ids(sidebar)

    assert "ent-local" in ids
    assert "lib_monsters_aboleth" not in ids
