import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:authapp1/features/auth/domain/auth_repository.dart';
import 'package:authapp1/features/auth/infrastructure/amplify_auth_repository.dart';
import 'package:authapp1/features/auth/infrastructure/auth_service.dart';
import 'package:authapp1/features/auth/infrastructure/credential_storage.dart';
import 'package:authapp1/features/auth/infrastructure/biometric_service.dart';

class AuthController extends StateNotifier<AsyncValue<AuthSession>> {
  AuthController(this._repository) : super(const AsyncLoading()) {
    load();
  }

  final AuthRepository _repository;

  Future<void> load() async {
    try {
      await _repository.configure();
      final session = await _repository.fetchSession();
      state = AsyncData(session);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final _authRepositoryImplProvider = Provider<AmplifyAuthRepository>((ref) {
  return AmplifyAuthRepository(AuthService());
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ref.watch(_authRepositoryImplProvider);
});

final credentialStorageProvider = Provider<CredentialStorage>((ref) => CredentialStorage());

final biometricServiceProvider = Provider<BiometricService>((ref) => BiometricService());

final authProvider = StateNotifierProvider<AuthController, AsyncValue<AuthSession>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
