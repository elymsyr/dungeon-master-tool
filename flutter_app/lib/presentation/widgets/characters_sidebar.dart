import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/campaign_provider.dart';
import '../../application/providers/character_claim_provider.dart';
import '../../application/providers/character_provider.dart';
import '../../application/providers/entity_provider.dart' show entityProvider;
import '../../application/providers/global_loading_provider.dart';
import '../../application/providers/online_worlds_provider.dart';
import '../../application/providers/role_provider.dart';
import '../../application/services/builtin_srd_entities.dart';
import '../../domain/entities/character.dart';
import '../../domain/entities/character_ext.dart';
import '../../domain/entities/entity.dart';
import '../screens/characters/character_editor_screen.dart';
import '../theme/dm_tool_colors.dart';
import 'character_add_menu.dart';
import 'character_stat_chips.dart';
import 'metadata_list_tile.dart';
import 'world_characters_view.dart';

/// Right-sidebar character workspace. Mirrors the player tab layout: 3
/// sections (Your / Available to Claim / Other) for online worlds via
/// [WorldCharactersView] with `dmMode: true`. Offline / solo worlds keep
/// the legacy local-list fallback. Tap → embeds [CharacterEditorScreen] in
/// the sidebar pane.
class CharactersSidebar extends ConsumerStatefulWidget {
  final DmToolColors palette;

  /// Optional callback invoked when the user taps a character whose
  /// `worldName` matches the active campaign. MainScreen wires this to
  /// surface the character inline (Database tab + selected entity).
  final void Function(String characterId)? onOpenCharacter;

  const CharactersSidebar({
    super.key,
    required this.palette,
    this.onOpenCharacter,
  });

  @override
  ConsumerState<CharactersSidebar> createState() => _CharactersSidebarState();
}

class _CharactersSidebarState extends ConsumerState<CharactersSidebar> {
  String? _inlineCharacterId;

  void _openInline(String id) {
    final inline = widget.onOpenCharacter;
    if (inline != null) {
      inline(id);
      return;
    }
    setState(() => _inlineCharacterId = id);
  }

  void _closeInline() {
    setState(() => _inlineCharacterId = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_inlineCharacterId != null) {
      return CharacterEditorScreen(
        characterId: _inlineCharacterId!,
        onClose: _closeInline,
      );
    }
    return _build(widget.palette);
  }

  Widget _build(DmToolColors palette) {
    final activeWorld = ref.watch(activeCampaignProvider);
    final worldId = ref.watch(activeCampaignIdProvider).valueOrNull;
    final onlineIds = ref.watch(onlineWorldIdsProvider);
    final isOnline = worldId != null && onlineIds.contains(worldId);

    return Column(
      children: [
        _SidebarHeader(
          palette: palette,
          activeWorld: activeWorld,
        ),
        Expanded(
          child: isOnline
              ? WorldCharactersView(
                  palette: palette,
                  worldId: worldId,
                  dmMode: true,
                  onOpen: _openInline,
                  padding: const EdgeInsets.all(8),
                )
              : _OfflineCharacterList(
                  palette: palette,
                  activeWorld: activeWorld,
                  onOpen: _openLocalCharacter,
                ),
        ),
      ],
    );
  }

  /// Offline path: keep the legacy load-cross-world behavior so picking a
  /// linked character from another world still opens correctly.
  Future<void> _openLocalCharacter(Character c) async {
    final worldId = c.worldId;
    String worldName = '';
    if (worldId != null) {
      final infos =
          ref.read(campaignInfoListProvider).valueOrNull ?? const [];
      worldName = c.resolvedWorldName(infos);
      if (worldName.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Character world not found locally.'),
          ),
        );
        return;
      }
      final active = ref.read(activeCampaignProvider);
      if (active != worldName) {
        final ok = await withLoading(
          ref.read(globalLoadingProvider.notifier),
          'open-world-$worldId',
          'Opening world "$worldName"...',
          () => ref.read(activeCampaignProvider.notifier).load(worldName),
        );
        if (!mounted) return;
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'World "$worldName" not found on disk — character cannot open.'),
            ),
          );
          return;
        }
      }
    }
    if (!mounted) return;
    final active = ref.read(activeCampaignProvider);
    final shouldEmbed = worldName.isNotEmpty && worldName == active;
    if (shouldEmbed) {
      _openInline(c.id);
      return;
    }
    context.push('/character/${c.id}');
  }
}

class _SidebarHeader extends StatelessWidget {
  final DmToolColors palette;
  final String? activeWorld;
  const _SidebarHeader({
    required this.palette,
    required this.activeWorld,
  });

  @override
  Widget build(BuildContext context) {
    // Match main center tab bar height (vertical:10 padding + ~18 icon row).
    // No bottom border — visually flush with content like the other tabs
    // (Database / Session / Mind Map / Map).
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: palette.tabBg,
      child: Row(
        children: [
          Icon(Icons.people, size: 18, color: palette.tabActiveText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              activeWorld == null
                  ? 'Characters'
                  : 'Characters · $activeWorld',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.tabActiveText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          CharacterAddButton(
            palette: palette,
            activeWorld: activeWorld,
            dense: true,
          ),
        ],
      ),
    );
  }
}

