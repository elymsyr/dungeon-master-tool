// Dice roller physics: die shapes, a throw simulated up front, and the face
// remap that makes every die land on a result Random decided before the
// throw. Pure Dart + vector_math so it runs (and is tested) without a GPU;
// dice_roll_view.dart renders the tracks it produces.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart' as vm;

/// What the roller offers, in menu order. A d100 is thrown as a d% and a d10.
const diceKinds = ['d4', 'd6', 'd8', 'd10', 'd12', 'd20', 'd100'];

/// Most dice one throw takes; the tray stays readable and the sim fast.
const maxDicePerRoll = 30;

/// Dice a kind throws: two for a d100, one otherwise.
int diceIn(String kind) => kind == 'd100' ? 2 : 1;

// --- geometry ------------------------------------------------------------------

class DieFace {
  DieFace(this.poly, this.normal) : centroid = _mean(poly);
  final List<vm.Vector3> poly; // CCW around the outward normal
  final vm.Vector3 normal, centroid;
  late vm.Vector3 up; // where the number's top points, in the face plane
  int number = 0;
}

vm.Vector3 _mean(Iterable<vm.Vector3> vs) =>
    vs.fold(vm.Vector3.zero(), (a, v) => a + v) / vs.length.toDouble();

// Faces of a convex vertex set: every plane through three corners with all
// the others behind it, its corners sorted CCW around the outward normal.
List<DieFace> _hull(List<vm.Vector3> verts) {
  final faces = <DieFace>[];
  for (var i = 0; i < verts.length; i++) {
    for (var j = i + 1; j < verts.length; j++) {
      for (var k = j + 1; k < verts.length; k++) {
        final n = (verts[j] - verts[i]).cross(verts[k] - verts[i]);
        if (n.length < 1e-6) continue;
        n.normalize();
        if (n.dot(verts[i]) < 0) n.negate();
        final d = n.dot(verts[i]);
        if (verts.any((v) => n.dot(v) > d + 1e-4)) continue;
        if (faces.any((f) => f.normal.dot(n) > 0.9999)) continue;
        final poly = verts.where((v) => (n.dot(v) - d).abs() < 1e-4).toList();
        final c = _mean(poly);
        final e1 = (poly.first - c)..normalize();
        final e2 = n.cross(e1);
        double angle(vm.Vector3 v) => math.atan2((v - c).dot(e2), (v - c).dot(e1));
        poly.sort((a, b) => angle(a).compareTo(angle(b)));
        faces.add(DieFace(poly, n));
      }
    }
  }
  return faces;
}

class DieShape {
  DieShape(this.name, this.radius, this.verts, this.faces)
      : inradius = faces.first.normal.dot(faces.first.poly.first),
        span = faces.first.poly.map((v) => v.distanceTo(faces.first.centroid)).reduce(math.max),
        inertia = 0.4 * radius * radius; // unit mass, close to a sphere
  final String name;
  final double radius, inradius, span, inertia; // span: face centre to corner
  final List<vm.Vector3> verts;
  final List<DieFace> faces;

  // A d4 is read at the corner pointing up, so its result is the face it lies on.
  bool get readsBottom => name == 'd4';

  String label(int n) => switch (name) {
        'd10' => _dot('${n - 1}'),
        'd%' => '${n - 1}0',
        _ => _dot('$n'),
      };

  int value(int n) => switch (name) {
        'd10' => n == 1 ? 10 : n - 1,
        'd%' => (n - 1) * 10,
        _ => n,
      };
}

String _dot(String s) => s == '6' || s == '9' ? '$s.' : s;

