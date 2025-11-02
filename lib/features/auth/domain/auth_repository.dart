import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

abstract class AuthRepository {
  Future<void> configure();
  Future<SignInResult> signIn({
    required String email,
    required String password,
  });
  Future<SignInResult> confirmSignIn(String value);
  Future<ResetPasswordResult> requestPasswordReset(String username);
  Future<ResetPasswordResult> confirmResetPassword({
    required String username,
    required String newPassword,
    required String confirmationCode,
  });
  Future<ResendSignUpCodeResult> resendSignUpCode(String username);
  Future<CognitoAuthSession> fetchSession();
  Future<void> signOut();
  Future<void> deleteUser();
}
