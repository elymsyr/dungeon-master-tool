import pytest

from dev_run import parse_args, should_watch_file


def test_parse_args_defaults():
    args = parse_args([])

    assert args.debounce_ms == 300
    assert args.no_restart is False
    assert args.restart_only is False
    assert "*.py" in args.pattern_list
    assert "*.qss" in args.pattern_list


def test_parse_args_custom_values():
    args = parse_args(
        [
            "--path",
            "/tmp/project",
            "--patterns",
            "*.py,*.qss",
            "--debounce-ms",
            "450",
            "--restart-only",
        ]
    )

    assert args.path == "/tmp/project"
    assert args.pattern_list == ["*.py", "*.qss"]
    assert args.debounce_ms == 450
    assert args.restart_only is True


def test_parse_args_rejects_incompatible_flags():
    with pytest.raises(SystemExit):
        parse_args(["--restart-only", "--no-restart"])


def test_should_watch_file_filters_patterns_and_excluded_dirs(tmp_path):
    root = tmp_path
    included = root / "ui" / "tabs" / "map_tab.py"
    excluded = root / ".git" / "hooks" / "post-commit.py"
    ignored_ext = root / "README.md"

    assert should_watch_file(included, root, ["*.py", "*.qss"]) is True
    assert should_watch_file(excluded, root, ["*.py", "*.qss"]) is False
    assert should_watch_file(ignored_ext, root, ["*.py", "*.qss"]) is False
