import '../entities/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> watchUser();
  Future<void> signInWithEmail(String email, String password);
  Future<void> registerStudent(String email, String password);
  Future<void> startPhoneSignIn(
    String e164PhoneNumber, {
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onFailed,
    required void Function() onAutoVerified,
  });
  Future<void> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  });
  Future<void> signOut();
}