DieShape _shape(String name, double radius, List<vm.Vector3> raw) {
  final far = raw.map((v) => v.length).reduce(math.max);
  final verts = [for (final v in raw) v * (radius / far)];
  final faces = _hull(verts);
  if (name == 'd4') {
    for (var i = 0; i < faces.length; i++) {
      faces[i].number = i + 1;
    }
  } else {
    // Opposite faces sum to n + 1, like real dice (a d10's 0–9 sum to 9).
    var next = 1;
    for (final f in faces) {
      if (f.number != 0) continue;
      final opp = faces.firstWhere((o) => o.normal.dot(f.normal) < -0.999);
      f.number = next;
      opp.number = faces.length + 1 - next;
      next++;
    }
  }
  for (final f in faces) {
    final tip = switch (name) {
      'd6' => (f.poly[0] + f.poly[1]) * 0.5, // square: number sits square to an edge
      'd10' || 'd%' => f.poly.reduce((a, b) => a.y.abs() > b.y.abs() ? a : b), // kite: toward the pole
      _ => f.poly[0],
    };
    f.up = (tip - f.centroid)..normalize();
  }
  return DieShape(name, radius, verts, faces);
}

// Every sign combination of (x, y, z), zeros not doubled.
List<vm.Vector3> _pm(double x, double y, double z) => [
      for (final sx in x == 0 ? [1] : [1, -1])
        for (final sy in y == 0 ? [1] : [1, -1])
          for (final sz in z == 0 ? [1] : [1, -1]) vm.Vector3(x * sx, y * sy, z * sz),
    ];

final _phi = (1 + math.sqrt(5)) / 2;

// Pentagonal trapezohedron: two poles and a zig-zag ring. The pole height that
// makes each kite flat is a·(1 + cos36°)/(1 − cos36°).
List<vm.Vector3> _d10Verts() {
  const a = 0.1;
  final c36 = math.cos(math.pi / 5);
  final h = a * (1 + c36) / (1 - c36);
  return [
    vm.Vector3(0, h, 0),
    vm.Vector3(0, -h, 0),
    for (var k = 0; k < 5; k++) ...[
      vm.Vector3(math.cos(k * 2 * math.pi / 5), a, math.sin(k * 2 * math.pi / 5)),
      vm.Vector3(math.cos((k + 0.5) * 2 * math.pi / 5), -a, math.sin((k + 0.5) * 2 * math.pi / 5)),
    ],
  ];
}

/// Every die shape by name; 'd%' is the tens die of a d100.
final dieShapes = {
  for (final s in [
    _shape('d4', 0.85, [vm.Vector3(1, 1, 1), vm.Vector3(1, -1, -1), vm.Vector3(-1, 1, -1), vm.Vector3(-1, -1, 1)]),
    _shape('d6', 0.62, _pm(1, 1, 1)),
    _shape('d8', 0.66, [..._pm(1, 0, 0), ..._pm(0, 1, 0), ..._pm(0, 0, 1)]),
    _shape('d10', 0.62, _d10Verts()),
    _shape('d%', 0.62, _d10Verts()),
    _shape('d12', 0.62, [..._pm(1, 1, 1), ..._pm(0, 1 / _phi, _phi), ..._pm(1 / _phi, _phi, 0), ..._pm(_phi, 0, 1 / _phi)]),
    _shape('d20', 0.6, [..._pm(0, 1, _phi), ..._pm(1, _phi, 0), ..._pm(_phi, 0, 1)]),
  ])
    s.name: s,
};

// --- physics + face remap -------------------------------------------------------
//
// The dice are really simulated (a tiny rigid-body sim, run up front in one go),
// so where they start, how they bounce and where they stop is all physical.
// Then each die is relabelled with one of its own rotational symmetries so the
// face that physically ended up as the result carries the number Random
// decided. A symmetry maps the corners onto themselves, so the relabelled die
// has the exact same shape and every frame of the motion stays physically valid.
// Contacts use the sharp corners; the rounding is a few % and only shows as a
// hair of air under a die balancing on an edge mid-tumble.

final _up = vm.Vector3(0, 1, 0);
// Camera sits at +Z looking down, so "up on screen" across the table is -Z.
final _screenUp = vm.Vector3(0, 0, -1);

/// Simulation steps per second of animation; a track holds one pose per step.
const diceSimHz = 240;
const _gravity = 30.0;
const _friction = 0.45;

