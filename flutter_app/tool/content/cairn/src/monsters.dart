/// `resources/monsters/*.md` (145 dosya) → `monster` + `creature-action`.
///
/// Gramer (145/145 uyuyor):
/// ```
/// # <Ad>
///
/// <N> HP[, <N> Armor], <N> STR, <N> DEX, <N> WIL[, <silah>…][, _detachment_]
///
/// - <madde>
/// - **<Yetenek>**: <metin>
/// ```
library;

import '../bp.dart';

/// Stat satırı. Armor opsiyonel; WIL'den sonrası (silahlar + `_detachment_`)
/// tek parça olarak yakalanır, virgülleri parantez-farkındalıklı bölünür.
final _statRe = RegExp(r'^(\d+) HP,\s*(?:(\d+) Armor,\s*)?'
    r'(\d+) STR,\s*(\d+) DEX,\s*(\d+) WIL\s*(?:,\s*(.*?))?$');

/// `name (dice[, nitelik])` — dice, ilk virgülden önceki kısım.
final _weaponRe = RegExp(r'^(.*?)\s*\((.*)\)$');

/// Cairn'in hasar/detachment notları — bunlar `traits_md`'ye de girer.
final _mechanicNote = RegExp(r'_(enhanced|impaired|detachment)_');

Map<String, List<Bp>> parseMonsters(String cairn) {
  final monsters = <Bp>[];
  final actions = <Bp>[];

  for (final path in mdFiles('$cairn/resources/monsters')) {
    final lines = readMd(path).split('\n');

    final name = lines
        .firstWhere((l) => l.startsWith('# '),
            orElse: () => throw StateError('başlık yok: $path'))
        .substring(2)
        .trim();

    final statIdx = lines.indexWhere((l) => _statRe.hasMatch(l.trim()));
    if (statIdx < 0) throw StateError('stat satırı yok: $path');
    final stat = lines[statIdx].trim();
    final m = _statRe.firstMatch(stat)!;

    // Madde bloğu: ilk `- ` satırından dosya sonuna kadar birebir (night-cat
    // gibi sarmalanmış maddelerin devam satırları da korunur).
    final bulletIdx = lines.indexWhere((l) => l.startsWith('- '), statIdx);
    final bulletBlock =
        bulletIdx < 0 ? '' : lines.sublist(bulletIdx).join('\n').trimRight();

    final armor = int.tryParse(m[2] ?? '') ?? 0;

    // Kuyruk: `bite (d8), claws (d6+d6), _detachment_`. Parantez içindeki
    // virgüller (`d10, _blast_`) bölme noktası değil.
    var detachment = false;
    final actionRefs = <Map<String, dynamic>>[];
    for (final item in _splitTopLevel(m[6] ?? '')) {
      if (plain(item) == 'detachment') {
        detachment = true;
        continue;
      }
      for (final frag in _splitAlternatives(item)) {
        final w = _weaponRe.firstMatch(frag);
        final attack = _titleCase(w == null ? frag : w[1]!);
        final actionName = '$name — $attack';
        actionRefs.add(ref('creature-action', actionName));
        actions.add(bpEntity(actionName, {
          'action_type': 'Action',
          'is_attack': true,
          'damage_dice': w == null ? null : w[2]!.split(',').first.trim(),
          'description': frag,
        }));
      }
    }

    final traits = _bullets(bulletBlock)
        .where((b) => b.startsWith('- **') || _mechanicNote.hasMatch(b))
        .join('\n');

    monsters.add(bpEntity(name, {
      'hp_average': int.parse(m[1]!),
      'ac': acForArmor(armor),
      'stat_block': {
        'STR': int.parse(m[3]!),
        'DEX': int.parse(m[4]!),
        'WIS': int.parse(m[5]!),
      },
      'description': bulletBlock.isEmpty ? stat : '$stat\n\n$bulletBlock',
      'traits_md': traits.isEmpty ? null : traits,
      'tags_line': detachment ? 'detachment' : null,
      'action_refs': actionRefs.isEmpty ? null : actionRefs,
    }));
  }

  return {'monster': monsters, 'creature-action': actions};
}

/// Parantez derinliği 0 olan virgüllerden böler.
List<String> _splitTopLevel(String s) {
  final out = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == '(') depth++;
    if (c == ')') depth--;
    if (c == ',' && depth == 0) {
      out.add(s.substring(start, i).trim());
      start = i + 1;
    }
  }
  out.add(s.substring(start).trim());
  return out..removeWhere((e) => e.isEmpty);
}

/// ` or ` **iki tarafı da kendi zarını taşıyorsa** iki ayrı saldırıdır
/// (`shortsword (d6) or short bow (d6)`); taşımıyorsa tek saldırının adıdır
/// (`bite or kick (d6)`).
List<String> _splitAlternatives(String item) {
  final parts = item.split(' or ');
  if (parts.length > 1 && parts.every((p) => p.contains('('))) {
    return parts.map((p) => p.trim()).toList();
  }
  return [item];
}

/// Madde bloğunu maddelere böler; devam satırları maddeye yapışık kalır.
List<String> _bullets(String block) {
  final out = <String>[];
  for (final line in block.split('\n')) {
    if (line.startsWith('- ') || out.isEmpty) {
      out.add(line);
    } else {
      out[out.length - 1] = '${out.last}\n$line';
    }
  }
  return out..removeWhere((b) => b.trim().isEmpty);
}

/// `bite or kick` → `Bite or Kick`. Bağlaç küçük kalır.
String _titleCase(String s) => s
    .split(' ')
    .map((w) => w == 'or' || w.isEmpty
        ? w
        : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
