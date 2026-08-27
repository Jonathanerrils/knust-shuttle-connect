import 'package:flutter_test/flutter_test.dart';
import 'package:knust_shuttle_connect/domain/entities/analytics_event.dart';
import 'package:knust_shuttle_connect/domain/entities/transport_context.dart';

void main() {
  test('analytics event serializes context and schema version', () {
    final event = AnalyticsEvent(
      eventId: 'evt-1',
      type: AnalyticsEventType.waitingStarted,
      occurredAt: DateTime.utc(2026, 8, 27, 12),
      context: const TransportContext(
        countryId: 'GH',
        cityId: 'kumasi',
        networkId: 'knust',
        operatorId: 'knust-transport',
      ),
      journeyId: 'journey-1',
      stopId: 'commercial-area',
      destinationStopId: 'brunei',
    );

    final map = event.toMap();
    expect(map['schemaVersion'], AnalyticsEvent.currentSchemaVersion);
    expect(map['eventType'], 'waitingStarted');
    expect(map['countryId'], 'GH');
    expect(map['networkId'], 'knust');
    expect(map['journeyId'], 'journey-1');
    expect(map['studentUid'], isNull);
  });
}
