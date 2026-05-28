import 'package:package_info_plus/package_info_plus.dart';

const String appName = 'Dungeon Master Tool';
// Fallback if PackageInfo lookup fails. Real value loaded by [initAppVersion]
// from the bundled pubspec version (Android/iOS/desktop) or the web build's
// info.json, so a `flutter build` automatically reflects the new version
// without hand-editing this file.
String appVersion = '9.3.0';
const String appProcess = 'beta';
String get appReleaseTag => '$appProcess-v$appVersion';
const String githubRepo = 'elymsyr/dungeon-master-tool';
const String apiBaseUrl = 'https://www.dnd5eapi.co/api';
const String open5eBaseUrl = 'https://api.open5e.com/v1';

Future<void> initAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isNotEmpty) appVersion = info.version;
  } catch (_) {
    // Keep the const fallback above.
  }
}
