import 'dart:math' as math;

enum EtaConfidence { high, medium, low }

class EtaEstimate {
  final double minutes;
  final double lowerMinutes;
  final double upperMinutes;
  final EtaConfidence confidence;
  final double effectiveSpeedMetersPerSecond;
  final double adjustedDistanceMeters;
  final bool usedObservedSpeed;
  final bool peakAdjusted;

  const EtaEstimate({
    required this.minutes,
    required this.lowerMinutes,
    required this.upperMinutes,
    required this.confidence,
    required this.effectiveSpeedMetersPerSecond,
    required this.adjustedDistanceMeters,
    required this.usedObservedSpeed,
    required this.peakAdjusted,
  });

  int get roundedMinutes => math.max(1, minutes.ceil()).toInt();
  int get lowerRoundedMinutes => math.max(1, lowerMinutes.floor()).toInt();
  int get upperRoundedMinutes =>
      math.max(lowerRoundedMinutes, upperMinutes.ceil()).toInt();

  String get confidenceLabel => confidence.name;
}

class EtaEstimator {
  static const double fallbackSpeedMetersPerSecond = 5.5;
  static const double defaultRoadDistanceFactor = 1.25;
  static const double minimumUsableSpeedMetersPerSecond = 2.0;
  static const double maximumPlausibleCampusSpeedMetersPerSecond = 15.0;
  static const double peakCongestionMultiplier = 1.20;

  const EtaEstimator._();

  static EtaEstimate estimate({
    required double distanceMeters,
    double? observedSpeedMetersPerSecond,
    DateTime? locationUpdatedAt,
    DateTime? now,
    double roadDistanceFactor = defaultRoadDistanceFactor,
  }) {
    final clock = now ?? DateTime.now();
    final nonNegativeDistance = math.max(0.0, distanceMeters).toDouble();
    final adjustedDistance =
        nonNegativeDistance * math.max(1.0, roadDistanceFactor);

    final speedIsPlausible = observedSpeedMetersPerSecond != null &&
        observedSpeedMetersPerSecond >= minimumUsableSpeedMetersPerSecond &&
        observedSpeedMetersPerSecond <=
            maximumPlausibleCampusSpeedMetersPerSecond;

    final ageSeconds = locationUpdatedAt == null
        ? double.infinity
        : math.max(0, clock.difference(locationUpdatedAt).inSeconds).toDouble();

    final observationWeight =
        speedIsPlausible ? _observationWeight(ageSeconds) : 0.0;

    final effectiveSpeed = observationWeight > 0
        ? observationWeight * observedSpeedMetersPerSecond! +
            (1 - observationWeight) * fallbackSpeedMetersPerSecond
        : fallbackSpeedMetersPerSecond;

    final peakAdjusted = _isPeakPeriod(clock);
    final congestionMultiplier =
        peakAdjusted ? peakCongestionMultiplier : 1.0;

    final rawMinutes = adjustedDistance == 0
        ? 0.0
        : adjustedDistance / effectiveSpeed / 60.0;
    final minutes = rawMinutes * congestionMultiplier;

    final confidence = _confidence(
      speedIsPlausible: speedIsPlausible,
      ageSeconds: ageSeconds,
    );
    final margin = switch (confidence) {
      EtaConfidence.high => 0.15,
      EtaConfidence.medium => 0.25,
      EtaConfidence.low => 0.40,
    };

    final lower = minutes == 0
        ? 0.0
        : math.max(0.5, minutes * (1 - margin)).toDouble();
    final upper = math.max(lower, minutes * (1 + margin)).toDouble();

    return EtaEstimate(
      minutes: minutes,
      lowerMinutes: lower,
      upperMinutes: upper,
      confidence: confidence,
      effectiveSpeedMetersPerSecond: effectiveSpeed,
      adjustedDistanceMeters: adjustedDistance,
      usedObservedSpeed: observationWeight > 0,
      peakAdjusted: peakAdjusted,
    );
  }

  static double _observationWeight(double ageSeconds) {
    if (ageSeconds <= 30) return 0.80;
    if (ageSeconds <= 90) return 0.65;
    if (ageSeconds <= 180) return 0.45;
    return 0.0;
  }

  static EtaConfidence _confidence({
    required bool speedIsPlausible,
    required double ageSeconds,
  }) {
    if (speedIsPlausible && ageSeconds <= 60) return EtaConfidence.high;
    if (speedIsPlausible && ageSeconds <= 180) return EtaConfidence.medium;
    return EtaConfidence.low;
  }

  static bool _isPeakPeriod(DateTime time) {
    final hour = time.hour;
    final morningPeak = hour >= 7 && hour < 9;
    final eveningPeak = hour >= 16 && hour < 18;
    return morningPeak || eveningPeak;
  }
}
