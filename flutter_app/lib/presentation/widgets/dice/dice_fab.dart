import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/theme_provider.dart';
import '../../../application/providers/ui_state_provider.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import 'dice_physics.dart';
import 'dice_roll_view.dart';

/// The dice button, bottom right on world and character screens. Opens the
/// dice menu above itself over a lightly dimmed screen; the dice are thrown on
/// that same dim and a tap after they land closes it.
class DiceFab extends ConsumerWidget {
  const DiceFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final look = resolveDiceLook(ref.watch(uiStateProvider.select((s) => s.diceTheme)), ref.watch(themeProvider));
    return FloatingActionButton(
      heroTag: 'dice_fab',
      tooltip: L10n.of(context)!.diceRollerTooltip,
      shape: RoundedRectangleBorder(borderRadius: palette.cbr),
      onPressed: () => _open(context, look),
      child: const Icon(Icons.casino),
    );
  }

  void _open(BuildContext context, String look) {
    final navigator = Navigator.of(context, rootNavigator: true);
    final box = context.findRenderObject()! as RenderBox;
    final anchor = box.localToGlobal(Offset.zero, ancestor: navigator.overlay!.context.findRenderObject()) & box.size;
    DiceKit.load(look).ignore(); // build the 3D dice while the menu is open
    _pushDiceRoute(context, _DiceMenu(anchor: anchor, look: look));
  }
}

/// Throws [counts] straight away (no menu), e.g. a d20 for a skill check;
/// [modifier] is added to the dice total and [label] titles the result card.
void rollDice(BuildContext context, WidgetRef ref, Map<String, int> counts, {int modifier = 0, String? label}) {
  final look = resolveDiceLook(ref.read(uiStateProvider).diceTheme, ref.read(themeProvider));
  _pushDiceRoute(
    context,
    Builder(
      builder: (context) => DiceRollView(
        counts: counts,
        look: look,
        modifier: modifier,
        label: label,
        onClose: () => Navigator.of(context).pop(),
      ),
    ),
  );
}

void _pushDiceRoute(BuildContext context, Widget child) {
  Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.black45,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: const Duration(milliseconds: 150),
    reverseTransitionDuration: const Duration(milliseconds: 150),
    // Transparent Material: text styles + ink, without painting over the dim.
    pageBuilder: (_, _, _) => Material(type: MaterialType.transparency, child: child),
    transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
  ));
}

/// The open menu: a Roll button and one row per die kind stacked above an X
/// that sits exactly where the dice button was. Rolling swaps it for the dice.
class _DiceMenu extends StatefulWidget {
  const _DiceMenu({required this.anchor, required this.look});
  final Rect anchor;
  final String look;

  @override
  State<_DiceMenu> createState() => _DiceMenuState();
}

class _DiceMenuState extends State<_DiceMenu> {
  final _counts = <String, int>{};
  Map<String, int>? _thrown;

  int get _dice => _counts.entries.fold(0, (a, e) => a + e.value * diceIn(e.key));

  // Reads the live counts, so taps landing in one frame all count (and stop at the cap).
  void _add(String kind, int by) => setState(() {
        final n = (_counts[kind] ?? 0) + by;
        if (n >= 0 && _dice + by * diceIn(kind) <= maxDicePerRoll) _counts[kind] = n;
      });

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final thrown = _thrown;
    if (thrown != null) return DiceRollView(counts: thrown, look: widget.look, onClose: _close);

    final l10n = L10n.of(context)!;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final size = MediaQuery.sizeOf(context);
    final a = widget.anchor;
    final selection = [
      for (final k in diceKinds)
        if ((_counts[k] ?? 0) > 0) '${_counts[k]}$k',
    ].join(' + ');
    return Stack(children: [
      Positioned(
        right: size.width - a.right,
        bottom: size.height - a.top + 4,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: a.top - MediaQuery.paddingOf(context).top - 12),
          // Short screens (a phone on its side) scroll the rows; Roll stays reachable.
          child: SingleChildScrollView(
            reverse: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: selection.isEmpty ? null : () => setState(() => _thrown = Map.of(_counts)),
                  icon: const Icon(Icons.casino, size: 18),
                  label: Text(selection.isEmpty ? l10n.diceRoll : l10n.diceRollSelection(selection)),
                ),
                const SizedBox(height: 4),
                for (final k in diceKinds) _row(k, a.width),
              ],
            ),
          ),
        ),
      ),
      Positioned.fromRect(
        rect: a,
        child: FloatingActionButton(
          heroTag: null,
          tooltip: l10n.btnClose,
          shape: RoundedRectangleBorder(borderRadius: palette.cbr),
          onPressed: _close,
          child: const Icon(Icons.close),
        ),
      ),
    ]);
  }

  // [−] [+] (dN): tapping the die itself throws just that one die.
  Widget _row(String kind, double width) {
    final n = _counts[kind] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          onPressed: n == 0 ? null : () => _add(kind, -1),
          icon: const Icon(Icons.remove, size: 18),
        ),
        IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          onPressed: _dice + diceIn(kind) > maxDicePerRoll ? null : () => _add(kind, 1),
          icon: const Icon(Icons.add, size: 18),
        ),
        SizedBox(
          width: width,
          child: Center(
            child: Badge(
              isLabelVisible: n > 0,
              label: Text('$n'),
              child: FloatingActionButton.small(
                heroTag: null,
                onPressed: () => setState(() => _thrown = {kind: 1}),
                child: Text(kind, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
