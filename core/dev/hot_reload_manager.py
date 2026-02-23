import importlib
from pathlib import Path
import sys
import threading
import time
import traceback
from typing import Dict, Iterable, List, Set

from config import load_theme


class HotReloadManager:
    """In-process development hot reload coordinator."""

    OUTCOME_APPLIED = "APPLIED"
    OUTCOME_NO_OP = "NO_OP"
    OUTCOME_RESTART_REQUIRED = "RESTART_REQUIRED"
    OUTCOME_FAILED = "FAILED"
    OUTCOME_BUSY = "BUSY"

    WATCHED_EXTENSIONS = {".py", ".ui", ".qss", ".json", ".yaml", ".yml"}

    STABLE_MODULES = {
        "__main__",
        "__mp_main__",
        "main",
        "core.dev.hot_reload_manager",
        "core.dev.ipc_bridge",
    }
    STABLE_PREFIXES = ("core.dev.",)

    RESTART_REQUIRED_FILES = {"main.py", "dev_run.py"}
    RESTART_REQUIRED_PREFIXES = ("core/dev/",)

    REQUIRED_WINDOW_ATTRS = (
        "tabs",
        "db_tab",
        "map_tab",
        "session_tab",
        "entity_sidebar",
        "soundpad_panel",
    )

    def __init__(self, window, project_root: Path | None = None):
        self.window = window
        self.project_root = (
            project_root.resolve() if project_root else Path(__file__).resolve().parents[2]
        )
        self._reload_lock = threading.Lock()

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
                candidate = self.project_root / candidate
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

    def _requires_restart(self, changed_py_paths: Iterable[str]) -> bool:
        for path in changed_py_paths:
            norm = Path(path).as_posix()
            if norm in self.RESTART_REQUIRED_FILES:
                return True
            if any(norm.startswith(prefix) for prefix in self.RESTART_REQUIRED_PREFIXES):
                return True
        return False

    def _collect_reload_targets(
        self,
        changed_modules: Iterable[str],
        changed_py_paths: Iterable[str],
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
                print(f"[dev] skipping reload (missing spec/loader): {module_name}")
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

    def _validate_window_health(self):
        if self.window.centralWidget() is None:
            raise RuntimeError("Hot reload health check failed: central widget is missing.")

        for attr in self.REQUIRED_WINDOW_ATTRS:
            if not hasattr(self.window, attr):
                raise RuntimeError(
                    f"Hot reload health check failed: missing window attribute '{attr}'."
                )
            if getattr(self.window, attr) is None:
                raise RuntimeError(
                    f"Hot reload health check failed: window attribute '{attr}' is None."
                )

        tabs = self.window.tabs
        if not hasattr(tabs, "count"):
            raise RuntimeError("Hot reload health check failed: tabs has no count().")
        if tabs.count() < 4:
            raise RuntimeError(
                f"Hot reload health check failed: expected >=4 tabs, got {tabs.count()}."
            )

    def _build_result(
        self,
        *,
        ok: bool,
        status: str,
        changed_paths: List[str],
        started_at: float,
        error: str | None = None,
        details: str = "",
    ) -> Dict[str, object]:
        duration_ms = int((time.monotonic() - started_at) * 1000)
        return {
            "ok": ok,
            "status": status,
            "error": error,
            "details": details,
            "last_world": self.window.data_manager.data.get("world_name"),
            "changed_paths": list(changed_paths),
            "duration_ms": duration_ms,
        }

    def attempt_hot_reload(self, changed_paths: Iterable[str]) -> Dict[str, object]:
        started_at = time.monotonic()
        normalized_paths = self._normalize_changed_paths(changed_paths)

        if not self._reload_lock.acquire(blocking=False):
            return self._build_result(
                ok=False,
                status=self.OUTCOME_BUSY,
                changed_paths=normalized_paths,
                started_at=started_at,
                error="Hot reload already in progress.",
                details="Skipped overlapping reload request.",
            )

        try:
            classified = self.classify_paths(normalized_paths)

            if self._requires_restart(classified["python"]):
                return self._build_result(
                    ok=False,
                    status=self.OUTCOME_RESTART_REQUIRED,
                    changed_paths=normalized_paths,
                    started_at=started_at,
                    error=(
                        "Shell/dev infrastructure changed; restart required "
                        "(main.py, dev_run.py, or core/dev/*)."
                    ),
                    details="The dev hot-reload shell keeps these modules stable in-process.",
                )

            needs_rebuild = bool(
                classified["python"]
                or classified["ui"]
                or classified["data"]
            )
            has_qss = bool(classified["qss"])

            if not needs_rebuild and not has_qss:
                return self._build_result(
                    ok=True,
                    status=self.OUTCOME_NO_OP,
                    changed_paths=normalized_paths,
                    started_at=started_at,
                    details="No relevant changes.",
                )

            print("[dev] attempting hot reload...")

            if classified["python"]:
                self._reload_python_modules(classified["python"])

            if has_qss:
                self._reload_stylesheet()

            if needs_rebuild:
                print("[dev] rebuilding root widget...")
                self.window.rebuild_root_widget(reload_main_root_module=True)
                self._validate_window_health()

            if classified["locales"] and hasattr(self.window, "retranslate_ui"):
                self.window.retranslate_ui()

            print("[dev] hot reload successful")
            return self._build_result(
                ok=True,
                status=self.OUTCOME_APPLIED,
                changed_paths=normalized_paths,
                started_at=started_at,
                details="Hot reload successful.",
            )
        except Exception as exc:
            tb_text = traceback.format_exc()
            print(f"[dev] hot reload failed: {exc}")
            return self._build_result(
                ok=False,
                status=self.OUTCOME_FAILED,
                changed_paths=normalized_paths,
                started_at=started_at,
                error=str(exc),
                details=tb_text,
            )
        finally:
            self._reload_lock.release()
