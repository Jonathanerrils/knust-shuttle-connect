import '../../core/utils/result.dart';
import '../entities/check_in.dart';
import '../repositories/check_in_repository.dart';

class CompleteCheckIn {
  final CheckInRepository _checkIns;

  const CompleteCheckIn(this._checkIns);

  Future<Result<void>> call(String uid, WaitingEndReason reason) async {
    try {
      await _checkIns.complete(uid: uid, reason: reason);
      return const Result.success(null);
    } catch (e) {
      return Result.failure('Could not update your waiting status. ($e)');
    }
  }
}
