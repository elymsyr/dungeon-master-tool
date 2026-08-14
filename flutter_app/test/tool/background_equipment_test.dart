import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/services/entity_ref.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/open5e_import/gate.dart';
import '../../tool/open5e_import/mappers/chargen.dart';

/// **Audit phase B6 — the gear stubs are gone.**
///
/// `_synthGearRef` used to invent an `adventuring-gear` entity for every kit
/// token a background's prose named, so the hard ref always resolved: 159
/// entities with no description, no cost and no weight, 47 of them duplicates,
/// several of them parse artifacts ("pet monkey wearing a tiny fez"). The ref
/// resolved and granted an empty card — the failure looked like success.
///
/// Now a kit token links the **built-in** catalog by soft ref, or ships no item
/// row at all. Two halves have to hold for that to be an improvement rather
/// than a deletion, and this file checks both:
///
///  1. [builtinItem] matches only what it can prove, and
///  2. the ref it emits survives *the reader* — `resolveEntityRef`, which is
///     what the wizard's commit flow calls. This half is the one B6's exit
///     insisted on, because `equipment_step` renders `ref['name']` whether or
///     not the ref resolves: a broken gear link looks perfect in the wizard and
///     silently vanishes on the sheet.
void main() {
  test('a catalog name matches, in the three spellings upstream uses', () {
    expect(builtinItem('Backpack')?.name, 'Backpack');
    expect(builtinItem('backpack')?.name, 'Backpack');
    // plural
    expect(builtinItem('Torches')?.name, 'Torch');
    expect(builtinItem('Candles')?.name, 'Candle');
    // comma name, inverted
    expect(builtinItem('Bullseye Lantern')?.name, 'Lantern, Bullseye');
    expect(builtinItem("Miner's Pick")?.name, "Pick, Miner's");
    // parenthetical qualifier dropped
    expect(builtinItem('Staff')?.name, 'Staff (Arcane Focus)');
    // and the slug follows the card, not the token
    expect(builtinItem("Thieves' Tools")?.slug, 'tool');
    expect(builtinItem('Mule')?.slug, 'mount');
  });

  test('a measure is not the item', () {
    // The tokeniser strips the leading count ("50 sheets of parchment" arrives
    // as "Sheets Of Parchment"), never the unit.
    expect(builtinItem('Bottle Of Ink')?.name, 'Ink');
    expect(builtinItem('Sheets Of Parchment')?.name, 'Parchment');
    expect(builtinItem('Feet Of Rope')?.name, 'Rope');
    expect(builtinItem('Days Rations')?.name, 'Rations');
    expect(builtinItem('Person Tent')?.name, 'Tent');
    // …but only when the tail is itself a card. These must stay misses, or the
    // rule has become a guess.
    for (final token in const [
      'Collection Of Bones',
      'Memento Of Your Destiny',
      'Letter Of Introduction From An Old Teacher',
      'Bottle Of Black Ink',
    ]) {
      expect(builtinItem(token), isNull, reason: token);
    }
  });

  test('background flavour matches nothing — it is not gear', () {
    for (final token in const [
      'Pet Monkey Wearing A Tiny Fez',
      'Stories You Know',
      'Memento Of Your Destiny',
      'Writ Detailing Your Family Tree',
      // A category, not an item: the catalog ships nine artisan's tools and
      // picking one would be a coercion (the B10 precedent).
      "Artisan's Tools",
      'Musical Instrument',
    ]) {
      expect(builtinItem(token), isNull, reason: token);
    }
  });

  test('the emitted soft ref resolves through the reader the wizard uses', () {
    // Stand in for the installed built-in pack: the catalog card a kit token
    // links to, under the name `builtinItem` reports.
    final hit = builtinItem('Torches')!;
    final entities = {
      'gear-1': Entity(
        id: 'gear-1',
        categorySlug: hit.slug,
        name: hit.name,
        fields: const {},
      ),
    };
    expect(resolveEntityRef({'slug': hit.slug, 'name': hit.name}, entities),
        'gear-1');
    // The old shape — a bare id — is still read, so in-pack items keep working.
    expect(resolveEntityRef('gear-1', entities), 'gear-1');
    // And the token that matched nothing never becomes a ref at all, so there
    // is nothing here for the reader to drop silently.
    expect(builtinItem('Pet Monkey Wearing A Tiny Fez'), isNull);
  });

  test('every name builtinItem returns is really in the built-in index', () {
    // The matcher indexes rewritten spellings ("Bullseye Lantern"), so its
    // *output* has to be the catalog's own name or the soft ref dangles.
    final index = builtinNameIndex();
    for (final token in const [
      'Torches',
      'Bullseye Lantern',
      "Miner's Pick",
      'Staff',
      "Thieves' Tools",
      'Mule',
      'Rope',
      'Waterskin',
    ]) {
      final hit = builtinItem(token)!;
      expect(index, contains(nameKey(hit.slug, hit.name)), reason: token);
    }
  });
}
