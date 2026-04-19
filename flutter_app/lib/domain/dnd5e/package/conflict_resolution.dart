/// How the importer should handle a same-source re-install (`srd` v1 already
/// installed, user imports `srd` v2). Cross-package collisions cannot happen
/// because ids are namespaced by `packageIdSlug` — see Doc 14 §Conflict.
enum ConflictResolution {
  /// Keep local rows, ignore incoming package.
  skip,

  /// Replace local rows with incoming (normal upgrade path).
  overwrite,

  /// Install side-by-side under a suffixed slug (`srd_2`). Caller supplies
  /// the new slug; the importer does not auto-pick one.
  duplicate,
}
