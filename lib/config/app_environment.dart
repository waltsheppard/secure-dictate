import 'package:authapp1/features/auth/auth.dart';

enum AppEnvironment { dev, staging, prod }

AppEnvironment parseAppEnvironment(String? value) {
  const fallback = AppEnvironment.dev;
  if (value == null || value.isEmpty) return fallback;
  final normalized = value.toLowerCase();
  return AppEnvironment.values.firstWhere(
    (env) => env.name == normalized,
    orElse: () => fallback,
  );
}

class EnvironmentConfig {
  const EnvironmentConfig({
    required this.environment,
    required this.authConfig,
  });

  final AppEnvironment environment;
  final AuthConfig authConfig;
}

EnvironmentConfig buildEnvironmentConfig(String? rawEnv) {
  final env = parseAppEnvironment(rawEnv);
  switch (env) {
    case AppEnvironment.staging:
      return EnvironmentConfig(
        environment: env,
        authConfig: AuthConfig(
          passwordMinLength: 10,
          rememberMeDefault: false,
          allowBiometricCredentialLogin: false,
          authMode: AuthMode.local,
        ),
      );
    case AppEnvironment.prod:
      return EnvironmentConfig(
        environment: env,
        authConfig: AuthConfig(
          passwordMinLength: 12,
          rememberMeDefault: false,
          allowBiometricCredentialLogin: false,
          authMode: AuthMode.local,
        ),
      );
    case AppEnvironment.dev:
      return EnvironmentConfig(
        environment: env,
        authConfig: AuthConfig(),
      );
  }
}
