/// How projection content is delivered to the player.
///
/// Multiple modes can be active at once (fan-out) — e.g. a local second
/// window for the DM plus [online] for remote players.
enum ProjectionOutputMode {
  /// No output active.
  none,

  /// Desktop second OS window via `desktop_multi_window` (desktop only).
  secondWindow,

  /// External display via platform Presentation API — Miracast, Chromecast,
  /// HDMI, AirPlay (desktop + mobile).
  screencast,

  /// Remote players over Supabase realtime — the `world_projection` manifest
  /// table replicated via the world CDC channel.
  online,
}
