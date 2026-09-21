
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/account_gate.dart';
import '../../application/providers/campaign_provider.dart';
import '../../application/providers/character_provider.dart';
import '../../application/providers/online_worlds_provider.dart';
import '../../application/providers/package_provider.dart';
import '../../application/providers/role_provider.dart';
import '../../application/providers/world_membership_provider.dart';
import '../../application/providers/world_mirror_provider.dart';
import '../../application/providers/world_online_status_provider.dart';
import '../../application/services/world_meta_sync.dart';
import '../../core/utils/error_format.dart';
import '../../domain/entities/online/world_member.dart';
import '../../domain/entities/online/world_role.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';
import 'online_world_widgets.dart';

/// Campaign settings dialog'unda yer alan "Online" bölümü.
///   - Worldu publish/unpublish etmek için toggle (DM).
///   - Aktif invite kodlarını listelemek + yenisini üretmek.
///   - Üyeleri listelemek + kovmak.
///   - Player için: rol göstergesi + "Leave World" butonu.
class OnlineWorldSection extends ConsumerStatefulWidget {
  /// Bu setting dialog'unun açıldığı campaign'in id (UUID).
  final String campaignId;
  /// Campaign display adı.
  final String campaignName;

  const OnlineWorldSection({
    super.key,
    required this.campaignId,
    required this.campaignName,
  });

  @override
  ConsumerState<OnlineWorldSection> createState() =>
      _OnlineWorldSectionState();
}

