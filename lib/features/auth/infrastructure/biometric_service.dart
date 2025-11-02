import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricAuthStatus {
  success,
  failed,
  notAvailable,
  notEnrolled,
  passcodeNotSet,
  lockedOut,
  error,
}

class BiometricAuthResult {
  const BiometricAuthResult(this.status, {this.errorMessage});

  final BiometricAuthStatus status;
  final String? errorMessage;

  bool get isSuccess => status == BiometricAuthStatus.success;
  String? get message => errorMessage;
}

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'Authenticate to continue'}) async {
    final result = await authenticateDetailed(reason: reason, biometricOnly: true);
    return result.isSuccess;
  }

  Future<BiometricAuthResult> authenticateDetailed({
    String reason = 'Authenticate to continue',
    bool biometricOnly = true,
  }) async {
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
      return didAuthenticate
          ? const BiometricAuthResult(BiometricAuthStatus.success)
          : const BiometricAuthResult(BiometricAuthStatus.failed);
    } on PlatformException catch (e) {
      final code = e.code.toLowerCase();
      if (code.contains('notavailable')) {
        return const BiometricAuthResult(BiometricAuthStatus.notAvailable);
      }
      if (code.contains('notenrolled')) {
        return const BiometricAuthResult(BiometricAuthStatus.notEnrolled);
      }
      if (code.contains('passcode')) {
        return const BiometricAuthResult(BiometricAuthStatus.passcodeNotSet);
      }
      if (code.contains('locked')) {
        return const BiometricAuthResult(BiometricAuthStatus.lockedOut);
      }
      return BiometricAuthResult(
        BiometricAuthStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      return BiometricAuthResult(
        BiometricAuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}
