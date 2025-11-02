import 'package:amplify_flutter/amplify_flutter.dart';

class ErrorHelper {
  static String friendly(AuthException e) {
    final msg = e.message;
    if (msg.contains('AliasExistsException')) return 'That email/phone is already in use.';
    if (msg.contains('TooManyRequestsException')) return 'Too many attempts. Please try again shortly.';
    if (msg.contains('UserNotConfirmedException')) return 'Your account isn’t confirmed yet. Check your email/SMS for a code.';
    if (msg.contains('NotAuthorizedException')) return 'Incorrect credentials or account not authorized.';
    if (msg.contains('CodeMismatchException')) return 'Incorrect verification code.';
    if (msg.contains('ExpiredCodeException')) return 'Code expired. Request a new one.';
    return e.message;
  }
}



