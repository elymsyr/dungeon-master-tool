// Content-quality checks beyond integrity test:
//   - flag entries whose name or description looks miscategorized
//   - basic shape rules (e.g. weapon must have damage_dice; magic-item
//     should not appear in adventuring-gear list)
//   - duplicate names within the same slug
//
// These are heuristics — false positives expected. Failures should
// trigger a manual review against the SRD PDF; if intentional, add an
// override entry below.

import 'package:flutter_test/flutter_test.dart';
import 'package:dungeon_master_tool/domain/entities/schema/builtin/srd_core/srd_core_pack.dart';

void main() {
  group('SRD Core Pack — content validation', () {
    final pack = buildSrdCorePack();
    final entities = pack.entities;

    // Group entities by slug.
    final bySlug = <String, List<MapEntry<String, dynamic>>>{};
    for (final entry in entities.entries) {
      final raw = entry.value as Map;
      final slug = raw['type'] as String? ?? 'unknown';
      bySlug.putIfAbsent(slug, () => []).add(entry);
    }

    test('no duplicate names within the same Tier-1 slug', () {
      final dupes = <String>[];
      for (final slug in bySlug.keys) {
        final seen = <String, int>{};
        for (final e in bySlug[slug]!) {
          final raw = e.value as Map;
          final name = raw['name'] as String? ?? '';
          seen[name] = (seen[name] ?? 0) + 1;
        }
        for (final mapEntry in seen.entries) {
          if (mapEntry.value > 1) {
            dupes.add('$slug → "${mapEntry.key}" appears ${mapEntry.value}×');
          }
        }
      }
      expect(dupes, isEmpty,
          reason: 'duplicate names within a slug pollute the picker UI');
    });

    test('weapon entries carry damage_dice + damage_type_ref', () {
      final missing = <String>[];
      for (final e in (bySlug['weapon'] ?? const [])) {
        final raw = e.value as Map;
        final attrs = (raw['attributes'] as Map?) ?? const {};
        final name = raw['name'] as String? ?? '?';
        if (attrs['damage_dice'] == null || attrs['damage_dice'] == '') {
          missing.add('$name: missing damage_dice');
        }
        if (attrs['damage_type_ref'] == null) {
          missing.add('$name: missing damage_type_ref');
        }
      }
      expect(missing, isEmpty);
    });

    test('armor entries carry base_ac + category_ref', () {
      final missing = <String>[];
      for (final e in (bySlug['armor'] ?? const [])) {
        final raw = e.value as Map;
        final attrs = (raw['attributes'] as Map?) ?? const {};
        final name = raw['name'] as String? ?? '?';
        if (attrs['base_ac'] == null) missing.add('$name: missing base_ac');
        if (attrs['category_ref'] == null) {
          missing.add('$name: missing category_ref');
        }
      }
      expect(missing, isEmpty);
    });

    test('spell entries have valid level + school + classes', () {
      final issues = <String>[];
      for (final e in (bySlug['spell'] ?? const [])) {
        final raw = e.value as Map;
        final attrs = (raw['attributes'] as Map?) ?? const {};
        final name = raw['name'] as String? ?? '?';
        final lvl = attrs['level'];
        if (lvl is! int || lvl < 0 || lvl > 9) {
          issues.add('$name: bad level=$lvl');
        }
        if (attrs['school_ref'] == null) {
          issues.add('$name: missing school_ref');
        }
        final classes = attrs['class_refs'];
        if (classes is! List || classes.isEmpty) {
          issues.add('$name: empty class_refs');
        }
      }
      expect(issues, isEmpty);
    });

    test('monster + animal entries carry stat_block + cr', () {
      final issues = <String>[];
      for (final slug in const ['monster', 'animal']) {
        for (final e in (bySlug[slug] ?? const [])) {
          final raw = e.value as Map;
          final attrs = (raw['attributes'] as Map?) ?? const {};
          final name = raw['name'] as String? ?? '?';
          if (attrs['stat_block'] is! Map) {
            issues.add('$slug/$name: missing stat_block');
          }
          if (attrs['cr'] == null || attrs['cr'] == '') {
            issues.add('$slug/$name: missing cr');
          }
          if (attrs['hp_average'] == null) {
            issues.add('$slug/$name: missing hp_average');
          }
        }
      }
      expect(issues, isEmpty);
    });

    test('magic-item entries carry rarity_ref + magic_category_ref', () {
      final missing = <String>[];
      for (final e in (bySlug['magic-item'] ?? const [])) {
        final raw = e.value as Map;
        final attrs = (raw['attributes'] as Map?) ?? const {};
        final name = raw['name'] as String? ?? '?';
        if (attrs['rarity_ref'] == null) missing.add('$name: missing rarity_ref');
        if (attrs['magic_category_ref'] == null) {
          missing.add('$name: missing magic_category_ref');
        }
      }
      expect(missing, isEmpty);
    });

    test('description text does not look like an action stat-line', () {
      // Heuristic: description that starts with "*Melee Attack Roll:*" or
      // "Melee Attack Roll:" is action-list text, which belongs in a
      // creature-action row, not a top-level description for non-creature
      // categories. Whitelist creatures themselves.
      const creatureSlugs = {
        'monster',
        'animal',
        'creature-action',
      };
      final issues = <String>[];
      for (final slug in bySlug.keys) {
        if (creatureSlugs.contains(slug)) continue;
        for (final e in bySlug[slug]!) {
          final raw = e.value as Map;
          final desc = (raw['description'] as String? ?? '').trim();
          if (desc.startsWith('Melee Attack Roll:') ||
              desc.startsWith('*Melee Attack Roll:*') ||
              desc.startsWith('Ranged Attack Roll:') ||
              desc.startsWith('*Ranged Attack Roll:*')) {
            issues.add('$slug/${raw['name']}: description starts with attack-roll line');
          }
        }
      }
      expect(issues, isEmpty,
          reason:
              'attack-roll text belongs in creature-action rows, not top-level descriptions');
    });
  });
}
