"""Shared utility functions for field mapping and data normalisation."""


def json_dict_to_str(d):
    if not d:
        return ""
    return ", ".join([f"{k}: {v}" for k, v in d.items()])


def format_actions(action_list):
    """Convert a raw action list (list of dicts with 'name'/'desc') to the
    standard ``[{"name": ..., "desc": ...}]`` format used by NpcSheet."""
    if not action_list:
        return []
    return [{"name": a.get("name", "Action"), "desc": a.get("desc", "")} for a in action_list]
