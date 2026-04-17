/// Safely parses an ISO-8601 date string from JSON/RPC responses.
/// Returns `null` if the input is missing, not a string, or malformed.
DateTime? parseIsoOrNull(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v);
}

/// Same as [parseIsoOrNull] but falls back to `DateTime.now()` for
/// required timestamps where a null would violate invariants.
DateTime parseIsoOrNow(dynamic v) => parseIsoOrNull(v) ?? DateTime.now();
