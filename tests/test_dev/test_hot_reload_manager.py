from pathlib import Path

from core.dev.hot_reload_manager import HotReloadManager


class _DummyPlayerWindow:
    def update_theme(self, _qss):
        pass


class _DummyDataManager:
    def __init__(self):
        self.current_theme = "dark"
        self.data = {"world_name": "DevWorld"}


class _DummyWindow:
    def __init__(self):
        self.data_manager = _DummyDataManager()
        self.player_window = _DummyPlayerWindow()
        self.rebuild_called = False
        self.retranslate_called = False
        self.current_stylesheet = ""

    def setStyleSheet(self, style):
        self.current_stylesheet = style

    def rebuild_root_widget(self, reload_main_root_module=True):
        self.rebuild_called = reload_main_root_module

    def retranslate_ui(self):
        self.retranslate_called = True


def test_module_name_from_path_regular_module():
    assert HotReloadManager.module_name_from_path("ui/tabs/map_tab.py") == "ui.tabs.map_tab"


def test_module_name_from_path_package_init():
    assert HotReloadManager.module_name_from_path("core/audio/__init__.py") == "core.audio"


def test_classify_paths_groups_by_type():
    classified = HotReloadManager.classify_paths(
        [
            "ui/tabs/map_tab.py",
            "themes/dark.qss",
            "locales/en.yml",
            "assets/soundpad/soundpad_library.yaml",
            "README.md",
        ]
    )

    assert classified["python"] == ["ui/tabs/map_tab.py"]
    assert classified["qss"] == ["themes/dark.qss"]
    assert classified["data"] == [
        "assets/soundpad/soundpad_library.yaml",
        "locales/en.yml",
    ]
    assert classified["locales"] == ["locales/en.yml"]


def test_attempt_hot_reload_returns_failure_payload_on_reload_error(monkeypatch, tmp_path):
    window = _DummyWindow()
    manager = HotReloadManager(window, project_root=Path(tmp_path))

    def _raise_reload(_paths):
        raise RuntimeError("synthetic reload failure")

    monkeypatch.setattr(manager, "_reload_python_modules", _raise_reload)

    result = manager.attempt_hot_reload(["ui/tabs/map_tab.py"])

    assert result["ok"] is False
    assert "synthetic reload failure" in result["error"]
    assert "RuntimeError" in result["details"]


def test_stable_module_detection_handles_windows_mp_main(tmp_path):
    window = _DummyWindow()
    manager = HotReloadManager(window, project_root=Path(tmp_path))

    assert manager._is_stable_module("__mp_main__") is True
    assert manager._is_stable_module("__random_runtime_module__") is True


def test_main_py_change_requires_restart(tmp_path):
    window = _DummyWindow()
    manager = HotReloadManager(window, project_root=Path(tmp_path))

    result = manager.attempt_hot_reload(["main.py"])

    assert result["ok"] is False
    assert "restart required" in result["error"]


def test_python_reload_without_locale_change_does_not_force_retranslate(
    monkeypatch, tmp_path
):
    window = _DummyWindow()
    manager = HotReloadManager(window, project_root=Path(tmp_path))

    monkeypatch.setattr(manager, "_reload_python_modules", lambda _paths: None)

    result = manager.attempt_hot_reload(["ui/main_root.py"])

    assert result["ok"] is True
    assert window.rebuild_called is True
    assert window.retranslate_called is False
