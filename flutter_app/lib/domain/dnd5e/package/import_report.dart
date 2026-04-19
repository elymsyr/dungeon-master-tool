/// Accumulates per-table insert counts and non-fatal warnings during a
/// package import. Returned inside [PackageImportResult] so callers can show
/// a summary dialog ("Imported 3 conditions, 10 spells, 5 monsters").
class ImportReport {
  final Map<String, int> _counts = {};
  final List<String> _warnings = [];

  int count(String table) => _counts[table] ?? 0;
  Map<String, int> get counts => Map.unmodifiable(_counts);
  List<String> get warnings => List.unmodifiable(_warnings);

  void record(String table, int n) {
    _counts.update(table, (v) => v + n, ifAbsent: () => n);
  }

  void warn(String message) {
    _warnings.add(message);
  }
}

sealed class PackageImportResult {
  const PackageImportResult();
  factory PackageImportResult.success(ImportReport report) =
      PackageImportSuccess;
  factory PackageImportResult.error(String message) = PackageImportError;
}

class PackageImportSuccess extends PackageImportResult {
  final ImportReport report;
  const PackageImportSuccess(this.report);
}

class PackageImportError extends PackageImportResult {
  final String message;
  const PackageImportError(this.message);
}
