import '../entities/bus_stop.dart';
import '../entities/check_in.dart';

abstract class CheckInRepository {
  Stream<CheckIn?> watchMyCheckIn(String uid);
  Future<void> checkIn({required String uid, required BusStop stop});
  Future<void> cancel(String uid);
}
