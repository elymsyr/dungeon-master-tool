import 'package:flutter/foundation.dart';

/// Immutable snapshot row from `marketplace_listings`. Once published, only
/// `downloadCount` may mutate (enforced by the DB trigger). Each publish is
/// an independent row — there is no lineage or supersede relationship.
@immutable
class MarketplaceListing {
  const MarketplaceListing({
    required this.id,
    required this.ownerId,
    required this.itemType,
    required this.title,
    this.description,
    this.language,
    this.tags = const <String>[],
    this.changelog,
    required this.contentHash,
    required this.payloadPath,
    this.sizeBytes = 0,
    this.downloadCount = 0,
    required this.createdAt,
    this.ownerUsername,
  });

  final String id;
  final String ownerId;

  /// 'world' | 'template' | 'package'
  final String itemType;

  final String title;
  final String? description;
  final String? language;
  final List<String> tags;
  final String? changelog;

  final String contentHash;
  final String payloadPath;
  final int sizeBytes;
  final int downloadCount;
  final DateTime createdAt;

  /// Joined from `profiles.username` for marketplace browse / preview UI.
  /// Null when fetched without the join.
  final String? ownerUsername;

  MarketplaceListing copyWith({
    int? downloadCount,
    String? ownerUsername,
  }) {
    return MarketplaceListing(
      id: id,
      ownerId: ownerId,
      itemType: itemType,
      title: title,
      description: description,
      language: language,
      tags: tags,
      changelog: changelog,
      contentHash: contentHash,
      payloadPath: payloadPath,
      sizeBytes: sizeBytes,
      downloadCount: downloadCount ?? this.downloadCount,
      createdAt: createdAt,
      ownerUsername: ownerUsername ?? this.ownerUsername,
    );
  }
}
