import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/cached_provider.dart';
import '../../core/utils/profanity_filter.dart';
import '../../data/datasources/remote/game_listings_remote_ds.dart';
import '../../data/datasources/remote/messages_remote_ds.dart';
import '../../data/datasources/remote/posts_remote_ds.dart' show PostsRemoteDataSource, FeedScope;
import '../../data/datasources/remote/profiles_remote_ds.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/game_listing.dart';
import '../../domain/entities/game_listing_application.dart';
import '../../domain/entities/marketplace_listing.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/user_profile.dart';
import 'auth_provider.dart';
import 'follows_provider.dart';
import 'marketplace_listing_provider.dart';

/// Sunucu `enforce_post_rate_limit` trigger'ı `post_rate_limit_exceeded`
/// exception'ı fırlattığında client tarafı bu sınıfa maple eder ve UI'a
/// lokalize "slow down" mesajı gösterir. Pencere label ('1m' | '1h' | '24h')
/// trigger'ın HINT alanından alınır.
class PostRateLimitedException implements Exception {
  final String? window;
  const PostRateLimitedException({this.window});
  @override
  String toString() => 'post_rate_limit_exceeded (${window ?? 'unknown'})';
}

bool _looksLikeRateLimit(Object error) {
  final msg = error.toString().toLowerCase();
  return msg.contains('post_rate_limit_exceeded');
}

String? _rateLimitWindow(Object error) {
  final msg = error.toString();
  final match = RegExp(r'window=(1m|1h|24h)').firstMatch(msg);
  return match?.group(1);
}

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
  return cachedFetch(
    ref: ref,
    cacheKey: 'feed:${scope.name}',
    ttl: const Duration(minutes: 2),
    fetch: () => ref.read(postsRemoteDsProvider).fetchFeed(scope: scope),
  );
});

/// Bir post'un lokal override'ı (optimistic): beğeni sayısı + likedByMe.
/// UI, feed'ten gelen post'u bu override ile maskeleyebilir.
class PostLikeOverride {
  final bool likedByMe;
  final int likeCount;
  const PostLikeOverride({required this.likedByMe, required this.likeCount});
}

final postLikeOverrideProvider =
    StateProvider.family<PostLikeOverride?, String>((ref, postId) => null);

/// Bir post'u beğen / beğeniyi geri al. Optimistic: UI anında güncellenir,
/// DB arka planda çalışır. Hata olursa override geri alınır.
class PostLikeNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  PostLikeNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> toggle(String postId, {required Post currentPost}) async {
    final prevOverride = _ref.read(postLikeOverrideProvider(postId));
    final currentLiked = prevOverride?.likedByMe ?? currentPost.likedByMe;
    final currentCount = prevOverride?.likeCount ?? currentPost.likeCount;
    final nextLiked = !currentLiked;
    final nextCount = currentCount + (nextLiked ? 1 : -1);
    _ref.read(postLikeOverrideProvider(postId).notifier).state =
        PostLikeOverride(likedByMe: nextLiked, likeCount: nextCount < 0 ? 0 : nextCount);

    try {
      await _ref.read(postsRemoteDsProvider).toggleLike(postId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      _ref.read(postLikeOverrideProvider(postId).notifier).state = prevOverride;
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
  return cachedFetch(
    ref: ref,
    cacheKey: 'userPosts:$userId',
    ttl: const Duration(minutes: 2),
    fetch: () => ref.read(postsRemoteDsProvider).fetchByAuthor(userId),
  );
});

class PostComposerNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  PostComposerNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<bool> submit({String? body, Uint8List? imageBytes, String contentType = 'image/jpeg', String? marketplaceItemId, String? gameListingId}) async {
    if ((body == null || body.trim().isEmpty) && imageBytes == null && marketplaceItemId == null && gameListingId == null) return false;
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
            marketplaceItemId: marketplaceItemId,
            gameListingId: gameListingId,
          );
      invalidateCachePrefix('feed:');
      _ref.invalidate(feedProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      if (_looksLikeRateLimit(e)) {
        state = AsyncValue.error(
          PostRateLimitedException(window: _rateLimitWindow(e)),
          st,
        );
      } else {
        state = AsyncValue.error(e, st);
      }
      return false;
    }
  }
}

final postComposerProvider =
    StateNotifierProvider<PostComposerNotifier, AsyncValue<void>>(
  (ref) => PostComposerNotifier(ref),
);

// ── Game listings ───────────────────────────────────────────────────

