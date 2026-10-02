// Renders a dice roll: the dice tumble in 3D (flutter_scene) over whatever is
// behind this widget, then a card shows the result. Where Flutter GPU is not
// available the card shows on its own.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import '../../l10n/app_localizations.dart';
import 'dice_physics.dart';

// --- number atlas + rounded mesh ------------------------------------------------

const _cols = 5, _cell = 256;
const _bevel = 0.14; // edge rounding radius, as a share of the inradius

int _rows(DieShape s) => (s.faces.length + _cols - 1) ~/ _cols;

// Where a point of face i lands in the number atlas, in pixels. flutter_scene
// renders left-handed, so the face's "right" is normal × up (not up × normal),
// or the numbers come out mirrored.
Offset _atlasPoint(DieShape s, int i, vm.Vector3 p) {
  final f = s.faces[i];
  final d = p - f.centroid;
  final k = _cell * 0.48 / s.span;
  return Offset(
    (i % _cols + 0.5) * _cell + d.dot(f.normal.cross(f.up)) * k,
    (i ~/ _cols + 0.5) * _cell - d.dot(f.up) * k,
  );
}

// The biggest circle that fits the face along its up axis: where the number
// goes and how big it can be (a kite's sits off-centre, toward its wide end).
(vm.Vector3, double) _textSpot(DieShape s, DieFace f) {
  var best = (f.centroid, 0.0);
  for (var t = -0.5; t <= 0.5; t += 0.02) {
    final p = f.centroid + f.up * (t * s.span);
    var r = double.infinity;
    for (var e = 0; e < f.poly.length; e++) {
      final a = f.poly[e], b = f.poly[(e + 1) % f.poly.length];
      r = math.min(r, (a - p).dot((b - a).cross(f.normal)..normalize()));
    }
    if (r > best.$2) best = (p, r);
  }
  return best;
}

Future<ui.Image> _numberAtlas(DieShape s, Color body, Color ink) {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  final w = _cols * _cell, h = _rows(s) * _cell;
  canvas.drawRect(Rect.fromLTWH(0, 0, w * 1.0, h * 1.0), Paint()..color = body);
  final px = _cell * 0.48 / s.span;
  void text(String label, Offset at, double size, double maxWidth, [double angle = 0]) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: ink, fontSize: size, fontWeight: FontWeight.w800, fontFamily: 'serif'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final fit = math.min(1.0, maxWidth / tp.width);
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..rotate(angle)
      ..scale(fit);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  for (var i = 0; i < s.faces.length; i++) {
    final f = s.faces[i];
    final (spot, r) = _textSpot(s, f);
    if (s.readsBottom) {
      // d4: each corner carries the number you read when that corner is up.
      final centre = _atlasPoint(s, i, f.centroid);
      for (final v in f.poly) {
        final opposite = s.faces.firstWhere((o) => !o.poly.contains(v));
        final at = _atlasPoint(s, i, f.centroid + (v - f.centroid) * 0.55);
        final dir = at - centre;
        text(s.label(opposite.number), at, 0.8 * r * px, r * px, math.atan2(dir.dx, -dir.dy));
      }
    } else {
      text(s.label(f.number), _atlasPoint(s, i, spot), 1.3 * r * px, 1.7 * r * px);
    }
  }
  return rec.endRecording().toImage(w, h);
}

