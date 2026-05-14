import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global view/edit mode toggle. Read by every screen that switches between
/// read-only display and editable inputs (database, mind map, character
/// sidebar, etc.). Toggled from the main screen toolbar.
///
/// `false` = view (read-only). `true` = edit.
final editModeProvider = StateProvider<bool>((_) => false);
