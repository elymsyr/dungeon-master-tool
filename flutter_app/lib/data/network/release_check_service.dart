import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';

import '../../core/constants.dart';

/// GitHub release metadata for the upstream repository.
class ReleaseInfo {
  ReleaseInfo({
    required this.tag,
    required this.name,
    required this.htmlUrl,
    required this.body,
  });

  /// Raw tag from GitHub (e.g. `beta-v4.0.2`).
  final String tag;

  /// Release title (falls back to tag if the release has no name).
  final String name;

  /// Browser URL pointing at the release page.
  final String htmlUrl;

  /// Release notes body (may be empty).
  final String body;

  /// Parsed `(process, major, minor, patch)` tuple. `null` if the tag
  /// doesn't conform to `<process>-v<semver>`.
  (String, int, int, int)? get parsed => _parseTag(tag);

  /// Returns true if this release is strictly newer than the local tag.
  bool isNewerThan(String localTag) {
    final a = _parseTag(tag);
    final b = _parseTag(localTag);
    if (a == null || b == null) return false;
    if (a.$1 != b.$1) return false; // different process channel — ignore
    if (a.$2 != b.$2) return a.$2 > b.$2;
    if (a.$3 != b.$3) return a.$3 > b.$3;
    return a.$4 > b.$4;
  }
}

(String, int, int, int)? _parseTag(String tag) {
  final m = RegExp(r'^([a-zA-Z]+)-v(\d+)\.(\d+)\.(\d+)$').firstMatch(tag);
  if (m == null) return null;
  return (
    m.group(1)!,
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    int.parse(m.group(4)!),
  );
}

/// Fetches the latest release from the GitHub API. Fail-soft: any
/// network / parsing error returns `null` so callers never block UI on it.
class ReleaseCheckService {
  ReleaseCheckService({HttpClient? httpClient, Logger? logger})
      : _httpClient = httpClient ?? HttpClient(),
        _logger = logger ?? Logger();

  final HttpClient _httpClient;
  final Logger _logger;

  static const _timeout = Duration(seconds: 6);

  Future<ReleaseInfo?> fetchLatest() async {
    final uri = Uri.parse(
      'https://api.github.com/repos/$githubRepo/releases/latest',
    );
    try {
      final req = await _httpClient.getUrl(uri).timeout(_timeout);
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      req.headers.set('X-GitHub-Api-Version', '2022-11-28');
      req.headers.set(HttpHeaders.userAgentHeader, 'dungeon-master-tool');
      final res = await req.close().timeout(_timeout);
      if (res.statusCode != 200) {
        _logger.d('Release check HTTP ${res.statusCode}');
        await res.drain<void>();
        return null;
      }
      final body = await res.transform(utf8.decoder).join().timeout(_timeout);
      final json = jsonDecode(body) as Map<String, dynamic>;
      final tag = json['tag_name'] as String?;
      if (tag == null) return null;
      return ReleaseInfo(
        tag: tag,
        name: (json['name'] as String?)?.trim().isNotEmpty == true
            ? (json['name'] as String).trim()
            : tag,
        htmlUrl: (json['html_url'] as String?) ??
            'https://github.com/$githubRepo/releases/latest',
        body: (json['body'] as String?) ?? '',
      );
    } catch (e, st) {
      _logger.d('Release check failed: $e', error: e, stackTrace: st);
      return null;
    }
  }
}