// Rounded die: the die shrunk by the rounding radius r, then grown by a ball of
// radius r. That is flat faces, a cylinder strip along every edge and a sphere
// patch at every corner; only the flat parts carry the numbers.
MeshGeometry _dieGeometry(DieShape s) {
  final g = GeometryBuilder(deduplicate: false);
  final r = _bevel * s.inradius, k = 1 - _bevel;
  final size = vm.Vector2(_cols * _cell * 1.0, _rows(s) * _cell * 1.0);
  final plain = vm.Vector2(2 / size.x, 2 / size.y); // a body-coloured texel
  (vm.Vector3, vm.Vector3, vm.Vector2) round(vm.Vector3 v, vm.Vector3 n) => (v * k + n * r, n, plain);
  void tri(List<(vm.Vector3, vm.Vector3, vm.Vector2)> t) {
    // Wind CCW around the outward normal, whatever order the corners came in.
    if ((t[1].$1 - t[0].$1).cross(t[2].$1 - t[0].$1).dot(t[0].$2 + t[1].$2 + t[2].$2) < 0) {
      t = [t[0], t[2], t[1]];
    }
    final idx = [for (final (p, n, uv) in t) g.normal(n).texCoord(uv).addVertex(p)];
    g.addTriangle(idx[0], idx[1], idx[2]);
  }

  const steps = 4;
  List<vm.Vector3> arc(vm.Vector3 a, vm.Vector3 b) {
    final w = math.acos(a.dot(b).clamp(-1.0, 1.0));
    return [
      for (var j = 0; j <= steps; j++)
        (a * math.sin((1 - j / steps) * w) + b * math.sin(j / steps * w)) / math.sin(w),
    ];
  }

  for (var i = 0; i < s.faces.length; i++) {
    final f = s.faces[i];
    vm.Vector2 uv(vm.Vector3 v) {
      final o = _atlasPoint(s, i, v);
      return vm.Vector2(o.dx / size.x, o.dy / size.y);
    }

    final flat = [for (final v in f.poly) (v * k + f.normal * r, f.normal, uv(v))];
    for (var e = 1; e + 1 < flat.length; e++) {
      tri([flat[0], flat[e], flat[e + 1]]);
    }
    // Edge strip to each neighbour, built once from the lower-index face.
    for (var e = 0; e < f.poly.length; e++) {
      final a = f.poly[e], b = f.poly[(e + 1) % f.poly.length];
      final j = s.faces.indexWhere((o) => o != f && o.poly.contains(a) && o.poly.contains(b));
      if (j < i) continue;
      final d = arc(f.normal, s.faces[j].normal);
      for (var m = 0; m < steps; m++) {
        tri([round(a, d[m]), round(b, d[m]), round(b, d[m + 1])]);
        tri([round(a, d[m]), round(b, d[m + 1]), round(a, d[m + 1])]);
      }
    }
  }
  // Corner patch: a fan through the normals of the faces meeting there.
  for (final v in s.verts) {
    final around = s.faces.where((f) => f.poly.contains(v)).toList();
    final c = around.fold(vm.Vector3.zero(), (a, f) => a + f.normal)..normalize();
    final e1 = (around.first.normal - c * around.first.normal.dot(c))..normalize();
    final e2 = c.cross(e1);
    double angle(DieFace f) => math.atan2(f.normal.dot(e2), f.normal.dot(e1));
    around.sort((x, y) => angle(x).compareTo(angle(y)));
    for (var m = 0; m < around.length; m++) {
      final d = arc(around[m].normal, around[(m + 1) % around.length].normal);
      for (var q = 0; q < steps; q++) {
        tri([round(v, c), round(v, d[q]), round(v, d[q + 1])]);
      }
    }
  }
  return g.build();
}

/// Resin and number colours per app theme, keyed by theme name.
const diceLooks = <String, ({Color body, Color ink})>{
  'dark': (body: Color(0xFF1F4E79), ink: Color(0xFFF0F4F8)),
  'light': (body: Color(0xFFF4F6FA), ink: Color(0xFF2C5282)),
  'parchment': (body: Color(0xFFE8D5A9), ink: Color(0xFF5D4037)),
  'ocean': (body: Color(0xFF006D7A), ink: Color(0xFFE0F7FA)),
  'emerald': (body: Color(0xFF0B6B3A), ink: Color(0xFFE8FFF1)),
  'midnight': (body: Color(0xFF2A1260), ink: Color(0xFFD1C4FF)),
  'soft': (body: Color(0xFF5865F2), ink: Color(0xFFFFFFFF)),
  'baldur': (body: Color(0xFF2A1A12), ink: Color(0xFFD4AF6A)),
  'grim': (body: Color(0xFF7A0F1C), ink: Color(0xFFF3E6C8)),
  'obsidian': (body: Color(0xFF111111), ink: Color(0xFFD0202A)),
  'frost': (body: Color(0xFFDDF4F2), ink: Color(0xFF1D6B69)),
  'amethyst': (body: Color(0xFF6A2C7A), ink: Color(0xFFF3E5F5)),
  'sunset': (body: Color(0xFFD9542B), ink: Color(0xFF2B1118)),
  'nord': (body: Color(0xFF4C566A), ink: Color(0xFF88C0D0)),
  'rose': (body: Color(0xFFF8BBD0), ink: Color(0xFFAD1457)),
  'terminal': (body: Color(0xFF0A0A0A), ink: Color(0xFF00FF41)),
  'terra': (body: Color(0xFFC2410C), ink: Color(0xFFFFF8E7)),
  'jade': (body: Color(0xFF00A86B), ink: Color(0xFFF0FFF8)),
  'mono': (body: Color(0xFFFFFFFF), ink: Color(0xFF000000)),
  'carmine': (body: Color(0xFFDC143C), ink: Color(0xFFFFFFFF)),
};

/// The dice look for a `diceTheme` setting: 'auto' follows [appTheme].
String resolveDiceLook(String setting, String appTheme) {
  final name = setting == 'auto' ? appTheme : setting;
  return diceLooks.containsKey(name) ? name : 'dark';
}

