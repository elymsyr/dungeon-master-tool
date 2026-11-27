import 'package:supabase_flutter/supabase_flutter.dart';

/// One "Promoted" button in the support dialog (migration 112).
class PromotedLink {
  final String id;
  final String label;
  final String url;
  final String? imageUrl;
  final String? imagePath;
  final DateTime? createdAt;

  const PromotedLink({
    required this.id,
    required this.label,
    required this.url,
    this.imageUrl,
    this.imagePath,
    this.createdAt,
  });

  factory PromotedLink.fromRow(Map<String, dynamic> row) => PromotedLink(
        id: row['id'].toString(),
        label: (row['label'] ?? '').toString(),
        url: (row['url'] ?? '').toString(),
        imageUrl: row['image_url']?.toString(),
        imagePath: row['image_path']?.toString(),
        createdAt:
            DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal(),
      );
}

/// `promoted_links` table: anyone reads, only admins insert / delete (RLS).
class PromotedLinksRemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<PromotedLink>> list() async {
    final rows = await _client
        .from('promoted_links')
        .select()
        .order('created_at');
    return rows.map(PromotedLink.fromRow).toList();
  }

  Future<void> create({
    required String label,
    required String url,
    String? imageUrl,
    String? imagePath,
  }) =>
      _client.from('promoted_links').insert({
        'label': label,
        'url': url,
        'image_url': imageUrl,
        'image_path': imagePath,
      });

  Future<void> delete(String id) =>
      _client.from('promoted_links').delete().eq('id', id);
}
