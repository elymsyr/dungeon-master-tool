/// PR-D2 deletion stub. Trash logic moved to `TrashDao`; this stub keeps
/// the import chain from breaking until PR-D4 rewrites
/// `package_repository_impl.dart` against v12 DAOs.
///
/// `moveToTrash` is now a no-op — once PR-D4 swaps the repo to `TrashDao`
/// this whole file goes away.
class PackageLocalDataSource {
  const PackageLocalDataSource();

  Future<void> moveToTrash(
    String packageName, {
    Map<String, dynamic>? data,
  }) async {
    // No-op. PR-D4 routes deletions through TrashDao directly.
  }
}
