import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/theme_provider.dart';
import '../../../application/providers/ui_state_provider.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import 'dice_log.dart';
import 'dice_physics.dart';
import 'dice_roll_view.dart';

/// The bottom-right button column — dice at the bottom, history/sidebar or
/// mind map zoom stacked above it, dice menu rows over those: one margin, one
/// size, one gap, on every platform.
const kFabMargin = 16.0;
const kFabSize = 40.0;
const kFabGap = 10.0;

/// Bottom inset for a column stacked right above the dice button.
const kAboveDiceFab = kFabMargin + kFabSize + kFabGap;

/// A button of that column: small FAB, card corners, a true 40×40 (no 48 tap
/// padding on phones, so columns line up the same as on desktop).
class StackFab extends StatelessWidget {
  const StackFab({super.key, required this.onPressed, required this.child, this.tooltip, this.heroTag});
  final VoidCallback? onPressed;
  final Widget child;
  final String? tooltip;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) => FloatingActionButton.small(
        heroTag: heroTag,
        tooltip: tooltip,
        shape: RoundedRectangleBorder(borderRadius: Theme.of(context).extension<DmToolColors>()!.cbr),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onPressed: onPressed,
        child: child,
      );
}

/// Right inset that keeps a bottom-pinned row clear of the mobile dice
/// button: 16 margin + 40 small FAB + 8 gap.
const kDiceFabLane = 64.0;

/// Height for such a row so the dice button sits centered inside it:
/// 16 margin + 40 small FAB + 16.
const kDiceFabRowHeight = 72.0;

/// The dice button, bottom right on world and character screens. Opens the
/// dice menu above itself over a lightly dimmed screen; the dice are thrown on
/// that same dim and a tap after they land closes it.
class DiceFab extends ConsumerWidget {
  const DiceFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = resolveDiceLook(ref.watch(uiStateProvider.select((s) => s.diceTheme)), ref.watch(themeProvider));
    return StackFab(
      heroTag: 'dice_fab',
      tooltip: L10n.of(context)!.diceRollerTooltip,
      onPressed: () => _open(context, look, ref.read(diceLoggerProvider)),
      child: const Icon(Icons.casino),
    );
  }

  void _open(BuildContext context, String look, DiceLogger logger) {
    final navigator = Navigator.of(context, rootNavigator: true);
    final box = context.findRenderObject()! as RenderBox;
    final anchor = box.localToGlobal(Offset.zero, ancestor: navigator.overlay!.context.findRenderObject()) & box.size;
    DiceKit.load(look).ignore(); // build the 3D dice while the menu is open
    _pushDiceRoute(context, _DiceMenu(anchor: anchor, look: look, logger: logger));
  }
}

/// Throws [counts] straight away (no menu), e.g. a d20 for a skill check;
/// [modifier] is added to the dice total and [label] titles the result card.
/// The session log gets it as a [kind] roll of [character].
void rollDice(BuildContext context, WidgetRef ref, Map<String, int> counts,
    {int modifier = 0, String? label, DiceRollKind kind = DiceRollKind.roll, String? character}) {
  final look = resolveDiceLook(ref.read(uiStateProvider).diceTheme, ref.read(themeProvider));
  final logger = ref.read(diceLoggerProvider);
  _pushDiceRoute(
    context,
    Builder(
      builder: (context) => DiceRollView(
        counts: counts,
        look: look,
        modifier: modifier,
        label: label,
        onClose: () => Navigator.of(context).pop(),
        onRolled: (roll) => unawaited(logger.log(
          kind: kind,
          label: label,
          character: character,
          total: roll.total + modifier,
          detail: rollBreakdown(roll, modifier),
        )),
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
/// that sits exactly where the dice button was, the dice on the same 40+10
/// pitch as the buttons they cover. Rolling swaps it for the dice.
class _DiceMenu extends StatefulWidget {
  const _DiceMenu({required this.anchor, required this.look, required this.logger});
  final Rect anchor;
  final String look;
  final DiceLogger logger;

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
    if (thrown != null) {
      return DiceRollView(
        counts: thrown,
        look: widget.look,
        onClose: _close,
        onRolled: (roll) => unawaited(widget.logger.log(
          kind: DiceRollKind.roll,
          total: roll.total,
          detail: rollBreakdown(roll, 0),
        )),
      );
    }

    final l10n = L10n.of(context)!;
    final size = MediaQuery.sizeOf(context);
    final a = widget.anchor;
    final selection = [
      for (final k in diceKinds)
        if ((_counts[k] ?? 0) > 0) '${_counts[k]}$k',
    ].join(' + ');
    return Stack(children: [
      Positioned(
        right: size.width - a.right,
        bottom: size.height - a.top,
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
                const SizedBox(height: kFabGap),
                for (final k in diceKinds) _row(k, a.width),
              ],
            ),
          ),
        ),
      ),
      Positioned.fromRect(
        rect: a,
        child: StackFab(
          tooltip: l10n.btnClose,
          onPressed: _close,
          child: const Icon(Icons.close),
        ),
      ),
    ]);
  }

  // [−] [+] (dN): tapping the die itself throws just that one die.
  Widget _row(String kind, double width) {
    final n = _counts[kind] ?? 0;
    final style = IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: Theme.of(context).extension<DmToolColors>()!.cbr));
    return Padding(
      padding: const EdgeInsets.only(bottom: kFabGap),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          style: style,
          onPressed: n == 0 ? null : () => _add(kind, -1),
          icon: const Icon(Icons.remove, size: 18),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          style: style,
          onPressed: _dice + diceIn(kind) > maxDicePerRoll ? null : () => _add(kind, 1),
          icon: const Icon(Icons.add, size: 18),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: width,
          child: Center(
            child: Badge(
              isLabelVisible: n > 0,
              label: Text('$n'),
              child: StackFab(
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
