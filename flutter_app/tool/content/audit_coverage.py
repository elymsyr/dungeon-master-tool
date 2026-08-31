#!/usr/bin/env python3
"""Kaynak metnin blueprint'e ne kadar aktarildigini olcer.

    pdftotext -enc UTF-8 adventure.pdf source.txt
    python audit_coverage.py source.txt ../../assets/worlds/<dir>

Blueprint'teki tum string alanlari tek havuza toplar, kaynagin her cumlesini
6-kelimelik shingle ortusmesiyle arar. Esigin altinda kalan cumleler =
aktarilmamis (ya da ozetlenmis) metin. `--check` sema/ref dogrular; bu betik
icerigin gercekten geldigini dogrular -- ikisi farkli sorular.
"""
import io, json, os, re, sys

N = 6                      # shingle uzunlugu
MIN_WORDS = 8              # daha kisa cumleler gurultu, atlanir
THRESHOLD = 0.5            # shingle'larinin yarisi bulunmayan cumle = eksik
PASS = 95.0                # bu kapsamin altinda non-zero cikis

_mention = re.compile(r'@?\[([^\]]+)\]\(entity:[^)]+\)')
_word = re.compile(r'[^a-z0-9]+')


def norm(s):
    return _word.sub(' ', _mention.sub(r'\1', s).lower()).split()


def shingles(words):
    return {tuple(words[i:i + N]) for i in range(len(words) - N + 1)}


def strings(node, out):
    if isinstance(node, str):
        out.append(node)
    elif isinstance(node, dict):
        for v in node.values():
            strings(v, out)
    elif isinstance(node, list):
        for v in node:
            strings(v, out)


def main(src, world_dir, threshold=THRESHOLD):
    blob = []
    for name in ('world-blueprint.json', 'blueprint.json'):
        path = os.path.join(world_dir, name)
        if os.path.exists(path):
            strings(json.load(io.open(path, encoding='utf-8')), blob)
    have = shingles(norm(' \n '.join(blob)))

    text = io.open(src, encoding='utf-8').read()
    text = re.sub(r'-\n(?=\w)', '', text)                     # satir sonu tirelemesi
    sentences = re.split(r'(?<=[.!?:])\s+|\n{2,}', text)

    checked = missing = 0
    for s in sentences:
        w = norm(s)
        if len(w) < MIN_WORDS:
            continue
        checked += 1
        sh = shingles(w)
        hit = len(sh & have) / len(sh)
        if hit < threshold:
            missing += 1
            print('%3d%%  %s' % (hit * 100, ' '.join(s.split())[:150]))

    pct = 100.0 * (checked - missing) / max(checked, 1)
    print('\n%d cumle kontrol edildi, %d tanesi esigin altinda (%.1f%% kapsam)'
          % (checked, missing, pct))
    return 0 if pct >= PASS else 1


if __name__ == '__main__':
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    thr = float(sys.argv[3]) if len(sys.argv) > 3 else THRESHOLD
    sys.exit(main(sys.argv[1], sys.argv[2], thr))
