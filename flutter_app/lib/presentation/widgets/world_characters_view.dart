import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/auth_provider.dart';
import '../../application/providers/character_claim_provider.dart';
import '../../application/providers/character_provider.dart';
import '../../application/providers/entity_provider.dart';
import '../../application/providers/role_provider.dart';
import '../../application/providers/world_characters_provider.dart';
import '../../application/providers/world_membership_provider.dart';
import '../../application/services/builtin_srd_entities.dart';
import '../../domain/entities/character.dart';
import '../../domain/entities/entity.dart';
import '../../domain/entities/online/world_member.dart';
import '../../domain/entities/online/world_role.dart';
import '../theme/dm_tool_colors.dart';
import 'character_stat_chips.dart';
import 'metadata_list_tile.dart';

/// Shared character list for both the DM world sidebar and the player tab.
///
/// Renders three sections — Your Characters, Available to Claim, Other —
/// against `worldCharactersProvider(worldId)`. Player vs DM only changes the
/// per-row controls: player can claim/release their own; DM additionally
/// gets assign-to-player and force-release on any row.
class WorldCharactersView extends ConsumerWidget {
  final DmToolColors palette;
  final String worldId;
  final bool dmMode;
  final ValueChanged<String> onOpen;
  final EdgeInsets padding;
  final double? maxWidth;

  const WorldCharactersView({
    super.key,
    required this.palette,
    required this.worldId,
    required this.dmMode,
    required this.onOpen,
    this.padding = const EdgeInsets.all(12),
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worldCharsAsync = ref.watch(worldCharactersProvider(worldId));
    final selfUid = ref.watch(authProvider)?.uid;
    return worldCharsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: $e',
              style: TextStyle(color: palette.dangerBtnBg)),
        ),
      ),
      data: (rows) {
        final mine = <WorldCharacterRow>[];
        final unclaimed = <WorldCharacterRow>[];
        final others = <WorldCharacterRow>[];
        for (final r in rows) {
          if (r.ownerId == null) {
            unclaimed.add(r);
          } else if (selfUid != null && r.ownerId == selfUid) {
            mine.add(r);
          } else {
            others.add(r);
          }
        }
        final body = ListView(
          padding: padding,
          children: [
            // "Import character to this world" butonu kaldırıldı — character tab
            // header'ındaki `+` menüsü zaten ImportOrphanDialog'u açıyor.
            if (mine.isNotEmpty) ...[
              _SectionHeader(
                palette: palette,
                icon: Icons.person,
                title: 'Your Character${mine.length > 1 ? 's' : ''}',
              ),
              const SizedBox(height: 8),
              for (final r in mine) ...[
                _CharacterRow(
                  row: r,
                  palette: palette,
                  dmMode: dmMode,
                  variant: _RowVariant.owned,
                  onOpen: onOpen,
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
            ],
            if (unclaimed.isNotEmpty) ...[
              _SectionHeader(
                palette: palette,
                icon: Icons.inventory_2,
                title: 'Available to Claim',
              ),
              Padding(
                padding:
                    const EdgeInsets.only(left: 26, bottom: 8, top: 4),
                child: Text(
                  dmMode
                      ? 'Unclaimed characters. Claim or assign to a player.'
                      : 'Unclaimed characters in this world. Claim one to make it yours.',
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),
              ),
              for (final r in unclaimed) ...[
                _CharacterRow(
                  row: r,
                  palette: palette,
                  dmMode: dmMode,
                  variant: _RowVariant.unclaimed,
                  onOpen: onOpen,
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
            ],
            if (others.isNotEmpty) ...[
              _SectionHeader(
                palette: palette,
                icon: Icons.group,
                title: dmMode
                    ? "Player Characters"
                    : "Other Players' Characters",
              ),
              const SizedBox(height: 8),
              for (final r in others) ...[
                _CharacterRow(
                  row: r,
                  palette: palette,
                  dmMode: dmMode,
                  variant: _RowVariant.other,
                  onOpen: onOpen,
                ),
                const SizedBox(height: 8),
              ],
            ],
            if (rows.isEmpty)
              _EmptyState(
                palette: palette,
                message: dmMode
                    ? 'No characters in this world yet. Create one to share with players.'
                    : 'No characters in this world yet. The DM can publish one to share, or create your own.',
              ),
          ],
        );
        if (maxWidth == null) return body;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth!),
            child: body,
          ),
        );
      },
    );
  }
}

