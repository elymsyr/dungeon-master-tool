import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Dikey Material [Stepper]'da adım değişince yeni adımın başlığını
/// görünümün en üstüne getirir (liste sonu izin verdiği kadar).
///
/// Stepper bunu kendisi yapmıyor: Devam/Geri'de hiç kaydırmıyor, başlığa
/// tıklamada da hedefi eski adım kapanmadan ölçüyor. Kendi `ListView`'i ekran
/// dışındaki adımları layout etmediğinden liste boyunu tahmin ediyor; uzun
/// bir adım açıkken tahmin katlarca büyük çıkıyor ve görünüm liste sonundaki
/// boşluğa kayabiliyor.
///
/// Kullanım: Stepper `physics: NeverScrollableScrollPhysics()` ile
/// [controller]'lı bir `SingleChildScrollView` içine konur (iç liste her şeyi
/// serer, boy kesinleşir), her `Step.content`'e [bodyKeys]'teki anahtarı
/// verilir, `currentStep`'i değiştiren setState'in yanında [reveal] çağrılır.
class StepperScroll {
  StepperScroll(int stepCount)
      : bodyKeys = List.generate(stepCount, (_) => GlobalKey());

  final ScrollController controller = ScrollController();
  final List<GlobalKey> bodyKeys;
  int _seq = 0;

  void dispose() => controller.dispose();

  void reveal(int from, int to) {
    if (from == to) return;
    final seq = ++_seq;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _reveal(seq, from, to));
  }

  Future<void> _reveal(int seq, int from, int to) async {
    if (!controller.hasClients) return;
    final pos = controller.position;
    // Başlığa tıklamada Stepper eski düzene göre kendi kaydırmasını başlattı;
    // durdur. Duran konum, içerik küçülünce sınıra kırpılır.
    pos.jumpTo(pos.pixels);
    final a = _geometry(from);
    final b = _geometry(to);
    final ctx = bodyKeys[to].currentContext;
    final keyboard = ctx != null && MediaQuery.viewInsetsOf(ctx).bottom > 0;
    if (a != null && b != null && pos.maxScrollExtent > 0 && !keyboard) {
      // Geçişin ilk karesi: Stepper gövdeleri saran AnimatedSize'ları yeni
      // başlattı — eski gövde hâlâ tam boy, yenisi 0. Son düzeni bu bekleyen
      // boy değişimlerinden hesaplayıp kaydırmayı onlarla aynı saat ve eğride
      // sürünce başlık bulunduğu yerden en üste kayar; konum da liste sonu da
      // aynı eğriyle doğrusal değiştiği için yol sınırı hiç aşmaz.
      final top = _offsetOf(b.box) + (from < to ? a.growth : 0.0);
      final end = pos.maxScrollExtent + a.growth + b.growth;
      final target = clampDouble(
          top, pos.minScrollExtent, math.max(pos.minScrollExtent, end));
      // AnimatedSize'lar bu karenin zaman damgasıyla başladı; animateTo bir
      // kare geç başlar ve başlık hedefi aşıp geri döner. Konumu aynı saatle
      // her karede kendimiz kuruyoruz.
      final binding = WidgetsBinding.instance;
      final start = pos.pixels;
      final t0 = binding.currentFrameTimeStamp;
      final done = Completer<bool>();
      void tick(Duration now) {
        // Yeni geçiş başladıysa ya da kullanıcı kaydırıyorsa bırak.
        if (seq != _seq ||
            !controller.hasClients ||
            controller.position.isScrollingNotifier.value) {
          return done.complete(false);
        }
        final t = math.min(1.0,
            (now - t0).inMicroseconds / kThemeAnimationDuration.inMicroseconds);
        controller.jumpTo(
            start + (target - start) * Curves.fastOutSlowIn.transform(t));
        if (t < 1) {
          binding.scheduleFrameCallback(tick);
        } else {
          done.complete(true);
        }
      }

      binding.scheduleFrameCallback(tick);
      if (!await done.future) return;
    } else {
      // Tahmin yok (adım ekran dışında, içerik ekrana sığıyor ya da klavye
      // kapanırken görünüm büyüyor): kapanma bitince hizala.
      await Future<void>.delayed(kThemeAnimationDuration);
    }
    await WidgetsBinding.instance.endOfFrame;
    final g = _geometry(to);
    if (seq != _seq || g == null || !controller.hasClients) return;
    final p = controller.position;
    final target =
        clampDouble(_offsetOf(g.box), p.minScrollExtent, p.maxScrollExtent);
    if ((target - p.pixels).abs() > 1) {
      await controller.animateTo(target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic);
    }
  }

  /// Adım [i]'nin listedeki kutusu (başlık + gövde) ve gövdesini saran
  /// AnimatedSize'ın henüz uygulanmamış boy değişimi (+ açılıyor, − kapanıyor).
  ({RenderBox box, double growth})? _geometry(int i) {
    // Stepper içeriği AnimatedCrossFade'in AnimatedSize'ına koyar, her adımı
    // da listenin tek çocuğu yapar; içerikten bu ikisine yukarı çıkıyoruz.
    RenderObject? o = bodyKeys[i].currentContext?.findRenderObject()?.parent;
    double? growth;
    while (o != null && o.parent is! RenderSliverMultiBoxAdaptor) {
      if (growth == null && o is RenderAnimatedSize) {
        final child = o.child;
        if (child == null || !child.hasSize || !o.hasSize) return null;
        growth = child.size.height - o.size.height;
      }
      o = o.parent;
    }
    return o is RenderBox && growth != null ? (box: o, growth: growth) : null;
  }

  /// [box]'ın üstünü dış kaydırmanın en üstüne getiren offset. En yakın
  /// viewport Stepper'ın kaydırmayan kendi listesi, bir üstü bizimki.
  static double _offsetOf(RenderBox box) {
    final inner = RenderAbstractViewport.of(box) as RenderObject;
    return RenderAbstractViewport.of(inner.parent)
        .getOffsetToReveal(box, 0)
        .offset;
  }
}
