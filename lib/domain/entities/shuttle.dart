import '../../core/utils/geo_utils.dart';
import '../services/eta_estimator.dart';

class Shuttle {
  final String id;
  final double latitude;
  final double longitude;
  final double? headingDegrees;
  final double? speedMetersPerSecond;
  final DateTime? updatedAt;
  final String? servingDestinationStopId;
  final String? routeId;
  final String? tripId;
  final String? routeDirection;
  final int? currentStopSequence;

  const Shuttle({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.headingDegrees,
    this.speedMetersPerSecond,
    this.updatedAt,
    this.servingDestinationStopId,
    this.routeId,
    this.tripId,
    this.routeDirection,
    this.currentStopSequence,
  });

  bool get isFresh =>
      updatedAt != null &&
      DateTime.now().difference(updatedAt!) < const Duration(minutes: 5);

  bool get hasServiceAssignment =>
      servingDestinationStopId != null || routeId != null || tripId != null;

  bool canServeDestination(String destinationStopId) =>
      servingDestinationStopId == destinationStopId;

  EtaEstimate etaEstimateTo(
    double lat,
    double lng, {
    DateTime? now,
  }) {
    final meters = GeoUtils.distanceMeters(latitude, longitude, lat, lng);
    return EtaEstimator.estimate(
      distanceMeters: meters,
      observedSpeedMetersPerSecond: speedMetersPerSecond,
      locationUpdatedAt: updatedAt,
      now: now,
    );
  }

  double etaMinutesTo(double lat, double lng) =>
      etaEstimateTo(lat, lng).minutes;
}
