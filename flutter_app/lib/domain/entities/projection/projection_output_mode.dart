/// How the projection content is delivered to the player.
///
/// Mutually exclusive — only one output mode can be active at a time.
enum ProjectionOutputMode {
  /// No output active.
  none,

  /// Desktop second OS window via `desktop_multi_window` (desktop only).
  secondWindow,

  /// External display via platform Presentation API — Miracast, Chromecast,
  /// HDMI, AirPlay (desktop + mobile).
  screencast,
}
