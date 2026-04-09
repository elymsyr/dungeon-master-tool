import '../entities/map_data.dart';

/// Map pin/timeline persistence interface.
abstract class MapRepository {
  /// Kampanyadaki tüm pin'leri getir.
  Future<List<MapPin>> getPins(String campaignId);

  /// Pin'leri reactive stream olarak izle.
  Stream<List<MapPin>> watchPins(String campaignId);

  /// Yeni pin oluştur.
  Future<void> createPin(MapPin pin, String campaignId);

  /// Pin güncelle.
  Future<void> updatePin(MapPin pin);

  /// Pin sil.
  Future<void> deletePin(String id);
}
