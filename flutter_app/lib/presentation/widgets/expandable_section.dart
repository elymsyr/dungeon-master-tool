import 'package:flutter/material.dart';

/// A "Show more / Show less" toggle that hides an arbitrary [child] (e.g. a
/// wide level-up table) until the user opts in. Collapsed by default so heavy
/// content doesn't dominate a step/card on first render. Mirrors the toggle
/// affordance of [ExpandableMarkdown] but wraps any widget instead of markdown.
class ExpandableSection extends StatefulWidget {
  final Widget child;
  final String collapsedLabel;
  final String expandedLabel;
  final bool initiallyExpanded;
  final IconData? icon;

  const ExpandableSection({
    super.key,
    required this.child,
    this.collapsedLabel = 'Show more',
    this.expandedLabel = 'Show less',
    this.initiallyExpanded = false,
    this.icon,
  });

  @override
  State<ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<ExpandableSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: color,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _expanded ? widget.expandedLabel : widget.collapsedLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded) widget.child,
      ],
    );
  }
}
