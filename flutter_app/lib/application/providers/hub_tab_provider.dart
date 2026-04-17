import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global hub tab index. HubScreen owns the visual state but exposes it here
/// so widgets outside the tree (e.g. the profile menu) can jump to a specific
/// tab. Default is 2 (Worlds), matching HubScreen's initial tab.
final hubTabIndexProvider = StateProvider<int>((ref) => 2);

/// Index of the Settings tab in [HubScreen]'s tab list.
const int settingsTabIndex = 1;
