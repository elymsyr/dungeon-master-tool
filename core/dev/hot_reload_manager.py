import importlib
import traceback
from pathlib import Path
import sys
from typing import Dict, Iterable, List, Set

from config import load_theme


class HotReloadManager:
    """In-process development hot reload coordinator."""

    WATCHED_EXTENSIONS = {".py", ".ui", ".qss", ".json", ".yaml", ".yml"}
    STABLE_MODULES = {
        "__main__",
        "__mp_main__",
        "main",
        "core.dev.hot_reload_manager",
        "core.dev.ipc_bridge",
    }
    STABLE_PREFIXES = ("core.dev.",)

    def __init__(self, window, project_root: Path | None = None):
        self.window = window
        self.project_root = (
            project_root.resolve() if project_root else Path(__file__).resolve().parents[2]
        )

    @staticmethod
    def module_name_from_path(relative_path: str) -> str:
        rel = Path(relative_path)
        if rel.suffix != ".py":
            return ""

        module_path = rel.with_suffix("")
        parts = list(module_path.parts)
        if not parts:
            return ""

        if parts[-1] == "__init__":
            parts = parts[:-1]

        return ".".join(parts)

    @classmethod
    def classify_paths(cls, changed_paths: Iterable[str]) -> Dict[str, List[str]]:
        classified = {
            "python": [],
            "qss": [],
            "ui": [],
            "data": [],
            "locales": [],
        }

        for changed in changed_paths:
            norm = Path(changed).as_posix()
            suffix = Path(norm).suffix.lower()
            if suffix not in cls.WATCHED_EXTENSIONS:
                continue

            if suffix == ".py":
                classified["python"].append(norm)
            elif suffix == ".qss":
                classified["qss"].append(norm)
            elif suffix == ".ui":
                classified["ui"].append(norm)
            elif suffix in {".json", ".yaml", ".yml"}:
                classified["data"].append(norm)
                if norm.startswith("locales/"):
                    classified["locales"].append(norm)

        for key in classified:
            classified[key] = sorted(set(classified[key]))

        return classified

    def _normalize_changed_paths(self, changed_paths: Iterable[str]) -> List[str]:
        normalized = []
        for changed in changed_paths:
            candidate = Path(changed)
            if not candidate.is_absolute():
                candidate = (self.project_root / candidate)
            resolved = candidate.resolve()

            try:
                rel = resolved.relative_to(self.project_root).as_posix()
            except ValueError:
                rel = resolved.as_posix()
            normalized.append(rel)

        return sorted(set(normalized))

    def _resolve_changed_modules(self, changed_py_paths: Iterable[str]) -> List[str]:
        modules = {
            self.module_name_from_path(path)
            for path in changed_py_paths
            if self.module_name_from_path(path)
        }
        return sorted(modules)

    def _is_stable_module(self, module_name: str) -> bool:
        if module_name in self.STABLE_MODULES:
            return True
        if module_name.startswith("__"):
            # Skip interpreter/runtime pseudo-modules.
            return True
        return any(module_name.startswith(prefix) for prefix in self.STABLE_PREFIXES)

    def _collect_reload_targets(
        self, changed_modules: Iterable[str], changed_py_paths: Iterable[str]
    ) -> List[str]:
        changed_modules = sorted(set(changed_modules))
        changed_files_abs = {
            (self.project_root / rel_path).resolve() for rel_path in changed_py_paths
        }

        targets: Set[str] = set()

        for module_name, module_obj in list(sys.modules.items()):
            if not module_name or self._is_stable_module(module_name):
                continue

            module_file = getattr(module_obj, "__file__", None)
            if not module_file:
                continue

            module_path = Path(module_file).resolve()
            if self.project_root not in module_path.parents and module_path != self.project_root:
                continue

            include_module = module_path in changed_files_abs
            if not include_module:
                for changed in changed_modules:
                    if (
                        module_name == changed
                        or module_name.startswith(f"{changed}.")
                        or changed.startswith(f"{module_name}.")
                    ):
                        include_module = True
                        break

            if include_module:
                targets.add(module_name)

        # If a changed module is not loaded yet, import it first so reload can still run.
        for changed in changed_modules:
            if not changed or self._is_stable_module(changed):
                continue
            if changed not in sys.modules:
                importlib.import_module(changed)
            targets.add(changed)

        return sorted(targets, key=lambda name: (name.count("."), name))

    def _reload_python_modules(self, changed_py_paths: Iterable[str]):
        changed_py_paths = sorted(set(changed_py_paths))
        if not changed_py_paths:
            return

        importlib.invalidate_caches()
        changed_modules = self._resolve_changed_modules(changed_py_paths)
        targets = self._collect_reload_targets(changed_modules, changed_py_paths)

        for module_name in targets:
            if self._is_stable_module(module_name):
                continue

            module_obj = sys.modules.get(module_name)
            if module_obj is None:
                module_obj = importlib.import_module(module_name)

            module_spec = getattr(module_obj, "__spec__", None)
            if module_spec is None or getattr(module_spec, "loader", None) is None:
                print(
                    f"[dev] skipping reload (missing spec/loader): {module_name}"
                )
                continue

            print(f"[dev] reloading module: {module_name}")
            importlib.reload(module_obj)

    def _reload_stylesheet(self):
        theme_name = self.window.data_manager.current_theme
        stylesheet = load_theme(theme_name)
        self.window.current_stylesheet = stylesheet
        self.window.setStyleSheet(stylesheet)

        if hasattr(self.window.player_window, "update_theme"):
            self.window.player_window.update_theme(stylesheet)

    def attempt_hot_reload(self, changed_paths: Iterable[str]) -> Dict[str, object]:
        normalized_paths = self._normalize_changed_paths(changed_paths)
        classified = self.classify_paths(normalized_paths)

        # main.py is the stable shell module in dev mode; restart is required for edits there.
        if any(Path(path).as_posix() == "main.py" for path in classified["python"]):
            return {
                "ok": False,
                "error": "main.py changed; restart required for stable shell updates.",
                "details": "The dev hot-reload shell keeps main.py stable in-process.",
                "last_world": self.window.data_manager.data.get("world_name"),
            }

        needs_rebuild = bool(
            classified["python"]
            or classified["ui"]
            or classified["data"]
        )
        has_qss = bool(classified["qss"])

        if not needs_rebuild and not has_qss:
            return {"ok": True, "details": "No relevant changes.", "last_world": self.window.data_manager.data.get("world_name")}

        print("[dev] attempting hot reload...")

        try:
            if classified["python"]:
                self._reload_python_modules(classified["python"])

            if has_qss:
                self._reload_stylesheet()

            if needs_rebuild:
                print("[dev] rebuilding root widget...")
                self.window.rebuild_root_widget(reload_main_root_module=True)

            if classified["locales"] and hasattr(self.window, "retranslate_ui"):
                self.window.retranslate_ui()

            print("[dev] hot reload successful")
            return {
                "ok": True,
                "details": "Hot reload successful.",
                "last_world": self.window.data_manager.data.get("world_name"),
            }
        except Exception as exc:
            tb_text = traceback.format_exc()
            print(f"[dev] hot reload failed: {exc}")
            return {
                "ok": False,
                "error": str(exc),
                "details": tb_text,
                "last_world": self.window.data_manager.data.get("world_name"),
            }
