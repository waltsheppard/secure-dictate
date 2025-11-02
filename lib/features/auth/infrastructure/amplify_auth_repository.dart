import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:authapp1/features/auth/domain/auth_repository.dart';
import 'package:authapp1/features/auth/infrastructure/auth_service.dart';

class AmplifyAuthRepository implements AuthRepository {
  AmplifyAuthRepository(this._service);

  final AuthService _service;

  @override
  Future<void> configure() => _service.configureIfNeeded();

  @override
  Future<SignInResult> signIn({
    required String email,
    required String password,
  }) => _service.signIn(email: email, password: password);

  @override
  Future<SignInResult> confirmSignIn(String value) =>
      _service.confirmSignIn(value);

  @override
  Future<ResetPasswordResult> requestPasswordReset(String username) =>
      _service.requestPasswordReset(username);

  @override
  Future<ResetPasswordResult> confirmResetPassword({
    required String username,
    required String newPassword,
    required String confirmationCode,
  }) => _service.confirmResetPassword(
        email: username,
        newPassword: newPassword,
        confirmationCode: confirmationCode,
      );

  @override
  Future<ResendSignUpCodeResult> resendSignUpCode(String username) =>
      _service.resendSignUpCode(username);

  @override
  Future<CognitoAuthSession> fetchSession() => _service.fetchSession();

  @override
  Future<void> signOut() => _service.signOut();

  @override
  Future<void> deleteUser() => _service.deleteUser();
}
