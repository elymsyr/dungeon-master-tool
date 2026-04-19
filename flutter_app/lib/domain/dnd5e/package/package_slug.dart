/// Validates a `packageIdSlug` — the short prefix that namespaces every
/// content id in a package (`<slug>:<localId>`). Per Doc 14:
///   `[a-z][a-z0-9_]{0,31}`
/// Short, URL-safe, cannot start with a digit. 32 chars total.
final RegExp _slugPattern = RegExp(r'^[a-z][a-z0-9_]{0,31}$');

String validatePackageSlug(String slug) {
  if (!_slugPattern.hasMatch(slug)) {
    throw ArgumentError(
        'packageIdSlug "$slug" must match [a-z][a-z0-9_]{0,31}');
  }
  return slug;
}

bool isValidPackageSlug(String slug) => _slugPattern.hasMatch(slug);
