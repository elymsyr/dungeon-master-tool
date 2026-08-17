#!/usr/bin/env python3
"""Bulgu defterinin denetçisi — `docs/pack_conformance_findings.md` (Stage F2).

F2'nin çıkış şartı ("her kayıt bir checklist maddesi, etkilenen varlık sayısı,
tekrar çalıştırılabilir kanıt, önerilen cause code ve seçenekler taşır")
yirmi oturuma yayılmış bir defterde elle korunamaz. Bu araç onu çalıştırılabilir
hâle getirir:

    python3 tool/check_findings.py            # defteri denetle
    python3 tool/check_findings.py --selftest # denetçi hâlâ hata yakalıyor mu

`## Bulgular` başlığından **önceki** şablon bölümü de denetlenir (format canlı
kalsın diye), ama `F-kuru-*` kimlikli kuru çalışma özet sayaçlara katılmaz.
"""

import argparse
import os
import re
import sys

DOC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'docs',
                   'pack_conformance_findings.md')

ITEMS = ([f'A{i}' for i in range(1, 6)] + [f'B{i}' for i in range(1, 6)] +
         [f'C{i}' for i in range(1, 9)] + [f'D{i}' for i in range(1, 4)] +
         [f'E{i}' for i in range(1, 4)] + [f'F{i}' for i in range(1, 5)] +
         [f'G{i}' for i in range(1, 4)])
PACKS = ['a5e-gpg', 'a5e-ddg', 'open5e', 'tdcs', 'toh', 'a5e-ag', 'kp', 'wz',
         'deepmx', 'spells-that-dont-suck', 'deepm', 'vom', 'ccdx', 'bfrd',
         'tob2', 'tob', 'tob3', 'a5e-mm', 'tob-2023']
SCOPES = ['pass0', 'builtin'] + PACKS
CODES = set('SLMDPNA') | {'—'}
STATUS = ['🔎', '❓', '🛠', '✅', '⚪', '❌']
ROWS = ['Kapsam', 'Checklist', 'Kategori / etki', 'Cause code', 'Durum']

ENTRY = re.compile(r'^### (F-[a-z0-9-]+-\d\d) — (.+)$', re.M)


def cells(line):
    return [c.strip() for c in line.strip().strip('|').split('|')]


def check_entry(eid, body, err):
    """Bir bulgu kaydının zorunlu alanları — F2 çıkış şartının kendisi."""
    scope = eid[2:-3]
    if scope not in SCOPES + ['kuru']:
        err(f'{eid}: kapsam "{scope}" tanınmıyor')
    tbl = {c[0]: c[1] for line in body.splitlines()
           if line.startswith('|') and len((c := cells(line))) == 2}
    # başlıkta açıklama olabiliyor ("Cause code (öneri)") — ön ekle eşle
    tbl = {r: v for k, v in tbl.items() for r in ROWS if k.strip('* ').startswith(r)}
    for r in ROWS:
        if r not in tbl:
            err(f'{eid}: "{r}" satırı yok')
    if 'Checklist' in tbl:
        found = [i for i in ITEMS if re.search(rf'\b{i}\b', tbl['Checklist'])]
        if len(found) != 1:
            err(f'{eid}: tam bir checklist maddesi gerekli, bulunan {found or "yok"}')
    if 'Kategori / etki' in tbl and not re.search(r'\d', tbl['Kategori / etki']):
        err(f'{eid}: etkilenen varlık sayısı yok')
    if 'Cause code' in tbl and not (set(re.findall(r'`([A-Z])`', tbl['Cause code'])) | (
            {'—'} if '—' in tbl['Cause code'] else set())) & CODES:
        err(f'{eid}: geçerli cause code yok ({sorted(CODES)})')
    if 'Durum' in tbl and not any(s in tbl['Durum'] for s in STATUS):
        err(f'{eid}: durum işareti sözlükte yok')
    if '```' not in body:
        err(f'{eid}: kanıt bloğu yok')
    for h in ('**Seçenekler.**', '**Karar.**'):
        if h not in body:
            err(f'{eid}: {h} yok')


def counters(text, entries, err):
    """Üç özet tablo gerçek kayıtlarla aynı şeyi söylüyor mu.

    Yalnızca "Özet sayaçlar" bölümü okunur — kayıtların kendi dağılım tabloları
    (yayılan bulgu kuralı) sayaç değildir, toplama katılmaz.
    """
    if '## Özet sayaçlar' not in text:
        return err('"## Özet sayaçlar" bölümü yok')
    text = text.split('## Özet sayaçlar', 1)[1].split('\n---', 1)[0]
    tallies = {'durum': {}, 'madde': {}, 'kapsam': {}}
    for line in text.splitlines():
        if not line.startswith('|'):
            continue
        c = cells(line)
        for i in range(len(c) - 1):
            if c[i + 1].isdigit():
                if c[i] in ITEMS:
                    tallies['madde'][c[i]] = int(c[i + 1])
                elif c[i].strip('`').replace('open5e-', '') in SCOPES:
                    tallies['kapsam'][c[i].strip('`').replace('open5e-', '')] = int(c[i + 1])
        if all(x.isdigit() or x.startswith('**') for x in c) and len(c) == 7:
            tallies['durum'] = dict(zip(STATUS, [int(x.strip('*')) for x in c]))
    real = len(entries)
    for name, t in tallies.items():
        if sum(t.values()) != real:
            err(f'özet sayaç "{name}" toplamı {sum(t.values())}, gerçek kayıt {real}')
    for k in ('madde', 'kapsam'):
        if not tallies[k]:
            err(f'özet tablo "{k}" okunamadı — tablo şekli değişmiş')


def run(path):
    text = open(path, encoding='utf-8').read()
    errs = []
    err = errs.append
    hits = list(ENTRY.finditer(text))
    for i, m in enumerate(hits):
        end = hits[i + 1].start() if i + 1 < len(hits) else len(text)
        check_entry(m.group(1), text[m.end():end], err)
    body = text.split('## Bulgular', 1)
    if len(body) != 2:
        err('"## Bulgular" başlığı yok')
    counted = [m for m in hits if not m.group(1).startswith('F-kuru-')
               and m.start() > (len(text) - len(body[-1]))]
    counters(text, counted, err)
    return errs, hits, counted


BAD = '''### F-toh-01 — bozuk kayıt
| | |
|---|---|
| **Kapsam** | `open5e-toh` |
| **Durum** | 🔎 açık |

**Bulgu.** kanıtsız.
'''


def selftest():
    errs, *_ = run(DOC)
    assert not errs, errs
    bad = []
    check_entry('F-toh-01', BAD.split('\n', 1)[1], bad.append)
    for want in ('Checklist', 'Kategori / etki', 'Cause code', 'kanıt', 'Seçenekler'):
        assert any(want in e for e in bad), f'denetçi "{want}" eksikliğini yakalamadı: {bad}'
    print(f'selftest: ok (defter temiz, bozuk kayıtta {len(bad)} hata yakalandı)')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--selftest', action='store_true')
    a = ap.parse_args()
    if a.selftest:
        selftest()
    else:
        errs, hits, counted = run(DOC)
        for e in errs:
            print('HATA:', e)
        print(f'{len(hits)} kayıt okundu, {len(counted)} tanesi sayaca giriyor — '
              f'{"temiz" if not errs else str(len(errs)) + " hata"}')
        sys.exit(1 if errs else 0)
