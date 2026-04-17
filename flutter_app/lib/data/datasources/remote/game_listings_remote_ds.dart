import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/parse_utils.dart';
import '../../../domain/entities/game_listing.dart';
import '../../../domain/entities/game_listing_application.dart';

class GameListingsRemoteDataSource {
  static const _table = 'game_listings';
  static const _applicationsTable = 'game_listing_applications';

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    return user.id;
  }

  /// Açık ilanları en yeni başta listele. Opsiyonel filtreler:
  /// [gameLanguage] = 'en' | 'tr' | ..., [system] = serbest metin,
  /// [tag] = listing.tags[] içinde geçecek tek tag.
  Future<List<GameListing>> fetchOpen({
    int limit = 50,
    String? gameLanguage,
    String? system,
    String? tag,
  }) async {
    var query = _client
        .from(_table)
        .select('*, profiles!game_listings_owner_id_fkey(username)')
        .eq('is_open', true);
    if (gameLanguage != null && gameLanguage.isNotEmpty) {
      query = query.eq('game_language', gameLanguage);
    }
    if (system != null && system.isNotEmpty) {
      query = query.ilike('system', '%$system%');
    }
    if (tag != null && tag.isNotEmpty) {
      query = query.contains('tags', [tag]);
    }
    final rows = await query
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(_rowToListing).toList();
  }

  Future<List<GameListing>> fetchByOwner(String ownerId) async {
    final rows = await _client
        .from(_table)
        .select('*, profiles!game_listings_owner_id_fkey(username)')
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);
    return rows.map(_rowToListing).toList();
  }

  /// Auth user'ın kendi ilanları. [fetchByOwner] ile aynı ama kullanıcıyı
  /// otomatik alır ve hangi ilana kaç başvuru olduğu bilgisi eklenir.
  Future<List<GameListing>> fetchMine() async {
    final uid = _userId;
    final rows = await _client
        .from(_table)
        .select('*, profiles!game_listings_owner_id_fkey(username)')
        .eq('owner_id', uid)
        .order('created_at', ascending: false);
    final listings = rows.map(_rowToListing).toList();
    if (listings.isEmpty) return listings;

    // Her listing için başvuru sayısı.
    final ids = listings.map((l) => l.id).toList();
    final appRows = await _client
        .from(_applicationsTable)
        .select('listing_id')
        .inFilter('listing_id', ids);
    final counts = <String, int>{};
    for (final r in appRows) {
      final id = r['listing_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return listings
        .map((l) => l.copyWith(applicationCount: counts[l.id] ?? 0))
        .toList();
  }

  /// Fetch a single game listing by ID (for post card tap preview).
  Future<GameListing?> fetchById(String id) async {
    final row = await _client
        .from(_table)
        .select('*, profiles!game_listings_owner_id_fkey(username)')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return _rowToListing(row);
  }

  Future<GameListing> create({
    required String title,
    String? description,
    String? system,
    int? seatsTotal,
    String? schedule,
    String? gameLanguage,
    List<String> tags = const [],
  }) async {
    final inserted = await _client.from(_table).insert({
      'owner_id': _userId,
      'title': title,
      'description': description,
      'system': system,
      'seats_total': seatsTotal,
      'schedule': schedule,
      'game_language': gameLanguage,
      'tags': tags,
    }).select('*, profiles!game_listings_owner_id_fkey(username)').single();
    return _rowToListing(inserted);
  }

  /// Owner-side metadata update for an existing listing. `is_open` ve
  /// `seats_filled` bu endpoint'te değişmez — onlar `close` / kontenjan
  /// akışıyla yönetilir.
  Future<GameListing> update({
    required String listingId,
    required String title,
    String? description,
    String? system,
    int? seatsTotal,
    String? schedule,
    String? gameLanguage,
    List<String> tags = const [],
  }) async {
    final updated = await _client
        .from(_table)
        .update({
          'title': title,
          'description': description,
          'system': system,
          'seats_total': seatsTotal,
          'schedule': schedule,
          'game_language': gameLanguage,
          'tags': tags,
        })
        .eq('id', listingId)
        .eq('owner_id', _userId)
        .select('*, profiles!game_listings_owner_id_fkey(username)')
        .single();
    return _rowToListing(updated);
  }

  Future<void> close(String listingId) async {
    await _client
        .from(_table)
        .update({'is_open': false})
        .eq('id', listingId)
        .eq('owner_id', _userId);
  }

  Future<void> delete(String listingId) async {
    await _client.from(_table).delete().eq('id', listingId).eq('owner_id', _userId);
  }

  // ── Applications ──────────────────────────────────────────────────────

  /// Auth user bir listing'e başvuru yapar. Mesaj zorunlu (1-1000 char).
  Future<GameListingApplication> apply({
    required String listingId,
    required String message,
  }) async {
    final uid = _userId;
    final inserted = await _client.from(_applicationsTable).insert({
      'listing_id': listingId,
      'applicant_id': uid,
      'message': message,
    }).select(
      '*, profiles!game_listing_applications_applicant_id_fkey(username, display_name, avatar_url)',
    ).single();
    return _rowToApplication(inserted);
  }

  /// Auth user bir listing'e başvurusunu geri çeker.
  Future<void> withdrawApplication(String listingId) async {
    final uid = _userId;
    await _client
        .from(_applicationsTable)
        .delete()
        .eq('listing_id', listingId)
        .eq('applicant_id', uid);
  }

  /// Auth user bir listing'e başvurdu mu?
  Future<bool> hasApplied(String listingId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final rows = await _client
        .from(_applicationsTable)
        .select('id')
        .eq('listing_id', listingId)
        .eq('applicant_id', uid)
        .limit(1);
    return rows.isNotEmpty;
  }

  /// Bir listing'e gelen başvurular (yalnızca listing owner görebilir; RLS
  /// tarafında bu zaten uygulanır).
  Future<List<GameListingApplication>> fetchApplicationsFor(String listingId) async {
    final rows = await _client
        .from(_applicationsTable)
        .select(
          '*, profiles!game_listing_applications_applicant_id_fkey(username, display_name, avatar_url)',
        )
        .eq('listing_id', listingId)
        .order('created_at', ascending: false);
    return rows.map(_rowToApplication).toList();
  }

  GameListing _rowToListing(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    final tagsRaw = row['tags'];
    return GameListing(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      ownerUsername: profile?['username'] as String?,
      title: row['title'] as String,
      description: row['description'] as String?,
      system: row['system'] as String?,
      seatsTotal: row['seats_total'] as int?,
      seatsFilled: (row['seats_filled'] as int?) ?? 0,
      schedule: row['schedule'] as String?,
      isOpen: (row['is_open'] as bool?) ?? true,
      createdAt: parseIsoOrNow(row['created_at']),
      gameLanguage: row['game_language'] as String?,
      tags: tagsRaw is List ? tagsRaw.whereType<String>().toList() : const [],
    );
  }

  GameListingApplication _rowToApplication(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    return GameListingApplication(
      id: row['id'] as String,
      listingId: row['listing_id'] as String,
      applicantId: row['applicant_id'] as String,
      applicantUsername: profile?['username'] as String?,
      applicantDisplayName: profile?['display_name'] as String?,
      applicantAvatarUrl: profile?['avatar_url'] as String?,
      message: row['message'] as String,
      createdAt: parseIsoOrNow(row['created_at']),
    );
  }
}
