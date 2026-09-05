#!/usr/bin/env python3
"""5eTools fluff metinlerinden canon lore çeker (subject_gen için).

Neden: mimo-v2.5 küçük model, canon görünüşü hafızadan hatırlaması şans işi
(Goliath'a boynuz + kırmızı göz uydurdu). Elimizde 5eTools'un fluff dosyaları
var; entity adı eşleşiyorsa LLM'e "hatırla" yerine "önündeki metni özetle"
dedirtiyoruz.

Not: her entity'nin fluff'ı yok (ör. Goliath'ın VGM fluff'ında fiziksel tarif
geçmiyor). Eşleşme yoksa boş döner, subject_gen eski yoluna düşer.
"""
from __future__ import annotations
import json, re
from functools import lru_cache
from pathlib import Path

DEFAULT_DATA = Path.home() / "GitHub/5e-Tools/data"

# fluff dosyaları -> içindeki liste anahtarı sabit değil, hepsini tarıyoruz.
GLOBS = ("fluff-*.json", "bestiary/fluff-bestiary-*.json")

_TAG = re.compile(r"\{@\w+ ([^}|]+)(\|[^}]*)?\}")   # {@creature ogre|MM} -> ogre
_WS = re.compile(r"\s+")


def _flatten(node, out: list[str]) -> None:
    if isinstance(node, str):
        out.append(node)
    elif isinstance(node, list):
        for x in node:
            _flatten(x, out)
    elif isinstance(node, dict):
        for k in ("entries", "items", "entry"):
            if k in node:
                _flatten(node[k], out)


@lru_cache(maxsize=1)
def _index(data_dir: str) -> dict[str, str]:
    """lowercase name -> düz lore metni."""
    root = Path(data_dir)
    idx: dict[str, str] = {}
    for glob in GLOBS:
        for f in sorted(root.glob(glob)):
            try:
                data = json.loads(f.read_text())
            except Exception:
                continue
            for value in data.values():
                if not isinstance(value, list):
                    continue
                for row in value:
                    if not isinstance(row, dict) or not row.get("name"):
                        continue
                    parts: list[str] = []
                    _flatten(row.get("entries") or [], parts)
                    text = _WS.sub(" ", _TAG.sub(r"\1", " ".join(parts))).strip()
                    if len(text) < 40:
                        continue
                    key = row["name"].strip().lower()
                    # aynı isimde birden çok kaynak varsa en uzun metni tut
                    if len(text) > len(idx.get(key, "")):
                        idx[key] = text
    return idx


def lore_for(name: str, data_dir: Path | str = DEFAULT_DATA,
             limit: int = 1500) -> str:
    """Entity adı için canon lore metni; yoksa boş string."""
    if not Path(data_dir).is_dir():
        return ""
    idx = _index(str(data_dir))
    key = (name or "").strip().lower()
    text = idx.get(key) or idx.get(key.rstrip("s")) or ""
    return text[:limit]


def _demo() -> None:
    assert lore_for("Goliath").startswith("At the highest mountain peaks")
    assert "aboleths" in lore_for("Aboleth").lower()
    assert lore_for("Nonexistent Thing XYZ") == ""
    print("lore.py ok:", len(_index(str(DEFAULT_DATA))), "entry")


if __name__ == "__main__":
    _demo()
