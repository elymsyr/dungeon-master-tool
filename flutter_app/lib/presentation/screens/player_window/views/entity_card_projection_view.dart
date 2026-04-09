import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../domain/entities/projection/entity_snapshot.dart';
import '../../../../domain/entities/projection/projection_item.dart';

/// Player-window view of an entity card. Renders from a serializable
/// [EntitySnapshot] — the player sub-isolate doesn't need access to the
/// entity provider or the world schema.
///
/// Layout: large portrait at the top, name + category badge, description,
/// then a flat list of label/value rows grouped by section.
class EntityCardProjectionView extends StatefulWidget {
  final EntityCardProjection item;

  const EntityCardProjectionView({required this.item, super.key});

  @override
  State<EntityCardProjectionView> createState() =>
      _EntityCardProjectionViewState();
}

class _EntityCardProjectionViewState extends State<EntityCardProjectionView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snap = widget.item.snapshot;
    final catColor = _hexColor(snap.categoryColorHex);
    return RepaintBoundary(
      child: Container(
        color: const Color(0xFF1a1a1a),
        padding: const EdgeInsets.all(40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (snap.imagePaths.isNotEmpty)
                  _Portrait(path: snap.imagePaths.first),
                if (snap.imagePaths.isNotEmpty) const SizedBox(width: 32),
                Expanded(child: _RightColumn(snap: snap, catColor: catColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _hexColor(String hex) {
    var clean = hex.replaceFirst('#', '');
    if (clean.length == 6) clean = 'FF$clean';
    try {
      return Color(int.parse(clean, radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

class _Portrait extends StatelessWidget {
  final String path;
  const _Portrait({required this.path});

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync()) {
      return const SizedBox(
        width: 360,
        height: 480,
        child: ColoredBox(color: Color(0xFF222222)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        file,
        width: 360,
        height: 480,
        fit: BoxFit.cover,
        cacheWidth: 720,
      ),
    );
  }
}

class _RightColumn extends StatelessWidget {
  final EntitySnapshot snap;
  final Color catColor;

  const _RightColumn({required this.snap, required this.catColor});

  @override
  Widget build(BuildContext context) {
    final groups = <String?, List<EntityFieldSnapshot>>{};
    for (final f in snap.fields) {
      groups.putIfAbsent(f.groupLabel, () => []).add(f);
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              snap.categoryName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: catColor,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Name
          Text(
            snap.name,
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          if (snap.source.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              snap.source,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          if (snap.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              snap.description,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
          ],

          if (snap.fields.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),
            for (final entry in groups.entries) ...[
              if (entry.key != null && entry.key!.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Text(
                    entry.key!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: catColor,
                    ),
                  ),
                ),
              ],
              for (final f in entry.value) _FieldRow(field: f),
            ],
          ],
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final EntityFieldSnapshot field;
  const _FieldRow({required this.field});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              field.label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              field.value,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
