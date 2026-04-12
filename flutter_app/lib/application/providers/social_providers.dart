import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/profanity_filter.dart';
import '../../data/datasources/remote/game_listings_remote_ds.dart';
import '../../data/datasources/remote/messages_remote_ds.dart';
import '../../data/datasources/remote/posts_remote_ds.dart' show PostsRemoteDataSource, FeedScope;
import '../../domain/entities/conversation.dart';
import '../../domain/entities/game_listing.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/shared_item.dart';
import 'auth_provider.dart';
import 'item_visibility_provider.dart';

// ── Remote DS singletons ────────────────────────────────────────────

final postsRemoteDsProvider = Provider<PostsRemoteDataSource>((_) => PostsRemoteDataSource());
final gameListingsRemoteDsProvider =
    Provider<GameListingsRemoteDataSource>((_) => GameListingsRemoteDataSource());
final messagesRemoteDsProvider =
    Provider<MessagesRemoteDataSource>((_) => MessagesRemoteDataSource());

// ── Posts / feed ────────────────────────────────────────────────────

/// Feed sekmesi: 'all' (tüm kullanıcılar) | 'following' (takip edilenler).
final feedScopeProvider = StateProvider<FeedScope>((_) => FeedScope.all);

/// Auth user için feed. Aktif scope'a göre tüm kullanıcılar veya
/// yalnızca takip edilenler döner.
final feedProvider = FutureProvider<List<Post>>((ref) async {
  if (!SupabaseConfig.isConfigured) return const [];
  final auth = ref.watch(authProvider);
  if (auth == null) return const [];
  final scope = ref.watch(feedScopeProvider);
  return ref.read(postsRemoteDsProvider).fetchFeed(scope: scope);
});

/// Bir post'u beğen / beğeniyi geri al. Optimistic update + feed invalidate.
class PostLikeNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  PostLikeNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> toggle(String postId) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(postsRemoteDsProvider).toggleLike(postId);
      _ref.invalidate(feedProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final postLikeProvider =
    StateNotifierProvider<PostLikeNotifier, AsyncValue<void>>(
  (ref) => PostLikeNotifier(ref),
);

/// Belirli kullanıcının postları (profile screen).
final userPostsProvider =
    FutureProvider.family<List<Post>, String>((ref, userId) async {
  if (!SupabaseConfig.isConfigured) return const [];
  return ref.read(postsRemoteDsProvider).fetchByAuthor(userId);
});

class PostComposerNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  PostComposerNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<bool> submit({String? body, Uint8List? imageBytes, String contentType = 'image/jpeg'}) async {
    if ((body == null || body.trim().isEmpty) && imageBytes == null) return false;
    if (body != null) {
      await ProfanityFilter.ensureLoaded();
      if (ProfanityFilter.contains(body)) {
        state = AsyncValue.error(
          const ProfanityRejectedException(),
          StackTrace.current,
        );
        return false;
      }
    }
    state = const AsyncValue.loading();
    try {
      await _ref.read(postsRemoteDsProvider).create(
            body: body?.trim(),
            imageBytes: imageBytes,
            contentType: contentType,
          );
      _ref.invalidate(feedProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final postComposerProvider =
    StateNotifierProvider<PostComposerNotifier, AsyncValue<void>>(
  (ref) => PostComposerNotifier(ref),
);

// ── Game listings ───────────────────────────────────────────────────

final openGameListingsProvider = FutureProvider<List<GameListing>>((ref) async {
  if (!SupabaseConfig.isConfigured) return const [];
  final auth = ref.watch(authProvider);
  if (auth == null) return const [];
  return ref.read(gameListingsRemoteDsProvider).fetchOpen();
});

class GameListingComposerNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  GameListingComposerNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<bool> create({
    required String title,
    String? description,
    String? system,
    int? seatsTotal,
    String? schedule,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(gameListingsRemoteDsProvider).create(
            title: title,
            description: description,
            system: system,
            seatsTotal: seatsTotal,
            schedule: schedule,
          );
      _ref.invalidate(openGameListingsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final gameListingComposerProvider =
    StateNotifierProvider<GameListingComposerNotifier, AsyncValue<void>>(
  (ref) => GameListingComposerNotifier(ref),
);

// ── Conversations / messages ────────────────────────────────────────

final myConversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  if (!SupabaseConfig.isConfigured) return const [];
  final auth = ref.watch(authProvider);
  if (auth == null) return const [];
  return ref.read(messagesRemoteDsProvider).fetchMyConversations();
});

/// Realtime mesaj akışı — chat ekranı bunu watch eder.
final messagesStreamProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, conversationId) {
  if (!SupabaseConfig.isConfigured) return const Stream.empty();
  return ref.read(messagesRemoteDsProvider).streamMessages(conversationId);
});

// ── Marketplace (public shared_items) ───────────────────────────────

class MarketplaceEntry {
  final SharedItem item;
  final String? ownerUsername;
  const MarketplaceEntry({required this.item, this.ownerUsername});
}

/// Marketplace filtresi: 'all' | 'world' | 'template' | 'package'.
final marketplaceFilterProvider = StateProvider<String>((_) => 'all');

final marketplaceProvider = FutureProvider<List<MarketplaceEntry>>((ref) async {
  if (!SupabaseConfig.isConfigured) return const [];
  final auth = ref.watch(authProvider);
  if (auth == null) return const [];
  final filter = ref.watch(marketplaceFilterProvider);
  final rows = await ref.read(sharedItemsRemoteDsProvider).listAllPublic(
        itemType: filter == 'all' ? null : filter,
      );
  return rows
      .map((r) => MarketplaceEntry(item: r.item, ownerUsername: r.ownerUsername))
      .toList();
});
