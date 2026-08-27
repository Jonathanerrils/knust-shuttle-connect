import 'package:flutter_test/flutter_test.dart';
import 'package:knust_shuttle_connect/domain/entities/occupancy.dart';

void main() {
  final now = DateTime.utc(2026, 8, 27, 14);

  test('fresh driver report is high confidence and authoritative', () {
    final estimate = OccupancyEstimate.fromSignals(
      driverReportedBand: OccupancyBand.full,
      driverReportedAt: now.subtract(const Duration(minutes: 2)),
      trackedOnboardCount: 8,
      safeCapacity: 40,
      now: now,
    );

    expect(estimate.band, OccupancyBand.full);
    expect(estimate.confidence, OccupancyConfidence.high);
    expect(estimate.usesDriverReport, isTrue);
  });

  test('older driver report loses confidence', () {
    final estimate = OccupancyEstimate.fromSignals(
      driverReportedBand: OccupancyBand.limited,
      driverReportedAt: now.subtract(const Duration(minutes: 10)),
      now: now,
    );

    expect(estimate.band, OccupancyBand.limited);
    expect(estimate.confidence, OccupancyConfidence.medium);
  });

  test('tracked occupancy falls back to broad capacity bands', () {
    final estimate = OccupancyEstimate.fromSignals(
      trackedOnboardCount: 32,
      safeCapacity: 40,
      now: now,
    );

    expect(estimate.band, OccupancyBand.limited);
    expect(estimate.confidence, OccupancyConfidence.medium);
    expect(estimate.usesDriverReport, isFalse);
  });

  test('missing capacity and driver report stays unknown', () {
    final estimate = OccupancyEstimate.fromSignals(
      trackedOnboardCount: 12,
      now: now,
    );

    expect(estimate.band, OccupancyBand.unknown);
    expect(estimate.confidence, OccupancyConfidence.low);
  });

  test('count at or above safe capacity is full', () {
    final estimate = OccupancyEstimate.fromSignals(
      trackedOnboardCount: 40,
      safeCapacity: 40,
      now: now,
    );

    expect(estimate.band, OccupancyBand.full);
  });
}
