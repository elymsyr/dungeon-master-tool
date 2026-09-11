#!/usr/bin/env python3
"""`resource_pool_grants` denetçisi — builtin SRD + open5e paketleri + dünyalar.

Kaynak sorun: bir kart "1 slot" veriyormuş gibi görünüyor ama aslında "uzun
dinlenmede 1 bedava kullanım" sayacı, ya da tersi — satır hiç çizilmiyor.
`CharacterResolver.applyResourcePools` + `ClassResourcesTracker.entries`
ikilisinin kuralları burada birebir taklit edilir:

  * `pool_ref` çözülemezse   → kart satırı **atlanır** (sessiz kayıp)
  * `count_by_level` / `count_formula` / `count` üçünden hiçbiri yoksa
    ya da formül `evalCountFormula`'da tanımlı değilse → `max` null
    → satır yine **atlanır**
  * `recharge` yoksa satır "1/long rest" etiketi olmadan çizilir, kullanıcı
    onu büyü slotu sanır

    python3 tool/scan_resource_pools.py            # tam tarama (bulgu varsa exit 1)
    python3 tool/scan_resource_pools.py --quiet    # sadece hatalar
    python3 tool/scan_resource_pools.py --selftest # denetçi hâlâ yakalıyor mu

Büyü-anahtarlı havuzlar (`granted_spells_at_level[].uses_per_long_rest`) da
listelenir: bunlar slot değil, günlük bedava cast sayacıdır.
"""

import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILTIN = os.path.join(ROOT, 'lib', 'domain', 'entities', 'schema', 'builtin')
FORMULA_SRC = os.path.join(ROOT, 'lib', 'domain', 'services', 'count_formula.dart')
LOOKUPS_SRC = os.path.join(BUILTIN, 'lookups.dart')
ASSET_DIRS = [os.path.join(ROOT, 'assets', 'open5e_packs'),
              os.path.join(ROOT, 'assets', 'worlds')]


# ── kurallar kaynaktan okunur, elle kopyalanmaz ──────────────────────────────

def known_formulas():
    """`evalCountFormula`'nın kabul ettiği token'lar."""
    src = open(FORMULA_SRC, encoding='utf-8').read()
    return {m.lower() for m in re.findall(r"case '([a-z0-9_]+)':", src)}


def builtin_pool_labels():
    """`kResourcePoolLabels` — builtin havuz id'si → sayfadaki etiket.

    Satırlar 2026-09-12'de `_resourcePoolCategory`'nin gövdesinden bu sabite
    taşındı (id anahtar kaldı, etiket veri oldu); parser da oraya bakıyor.
    """
    src = open(LOOKUPS_SRC, encoding='utf-8').read()
    start = src.index('const kResourcePoolLabels')
    body = src[start:src.index('\n};', start)]
    # Etiket ya tek ya çift tırnaklı ("Hunter's Mark (Free Casts)" kesme
    # işareti taşıdığı için çift).
    pairs = re.findall(
        r"'(pool:[a-z0-9_]+)':\s*(?:'([^']*)'|\"([^\"]*)\")", body)
    return {slug: single or double for slug, single, double in pairs}


def builtin_pool_slugs():
    """Builtin'de var olan havuz id'leri."""
    return set(builtin_pool_labels())


# ── satır denetimi (tek yerde; JSON ve Dart aynı kuralı kullanır) ────────────

def check_row(pool_id, has_count, formula, resolvable, formulas):
    """Bir grant satırı için bulgu listesi. Boş liste = temiz."""
    out = []
    if not resolvable:
        out.append(f'DROP pool_ref çözülemiyor ({pool_id})')
    if formula and formula.lower() not in formulas:
        out.append(f'DROP count_formula tanımsız ({formula})')
    elif not has_count and not formula:
        out.append('DROP max yok (count/count_formula/count_by_level hiçbiri)')
    return out


# ── JSON tarafı: paketler ve dünyalar ───────────────────────────────────────

def pack_files():
    for base in ASSET_DIRS:
        for dirpath, _, names in os.walk(base):
            for n in names:
                if n.endswith('.pkg.json') or n.endswith('blueprint.json'):
                    yield os.path.join(dirpath, n)


def entity_index(pack):
    """(kategori-slug, ad) → id  ve  id kümesi."""
    ents = pack.get('entities')
    if isinstance(ents, dict):
        vals = list(ents.values())
        ids = set(ents)
    elif isinstance(ents, list):
        vals = ents
        ids = {e.get('id') for e in vals if isinstance(e, dict)}
    else:
        return {}, set(), []
    by_name = {}
    for e in vals:
        if isinstance(e, dict):
            by_name.setdefault((e.get('type'), e.get('name')), e.get('id'))
    return by_name, ids, vals


def resolve(ref, by_name, ids, builtin_pools):
    """`resolveEntityRef` + builtin havuz listesi."""
    if isinstance(ref, str):
        return ref in ids or ref in builtin_pools
    if isinstance(ref, dict):
        slug = ref.get('_ref') or ref.get('slug') or ref.get('_lookup')
        name = ref.get('name')
        if not isinstance(name, str):
            return False
        if (slug, name) in by_name:
            return True
        stripped = re.sub(r'\s*\([^)]*\)\s*$', '', name).strip()
        if (slug, stripped) in by_name:
            return True
        return name in builtin_pools or stripped in builtin_pools
    return False


