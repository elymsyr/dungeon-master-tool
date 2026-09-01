import 'package:flutter_test/flutter_test.dart';
import 'package:dungeon_master_tool/core/utils/unique_name.dart';
void main() {
  test('copy naming', () {
    expect(uniqueCopyName('W', {}), 'W');
    expect(uniqueCopyName('W', {'W'}), 'W (Copy)');
    expect(uniqueCopyName('W', {'W', 'W (Copy)'}), 'W (Copy 2)');
  });
}
