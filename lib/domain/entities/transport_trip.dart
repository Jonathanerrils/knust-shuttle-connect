import 'transport_route.dart';

class TransportTrip {
  final String id;
  final String routeId;
  final String vehicleId;
  final String operatorId;
  final RouteDirection direction;
  final DateTime serviceDate;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const TransportTrip({
    required this.id,
    required this.routeId,
    required this.vehicleId,
    required this.operatorId,
    required this.direction,
    required this.serviceDate,
    this.startedAt,
    this.endedAt,
  });
}
