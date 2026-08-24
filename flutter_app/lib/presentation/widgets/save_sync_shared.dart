import 'package:flutter/material.dart';

import '../theme/dm_tool_colors.dart';

class SectionLabel extends StatelessWidget {
  final String text;
  final DmToolColors palette;
  const SectionLabel(this.text, this.palette, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: palette.sidebarLabelSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final DmToolColors palette;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: palette.featureCardBorder),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

// ponytail: StorageUsageBar removed — cloud storage gone, only local+LAN remains

