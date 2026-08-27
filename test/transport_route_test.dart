import 'package:flutter_test/flutter_test.dart';
import 'package:knust_shuttle_connect/domain/entities/transport_route.dart';

void main() {
  const route = TransportRoute(
    id: 'route-1',
    networkId: 'knust',
    operatorId: 'knust-transport',
    name: 'Example outbound',
    direction: RouteDirection.outbound,
    stops: [
      RouteStop(stopId: 'a', sequence: 0),
      RouteStop(stopId: 'b', sequence: 1),
      RouteStop(stopId: 'c', sequence: 2),
    ],
  );

  test('serves destinations later in the ordered route', () {
    expect(route.canServe(boardingStopId: 'a', destinationStopId: 'c'), isTrue);
    expect(route.canServe(boardingStopId: 'b', destinationStopId: 'c'), isTrue);
  });

  test('rejects reverse-direction and unknown journeys', () {
    expect(route.canServe(boardingStopId: 'c', destinationStopId: 'a'), isFalse);
    expect(route.canServe(boardingStopId: 'x', destinationStopId: 'c'), isFalse);
  });

  test('loop routes can serve any different stop on the loop', () {
    const loop = TransportRoute(
      id: 'loop',
      networkId: 'n',
      operatorId: 'o',
      name: 'Loop',
      direction: RouteDirection.loop,
      stops: [
        RouteStop(stopId: 'a', sequence: 0),
        RouteStop(stopId: 'b', sequence: 1),
        RouteStop(stopId: 'c', sequence: 2),
      ],
    );

    expect(loop.canServe(boardingStopId: 'c', destinationStopId: 'a'), isTrue);
    expect(loop.canServe(boardingStopId: 'a', destinationStopId: 'a'), isFalse);
  });
}
