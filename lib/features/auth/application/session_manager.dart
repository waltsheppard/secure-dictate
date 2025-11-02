import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:authapp1/features/auth/auth.dart';

class PinValidationException implements Exception {
  const PinValidationException(this.message);

  final String message;

  @override
  String toString() => 'PinValidationException: $message';
}

class SessionManager {
  SessionManager(this._ref);

  final Ref _ref;

  AuthRepository get _authRepository => _ref.read(authRepositoryProvider);
  CredentialStorage get _storage => _ref.read(credentialStorageProvider);
  AuthConfig get _config => _ref.read(authConfigProvider);

  Future<bool> hasPin() => _storage.hasPin();

  Future<void> updatePin({
    String? currentPin,
    required String newPin,
  }) async {
    final hasExisting = await hasPin();
    if (hasExisting) {
      if (currentPin == null || currentPin.isEmpty) {
        throw const PinValidationException('Current PIN required');
      }
      final valid = await _storage.verifyPin(currentPin);
      if (!valid) {
        throw const PinValidationException('Current PIN is incorrect');
      }
    }
    await _storage.savePin(newPin);
  }

  Future<bool> verifyPin(String pin) => _storage.verifyPin(pin);

  Future<void> clearPin() => _storage.clearPin();

  Future<bool> isRememberMeEnabled() async {
    final stored = await _storage.readRememberMe();
    return stored ?? _config.rememberMeDefault;
  }

  Future<void> updateRememberMe(bool remember, {String? email}) async {
    await _storage.saveRememberMe(remember);
    if (remember) {
      if (email != null && email.isNotEmpty) {
        await _storage.saveEmail(email);
      }
    } else {
      await _storage.clear();
      await _storage.saveRememberMe(false);
    }
  }

  Future<void> handleSuccessfulSignIn({
    required String email,
    required bool rememberMe,
    String? password,
    bool persistPassword = true,
  }) async {
    if (rememberMe) {
      await _storage.saveRememberMe(true);
      await _storage.saveEmail(email);
      final session = await currentSession();
      final refreshToken = session.userPoolTokensResult.valueOrNull?.refreshToken;
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _storage.saveRefreshToken(refreshToken);
      }
      if (_config.allowBiometricCredentialLogin) {
        if (persistPassword && password != null && password.isNotEmpty) {
          await _storage.savePassword(password);
        } else if (!persistPassword) {
          // leave existing password untouched
        } else {
          await _storage.clearPassword();
        }
      } else {
        await _storage.clearPassword();
      }
    } else {
      await updateRememberMe(false);
      await _storage.clearPassword();
    }
  }

  Future<bool> canUseQuickSignIn() async {
    final remember = await isRememberMeEnabled();
    if (!remember) return false;
    final storedRefresh = await _storage.readRefreshToken();
    if (storedRefresh != null && storedRefresh.isNotEmpty) return true;
    if (_config.allowBiometricCredentialLogin) {
      final storedPassword = await _storage.readPassword();
      return storedPassword != null && storedPassword.isNotEmpty;
    }
    return false;
  }

  Future<String?> savedEmail() => _storage.readEmail();

  Future<bool> hasSavedCredentials() async {
    final email = await savedEmail();
    final refresh = await _storage.readRefreshToken();
    if (email == null || email.isEmpty) return false;
    if (refresh != null && refresh.isNotEmpty) return true;
    if (_config.allowBiometricCredentialLogin) {
      final password = await _storage.readPassword();
      if (password != null && password.isNotEmpty) return true;
    }
    return false;
  }

  Future<CognitoAuthSession> currentSession() async {
    await _authRepository.configure();
    return _authRepository.fetchSession();
  }

  Future<void> signOut() async {
    final remember = await isRememberMeEnabled();
    final email = remember ? await savedEmail() : null;
    await _authRepository.signOut();
    await _storage.clear();
    if (remember) {
      await updateRememberMe(true, email: email);
    } else {
      await _storage.saveRememberMe(false);
    }
    await _ref.read(platformHooksProvider).onSignOut(_ref);
  }

  Future<void> clearStoredCredentials() async {
    final remember = await isRememberMeEnabled();
    await _storage.clear();
    await _storage.saveRememberMe(remember);
  }

  Future<bool> signInWithStoredCredentials() async {
    if (!_config.allowBiometricCredentialLogin) return false;
    final email = await savedEmail();
    final password = await _storage.readPassword();
    if (email == null || email.isEmpty || password == null || password.isEmpty) {
      return false;
    }
    try {
      await _authRepository.configure();
      final result = await _authRepository.signIn(email: email, password: password);
      if (result.isSignedIn) {
        await handleSuccessfulSignIn(
          email: email,
          rememberMe: true,
          password: password,
          persistPassword: false,
        );
        return true;
      }
      return false;
    } on AuthException {
      await _storage.clearPassword();
      return false;
    }
  }
}

final sessionManagerProvider = Provider<SessionManager>((ref) => SessionManager(ref));
