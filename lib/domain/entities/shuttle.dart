import '../../core/utils/geo_utils.dart';
import '../services/eta_estimator.dart';

class Shuttle {
  final String id;
  final double latitude;
  final double longitude;
  final double? headingDegrees;
  final double? speedMetersPerSecond;
  final DateTime? updatedAt;

  const Shuttle({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.headingDegrees,
    this.speedMetersPerSecond,
    this.updatedAt,
  });

  bool get isFresh =>
      updatedAt != null &&
      DateTime.now().difference(updatedAt!) < const Duration(minutes: 5);

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
