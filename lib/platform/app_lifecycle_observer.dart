import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'platform_hooks.dart';

class AppLifecycleObserver extends WidgetsBindingObserver {
  AppLifecycleObserver(this.ref) {
    WidgetsBinding.instance.addObserver(this);
  }

  final Ref ref;

  PlatformHooks get _hooks => ref.read(platformHooksProvider);

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        await _hooks.onAppResume(ref);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        await _hooks.onAppPaused(ref);
        break;
      case AppLifecycleState.paused:
        await _hooks.onAppPaused(ref);
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

final appLifecycleObserverProvider = Provider<AppLifecycleObserver>((ref) {
  final observer = AppLifecycleObserver(ref);
  ref.onDispose(observer.dispose);
  return observer;
});

final _appLaunchProvider = Provider<void>((ref) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(platformHooksProvider).onAppLaunch(ref);
  });
});

void bootstrapPlatformHooks(WidgetRef ref) {
  ref.read(appLifecycleObserverProvider);
  ref.read(_appLaunchProvider);
}