// A point p is inside a plane (n, offset) when n·p >= offset.
typedef _Plane = (vm.Vector3, double);

// Floor + four invisible walls around the tray.
List<_Plane> _tray(double x, double z) => [
      (vm.Vector3(0, 1, 0), 0.0),
      (vm.Vector3(1, 0, 0), -x),
      (vm.Vector3(-1, 0, 0), -x),
      (vm.Vector3(0, 0, 1), -z),
      (vm.Vector3(0, 0, -1), -z),
    ];

class _Body {
  _Body(this.shape, this.pos, this.vel, this.rot, this.omega)
      : corners = [for (final _ in shape.verts) vm.Vector3.zero()];
  final DieShape shape;
  vm.Vector3 pos, vel, omega;
  vm.Quaternion rot;
  // Corners turned into world orientation (relative to pos), refilled every
  // step instead of allocated: the sim's hot loop reads them several times.
  final List<vm.Vector3> corners;
  int still = 0, cocked = 0;
  bool get asleep => still > diceSimHz ~/ 4;

  // Impulse dir·size at corner r.
  void impulse(vm.Vector3 r, vm.Vector3 dir, double size) {
    vel.addScaled(dir, size);
    omega.addScaled(r.crossInto(dir, _c), size / shape.inertia);
  }
}

// Scratch vectors for the contact solver, which would otherwise allocate a
// handful per contact per pass. The sim runs on one isolate at a time.
final _v = vm.Vector3.zero(), _c = vm.Vector3.zero();

// World normal of the face the die is lying on (or closest to lying on).
vm.Vector3 _downNormal(DieShape s, vm.Matrix3 m) =>
    s.faces.map((f) => m.transformed(f.normal)).reduce((x, y) => x.y < y.y ? x : y);

