import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_master_tool/presentation/screens/map/world_map_notifier.dart';

ProviderContainer _makeContainer() => ProviderContainer();

// ignore: invalid_use_of_protected_member
WorldMapState _state(WorldMapNotifier n) => n.state;

void main() {
  group('WorldMapNotifier — Pin CRUD', () {
    late ProviderContainer c;
    late WorldMapNotifier n;

    setUp(() {
      c = _makeContainer();
      n = c.read(worldMapProvider.notifier);
    });
    tearDown(() => c.dispose());

    test('addPin creates pin with correct position', () {
      n.addPin(const Offset(100, 200));
      final pins = _state(n).pins;
      expect(pins, hasLength(1));
      expect(pins.first.x, 100);
      expect(pins.first.y, 200);
      expect(pins.first.pinType, 'default');
      expect(pins.first.label, '');
    });

    test('addPin with pinType and label', () {
      n.addPin(const Offset(50, 75), pinType: 'npc', label: 'Blacksmith');
      final pin = _state(n).pins.first;
      expect(pin.pinType, 'npc');
      expect(pin.label, 'Blacksmith');
    });

    test('addPin returns unique ids', () {
      final id1 = n.addPin(const Offset(0, 0));
      final id2 = n.addPin(const Offset(100, 100));
      expect(id1, isNot(id2));
    });

    test('updatePin changes position', () {
      n.addPin(const Offset(0, 0));
      final id = _state(n).pins.first.id;
      n.updatePin(id, pos: const Offset(300, 400));
      expect(_state(n).pins.first.x, 300);
      expect(_state(n).pins.first.y, 400);
    });

    test('updatePin changes label', () {
      n.addPin(const Offset(0, 0));
      final id = _state(n).pins.first.id;
      n.updatePin(id, label: 'New Label');
      expect(_state(n).pins.first.label, 'New Label');
    });

    test('updatePin changes pinType', () {
      n.addPin(const Offset(0, 0));
      final id = _state(n).pins.first.id;
      n.updatePin(id, pinType: 'monster');
      expect(_state(n).pins.first.pinType, 'monster');
    });

    test('updatePin ignores unknown id', () {
      n.addPin(const Offset(0, 0));
      n.updatePin('non-existent', label: 'x'); // should not throw
      expect(_state(n).pins, hasLength(1));
    });

    test('deletePin removes pin', () {
      n.addPin(const Offset(0, 0));
      final id = _state(n).pins.first.id;
      n.deletePin(id);
      expect(_state(n).pins, isEmpty);
    });

    test('deletePin with multiple pins removes only target', () {
      n.addPin(const Offset(0, 0));
      n.addPin(const Offset(100, 100));
      n.addPin(const Offset(200, 200));
      final id = _state(n).pins[1].id;
      n.deletePin(id);
      expect(_state(n).pins, hasLength(2));
      expect(_state(n).pins.any((p) => p.id == id), isFalse);
    });
  });

  group('WorldMapNotifier — Pin type filter', () {
    late ProviderContainer c;
    late WorldMapNotifier n;

    setUp(() {
      c = _makeContainer();
      n = c.read(worldMapProvider.notifier);
    });
    tearDown(() => c.dispose());

    test('togglePinTypeVisibility hides pin type', () {
      n.togglePinTypeVisibility('npc');
      expect(_state(n).hiddenPinTypes, contains('npc'));
    });

    test('togglePinTypeVisibility shows previously hidden type', () {
      n.togglePinTypeVisibility('npc');
      n.togglePinTypeVisibility('npc');
      expect(_state(n).hiddenPinTypes, isNot(contains('npc')));
    });

    test('multiple types can be hidden simultaneously', () {
      n.togglePinTypeVisibility('npc');
      n.togglePinTypeVisibility('monster');
      expect(_state(n).hiddenPinTypes, containsAll(['npc', 'monster']));
    });
  });

  group('WorldMapNotifier — Pan / Zoom', () {
    late ProviderContainer c;
    late WorldMapNotifier n;

    setUp(() {
      c = _makeContainer();
      n = c.read(worldMapProvider.notifier);
    });
    tearDown(() => c.dispose());

    test('initial viewTransform has scale 1 and zero pan', () {
      expect(n.viewTransform.value.scale, 1.0);
      expect(n.viewTransform.value.panOffset, Offset.zero);
    });

    test('resetView restores defaults', () {
      n.onScaleStart(ScaleStartDetails(focalPoint: const Offset(100, 100)));
      n.onScaleUpdate(ScaleUpdateDetails(
        focalPoint: const Offset(150, 150),
        scale: 2.0,
      ));
      n.resetView();
      expect(n.viewTransform.value.scale, 1.0);
      expect(n.viewTransform.value.panOffset, Offset.zero);
    });

    test('zoomAtPoint clamps scale to minimum 0.05', () {
      // Zoom out far beyond minimum
      for (var i = 0; i < 100; i++) {
        n.zoomAtPoint(Offset.zero, 1); // scroll down = zoom out
      }
      expect(n.viewTransform.value.scale, greaterThanOrEqualTo(0.05));
    });

    test('zoomAtPoint clamps scale to maximum 10', () {
      for (var i = 0; i < 100; i++) {
        n.zoomAtPoint(Offset.zero, -1); // scroll up = zoom in
      }
      expect(n.viewTransform.value.scale, lessThanOrEqualTo(10.0));
    });
  });

  group('WorldMapNotifier — Coordinate conversion', () {
    late ProviderContainer c;
    late WorldMapNotifier n;

    setUp(() {
      c = _makeContainer();
      n = c.read(worldMapProvider.notifier);
    });
    tearDown(() => c.dispose());

    test('screenToCanvas and canvasToScreen are inverse at default transform', () {
      const screen = Offset(300, 400);
      final canvas = n.screenToCanvas(screen);
      final back = n.canvasToScreen(canvas);
      expect(back.dx, closeTo(screen.dx, 0.001));
      expect(back.dy, closeTo(screen.dy, 0.001));
    });
  });

  group('WorldMapNotifier — init/save roundtrip', () {
    late ProviderContainer c;
    late WorldMapNotifier n;

    setUp(() {
      c = _makeContainer();
      n = c.read(worldMapProvider.notifier);
    });
    tearDown(() => c.dispose());

    test('init loads imagePath and pins', () {
      n.addPin(const Offset(100, 200), pinType: 'location', label: 'Town');
      n.addPin(const Offset(300, 400), pinType: 'npc', label: 'Hero');

      final json = <String, dynamic>{
        'image_path': '/path/to/map.png',
        'pins': _state(n).pins.map((p) => p.toJson()).toList(),
        'scale': 1.5,
        'pan_x': 50.0,
        'pan_y': 75.0,
      };

      final c2 = _makeContainer();
      addTearDown(c2.dispose);
      final n2 = c2.read(worldMapProvider.notifier);
      n2.init(json);

      // ignore: invalid_use_of_protected_member
      final s2 = n2.state;
      expect(s2.imagePath, '/path/to/map.png');
      expect(s2.pins, hasLength(2));
      expect(s2.pins[0].label, 'Town');
      expect(s2.pins[0].pinType, 'location');
      expect(s2.pins[1].label, 'Hero');
      expect(n2.viewTransform.value.scale, 1.5);
      expect(n2.viewTransform.value.panOffset.dx, 50.0);
      expect(n2.viewTransform.value.panOffset.dy, 75.0);
    });

    test('init with empty data sets defaults', () {
      n.init({});
      expect(_state(n).imagePath, '');
      expect(_state(n).pins, isEmpty);
      expect(n.viewTransform.value.scale, 1.0);
    });
  });
}
