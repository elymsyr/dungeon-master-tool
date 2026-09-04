/// Relic'ler → `magic-item`.
/// `second-edition/wardens-guide/reliquary.md` (core) ve
/// `resources/more-relics.md` (community — kaynak başına atıf).
library;

import '../bp.dart';

/// `## <Ad>[, N charges|uses][, +N Armor][, _petty_][ (dX)]` + madde imleri.
Map<String, List<Bp>> parseReliquary(String cairn) => {
      'magic-item': [
        for (final s in sections(
            readMd('$cairn/second-edition/wardens-guide/reliquary.md')))
          if (s.title.isNotEmpty) _relic(s.title, s.body, 2),
      ],
    };

/// Aynı gramer `###` seviyesinde. `### From …` bir relic değil, altındaki
/// bloğun atıf başlığıdır; her relic'e birebir iliştirilir — bu paket zaten
/// kaynağı girdi başına değiştiği için var.
Map<String, List<Bp>> parseMoreRelics(String cairn) {
  final md = readMd('$cairn/resources/more-relics.md');
  final rows = <Bp>[];
  var from = '';
  var preamble = '';
  for (final s in sections(md, level: 3)) {
    if (s.title.startsWith('From ')) {
      from = s.title;
    } else if (s.title.isNotEmpty) {
      rows.add(_relic(s.title, s.body, 3, from: from.isEmpty ? null : from));
    } else if (s.body.isNotEmpty) {
      // Başlıktan önceki önsöz ("…copied with permission.") — bu paketin
      // izin beyanı, hiçbir relic'e ait değil.
      preamble = s.body;
    }
  }
  return {
    'magic-item': rows,
    'lore': [loreNote('More Relics (credits and notes)', preamble, 'More Relics')],
  };
}

final _bullet = RegExp(r'^\s*[-*]\s*');
final _recharge = RegExp(r'^\*{0,2}Recharge\*{0,2}\s*:\s*');
final _charges = RegExp(r'(\d+)\s+(?:charges?|uses?)', caseSensitive: false);

/// Ad başlığın kendisi — nitelikleriyle (`, 2 uses`, `, +1 Armor`, `(d6)`)
/// birlikte: hem kategori içinde tekil kalır hem hiçbir şey kaybolmaz.
/// Cairn'in "Armor"ı düz hasar azaltması, 5e AC'si değil → `ac_bonus`'a
/// çevrilmez; nadirlik/aktivasyon/uyum gibi 5e alanlarını kaynak hiç
/// söylemiyor, o yüzden yazılmıyor.
Bp _relic(String title, String body, int level, {String? from}) {
  final effects = <String>[];
  String? regain;
  for (final line in body.split('\n')) {
    final t = line.replaceFirst(_bullet, '').trim();
    if (t.isEmpty) continue;
    // Bazı girdilerde `Recharge` satırı madde imi almamış; imle değil metinle ayır.
    final m = _recharge.firstMatch(t);
    if (m == null) {
      effects.add(t);
    } else {
      regain = [?regain, t.substring(m.end)].join(' ');
    }
  }
  final charges = _charges.firstMatch(title);
  return bpEntity(
    title,
    {
      'charges_max': charges == null ? null : int.parse(charges[1]!),
      'charge_regain': regain,
      'effects': effects.isEmpty ? null : effects.join('\n\n'),
      // Atıf satırı (bağlantısıyla birlikte) gövdede de birebir kalır;
      // `source` onun aranabilir/sıralanabilir hâli.
      'description': '${'#' * level} $title\n\n$body'
          '${from == null ? '' : '\n\n_${from}_'}',
    },
    source: from == null ? null : plain(from).replaceFirst('From ', ''),
  );
}
