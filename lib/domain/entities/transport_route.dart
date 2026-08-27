enum RouteDirection { inbound, outbound, clockwise, counterClockwise, loop }

class RouteStop {
  final String stopId;
  final int sequence;
  final double? distanceFromPreviousMeters;

  const RouteStop({
    required this.stopId,
    required this.sequence,
    this.distanceFromPreviousMeters,
  });
}

class TransportRoute {
  final String id;
  final String networkId;
  final String operatorId;
  final String name;
  final RouteDirection direction;
  final List<RouteStop> stops;
  final bool active;

  const TransportRoute({
    required this.id,
    required this.networkId,
    required this.operatorId,
    required this.name,
    required this.direction,
    required this.stops,
    this.active = true,
  });

  bool containsStop(String stopId) => stops.any((stop) => stop.stopId == stopId);

  int? sequenceOf(String stopId) {
    for (final stop in stops) {
      if (stop.stopId == stopId) return stop.sequence;
    }
    return null;
  }

  bool canServe({required String boardingStopId, required String destinationStopId}) {
    final from = sequenceOf(boardingStopId);
    final to = sequenceOf(destinationStopId);
    if (from == null || to == null) return false;
    if (direction == RouteDirection.loop ||
        direction == RouteDirection.clockwise ||
        direction == RouteDirection.counterClockwise) {
      return from != to;
    }
    return to > from;
  }
}
