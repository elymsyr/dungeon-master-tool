import '../entities/mind_map.dart';

/// Mind map node/edge persistence interface.
abstract class MindMapRepository {
  /// Belirli bir mind map'teki tüm node'ları getir.
  Future<List<MindMapNode>> getNodes(String campaignId, String mapId);

  /// Node'ları reactive stream olarak izle.
  Stream<List<MindMapNode>> watchNodes(String campaignId, String mapId);

  /// Belirli bir mind map'teki tüm edge'leri getir.
  Future<List<MindMapEdge>> getEdges(String campaignId, String mapId);

  /// Edge'leri reactive stream olarak izle.
  Stream<List<MindMapEdge>> watchEdges(String campaignId, String mapId);

  /// Yeni node oluştur.
  Future<void> createNode(MindMapNode node, String campaignId, String mapId);

  /// Node güncelle.
  Future<void> updateNode(MindMapNode node);

  /// Node sil (cascade: bağlı edge'ler de silinir).
  Future<void> deleteNode(String id);

  /// Yeni edge oluştur.
  Future<void> createEdge(
      MindMapEdge edge, String campaignId, String mapId);

  /// Edge sil.
  Future<void> deleteEdge(String id);
}
