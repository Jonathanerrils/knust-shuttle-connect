import 'package:flutter_test/flutter_test.dart';
import 'package:knust_shuttle_connect/domain/entities/shuttle.dart';

void main() {
  test('shuttle is compatible only with its assigned destination', () {
    final shuttle = Shuttle(
      id: 'driver-1',
      latitude: 6.67,
      longitude: -1.57,
      updatedAt: DateTime.now(),
      servingDestinationStopId: 'brunei',
      routeId: 'route-1',
      tripId: 'trip-1',
      routeDirection: 'outbound',
      currentStopSequence: 2,
    );

    expect(shuttle.hasServiceAssignment, isTrue);
    expect(shuttle.canServeDestination('brunei'), isTrue);
    expect(shuttle.canServeDestination('ksb'), isFalse);
  });

  test('unassigned shuttle is not falsely presented as compatible', () {
    final shuttle = Shuttle(
      id: 'driver-2',
      latitude: 6.67,
      longitude: -1.57,
      updatedAt: DateTime.now(),
    );

    expect(shuttle.hasServiceAssignment, isFalse);
    expect(shuttle.canServeDestination('brunei'), isFalse);
  });
}
