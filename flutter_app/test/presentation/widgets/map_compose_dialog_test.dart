import 'dart:ui' as ui;

import 'package:dungeon_master_tool/presentation/l10n/app_localizations.dart';
import 'package:dungeon_master_tool/presentation/theme/palettes.dart';
import 'package:dungeon_master_tool/presentation/widgets/battle_map/map_compose_dialog.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _img(int w, int h) {
  final r = ui.PictureRecorder();
  Canvas(r).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint());
  return r.endRecording().toImage(w, h);
}

void main() {
  testWidgets('drag + underneath returns placement in base pixel space',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final base = (await tester.runAsync(() => _img(1000, 800)))!;
    final overlay = (await tester.runAsync(() => _img(400, 200)))!;
    MapPlacement? result;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: ThemeData.dark().copyWith(extensions: [themePalettes['dark']!]),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showMapComposeDialog(
              context, base: base, overlay: overlay),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Underneath'));
    await tester.drag(find.byWidgetPredicate((w) =>
        w is CustomPaint && '${w.painter.runtimeType}' == '_ComposePainter'), const Offset(-100, -100));
    // Wheel zooms the preview only; size changes come from the slider/±.
    final preview = tester.getCenter(find.byWidgetPredicate((w) =>
        w is CustomPaint && '${w.painter.runtimeType}' == '_ComposePainter'));
    await tester.sendEventToBinding(
        PointerScrollEvent(position: preview, scrollDelta: const Offset(0, -50)));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('101%'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    await tester.tap(find.text('Combine'));
    await tester.pumpAndSettle();

    expect(result!.below, isTrue);
    expect(result!.rect.size, const Size(400, 200)); // native size by default
    expect(result!.rect.center.dx, lessThan(500)); // moved left of base center
    expect(result!.rect.center.dy, lessThan(400));
  });
}
