#!/usr/bin/env python3
import argparse
import fnmatch
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import time
from multiprocessing.connection import Listener
from typing import Iterable, List, Optional, Sequence, Tuple

try:
    from watchfiles import watch
except ImportError:  # pragma: no cover - validated via runtime message
    watch = None


STATUS_APPLIED = "APPLIED"
STATUS_NO_OP = "NO_OP"
STATUS_RESTART_REQUIRED = "RESTART_REQUIRED"
STATUS_FAILED = "FAILED"
STATUS_BUSY = "BUSY"

DEFAULT_PATTERNS = "*.py,*.ui,*.qss,*.json,*.yaml,*.yml"
DEFAULT_DEBOUNCE_MS = 300
DEFAULT_EXCLUDED_DIRS = {
    ".git",
    "__pycache__",
    ".venv",
    "venv",
    "dist",
    "build",
    ".mypy_cache",
    ".pytest_cache",
    ".ruff_cache",
    "node_modules",
    "cache",
    "worlds",
}


def parse_patterns(raw: str) -> List[str]:
    return [part.strip() for part in raw.split(",") if part.strip()]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Development hot reload runner (in-process first, restart fallback)."
    )
    parser.add_argument(
        "--path",
        default=str(Path(__file__).resolve().parent),
        help="Root path to watch and run the app from (default: repo root).",
    )
    parser.add_argument(
        "--patterns",
        default=DEFAULT_PATTERNS,
        help="Comma-separated file patterns to watch.",
    )
    parser.add_argument(
        "--debounce-ms",
        type=int,
        default=DEFAULT_DEBOUNCE_MS,
        help="Debounce window in milliseconds.",
    )
    parser.add_argument(
        "--no-restart",
        action="store_true",
        help="Disable fallback restart when hot reload fails.",
    )
    parser.add_argument(
        "--restart-only",
        action="store_true",
        help="Disable in-process hot reload and always restart on file change.",
    )
    return parser


def parse_args(argv: Optional[Sequence[str]] = None):
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.restart_only and args.no_restart:
        parser.error("--restart-only cannot be used with --no-restart")
    if args.debounce_ms < 0:
        parser.error("--debounce-ms must be >= 0")
    args.pattern_list = parse_patterns(args.patterns)
    return args


def _relative_posix(path: Path, root: Path) -> Optional[str]:
    try:
        rel = path.resolve().relative_to(root.resolve())
    except Exception:
        return None
    return rel.as_posix()


def should_watch_file(
    path: str | Path,
    root: str | Path,
    patterns: Iterable[str],
    excluded_dirs: Iterable[str] = DEFAULT_EXCLUDED_DIRS,
) -> bool:
    root_path = Path(root).resolve()
    candidate = Path(path)
    rel = _relative_posix(candidate, root_path)
    if rel is None:
        return False

    rel_path = Path(rel)
    excluded = set(excluded_dirs)
    if any(part in excluded for part in rel_path.parts):
        return False

    name = rel_path.name
    rel_posix = rel_path.as_posix()
    return any(
        fnmatch.fnmatch(name, pattern) or fnmatch.fnmatch(rel_posix, pattern)
        for pattern in patterns
    )