def pool_label(ref):
    if isinstance(ref, str):
        return ref
    if isinstance(ref, dict):
        return str(ref.get('name') or ref.get('_lookup') or ref)
    return str(ref)


def walk_attrs(node, path, hits):
    """`resource_pool_grants` / `granted_spells_at_level` taşıyan her düğüm."""
    if isinstance(node, dict):
        if 'resource_pool_grants' in node or 'granted_spells_at_level' in node:
            hits.append((path, node))
        for k, v in node.items():
            walk_attrs(v, path, hits)
    elif isinstance(node, list):
        for v in node:
            walk_attrs(v, path, hits)


# Kart metni "uzun dinlenmede N kullanım" diyorsa sayaç beklenir. Grant yoksa
# kullanıcı sayfada hiçbir şey görmez — kullanıcının şikâyetinin tersi hâli.
USES_RE = re.compile(
    r'(?i)(\d+\s*/\s*(long|short)\s*rest'
    r'|per\s+(long|short)\s+rest'
    r'|(uses?|times)\s+equal\s+to'
    r'|(uzun|kısa)\s+dinlenmede)')
POOLABLE = {'feat', 'trait', 'subclass', 'species', 'subspecies', 'background',
            'magic-item', 'class-feature'}


def scan_json(path, formulas, builtin_pools):
    pack = json.load(open(path, encoding='utf-8'))
    by_name, ids, vals = entity_index(pack)
    rows, problems = [], []
    for e in vals:
        if not isinstance(e, dict):
            continue
        owner = f"{e.get('name')} [{e.get('type')}]"
        hits = []
        walk_attrs(e.get('attributes') or e.get('fields') or {}, owner, hits)
        for _, node in hits:
            seen = set()
            for r in node.get('resource_pool_grants') or []:
                if not isinstance(r, dict):
                    continue
                pid = pool_label(r.get('pool_ref'))
                bad = check_row(
                    pid,
                    r.get('count') is not None or r.get('count_by_level'),
                    r.get('count_formula'),
                    resolve(r.get('pool_ref'), by_name, ids, builtin_pools),
                    formulas)
                if pid in seen:
                    bad.append('yinelenen pool_ref (aynı kartta iki kez)')
                seen.add(pid)
                if not r.get('recharge'):
                    bad.append('WARN recharge yok — satır etiketsiz çizilir')
                rows.append((owner, pid, r.get('recharge'), bad))
                problems += [(owner, pid, b) for b in bad]
            for r in node.get('granted_spells_at_level') or []:
                if not isinstance(r, dict) or not r.get('uses_per_long_rest'):
                    continue
                ok = resolve(r.get('spell_ref'), by_name, ids, set())
                lbl = pool_label(r.get('spell_ref'))
                if not ok:
                    problems.append((owner, lbl, 'DROP spell_ref çözülemiyor'))
                rows.append((owner, f'spell:{lbl}', 'long_rest',
                             [] if ok else ['DROP spell_ref çözülemiyor']))
        # Havuzun *adı* makine anahtarı; sayfadaki etiket `display_name`.
        # Yoksa kart slug'ı güzelleştirmeye çalışır ve mekaniği adlandıran bir
        # anahtar okunamaz hale gelir ("Hunters Mark No Slot Uses").
        if e.get('type') == 'resource-pool':
            attrs = e.get('attributes') or e.get('fields') or {}
            if not str(attrs.get('display_name') or '').strip():
                problems.append((owner, e.get('name', '?'),
                                 'WARN display_name yok — kart slug gösterir'))
        if not hits and e.get('type') in POOLABLE:
            attrs = e.get('attributes') or e.get('fields') or {}
            text = ' '.join(str(attrs.get(k, '')) for k in
                            ('benefits', 'mechanical_notes')) +                 str(e.get('description') or '')
            if USES_RE.search(text):
                problems.append(
                    (owner, '-', 'WARN metin kullanım sayısı diyor, '
                                 'resource_pool_grants yok'))
    return rows, problems


# ── Dart tarafı: builtin SRD haritası ───────────────────────────────────────

def row_text(src, idx):
    """`'pool_ref'` indeksini saran `{ ... }` bloğunun metni."""
    depth, start = 0, None
    for i in range(idx, -1, -1):
        c = src[i]
        if c == '}':
            depth += 1
        elif c == '{':
            if depth == 0:
                start = i
                break
            depth -= 1
    if start is None:
        return ''
    depth = 0
    for i in range(start, len(src)):
        if src[i] == '{':
            depth += 1
        elif src[i] == '}':
            depth -= 1
            if depth == 0:
                return src[start:i + 1]
    return src[start:]