/// The dice scene, built per dice look (only the last one is kept): a number atlas, rounded mesh and
/// resin material per die shape, lit by one shadow-casting light over an
/// invisible floor that only catches the shadows. Fails where Flutter GPU is
/// not available; the roller then shows results without the 3D dice.
class DiceKit {
  DiceKit._(this.scene, this.looks);
  final Scene scene;
  final Map<String, (MeshGeometry, PhysicallyBasedMaterial)> looks;

  static (String, Future<DiceKit>)? _kit;
  static Future<DiceKit> load(String look) {
    final kit = _kit;
    if (kit != null && kit.$1 == look) return kit.$2;
    return (_kit = (look, _build(diceLooks[look] ?? diceLooks['dark']!))).$2;
  }

  static Future<DiceKit> _build(({Color body, Color ink}) look) async {
    try {
      // Touch the GPU once first: without Flutter GPU this throws right here,
      // before the engine starts its own loads (whose failures go unhandled).
      Texture2D.fromPixels(Uint8List(4), 1, 1);
      await Scene.initializeStaticResources();
      final looks = <String, (MeshGeometry, PhysicallyBasedMaterial)>{};
      for (final s in dieShapes.values) {
        final atlas = await _numberAtlas(s, look.body, look.ink);
        final mat = PhysicallyBasedMaterial(baseColorTexture: await Texture2D.fromImage(atlas))
          ..roughnessFactor = 0.32
          ..metallicFactor = 0.0
          ..clearcoat = 0.8
          ..clearcoatRoughness = 0.08;
        looks[s.name] = (_dieGeometry(s), mat);
      }
      final scene = Scene()
        ..directionalLight = DirectionalLight(
          direction: vm.Vector3(-0.6, -1.0, -0.5),
          intensity: 2.2,
          castsShadow: true,
          // The view is one flat tray seen from above: a single cascade
          // fitted to it (DiceView sets shadowMaxDistance) covers it all.
          shadowCascadeCount: 1,
        );
      scene.add(Node(
        mesh: Mesh(PlaneGeometry(width: 200, depth: 200), ShadowCatcherMaterial(shadowIntensity: 0.6, aoStrength: 0)),
      ));
      // Compile the pipelines and upload the atlases now (the menu is open,
      // nothing rolls yet), so the first throw doesn't stall on its first frame.
      final probes = [for (final (g, m) in looks.values) Node(mesh: Mesh(g, m))];
      probes.forEach(scene.add);
      await scene.warmUp([RenderView(camera: DiceView(const Size(400, 800)).camera)]);
      probes.forEach(scene.remove);
      return DiceKit._(scene, looks);
    } catch (e) {
      debugPrint('dice: 3D unavailable, showing results only: $e');
      rethrow;
    }
  }
}

// --- throw area -------------------------------------------------------------------

const _fov = 24 * vm.degrees2Radians;
const _wallMargin = 0.8; // world units between the tray walls and the screen edge
const _cardReserve = 110.0; // logical px kept free at the top for the result card

/// Camera and tray for a screen of [size]: dice keep a steady on-screen size
/// (a die across is ~20% of the short side, 72–120 px) and the tray fills the
/// screen around them.
class DiceView {
  factory DiceView(Size size) {
    final k = 1.2 / (size.shortestSide * 0.2).clamp(72.0, 120.0); // world units per px
    final hx = size.width / 2 * k, hz = size.height / 2 * k;
    final reserve = _cardReserve * k;
    // Aim the camera up by half the reserve so the tray sits below the card.
    final aimZ = -reserve / 2;
    final height = hz / math.tan(_fov / 2);
    return DiceView._(
      // Shadows only out to the far edge of the tray (the view's corners).
      shadowDistance: height * 1.15 + 2,
      trayX: math.max(1.5, hx - _wallMargin),
      trayZ: math.max(1.5, hz - _wallMargin - reserve / 2),
      // Long lens from almost straight above: a wide angle stretched the dice
      // near the screen edges and made flat ones look tilted.
      camera: PerspectiveCamera(
        position: vm.Vector3(0, height, aimZ + height * 0.18),
        target: vm.Vector3(0, 0, aimZ),
        fovRadiansY: _fov,
        // Clip range hugging the tray (dice never fly 12 units up): depth
        // precision and the shadow cascade both go where the dice are.
        fovNear: math.max(0.1, height - 12),
        fovFar: height * 1.3,
      ),
    );
  }
  DiceView._({required this.shadowDistance, required this.trayX, required this.trayZ, required this.camera});
  final double shadowDistance, trayX, trayZ;
  final PerspectiveCamera camera;
}

// --- widget -------------------------------------------------------------------

// Top level, so the isolate message carries only the record, not a closure scope.
DiceRoll _throwInBackground((Map<String, int>, double, double) a) =>
    throwDice(a.$1, math.Random(), trayX: a.$2, trayZ: a.$3);