class _OnlineWorldSectionState extends ConsumerState<OnlineWorldSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final offline = !ref.watch(hasAccountProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cloud_outlined, size: 16, color: palette.tabActiveText),
            const SizedBox(width: 6),
            Text(L10n.of(context)!.worldsRoleBadgeNone,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: palette.tabActiveText,
                )),
          ],
        ),
        const SizedBox(height: 8),
        if (offline)
          Text(
            L10n.of(context)!.onlineSignInToEnable,
            style: TextStyle(
                fontSize: 12, color: palette.sidebarLabelSecondary),
          )
        else
          _onlineBody(palette),
      ],
    );
  }

  Widget _onlineBody(DmToolColors palette) {
    final onlineStatusAsync =
        ref.watch(worldOnlineStatusProvider(widget.campaignId));
    final roleAsync = ref.watch(worldRoleProvider(widget.campaignId));

    return onlineStatusAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Text(formatError(e),
          style: TextStyle(fontSize: 12, color: palette.dangerBtnBg)),
      data: (isOnline) {
        final role = roleAsync.valueOrNull ?? WorldRole.none;
        if (!isOnline) return _offlineToggle(palette);
        if (role == WorldRole.dm) return _dmManageOnline(palette);
        if (role == WorldRole.player) return _playerInfo(palette);
        // online ama henüz üyelik bilgisi gelmedi: yumuşak bekleme.
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Text(L10n.of(context)!.onlineResolvingMembership,
              style: const TextStyle(fontSize: 12)),
        );
      },
    );
  }

  Widget _offlineToggle(DmToolColors palette) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.featureCardBg,
        borderRadius: palette.br,
        border: Border.all(color: palette.featureCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L10n.of(context)!.onlineLocalOnly,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            L10n.of(context)!.onlineMakeOnlineBody,
            style: TextStyle(
                fontSize: 12, color: palette.sidebarLabelSecondary),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy ? null : _publish,
            icon: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload, size: 16),
            label: Text(L10n.of(context)!.multiplayerOn),
          ),
        ],
      ),
    );
  }

  Widget _dmManageOnline(DmToolColors palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, size: 14, color: palette.successBtnBg),
            const SizedBox(width: 6),
            Text(L10n.of(context)!.worldIsOnline,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton.icon(
              onPressed: _busy ? null : _unpublish,
              icon: const Icon(Icons.cloud_off, size: 14),
              label: Text(L10n.of(context)!.multiplayerOff),
              style: TextButton.styleFrom(
                foregroundColor: palette.dangerBtnBg,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OnlineSectionLabel('Invite Code', palette),
        const SizedBox(height: 8),
        InviteCodeRow(palette: palette, worldId: widget.campaignId),
        const SizedBox(height: 16),
        OnlineSectionLabel('Members', palette),
        const SizedBox(height: 8),
        MembersList(
          worldId: widget.campaignId,
          palette: palette,
          onRemoveMember: _busy ? null : _removeMember,
        ),
      ],
    );
  }

  Widget _playerInfo(DmToolColors palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person, size: 14, color: palette.tabActiveText),
            const SizedBox(width: 6),
            Text(L10n.of(context)!.joinedAsPlayer,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton.icon(
              onPressed: _busy ? null : _leave,
              icon: const Icon(Icons.exit_to_app, size: 14),
              label: Text(L10n.of(context)!.worldsLeaveTitle),
              style: TextButton.styleFrom(
                foregroundColor: palette.dangerBtnBg,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OnlineSectionLabel('Members', palette),
        const SizedBox(height: 8),
        MembersList(worldId: widget.campaignId, palette: palette),
      ],
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────

  Future<void> _publish() async {
    // Online oynamak hesap ister — dünya paylaşımı auth.uid()'e bağlı satırlar
    // üzerinden yürüyor. Beta kapısı kalktı; kalan tek koşul bu.
    if (!ref.read(hasAccountProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context)!.accountRequiredBody)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(campaignRepositoryProvider);
      final data = await repo.load(widget.campaignName);
      final templateId =
          (data['world_schema'] as Map?)?['schemaId'] as String?;
      final templateHash = data['template_hash'] as String?;
      await ref.read(worldMembershipServiceProvider).publishWorld(
            worldId: widget.campaignId,
            worldName: widget.campaignName,
            templateId: templateId,
            templateHash: templateHash,
          );
      // Kart kimliği (açıklama/etiket/kapak) da çıksın — oyuncu dünyaya
      // katıldığında hub kartı boş görünmesin.
      final meta = data['metadata'];
      if (meta is Map) {
        await ref.read(worldMetaSyncProvider)?.push(
              worldId: widget.campaignId,
              metadata: Map<String, dynamic>.from(meta),
            );
      }
      ref.read(onlineWorldIdsProvider.notifier).add(widget.campaignId);
      // Bu dünyanın yerel karakterlerini aynaya taşı — aksi halde sidebar
      // bulut listesine döndüğünde boş görünür.
      await ref
          .read(characterListProvider.notifier)
          .pushOwnedCharacters(widget.campaignId);
      ref.invalidate(worldOnlineStatusProvider(widget.campaignId));
      ref.invalidate(currentWorldRoleProvider);
      ref.invalidate(worldRoleProvider(widget.campaignId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context)!.worldNowOnline)),
      );
      // Hub'daki ayar diyaloğu aktif OLMAYAN bir dünyayı da publish
      // edebiliyor — tohum `data`'dan okumalı, provider'lardan değil.
      await seedAndAnnounceWorldContent(
        context,
        ref,
        widget.campaignId,
        campaignData: data,
      );
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unpublish() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(context)!.multiplayerOff),
        content: Text(
            L10n.of(context)!.multiplayerOffBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L10n.of(context)!.btnCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(L10n.of(context)!.multiplayerOff)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    // Make Offline = kasıtlı; lokal Drift verisi korunmalı. unpublish'in
    // cascade DELETE CDC echo'su bu cihaza döndüğünde applier purge'ü
    // atlasın diye guard'ı kaydet.
    final mirror = ref.read(worldMirrorServiceProvider);
    mirror?.registerExpectedUnpublish(widget.campaignId);
    try {
      await ref
          .read(worldMembershipServiceProvider)
          .unpublishWorld(widget.campaignId);
      ref.read(onlineWorldIdsProvider.notifier).remove(widget.campaignId);
      ref.invalidate(worldOnlineStatusProvider(widget.campaignId));
      ref.invalidate(currentWorldRoleProvider);
      ref.invalidate(worldRoleProvider(widget.campaignId));
      ref.invalidate(worldMembersProvider(widget.campaignId));
      ref.invalidate(worldInvitesProvider(widget.campaignId));
    } catch (e) {
      // Unpublish başarısız → DELETE CDC gelmez, guard'ı bırak.
      mirror?.clearExpectedUnpublish(widget.campaignId);
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeMember(WorldMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(context)!.removeMember),
        content: Text(
            L10n.of(context)!.removeMemberBody(m.displayName ?? m.username ?? L10n.of(context)!.thisPlayer)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L10n.of(context)!.btnCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(L10n.of(context)!.btnRemove)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(worldMembershipServiceProvider).removeMember(
            worldId: widget.campaignId,
            userId: m.userId,
          );
      ref.invalidate(worldMembersProvider(widget.campaignId));
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(context)!.worldsLeaveTitle),
        content: Text(
            L10n.of(context)!.leaveWorldBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L10n.of(context)!.btnCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(L10n.of(context)!.worldsBtnLeave)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(worldMembershipServiceProvider)
          .leaveWorld(widget.campaignId);
      ref.read(onlineWorldIdsProvider.notifier).remove(widget.campaignId);
      ref.invalidate(currentWorldRoleProvider);
      ref.invalidate(worldRoleProvider(widget.campaignId));
      ref.invalidate(worldOnlineStatusProvider(widget.campaignId));
      // Wipe the local mirror immediately — no `.trash/` entry. The
      // realtime applier would do this on its own once the world_members
      // DELETE event arrives, but we don't want to make the user stare at
      // a dead settings dialog while waiting for round-trip.
      await ref
          .read(activeCampaignProvider.notifier)
          .purge(widget.campaignName);
      ref.invalidate(campaignInfoListProvider);
      ref.invalidate(packageListProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context)!.leftWorldSnack(widget.campaignName))),
        );
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    final palette = Theme.of(context).extension<DmToolColors>()!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(formatError(e)),
        backgroundColor: palette.dangerBtnBg,
      ),
    );
  }
}