void _step(List<_Body> bodies, List<_Plane> planes) {
  const dt = 1 / diceSimHz;
  for (final b in bodies) {
    if (b.asleep) continue;
    final s = b.shape;
    b.vel.y -= _gravity * dt;
    b.pos.addScaled(b.vel, dt);
    final w = b.omega.length;
    if (w > 1e-9) {
      b.rot = (vm.Quaternion.axisAngle(b.omega / w, w * dt) * b.rot)..normalize();
    }
    final m = b.rot.asRotationMatrix();
    for (var c = 0; c < s.verts.length; c++) {
      m.transform(b.corners[c]..setFrom(s.verts[c]));
    }
    final contacts = <(vm.Vector3, vm.Vector3)>[];
    for (final (n, offset) in planes) {
      // No corner reaches past the bounding sphere: most steps skip the walls.
      if (n.dot(b.pos) - s.radius >= offset) continue;
      for (final r in b.corners) {
        final depth = offset - n.dot(b.pos) - n.dot(r);
        if (depth <= 0) continue;
        b.pos.addScaled(n, depth);
        contacts.add((n, r));
      }
    }
    // A few sequential-impulse passes so a die lying on a face really comes
    // to rest instead of trading tiny impulses between its corners.
    for (var it = 0; it < 4; it++) {
      for (final (n, r) in contacts) {
        final vn = (b.omega.crossInto(r, _v)..add(b.vel)).dot(n); // corner velocity
        if (vn >= 0) continue;
        // Bounce only on real impacts; resting contacts get none (no jitter).
        final e = it == 0 && vn < -2 ? 0.3 : 0.0;
        final jn = -(1 + e) * vn / (1 + r.crossInto(n, _c).length2 / s.inertia);
        b.impulse(r, n, jn);
        final vc = b.omega.crossInto(r, _v)..add(b.vel);
        final vt = vc..addScaled(n, -vc.dot(n)); // sliding part
        final vtLen = vt.length;
        if (vtLen < 1e-6) continue;
        final t = vt..scale(1 / vtLen);
        final jt = math.min(vtLen / (1 + r.crossInto(t, _c).length2 / s.inertia), _friction * jn);
        b.impulse(r, t, -jt);
      }
    }
    b.omega.scale(contacts.isEmpty ? 0.999 : 0.992);
    // Sleep only face-down (3+ corners on the felt), never balanced on an edge.
    final floorCorners = b.corners.where((r) => b.pos.y + r.y < 0.01).length;
    final slow = b.vel.length2 < 0.02 && b.omega.length2 < 0.1;
    if (floorCorners >= 3 && slow) {
      b.still++;
      if (b.asleep) {
        b.vel.setZero();
        b.omega.setZero();
      }
    } else {
      b.still = 0;
    }
    // Cocked die (rocking on an edge, or leaning on a wall or a neighbour):
    // tip it toward its nearest face, the way you'd tap the tray.
    final cocked = floorCorners < 3 && b.pos.y < s.radius && b.vel.length2 < 0.25;
    b.cocked = cocked ? b.cocked + 1 : 0;
    if (b.cocked > diceSimHz ~/ 8) {
      b.cocked = 0;
      final axis = _downNormal(s, m).cross(-_up);
      if (axis.length2 > 1e-8) b.omega.add(axis.normalized() * 2.5);
    }
  }
  // Dice knock into each other as spheres around their corners, pushed apart
  // sideways only: the meshes can never sink into each other, and one can
  // never come to rest propped on another (it would show a tilted face).
  for (var i = 0; i < bodies.length; i++) {
    for (var j = i + 1; j < bodies.length; j++) {
      final a = bodies[i], b = bodies[j];
      if (a.asleep && b.asleep) continue;
      final reach = a.shape.radius + b.shape.radius;
      final dx = b.pos.x - a.pos.x, dy = b.pos.y - a.pos.y, dz = b.pos.z - a.pos.z;
      if (dx * dx + dy * dy + dz * dz >= reach * reach) continue;
      final d = vm.Vector3(dx, 0, dz);
      final dist = d.length;
      if (dist < 1e-6) continue;
      final n = d / dist;
      // A resting die is a wall for the one bumping into it.
      final overlap = reach - dist;
      final wa = a.asleep ? 0.0 : (b.asleep ? 1.0 : 0.5);
      a.pos.addScaled(n, -overlap * wa);
      b.pos.addScaled(n, overlap * (1 - wa));
      final vn = (b.vel - a.vel).dot(n);
      if (vn >= 0) continue;
      final jn = -(1 + 0.4) * vn * (a.asleep || b.asleep ? 1 : 0.5);
      if (!a.asleep) a.vel.addScaled(n, -jn);
      if (!b.asleep) b.vel.addScaled(n, jn);
      // Only a real knock wakes a die; resting neighbours touching is not one.
      if (vn < -0.3) {
        a.still = 0;
        b.still = 0;
      }
    }
  }
}

/// One die's motion: per sim step its position (x, y, z) then rotation
/// (x, y, z, w), packed flat so a roll crosses the isolate boundary as a few
/// typed arrays instead of thousands of small objects.
typedef DiceTrack = Float32List;
const _poseLen = 7;

class _TrackWriter {
  var data = Float32List(_poseLen * diceSimHz);
  var length = 0;

  void add(vm.Vector3 p, vm.Quaternion q) {
    if (length + _poseLen > data.length) {
      data = Float32List(data.length * 2)..setAll(0, data);
    }
    data
      ..[length] = p.x
      ..[length + 1] = p.y
      ..[length + 2] = p.z
      ..[length + 3] = q.x
      ..[length + 4] = q.y
      ..[length + 5] = q.z
      ..[length + 6] = q.w;
    length += _poseLen;
  }

  DiceTrack done() => Float32List.sublistView(data, 0, length);
}

