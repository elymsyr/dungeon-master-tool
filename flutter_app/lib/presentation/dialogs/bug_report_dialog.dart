import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/log_buffer.dart';
import '../../core/services/screenshot_service.dart';

const _githubIssuesUrl =
    'https://github.com/elymsyr/dungeon-master-tool/issues';
const _supportEmail = 'orhun868@gmail.com';

/// Bug report dialog — title, açıklama, otomatik screenshot + log capture.
/// Mail ile gönderim ve GitHub issues yönlendirme sağlar.
class BugReportDialog extends StatefulWidget {
  /// Screenshot için hedef RepaintBoundary'nin global key'i.
  final GlobalKey? screenshotKey;

  const BugReportDialog({super.key, this.screenshotKey});

  static Future<void> show(BuildContext context,
      {GlobalKey? screenshotKey}) {
    return showDialog<void>(
      context: context,
      builder: (_) => BugReportDialog(screenshotKey: screenshotKey),
    );
  }

  @override
  State<BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<BugReportDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  Uint8List? _screenshotBytes;
  String? _screenshotPath;
  late final String _logsSnapshot;
  bool _capturing = true;

  @override
  void initState() {
    super.initState();
    _logsSnapshot = LogBuffer.instance.tail(200);
    _captureScreenshot();
  }

  Future<void> _captureScreenshot() async {
    if (widget.screenshotKey == null) {
      setState(() => _capturing = false);
      return;
    }
    // Bir frame bekle ki dialog bizi engelleyemesin
    await Future.delayed(const Duration(milliseconds: 50));
    final path = await ScreenshotService.captureToFile(widget.screenshotKey!);
    if (path != null) {
      final bytes = await File(path).readAsBytes();
      if (mounted) {
        setState(() {
          _screenshotPath = path;
          _screenshotBytes = bytes;
          _capturing = false;
        });
      }
    } else if (mounted) {
      setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String _buildBody() {
    final buf = StringBuffer();
    buf.writeln('## Description');
    buf.writeln(_descCtrl.text.isEmpty ? '(no description)' : _descCtrl.text);
    buf.writeln();
    buf.writeln('## Environment');
    buf.writeln('- Platform: ${Platform.operatingSystem}');
    buf.writeln('- OS Version: ${Platform.operatingSystemVersion}');
    buf.writeln('- Locale: ${Platform.localeName}');
    buf.writeln();
    if (_screenshotPath != null) {
      buf.writeln('## Screenshot');
      buf.writeln('Attached: $_screenshotPath');
      buf.writeln();
    }
    buf.writeln('## Recent Logs');
    buf.writeln('```');
    buf.writeln(_logsSnapshot.isEmpty ? '(no logs captured)' : _logsSnapshot);
    buf.writeln('```');
    return buf.toString();
  }

  Future<void> _sendEmail() async {
    final subject = _titleCtrl.text.isEmpty
        ? '[DMT Bug Report]'
        : '[DMT Bug Report] ${_titleCtrl.text}';
    final body = _buildBody();
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: _encodeQuery({'subject': subject, 'body': body}),
    );
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      _showError('Could not open mail client. Report copied to clipboard.');
      await Clipboard.setData(ClipboardData(text: '$subject\n\n$body'));
    }
  }

  Future<void> _openGithub() async {
    final ok = await launchUrl(
      Uri.parse(_githubIssuesUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      _showError('Could not open browser.');
    }
  }

  Future<void> _copyToClipboard() async {
    final subject = _titleCtrl.text.isEmpty
        ? '[DMT Bug Report]'
        : '[DMT Bug Report] ${_titleCtrl.text}';
    await Clipboard.setData(
        ClipboardData(text: '$subject\n\n${_buildBody()}'));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bug report copied to clipboard'),
            duration: Duration(seconds: 2)),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _encodeQuery(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.bug_report, color: theme.colorScheme.error),
                  const SizedBox(width: 12),
                  Text('Report a Bug',
                      style: theme.textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          hintText: 'Brief summary of the issue',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descCtrl,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText:
                              'Steps to reproduce, expected vs actual behavior…',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionHeader(
                        icon: Icons.image,
                        title: 'Screenshot',
                        trailing: _capturing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : null,
                      ),
                      const SizedBox(height: 8),
                      if (_screenshotBytes != null)
                        Container(
                          constraints:
                              const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.memory(_screenshotBytes!,
                              fit: BoxFit.contain),
                        )
                      else if (!_capturing)
                        Text('(no screenshot available)',
                            style: theme.textTheme.bodySmall),
                      const SizedBox(height: 16),
                      _SectionHeader(
                        icon: Icons.terminal,
                        title:
                            'Recent Logs (${_logsSnapshot.split('\n').length} lines)',
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints:
                            const BoxConstraints(maxHeight: 140),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            _logsSnapshot.isEmpty
                                ? '(no logs captured)'
                                : _logsSnapshot,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                    onPressed: _copyToClipboard,
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('GitHub Issues'),
                    onPressed: _openGithub,
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.email, size: 18),
                    label: const Text('Send Email'),
                    onPressed: _sendEmail,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;

  const _SectionHeader(
      {required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.secondary),
        const SizedBox(width: 8),
        Text(title,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.secondary)),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}
