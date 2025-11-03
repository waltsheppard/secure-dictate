import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:authapp1/features/auth/auth.dart';
import 'package:authapp1/features/dictation/presentation/dictation_screen.dart';
import 'package:authapp1/features/dictation/presentation/held_dictations_screen.dart';
import 'package:authapp1/features/dictation/presentation/uploads_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.requiresContactVerification = false});

  final bool requiresContactVerification;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _needsVerification = false;
  bool _checkingVerification = false;

  @override
  void initState() {
    super.initState();
    _needsVerification = widget.requiresContactVerification;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshVerification();
    });
  }

  Future<void> _refreshVerification() async {
    setState(() => _checkingVerification = true);
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      bool emailVerified = true;
      final authConfig = ref.read(authConfigProvider);
      bool phoneVerified = !authConfig.requirePhoneVerification;
      for (final attribute in attributes) {
        final key = attribute.userAttributeKey.key;
        if (key == 'email_verified') {
          emailVerified = attribute.value.toLowerCase() == 'true';
        } else if (key == 'phone_number_verified' &&
            authConfig.requirePhoneVerification) {
          phoneVerified = attribute.value.toLowerCase() == 'true';
        }
      }
      if (mounted) {
        setState(() {
          _needsVerification = !(emailVerified && phoneVerified);
        });
      }
    } catch (_) {
      // ignore network errors; keep previous state
    } finally {
      if (mounted) {
        setState(() => _checkingVerification = false);
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await ref.read(sessionManagerProvider).signOut();
    } catch (_) {}
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Uploads',
            icon: const Icon(Icons.cloud_upload_outlined),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const UploadsScreen()));
            },
          ),
          IconButton(
            tooltip: 'Held dictations',
            icon: const Icon(Icons.list_alt),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HeldDictationsScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
              if (!mounted) return;
              await _refreshVerification();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_needsVerification)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Verify your contact information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ref.read(authConfigProvider).requirePhoneVerification
                              ? 'We still need you to confirm your email and phone number. '
                                  'Follow the verification links/code sent to your email and SMS, then refresh status.'
                              : 'We still need you to confirm your email address. '
                                  'Follow the verification link sent to your email, then refresh status.',
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed:
                              _checkingVerification
                                  ? null
                                  : _refreshVerification,
                          child:
                              _checkingVerification
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text('Refresh status'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ProfileScreen(),
                              ),
                            );
                            if (!mounted) return;
                            await _refreshVerification();
                          },
                          child: const Text('Manage security settings'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(child: const DictationBody()),
          ],
        ),
      ),
    );
  }
}
