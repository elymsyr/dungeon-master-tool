import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../application/providers/social_providers.dart';
import '../../../domain/entities/post.dart';
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
    if (_bodyCtrl.text.trim().isEmpty) return;
    final ok = await ref.read(postComposerProvider.notifier).submit(body: _bodyCtrl.text);
    if (ok) _bodyCtrl.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
    final feedAsync = ref.watch(feedProvider);
    final composerState = ref.watch(postComposerProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(feedProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        children: [
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
                  decoration: const InputDecoration(
                    hintText: "Share something with your players…",
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
                      tooltip: 'Add image (uses storage quota)',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Image upload coming soon')),
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
                          : const Text('Post', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                ? const SocialEmptyState(
                    icon: Icons.dynamic_feed_outlined,
                    title: 'Your feed is empty',
                    subtitle: 'Follow other players or share the first post above.',
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

class _PostCard extends StatelessWidget {
  final Post post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<DmToolColors>()!;
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
        ],
      ),
    );
  }
}
