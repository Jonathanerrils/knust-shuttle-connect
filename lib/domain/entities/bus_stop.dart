class BusStop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double geofenceRadiusMeters;
  final int waitingCount;
  final Map<String, int> destinationDemand;
  final bool active;
  final String? enRouteBy;
  final DateTime? enRouteAt;
  final DateTime? arrivedAt;

  const BusStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.geofenceRadiusMeters,
    this.waitingCount = 0,
    this.destinationDemand = const <String, int>{},
    this.active = true,
    this.enRouteBy,
    this.enRouteAt,
    this.arrivedAt,
  });

  bool get hasShuttleEnRoute => enRouteBy != null && arrivedAt == null;

  int demandForDestination(String? destinationStopId) {
    if (destinationStopId == null) return waitingCount;
    return destinationDemand[destinationStopId] ?? 0;
  }
}
