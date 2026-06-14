// Dev harness for the offline pack-conversion core
// (`tool/convert_packs_v3.dart`; roadmap PR-3.0 / content-convert §8).
//
// Run from the Flutter project root (`flutter_app/`):
//
//     dart run tool/convert_packs_v3.dart_harness   # (typo-safe: see below)
//     dart run tool/convert_packs_v3_harness.dart
//
// It drives the pure conversion core (no dart:io) and asserts:
//   * a feat assembles intro ⊕ `### Effects` ⊕ `### Prerequisites` in §4.1
//     order, with parametric rows rendered as bold-led paragraphs;
//   * the report tallies mapped / noted / dropped / prereqs per content-convert
//     §6/§8 (parametric → mapped, combat/unknown → noted, empty → dropped);
//   * a magic item's bare-string `effects` is preserved as `### Properties`
//     prose (a `noted` row) and the intro is not duplicated;
//   * open5e `prereq_clauses` (`type`-discriminated) normalise into the engine's
//     closed clause vocabulary (ability_min / character_level / spellcasting /
//     armor_proficiency);
//   * the conversion is idempotent: an already-`"format": 3` card is skipped and
//     a second `convertPack` run is byte-identical.
//
// Verification gate for the slice; NOT part of the app build.
//
// ignore_for_file: avoid_print
library;

import 'dart:convert';

import 'convert_packs_v3.dart';

int _checks = 0;
int _failures = 0;

void expect(String name, bool ok) {
  _checks++;
  if (!ok) _failures++;
  print('${ok ? 'PASS' : 'FAIL'}  $name');
}

void main() {
  _feat();
  _idempotency();
  _magicItemProse();
  _prereqVocabulary();
  _packRoundTrip();

  print('');
  print(_failures == 0
      ? 'Overall: PASS ($_checks checks)'
      : 'Overall: FAIL ($_failures of $_checks checks failed)');
}

// ── 1. Feat: assembly + disposition tally ──────────────────────────────────

void _feat() {
  print('— Feat assembly + report —');
  final entity = <String, dynamic>{
    'name': 'Athlete',
    'type': 'feat',
    'description': 'You have undergone extensive physical training.',
    'attributes': <String, dynamic>{
      'description': 'You have undergone extensive physical training.',
      'effects': <dynamic>[
        <String, dynamic>{'kind': 'ability_score_bonus', 'ability': 'STR', 'value': 1},
        <String, dynamic>{'kind': 'speed_bonus', 'value': 5},
        <String, dynamic>{'kind': 'reroll_on_falling'}, // out-of-scope → noted
      ],
      'prereq_clauses': <dynamic>[
        <String, dynamic>{
          'type': 'ability_min',
          'ability_options': <dynamic>[
            <String, dynamic>{'_lookup': 'ability', 'name': 'Strength'},
          ],
          'min_score': 13,
        },
      ],
    },
  };
  final report = ConversionReport(packName: 'test');
  final converted = convertEntity(entity, report);
  final desc = entity['description'] as String;

  expect('feat converted', converted);
  expect('mapped == 2 (asi + speed)', report.mapped == 2);
  expect('noted == 1 (reroll)', report.noted == 1);
  expect('dropped == 0', report.dropped == 0);
  expect('prereqs == 1', report.prereqs == 1);
  // slice 4: mapped rows also write their v3 data fields.
  final attrs = entity['attributes'] as Map;
  expect('field writes == 2 (asi + speed)', report.fieldWrites == 2);
  expect('ability_bonuses row written',
      attrs['ability_bonuses'] is List && (attrs['ability_bonuses'] as List).length == 1);
  expect('speed_bonus scalar written', attrs['speed_bonus'] == 5);
  expect('reroll wrote no data field', attrs.containsKey('extra_attacks') == false);
  expect('intro kept at top',
      desc.startsWith('You have undergone extensive physical training.'));
  expect('has ### Prerequisites', desc.contains('### Prerequisites'));
  expect('prereq bullet "- Strength 13+"', desc.contains('- Strength 13+'));
  expect('has ### Effects', desc.contains('### Effects'));
  expect('asi paragraph', desc.contains('**Ability Score Increase.**'));
  expect('speed paragraph', desc.contains('**Speed.**'));
  expect('reroll humanized (not dropped)',
      desc.contains('Reroll On Falling') || desc.toLowerCase().contains('reroll'));
  // §4.1 order: Prerequisites before Effects.
  expect('Prerequisites precede Effects',
      desc.indexOf('### Prerequisites') < desc.indexOf('### Effects'));
  expect('entity stamped format 3',
      (entity['attributes'] as Map)['format'] == 3);
}

// ── 2. Idempotency ─────────────────────────────────────────────────────────

