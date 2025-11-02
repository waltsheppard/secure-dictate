import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:authapp1/state/security_controller.dart';

abstract class PlatformHooks {
  const PlatformHooks();

  Future<void> onAppLaunch(Ref ref) async {}

  Future<void> onAppResume(Ref ref) async {}

  Future<void> onAppPaused(Ref ref) async {}

  Future<void> onDeepLink(Ref ref, Uri link) async {}

  Future<void> onSignOut(Ref ref) async {}
}

class DefaultPlatformHooks extends PlatformHooks {
  const DefaultPlatformHooks();

  @override
  Future<void> onAppLaunch(Ref ref) async {
    await ref.read(securityControllerProvider.notifier).handleAppLaunch();
  }

  @override
  Future<void> onAppResume(Ref ref) async {
    await ref.read(securityControllerProvider.notifier).handleAppResume();
  }

  @override
  Future<void> onAppPaused(Ref ref) async {
    ref.read(securityControllerProvider.notifier).handleAppPaused();
  }

  @override
  Future<void> onSignOut(Ref ref) async {
    ref.read(securityControllerProvider.notifier).lock();
  }
}

final platformHooksProvider = Provider<PlatformHooks>((ref) {
  return const DefaultPlatformHooks();
});