class DevSupervisor:
    def __init__(self, args):
        self.args = args
        self.root = Path(args.path).resolve()
        self.patterns = list(args.pattern_list)
        self.last_world = os.getenv("DM_DEV_LAST_WORLD") or ""

        self.listener = None
        self.child_proc = None
        self.child_conn = None
        self.auth_token = ""
        self._pending_changes: set[str] = set()

    def _open_listener(self):
        self.auth_token = secrets.token_hex(16)
        self.listener = Listener(("127.0.0.1", 0), authkey=self.auth_token.encode("utf-8"))

        try:
            self.listener._listener._socket.settimeout(0.2)
        except Exception:
            pass

    def _build_child_env(self):
        env = os.environ.copy()
        env["DM_DEV_CHILD"] = "1"
        env["DM_DEV_IPC_HOST"] = str(self.listener.address[0])
        env["DM_DEV_IPC_PORT"] = str(self.listener.address[1])
        env["DM_DEV_IPC_AUTH"] = self.auth_token

        if self.last_world:
            env["DM_DEV_LAST_WORLD"] = self.last_world
        else:
            env.pop("DM_DEV_LAST_WORLD", None)

        return env

    def _accept_child_connection(self, timeout_sec: float = 10.0):
        deadline = time.time() + timeout_sec
        while time.time() < deadline:
            if self.child_proc and self.child_proc.poll() is not None:
                return None
            try:
                return self.listener.accept()
            except socket.timeout:
                continue
            except OSError:
                continue
        return None

    def _close_child_connection(self):
        if self.child_conn is not None:
            try:
                self.child_conn.close()
            except Exception:
                pass
            self.child_conn = None

    def _terminate_child(self):
        if self.child_proc is None:
            return
        if self.child_proc.poll() is not None:
            return

        self.child_proc.terminate()
        try:
            self.child_proc.wait(timeout=3.0)
        except subprocess.TimeoutExpired:
            self.child_proc.kill()
            try:
                self.child_proc.wait(timeout=2.0)
            except subprocess.TimeoutExpired:
                pass

    def start_child(self):
        self._close_child_connection()

        cmd = [sys.executable, str(self.root / "main.py")]
        self.child_proc = subprocess.Popen(
            cmd,
            cwd=str(self.root),
            env=self._build_child_env(),
        )

        self.child_conn = self._accept_child_connection(timeout_sec=10.0)
        if self.child_conn is None:
            if self.child_proc.poll() is not None:
                print(
                    "[dev] application exited before dev bridge connection; "
                    "waiting for next change"
                )
            else:
                print(
                    "[dev] dev bridge connection timed out; hot reload disabled "
                    "until next restart"
                )
        else:
            print("[dev] dev bridge connected")

    def restart_child(self):
        print("[dev] restarting application...")
        self._close_child_connection()
        self._terminate_child()
        time.sleep(0.25)
        self.start_child()

        time.sleep(0.5)
        if self.child_proc and self.child_proc.poll() is not None:
            print("[dev] restart failed; waiting for next change")

    def _compute_hot_reload_timeout(self, changed_paths: List[str]) -> float:
        return min(45.0, 8.0 + 2.0 * len(changed_paths))

    def _status_from_response(self, response: dict) -> str:
        status = response.get("status")
        if status in {
            STATUS_APPLIED,
            STATUS_NO_OP,
            STATUS_RESTART_REQUIRED,
            STATUS_FAILED,
            STATUS_BUSY,
        }:
            return status

        if response.get("ok"):
            return STATUS_APPLIED

        err = str(response.get("error", "")).lower()
        if "restart required" in err:
            return STATUS_RESTART_REQUIRED
        if "busy" in err:
            return STATUS_BUSY
        return STATUS_FAILED

    def _send_hot_reload(self, changed_paths: List[str], timeout_sec: float):
        if self.child_conn is None:
            return {
                "ok": False,
                "status": STATUS_FAILED,
                "error": "Dev bridge is not connected.",
                "details": "",
                "last_world": None,
                "changed_paths": list(changed_paths),
                "duration_ms": 0,
            }

        try:
            self.child_conn.send({"cmd": "hot_reload", "changed_paths": changed_paths})

            deadline = time.time() + timeout_sec
            while time.time() < deadline:
                if self.child_proc and self.child_proc.poll() is not None:
                    return {
                        "ok": False,
                        "status": STATUS_FAILED,
                        "error": "Application process exited while waiting for reload response.",
                        "details": "",
                        "last_world": None,
                        "changed_paths": list(changed_paths),
                        "duration_ms": 0,
                    }
                if self.child_conn.poll(0.2):
                    response = self.child_conn.recv()
                    if isinstance(response, dict):
                        return response
                    return {
                        "ok": False,
                        "status": STATUS_FAILED,
                        "error": "Invalid hot reload response payload.",
                        "details": repr(response),
                        "last_world": None,
                        "changed_paths": list(changed_paths),
                        "duration_ms": 0,
                    }

            return {
                "ok": False,
                "status": STATUS_FAILED,
                "error": "Timed out waiting for hot reload response.",
                "details": "",
                "last_world": None,
                "changed_paths": list(changed_paths),
                "duration_ms": 0,
            }
        except Exception as exc:
            return {
                "ok": False,
                "status": STATUS_FAILED,
                "error": str(exc),
                "details": "Hot reload IPC send/recv failed.",
                "last_world": None,
                "changed_paths": list(changed_paths),
                "duration_ms": 0,
            }

    def _ensure_child_for_change(self):
        if self.child_proc is None or self.child_proc.poll() is not None:
            print("[dev] application is not running; starting process...")
            self.start_child()

    def handle_changes(self, changed_paths: List[str]):
        self._pending_changes.update(changed_paths)
        self._ensure_child_for_change()

        if self.args.restart_only:
            self._pending_changes.clear()
            self.restart_child()
            return

        if not self._pending_changes:
            return

        batch = sorted(self._pending_changes)
        self._pending_changes.clear()

        attempt = 0
        while attempt < 2:
            attempt += 1
            timeout_sec = self._compute_hot_reload_timeout(batch)
            print("[dev] attempting hot reload...")
            response = self._send_hot_reload(batch, timeout_sec=timeout_sec)

            if response.get("last_world"):
                self.last_world = response["last_world"]

            status = self._status_from_response(response)

            if status in {STATUS_APPLIED, STATUS_NO_OP}:
                return

            if status == STATUS_BUSY:
                if attempt == 1:
                    print("[dev] hot reload busy; retrying once with coalesced changes...")
                    self._pending_changes.update(batch)
                    time.sleep(0.2)
                    batch = sorted(self._pending_changes)
                    self._pending_changes.clear()
                    continue

                print("[dev] hot reload still busy; deferring changes to next file event.")
                self._pending_changes.update(batch)
                return

            print(f"[dev] hot reload failed: {response.get('error', 'unknown error')}")
            if response.get("details"):
                print(response["details"])

            if self.args.no_restart:
                return

            self.restart_child()
            return

    def _filter_changes(self, raw_changes: Iterable[Tuple[object, str]]) -> List[str]:
        changed = []
        for _, changed_path in raw_changes:
            if should_watch_file(changed_path, self.root, self.patterns):
                rel = _relative_posix(Path(changed_path), self.root)
                if rel:
                    changed.append(rel)

        changed = sorted(set(changed))
        return changed

    def watch_loop(self):
        if watch is None:
            print(
                "[dev] watchfiles is not installed. Run: pip install -r requirements-dev.txt"
            )
            return 1

        self._open_listener()
        self.start_child()

        print("[dev] watching for changes...")

        try:
            for changes in watch(
                str(self.root),
                debounce=self.args.debounce_ms,
                step=50,
                raise_interrupt=False,
            ):
                changed_paths = self._filter_changes(changes)
                if not changed_paths:
                    continue

                for changed in changed_paths:
                    print(f"[dev] change detected: {changed}")

                self.handle_changes(changed_paths)
        except KeyboardInterrupt:
            print("[dev] stopping watcher")
        finally:
            self._close_child_connection()
            self._terminate_child()
            if self.listener is not None:
                try:
                    self.listener.close()
                except Exception:
                    pass

        return 0


def main(argv: Optional[Sequence[str]] = None) -> int:
    from core.log_config import setup_logging

    setup_logging(level="DEBUG", console=True)

    args = parse_args(argv)
    supervisor = DevSupervisor(args)
    return supervisor.watch_loop()


if __name__ == "__main__":
    sys.exit(main())
