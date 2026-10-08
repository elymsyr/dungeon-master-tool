import 'dart:ui' as ui;

import 'package:dungeon_master_tool/presentation/screens/player_window/views/battle_map_projection_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pişirilmiş sis: kenarda opak, ortada yumuşak, hizası doğru',
      (t) async {
    await t.runAsync(() async {
      // 400×200 canvas, sol yarı sisli; sis bitmap'i canvas'ın iki katı.
      final r = ui.PictureRecorder();
      Canvas(r).drawRect(const Rect.fromLTWH(0, 0, 400, 400),
          Paint()..color = const Color(0xFF000000));
      final fog = r.endRecording().toImageSync(800, 400);

      final baked = blurFog(fog, const Size(400, 200));
      // Canvas biriminin 1/4'ü + her yanda 36 birimlik (9 px) halka.
      expect(baked.width, 400 / 4 + 18);
      expect(baked.height, 200 / 4 + 18);

      final px = (await baked.toByteData())!;
      // Canvas koordinatından baked resmin alfa değeri.
      int alpha(double cx, double cy) {
        final x = (9 + cx / 4).floor(), y = (9 + cy / 4).floor();
        return px.getUint8((y * baked.width + x) * 4 + 3);
      }

      expect(alpha(0, 100), 255, reason: 'canvas kenarı: harita görünmemeli');
      expect(alpha(0, 0), 255, reason: 'köşe de tam kapalı');
      expect(alpha(150, 100), 255);
      expect(alpha(250, 100), 0);
      expect(alpha(399, 100), 0);
      // Sınır 200'de; geçiş birkaç sigma boyunca yumuşak.
      expect(alpha(200, 100), inInclusiveRange(90, 165));
      expect(alpha(188, 100), greaterThan(alpha(200, 100)));
      expect(alpha(212, 100), lessThan(alpha(200, 100)));
    });
  });
}
