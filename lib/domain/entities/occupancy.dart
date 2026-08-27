enum OccupancyBand {
  unknown,
  empty,
  light,
  moderate,
  limited,
  full,
}

enum OccupancyConfidence { low, medium, high }

class OccupancyEstimate {
  final OccupancyBand band;
  final OccupancyConfidence confidence;
  final int? trackedOnboardCount;
  final int? safeCapacity;
  final DateTime? driverReportedAt;
  final bool usesDriverReport;

  const OccupancyEstimate({
    required this.band,
    required this.confidence,
    this.trackedOnboardCount,
    this.safeCapacity,
    this.driverReportedAt,
    this.usesDriverReport = false,
  });

  static OccupancyEstimate fromSignals({
    OccupancyBand? driverReportedBand,
    DateTime? driverReportedAt,
    int? trackedOnboardCount,
    int? safeCapacity,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();

    if (driverReportedBand != null &&
        driverReportedBand != OccupancyBand.unknown &&
        driverReportedAt != null) {
      final age = referenceNow.difference(driverReportedAt);
      final confidence = age <= const Duration(minutes: 5)
          ? OccupancyConfidence.high
          : age <= const Duration(minutes: 15)
              ? OccupancyConfidence.medium
              : OccupancyConfidence.low;
      return OccupancyEstimate(
        band: driverReportedBand,
        confidence: confidence,
        trackedOnboardCount: trackedOnboardCount,
        safeCapacity: safeCapacity,
        driverReportedAt: driverReportedAt,
        usesDriverReport: true,
      );
    }

    if (trackedOnboardCount != null && safeCapacity != null && safeCapacity > 0) {
      final count = trackedOnboardCount < 0 ? 0 : trackedOnboardCount;
      final ratio = count / safeCapacity;
      final band = ratio <= 0
          ? OccupancyBand.empty
          : ratio <= 0.35
              ? OccupancyBand.light
              : ratio <= 0.70
                  ? OccupancyBand.moderate
                  : ratio < 1
                      ? OccupancyBand.limited
                      : OccupancyBand.full;

      // App-confirmed boardings are a useful signal, but until app adoption is
      // measured they should not be treated as a complete passenger census.
      return OccupancyEstimate(
        band: band,
        confidence: OccupancyConfidence.medium,
        trackedOnboardCount: count,
        safeCapacity: safeCapacity,
      );
    }

    return OccupancyEstimate(
      band: OccupancyBand.unknown,
      confidence: OccupancyConfidence.low,
      trackedOnboardCount: trackedOnboardCount,
      safeCapacity: safeCapacity,
    );
  }

  String get label {
    switch (band) {
      case OccupancyBand.empty:
        return 'Empty';
      case OccupancyBand.light:
        return 'Plenty of room';
      case OccupancyBand.moderate:
        return 'Moderate occupancy';
      case OccupancyBand.limited:
        return 'Limited boarding space';
      case OccupancyBand.full:
        return 'Full / very limited boarding';
      case OccupancyBand.unknown:
        return 'Occupancy unknown';
    }
  }

  String get confidenceLabel => confidence.name;
}
