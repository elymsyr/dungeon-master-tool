/// Cairn markdown → `world-blueprint.json` ortak sözleşmesi.
///
/// `src/` altındaki her parser bu dosyayı import eder ve tek bir şey döner:
/// `Map<String, List<Bp>>` — kategori slug'ı → entity satırları. `build_cairn`
/// bunları tek `categories` bloğunda birleştirir.
///
/// Alan adları [tool/content/world-blueprint.md] sözleşmesidir; şemada
/// olmayan bir anahtar `convert_blueprint.dart --check`'te **hata** verir
/// (sessizce düşmez), o yüzden burada uydurma alan yok.
library;

import 'dart:io';

/// `categories.<slug>` içindeki tek satır: `{source_name, [source,] mapping}`.
typedef Bp = Map<String, dynamic>;

/// Entity satırı kurar. `null` değerli alanlar düşer — kaynak bir şey
/// söylemiyorsa alan **yazılmaz**, tahmin edilmez (README §0).
///
/// [source] girdi başına atıf: `mapping`'in **kardeşi** olarak yazılır ve
/// entity'nin `source` alanına (UI'daki Source rozeti / kenar çubuğu sıralama
/// facet'i) geçer. Verilmezse paketin manifest başlığı kullanılır.
Bp bpEntity(String name, Map<String, dynamic> fields, {String? source}) => {
      'source_name': name,
      'source': ?source,
      'mapping': <String, dynamic>{
        'name': name,
        ...Map.of(fields)..removeWhere((_, v) => v == null),
      },
    };

/// Bir kaynak dosyanın hiçbir girdiye ait olmayan metni (önsöz, atıf listesi,
/// kullanım notu) → tek `lore` sayfası, birebir. Özetlenmez, atılmaz.
Bp loreNote(String name, String text, String tag) => bpEntity(name, {
      'pages': [text],
      'description': text,
      'tags': [tag],
    });

/// Ref zarfı — `lookup` **hedefin** kategori slug'ı.
Map<String, dynamic> ref(String slug, String name) =>
    <String, dynamic>{'lookup': slug, 'match': 'name', 'value': name};

/// İki parser aynı kategoriye yazabilir (ör. reliquary + more-relics →
/// `magic-item`); satırları birleştirir, üzerine yazmaz.
void mergeInto(Map<String, List<Bp>> into, Map<String, List<Bp>> from) {
  from.forEach((slug, rows) => (into[slug] ??= <Bp>[]).addAll(rows));
}

// ── Markdown yardımcıları ────────────────────────────────────────────────

/// Jekyll frontmatter'ını (`---` … `---`) atar.
String stripFrontmatter(String md) {
  if (!md.startsWith('---')) return md;
  final end = md.indexOf('\n---', 3);
  if (end < 0) return md;
  final nl = md.indexOf('\n', end + 1);
  return nl < 0 ? '' : md.substring(nl + 1);
}

/// Dosyayı okur, frontmatter'ı atar, satır sonlarını normalize eder.
String readMd(String path) {
  final f = File(path);
  if (!f.existsSync()) throw StateError('kaynak yok: $path');
  return stripFrontmatter(f.readAsStringSync().replaceAll('\r\n', '\n'));
}

/// `<dir>` altındaki `.md` dosyalarını ada göre sıralı verir.
List<String> mdFiles(String dir) => (Directory(dir)
        .listSync()
        .whereType<File>()
        .map((f) => f.path)
        .where((p) => p.endsWith('.md'))
        .toList()
      ..sort());

/// Verilen seviyedeki başlıklara göre böler → `(başlık, gövde)`.
/// Başlıktan önceki metin `''` başlıklı ilk kayıt olarak döner.
List<({String title, String body})> sections(String md, {int level = 2}) {
  final marker = '${'#' * level} ';
  final out = <({String title, String body})>[];
  var title = '';
  final body = <String>[];
  void flush() {
    final text = body.join('\n').trim();
    if (title.isNotEmpty || text.isNotEmpty) out.add((title: title, body: text));
    body.clear();
  }

  for (final line in md.split('\n')) {
    // Daha derin başlıklar (`###`) gövdede kalmalı; sadece tam seviye böler.
    if (line.startsWith(marker) && !line.startsWith('$marker#')) {
      flush();
      title = line.substring(marker.length).trim();
    } else {
      body.add(line);
    }
  }
  flush();
  return out;
}

/// Markdown tablo satırlarını hücrelere böler. Ayraç satırı (`| --- |`) ve
/// tamamen boş satırlar atlanır. Hücreler trim'li, kenar boşlukları atılmış.
List<List<String>> tableRows(String md) {
  final out = <List<String>>[];
  for (final line in md.split('\n')) {
    final t = line.trim();
    if (!t.startsWith('|')) continue;
    if (RegExp(r'^\|[\s:|-]+\|?$').hasMatch(t)) continue;
    final cells = t
        .substring(1, t.endsWith('|') ? t.length - 1 : t.length)
        .split('|')
        .map((c) => c.trim())
        .toList();
    if (cells.every((c) => c.isEmpty)) continue;
    out.add(cells);
  }
  return out;
}

/// `**Ad**` / `_x_` / `[Ad](url)` biçimlendirmesini metinden söker — sadece
/// *isim* alanları için. Gövde metni her zaman birebir korunur.
String plain(String s) => s
    .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!)
    .replaceAll(RegExp(r'\*\*|__|[*_`]'), '')
    .trim();

// ── Cairn → 5e sayısal dönüşüm ───────────────────────────────────────────

/// Cairn Armor → 5e `ac`. `resources/5e-notes.md`'nin AC→Armor eşiklerinin
/// tersi (≤12 / 13+ / 16+ / 20+) — uydurma değil, kaynağın kendi kuralı.
int acForArmor(int armor) => switch (armor) {
      >= 3 => 20,
      2 => 16,
      1 => 13,
      _ => 10,
    };

/// Cairn fiyatları gold piece; şemanın `*_cp` alanları copper.
int cpFromGp(num gp) => (gp * 100).round();
