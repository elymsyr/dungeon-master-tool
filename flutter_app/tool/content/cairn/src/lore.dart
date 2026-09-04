/// Kural metni, prosedürler, tablolar, seed üreteçleri, Vald → `lore`.
///
/// Her kaynak dosya bir `lore` entity'si: `pages` = dosyanın `##` bölümleri,
/// başlığıyla birlikte **birebir**. `description` sadece kaynak yol —
/// gerçek metnin tamamı `pages` içinde durur, özet yok.
library;

import '../bp.dart';

const _pg = 'second-edition/players-guide';
const _wg = 'second-edition/wardens-guide';

const _pgDocs = [
  'character-creation',
  'core-rules',
  'overview-and-principles',
  'procedures',
];

const _wgDocs = [
  'about-the-example-party',
  'bibliography',
  'bonds-and-omens',
  'combat',
  'creating-backgrounds',
  'creating-monsters',
  'detachments',
  'dungeon-exploration',
  'dungeon-seeds',
  'forest-seeds',
  'growth',
  'knowledge-and-perception',
  'naming-procedures',
  'npc-tables',
  'pointcrawls',
  'saves',
  'setting-seeds',
  'variable-difficulty',
  'wilderness-exploration',
];

Map<String, List<Bp>> parseLore(String cairn) {
  final rows = <Bp>[
    for (final d in _pgDocs) _doc(cairn, '$_pg/$d.md', "player's guide"),
    // İki dosya da "# Vald" başlıklı — aynı kategoride aynı ad hata.
    _doc(cairn, '$_pg/vald.md', "player's guide", name: "Vald (Player's Guide)"),
    for (final d in _wgDocs) _doc(cairn, '$_wg/$d.md', "warden's guide"),
    _doc(cairn, '$_wg/vald.md', "warden's guide", name: "Vald (Warden's Guide)"),
    _monsterCategories(cairn),
  ];
  return {'lore': rows};
}

/// Bir markdown dosyası → tek `lore`. H1 satırı ad olur ve gövdeden çıkar;
/// kalan metin `##` bölümlerine ayrılır, her bölüm başlığıyla beraber bir
/// sayfa. `##` yoksa dosyanın tamamı tek sayfa.
Bp _doc(String cairn, String rel, String tag, {String? name}) {
  final md = readMd('$cairn/$rel');
  final lines = md.split('\n');
  final h1 = lines.indexWhere((l) => l.startsWith('# '));
  final title = h1 < 0 ? rel : lines[h1].substring(2).trim();
  final body = h1 < 0 ? md : (List.of(lines)..removeAt(h1)).join('\n');

  final pages = <String>[];
  for (final s in sections(body)) {
    final page = s.title.isEmpty ? s.body : '## ${s.title}\n\n${s.body}';
    if (page.trim().isNotEmpty) pages.add(page.trim());
  }

  return bpEntity(name ?? title, {
    'description': rel,
    'pages': pages,
    'tags': [tag],
  });
}

/// bestiary.md'nin geri kalanı `resources/monsters/` ile aynı — sadece
/// d20 kategori tablosu lore'a girer.
Bp _monsterCategories(String cairn) {
  final s = sections(readMd('$cairn/$_wg/bestiary.md'))
      .firstWhere((s) => s.title == 'Monster Categories');
  return bpEntity('Monster Categories', {
    'description': '$_wg/bestiary.md#monster-categories',
    'pages': ['## ${s.title}\n\n${s.body}'],
    'tags': ["warden's guide"],
  });
}
