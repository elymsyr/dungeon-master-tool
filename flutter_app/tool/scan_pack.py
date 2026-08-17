#!/usr/bin/env python3
"""Stage F paket tarayıcısı — `docs/pack_conformance_plan.md` Adım 2–5.

Tek bir `*.pkg.json`'ı okunabilir bütçe içinde açar. Üç mod:

    python3 tool/scan_pack.py toh                 # kategori haritası + metadata
    python3 tool/scan_pack.py toh --cat spell     # alan doluluğu + örneklem
    python3 tool/scan_pack.py --selfcheck         # aracın kendi kontrolü

Paket dosyasının şekli (elle okumadan önce bilinmesi gereken): üst seviye
`{package_name, metadata, entities}` ve **`entities` bir liste değil, id → varlık
sözlüğü**; varlığın alanları `fields` değil **`attributes`** altında; kategori
anahtarı `category` değil **`type`**.

Örneklem yazdırırken skaler diziler (uuid listeleri) tek satıra toplanır — bir
canavar indent=1 JSON ile ~236 satır, burada ~40. Bütçe (paket başına ~600 satır)
o sayede 5 varlıklık örneklemle bağdaşıyor.
"""

import argparse
import collections
import json
import os
import sys

PACKS = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'open5e_packs')
SKIP = ('images', 'pdfs', 'image_path', 'location_id', 'dm_notes')
BUDGET = 600  # satır / paket (plan §4)


def load(slug):
    path = slug if slug.endswith('.json') else os.path.join(PACKS, f'open5e-{slug}.pkg.json')
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def rows(pack, cat):
    return [e for e in pack['entities'].values() if e.get('type') == cat]


def show(value, indent):
    """Skaler dizileri tek satırda tutan, sözlükleri açan yazıcı."""
    pad = ' ' * indent
    for k, v in value.items():
        if k in SKIP:
            continue
        if isinstance(v, dict) and v:
            print(f'{pad}{k}:')
            show(v, indent + 2)
            continue
        s = json.dumps(v, ensure_ascii=False)
        if len(s) > 400 and isinstance(v, list):
            print(f'{pad}{k}: [{len(v)} öğe]')
            for item in v[:3]:
                print(f'{pad}  {json.dumps(item, ensure_ascii=False)[:400]}')
            if len(v) > 3:
                print(f'{pad}  … +{len(v) - 3}')
        else:
            print(f'{pad}{k}: {s[:400]}{" …" if len(s) > 400 else ""}')


def overview(pack):
    ents = pack['entities']
    counts = collections.Counter(e.get('type') for e in ents.values())
    print(f"{pack['package_name']} — {len(ents)} varlık, {len(counts)} kategori")
    for k, v in counts.most_common():
        print(f'  {k:22} {v}')
    print(f"\n--only {','.join(sorted(counts))}   # audit_packs/gate_packs bunu ister (plan Adım 1)")
    print('\nmetadata:')
    show(pack['metadata'], 2)


def category(pack, cat, picks):
    rs = rows(pack, cat)
    if not rs:
        sys.exit(f'{cat}: bu pakette yok')
    fill = collections.Counter()
    for e in rs:
        for k, v in (e.get('attributes') or {}).items():
            if v not in (None, '', [], {}):
                fill[k] += 1
    print(f'{cat} — {len(rs)} varlık, {len(fill)} dolu alan')
    for k, v in sorted(fill.items(), key=lambda x: -x[1]):
        print(f'  {k:34} {v:5}/{len(rs)}')
    print('  (yukarıda hiç görünmeyen şema alanı = 0/n → checklist C8 adayı)')

    idx = sorted({0, len(rs) - 1, len(rs) // 4, len(rs) // 2, 3 * len(rs) // 4})[:picks]
    for i in idx:
        print(f'\n--- #{i} {rs[i].get("name")} ' + '-' * 40)
        show(rs[i], 2)


def selfcheck():
    p = load('tdcs')
    assert p['package_name'], 'package_name yok'
    assert isinstance(p['entities'], dict), 'entities sözlük değil — dosya şekli değişmiş'
    assert len(p['entities']) == 35, len(p['entities'])
    c = collections.Counter(e['type'] for e in p['entities'].values())
    assert c['trait'] == 11 and c['monster'] == 4, c
    assert all('attributes' in e for e in p['entities'].values()), 'attributes yok'
    v = load('vom')
    assert {json.dumps(e['attributes'].get('cost_gp')) for e in v['entities'].values()} == {'null'}, \
        'vom cost_gp artık null değil — plan Dalga 3 notu ve checklist C5 yeniden ölçülmeli'
    print('selfcheck: ok (tdcs 35/6, vom cost_gp null)')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('pack', nargs='?', help='paket slug (toh) veya .pkg.json yolu')
    ap.add_argument('--cat', help='kategori — alan doluluğu + örneklem')
    ap.add_argument('--picks', type=int, default=5, help='örneklem büyüklüğü (varsayılan 5)')
    ap.add_argument('--selfcheck', action='store_true')
    a = ap.parse_args()
    if a.selfcheck:
        selfcheck()
    elif not a.pack:
        ap.error('paket adı gerekli (veya --selfcheck)')
    elif a.cat:
        category(load(a.pack), a.cat, a.picks)
    else:
        overview(load(a.pack))
