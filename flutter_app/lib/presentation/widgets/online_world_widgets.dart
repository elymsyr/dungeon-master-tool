import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers/cloud_push_provider.dart';
import '../../application/providers/entity_share_provider.dart';
import '../../application/providers/global_loading_provider.dart';
import '../../application/providers/online_worlds_provider.dart';
import '../../application/providers/role_provider.dart';
import '../../application/providers/world_membership_provider.dart';
import '../../application/services/entity_share_prepare.dart';
import '../../application/services/world_media_sync.dart';
import '../../application/services/world_meta_sync.dart';
import '../../core/utils/error_format.dart';
import '../../core/utils/format_bytes.dart';
import '../../data/database/database_provider.dart';
import '../../domain/entities/online/world_member.dart';
import '../../domain/entities/online/world_role.dart';
import '../l10n/app_localizations.dart';
import '../theme/dm_tool_colors.dart';

/// Dünya online'a alındıktan sonra: DM'in **paylaşıma işaretlediği**
/// kartları oyunculara açar, sonra ne gidip ne gitmediğini bir kez anlatır.
/// İşaret dünya offline'ken de konulabiliyor, yani burada genelde hazır bir
/// liste bulunur.
///
/// Publish'in İKİ girişi var — dünya ayarlarındaki toggle
/// (`online_world_section._publish`) ve dünya içindeki "Make Online"
/// (`save_sync_indicator._makeOnline`). İkisi de buradan geçmek zorunda;
/// biri atlanırsa o yoldan online olan dünyada DM'in işaretledikleri hiç
/// gitmez.
///
/// [campaignData] aktif olmayan bir dünya publish edildiğinde zorunlu —
/// tohum o blob'dan okur, yoksa aktif kampanyanın kartlarını paylaşırdı.
Future<void> seedAndAnnounceWorldContent(
  BuildContext context,
  WidgetRef ref,
  String worldId, {
  Map<String, dynamic>? campaignData,
}) async {
  try {
    await ref.read(entitySharerProvider).seedSharedContent(
          worldId: worldId,
          campaignData: campaignData,
        );
  } catch (e) {
    debugPrint('seedSharedContent failed for $worldId: $e');
  }
  ref.invalidate(worldEntitySharesProvider(worldId));
  if (!context.mounted) return;
  final l10n = L10n.of(context)!;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.worldContentSharedTitle),
      content: Text(l10n.worldContentSharedBody),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.landingOk),
        ),
      ],
    ),
  );
}

/// "Multiplayer aç"ın ortak gövdesi — iki giriş (dünya içi gösterge ve hub
/// ayar diyaloğu) buradan geçer. Hub yolu bugüne kadar yerel bayrağı hiç
/// açmıyordu: o yoldan multiplayer olan dünyanın satırları buluta çıkmıyordu.
///
/// Sıra (Faz 5d):
///   1. Ön hesap — medyanın toplamı kalan kotaya sığmıyorsa hiçbir şey
///      yayınlanmadan red; ne kadar yer gerektiği söylenir.
///   2. `publish_world` + kart kimliği.
///   3. Yerel bayrak + satırların tam push'u.
///   4. Bütün medya, ilerleme overlay'inde. Ağ burada koparsa dünya yine
///      multiplayer; pompa eksikleri arka planda yeniden dener.
///   5. Limiti aşan dosyalar listelenir.
///
/// [data] dünyanın depodaki blob'u (`campaignRepository.load`). Dönen değer
/// dünyanın yayınlanıp yayınlanmadığı; ön hesap reddi burada anlatılır, diğer
/// hatalar çağırana çıkar.
Future<bool> turnMultiplayerOn(
  BuildContext context,
  WidgetRef ref,
  String worldId, {
  required Map<String, dynamic> data,
  required String worldName,
}) async {
  final l10n = L10n.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final pushSvc = ref.read(cloudPushServiceProvider);
  final media = ref.read(worldMediaSyncProvider);

  if (pushSvc != null && media != null) {
    final plan = await media.plan(await pushSvc.worldMediaRefs(worldId));
    if (plan.bytes > 0) {
      final quota = await media.quota();
      if (plan.bytes > quota.remaining) {
        messenger.showSnackBar(SnackBar(
          content: Text(l10n.multiplayerQuotaExceeded(
              formatBytes(plan.bytes), formatBytes(quota.remaining))),
        ));
        return false;
      }
    }
  }

  await ref.read(worldMembershipServiceProvider).publishWorld(
        worldId: worldId,
        worldName: worldName,
        templateId: (data['world_schema'] as Map?)?['schemaId'] as String?,
        templateHash: data['template_hash'] as String?,
      );
  // Kart kimliği (açıklama/etiket/kapak) da çıksın — oyuncu dünyaya
  // katıldığında hub kartı boş görünmesin.
  final meta = data['metadata'];
  if (meta is Map) {
    await ref.read(worldMetaSyncProvider)?.push(
          worldId: worldId,
          metadata: Map<String, dynamic>.from(meta),
        );
  }
  ref.read(onlineWorldIdsProvider.notifier).add(worldId);
  // `publish_world` DM üyeliğini yazdı; rol offline'ken `none`'a çözülüp
  // önbellekte kalmıştı. Tazelenmezse push "DM değil" diye atlar.
  ref.invalidate(currentWorldRoleProvider);
  ref.invalidate(worldRoleProvider(worldId));

  // Faz 4 — bayrak yerelde de duruyor: push kararı çevrimdışıyken de
  // verilebilmeli. Ardından ilk tam tur: dünyanın satırları buluta çıkar.
  await ref.read(appDatabaseProvider).worldsDao.setOnline(worldId, true);
  final pump = ref.read(cloudPushPumpProvider);
  final rows = await pump.push(full: true, worldId: worldId);
  debugPrint('multiplayer açıldı $worldId: ${rows.pushed} satır, '
      '${rows.rejected.length} red, hata: ${rows.error}');

  // Faz 9 kuralı: kullanıcının başlattığı ve beklediği iş → overlay.
  final loading = ref.read(globalLoadingProvider.notifier);
  const task = 'multiplayer-media';
  loading.start(LoadingTask(
      id: task, message: l10n.multiplayerUploadingMedia('0', '…')));
  WorldMediaReport? report;
  var complete = true;
  try {
    report = await pump.syncWorldMedia(worldId, onProgress: (done, total) {
      loading.update(task,
          message: l10n.multiplayerUploadingMedia('$done', '$total'),
          progress: total == 0 ? null : done / total);
    });
  } catch (e) {
    complete = false;
    debugPrint('multiplayer medya $worldId yarım kaldı: $e');
  } finally {
    loading.end(task);
  }

  if (!complete || (report?.failed.isNotEmpty ?? false)) {
    messenger.showSnackBar(
        SnackBar(content: Text(l10n.multiplayerMediaIncomplete)));
  }
  final tooLarge = report?.tooLarge ?? const <String>[];
  if (tooLarge.isNotEmpty && context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.multiplayerTooLargeTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.multiplayerTooLargeBody),
              const SizedBox(height: 12),
              for (final name in tooLarge)
                Text('• $name', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.landingOk),
          ),
        ],
      ),
    );
  }
  return true;
}

