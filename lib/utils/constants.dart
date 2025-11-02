import 'package:flutter/foundation.dart';
import 'package:authapp1/features/auth/config/auth_config.dart';

class AppConstants {
  static const int resendCooldownSeconds = 30;
  static final AuthConfig _defaultConfig = AuthConfig();

  static RegExp get emailRegex => _defaultConfig.emailRegex;
  static RegExp get e164Regex => _defaultConfig.phoneRegex;

  static bool get isWeb => kIsWeb;
}

