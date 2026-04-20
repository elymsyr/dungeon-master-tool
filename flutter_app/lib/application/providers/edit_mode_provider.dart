import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global edit-mode toggle. When `false`, typed-card inline fields render
/// as read-only text (tap is a no-op) and the schema-driven `EntityCard`
/// is passed `readOnly: true`. When `true`, all inline edits are live.
///
/// Lives as a StateProvider rather than a local MainScreen state so the
/// many inline widgets scattered across typed cards can observe it
/// without prop-drilling an `editMode` boolean through every intermediate
/// layer.
final editModeProvider = StateProvider<bool>((_) => false);
