import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/dm_tool_colors.dart';

/// Cloud backup button — uploads local item to cloud.
/// idle: cloud_upload icon, busy: spinner, done: check (2s), error: warning.
class CloudBackupButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isBusy;
  final bool isDone;
  final bool hasError;
  final String? tooltip;
  final double iconSize;

  const CloudBackupButton({
    super.key,
    this.onPressed,
    this.isBusy = false,
    this.isDone = false,
    this.hasError = false,
    this.tooltip,
    this.iconSize = 16,
  });

  @override
  State<CloudBackupButton> createState() => _CloudBackupButtonState();
}

class _CloudBackupButtonState extends State<CloudBackupButton> {
  bool _showCheck = false;
  Timer? _checkTimer;

  @override
  void didUpdateWidget(CloudBackupButton old) {
    super.didUpdateWidget(old);
    if (!old.isDone && widget.isDone && !widget.hasError) {
      setState(() => _showCheck = true);
      _checkTimer?.cancel();
      _checkTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showCheck = false);
      });
    }
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;

    final Widget icon;
    if (widget.isBusy) {
      icon = SizedBox(
        width: widget.iconSize,
        height: widget.iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: palette.featureCardAccent,
        ),
      );
    } else if (_showCheck) {
      icon = Icon(Icons.cloud_done, size: widget.iconSize,
          color: palette.successBtnBg);
    } else if (widget.hasError) {
      icon = Icon(Icons.cloud_off, size: widget.iconSize,
          color: palette.dangerBtnBg);
    } else {
      icon = Icon(Icons.cloud_upload_outlined, size: widget.iconSize,
          color: palette.tabText);
    }

    return IconButton(
      icon: icon,
      tooltip: widget.tooltip ?? 'Backup to Cloud',
      onPressed: widget.isBusy ? null : widget.onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
    );
  }
}

/// Cloud restore button — downloads cloud backup to local.
/// idle: cloud_download icon, busy: spinner, done: check (2s), error: warning.
class CloudRestoreButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isBusy;
  final bool isDone;
  final bool hasError;
  final String? tooltip;
  final double iconSize;

  const CloudRestoreButton({
    super.key,
    this.onPressed,
    this.isBusy = false,
    this.isDone = false,
    this.hasError = false,
    this.tooltip,
    this.iconSize = 16,
  });

  @override
  State<CloudRestoreButton> createState() => _CloudRestoreButtonState();
}

class _CloudRestoreButtonState extends State<CloudRestoreButton> {
  bool _showCheck = false;
  Timer? _checkTimer;

  @override
  void didUpdateWidget(CloudRestoreButton old) {
    super.didUpdateWidget(old);
    if (!old.isDone && widget.isDone && !widget.hasError) {
      setState(() => _showCheck = true);
      _checkTimer?.cancel();
      _checkTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showCheck = false);
      });
    }
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;

    final Widget icon;
    if (widget.isBusy) {
      icon = SizedBox(
        width: widget.iconSize,
        height: widget.iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: palette.featureCardAccent,
        ),
      );
    } else if (_showCheck) {
      icon = Icon(Icons.cloud_done, size: widget.iconSize,
          color: palette.successBtnBg);
    } else if (widget.hasError) {
      icon = Icon(Icons.cloud_off, size: widget.iconSize,
          color: palette.dangerBtnBg);
    } else {
      icon = Icon(Icons.cloud_download_outlined, size: widget.iconSize,
          color: palette.tabText);
    }

    return IconButton(
      icon: icon,
      tooltip: widget.tooltip ?? 'Restore from Cloud',
      onPressed: widget.isBusy ? null : widget.onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
    );
  }
}