List<DiceTrack> _simulate(List<_Body> bodies, List<_Plane> planes) {
  final tracks = [for (final _ in bodies) _TrackWriter()];
  for (var s = 0; s < diceSimHz * 4; s++) {
    _step(bodies, planes);
    for (var i = 0; i < bodies.length; i++) {
      tracks[i].add(bodies[i].pos, bodies[i].rot);
    }
    if (bodies.every((b) => b.asleep)) break;
  }
  // ponytail: a die still moving at the cap (jammed against a wall or a
  // neighbour) just tips onto its nearest face over a quarter second.
  for (var i = 0; i < bodies.length; i++) {
    final b = bodies[i];
    if (b.asleep) continue;
    final down = _downNormal(b.shape, b.rot.asRotationMatrix());
    var to = vm.Quaternion.fromTwoVectors(down, -_up) * b.rot;
    final from = b.rot;
    if (from.x * to.x + from.y * to.y + from.z * to.z + from.w * to.w < 0) to = -to;
    final tm = to.asRotationMatrix();
    final p0 = b.pos.clone();
    final p1 = p0.clone()..y = -b.shape.verts.map((v) => tm.transformed(v).y).reduce(math.min);
    const n = diceSimHz ~/ 4;
    for (var k = 1; k <= n; k++) {
      final e = 1 - math.pow(1 - k / n, 2).toDouble();
      tracks[i].add(p0 + (p1 - p0) * e, (from.scaled(1 - e) + to.scaled(e))..normalize());
    }
  }
  return [for (final t in tracks) t.done()];
}

// Body-frame symmetry C that maps the decided face onto the face that landed
// (C·n_decided = n_landed). Of the ways to do that, pick the one that leaves
// the number most upright for the camera.
vm.Quaternion _remap(DieShape s, DieFace decided, DieFace landed, vm.Matrix3 finalRot) {
  final from = vm.Matrix3.columns(decided.poly[0], decided.poly[1], decided.poly[2])..invert();
  final to = landed.poly, n = to.length;
  vm.Matrix3? best;
  var bestDot = -2.0;
  for (var k = 0; k < n; k++) {
    final c = vm.Matrix3.columns(to[k], to[(k + 1) % n], to[(k + 2) % n]).multiplied(from);
    // Only a real symmetry carries every corner onto a corner (a d10's kite
    // fits itself one way only); anything else would warp the die.
    final isSymmetry = s.verts.every((v) {
      final w = c.transformed(v);
      return s.verts.any((u) => u.distanceTo(w) < 1e-3);
    });
    if (!isSymmetry) continue;
    final top = finalRot.multiplied(c).transformed(decided.up)..y = 0;
    final d = top.normalized().dot(_screenUp);
    if (d > bestDot) {
      bestDot = d;
      best = c;
    }
  }
  return vm.Quaternion.fromRotation(best!);
}

// One throw = one hand: a random tray edge, a random aim point, and the dice
// leave it as a loose handful.
List<_Body> _throw(math.Random rng, List<DieShape> dice, double trayX, double trayZ) {
  final side = rng.nextInt(4);
  final along = rng.nextDouble() * 2 - 1;
  final origin = switch (side) {
    0 => vm.Vector3(-trayX + 1, 0, along * (trayZ - 1)),
    1 => vm.Vector3(trayX - 1, 0, along * (trayZ - 1)),
    2 => vm.Vector3(along * (trayX - 1), 0, -trayZ + 1),
    _ => vm.Vector3(along * (trayX - 1), 0, trayZ - 1),
  };
  final aim = vm.Vector3(
    (rng.nextDouble() * 2 - 1) * trayX * 0.4,
    0,
    (rng.nextDouble() * 2 - 1) * trayZ * 0.4,
  );
  final spread = 0.5 + 0.25 * math.sqrt(dice.length);
  final bodies = <_Body>[];
  for (final s in dice) {
    vm.Vector3 p;
    var tries = 0;
    do {
      p = origin +
          vm.Vector3(
            (rng.nextDouble() * 2 - 1) * spread,
            1.2 + rng.nextDouble() * (0.8 + dice.length * 0.08),
            (rng.nextDouble() * 2 - 1) * spread,
          );
    } while (++tries < 60 && bodies.any((b) => b.pos.distanceTo(p) < b.shape.radius + s.radius));
    final dir = (aim - p)..y = 0;
    final vel = dir.normalized() * (5 + rng.nextDouble() * 3)
      ..y = rng.nextDouble() * 2;
    final omega = (vm.Vector3.random(rng) - vm.Vector3.all(0.5)).normalized() *
        (10 + rng.nextDouble() * 12);
    bodies.add(_Body(s, p, vel, vm.Quaternion.random(rng), omega));
  }
  return bodies;
}