enum _RowVariant { owned, unclaimed, other }

String _displayNameFor(WorldCharacterRow row) {
  try {
    final decoded = jsonDecode(row.payloadJson);
    if (decoded is Map<String, dynamic>) {
      final entity = decoded['entity'];
      if (entity is Map && entity['name'] is String) {
        final n = entity['name'] as String;
        if (n.isNotEmpty) return n;
      }
      final flat = decoded['name'];
      if (flat is String && flat.isNotEmpty) return flat;
    }
  } catch (_) {}
  return row.templateName.isNotEmpty ? row.templateName : '(Unnamed)';
}

class _SectionHeader extends StatelessWidget {
  final DmToolColors palette;
  final IconData icon;
  final String title;
  const _SectionHeader({
    required this.palette,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.tabIndicator),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: palette.tabActiveText,
            )),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final DmToolColors palette;
  final String message;
  const _EmptyState({required this.palette, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_alt_1,
                size: 56, color: palette.sidebarLabelSecondary),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: palette.sidebarLabelSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One character row. Tap opens inline editor. Trailing controls depend on
/// `variant` + `dmMode`:
///   - owned: Release (everyone)
///   - unclaimed: Claim (everyone) + DM overflow (assign-to / remove)
///   - other: open-only for player; DM gets overflow (assign-to / release /
///     remove)
class _CharacterRow extends ConsumerStatefulWidget {
  final WorldCharacterRow row;
  final DmToolColors palette;
  final bool dmMode;
  final _RowVariant variant;
  final ValueChanged<String> onOpen;
  const _CharacterRow({
    required this.row,
    required this.palette,
    required this.dmMode,
    required this.variant,
    required this.onOpen,
  });

  @override
  ConsumerState<_CharacterRow> createState() => _CharacterRowState();
}

class _CharacterRowState extends ConsumerState<_CharacterRow> {
  bool _busy = false;

  Future<void> _runBusy(Future<void> Function() body) async {
    setState(() => _busy = true);
    try {
      await body();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claim() async {
    await _runBusy(() async {
      try {
        final svc = ref.read(characterClaimServiceProvider);
        if (svc == null) return;
        final selfUid = ref.read(authProvider)?.uid;
        final result = await svc.claim(widget.row.id);
        ref
            .read(worldCharactersProvider(result.worldId).notifier)
            .applyMirror(widget.row.copyWith(
              ownerId: selfUid,
              updatedAt: DateTime.now(),
            ));
        try {
          final decoded = jsonDecode(widget.row.payloadJson);
          if (decoded is Map<String, dynamic>) {
            final character = Character.fromJson(decoded).copyWith(
              ownerId: selfUid,
              updatedAt: DateTime.now().toUtc().toIso8601String(),
            );
            await ref
                .read(characterListProvider.notifier)
                .applyMirror(character);
            // 039 model: world_characters CDC cross-device sync sağlar;
            // personal_characters retire edildi (migration 040). Eski
            // `ensureOnline` push'a gerek kalmadı.
          }
        } catch (e) {
          debugPrint('claim local seed error: $e');
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Character claimed')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    });
  }

  Future<void> _confirmAndRelease() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Release character?'),
        content: const Text(
          'You will give up ownership. Anyone in this world can claim it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: widget.palette.dangerBtnBg,
              foregroundColor: widget.palette.dangerBtnText,
            ),
            child: const Text('Release'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _release();
  }

  Future<void> _release() async {
    // RPC `release_character` artık (me, W) → (NULL, W) UPDATE yapar. Eski
    // local cleanup'lar (removeMirror, makeOffline, deleteBackupByItem) CDC
    // echo'sunun aynısını manuel uyguluyordu — yeni model'de DB single-source,
    // CDC `applyMirror` ile patch atar. Stale state'e karşı koruma RPC'nin
    // kendisinde (`v_owner IS NULL → idempotent return`).
    if (widget.row.ownerId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already released')),
      );
      return;
    }
    await _runBusy(() async {
      try {
        final svc = ref.read(characterClaimServiceProvider);
        if (svc == null) return;
        await svc.release(widget.row.id);
        // Optimistic local patch: owner_id → NULL. CDC echo'su geldiğinde de
        // aynı state'i ekleyecek; arada UI latency için optimistic.
        ref
            .read(worldCharactersProvider(widget.row.worldId).notifier)
            .applyMirror(widget.row.copyWith(
              ownerId: null,
              updatedAt: DateTime.now(),
            ));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Character released')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    });
  }

  /// DM force-release. `release_character` RPC artık owner-or-DM gate
  /// uygular; ayrı `setOwner(null)` direkt UPDATE kaldırıldı (constraint
  /// by-pass riski). Player tarafıyla aynı RPC.
  Future<void> _dmForceRelease() async {
    if (widget.row.ownerId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already released')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Release this character?'),
        content: Text(
          '"${_displayNameFor(widget.row)}" will lose its owner and become claimable again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: widget.palette.dangerBtnBg,
              foregroundColor: widget.palette.dangerBtnText,
            ),
            child: const Text('Release'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runBusy(() async {
      try {
        final svc = ref.read(characterClaimServiceProvider);
        if (svc == null) return;
        await svc.release(widget.row.id);
        ref
            .read(worldCharactersProvider(widget.row.worldId).notifier)
            .applyMirror(widget.row.copyWith(
              ownerId: null,
              updatedAt: DateTime.now(),
            ));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ownership released')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    });
  }

  /// DM assign dialog. Lists every player in the world plus a `None` option
  /// that nulls the owner — DM can clear ownership without leaving the
  /// menu. Returns `(picked: true, userId: …)` so a null `userId` means
  /// "unassign" (distinguishable from dialog dismissal).
  Future<void> _dmAssignToPlayer() async {
    final notifier =
        ref.read(worldMembersProvider(widget.row.worldId).notifier);
    await notifier.bootstrap();
    final members =
        ref.read(worldMembersProvider(widget.row.worldId)).valueOrNull ??
            const <WorldMember>[];
    final players =
        members.where((m) => m.role == WorldRole.player).toList();
    if (!mounted) return;
    const noneSentinel = '__none__';
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Assign "${_displayNameFor(widget.row)}" to'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, noneSentinel),
            child: const Row(children: [
              Icon(Icons.person_off_outlined, size: 16),
              SizedBox(width: 8),
              Text('None (unassign)'),
            ]),
          ),
          if (players.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'No players in this world yet.',
                style: TextStyle(fontSize: 12),
              ),
            )
          else
            ...players.map((m) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, m.userId),
                  child: Text(m.displayName ??
                      m.username ??
                      m.userId.substring(0, 8)),
                )),
        ],
      ),
    );
    if (selected == null) return;
    final userId = selected == noneSentinel ? null : selected;
    await _runBusy(() async {
      try {
        final svc = ref.read(characterClaimServiceProvider);
        if (svc == null) return;
        if (userId == null) {
          // None → unassign. `release_character` RPC owner-or-DM gate ile
          // owner_id = NULL yapar.
          await svc.release(widget.row.id);
        } else {
          await svc.assignToPlayer(
            characterId: widget.row.id,
            userId: userId,
          );
        }
        ref
            .read(worldCharactersProvider(widget.row.worldId).notifier)
            .applyMirror(widget.row.copyWith(
              ownerId: userId,
              clearOwner: userId == null,
              updatedAt: DateTime.now(),
            ));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userId == null
                ? 'Ownership cleared'
                : 'Assigned to player'),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    });
  }

  /// Unclaim dispatch: if the row belongs to the current user, the
  /// `release_character` RPC is the right path (owner-only). Otherwise DM
  /// uses the direct `setOwner(null)` admin update.
  Future<void> _unclaim() async {
    final selfUid = ref.read(authProvider)?.uid;
    if (widget.row.ownerId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already released')),
      );
      return;
    }
    if (selfUid != null && widget.row.ownerId == selfUid) {
      await _confirmAndRelease();
    } else if (widget.dmMode) {
      await _dmForceRelease();
    }
  }

  /// DM "Remove from world" — `remove_from_world` RPC. Server-side branch:
  ///   - owner varsa: `world_id → NULL` (karakter owner'ın char tab'ına düşer)
  ///   - owner yoksa: row tamamen silinir (CHECK violation olurdu)
  /// CDC echo'su uygun event'i yayar (UPDATE vs DELETE). `linked_character_ids`
  /// side-band list yeni model'de yok — `world_id` kolonu kanon.
  Future<void> _dmDelete() async {
    final hasOwner = widget.row.ownerId != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from world?'),
        content: Text(
          hasOwner
              ? '"${_displayNameFor(widget.row)}" leaves this world. The owner keeps the character in their Characters tab.'
              : '"${_displayNameFor(widget.row)}" is unclaimed — it will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: widget.palette.dangerBtnBg,
              foregroundColor: widget.palette.dangerBtnText,
            ),
            child: Text(hasOwner ? 'Remove' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runBusy(() async {
      try {
        final svc = ref.read(characterClaimServiceProvider);
        if (svc == null) return;
        final result = await svc.removeFromWorld(widget.row.id);
        // Optimistic: row world view'dan çıkar. CDC echo'su zaten DELETE
        // veya world_id=NULL UPDATE event'i yayar — sonradan idempotent.
        ref
            .read(worldCharactersProvider(widget.row.worldId).notifier)
            .removeMirror(widget.row.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.deleted
                ? 'Deleted from world'
                : 'Removed from world (owner keeps the character)'),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    });
  }

  /// Decoded Character from payloadJson. Null if payload malformed — caller
  /// falls back to row-level metadata (templateName, etc).
  Character? _decodeCharacter() {
    try {
      final decoded = jsonDecode(widget.row.payloadJson);
      if (decoded is Map<String, dynamic>) {
        return Character.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final name = _displayNameFor(widget.row);
    final isUnclaimed = widget.variant == _RowVariant.unclaimed;
    final isOther = widget.variant == _RowVariant.other;
    final cardColor = isUnclaimed
        ? palette.featureCardAccent.withValues(alpha: 0.08)
        : (isOther
            ? palette.featureCardBg.withValues(alpha: 0.6)
            : palette.featureCardBg);
    final subtitle = isOther
        ? '${widget.row.templateName} · Owned by another player'
        : widget.row.templateName;

    final character = _decodeCharacter();
    // Resolve entity map for stat chip name lookups. Active campaign first,
    // builtin SRD as fallback.
    final activeWorldId =
        ref.watch(activeCampaignIdProvider).valueOrNull;
    final builtin = ref.watch(builtinSrdEntitiesProvider);
    final Map<String, Entity> entities;
    if (character == null ||
        character.worldId == null ||
        character.worldId != activeWorldId) {
      entities = builtin;
    } else {
      final campaign = ref.watch(entityProvider);
      entities = campaign.isEmpty
          ? builtin
          : UnmodifiableMapView<String, Entity>(
              CombinedMapView<String, Entity>([campaign, builtin]),
            );
    }

    return InkWell(
      borderRadius: palette.br,
      onTap: _busy ? null : () => widget.onOpen(widget.row.id),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 140),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: palette.br,
            border: Border.all(color: palette.featureCardBorder),
          ),
          child: MetadataListTile(
            icon: isOther
                ? Icons.lock_outline
                : (isUnclaimed ? Icons.person_outline : Icons.person),
            name: name,
            subtitle: subtitle,
            description: character?.entity.description ?? '',
            tags: character?.entity.tags ?? const <String>[],
            coverImagePath: character?.entity.imagePath ?? '',
            isSelected: false,
            palette: palette,
            layout: MetadataTileLayout.leftAvatar,
            onSettings: () {},
            infoChips: character == null
                ? null
                : CharacterStatChips(
                    lines: characterStatLines(
                      character,
                      entities,
                      ownerLabel:
                          resolveCharacterOwnerLabel(ref, character),
                    ),
                    palette: palette,
                    compact: true,
                  ),
            trailingControl: _trailingMenu(isUnclaimed),
          ),
        ),
      ),
    );
  }

  /// Single hamburger replaces every per-variant action button. Items are
  /// gated by ownership + role so the menu carries only what the user is
  /// allowed to do — no greyed-out noise.
  ///
  /// Player: Claim (if unclaimed), Unclaim (if own).
  /// DM:     Claim (if unclaimed), Unclaim (if any owner — release-self or
  ///         force-release), Assign to player..., Remove from world.
  Widget _trailingMenu(bool isUnclaimed) {
    final palette = widget.palette;
    final canShowUnclaim = !isUnclaimed &&
        (widget.dmMode ||
            widget.row.ownerId == ref.read(authProvider)?.uid);
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      icon: Icon(Icons.more_vert,
          size: 18, color: palette.sidebarLabelSecondary),
      padding: EdgeInsets.zero,
      splashRadius: 18,
      onSelected: (v) async {
        switch (v) {
          case 'claim':
            await _claim();
          case 'unclaim':
            await _unclaim();
          case 'assign':
            await _dmAssignToPlayer();
          case 'remove':
            await _dmDelete();
        }
      },
      itemBuilder: (_) => [
        if (isUnclaimed)
          const PopupMenuItem(
            value: 'claim',
            child: Row(children: [
              Icon(Icons.check, size: 16),
              SizedBox(width: 8),
              Text('Claim'),
            ]),
          ),
        if (canShowUnclaim)
          const PopupMenuItem(
            value: 'unclaim',
            child: Row(children: [
              Icon(Icons.logout, size: 16),
              SizedBox(width: 8),
              Text('Unclaim'),
            ]),
          ),
        if (widget.dmMode) ...[
          const PopupMenuItem(
            value: 'assign',
            child: Row(children: [
              Icon(Icons.person_pin, size: 16),
              SizedBox(width: 8),
              Text('Assign to player...'),
            ]),
          ),
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
      ],
    );
  }
}

/// World içinden çağrılan import: kullanıcının orphan karakterlerini (worldless
/// + self-owned) listeler, seçileni `attachToWorld` ile aktif world'e bağlar.
/// Eski `LinkCharacterDialog`'un yeniden tasarlanmış hali — `linked_character_ids`
/// side-band ve cross-world re-link özellikleri kaldırıldı. Bir karakter aynı
/// anda en fazla bir dünyaya bağlıdır.
class ImportOrphanDialog extends ConsumerStatefulWidget {
  final String worldId;
  final DmToolColors palette;
  const ImportOrphanDialog({
    super.key,
    required this.worldId,
    required this.palette,
  });

  @override
  ConsumerState<ImportOrphanDialog> createState() =>
      ImportOrphanDialogState();
}

class ImportOrphanDialogState extends ConsumerState<ImportOrphanDialog> {
  bool _busy = false;

  Future<void> _attach(Character c) async {
    setState(() => _busy = true);
    try {
      final svc = ref.read(characterClaimServiceProvider);
      if (svc == null) {
        throw StateError('Sign in to import characters.');
      }
      await svc.attachToWorld(
        characterId: c.id,
        worldId: widget.worldId,
      );
      // Hub-level optimistic patch: worldId set et. Display layer
      // `campaignInfoListProvider` üzerinden adı çözer (worldName retired).
      final patched = c.copyWith(worldId: widget.worldId);
      await ref.read(characterListProvider.notifier).update(patched);
      // World list optimistic insert — CDC echo'su gelene kadar UI'da
      // boşluk olmasın. `applyMirror` idempotent, echo aynı row'u tekrar
      // yazınca diff yok.
      ref
          .read(worldCharactersProvider(widget.worldId).notifier)
          .applyMirror(
            WorldCharacterRow(
              id: c.id,
              worldId: widget.worldId,
              ownerId: c.ownerId,
              templateId: c.templateId,
              templateName: c.templateName,
              payloadJson: jsonEncode(patched.toJson()),
              updatedAt: DateTime.now().toUtc(),
            ),
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported "${c.entity.name}" to this world')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final selfUid = ref.watch(authProvider)?.uid;
    final charList = ref.watch(characterListProvider);

    return AlertDialog(
      title: const Text('Import Character'),
      content: SizedBox(
        width: 480,
        height: 420,
        child: charList.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (chars) {
            // Orphan + self-owned filtresi. `worldId == null` kanon.
            final candidates = chars
                .where((c) =>
                    c.ownerId == selfUid &&
                    c.worldId == null)
                .toList();
            if (candidates.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No orphan characters to import. Create one from the '
                    'Characters tab first, then come back here.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: palette.sidebarLabelSecondary),
                  ),
                ),
              );
            }
            return ListView.separated(
              itemCount: candidates.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final c = candidates[i];
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: palette.featureCardBg,
                    borderRadius: palette.cbr,
                    border: Border.all(color: palette.featureCardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: palette.tabActiveText),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.entity.name,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: palette.tabActiveText)),
                            Text(
                              c.templateName,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: palette.sidebarLabelSecondary),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 28,
                        child: FilledButton(
                          onPressed: _busy ? null : () => _attach(c),
                          style: FilledButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          child: const Text('Import'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
