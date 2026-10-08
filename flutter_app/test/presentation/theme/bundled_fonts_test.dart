import 'dart:async';

import 'package:dungeon_master_tool/presentation/theme/palettes.dart';
import 'package:dungeon_master_tool/presentation/widgets/dice/dice_roll_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  // Uygulama fontları indirmiyor; tema ya da zar görünümüne eklenen bir font
  // tool/fonts/bundle_fonts.py'ye eklenmezse burada yakalanır.
  test('her tema ve zar fontu assets/fonts içinden yüklenir', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    final errors = <String>[];
    await runZoned(
      () async {
        for (final p in themePalettes.values) {
          if (p.fontFamily != null) GoogleFonts.getFont(p.fontFamily!);
        }
        for (final look in diceLooks.values) {
          diceFont(look);
        }
        await GoogleFonts.pendingFonts();
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          if (line.contains('unable to load font')) errors.add(line);
        },
      ),
    );
    expect(errors, isEmpty);
  });
}
