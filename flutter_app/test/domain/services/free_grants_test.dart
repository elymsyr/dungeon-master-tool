import 'package:dungeon_master_tool/domain/entities/entity.dart';
import 'package:dungeon_master_tool/domain/entities/schema/entity_category_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/field_schema.dart';
import 'package:dungeon_master_tool/domain/entities/schema/world_schema.dart';
import 'package:dungeon_master_tool/domain/services/free_field_styles.dart'
    show RestKind;
import 'package:dungeon_master_tool/domain/services/free_grants.dart';
import 'package:dungeon_master_tool/domain/services/template_edit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 7a (docs/free-template/ROADMAP.md): Grants, the Level table, the
/// Pool and the engine that reads them — DESIGN §8.4, §8.5, §8.7, §11.
const _now = '2026-10-12T00:00:00.000Z';

FieldSchema _f(
  String key,
  FieldType type, {
  List<String>? targets,
  bool list = false,
}) => FieldSchema(
  fieldId: key,
  categoryId: 'c',
  fieldKey: key,
  label: key,
  fieldType: type,
  isList: list,
  validation: FieldValidation(allowedTypes: targets),
  createdAt: _now,
  updatedAt: _now,
);

FieldSchema _list(String key, String target) =>
    _f(key, FieldType.relation, targets: [target], list: true);

EntityCategorySchema _cat(
  String slug,
  List<FieldSchema> fields, {
  LevelMode? mode,
  bool player = false,
}) => EntityCategorySchema(
  categoryId: slug,
  schemaId: 's',
  name: slug,
  slug: slug,
  fields: fields,
  levelMode: mode?.name,
  isPlayerCard: player ? true : null,
  createdAt: _now,
  updatedAt: _now,
);

/// [target]: the player card's list for it.
Map<String, dynamic> _card(String id, {String? target}) => {
  '_id': 'g_$id',
  'kind': 'card',
  'card': id,
  if (target != null) 'targets': {'pc': target},
};

Map<String, dynamic> _res(
  String name,
  int? max, {
  String short = 'keep',
  String long = 'fill',
}) => {
  '_id': 'g_$name$max',
  'kind': 'resource',
  'name': name,
  'max': ?max,
  'short': short,
  'long': long,
};

Map<String, dynamic> _text(String id, String value) => {
  '_id': id,
  'kind': 'style',
  'style': 'markdown',
  'label': id,
  'value': value,
};

Map<String, dynamic> _row(
  int level, {
  String text = '',
  List<Map<String, dynamic>> items = const [],
}) => {'_id': 'r$level', 'level': level, 'text': text, 'items': items};

// The template: the player card, Class (separate), Subclass (together),
// Feature (separate, so a granted feature shows it follows the main level
// all the same, V11), Feat, Action, and a Monster that can carry feats.
final _player = _cat('pc', [
  _f('level', FieldType.characterLevel),
  _list('class_refs', 'class'),
  _list('subclass_refs', 'subclass'),
  _list('features', 'feature'),
  _list('actions', 'feature'),
  _list('feats', 'feat'),
  _list('reactions', 'action'),
  _f('auto_resources', FieldType.autoResources),
], player: true);

final _classes = _cat('class', [
  _f('table', FieldType.progressionTable),
  _f('grants', FieldType.grantHolder),
], mode: LevelMode.separate);

final _subclasses = _cat('subclass', [
  _f('table', FieldType.progressionTable),
], mode: LevelMode.together);

final _featureCat = _cat('feature', [
  _f('table', FieldType.progressionTable),
  _f('grants', FieldType.grantHolder),
], mode: LevelMode.separate);

final _feats = _cat('feat', [_f('grants', FieldType.grantHolder)]);
final _actionCat = _cat('action', const []);
final _monster = _cat('monster', [
  _list('feats', 'feat'),
  _f('auto_resources', FieldType.autoResources),
]);

final _categories = [
  _player,
  _classes,
  _subclasses,
  _featureCat,
  _feats,
  _actionCat,
  _monster,
];

Entity _e(String id, String slug, [Map<String, dynamic> fields = const {}]) =>
    Entity(id: id, name: id, categorySlug: slug, fields: fields);

