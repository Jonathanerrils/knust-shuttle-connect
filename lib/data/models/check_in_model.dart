import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/check_in.dart';

class CheckInModel {
  CheckInModel._();

  static CheckIn? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    final rawReason = data['endReason'] as String?;
    return CheckIn(
      studentUid: doc.id,
      journeyId: (data['journeyId'] as String?) ?? '',
      stopId: data['stopId'] as String,
      stopName: (data['stopName'] as String?) ?? '',
      destinationStopId: (data['destinationStopId'] as String?) ?? '',
      destinationStopName: (data['destinationStopName'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endReason: rawReason == null
          ? null
          : WaitingEndReason.values.where((r) => r.name == rawReason).firstOrNull,
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
      missedBoardingCount: (data['missedBoardingCount'] as num?)?.toInt() ?? 0,
      lastMissedBoardingAt:
          (data['lastMissedBoardingAt'] as Timestamp?)?.toDate(),
    );
  }
}
