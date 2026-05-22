import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/projection/projection_state.dart';

/// Player-side holder for the projection manifest received from the DM.
///
/// `WorldMirrorApplier` writes this on every `world_projection` CDC event:
/// the decoded [ProjectionState] on insert/update, `null` on delete (DM
/// closed the projection). `PlayerSecondScreenTab` watches it to render
/// whatever the DM is currently sharing.
///
/// `null` = the DM is not projecting anything right now.
final onlineProjectionProvider = StateProvider<ProjectionState?>((ref) => null);
