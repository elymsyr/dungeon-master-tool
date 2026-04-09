import 'package:flutter/material.dart';

/// Pure-black fullscreen filler. Used both as a regular projection item
/// (`BlackScreenProjection`) and as the global blackout overlay.
class BlackScreenView extends StatelessWidget {
  const BlackScreenView({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.black, child: SizedBox.expand());
  }
}