/// Compact uppercase-style section heading shared by save&sync indicator
/// and the world-settings online panel. Keeps the two surfaces visually
/// in sync.
class OnlineSectionLabel extends StatelessWidget {
  final String text;
  final DmToolColors palette;
  const OnlineSectionLabel(this.text, this.palette, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: palette.sidebarLabelSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Aktif tek davet kodunu büyük puntolu gösterir + copy / regenerate.
class InviteCodeRow extends ConsumerStatefulWidget {
  final DmToolColors palette;
  final String worldId;
  const InviteCodeRow({
    super.key,
    required this.palette,
    required this.worldId,
  });

  @override
  ConsumerState<InviteCodeRow> createState() => _InviteCodeRowState();
}

class _InviteCodeRowState extends ConsumerState<InviteCodeRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final codeAsync =
        ref.watch(worldActiveInviteCodeProvider(widget.worldId));
    return codeAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => Text(
        isOfflineError(e) ? formatError(e) : 'Could not load invite: $e',
        style: TextStyle(fontSize: 11, color: palette.dangerBtnBg),
      ),
      data: (code) {
        if (code == null) {
          return Row(
            children: [
              Expanded(
                child: Text(
                  L10n.of(context)!.inviteNone,
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),
              ),
              IconButton(
                tooltip: L10n.of(context)!.inviteRetryFetch,
                icon: const Icon(Icons.refresh, size: 16),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => ref.invalidate(
                    worldActiveInviteCodeProvider(widget.worldId)),
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: SelectableText(
                code,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  color: palette.tabActiveText,
                ),
              ),
            ),
            IconButton(
              tooltip: L10n.of(context)!.charCopyToWorldAction,
              icon: const Icon(Icons.copy, size: 16),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(L10n.of(context)!.inviteCopied)),
                );
              },
            ),
            IconButton(
              tooltip: L10n.of(context)!.inviteRegenerateTooltip,
              icon: const Icon(Icons.refresh, size: 16),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: _busy ? null : _regenerate,
            ),
          ],
        );
      },
    );
  }

  Future<void> _regenerate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(context)!.inviteRegenerateTitle),
        content: Text(
            L10n.of(context)!.inviteRegenerateBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L10n.of(context)!.btnCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(L10n.of(context)!.inviteRegenerate)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(worldMembershipServiceProvider)
          .regenerateInvite(widget.worldId);
      ref.invalidate(worldActiveInviteCodeProvider(widget.worldId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context)!.inviteRegenerated)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context)!.inviteRegenerateFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Tek üye satırı — avatar + display name + DM/PLAYER badge.
/// [onRemove] non-null ise sağda silme butonu render edilir (DM yetkisi).
class MemberRow extends StatelessWidget {
  final WorldMember member;
  final DmToolColors palette;
  final VoidCallback? onRemove;

