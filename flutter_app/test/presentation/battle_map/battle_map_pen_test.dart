import 'dart:math' as math;

import 'package:dungeon_master_tool/application/providers/combat_provider.dart';
import 'package:dungeon_master_tool/application/services/event_bus.dart';
import 'package:dungeon_master_tool/presentation/l10n/app_localizations.dart';
import 'package:dungeon_master_tool/presentation/screens/battle_map/battle_map_notifier.dart';
import 'package:dungeon_master_tool/presentation/screens/battle_map/battle_map_painter.dart';
import 'package:dungeon_master_tool/presentation/screens/battle_map/battle_map_screen.dart';
import 'package:dungeon_master_tool/presentation/theme/palettes.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoSaveCombat extends CombatNotifier {
  _NoSaveCombat()
      : super(() => {}, () => throw UnimplementedError(), () => [],
            () => null, AppEventBus(), (_) async {}, (_) async {}, () => true);

  @override
  void saveMapData({
    required String encounterId,
    String? mapPath,
    Map<String, dynamic>? tokenPositions,
    Map<String, double>? tokenSizeMultipliers,
    int? tokenSize,
    List<String>? hiddenTokenIds,
  }) {}

  @override
  void saveFogAndAnnotation({
    required String encounterId,
    String? fogData,
    String? annotationData,
    String? measurementsData,
    String? strokesData,
    String? sceneVectorJson,
  }) {}
}

// ignore: invalid_use_of_protected_member
BattleMapState _state(BattleMapNotifier n) => n.state;

void main() {
  late ProviderContainer c;
  late BattleMapNotifier n;

  Future<void> pump(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(1400, 900));
    c = ProviderContainer(
        overrides: [combatProvider.overrideWith((_) => _NoSaveCombat())]);
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme:
            ThemeData.dark().copyWith(extensions: [themePalettes['dark']!]),
        home: const Scaffold(body: BattleMapScreen(encounterId: 'e1')),
      ),
    ));
    n = c.read(battleMapProvider('e1').notifier);
    n.setTool(BattleMapTool.draw);
    await t.pump();
  }

  Future<void> done(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3)); // debounced autosaves
    c.dispose();
    await t.binding.setSurfaceSize(null);
  }

  Offset arc(Offset from, int i) =>
      from +
      Offset(100 * math.sin(i * math.pi / 20),
          100 - 100 * math.cos(i * math.pi / 20));

  Future<void> drag(TestGesture g, Offset from) async {
    await g.down(from);
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(arc(from, i));
    }
  }

  testWidgets('a finger draws a smooth stroke from its first sample',
      (t) async {
    await pump(t);
    final f = await t.createGesture(kind: PointerDeviceKind.touch);
    await drag(f, const Offset(300, 300));
    await f.up();
    await t.pump();
    final s = _state(n).strokes.single;
    expect(s.rawPoints.length, greaterThan(3));
    // Starts exactly under the finger — no pan slop swallowed.
    final origin = t.getTopLeft(find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is BattleMapPainter));
    expect(s.rawPoints.first,
        n.screenToCanvas(const Offset(300, 300) - origin));
    await done(t);
  });

  testWidgets('a second finger cancels the stroke and pans/zooms instead',
      (t) async {
    await pump(t);
    final before = n.viewTransform.value;
    final f1 = await t.createGesture(kind: PointerDeviceKind.touch, pointer: 1);
    final f2 = await t.createGesture(kind: PointerDeviceKind.touch, pointer: 2);
    await drag(f1, const Offset(300, 300));
    await f2.down(const Offset(600, 600));
    for (var i = 1; i <= 5; i++) {
      await f2.moveTo(Offset(600 + i * 20.0, 600 + i * 20.0));
      await f1.moveTo(arc(const Offset(300, 300), 10) + Offset(i * 5.0, 0));
    }
    await f1.up();
    await f2.up();
    await t.pump();
    expect(_state(n).strokes, isEmpty);
    expect(n.viewTransform.value, isNot(before));

    // A tap leaves nothing behind.
    await t.tapAt(const Offset(500, 500));
    await t.pump();
    expect(_state(n).strokes, isEmpty);
    await done(t);
  });
}
