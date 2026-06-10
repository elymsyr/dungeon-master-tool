import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/character/effective_character.dart';

/// Warning banner for prerequisites the character carries grants for but does
/// not currently meet (WARN-KEEP policy — the resolver applied the mechanics
/// anyway; this surface lets the table adjudicate). Also hosts the resolver's
/// debug `warnings` list behind an expander in debug builds — that list was
/// previously computed but rendered nowhere.
///
/// Renders nothing when there is nothing to show.
class PrereqWarningsBanner extends StatelessWidget {
  final List<UnmetPrerequisite> unmetPrerequisites;
  final List<String> debugWarnings;

  const PrereqWarningsBanner({
    super.key,
    required this.unmetPrerequisites,
    this.debugWarnings = const [],
  });

  @override
  Widget build(BuildContext context) {
    final showDebug = kDebugMode && debugWarnings.isNotEmpty;
    if (unmetPrerequisites.isEmpty && !showDebug) {
      return const SizedBox.shrink();
    }
    const orange = Color(0xFFB45309);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (unmetPrerequisites.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: orange.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: orange),
                      SizedBox(width: 6),
                      Text(
                        'Unmet prerequisites',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final u in unmetPrerequisites)
                    Padding(
                      padding: const EdgeInsets.only(left: 22, top: 2),
                      child: Text(
                        u.failedClauses.isEmpty
                            ? '${u.sourceName}: prerequisite not met.'
                            : '${u.sourceName}: requires ${u.failedClauses.join(', ')}.',
                        style: const TextStyle(fontSize: 12, color: orange),
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.only(left: 22, top: 4),
                    child: Text(
                      'Mechanics still apply — adjust the character or remove '
                      'the grant if the table rules it out.',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (showDebug)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(
                  'Resolver warnings (${debugWarnings.length}) — debug',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                children: [
                  for (final w in debugWarnings)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 2),
                        child: Text(
                          '• $w',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
