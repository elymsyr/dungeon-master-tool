import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/social_providers.dart';
import '../../../core/utils/profanity_filter.dart';
import '../../../data/datasources/remote/posts_remote_ds.dart' show FeedScope;
import '../../../domain/entities/post.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dm_tool_colors.dart';
import '../../widgets/profile_avatar.dart';
import 'social_shell.dart';

class FeedTab extends ConsumerStatefulWidget {
  const FeedTab({super.key});
  @override
  ConsumerState<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<FeedTab> {
  final _bodyCtrl = TextEditingController();
  bool _composerFocused = false;

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _bodyCtrl.text;
    if (raw.trim().isEmpty) return;
    final l10n = L10n.of(context)!;
    final ok = await ref.read(postComposerProvider.notifier).submit(body: raw);
    if (ok) _bodyCtrl.clear();
    if (!mounted) return;
    final state = ref.read(postComposerProvider);
    if (state is AsyncError && state.error is ProfanityRejectedException) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.feedProfanityRejected)),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final l10n = L10n.of(context)!;
    final feedAsync = ref.watch(feedProvider);
    final composerState = ref.watch(postComposerProvider);
    final scope = ref.watch(feedScopeProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(feedProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        children: [
          _FeedScopeTabs(scope: scope, palette: palette),
          const SizedBox(height: 16),
          // Composer
          SocialCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _bodyCtrl,
                  maxLines: _composerFocused ? 4 : 2,
                  minLines: 1,
                  maxLength: 2000,
                  onTap: () => setState(() => _composerFocused = true),
                  decoration: InputDecoration(
                    hintText: l10n.feedComposerHint,
                    border: InputBorder.none,
                    counterText: '',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.image_outlined, size: 20, color: palette.sidebarLabelSecondary),
                      tooltip: l10n.feedComposerImageTooltip,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.feedImageUploadComingSoon)),
                        );
                      },
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.featureCardAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: composerState is AsyncLoading || _bodyCtrl.text.trim().isEmpty
                          ? null
                          : _submit,
                      child: composerState is AsyncLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(l10n.feedBtnPost, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          feedAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SocialCard(
              child: Text('Error: $e', style: TextStyle(color: palette.dangerBtnBg)),
            ),
            data: (posts) => posts.isEmpty
                ? SocialEmptyState(
                    icon: Icons.dynamic_feed_outlined,
                    title: l10n.feedEmptyTitle,
                    subtitle: l10n.feedEmptySubtitle,
                  )
                : Column(
                    children: [
                      for (final p in posts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _PostCard(post: p),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _FeedScopeTabs extends ConsumerWidget {
  final FeedScope scope;
  final DmToolColors palette;
  const _FeedScopeTabs({required this.scope, required this.palette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context)!;
    return SegmentedButton<FeedScope>(
      style: SegmentedButton.styleFrom(
        backgroundColor: palette.tabBg,
        selectedBackgroundColor: palette.featureCardAccent,
        selectedForegroundColor: Colors.white,
        foregroundColor: palette.tabText,
        side: BorderSide(color: palette.featureCardBorder),
      ),
      segments: [
        ButtonSegment(
          value: FeedScope.all,
          label: Text(l10n.feedScopeAll),
          icon: const Icon(Icons.public, size: 16),
        ),
        ButtonSegment(
          value: FeedScope.following,
          label: Text(l10n.feedScopeFollowing),
          icon: const Icon(Icons.people_alt_outlined, size: 16),
        ),
      ],
      selected: {scope},
      onSelectionChanged: (s) {
        ref.read(feedScopeProvider.notifier).state = s.first;
      },
    );
  }
}

class _PostCard extends ConsumerWidget {
  final Post post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final likeBusy = ref.watch(postLikeProvider) is AsyncLoading;
    return SocialCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.push('/profile/${post.authorId}'),
                child: ProfileAvatar(
                  avatarUrl: post.authorAvatarUrl,
                  fallbackText: post.authorUsername ?? '?',
                  size: 36,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${post.authorUsername ?? 'unknown'}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.tabActiveText,
                      ),
                    ),
                    Text(
                      DateFormat.yMMMd().add_Hm().format(post.createdAt.toLocal()),
                      style: TextStyle(fontSize: 11, color: palette.sidebarLabelSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (post.body != null && post.body!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              post.body!,
              style: TextStyle(fontSize: 13.5, height: 1.45, color: palette.tabText),
            ),
          ],
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(post.imageUrl!, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: likeBusy
                    ? null
                    : () => ref.read(postLikeProvider.notifier).toggle(post.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        post.likedByMe ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: post.likedByMe
                            ? palette.dangerBtnBg
                            : palette.sidebarLabelSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${post.likeCount}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: post.likedByMe
                              ? palette.dangerBtnBg
                              : palette.sidebarLabelSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
