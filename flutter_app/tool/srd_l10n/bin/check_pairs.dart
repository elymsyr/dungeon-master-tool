// SRD Türkçeleştirme (docs/srd-tr/ROADMAP.md Faz 3) — her `İngilizce → Türkçe`
// çiftini N1–N10 kurallarıyla denetler ve scope başına kapsam raporu basar.
//
//   dart run tool/srd_l10n/bin/check_pairs.dart [--dir assets/srd_l10n/tr]
//       [--glossary ../docs/srd-tr/GLOSSARY.md] [scope ...]
//
// Değeri "" olan çift çevrilmemiştir, denetlenmez (kapsamda sayılır). Herhangi
// bir FAIL varsa çıkış kodu 1'dir; UYARI'lar listelenir, insan bakar.
//
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

class Finding {
  const Finding(this.code, this.fail, this.detail);
  final String code;
  final bool fail;
  final String detail;
  @override
  String toString() => '${fail ? 'FAIL' : 'UYARI'} $code $detail';
}

/// GLOSSARY.md'den okunan terimler (N10) ve "aynen kalır" listesi (N6).
class Glossary {
  Glossary(this.terms, this.keep)
      : _termRes = [
          for (final en in terms.keys.toList()
            ..sort((a, b) => b.length.compareTo(a.length)))
            (en, _enTermRe(en)),
        ];

  /// İngilizce terim → onaylı Türkçe karşılıklar.
  final Map<String, Set<String>> terms;

  /// İngilizceyle aynı kalması hata olmayan metinler.
  final Set<String> keep;

  final List<(String, RegExp)> _termRes;
}

final _row = RegExp(r'^\|(.+)\|\s*$');
final _paren = RegExp(r'\s*\([^)]*\)');

/// §3'ten itibaren her `| İngilizce | Türkçe | … |` satırı bir terimdir.
/// `A / B` hücreleri ayrılır; `Cloud / … / Storm Giant` gibi ortak son kelime
/// tek kelimelik parçalara eklenir.
Glossary parseGlossary(String md) {
  final terms = <String, Set<String>>{};
  final keep = <String>{};
  final lines = const LineSplitter().convert(md);

  final k = lines.indexWhere((l) => l.contains('**Aynen kalır**'));
  if (k >= 0) {
    final para = StringBuffer();
    for (var i = k; i < lines.length && lines[i].trim().isNotEmpty; i++) {
      para.write(' ${lines[i]}');
    }
    final list = para.toString().split(':').skip(1).join(':');
    keep.addAll(list
        .split('·')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty));
  }

  final start = lines.indexWhere((l) => l.startsWith('## 3.'));
  for (final l in lines.skip(start < 0 ? lines.length : start)) {
    final m = _row.firstMatch(l);
    if (m == null) continue;
    final cells = m[1]!.split('|').map(_clean).toList();
    if (cells.length < 3) continue;
    final en = cells[0], tr = cells[1];
    if (en == 'İngilizce' || en.startsWith('---') || en.contains('<')) {
      continue;
    }
    final ens = _expand(en.replaceAll(_paren, '')),
        trs = _expand(tr.replaceAll(_paren, ''));
    if (ens.isEmpty || trs.isEmpty) continue;
    for (var i = 0; i < ens.length; i++) {
      final t = trs.length == ens.length ? trs[i] : trs.first;
      if (trs.length != ens.length && trs.length != 1) break;
      terms.putIfAbsent(ens[i], () => {}).add(t);
      if (ens[i] == t) keep.add(t);
    }
  }
  return Glossary(terms, keep);
}

String _clean(String c) =>
    c.replaceAll('`', '').replaceAll('**', '').trim();

List<String> _expand(String cell) {
  final parts = cell
      .split(' / ')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.length < 2) return parts;
  final last = parts.last.split(' ');
  if (last.length < 2) return parts;
  final tail = last.sublist(1).join(' ');
  return [
    for (final p in parts) p.contains(' ') ? p : '$p $tail',
  ];
}

// ---- N1–N10 ----------------------------------------------------------------

final _num = RegExp(r'(?:(?<=^|[\s(\[])[+\-−])?\d+(?:[.,/]\d+)*');
final _dice = RegExp(
    r'(?<![A-Za-z])(\d*)[dD](\d+)(?:\s*([+\-−])\s*(\d+)(?![dD\d]))?');
final _dc = RegExp(r"DC(?:'[a-zçğıöşü]+)?\s+(\d+)");
final _enUnit = RegExp(
    r'\d\s*-?\s*(feet|foot|ft\.|miles?|lb\.|pounds?|gallons?|pints?|ounces?|inch(?:es)?|gp|sp|cp|ep|pp)(?![A-Za-z])');
final _trUnit = RegExp(
    r'\d\s*-?\s*(fit|ft\.|mil|lb\.|pound|galon|pint|ons|inç|gp|sp|cp|ep|pp)');
