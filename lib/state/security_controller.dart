import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:safe_device/safe_device.dart';
import 'package:authapp1/features/auth/auth.dart';

const _idleTimeout = Duration(minutes: 2);

enum SecurityBlockReason {
  compromisedDevice,
  insecureDevice,
}

class SecurityState {
  const SecurityState({
    required this.isUnlocked,
    required this.blockReason,
    required this.blockMessage,
    required this.authInProgress,
    required this.firstCheckComplete,
    required this.requiresPin,
  });

  factory SecurityState.initial() => const SecurityState(
        isUnlocked: false,
        blockReason: null,
        blockMessage: null,
        authInProgress: false,
        firstCheckComplete: false,
        requiresPin: false,
      );

  final bool isUnlocked;
  final SecurityBlockReason? blockReason;
  final String? blockMessage;
  final bool authInProgress;
  final bool firstCheckComplete;
  final bool requiresPin;

  SecurityState copyWith({
    bool? isUnlocked,
    SecurityBlockReason? blockReason,
    bool setBlockReasonNull = false,
    String? blockMessage,
    bool setBlockMessageNull = false,
    bool? authInProgress,
    bool? firstCheckComplete,
    bool? requiresPin,
  }) {
    return SecurityState(
      isUnlocked: isUnlocked ?? this.isUnlocked,
      blockReason: setBlockReasonNull ? null : blockReason ?? this.blockReason,
      blockMessage: setBlockMessageNull ? null : blockMessage ?? this.blockMessage,
      authInProgress: authInProgress ?? this.authInProgress,
      firstCheckComplete: firstCheckComplete ?? this.firstCheckComplete,
      requiresPin: requiresPin ?? this.requiresPin,
    );
  }
}

class SecurityController extends StateNotifier<SecurityState> {
  SecurityController(this._ref) : super(SecurityState.initial());

  final Ref _ref;
  Timer? _idleTimer;

  SessionManager get _sessionManager => _ref.read(sessionManagerProvider);
  BiometricService get _biometricService => _ref.read(biometricServiceProvider);

  Future<void> handleAppLaunch() async {
    await _evaluateDevice();
    if (state.blockReason != null) {
      state = state.copyWith(firstCheckComplete: true);
      return;
    }
    await requestUnlock(reason: 'Unlock to continue');
  }

  Future<void> handleAppResume() async {
    await _evaluateDevice();
    if (state.blockReason != null) {
      state = state.copyWith(firstCheckComplete: true);
      return;
    }
    if (!state.isUnlocked && !state.authInProgress && !state.requiresPin) {
      await requestUnlock(reason: 'Unlock to continue');
    } else {
      recordUserActivity();
      state = state.copyWith(firstCheckComplete: true);
    }
  }

  void handleAppPaused() {
    lock();
  }

  Future<void> _evaluateDevice() async {
    if (kDebugMode) {
      state = state.copyWith(
        setBlockReasonNull: true,
        setBlockMessageNull: true,
      );
      return;
    }
    try {
      final bool isSafe = await SafeDevice.isSafeDevice;
      if (!isSafe) {
        _block(
          SecurityBlockReason.compromisedDevice,
          message:
              'This device appears to be rooted, jailbroken, or otherwise insecure. '
              'Access is blocked. Use a managed device that meets security requirements.',
        );
        return;
      }
      state = state.copyWith(
        setBlockReasonNull: true,
        setBlockMessageNull: true,
      );
    } catch (error) {
      _block(
        SecurityBlockReason.compromisedDevice,
        message:
            'Unable to verify device integrity. Please retry on a managed device.',
      );
    }
  }

  Future<void> requestUnlock({required String reason}) async {
    if (state.blockReason != null) {
      state = state.copyWith(firstCheckComplete: true);
      return;
    }
    _stopIdleTimer();
    state = state.copyWith(authInProgress: true);
    final result = await _biometricService.authenticateDetailed(
      reason: reason,
      biometricOnly: false,
    );
    if (result.isSuccess) {
      state = state.copyWith(
        isUnlocked: true,
        authInProgress: false,
        firstCheckComplete: true,
        setBlockReasonNull: true,
        setBlockMessageNull: true,
        requiresPin: false,
      );
      _startIdleTimer();
      return;
    }
    state = state.copyWith(firstCheckComplete: true);
    switch (result.status) {
      case BiometricAuthStatus.notAvailable:
      case BiometricAuthStatus.notEnrolled:
      case BiometricAuthStatus.passcodeNotSet:
        final hasPin = await _sessionManager.hasPin();
        if (hasPin) {
          state = state.copyWith(
            authInProgress: false,
            requiresPin: true,
            isUnlocked: false,
            blockMessage: 'Enter your security PIN to continue.',
            setBlockReasonNull: true,
          );
        } else {
          _block(
            SecurityBlockReason.insecureDevice,
            message:
                'Enable a device passcode or biometric unlock to continue. '
                'Once configured, reopen the app.',
          );
        }
        break;
      case BiometricAuthStatus.lockedOut:
        lock(message: 'Too many failed attempts. Try again later.');
        break;
      case BiometricAuthStatus.failed:
        lock(message: 'Unlock cancelled. Tap Unlock to try again.');
        break;
      case BiometricAuthStatus.error:
        lock(message: result.errorMessage ?? 'Authentication error. Try again.');
        break;
      case BiometricAuthStatus.success:
        break;
    }
  }

  void recordUserActivity() {
    if (!state.isUnlocked || state.blockReason != null || state.requiresPin) return;
    _startIdleTimer();
  }

  void lock({String? message}) {
    _stopIdleTimer();
    state = state.copyWith(
      isUnlocked: false,
      authInProgress: false,
      blockMessage: message ?? state.blockMessage,
      firstCheckComplete: state.firstCheckComplete,
      requiresPin: false,
    );
  }

  void _block(SecurityBlockReason reason, {required String message}) {
    _stopIdleTimer();
    state = state.copyWith(
      isUnlocked: false,
      authInProgress: false,
      blockReason: reason,
      blockMessage: message,
      firstCheckComplete: true,
      requiresPin: false,
    );
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, () {
      lock(message: 'Session locked due to inactivity.');
    });
  }

  void _stopIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  Future<void> forceSignOut() async {
    await _sessionManager.signOut();
    lock();
  }

  Future<bool> unlockWithPin(String pin) async {
    _stopIdleTimer();
    state = state.copyWith(authInProgress: true);
    final valid = await _sessionManager.verifyPin(pin);
    if (valid) {
      state = state.copyWith(
        isUnlocked: true,
        authInProgress: false,
        requiresPin: false,
        setBlockMessageNull: true,
        setBlockReasonNull: true,
        firstCheckComplete: true,
      );
      _startIdleTimer();
      return true;
    }
    state = state.copyWith(
      authInProgress: false,
      requiresPin: true,
      blockMessage: 'Incorrect PIN. Try again.',
      firstCheckComplete: true,
    );
    return false;
  }

  @override
  void dispose() {
    _stopIdleTimer();
    super.dispose();
  }
}

final securityControllerProvider =
    StateNotifierProvider<SecurityController, SecurityState>(
  (ref) => SecurityController(ref),
);
