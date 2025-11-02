import 'package:flutter_test/flutter_test.dart';
import 'package:authapp1/features/auth/domain/auth_repository.dart';
import 'package:authapp1/features/auth/infrastructure/auth_service.dart';
import 'package:authapp1/features/auth/infrastructure/amplify_auth_repository.dart';

class _FakeAuthService extends AuthService {}

void main() {
  test('AmplifyAuthRepository implements AuthRepository', () {
    final repo = AmplifyAuthRepository(_FakeAuthService());
    expect(repo, isA<AuthRepository>());
  });
}

