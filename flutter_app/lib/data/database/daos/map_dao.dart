import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/map_pins_table.dart';
import '../tables/timeline_pins_table.dart';

part 'map_dao.g.dart';

@DriftAccessor(tables: [MapPins, TimelinePins])
class MapDao extends DatabaseAccessor<AppDatabase> with _$MapDaoMixin {
  MapDao(super.db);

  // --- Map Pins ---

  Future<List<MapPin>> getPinsForCampaign(String campaignId) =>
      (select(mapPins)..where((t) => t.campaignId.equals(campaignId))).get();

  Stream<List<MapPin>> watchPinsForCampaign(String campaignId) =>
      (select(mapPins)..where((t) => t.campaignId.equals(campaignId))).watch();

  Future<void> createPin(MapPinsCompanion pin) => into(mapPins).insert(pin);

  Future<bool> updatePin(MapPinsCompanion pin) =>
      (update(mapPins)..where((t) => t.id.equals(pin.id.value)))
          .write(pin)
          .then((rows) => rows > 0);

  Future<int> deletePin(String id) =>
      (delete(mapPins)..where((t) => t.id.equals(id))).go();

  Future<void> insertAllPins(List<MapPinsCompanion> pins) async {
    await batch((b) => b.insertAll(mapPins, pins));
  }

  // --- Timeline Pins ---

  Future<List<TimelinePin>> getTimelinePinsForCampaign(String campaignId) =>
      (select(timelinePins)..where((t) => t.campaignId.equals(campaignId)))
          .get();

  Stream<List<TimelinePin>> watchTimelinePinsForCampaign(String campaignId) =>
      (select(timelinePins)..where((t) => t.campaignId.equals(campaignId)))
          .watch();

  Future<void> createTimelinePin(TimelinePinsCompanion pin) =>
      into(timelinePins).insert(pin);

  Future<bool> updateTimelinePin(TimelinePinsCompanion pin) =>
      (update(timelinePins)..where((t) => t.id.equals(pin.id.value)))
          .write(pin)
          .then((rows) => rows > 0);

  Future<int> deleteTimelinePin(String id) =>
      (delete(timelinePins)..where((t) => t.id.equals(id))).go();

  Future<void> insertAllTimelinePins(List<TimelinePinsCompanion> pins) async {
    await batch((b) => b.insertAll(timelinePins, pins));
  }
}
