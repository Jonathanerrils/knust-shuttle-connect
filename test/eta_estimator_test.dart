import 'package:flutter_test/flutter_test.dart';
import 'package:knust_shuttle_connect/domain/services/eta_estimator.dart';

void main() {
  group('EtaEstimator', () {
    test('falls back to campus baseline speed when observed speed is absent', () {
      final now = DateTime(2026, 8, 26, 12, 0);
      final estimate = EtaEstimator.estimate(
        distanceMeters: 1000,
        now: now,
      );

      expect(estimate.usedObservedSpeed, isFalse);
      expect(estimate.confidence, EtaConfidence.low);
      expect(estimate.adjustedDistanceMeters, closeTo(1250, 0.001));
      expect(estimate.minutes, closeTo(1250 / 5.5 / 60, 0.001));
    });

    test('recent plausible speed receives high confidence', () {
      final now = DateTime(2026, 8, 26, 12, 0);
      final estimate = EtaEstimator.estimate(
        distanceMeters: 800,
        observedSpeedMetersPerSecond: 8,
        locationUpdatedAt: now.subtract(const Duration(seconds: 20)),
        now: now,
      );

      expect(estimate.usedObservedSpeed, isTrue);
      expect(estimate.confidence, EtaConfidence.high);
      expect(estimate.effectiveSpeedMetersPerSecond, greaterThan(7));
      expect(estimate.upperMinutes, greaterThan(estimate.minutes));
      expect(estimate.lowerMinutes, lessThan(estimate.minutes));
    });

    test('stale speed is ignored', () {
      final now = DateTime(2026, 8, 26, 12, 0);
      final estimate = EtaEstimator.estimate(
        distanceMeters: 1000,
        observedSpeedMetersPerSecond: 9,
        locationUpdatedAt: now.subtract(const Duration(minutes: 4)),
        now: now,
      );

      expect(estimate.usedObservedSpeed, isFalse);
      expect(estimate.confidence, EtaConfidence.low);
      expect(
        estimate.effectiveSpeedMetersPerSecond,
        EtaEstimator.fallbackSpeedMetersPerSecond,
      );
    });

    test('peak period increases ETA by twenty percent', () {
      final offPeak = EtaEstimator.estimate(
        distanceMeters: 1000,
        now: DateTime(2026, 8, 26, 12, 0),
      );
      final peak = EtaEstimator.estimate(
        distanceMeters: 1000,
        now: DateTime(2026, 8, 26, 8, 0),
      );

      expect(peak.peakAdjusted, isTrue);
      expect(offPeak.peakAdjusted, isFalse);
      expect(peak.minutes, closeTo(offPeak.minutes * 1.2, 0.001));
    });

    test('implausibly fast campus speed is rejected', () {
      final now = DateTime(2026, 8, 26, 12, 0);
      final estimate = EtaEstimator.estimate(
        distanceMeters: 500,
        observedSpeedMetersPerSecond: 30,
        locationUpdatedAt: now,
        now: now,
      );

      expect(estimate.usedObservedSpeed, isFalse);
      expect(estimate.confidence, EtaConfidence.low);
    });
  });
}
