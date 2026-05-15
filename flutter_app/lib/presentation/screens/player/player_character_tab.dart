import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/campaign_provider.dart';
import '../../../application/providers/role_provider.dart';
import '../../../core/utils/screen_type.dart';
import '../characters/character_editor_screen.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/character_add_menu.dart';
import '../../widgets/online_world_widgets.dart';
import '../../widgets/world_characters_view.dart';

/// Player character tab. Hosts the shared [WorldCharactersView] (3 sections:
/// Your / Available to Claim / Other Players) plus a roster strip + create
/// button. DM-only controls are gated by `dmMode: false`.
///
/// Character open: in-tab inline swap. Tapping a card sets `_openCharacterId`
/// → `CharacterEditorScreen` renders embedded with `onClose` returning to the
/// list. No fullscreen route push.
class PlayerCharacterTab extends ConsumerStatefulWidget {
  const PlayerCharacterTab({super.key});

  @override
  ConsumerState<PlayerCharacterTab> createState() => _PlayerCharacterTabState();
}

class _PlayerCharacterTabState extends ConsumerState<PlayerCharacterTab> {
  String? _openCharacterId;

  void _open(String characterId) {
    setState(() => _openCharacterId = characterId);
  }

  void _closeInline() {
    setState(() => _openCharacterId = null);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    if (_openCharacterId != null) {
      return CharacterEditorScreen(
        characterId: _openCharacterId!,
        onClose: _closeInline,
      );
    }
    final activeWorld = ref.watch(activeCampaignProvider);
    final worldId = ref.watch(activeCampaignIdProvider).valueOrNull;
    final screen = getScreenType(context);
    final maxWidth = switch (screen) {
      ScreenType.desktop => 720.0,
      ScreenType.tablet => 640.0,
      ScreenType.phone => double.infinity,
    };

    return Container(
      color: palette.tabBg,
      child: Column(
        children: [
          _Header(palette: palette, activeWorld: activeWorld),
          if (worldId != null)
            MembersStrip(worldId: worldId, palette: palette),
          Expanded(
            child: worldId == null
                ? _EmptyOpenWorld(palette: palette)
                : WorldCharactersView(
                    palette: palette,
                    worldId: worldId,
                    dmMode: false,
                    onOpen: _open,
                    padding: EdgeInsets.all(
                        screen == ScreenType.phone ? 12 : 20),
                    maxWidth: maxWidth,
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final DmToolColors palette;
  final String? activeWorld;
  const _Header({required this.palette, required this.activeWorld});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: palette.tabBg,
        border: Border(bottom: BorderSide(color: palette.sidebarDivider)),
      ),
      child: Row(
        children: [
          Icon(Icons.person, size: 18, color: palette.tabActiveText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              activeWorld == null
                  ? 'Your Characters'
                  : 'Characters · $activeWorld',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: palette.tabActiveText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          CharacterAddButton(
            palette: palette,
            activeWorld: activeWorld,
          ),
        ],
      ),
    );
  }
}

class _EmptyOpenWorld extends StatelessWidget {
  final DmToolColors palette;
  const _EmptyOpenWorld({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Open a world to see characters.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.sidebarLabelSecondary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
