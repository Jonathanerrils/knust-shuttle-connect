import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/bus_stop.dart';
import '../../domain/entities/check_in.dart';
import '../../domain/repositories/check_in_repository.dart';
import '../models/check_in_model.dart';

class FirestoreCheckInRepository implements CheckInRepository {
  final FirebaseFirestore _db;

  FirestoreCheckInRepository(this._db);

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('checkins').doc(uid);

  @override
  Stream<CheckIn?> watchMyCheckIn(String uid) => _doc(uid).snapshots().map(
        (doc) {
          final checkIn = CheckInModel.fromDoc(doc);
          if (checkIn == null || !checkIn.isActive) return null;
          return checkIn;
        },
      );

  @override
  Future<void> checkIn({
    required String uid,
    required BusStop stop,
    required BusStop destination,
  }) {
    final journeyId = _db.collection('analytics_events').doc().id;
    return _doc(uid).set(<String, dynamic>{
      'journeyId': journeyId,
      'stopId': stop.id,
      'stopName': stop.name,
      'destinationStopId': destination.id,
      'destinationStopName': destination.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(AppConstants.checkInTtl),
      ),
    });
  }

  @override
  Future<void> complete({
    required String uid,
    required WaitingEndReason reason,
  }) {
    return _doc(uid).update(<String, dynamic>{
      'endReason': reason.name,
      'endedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
