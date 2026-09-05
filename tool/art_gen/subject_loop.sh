#!/usr/bin/env bash
# subject_gen'i bitene kadar döngüde çalıştırır. Ardışık hata yüzünden kendini
# durdurursa (exit 1) ya da geride kalan entity varsa 1 saat uyur, tekrar dener.
# Asla kendiliğinden çıkmaz — yalnızca üretilecek entity kalmadığında biter.
cd "$(dirname "$0")" || exit 1
SLEEP=${SLEEP:-3600}
while :; do
    python3 -u subject_gen.py --workers "${WORKERS:-6}" --retries 2 --max-streak "${STREAK:-20}"
    rc=$?
    left=$(python3 - <<'PY'
import json, sys
from pathlib import Path
sys.path.insert(0, ".")
from subject_gen import load_packs
rows = load_packs([Path("../../flutter_app/assets/open5e_packs"), Path("packs")])
cache = json.loads(Path("subject_cache.json").read_text())
print(sum(1 for u in rows if u not in cache))
PY
)
    echo "=== tur bitti (exit=$rc, kalan=$left) $(date '+%F %T')"
    [ "$left" = "0" ] && { echo "=== hepsi tamam, çıkılıyor"; break; }
    echo "=== $SLEEP sn uyuyor, sonra devam"
    sleep "$SLEEP"
done
