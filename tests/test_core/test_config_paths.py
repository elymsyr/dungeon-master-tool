import os

import config


def test_resolve_data_root_prefers_portable_when_writable(tmp_path):
    portable = tmp_path / "portable-root"
    xdg_home = tmp_path / "xdg-home"
    env_map = {"XDG_DATA_HOME": str(xdg_home)}

    def probe(path):
        return os.path.abspath(path) == os.path.abspath(str(portable))

    root, mode, reason = config.resolve_data_root(
        str(portable),
        env_map=env_map,
        platform_name="linux",
        probe=probe,
    )

    assert root == os.path.abspath(str(portable))
    assert mode == "portable"
    assert reason == "portable_writable"


def test_resolve_data_root_falls_back_when_portable_unwritable(tmp_path):
    portable = tmp_path / "portable-root"
    xdg_home = tmp_path / "xdg-home"
    env_map = {"XDG_DATA_HOME": str(xdg_home)}
    expected_fallback = os.path.join(str(xdg_home), "dungeon-master-tool")

    def probe(path):
        return os.path.abspath(path) == os.path.abspath(expected_fallback)

    root, mode, reason = config.resolve_data_root(
        str(portable),
        env_map=env_map,
        platform_name="linux",
        probe=probe,
    )

    assert root == os.path.abspath(expected_fallback)
    assert mode == "fallback"
    assert "portable_unwritable" in reason


def test_resolve_data_root_honors_dm_data_root_override(tmp_path):
    portable = tmp_path / "portable-root"
    override = tmp_path / "custom-data-root"
    env_map = {"DM_DATA_ROOT": str(override), "XDG_DATA_HOME": str(tmp_path / "xdg-home")}

    def probe(path):
        return os.path.abspath(path) == os.path.abspath(str(override))

    root, mode, reason = config.resolve_data_root(
        str(portable),
        env_map=env_map,
        platform_name="linux",
        probe=probe,
    )

    assert root == os.path.abspath(str(override))
    assert mode == "override"
    assert reason == "env_override"
