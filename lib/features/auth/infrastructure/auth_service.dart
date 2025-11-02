import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

class AuthService {
  Future<void> configureIfNeeded() async {
    if (!Amplify.isConfigured) {
      final auth = AmplifyAuthCognito();
      await Amplify.addPlugins([auth]);
    }
  }

  Future<SignInResult> signIn({
    required String email,
    required String password,
  }) async {
    return await Amplify.Auth.signIn(username: email, password: password);
  }

  Future<CognitoAuthSession> fetchSession() async {
    final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
    return session;
  }

  Future<void> signOut() async {
    await Amplify.Auth.signOut();
  }

  Future<ResetPasswordResult> resetPassword({required String email}) async {
    return await Amplify.Auth.resetPassword(username: email);
  }

  Future<ResetPasswordResult> confirmResetPassword({
    required String email,
    required String newPassword,
    required String confirmationCode,
  }) async {
    return await Amplify.Auth.confirmResetPassword(
      username: email,
      newPassword: newPassword,
      confirmationCode: confirmationCode,
    );
  }

  Future<void> deleteUser() async {
    await Amplify.Auth.deleteUser();
  }

  Future<SignInResult> confirmSignIn(String confirmationValue) async {
    return Amplify.Auth.confirmSignIn(confirmationValue: confirmationValue);
  }

  Future<ResetPasswordResult> requestPasswordReset(String username) async {
    return Amplify.Auth.resetPassword(username: username);
  }

  Future<ResendSignUpCodeResult> resendSignUpCode(String username) async {
    return Amplify.Auth.resendSignUpCode(username: username);
  }

}
