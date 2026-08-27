import '../entities/bus_stop.dart';

abstract class StopRepository {
  Stream<List<BusStop>> watchStops();
  Future<List<BusStop>> getCachedStops();
  Future<void> cacheStops(List<BusStop> stops);
  Future<DateTime?> lastCacheTime();
  Future<void> markEnRoute(String stopId, String driverUid);
  Future<void> markArrived(String stopId, String driverUid);
  Future<void> clearEnRoute(String stopId);
  Future<void> upsertStop(BusStop stop);
  Future<void> deactivateStop(String stopId);
}