/// Feed "Game Lists" sekmesi ve Game Listings tab'ı için filtre state'i.
/// null değerler "hepsi" anlamına gelir.
class GameListingFilters {
  final String? gameLanguage;
  final String? system;
  final String? tag;
  const GameListingFilters({this.gameLanguage, this.system, this.tag});

  GameListingFilters copyWith({
    Object? gameLanguage = _sentinel,
    Object? system = _sentinel,
    Object? tag = _sentinel,
  }) =>
      GameListingFilters(
        gameLanguage: gameLanguage == _sentinel ? this.gameLanguage : gameLanguage as String?,
        system: system == _sentinel ? this.system : system as String?,
        tag: tag == _sentinel ? this.tag : tag as String?,
      );

  static const _sentinel = Object();
}

final gameListingFiltersProvider =
    StateProvider<GameListingFilters>((_) => const GameListingFilters());

final openGameListingsProvider = FutureProvider<List<GameListing>>((ref) async {
  if (!SupabaseConfig.isConfigured) return const [];
  final auth = ref.watch(authProvider);
  if (auth == null) return const [];
  final filters = ref.watch(gameListingFiltersProvider);
  return cachedFetch(
    ref: ref,
    cacheKey: 'gameListings:${filters.gameLanguage}:${filters.system}:${filters.tag}',
    ttl: const Duration(minutes: 5),
    fetch: () => ref.read(gameListingsRemoteDsProvider).fetchOpen(
          gameLanguage: filters.gameLanguage,
          system: filters.system,
          tag: filters.tag,
        ),
  );
});

/// Herhangi bir kullanıcının (başkasının profili için) public listings'i.
/// Sadece public / open olanlar değil — hepsini getirir; Profile Listings
/// sekmesinde başka kullanıcıların geçmiş ilanları da görünebilir.
final userGameListingsProvider =
    FutureProvider.family<List<GameListing>, String>((ref, userId) async {
  if (!SupabaseConfig.isConfigured) return const [];
  return cachedFetch(
    ref: ref,
    cacheKey: 'userGameListings:$userId',
    ttl: const Duration(minutes: 5),
    fetch: () => ref.read(gameListingsRemoteDsProvider).fetchByOwner(userId),
  );
});

/// Auth user'ın kendi ilanları (başvuru sayılarıyla birlikte).
final myGameListingsProvider = FutureProvider<List<GameListing>>((ref) async {
  if (!SupabaseConfig.isConfigured) return const [];
  final auth = ref.watch(authProvider);
  if (auth == null) return const [];
  return cachedFetch(
    ref: ref,
    cacheKey: 'myGameListings',
    ttl: const Duration(minutes: 5),
    fetch: () => ref.read(gameListingsRemoteDsProvider).fetchMine(),
  );
});

/// Belirli bir listing'e gelen başvurular (listing owner'ı için).
final listingApplicationsProvider =
    FutureProvider.family<List<GameListingApplication>, String>(
  (ref, listingId) async {
    if (!SupabaseConfig.isConfigured) return const [];
    return ref.read(gameListingsRemoteDsProvider).fetchApplicationsFor(listingId);
  },
);

