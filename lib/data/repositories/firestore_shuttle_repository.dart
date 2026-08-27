import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/occupancy.dart';
import '../../domain/entities/shuttle.dart';
import '../../domain/repositories/shuttle_repository.dart';

class FirestoreShuttleRepository implements ShuttleRepository {
  final FirebaseFirestore _db;

  FirestoreShuttleRepository(this._db);

  @override
  Stream<List<Shuttle>> watchOnDutyShuttles() {
    return _db
        .collection('shuttles')
        .where('onDuty', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map(_fromDoc)
            .whereType<Shuttle>()
            .where((s) => s.isFresh)
            .toList());
  }

  Shuttle? _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final lat = (data?['latitude'] as num?)?.toDouble();
    final lng = (data?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    final rawBand = data?['driverOccupancyBand'] as String?;
    final occupancyBand = rawBand == null
        ? null
        : OccupancyBand.values.where((b) => b.name == rawBand).firstOrNull;

    return Shuttle(
      id: doc.id,
      latitude: lat,
      longitude: lng,
      headingDegrees: (data?['heading'] as num?)?.toDouble(),
      speedMetersPerSecond: (data?['speed'] as num?)?.toDouble(),
      updatedAt: (data?['updatedAt'] as Timestamp?)?.toDate(),
      servingDestinationStopId:
          data?['servingDestinationStopId'] as String?,
      routeId: data?['routeId'] as String?,
      tripId: data?['tripId'] as String?,
      routeDirection: data?['routeDirection'] as String?,
      currentStopSequence: (data?['currentStopSequence'] as num?)?.toInt(),
      driverOccupancyBand: occupancyBand,
      occupancyReportedAt:
          (data?['occupancyReportedAt'] as Timestamp?)?.toDate(),
      trackedOnboardCount: (data?['trackedOnboardCount'] as num?)?.toInt(),
      safeCapacity: (data?['safeCapacity'] as num?)?.toInt(),
    );
  }
}
