/// Cloudflare Worker (`dmt-assets`) tabanı — R2 kataloğunun ve imzalı asset
/// rotalarının kökü.
///
/// URL **gizli değil**: `/catalog/*` rotaları kasten public GET (kimlik
/// doğrulaması yok) ve zaten her binary'nin içinde düz metin duruyor. Yalnızca
/// `--dart-define`'a bırakıldığında, CI'da tanım build'e girmezse uygulama
/// sessizce "her şeyi listeleyen ama hiçbir şey indiremeyen" bir Marketplace'e
/// dönüşüyordu (bundle'daki manifest fallback'i arızayı gizliyor). Varsayılan
/// değer bu sınıf hatayı tamamen kaldırıyor; `--dart-define=DMT_WORKER_URL=...`
/// verildiğinde yine o eziyor (staging/self-host).
class WorkerConfig {
  const WorkerConfig._();

  static const String baseUrl = String.fromEnvironment(
    'DMT_WORKER_URL',
    defaultValue: 'https://dmt-assets.dungeon-master-tool.workers.dev',
  );

  static bool get isConfigured => baseUrl.isNotEmpty;
}