/// Auth user, verilen listing'e başvurdu mu? (feed'de "Başvuru yap" vs
/// "Başvuruldu" durumunu göstermek için.)
final hasAppliedProvider =
    FutureProvider.family<bool, String>((ref, listingId) async {
  if (!SupabaseConfig.isConfigured) return false;
  final auth = ref.watch(authProvider);
  if (auth == null) return false;
  return ref.read(gameListingsRemoteDsProvider).hasApplied(listingId);
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
    String? gameLanguage,
    List<String> tags = const [],
  }) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(gameListingsRemoteDsProvider).create(
            title: title,
            description: description,
            system: system,
            seatsTotal: seatsTotal,
            schedule: schedule,
            gameLanguage: gameLanguage,
            tags: tags,
          );
      invalidateCachePrefix('gameListings:');
      invalidateCache('myGameListings');
      _ref.invalidate(openGameListingsProvider);
      _ref.invalidate(myGameListingsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> update({
    required String listingId,
    required String title,
    String? description,
    String? system,
    int? seatsTotal,
    String? schedule,
    String? gameLanguage,
    List<String> tags = const [],
  }) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(gameListingsRemoteDsProvider).update(
            listingId: listingId,
            title: title,
            description: description,
            system: system,
            seatsTotal: seatsTotal,
            schedule: schedule,
            gameLanguage: gameLanguage,
            tags: tags,
          );
      invalidateCachePrefix('gameListings:');
      invalidateCache('myGameListings');
      invalidateCachePrefix('userGameListings:');
      _ref.invalidate(openGameListingsProvider);
      _ref.invalidate(myGameListingsProvider);
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

/// Başvuru yap / geri çek için optimistic notifier.
class ListingApplicationNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  ListingApplicationNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<bool> apply({required String listingId, required String message}) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(gameListingsRemoteDsProvider).apply(
            listingId: listingId,
            message: message,
          );
      invalidateCache('myGameListings');
      _ref.invalidate(hasAppliedProvider(listingId));
      _ref.invalidate(listingApplicationsProvider(listingId));
      _ref.invalidate(myGameListingsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> withdraw(String listingId) async {
    try {
      await _ref.read(gameListingsRemoteDsProvider).withdrawApplication(listingId);
      invalidateCache('myGameListings');
      _ref.invalidate(hasAppliedProvider(listingId));
      _ref.invalidate(listingApplicationsProvider(listingId));
      _ref.invalidate(myGameListingsProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final listingApplicationProvider =
    StateNotifierProvider<ListingApplicationNotifier, AsyncValue<void>>(
  (ref) => ListingApplicationNotifier(ref),
);

// ── Conversations / messages ────────────────────────────────────────

final myConversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  if (!SupabaseConfig.isConfigured) return const [];
  final auth = ref.watch(authProvider);
  if (auth == null) return const [];
  return cachedFetch(
    ref: ref,
    cacheKey: 'conversations',
    ttl: const Duration(minutes: 1),
    fetch: () => ref.read(messagesRemoteDsProvider).fetchMyConversations(),
  );
});

/// Total unread message count across all conversations — for badges.
final totalUnreadCountProvider = FutureProvider<int>((ref) async {
  if (!SupabaseConfig.isConfigured) return 0;
  final auth = ref.watch(authProvider);
  if (auth == null) return 0;
  return cachedFetch(
    ref: ref,
    cacheKey: 'totalUnread',
    ttl: const Duration(seconds: 30),
    fetch: () => ref.read(messagesRemoteDsProvider).fetchTotalUnreadCount(),
  );
});

/// Aggregated notification count across ALL sources. Hub badge watches this.
/// To add a new notification source:
///   1. Create a `FutureProvider<int>` that returns its unread count.
///   2. `ref.watch` it here and add the value to the sum.
///   3. Invalidate it from the appropriate realtime subscription.
final totalNotificationCountProvider = FutureProvider<int>((ref) async {
  final messages = await ref.watch(totalUnreadCountProvider.future);
  // Future sources plug in here:
  // final apps = await ref.watch(unreadApplicationsCountProvider.future);
  return messages;
});

/// Realtime mesaj akışı — chat ekranı bunu watch eder.
final messagesStreamProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, conversationId) {
  if (!SupabaseConfig.isConfigured) return const Stream.empty();
  return ref.read(messagesRemoteDsProvider).streamMessages(conversationId);
});

/// `messages` tablosuna realtime subscription kurar; her yeni insert
/// geldiğinde `myConversationsProvider` invalidate edilir, böylece Messages
/// tab'ındaki conversation listesi otomatik güncellenir. Supabase RLS
/// payload'u zaten kullanıcının üyesi olduğu konuşmalarla sınırlar.
final conversationListRealtimeProvider = Provider<void>((ref) {
  if (!SupabaseConfig.isConfigured) return;
  final auth = ref.watch(authProvider);
  if (auth == null) return;
  final client = Supabase.instance.client;

  /// Debounced invalidation: skip if the last fetch was < 10 seconds ago.
  void invalidateConversations({bool includeUnread = false}) {
    final age = cacheAge('conversations');
    if (age != null && age < const Duration(seconds: 10)) return;
    invalidateCache('conversations');
    ref.invalidate(myConversationsProvider);
    if (includeUnread) {
      invalidateCache('totalUnread');
      ref.invalidate(totalUnreadCountProvider);
    }
  }

  final channel = client.channel('public:messages:inbox:${auth.uid}')
    ..onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (_) => invalidateConversations(includeUnread: true),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'conversation_members',
      callback: (_) => invalidateConversations(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'conversation_members',
      callback: (_) => invalidateConversations(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'conversations',
      callback: (_) => invalidateConversations(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'conversations',
      callback: (_) => invalidateConversations(),
    )
    ..subscribe();
  ref.onDispose(() => client.removeChannel(channel));
});

// ── Marketplace (public marketplace_listings) ───────────────────────

class MarketplaceFilters {
  final String type; // 'all' | 'world' | 'template' | 'package' | 'character'
  final String? language;
  final String? tag;
  /// null = hepsi (built-in + user), true = yalnız built-in, false = yalnız user-generated.
  final bool? builtinOnly;
  const MarketplaceFilters({
    this.type = 'all',
    this.language,
    this.tag,
    this.builtinOnly,
  });

  MarketplaceFilters copyWith({
    String? type,
    Object? language = _sentinel,
    Object? tag = _sentinel,
    Object? builtinOnly = _sentinel,
  }) =>
      MarketplaceFilters(
        type: type ?? this.type,
        language: language == _sentinel ? this.language : language as String?,
        tag: tag == _sentinel ? this.tag : tag as String?,
        builtinOnly: builtinOnly == _sentinel
            ? this.builtinOnly
            : builtinOnly as bool?,
      );

  static const _sentinel = Object();
}

final marketplaceFiltersProvider =
    StateProvider<MarketplaceFilters>((_) => const MarketplaceFilters());

/// Eski filtre provider'ı bazı yerlerde `type` için hâlâ kullanılıyor
/// olabilir — tutarlılık için geri uyumlu shortcut.
final marketplaceFilterProvider = StateProvider<String>((ref) {
  return ref.watch(marketplaceFiltersProvider).type;
});

final marketplaceProvider = FutureProvider<List<MarketplaceListing>>((ref) async {
  if (!SupabaseConfig.isConfigured) return const [];
  final auth = ref.watch(authProvider);
  if (auth == null) return const [];
  final filters = ref.watch(marketplaceFiltersProvider);
  return cachedFetch(
    ref: ref,
    cacheKey:
        'marketplace:${filters.type}:${filters.language}:${filters.tag}:${filters.builtinOnly}',
    ttl: const Duration(minutes: 5),
    fetch: () => ref.read(marketplaceListingsRemoteDsProvider).listAllCurrent(
          itemType: filters.type == 'all' ? null : filters.type,
          language: filters.language,
          tag: filters.tag,
          builtinOnly: filters.builtinOnly,
        ),
  );
});

// ── Suggested users (marketplace right panel) ────────────────────────

final profilesRemoteDsProvider =
    Provider<ProfilesRemoteDataSource>((_) => ProfilesRemoteDataSource());

final suggestedUsersProvider = FutureProvider<List<UserProfile>>((ref) async {
  if (!SupabaseConfig.isConfigured) return const [];
  final auth = ref.watch(authProvider);
  if (auth == null) return const [];
  return cachedFetch(
    ref: ref,
    cacheKey: 'suggestedUsers',
    ttl: const Duration(minutes: 10),
    fetch: () => ref.read(profilesRemoteDsProvider).suggested(),
  );
});

/// Marketplace sağ panelinde "followed + suggested" birleşik görünümü.
/// Önce takip edilenler, sonra öneriler (takip edilenler hariç) döner.
// ── Discover people ──────────────────────────────────────────────────

final discoverSearchQueryProvider = StateProvider<String>((ref) => '');

final discoverPeopleProvider = FutureProvider<List<UserProfile>>((ref) async {
  if (!SupabaseConfig.isConfigured) return const [];
  final auth = ref.watch(authProvider);
  if (auth == null) return const [];
  final query = ref.watch(discoverSearchQueryProvider);
  return cachedFetch(
    ref: ref,
    cacheKey: 'discover:${query.trim()}',
    ttl: const Duration(minutes: 5),
    fetch: () {
      if (query.trim().isNotEmpty) {
        return ref.read(profilesRemoteDsProvider).search(query, limit: 30);
      }
      return ref.read(profilesRemoteDsProvider).suggested(limit: 30);
    },
  );
});

final marketplacePlayersProvider = FutureProvider<List<UserProfile>>((ref) async {
  if (!SupabaseConfig.isConfigured) return const [];
  final auth = ref.watch(authProvider);
  if (auth == null) return const [];
  final uid = auth.uid;
  return cachedFetch(
    ref: ref,
    cacheKey: 'marketplacePlayers',
    ttl: const Duration(minutes: 5),
    fetch: () async {
      final followedFuture = ref.read(followsRemoteDsProvider).followingOf(uid);
      final suggestedFuture = ref.read(profilesRemoteDsProvider).suggested(limit: 10);
      final followed = await followedFuture;
      final suggested = await suggestedFuture;
      final seen = <String>{for (final p in followed) p.userId};
      return [
        ...followed,
        ...suggested.where((p) => !seen.contains(p.userId)),
      ];
    },
  );
});
