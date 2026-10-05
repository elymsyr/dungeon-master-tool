import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/presentation/l10n/app_localizations.dart';
import 'package:dungeon_master_tool/presentation/screens/mind_map/mind_map_canvas.dart';
import 'package:dungeon_master_tool/presentation/screens/mind_map/mind_map_notifier.dart';
import 'package:dungeon_master_tool/presentation/screens/mind_map/mind_map_painter.dart';
import 'package:dungeon_master_tool/presentation/theme/palettes.dart';

// ignore: invalid_use_of_protected_member
MindMapState _state(MindMapNotifier n) => n.state;

void main() {
  late ProviderContainer c;
  late MindMapNotifier n;

  Future<void> pump(WidgetTester t) async {
    c = ProviderContainer();
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: ThemeData.dark()
            .copyWith(extensions: [themePalettes['dark']!]),
        home: const Scaffold(body: MindMapCanvas()),
      ),
    ));
    n = c.read(mindMapProvider.notifier);
    n.selectPen(Colors.green);
    await t.pump();
  }

  // Quarter-circle arc (radius 100) starting at [from].
  Offset arc(Offset from, int i) =>
      from + Offset(100 * math.sin(i * math.pi / 20),
          100 - 100 * math.cos(i * math.pi / 20));

  Future<void> drag(WidgetTester t, TestGesture g, Offset from) async {
    await g.down(from);
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(arc(from, i));
    }
  }

  testWidgets('stylus draws a stroke; a finger after it only pans',
      (t) async {
    await pump(t);
    final pen = await t.createGesture(kind: PointerDeviceKind.stylus);
    await drag(t, pen, const Offset(100, 100));
    await pen.up();
    await t.pump();
    final s = _state(n).strokes.single;
    expect(s.color, Colors.green);
    expect(s.points.length, greaterThan(5));
    expect(s.points.first, const Offset(100, 100));
    // Filtered line still ends exactly where the pen lifted.
    expect(s.points.last, arc(const Offset(100, 100), 10));

    final finger = await t.createGesture(kind: PointerDeviceKind.touch);
    await drag(t, finger, const Offset(300, 300));
    await finger.up();
    await t.pump();
    expect(_state(n).strokes, hasLength(1));
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('second finger cancels a finger stroke (pinch)', (t) async {
    await pump(t);
    final f1 = await t.createGesture(kind: PointerDeviceKind.touch, pointer: 1);
    final f2 = await t.createGesture(kind: PointerDeviceKind.touch, pointer: 2);
    await drag(t, f1, const Offset(100, 100));
    await f2.down(const Offset(400, 400));
    await f2.moveTo(const Offset(450, 450));
    await f1.up();
    await f2.up();
    await t.pump();
    expect(_state(n).strokes, isEmpty);

    n.exitPen();
    await t.pump();
    final f3 = await t.createGesture(kind: PointerDeviceKind.touch);
    await drag(t, f3, const Offset(100, 100));
    await f3.up();
    await t.pump();
    expect(_state(n).strokes, isEmpty);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('stroke saves the chosen width and the zoom it was drawn at',
      (t) async {
    await pump(t);
    n.setPenWidth(MindMapNotifier.penWidths.last);
    n.viewTransform.value = const MindMapViewTransform(scale: 4);
    final pen = await t.createGesture(kind: PointerDeviceKind.stylus);
    await drag(t, pen, const Offset(100, 100));
    await pen.up();
    await t.pump();
    final s = _state(n).strokes.single;
    expect(s.width, MindMapNotifier.penWidths.last);
    expect(s.zoom, 4);
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('eraser drag removes touched strokes whole; one undo',
      (t) async {
    await pump(t);
    n.addStroke(const [Offset(0, 200), Offset(800, 200)], Colors.red, 4);
    n.addStroke(const [Offset(0, 260), Offset(800, 260)], Colors.red, 4);
    n.addStroke(const [Offset(0, 500), Offset(800, 500)], Colors.red, 4);
    await t.pump();

    n.toggleEraser();
    await t.pump();
    // Fast vertical swipe: only two samples, both off the lines.
    final pen = await t.createGesture(kind: PointerDeviceKind.stylus);
    await pen.down(const Offset(400, 150));
    await pen.moveTo(const Offset(400, 300));
    await pen.up();
    await t.pump();
    expect(_state(n).strokes.single.points.first, const Offset(0, 500));

    n.undo();
    expect(_state(n).strokes, hasLength(3));
    await t.pumpWidget(const SizedBox());
    c.dispose();
  });

  test('stroke width follows zoom, held within [1 px, 2× chosen] on screen',
      () {
    const s = MindMapStroke(
        id: 'a', color: Colors.red, width: 4, zoom: 0.5, points: []);
    double onScreen(double scale) => s.canvasWidthAt(scale) * scale;
    expect(onScreen(0.5), 4); // as drawn
    expect(onScreen(0.75), 6); // grows with the content…
    expect(onScreen(5), 8); // …but drawn zoomed-out it caps at 2×
    expect(onScreen(0.05), 1); // and never vanishes
    // Legacy tiny width: no clamp ArgumentError.
    const thin = MindMapStroke(
        id: 'b', color: Colors.red, width: 0.3, points: []);
    expect(thin.canvasWidthAt(1), 0.3);
  });

  test('simplifyStroke keeps corners, drops collinear points', () {
    final line = [for (var i = 0; i <= 10; i++) Offset(i * 10.0, 0)];
    expect(simplifyStroke(line, 0.5), [line.first, line.last]);

    final corner = [...line, const Offset(100, 50), const Offset(100, 100)];
    expect(simplifyStroke(corner, 0.5),
        [const Offset(0, 0), const Offset(100, 0), const Offset(100, 100)]);
  });
}
