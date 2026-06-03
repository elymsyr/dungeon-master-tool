import 'package:flutter/material.dart';

/// Faint source label for a chargen option — where it came from (e.g.
/// "System Reference Document 5.2", "Adventurer's Guide"). No background/
/// border; sits left, next to the option name. Renders nothing when empty.
class SourceBadge extends StatelessWidget {
  final String source;
  const SourceBadge(this.source, {super.key});

  @override
  Widget build(BuildContext context) {
    if (source.trim().isEmpty) return const SizedBox.shrink();
    return Text(
      source,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 10,
        color: Theme.of(context).disabledColor,
      ),
    );
  }
}
