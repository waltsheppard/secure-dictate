import 'package:flutter_test/flutter_test.dart';
import 'package:authapp1/utils/constants.dart';

void main() {
  group('E.164 regex', () {
    test('valid numbers', () {
      expect(AppConstants.e164Regex.hasMatch('+15551234567'), true);
      expect(AppConstants.e164Regex.hasMatch('+441234567890'), true);
    });
    test('invalid numbers', () {
      expect(AppConstants.e164Regex.hasMatch('5551234567'), false);
      expect(AppConstants.e164Regex.hasMatch('+1'), false);
      expect(AppConstants.e164Regex.hasMatch('+12 345'), false);
    });
  });

  group('Email regex', () {
    test('valid emails', () {
      expect(AppConstants.emailRegex.hasMatch('a@b.co'), true);
      expect(AppConstants.emailRegex.hasMatch('user.name+1@domain.io'), true);
    });
    test('invalid emails', () {
      expect(AppConstants.emailRegex.hasMatch('a@b'), false);
      expect(AppConstants.emailRegex.hasMatch('abc'), false);
    });
  });
}



