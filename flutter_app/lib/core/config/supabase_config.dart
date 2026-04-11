/// Supabase configuration from compile-time `--dart-define`.
///
/// Build command:
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
///
/// When neither value is provided the app runs fully offline —
/// no Supabase SDK is initialized.
class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// True when both URL and anon key are provided at compile time.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
