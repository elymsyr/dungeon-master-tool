import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../domain/entities/projection/entity_snapshot.dart';
import '../../../../domain/entities/projection/projection_item.dart';

const _parchment = Color(0xFFF5EFE0);
const _ink = Color(0xFF1B1B1B);
const _headingRed = Color(0xFF7A1F1F);
const _subtitle = Color(0xFF5A4A3A);

/// Player-window view of an entity card. Renders from a serializable
/// [EntitySnapshot]. SRD source-book look: serif red title, italic subtitle,
/// red rule, parchment background.
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
    return RepaintBoundary(
      child: Container(
        color: _parchment,
        padding: const EdgeInsets.all(48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    snap.name,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: _headingRed,
                      height: 1.1,
                    ),
                  ),
                  // Italic subtitle = category name (DM card builds richer subtitle, but
                  // projection EntitySnapshot only carries category name).
                  if (snap.categoryName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      snap.categoryName,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 20,
                        fontStyle: FontStyle.italic,
                        color: _subtitle,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(height: 1.5, color: _headingRed),
                  const SizedBox(height: 20),
                  // Body
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _RightColumn(snap: snap)),
                      if (snap.imagePaths.isNotEmpty) ...[
                        const SizedBox(width: 32),
                        _Portrait(path: snap.imagePaths.first),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

  const _RightColumn({required this.snap});

  @override
  Widget build(BuildContext context) {
    final groups = <String?, List<EntityFieldSnapshot>>{};
    for (final f in snap.fields) {
      groups.putIfAbsent(f.groupLabel, () => []).add(f);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (snap.source.isNotEmpty) ...[
          Text(
            'Source: ${snap.source}',
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 14,
              color: _subtitle,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (snap.description.isNotEmpty) ...[
          Text(
            snap.description,
            style: const TextStyle(
              fontSize: 18,
              color: _ink,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
        ],

        if (snap.fields.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final entry in groups.entries) ...[
            if (entry.key != null && entry.key!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 4),
                child: Text(
                  entry.key!,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _headingRed,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Container(height: 1, color: _headingRed),
              const SizedBox(height: 8),
            ],
            for (final f in entry.value) _FieldRow(field: f),
          ],
        ],
      ],
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
            width: 200,
            child: Text(
              '${field.label}:',
              style: const TextStyle(
                fontSize: 16,
                color: _ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              field.value,
              style: const TextStyle(fontSize: 16, color: _ink),
            ),
          ),
        ],
      ),
    );
  }
}