void _idempotency() {
  print('');
  print('— Idempotency (skip already-format-3) —');
  final entity = <String, dynamic>{
    'name': 'Tough',
    'type': 'feat',
    'description': 'Your hit point maximum increases.',
    'attributes': <String, dynamic>{
      'effects': <dynamic>[
        <String, dynamic>{'kind': 'hp_bonus_per_level', 'value': 2},
      ],
    },
  };
  final r1 = ConversionReport(packName: 't');
  convertEntity(entity, r1);
  final afterFirst = jsonEncode(entity);

  final r2 = ConversionReport(packName: 't');
  final secondConverted = convertEntity(entity, r2);
  final afterSecond = jsonEncode(entity);

  expect('second run skipped', !secondConverted);
  expect('skipped == 1', r2.skipped == 1);
  expect('no new mapped on skip', r2.mapped == 0);
  expect('entity byte-identical after re-run', afterFirst == afterSecond);
}

// ── 3. Magic item: bare-string effects → Properties prose ──────────────────

void _magicItemProse() {
  print('');
  print('— Magic item prose (string effects) —');
  final entity = <String, dynamic>{
    'name': 'Cloak of Protection',
    'type': 'magic-item',
    'description': 'A fine traveling cloak.',
    'attributes': <String, dynamic>{
      'effects': 'While wearing this cloak you gain a +1 bonus to AC and saving '
          'throws.',
    },
  };
  final report = ConversionReport(packName: 't');
  convertEntity(entity, report);
  final desc = entity['description'] as String;

  expect('magic-item noted == 1 (prose)', report.noted == 1);
  expect('magic-item mapped == 0', report.mapped == 0);
  expect('has ### Properties', desc.contains('### Properties'));
  expect('prose preserved', desc.contains('+1 bonus to AC'));
  expect('intro at top', desc.startsWith('A fine traveling cloak.'));
}

// ── 4. Prereq vocabulary normalisation ─────────────────────────────────────

void _prereqVocabulary() {
  print('');
  print('— Prereq vocabulary bridge —');
  String render(Map<String, dynamic> clause) {
    final e = <String, dynamic>{
      'name': 'X',
      'type': 'feat',
      'description': '',
      'attributes': <String, dynamic>{
        'prereq_clauses': <dynamic>[clause],
      },
    };
    convertEntity(e, ConversionReport(packName: 't'));
    return e['description'] as String;
  }

  expect('armor_proficiency → "Medium armor"',
      render(<String, dynamic>{'type': 'armor_proficiency', 'category': 'Medium'})
          .contains('Proficiency with Medium armor'));
  expect('character_level → "Character level 5+"',
      render(<String, dynamic>{'type': 'character_level', 'min_level': 5})
          .contains('Character level 5+'));
  expect('spellcasting → cast a spell',
      render(<String, dynamic>{'type': 'spellcasting'})
          .contains('The ability to cast at least one spell'));
  expect('ability_min via ability_options ref',
      render(<String, dynamic>{
        'type': 'ability_min',
        'ability_options': <dynamic>[
          <String, dynamic>{'_lookup': 'ability', 'name': 'Constitution'},
        ],
        'min_score': 13,
      }).contains('Constitution 13+'));
  expect('unknown clause not dropped',
      render(<String, dynamic>{'type': 'phase_of_moon', 'value': 'full'})
          .contains('### Prerequisites'));
}

// ── 5. convertPack round-trip + idempotency ────────────────────────────────

void _packRoundTrip() {
  print('');
  print('— convertPack round-trip —');
  Map<String, dynamic> freshPack() => <String, dynamic>{
        'package_name': 'demo',
        'metadata': <String, dynamic>{'title': 'Demo'},
        'entities': <String, dynamic>{
          'id-1': <String, dynamic>{
            'name': 'Half-Elf',
            'type': 'species',
            'description': 'Caught between two worlds.',
            'attributes': <String, dynamic>{
              'granted_modifiers': <dynamic>[
                <String, dynamic>{'kind': 'ability_score_bonus', 'ability': 'CHA', 'value': 2},
              ],
            },
          },
          'id-2': <String, dynamic>{
            'name': 'Torch',
            'type': 'adventuring-gear',
            'description': 'Burns for 1 hour.',
            'attributes': <String, dynamic>{},
          },
        },
      };

  final pack = freshPack();
  final report = convertPack(pack);
  expect('pack converted 2', report.converted == 2);
  expect('pack metadata stamped',
      (pack['metadata'] as Map)['format'] == 3);
  expect('species mapped 1', report.mapped == 1);

  final afterFirst = jsonEncode(pack);
  final report2 = convertPack(pack);
  final afterSecond = jsonEncode(pack);
  expect('second pack run skips all', report2.skipped == 2);
  expect('second pack run converts none', report2.converted == 0);
  expect('pack byte-identical after re-run', afterFirst == afterSecond);

  final json = report.toJson();
  expect('report effects block present',
      (json['effects'] as Map).containsKey('mapped'));
  expect('report mapped_kinds has ability_score_bonus',
      (json['mapped_kinds'] as Map).containsKey('ability_score_bonus'));
}
