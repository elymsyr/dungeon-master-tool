import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/bug_report_provider.dart';
import '../../../core/utils/relative_time.dart';
import '../../../data/datasources/remote/bug_reports_remote_ds.dart';
import '../../dialogs/admin_compose_dm_dialog.dart';
import '../../theme/dm_tool_colors.dart';

/// Admin panel → Reports sekmesi. Kullanıcı gönderimleri listelenir,
/// status (open/read/resolved) filtresiyle süzülür, inline action'larla
/// güncellenir veya DM ile yanıt verilir.
class BugReportsTab extends ConsumerWidget {
  const BugReportsTab({super.key});

  static const _statuses = ['open', 'read', 'resolved', 'all'];

  String _statusLabel(String s) {
    switch (s) {
      case 'open':
        return 'Open';
      case 'read':
        return 'Read';
      case 'resolved':
        return 'Resolved';
      default:
        return 'All';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final filter = ref.watch(bugReportStatusFilterProvider);
    final reportsAsync = ref.watch(adminBugReportsProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SegmentedButton<String>(
            segments: _statuses
                .map((s) => ButtonSegment<String>(
                      value: s,
                      label: Text(_statusLabel(s),
                          style: const TextStyle(fontSize: 12)),
                    ))
                .toList(),
            selected: {filter},
            onSelectionChanged: (set) {
              ref.read(bugReportStatusFilterProvider.notifier).state =
                  set.first;
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: reportsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (reports) {
                if (reports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 48, color: palette.sidebarLabelSecondary),
                        const SizedBox(height: 8),
                        Text('No bug reports.',
                            style: TextStyle(
                                color: palette.sidebarLabelSecondary)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(adminBugReportsProvider),
                  child: ListView.separated(
                    itemCount: reports.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) =>
                        _BugReportCard(report: reports[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BugReportCard extends ConsumerStatefulWidget {
  final BugReport report;
  const _BugReportCard({required this.report});

  @override
  ConsumerState<_BugReportCard> createState() => _BugReportCardState();
}

class _BugReportCardState extends ConsumerState<_BugReportCard> {
  bool _expanded = false;
  bool _logsExpanded = false;

  Color _statusColor(String status, DmToolColors palette) {
    switch (status) {
      case 'open':
        return palette.featureCardAccent;
      case 'read':
        return palette.sidebarLabelSecondary;
      case 'resolved':
        return Colors.green;
      default:
        return palette.featureCardBorder;
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      await ref
          .read(bugReportsDataSourceProvider)
          .updateStatus(widget.report.id, newStatus);
      ref.invalidate(adminBugReportsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  void _copyAll() {
    final r = widget.report;
    final buf = StringBuffer();
    buf.writeln('Bug Report — ${r.username ?? r.email ?? r.userId}');
    buf.writeln('Status: ${r.status} | Version: ${r.appVersion ?? '?'} | '
        'Platform: ${r.platform ?? '?'} | Date: ${r.createdAt}');
    buf.writeln();
    buf.writeln('== Description ==');
    buf.writeln(r.message);
    if (r.logs != null && r.logs!.isNotEmpty) {
      buf.writeln();
      buf.writeln('== Terminal Logs ==');
      buf.writeln(r.logs);
    }
    if (r.adminNote != null && r.adminNote!.isNotEmpty) {
      buf.writeln();
      buf.writeln('== Admin Note ==');
      buf.writeln(r.adminNote);
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final r = widget.report;
    final title = r.username ?? r.email ?? r.userId;
    final hasLogs = r.logs != null && r.logs!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        border: Border.all(color: palette.featureCardBorder),
        borderRadius: palette.cbr,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _statusColor(r.status, palette)
                    .withValues(alpha: 0.15),
                child: Icon(Icons.bug_report_outlined,
                    size: 16, color: _statusColor(r.status, palette)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.tabActiveText)),
                    if (r.email != null && r.email != title)
                      Text(r.email!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              color: palette.sidebarLabelSecondary)),
                  ],
                ),
              ),
              _Chip(
                label: r.status.toUpperCase(),
                color: _statusColor(r.status, palette),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Meta row
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (r.appVersion != null)
                _Chip(label: r.appVersion!, color: palette.featureCardBorder),
              if (r.platform != null)
                _Chip(label: r.platform!, color: palette.featureCardBorder),
              _Chip(
                label: formatRelative(r.createdAt),
                color: palette.featureCardBorder,
              ),
              if (hasLogs)
                _Chip(label: 'HAS LOGS', color: palette.featureCardAccent),
            ],
          ),
          const SizedBox(height: 10),
          // Message body
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              r.message,
              maxLines: _expanded ? null : 3,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, height: 1.4, color: palette.tabActiveText),
            ),
          ),
          // Logs section
          if (hasLogs) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => setState(() => _logsExpanded = !_logsExpanded),
              child: Row(
                children: [
                  Icon(Icons.terminal, size: 14,
                      color: palette.sidebarLabelSecondary),
                  const SizedBox(width: 6),
                  Text(
                    _logsExpanded ? 'Hide logs' : 'Show logs',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: palette.featureCardAccent,
                    ),
                  ),
                  Icon(
                    _logsExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 16,
                    color: palette.featureCardAccent,
                  ),
                ],
              ),
            ),
            if (_logsExpanded) ...[
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: palette.featureCardBorder.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    r.logs!,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: palette.tabActiveText,
                    ),
                  ),
                ),
              ),
            ],
          ],
          if (r.adminNote != null && r.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Note: ${r.adminNote}',
              style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: palette.sidebarLabelSecondary),
            ),
          ],
          const SizedBox(height: 8),
          // Actions
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            children: [
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                tooltip: 'Copy all',
                onPressed: _copyAll,
              ),
              if (r.status == 'open')
                TextButton.icon(
                  icon: const Icon(Icons.mark_email_read_outlined, size: 16),
                  label: const Text('Mark read'),
                  onPressed: () => _updateStatus('read'),
                ),
              if (r.status != 'resolved')
                TextButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Mark resolved'),
                  onPressed: () => _updateStatus('resolved'),
                ),
              TextButton.icon(
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('Message'),
                onPressed: () => AdminComposeDmDialog.show(
                  context,
                  targetUserId: r.userId,
                  targetName: r.username ?? r.email ?? 'user',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.4),
      ),
    );
  }
}
