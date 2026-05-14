import 'package:freezed_annotation/freezed_annotation.dart';

part 'entity.freezed.dart';
part 'entity.g.dart';

/// Schema-driven entity. Tüm tip-spesifik veriler [fields] map'inde saklanır.
@freezed
abstract class Entity with _$Entity {
  const factory Entity({
    required String id,
    @Default('New Record') String name,
    required String categorySlug,
    @Default('') String source,
    @Default('') String description,
    @Default([]) List<String> images,
    @Default('') String imagePath,
    @Default([]) List<String> tags,
    @Default('') String dmNotes,
    @Default([]) List<String> pdfs,
    String? locationId,
    @Default({}) Map<String, dynamic> fields,
    String? packageId,
    String? packageEntityId,
    @Default(false) bool linked,
  }) = _Entity;

  factory Entity.fromJson(Map<String, dynamic> json) =>
      _$EntityFromJson(json);
}
