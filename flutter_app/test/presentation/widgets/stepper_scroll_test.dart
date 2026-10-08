import 'package:dungeon_master_tool/presentation/widgets/stepper_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Karakter sihirbazının düzeni: dış SingleChildScrollView + kendisi
/// kaydırmayan dikey Stepper; aktif olmayan adımın içeriği boş.
class _Wizard extends StatefulWidget {
  const _Wizard(this.heights, {this.initial = 0});
  final List<double> heights;
  final int initial;

  @override
  State<_Wizard> createState() => _WizardState();
}

class _WizardState extends State<_Wizard> {
  late final scroll = StepperScroll(widget.heights.length);
  late int current = widget.initial;

  void go(int to) {
    final from = current;
    setState(() => current = to);
    scroll.reveal(from, to);
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          appBar: AppBar(),
          body: SingleChildScrollView(
            controller: scroll.controller,
            child: Stepper(
              physics: const NeverScrollableScrollPhysics(),
              currentStep: current,
              onStepTapped: go,
              onStepContinue: () => go(current + 1),
              onStepCancel: () => go(current - 1),
              steps: [
                for (var i = 0; i < widget.heights.length; i++)
                  Step(
                    title: Text('Step $i'),
                    content: SizedBox(
                      key: scroll.bodyKeys[i],
                      height: i == current ? widget.heights[i] : 0,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

ScrollPosition _pos(WidgetTester t) =>
    t.state<_WizardState>(find.byType(_Wizard)).scroll.controller.position;

double _viewportTop(WidgetTester t) =>
    t.getTopLeft(find.byType(SingleChildScrollView)).dy;

/// Başlık metninin, başlık satırının üstünden uzaklığı (her adımda aynı).
late double _titleInset;

/// Adım [i] başlık satırının görünümün üstüne uzaklığı; 0 = en üstte.
double _headerY(WidgetTester t, int i) =>
    t.getTopLeft(find.text('Step $i')).dy - _viewportTop(t) - _titleInset;

Future<void> _pumpWizard(WidgetTester t, _Wizard w) async {
  await t.pumpWidget(w);
  await t.pumpAndSettle();
  // İlk adımın başlığı içeriğin en başında.
  _titleInset = t.getTopLeft(find.text('Step 0')).dy -
      _viewportTop(t) +
      _pos(t).pixels;
}

Future<void> _jumpToEnd(WidgetTester t) async {
  final p = _pos(t);
  p.jumpTo(p.maxScrollExtent);
  await t.pump();
  // Tahmini değil gerçek extent: en dipte içeriğin sonu görünümün sonunda,
  // altında boşluk yok.
  expect(
    t.getBottomLeft(find.byType(Stepper)).dy,
    moreOrLessEquals(t.getBottomLeft(find.byType(SingleChildScrollView)).dy,
        epsilon: 1),
  );
}

/// Geçişi kare kare oynatır; hiçbir karede kaydırma sınırı aşılmamalı
/// (aşılırsa görünüm liste sonundaki boşluğu gösterir). [watch] adımının
/// başlık konumlarını döndürür.
Future<List<double>> _play(WidgetTester t, int watch) async {
  final ys = <double>[];
  for (var f = 0; f < 40; f++) {
    await t.pump(const Duration(milliseconds: 16));
    final p = _pos(t);
    expect(p.pixels, lessThanOrEqualTo(p.maxScrollExtent + 0.5),
        reason: 'kare $f: liste sonu aşıldı');
    expect(p.pixels, greaterThanOrEqualTo(p.minScrollExtent - 0.5),
        reason: 'kare $f: liste başı aşıldı');
    ys.add(_headerY(t, watch));
  }
  await t.pumpAndSettle();
  return ys;
}

/// Başlık son yerine tek hamlede gider: hedefe uzaklığı hiçbir karede
/// artmaz (aşıp geri dönmez, önce ters yöne kaçmaz).
void _expectGlide(List<double> ys) {
  final end = ys.last;
  for (var k = 1; k < ys.length; k++) {
    expect((ys[k] - end).abs(), lessThanOrEqualTo((ys[k - 1] - end).abs() + 0.5),
        reason: 'kare $k: başlık geri zıpladı');
  }
}

void main() {
  testWidgets(
      'Devam: uzun adımın dibinden geçince yeni başlık tek hamlede en üste '
      'süzülür', (t) async {
    await _pumpWizard(t, const _Wizard([2000, 1500, 300, 300]));
    await _jumpToEnd(t);

    await t.tap(find.text('Continue').hitTestable());
    _expectGlide(await _play(t, 1));

    expect(_headerY(t, 1), moreOrLessEquals(0, epsilon: 1));
  });

  testWidgets('Devam: kısa son adımda liste sonuna oturur, boşluğa taşmaz',
      (t) async {
    await _pumpWizard(t, const _Wizard([300, 300, 2000, 120], initial: 2));
    await _jumpToEnd(t);

    await t.tap(find.text('Continue').hitTestable());
    _expectGlide(await _play(t, 3));

    final p = _pos(t);
    expect(p.pixels, moreOrLessEquals(p.maxScrollExtent, epsilon: 1));
  });

  testWidgets('Geri: önceki adımın başlığı en üste gelir', (t) async {
    await _pumpWizard(t, const _Wizard([400, 2000, 300], initial: 1));
    await _jumpToEnd(t);

    await t.tap(find.text('Cancel').hitTestable());
    _expectGlide(await _play(t, 0));

    expect(_headerY(t, 0), moreOrLessEquals(0, epsilon: 1));
  });

  // Dipten 0 px: Stepper'ın eski düzene göre hedefi zaten sona kırpılıyor.
  // Dipten 50 px: Stepper kendi kaydırma animasyonunu da başlatıyor.
  for (final fromEnd in [0.0, 50.0]) {
    testWidgets(
      'Başlığa tıklama (dipten $fromEnd px): Stepper\'ın eski düzene göre '
      'kaydırması boşluğa taşıyamaz, yeni başlık en üste gelir',
      (t) async {
        await _pumpWizard(t, const _Wizard([2000, 300, 900, 300]));
        await _jumpToEnd(t);
        _pos(t).jumpTo(_pos(t).pixels - fromEnd);
        await t.pump();

        await t.tap(find.text('Step 2'));
        _expectGlide(await _play(t, 2));

        expect(_headerY(t, 2), moreOrLessEquals(0, epsilon: 1));
      },
      variant: const TargetPlatformVariant(
          {TargetPlatform.android, TargetPlatform.iOS}),
    );
  }
}
