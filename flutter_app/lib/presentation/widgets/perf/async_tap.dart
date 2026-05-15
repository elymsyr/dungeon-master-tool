import 'package:flutter/material.dart';

/// InkWell variant that shows a spinner overlay while [onTap] is running and
/// blocks re-taps until the future completes. Use this anywhere an `onTap:
/// () async { await showDialog(...); }` chain currently leaves the user
/// staring at a frozen UI for 100-300ms before the dialog opens.
class AsyncInkWell extends StatefulWidget {
  const AsyncInkWell({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius,
    this.overlayColor,
    this.spinnerSize = 16,
    this.spinnerStrokeWidth = 2,
  });

  final Widget child;
  final Future<void> Function() onTap;
  final BorderRadius? borderRadius;
  final Color? overlayColor;
  final double spinnerSize;
  final double spinnerStrokeWidth;

  @override
  State<AsyncInkWell> createState() => _AsyncInkWellState();
}

class _AsyncInkWellState extends State<AsyncInkWell> {
  bool _busy = false;

  Future<void> _handleTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onTap();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        InkWell(
          borderRadius: widget.borderRadius,
          onTap: _busy ? null : _handleTap,
          child: widget.child,
        ),
        if (_busy)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: widget.overlayColor ?? Colors.black.withValues(alpha: 0.06),
                child: Center(
                  child: SizedBox(
                    width: widget.spinnerSize,
                    height: widget.spinnerSize,
                    child: CircularProgressIndicator(
                      strokeWidth: widget.spinnerStrokeWidth,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
