import 'package:flutter/material.dart';

import '../../../domain/entities/entity.dart';
import '../../../domain/entities/map_data.dart';
import '../../../domain/value_objects/asset_ref.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/asset_ref_image.dart';
import 'world_map_notifier.dart';

/// Result returned by [DeleteWaypointDialog] — root world map strategy plus
/// a per-location map override.
class DeleteWaypointResult {
  final EraMergeStrategy root;
  final Map<String, EraMergeStrategy> perLocation;
  const DeleteWaypointResult({required this.root, required this.perLocation});
}

/// Result from [AddWaypointDialog].
class AddWaypointResult {
  final String label;
  final bool copyPins;
  final bool copyTimelinePins;
  const AddWaypointResult({
    required this.label,
    required this.copyPins,
    required this.copyTimelinePins,
  });
}

/// Dialog for adding a new era waypoint.
class AddWaypointDialog extends StatefulWidget {
  final DmToolColors palette;

  const AddWaypointDialog({super.key, required this.palette});

  @override
  State<AddWaypointDialog> createState() => _AddWaypointDialogState();
}

class _AddWaypointDialogState extends State<AddWaypointDialog> {
  final _labelCtrl = TextEditingController();
  bool _copyPins = false;
  bool _copyTimeline = false;

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return AlertDialog(
      backgroundColor: p.uiFloatingBg,
      title: Text('Add Waypoint',
          style: TextStyle(fontSize: 14, color: p.uiFloatingText)),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelCtrl,
              autofocus: true,
              style: TextStyle(fontSize: 12, color: p.uiFloatingText),
              decoration: InputDecoration(
                labelText: 'Name (number, date or text)',
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: p.uiFloatingText.withValues(alpha: 0.6),
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            _check('Copy map pins', _copyPins, (v) {
              setState(() => _copyPins = v ?? false);
            }),
            _check('Copy timeline pins', _copyTimeline, (v) {
              setState(() => _copyTimeline = v ?? false);
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              Text('Cancel', style: TextStyle(color: p.uiFloatingText)),
        ),
        ElevatedButton(
          onPressed: () {
            final label = _labelCtrl.text.trim();
            if (label.isEmpty) return;
            Navigator.pop(
              context,
              AddWaypointResult(
                label: label,
                copyPins: _copyPins,
                copyTimelinePins: _copyTimeline,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  Widget _check(String label, bool value, ValueChanged<bool?> onChanged) {
    final p = widget.palette;
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(value: value, onChanged: onChanged),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(fontSize: 11, color: p.uiFloatingText)),
      ],
    );
  }
}

/// Dialog for deleting a waypoint. Lists every scope with pin data (root
/// world map + each location whose drilled map has pins in either era) so
/// the DM can pick a merge strategy per scope.
class DeleteWaypointDialog extends StatefulWidget {
  final DmToolColors palette;
  final String waypointLabel;
  final MapEra leftEra;
  final MapEra rightEra;
  final Map<String, Entity> entities;

  const DeleteWaypointDialog({
    super.key,
    required this.palette,
    required this.waypointLabel,
    required this.leftEra,
    required this.rightEra,
    required this.entities,
  });

  @override
  State<DeleteWaypointDialog> createState() => _DeleteWaypointDialogState();
}

class _DeleteWaypointDialogState extends State<DeleteWaypointDialog> {
  EraMergeStrategy _rootStrategy = EraMergeStrategy.merge;
  final Map<String, EraMergeStrategy> _locationStrategies = {};

  static String? _resolveLocationMapRef(Entity entity, String eraId) {
    final perEra = entity.fields['map_per_era'];
    if (perEra is Map) {
      final v = perEra[eraId];
      if (v is String && v.isNotEmpty) return v;
    }
    final fallback = entity.fields['map'];
    if (fallback is String && fallback.isNotEmpty) return fallback;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;

    final locIds = <String>{
      ...widget.leftEra.locationMaps.keys,
      ...widget.rightEra.locationMaps.keys,
    }.toList()
      ..sort((a, b) {
        final na = widget.entities[a]?.name ?? a;
        final nb = widget.entities[b]?.name ?? b;
        return na.compareTo(nb);
      });

    return AlertDialog(
      backgroundColor: p.uiFloatingBg,
      title: Text('Delete: ${widget.waypointLabel}',
          style: TextStyle(fontSize: 14, color: p.uiFloatingText)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _rootRow(p),
              for (final id in locIds) ...[
                const SizedBox(height: 12),
                _locationRow(p, id),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: p.uiFloatingText)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
          onPressed: () => Navigator.pop(
            context,
            DeleteWaypointResult(
              root: _rootStrategy,
              perLocation: Map<String, EraMergeStrategy>.from(
                _locationStrategies,
              ),
            ),
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }

  Widget _rootRow(DmToolColors p) {
    final leftPins =
        widget.leftEra.pins.length + widget.leftEra.timelinePins.length;
    final rightPins =
        widget.rightEra.pins.length + widget.rightEra.timelinePins.length;
    return _scopeCard(
      p,
      label: 'World map',
      leftRef: widget.leftEra.imagePath,
      rightRef: widget.rightEra.imagePath,
      leftPins: leftPins,
      rightPins: rightPins,
      strategy: _rootStrategy,
      onChanged: (v) => setState(
        () => _rootStrategy = v ?? _rootStrategy,
      ),
    );
  }

  Widget _locationRow(DmToolColors p, String locId) {
    final entity = widget.entities[locId];
    final name = entity?.name ?? locId;
    final leftData = widget.leftEra.locationMaps[locId];
    final rightData = widget.rightEra.locationMaps[locId];
    final leftPins =
        (leftData?.pins.length ?? 0) + (leftData?.timelinePins.length ?? 0);
    final rightPins =
        (rightData?.pins.length ?? 0) + (rightData?.timelinePins.length ?? 0);
    final leftRef = entity == null
        ? null
        : _resolveLocationMapRef(entity, widget.leftEra.id);
    final rightRef = entity == null
        ? null
        : _resolveLocationMapRef(entity, widget.rightEra.id);
    final strategy =
        _locationStrategies[locId] ?? EraMergeStrategy.merge;
    return _scopeCard(
      p,
      label: name,
      leftRef: leftRef ?? '',
      rightRef: rightRef ?? '',
      leftPins: leftPins,
      rightPins: rightPins,
      strategy: strategy,
      onChanged: (v) {
        if (v == null) return;
        setState(() => _locationStrategies[locId] = v);
      },
    );
  }

  Widget _scopeCard(
    DmToolColors p, {
    required String label,
    required String leftRef,
    required String rightRef,
    required int leftPins,
    required int rightPins,
    required EraMergeStrategy strategy,
    required ValueChanged<EraMergeStrategy?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: p.uiFloatingBorder),
        borderRadius: p.cbr,
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: p.uiFloatingText,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _thumb(p, ref: leftRef, pins: leftPins)),
              const SizedBox(width: 8),
              Expanded(child: _thumb(p, ref: rightRef, pins: rightPins)),
            ],
          ),
          const SizedBox(height: 8),
          RadioGroup<EraMergeStrategy>(
            groupValue: strategy,
            onChanged: onChanged,
            child: Column(
              children: [
                _radio(p, EraMergeStrategy.merge, 'Merge'),
                _radio(p, EraMergeStrategy.keepLeft, 'Keep left'),
                _radio(p, EraMergeStrategy.keepRight, 'Keep right'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb(DmToolColors p, {required String ref, required int pins}) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: ClipRRect(
        borderRadius: p.cbr,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (ref.isNotEmpty)
              AssetRefImage(
                ref: AssetRef(ref),
                fit: BoxFit.cover,
                cacheWidth: 480,
                placeholder: Container(color: p.canvasBg),
                errorWidget: Container(
                  color: p.canvasBg,
                  child: const Center(child: Icon(Icons.broken_image, size: 18)),
                ),
              )
            else
              Container(
                color: p.canvasBg,
                alignment: Alignment.center,
                child: Text(
                  'no map',
                  style: TextStyle(
                    fontSize: 11,
                    color: p.uiFloatingText.withValues(alpha: 0.5),
                  ),
                ),
              ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: p.chr,
                ),
                child: Text(
                  '$pins pins',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _radio(DmToolColors p, EraMergeStrategy value, String label) {
    return RadioListTile<EraMergeStrategy>(
      value: value,
      title: Text(label,
          style: TextStyle(fontSize: 12, color: p.uiFloatingText)),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// Dialog to pick which era to copy a pin to.
class CopyToEraDialog extends StatelessWidget {
  final DmToolColors palette;
  final List<String> eraNames;
  final int currentEraIndex;

  const CopyToEraDialog({
    super.key,
    required this.palette,
    required this.eraNames,
    required this.currentEraIndex,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final options = <int>[];
    for (int i = 0; i < eraNames.length; i++) {
      if (i != currentEraIndex) options.add(i);
    }

    return AlertDialog(
      backgroundColor: p.uiFloatingBg,
      title: Text('Copy to...',
          style: TextStyle(fontSize: 14, color: p.uiFloatingText)),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((i) {
            return ListTile(
              dense: true,
              title: Text(eraNames[i],
                  style:
                      TextStyle(fontSize: 12, color: p.uiFloatingText)),
              onTap: () => Navigator.pop(context, i),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Dialog to rename a waypoint.
class RenameWaypointDialog extends StatefulWidget {
  final DmToolColors palette;
  final String currentLabel;

  const RenameWaypointDialog({
    super.key,
    required this.palette,
    required this.currentLabel,
  });

  @override
  State<RenameWaypointDialog> createState() => _RenameWaypointDialogState();
}

class _RenameWaypointDialogState extends State<RenameWaypointDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentLabel);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return AlertDialog(
      backgroundColor: p.uiFloatingBg,
      title: Text('Rename Waypoint',
          style: TextStyle(fontSize: 14, color: p.uiFloatingText)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        style: TextStyle(fontSize: 12, color: p.uiFloatingText),
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          isDense: true,
          labelText: 'Label',
          labelStyle: TextStyle(
            fontSize: 11,
            color: p.uiFloatingText.withValues(alpha: 0.6),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              Text('Cancel', style: TextStyle(color: p.uiFloatingText)),
        ),
        ElevatedButton(
          onPressed: () {
            final label = _ctrl.text.trim();
            if (label.isNotEmpty) Navigator.pop(context, label);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
