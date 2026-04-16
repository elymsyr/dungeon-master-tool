import 'package:freezed_annotation/freezed_annotation.dart';

part 'conversation.freezed.dart';
part 'conversation.g.dart';

@freezed
abstract class Conversation with _$Conversation {
  const factory Conversation({
    required String id,
    @Default(false) bool isGroup,
    String? title,
    String? createdBy,
    String? lastMessageBody,
    DateTime? lastMessageAt,
    @Default(<String>[]) List<String> memberIds,
    @Default(<String>[]) List<String> memberUsernames,
    required DateTime createdAt,
  }) = _Conversation;

  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(json);
}

@freezed
abstract class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    required String conversationId,
    String? authorId,
    String? authorUsername,
    required String body,
    required DateTime createdAt,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);
}
