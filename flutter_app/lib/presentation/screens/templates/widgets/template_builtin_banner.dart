import 'package:flutter/material.dart';

import '../../../theme/dm_tool_colors.dart';

/// Persistent "Built-in template — make a copy to edit" strip shown across the
/// top of the editor when a read-only built-in template is open (roadmap §1.5).
/// Carries an inline Copy action so the user can branch into an editable copy
/// without leaving the editor.
class TemplateBuiltinBanner extends StatelessWidget {
  final DmToolColors palette;
  final VoidCallback? onCopy;

  const TemplateBuiltinBanner({
    super.key,
    required this.palette,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.featureCardAccent.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 18, color: palette.featureCardAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Built-in template — make a copy to edit.',
                style: TextStyle(
                  fontSize: 13,
                  color: palette.tabActiveText,
                ),
              ),
            ),
            if (onCopy != null)
              TextButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.content_copy, size: 16),
                label: const Text('Copy'),
                style: TextButton.styleFrom(
                  foregroundColor: palette.featureCardAccent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
