import '../entities/shuttle.dart';

abstract class ShuttleRepository {
  Stream<List<Shuttle>> watchOnDutyShuttles();
}
