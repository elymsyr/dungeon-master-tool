/// `second-edition/players-guide/marketplace.md` + `resources/hirelings.md`
/// → `armor` / `weapon` / `mount` / `vehicle` / `service` /
/// `adventuring-gear` / `hireling` (+ dosya önsözleri için tek `lore`).
///
/// Fiyat listesi **kanonik addır** — `build_cairn`'de ilk sırada koşar, sonraki
/// parser'lar aynı eşyayı tekrar tanımlarsa düşürülür.
///
/// Tek bir `##` bölümü tek bir kategoriye gitmiyor: "Transport" hem hayvan
/// (`mount`) hem araç (`vehicle`) hem satın alınan yolculuk (`service`),
/// "Upkeep & Recovery" hem hizmet hem envanter eşyası taşıyor. Bölüm başlığı
/// varsayılan, [_rowSlug] istisnadır — tahmin değil, satırın kendi adı söylüyor.
library;

import '../bp.dart';

const _sectionSlug = <String, String>{
  'Armor': 'armor',
  'Weapons': 'weapon',
  'Transport': 'vehicle',
  'Upkeep & Recovery': 'service',
  'Hirelings (per day)': 'hireling',
  'Gear': 'adventuring-gear',
};

const _rowSlug = <String, String>{
  'Horse (+4 slots)': 'mount',
  'Mule (+6 slots, slow)': 'mount',
  'Carriage Seat': 'service',
  "Ship's Passage": 'service',
  'Rations (3 uses)': 'adventuring-gear',
  'Animal Feed (3 uses, bulky)': 'adventuring-gear',
};

/// `service.kind` kapalı enum; satırın kendisi hangisi olduğunu söylüyor.
const _serviceKind = <String, String>{
  'Carriage Seat': 'Transport',
  "Ship's Passage": 'Transport',
  'Room & Board (per night)': 'Shelter',
  'Private Room & Board (fits 4)': 'Shelter',
  'Stable & Feed (per night)': 'Shelter',
};

/// Menzilli olduğu adından belli olan üç silah; kalan üç satır yakın dövüş.
const _ranged = {'Sling', 'Bow', 'Crossbow'};

/// `(+1 Armor)` bonus, `(2 Armor, _bulky_)` eşik. İkisi aynı alana yazılıyor:
/// SRD'nin kendi Shield satırı da `base_ac: 2`yi bonus olarak taşıyor
/// (content.dart `_armorCategory`, min 0 yorumu).
final _armorRe = RegExp(r'\((\+)?(\d+) Armor');
final _damageRe = RegExp(r'\((d\d+) damage');
final _usesRe = RegExp(r'\((\d+) uses');

/// `Alchemist (30/day)` / ` Scholar (20)` → `Alchemist` / `Scholar`.
final _hirelingTitleRe = RegExp(r'\s*\([^)]*\)\s*$');

Map<String, List<Bp>> parseMarketplace(String cairn) {
  final md = readMd('$cairn/second-edition/players-guide/marketplace.md');
  final hirelings = readMd('$cairn/resources/hirelings.md');
  final blocks = _hirelingBlocks(hirelings);
  final out = <String, List<Bp>>{};
  void add(String slug, Bp row) => (out[slug] ??= <Bp>[]).add(row);

  for (final sec in sections(md)) {
    if (sec.title.isEmpty) continue; // önsöz aşağıda `lore` olarak saklanıyor
    final sectionSlug = _sectionSlug[sec.title];
    if (sectionSlug == null) {
      throw StateError('marketplace: bilinmeyen bölüm "${sec.title}"');
    }
    for (final row in tableRows(sec.body)) {
      if (row.length < 2) continue;
      final name = plain(row[0]);
      final gp = num.tryParse(row[1]);
      if (name.isEmpty || gp == null) continue;
      final slug = _rowSlug[name] ?? sectionSlug;
      final raw = '| ${row.join(' | ')} |';
      final extra = blocks.remove(name);
      final description = [
        '## ${sec.title}',
        raw,
        ?extra,
      ].join('\n\n');

      add(slug, switch (slug) {
        'armor' => bpEntity(name, {
            'base_ac': _baseAc(name),
            'cost_gp': gp,
            'description': description,
            'tags': [sec.title],
          }),
        'weapon' => bpEntity(name, {
            'damage_dice': _damageRe.firstMatch(name)?.group(1),
            'is_melee': !_ranged.contains(name.split(' ').first),
            'cost_gp': gp,
            'description': description,
            'tags': [sec.title],
          }),
        'mount' => bpEntity(name, {
            'cost_gp': gp.round(),
            'description': description,
            'tags': [sec.title],
          }),
        'vehicle' => bpEntity(name, {
            // Cairn'in tek araç türü kara aracı; su/hava yolculuğu `service`.
            'vehicle_kind': 'Land',
            'cost_gp': gp.round(),
            'description': description,
            'tags': [sec.title],
          }),
        'service' => bpEntity(name, {
            'kind': _serviceKind[name] ?? 'Other',
            'cost_cp': cpFromGp(gp),
            'description': description,
            'tags': [sec.title],
          }),
        'hireling' => bpEntity(name, {
            'daily_cost_cp': cpFromGp(gp),
            'description': description,
            'tags': [sec.title],
          }),
        // 'adventuring-gear'
        _ => bpEntity(name, {
            'cost_cp': cpFromGp(gp),
            // Kaynak "N uses" demediyse tüketilir demiyor — uydurulmaz.
            'consumable': _usesRe.hasMatch(name) ? true : null,
            'description': description,
            'tags': [sec.title],
          }),
      });
    }
  }

  if (blocks.isNotEmpty) {
    throw StateError('hirelings.md: fiyat listesinde karşılığı olmayan '
        'kayıt(lar) — ${blocks.keys.join(', ')}');
  }

  // İki dosyanın da önsözü tek `lore`'da birebir durur; kural metni
  // ("All prices are in gold pieces") eşya satırlarına kopyalanmaz.
  out['lore'] = [
    bpEntity('Marketplace', {
      'description': 'second-edition/players-guide/marketplace.md',
      'pages': [
        for (final s in [_preamble(md), _preamble(hirelings)])
          if (s.isNotEmpty) s,
      ],
      'tags': ["player's guide"],
    }),
  ];
  return out;
}

/// `(+1 Armor)` → 1 (bonus, Shield konvansiyonu) · `(2 Armor…)` → 16 (eşik).
int? _baseAc(String name) {
  final m = _armorRe.firstMatch(name);
  if (m == null) return null;
  final n = int.parse(m[2]!);
  return m[1] == null ? acForArmor(n) : n;
}

/// H1'den ilk `##`'ye kadarki metin — H1 satırı dahil.
String _preamble(String md) => sections(md).first.body.trim();

/// hirelings.md `## <Ad> (<fiyat>)` bölümleri → ad → başlık + gövde (birebir).
Map<String, String> _hirelingBlocks(String md) => {
      for (final s in sections(md))
        if (s.title.isNotEmpty)
          s.title.replaceFirst(_hirelingTitleRe, '').trim():
              '## ${s.title}\n\n${s.body}',
    };
