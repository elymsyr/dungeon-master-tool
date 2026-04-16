import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/providers/bug_report_provider.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants.dart';
import '../../core/services/log_buffer.dart';
import '../../data/datasources/remote/bug_reports_remote_ds.dart';

const _githubIssuesUrl =
    'https://github.com/elymsyr/dungeon-master-tool/issues';

/// In-app bug report dialog — metni + arka plan terminal çıktısını
/// Supabase'deki `bug_reports` tablosuna gönderir. Resim/ek yok; sadece metin
/// ve otomatik log capture. Admin paneli raporları + log'ları görüntüler.
class BugReportDialog extends ConsumerStatefulWidget {
  const BugReportDialog({super.key});

  static Future<void> show(BuildContext context) {
    if (!SupabaseConfig.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bug reporting requires cloud sign-in.'),
        ),
      );
      return Future.value();
    }
    return showDialog<void>(
      context: context,
      builder: (_) => const BugReportDialog(),
    );
  }

  @override
  ConsumerState<BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends ConsumerState<BugReportDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _errorText;
  late final String _logsSnapshot;

  static const int _minLength = 10;
  static const int _maxLength = 4000;

  @override
  void initState() {
    super.initState();
    _logsSnapshot = LogBuffer.instance.tail(200);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return 'unknown';
    }
  }

  Future<void> _submit() async {
    final message = _controller.text.trim();
    if (message.length < _minLength) {
      setState(() =>
          _errorText = 'Please provide at least $_minLength characters.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await ref.read(bugReportsDataSourceProvider).submit(
            message: message,
            logs: _logsSnapshot,
            appVersion: appReleaseTag,
            platform: _platformLabel(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you — your report was sent.')),
      );
    } on BugReportRateLimitException {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = 'Too many reports recently. Please try again later.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = 'Failed to send report: $e';
      });
    }
  }

  Future<void> _openGithub() async {
    await launchUrl(
      Uri.parse(_githubIssuesUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final length = _controller.text.trim().length;
    final canSubmit = !_submitting && length >= _minLength;
    final hasLogs = _logsSnapshot.isNotEmpty;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.bug_report_outlined, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          const Expanded(child: Text('Report a bug')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Describe the issue you encountered. '
                'Terminal output is captured automatically and will be sent with your report.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                maxLines: 6,
                maxLength: _maxLength,
                autofocus: true,
                enabled: !_submitting,
                decoration: InputDecoration(
                  hintText:
                      'Steps to reproduce, expected vs actual behavior…',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  errorText: _errorText,
                ),
                onChanged: (_) {
                  if (_errorText != null) {
                    setState(() => _errorText = null);
                  } else {
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 8),
              // Logs preview
              if (hasLogs) ...[
                Row(
                  children: [
                    Icon(Icons.terminal, size: 14,
                        color: theme.colorScheme.secondary),
                    const SizedBox(width: 6),
                    Text(
                      'Recent logs (${_logsSnapshot.split('\n').length} lines — will be included)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 100),
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _logsSnapshot,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ] else
                Text(
                  '(no terminal logs captured)',
                  style: theme.textTheme.bodySmall,
                ),
              const SizedBox(height: 8),
              Text(
                'Version: $appReleaseTag · Platform: ${_platformLabel()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.disabledColor,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('GitHub Issues'),
          onPressed: _openGithub,
        ),
        const Spacer(),
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: _submitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send, size: 16),
          label: const Text('Send report'),
          onPressed: canSubmit ? _submit : null,
        ),
      ],
    );
  }
}
