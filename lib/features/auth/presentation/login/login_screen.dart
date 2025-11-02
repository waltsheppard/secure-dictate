import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:authapp1/features/auth/auth.dart';
import 'package:authapp1/screens/home_screen.dart';
import 'package:authapp1/widgets/dialogs.dart';
import 'package:authapp1/theme/app_theme.dart';
import 'package:authapp1/theme/layout/auth_layout.dart';


class _ResetDialogResult {
  const _ResetDialogResult({required this.code, required this.newPassword});

  final String code;
  final String newPassword;
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.minPasswordLength});

  final int minPasswordLength;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    Navigator.of(context).pop(
      _ResetDialogResult(
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Verification code',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Enter the code' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'New password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Enter a password';
                }
                if (value.length < widget.minPasswordLength) {
                  return 'Minimum ${widget.minPasswordLength} characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) =>
                  value == _passwordController.text ? null : 'Passwords do not match',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final BiometricService _biometricService;
  late final SessionManager _sessionManager;
  bool _biometricsAvailable = false;
  bool _quickSignInReady = false;
  bool _samlSigningIn = false;
  late bool _rememberMe;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _biometricService = ref.read(biometricServiceProvider);
    _sessionManager = ref.read(sessionManagerProvider);
    final config = ref.read(authConfigProvider);
    _rememberMe = config.rememberMeDefault;
    if (config.isFederatedLogin) {
      _biometricsAvailable = false;
      _quickSignInReady = false;
    } else {
      _checkBiometrics();
    }
  }

  Future<void> _refreshQuickSignInAvailability() async {
    final ready = await _sessionManager.canUseQuickSignIn();
    if (!mounted) return;
    setState(() => _quickSignInReady = ready);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final available = await _biometricService.canCheckBiometrics();
    final remember = await _sessionManager.isRememberMeEnabled();
    final savedEmail = await _sessionManager.savedEmail();
    final quickReady = await _sessionManager.canUseQuickSignIn();
    if (!mounted) return;
    setState(() {
      _biometricsAvailable = available;
      _rememberMe = remember;
      _quickSignInReady = quickReady;
      if (savedEmail != null) _emailController.text = savedEmail;
    });
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = ref.read(authConfigProvider).emailRegex;
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    final minLength = ref.read(authConfigProvider).passwordMinLength;
    if (value.length < minLength) return 'Minimum $minLength characters';
    return null;
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(loginControllerProvider.notifier);
    try {
      final res = await controller.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (res.isSignedIn) {
        await _postSignInSuccess(password: _passwordController.text);
        return;
      }
      // Handle challenges
      final step = res.nextStep.signInStep;
      if (step == AuthSignInStep.confirmSignInWithSmsMfaCode || step == AuthSignInStep.confirmSignInWithTotpMfaCode) {
        if (!mounted) return;
        final code = await promptForInput(
          title: 'Enter verification code',
          label: 'Code',
          keyboard: TextInputType.number,
          context: context,
        );
        if (code == null || code.isEmpty) return;
        final conf = await controller.confirmSignIn(code);
        if (conf.isSignedIn && mounted) {
          await _postSignInSuccess();
        }
      } else if (step == AuthSignInStep.confirmSignInWithNewPassword) {
        if (!mounted) return;
        final newPassword = await promptForInput(
          title: 'Set new password',
          label: 'New password',
          obscure: true,
          context: context,
        );
        if (newPassword == null || newPassword.isEmpty) return;
        final conf = await controller.confirmSignIn(newPassword);
        if (conf.isSignedIn && mounted) {
          await _postSignInSuccess(password: newPassword);
        }
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _postSignInSuccess({String? password}) async {
    await _sessionManager.handleSuccessfulSignIn(
      email: _emailController.text.trim(),
      rememberMe: _rememberMe,
      password: password,
    );
    await _refreshQuickSignInAvailability();
    await _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    final requiresVerification = await _checkContactVerification();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeScreen(requiresContactVerification: requiresVerification),
      ),
      (route) => false,
    );
  }

  Future<bool> _checkContactVerification() async {
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      bool emailVerified = true;
      bool phoneVerified = true;
      for (final attribute in attributes) {
        final key = attribute.userAttributeKey.key;
        if (key == 'email_verified') {
          emailVerified = attribute.value.toLowerCase() == 'true';
        } else if (key == 'phone_number_verified') {
          phoneVerified = attribute.value.toLowerCase() == 'true';
        }
      }
      return !(emailVerified && phoneVerified);
    } catch (_) {
      return false;
    }
  }

  Future<void> _biometricLogin() async {
    if (!_quickSignInReady) {
      final rememberEnabled = await _sessionManager.isRememberMeEnabled();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            rememberEnabled
                ? 'Quick sign-in not available yet. Sign in once to enable it.'
                : 'Quick sign-in disabled. Enable Remember me.',
          ),
        ),
      );
      return;
    }

    final authenticated = await _biometricService.authenticate(
      reason: 'Authenticate to sign in',
    );
    if (!authenticated) return;

    try {
      final session = await _sessionManager.currentSession();
      if (session.isSignedIn) {
        if (!mounted) return;
        await _navigateToHome();
        return;
      }

      bool quickSignedIn = false;
      if (ref.read(authConfigProvider).allowBiometricCredentialLogin) {
        quickSignedIn = await _sessionManager.signInWithStoredCredentials();
      }

      if (quickSignedIn) {
        if (!mounted) return;
        await _navigateToHome();
        return;
      }

      final refreshed = await _sessionManager.currentSession();
      if (refreshed.isSignedIn) {
        if (!mounted) return;
        await _navigateToHome();
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please sign in once to enable quick sign-in.')),
      );
      await _refreshQuickSignInAvailability();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      await _refreshQuickSignInAvailability();
    }
  }

  Future<void> _signInWithSaml() async {
    if (_samlSigningIn) return;
    setState(() => _samlSigningIn = true);
    try {
      final result = await Amplify.Auth.signInWithWebUI();
      if (!mounted) return;
      if (result.isSignedIn) {
        await _postSignInSuccess();
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _samlSigningIn = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    if (ref.read(authConfigProvider).isFederatedLogin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password resets are handled by your organization. Use your corporate self-service portal.'),
        ),
      );
      return;
    }
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email first')),
      );
      return;
    }
    try {
      final controller = ref.read(loginControllerProvider.notifier);
      await controller.requestPasswordReset(email);
      if (!mounted) return;
      final success = await _promptForResetConfirmation(email: email);
      if (!mounted) return;
      if (success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successful. Please sign in.')),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<bool?> _promptForResetConfirmation({required String email}) async {
    final result = await showDialog<_ResetDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _ResetPasswordDialog(
          minPasswordLength: ref.read(authConfigProvider).passwordMinLength,
        );
      },
    );
    if (result == null) {
      return false;
    }
    try {
      await ref.read(loginControllerProvider.notifier).confirmPasswordReset(
            email: email,
            newPassword: result.newPassword,
            confirmationCode: result.code,
          );
      return true;
    } on AuthException catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authConfig = ref.watch(authConfigProvider);
    final loginState = ref.watch(loginControllerProvider);
    final isLoading = loginState.isLoading;

    if (authConfig.isFederatedLogin) {
      final effectiveLoading = isLoading || _samlSigningIn;
      return AuthScaffold(
        title: 'Login',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (effectiveLoading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: AppSpacing.sm),
            ],
            ElevatedButton.icon(
              onPressed: effectiveLoading ? null : _signInWithSaml,
              icon: const Icon(Icons.login),
              label: const Text('Sign in with Microsoft'),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'You will be redirected to your organization\'s Entra ID login page. '
              'Use your corporate credentials and follow any MFA prompts.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      title: 'Login',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isLoading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (loginState.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  loginState.error.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
            SizedBox(height: AppSpacing.sm * 1.5),
            TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: _validatePassword,
                ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Checkbox(
                      value: _rememberMe,
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() => _rememberMe = v);
                        await _sessionManager.updateRememberMe(
                          v,
                          email: v ? _emailController.text.trim() : null,
                        );
                        await _refreshQuickSignInAvailability();
                      },
                ),
                const Text('Remember me'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
                  onPressed: isLoading ? null : _signIn,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign In'),
                ),
            const SizedBox(height: AppSpacing.sm),
            if (_biometricsAvailable) ...[
              OutlinedButton.icon(
                onPressed: (!isLoading && _quickSignInReady) ? _biometricLogin : null,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Use biometrics'),
              ),
              if (!_quickSignInReady)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Sign in once with Remember me enabled to activate quick sign-in.',
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
            TextButton(
                  onPressed: _forgotPassword,
                  child: const Text('Forgot password?'),
                ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Accounts are provisioned by your administrator. '
              'Contact your on-call support team if you need access or updates.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
