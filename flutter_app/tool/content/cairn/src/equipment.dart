/// `resources/more-equipment.md` → `adventuring-gear` (+ ücretli iş gücü için
/// `service`) ve önsözü taşıyan tek bir `lore`. Community pack.
///
/// Tablolar **dört sütunlu**: tek satır iki eşya taşır
/// (`| Ad | Fiyat | Ad | Fiyat |`), o yüzden hücreler ikişerli gezilir —
/// naif iki sütunlu okuma listenin yarısını sessizce yer.
library;

import '../bp.dart';

/// Dosyanın kendi kredi satırı; community içerik, birebir korunur.
const _credit = 'Credit to [Oskar Swida](https://oskarswida.itch.io/)';

/// Aynı kredinin aranabilir/sıralanabilir hâli — her satır tek katkıcıya ait.
const _source = 'Oskar Swida';

Map<String, List<Bp>> parseMoreEquipment(String cairn) {
  final md = readMd('$cairn/resources/more-equipment.md');
  final out = <String, List<Bp>>{'adventuring-gear': [], 'service': []};

  for (final sec in sections(md)) {
    if (sec.title.isEmpty) {
      // Önsöz (başlıklar + madde imleri) tek `lore` olarak birebir saklanır.
      out['lore'] = [
        loreNote('More Equipment (credits and notes)', sec.body,
            'More Equipment'),
      ];
      continue;
    }
    // Tablo dışı serbest metin (ör. "First value means wages per a week…").
    final note = sec.body
        .split('\n')
        .where((l) => !l.trim().startsWith('|') && l.trim().isNotEmpty)
        .join('\n');
    // Kiralık iş gücü hizmettir; kalan her şey taşınabilir olmasa da gear.
    final slug = sec.title.startsWith('Hirelings') ? 'service' : 'adventuring-gear';

    String? header;
    for (final row in tableRows(sec.body)) {
      if (row.first.startsWith('**')) {
        // Sütun başlığı satırın anlamını taşıyor: Specialists'te gövde metni
        // "wage per week" derken tablo "**Wage (per month)**" diyor. Kaynak
        // kendiyle çelişiyor — hangisinin doğru olduğuna karar vermiyoruz,
        // ikisi de girdinin açıklamasında duruyor.
        header = '| ${row.join(' | ')} |';
        continue;
      }
      final raw = '| ${row.join(' | ')} |';
      for (var i = 0; i + 1 < row.length; i += 2) {
        final name = plain(row[i]);
        if (name.isEmpty) continue;
        // Sayı olmayan hücre (`5 × normal`, `5 / 1%`, `1gp per square foot`)
        // tahmine dönüştürülmez; ham satırda zaten duruyor.
        final gp = num.tryParse(row[i + 1]);
        out[slug]!.add(bpEntity(
          name,
          {
            'cost_cp': gp == null ? null : cpFromGp(gp),
            'kind': slug == 'service' ? 'Other' : null,
            'description': [
              '## ${sec.title}',
              if (note.isNotEmpty) note,
              ?header,
              raw,
              _credit,
            ].join('\n\n'),
            'tags': [sec.title],
          },
          source: _source,
        ));
      }
    }
  }
  return out;
}
