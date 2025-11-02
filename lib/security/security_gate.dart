import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:authapp1/state/security_controller.dart';

class SecurityGate extends ConsumerWidget {
  const SecurityGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final securityState = ref.watch(securityControllerProvider);
    final controller = ref.read(securityControllerProvider.notifier);

    if (securityState.blockReason != null) {
      return _BlockedDeviceScreen(
        message: securityState.blockMessage ??
            'This device does not meet security requirements.',
        onSignOut: controller.forceSignOut,
      );
    }

    if (!securityState.firstCheckComplete || securityState.authInProgress) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (securityState.requiresPin) {
      return _PinUnlockScreen(message: securityState.blockMessage);
    }

    if (!securityState.isUnlocked) {
      return _LockedSessionScreen(
        message: securityState.blockMessage,
        onUnlock: () => controller.requestUnlock(reason: 'Unlock to continue'),
        onSignOut: controller.forceSignOut,
      );
    }

    return child;
  }
}

class _LockedSessionScreen extends StatelessWidget {
  const _LockedSessionScreen({
    required this.onUnlock,
    required this.onSignOut,
    this.message,
  });

  final Future<void> Function() onUnlock;
  final Future<void> Function() onSignOut;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_outline, size: 64),
              const SizedBox(height: 24),
              const Text(
                'Session Locked',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message ?? 'Tap Unlock and authenticate to continue.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onUnlock,
                child: const Text('Unlock'),
              ),
              TextButton(
                onPressed: onSignOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockedDeviceScreen extends StatelessWidget {
  const _BlockedDeviceScreen({
    required this.message,
    required this.onSignOut,
  });

  final String message;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.error_outline, size: 72, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'Access Blocked',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onSignOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinUnlockScreen extends ConsumerStatefulWidget {
  const _PinUnlockScreen({required this.message});

  final String? message;

  @override
  ConsumerState<_PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends ConsumerState<_PinUnlockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final ok = await ref.read(securityControllerProvider.notifier).unlockWithPin(
          _pinController.text,
        );
    if (!mounted) return;
    if (ok) {
      setState(() {
        _submitting = false;
        _error = null;
      });
      _pinController.clear();
    } else {
      setState(() {
        _submitting = false;
        _error = 'Incorrect PIN. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(securityControllerProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.pin_outlined, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Enter Security PIN',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _error ?? widget.message ?? 'Use your app PIN to unlock.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _pinController,
                  decoration: const InputDecoration(
                    labelText: 'PIN code',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Enter your PIN';
                    if (v.length < 4) return 'PIN must be at least 4 digits';
                    if (!RegExp(r'^\\d+$').hasMatch(v)) return 'Use digits only';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Unlock'),
                ),
                TextButton(
                  onPressed: _submitting ? null : controller.forceSignOut,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