final _entities = {
  for (final e in [
    _e('fighter', 'class', {
      'table': [
        _row(
          1,
          text: 'HP: 10 + CON',
          items: [
            _card('second_wind', target: 'features'),
            _card('weapon_mastery'),
          ],
        ),
        _row(2, items: [_card('action_surge', target: 'features')]),
        _row(3, text: 'Choose a Fighter subclass.'),
        _row(5, items: [_card('extra_attack', target: 'actions')]),
      ],
    }),
    _e('wizard', 'class', {
      'table': [
        _row(1, items: [_res('1st-level slot', 2), _card('arcane_recovery')]),
        _row(3, items: [_res('1st-level slot', 4), _res('2nd-level slot', 2)]),
      ],
    }),
    _e('barbarian', 'class', {
      'table': [
        _row(
          1,
          items: [
            _card('rage', target: 'features'),
            _res('Rage', 2),
            _text('rage_note', 'Rage: one use back on a short rest.'),
          ],
        ),
        _row(3, items: [_res('Rage', 3)]),
        _row(6, items: [_res('Rage', 4)]),
      ],
    }),
    _e('champion', 'subclass', {
      'table': [
        _row(1, items: [_card('improved_critical')]),
        _row(3, text: 'Remarkable Athlete.'),
        _row(4, items: [_card('champion_four')]),
        _row(7, items: [_card('champion_seven')]),
      ],
    }),
    // Granted; its own table follows the main level (V11).
    _e('second_wind', 'feature', {
      'table': [
        _row(1, items: [_res('Second Wind', 2)]),
        _row(4, items: [_res('Second Wind', 3)]),
      ],
    }),
    _e('weapon_mastery', 'feature'),
    _e('action_surge', 'feature'),
    _e('extra_attack', 'feature'),
    _e('rage', 'feature'),
    _e('arcane_recovery', 'feature'),
    _e('improved_critical', 'feature'),
    _e('champion_four', 'feature'),
    _e('champion_seven', 'feature'),
    _e('superiority', 'feat', {
      'grants': [
        _res('Superiority die', 4, short: 'fill', long: 'fill'),
        _text('sup_note', 'The die is a d8.'),
        _card('riposte', target: 'reactions'),
      ],
    }),
    _e('big_superiority', 'feat', {
      'grants': [_res('Superiority die', 6)],
    }),
    _e('riposte', 'action'),
    _e('loop_a', 'feature', {
      'grants': [_card('loop_b')],
    }),
    _e('loop_b', 'feature', {
      'grants': [_card('loop_a')],
    }),
    _e('lonely_feat', 'feat'),
    _e('gives_feat', 'feature', {
      'grants': [_card('lonely_feat')],
    }),
  ])
    e.id: e,
};

GrantContext _ctx([EntityCategorySchema? carrier]) => GrantContext(
  carrier: carrier ?? _player,
  categories: _categories,
  entities: _entities,
);

List<String> _ids(Object? v) => [for (final r in (v as List? ?? const [])) '$r'];

/// The player adds [id] to [list] (DESIGN §11.5).
GrantChange _add(Map<String, dynamic> f, String list, String id) =>
    settleGrants(f, {
      ...f,
      list: [...?(f[list] as List?), id],
    }, _ctx());

