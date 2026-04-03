import 'package:freezed_annotation/freezed_annotation.dart';

part 'mind_map.freezed.dart';
part 'mind_map.g.dart';

/// Mind map node — Sprint 4'te detaylandırılacak.
@freezed
abstract class MindMapNode with _$MindMapNode {
  const factory MindMapNode({
    required String id,
    @Default('') String label,
    @Default('note') String nodeType, // note, entity, image, workspace
    @Default(0) double x,
    @Default(0) double y,
    @Default(200) double width,
    @Default(100) double height,
    String? entityId,
    String? imageUrl,
    @Default('') String content,
    @Default({}) Map<String, dynamic> style,
  }) = _MindMapNode;

  factory MindMapNode.fromJson(Map<String, dynamic> json) =>
      _$MindMapNodeFromJson(json);
}

/// Mind map edge — iki node arası bağlantı.
@freezed
abstract class MindMapEdge with _$MindMapEdge {
  const factory MindMapEdge({
    required String id,
    required String sourceId,
    required String targetId,
    @Default('') String label,
    @Default({}) Map<String, dynamic> style,
  }) = _MindMapEdge;

  factory MindMapEdge.fromJson(Map<String, dynamic> json) =>
      _$MindMapEdgeFromJson(json);
}
