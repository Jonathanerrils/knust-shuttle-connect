import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/check_in.dart';

class CheckInModel {
  CheckInModel._();

  static CheckIn? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    return CheckIn(
      studentUid: doc.id,
      journeyId: (data['journeyId'] as String?) ?? '',
      stopId: data['stopId'] as String,
      stopName: (data['stopName'] as String?) ?? '',
      destinationStopId: (data['destinationStopId'] as String?) ?? '',
      destinationStopName: (data['destinationStopName'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
