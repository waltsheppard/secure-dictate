import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:authapp1/features/auth/auth.dart';
import 'package:authapp1/theme/app_theme.dart';
import 'package:authapp1/theme/layout/auth_layout.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _passwordFormKey = GlobalKey<FormState>();
  final _pinFormKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _changingPassword = false;
  bool _updatingPin = false;
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _loadPinState();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _loadPinState() async {
    final hasPin = await ref.read(profileControllerProvider.notifier).hasPin();
    if (mounted) {
      setState(() => _hasPin = hasPin);
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => _changingPassword = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(profileControllerProvider.notifier).changePassword(
            currentPassword: _currentPasswordController.text,
            newPassword: _newPasswordController.text,
          );
      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('Password updated.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to update password. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  Future<void> _updatePin() async {
    if (!_pinFormKey.currentState!.validate()) return;
    setState(() => _updatingPin = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(profileControllerProvider.notifier).updatePin(
            currentPin: _hasPin ? _currentPinController.text.trim() : null,
            newPin: _newPinController.text.trim(),
          );
      if (!mounted) return;
      _currentPinController.clear();
      _newPinController.clear();
      _confirmPinController.clear();
      await _loadPinState();
      messenger.showSnackBar(
        const SnackBar(content: Text('Security PIN updated.')),
      );
    } on PinValidationException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to update PIN. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _updatingPin = false);
    }
  }

  Future<void> _removePin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove security PIN'),
        content: const Text('Removing your PIN disables app unlock via PIN. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) return;
    setState(() => _updatingPin = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(profileControllerProvider.notifier).removePin();
      if (!mounted) return;
      _currentPinController.clear();
      _newPinController.clear();
      _confirmPinController.clear();
      await _loadPinState();
      messenger.showSnackBar(
        const SnackBar(content: Text('Security PIN removed.')),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to remove PIN. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _updatingPin = false);
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter a password';
    final minLength = ref.read(authConfigProvider).passwordMinLength;
    if (value.length < minLength) {
      return 'Minimum $minLength characters';
    }
    return null;
  }

  String? _validatePin(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter a PIN';
    if (v.length < 4) return 'PIN must be at least 4 digits';
    if (v.length > 6) return 'PIN must be 4-6 digits';
    if (!RegExp(r'^\d+$').hasMatch(v)) return 'Use digits only';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).size.width > 640 ? const EdgeInsets.symmetric(horizontal: 120) : const EdgeInsets.symmetric(horizontal: 24);
    return AuthScaffold(
      title: 'Account security',
      child: SingleChildScrollView(
        padding: padding.copyWith(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Update password',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Form(
              key: _passwordFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _currentPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) =>
                        (value == null || value.isEmpty) ? 'Enter current password' : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _newPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: _changingPassword ? null : _changePassword,
                    child: _changingPassword
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Update password'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Manage security PIN',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Use a 4-6 digit PIN as a fallback unlock method when biometrics are unavailable. ',
            ),
            const SizedBox(height: AppSpacing.sm),
            Form(
              key: _pinFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_hasPin) ...[
                    TextFormField(
                      controller: _currentPinController,
                      decoration: const InputDecoration(
                        labelText: 'Current PIN',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 6,
                      validator: _validatePin,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  TextFormField(
                    controller: _newPinController,
                    decoration: const InputDecoration(
                      labelText: 'New PIN',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    validator: _validatePin,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _confirmPinController,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new PIN',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    validator: (value) {
                      if (value != _newPinController.text.trim()) {
                        return 'PIN codes do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: _updatingPin ? null : _updatePin,
                    child: _updatingPin
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_hasPin ? 'Update PIN' : 'Set PIN'),
                  ),
                  if (_hasPin)
                    TextButton(
                      onPressed: _updatingPin ? null : _removePin,
                      child: const Text('Remove PIN'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
