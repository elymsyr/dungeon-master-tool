import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/game_listing.dart';

class GameListingsRemoteDataSource {
  static const _table = 'game_listings';

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    return user.id;
  }

  /// Açık ilanları en yeni başta listele.
  Future<List<GameListing>> fetchOpen({int limit = 50}) async {
    final rows = await _client
        .from(_table)
        .select('*, profiles!game_listings_owner_id_fkey(username)')
        .eq('is_open', true)
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

  Future<GameListing> create({
    required String title,
    String? description,
    String? system,
    int? seatsTotal,
    String? schedule,
  }) async {
    final inserted = await _client.from(_table).insert({
      'owner_id': _userId,
      'title': title,
      'description': description,
      'system': system,
      'seats_total': seatsTotal,
      'schedule': schedule,
    }).select('*, profiles!game_listings_owner_id_fkey(username)').single();
    return _rowToListing(inserted);
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

  GameListing _rowToListing(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
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
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
