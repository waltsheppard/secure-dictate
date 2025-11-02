import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:authapp1/features/auth/auth.dart';
import 'package:authapp1/security/inactivity_guard.dart';
import 'package:authapp1/security/security_gate.dart';
import 'package:authapp1/theme/app_theme.dart';
import 'config/app_environment.dart';
import 'amplifyconfiguration.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final envValue = const String.fromEnvironment('APP_ENV');
  final environmentConfig = buildEnvironmentConfig(envValue);
  await _AmplifyBootstrapper.ensureConfigured();
  runApp(
    ProviderScope(
      overrides: [
        authConfigProvider.overrideWithValue(environmentConfig.authConfig),
      ],
      child: MyApp(environment: environmentConfig.environment),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key, required this.environment});

  final AppEnvironment environment;

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    bootstrapPlatformHooks(ref);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auth App',
      theme: AppTheme.light(),
      builder: (context, child) => SecurityGate(
        child: InactivityGuard(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: widget.environment != AppEnvironment.prod,
    );
  }
}

class _AmplifyBootstrapper {
  static bool _isBootstrapped = false;
  static Future<void> ensureConfigured() async {
    if (_isBootstrapped) return;
    if (!Amplify.isConfigured) {
      await AuthService().configureIfNeeded();
      try {
        await Amplify.configure(amplifyconfig);
      } on AmplifyAlreadyConfiguredException {
        // ignore if already configured
      }
    }
    _isBootstrapped = true;
  }
}
