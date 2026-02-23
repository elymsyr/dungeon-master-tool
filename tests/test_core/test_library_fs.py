import json
import os

from core.library_fs import migrate_legacy_layout, scan_library_tree, search_library_tree


def _write_json(path, data=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(data or {}, handle)


def test_migrate_legacy_layout_moves_files_to_source_scoped_tree(tmp_path):
    cache_dir = tmp_path / "cache"
    legacy_file = cache_dir / "library" / "monsters" / "aboleth.json"
    _write_json(str(legacy_file), {"index": "aboleth"})

    report = migrate_legacy_layout(str(cache_dir), default_source="dnd5e")

    expected = cache_dir / "library" / "dnd5e" / "monsters" / "aboleth.json"
    assert expected.exists()
    assert report["moved_files"] == 1
    assert report["legacy_categories_found"] == 1


def test_migrate_legacy_layout_is_idempotent(tmp_path):
    cache_dir = tmp_path / "cache"
    legacy_file = cache_dir / "library" / "monsters" / "aboleth.json"
    _write_json(str(legacy_file), {"index": "aboleth"})

    first = migrate_legacy_layout(str(cache_dir), default_source="dnd5e")
    second = migrate_legacy_layout(str(cache_dir), default_source="dnd5e")

    assert first["moved_files"] == 1
    assert second["moved_files"] == 0


def test_scan_library_tree_reads_legacy_layout_as_default_source(tmp_path):
    cache_dir = tmp_path / "cache"
    legacy_file = cache_dir / "library" / "monsters" / "aboleth.json"
    _write_json(str(legacy_file), {"index": "aboleth"})

    tree = scan_library_tree(str(cache_dir), default_source="dnd5e")

    assert "dnd5e" in tree
    assert "monsters" in tree["dnd5e"]
    indices = {row["index"] for row in tree["dnd5e"]["monsters"]}
    assert "aboleth" in indices


def test_search_library_tree_filters_by_query_and_normalized_category(tmp_path):
    cache_dir = tmp_path / "cache"
    canonical = cache_dir / "library" / "dnd5e" / "monsters" / "adult-black-dragon.json"
    _write_json(str(canonical), {"index": "adult-black-dragon"})

    tree = scan_library_tree(str(cache_dir), default_source="dnd5e")
    results = search_library_tree(
        tree,
        query="black",
        normalized_categories={"monster"},
    )

    assert len(results) == 1
    assert results[0]["category"] == "monsters"
    assert results[0]["index"] == "adult-black-dragon"
