import 'package:authapp1/features/auth/infrastructure/amplify_auth_repository.dart';
import 'package:authapp1/features/auth/infrastructure/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  test('signIn delegates to service', () async {
    final svc = _MockAuthService();
    final repo = AmplifyAuthRepository(svc);
    when(() => svc.signIn(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => throw UnimplementedError());
    try {
      await repo.signIn(email: 'e', password: 'p');
    } catch (_) {}
    verify(() => svc.signIn(email: 'e', password: 'p')).called(1);
  });
}
