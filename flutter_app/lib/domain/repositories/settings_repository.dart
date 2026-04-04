/// Settings persistence interface.
abstract class SettingsRepository {
  Future<void> setTheme(String themeName);
  Future<void> setLocale(String localeCode);
  Future<void> setVolume(double volume);
}
