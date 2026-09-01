/// `Ad` → `Ad (Copy)` → `Ad (Copy 2)` …
///
/// Worlds tab'ındaki "Copy World" ile aynı isimlendirme; katalogdan tekrar
/// indirilen paket/dünya var olanın üstüne yazmasın diye kullanılıyor.
String uniqueCopyName(String base, Set<String> taken) {
  if (!taken.contains(base)) return base;
  var candidate = '$base (Copy)';
  var n = 2;
  while (taken.contains(candidate)) {
    candidate = '$base (Copy $n)';
    n++;
  }
  return candidate;
}
