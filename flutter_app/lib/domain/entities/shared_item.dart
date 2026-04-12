import 'package:freezed_annotation/freezed_annotation.dart';

part 'shared_item.freezed.dart';
part 'shared_item.g.dart';

/// World / template / package için public/private görünürlük kaydı.
/// Yerel Drift modellerine isPublic eklemek yerine bu tek "source of truth"
/// kullanılır.
@freezed
abstract class SharedItem with _$SharedItem {
  const factory SharedItem({
    required String id,
    required String ownerId,
    /// 'world' | 'template' | 'package'
    required String itemType,
    required String localId,
    required String title,
    String? description,
    @Default(false) bool isPublic,
    String? payloadPath,
    @Default(0) int sizeBytes,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _SharedItem;

  factory SharedItem.fromJson(Map<String, dynamic> json) =>
      _$SharedItemFromJson(json);
}
