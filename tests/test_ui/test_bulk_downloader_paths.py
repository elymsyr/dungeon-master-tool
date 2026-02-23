import json

from ui.dialogs import bulk_downloader as bulk_mod


class _DummyResponse:
    def __init__(self, status_code, payload):
        self.status_code = status_code
        self._payload = payload

    def json(self):
        return self._payload


class _DummySession:
    def get(self, url, timeout=0):
        if url.endswith("/monsters"):
            return _DummyResponse(200, {"results": [{"index": "aboleth", "name": "Aboleth"}]})
        if url.endswith("/monsters/aboleth"):
            return _DummyResponse(200, {"index": "aboleth", "name": "Aboleth"})
        return _DummyResponse(404, {})


def test_download_worker_writes_to_source_scoped_library(monkeypatch, tmp_path):
    cache_dir = tmp_path / "cache"
    library_dir = cache_dir / "library"
    source_dir = library_dir / "dnd5e"

    monkeypatch.setattr(bulk_mod, "CACHE_DIR", str(cache_dir))
    monkeypatch.setattr(bulk_mod, "LIBRARY_DIR", str(library_dir))
    monkeypatch.setattr(bulk_mod, "LIBRARY_SOURCE_DIR", str(source_dir))
    monkeypatch.setattr(bulk_mod, "API_BASE_URL", "https://example.test/api")
    monkeypatch.setattr(bulk_mod, "probe_write_access", lambda _: True)
    monkeypatch.setattr(bulk_mod.requests, "Session", lambda: _DummySession())
    monkeypatch.setattr(bulk_mod.time, "sleep", lambda *_args, **_kwargs: None)

    worker = bulk_mod.DownloadWorker()
    worker.categories = {"monsters": "Monsters"}
    worker.run()

    expected_file = source_dir / "monsters" / "aboleth.json"
    assert expected_file.exists()
    payload = json.loads(expected_file.read_text(encoding="utf-8"))
    assert payload["index"] == "aboleth"