def scan_dart(path, formulas, builtin_pools):
    src = open(path, encoding='utf-8').read()
    rows, problems = [], []
    for m in re.finditer(r"'pool_ref'\s*:", src):
        block = row_text(src, m.start())
        pid_m = re.search(r"'(pool:[a-z0-9_]*)'", block)
        pid = pid_m.group(1) if pid_m else '??'
        owner_m = None
        for om in re.finditer(r"name:\s*[\"']([^\"']+)[\"']", src[:m.start()]):
            owner_m = om
        owner = owner_m.group(1) if owner_m else os.path.basename(path)
        formula = None
        fm = re.search(r"'count_formula'\s*:\s*'([^']+)'", block)
        if fm:
            formula = fm.group(1)
        has_count = bool(re.search(r"'count(_by_level)?'\s*:", block))
        bad = check_row(pid, has_count, formula, pid in builtin_pools, formulas)
        if not re.search(r"'recharge'\s*:", block):
            bad.append('WARN recharge yok — satır etiketsiz çizilir')
        rech = re.search(r"'recharge'\s*:\s*'([^']+)'", block)
        rows.append((owner, pid, rech.group(1) if rech else None, bad))
        problems += [(owner, pid, b) for b in bad]
    return rows, problems


def selftest():
    f = {'wis_mod_min_1', 'pb'}
    assert check_row('pool:x', False, None, True, f) == [
        'DROP max yok (count/count_formula/count_by_level hiçbiri)']
    assert check_row('pool:x', True, None, False, f)[0].startswith('DROP pool_ref')
    assert check_row('pool:x', False, 'wis_mod_min_1', True, f) == []
    assert check_row('pool:x', False, 'bogus_mod', True, f)[0].startswith(
        'DROP count_formula')
    assert row_text("a {'pool_ref': 1, 'b': {'c': 2}} z", 4).endswith('}')
    assert resolve({'_lookup': 'resource-pool', 'name': 'pool:a'},
                   {('resource-pool', 'pool:a'): 'id1'}, set(), set())
    assert resolve('pool:rage_uses', {}, set(), {'pool:rage_uses'})
    assert not resolve({'_lookup': 'resource-pool', 'name': 'pool:z'},
                       {}, set(), set())
    print('selftest ok')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--quiet', action='store_true', help='sadece bulgular')
    ap.add_argument('--selftest', action='store_true')
    ap.add_argument('--all', action='store_true',
                    help='üçüncü parti paketlerin metin sezgisi de raporlansın')
    args = ap.parse_args()
    if args.selftest:
        return selftest()

    formulas = known_formulas()
    pools = builtin_pool_slugs()
    all_rows, all_problems = [], []

    for dirpath, _, names in os.walk(BUILTIN):
        for n in sorted(names):
            if n.endswith('.dart'):
                p = os.path.join(dirpath, n)
                r, pr = scan_dart(p, formulas, pools)
                src = os.path.relpath(p, ROOT)
                all_rows += [(src,) + x for x in r]
                all_problems += [(src,) + x for x in pr]

    for p in sorted(pack_files()):
        try:
            r, pr = scan_json(p, formulas, pools)
        except (json.JSONDecodeError, UnicodeDecodeError) as e:
            all_problems.append((os.path.relpath(p, ROOT), '-', '-',
                                 f'okunamadı: {e}'))
            continue
        src = os.path.relpath(p, ROOT)
        # Üçüncü parti paketlerin düz metni bizim elimizde değil; metin sezgisi
        # orada 60+ satır gürültü üretiyor. Grant hataları her zaman raporlanır.
        third_party = ('open5e_packs' in src and 'dnd5e-srd' not in src)
        if third_party and not args.all:
            pr = [x for x in pr if 'metin kullanım' not in x[-1]]
        all_rows += [(src,) + x for x in r]
        all_problems += [(src,) + x for x in pr]

    if not args.quiet:
        cur = None
        for src, owner, pid, rech, bad in all_rows:
            if src != cur:
                print(f'\n── {src}')
                cur = src
            flag = '  ✗ ' + '; '.join(bad) if bad else ''
            print(f'   {owner:<34} {pid:<40} {rech or "-":<12}{flag}')

    # Hiçbir grant'ın işaret etmediği builtin havuz: Tier-0'da duran ama
    # kimsenin vermediği kayıt — ya grant unutulmuş ya lookup ölü.
    referenced = {r[2] for r in all_rows}
    for slug in sorted(pools - referenced):
        all_problems.append((os.path.relpath(LOOKUPS_SRC, ROOT), 'lookups',
                             slug, 'WARN hiçbir kart bu havuzu vermiyor'))

    drops = [x for x in all_problems if 'DROP' in x[-1] or 'yinelenen' in x[-1]]
    warns = [x for x in all_problems if x not in drops]
    print(f'\nToplam {len(all_rows)} havuz satırı; '
          f'{len(drops)} sessiz kayıp, {len(warns)} etiket uyarısı.')
    for src, owner, pid, msg in drops:
        print(f'  ✗ {src}: {owner} → {pid}: {msg}')
    for src, owner, pid, msg in warns:
        print(f'  ! {src}: {owner} → {pid}: {msg}')
    return 1 if drops else 0


if __name__ == '__main__':
    sys.exit(main() or 0)
