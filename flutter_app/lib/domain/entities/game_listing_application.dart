import 'package:freezed_annotation/freezed_annotation.dart';

part 'game_listing_application.freezed.dart';
part 'game_listing_application.g.dart';

/// Bir [GameListing]'e yapılan başvuru. Listing sahibi başvuruları görür,
/// başvuran kullanıcıya özel mesaj atabilir.
@freezed
abstract class GameListingApplication with _$GameListingApplication {
  const factory GameListingApplication({
    required String id,
    required String listingId,
    required String applicantId,
    String? applicantUsername,
    String? applicantDisplayName,
    String? applicantAvatarUrl,
    required String message,
    required DateTime createdAt,
  }) = _GameListingApplication;

  factory GameListingApplication.fromJson(Map<String, dynamic> json) =>
      _$GameListingApplicationFromJson(json);
}
