import '../entities/bus_stop.dart';
import '../entities/check_in.dart';

abstract class CheckInRepository {
  Stream<CheckIn?> watchMyCheckIn(String uid);

  Future<void> checkIn({
    required String uid,
    required BusStop stop,
    required BusStop destination,
  });

  Future<void> complete({
    required String uid,
    required WaitingEndReason reason,
  });

  Future<void> reportMissedBoarding(String uid);
}
