import 'package:flutter_test/flutter_test.dart';
import 'package:dungeon_master_tool/application/services/local_media_localizer.dart';

void main() {
  test('dirSafe strips characters Windows rejects in a path', () {
    expect(LocalMediaLocalizer.dirSafe('Aegis — Meridia: Birinci Perde'),
        'Aegis — Meridia_ Birinci Perde');
    expect(LocalMediaLocalizer.dirSafe(r'a\b/c*d?e"f<g>h|i'),
        'a_b_c_d_e_f_g_h_i');
    expect(LocalMediaLocalizer.dirSafe('trailing dot.'), 'trailing dot');
    expect(LocalMediaLocalizer.dirSafe('Normal World'), 'Normal World');
  });
}