  const MemberRow({
    super.key,
    required this.member,
    required this.palette,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final name = member.displayName?.isNotEmpty == true
        ? member.displayName!
        : (member.username?.isNotEmpty == true
            ? '@${member.username}'
            : member.userId.substring(0, 8));
    final isDm = member.role == WorldRole.dm;
    return InkWell(
      onTap: () => context.push('/profile/${member.userId}'),
      borderRadius: palette.br,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: palette.featureCardAccent.withValues(alpha: 0.2),
            backgroundImage: (member.avatarUrl?.isNotEmpty == true)
                ? NetworkImage(member.avatarUrl!)
                : null,
            child: (member.avatarUrl?.isEmpty ?? true)
                ? Icon(Icons.person, size: 12, color: palette.tabActiveText)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: palette.tabActiveText),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDm
                  ? palette.featureCardAccent.withValues(alpha: 0.2)
                  : palette.sidebarDivider,
              borderRadius: palette.br,
            ),
            child: Text(
              isDm ? 'DM' : 'PLAYER',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: isDm ? palette.tabIndicator : palette.tabActiveText,
              ),
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: L10n.of(context)!.removeFromWorld,
              icon: Icon(Icons.delete_outline,
                  size: 14, color: palette.dangerBtnBg),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: onRemove,
            ),
          ],
        ],
      ),
      ),
    );
  }
}

/// Player hub'ı / party tab için kompakt yatay roster çubuğu. Avatar +
/// initials + DM rozeti. `worldMembersProvider` ile granular reactive —
/// join/leave CDC anında çubuğa yansır.
class MembersStrip extends ConsumerWidget {
  final String worldId;
  final DmToolColors palette;
  const MembersStrip({
    super.key,
    required this.worldId,
    required this.palette,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(worldMembersProvider(worldId));
    return membersAsync.when(
      loading: () => const SizedBox(height: 36),
      error: (_, _) => const SizedBox(height: 36),
      data: (members) {
        if (members.isEmpty) {
          return SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  L10n.of(context)!.membersEmpty,
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.sidebarLabelSecondary,
                  ),
                ),
              ),
            ),
          );
        }
        final sorted = [...members]..sort((a, b) {
            if (a.role == WorldRole.dm && b.role != WorldRole.dm) return -1;
            if (a.role != WorldRole.dm && b.role == WorldRole.dm) return 1;
            return a.joinedAt.compareTo(b.joinedAt);
          });
        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _MemberChip(member: sorted[i], palette: palette),
          ),
        );
      },
    );
  }
}

class _MemberChip extends StatelessWidget {
  final WorldMember member;
  final DmToolColors palette;
  const _MemberChip({required this.member, required this.palette});

  String _initials() {
    final src = (member.displayName?.isNotEmpty == true
            ? member.displayName!
            : (member.username?.isNotEmpty == true
                ? member.username!
                : member.userId))
        .trim();
    if (src.isEmpty) return '?';
    final parts = src.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return src.substring(0, src.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDm = member.role == WorldRole.dm;
    final label = member.displayName?.isNotEmpty == true
        ? member.displayName!
        : (member.username?.isNotEmpty == true
            ? '@${member.username}'
            : member.userId.substring(0, 8));
    return Tooltip(
      message: '$label · ${isDm ? 'DM' : 'PLAYER'}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDm
              ? palette.featureCardAccent.withValues(alpha: 0.18)
              : palette.featureCardBg,
          borderRadius: palette.br,
          border: Border.all(
            color: isDm
                ? palette.featureCardAccent.withValues(alpha: 0.6)
                : palette.featureCardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 10,
              backgroundColor:
                  palette.featureCardAccent.withValues(alpha: 0.25),
              backgroundImage: (member.avatarUrl?.isNotEmpty == true)
                  ? NetworkImage(member.avatarUrl!)
                  : null,
              child: (member.avatarUrl?.isEmpty ?? true)
                  ? Text(
                      _initials(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: palette.tabActiveText,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: palette.tabActiveText,
              ),
            ),
            if (isDm) ...[
              const SizedBox(width: 4),
              Text(
                'DM',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: palette.tabIndicator,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `worldMembersProvider` watch eden hazır liste; loading/error/empty
/// durumlarını save&sync paneliyle aynı şekilde gösterir.
class MembersList extends ConsumerWidget {
  final String worldId;
  final DmToolColors palette;
  final void Function(WorldMember)? onRemoveMember;

  const MembersList({
    super.key,
    required this.worldId,
    required this.palette,
    this.onRemoveMember,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(worldMembersProvider(worldId));
    return membersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => Text(
        isOfflineError(e) ? formatError(e) : 'Could not load members: $e',
        style: TextStyle(fontSize: 11, color: palette.dangerBtnBg),
      ),
      data: (members) {
        if (members.isEmpty) {
          return Text(
            L10n.of(context)!.membersEmpty,
            style: TextStyle(
              fontSize: 12,
              color: palette.sidebarLabelSecondary,
            ),
          );
        }
        return Column(
          children: [
            for (final m in members)
              MemberRow(
                member: m,
                palette: palette,
                onRemove: onRemoveMember == null || m.role == WorldRole.dm
                    ? null
                    : () => onRemoveMember!(m),
              ),
          ],
        );
      },
    );
  }
}
