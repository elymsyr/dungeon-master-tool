import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/srd_l10n/bin/check_pairs.dart';

/// **SRD TR Faz 3 — `check_pairs` kendi testi.** Gerçek SRD metinleri ve
/// sözlüğe uygun çevirileri temiz geçmeli; bilerek bozulmuş her çift kendi
/// kuralına takılmalı. Son test G2 kapısıdır: paketteki çevirilerde FAIL 0.
void main() {
  final g =
      parseGlossary(File('../docs/srd-tr/GLOSSARY.md').readAsStringSync());
  List<String> codes(String en, String tr) => [
        for (final f in checkPair(en, tr, g)) '${f.fail ? 'F' : 'W'}${f.code}',
      ];

  const ca = '*Melee Attack Roll:* +9, reach 15 ft. *Hit:* 12 (2d6 + 5) '
      'Bludgeoning damage. If the target is a creature, it must succeed on a '
      'DC 14 Constitution save or be cursed with Aboleth Tentacle Disease.';
  const caTr = '*Yakın Dövüş Saldırı Zarı:* +9, erişim 15 ft. *Vuruş:* 12 '
      '(2d6 + 5) Ezici hasar. Hedef bir varlıksa DC 14 Dayanıklılık kurtarma '
      'zarında başarılı olmalıdır, yoksa Aboleth Dokunaç Hastalığı ile '
      'lanetlenir.';
  const sp = 'Hurl a bubble of acid. Choose one or two creatures within range '
      'no more than 5 feet apart. A target must succeed on a Dexterity saving '
      'throw or take 1d6 Acid damage.\n\n**Cantrip Upgrade.** The damage '
      'increases by 1d6 at character levels 5 (2d6), 11 (3d6), and 17 (4d6).';
  const spTr = 'Bir asit baloncuğu fırlat. Menzil içinde birbirinden en fazla '
      '5 fit uzaktaki bir ya da iki varlık seç. Hedef bir Çeviklik kurtarma '
      'zarında başarılı olmalıdır, yoksa 1d6 Asit hasarı alır.\n\n'
      '**Cantrip Gelişimi.** Hasar, 5 (2d6), 11 (3d6) ve 17 (4d6) karakter '
      'seviyelerinde 1d6 artar.';
  const ft = 'You gain the following benefits.\n\n**Initiative Proficiency.** '
      'When you roll Initiative, you can add your Proficiency Bonus to the '
      'roll.\n\n**Initiative Swap.** Immediately after you roll Initiative, '
      'you can swap your Initiative with the Initiative of one willing ally '
      "in the same combat. You can't make this swap if you or the ally has "
      'the Incapacitated condition.';
  const ftTr = 'Aşağıdaki faydaları kazanırsın.\n\n**Öncelik Yetkinliği.** '
      'Öncelik zarı attığında Yetkinlik Katkını zara ekleyebilirsin.\n\n'
      '**Öncelik Takası.** Öncelik zarı attıktan hemen sonra Önceliğini aynı '
      'çatışmadaki gönüllü bir müttefikin Önceliğiyle takas edebilirsin. Sen '
      'ya da müttefik Etkisiz Hal durumundaysanız bu takası yapamazsın.';

  test('sözlük ayrıştırılır', () {
    expect(g.terms['Saving Throw'], {'Kurtarma Zarı'});
    expect(g.terms['Proficiency Bonus'], {'Yetkinlik Katkısı'});
    expect(g.terms['Cloud Giant'], {'Bulut Devi'}); // ortak son kelime
    expect(g.terms['Hit Dice'], {'Can Zarı'}); // çok İngilizce → tek Türkçe
    expect(g.keep, containsAll(['Druid', 'gp', 'Abyssal Tiefling']));
    // §4.26'daki ikinci liste; `ft.` gibi kısaltmalar noktasıyla kalır.
    expect(g.keep, containsAll(['Mount Celestia', 'Outlands', 'ft.', 'lb.']));
  });

  test('doğru çeviriler temiz geçer', () {
    expect(codes(ca, caTr), isEmpty);
    expect(codes(sp, spTr), isEmpty);
    expect(codes(ft, ftTr), isEmpty);
    expect(codes('Druid', 'Druid'), isEmpty); // aynen kalır
    expect(codes('Force of personality.', 'Kişilik gücü.'), isEmpty); // ç→c
    expect(codes('Climb, jump, swim, grapple.', 'Tırman, zıpla, yüz, yakala.'),
        isEmpty); // isim-fiil → fiil kökü
  });

  group('bozuk çiftler yakalanır', () {
    test('N1 sayı değişmiş / işaret düşmüş', () {
      expect(codes(ca, caTr.replaceFirst('+9', '+8')), contains('FN1'));
      expect(codes(ca, caTr.replaceFirst('+9', '9')), contains('FN1'));
    });
    test('N2 zar silinmiş', () {
      expect(codes(sp, spTr.replaceFirst('1d6 Asit', 'Asit')), contains('FN2'));
    });
    test('N3 DC değişmiş', () {
      expect(codes(ca, caTr.replaceFirst('DC 14', 'DC 15')), contains('FN3'));
    });
    test('N4 birim dönüştürülmüş', () {
      expect(codes(sp, spTr.replaceFirst('5 fit', '5 metre')), contains('FN4'));
    });
    test('N5 kalın / satır sonu kaybolmuş', () {
      expect(codes(ft, ftTr.replaceFirst('**Öncelik Takası.**', 'Öncelik Takası.')),
          contains('FN5'));
      expect(codes(ft, ftTr.replaceAll('\n\n', ' ')), contains('FN5'));
    });
    test('N6 çevrilmemiş ya da boşluk', () {
      expect(codes(ca, ca), ['FN6']);
      expect(codes(ca, '   '), ['FN6']);
    });
    test('N7 parantez silinmiş', () {
      expect(codes(ca, caTr.replaceFirst('(2d6 + 5)', '2d6 + 5')),
          contains('FN7'));
    });
    test('N8 uzunluk oranı', () {
      expect(codes(ft, 'Aşağıdaki faydaları kazanırsın.'), contains('WN8'));
    });
    test('N9 cümle eklenmiş', () {
      expect(
          codes(ft, '$ftTr Bu hüner çok güçlüdür. Herkes onu ister.'),
          contains('WN9'));
    });
    test('N10 sözlük terimi yanlış', () {
      expect(codes(ca, caTr.replaceFirst('Ezici', 'Darbe')), ['WN10']);
      expect(codes(ft, ftTr.replaceFirst('Yetkinlik Katkını', 'Bonusunu')),
          ['WN10']);
    });
  });

  test('G2: paketteki çevirilerde FAIL 0', () {
    final fails = <String>[];
    for (final f in Directory('assets/srd_l10n/tr')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))) {
      final pairs =
          (jsonDecode(f.readAsStringSync()) as Map).cast<String, String>();
      for (final MapEntry(key: en, value: tr) in pairs.entries) {
        if (tr.isEmpty) continue;
        for (final x in checkPair(en, tr, g).where((x) => x.fail)) {
          fails.add('${f.uri.pathSegments.last} ${jsonEncode(en)}: $x');
        }
      }
    }
    expect(fails, isEmpty, reason: fails.take(20).join('\n'));
  });
}
