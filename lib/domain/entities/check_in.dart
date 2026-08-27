enum WaitingEndReason {
  boarded,
  cancelled,
  geofenceExited,
}

class CheckIn {
  final String studentUid;
  final String journeyId;
  final String stopId;
  final String stopName;
  final String destinationStopId;
  final String destinationStopName;
  final DateTime createdAt;
  final DateTime expiresAt;
  final WaitingEndReason? endReason;
  final DateTime? endedAt;
  final int missedBoardingCount;
  final DateTime? lastMissedBoardingAt;

  const CheckIn({
    required this.studentUid,
    required this.journeyId,
    required this.stopId,
    required this.stopName,
    required this.destinationStopId,
    required this.destinationStopName,
    required this.createdAt,
    required this.expiresAt,
    this.endReason,
    this.endedAt,
    this.missedBoardingCount = 0,
    this.lastMissedBoardingAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isActive => endReason == null && endedAt == null && !isExpired;
}
