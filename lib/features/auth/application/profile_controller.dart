import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:authapp1/features/auth/auth.dart';

class ProfileController extends StateNotifier<AsyncValue<void>> {
  ProfileController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  SessionManager get _sessionManager => _ref.read(sessionManagerProvider);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = const AsyncLoading();
    try {
      await Amplify.Auth.updatePassword(
        oldPassword: currentPassword,
        newPassword: newPassword,
      );
      state = const AsyncValue.data(null);
    } on AuthException catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> updatePin({
    String? currentPin,
    required String newPin,
  }) async {
    state = const AsyncLoading();
    try {
      await _sessionManager.updatePin(currentPin: currentPin, newPin: newPin);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> removePin() async {
    state = const AsyncLoading();
    try {
      await _sessionManager.clearPin();
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<bool> hasPin() => _sessionManager.hasPin();
}

final profileControllerProvider =
    StateNotifierProvider<ProfileController, AsyncValue<void>>(
  (ref) => ProfileController(ref),
);
