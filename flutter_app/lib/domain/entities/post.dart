import 'package:freezed_annotation/freezed_annotation.dart';

part 'post.freezed.dart';
part 'post.g.dart';

@freezed
abstract class Post with _$Post {
  const factory Post({
    required String id,
    required String authorId,
    String? authorUsername,
    String? authorAvatarUrl,
    String? body,
    String? imageUrl,
    @Default(0) int sizeBytes,
    required DateTime createdAt,
    @Default(0) int likeCount,
    @Default(false) bool likedByMe,
  }) = _Post;

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);
}
