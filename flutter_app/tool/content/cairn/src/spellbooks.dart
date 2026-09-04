/// Spellbook'lar → `spell`.
/// `second-edition/wardens-guide/spellbooks.md` (d100, core) ve
/// `resources/more-spellbooks.md` (d666, community).
///
/// İkisi de tek bir markdown tablosu; gövde/detay bölümü yok. d666
/// dosyasındaki `[Ad](#anchor)` bağlantıları o dosyada karşılığı olmayan
/// ölü çapalar — isim hücresinden sadece ad alınır.
///
/// Cairn spell'lerinin seviyesi, okulu, bileşeni, süresi yok; o alanlar
/// bilerek yazılmaz. Zar numarası için sayısal alan yok → `tags`.
library;

import '../bp.dart';

/// `| **<N>** | **<Ad>** | <Etki>. _<kitabın tuhaflığı>._ |` — 100 satır.
/// Üçüncü hücre birebir `description`; italik tuhaflık cümlesi de girişin
/// parçası, ayrılmaz.
Map<String, List<Bp>> parseSpellbooks(String cairn) => {
      'spell': [
        for (final r
            in tableRows(readMd('$cairn/second-edition/wardens-guide/spellbooks.md')))
          if (r.length >= 3 && RegExp(r'^\d+$').hasMatch(plain(r[0])))
            bpEntity(plain(r[1]), {
              'description': r[2],
              'tags': ['d100:${plain(r[0])}'],
            }),
      ],
    };

/// `| <NNN> | [Ad](#anchor) | <özet> |` — d666, 216 satır.
///
/// Girdi başına `source` **yazılmaz**: dosyanın `### References` bloğu sekiz
/// kaynağı tablonun tamamı için sayıyor, hangi satırın hangisinden geldiğini
/// söylemiyor. Uydurmak yerine blok olduğu gibi tek `lore` sayfasında durur;
/// entity'lerin `source`'u paket başlığı kalır.
Map<String, List<Bp>> parseMoreSpellbooks(String cairn) {
  final md = readMd('$cairn/resources/more-spellbooks.md');
  return {
    'spell': [
      for (final r in tableRows(md))
        if (r.length >= 3 && RegExp(r'^[1-6]{3}$').hasMatch(r[0]))
          bpEntity(plain(r[1]), {
            'description': r[2],
            'tags': ['d666:${r[0]}'],
          }),
    ],
    'lore': [
      loreNote('More Spellbooks (credits and notes)', _nonTable(md),
          'More Spellbooks'),
    ],
  };
}

/// Tablo dışında kalan her şey: önsöz + `### References` atıf listesi.
String _nonTable(String md) => md
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('|'))
    .join('\n')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();
