import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/services/screencast_platform.dart';

/// Dialog that lists available external displays for screencast.
///
/// Auto-refreshes the list when displays connect/disconnect. Returns the
/// selected [ExternalDisplay] or `null` if cancelled.
class ScreencastDisplayPicker extends StatefulWidget {
  const ScreencastDisplayPicker({super.key});

  /// Shows the picker and returns the chosen display, or `null`.
  static Future<ExternalDisplay?> show(BuildContext context) {
    return showDialog<ExternalDisplay>(
      context: context,
      builder: (_) => const ScreencastDisplayPicker(),
    );
  }

  @override
  State<ScreencastDisplayPicker> createState() =>
      _ScreencastDisplayPickerState();
}

class _ScreencastDisplayPickerState extends State<ScreencastDisplayPicker> {
  final _platform = ScreencastPlatform();
  List<ExternalDisplay>? _displays;
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadDisplays();
    // Poll every 2s to detect newly connected / disconnected displays.
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadDisplays();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _platform.dispose();
    super.dispose();
  }

  Future<void> _loadDisplays() async {
    final displays = await _platform.getAvailableDisplays();
    if (!mounted) return;
    setState(() {
      _displays = displays;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cast, size: 22),
          SizedBox(width: 10),
          Text('Screen Cast'),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: _buildContent(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final displays = _displays ?? [];
    if (displays.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cast, size: 48, color: Colors.white24),
            SizedBox(height: 12),
            Text(
              'No external display found.',
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 6),
            Text(
              'Connect a display via HDMI, Miracast,\nChromecast, or AirPlay.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white54),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child:
                      CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Waiting for displays...',
                  style: TextStyle(fontSize: 12, color: Colors.white38),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final display in displays)
          ListTile(
            leading: const Icon(Icons.tv),
            title: Text(display.name),
            subtitle: Text('${display.width} × ${display.height}'),
            onTap: () => Navigator.pop(context, display),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      ],
    );
  }
}
