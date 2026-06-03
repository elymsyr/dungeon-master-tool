import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// One labelled dimension in a hub filter dialog (e.g. "Templates",
/// "Packages", "Worlds"). [options] are the distinct values that can be
/// selected; [selected] is the currently-applied subset.
class FilterSection {
  final String label;
  final List<String> options;
  final Set<String> selected;
  const FilterSection({
    required this.label,
    required this.options,
    required this.selected,
  });
}

/// Header icon button that opens a multi-section filter dialog. Shows a badge
/// with the total number of selected values. Calls [onChanged] with the new
/// per-section selections (order matches [sections]) when the user applies or
/// clears; does nothing on cancel.
class HubFilterButton extends StatelessWidget {
  final List<FilterSection> sections;
  final int totalSelected;
  final ValueChanged<List<Set<String>>> onChanged;

  const HubFilterButton({
    super.key,
    required this.sections,
    required this.totalSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final icon = Icon(
      Icons.filter_alt,
      size: 16,
      color: totalSelected > 0 ? palette.featureCardAccent : null,
    );
    return Tooltip(
      message: l10n.hubTooltipFilter,
      child: OutlinedButton(
        onPressed: () async {
          final result = await showHubFilterDialog(context, sections: sections);
          if (result != null) onChanged(result);
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          minimumSize: const Size(32, 32),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: totalSelected > 0
            ? Badge(
                label: Text('$totalSelected'),
                backgroundColor: palette.featureCardAccent,
                child: icon,
              )
            : icon,
      ),
    );
  }
}

/// Shows the filter dialog and returns the new per-section selections aligned
/// to [sections], or `null` if the user cancelled. "Clear filter" returns a
/// list of empty sets.
Future<List<Set<String>>?> showHubFilterDialog(
  BuildContext context, {
  required List<FilterSection> sections,
}) {
  final palette = Theme.of(context).extension<DmToolColors>()!;
  final l10n = L10n.of(context)!;
  // Working copy so the dialog applies/cancels atomically.
  final working = [for (final s in sections) <String>{...s.selected}];

  return showDialog<List<Set<String>>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final anySelected = working.any((s) => s.isNotEmpty);
        final visible = <Widget>[];
        for (var i = 0; i < sections.length; i++) {
          final section = sections[i];
          if (section.options.isEmpty) continue;
          final opts = [...section.options]
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          if (visible.isNotEmpty) visible.add(const SizedBox(height: 12));
          visible.add(Align(
            alignment: Alignment.centerLeft,
            child: Text(
              section.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.tabActiveText,
              ),
            ),
          ));
          visible.add(const SizedBox(height: 6));
          visible.add(Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final o in opts)
                FilterChip(
                  label: Text(o, style: const TextStyle(fontSize: 12)),
                  selected: working[i].contains(o),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (v) => setLocal(() {
                    if (v) {
                      working[i].add(o);
                    } else {
                      working[i].remove(o);
                    }
                  }),
                ),
            ],
          ));
        }

        return AlertDialog(
          title: Text(l10n.hubFilterTitle),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: visible.isEmpty
                    ? [
                        Text(
                          l10n.hubFilterEmpty,
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.sidebarLabelSecondary,
                          ),
                        ),
                      ]
                    : visible,
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: anySelected
                  ? () => Navigator.pop(
                        ctx,
                        [for (var i = 0; i < sections.length; i++) <String>{}],
                      )
                  : null,
              child: Text(l10n.hubFilterClear),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.btnCancel),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, working),
                  child: Text(l10n.hubFilterApply),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}
