import 'package:flutter_test/flutter_test.dart';
import 'package:knust_shuttle_connect/domain/entities/bus_stop.dart';
import 'package:knust_shuttle_connect/domain/entities/check_in.dart';
import 'package:knust_shuttle_connect/domain/repositories/check_in_repository.dart';
import 'package:knust_shuttle_connect/domain/usecases/check_in_at_stop.dart';

class _FakeCheckInRepository implements CheckInRepository {
  BusStop? lastCheckedInStop;
  BusStop? lastDestination;
  String? lastUid;
  bool cancelled = false;

  @override
  Future<void> checkIn({
    required String uid,
    required BusStop stop,
    required BusStop destination,
  }) async {
    lastUid = uid;
    lastCheckedInStop = stop;
    lastDestination = destination;
  }

  @override
  Future<void> cancel(String uid) async => cancelled = true;

  @override
  Stream<CheckIn?> watchMyCheckIn(String uid) => const Stream.empty();
}

void main() {
  const stop = BusStop(
    id: 'commercial-area',
    name: 'Commercial Area',
    latitude: 6.6828,
    longitude: -1.5760,
    geofenceRadiusMeters: 75,
  );
  const destination = BusStop(
    id: 'brunei',
    name: 'Brunei',
    latitude: 6.6797,
    longitude: -1.5722,
    geofenceRadiusMeters: 75,
  );

  late _FakeCheckInRepository repo;
  late CheckInAtStop useCase;

  setUp(() {
    repo = _FakeCheckInRepository();
    useCase = CheckInAtStop(repo);
  });

  test('succeeds inside the geofence with a different destination', () async {
    final result = await useCase(
      uid: 'student1',
      stop: stop,
      destination: destination,
      latitude: stop.latitude + 0.0001,
      longitude: stop.longitude,
    );
    expect(result.isSuccess, isTrue);
    expect(repo.lastCheckedInStop?.id, 'commercial-area');
    expect(repo.lastDestination?.id, 'brunei');
    expect(repo.lastUid, 'student1');
  });

  test('rejects selecting the boarding stop as the destination', () async {
    final result = await useCase(
      uid: 'student1',
      stop: stop,
      destination: stop,
      latitude: stop.latitude,
      longitude: stop.longitude,
    );
    expect(result.isFailure, isTrue);
    expect(result.error, contains('destination'));
    expect(repo.lastCheckedInStop, isNull);
  });

  test('rejects check-in outside the geofence', () async {
    final result = await useCase(
      uid: 'student1',
      stop: stop,
      destination: destination,
      latitude: stop.latitude + 0.01,
      longitude: stop.longitude,
    );
    expect(result.isFailure, isTrue);
    expect(result.error, contains('must be at'));
    expect(repo.lastCheckedInStop, isNull);
  });

  test('rejects rapid repeated check-ins', () async {
    final result = await useCase(
      uid: 'student1',
      stop: stop,
      destination: destination,
      latitude: stop.latitude,
      longitude: stop.longitude,
      lastActionAt: DateTime.now().subtract(const Duration(seconds: 10)),
    );
    expect(result.isFailure, isTrue);
    expect(result.error, contains('wait'));
    expect(repo.lastCheckedInStop, isNull);
  });

  test('allows a new check-in after the cooldown has passed', () async {
    final result = await useCase(
      uid: 'student1',
      stop: stop,
      destination: destination,
      latitude: stop.latitude,
      longitude: stop.longitude,
      lastActionAt: DateTime.now().subtract(const Duration(seconds: 61)),
    );
    expect(result.isSuccess, isTrue);
  });

  test('check-in entity reports expiry correctly', () {
    final expired = CheckIn(
      studentUid: 'student1',
      stopId: stop.id,
      stopName: stop.name,
      destinationStopId: destination.id,
      destinationStopName: destination.name,
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );
    final fresh = CheckIn(
      studentUid: 'student1',
      stopId: stop.id,
      stopName: stop.name,
      destinationStopId: destination.id,
      destinationStopName: destination.name,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 25)),
    );
    expect(expired.isExpired, isTrue);
    expect(fresh.isExpired, isFalse);
  });
}