void main() {
  group('Aria (DESIGN §11.9, word for word)', () {
    test('Fighter, level up ×2 with Wizard, Champion', () {
      // Character created: level 1, blank.
      var f = <String, dynamic>{'level': 1};

      // Fighter joins the Class list: row 1 runs.
      var c = _add(f, 'class_refs', 'fighter');
      f = c.fields;
      expect(_ids(f['features']), ['second_wind', 'weapon_mastery']);
      expect(summarize(c).reads.map((r) => r.text), ['HP: 10 + CON']);
      expect(c.after.reached['fighter'], 1);

      // Level up: the only class is picked by itself (V13).
      var groups = levelUpGroups(f, _ctx());
      expect(groups.single.cards, [(id: 'fighter', level: 1)]);
      c = settleGrants(
        f,
        levelUp(f, _ctx(), picked: {'class': 'fighter'}),
        _ctx(),
      );
      f = c.fields;
      expect(f['level'], 2);
      expect([for (final a in c.added) a.cardId], ['action_surge']);
      expect(_ids(f['features']).last, 'action_surge');

      // Level up, Wizard added: it starts at 1; its row 1 slot is in the
      // Pool, following the Wizard's level.
      c = settleGrants(
        f,
        levelUp(f, _ctx(), added: {'class': 'wizard'}),
        _ctx(),
      );
      f = c.fields;
      expect(f['level'], 3);
      expect(cardLevelsOf(f), {'fighter': 2, 'wizard': 1});
      final slot = c.after.resources.firstWhere(
        (r) => r.name == '1st-level slot',
      );
      expect(slot.max, 2);
      expect(summarize(c).resources.single, (
        name: '1st-level slot',
        from: 0,
        to: 2,
      ));

      // Level up, Fighter picked: Fighter 3 says "choose a subclass".
      c = settleGrants(
        f,
        levelUp(f, _ctx(), picked: {'class': 'fighter'}),
        _ctx(),
      );
      f = c.fields;
      expect(f['level'], 4);
      expect(cardLevelsOf(f), {'fighter': 3, 'wizard': 1});
      expect(summarize(c).reads.map((r) => r.text), [
        'Choose a Fighter subclass.',
      ]);
      // The Wizard is still 1: its slot stays at 2 (D26).
      expect(
        c.after.resources.firstWhere((r) => r.name == '1st-level slot').max,
        2,
      );

      // Champion (together) joins at the main level: rows 1–4 run (D10).
      c = _add(f, 'subclass_refs', 'champion');
      f = c.fields;
      expect(c.after.reached['champion'], 4);
      expect([for (final a in c.added) a.cardId], [
        'improved_critical',
        'champion_four',
      ]);
    });
  });

  group('levels (DESIGN §11.3)', () {
    test('Barbarian 8: Rage from the same card replaces, 8 → 4 (D39)', () {
      final r = computeGrants({
        'level': 8,
        'class_refs': ['barbarian'],
        cardLevelsKey: {'barbarian': 8},
      }, _ctx());
      final rage = r.resources.where((x) => x.name == 'Rage');
      expect(rage.single.max, 4);
    });

    test('a separate card\'s row resources follow its own level', () {
      final r = computeGrants({
        'level': 9,
        'class_refs': ['fighter', 'wizard'],
        cardLevelsKey: {'fighter': 6, 'wizard': 3},
      }, _ctx());
      expect(r.resources.map((x) => (x.name, x.max)), [
        ('1st-level slot', 4),
        ('2nd-level slot', 2),
      ]);
    });

    test('a granted card follows the main level (V11), even when its '
        'category is separate', () {
      final r = computeGrants({
        'level': 4,
        'class_refs': ['fighter'],
        'features': ['second_wind'],
        cardLevelsKey: {'fighter': 1},
        grantedKey: {
          'second_wind': {'from': 'fighter', 'level': 1},
        },
      }, _ctx());
      expect(r.reached['second_wind'], 4);
      expect(r.resources.single.max, 3);
      // …and a level up never asks about it.
      expect(
        levelUpGroups({
          'class_refs': ['fighter'],
          'features': ['second_wind'],
          grantedKey: {
            'second_wind': {'from': 'fighter'},
          },
        }, _ctx()).single.cards.map((c) => c.id),
        ['fighter'],
      );
    });

    test('a together card added later reads every row to the main level '
        '(D10)', () {
      final r = computeGrants({
        'level': 7,
        'subclass_refs': ['champion'],
      }, _ctx());
      expect(r.reached['champion'], 7);
      expect(r.cards.map((g) => g.cardId), [
        'improved_critical',
        'champion_four',
        'champion_seven',
      ]);
    });

    test('a level up with no separate card asks nothing (V13)', () {
      expect(levelUpGroups({'level': 3}, _ctx()), isEmpty);
      expect(levelUp({'level': 3}, _ctx())['level'], 4);
    });

    test('no Level field: Level tables are not read (D34, V30)', () {
      final noLevel = _cat('pc', [
        _list('class_refs', 'class'),
        _list('features', 'feature'),
      ], player: true);
      final r = computeGrants({
        'class_refs': ['fighter'],
      }, _ctx(noLevel));
      expect(r.reached, isEmpty);
      expect(r.cards, isEmpty);
    });
  });

  group('the target list (V10)', () {
    test('the chosen list, else the first for its category', () {
      final r = computeGrants({
        'level': 5,
        'class_refs': ['fighter'],
        cardLevelsKey: {'fighter': 5},
      }, _ctx());
      String? into(String id) =>
          r.cards.firstWhere((g) => g.cardId == id).listKey;
      // Chosen.
      expect(into('extra_attack'), 'actions');
      expect(into('action_surge'), 'features');
      // Not chosen: the first list naming the category.
      expect(into('weapon_mastery'), 'features');
    });

    test('no list takes it: the Pool, under the giver', () {
      final r = computeGrants({
        'level': 1,
        'features': ['gives_feat'],
      }, _ctx(_cat('pc', [
        _f('level', FieldType.characterLevel),
        _list('features', 'feature'),
        _f('auto_resources', FieldType.autoResources),
      ], player: true)));
      final entry = r.entries.single;
      expect((entry.cardId, entry.fromId), ('lonely_feat', 'gives_feat'));
      expect(r.homeless, isEmpty);
    });

    test('no list and no Pool: nowhere to go', () {
      final c = _cat('pc', [
        _f('level', FieldType.characterLevel),
        _list('features', 'feature'),
      ], player: true);
      final change = settleGrants(
        {'level': 1},
        {
          'level': 1,
          'features': ['gives_feat'],
        },
        _ctx(c),
      );
      expect(change.after.homeless, ['lonely_feat']);
      expect(summarize(change).homeless, ['lonely_feat']);
    });

    test('a chosen list that is gone or does not take the card: the Pool', () {
      GrantResult r(String target) => computeGrants({
        'feats': ['wrong_target'],
      }, GrantContext(
        carrier: _player,
        categories: _categories,
        entities: {
          ..._entities,
          'wrong_target': _e('wrong_target', 'feat', {
            'grants': [_card('riposte', target: target)],
          }),
        },
      ));
      // Features takes no actions; a deleted list is not there at all.
      // Reactions would take it, but the owner did not pick it.
      for (final target in ['features', 'deleted']) {
        expect(r(target).cards.single.listKey, isNull);
        expect(r(target).entries.single.cardId, 'riposte');
      }
    });

    test('each carrier category has its own list for the card', () {
      List<FieldSchema> lists() => [
        _list('feats', 'feat'),
        _list('traits', 'action'),
        _list('moves', 'action'),
      ];
      final beast = _cat('beast', lists());
      final entities = {
        ..._entities,
        'tough': _e('tough', 'feat', {
          'grants': [
            {
              '_id': 'g',
              'kind': 'card',
              'card': 'riposte',
              'targets': {'pc': 'reactions', 'beast': 'moves'},
            },
          ],
        }),
      };
      String? into(EntityCategorySchema carrier) =>
          computeGrants(
                {
                  'feats': ['tough'],
                },
                GrantContext(
                  carrier: carrier,
                  categories: [..._categories, beast],
                  entities: entities,
                ),
              ).cards.single.listKey;
      expect(into(_player), 'reactions');
      expect(into(beast), 'moves');
      // A carrier not named: the first list for the card's category.
      expect(into(_cat('bird', lists())), 'traits');
      expect(
        GrantItem.fromJson(
          entities['tough']!.fields['grants'][0] as Map<String, dynamic>,
        ).toJson()['targets'],
        {'pc': 'reactions', 'beast': 'moves'},
      );
    });
  });

  group('Grants (DESIGN §8.5)', () {
    test('a feat: the card into its list, resource and text into the Pool',
        () {
      final c = _add({'level': 1}, 'feats', 'superiority');
      expect(_ids(c.fields['reactions']), ['riposte']);
      expect(grantLabelsOf(c.fields)['riposte'], (
        from: 'superiority',
        level: null,
      ));
      expect(c.after.resources.single.name, 'Superiority die');
      expect(c.after.entries.single.item.value, 'The die is a d8.');
      expect(c.after.entries.single.fromId, 'superiority');
    });

    test('without the list the card goes to the Pool too', () {
      final noReactions = _cat('pc', [
        _f('level', FieldType.characterLevel),
        _list('feats', 'feat'),
        _f('auto_resources', FieldType.autoResources),
      ], player: true);
      final r = computeGrants({
        'feats': ['superiority'],
      }, _ctx(noReactions));
      expect(
        r.entries.where((e) => e.cardId != null).single.cardId,
        'riposte',
      );
    });

    test('V31: Grants never carry the card\'s own structures', () {
      for (final t in [
        FieldType.grantHolder,
        FieldType.progressionTable,
        FieldType.autoResources,
        FieldType.combatStats,
        FieldType.characterLevel,
      ]) {
        expect(grantItemStyles, isNot(contains(t)));
      }
      final r = computeGrants({
        'feats': ['bad'],
      }, GrantContext(
        carrier: _player,
        categories: _categories,
        entities: {
          'bad': _e('bad', 'feat', {
            'grants': [
              {'_id': 'x', 'kind': 'style', 'style': 'progressionTable'},
              {'_id': 'y', 'kind': 'style', 'style': 'combatStats'},
            ],
          }),
        },
      ));
      expect(r.entries, isEmpty);
    });

    test('A ↔ B: no loop, each once', () {
      final c = _add({'level': 1}, 'features', 'loop_a');
      expect(_ids(c.fields['features']), ['loop_a', 'loop_b']);
      expect(c.added.single.cardId, 'loop_b');
    });

    test('two givers, one card: added once', () {
      final twice = {
        ..._entities,
        'g1': _e('g1', 'feat', {
          'grants': [_card('riposte')],
        }),
        'g2': _e('g2', 'feat', {
          'grants': [_card('riposte')],
        }),
      };
      final ctx = GrantContext(
        carrier: _player,
        categories: _categories,
        entities: twice,
      );
      final c = settleGrants(
        {},
        {
          'feats': ['g1', 'g2'],
        },
        ctx,
      );
      expect(_ids(c.fields['reactions']), ['riposte']);
    });

    test('a granted card the player removed is not granted again', () {
      var f = _add({'level': 1}, 'class_refs', 'fighter').fields;
      f = {...f, 'features': ['weapon_mastery']};
      final c = settleGrants(
        f,
        levelUp(f, _ctx(), picked: {'class': 'fighter'}),
        _ctx(),
      );
      expect(_ids(c.fields['features']), ['weapon_mastery', 'action_surge']);
    });
  });

  group('the Pool (DESIGN §8.7)', () {
    test('same name from different cards: the larger max (D39)', () {
      final r = computeGrants({
        'feats': ['superiority', 'big_superiority'],
      }, _ctx());
      expect(r.resources.single.max, 6);
      expect(r.resources.single.fromId, 'big_superiority');
    });

    test('a new resource starts full; a lower max lowers it (V32)', () {
      const r = PoolResource(name: 'Rage', fromId: 'b', max: 3);
      expect(poolResourceValue(r, null).current, 3);
      expect(
        poolResourceValue(r, {
          'Rage': {'current': 5},
        }).current,
        3,
      );
      expect(
        poolResourceValue(r, {
          'Rage': {'current': 1},
        }).current,
        1,
      );
    });

    test('a max left open is the player\'s (D30)', () {
      const r = PoolResource(name: 'Inspiration', fromId: 'b');
      final v = poolResourceValue(r, {
        'Inspiration': {'current': 1, 'max': 3},
      });
      expect((v.current, v.max, v.playerMax), (1, 3, true));
    });

    test('the giver leaves: its items go, the current value stays (V29)', () {
      var f = <String, dynamic>{
        'feats': ['superiority'],
        'auto_resources': poolStoredWith(null, 'Superiority die', current: 1),
      };
      expect(computeGrants(f, _ctx()).resources, isNotEmpty);
      f = withoutCards(f, ['superiority'], _ctx());
      final r = computeGrants(f, _ctx());
      expect(r.resources, isEmpty);
      expect(r.entries, isEmpty);
      // Back again: where it was.
      f = {...f, 'feats': ['superiority']};
      final res = computeGrants(f, _ctx()).resources.single;
      expect(poolResourceValue(res, f['auto_resources']).current, 1);
    });

    test('rests apply to the Pool\'s resources (DESIGN §12.3)', () {
      final f = {
        'feats': ['superiority'],
        'auto_resources': poolStoredWith(null, 'Superiority die', current: 0),
      };
      final r = computeGrants(f, _ctx());
      expect(
        poolAfterRest(r, f['auto_resources'], RestKind.short)?['Superiority die'],
        {'current': 4},
      );
      // Full already: nothing to write.
      expect(poolAfterRest(r, null, RestKind.long), isNull);
    });

    test('taken out by the player: not granted at all; put back', () {
      // Superiority's resource and text; Riposte has no list here.
      final c = _cat('pc', [
        _f('level', FieldType.characterLevel),
        _list('feats', 'feat'),
        _f('auto_resources', FieldType.autoResources),
      ], player: true);
      var f = <String, dynamic>{
        'feats': ['superiority'],
      };
      final before = computeGrants(f, _ctx(c));
      expect(before.resources.single.name, 'Superiority die');
      expect(before.entries.map((e) => e.cardId ?? e.item.id), [
        'sup_note',
        'riposte',
      ]);
      var pool = poolWithRemoved(null, 'Superiority die');
      for (final e in before.entries) {
        pool = poolWithRemoved(pool, poolEntryKey(e.fromId, e.item));
      }
      f = {...f, 'auto_resources': pool};
      final after = computeGrants(f, _ctx(c));
      expect(after.resources, isEmpty);
      expect(after.entries, isEmpty);
      expect(after.cards, isEmpty);
      expect(poolAfterRest(after, pool, RestKind.long), isNull);
      f = {...f, 'auto_resources': poolWithRemoved(pool, null)};
      expect(computeGrants(f, _ctx(c)).entries, hasLength(2));
    });
  });

  group('taking back (V12)', () {
    test('the giver removed: its labelled cards are offered', () {
      var f = _add({'level': 1}, 'class_refs', 'wizard').fields;
      expect(_ids(f['features']), ['arcane_recovery']);
      final c = settleGrants(
        f,
        withoutCards(f, ['wizard'], _ctx()),
        _ctx(),
      );
      expect(c.stale, ['arcane_recovery']);
      // Offered, not removed.
      expect(_ids(c.fields['features']), ['arcane_recovery']);
      // Its Pool items went by themselves.
      expect(c.after.resources, isEmpty);
    });

    test('a level lowered by hand: rows no longer reached', () {
      var f = <String, dynamic>{'level': 1};
      f = _add(f, 'class_refs', 'fighter').fields;
      f = settleGrants(
        f,
        levelUp(f, _ctx(), picked: {'class': 'fighter'}),
        _ctx(),
      ).fields;
      final c = settleGrants(
        f,
        {
          ...f,
          cardLevelsKey: {'fighter': 1},
        },
        _ctx(),
      );
      expect(c.stale, ['action_surge']);
    });

    test('labels and card levels of cards gone from the lists go', () {
      var f = _add({'level': 1}, 'class_refs', 'fighter').fields;
      f = withoutCards(f, ['fighter', 'second_wind'], _ctx());
      expect(cardLevelsOf(f), isEmpty);
      expect(grantLabelsOf(f).keys, ['weapon_mastery']);
    });
  });

  group('single card links (Faz 7b)', () {
    // The player card with its class as one card, beside the lists.
    final ctx = GrantContext(
      carrier: _player.copyWith(
        fields: [
          ..._player.fields,
          _f('main_class', FieldType.relation, targets: ['class']),
        ],
      ),
      categories: _categories,
      entities: _entities,
    );

    test('its card grants like a listed one, read to the main level', () {
      final c = settleGrants(const {}, {'level': 2, 'main_class': 'fighter'}, ctx);
      // Separate, but one card has no level of its own.
      expect(c.after.reached['fighter'], 2);
      expect(
        _ids(c.fields['features']),
        containsAll(['second_wind', 'weapon_mastery', 'action_surge']),
      );
      expect(c.fields['main_class'], 'fighter');
    });

    test('another card linked: what the old one granted is offered', () {
      final f = settleGrants(const {}, {'level': 1, 'main_class': 'fighter'}, ctx)
          .fields;
      final c = settleGrants(f, {...f, 'main_class': 'wizard'}, ctx);
      expect(c.stale, containsAll(['second_wind', 'weapon_mastery']));
      expect(_ids(c.fields['features']), contains('arcane_recovery'));
      // Offered, not removed: Second Wind's own pool stays with it.
      expect(
        c.after.resources.map((r) => r.name),
        ['Second Wind', '1st-level slot'],
      );
    });
  });

  group('card carrier (V30)', () {
    test('a monster takes a feat: the card list, the Pool; no levels', () {
      final c = settleGrants(
        {},
        {
          'feats': ['superiority'],
        },
        _ctx(_monster),
      );
      // The monster has no Reactions list: Riposte is in its Pool.
      expect(c.after.entries.map((e) => e.cardId ?? e.item.id), [
        'sup_note',
        'riposte',
      ]);
      expect(c.after.resources.single.name, 'Superiority die');
      expect(mainLevelOf(_monster, c.fields), isNull);
    });
  });

  group('dependency warnings (D34, DESIGN §10.1)', () {
    WorldSchema schema(List<EntityCategorySchema> cats) => WorldSchema(
      schemaId: 's',
      name: 's',
      freeRootId: 's',
      categories: cats,
      createdAt: _now,
      updatedAt: _now,
    );
    final bare = _cat('pc', [_list('feats', 'feat')], player: true);

    test('a Level table needs the Level, Grants need the Pool', () {
      expect(missingOwnFields(schema([bare, _classes])), [
        FieldType.characterLevel,
        FieldType.autoResources,
      ]);
      expect(missingOwnFields(schema([bare, _subclasses])), [
        FieldType.characterLevel,
      ]);
      expect(missingOwnFields(schema([_player, _classes])), isEmpty);
    });

    test('[Add] puts the field on the player card, once', () {
      var s = schema([bare, _feats]);
      s = addOwnField(
        s,
        FieldType.autoResources,
        id: 'pool',
        label: 'Pool',
        now: _now,
      );
      final card = s.categories.first;
      final pool = card.fields.singleWhere(
        (f) => f.fieldType == FieldType.autoResources,
      );
      expect(pool.fieldKey, 'auto_resources');
      expect(missingOwnFields(s), isEmpty);
      expect(
        addOwnField(
          s,
          FieldType.autoResources,
          id: 'x',
          label: 'x',
          now: _now,
        ),
        s,
      );
    });

    test('the users a deletion lists', () {
      final s = schema([_player, _classes, _subclasses, _feats]);
      expect(ownFieldUsers(s, FieldType.characterLevel), [
        'class',
        'subclass',
      ]);
      expect(ownFieldUsers(s, FieldType.autoResources), [
        'class',
        'subclass',
        'feat',
      ]);
    });

    test('one Level table and one Pool per category; any category', () {
      expect(canAddFieldType(_classes, FieldType.progressionTable), isFalse);
      expect(canAddFieldType(_feats, FieldType.progressionTable), isTrue);
      expect(canAddFieldType(_feats, FieldType.autoResources), isTrue);
      expect(canAddFieldType(_monster, FieldType.autoResources), isFalse);
      expect(canAddFieldType(_feats, FieldType.grantHolder), isTrue);
      // The Level too, on any category (no longer the player card's alone).
      expect(canAddFieldType(_feats, FieldType.characterLevel), isTrue);
      expect(canAddFieldType(_player, FieldType.characterLevel), isFalse);
    });
  });

  group('shapes', () {
    test('items and rows round-trip', () {
      for (final m in [
        _card('x', target: 'feats'),
        _res('Rage', 2, short: 'fill'),
        _res('Open', null),
        _text('t', 'hi'),
      ]) {
        expect(GrantItem.fromJson(m).toJson(), m);
      }
      final row = _row(3, text: 'x', items: [_card('y')]);
      expect(LevelRow.fromJson(row).toJson(), row);
    });

    test('rows read in level order', () {
      expect(levelRowsOf([_row(5), _row(1), _row(3)]).map((r) => r.level), [
        1,
        3,
        5,
      ]);
    });
  });
}