/// Offline / solo-world fallback. No `world_characters` mirror — pull from
/// the local `characterListProvider` filtered to this world. Renders the
/// same compact-row + hamburger UI as [WorldCharactersView] so the DM
/// sidebar looks identical regardless of online state.
///
/// Hamburger menu offline-context items: Remove from world, Delete. (No
/// claim/unclaim — claim is an online concept.)
class _OfflineCharacterList extends ConsumerWidget {
  final DmToolColors palette;
  final String? activeWorld;
  final ValueChanged<Character> onOpen;
  const _OfflineCharacterList({
    required this.palette,
    required this.activeWorld,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charactersAsync = ref.watch(characterListProvider);
    ref.watch(campaignRevisionProvider);
    // 039 model: world linkage kanon `worldId` (cloud `world_characters.world_id`
    // veya local Campaigns.id). Legacy `linked_character_ids` side-band kaldı —
    // sadece `worldName`/`worldId` üzerinden filter.
    final activeWorldId =
        ref.watch(activeCampaignIdProvider).valueOrNull;

    return charactersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error: $e',
            style: TextStyle(color: palette.dangerBtnBg),
          ),
        ),
      ),
      data: (all) {
        final scoped = activeWorldId == null
            ? const <Character>[]
            : (all
                    .where((c) => c.worldId == activeWorldId)
                    .toList()
                  ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));
        if (scoped.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                activeWorld == null
                    ? 'Open a world to see its characters.'
                    : 'No characters in this world yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.sidebarLabelSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: scoped.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            final c = scoped[i];
            return _OfflineCharacterRow(
              palette: palette,
              character: c,
              onOpen: () => onOpen(c),
            );
          },
        );
      },
    );
  }
}

class _OfflineCharacterRow extends ConsumerStatefulWidget {
  final DmToolColors palette;
  final Character character;
  final VoidCallback onOpen;
  const _OfflineCharacterRow({
    required this.palette,
    required this.character,
    required this.onOpen,
  });

  @override
  ConsumerState<_OfflineCharacterRow> createState() =>
      _OfflineCharacterRowState();
}

class _OfflineCharacterRowState
    extends ConsumerState<_OfflineCharacterRow> {
  bool _busy = false;

  Future<void> _runBusy(Future<void> Function() body) async {
    setState(() => _busy = true);
    try {
      await body();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeFromWorld() async {
    final c = widget.character;
    final palette = widget.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from world?'),
        content: Text(
          '"${c.entity.name}" leaves this world. The character itself is kept and can be attached to another world later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: palette.dangerBtnBg,
              foregroundColor: palette.dangerBtnText,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runBusy(() async {
      // 039 model: world linkage canonical `world_characters` row. `remove_from_world`
      // RPC server-side branch'i halleder:
      //   - owner varsa → world_id NULL (UPDATE event)
      //   - owner yoksa → DELETE event (CHECK violation olurdu)
      // CDC echo'su local Character'ın worldId/worldName'ini patch eder.
      // Auth-always invariant altında `svc != null`; gerçek offline'da
      // (Supabase config yok) manuel patch.
      final svc = ref.read(characterClaimServiceProvider);
      if (svc != null) {
        try {
          await svc.removeFromWorld(c.id);
        } catch (e) {
          // RPC fail ederse manuel patch'e düş — örn. row hâlâ migrate olmamış
          // legacy local-only karakter.
        }
      }
      await ref
          .read(characterListProvider.notifier)
          .update(c.copyWith(worldId: null));
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final c = widget.character;
    final activeWorldId =
        ref.watch(activeCampaignIdProvider).valueOrNull;
    final builtin = ref.watch(builtinSrdEntitiesProvider);
    final campaign = ref.watch(entityProvider);
    final Map<String, Entity> entities;
    if (c.worldId == null || c.worldId != activeWorldId) {
      entities = builtin;
    } else {
      entities = campaign.isEmpty
          ? builtin
          : UnmodifiableMapView<String, Entity>(
              CombinedMapView<String, Entity>([campaign, builtin]),
            );
    }
    return InkWell(
      borderRadius: palette.br,
      onTap: _busy ? null : widget.onOpen,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 140),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: palette.featureCardBg,
            borderRadius: palette.br,
            border: Border.all(color: palette.featureCardBorder),
          ),
          child: MetadataListTile(
            icon: Icons.person,
            name: c.entity.name,
            subtitle: c.templateName,
            description: c.entity.description,
            tags: c.entity.tags,
            coverImagePath: c.entity.imagePath,
            isSelected: false,
            palette: palette,
            layout: MetadataTileLayout.leftAvatar,
            onSettings: () {},
            infoChips: CharacterStatChips(
              lines: characterStatLines(
                c,
                entities,
                ownerLabel: resolveCharacterOwnerLabel(ref, c),
              ),
              palette: palette,
              compact: true,
            ),
            trailingControl: _busy
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : PopupMenuButton<String>(
                    tooltip: 'Actions',
                    icon: Icon(Icons.more_vert,
                        size: 18, color: palette.sidebarLabelSecondary),
                    padding: EdgeInsets.zero,
                    splashRadius: 18,
                    onSelected: (v) async {
                      switch (v) {
                        case 'remove':
                          await _removeFromWorld();
                      }
                    },
                    itemBuilder: (_) => [
                      if (c.worldId != null)
                        PopupMenuItem(
                          value: 'remove',
                          child: Row(children: [
                            Icon(Icons.exit_to_app,
                                size: 16, color: palette.dangerBtnBg),
                            const SizedBox(width: 8),
                            const Text('Remove from world'),
                          ]),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
