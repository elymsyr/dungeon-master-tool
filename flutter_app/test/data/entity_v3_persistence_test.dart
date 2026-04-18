import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:dungeon_master_tool/data/database/app_database.dart';
import 'package:dungeon_master_tool/domain/entities/applied_effect.dart';
import 'package:dungeon_master_tool/domain/entities/choice_state.dart';
import 'package:dungeon_master_tool/domain/entities/resource_state.dart';
import 'package:dungeon_master_tool/domain/entities/schema/event_kind.dart';
import 'package:dungeon_master_tool/domain/entities/turn_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('migration v6 creates V3 columns with defaults', () async {
    // Schema creates all; verify defaults work.
    await db.campaignDao.createCampaign(const CampaignsCompanion(
      id: Value('c1'),
      worldName: Value('World'),
    ));
    await db.entityDao.createEntity(const EntitiesCompanion(
      id: Value('e1'),
      campaignId: Value('c1'),
      categorySlug: Value('player'),
      name: Value('Test'),
    ));
    final row = await db.entityDao.getById('e1');
    expect(row, isNotNull);
    expect(row!.resourcesJson, '{}');
    expect(row.choicesJson, '{}');
    expect(row.turnStateJson, '{}');
    expect(row.activeEffectsJson, '[]');
  });

  test('V3 JSON round-trip preserves full state', () async {
    const resources = {
      'spell_slot_3': ResourceState(
        resourceKey: 'spell_slot_3',
        current: 1,
        max: 2,
        refreshRule: RefreshRule.longRest,
      ),
      'rage_uses': ResourceState(
        resourceKey: 'rage_uses',
        current: 2,
        max: 3,
      ),
    };
    const choices = {
      'fighting_style': ChoiceState(
        choiceKey: 'fighting_style',
        chosenValue: 'archery',
      ),
    };
    const turnState = TurnState(
      entityId: 'e1',
      roundNumber: 4,
      actionUsed: true,
      criticalRangeMin: 19,
    );
    const effects = [
      AppliedEffect(
        effectId: 'bless',
        requiresConcentration: true,
        duration: DurationSpec.rounds(10),
      ),
    ];

    final resourcesJson = jsonEncode(
      resources.map((k, v) => MapEntry(k, v.toJson())),
    );
    final choicesJson = jsonEncode(
      choices.map((k, v) => MapEntry(k, v.toJson())),
    );
    final turnStateJson = jsonEncode(turnState.toJson());
    final effectsJson =
        jsonEncode(effects.map((e) => e.toJson()).toList());

    await db.campaignDao.createCampaign(const CampaignsCompanion(
      id: Value('c1'),
      worldName: Value('World'),
    ));
    await db.entityDao.createEntity(EntitiesCompanion(
      id: const Value('e1'),
      campaignId: const Value('c1'),
      categorySlug: const Value('player'),
      name: const Value('Aragorn'),
      resourcesJson: Value(resourcesJson),
      choicesJson: Value(choicesJson),
      turnStateJson: Value(turnStateJson),
      activeEffectsJson: Value(effectsJson),
    ));

    final row = await db.entityDao.getById('e1');
    expect(row, isNotNull);

    final decodedResources = (jsonDecode(row!.resourcesJson) as Map)
        .map((k, v) => MapEntry(
              k.toString(),
              ResourceState.fromJson(Map<String, dynamic>.from(v as Map)),
            ));
    expect(decodedResources, equals(resources));

    final decodedChoices = (jsonDecode(row.choicesJson) as Map)
        .map((k, v) => MapEntry(
              k.toString(),
              ChoiceState.fromJson(Map<String, dynamic>.from(v as Map)),
            ));
    expect(decodedChoices, equals(choices));

    final decodedTurn = TurnState.fromJson(
      Map<String, dynamic>.from(jsonDecode(row.turnStateJson) as Map),
    );
    expect(decodedTurn, equals(turnState));

    final decodedEffects = (jsonDecode(row.activeEffectsJson) as List)
        .map((e) => AppliedEffect.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    expect(decodedEffects, equals(effects));
  });

  test('empty V3 blobs parse safely', () async {
    await db.campaignDao.createCampaign(const CampaignsCompanion(
      id: Value('c1'),
      worldName: Value('World'),
    ));
    await db.entityDao.createEntity(const EntitiesCompanion(
      id: Value('e1'),
      campaignId: Value('c1'),
      categorySlug: Value('player'),
      name: Value('Blank'),
    ));
    final row = await db.entityDao.getById('e1');
    expect(jsonDecode(row!.resourcesJson), isEmpty);
    expect(jsonDecode(row.choicesJson), isEmpty);
    expect(jsonDecode(row.turnStateJson), isEmpty);
    expect(jsonDecode(row.activeEffectsJson), isEmpty);
  });
}
