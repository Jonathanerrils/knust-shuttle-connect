import 'transport_context.dart';

enum AnalyticsEventType {
  waitingStarted,
  waitingEnded,
  waitingCancelled,
  waitingExpired,
  geofenceExited,
  boardingMissed,
  shuttleEnRoute,
  shuttleArrived,
  boarded,
  etaGenerated,
  etaOutcomeRecorded,
  safetyReportSubmitted,
}

class AnalyticsEvent {
  static const int currentSchemaVersion = 2;

  final String eventId;
  final AnalyticsEventType type;
  final DateTime occurredAt;
  final TransportContext context;
  final int schemaVersion;
  final String? journeyId;
  final String? tripId;
  final String? vehicleId;
  final String? routeId;
  final String? stopId;
  final String? destinationStopId;
  final Map<String, Object?> attributes;

  const AnalyticsEvent({
    required this.eventId,
    required this.type,
    required this.occurredAt,
    required this.context,
    this.schemaVersion = currentSchemaVersion,
    this.journeyId,
    this.tripId,
    this.vehicleId,
    this.routeId,
    this.stopId,
    this.destinationStopId,
    this.attributes = const <String, Object?>{},
  });

  Map<String, Object?> toMap() => <String, Object?>{
        'eventId': eventId,
        'eventType': type.name,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'schemaVersion': schemaVersion,
        ...context.toMap(),
        if (journeyId != null) 'journeyId': journeyId,
        if (tripId != null) 'tripId': tripId,
        if (vehicleId != null) 'vehicleId': vehicleId,
        if (routeId != null) 'routeId': routeId,
        if (stopId != null) 'stopId': stopId,
        if (destinationStopId != null)
          'destinationStopId': destinationStopId,
        'attributes': attributes,
      };
}
