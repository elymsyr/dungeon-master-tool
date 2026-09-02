import 'package:flutter_test/flutter_test.dart';
import 'package:dungeon_master_tool/core/config/worker_config.dart';
import 'package:dungeon_master_tool/data/services/first_party_catalog_service.dart';

/// `--dart-define=DMT_WORKER_URL` verilmeden çalışır: CI secret'ı build'e
/// girmediğinde Marketplace'in sessizce "listeler ama indiremez" hâline
/// düşmesini (banner yok + payload unavailable) engelleyen varsayılanın nöbeti.
void main() {
  test('worker base URL is available without a dart-define', () {
    expect(WorkerConfig.isConfigured, isTrue);
    expect(WorkerConfig.baseUrl, startsWith('https://'));
  });

  test('official banner URL resolves without a dart-define', () {
    expect(officialBannerUrl('open5e-a5e-ag'), isNotNull);
  });
}