/// Throws [counts] and shows the roll filling the screen. A tap skips to the
/// landed dice; a tap after they land calls [onClose].
class DiceRollView extends StatefulWidget {
  const DiceRollView({
    super.key,
    required this.counts,
    required this.look,
    required this.onClose,
    this.modifier = 0,
    this.label,
  });
  final Map<String, int> counts;
  final String look;
  final int modifier; // added to the dice total, e.g. a skill bonus
  final String? label; // what was rolled, e.g. "Stealth"
  final VoidCallback onClose;

  @override
  State<DiceRollView> createState() => _DiceRollViewState();
}

class _DiceRollViewState extends State<DiceRollView> {
  DiceView? _view;
  DiceRoll? _roll;
  DiceKit? _kit;
  final _nodes = <Node>[];
  double _t = 0;
  bool _settled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_view != null) return;
    final view = _view = DiceView(MediaQuery.sizeOf(context));
    // The throw is simulated up front (~90 ms for 30 dice on desktop), off
    // the UI isolate so the screen doesn't hitch.
    final roll = compute(_throwInBackground, (widget.counts, view.trayX, view.trayZ));
    final kit = DiceKit.load(widget.look).then<DiceKit?>((k) => k, onError: (_) => null);
    Future.wait([roll, kit]).then((r) {
      if (!mounted) return;
      final roll = r[0] as DiceRoll, kit = r[1] as DiceKit?;
      if (kit != null) {
        kit.scene.directionalLight!.shadowMaxDistance = view.shadowDistance;
        for (final d in roll.dice) {
          final (geometry, material) = kit.looks[d.shape.name]!;
          final node = Node(mesh: Mesh(geometry, material));
          _place(node, d, 0);
          kit.scene.add(node);
          _nodes.add(node);
        }
      }
      setState(() {
        _roll = roll;
        _kit = kit;
        _settled = kit == null;
      });
    });
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      _kit?.scene.remove(n);
    }
    super.dispose();
  }

  void _place(Node node, ThrownDie d, int step) {
    final (p, q) = d.poseAt(step);
    node.position = p;
    node.rotation = q;
  }

  void _tick(Duration _, double dt) {
    final roll = _roll;
    if (roll == null || _settled) return;
    // Don't let a frame stall teleport the animation to its end.
    _t += math.min(dt, 1 / 30);
    final step = (_t * diceSimHz).floor();
    for (var i = 0; i < roll.dice.length; i++) {
      _place(_nodes[i], roll.dice[i], step);
    }
    if (step >= roll.steps - 1) setState(() => _settled = true);
  }

  void _tap() {
    final roll = _roll;
    if (roll == null || _settled) {
      widget.onClose();
    } else {
      _t = roll.steps / diceSimHz; // next tick lands every die
    }
  }

  @override
  Widget build(BuildContext context) {
    final roll = _roll, kit = _kit;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: Stack(children: [
        if (roll != null && kit != null)
          Positioned.fill(
            // Own layer, so the result card animating above doesn't re-render
            // the scene; once the dice rest, the scene stops rendering per frame.
            child: RepaintBoundary(
              child: SceneView(
                kit.scene,
                camera: _view!.camera,
                autoTick: !_settled,
                onTick: _tick,
                // Dice are ~100 px across; past 2× a phone just pays fill rate.
                pixelRatio: math.min(2.0, MediaQuery.devicePixelRatioOf(context)),
              ),
            ),
          ),
        if (roll != null && _settled)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            left: 16,
            right: 16,
            child: _ResultCard(roll, modifier: widget.modifier, label: widget.label),
          ),
      ]),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard(this.roll, {this.modifier = 0, this.label});
  final DiceRoll roll;
  final int modifier;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final single = roll.dice.length == 1 || (roll.results.length == 1 && roll.results.values.first.length == 1);
    final dice = single
        ? (modifier == 0 ? roll.results.keys.single : '${roll.results.keys.single}: ${roll.total}')
        : [
            for (final MapEntry(key: k, value: vs) in roll.results.entries)
              vs.length == 1 ? '$k: ${vs.single}' : '${vs.length}$k: ${vs.join(' + ')} = ${vs.reduce((a, b) => a + b)}',
          ].join('  ·  ');
    final breakdown = modifier == 0 ? dice : '$dice ${modifier > 0 ? '+' : '−'} ${modifier.abs()}';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (_, s, child) => Opacity(opacity: ((s - 0.85) / 0.15).clamp(0.0, 1.0), child: Transform.scale(scale: s, child: child)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: scheme.surface.withValues(alpha: 0.94),
            elevation: 6,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (label != null)
                  Text(label!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
                Text(
                  '${roll.total + modifier}',
                  style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: scheme.onSurface),
                ),
                Text(
                  breakdown,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          L10n.of(context)!.diceTapToClose,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ]),
    );
  }
}
