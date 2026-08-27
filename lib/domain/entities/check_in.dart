class CheckIn {
  final String studentUid;
  final String stopId;
  final String stopName;
  final String destinationStopId;
  final String destinationStopName;
  final DateTime createdAt;
  final DateTime expiresAt;

  const CheckIn({
    required this.studentUid,
    required this.stopId,
    required this.stopName,
    required this.destinationStopId,
    required this.destinationStopName,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
