import 'dart:convert';

import 'package:dungeon_master_tool/application/providers/entity_provider.dart';
import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bulut sync kaldırıldıktan sonra oyuncuya giden kartın TEK içerik kaynağı
/// `entity_shares.payload_json`. `world_entities` aynası yok; bu round-trip
/// bozulursa oyuncu kartı boş ya da eksik görür, üstelik sessizce.
///
/// Yazan taraf: `entityToRaw` (entity_share_prepare → EntityShareService).
/// Okuyan taraf: `entityFromRaw` (WorldMirrorApplier blob'a yazar, UI okur).
void main() {
  group('entity share payload round-trip', () {
    final full = Entity(
      id: 'e1',
      name: 'Kara Şövalye',
      categorySlug: 'npc',
      source: 'homebrew',
      description: 'Uzrah sarayının muhafızı.',
      images: const ['dmt-asset://a/1.png', 'dmt-public://b/2.jpg'],
      imagePath: 'dmt-asset://a/portrait.png',
      tags: const ['undead', 'boss'],
      dmNotes: 'Oyunculara söyleme: aslında kardeşi.',
      pdfs: const ['dmt-asset://a/statblock.pdf'],
      locationId: 'loc-7',
      fields: const {
        'hp': 84,
        'ac': 18,
        'speed': {'walk': 30, 'fly': 60},
        'resistances': ['cold', 'necrotic'],
        'legendary': true,
        'cr': 7.5,
        'nullable': null,
      },
      packageId: 'pkg-3',
      packageEntityId: 'pe-9',
    );

    /// Gerçek yol: Dart → JSON metni (Supabase kolonu) → Dart.
    Entity throughTheWire(Entity e) {
      final encoded = jsonEncode(entityToRaw(e));
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      return entityFromRaw(e.id, decoded);
    }

    test('survives the wire with every field intact', () {
      expect(throughTheWire(full), equals(full));
    });

    test('a bare entity keeps its defaults rather than picking up nulls', () {
      const bare = Entity(id: 'e2', categorySlug: 'item');
      expect(throughTheWire(bare), equals(bare));
    });

    test('nested field values keep their types, not just their text', () {
      final back = throughTheWire(full);
      expect(back.fields['hp'], isA<int>());
      expect(back.fields['cr'], isA<double>());
      expect(back.fields['legendary'], isTrue);
      expect(back.fields['speed'], {'walk': 30, 'fly': 60});
      expect(back.fields['resistances'], ['cold', 'necrotic']);
    });

    test('linked flag round-trips — it decides who owns the card body', () {
      // payload_json linked kartlar için NULL gönderilir (gövde kurulu
      // paketten gelir), ama bayrağın kendisi kaybolmamalı: kaybolursa
      // paylaşım yolu kartı homebrew sanıp gövdesini kopyalar.
      final linked = full.copyWith(linked: true);
      expect(throughTheWire(linked).linked, isTrue);
      expect(throughTheWire(full).linked, isFalse);
    });
  });
}
