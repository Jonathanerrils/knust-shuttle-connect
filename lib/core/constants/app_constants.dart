/// Central knobs for the count-accuracy logic. Server-side equivalents live
/// in `functions/src/index.ts` and `firestore.rules` — keep them in sync.
class AppConstants {
  AppConstants._();

  static const Duration checkInTtl = Duration(minutes: 25);
  static const Duration checkInCooldown = Duration(seconds: 60);
  static const double defaultGeofenceRadiusMeters = 75;
  static const double geofenceExitBufferMeters = 50;
  static const int studentDistanceFilterMeters = 30;
  static const int driverDistanceFilterMeters = 25;

  static const List<String> allowedStudentDomains = <String>[
    'st.knust.edu.gh',
    'knust.edu.gh',
  ];

  static const int busyThreshold = 15;
  static const int moderateThreshold = 5;

  static String stopTopic(String stopId) => 'stop_$stopId';

  static const double campusCenterLat = 6.6745;
  static const double campusCenterLng = -1.5716;
  static const double campusDefaultZoom = 15;
}