const _unitCanon = {
  'feet': 'ft', 'foot': 'ft', 'ft.': 'ft', 'fit': 'ft', //
  'mile': 'mi', 'miles': 'mi', 'mil': 'mi',
  'lb.': 'lb', 'pound': 'lb', 'pounds': 'lb',
  'gallon': 'gal', 'gallons': 'gal', 'galon': 'gal',
  'pint': 'pt', 'pints': 'pt',
  'ounce': 'oz', 'ounces': 'oz', 'ons': 'oz',
  'inch': 'in', 'inches': 'in', 'inç': 'in',
};
final _abbrev =
    RegExp(r'\b(?:ft|lb|vb|vs|örn|bkz|etc|e\.g|i\.e)\.', caseSensitive: false);
final _ordinal = RegExp(r'\d\.(?=\s+[a-zçğıöşü\d])');
final _sentenceEnd = RegExp(r'[.!?]+(?=\s|$)');

List<String> _sorted(Iterable<String> xs) => xs.toList()..sort();
bool _sameBag(Iterable<String> a, Iterable<String> b) =>
    _sorted(a).join('\u0000') == _sorted(b).join('\u0000');
String _bagDiff(Iterable<String> en, Iterable<String> tr) =>
    'EN ${_sorted(en)} ≠ TR ${_sorted(tr)}';

Iterable<String> _nums(String s) =>
    _num.allMatches(s).map((m) => m[0]!.replaceAll('−', '-'));
Iterable<String> _dices(String s) => _dice.allMatches(s).map((m) =>
    '${m[1]}d${m[2]}${m[3] == null ? '' : '${m[3]!.replaceAll('−', '-')}${m[4]}'}');
Iterable<String> _dcs(String s) => _dc.allMatches(s).map((m) => m[1]!);
Iterable<String> _units(RegExp re, String s) => re.allMatches(s).map((m) {
      final u = m[1]!.toLowerCase();
      return _unitCanon[u] ?? u;
    });

Map<String, int> _markdown(String s) {
  final noBold = s.replaceAll('**', '');
  int count(Pattern p, String x) => p.allMatches(x).length;
  return {
    '**': count('**', s),
    '*': count('*', noBold),
    '_': count('_', s),
    'satır': count('\n', s),
    'madde': count(RegExp(r'^\s*[-*] ', multiLine: true), s),
    '|': count('|', s),
  };
}

int _sentences(String s) => _sentenceEnd
    .allMatches(s.replaceAll(_abbrev, ' ').replaceAll(_ordinal, ' '))
    .length;

/// Türkçe küçük harf (I → ı, İ → i).
String _trLower(String s) =>
    s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

RegExp _enTermRe(String term) => RegExp(
    '(?<![A-Za-z])${RegExp.escape(term)}(?:e?s)?(?![A-Za-z])',
    caseSensitive: !term.contains(' '));

/// Sondaki ünsüzün yumuşamış hali (`Güç` → `gücü`, `Yetkinlik` → `yetkinliğin`).
const _softened = {
  'k': '[kğg]',
  'ç': '[çc]',
  't': '[td]',
  'p': '[pb]',
  'g': '[gğ]',
};

/// Türkçe terim çekimli de geçebilir (`Kurtarma Zarı` → `kurtarma zarlarına`,
/// `Yetkinlik` → `yetkinliğin`): son kelimenin tamlama eki atılır, sondaki
/// ünsüzün yumuşamış hali de kabul edilir, kelimeler önek olarak aranır.
// ponytail: önek araması bazı yanlış eşleşmelere göz yumar (N10 sadece UYARI).
bool _hasTrTerm(String trLower, String term) {
  final words = _trLower(term).split(RegExp(r'\s+'));
  final stems = <String>[];
  for (var i = 0; i < words.length; i++) {
    var w = words[i];
    if (words.length > 1 && i == words.length - 1) {
      final m = RegExp(r'(s?[ıiuü])$').firstMatch(w);
      if (m != null && w.length - m[0]!.length >= 3) {
        w = w.substring(0, w.length - m[0]!.length);
      }
    }
    // İsim-fiil → fiil kökü (`Tırmanma` → `tırman`, `Büyü Yapma` → `büyü yap`).
    if (i == words.length - 1 && w.length >= 5 && RegExp(r'm[ae]$').hasMatch(w)) {
      stems.add(RegExp.escape(w.substring(0, w.length - 2)));
      continue;
    }
    final soft = _softened[w[w.length - 1]];
    stems.add(soft == null
        ? RegExp.escape(w)
        : '${RegExp.escape(w.substring(0, w.length - 1))}$soft');
  }
  return RegExp('(?<!\\p{L})${stems.join(r'\S*\s+')}', unicode: true)
      .hasMatch(trLower);
}

