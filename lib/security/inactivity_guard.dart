import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:authapp1/state/security_controller.dart';

class InactivityGuard extends ConsumerStatefulWidget {
  const InactivityGuard({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<InactivityGuard> createState() => _InactivityGuardState();
}

class _InactivityGuardState extends ConsumerState<InactivityGuard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(securityControllerProvider.notifier).recordUserActivity();
    });
  }

  void _record() {
    ref.read(securityControllerProvider.notifier).recordUserActivity();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _record(),
      onPointerMove: (_) => _record(),
      onPointerHover: (_) => _record(),
      child: widget.child,
    );
  }
}
