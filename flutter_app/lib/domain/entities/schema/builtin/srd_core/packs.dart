// SRD 5.2.1 Equipment Packs (bodies pp. 96–97). content_refs point to
// `adventuring-gear` rows by name; ammunition + weapons present in the
// canonical pack lists also referenced. content_quantities maps each
// referenced item id → quantity at import time (we encode `(slug, name)`
// → qty here as a parallel narrative until the resolver plumbing is
// extended to rewrite quantities by id).

import '_helpers.dart';

const _slug = 'pack';

Map<String, dynamic> _p({
  required String name,
  required int costGp,
  double? weightLb,
  required Map<String, int> contents, // gear name → quantity
  required String narrative,
}) {
  // content_refs resolves to gear/weapon/etc UUIDs at pack build time.
  final refs = contents.keys
      .map((itemName) => _refForItem(itemName))
      .toList();
  final attrs = <String, dynamic>{
    'cost_gp': costGp,
    'content_refs': refs,
    'contents': narrative,
  };
  if (weightLb != null) attrs['weight_lb'] = weightLb;
  return packEntity(slug: _slug, name: name, attributes: attrs);
}

/// Most pack contents are gear; a handful (Arrows, Bolts) are ammunition.
/// Resolver looks up the row by exact name in the destination slug.
Map<String, String> _refForItem(String name) {
  const ammo = {'Arrows', 'Bolts'};
  if (ammo.contains(name)) return ref('ammunition', name);
  return ref('adventuring-gear', name);
}

/// SRD 5.2.1 equipment packs.
List<Map<String, dynamic>> srdPacks() => [
      _p(
        name: "Burglar's Pack",
        costGp: 16,
        weightLb: 42,
        contents: const {
          'Backpack': 1,
          'Ball Bearings': 1,
          'Bell': 1,
          'Candle': 10,
          'Crowbar': 1,
          'Lantern, Hooded': 1,
          'Oil': 7,
          'Rations': 5,
          'Rope': 1,
          'Tinderbox': 1,
          'Waterskin': 1,
        },
        narrative:
            'Backpack, Ball Bearings, Bell, 10 Candles, Crowbar, Hooded Lantern, 7 flasks of Oil, 5 days of Rations, Rope, Tinderbox, Waterskin.',
      ),
      _p(
        name: "Diplomat's Pack",
        costGp: 39,
        weightLb: 39,
        contents: const {
          'Chest': 1,
          'Clothes, Fine': 1,
          'Ink': 1,
          'Ink Pen': 5,
          'Lamp': 1,
          'Case, Map or Scroll': 2,
          'Oil': 4,
          'Paper': 5,
          'Parchment': 5,
          'Perfume': 1,
          'Tinderbox': 1,
        },
        narrative:
            'Chest, Fine Clothes, Ink, 5 Ink Pens, Lamp, 2 Map or Scroll Cases, 4 flasks of Oil, 5 sheets of Paper, 5 sheets of Parchment, Perfume, Tinderbox.',
      ),
      _p(
        name: "Dungeoneer's Pack",
        costGp: 12,
        weightLb: 55,
        contents: const {
          'Backpack': 1,
          'Caltrops': 1,
          'Crowbar': 1,
          'Oil': 2,
          'Rations': 10,
          'Rope': 1,
          'Tinderbox': 1,
          'Torch': 10,
          'Waterskin': 1,
        },
        narrative:
            'Backpack, Caltrops, Crowbar, 2 flasks of Oil, 10 days of Rations, Rope, Tinderbox, 10 Torches, Waterskin.',
      ),
      _p(
        name: "Entertainer's Pack",
        costGp: 40,
        weightLb: 58,
        contents: const {
          'Backpack': 1,
          'Bedroll': 1,
          'Bell': 1,
          'Lantern, Bullseye': 1,
          'Costume': 3,
          'Mirror': 1,
          'Oil': 8,
          'Rations': 9,
          'Tinderbox': 1,
          'Waterskin': 1,
        },
        narrative:
            'Backpack, Bedroll, Bell, Bullseye Lantern, 3 Costumes, Mirror, 8 flasks of Oil, 9 days of Rations, Tinderbox, Waterskin.',
      ),
      _p(
        name: "Explorer's Pack",
        costGp: 10,
        weightLb: 55,
        contents: const {
          'Backpack': 1,
          'Bedroll': 1,
          'Oil': 2,
          'Rations': 10,
          'Rope': 1,
          'Tinderbox': 1,
          'Torch': 10,
          'Waterskin': 1,
        },
        narrative:
            "Backpack, Bedroll, 2 flasks of Oil, 10 days of Rations, Rope, Tinderbox, 10 Torches, Waterskin.",
      ),
      _p(
        name: "Priest's Pack",
        costGp: 33,
        weightLb: 29,
        contents: const {
          'Backpack': 1,
          'Blanket': 1,
          'Holy Water': 1,
          'Lamp': 1,
          'Rations': 7,
          'Robe': 1,
          'Tinderbox': 1,
        },
        narrative:
            "Backpack, Blanket, Holy Water, Lamp, 7 days of Rations, Robe, Tinderbox.",
      ),
      _p(
        name: "Scholar's Pack",
        costGp: 40,
        weightLb: 22,
        contents: const {
          'Backpack': 1,
          'Book': 1,
          'Ink': 1,
          'Ink Pen': 1,
          'Lamp': 1,
          'Oil': 10,
          'Parchment': 10,
          'Tinderbox': 1,
        },
        narrative:
            "Backpack, Book, Ink, Ink Pen, Lamp, 10 flasks of Oil, 10 sheets of Parchment, Tinderbox.",
      ),
    ];
