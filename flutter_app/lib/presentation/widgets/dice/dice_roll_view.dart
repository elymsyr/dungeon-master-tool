// Renders a dice roll: the dice tumble in 3D (flutter_scene) over whatever is
// behind this widget, then a card shows the result. Where Flutter GPU is not
// available the card shows on its own.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:google_fonts/google_fonts.dart';
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

// A wandering line across the atlas: marble veins, lava cracks.
Path _wander(math.Random rnd, Size size, int steps) {
  var p = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
  var a = rnd.nextDouble() * 2 * math.pi;
  final path = Path()..moveTo(p.dx, p.dy);
  for (var i = 0; i < steps; i++) {
    a += (rnd.nextDouble() - 0.5) * 1.2;
    p += Offset(math.cos(a), math.sin(a)) * (30 + rnd.nextDouble() * 50);
    path.lineTo(p.dx, p.dy);
  }
  return path;
}

// The body's pattern, painted under the numbers. [glow] paints only what
// shines (the emissive atlas), on black.
void _paintBody(Canvas c, Size size, DiceLook look, bool glow) {
  final rnd = math.Random(7);
  Paint line(Color color, double width, [double blur = 0]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..color = color
    ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null;
  switch (look.paint) {
    case DicePaint.plain:
      break;
    case DicePaint.marble:
      for (var i = 0; i < 30; i++) {
        final path = _wander(rnd, size, 16);
        c
          ..drawPath(path, line(look.accent.withValues(alpha: 0.3), 16, 9))
          ..drawPath(path, line(look.accent.withValues(alpha: 0.85), 1.5 + rnd.nextDouble() * 3));
      }
    case DicePaint.wood:
      // Grain along each face's "right", rings of varying weight.
      for (var y = 0.0; y < size.height; y += 3 + rnd.nextDouble() * 7) {
        final path = Path(), amp = 2 + rnd.nextDouble() * 4, phase = rnd.nextDouble() * 6;
        for (var x = 0.0; x <= size.width; x += 16) {
          final yy = y + amp * math.sin(x / 90 + phase) + 1.5 * math.sin(x / 23 + phase * 2);
          x == 0 ? path.moveTo(x, yy) : path.lineTo(x, yy);
        }
        c.drawPath(path, line(look.accent.withValues(alpha: 0.25 + rnd.nextDouble() * 0.5), 0.8 + rnd.nextDouble() * 2.2));
      }
    case DicePaint.galaxy:
      if (!glow) {
        const clouds = [Color(0xFF7B2FBE), Color(0xFF1FA2B8), Color(0xFFC2185B), Color(0xFF283593)];
        for (var i = 0; i < 60; i++) {
          final r = 30 + rnd.nextDouble() * 110;
          c.drawCircle(
            Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
            r,
            Paint()
              ..color = clouds[i % clouds.length].withValues(alpha: 0.35)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
          );
        }
      }
      for (var i = 0; i < 900; i++) {
        final o = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
        c.drawCircle(o, 0.6 + math.pow(rnd.nextDouble(), 4) * 2.4, Paint()..color = Colors.white.withValues(alpha: 0.5 + rnd.nextDouble() * 0.5));
      }
    case DicePaint.lava:
      for (var i = 0; i < 12; i++) {
        final path = _wander(rnd, size, 8);
        if (glow) c.drawPath(path, line(look.accent.withValues(alpha: 0.6), 6, 5));
        c.drawPath(path, line(glow ? const Color(0xFFFFB060) : look.accent.withValues(alpha: 0.7), 1 + rnd.nextDouble() * 1.5));
      }
  }
}

Future<ui.Image> _numberAtlas(DieShape s, DiceLook look, {bool glow = false}) {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  final w = _cols * _cell, h = _rows(s) * _cell;
  final body = glow ? Colors.black : look.body.withValues(alpha: look.opacity);
  final ink = glow ? look.accent : look.ink;
  canvas.drawRect(Rect.fromLTWH(0, 0, w * 1.0, h * 1.0), Paint()..color = body);
  _paintBody(canvas, Size(w * 1.0, h * 1.0), look, glow);
  // The texel the rounded edges sample (see _dieGeometry): plain body.
  canvas.drawRect(const Rect.fromLTWH(0, 0, 6, 6), Paint()..color = body..blendMode = BlendMode.src);
  final px = _cell * 0.48 / s.span;
  // On a see-through die the number gets a dark rim, so it reads over
  // whatever is behind or inside it.
  final rim = !glow && look.opacity < 1;
  final font = diceFont(look);
  void text(String label, Offset at, double size, double maxWidth, [double angle = 0]) {
    TextPainter painter(Paint p) => TextPainter(
          text: TextSpan(
            text: label,
            style: font.copyWith(foreground: p, fontSize: size),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
    final tp = painter(Paint()..color = ink);
    final fit = math.min(1.0, maxWidth / tp.width);
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..rotate(angle)
      ..scale(fit);
    if (rim) {
      painter(Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size * 0.14
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xE6000000))
          .paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    }
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
// patch at every corner; only the flat parts carry the numbers. [inside] turns
// it inside out: the far faces of a see-through die, seen through the near ones.
// Its atlas layout is the shape's alone, so every look shares one mesh.
MeshGeometry _dieGeometry(DieShape s, {bool inside = false}) =>
    _geometries[(s.name, inside)] ??= _roundedDie(s, inside);
final _geometries = <(String, bool), MeshGeometry>{};

MeshGeometry _roundedDie(DieShape s, bool inside) {
  final g = GeometryBuilder(deduplicate: false);
  final r = _bevel * s.inradius, k = 1 - _bevel;
  final size = vm.Vector2(_cols * _cell * 1.0, _rows(s) * _cell * 1.0);
  final plain = vm.Vector2(2 / size.x, 2 / size.y); // a body-coloured texel
  (vm.Vector3, vm.Vector3, vm.Vector2) round(vm.Vector3 v, vm.Vector3 n) => (v * k + n * r, n, plain);
  void tri(List<(vm.Vector3, vm.Vector3, vm.Vector2)> t) {
    if (inside) t = [for (final (p, n, uv) in t) (p, -n, uv)];
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

/// Every dice look by name: plain resin in each app theme's colours (keyed
/// by theme name), then the named styles.
const diceLooks = <String, DiceLook>{
  'dark': DiceLook(Color(0xFF1F4E79), Color(0xFFF0F4F8)),
  'light': DiceLook(Color(0xFFF4F6FA), Color(0xFF2C5282)),
  'parchment': DiceLook(Color(0xFFE8D5A9), Color(0xFF5D4037)),
  'ocean': DiceLook(Color(0xFF006D7A), Color(0xFFE0F7FA)),
  'emerald': DiceLook(Color(0xFF0B6B3A), Color(0xFFE8FFF1)),
  'midnight': DiceLook(Color(0xFF2A1260), Color(0xFFD1C4FF)),
  'soft': DiceLook(Color(0xFF5865F2), Color(0xFFFFFFFF)),
  'baldur': DiceLook(Color(0xFF2A1A12), Color(0xFFD4AF6A)),
  'grim': DiceLook(Color(0xFF7A0F1C), Color(0xFFF3E6C8)),
  'obsidian': DiceLook(Color(0xFF111111), Color(0xFFD0202A)),
  'frost': DiceLook(Color(0xFFDDF4F2), Color(0xFF1D6B69)),
  'amethyst': DiceLook(Color(0xFF6A2C7A), Color(0xFFF3E5F5)),
  'sunset': DiceLook(Color(0xFFD9542B), Color(0xFF2B1118)),
  'nord': DiceLook(Color(0xFF4C566A), Color(0xFF88C0D0)),
  'rose': DiceLook(Color(0xFFF8BBD0), Color(0xFFAD1457)),
  'terminal': DiceLook(Color(0xFF0A0A0A), Color(0xFF00FF41), font: 'JetBrains Mono'),
  'terra': DiceLook(Color(0xFFC2410C), Color(0xFFFFF8E7), font: 'PT Serif'),
  'jade': DiceLook(Color(0xFF00A86B), Color(0xFFF0FFF8), font: 'Noto Serif'),
  'mono': DiceLook(Color(0xFFFFFFFF), Color(0xFF000000), font: 'JetBrains Mono'),
  'carmine': DiceLook(Color(0xFFDC143C), Color(0xFFFFFFFF), font: 'Playfair Display'),
  // Named styles. Black ink on metal reads as dark enamel in engraved numbers.
  'gold': DiceLook(Color(0xFFE0B04A), Color(0xFF1A1208), metallic: 1, roughness: 0.28, coat: false, font: 'Cinzel'),
  'silver': DiceLook(Color(0xFFD8DCE2), Color(0xFF14161A), metallic: 1, roughness: 0.22, coat: false, font: 'Philosopher'),
  'marble': DiceLook(Color(0xFFF2EFEA), Color(0xFF8A6A1F), paint: DicePaint.marble, accent: Color(0xFF55585E), roughness: 0.2, font: 'Cormorant Garamond'),
  'wood': DiceLook(Color(0xFF8A5A33), Color(0xFF2A160A), paint: DicePaint.wood, accent: Color(0xFF4A2A12), roughness: 0.7, coat: false, font: 'Rye'),
  'bone': DiceLook(Color(0xFFE9DFC8), Color(0xFF4A2F1A), roughness: 0.6, coat: false, font: 'IM Fell English SC'),
  'galaxy': DiceLook(Color(0xFF0B0B24), Color(0xFFF4F0FF), paint: DicePaint.galaxy, accent: Color(0xFFB9A8FF), glow: true, font: 'Audiowide'),
  'infernal': DiceLook(Color(0xFF151012), Color(0xFFFF7A1A), paint: DicePaint.lava, accent: Color(0xFFFF5A0A), roughness: 0.55, coat: false, glow: true, font: 'UnifrakturMaguntia'),
  'crystal': DiceLook(Color(0xFF8FD8FF), Color(0xFFFFFFFF), opacity: 0.3, roughness: 0.05, coat: false, font: 'Quicksand'),
  'dragon-eye': DiceLook(Color(0xFFE89A2E), Color(0xFFFFF2D6), opacity: 0.35, roughness: 0.05, coat: false, core: DiceCore.eye, font: 'Uncial Antiqua'),
  'arcane': DiceLook(Color(0xFF7B4FE0), Color(0xFFF0E8FF), opacity: 0.35, roughness: 0.05, coat: false, core: DiceCore.gem, accent: Color(0xFFB98CFF), font: 'Cinzel Decorative'),
};

enum DicePaint { plain, marble, wood, galaxy, lava }

/// Something inside a see-through die: a dragon's eye that looks up at you
/// when the die lands, or a glowing gem.
enum DiceCore { none, eye, gem }

/// What a die is made of. Every look draws with the same lit material the
/// plain resin uses — the pattern is painted into the number atlas, glow is a
/// second atlas — so none costs more per pixel than resin; a see-through shell
/// blends over whatever is inside, and a [core] is one more small mesh.
class DiceLook {
  const DiceLook(
    this.body,
    this.ink, {
    this.paint = DicePaint.plain,
    this.accent = const Color(0xFF000000),
    this.metallic = 0,
    this.roughness = 0.32,
    this.coat = true,
    this.glow = false,
    this.opacity = 1,
    this.core = DiceCore.none,
    this.font,
  });
  final Color body, ink;
  final DicePaint paint;
  final Color accent; // pattern colour; glowing numbers and cracks; a gem core
  final double metallic, roughness, opacity;
  final bool coat; // clearcoat (desktop only)
  final bool glow; // numbers and pattern shine (emissive atlas)
  final DiceCore core;
  final String? font; // Google Fonts family of the numbers; null = serif
}

/// What a look's numbers are drawn in; the picker labels its chip in it too.
/// One weight only: each weight of a Google font is a download of its own.
TextStyle diceFont(DiceLook look) => look.font == null
    ? const TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w800)
    : GoogleFonts.getFont(look.font!, fontWeight: FontWeight.w800).copyWith(fontFamilyFallback: const ['serif']);

/// The dice look for a `diceTheme` setting: 'auto' follows [appTheme].
String resolveDiceLook(String setting, String appTheme) {
  final name = setting == 'auto' ? appTheme : setting;
  return diceLooks.containsKey(name) ? name : 'dark';
}

// A soft round shadow, dark in the middle: what a phone draws under each die
// instead of a shadow map.
Future<Texture2D> _blobTexture() async {
  const n = 64.0, c = Offset(n / 2, n / 2);
  final rec = ui.PictureRecorder();
  Canvas(rec).drawCircle(
    c,
    n / 2,
    Paint()..shader = ui.Gradient.radial(c, n / 2, const [Color(0x8C000000), Color(0x00000000)], const [0.25, 1]),
  );
  return Texture2D.fromImage(await rec.endRecording().toImage(n.toInt(), n.toInt()), content: TextureContent.data);
}

// A slit-pupil dragon's eye, painted to fill a disc: [_eyeGeometry] projects
// it straight down onto a ball, so it is the ball's top (and bottom).
Future<Texture2D> _eyeTexture() async {
  const n = 256.0, c = Offset(n / 2, n / 2);
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec)
    ..drawRect(const Rect.fromLTWH(0, 0, n, n), Paint()..color = const Color(0xFF3A0A02))
    ..drawCircle(
      c,
      n * 0.42,
      Paint()
        ..shader = ui.Gradient.radial(c, n * 0.42, const [Color(0xFFFFF27A), Color(0xFFF5A623), Color(0xFFB0300A), Color(0xFF3A0A02)],
            const [0, 0.35, 0.8, 1]),
    );
  final rnd = math.Random(3);
  for (var i = 0; i < 90; i++) {
    final a = rnd.nextDouble() * 2 * math.pi, d = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(c + d * n * 0.08, c + d * n * (0.25 + rnd.nextDouble() * 0.15),
        Paint()..color = const Color(0x66601000)..strokeWidth = 1 + rnd.nextDouble() * 1.5);
  }
  canvas.drawOval(
    Rect.fromCenter(center: c, width: n * 0.16, height: n * 0.7),
    Paint()..color = Colors.black..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
  );
  return Texture2D.fromImage(await rec.endRecording().toImage(n.toInt(), n.toInt()), content: TextureContent.data);
}

// A ball of radius 0.5 whose texture is projected along y: the eye looks up +y.
MeshGeometry _eyeGeometry() {
  final g = GeometryBuilder();
  const rings = 10, segs = 16;
  final idx = [
    for (var i = 0; i <= rings; i++)
      [
        for (var j = 0; j < segs; j++)
          () {
            final lat = math.pi * i / rings, lon = 2 * math.pi * j / segs;
            final n = vm.Vector3(math.sin(lat) * math.cos(lon), math.cos(lat), math.sin(lat) * math.sin(lon));
            return g.normal(n).texCoord(vm.Vector2(n.x * 0.5 + 0.5, n.z * 0.5 + 0.5)).addVertex(n * 0.5);
          }(),
      ],
  ];
  for (var i = 0; i < rings; i++) {
    for (var j = 0; j < segs; j++) {
      final a = idx[i][j], b = idx[i][(j + 1) % segs], c = idx[i + 1][j], d = idx[i + 1][(j + 1) % segs];
      g
        ..addTriangle(a, b, d)
        ..addTriangle(a, d, c);
    }
  }
  return g.build();
}

vm.Vector4 _linear(Color c, [double k = 1]) => vm.Vector4(c.r * k, c.g * k, c.b * k, 1);

/// The dice scene, built per dice look (only the last one is kept): a number atlas, rounded mesh and
/// lit material per die shape, lit by one shadow-casting light over an
/// invisible floor that only catches the shadows. Phones skip the shadow map
/// and the clearcoat and lay a [blob] under each die instead. Fails where
/// Flutter GPU is not available; the roller then shows results without the 3D dice.
class DiceKit {
  DiceKit._(this.scene, this.looks, this.backs, this.blob, this.core, this.coreKind);
  final Scene scene;
  final Map<String, (MeshGeometry, PhysicallyBasedMaterial)> looks;
  final Map<String, (MeshGeometry, PhysicallyBasedMaterial)> backs; // see-through looks only
  final (MeshGeometry, UnlitMaterial)? blob; // phones only
  final (MeshGeometry, UnlitMaterial)? core; // inside every die, see-through looks only
  final DiceCore coreKind;

  static (String, Future<DiceKit>)? _kit;
  static Future<DiceKit> load(String look) {
    final kit = _kit;
    if (kit != null && kit.$1 == look) return kit.$2;
    return (_kit = (look, _build(diceLooks[look] ?? diceLooks['dark']!))).$2;
  }

  static Future<DiceKit> _build(DiceLook look) async {
    try {
      // Touch the GPU once first: without Flutter GPU this throws right here,
      // before the engine starts its own loads (whose failures go unhandled).
      Texture2D.fromPixels(Uint8List(4), 1, 1);
      await Scene.initializeStaticResources();
      // The atlas is painted once: its font must be loaded first. Offline and
      // never fetched, google_fonts logs it and the numbers fall back to serif.
      diceFont(look);
      await GoogleFonts.pendingFonts();
      final looks = <String, (MeshGeometry, PhysicallyBasedMaterial)>{}, backs = {...looks};
      for (final s in dieShapes.values) {
        // `data` averages mips as plain bytes. The default (`color`) does it
        // in linear light: millions of pow() calls on the UI isolate, a
        // multi-second freeze on a phone, for a two-colour atlas.
        final tex = await Texture2D.fromImage(await _numberAtlas(s, look), content: TextureContent.data);
        final mat = PhysicallyBasedMaterial(baseColorTexture: tex)
          ..roughnessFactor = look.roughness
          ..metallicFactor = look.metallic
          ..clearcoat = _phone || !look.coat ? 0 : 0.8
          ..clearcoatRoughness = 0.08;
        if (look.glow) {
          mat
            ..emissiveTexture = await Texture2D.fromImage(await _numberAtlas(s, look, glow: true), content: TextureContent.data)
            ..emissiveFactor = vm.Vector4(1, 1, 1, 1)
            ..emissiveStrength = 1.6;
        }
        if (look.opacity < 1) {
          mat.alphaMode = AlphaMode.blend;
          // The engine culls a blended surface's back faces, so the far side
          // is its own inside-out mesh: drawn opaque before the shell, and
          // cut down to just its numbers (the body is below the cutoff).
          // Desktop only: on the phone tier it cost ~10% of GPU time.
          if (!_phone) {
            backs[s.name] = (
              _dieGeometry(s, inside: true),
              PhysicallyBasedMaterial(baseColorTexture: tex)
                ..alphaMode = AlphaMode.mask
                // Seen through the shell: tinted by it, and dimmer than the front.
                ..baseColorFactor = _linear(Color.lerp(look.body, Colors.black, 0.45)!)
                ..roughnessFactor = look.roughness
                ..metallicFactor = 0,
            );
          }
        }
        looks[s.name] = (_dieGeometry(s), mat);
      }
      final core = switch (look.core) {
        DiceCore.none => null,
        // Unlit: a core glows on its own, and lit it cost phones ~10%.
        DiceCore.eye => (_eyeGeometry(), UnlitMaterial(colorTexture: await _eyeTexture())),
        DiceCore.gem => (_dieGeometry(dieShapes['d8']!), UnlitMaterial()..baseColorFactor = _linear(look.accent)),
      };
      final scene = Scene()
        ..directionalLight = DirectionalLight(
          direction: vm.Vector3(-0.6, -1.0, -0.5),
          intensity: 2.2,
          castsShadow: !_phone,
          // The view is one flat tray seen from above: a single cascade
          // fitted to it (DiceView sets shadowMaxDistance) covers it all.
          shadowCascadeCount: 1,
        );
      // Seen from straight above, metal mirrors the environment's even
      // ceiling and reads as flat paint; tilted, it catches the horizon.
      if (look.metallic > 0) scene.environmentTransform = vm.Matrix3.rotationX(1.1);
      if (!_phone) {
        scene.add(Node(
          mesh: Mesh(PlaneGeometry(width: 200, depth: 200), ShadowCatcherMaterial(shadowIntensity: 0.6, aoStrength: 0)),
        ));
      }
      final blob = _phone
          ? (PlaneGeometry(), UnlitMaterial(colorTexture: await _blobTexture())..alphaMode = AlphaMode.blend)
          : null;
      // Compile the pipelines and upload the atlases now (the menu is open,
      // nothing rolls yet), so the first throw doesn't stall on its first frame.
      final probes = [
        for (final (g, m) in [...looks.values, ...backs.values]) Node(mesh: Mesh(g, m)),
        if (blob != null) Node(mesh: Mesh(blob.$1, blob.$2)),
        if (core != null) Node(mesh: Mesh(core.$1, core.$2)),
      ];
      probes.forEach(scene.add);
      await scene.warmUp([RenderView(camera: DiceView(const Size(400, 800)).camera)]);
      probes.forEach(scene.remove);
      return DiceKit._(scene, looks, backs, blob, core, look.core);
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
// Phone GPUs can't afford what desktop draws. Measured at a phone's pixel
// count, the shadow map + full-screen catcher were half the GPU time and
// clearcoat a third more with many dice, so phones drop both (blob shadows
// instead) and render at a capped pixel ratio, MSAA smoothing the rest.
final _phone =
    defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
final _maxPixelRatio = _phone ? 1.25 : 2.0;

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

/// A die of [shape] in [kit]'s look, with its far side and core. [rest] is
/// its rotation once it has landed: an eye core is turned in the die so that
/// it then looks straight up at the camera. A core's shadow is the die's own,
/// so it casts none.
Node _dieNode(DiceKit kit, DieShape shape, vm.Quaternion rest) {
  final (geometry, material) = kit.looks[shape.name]!;
  final node = Node(mesh: Mesh(geometry, material));
  if (kit.backs[shape.name] case (final g, final m)) node.add(Node(mesh: Mesh(g, m))..castsShadows = false);
  if (kit.core case (final g, final m)) {
    final eye = kit.coreKind == DiceCore.eye;
    final core = Node(mesh: Mesh(g, m))
      ..castsShadows = false
      ..scale = vm.Vector3.all(shape.inradius * (eye ? 0.9 : 0.55));
    if (eye) {
      core.rotation = vm.Quaternion.fromTwoVectors(
          vm.Vector3(0, 1, 0), rest.asRotationMatrix().transposed().transform(vm.Vector3(0, 1, 0)));
    }
    node.add(core);
  }
  return node;
}

// --- widget -------------------------------------------------------------------

/// A d20 in [look] seen straight down onto its 20, centred: the dice look
/// picker's preview. Loading it also readies [DiceKit] for the next
/// throw. Shows nothing where Flutter GPU is not available.
class DicePreview extends StatefulWidget {
  const DicePreview({super.key, required this.look, this.size = 120});
  final String look;
  final double size;

  @override
  State<DicePreview> createState() => _DicePreviewState();
}

class _DicePreviewState extends State<DicePreview> {
  // Straight above, close enough that the die fills ~85% of the view; screen
  // up is -Z, as in the roller.
  static final _camera = PerspectiveCamera(
    position: vm.Vector3(0, 3.3, 0),
    target: vm.Vector3.zero(),
    up: vm.Vector3(0, 0, -1),
    fovRadiansY: _fov,
    fovNear: 1,
    fovFar: 6,
  );
  // A scene per look of its own (not the kit's, which the roller fills), and
  // a new one each time, so the view repaints with its fixed camera.
  Scene? _scene;
  Future<void>? _building;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DicePreview old) {
    super.didUpdateWidget(old);
    if (old.look != widget.look) _load();
  }

  Future<void> _load() async {
    final look = widget.look;
    // Tapping through the chips: one kit build at a time, and once it is done
    // only the look still selected is built, not every one tapped past.
    await _building;
    if (!mounted || look != widget.look) return;
    final build = DiceKit.load(look);
    _building = build.then((_) {}, onError: (_) {});
    final DiceKit kit;
    try {
      kit = await build;
    } catch (_) {
      return;
    }
    if (!mounted || look != widget.look) return;
    final d20 = dieShapes['d20']!, f = d20.faces.firstWhere((f) => f.number == 20);
    // The 20's normal to world up, the top of its number to screen up (-Z).
    final rest = vm.Quaternion.fromRotation(
      vm.Matrix3.columns(vm.Vector3(0, 1, 0), vm.Vector3(0, 0, -1), vm.Vector3(-1, 0, 0))
          .multiplied(vm.Matrix3.columns(f.normal, f.up, f.normal.cross(f.up)).transposed()),
    );
    setState(() => _scene = Scene()
      ..directionalLight = DirectionalLight(direction: vm.Vector3(-0.6, -1.0, -0.5), intensity: 2.2)
      ..environmentTransform = kit.scene.environmentTransform.clone()
      ..add(_dieNode(kit, d20, rest)..rotation = rest));
  }

  @override
  Widget build(BuildContext context) {
    final scene = _scene;
    return SizedBox.square(
      dimension: widget.size,
      child: scene == null
          ? null
          : SceneView(
              scene,
              camera: _camera,
              autoTick: false,
              pixelRatio: math.min(_maxPixelRatio, MediaQuery.devicePixelRatioOf(context)),
            ),
    );
  }
}

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
    this.onRolled,
  });
  final Map<String, int> counts;
  final String look;
  final int modifier; // added to the dice total, e.g. a skill bonus
  final String? label; // what was rolled, e.g. "Stealth"
  final VoidCallback onClose;

  /// Once, as soon as the throw is decided — before the dice even fly, so the
  /// session log (and a player's DM) gets it without waiting for them to land.
  final void Function(DiceRoll roll)? onRolled;

  @override
  State<DiceRollView> createState() => _DiceRollViewState();
}

class _DiceRollViewState extends State<DiceRollView> {
  DiceView? _view;
  DiceRoll? _roll;
  DiceKit? _kit;
  final _nodes = <Node>[], _blobs = <Node>[];
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
    final onRolled = widget.onRolled;
    if (onRolled != null) roll.then(onRolled).ignore();
    final kit = DiceKit.load(widget.look).then<DiceKit?>((k) => k, onError: (_) => null);
    Future.wait([roll, kit]).then((r) {
      if (!mounted) return;
      final roll = r[0] as DiceRoll, kit = r[1] as DiceKit?;
      if (kit != null) {
        kit.scene.directionalLight!.shadowMaxDistance = view.shadowDistance;
        final blob = kit.blob;
        for (final d in roll.dice) {
          _nodes.add(_dieNode(kit, d.shape, d.poseAt(d.steps - 1).$2));
          if (blob != null) _blobs.add(Node(mesh: Mesh(blob.$1, blob.$2)));
        }
        for (var i = 0; i < roll.dice.length; i++) {
          _place(i, roll.dice[i], 0);
        }
        [..._blobs, ..._nodes].forEach(kit.scene.add);
      }
      setState(() {
        _roll = roll;
        _kit = kit;
      });
      if (kit == null) _land();
    });
  }

  void _land() => setState(() => _settled = true);

  @override
  void dispose() {
    for (final n in [..._nodes, ..._blobs]) {
      _kit?.scene.remove(n);
    }
    super.dispose();
  }

  void _place(int i, ThrownDie d, int step) {
    final (p, q) = d.poseAt(step);
    _nodes[i]
      ..position = p
      ..rotation = q;
    if (_blobs.isEmpty) return;
    // Where the die's centre falls along the light (-0.6, -1, -0.5), on the
    // floor, and wider as it rises.
    final w = 1.9 * d.shape.radius + 0.3 * p.y;
    _blobs[i]
      ..position = vm.Vector3(p.x - 0.6 * p.y, 0.01, p.z - 0.5 * p.y)
      ..scale = vm.Vector3(w, 1, w);
  }

  void _tick(Duration _, double dt) {
    final roll = _roll;
    if (roll == null || _settled) return;
    // Don't let a frame stall teleport the animation to its end.
    _t += math.min(dt, 1 / 30);
    final step = (_t * diceSimHz).floor();
    for (var i = 0; i < roll.dice.length; i++) {
      _place(i, roll.dice[i], step);
    }
    if (step >= roll.steps - 1) _land();
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
                // Dice are ~100 px across; past this a device just pays fill
                // rate (every floor pixel runs a 16-tap shadow lookup).
                pixelRatio: math.min(_maxPixelRatio, MediaQuery.devicePixelRatioOf(context)),
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

/// The dice line under a roll's total, e.g. "d20: 12 + 5" or
/// "2d6: 3 + 4 = 7  ·  d8: 5".
String rollBreakdown(DiceRoll roll, int modifier) {
  final single = roll.dice.length == 1 || (roll.results.length == 1 && roll.results.values.first.length == 1);
  final dice = single
      ? (modifier == 0 ? roll.results.keys.single : '${roll.results.keys.single}: ${roll.total}')
      : [
          for (final MapEntry(key: k, value: vs) in roll.results.entries)
            vs.length == 1 ? '$k: ${vs.single}' : '${vs.length}$k: ${vs.join(' + ')} = ${vs.reduce((a, b) => a + b)}',
        ].join('  ·  ');
  return modifier == 0 ? dice : '$dice ${modifier > 0 ? '+' : '−'} ${modifier.abs()}';
}

class _ResultCard extends StatelessWidget {
  const _ResultCard(this.roll, {this.modifier = 0, this.label});
  final DiceRoll roll;
  final int modifier;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final breakdown = rollBreakdown(roll, modifier);
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
