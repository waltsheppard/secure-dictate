import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthMode { local, saml }

class AuthConfig {
  AuthConfig({
    RegExp? emailRegex,
    RegExp? phoneRegex,
    this.passwordMinLength = 8,
    this.rememberMeDefault = true,
    this.allowBiometricCredentialLogin = false,
    this.authMode = AuthMode.local,
  })  : emailRegex = emailRegex ?? RegExp(r'^.+@.+\..+$'),
        phoneRegex = phoneRegex ?? RegExp(r'^\+[1-9]\d{7,14}$');

  final RegExp emailRegex;
  final RegExp phoneRegex;
  final int passwordMinLength;
  final bool rememberMeDefault;
  final bool allowBiometricCredentialLogin;
  final AuthMode authMode;

  bool get isFederatedLogin => authMode == AuthMode.saml;
}

final authConfigProvider = Provider<AuthConfig>((ref) => AuthConfig());
