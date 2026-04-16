/// Compact relative time formatter: `now`, `5m`, `2h`, `3d`, `2w`, `4mo`, `1y`.
/// L10n bağımsız — tek harf suffix'ler her dilde yeterli.
String formatRelative(DateTime? t, {DateTime? now}) {
  if (t == null) return '—';
  final n = now ?? DateTime.now();
  final d = n.difference(t);
  if (d.isNegative) return 'now';
  if (d.inSeconds < 60) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  if (d.inDays < 30) return '${(d.inDays / 7).floor()}w';
  if (d.inDays < 365) return '${(d.inDays / 30).floor()}mo';
  return '${(d.inDays / 365).floor()}y';
}
