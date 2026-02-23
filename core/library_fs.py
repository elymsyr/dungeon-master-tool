import os
import shutil

KNOWN_LIBRARY_CATEGORIES = (
    "monsters",
    "spells",
    "equipment",
    "magic-items",
    "classes",
    "races",
    "weapons",
    "armor",
    "feats",
    "conditions",
    "backgrounds",
)

_CATEGORY_NORMALIZATION_MAP = {
    "monsters": "monster",
    "spells": "spell",
    "equipment": "equipment",
    "magic-items": "equipment",
    "weapons": "equipment",
    "armor": "equipment",
    "classes": "class",
    "races": "race",
    "feats": "feat",
    "conditions": "condition",
    "backgrounds": "background",
}


def _library_root(cache_dir):
    return os.path.join(cache_dir, "library")


def _normalize_category(category):
    category = str(category).lower()
    return _CATEGORY_NORMALIZATION_MAP.get(category, category.rstrip("s"))


def _iter_json_files(directory):
    try:
        names = sorted(n for n in os.listdir(directory) if n.lower().endswith(".json"))
    except OSError:
        return []
    return names


def _build_display_name(index):
    return index.replace("-", " ").replace("_", " ").title()


def migrate_legacy_layout(cache_dir, default_source="dnd5e"):
    """
    Migrates legacy layout:
      cache/library/<category>/<file>.json
    to canonical layout:
      cache/library/<source>/<category>/<file>.json

    Conflicts are non-destructive: if destination already exists, legacy file remains.
    """
    report = {
        "legacy_categories_found": 0,
        "moved_files": 0,
        "conflicts": 0,
        "removed_legacy_dirs": 0,
        "errors": [],
    }

    library_root = _library_root(cache_dir)
    if not os.path.isdir(library_root):
        return report

    canonical_source_root = os.path.join(library_root, default_source)

    for category in KNOWN_LIBRARY_CATEGORIES:
        legacy_dir = os.path.join(library_root, category)
        if not os.path.isdir(legacy_dir):
            continue

        report["legacy_categories_found"] += 1
        json_files = _iter_json_files(legacy_dir)
        if not json_files:
            try:
                os.rmdir(legacy_dir)
                report["removed_legacy_dirs"] += 1
            except OSError:
                pass
            continue

        for filename in json_files:
            src = os.path.join(legacy_dir, filename)
            dst_dir = os.path.join(canonical_source_root, category)
            dst = os.path.join(dst_dir, filename)

            if os.path.exists(dst):
                report["conflicts"] += 1
                continue

            try:
                os.makedirs(dst_dir, exist_ok=True)
                shutil.move(src, dst)
                report["moved_files"] += 1
            except OSError as exc:
                report["errors"].append(str(exc))

        try:
            if not os.listdir(legacy_dir):
                os.rmdir(legacy_dir)
                report["removed_legacy_dirs"] += 1
        except OSError:
            pass

    return report


def scan_library_tree(cache_dir, default_source="dnd5e"):
    """
    Scans library directories and returns:
      {source: {category: [entry, ...], ...}, ...}

    Entry shape:
      {
        "path": "...",
        "index": "adult-black-dragon",
        "display_name": "Adult Black Dragon",
        "source": "dnd5e",
        "category": "monsters",
      }
    """
    library_root = _library_root(cache_dir)
    tree = {}
    dedupe = set()

    if not os.path.isdir(library_root):
        return tree

    def add_category(source_key, category_name, category_path):
        source_bucket = tree.setdefault(source_key, {})
        cat_bucket = source_bucket.setdefault(category_name, [])

        for filename in _iter_json_files(category_path):
            index = filename[:-5]
            dedupe_key = (source_key, category_name, index)
            if dedupe_key in dedupe:
                continue
            dedupe.add(dedupe_key)

            cat_bucket.append(
                {
                    "path": os.path.join(category_path, filename),
                    "index": index,
                    "display_name": _build_display_name(index),
                    "source": source_key,
                    "category": category_name,
                }
            )

        cat_bucket.sort(key=lambda row: row["display_name"].lower())

    try:
        root_children = sorted(os.listdir(library_root))
    except OSError:
        return tree

    legacy_names = set(KNOWN_LIBRARY_CATEGORIES)
    for child in root_children:
        child_path = os.path.join(library_root, child)
        if not os.path.isdir(child_path):
            continue
        if child == "images":
            continue
        if child in legacy_names:
            continue

        try:
            category_names = sorted(
                d
                for d in os.listdir(child_path)
                if os.path.isdir(os.path.join(child_path, d))
            )
        except OSError:
            continue

        for category_name in category_names:
            add_category(child, category_name, os.path.join(child_path, category_name))

    # Legacy compatibility read: cache/library/<category>/*
    for category_name in KNOWN_LIBRARY_CATEGORIES:
        legacy_path = os.path.join(library_root, category_name)
        if os.path.isdir(legacy_path):
            add_category(default_source, category_name, legacy_path)

    return tree


def search_library_tree(tree, query, normalized_categories=None, source=None):
    """
    Searches scanned library tree.

    Returns list rows:
      {
        "source": "dnd5e",
        "category": "monsters",
        "normalized_category": "monster",
        "index": "aboleth",
        "display_name": "Aboleth",
        "path": "...",
      }
    """
    query = (query or "").strip().lower()
    source = (source or "").strip().lower()

    norm_filters = None
    if normalized_categories:
        norm_filters = {str(c).strip().lower() for c in normalized_categories if str(c).strip()}

    results = []
    for source_key, categories in tree.items():
        if source and source_key.lower() != source:
            continue

        for category_name, entries in categories.items():
            normalized = _normalize_category(category_name)
            if norm_filters and normalized not in norm_filters:
                continue

            for entry in entries:
                haystack = (
                    f"{entry.get('display_name', '')} "
                    f"{entry.get('index', '')} "
                    f"{category_name} {source_key}"
                ).lower()
                if query and query not in haystack:
                    continue

                results.append(
                    {
                        "source": source_key,
                        "category": category_name,
                        "normalized_category": normalized,
                        "index": entry.get("index", ""),
                        "display_name": entry.get("display_name", entry.get("index", "")),
                        "path": entry.get("path", ""),
                    }
                )

    results.sort(key=lambda row: (row["display_name"].lower(), row["source"], row["category"]))
    return results
