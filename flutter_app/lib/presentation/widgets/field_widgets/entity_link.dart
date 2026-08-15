import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/ui_state_provider.dart';
import '../../../domain/entities/entity.dart';
import '../../../domain/services/entity_ref.dart';

/// **The one "open this entity" entry point** (audit **U3**).
///
/// U3's design decision was where a widget nested inside a field asks for a
/// card to be opened. Screen selection is local `setState` — `_selectedEntityId`
/// in `main_screen.dart` and `package_screen.dart` — so a mini relation field
/// buried in a structured-list row cannot reach it. The answer is not a third
/// copy of that state and not a callback threaded through every field-widget
/// constructor: [entityNavigationProvider] already existed for exactly this,
/// `main_screen` already listened to it, and the relation chips and markdown
/// links already wrote to it. This file lifts the write out of
/// `field_widget_factory` so every ref renderer — including the ones in
/// `structured_list_field_widgets` — uses the same one.
void navigateToEntity(WidgetRef ref, String id, {String? sourcePanel}) {
  final target = switch (sourcePanel) {
    'left' => 'right',
    'right' => 'left',
    _ => null,
  };
  ref.read(entityNavigationTargetPanelProvider.notifier).state = target;
  ref.read(entityNavigationProvider.notifier).state = id;
}

/// The id a stored ref should open, or `null` when nothing is there to open.
///
/// Goes through [resolveEntityRef] — the reader U1 standardised the wizard on —
/// so the three envelopes (bare uuid, `{_ref/_lookup, name}`, soft
/// `{slug, name}`) all become links, and **nothing else does**. Returning
/// `null` is the load-bearing half: an uninstalled pack's card must stay plain
/// text, because a link that opens an empty dialog is worse than no link.
String? entityLinkTarget(Object? raw, Map<String, Entity>? byId) {
  if (byId == null) return null;
  return resolveEntityRef(raw, byId);
}

/// Wraps [child] in a tap that opens [targetId]; renders it untouched when
/// [targetId] or [ref] is null. The underline is the affordance — it appears
/// only when the tap will actually land somewhere.
class EntityLink extends StatelessWidget {
  const EntityLink({
    super.key,
    required this.targetId,
    required this.ref,
    required this.child,
    this.sourcePanel,
  });

  final String? targetId;
  final WidgetRef? ref;
  final String? sourcePanel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final id = targetId;
    final r = ref;
    if (id == null || r == null) return child;
    return InkWell(
      onTap: () => navigateToEntity(r, id, sourcePanel: sourcePanel),
      child: child,
    );
  }
}
