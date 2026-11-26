import 'package:dungeon_master_tool/data/network/release_check_service.dart';
import 'package:flutter_test/flutter_test.dart';

ReleaseInfo _r(String tag) =>
    ReleaseInfo(tag: tag, name: tag, htmlUrl: '', body: '');

void main() {
  test('same channel compares semver', () {
    expect(_r('beta-v19.1.2').isNewerThan('beta-v19.1.1'), isTrue);
    expect(_r('beta-v19.1.1').isNewerThan('beta-v19.1.1'), isFalse);
    expect(_r('beta-v19.0.9').isNewerThan('beta-v19.1.1'), isFalse);
  });

  test('stable is offered to beta builds', () {
    expect(_r('stable-v20.0.0').isNewerThan('beta-v19.1.1'), isTrue);
    expect(_r('stable-v20.0.0').isNewerThan('beta-v20.0.0'), isTrue);
    expect(_r('stable-v20.0.0').isNewerThan('stable-v20.0.0'), isFalse);
    expect(_r('stable-v19.1.1').isNewerThan('beta-v20.0.0'), isFalse);
  });

  test('beta is not offered to stable builds; bad tags are ignored', () {
    expect(_r('beta-v21.0.0').isNewerThan('stable-v20.0.0'), isFalse);
    expect(_r('v20.0.0').isNewerThan('beta-v19.1.1'), isFalse);
  });
}
