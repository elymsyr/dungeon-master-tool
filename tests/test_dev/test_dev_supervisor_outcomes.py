from dev_run import (
    DevSupervisor,
    STATUS_APPLIED,
    STATUS_BUSY,
    STATUS_FAILED,
    STATUS_NO_OP,
    STATUS_RESTART_REQUIRED,
    parse_args,
)


def _new_supervisor(extra_args=None):
    args = parse_args(extra_args or [])
    sup = DevSupervisor(args)
    return sup


def test_restart_required_triggers_restart(monkeypatch):
    supervisor = _new_supervisor()
    calls = {"restart": 0}

    monkeypatch.setattr(supervisor, "_ensure_child_for_change", lambda: None)
    monkeypatch.setattr(
        supervisor,
        "_send_hot_reload",
        lambda *_args, **_kwargs: {
            "ok": False,
            "status": STATUS_RESTART_REQUIRED,
            "error": "restart required",
            "details": "",
            "last_world": None,
        },
    )
    monkeypatch.setattr(supervisor, "restart_child", lambda: calls.__setitem__("restart", calls["restart"] + 1))

    supervisor.handle_changes(["main.py"])

    assert calls["restart"] == 1


def test_failed_triggers_restart(monkeypatch):
    supervisor = _new_supervisor()
    calls = {"restart": 0}

    monkeypatch.setattr(supervisor, "_ensure_child_for_change", lambda: None)
    monkeypatch.setattr(
        supervisor,
        "_send_hot_reload",
        lambda *_args, **_kwargs: {
            "ok": False,
            "status": STATUS_FAILED,
            "error": "boom",
            "details": "trace",
            "last_world": None,
        },
    )
    monkeypatch.setattr(supervisor, "restart_child", lambda: calls.__setitem__("restart", calls["restart"] + 1))

    supervisor.handle_changes(["ui/main_root.py"])

    assert calls["restart"] == 1


def test_no_op_and_applied_do_not_restart(monkeypatch):
    supervisor = _new_supervisor()
    calls = {"restart": 0, "idx": 0}
    responses = [
        {"ok": True, "status": STATUS_NO_OP, "error": None, "details": "", "last_world": None},
        {"ok": True, "status": STATUS_APPLIED, "error": None, "details": "", "last_world": None},
    ]

    monkeypatch.setattr(supervisor, "_ensure_child_for_change", lambda: None)

    def _send(*_args, **_kwargs):
        resp = responses[calls["idx"]]
        calls["idx"] += 1
        return resp

    monkeypatch.setattr(supervisor, "_send_hot_reload", _send)
    monkeypatch.setattr(supervisor, "restart_child", lambda: calls.__setitem__("restart", calls["restart"] + 1))

    supervisor.handle_changes(["ui/main_root.py"])
    supervisor.handle_changes(["ui/main_root.py"])

    assert calls["restart"] == 0


def test_busy_retries_once_with_coalesced_pending_set(monkeypatch):
    supervisor = _new_supervisor()
    sent_batches = []
    calls = {"restart": 0, "send": 0}

    monkeypatch.setattr(supervisor, "_ensure_child_for_change", lambda: None)

    def _send(batch, timeout_sec):
        sent_batches.append((list(batch), timeout_sec))
        calls["send"] += 1
        if calls["send"] == 1:
            supervisor._pending_changes.add("ui/second.py")
            return {
                "ok": False,
                "status": STATUS_BUSY,
                "error": "busy",
                "details": "",
                "last_world": None,
            }
        return {
            "ok": True,
            "status": STATUS_APPLIED,
            "error": None,
            "details": "",
            "last_world": None,
        }

    monkeypatch.setattr(supervisor, "_send_hot_reload", _send)
    monkeypatch.setattr(supervisor, "restart_child", lambda: calls.__setitem__("restart", calls["restart"] + 1))

    supervisor.handle_changes(["ui/first.py"])

    assert calls["send"] == 2
    assert calls["restart"] == 0
    assert sorted(sent_batches[0][0]) == ["ui/first.py"]
    assert sorted(sent_batches[1][0]) == ["ui/first.py", "ui/second.py"]


def test_adaptive_timeout_small_and_large_batches():
    supervisor = _new_supervisor()

    assert supervisor._compute_hot_reload_timeout(["a.py"]) == 10.0
    assert supervisor._compute_hot_reload_timeout([f"f{i}.py" for i in range(30)]) == 45.0
