import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/admin_notifications_provider.dart';
import '../../data/datasources/remote/admin_notifications_remote_ds.dart';
import '../../domain/entities/app_notification.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Admin view of aggregated responses for one notification: poll vote tallies
/// (with bars) and a list of free-text answers by username.
class NotificationResponsesDialog extends ConsumerWidget {
  final AdminNotificationSummary summary;
  const NotificationResponsesDialog({super.key, required this.summary});

  static Future<void> show(BuildContext context, AdminNotificationSummary s) {
    return showDialog<void>(
      context: context,
      builder: (_) => NotificationResponsesDialog(summary: s),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final async = ref.watch(adminNotificationResponsesProvider(summary.id));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: palette.cbr),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${l10n.notifResponsesTitle} — ${summary.title}',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: palette.tabActiveText)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: async.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: $e',
                        style: TextStyle(color: palette.dangerBtnBg)),
                  ),
                  data: (rows) => rows.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(l10n.notifNoResponses,
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: palette.sidebarLabelSecondary)),
                        )
                      : _ResultsBody(summary: summary, rows: rows),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultsBody extends StatelessWidget {
  final AdminNotificationSummary summary;
  final List<NotificationResponseRow> rows;
  const _ResultsBody({required this.summary, required this.rows});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;

    final sections = <Widget>[];
    for (final block in summary.blocks) {
      if (block is PollBlock) {
        sections.add(_pollSection(palette, l10n, block));
      } else if (block is InputBlock) {
        sections.add(_inputSection(palette, l10n, block));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      shrinkWrap: true,
      children: [
        Text(l10n.notifResponseCount(rows.length),
            style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary)),
        const SizedBox(height: 12),
        for (final s in sections) ...[s, const SizedBox(height: 18)],
      ],
    );
  }

  Widget _pollSection(DmToolColors palette, L10n l10n, PollBlock block) {
    // Tally votes per option index across all responses.
    final counts = List<int>.filled(block.options.length, 0);
    for (final r in rows) {
      final ans = r.answers[block.id];
      final choice = (ans is Map ? ans['choice'] : null);
      if (choice is List) {
        for (final c in choice) {
          final idx = (c is num) ? c.toInt() : -1;
          if (idx >= 0 && idx < counts.length) counts[idx]++;
        }
      }
    }
    final maxCount = counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(block.question,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.tabActiveText)),
        const SizedBox(height: 8),
        for (int i = 0; i < block.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(block.options[i],
                          style: TextStyle(fontSize: 12, color: palette.tabActiveText)),
                    ),
                    Text(l10n.notifVotes(counts[i]),
                        style: TextStyle(
                            fontSize: 11, color: palette.sidebarLabelSecondary)),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: maxCount == 0 ? 0 : counts[i] / maxCount,
                    minHeight: 6,
                    backgroundColor: palette.featureCardBorder,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(palette.featureCardAccent),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _inputSection(DmToolColors palette, L10n l10n, InputBlock block) {
    final entries = <(String, String)>[];
    for (final r in rows) {
      final ans = r.answers[block.id];
      final text = (ans is Map ? ans['text'] : null)?.toString();
      if (text != null && text.trim().isNotEmpty) {
        entries.add((r.username ?? r.userId.substring(0, 8), text.trim()));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(block.prompt,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.tabActiveText)),
        const SizedBox(height: 6),
        if (entries.isEmpty)
          Text(l10n.notifNoResponses,
              style: TextStyle(fontSize: 12, color: palette.sidebarLabelSecondary))
        else
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.$1,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: palette.featureCardAccent)),
                  Text(e.$2,
                      style: TextStyle(fontSize: 12, color: palette.tabActiveText)),
                ],
              ),
            ),
      ],
    );
  }
}
