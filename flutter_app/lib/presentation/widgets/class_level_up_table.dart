import 'package:flutter/material.dart';

import '../../domain/entities/entity.dart';
import '../theme/dm_tool_colors.dart';

/// Read-only per-level progression table built by merging a class's
/// `features` list with the picked subclass's `features` list. Renders
/// 20 rows (one per character level) with proficiency bonus and the
/// combined feature text granted at that level. Shown to characters
/// that have both a class and subclass selected.
class ClassLevelUpTable extends StatelessWidget {
  final Entity classEntity;
  final Entity subclassEntity;
  final int? currentLevel;

  const ClassLevelUpTable({
    super.key,
    required this.classEntity,
    required this.subclassEntity,
    this.currentLevel,
  });

  static int profBonusFor(int level) {
    if (level >= 17) return 6;
    if (level >= 13) return 5;
    if (level >= 9) return 4;
    if (level >= 5) return 3;
    return 2;
  }

  List<Map<String, dynamic>> _rowsFor(Entity e) {
    final v = e.fields['features'];
    if (v is! List) return const [];
    return [
      for (final r in v)
        if (r is Map) Map<String, dynamic>.from(r),
    ];
  }

  List<String> _featuresAtLevel(int level) {
    String label(Map<String, dynamic> r, String prefix) {
      final name = (r['name'] ?? '').toString().trim();
      final desc = (r['description'] ?? '').toString().trim();
      final head = name.isNotEmpty ? name : desc;
      return prefix.isEmpty ? head : '$prefix: $head';
    }

    final classRows = _rowsFor(classEntity).where((r) => r['level'] == level);
    final subRows = _rowsFor(subclassEntity).where((r) => r['level'] == level);
    return [
      for (final r in classRows) label(r, ''),
      for (final r in subRows) label(r, subclassEntity.name),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>();
    final ink = palette?.srdInk ?? Theme.of(context).colorScheme.onSurface;
    final headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: ink,
    );
    final cellStyle = TextStyle(fontSize: 12, color: ink);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 28,
            dataRowMinHeight: 28,
            dataRowMaxHeight: 80,
            columns: [
              DataColumn(label: Text('Lvl', style: headerStyle)),
              DataColumn(label: Text('PB', style: headerStyle)),
              DataColumn(label: Text('Features', style: headerStyle)),
            ],
            rows: [
              for (var lvl = 1; lvl <= 20; lvl++)
                DataRow(
                  selected: currentLevel == lvl,
                  cells: [
                    DataCell(Text('$lvl', style: cellStyle)),
                    DataCell(Text('+${profBonusFor(lvl)}', style: cellStyle)),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Text(
                          _featuresAtLevel(lvl).join('\n') ,
                          style: cellStyle,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