// --- a roll -----------------------------------------------------------------------

/// One die of a roll: how it moves and what it shows when it stops.
class ThrownDie {
  ThrownDie(this.shape, this.face, this.track, this.remap);
  final DieShape shape;
  final DieFace face; // decided before the throw
  final DiceTrack track;
  final vm.Quaternion remap; // body-frame relabel, applied under every pose

  /// Sim steps in [track]; the die rests at the last one.
  int get steps => track.length ~/ _poseLen;

  /// Pose at sim step [i] (clamped to the last one, where the die rests).
  (vm.Vector3, vm.Quaternion) poseAt(int i) {
    final o = math.min(i, steps - 1) * _poseLen;
    final t = track;
    return (
      vm.Vector3(t[o], t[o + 1], t[o + 2]),
      vm.Quaternion(t[o + 3], t[o + 4], t[o + 5], t[o + 6]) * remap,
    );
  }
}

class DiceRoll {
  DiceRoll(this.dice, this.results);
  final List<ThrownDie> dice;

  /// Values per kind, in [diceKinds] order (a d100 is one value, 1–100).
  final Map<String, List<int>> results;

  int get total => results.values.expand((v) => v).fold(0, (a, b) => a + b);

  /// Sim steps until every die rests.
  int get steps => dice.fold(0, (a, d) => math.max(a, d.steps));
}

/// Throws [counts] (kind → how many) into a tray of half-size [trayX] × [trayZ]
/// on the floor plane. Results are drawn from [rng]; the motion only shows them.
DiceRoll throwDice(Map<String, int> counts, math.Random rng, {required double trayX, required double trayZ}) {
  final kinds = [
    for (final k in diceKinds)
      for (var i = 0; i < (counts[k] ?? 0); i++) k,
  ];
  final shapes = [
    for (final k in kinds) ...(k == 'd100' ? [dieShapes['d%']!, dieShapes['d10']!] : [dieShapes[k]!]),
  ];
  final tracks = _simulate(_throw(rng, shapes, trayX, trayZ), _tray(trayX, trayZ));
  final dice = <ThrownDie>[];
  for (var i = 0; i < shapes.length; i++) {
    final s = shapes[i];
    final t = tracks[i], o = t.length - 4; // the last pose's rotation
    final finalRot = vm.Quaternion(t[o], t[o + 1], t[o + 2], t[o + 3]).asRotationMatrix();
    double y(DieFace f) => finalRot.transformed(f.normal).y;
    final landed = s.readsBottom
        ? s.faces.reduce((a, b) => y(a) < y(b) ? a : b)
        : s.faces.reduce((a, b) => y(a) > y(b) ? a : b);
    final decided = s.faces[rng.nextInt(s.faces.length)]; // the result is decided here, before the animation
    dice.add(ThrownDie(s, decided, tracks[i], _remap(s, decided, landed, finalRot)));
  }
  final results = <String, List<int>>{};
  var i = 0;
  for (final k in kinds) {
    final int v;
    if (k == 'd100') {
      // 00 + 0 reads as 100.
      final sum = (dice[i++].face.number - 1) * 10 + dice[i++].face.number - 1;
      v = sum == 0 ? 100 : sum;
    } else {
      final d = dice[i++];
      v = d.shape.value(d.face.number);
    }
    (results[k] ??= []).add(v);
  }
  return DiceRoll(dice, results);
}