/// Bir çifti N1–N10'a göre denetler. `tr` boşsa çağrılmamalı.
List<Finding> checkPair(String en, String tr, Glossary g) {
  final out = <Finding>[];
  void fail(String code, String d) => out.add(Finding(code, true, d));
  void warn(String code, String d) => out.add(Finding(code, false, d));

  // N6 önce: boş ya da çevrilmemiş çiftte diğer kurallar anlamsız.
  if (tr.trim().isEmpty) {
    fail('N6', 'çeviri sadece boşluk');
    return out;
  }
  if (tr == en && !g.keep.contains(en)) {
    fail('N6', 'İngilizceyle aynı (sözlükte "aynen kalır" değil)');
    return out;
  }

  if (!_sameBag(_nums(en), _nums(tr))) {
    fail('N1', 'sayılar: ${_bagDiff(_nums(en), _nums(tr))}');
  }
  if (!_sameBag(_dices(en), _dices(tr))) {
    fail('N2', 'zarlar: ${_bagDiff(_dices(en), _dices(tr))}');
  }
  if (!_sameBag(_dcs(en), _dcs(tr))) {
    fail('N3', 'DC: ${_bagDiff(_dcs(en), _dcs(tr))}');
  }
  final eu = _units(_enUnit, en), tu = _units(_trUnit, tr);
  if (!_sameBag(eu, tu)) fail('N4', 'birimler: ${_bagDiff(eu, tu)}');

  final em = _markdown(en), tm = _markdown(tr);
  final md = [
    for (final k in em.keys)
      if (em[k] != tm[k]) '$k ${em[k]}→${tm[k]}',
  ];
  if (md.isNotEmpty) fail('N5', 'markdown: ${md.join(', ')}');

  final ep = [en.split('(').length, en.split(')').length],
      tp = [tr.split('(').length, tr.split(')').length];
  if (ep[0] != tp[0] || ep[1] != tp[1]) {
    fail('N7', 'parantez: EN ${ep[0] - 1}/${ep[1] - 1} ≠ TR ${tp[0] - 1}/${tp[1] - 1}');
  }

  // N8 kısa metinlerde (adlar) gürültü — ad listeleri dalga onayında
  // topluca gösterilir; oran 5+ kelimelik metinlere uygulanır.
  if (en.split(RegExp(r'\s+')).length >= 5) {
    final r = tr.length / en.length;
    if (r < 0.7 || r > 1.6) warn('N8', 'uzunluk oranı ${r.toStringAsFixed(2)}');
  }

  final es = _sentences(en), ts = _sentences(tr);
  if ((es - ts).abs() > 1) warn('N9', 'cümle sayısı EN $es ≠ TR $ts');

  // N10: uzun terim önce eşleşir, eşleşen yer maskelenir (`Saving Throw`
  // içindeki `Throw` ayrıca sayılmaz).
  var masked = en;
  final trL = _trLower(tr);
  final missing = <String>{};
  for (final (term, re) in g._termRes) {
    if (!re.hasMatch(masked)) continue;
    masked = masked.replaceAllMapped(re, (m) => ' ' * m[0]!.length);
    final alts = g.terms[term]!;
    if (!alts.any((t) => _hasTrTerm(trL, t))) {
      missing.add('$term → ${alts.join(' | ')}');
    }
  }
  if (missing.isNotEmpty) warn('N10', 'sözlük: ${missing.join('; ')}');
  return out;
}

void main(List<String> args) {
  var dir = 'assets/srd_l10n/tr';
  var glossaryPath = '../docs/srd-tr/GLOSSARY.md';
  final only = <String>{};
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--dir':
        dir = args[++i];
      case '--glossary':
        glossaryPath = args[++i];
      default:
        only.add(args[i]);
    }
  }
  final g = parseGlossary(File(glossaryPath).readAsStringSync());

  final files = Directory(dir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final rows = <String>[];
  var tAll = 0, tDone = 0, tFail = 0, tWarn = 0;
  for (final f in files) {
    final scope = f.uri.pathSegments.last.replaceAll('.json', '');
    if (only.isNotEmpty && !only.contains(scope)) continue;
    final pairs = (jsonDecode(f.readAsStringSync()) as Map).cast<String, String>();
    var done = 0, nFail = 0, nWarn = 0;
    for (final MapEntry(key: en, value: tr) in pairs.entries) {
      if (tr.isEmpty) continue;
      done++;
      final fs = checkPair(en, tr, g);
      if (fs.isEmpty) continue;
      final short = en.length > 70 ? '${en.substring(0, 70)}…' : en;
      print('[$scope] ${jsonEncode(short)}');
      for (final x in fs) {
        print('    $x');
        x.fail ? nFail++ : nWarn++;
      }
    }
    final pct = pairs.isEmpty ? 100 : done * 100 ~/ pairs.length;
    rows.add('| $scope | $done / ${pairs.length} | %$pct | $nFail | $nWarn |');
    tAll += pairs.length;
    tDone += done;
    tFail += nFail;
    tWarn += nWarn;
  }
  print('');
  print('| scope | çevrili / toplam | kapsam | FAIL | UYARI |');
  print('|---|---:|---:|---:|---:|');
  rows.forEach(print);
  final tPct = tAll == 0 ? 100 : tDone * 100 ~/ tAll;
  print('| **toplam** | **$tDone / $tAll** | **%$tPct** | **$tFail** | **$tWarn** |');
  print('');
  print('FAIL: $tFail · UYARI: $tWarn · sözlük: ${g.terms.length} terim, '
      '${g.keep.length} aynen kalır');
  if (tFail > 0) exitCode = 1;
}
