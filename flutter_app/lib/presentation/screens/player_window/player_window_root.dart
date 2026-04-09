import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/projection/projection_item.dart';
import '../../../domain/entities/projection/projection_state.dart';
import 'player_window_state_provider.dart';
import 'views/battle_map_projection_view.dart';
import 'views/black_screen_view.dart';
import 'views/entity_card_projection_view.dart';
import 'views/image_projection_view.dart';

/// Root widget of the player sub-window. Uses an `IndexedStack` keyed by
/// `items.length` so every projected item stays mounted in the widget tree —
/// switching the active tab only changes the stack index, no rebuild, no
/// re-decode. This is the core performance trick.
///
/// This widget is shared between the local sub-window and the future remote
/// player tab (online mode), differing only in which provider feeds it
/// `ProjectionState`.
class PlayerWindowRoot extends ConsumerWidget {
  /// Provider that feeds this widget. When null, falls back to the
  /// sub-isolate's `playerProjectionStateProvider`; the future online tab
  /// will pass a remote-event-fed provider instead.
  final ProviderListenable<ProjectionState>? stateProvider;

  const PlayerWindowRoot({this.stateProvider, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stateProvider ?? playerProjectionStateProvider);
    final items = state.items;
    final activeIndex = _activeIndex(state);

    if (items.isEmpty) {
      // No items yet — show empty black canvas, optionally with a hint.
      return const BlackScreenView();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        IndexedStack(
          index: activeIndex,
          // Force children to fill the full window — without this, single
          // images render at their intrinsic size in the top-left corner
          // because IndexedStack defaults to StackFit.loose + topStart.
          sizing: StackFit.expand,
          alignment: Alignment.center,
          children: [
            for (final item in items) _itemWidget(item),
          ],
        ),
        if (state.blackoutOverride) const BlackScreenView(),
      ],
    );
  }

  int _activeIndex(ProjectionState state) {
    if (state.activeItemId == null) return 0;
    for (var i = 0; i < state.items.length; i++) {
      if (state.items[i].id == state.activeItemId) return i;
    }
    return 0;
  }

  Widget _itemWidget(ProjectionItem item) {
    // KeyedSubtree with a stable ValueKey so reorder/replace doesn't drop
    // the AutomaticKeepAliveClient state.
    return KeyedSubtree(
      key: ValueKey('projection_${item.id}'),
      child: switch (item) {
        ImageProjection() => ImageProjectionView(item: item),
        BlackScreenProjection() => const BlackScreenView(),
        EntityCardProjection() => EntityCardProjectionView(item: item),
        BattleMapProjection() => BattleMapProjectionView(item: item),
        PdfProjection() => const _StubView(label: 'PDF (Phase 3)'),
      },
    );
  }
}

class _StubView extends StatelessWidget {
  final String label;
  const _StubView({required this.label});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 24),
        ),
      ),
    );
  }
}
