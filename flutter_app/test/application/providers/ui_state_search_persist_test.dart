import 'package:flutter_test/flutter_test.dart';
import 'package:dungeon_master_tool/application/providers/ui_state_provider.dart';

void main() {
  test('dbSearchByWorld survives a json roundtrip', () {
    const s = UiState(dbSearchByWorld: {'w1': 'goblin'});
    expect(UiState.fromJson(s.toJson()).dbSearchByWorld['w1'], 'goblin');
  });
}
