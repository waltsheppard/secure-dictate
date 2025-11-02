import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:authapp1/features/auth/auth.dart';

class LoginController extends StateNotifier<AsyncValue<void>> {
  LoginController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<SignInResult> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      final repo = _ref.read(authRepositoryProvider);
      await repo.configure();
      final result = await repo.signIn(email: email, password: password);
      state = const AsyncData(null);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<SignInResult> confirmSignIn(String value) async {
    state = const AsyncLoading();
    try {
      final repo = _ref.read(authRepositoryProvider);
      final result = await repo.confirmSignIn(value);
      state = const AsyncData(null);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<ResetPasswordResult> requestPasswordReset(String email) async {
    state = const AsyncLoading();
    try {
      final repo = _ref.read(authRepositoryProvider);
      await repo.configure();
      final result = await repo.requestPasswordReset(email);
      state = const AsyncData(null);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String newPassword,
    required String confirmationCode,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = _ref.read(authRepositoryProvider);
      await repo.configure();
      await repo.confirmResetPassword(
        username: email,
        newPassword: newPassword,
        confirmationCode: confirmationCode,
      );
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<CognitoAuthSession> fetchSession() async {
    final repo = _ref.read(authRepositoryProvider);
    await repo.configure();
    return repo.fetchSession();
  }

  Future<void> signOut() async {
    final repo = _ref.read(authRepositoryProvider);
    await repo.signOut();
  }
}

final loginControllerProvider =
    StateNotifierProvider<LoginController, AsyncValue<void>>((ref) => LoginController(ref));
