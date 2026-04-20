import 'package:flutter/widgets.dart';

/// Inherited scope installed by each database-screen panel so descendant
/// link chips can open referenced entities in the OPPOSITE panel without
/// taking a callback through props. `panelId` lets the router tell which
/// panel the current card lives in ("left" or "right").
///
/// If no scope is installed (e.g. card shown in a dialog or preview),
/// [CardPanelScope.maybeOf] returns null and link chips fall back to a
/// no-op tap.
class CardPanelScope extends InheritedWidget {
  final String panelId;
  final void Function(String entityId) openInOtherPanel;

  const CardPanelScope({
    required this.panelId,
    required this.openInOtherPanel,
    required super.child,
    super.key,
  });

  static CardPanelScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CardPanelScope>();
  }

  @override
  bool updateShouldNotify(CardPanelScope old) =>
      panelId != old.panelId ||
      !identical(openInOtherPanel, old.openInOtherPanel);
}
